local auditEntries = {}

local function appendEntry(entry)
    auditEntries[#auditEntries + 1] = entry

    if #auditEntries > NexaAuditServer.bufferLimit then
        table.remove(auditEntries, 1)
    end
end

function createAuditEntry(entry)
    local valid, code = NexaAuditValidateEntry(entry)

    if not valid then
        return {
            success = false,
            code = code,
            message = 'Audit-Eintrag ist ungueltig.',
            data = nil,
            meta = nil,
            audit_id = nil
        }
    end

    local auditId = ('audit:%s:%d'):format(os.time(), #auditEntries + 1)
    local normalizedEntry = {
        auditId = auditId,
        eventType = entry.eventType,
        severity = entry.severity or 'info',
        actorPlayerId = entry.actorPlayerId,
        actorCharacterId = entry.actorCharacterId,
        targetType = entry.targetType,
        targetId = entry.targetId,
        resourceName = entry.resourceName or GetInvokingResource() or NEXA_AUDIT.resourceName,
        action = entry.action,
        metadata = entry.metadata or {},
        createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    appendEntry(normalizedEntry)

    return {
        success = true,
        code = 'OK',
        message = 'Audit-Eintrag wurde erfasst.',
        data = normalizedEntry,
        meta = nil,
        audit_id = auditId
    }
end

function getRecentAuditEntries(limit)
    local requestedLimit = tonumber(limit) or 50
    local result = {}
    local startIndex = math.max(1, #auditEntries - requestedLimit + 1)

    for index = startIndex, #auditEntries do
        result[#result + 1] = auditEntries[index]
    end

    return result
end
