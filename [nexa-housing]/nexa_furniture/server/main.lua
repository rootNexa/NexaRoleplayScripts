AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaFurnitureConstants.resourceName, 'Furniture Resource gestartet.', {
            phase = '7D'
        })
    end
end)
