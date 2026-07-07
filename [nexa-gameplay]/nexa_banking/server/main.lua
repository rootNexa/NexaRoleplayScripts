local function getStatus()
    return {
        resourceName = NEXA_BANKING.resourceName,
        version = NEXA_BANKING.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_BANKING.resourceName, 'Bankingresource gestartet.', {
        version = NEXA_BANKING.version
    })
end)

exports('getStatus', getStatus)
