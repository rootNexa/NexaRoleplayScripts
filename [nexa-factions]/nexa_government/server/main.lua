local function getStatus()
    return {
        resourceName = NEXA_GOVERNMENT.resourceName,
        version = NEXA_GOVERNMENT.version,
        api = GetResourceState('nexa_api') == 'started',
        factionsCore = GetResourceState('nexa_factions_core') == 'started',
        documents = GetResourceState('nexa_documents') == 'started',
        licenses = GetResourceState('nexa_licenses') == 'started',
        enabled = GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaGovernmentConfig.featureFlag)
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_GOVERNMENT.resourceName, 'Government-Resource gestartet.', {
        version = NEXA_GOVERNMENT.version,
        featureFlag = NexaGovernmentConfig.featureFlag,
        factionName = NexaGovernmentConfig.factionName
    })
end)

exports('getStatus', getStatus)
