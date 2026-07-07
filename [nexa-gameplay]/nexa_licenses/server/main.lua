local function getStatus()
    return {
        resourceName = NEXA_LICENSES.resourceName,
        version = NEXA_LICENSES.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_LICENSES.resourceName, 'Lizenzresource gestartet.', {
        version = NEXA_LICENSES.version
    })
end)

exports('getStatus', getStatus)
