local reports = {}

function validateSource(source)
    local sourceNumber = tonumber(source)

    if sourceNumber == nil or sourceNumber <= 0 then
        return false, 'INVALID_SOURCE'
    end

    return true, 'OK'
end

function checkRateLimit(source, eventName)
    local allowed, code = checkRateLimitInternal(source, eventName)

    return {
        success = allowed,
        code = code,
        message = allowed and 'Anfrage erlaubt.' or 'Anfrage wurde begrenzt.',
        data = {
            source = source,
            eventName = eventName
        },
        meta = nil,
        audit_id = nil
    }
end

function reject(source, eventName, reason, severity)
    local normalizedSeverity = severity or 'medium'

    if not NexaSecurityConfig.severities[normalizedSeverity] then
        normalizedSeverity = 'medium'
    end

    local reportEntry = {
        source = source,
        eventName = eventName,
        reason = reason or 'SECURITY_REJECTED',
        severity = normalizedSeverity,
        createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    reports[#reports + 1] = reportEntry

    local auditResult = exports.nexa_audit:writeSecurity({
        action = 'security.reject',
        eventType = 'security',
        severity = normalizedSeverity == 'critical' and 'critical' or 'warning',
        resourceName = NEXA_SECURITY.resourceName,
        metadata = reportEntry
    })

    TriggerEvent('nexa:security:internal:securityRejected', reportEntry)

    return {
        success = true,
        code = 'SECURITY_REJECTED',
        message = 'Sicherheitsereignis wurde erfasst.',
        data = reportEntry,
        meta = nil,
        audit_id = auditResult.audit_id
    }
end

function report(entry)
    entry = entry or {}
    return reject(entry.source, entry.eventName, entry.reason, entry.severity)
end

function isBanned(source)
    local valid = validateSource(source)

    if not valid then
        return false
    end

    return false
end

function recent(limit)
    local requestedLimit = tonumber(limit) or 50
    local result = {}
    local startIndex = math.max(1, #reports - requestedLimit + 1)

    for index = startIndex, #reports do
        result[#result + 1] = reports[index]
    end

    return result
end

AddEventHandler('nexa:security:internal:rateLimitExceeded', function(entry)
    exports.nexa_logs:warn(NEXA_SECURITY.resourceName, 'Rate-Limit wurde erreicht.', entry)
end)

exports('validateSource', validateSource)
exports('checkRateLimit', checkRateLimit)
exports('reject', reject)
exports('report', report)
exports('isBanned', isBanned)
exports('recent', recent)
