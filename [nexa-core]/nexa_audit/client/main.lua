function isClientAccessAllowed()
    return NexaAuditClient.clientAccess
end

exports('isClientAccessAllowed', isClientAccessAllowed)
