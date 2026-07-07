local godmodeSnapshots = {}
local godmodeExceptions = {}
local damageEvents = {}
local suspiciousGodmodeReports = {}
local consecutiveGodmodeFindings = {}

local function godmodeResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Godmode-Detection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isGodmodeDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.godmodeDetectionFeatureFlag)
end

local function writeGodmodeAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logGodmodeWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function getNowMs()
    if GetGameTimer ~= nil then
        return GetGameTimer()
    end

    return math.floor(os.time() * 1000)
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.godmodeDetection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
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

local function normalizeContext(context)
    if type(context) ~= 'string' then
        return nil
    end

    context = context:lower():gsub('%s+', '_')

    if NexaAnticheatServer.godmodeDetection.exceptionContexts[context] ~= true then
        return nil
    end

    return context
end

local function validateSource(source)
    local valid, code, normalizedSource = NexaAnticheatValidateSource(source)

    if not valid then
        return false, code, nil
    end

    return true, 'OK', normalizedSource
end

local function callNative(name, ...)
    local native = _G[name]

    if type(native) ~= 'function' then
        return false, nil
    end

    local ok, result = pcall(native, ...)

    if not ok then
        return false, nil
    end

    return true, result
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
                return true
            end
        end
    end

    return false
end

local function hasContextPermission(source, context, metadata)
    local actorSource = tonumber(metadata and metadata.actorSource) or source

    if context == 'admin_heal' or context == 'admin_revive' then
        return hasAnyPermission(actorSource, NexaAnticheatServer.godmodeDetection.adminPermissions)
    end

    if context == 'ems_treatment' then
        return hasAnyPermission(actorSource, NexaAnticheatServer.godmodeDetection.emsPermissions)
    end

    return true
end

local function getServerGodmodeState(source)
    local ped = GetPlayerPed(source)

    if ped == nil or ped == 0 then
        return nil, 'PED_NOT_FOUND'
    end

    local health = GetEntityHealth(ped)

    if health == nil then
        return nil, 'HEALTH_UNAVAILABLE'
    end

    local armor = 0
    local armorOk, armorValue = callNative('GetPedArmour', ped)

    if armorOk and armorValue ~= nil then
        armor = tonumber(armorValue) or 0
    end

    local invincible = false
    local playerInvincibleOk, playerInvincible = callNative('GetPlayerInvincible', source)

    if playerInvincibleOk and playerInvincible == true then
        invincible = true
    end

    local entityCanBeDamaged = nil
    local damageableOk, damageable = callNative('GetEntityCanBeDamaged', ped)

    if damageableOk then
        entityCanBeDamaged = damageable == true

        if entityCanBeDamaged == false then
            invincible = true
        end
    end

    return {
        ped = ped,
        health = tonumber(health) or 0,
        armor = armor,
        invincible = invincible,
        entityCanBeDamaged = entityCanBeDamaged
    }, 'OK'
end

local function getGodmodeException(source, capturedAt)
    local key = tostring(source)
    local exception = godmodeExceptions[key]

    if exception == nil then
        return nil
    end

    if exception.expiresAt < capturedAt then
        godmodeExceptions[key] = nil
        return nil
    end

    return exception
end

local function pruneDamageEvents(source, capturedAt)
    local key = tostring(source)
    local events = damageEvents[key]

    if events == nil then
        return {}
    end

    local graceMs = (NexaAnticheatServer.godmodeDetection.damageGraceSeconds or 4) * 1000
    local remaining = {}

    for _, event in ipairs(events) do
        if capturedAt - event.capturedAt <= graceMs then
            remaining[#remaining + 1] = event
        end
    end

    damageEvents[key] = remaining

    return remaining
end

local function appendSuspiciousGodmodeReport(report)
    suspiciousGodmodeReports[#suspiciousGodmodeReports + 1] = report

    local maxReports = math.max(NexaAnticheatServer.godmodeDetection.reportLimit or 50, 50)

    while #suspiciousGodmodeReports > maxReports do
        table.remove(suspiciousGodmodeReports, 1)
    end
end

local function recordSnapshot(source, state, capturedAt)
    godmodeSnapshots[tostring(source)] = {
        health = state.health,
        armor = state.armor,
        invincible = state.invincible,
        capturedAt = capturedAt
    }
end

local function buildGodmodeFinding(source, previous, current, damageWindow, capturedAt)
    local config = NexaAnticheatServer.godmodeDetection
    local previousEffective = previous and ((previous.health or 0) + (previous.armor or 0)) or nil
    local currentEffective = (current.health or 0) + (current.armor or 0)
    local expectedDamage = 0

    for _, event in ipairs(damageWindow or {}) do
        expectedDamage = expectedDamage + (tonumber(event.amount) or 0)
    end

    local noDamageApplied = previousEffective ~= nil
        and expectedDamage >= config.minDamageAmount
        and currentEffective >= previousEffective
    local healthOverflow = current.health > config.maxHealth
    local armorOverflow = current.armor > config.maxArmor
    local suspicious = current.invincible == true or healthOverflow or armorOverflow or noDamageApplied

    return {
        source = source,
        suspicious = suspicious,
        health = current.health,
        armor = current.armor,
        invincible = current.invincible,
        entityCanBeDamaged = current.entityCanBeDamaged,
        previousHealth = previous and previous.health or nil,
        previousArmor = previous and previous.armor or nil,
        expectedDamage = expectedDamage,
        damageEvents = damageWindow,
        noDamageApplied = noDamageApplied,
        healthOverflow = healthOverflow,
        armorOverflow = armorOverflow,
        maxHealth = config.maxHealth,
        maxArmor = config.maxArmor,
        capturedAt = capturedAt
    }
end

function allowGodmodeException(source, context, metadata)
    if not isGodmodeDetectionEnabled() then
        return godmodeResponse(false, 'FEATURE_DISABLED', 'Godmode Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return godmodeResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local normalizedContext = normalizeContext(context)

    if normalizedContext == nil then
        return godmodeResponse(false, 'INVALID_INPUT', 'Ungueltiger Godmode-Ausnahme-Kontext.', nil, nil, nil)
    end

    local sanitizedMetadata = sanitizeMetadata(metadata)

    if not hasContextPermission(normalizedSource, normalizedContext, sanitizedMetadata) then
        return godmodeResponse(false, 'NO_PERMISSION', 'Godmode-Ausnahme wurde verweigert.', nil, nil, nil)
    end

    local capturedAt = getNowMs()
    local ttlSeconds = normalizedContext == 'spawn_protection'
        and NexaAnticheatServer.godmodeDetection.spawnProtectionSeconds
        or NexaAnticheatServer.godmodeDetection.exceptionTtlSeconds
    local exception = {
        context = normalizedContext,
        metadata = sanitizedMetadata,
        createdAt = capturedAt,
        expiresAt = capturedAt + ((ttlSeconds or 12) * 1000)
    }

    godmodeExceptions[tostring(normalizedSource)] = exception

    local auditId = writeGodmodeAudit('godmode.exception.marked', 'info', {
        source = normalizedSource,
        context = normalizedContext,
        expiresAt = exception.expiresAt,
        metadata = exception.metadata
    })

    return godmodeResponse(true, 'OK', 'Godmode-Ausnahme wurde serverseitig markiert.', exception, nil, auditId)
end

function recordGodmodeDamageEvent(source, payload)
    if not isGodmodeDetectionEnabled() then
        return godmodeResponse(false, 'FEATURE_DISABLED', 'Godmode Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return godmodeResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.godmode.recordDamage')

    if not limited then
        return godmodeResponse(false, limitCode, 'Godmode Damage Validation wurde rate-limited.', nil, nil, nil)
    end

    local amount = tonumber(payload and payload.amount)

    if amount == nil or amount < NexaAnticheatServer.godmodeDetection.minDamageAmount then
        return godmodeResponse(false, 'INVALID_INPUT', 'Ungueltiger Damage-Event.', nil, nil, nil)
    end

    local key = tostring(normalizedSource)
    local capturedAt = getNowMs()
    damageEvents[key] = damageEvents[key] or {}
    damageEvents[key][#damageEvents[key] + 1] = {
        amount = amount,
        reason = type(payload) == 'table' and type(payload.reason) == 'string' and payload.reason:sub(1, 64) or 'damage',
        resourceName = GetInvokingResource() or NEXA_ANTICHEAT.resourceName,
        capturedAt = capturedAt
    }

    pruneDamageEvents(normalizedSource, capturedAt)

    return godmodeResponse(true, 'OK', 'Damage-Event wurde serverseitig fuer Godmode Detection vorgemerkt.', {
        source = normalizedSource,
        amount = amount
    }, nil, nil)
end

function validateGodmodeState(source, payload)
    if not isGodmodeDetectionEnabled() then
        return godmodeResponse(false, 'FEATURE_DISABLED', 'Godmode Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return godmodeResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.godmode.validateState')

    if not limited then
        return godmodeResponse(false, limitCode, 'Godmode Detection wurde rate-limited.', nil, nil, nil)
    end

    local state, stateCode = getServerGodmodeState(normalizedSource)

    if state == nil then
        local auditId = writeGodmodeAudit('godmode.state.unavailable', 'warning', {
            source = normalizedSource,
            code = stateCode
        })

        return godmodeResponse(false, stateCode, 'Serverseitiger Health/Armor-Zustand konnte nicht bestimmt werden.', nil, nil, auditId)
    end

    local capturedAt = getNowMs()
    local key = tostring(normalizedSource)
    local previous = godmodeSnapshots[key]
    local damageWindow = pruneDamageEvents(normalizedSource, capturedAt)
    local exception = getGodmodeException(normalizedSource, capturedAt)
    local finding = buildGodmodeFinding(normalizedSource, previous, state, damageWindow, capturedAt)
    finding.payloadIgnored = payload ~= nil
    finding.exception = exception and exception.context or nil

    recordSnapshot(normalizedSource, state, capturedAt)

    if previous == nil then
        consecutiveGodmodeFindings[key] = nil

        return godmodeResponse(true, 'OK', 'Godmode Detection Snapshot initialisiert.', finding, {
            initialized = true
        }, nil)
    end

    if exception ~= nil then
        consecutiveGodmodeFindings[key] = nil

        return godmodeResponse(true, 'OK', 'Godmode Detection wurde mit legitimer Ausnahme abgeschlossen.', finding, {
            suspicious = false,
            exception = exception.context
        }, nil)
    end

    if finding.suspicious then
        consecutiveGodmodeFindings[key] = (consecutiveGodmodeFindings[key] or 0) + 1
    else
        consecutiveGodmodeFindings[key] = nil
    end

    finding.consecutiveFindings = consecutiveGodmodeFindings[key] or 0

    if finding.consecutiveFindings >= NexaAnticheatServer.godmodeDetection.suspiciousConsecutiveLimit then
        local auditId = writeGodmodeAudit('godmode.suspicious_state', 'warning', finding)
        finding.auditId = auditId
        appendSuspiciousGodmodeReport(finding)

        logGodmodeWarning('Godmode Detection hat verdaechtigen Zustand markiert.', {
            source = normalizedSource,
            auditId = auditId,
            health = finding.health,
            armor = finding.armor,
            invincible = finding.invincible
        })

        return godmodeResponse(true, 'SUSPICIOUS_GODMODE', 'Verdaechtiger Godmode-Zustand wurde auditierbar markiert.', finding, {
            suspicious = true,
            automaticSanction = false
        }, auditId)
    end

    return godmodeResponse(true, 'OK', 'Godmode Detection wurde abgeschlossen.', finding, {
        suspicious = false,
        pendingSuspicion = finding.suspicious == true
    }, nil)
end

function getSuspiciousGodmodeReports(limit)
    local requestedLimit = normalizeLimit(limit)
    local result = {}
    local startIndex = math.max(1, #suspiciousGodmodeReports - requestedLimit + 1)

    for index = startIndex, #suspiciousGodmodeReports do
        result[#result + 1] = suspiciousGodmodeReports[index]
    end

    return godmodeResponse(true, 'OK', 'Suspicious godmode reports wurden gelesen.', result, {
        count = #result
    }, nil)
end

AddEventHandler('playerDropped', function()
    local source = source
    local key = tostring(source)

    godmodeSnapshots[key] = nil
    godmodeExceptions[key] = nil
    damageEvents[key] = nil
    consecutiveGodmodeFindings[key] = nil
end)

exports('validateGodmodeState', validateGodmodeState)
exports('allowGodmodeException', allowGodmodeException)
exports('recordGodmodeDamageEvent', recordGodmodeDamageEvent)
exports('getSuspiciousGodmodeReports', getSuspiciousGodmodeReports)
