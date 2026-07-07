function NexaAuditValidateEntry(entry)
    if type(entry) ~= 'table' then
        return false, 'INVALID_ENTRY'
    end

    if type(entry.eventType) ~= 'string' or entry.eventType == '' then
        return false, 'INVALID_EVENT_TYPE'
    end

    if type(entry.action) ~= 'string' or entry.action == '' then
        return false, 'INVALID_ACTION'
    end

    if entry.severity ~= nil and not NexaAuditConfig.severities[entry.severity] then
        return false, 'INVALID_SEVERITY'
    end

    return true, 'OK'
end
