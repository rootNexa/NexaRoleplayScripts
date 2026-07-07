local function getStatus()
    return {
        resourceName = NEXA_EMS.resourceName,
        version = NEXA_EMS.version,
        api = GetResourceState('nexa_api') == 'started',
        factionsCore = GetResourceState('nexa_factions_core') == 'started',
        enabled = GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaEmsConfig.featureFlag)
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_EMS.resourceName, 'EMS-Resource gestartet.', {
        version = NEXA_EMS.version,
        featureFlag = NexaEmsConfig.featureFlag,
        factionName = NexaEmsConfig.factionName
    })
end)

exports('getStatus', getStatus)
