local function getStatus()
    return {
        resourceName = NEXA_LSPD.resourceName,
        version = NEXA_LSPD.version,
        api = GetResourceState('nexa_api') == 'started',
        factionsCore = GetResourceState('nexa_factions_core') == 'started',
        mdt = GetResourceState('nexa_mdt') == 'started',
        enabled = GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaLspdConfig.featureFlag)
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_LSPD.resourceName, 'LSPD-Resource gestartet.', {
        version = NEXA_LSPD.version,
        featureFlag = NexaLspdConfig.featureFlag,
        factionName = NexaLspdConfig.factionName
    })
end)

exports('getStatus', getStatus)
