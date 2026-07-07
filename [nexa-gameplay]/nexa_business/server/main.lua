local function getStatus()
    return {
        resourceName = NEXA_BUSINESS.resourceName,
        version = NEXA_BUSINESS.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_BUSINESS.resourceName, 'Businessresource gestartet.', {
        version = NEXA_BUSINESS.version
    })
end)

exports('getStatus', getStatus)
