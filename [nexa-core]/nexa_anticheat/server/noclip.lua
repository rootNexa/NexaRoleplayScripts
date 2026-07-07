local noclipSnapshots = {}
local noclipExceptions = {}
local suspiciousNoclipReports = {}
local consecutiveNoclipFindings = {}

local function noclipResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Noclip-Detection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isNoclipDetectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.noclipDetectionFeatureFlag)
end

local function writeNoclipAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logNoclipWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function getNowMs()
    if GetGameTimer ~= nil then
        return GetGameTimer()
    end

    return math.floor(os.time() * 1000)
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.noclipDetection.reportLimit
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

    if NexaAnticheatServer.noclipDetection.transitionContexts[context] ~= true then
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

local function hasAnyAdminNoclipPermission(source, metadata)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local permissionSource = tonumber(metadata and metadata.actorSource) or source

    for permission, enabled in pairs(NexaAnticheatServer.noclipDetection.adminPermissions or {}) do
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

local function getVectorComponents(value)
    if value == nil then
        return nil
    end

    return {
        x = value.x or value[1] or 0.0,
        y = value.y or value[2] or 0.0,
        z = value.z or value[3] or 0.0
    }
end

local function getPedVehicleState(ped)
    local vehicleOk, vehicle = callNative('GetVehiclePedIsIn', ped, false)

    if not vehicleOk or vehicle == nil or vehicle == 0 then
        local anyVehicleOk, anyVehicle = callNative('IsPedInAnyVehicle', ped, false)

        return {
            inVehicle = anyVehicleOk and anyVehicle == true,
            passenger = false
        }
    end

    local driverOk, driverPed = callNative('GetPedInVehicleSeat', vehicle, -1)

    return {
        inVehicle = true,
        passenger = driverOk and driverPed ~= nil and driverPed ~= ped
    }
end

local function getMovementExceptions(ped)
    local fallingOk, falling = callNative('IsPedFalling', ped)
    local jumpingOk, jumping = callNative('IsPedJumping', ped)
    local parachuteOk, parachuteState = callNative('GetPedParachuteState', ped)

    return {
        falling = fallingOk and falling == true,
        jumping = jumpingOk and jumping == true,
        parachute = parachuteOk and parachuteState ~= nil and tonumber(parachuteState) ~= -1
    }
end

local function getServerMovementState(source)
    local ped = GetPlayerPed(source)

    if ped == nil or ped == 0 then
        return nil, 'PED_NOT_FOUND'
    end

    local coords = GetEntityCoords(ped)

    if coords == nil then
        return nil, 'POSITION_UNAVAILABLE'
    end

    local velocity = nil
    local velocityOk, velocityValue = callNative('GetEntityVelocity', ped)

    if velocityOk then
        velocity = getVectorComponents(velocityValue)
    end

    local heightAboveGround = nil
    local heightOk, heightValue = callNative('GetEntityHeightAboveGround', ped)

    if heightOk then
        heightAboveGround = tonumber(heightValue)
    end

    local speed = nil
    local speedOk, speedValue = callNative('GetEntitySpeed', ped)

    if speedOk then
        speed = tonumber(speedValue)
    end

    local position = getVectorComponents(coords)

    return {
        ped = ped,
        position = position,
        velocity = velocity,
        speed = speed,
        heightAboveGround = heightAboveGround,
        vehicle = getPedVehicleState(ped),
        movementExceptions = getMovementExceptions(ped)
    }, 'OK'
end

local function calculateHorizontalDistance(first, second)
    local dx = (first.x or 0.0) - (second.x or 0.0)
    local dy = (first.y or 0.0) - (second.y or 0.0)

    return math.sqrt((dx * dx) + (dy * dy))
end

local function recordSnapshot(source, movementState, capturedAt)
    noclipSnapshots[tostring(source)] = {
        position = movementState.position,
        heightAboveGround = movementState.heightAboveGround,
        capturedAt = capturedAt
    }
end

local function getNoclipException(source, capturedAt)
    local key = tostring(source)
    local exception = noclipExceptions[key]

    if exception == nil then
        return nil
    end

    if exception.expiresAt < capturedAt then
        noclipExceptions[key] = nil
        return nil
    end

    return exception
end

local function pruneExpiredSnapshots(capturedAt)
    local ttlMs = (NexaAnticheatServer.noclipDetection.snapshotTtlSeconds or 45) * 1000

    for key, snapshot in pairs(noclipSnapshots) do
        if capturedAt - snapshot.capturedAt > ttlMs then
            noclipSnapshots[key] = nil
            consecutiveNoclipFindings[key] = nil
        end
    end
end

local function appendSuspiciousNoclipReport(report)
    suspiciousNoclipReports[#suspiciousNoclipReports + 1] = report

    local maxReports = math.max(NexaAnticheatServer.noclipDetection.reportLimit or 50, 50)

    while #suspiciousNoclipReports > maxReports do
        table.remove(suspiciousNoclipReports, 1)
    end
end

local function hasMovementException(movementState, exception)
    if exception ~= nil then
        return true, exception.context
    end

    if movementState.vehicle.inVehicle == true or movementState.vehicle.passenger == true then
        return true, 'vehicle'
    end

    if movementState.movementExceptions.falling == true then
        return true, 'fall'
    end

    if movementState.movementExceptions.jumping == true then
        return true, 'jump'
    end

    if movementState.movementExceptions.parachute == true then
        return true, 'parachute'
    end

    return false, nil
end

local function buildNoclipFinding(source, previous, current, capturedAt)
    local config = NexaAnticheatServer.noclipDetection
    local elapsedSeconds = math.max((capturedAt - previous.capturedAt) / 1000, config.minDeltaSeconds or 0.25)
    local horizontalDistance = calculateHorizontalDistance(previous.position, current.position)
    local horizontalSpeed = horizontalDistance / elapsedSeconds
    local verticalDelta = math.abs((current.position.z or 0.0) - (previous.position.z or 0.0))
    local signedVerticalDelta = (current.position.z or 0.0) - (previous.position.z or 0.0)
    local verticalSpeed = verticalDelta / elapsedSeconds
    local heightAboveGround = current.heightAboveGround
    local airborne = heightAboveGround ~= nil and heightAboveGround > config.maxHeightAboveGround
    local elevatedWithoutContact = airborne and horizontalDistance > config.minAirborneDistance
    local velocityHorizontalSpeed = nil

    if current.velocity ~= nil then
        velocityHorizontalSpeed = math.sqrt((current.velocity.x * current.velocity.x) + (current.velocity.y * current.velocity.y))
    end

    local suspicious = elevatedWithoutContact
        and (
            horizontalSpeed > config.maxHorizontalMetersPerSecond
            or verticalSpeed > config.maxVerticalMetersPerSecond
            or (current.speed ~= nil and current.speed > config.maxHorizontalMetersPerSecond)
            or (velocityHorizontalSpeed ~= nil and velocityHorizontalSpeed > config.maxHorizontalMetersPerSecond)
        )

    return {
        source = source,
        suspicious = suspicious,
        previous = previous.position,
        current = current.position,
        previousCapturedAt = previous.capturedAt,
        capturedAt = capturedAt,
        horizontalDistance = horizontalDistance,
        horizontalSpeed = horizontalSpeed,
        verticalDelta = verticalDelta,
        signedVerticalDelta = signedVerticalDelta,
        verticalSpeed = verticalSpeed,
        entitySpeed = current.speed,
        velocityHorizontalSpeed = velocityHorizontalSpeed,
        heightAboveGround = heightAboveGround,
        groundContactValidated = heightAboveGround ~= nil,
        maxHeightAboveGround = config.maxHeightAboveGround,
        maxHorizontalMetersPerSecond = config.maxHorizontalMetersPerSecond,
        maxVerticalMetersPerSecond = config.maxVerticalMetersPerSecond
    }
end

local function inferAirMovementException(finding)
    local config = NexaAnticheatServer.noclipDetection

    if finding.heightAboveGround == nil or finding.heightAboveGround <= config.maxHeightAboveGround then
        return nil
    end

    if finding.signedVerticalDelta <= -(config.minFallDelta or 3.0)
        and finding.horizontalSpeed <= (config.maxFallHorizontalMetersPerSecond or 45.0) then
        return 'fall'
    end

    if finding.signedVerticalDelta <= 0
        and finding.horizontalSpeed <= (config.maxParachuteHorizontalMetersPerSecond or 32.0)
        and finding.verticalSpeed <= (config.maxVerticalMetersPerSecond or 24.0) then
        return 'parachute'
    end

    return nil
end

function allowNoclipException(source, context, metadata)
    if not isNoclipDetectionEnabled() then
        return noclipResponse(false, 'FEATURE_DISABLED', 'Noclip Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return noclipResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local normalizedContext = normalizeContext(context)

    if normalizedContext == nil then
        return noclipResponse(false, 'INVALID_INPUT', 'Ungueltiger Noclip-Ausnahme-Kontext.', nil, nil, nil)
    end

    local sanitizedMetadata = sanitizeMetadata(metadata)

    if normalizedContext == 'admin_noclip' and not hasAnyAdminNoclipPermission(normalizedSource, sanitizedMetadata) then
        return noclipResponse(false, 'NO_PERMISSION', 'Admin-Noclip-Ausnahme wurde verweigert.', nil, nil, nil)
    end

    local capturedAt = getNowMs()
    local ttlMs = (NexaAnticheatServer.noclipDetection.exceptionTtlSeconds or 12) * 1000
    local exception = {
        context = normalizedContext,
        metadata = sanitizedMetadata,
        createdAt = capturedAt,
        expiresAt = capturedAt + ttlMs
    }

    noclipExceptions[tostring(normalizedSource)] = exception

    local auditId = writeNoclipAudit('noclip.exception.marked', 'info', {
        source = normalizedSource,
        context = normalizedContext,
        expiresAt = exception.expiresAt,
        metadata = exception.metadata
    })

    return noclipResponse(true, 'OK', 'Noclip-Ausnahme wurde serverseitig markiert.', exception, nil, auditId)
end

function validateNoclipMovement(source, payload)
    if not isNoclipDetectionEnabled() then
        return noclipResponse(false, 'FEATURE_DISABLED', 'Noclip Detection ist deaktiviert.', nil, nil, nil)
    end

    local sourceValid, sourceCode, normalizedSource = validateSource(source)

    if not sourceValid then
        return noclipResponse(false, sourceCode, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.noclip.validateMovement')

    if not limited then
        return noclipResponse(false, limitCode, 'Noclip Detection wurde rate-limited.', nil, nil, nil)
    end

    local movementState, movementCode = getServerMovementState(normalizedSource)

    if movementState == nil then
        local auditId = writeNoclipAudit('noclip.movement.unavailable', 'warning', {
            source = normalizedSource,
            code = movementCode
        })

        return noclipResponse(false, movementCode, 'Serverseitige Bewegungsdaten konnten nicht bestimmt werden.', nil, nil, auditId)
    end

    local capturedAt = getNowMs()
    pruneExpiredSnapshots(capturedAt)

    local key = tostring(normalizedSource)
    local previous = noclipSnapshots[key]
    recordSnapshot(normalizedSource, movementState, capturedAt)

    if previous == nil then
        consecutiveNoclipFindings[key] = nil

        return noclipResponse(true, 'OK', 'Noclip Detection Snapshot initialisiert.', {
            source = normalizedSource,
            position = movementState.position,
            heightAboveGround = movementState.heightAboveGround
        }, {
            initialized = true
        }, nil)
    end

    local exception = getNoclipException(normalizedSource, capturedAt)
    local excepted, exceptionReason = hasMovementException(movementState, exception)
    local finding = buildNoclipFinding(normalizedSource, previous, movementState, capturedAt)
    local inferredException = inferAirMovementException(finding)

    if not excepted and inferredException ~= nil then
        excepted = true
        exceptionReason = inferredException
    end

    finding.payloadIgnored = payload ~= nil
    finding.exception = exceptionReason

    if excepted then
        consecutiveNoclipFindings[key] = nil

        return noclipResponse(true, 'OK', 'Noclip Detection wurde mit legitimer Ausnahme abgeschlossen.', finding, {
            suspicious = false,
            exception = exceptionReason
        }, nil)
    end

    if finding.suspicious then
        consecutiveNoclipFindings[key] = (consecutiveNoclipFindings[key] or 0) + 1
    else
        consecutiveNoclipFindings[key] = nil
    end

    finding.consecutiveFindings = consecutiveNoclipFindings[key] or 0

    if finding.consecutiveFindings >= NexaAnticheatServer.noclipDetection.suspiciousConsecutiveLimit then
        local auditId = writeNoclipAudit('noclip.suspicious_movement', 'warning', finding)
        finding.auditId = auditId
        appendSuspiciousNoclipReport(finding)

        logNoclipWarning('Noclip Detection hat verdaechtige Bewegung markiert.', {
            source = normalizedSource,
            auditId = auditId,
            horizontalSpeed = finding.horizontalSpeed,
            heightAboveGround = finding.heightAboveGround
        })

        return noclipResponse(true, 'SUSPICIOUS_NOCLIP', 'Verdaechtige Noclip-Bewegung wurde auditierbar markiert.', finding, {
            suspicious = true,
            automaticSanction = false
        }, auditId)
    end

    return noclipResponse(true, 'OK', 'Noclip Detection wurde abgeschlossen.', finding, {
        suspicious = false,
        pendingSuspicion = finding.suspicious == true
    }, nil)
end

function getSuspiciousNoclipReports(limit)
    local requestedLimit = normalizeLimit(limit)
    local result = {}
    local startIndex = math.max(1, #suspiciousNoclipReports - requestedLimit + 1)

    for index = startIndex, #suspiciousNoclipReports do
        result[#result + 1] = suspiciousNoclipReports[index]
    end

    return noclipResponse(true, 'OK', 'Suspicious noclip reports wurden gelesen.', result, {
        count = #result
    }, nil)
end

AddEventHandler('playerDropped', function()
    local source = source
    local key = tostring(source)

    noclipSnapshots[key] = nil
    noclipExceptions[key] = nil
    consecutiveNoclipFindings[key] = nil
end)

exports('validateNoclipMovement', validateNoclipMovement)
exports('allowNoclipException', allowNoclipException)
exports('getSuspiciousNoclipReports', getSuspiciousNoclipReports)
