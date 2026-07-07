local jobLimits = {
    maxNameLength = 64,
    maxDutyTypeLength = 32,
    salaryIntervalSeconds = 1800
}

local jobPermissions = {
    manage = 'jobs.manage',
    assign = 'jobs.assign',
    salary = 'jobs.salary'
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    return trimmed
end

local function encodeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return json.encode({})
    end

    return json.encode(metadata)
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function hasGlobalPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function writeJobAudit(action, actor, targetType, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'job',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = targetType,
        targetId = targetId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function getJobByName(name)
    return MySQL.single.await([[
        SELECT id, name, label, job_type, is_active, metadata, created_at
        FROM jobs
        WHERE name = ?
        LIMIT 1
    ]], {
        name
    })
end

local function getGrade(jobId, gradeLevel)
    return MySQL.single.await([[
        SELECT id, job_id, grade_level, name, label, salary, permissions
        FROM job_grades
        WHERE job_id = ? AND grade_level = ?
        LIMIT 1
    ]], {
        jobId,
        gradeLevel
    })
end

local function getActiveCharacterJob(characterId, jobId)
    local query = [[
        SELECT cj.id, cj.character_id, cj.job_id, cj.grade_id, cj.is_primary, cj.assigned_at,
            j.name AS job_name, j.label AS job_label, j.job_type,
            g.grade_level, g.name AS grade_name, g.label AS grade_label, g.salary, g.permissions
        FROM character_jobs cj
        JOIN jobs j ON j.id = cj.job_id
        JOIN job_grades g ON g.id = cj.grade_id
        WHERE cj.character_id = ? AND cj.ended_at IS NULL
    ]]
    local values = { characterId }

    if jobId ~= nil then
        query = query .. ' AND cj.job_id = ?'
        values[#values + 1] = jobId
    else
        query = query .. ' AND cj.is_primary = TRUE'
    end

    query = query .. ' ORDER BY cj.assigned_at DESC LIMIT 1'

    return MySQL.single.await(query, values)
end

local function getOpenDutySession(characterId, dutyType, refId)
    return MySQL.single.await([[
        SELECT id, character_id, duty_type, duty_ref_id, started_at
        FROM duty_sessions
        WHERE character_id = ? AND duty_type = ? AND duty_ref_id = ? AND ended_at IS NULL
        ORDER BY started_at DESC
        LIMIT 1
    ]], {
        characterId,
        dutyType,
        refId
    })
end

local function beginJobTransaction()
    MySQL.query.await('START TRANSACTION')
end

local function commitJobTransaction()
    MySQL.query.await('COMMIT')
end

local function rollbackJobTransaction()
    MySQL.query.await('ROLLBACK')
end

local function lockCharacter(characterId)
    return MySQL.scalar.await('SELECT id FROM characters WHERE id = ? AND is_active = TRUE LIMIT 1 FOR UPDATE', {
        characterId
    })
end

local function getOpenDutySessionForUpdate(characterId, dutyType, refId)
    return MySQL.single.await([[
        SELECT id, character_id, duty_type, duty_ref_id, started_at
        FROM duty_sessions
        WHERE character_id = ? AND duty_type = ? AND duty_ref_id = ? AND ended_at IS NULL
        ORDER BY started_at DESC
        LIMIT 1
        FOR UPDATE
    ]], {
        characterId,
        dutyType,
        refId
    })
end

local function getDutyRuntimeSeconds(dutySessionId)
    return MySQL.scalar.await([[
        SELECT TIMESTAMPDIFF(SECOND, started_at, NOW())
        FROM duty_sessions
        WHERE id = ? AND ended_at IS NULL
        LIMIT 1
    ]], {
        dutySessionId
    })
end

local function buildSalaryTransactionId(characterId, jobId, dutySessionId, slot)
    return ('salary_%s_%s_%s_%s'):format(characterId, jobId, dutySessionId, slot)
end

function listJobs()
    local rows = MySQL.query.await([[
        SELECT id, name, label, job_type, is_active, metadata, created_at
        FROM jobs
        WHERE is_active = TRUE
        ORDER BY label ASC
    ]])

    return respond(true, 'OK', 'Jobs wurden geladen.', {
        jobs = rows or {}
    }, nil, nil)
end

function getCharacterJob(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local characterId = normalizeId(payload and payload.characterId) or actor.id

    if characterId ~= actor.id and not hasGlobalPermission(source, jobPermissions.manage) then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local job = getActiveCharacterJob(characterId, nil)

    return respond(true, 'OK', 'Job wurde geladen.', {
        job = job
    }, nil, nil)
end

function assignJob(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not hasGlobalPermission(source, jobPermissions.assign) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Jobs zuweisen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)
    local jobName = normalizeText(payload.jobName, nil)
    local gradeLevel = normalizeId(payload.gradeLevel) or 0
    local primary = payload.isPrimary ~= false

    if characterId == nil or jobName == nil or #jobName > jobLimits.maxNameLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Jobdaten.', nil, nil, nil)
    end

    local job = getJobByName(jobName)

    if job == nil or job.is_active == false or job.is_active == 0 then
        return respond(false, 'NOT_FOUND', 'Job wurde nicht gefunden.', nil, nil, nil)
    end

    local grade = getGrade(job.id, gradeLevel)

    if grade == nil then
        return respond(false, 'NOT_FOUND', 'Jobrang wurde nicht gefunden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        return MySQL.transaction.await({
            {
                query = [[
                    UPDATE character_jobs
                    SET ended_at = NOW()
                    WHERE character_id = ? AND job_id = ? AND ended_at IS NULL
                ]],
                values = { characterId, job.id }
            },
            {
                query = [[
                    UPDATE character_jobs
                    SET is_primary = FALSE
                    WHERE character_id = ? AND ended_at IS NULL
                ]],
                values = { characterId }
            },
            {
                query = [[
                    INSERT INTO character_jobs (character_id, job_id, grade_id, is_primary, assigned_at)
                    VALUES (?, ?, ?, ?, NOW())
                ]],
                values = { characterId, job.id, grade.id, primary }
            }
        })
    end)

    if not success or result == false then
        return respond(false, 'DATABASE_ERROR', 'Job konnte nicht zugewiesen werden.', nil, nil, nil)
    end

    local auditId = writeJobAudit('job.assign', actor, 'character', characterId, {
        jobId = job.id,
        gradeId = grade.id,
        gradeLevel = gradeLevel
    })

    return respond(true, 'OK', 'Job wurde zugewiesen.', {
        job = getActiveCharacterJob(characterId, job.id)
    }, nil, auditId)
end

function startDuty(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local jobId = normalizeId(payload and payload.jobId)
    local activeJob = getActiveCharacterJob(actor.id, jobId)

    if activeJob == nil then
        return respond(false, 'NO_PERMISSION', 'Du bist diesem Job nicht zugeordnet.', nil, nil, nil)
    end

    beginJobTransaction()

    local ok, result = pcall(function()
        if lockCharacter(actor.id) == nil then
            error('CHARACTER_NOT_LOADED', 0)
        end

        local open = getOpenDutySessionForUpdate(actor.id, 'job', activeJob.job_id)

        if open ~= nil then
            return {
                conflict = true,
                dutySession = open
            }
        end

        local dutyId = MySQL.insert.await([[
            INSERT INTO duty_sessions (character_id, duty_type, duty_ref_id, started_at)
            VALUES (?, 'job', ?, NOW())
        ]], {
            actor.id,
            activeJob.job_id
        })

        return {
            dutySessionId = dutyId
        }
    end)

    if not ok then
        rollbackJobTransaction()
        return respond(false, 'DATABASE_ERROR', 'Dienst konnte nicht gestartet werden.', nil, nil, nil)
    end

    commitJobTransaction()

    if result.conflict then
        return respond(false, 'CONFLICT', 'Du bist bereits im Dienst.', {
            dutySession = result.dutySession
        }, nil, nil)
    end

    local auditId = writeJobAudit('job.dutyStart', actor, 'duty_session', result.dutySessionId, {
        jobId = activeJob.job_id
    })

    return respond(true, 'OK', 'Dienst wurde gestartet.', {
        dutySessionId = result.dutySessionId,
        job = activeJob
    }, nil, auditId)
end

function endDuty(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local jobId = normalizeId(payload and payload.jobId)
    local activeJob = getActiveCharacterJob(actor.id, jobId)

    if activeJob == nil then
        return respond(false, 'NO_PERMISSION', 'Du bist diesem Job nicht zugeordnet.', nil, nil, nil)
    end

    beginJobTransaction()

    local ok, result = pcall(function()
        if lockCharacter(actor.id) == nil then
            error('CHARACTER_NOT_LOADED', 0)
        end

        local open = getOpenDutySessionForUpdate(actor.id, 'job', activeJob.job_id)

        if open == nil then
            return {
                missing = true
            }
        end

        MySQL.update.await([[
            UPDATE duty_sessions
            SET ended_at = NOW(), duration_seconds = TIMESTAMPDIFF(SECOND, started_at, NOW())
            WHERE id = ? AND ended_at IS NULL
        ]], {
            open.id
        })

        return {
            dutySessionId = open.id
        }
    end)

    if not ok then
        rollbackJobTransaction()
        return respond(false, 'DATABASE_ERROR', 'Dienst konnte nicht beendet werden.', nil, nil, nil)
    end

    commitJobTransaction()

    if result.missing then
        return respond(false, 'NOT_FOUND', 'Keine offene Dienstzeit gefunden.', nil, nil, nil)
    end

    local ended = MySQL.single.await([[
        SELECT id, character_id, duty_type, duty_ref_id, started_at, ended_at, duration_seconds
        FROM duty_sessions
        WHERE id = ?
        LIMIT 1
    ]], {
        result.dutySessionId
    })

    local auditId = writeJobAudit('job.dutyEnd', actor, 'duty_session', result.dutySessionId, {
        jobId = activeJob.job_id,
        durationSeconds = ended and ended.duration_seconds or nil
    })

    return respond(true, 'OK', 'Dienst wurde beendet.', {
        dutySession = ended
    }, nil, auditId)
end

function paySalary(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local activeJob = getActiveCharacterJob(actor.id, normalizeId(payload and payload.jobId))

    if activeJob == nil then
        return respond(false, 'NO_PERMISSION', 'Du bist diesem Job nicht zugeordnet.', nil, nil, nil)
    end

    local openDuty = getOpenDutySession(actor.id, 'job', activeJob.job_id)

    if openDuty == nil then
        return respond(false, 'CONFLICT', 'Gehalt ist nur im aktiven Dienst moeglich.', nil, nil, nil)
    end

    local runtimeSeconds = normalizeId(getDutyRuntimeSeconds(openDuty.id)) or 0

    if runtimeSeconds < jobLimits.salaryIntervalSeconds then
        return respond(false, 'CONFLICT', 'Gehalt ist erst nach ausreichender Dienstzeit moeglich.', nil, {
            requiredSeconds = jobLimits.salaryIntervalSeconds,
            currentSeconds = runtimeSeconds
        }, nil)
    end

    local salarySlot = math.floor(runtimeSeconds / jobLimits.salaryIntervalSeconds)
    local salaryTransactionId = buildSalaryTransactionId(actor.id, activeJob.job_id, openDuty.id, salarySlot)

    if MySQL.scalar.await('SELECT id FROM economy_ledger WHERE transaction_id = ? LIMIT 1', {
        salaryTransactionId
    }) ~= nil then
        return respond(false, 'CONFLICT', 'Gehalt fuer dieses Dienstzeitfenster wurde bereits ausgezahlt.', nil, nil, nil)
    end

    local salary = normalizeId(activeJob.salary)

    if salary == nil or salary <= 0 then
        return respond(false, 'CONFLICT', 'Fuer diesen Rang ist kein Gehalt hinterlegt.', nil, nil, nil)
    end

    local account = MySQL.single.await([[
        SELECT id, account_number
        FROM accounts
        WHERE owner_type = 'character' AND owner_id = ? AND account_type = 'checking'
        ORDER BY created_at ASC
        LIMIT 1
    ]], {
        actor.id
    })

    if account == nil then
        return respond(false, 'NOT_FOUND', 'Kein Gehaltskonto gefunden.', nil, nil, nil)
    end

    local paid = addSystemMoney(source, {
        accountId = account.id,
        amount = salary,
        reason = ('Gehalt: %s'):format(activeJob.job_label),
        category = 'salary',
        transactionId = salaryTransactionId,
        transactionPrefix = 'salary',
        metadata = {
            jobId = activeJob.job_id,
            gradeId = activeJob.grade_id,
            gradeLevel = activeJob.grade_level,
            dutySessionId = openDuty.id,
            salarySlot = salarySlot,
            salaryIntervalSeconds = jobLimits.salaryIntervalSeconds
        }
    })

    if not paid.success then
        return paid
    end

    local auditId = writeJobAudit('job.salaryPay', actor, 'job', activeJob.job_id, {
        accountId = account.id,
        amount = salary,
        ledgerId = paid.data and paid.data.ledger and paid.data.ledger.id or nil
    })

    return respond(true, 'OK', 'Gehalt wurde ausgezahlt.', paid.data, nil, auditId)
end

exports('job.list', listJobs)
exports('job.getCharacter', getCharacterJob)
exports('job.assign', assignJob)
exports('job.startDuty', startDuty)
exports('job.endDuty', endDuty)
exports('job.paySalary', paySalary)
