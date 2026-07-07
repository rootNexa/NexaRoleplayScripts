local function getStatus()
    return {
        resourceName = NEXA_DOCUMENTS.resourceName,
        version = NEXA_DOCUMENTS.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_DOCUMENTS.resourceName, 'Dokumentenresource gestartet.', {
        version = NEXA_DOCUMENTS.version
    })
end)

exports('getStatus', getStatus)
