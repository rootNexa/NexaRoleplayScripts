function writeAudit(entry)
    return exports.nexa_audit:write(entry)
end

exports('writeAudit', writeAudit)
exports('audit.write', writeAudit)
