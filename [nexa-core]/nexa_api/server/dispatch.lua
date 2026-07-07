local dispatchLimits = {
    maxCategoryLength = 64,
    maxDescriptionLength = 500,
    maxFactionNameLength = 64,
    maxLimit = 50,
    defaultLimit = 25,
    minPriority = 1,
    maxPriority = 5,
    defaultPriority = 3
}

local dispatchPermissions = {
    view = 'dispatch.view',
    create = 'dispatch.create',
    assign = 'dispatch.assign',
    status = 'dispatch.status',
    priority = 'dispatch.priority',
    manage = 'dispatch.manage'
}

local statusTransitions = {
    open = {
        assigned = true,
        closed = true,
        cancelled = true
    },
    assigned = {
        open = true,
        closed = true,
        cancelled = true
    },
    closed = {},
    cancelled = {}
}

local emergencyFactions = {
    lspd = true,
    ems = true,
    government = true,
    weazel = true
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

local function normalizePriority(value)
    local number = tonumber(value) or dispatchLimits.defaultPriority

    if number == nil or math.floor(number) ~= number then
        return nil
    end

    if number < dispatchLimits.minPriority or number > dispatchLimits.maxPriority then
        return nil
    end

    return number
end

local function normalizeLimit(value)
    local number = tonumber(value) or dispatchLimits.defaultLimit

    if number < 1 then
        return dispatchLimits.defaultLimit
    end

    return math.min(math.floor(number), dispatchLimits.maxLimit)
end

local function normalizeText(value, fallback, maxLength)
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

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function encodeJson(value)
    if type(value) ~= 'table' then
        return json.encode({})
    end

    return json.encode(value)
end

local function decodeJson(value)
    if value == nil or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)

    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    return decoded
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

local function writeDispatchAudit(action, actor, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'dispatch',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'dispatch_call',
        targetId = targetId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function normalizeLocation(location)
    if type(location) ~= 'table' then
        return nil
    end

    local normalized = {}

    for _, key in ipairs({ 'x', 'y', 'z', 'heading' }) do
        if location[key] ~= nil then
            local number = tonumber(location[key])

            if number == nil then
                return nil
            end

            normalized[key] = number
        end
    end

    normalized.street = normalizeText(location.street, nil, 128)
    normalized.zone = normalizeText(location.zone, nil, 64)

    return normalized
end

local function normalizeTargetFactions(value)
    local result = {}

    if value == nil then
        return result
    end

    if type(value) ~= 'table' or #value > 6 then
        return nil
    end

    for _, factionName in ipairs(value) do
        local normalized = normalizeText(factionName, nil, dispatchLimits.maxFactionNameLength)

        if normalized == nil or not emergencyFactions[normalized] then
            return nil
        end

        result[#result + 1] = normalized
    end

    return result
end

local function getDispatchCall(callId)
    return MySQL.single.await([[
        SELECT id, call_number, caller_character_id, status, priority, category, location, description, metadata, created_at, closed_at
        FROM dispatch_calls
        WHERE id = ?
        LIMIT 1
    ]], {
        callId
    })
end

local function getDispatchCallForUpdate(callId)
    return MySQL.single.await([[
        SELECT id, call_number, caller_character_id, status, priority, category, location, description, metadata, created_at, closed_at
        FROM dispatch_calls
        WHERE id = ?
        LIMIT 1
        FOR UPDATE
    ]], {
        callId
    })
end

local function beginDispatchTransaction()
    MySQL.query.await('START TRANSACTION')
end

local function commitDispatchTransaction()
    MySQL.query.await('COMMIT')
end

local function rollbackDispatchTransaction()
    MySQL.query.await('ROLLBACK')
end

local function findFactionMembership(characterId, factionName)
    local query = [[
        SELECT fm.id, fm.faction_id, fm.character_id, fm.grade_id, fm.callsign,
            f.name AS faction_name, f.label AS faction_label, f.faction_type, f.status,
            fg.grade_level, fg.name AS grade_name, fg.label AS grade_label
        FROM faction_members fm
        JOIN factions f ON f.id = fm.faction_id
        JOIN faction_grades fg ON fg.id = fm.grade_id
        WHERE fm.character_id = ? AND fm.left_at IS NULL AND f.status = 'active'
    ]]
    local values = { characterId }

    if factionName ~= nil then
        query = query .. ' AND f.name = ?'
        values[#values + 1] = factionName
    end

    query = query .. ' ORDER BY fg.grade_level DESC LIMIT 1'

    return MySQL.single.await(query, values)
end

local function findDispatchJob(characterId)
    return MySQL.single.await([[
        SELECT cj.id, cj.character_id, cj.job_id, cj.grade_id,
            j.name AS job_name, j.label AS job_label, j.job_type,
            g.grade_level, g.name AS grade_name, g.label AS grade_label, g.permissions
        FROM character_jobs cj
        JOIN jobs j ON j.id = cj.job_id
        JOIN job_grades g ON g.id = cj.grade_id
        WHERE cj.character_id = ? AND cj.ended_at IS NULL AND j.is_active = TRUE
            AND (j.job_type = 'faction' OR j.name IN ('dispatcher', 'ems', 'police'))
        ORDER BY cj.assigned_at DESC
        LIMIT 1
    ]], {
        characterId
    })
end

local function hasDispatchAccess(source, actor, permission, factionName)
    if hasGlobalPermission(source, dispatchPermissions.manage) or hasGlobalPermission(source, permission) then
        return true, nil
    end

    local membership = findFactionMembership(actor.id, factionName)

    if membership ~= nil then
        return true, membership
    end

    local job = findDispatchJob(actor.id)

    if job ~= nil then
        return true, job
    end

    return false, nil
end

local function createCallNumber()
    return ('D%s%03d'):format(os.date('%y%m%d%H%M%S'), math.random(0, 999))
end

local function generateCallNumber()
    for _ = 1, 10 do
        local callNumber = createCallNumber()
        local existing = MySQL.scalar.await('SELECT id FROM dispatch_calls WHERE call_number = ? LIMIT 1', {
            callNumber
        })

        if existing == nil then
            return callNumber
        end
    end

    return nil
end

local function appendHistory(metadata, action, actor, extra)
    metadata.status_history = metadata.status_history or {}
    metadata.status_history[#metadata.status_history + 1] = {
        action = action,
        actorCharacterId = actor and actor.id or nil,
        actorPlayerId = actor and actor.player_id or nil,
        at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        extra = extra or {}
    }
end

function createDispatchCall(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Notrufdaten.', nil, nil, nil)
    end

    local category = normalizeText(payload.category, 'general', dispatchLimits.maxCategoryLength)
    local description = normalizeText(payload.description, nil, dispatchLimits.maxDescriptionLength)
    local priority = normalizePriority(payload.priority)
    local location = normalizeLocation(payload.location)
    local targetFactions = normalizeTargetFactions(payload.targetFactions)

    if category == nil or description == nil or priority == nil or targetFactions == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Notrufdaten.', nil, nil, nil)
    end

    local callNumber = generateCallNumber()

    if callNumber == nil then
        return respond(false, 'CONFLICT', 'Notrufnummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local metadata = {
        target_factions = targetFactions,
        assigned_units = {},
        created_by = {
            characterId = actor.id,
            playerId = actor.player_id
        }
    }

    appendHistory(metadata, 'dispatch.created', actor, {
        priority = priority,
        category = category
    })

    local callId = MySQL.insert.await([[
        INSERT INTO dispatch_calls (
            call_number, caller_character_id, status, priority, category, location, description, metadata, created_at
        )
        VALUES (?, ?, 'open', ?, ?, ?, ?, ?, NOW())
    ]], {
        callNumber,
        actor.id,
        priority,
        category,
        encodeJson(location or {}),
        description,
        encodeJson(metadata)
    })

    if callId == nil then
        return respond(false, 'DATABASE_ERROR', 'Notruf konnte nicht erstellt werden.', nil, nil, nil)
    end

    local auditId = writeDispatchAudit('dispatch.callCreated', actor, callId, {
        callNumber = callNumber,
        category = category,
        priority = priority,
        targetFactions = targetFactions
    })

    return respond(true, 'CREATED', 'Notruf wurde erstellt.', {
        call = getDispatchCall(callId)
    }, nil, auditId)
end

function listDispatchCalls(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    payload = payload or {}

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Filterdaten.', nil, nil, nil)
    end

    local factionName = normalizeText(payload.faction, nil, dispatchLimits.maxFactionNameLength)
    local allowed = hasDispatchAccess(source, actor, dispatchPermissions.view, factionName)

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local status = normalizeText(payload.status, nil, 16)
    local limit = normalizeLimit(payload.limit)
    local query = [[
        SELECT id, call_number, caller_character_id, status, priority, category, location, description, metadata, created_at, closed_at
        FROM dispatch_calls
        WHERE 1 = 1
    ]]
    local values = {}

    if status ~= nil then
        if statusTransitions[status] == nil then
            return respond(false, 'INVALID_INPUT', 'Ungueltiger Einsatzstatus.', nil, nil, nil)
        end

        query = query .. ' AND status = ?'
        values[#values + 1] = status
    else
        query = query .. " AND status IN ('open', 'assigned')"
    end

    if factionName ~= nil then
        query = query .. [[
            AND (
                JSON_LENGTH(JSON_EXTRACT(metadata, '$.target_factions')) IS NULL
                OR JSON_LENGTH(JSON_EXTRACT(metadata, '$.target_factions')) = 0
                OR JSON_CONTAINS(JSON_EXTRACT(metadata, '$.target_factions'), JSON_QUOTE(?))
            )
        ]]
        values[#values + 1] = factionName
    end

    query = query .. ' ORDER BY priority ASC, created_at DESC LIMIT ?'
    values[#values + 1] = limit

    local calls = MySQL.query.await(query, values) or {}

    return respond(true, 'OK', 'Dispatch-Einsaetze wurden geladen.', {
        calls = calls
    }, {
        limit = limit
    }, nil)
end

function assignDispatchCall(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zuweisungsdaten.', nil, nil, nil)
    end

    local callId = normalizeId(payload.callId)
    local characterId = normalizeId(payload.characterId) or actor.id
    local factionName = normalizeText(payload.faction, nil, dispatchLimits.maxFactionNameLength)

    if callId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zuweisungsdaten.', nil, nil, nil)
    end

    local allowed, membership = hasDispatchAccess(source, actor, dispatchPermissions.assign, factionName)

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Einsaetze zuweisen.', nil, nil, nil)
    end

    beginDispatchTransaction()

    local ok, result = pcall(function()
        local call = getDispatchCallForUpdate(callId)

        if call == nil then
            return {
                success = false,
                code = 'NOT_FOUND',
                message = 'Einsatz wurde nicht gefunden.'
            }
        end

        if call.status == 'closed' or call.status == 'cancelled' then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Dieser Einsatz ist bereits abgeschlossen.'
            }
        end

        local metadata = decodeJson(call.metadata)
        metadata.assigned_units = metadata.assigned_units or {}
        metadata.assigned_units[#metadata.assigned_units + 1] = {
            characterId = characterId,
            assignedByCharacterId = actor.id,
            faction = factionName or (membership and membership.faction_name or nil),
            callsign = membership and membership.callsign or nil,
            assignedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
        appendHistory(metadata, 'dispatch.assigned', actor, {
            characterId = characterId,
            faction = factionName
        })

        local updated = MySQL.update.await([[
            UPDATE dispatch_calls
            SET status = 'assigned', metadata = ?
            WHERE id = ? AND status IN ('open', 'assigned')
        ]], {
            encodeJson(metadata),
            callId
        })

        if updated == nil or updated < 1 then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Einsatz konnte nicht zugewiesen werden.'
            }
        end

        return {
            success = true
        }
    end)

    if not ok then
        rollbackDispatchTransaction()
        return respond(false, 'DATABASE_ERROR', 'Einsatz konnte nicht zugewiesen werden.', nil, nil, nil)
    end

    commitDispatchTransaction()

    if not result.success then
        return respond(false, result.code, result.message, nil, nil, nil)
    end

    local auditId = writeDispatchAudit('dispatch.callAssigned', actor, callId, {
        assignedCharacterId = characterId,
        faction = factionName
    })

    return respond(true, 'UPDATED', 'Einsatz wurde zugewiesen.', {
        call = getDispatchCall(callId)
    }, nil, auditId)
end

function updateDispatchStatus(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Einsatzstatus.', nil, nil, nil)
    end

    local callId = normalizeId(payload.callId)
    local nextStatus = normalizeText(payload.status, nil, 16)

    if callId == nil or statusTransitions[nextStatus] == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Einsatzstatus.', nil, nil, nil)
    end

    local allowed = hasDispatchAccess(source, actor, dispatchPermissions.status, nil)

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du darfst den Einsatzstatus nicht aendern.', nil, nil, nil)
    end

    beginDispatchTransaction()

    local ok, result = pcall(function()
        local call = getDispatchCallForUpdate(callId)

        if call == nil then
            return {
                success = false,
                code = 'NOT_FOUND',
                message = 'Einsatz wurde nicht gefunden.'
            }
        end

        if not statusTransitions[call.status][nextStatus] then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Dieser Statuswechsel ist nicht erlaubt.'
            }
        end

        local metadata = decodeJson(call.metadata)
        appendHistory(metadata, 'dispatch.statusChanged', actor, {
            from = call.status,
            to = nextStatus,
            reason = normalizeText(payload.reason, nil, 255)
        })

        local closedAtExpression = (nextStatus == 'closed' or nextStatus == 'cancelled') and 'NOW()' or 'NULL'
        local updated = MySQL.update.await(([[  
            UPDATE dispatch_calls
            SET status = ?, metadata = ?, closed_at = %s
            WHERE id = ? AND status = ?
        ]]):format(closedAtExpression), {
            nextStatus,
            encodeJson(metadata),
            callId,
            call.status
        })

        if updated == nil or updated < 1 then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Einsatzstatus konnte nicht geaendert werden.'
            }
        end

        return {
            success = true,
            previousStatus = call.status
        }
    end)

    if not ok then
        rollbackDispatchTransaction()
        return respond(false, 'DATABASE_ERROR', 'Einsatzstatus konnte nicht geaendert werden.', nil, nil, nil)
    end

    commitDispatchTransaction()

    if not result.success then
        return respond(false, result.code, result.message, nil, nil, nil)
    end

    local auditId = writeDispatchAudit('dispatch.statusChanged', actor, callId, {
        from = result.previousStatus,
        to = nextStatus
    })

    return respond(true, 'UPDATED', 'Einsatzstatus wurde geaendert.', {
        call = getDispatchCall(callId)
    }, nil, auditId)
end

function setDispatchPriority(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Prioritaet.', nil, nil, nil)
    end

    local callId = normalizeId(payload.callId)
    local priority = normalizePriority(payload.priority)

    if callId == nil or priority == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Prioritaet.', nil, nil, nil)
    end

    local allowed = hasDispatchAccess(source, actor, dispatchPermissions.priority, nil)

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du darfst die Prioritaet nicht aendern.', nil, nil, nil)
    end

    beginDispatchTransaction()

    local ok, result = pcall(function()
        local call = getDispatchCallForUpdate(callId)

        if call == nil then
            return {
                success = false,
                code = 'NOT_FOUND',
                message = 'Einsatz wurde nicht gefunden.'
            }
        end

        if call.status == 'closed' or call.status == 'cancelled' then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Dieser Einsatz ist bereits abgeschlossen.'
            }
        end

        local metadata = decodeJson(call.metadata)
        appendHistory(metadata, 'dispatch.priorityChanged', actor, {
            from = call.priority,
            to = priority
        })

        local updated = MySQL.update.await([[
            UPDATE dispatch_calls
            SET priority = ?, metadata = ?
            WHERE id = ? AND status IN ('open', 'assigned')
        ]], {
            priority,
            encodeJson(metadata),
            callId
        })

        if updated == nil or updated < 1 then
            return {
                success = false,
                code = 'CONFLICT',
                message = 'Prioritaet konnte nicht geaendert werden.'
            }
        end

        return {
            success = true,
            previousPriority = call.priority
        }
    end)

    if not ok then
        rollbackDispatchTransaction()
        return respond(false, 'DATABASE_ERROR', 'Prioritaet konnte nicht geaendert werden.', nil, nil, nil)
    end

    commitDispatchTransaction()

    if not result.success then
        return respond(false, result.code, result.message, nil, nil, nil)
    end

    local auditId = writeDispatchAudit('dispatch.priorityChanged', actor, callId, {
        from = result.previousPriority,
        to = priority
    })

    return respond(true, 'UPDATED', 'Prioritaet wurde geaendert.', {
        call = getDispatchCall(callId)
    }, nil, auditId)
end

exports('dispatch.createCall', createDispatchCall)
exports('dispatch.listCalls', listDispatchCalls)
exports('dispatch.assignCall', assignDispatchCall)
exports('dispatch.updateStatus', updateDispatchStatus)
exports('dispatch.setPriority', setDispatchPriority)
