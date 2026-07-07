function getClientStatus()
    return {
        resourceName = NEXA_BOOTSTRAP.resourceName,
        version = NEXA_BOOTSTRAP.version,
        exposeClientStatus = NexaBootstrapClient.exposeClientStatus
    }
end

exports('getClientStatus', getClientStatus)
