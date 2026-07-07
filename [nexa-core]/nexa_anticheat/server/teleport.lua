local positionSnapshots = {}
local teleportAllowances = {}
local suspiciousMovementReports = {}

local function teleportResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Teleport-Detection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isTeleportDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.teleportDetectionFeatureFlag)
end

local function writeTeleportAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logTeleportWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function getNowMs()
    if GetGameTimer ~= nil then
        return GetGameTimer()
    end

    return math.floor(os.time() * 1000)
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.teleportDetection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function normalizeContext(context)
    if type(context) ~= 'string' then
        return nil
    end

    context = context:lower():gsub('%s+', '_')

    if NexaAnticheatServer.teleportDetection.whitelistedContexts[context] ~= true then
        return nil
    end

    return context
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

local function hasAnyAdminTeleportPermission(source, metadata)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local permissionSource = tonumber(metadata and metadata.actorSource) or source

    for permission, enabled in pairs(NexaAnticheatServer.teleportDetection.adminPermissions or {}) do
        if enabled == true then
            local ok, allowed = pcall(function()
                return exports.nexa_permissions:has(permissionSource, permission)
            end)

            if ok and allowed == true then
                return true
            end
        end
    end

    return false
end

local function validateSource(source)
    local valid, code, normalizedSource = NexaAnticheatValidateSource(source)

    if not valid then
        return false, code, nil
    end

    return true, 'OK', normalizedSource
end

local function getServerPosition(source)
    local ped = GetPlayerPed(source)

    if ped == nil or ped == 0 then
        return nil, 'PED_NOT_FOUND'
    end

    local coords = GetEntityCoords(ped)

    if coords == nil then
        return nil, 'POSITION_UNAVAILABLE'
    end

    return {
        x = coords.x or coords[1],
        y = coords.y or coords[2],
        z = coords.z or coords[3]
    }, 'OK'
end

local function calculateDistance(first, second)
    local dx = (first.x or 0.0) - (second.x or 0.0)
    local dy = (first.y or 0.0) - (second.y or 0.0)
    local dz = (first.z or 0.0) - (second.z or 0.0)

    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function recordSnapshot(source, position, capturedAt)
    positionSnapshots[tostring(source)] = {
        position = position,
        capturedAt = capturedAt
    }
end

local function consumeTeleportAllowance(source, capturedAt)
    local key = tostring(source)
    local allowance = teleportAllowances[key]

    if allowance == nil then
        return nil
    end

    teleportAllowances[key] = nil

    if allowance.expiresAt < capturedAt then
        return nil
    end

    return allowance
end

local function pruneExpiredSnapshots(capturedAt)
    local ttlMs = (NexaAnticheatServer.teleportDetection.snapshotTtlSeconds or 60) * 1000

    for key, snapshot in pairs(positionSnapshots) do
        if capturedAt - snapshot.capturedAt > ttlMs then
            positionSnapshots[key] = nil
        end
    end
end

local function appendSuspiciousMovementReport(report)
    suspiciousMovementReports[#suspiciousMovementReports + 1] = report

    local maxReports = math.max(NexaAnticheatServer.teleportDetection.reportLimit or 50, 50)

    while #suspiciousMovementReports > maxReports do
        table.remove(suspiciousMovementReports, 1)
    end
end

local function buildMovementReport(source, previous, current, capturedAt, distance, speed)
    return {
        source = source,
        previous = previous.position,
        current = current,
        previousCapturedAt = previous.capturedAt,
        capturedAt = capturedAt,
        distanceDelta = distance,
        speedMetersPerSecond = speed,
        maxDistanceDelta = NexaAnticheatServer.teleportDetection.maxDistanceDelta,
        maxSpeedMetersPerSecond = NexaAnticheatServer.teleportDetection.maxSpeedMetersPerSecond
    }
end

function allowTeleport(source, context, metadata)
    if not isTeleportDetectionEnabled() then
        return teleportResponse(false, 'FEATURE_DISABLED', 'Teleport Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return teleportResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local normalizedContext = normalizeContext(context)

    if normalizedContext == nil then
        return teleportResponse(false, 'INVALID_INPUT', 'Ungueltiger Teleport-Allowlist-Kontext.', nil, nil, nil)
    end

    local sanitizedMetadata = sanitizeMetadata(metadata)

    if (normalizedContext == 'admin_teleport' or normalizedContext == 'admin_utility')
        and not hasAnyAdminTeleportPermission(normalizedSource, sanitizedMetadata) then
        return teleportResponse(false, 'NO_PERMISSION', 'Admin-Teleport-Ausnahme wurde verweigert.', nil, nil, nil)
    end

    local capturedAt = getNowMs()
    local ttlMs = (NexaAnticheatServer.teleportDetection.whitelistTtlSeconds or 12) * 1000
    local allowance = {
        context = normalizedContext,
        metadata = sanitizedMetadata,
        createdAt = capturedAt,
        expiresAt = capturedAt + ttlMs
    }

    teleportAllowances[tostring(normalizedSource)] = allowance

    local auditId = writeTeleportAudit('teleport.allowlist.marked', 'info', {
        source = normalizedSource,
        context = normalizedContext,
        expiresAt = allowance.expiresAt,
        metadata = allowance.metadata
    })

    return teleportResponse(true, 'OK', 'Teleport-Allowlist-Kontext wurde serverseitig markiert.', allowance, nil, auditId)
end

function validatePositionSnapshot(source, payload)
    if not isTeleportDetectionEnabled() then
        return teleportResponse(false, 'FEATURE_DISABLED', 'Teleport Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return teleportResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.teleport.validateSnapshot')

    if not limited then
        return teleportResponse(false, limitCode, 'Teleport Detection wurde rate-limited.', nil, nil, nil)
    end

    local position, positionCode = getServerPosition(normalizedSource)

    if position == nil then
        local auditId = writeTeleportAudit('teleport.position.unavailable', 'warning', {
            source = normalizedSource,
            code = positionCode
        })

        return teleportResponse(false, positionCode, 'Serverseitige Position konnte nicht bestimmt werden.', nil, nil, auditId)
    end

    local capturedAt = getNowMs()
    pruneExpiredSnapshots(capturedAt)

    local key = tostring(normalizedSource)
    local previous = positionSnapshots[key]
    recordSnapshot(normalizedSource, position, capturedAt)

    if previous == nil then
        return teleportResponse(true, 'OK', 'Position Snapshot Validation initialisiert.', {
            source = normalizedSource,
            position = position
        }, {
            initialized = true
        }, nil)
    end

    local elapsedSeconds = math.max(
        (capturedAt - previous.capturedAt) / 1000,
        NexaAnticheatServer.teleportDetection.minDeltaSeconds or 0.25
    )
    local distance = calculateDistance(previous.position, position)
    local speed = distance / elapsedSeconds
    local allowance = consumeTeleportAllowance(normalizedSource, capturedAt)
    local suspicious = allowance == nil
        and (
            distance > NexaAnticheatServer.teleportDetection.maxDistanceDelta
            or speed > NexaAnticheatServer.teleportDetection.maxSpeedMetersPerSecond
        )

    if suspicious then
        local report = buildMovementReport(normalizedSource, previous, position, capturedAt, distance, speed)
        report.payloadIgnored = payload ~= nil

        local auditId = writeTeleportAudit('teleport.suspicious_movement', 'warning', report)
        report.auditId = auditId
        appendSuspiciousMovementReport(report)

        logTeleportWarning('Teleport Detection hat verdaechtige Bewegung markiert.', {
            source = normalizedSource,
            auditId = auditId,
            distanceDelta = distance,
            speedMetersPerSecond = speed
        })

        return teleportResponse(true, 'SUSPICIOUS_TELEPORT', 'Verdaechtige Bewegung wurde auditierbar markiert.', report, {
            suspicious = true,
            automaticSanction = false
        }, auditId)
    end

    return teleportResponse(true, 'OK', 'Position Snapshot Validation wurde abgeschlossen.', {
        source = normalizedSource,
        position = position,
        distanceDelta = distance,
        speedMetersPerSecond = speed,
        allowance = allowance
    }, {
        suspicious = false,
        whitelisted = allowance ~= nil
    }, nil)
end

function getSuspiciousMovementReports(limit)
    local requestedLimit = normalizeLimit(limit)
    local result = {}
    local startIndex = math.max(1, #suspiciousMovementReports - requestedLimit + 1)

    for index = startIndex, #suspiciousMovementReports do
        result[#result + 1] = suspiciousMovementReports[index]
    end

    return teleportResponse(true, 'OK', 'Suspicious movement reports wurden gelesen.', result, {
        count = #result
    }, nil)
end

AddEventHandler('playerDropped', function()
    local source = source
    local key = tostring(source)

    positionSnapshots[key] = nil
    teleportAllowances[key] = nil
end)

exports('validatePositionSnapshot', validatePositionSnapshot)
exports('allowTeleport', allowTeleport)
exports('getSuspiciousMovementReports', getSuspiciousMovementReports)
