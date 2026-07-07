local function vehicleResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Vehicle-Protection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isVehicleProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.vehicleProtectionFeatureFlag)
end

local function writeVehicleAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logVehicleWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.vehicleProtection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function normalizeVehicleId(value)
    local vehicleId = tonumber(value)

    if vehicleId == nil or vehicleId <= 0 or math.floor(vehicleId) ~= vehicleId then
        return nil
    end

    return vehicleId
end

local function sortedEnabledKeys(values)
    local keys = {}

    for key, enabled in pairs(values or {}) do
        if enabled == true then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)

    return keys
end

local function buildSqlInClause(values)
    local placeholders = {}

    for index = 1, #values do
        placeholders[index] = '?'
    end

    return table.concat(placeholders, ', ')
end

local function appendValues(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function hasFindings(report)
    return #report.integrityFindings > 0
        or #report.ownershipFindings > 0
        or #report.garageStateFindings > 0
        or #report.duplicateVehicleFindings > 0
        or #report.unauthorizedSpawnFindings > 0
        or #report.unauthorizedLockFindings > 0
        or #report.fuelManipulationFindings > 0
        or #report.impoundStateFindings > 0
        or #report.dealerPurchaseFindings > 0
        or #report.keyAbuseFindings > 0
end

local function buildReport(limit)
    local reportLimit = normalizeLimit(limit)
    local vehicleConfig = NexaAnticheatServer.vehicleProtection

    local integrityFindings = MySQL.query.await([[
        SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name, fuel_level, engine_health, body_health, deleted_at, updated_at
        FROM vehicles
        WHERE plate IS NULL
            OR plate = ''
            OR CHAR_LENGTH(plate) > 16
            OR model IS NULL
            OR model = ''
            OR owner_character_id IS NULL AND status NOT IN ('deleted', 'seized')
            OR fuel_level < ?
            OR fuel_level > ?
            OR engine_health < 0
            OR body_health < 0
            OR status NOT IN ('active', 'stored', 'impounded', 'seized', 'deleted')
            OR (status = 'deleted' AND deleted_at IS NULL)
            OR (status <> 'deleted' AND deleted_at IS NOT NULL)
        ORDER BY updated_at DESC, id DESC
        LIMIT ?
    ]], {
        vehicleConfig.minFuelLevel,
        vehicleConfig.maxFuelLevel,
        reportLimit
    }) or {}

    local ownershipFindings = MySQL.query.await([[
        SELECT v.id, v.owner_character_id, v.plate, v.status, c.id AS character_id, c.deleted_at AS character_deleted_at, c.is_active
        FROM vehicles v
        LEFT JOIN characters c ON c.id = v.owner_character_id
        WHERE v.deleted_at IS NULL
            AND v.status NOT IN ('deleted', 'seized')
            AND (v.owner_character_id IS NULL OR c.id IS NULL OR c.deleted_at IS NOT NULL OR c.is_active = FALSE)
        ORDER BY v.updated_at DESC, v.id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local garageStateFindings = MySQL.query.await([[
        SELECT v.id, v.plate, v.status, v.garage_name, gs.state, gs.garage_name AS state_garage_name, gs.updated_at
        FROM vehicles v
        LEFT JOIN vehicle_garage_states gs ON gs.vehicle_id = v.id
        WHERE v.deleted_at IS NULL
            AND (
                gs.vehicle_id IS NULL
                OR gs.state NOT IN ('stored', 'out', 'impounded', 'seized')
                OR (v.status = 'stored' AND gs.state <> 'stored')
                OR (v.status = 'active' AND gs.state <> 'out')
                OR (v.status = 'impounded' AND gs.state <> 'impounded')
                OR (v.status = 'seized' AND gs.state <> 'seized')
                OR (gs.state = 'stored' AND (gs.garage_name IS NULL OR gs.garage_name = ''))
            )
        ORDER BY v.updated_at DESC, v.id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local duplicateVehicleFindings = MySQL.query.await([[
        SELECT plate, COUNT(*) AS duplicate_count, MIN(id) AS first_vehicle_id, MAX(id) AS last_vehicle_id
        FROM vehicles
        WHERE deleted_at IS NULL
            AND plate IS NOT NULL
            AND plate <> ''
        GROUP BY plate
        HAVING COUNT(*) > 1
        ORDER BY duplicate_count DESC, last_vehicle_id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local spawnEvents = sortedEnabledKeys(vehicleConfig.authorizedSpawnEvents)
    local unauthorizedSpawnFindings = {}

    if #spawnEvents > 0 then
        local spawnParams = {}
        appendValues(spawnParams, spawnEvents)
        spawnParams[#spawnParams + 1] = reportLimit

        unauthorizedSpawnFindings = MySQL.query.await(([[
            SELECT h.id, h.vehicle_id, h.event_type, h.actor_character_id, h.created_at, v.plate, v.status
            FROM vehicle_history h
            JOIN vehicles v ON v.id = h.vehicle_id
            WHERE (h.event_type LIKE '%%spawn%%' OR h.event_type LIKE '%%retrieve%%')
                AND h.event_type NOT IN (%s)
            ORDER BY h.created_at DESC, h.id DESC
            LIMIT ?
        ]]):format(buildSqlInClause(spawnEvents)), spawnParams) or {}
    end

    local unauthorizedLockFindings = MySQL.query.await([[
        SELECT h.id, h.vehicle_id, h.event_type, h.actor_character_id, h.created_at, v.plate, v.owner_character_id
        FROM vehicle_history h
        JOIN vehicles v ON v.id = h.vehicle_id
        LEFT JOIN vehicle_keys vk ON vk.vehicle_id = h.vehicle_id
            AND vk.character_id = h.actor_character_id
            AND (vk.expires_at IS NULL OR vk.expires_at > h.created_at)
        WHERE h.event_type IN ('vehicle.lock', 'vehicle.unlock')
            AND h.actor_character_id IS NOT NULL
            AND v.owner_character_id <> h.actor_character_id
            AND vk.id IS NULL
            AND NOT EXISTS (
                SELECT 1
                FROM vehicle_history grant_history
                WHERE grant_history.vehicle_id = h.vehicle_id
                    AND grant_history.event_type = 'vehicle.key.grant'
                    AND grant_history.actor_character_id IS NOT NULL
                    AND JSON_UNQUOTE(JSON_EXTRACT(grant_history.new_value, '$.characterId')) = CAST(h.actor_character_id AS CHAR)
                    AND grant_history.created_at <= h.created_at
                    AND NOT EXISTS (
                        SELECT 1
                        FROM vehicle_history revoke_history
                        WHERE revoke_history.vehicle_id = h.vehicle_id
                            AND revoke_history.event_type = 'vehicle.key.revoke'
                            AND JSON_UNQUOTE(JSON_EXTRACT(revoke_history.old_value, '$.characterId')) = CAST(h.actor_character_id AS CHAR)
                            AND revoke_history.created_at > grant_history.created_at
                            AND revoke_history.created_at <= h.created_at
                    )
            )
        ORDER BY h.created_at DESC, h.id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local fuelManipulationFindings = MySQL.query.await([[
        SELECT h.id, h.vehicle_id, h.event_type, h.actor_character_id, h.old_value, h.new_value, h.created_at, v.plate, v.fuel_level
        FROM vehicle_history h
        JOIN vehicles v ON v.id = h.vehicle_id
        WHERE v.fuel_level < ?
            OR v.fuel_level > ?
            OR (
                h.event_type IN ('vehicle.fuel.purchase', 'vehicle.fuel.consume')
                AND (
                    CAST(JSON_UNQUOTE(JSON_EXTRACT(h.old_value, '$.fuelLevel')) AS DECIMAL(8,2)) < ?
                    OR CAST(JSON_UNQUOTE(JSON_EXTRACT(h.old_value, '$.fuelLevel')) AS DECIMAL(8,2)) > ?
                    OR CAST(JSON_UNQUOTE(JSON_EXTRACT(h.new_value, '$.fuelLevel')) AS DECIMAL(8,2)) < ?
                    OR CAST(JSON_UNQUOTE(JSON_EXTRACT(h.new_value, '$.fuelLevel')) AS DECIMAL(8,2)) > ?
                    OR ABS(CAST(JSON_UNQUOTE(JSON_EXTRACT(h.new_value, '$.fuelLevel')) AS DECIMAL(8,2)) - CAST(JSON_UNQUOTE(JSON_EXTRACT(h.old_value, '$.fuelLevel')) AS DECIMAL(8,2))) > ?
                    OR (h.event_type = 'vehicle.fuel.consume' AND CAST(JSON_UNQUOTE(JSON_EXTRACT(h.new_value, '$.fuelLevel')) AS DECIMAL(8,2)) > CAST(JSON_UNQUOTE(JSON_EXTRACT(h.old_value, '$.fuelLevel')) AS DECIMAL(8,2)))
                    OR (h.event_type = 'vehicle.fuel.purchase' AND CAST(JSON_UNQUOTE(JSON_EXTRACT(h.new_value, '$.fuelLevel')) AS DECIMAL(8,2)) < CAST(JSON_UNQUOTE(JSON_EXTRACT(h.old_value, '$.fuelLevel')) AS DECIMAL(8,2)))
                )
            )
        ORDER BY h.created_at DESC, h.id DESC
        LIMIT ?
    ]], {
        vehicleConfig.minFuelLevel,
        vehicleConfig.maxFuelLevel,
        vehicleConfig.minFuelLevel,
        vehicleConfig.maxFuelLevel,
        vehicleConfig.minFuelLevel,
        vehicleConfig.maxFuelLevel,
        vehicleConfig.maxFuelDelta,
        reportLimit
    }) or {}

    local impoundStateFindings = MySQL.query.await([[
        SELECT v.id, v.plate, v.status, gs.state, gs.impound_reason, vf.id AS fine_id, vf.status AS fine_status, vf.amount
        FROM vehicles v
        LEFT JOIN vehicle_garage_states gs ON gs.vehicle_id = v.id
        LEFT JOIN vehicle_fines vf ON vf.vehicle_id = v.id AND vf.fine_type = 'impound' AND vf.status = 'open'
        WHERE v.deleted_at IS NULL
            AND (
                (v.status = 'impounded' AND (gs.state IS NULL OR gs.state <> 'impounded'))
                OR (gs.state = 'impounded' AND v.status <> 'impounded')
                OR (v.status <> 'impounded' AND vf.id IS NOT NULL)
            )
        ORDER BY v.updated_at DESC, v.id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local dealerPurchaseFindings = MySQL.query.await([[
        SELECT h.id, h.vehicle_id, h.actor_character_id, h.new_value, h.created_at, v.owner_character_id, v.plate, v.status
        FROM vehicle_history h
        JOIN vehicles v ON v.id = h.vehicle_id
        LEFT JOIN vehicle_keys vk ON vk.vehicle_id = v.id AND vk.character_id = v.owner_character_id AND vk.key_type = 'owner'
        WHERE h.event_type = 'vehicle.dealer.purchase'
            AND (
                v.owner_character_id IS NULL
                OR h.actor_character_id IS NULL
                OR v.owner_character_id <> h.actor_character_id
                OR vk.id IS NULL
                OR v.status NOT IN ('stored', 'active')
            )
        ORDER BY h.created_at DESC, h.id DESC
        LIMIT ?
    ]], {
        reportLimit
    }) or {}

    local keyAbuseFindings = MySQL.query.await([[
        SELECT vk.vehicle_id, vk.character_id, vk.key_type, vk.granted_by_character_id, vk.expires_at, vk.created_at, v.owner_character_id, v.plate, COUNT(*) OVER (PARTITION BY vk.vehicle_id) AS active_key_count
        FROM vehicle_keys vk
        JOIN vehicles v ON v.id = vk.vehicle_id
        WHERE v.deleted_at IS NULL
            AND (
                vk.key_type NOT IN ('owner', 'shared', 'temporary', 'job', 'faction')
                OR (vk.key_type = 'owner' AND vk.character_id <> v.owner_character_id)
                OR (vk.key_type = 'temporary' AND vk.expires_at IS NOT NULL AND vk.expires_at <= NOW())
                OR (vk.key_type <> 'owner' AND vk.granted_by_character_id = vk.character_id)
                OR (
                    SELECT COUNT(*)
                    FROM vehicle_keys active_keys
                    WHERE active_keys.vehicle_id = vk.vehicle_id
                        AND (active_keys.expires_at IS NULL OR active_keys.expires_at > NOW())
                ) > ?
            )
        ORDER BY vk.created_at DESC, vk.vehicle_id DESC
        LIMIT ?
    ]], {
        vehicleConfig.maxActiveKeysPerVehicle,
        reportLimit
    }) or {}

    return {
        integrityFindings = integrityFindings,
        ownershipFindings = ownershipFindings,
        garageStateFindings = garageStateFindings,
        duplicateVehicleFindings = duplicateVehicleFindings,
        unauthorizedSpawnFindings = unauthorizedSpawnFindings,
        unauthorizedLockFindings = unauthorizedLockFindings,
        fuelManipulationFindings = fuelManipulationFindings,
        impoundStateFindings = impoundStateFindings,
        dealerPurchaseFindings = dealerPurchaseFindings,
        keyAbuseFindings = keyAbuseFindings
    }
end

function validateVehicleIntegrity(payload)
    if not isVehicleProtectionEnabled() then
        return vehicleResponse(false, 'FEATURE_DISABLED', 'Vehicle Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeVehicleAudit('vehicle.integrity.database_error', 'error', {
            error = tostring(report)
        })

        logVehicleWarning('Vehicle Protection konnte die Integrity-Pruefung nicht ausfuehren.', {
            auditId = auditId
        })

        return vehicleResponse(false, 'DATABASE_ERROR', 'Vehicle-Integrity-Pruefung konnte nicht ausgefuehrt werden.', nil, nil, auditId)
    end

    local suspicious = hasFindings(report)
    local auditId = writeVehicleAudit(suspicious and 'vehicle.integrity.suspicious' or 'vehicle.integrity.validated', suspicious and 'warning' or 'info', {
        suspicious = suspicious,
        integrityFindings = #report.integrityFindings,
        ownershipFindings = #report.ownershipFindings,
        garageStateFindings = #report.garageStateFindings,
        duplicateVehicleFindings = #report.duplicateVehicleFindings,
        unauthorizedSpawnFindings = #report.unauthorizedSpawnFindings,
        unauthorizedLockFindings = #report.unauthorizedLockFindings,
        fuelManipulationFindings = #report.fuelManipulationFindings,
        impoundStateFindings = #report.impoundStateFindings,
        dealerPurchaseFindings = #report.dealerPurchaseFindings,
        keyAbuseFindings = #report.keyAbuseFindings
    })

    if suspicious then
        logVehicleWarning('Vehicle Protection hat verdaechtige Fahrzeugmuster markiert.', {
            auditId = auditId
        })
    end

    return vehicleResponse(true, suspicious and 'SUSPICIOUS_VEHICLE_ACTIVITY' or 'OK', 'Vehicle-Integrity-Pruefung wurde abgeschlossen.', report, {
        suspicious = suspicious
    }, auditId)
end

function validateVehicleOwnership(payload)
    if not isVehicleProtectionEnabled() then
        return vehicleResponse(false, 'FEATURE_DISABLED', 'Vehicle Protection ist deaktiviert.', nil, nil, nil)
    end

    local vehicleId = normalizeVehicleId(payload and payload.vehicleId)

    if vehicleId == nil then
        return vehicleResponse(false, 'INVALID_INPUT', 'Ungueltige Fahrzeug-ID.', nil, nil, nil)
    end

    local queryOk, vehicle = pcall(MySQL.single.await, [[
        SELECT v.id, v.owner_character_id, v.plate, v.status, v.deleted_at, c.id AS character_id, c.is_active, c.deleted_at AS character_deleted_at
        FROM vehicles v
        LEFT JOIN characters c ON c.id = v.owner_character_id
        WHERE v.id = ?
        LIMIT 1
    ]], {
        vehicleId
    })

    if not queryOk then
        local auditId = writeVehicleAudit('vehicle.ownership.database_error', 'error', {
            vehicleId = vehicleId,
            error = tostring(vehicle)
        })

        return vehicleResponse(false, 'DATABASE_ERROR', 'Fahrzeugbesitz konnte nicht geprueft werden.', nil, nil, auditId)
    end

    if vehicle == nil then
        return vehicleResponse(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    local suspicious = vehicle.deleted_at == nil
        and vehicle.status ~= 'deleted'
        and vehicle.status ~= 'seized'
        and (vehicle.owner_character_id == nil or vehicle.character_id == nil or vehicle.character_deleted_at ~= nil or vehicle.is_active == false or vehicle.is_active == 0)
    local auditId = nil

    if suspicious then
        auditId = writeVehicleAudit('vehicle.ownership.suspicious', 'warning', {
            vehicleId = vehicleId,
            ownerCharacterId = vehicle.owner_character_id
        })

        logVehicleWarning('Vehicle Protection hat verdaechtigen Fahrzeugbesitz markiert.', {
            vehicleId = vehicleId,
            auditId = auditId
        })
    end

    return vehicleResponse(true, suspicious and 'SUSPICIOUS_VEHICLE_OWNERSHIP' or 'OK', 'Fahrzeugbesitz wurde geprueft.', {
        vehicle = vehicle,
        suspicious = suspicious
    }, nil, auditId)
end

function validateVehicleGarageState(payload)
    if not isVehicleProtectionEnabled() then
        return vehicleResponse(false, 'FEATURE_DISABLED', 'Vehicle Protection ist deaktiviert.', nil, nil, nil)
    end

    local vehicleId = normalizeVehicleId(payload and payload.vehicleId)

    if vehicleId == nil then
        return vehicleResponse(false, 'INVALID_INPUT', 'Ungueltige Fahrzeug-ID.', nil, nil, nil)
    end

    local queryOk, row = pcall(MySQL.single.await, [[
        SELECT v.id, v.plate, v.status, v.garage_name, gs.state, gs.garage_name AS state_garage_name, gs.updated_at
        FROM vehicles v
        LEFT JOIN vehicle_garage_states gs ON gs.vehicle_id = v.id
        WHERE v.id = ?
        LIMIT 1
    ]], {
        vehicleId
    })

    if not queryOk then
        local auditId = writeVehicleAudit('vehicle.garage_state.database_error', 'error', {
            vehicleId = vehicleId,
            error = tostring(row)
        })

        return vehicleResponse(false, 'DATABASE_ERROR', 'Garagenstatus konnte nicht geprueft werden.', nil, nil, auditId)
    end

    if row == nil then
        return vehicleResponse(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    local suspicious = row.state == nil
        or (row.status == 'stored' and row.state ~= 'stored')
        or (row.status == 'active' and row.state ~= 'out')
        or (row.status == 'impounded' and row.state ~= 'impounded')
        or (row.status == 'seized' and row.state ~= 'seized')
    local auditId = nil

    if suspicious then
        auditId = writeVehicleAudit('vehicle.garage_state.suspicious', 'warning', {
            vehicleId = vehicleId,
            status = row.status,
            state = row.state
        })

        logVehicleWarning('Vehicle Protection hat verdaechtigen Garagenstatus markiert.', {
            vehicleId = vehicleId,
            auditId = auditId
        })
    end

    return vehicleResponse(true, suspicious and 'SUSPICIOUS_GARAGE_STATE' or 'OK', 'Garagenstatus wurde geprueft.', {
        vehicle = row,
        suspicious = suspicious
    }, nil, auditId)
end

function validateVehicleHistory(payload)
    if not isVehicleProtectionEnabled() then
        return vehicleResponse(false, 'FEATURE_DISABLED', 'Vehicle Protection ist deaktiviert.', nil, nil, nil)
    end

    local vehicleId = normalizeVehicleId(payload and payload.vehicleId)

    if vehicleId == nil then
        return vehicleResponse(false, 'INVALID_INPUT', 'Ungueltige Fahrzeug-ID.', nil, nil, nil)
    end

    local events = sortedEnabledKeys(NexaAnticheatServer.vehicleProtection.authorizedHistoryEvents)

    if #events == 0 then
        return vehicleResponse(false, 'INVALID_INPUT', 'Keine autorisierten Vehicle-History-Events konfiguriert.', nil, nil, nil)
    end

    local params = { vehicleId }
    appendValues(params, events)
    params[#params + 1] = normalizeLimit(payload and payload.limit)

    local queryOk, rows = pcall(MySQL.query.await, ([[
        SELECT id, vehicle_id, event_type, actor_character_id, old_value, new_value, reason, created_at
        FROM vehicle_history
        WHERE vehicle_id = ?
            AND event_type NOT IN (%s)
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]]):format(buildSqlInClause(events)), params)

    if not queryOk then
        local auditId = writeVehicleAudit('vehicle.history.database_error', 'error', {
            vehicleId = vehicleId,
            error = tostring(rows)
        })

        return vehicleResponse(false, 'DATABASE_ERROR', 'Fahrzeughistorie konnte nicht geprueft werden.', nil, nil, auditId)
    end

    rows = rows or {}
    local suspicious = #rows > 0
    local auditId = nil

    if suspicious then
        auditId = writeVehicleAudit('vehicle.history.suspicious', 'warning', {
            vehicleId = vehicleId,
            entries = #rows
        })

        logVehicleWarning('Vehicle Protection hat verdaechtige Fahrzeughistorie markiert.', {
            vehicleId = vehicleId,
            auditId = auditId
        })
    end

    return vehicleResponse(true, suspicious and 'SUSPICIOUS_VEHICLE_HISTORY' or 'OK', 'Fahrzeughistorie wurde geprueft.', {
        entries = rows,
        suspicious = suspicious
    }, nil, auditId)
end

function getVehicleReconciliationReport(payload)
    if not isVehicleProtectionEnabled() then
        return vehicleResponse(false, 'FEATURE_DISABLED', 'Vehicle Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeVehicleAudit('vehicle.reconciliation.database_error', 'error', {
            error = tostring(report)
        })

        logVehicleWarning('Vehicle Protection konnte den Reconciliation-Report nicht erstellen.', {
            auditId = auditId
        })

        return vehicleResponse(false, 'DATABASE_ERROR', 'Vehicle-Reconciliation-Report konnte nicht erstellt werden.', nil, nil, auditId)
    end

    local suspicious = hasFindings(report)
    local auditId = writeVehicleAudit('vehicle.reconciliation.report', suspicious and 'warning' or 'info', {
        suspicious = suspicious
    })

    return vehicleResponse(true, 'OK', 'Vehicle-Reconciliation-Report wurde erstellt.', report, {
        suspicious = suspicious
    }, auditId)
end

exports('validateVehicleIntegrity', validateVehicleIntegrity)
exports('validateVehicleOwnership', validateVehicleOwnership)
exports('validateVehicleGarageState', validateVehicleGarageState)
exports('validateVehicleHistory', validateVehicleHistory)
exports('getVehicleReconciliationReport', getVehicleReconciliationReport)
