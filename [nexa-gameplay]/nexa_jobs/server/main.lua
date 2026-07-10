local migrated = false
local jobsBySource = {}
local sourceByCharacter = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_JOB_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end

local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end

local function encode(value)
    local okJson, encoded = pcall(json.encode, value or {})
    return okJson and encoded or '{}'
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id % 1 == 0 and math.floor(id) or nil
end

local function normalizeSource(value)
    local source = tonumber(value)
    return source and source > 0 and source % 1 == 0 and math.floor(source) or nil
end

local function normalizeString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')
    if normalized == '' or (maxLength and #normalized > maxLength) then return nil end
    return normalized
end

local function correlationId(prefix)
    return ('%s:%s:%s:%s'):format(prefix or 'job', os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local okCore, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return okCore and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end
    print(('[%s] [%s] %s %s'):format(NEXA_JOBS.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_JOBS.resourceName }) end
end

local function audit(action, state, result, context)
    context = type(context) == 'table' and context or {}
    NexaJobsDatabase.InsertAudit({
        action = action,
        source = state and state.source or context.source,
        character_id = state and state.character_id or context.character_id,
        organization_id = state and state.organization_id or context.organization_id,
        rank_id = state and state.rank_id or context.rank_id,
        duty_session_id = state and state.duty_session_id or context.duty_session_id,
        reason = context.reason,
        result = result.ok and 'success' or 'failed',
        error_code = result.ok and nil or result.code,
        metadata = context.metadata,
        correlation_id = context.correlation_id or correlationId(action)
    })
end

local function activeCharacterId(source)
    if GetResourceState('nexa_playerstate') == 'started' then
        local okState, stateResult = pcall(function() return exports.nexa_playerstate:GetActiveCharacter(source) end)
        if okState and stateResult then
            local data = type(stateResult) == 'table' and (stateResult.data or stateResult) or {}
            local character = data.character or data
            local characterId = normalizeId(character.id or character.character_id)
            if characterId then return characterId end
        end
    end
    local okChar, charResult = pcall(function() return exports.nexa_characters:GetActiveCharacter(source) end)
    if okChar and charResult then
        local data = type(charResult) == 'table' and (charResult.data or charResult) or {}
        local character = data.character or data
        return normalizeId(character.id or character.character_id)
    end
    return nil
end

local function loadJobForSource(source)
    source = normalizeSource(source)
    if not source then return fail(NEXA_JOB_ERRORS.invalidInput, 'Source is invalid.') end
    local characterId = activeCharacterId(source)
    if not characterId then return fail(NEXA_JOB_ERRORS.notAssigned, 'No active character.') end
    local membership = exports.nexa_organizations:GetCharacterOrganization(characterId)
    if not membership or not membership.ok then
        jobsBySource[source] = { source = source, character_id = characterId, state = NEXA_JOB_STATES.unassigned }
        return fail(NEXA_JOB_ERRORS.notAssigned, 'No active organization membership.')
    end
    local organization = exports.nexa_organizations:GetOrganization(membership.data.organization_id)
    local rank = exports.nexa_organizations:GetOrganizationRanks(membership.data.organization_id)
    local state = {
        source = source,
        character_id = characterId,
        organization_id = membership.data.organization_id,
        rank_id = membership.data.rank_id,
        member = membership.data,
        organization = organization and organization.ok and organization.data or nil,
        ranks = rank and rank.ok and rank.data or {},
        state = NEXA_JOB_STATES.offDuty,
        duty_session_id = nil,
        loaded_at = os.time()
    }
    jobsBySource[source] = state
    sourceByCharacter[characterId] = source
    emit(NEXA_JOB_EVENTS.ready, { source = source, characterId = characterId, organizationId = state.organization_id, rankId = state.rank_id })
    return ok(state, 'Job loaded.')
end

function GetJob(source)
    source = normalizeSource(source)
    if not source then return fail(NEXA_JOB_ERRORS.invalidInput, 'Source is invalid.') end
    return jobsBySource[source] and ok(jobsBySource[source], 'Job loaded.') or loadJobForSource(source)
end

function GetJobByCharacter(characterId)
    characterId = normalizeId(characterId)
    if not characterId then return fail(NEXA_JOB_ERRORS.invalidInput, 'Character id is invalid.') end
    local source = sourceByCharacter[characterId]
    if source and jobsBySource[source] then return ok(jobsBySource[source], 'Job loaded.') end
    local membership = exports.nexa_organizations:GetCharacterOrganization(characterId)
    if not membership or not membership.ok then return fail(NEXA_JOB_ERRORS.notAssigned, 'Job not assigned.') end
    return ok({ character_id = characterId, organization_id = membership.data.organization_id, rank_id = membership.data.rank_id, state = NEXA_JOB_STATES.assigned }, 'Job loaded.')
end

function IsOnDuty(source)
    local job = GetJob(source)
    return ok(job.ok and job.data.state == NEXA_JOB_STATES.onDuty, 'Duty checked.')
end

local function canUseDuty(state)
    if not state or not state.organization_id then return false, NEXA_JOB_ERRORS.notAssigned end
    if state.organization and state.organization.status == 'suspended' then return false, NEXA_JOB_ERRORS.organizationSuspended end
    if state.member and state.member.status == 'suspended' then return false, NEXA_JOB_ERRORS.memberSuspended end
    if not exports.nexa_organizations:HasOrganizationPermission(state.character_id, NexaJobsConfig.dutyPermission, { organization_id = state.organization_id }) then
        return false, NEXA_JOB_ERRORS.dutyNotAllowed
    end
    return true
end

function StartDuty(source, context)
    context = type(context) == 'table' and context or {}
    local job = GetJob(source)
    if not job.ok then return job end
    local state = job.data
    if state.state == NEXA_JOB_STATES.onDuty then return fail(NEXA_JOB_ERRORS.alreadyOnDuty, 'Already on duty.') end
    local allowed, code = canUseDuty(state)
    if not allowed then return fail(code, 'Duty is not allowed.') end
    local existing = NexaJobsDatabase.GetActiveDutySession(state.character_id)
    if existing then return fail(NEXA_JOB_ERRORS.dutySessionConflict, 'Active duty session already exists.') end
    local sessionId, err = NexaJobsDatabase.InsertDutySession({ character_id = state.character_id, organization_id = state.organization_id, rank_id = state.rank_id, status = NEXA_DUTY_SESSION_STATUS.active, start_reason = normalizeString(context.reason, 255), source = state.source, metadata = {} })
    if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Duty session could not be started.', err) end
    state.state = NEXA_JOB_STATES.onDuty
    state.duty_session_id = sessionId
    local result = ok({ duty_session_id = sessionId, organization_id = state.organization_id, character_id = state.character_id }, 'Duty started.')
    audit('duty.start', state, result, context)
    emit(NEXA_JOB_EVENTS.dutyStarted, result.data)
    return result
end

function StopDuty(source, reason, context)
    context = type(context) == 'table' and context or {}
    context.reason = context.reason or reason
    local job = GetJob(source)
    if not job.ok then return job end
    local state = job.data
    local session = NexaJobsDatabase.GetActiveDutySession(state.character_id)
    if not session then return fail(NEXA_JOB_ERRORS.notOnDuty, 'Not on duty.') end
    local _, err = NexaJobsDatabase.EndDutySession(session.id, NEXA_DUTY_SESSION_STATUS.ended, normalizeString(context.reason, 255))
    if err then return fail(NEXA_JOB_ERRORS.databaseError, 'Duty session could not be stopped.', err) end
    state.state = NEXA_JOB_STATES.offDuty
    state.duty_session_id = nil
    local result = ok({ duty_session_id = session.id, organization_id = state.organization_id, character_id = state.character_id }, 'Duty stopped.')
    audit('duty.stop', state, result, context)
    emit(NEXA_JOB_EVENTS.dutyStopped, result.data)
    return result
end

function GetActiveDutyMembers(organizationId)
    organizationId = normalizeId(organizationId)
    if not organizationId then return fail(NEXA_JOB_ERRORS.invalidInput, 'Organization id is invalid.') end
    local rows, err = NexaJobsDatabase.ListActiveDuty(organizationId)
    return err and fail(NEXA_JOB_ERRORS.databaseError, 'Duty sessions could not be listed.', err) or ok(rows or {}, 'Active duty members listed.')
end

function ForceStopDuty(actor, targetSource, reason)
    return StopDuty(targetSource, reason or 'Force stop duty', { reason = reason, actor = actor })
end

function JobsUnload(source, reason)
    source = normalizeSource(source)
    if not source then return fail(NEXA_JOB_ERRORS.invalidInput, 'Source is invalid.') end
    local state = jobsBySource[source]
    if state then
        if state.state == NEXA_JOB_STATES.onDuty then
            StopDuty(source, reason or 'Job unload')
        end
        emit(NEXA_JOB_EVENTS.unloading, { source = source, characterId = state.character_id })
        sourceByCharacter[state.character_id] = nil
        jobsBySource[source] = nil
    end
    return ok({ source = source }, 'Job unloaded.')
end

local function registerCallbacks()
    local core = getCore()
    if not core or not core.Callbacks then return end
    core.Callbacks.RegisterNetwork('nexa:jobs:cb:getOwnJob', function(source)
        return GetJob(source)
    end, { rateLimitMs = NexaJobsConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork('nexa:jobs:cb:startDuty', function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        return StartDuty(source, { reason = payload.reason })
    end, { rateLimitMs = NexaJobsConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork('nexa:jobs:cb:stopDuty', function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        return StopDuty(source, payload.reason)
    end, { rateLimitMs = NexaJobsConfig.callbacks.rateLimitMs })
end

AddEventHandler('nexa:playerstate:active', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local source = normalizeSource(payload.source)
    if source then loadJobForSource(source) end
end)

AddEventHandler('playerDropped', function(reason)
    JobsUnload(source, reason or 'playerDropped')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaJobsConfig.autoMigrate then
        local migrateOk, migrateErr = NexaJobsDatabase.Migrate()
        migrated = migrateOk == true
        if not migrated then log('Error', 'jobs.migration', 'Jobs migration failed.', { error = migrateErr }) end
    end
    registerCallbacks()
    log('Info', 'jobs.start', 'nexa_jobs started.', { migrated = migrated })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for source in pairs(jobsBySource) do
        JobsUnload(source, 'resource stop')
    end
    log('Info', 'jobs.stop', 'nexa_jobs stopped.')
end)

exports('GetJob', GetJob)
exports('GetJobByCharacter', GetJobByCharacter)
exports('IsOnDuty', IsOnDuty)
exports('StartDuty', StartDuty)
exports('StopDuty', StopDuty)
exports('GetActiveDutyMembers', GetActiveDutyMembers)
exports('ForceStopDuty', ForceStopDuty)
exports('getStatus', function() return { resourceName = NEXA_JOBS.resourceName, version = NEXA_JOBS.version, migrated = migrated, loadedJobs = jobsBySource } end)
exports('getSchema', NexaJobsDatabase.GetSchema)
