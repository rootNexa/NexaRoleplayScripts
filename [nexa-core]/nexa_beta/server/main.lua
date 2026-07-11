local migrated = false
local creators = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_BETA_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function registerCallback(name, handler) if GetResourceState('nexa_api') == 'started' then exports.nexa_api:RegisterServerCallback(name, handler) end end

local defaultCreators = {
    jobs = { label = 'Jobs Creator', resource_name = 'nexa_jobscreator' },
    vehicles = { label = 'Vehicle Creator', resource_name = 'nexa_vehicles' },
    items = { label = 'Item Creator', resource_name = 'nexa_items' },
    evidence = { label = 'Evidence Creator', resource_name = 'nexa_evidence' },
    licenses = { label = 'License Creator', resource_name = 'nexa_licenses' },
    dispatch = { label = 'Dispatch Creator', resource_name = 'nexa_dispatch' },
    hospital = { label = 'Hospital Creator', resource_name = 'nexa_ems' },
    housing = { label = 'Housing Creator', resource_name = 'nexa_properties' },
    shops = { label = 'Shop Creator', resource_name = 'nexa_shops' },
    crafting = { label = 'Crafting Creator', resource_name = 'nexa_crafting' },
    registry = { label = 'Registry Management', resource_name = 'nexa_beta' }
}

function RegisterCreator(payload)
    payload = type(payload) == 'table' and payload or {}
    local creatorType = payload.creator_type or payload.type
    if type(creatorType) ~= 'string' or creatorType == '' then return fail(NEXA_BETA_ERRORS.invalidInput, 'Creator type is required.') end
    local entry = { creator_type = creatorType, label = payload.label or creatorType, resource_name = payload.resource_name, enabled = payload.enabled ~= false, metadata = payload.metadata or {} }
    creators[creatorType] = entry
    local id, err = NexaBetaDatabase.UpsertCreator(entry)
    return err and fail(NEXA_BETA_ERRORS.databaseError, 'Creator could not be registered.', err) or ok({ creator_id = id, creator = entry }, 'Creator registered.')
end

function ListCreators()
    local rows, err = NexaBetaDatabase.ListCreators()
    if err then
        local fallback = {}

        for _, entry in pairs(creators) do
            fallback[#fallback + 1] = entry
        end

        return ok({ creators = fallback, source = 'memory' }, 'Creators listed from memory registry.', { warning = err })
    end

    return ok({ creators = rows or {}, source = 'database' }, 'Creators listed.')
end

function SetFeatureFlag(flagKey, enabled, value)
    if type(flagKey) ~= 'string' or flagKey == '' then return fail(NEXA_BETA_ERRORS.invalidInput, 'Feature flag is invalid.') end
    local id, err = NexaBetaDatabase.UpsertFeatureFlag({ flag_key = flagKey, enabled = enabled == true, value = value or {} })
    return err and fail(NEXA_BETA_ERRORS.databaseError, 'Feature flag could not be updated.', err) or ok({ flag_id = id, flag_key = flagKey, enabled = enabled == true }, 'Feature flag updated.')
end

function CollectHealth()
    local resources = {}
    local ready = true
    for _, resourceName in ipairs(NexaBetaConfig.requiredResources) do
        local state = GetResourceState(resourceName)
        resources[#resources + 1] = { name = resourceName, state = state }
        if state ~= 'started' then ready = false end
    end
    return ok({ ready = ready, resources = resources }, ready and 'All required resources are started.' or 'Required resources are missing.')
end

function GetReadiness()
    local health = CollectHealth()
    return ok({ stage = NexaBetaConfig.targetStage, channel = NexaBetaConfig.releaseChannel, health = health.data, migrated = migrated }, 'Beta readiness collected.')
end

function RecordPerformanceSnapshot(payload)
    payload = type(payload) == 'table' and payload or {}
    local key = payload.snapshot_key or ('snapshot-' .. os.time())
    local id, err = NexaBetaDatabase.InsertPerformanceSnapshot({ snapshot_key = key, cpu_ms = tonumber(payload.cpu_ms), memory_kb = tonumber(payload.memory_kb), net_events = tonumber(payload.net_events), sql_queries = tonumber(payload.sql_queries), metadata = payload.metadata or {} })
    return err and fail(NEXA_BETA_ERRORS.databaseError, 'Performance snapshot could not be recorded.', err) or ok({ snapshot_id = id, snapshot_key = key }, 'Performance snapshot recorded.')
end

function GetReleaseMetadata()
    return ok({ release_key = 'gp18-alpha', release_channel = NexaBetaConfig.releaseChannel, status = NexaBetaConfig.targetStage, version = NEXA_BETA.version }, 'Release metadata loaded.')
end

local function registerDefaults()
    for creatorType, definition in pairs(defaultCreators) do
        RegisterCreator({ creator_type = creatorType, label = definition.label, resource_name = definition.resource_name, metadata = { default = true } })
    end
    NexaBetaDatabase.UpsertRelease({ release_key = 'gp18-alpha', release_channel = NexaBetaConfig.releaseChannel, status = NexaBetaConfig.targetStage, version = NEXA_BETA.version, metadata = { requiredResources = NexaBetaConfig.requiredResources } })
end

local function registerCallbacks()
    registerCallback('nexa:beta:cb:getReadiness', function() return GetReadiness() end)
    registerCallback('nexa:beta:cb:collectHealth', function() return CollectHealth() end)
    registerCallback('nexa:beta:cb:listCreators', function() return ListCreators() end)
    registerCallback('nexa:beta:cb:setFeatureFlag', function(_, payload) payload = type(payload) == 'table' and payload or {}; return SetFeatureFlag(payload.flag_key, payload.enabled, payload.value) end)
    registerCallback('nexa:beta:cb:recordPerformanceSnapshot', function(_, payload) return RecordPerformanceSnapshot(payload) end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaBetaConfig.autoMigrate then migrated = NexaBetaDatabase.Migrate() == true end
    registerDefaults()
    registerCallbacks()
    print(('[nexa_beta] GP18 integration ready. migrated=%s'):format(tostring(migrated)))
end)

exports('RegisterCreator', RegisterCreator)
exports('ListCreators', ListCreators)
exports('SetFeatureFlag', SetFeatureFlag)
exports('GetReadiness', GetReadiness)
exports('CollectHealth', CollectHealth)
exports('RecordPerformanceSnapshot', RecordPerformanceSnapshot)
exports('GetReleaseMetadata', GetReleaseMetadata)
exports('getSchema', NexaBetaDatabase.GetSchema)
exports('getStatus', function() return { resourceName = NEXA_BETA.resourceName, version = NEXA_BETA.version, migrated = migrated } end)
