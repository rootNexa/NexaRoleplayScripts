local function getStatus()
    return {
        resourceName = NEXA_DISPATCH.resourceName,
        version = NEXA_DISPATCH.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_DISPATCH.resourceName, 'Dispatchresource gestartet.', {
        version = NEXA_DISPATCH.version
    })
end)

exports('getStatus', getStatus)
