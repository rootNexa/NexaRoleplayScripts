local function getStatus()
    return {
        resourceName = NEXA_FACTIONS.resourceName,
        version = NEXA_FACTIONS.version,
        api = GetResourceState('nexa_api') == 'started',
        enabled = GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaFactionsConfig.featureFlag)
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_FACTIONS.resourceName, 'Fraktions-Core gestartet.', {
        version = NEXA_FACTIONS.version,
        featureFlag = NexaFactionsConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
