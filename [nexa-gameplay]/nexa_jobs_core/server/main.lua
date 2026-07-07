local function getStatus()
    return {
        resourceName = NEXA_JOBS.resourceName,
        version = NEXA_JOBS.version,
        api = GetResourceState('nexa_api') == 'started'
    }
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_JOBS.resourceName, 'Jobs-Core gestartet.', {
        version = NEXA_JOBS.version
    })
end)

exports('getStatus', getStatus)
