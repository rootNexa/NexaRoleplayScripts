local auditEntries = {}

local function response(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Anticheat-Core-Anfrage konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.featureFlag)
end

local function isEventProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.eventProtectionFeatureFlag)
end

local function isInventoryProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.inventoryProtectionFeatureFlag)
end

local function isVehicleProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.vehicleProtectionFeatureFlag)
end

local function isTeleportDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.teleportDetectionFeatureFlag)
end

local function isNoclipDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.noclipDetectionFeatureFlag)
end

local function isGodmodeDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.godmodeDetectionFeatureFlag)
end

local function isExecutorDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.executorDetectionFeatureFlag)
end

local function isEvidenceCaptureEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.evidenceCaptureFeatureFlag)
end

local function isBanSystemEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.banSystemFeatureFlag)
end

local function appendAudit(entry)
    auditEntries[#auditEntries + 1] = entry

    if #auditEntries > NexaAnticheatServer.auditBufferLimit then
        table.remove(auditEntries, 1)
    end
end

local function writeAudit(action, severity, metadata)
    local entry = {
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    }

    local result = exports.nexa_audit:writeSecurity(entry)
    entry.auditId = result.audit_id
    entry.createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    appendAudit(entry)

    return result.audit_id
end

local function logReject(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata)
end

local function reject(source, eventName, code, metadata)
    local auditId = writeAudit('anticheat.reject', 'warning', {
        source = source,
        eventName = eventName,
        code = code,
        metadata = metadata or {}
    })

    logReject('Anticheat-Core hat eine Anfrage abgelehnt.', {
        source = source,
        eventName = eventName,
        code = code
    })

    return response(false, code, 'Anticheat-Validierung fehlgeschlagen.', nil, nil, auditId)
end

function registerSecureEvent(eventName, options)
    local valid, code, registered = NexaAnticheatRegisterSecureEvent(eventName, options)

    if not valid then
        return response(false, code, 'Secure Event konnte nicht registriert werden.', nil, nil, nil)
    end

    exports.nexa_logs:info(NEXA_ANTICHEAT.resourceName, 'Secure Event wurde registriert.', {
        eventName = registered.eventName,
        registeredBy = registered.registeredBy
    })

    return response(true, 'OK', 'Secure Event wurde registriert.', registered, nil, nil)
end

function validateEvent(source, eventName, payload, token)
    if not isEnabled() then
        return reject(source, eventName, 'FEATURE_DISABLED')
    end

    if not isEventProtectionEnabled() then
        return reject(source, eventName, 'EVENT_PROTECTION_DISABLED')
    end

    local sourceValid, sourceCode, normalizedSource = NexaAnticheatValidateSource(source)

    if not sourceValid then
        return reject(source, eventName, sourceCode)
    end

    local eventValid, eventCode, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return reject(normalizedSource, eventName, eventCode)
    end

    if NexaAnticheatIsDeniedEvent(normalizedEventName) then
        return reject(normalizedSource, normalizedEventName, 'EVENT_DENIED')
    end

    if not NexaAnticheatIsAllowedEvent(normalizedEventName) then
        return reject(normalizedSource, normalizedEventName, 'EVENT_NOT_ALLOWED')
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.validateEvent')

    if not limited then
        return reject(normalizedSource, normalizedEventName, limitCode)
    end

    local sessionValid, sessionCode = NexaAnticheatValidateSession(normalizedSource)

    if not sessionValid then
        return reject(normalizedSource, normalizedEventName, sessionCode)
    end

    local registered = NexaAnticheatGetSecureEvent(normalizedEventName)

    if registered == nil then
        return reject(normalizedSource, normalizedEventName, 'EVENT_NOT_REGISTERED')
    end

    local resourceValid, resourceCode, resourceName = NexaAnticheatValidateCallingResource(registered)

    if not resourceValid then
        return reject(normalizedSource, normalizedEventName, resourceCode)
    end

    local payloadValid, payloadCode = NexaAnticheatValidatePayloadShape(payload)

    if not payloadValid then
        return reject(normalizedSource, normalizedEventName, payloadCode)
    end

    local payloadSizeValid, payloadSizeCode = NexaAnticheatValidatePayloadSize(payload)

    if not payloadSizeValid then
        return reject(normalizedSource, normalizedEventName, payloadSizeCode)
    end

    local payloadTypesValid, payloadTypesCode = NexaAnticheatValidatePayloadTypes(payload)

    if not payloadTypesValid then
        return reject(normalizedSource, normalizedEventName, payloadTypesCode)
    end

    local schemaValid, schemaCode = NexaAnticheatValidateSchema(payload, registered.payload)

    if not schemaValid then
        return reject(normalizedSource, normalizedEventName, schemaCode)
    end

    if registered.requireToken then
        local tokenValid, tokenCode = NexaAnticheatValidateToken(normalizedSource, normalizedEventName, token, registered.consumeToken)

        if not tokenValid then
            return reject(normalizedSource, normalizedEventName, tokenCode)
        end
    end

    if registered.requireReplayProtection then
        local replayValid, replayCode = NexaAnticheatValidateReplay(normalizedSource, normalizedEventName, payload)

        if not replayValid then
            return reject(normalizedSource, normalizedEventName, replayCode)
        end
    end

    local auditId = writeAudit('anticheat.validate', 'info', {
        source = normalizedSource,
        eventName = normalizedEventName,
        critical = registered.critical,
        resourceName = resourceName
    })

    NexaAnticheatEmitSecureInternalEvent('nexa:anticheat:internal:validated', {
        source = normalizedSource,
        eventName = normalizedEventName,
        resourceName = resourceName,
        auditId = auditId
    })

    return response(true, 'OK', 'Anticheat-Event wurde serverseitig validiert.', {
        source = normalizedSource,
        eventName = normalizedEventName,
        critical = registered.critical,
        resourceName = resourceName
    }, nil, auditId)
end

function issueToken(source, eventName, metadata)
    local limited, limitCode = NexaAnticheatCheckRateLimit(source, 'anticheat.issueToken')

    if not limited then
        return reject(source, eventName, limitCode)
    end

    local eventValid, eventCode, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return reject(source, eventName, eventCode)
    end

    if NexaAnticheatIsDeniedEvent(normalizedEventName) then
        return reject(source, normalizedEventName, 'EVENT_DENIED')
    end

    if not NexaAnticheatIsAllowedEvent(normalizedEventName) then
        return reject(source, normalizedEventName, 'EVENT_NOT_ALLOWED')
    end

    if NexaAnticheatGetSecureEvent(normalizedEventName) == nil then
        return reject(source, normalizedEventName, 'EVENT_NOT_REGISTERED')
    end

    local valid, code, tokenData = NexaAnticheatIssueToken(source, normalizedEventName, metadata)

    if not valid then
        return reject(source, normalizedEventName, code)
    end

    local auditId = writeAudit('anticheat.token.issue', 'info', {
        source = source,
        eventName = normalizedEventName,
        expiresAt = tokenData.expiresAt
    })

    return response(true, 'OK', 'Anticheat-Token wurde ausgestellt.', tokenData, nil, auditId)
end

function validateToken(source, eventName, token)
    local limited, limitCode = NexaAnticheatCheckRateLimit(source, 'anticheat.verifyToken')

    if not limited then
        return reject(source, eventName, limitCode)
    end

    local valid, code = NexaAnticheatValidateToken(source, eventName, token, false)

    if not valid then
        return reject(source, eventName, code)
    end

    return response(true, 'OK', 'Anticheat-Token ist gueltig.', {
        source = source,
        eventName = eventName
    }, nil, nil)
end

function verifyEventToken(source, eventName, token)
    return validateToken(source, eventName, token)
end

function listSecureEvents()
    return NexaAnticheatListSecureEvents()
end

function validateSession(source)
    local valid, code, session = NexaAnticheatValidateSession(source)

    if not valid then
        return reject(source, 'anticheat.session', code)
    end

    return response(true, 'OK', 'Session wurde serverseitig validiert.', session, nil, nil)
end

function validateResourceIntegrity(resourceName)
    local valid, code, result = NexaAnticheatValidateResourceIntegrity(resourceName)

    if not valid then
        return reject(0, 'anticheat.resourceIntegrity', code, result)
    end

    return response(true, 'OK', 'Resource-Integrity wurde validiert.', result, nil, nil)
end

function getAuditRecent(limit)
    local requestedLimit = tonumber(limit) or 50
    local result = {}
    local startIndex = math.max(1, #auditEntries - requestedLimit + 1)

    for index = startIndex, #auditEntries do
        result[#result + 1] = auditEntries[index]
    end

    return result
end

function getStatus()
    return {
        resourceName = NEXA_ANTICHEAT.resourceName,
        version = NEXA_ANTICHEAT.version,
        phase = NEXA_ANTICHEAT.phase,
        enabled = isEnabled(),
        eventProtectionEnabled = isEventProtectionEnabled(),
        inventoryProtectionEnabled = isInventoryProtectionEnabled(),
        vehicleProtectionEnabled = isVehicleProtectionEnabled(),
        teleportDetectionEnabled = isTeleportDetectionEnabled(),
        noclipDetectionEnabled = isNoclipDetectionEnabled(),
        godmodeDetectionEnabled = isGodmodeDetectionEnabled(),
        executorDetectionEnabled = isExecutorDetectionEnabled(),
        evidenceCaptureEnabled = isEvidenceCaptureEnabled(),
        banSystemEnabled = isBanSystemEnabled(),
        secureEvents = NexaAnticheatListSecureEvents()
    }
end

AddEventHandler('nexa:anticheat:internal:violation', function(entry)
    if not NexaAnticheatIsSecureInternalDispatch() then
        writeAudit('anticheat.internal.rejected', 'warning', {
            eventName = 'nexa:anticheat:internal:violation',
            reason = 'INTERNAL_EVENT_NOT_ALLOWED'
        })
        return
    end

    writeAudit('anticheat.internal.violation', 'warning', entry or {})
end)

AddEventHandler('nexa:anticheat:internal:validated', function(entry)
    if not NexaAnticheatIsSecureInternalDispatch() then
        writeAudit('anticheat.internal.rejected', 'warning', {
            eventName = 'nexa:anticheat:internal:validated',
            reason = 'INTERNAL_EVENT_NOT_ALLOWED'
        })
        return
    end

    exports.nexa_logs:info(NEXA_ANTICHEAT.resourceName, 'Secure Event wurde validiert.', entry or {})
end)

exports('registerSecureEvent', registerSecureEvent)
exports('listSecureEvents', listSecureEvents)
exports('validateEvent', validateEvent)
exports('issueToken', issueToken)
exports('validateToken', validateToken)
exports('verifyEventToken', verifyEventToken)
exports('validateSession', validateSession)
exports('validateResourceIntegrity', validateResourceIntegrity)
exports('getAuditRecent', getAuditRecent)
exports('getStatus', getStatus)
