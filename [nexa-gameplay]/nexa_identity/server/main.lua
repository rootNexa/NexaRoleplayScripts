local function getStatus()
    return {
        resourceName = NEXA_IDENTITY.resourceName,
        version = NEXA_IDENTITY.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_IDENTITY.resourceName, 'Identitaetsresource gestartet.', {
        version = NEXA_IDENTITY.version
    })
end)

exports('getStatus', getStatus)
