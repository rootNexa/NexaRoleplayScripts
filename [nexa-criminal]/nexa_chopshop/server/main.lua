local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaChopshopConfig.featureFlag)
end

local function getStatus()
    return {
        resourceName = NEXA_CHOPSHOP.resourceName,
        version = NEXA_CHOPSHOP.version,
        enabled = isEnabled(),
        illegalCore = GetResourceState('nexa_illegal_core') == 'started'
    }
end

local function buildConfigPayload()
    return {
        yards = NexaChopshopServer.yards,
        buyers = NexaChopshopServer.buyers
    }
end

local function dismantle(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Chopshop ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.chopshopDismantle'](source, payload, buildConfigPayload())
end

local function sell(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Chopshop ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.chopshopSell'](source, payload, buildConfigPayload())
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_CHOPSHOP.resourceName, 'Chopshop gestartet.', {
        version = NEXA_CHOPSHOP.version,
        featureFlag = NexaChopshopConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('chopshop.dismantle', dismantle)
exports('chopshop.sell', sell)
