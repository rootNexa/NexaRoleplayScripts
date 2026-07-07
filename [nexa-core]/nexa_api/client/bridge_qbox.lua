function getQboxClientBridgeStatus()
    return {
        active = GetResourceState('qbx_core') == 'started'
    }
end

exports('getQboxClientBridgeStatus', getQboxClientBridgeStatus)
