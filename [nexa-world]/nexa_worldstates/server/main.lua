local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaWorldStatesConfig.featureFlag)
end

local function unavailable()
    return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'World States sind deaktiviert.', nil, nil, nil)
end

local function getStatus()
    return {
        resourceName = NEXA_WORLDSTATES.resourceName,
        version = NEXA_WORLDSTATES.version,
        enabled = isEnabled(),
        api = GetResourceState('nexa_api') == 'started'
    }
end

local function getState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    return exports.nexa_api['world.getState'](source, payload or {})
end

local function listStates(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    return exports.nexa_api['world.listStates'](source, payload or {})
end

local function setState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    return exports.nexa_api['world.setState'](source, payload or {})
end

local function clearState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    return exports.nexa_api['world.clearState'](source, payload or {})
end

local function getResourceStates(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    payload = payload or {}

    if payload.resources == nil then
        payload.resources = NexaWorldStatesServer.knownResources
    end

    return exports.nexa_api['world.getResourceStates'](source, payload)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_WORLDSTATES.resourceName, 'World States gestartet.', {
        version = NEXA_WORLDSTATES.version,
        featureFlag = NexaWorldStatesConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('worldstates.getState', getState)
exports('worldstates.listStates', listStates)
exports('worldstates.setState', setState)
exports('worldstates.clearState', clearState)
exports('worldstates.getResourceStates', getResourceStates)
