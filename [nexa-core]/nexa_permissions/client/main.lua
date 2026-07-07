function isClientCacheAllowed()
    return NexaPermissionsClient.clientCacheAllowed
end

exports('isClientCacheAllowed', isClientCacheAllowed)
