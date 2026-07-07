local evidenceCaptureRequests = {}

local function evidenceResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Evidence-Capture-Anfrage konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isEvidenceCaptureEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.evidenceCaptureFeatureFlag)
end

local function writeEvidenceAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logEvidenceWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function logEvidenceInfo(message, metadata)
    exports.nexa_logs:info(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function getNowMs()
    if GetGameTimer ~= nil then
        return GetGameTimer()
    end

    return math.floor(os.time() * 1000)
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.evidenceCapture.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function appendEvidenceCaptureRequest(request)
    evidenceCaptureRequests[#evidenceCaptureRequests + 1] = request

    local maxReports = math.max(NexaAnticheatServer.evidenceCapture.reportLimit or 50, 50)

    while #evidenceCaptureRequests > maxReports do
        table.remove(evidenceCaptureRequests, 1)
    end
end

local function validateSource(source)
    local valid, code, normalizedSource = NexaAnticheatValidateSource(source)

    if not valid then
        return false, code, nil
    end

    return true, 'OK', normalizedSource
end

local function sanitizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local sanitized = value:gsub('[%c]', ' '):sub(1, maxLength or 128)

    if sanitized == '' then
        return nil
    end

    return sanitized
end

local function sanitizeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return {}
    end

    local config = NexaAnticheatServer.evidenceCapture
    local sanitized = {}
    local count = 0

    for key, value in pairs(metadata) do
        if count >= config.maxMetadataKeys then
            break
        end

        if type(key) == 'string' and #key <= 64 then
            local valueType = type(value)

            if valueType == 'string' then
                sanitized[key] = sanitizeText(value, config.maxMetadataStringLength)
                count = count + 1
            elseif valueType == 'number' or valueType == 'boolean' then
                sanitized[key] = value
                count = count + 1
            end
        end
    end

    return sanitized
end

local function hasAnyPermission(source, permissions)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    for permission, enabled in pairs(permissions or {}) do
        if enabled == true then
            local ok, allowed = pcall(function()
                return exports.nexa_permissions:has(source, permission)
            end)

            if ok and allowed == true then
                return true, permission
            end
        end
    end

    return false, nil
end

local function normalizeReason(reason)
    local sanitized = sanitizeText(reason, NexaAnticheatServer.evidenceCapture.maxReasonLength)

    if sanitized == nil then
        return nil
    end

    local key = sanitized:lower():gsub('%s+', '_')

    if NexaAnticheatServer.evidenceCapture.allowedReasons[key] == true then
        return key
    end

    return sanitized
end

local function buildRequestId(actorSource, targetSource, capturedAt)
    return ('ev-%s-%s-%s'):format(tostring(actorSource), tostring(targetSource), tostring(capturedAt))
end

local function buildEvidenceRequest(actorSource, targetSource, requestType, reason, metadata, capturedAt)
    local config = NexaAnticheatServer.evidenceCapture

    return {
        requestId = buildRequestId(actorSource, targetSource, capturedAt),
        requestType = requestType,
        actorSource = actorSource,
        targetSource = targetSource,
        reason = reason,
        metadata = sanitizeMetadata(metadata),
        status = 'prepared',
        captureDispatched = false,
        externalUploadEnabled = config.externalUploadEnabled == true,
        externalUploadProvider = config.externalUploadProvider,
        transparencyNotice = config.transparencyNotice,
        retentionHint = config.retentionHint,
        automaticSanction = false,
        createdAt = capturedAt,
        expiresAt = capturedAt + ((config.requestTtlSeconds or 300) * 1000)
    }
end

function requestEvidenceCapture(actorSource, targetSource, payload)
    if not isEvidenceCaptureEnabled() then
        return evidenceResponse(false, 'FEATURE_DISABLED', 'Evidence Capture ist deaktiviert.', nil, nil, nil)
    end

    local actorValid, actorCode, normalizedActor = validateSource(actorSource)

    if not actorValid then
        return evidenceResponse(false, actorCode, 'Ungueltige Admin-Source.', nil, nil, nil)
    end

    local targetValid, targetCode, normalizedTarget = validateSource(targetSource)

    if not targetValid then
        return evidenceResponse(false, targetCode, 'Ungueltige Ziel-Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedActor, 'anticheat.evidence.request')

    if not limited then
        return evidenceResponse(false, limitCode, 'Evidence Capture wurde rate-limited.', nil, nil, nil)
    end

    local allowed, permission = hasAnyPermission(normalizedActor, NexaAnticheatServer.evidenceCapture.manualPermissions)

    if not allowed then
        local auditId = writeEvidenceAudit('evidence.capture.denied', 'warning', {
            actorSource = normalizedActor,
            targetSource = normalizedTarget,
            reason = 'NO_PERMISSION'
        })

        logEvidenceWarning('Evidence Capture wurde ohne Permission angefordert.', {
            actorSource = normalizedActor,
            targetSource = normalizedTarget,
            auditId = auditId
        })

        return evidenceResponse(false, 'NO_PERMISSION', 'Evidence Capture wurde mangels Permission verweigert.', nil, {
            automaticSanction = false
        }, auditId)
    end

    local reason = normalizeReason(type(payload) == 'table' and payload.reason or nil)

    if reason == nil then
        return evidenceResponse(false, 'INVALID_INPUT', 'Evidence Capture benoetigt einen nachvollziehbaren Grund.', nil, nil, nil)
    end

    local capturedAt = getNowMs()
    local request = buildEvidenceRequest(normalizedActor, normalizedTarget, 'manual_admin_request', reason, type(payload) == 'table' and payload.metadata or nil, capturedAt)
    request.permission = permission
    request.invokingResource = GetInvokingResource() or NEXA_ANTICHEAT.resourceName

    appendEvidenceCaptureRequest(request)

    local auditId = writeEvidenceAudit('evidence.capture.requested', 'info', request)
    request.auditId = auditId

    logEvidenceInfo('Evidence Capture wurde manuell vorbereitet.', {
        actorSource = normalizedActor,
        targetSource = normalizedTarget,
        requestId = request.requestId,
        auditId = auditId
    })

    return evidenceResponse(true, 'OK', 'Evidence Capture wurde permission-geprueft und auditierbar vorbereitet.', request, {
        captureDispatched = false,
        manualRequest = true,
        automaticSanction = false
    }, auditId)
end

function prepareAnticheatEvidenceCapture(targetSource, payload)
    if not isEvidenceCaptureEnabled() then
        return evidenceResponse(false, 'FEATURE_DISABLED', 'Evidence Capture ist deaktiviert.', nil, nil, nil)
    end

    local targetValid, targetCode, normalizedTarget = validateSource(targetSource)

    if not targetValid then
        return evidenceResponse(false, targetCode, 'Ungueltige Ziel-Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedTarget, 'anticheat.evidence.prepare')

    if not limited then
        return evidenceResponse(false, limitCode, 'Evidence Capture Vorbereitung wurde rate-limited.', nil, nil, nil)
    end

    local invokingResource = GetInvokingResource() or NEXA_ANTICHEAT.resourceName

    if NexaAnticheatServer.evidenceCapture.anticheatTrustedResources[invokingResource] ~= true then
        local auditId = writeEvidenceAudit('evidence.capture.prepare_denied', 'warning', {
            targetSource = normalizedTarget,
            invokingResource = invokingResource,
            reason = 'RESOURCE_NOT_ALLOWED'
        })

        logEvidenceWarning('Anticheat-Evidence-Capture Vorbereitung wurde wegen Resource verweigert.', {
            targetSource = normalizedTarget,
            invokingResource = invokingResource,
            auditId = auditId
        })

        return evidenceResponse(false, 'RESOURCE_NOT_ALLOWED', 'Anticheat-Evidence-Capture darf nur durch vertrauenswuerdige Serverressourcen vorbereitet werden.', nil, {
            automaticSanction = false
        }, auditId)
    end

    local reason = normalizeReason(type(payload) == 'table' and payload.reason or 'anticheat_followup')

    if reason == nil then
        reason = 'anticheat_followup'
    end

    local capturedAt = getNowMs()
    local request = buildEvidenceRequest(0, normalizedTarget, 'anticheat_prepared_interface', reason, type(payload) == 'table' and payload.metadata or nil, capturedAt)
    request.invokingResource = invokingResource
    request.anticheatOnlyPrepared = true

    appendEvidenceCaptureRequest(request)

    local auditId = writeEvidenceAudit('evidence.capture.anticheat_prepared', 'info', request)
    request.auditId = auditId

    logEvidenceInfo('Anticheat-Evidence-Capture wurde vorbereitet.', {
        targetSource = normalizedTarget,
        requestId = request.requestId,
        invokingResource = invokingResource,
        auditId = auditId
    })

    return evidenceResponse(true, 'OK', 'Anticheat-Evidence-Capture wurde nur als Schnittstelle vorbereitet.', request, {
        captureDispatched = false,
        anticheatPreparedOnly = true,
        automaticSanction = false
    }, auditId)
end

function getEvidenceCaptureRequests(limit)
    local requestedLimit = normalizeLimit(limit)
    local result = {}
    local startIndex = math.max(1, #evidenceCaptureRequests - requestedLimit + 1)

    for index = startIndex, #evidenceCaptureRequests do
        result[#result + 1] = evidenceCaptureRequests[index]
    end

    return evidenceResponse(true, 'OK', 'Evidence-Capture-Requests wurden gelesen.', result, {
        count = #result
    }, nil)
end

exports('requestEvidenceCapture', requestEvidenceCapture)
exports('prepareAnticheatEvidenceCapture', prepareAnticheatEvidenceCapture)
exports('getEvidenceCaptureRequests', getEvidenceCaptureRequests)
