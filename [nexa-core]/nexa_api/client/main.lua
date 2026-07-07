function getClientStatus()
    return {
        resourceName = NEXA_API.resourceName,
        version = NEXA_API.version,
        clientApiEnabled = NexaApiClient.clientApiEnabled
    }
end

exports('getClientStatus', getClientStatus)
