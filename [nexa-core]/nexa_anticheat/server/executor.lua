local suspiciousExecutorReports = {}

local function executorResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Executor-/Injection-Detection konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isExecutorDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.executorDetectionFeatureFlag)
end

local function writeExecutorAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logExecutorWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function getNowMs()
    if GetGameTimer ~= nil then
        return GetGameTimer()
    end

    return math.floor(os.time() * 1000)
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.executorDetection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function appendSuspiciousExecutorReport(report)
    suspiciousExecutorReports[#suspiciousExecutorReports + 1] = report

    local maxReports = math.max(NexaAnticheatServer.executorDetection.reportLimit or 50, 50)

    while #suspiciousExecutorReports > maxReports do
        table.remove(suspiciousExecutorReports, 1)
    end
end

local function sanitizeString(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    return value:sub(1, maxLength or 128)
end

local function sanitizeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return {}
    end

    local sanitized = {}

    for key, value in pairs(metadata) do
        if type(key) == 'string' and #key <= 64 then
            local valueType = type(value)

            if valueType == 'string' then
                sanitized[key] = value:sub(1, 128)
            elseif valueType == 'number' or valueType == 'boolean' then
                sanitized[key] = value
            end
        end
    end

    return sanitized
end

local function validateSource(source)
    local valid, code, normalizedSource = NexaAnticheatValidateSource(source)

    if not valid then
        return false, code, nil
    end

    return true, 'OK', normalizedSource
end

local function containsPattern(value, patterns)
    if type(value) ~= 'string' then
        return nil
    end

    local lowered = value:lower()

    for _, pattern in ipairs(patterns or {}) do
        local normalizedPattern = tostring(pattern):lower()
        local ok, matched = pcall(function()
            return lowered:find(normalizedPattern) ~= nil
        end)

        if (ok and matched) or (not ok and lowered:find(normalizedPattern, 1, true) ~= nil) then
            return pattern
        end
    end

    return nil
end

local function countTableKeys(value)
    if type(value) ~= 'table' then
        return 0
    end

    local count = 0

    for _ in pairs(value) do
        count = count + 1
    end

    return count
end

local function inspectPayload(value, depth, result)
    result = result or {
        maxDepth = 0,
        keyCount = 0,
        functionValue = false,
        threadValue = false,
        userdataValue = false,
        longString = false,
        matchedPayloadPattern = nil,
        matchedExploitSignature = nil
    }

    local valueType = type(value)
    local config = NexaAnticheatServer.executorDetection

    result.maxDepth = math.max(result.maxDepth, depth)

    if valueType == 'string' then
        if #value > config.maxStringLength then
            result.longString = true
        end

        result.matchedPayloadPattern = result.matchedPayloadPattern or containsPattern(value, config.payloadPatterns)
        result.matchedExploitSignature = result.matchedExploitSignature or containsPattern(value, config.exploitSignatures)
        return result
    end

    if valueType == 'function' then
        result.functionValue = true
        return result
    end

    if valueType == 'thread' then
        result.threadValue = true
        return result
    end

    if valueType == 'userdata' then
        result.userdataValue = true
        return result
    end

    if valueType ~= 'table' then
        return result
    end

    result.keyCount = result.keyCount + countTableKeys(value)

    if depth >= config.maxPayloadDepth then
        return result
    end

    for key, nestedValue in pairs(value) do
        inspectPayload(key, depth + 1, result)
        inspectPayload(nestedValue, depth + 1, result)
    end

    return result
end

local function addSignal(finding, reason, weight, metadata)
    finding.score = finding.score + weight
    finding.reasons[#finding.reasons + 1] = reason
    finding.indicators[#finding.indicators + 1] = metadata or { reason = reason }
end

local function buildExecutorFinding(source, payload, capturedAt)
    local config = NexaAnticheatServer.executorDetection
    local eventName = sanitizeString(type(payload) == 'table' and payload.eventName, 160)
    local resourceName = sanitizeString(type(payload) == 'table' and payload.resourceName, 96)
    local signalName = sanitizeString(type(payload) == 'table' and payload.signalName, 96)
    local clientSignal = type(payload) == 'table' and payload.clientSignal == true
    local metadata = sanitizeMetadata(type(payload) == 'table' and payload.metadata or nil)
    local finding = {
        source = source,
        score = 0,
        suspicious = false,
        reasons = {},
        indicators = {},
        eventName = eventName,
        resourceName = resourceName,
        signalName = signalName,
        clientSignal = clientSignal,
        clientSignalTrusted = false,
        metadata = metadata,
        capturedAt = capturedAt
    }

    local eventPattern = containsPattern(eventName, config.eventPatterns)

    if eventPattern ~= nil then
        addSignal(finding, 'suspicious_event_pattern', config.eventPatternWeight, {
            eventName = eventName,
            pattern = eventPattern
        })
    end

    local resourcePattern = containsPattern(resourceName, config.resourcePatterns)

    if resourcePattern ~= nil then
        addSignal(finding, 'suspicious_resource_pattern', config.resourcePatternWeight, {
            resourceName = resourceName,
            pattern = resourcePattern
        })
    end

    local payloadInspection = inspectPayload(type(payload) == 'table' and payload.payload or payload, 0)
    finding.payloadInspection = payloadInspection

    if payloadInspection.keyCount > config.maxPayloadKeys or payloadInspection.maxDepth > config.maxPayloadDepth then
        addSignal(finding, 'unusual_payload_structure', config.payloadPatternWeight, {
            keyCount = payloadInspection.keyCount,
            maxDepth = payloadInspection.maxDepth
        })
    end

    if payloadInspection.functionValue or payloadInspection.threadValue or payloadInspection.userdataValue then
        addSignal(finding, 'unsafe_payload_type', config.payloadPatternWeight, {
            functionValue = payloadInspection.functionValue,
            threadValue = payloadInspection.threadValue,
            userdataValue = payloadInspection.userdataValue
        })
    end

    if payloadInspection.longString then
        addSignal(finding, 'unusual_payload_string_length', config.payloadPatternWeight, {
            maxStringLength = config.maxStringLength
        })
    end

    if payloadInspection.matchedPayloadPattern ~= nil then
        addSignal(finding, 'suspicious_payload_pattern', config.payloadPatternWeight, {
            pattern = payloadInspection.matchedPayloadPattern
        })
    end

    local exploitSignature = payloadInspection.matchedExploitSignature
        or containsPattern(eventName, config.exploitSignatures)
        or containsPattern(resourceName, config.exploitSignatures)
        or containsPattern(signalName, config.exploitSignatures)

    if exploitSignature ~= nil then
        addSignal(finding, 'known_exploit_signature', config.exploitSignatureWeight, {
            signature = exploitSignature
        })
    end

    if clientSignal then
        addSignal(finding, 'untrusted_client_tamper_indicator', config.clientSignalWeight, {
            untrusted = true,
            signalName = signalName
        })
    end

    finding.suspicious = finding.score >= config.suspicionThreshold

    return finding
end

function validateExecutorSignal(source, payload)
    if not isExecutorDetectionEnabled() then
        return executorResponse(false, 'FEATURE_DISABLED', 'Executor Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return executorResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.executor.validateSignal')

    if not limited then
        return executorResponse(false, limitCode, 'Executor Detection wurde rate-limited.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return executorResponse(false, 'INVALID_INPUT', 'Ungueltiges Executor-Detection-Signal.', nil, nil, nil)
    end

    local invokingResource = GetInvokingResource() or NEXA_ANTICHEAT.resourceName
    local trustedResource = NexaAnticheatServer.executorDetection.trustedSignalResources[invokingResource] == true
    local capturedAt = getNowMs()
    local finding = buildExecutorFinding(normalizedSource, payload, capturedAt)
    finding.invokingResource = invokingResource
    finding.trustedSignalResource = trustedResource

    if not trustedResource and finding.clientSignal == true then
        finding.reasons[#finding.reasons + 1] = 'client_signal_untrusted'
    end

    if finding.suspicious then
        local auditId = writeExecutorAudit('executor.suspicious_signal', 'warning', finding)
        finding.auditId = auditId
        appendSuspiciousExecutorReport(finding)

        logExecutorWarning('Executor Detection hat verdaechtiges Signal markiert.', {
            source = normalizedSource,
            auditId = auditId,
            score = finding.score,
            eventName = finding.eventName,
            resourceName = finding.resourceName
        })

        return executorResponse(true, 'SUSPICIOUS_EXECUTOR', 'Verdaechtiges Executor-/Injection-Signal wurde auditierbar markiert.', finding, {
            suspicious = true,
            automaticSanction = false,
            clientSignalTrusted = false
        }, auditId)
    end

    return executorResponse(true, 'OK', 'Executor Detection wurde abgeschlossen.', finding, {
        suspicious = false,
        automaticSanction = false,
        clientSignalTrusted = false
    }, nil)
end

function getSuspiciousExecutorReports(limit)
    local requestedLimit = normalizeLimit(limit)
    local result = {}
    local startIndex = math.max(1, #suspiciousExecutorReports - requestedLimit + 1)

    for index = startIndex, #suspiciousExecutorReports do
        result[#result + 1] = suspiciousExecutorReports[index]
    end

    return executorResponse(true, 'OK', 'Suspicious executor reports wurden gelesen.', result, {
        count = #result
    }, nil)
end

exports('validateExecutorSignal', validateExecutorSignal)
exports('getSuspiciousExecutorReports', getSuspiciousExecutorReports)
