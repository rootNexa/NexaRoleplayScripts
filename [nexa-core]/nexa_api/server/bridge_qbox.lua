function getQboxBridgeStatus()
    return {
        active = GetResourceState('qbx_core') == 'started',
        resource = 'qbx_core'
    }
end

exports('getQboxBridgeStatus', getQboxBridgeStatus)
