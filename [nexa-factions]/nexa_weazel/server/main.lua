local function getStatus()
    return {
        resourceName = NEXA_WEAZEL.resourceName,
        version = NEXA_WEAZEL.version,
        api = GetResourceState('nexa_api') == 'started',
        factionsCore = GetResourceState('nexa_factions_core') == 'started',
        documents = GetResourceState('nexa_documents') == 'started',
        enabled = GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaWeazelConfig.featureFlag)
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_WEAZEL.resourceName, 'Weazel-Resource gestartet.', {
        version = NEXA_WEAZEL.version,
        featureFlag = NexaWeazelConfig.featureFlag,
        factionName = NexaWeazelConfig.factionName
    })
end)

exports('getStatus', getStatus)
