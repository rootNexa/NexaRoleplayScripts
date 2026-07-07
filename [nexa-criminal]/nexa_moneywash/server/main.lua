local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaMoneywashConfig.featureFlag)
end

local function getStatus()
    return {
        resourceName = NEXA_MONEYWASH.resourceName,
        version = NEXA_MONEYWASH.version,
        enabled = isEnabled(),
        illegalCore = GetResourceState('nexa_illegal_core') == 'started'
    }
end

local function wash(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Geldwaesche ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.moneywashWash'](source, payload, {
        stations = NexaMoneywashServer.stations
    })
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_MONEYWASH.resourceName, 'Geldwaesche gestartet.', {
        version = NEXA_MONEYWASH.version,
        featureFlag = NexaMoneywashConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('moneywash.wash', wash)
