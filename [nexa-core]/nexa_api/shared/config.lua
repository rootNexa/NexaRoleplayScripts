NexaApiConfig = {
    debug = GetConvar('nexa_api:debug', 'false') == 'true',
    environment = GetConvar('nexa:environment', 'development'),
    commandsEnabled = true,
    callbackTimeoutMs = tonumber(GetConvar('nexa_api:callbackTimeoutMs', '5000')) or 5000
}

function NexaApiConfig.IsDevelopment()
    return NexaApiConfig.environment == 'development'
end
