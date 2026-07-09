AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    print(('[nexa_api] client ready version %s'):format(NexaApiClient.Version))
end)
