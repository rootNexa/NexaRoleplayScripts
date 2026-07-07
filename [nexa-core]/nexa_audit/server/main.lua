function write(entry)
    return createAuditEntry(entry)
end

function writeAdmin(entry)
    entry = entry or {}
    entry.eventType = entry.eventType or 'admin'
    entry.severity = entry.severity or 'warning'

    return createAuditEntry(entry)
end

function writeSecurity(entry)
    entry = entry or {}
    entry.eventType = entry.eventType or 'security'
    entry.severity = entry.severity or 'warning'

    return createAuditEntry(entry)
end

function linkLedger(entry)
    entry = entry or {}
    entry.eventType = entry.eventType or 'ledger'
    entry.action = entry.action or 'ledger.link'

    return createAuditEntry(entry)
end

function recent(limit)
    return getRecentAuditEntries(limit)
end

AddEventHandler('nexa:audit:internal:write', function(entry)
    createAuditEntry(entry)
end)

exports('write', write)
exports('writeAdmin', writeAdmin)
exports('writeSecurity', writeSecurity)
exports('linkLedger', linkLedger)
exports('recent', recent)
