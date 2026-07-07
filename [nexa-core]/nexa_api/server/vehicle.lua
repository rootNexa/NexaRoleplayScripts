local vehicleLimits = {
    maxGarageNameLength = 64,
    maxPlateLength = 16,
    maxListLimit = 50,
    defaultListLimit = 25,
    maxReasonLength = 128,
    minTemporaryMinutes = 1,
    maxTemporaryMinutes = 1440,
    maxCatalogIdLength = 64,
    maxModelLength = 64,
    maxVehicleTypeLength = 32,
    minVehiclePrice = 1,
    maxVehiclePrice = 100000000,
    minFuelLevel = 0,
    maxFuelLevel = 100,
    minFuelLiters = 1,
    maxFuelLiters = 100,
    minFuelPrice = 1,
    maxFuelPrice = 100000,
    maxFuelConsumptionDelta = 15,
    minFuelPersistDelta = 0.5,
    minImpoundFee = 0,
    maxImpoundFee = 1000000,
    maxImpoundLocationLength = 64
}

local validKeyTypes = {
    owner = true,
    shared = true,
    temporary = true
}

local lockStates = {}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeLimit(value)
    local number = tonumber(value) or vehicleLimits.defaultListLimit

    if number < 1 then
        return vehicleLimits.defaultListLimit
    end

    return math.min(math.floor(number), vehicleLimits.maxListLimit)
end

local function normalizeText(value, fallback, maxLength)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function encodeJson(value)
    if type(value) ~= 'table' then
        return json.encode({})
    end

    return json.encode(value)
end

local function decodeJson(value)
    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)

    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function writeVehicleAudit(action, actor, vehicleId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'vehicle',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'vehicle',
        targetId = vehicleId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logVehicle(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info('nexa_api', message, metadata or {})
    end
end

local function hasGlobalPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function findOwnedVehicle(characterId, vehicleId)
    return MySQL.single.await([[
        SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name,
            fuel_level, engine_health, body_health, metadata
        FROM vehicles
        WHERE id = ? AND owner_character_id = ? AND deleted_at IS NULL
        LIMIT 1
    ]], {
        vehicleId,
        characterId
    })
end

local function findVehicle(vehicleId)
    return MySQL.single.await([[
        SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name,
            fuel_level, engine_health, body_health, metadata
        FROM vehicles
        WHERE id = ? AND deleted_at IS NULL
        LIMIT 1
    ]], {
        vehicleId
    })
end

local function findCharacter(characterId)
    return MySQL.single.await([[
        SELECT id, player_id, citizenid, is_active, deleted_at
        FROM characters
        WHERE id = ? AND is_active = TRUE AND deleted_at IS NULL
        LIMIT 1
    ]], {
        characterId
    })
end

local function cleanupExpiredVehicleKeys(vehicleId)
    local query = [[
        DELETE FROM vehicle_keys
        WHERE key_type = 'temporary' AND expires_at IS NOT NULL AND expires_at <= NOW()
    ]]
    local values = {}

    if vehicleId ~= nil then
        query = query .. ' AND vehicle_id = ?'
        values[#values + 1] = vehicleId
    end

    return MySQL.update.await(query, values) or 0
end

local function hasActiveKey(characterId, vehicleId)
    cleanupExpiredVehicleKeys(vehicleId)

    local vehicle = findVehicle(vehicleId)

    if vehicle == nil then
        return false, nil
    end

    if tonumber(vehicle.owner_character_id) == tonumber(characterId) then
        return true, vehicle
    end

    local keyId = MySQL.scalar.await([[
        SELECT id
        FROM vehicle_keys
        WHERE vehicle_id = ?
            AND character_id = ?
            AND (expires_at IS NULL OR expires_at > NOW())
        LIMIT 1
    ]], {
        vehicleId,
        characterId
    })

    return keyId ~= nil, vehicle
end

local function writeVehicleHistory(vehicleId, eventType, actorCharacterId, oldValue, newValue, reason)
    MySQL.insert.await([[
        INSERT INTO vehicle_history (vehicle_id, event_type, actor_character_id, old_value, new_value, reason)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        vehicleId,
        eventType,
        actorCharacterId,
        encodeJson(oldValue),
        encodeJson(newValue),
        reason
    })
end

local function normalizeKeyType(value)
    if type(value) ~= 'string' then
        return 'shared'
    end

    local keyType = value:lower()

    if not validKeyTypes[keyType] then
        return nil
    end

    return keyType
end

local function normalizeDurationMinutes(value)
    local duration = tonumber(value)

    if duration == nil then
        return nil
    end

    duration = math.floor(duration)

    if duration < vehicleLimits.minTemporaryMinutes or duration > vehicleLimits.maxTemporaryMinutes then
        return nil
    end

    return duration
end

local function normalizeReason(value, fallback)
    return normalizeText(value, fallback or 'vehicle.keys', vehicleLimits.maxReasonLength)
end

local function normalizePrice(value)
    local price = tonumber(value)

    if price == nil or price < vehicleLimits.minVehiclePrice or price > vehicleLimits.maxVehiclePrice then
        return nil
    end

    if math.floor(price) ~= price then
        return nil
    end

    return price
end

local function normalizeImpoundFee(value)
    local fee = tonumber(value) or 0

    if fee < vehicleLimits.minImpoundFee or fee > vehicleLimits.maxImpoundFee then
        return nil
    end

    if math.floor(fee) ~= fee then
        return nil
    end

    return fee
end

local function normalizeFuelLevel(value)
    local number = tonumber(value)

    if number == nil then
        return nil
    end

    if number < vehicleLimits.minFuelLevel or number > vehicleLimits.maxFuelLevel then
        return nil
    end

    return math.floor(number * 100 + 0.5) / 100
end

local function normalizeFuelDelta(value, maxValue)
    local number = tonumber(value)

    if number == nil or number <= 0 or number > maxValue then
        return nil
    end

    return math.floor(number * 100 + 0.5) / 100
end

local function generatePlate()
    for _ = 1, 20 do
        local plate = ('NX%06d'):format(math.random(0, 999999))
        local existing = MySQL.scalar.await('SELECT id FROM vehicles WHERE plate = ? LIMIT 1', {
            plate
        })

        if existing == nil then
            return plate
        end
    end

    return nil
end

local function validateCatalogItem(value)
    if type(value) ~= 'table' then
        return nil
    end

    local catalogId = normalizeText(value.id, nil, vehicleLimits.maxCatalogIdLength)
    local model = normalizeText(value.model, nil, vehicleLimits.maxModelLength)
    local label = normalizeText(value.label, model, vehicleLimits.maxModelLength)
    local vehicleType = normalizeText(value.vehicleType or value.vehicle_type, 'car', vehicleLimits.maxVehicleTypeLength)
    local price = normalizePrice(value.price)
    local garageName = normalizeText(value.garageName, 'stadtgarage', vehicleLimits.maxGarageNameLength)

    if catalogId == nil or model == nil or label == nil or vehicleType == nil or price == nil or garageName == nil then
        return nil
    end

    return {
        id = catalogId,
        model = model,
        label = label,
        vehicleType = vehicleType,
        price = price,
        garageName = garageName
    }
end

local function mapPurchasedVehicle(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        ownerCharacterId = row.owner_character_id,
        plate = row.plate,
        model = row.model,
        vehicleType = row.vehicle_type,
        status = row.status,
        garageName = row.garage_name
    }
end

local function ensureGarageState(vehicleId, fallbackGarageName)
    local state = MySQL.single.await([[
        SELECT vehicle_id, state, garage_name, stored_at, out_at
        FROM vehicle_garage_states
        WHERE vehicle_id = ?
        LIMIT 1
    ]], {
        vehicleId
    })

    if state ~= nil then
        return state
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO vehicle_garage_states (vehicle_id, state, garage_name, stored_at)
        VALUES (?, 'stored', ?, NOW())
    ]], {
        vehicleId,
        fallbackGarageName
    })

    return MySQL.single.await([[
        SELECT vehicle_id, state, garage_name, stored_at, out_at
        FROM vehicle_garage_states
        WHERE vehicle_id = ?
        LIMIT 1
    ]], {
        vehicleId
    })
end

local function formatVehicle(vehicle, state)
    return {
        id = vehicle.id,
        plate = vehicle.plate,
        model = vehicle.model,
        vehicleType = vehicle.vehicle_type,
        status = vehicle.status,
        garageName = state and state.garage_name or vehicle.garage_name,
        garageState = state and state.state or 'stored',
        fuelLevel = tonumber(vehicle.fuel_level) or 0,
        engineHealth = tonumber(vehicle.engine_health) or 0,
        bodyHealth = tonumber(vehicle.body_health) or 0
    }
end

function listGarageVehicles(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    payload = payload or {}

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Garagenabfrage.', nil, nil, nil)
    end

    local garageName = normalizeText(payload.garageName, nil, vehicleLimits.maxGarageNameLength)
    local limit = normalizeLimit(payload.limit)

    if garageName == nil and payload.garageName ~= nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Garage.', nil, nil, nil)
    end

    local query = [[
        SELECT v.id, v.owner_character_id, v.plate, v.model, v.vehicle_type, v.status, v.garage_name,
            v.fuel_level, v.engine_health, v.body_health, v.metadata,
            gs.state AS garage_state, gs.garage_name AS state_garage_name, gs.stored_at, gs.out_at
        FROM vehicles v
        LEFT JOIN vehicle_garage_states gs ON gs.vehicle_id = v.id
        WHERE v.owner_character_id = ? AND v.deleted_at IS NULL
            AND v.status NOT IN ('deleted')
    ]]
    local values = { actor.id }

    if garageName ~= nil then
        query = query .. ' AND (gs.garage_name = ? OR v.garage_name = ?)'
        values[#values + 1] = garageName
        values[#values + 1] = garageName
    end

    query = query .. ' ORDER BY v.updated_at DESC LIMIT ?'
    values[#values + 1] = limit

    local rows = MySQL.query.await(query, values) or {}
    local vehicles = {}

    for _, row in ipairs(rows) do
        vehicles[#vehicles + 1] = formatVehicle(row, {
            state = row.garage_state or 'stored',
            garage_name = row.state_garage_name or row.garage_name,
            stored_at = row.stored_at,
            out_at = row.out_at
        })
    end

    return respond(true, 'OK', 'Garagenliste wurde geladen.', {
        vehicles = vehicles
    }, {
        limit = limit,
        garageName = garageName
    }, nil)
end

function storeGarageVehicle(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fahrzeugdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local garageName = normalizeText(payload.garageName, 'stadtgarage', vehicleLimits.maxGarageNameLength)

    if vehicleId == nil or garageName == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fahrzeugdaten.', nil, nil, nil)
    end

    local vehicle = findOwnedVehicle(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NO_PERMISSION', 'Fahrzeug gehoert nicht zu deinem Charakter.', nil, nil, nil)
    end

    if vehicle.status == 'impounded' or vehicle.status == 'seized' or vehicle.status == 'deleted' then
        return respond(false, 'CONFLICT', 'Fahrzeugstatus erlaubt kein Einparken.', nil, nil, nil)
    end

    ensureGarageState(vehicleId, garageName)

    local updated = MySQL.update.await([[
        UPDATE vehicle_garage_states
        SET state = 'stored', garage_name = ?, stored_at = NOW(), out_at = NULL
        WHERE vehicle_id = ? AND state = 'out'
    ]], {
        garageName,
        vehicleId
    })

    if updated == nil or updated < 1 then
        return respond(false, 'CONFLICT', 'Fahrzeug ist nicht ausgeparkt oder wird bereits verarbeitet.', nil, nil, nil)
    end

    MySQL.update.await([[
        UPDATE vehicles
        SET status = 'stored', garage_name = ?
        WHERE id = ? AND owner_character_id = ?
    ]], {
        garageName,
        vehicleId,
        actor.id
    })

    MySQL.insert.await([[
        INSERT INTO vehicle_history (vehicle_id, event_type, actor_character_id, old_value, new_value, reason)
        VALUES (?, 'garage.store', ?, ?, ?, 'garage.store')
    ]], {
        vehicleId,
        actor.id,
        encodeJson({
            state = 'out'
        }),
        encodeJson({
            state = 'stored',
            garageName = garageName
        })
    })

    local auditId = writeVehicleAudit('vehicle.garage.store', actor, vehicleId, {
        garageName = garageName
    })
    logVehicle('Fahrzeug wurde eingeparkt.', {
        source = source,
        vehicleId = vehicleId,
        garageName = garageName
    })

    return respond(true, 'UPDATED', 'Fahrzeug wurde eingeparkt.', {
        vehicle = formatVehicle(findOwnedVehicle(actor.id, vehicleId), ensureGarageState(vehicleId, garageName))
    }, nil, auditId)
end

function retrieveGarageVehicle(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fahrzeugdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local garageName = normalizeText(payload.garageName, nil, vehicleLimits.maxGarageNameLength)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fahrzeugdaten.', nil, nil, nil)
    end

    local vehicle = findOwnedVehicle(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NO_PERMISSION', 'Fahrzeug gehoert nicht zu deinem Charakter.', nil, nil, nil)
    end

    if vehicle.status == 'impounded' or vehicle.status == 'seized' or vehicle.status == 'deleted' then
        return respond(false, 'CONFLICT', 'Fahrzeugstatus erlaubt kein Ausparken.', nil, nil, nil)
    end

    local state = ensureGarageState(vehicleId, garageName or vehicle.garage_name)

    if state == nil or state.state ~= 'stored' then
        return respond(false, 'CONFLICT', 'Fahrzeug ist nicht eingeparkt.', nil, nil, nil)
    end

    if garageName ~= nil and state.garage_name ~= nil and state.garage_name ~= garageName then
        return respond(false, 'CONFLICT', 'Fahrzeug steht in einer anderen Garage.', nil, nil, nil)
    end

    local updated = MySQL.update.await([[
        UPDATE vehicle_garage_states
        SET state = 'out', out_at = NOW()
        WHERE vehicle_id = ? AND state = 'stored'
    ]], {
        vehicleId
    })

    if updated == nil or updated < 1 then
        return respond(false, 'CONFLICT', 'Fahrzeug wird bereits ausgeparkt.', nil, nil, nil)
    end

    MySQL.update.await([[
        UPDATE vehicles
        SET status = 'active'
        WHERE id = ? AND owner_character_id = ?
    ]], {
        vehicleId,
        actor.id
    })

    MySQL.insert.await([[
        INSERT INTO vehicle_history (vehicle_id, event_type, actor_character_id, old_value, new_value, reason)
        VALUES (?, 'garage.retrieve', ?, ?, ?, 'garage.retrieve')
    ]], {
        vehicleId,
        actor.id,
        encodeJson({
            state = 'stored',
            garageName = state.garage_name
        }),
        encodeJson({
            state = 'out'
        })
    })

    local auditId = writeVehicleAudit('vehicle.garage.retrieve', actor, vehicleId, {
        garageName = state.garage_name
    })
    logVehicle('Fahrzeug wurde ausgeparkt.', {
        source = source,
        vehicleId = vehicleId,
        garageName = state.garage_name
    })

    return respond(true, 'UPDATED', 'Fahrzeug wurde ausgeparkt.', {
        vehicle = formatVehicle(findOwnedVehicle(actor.id, vehicleId), ensureGarageState(vehicleId, state.garage_name))
    }, nil, auditId)
end

function hasVehicleKey(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesselabfrage.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Fahrzeug.', nil, nil, nil)
    end

    local allowed, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du besitzt keinen Fahrzeugschluessel.', {
            hasKey = false
        }, nil, nil)
    end

    return respond(true, 'OK', 'Fahrzeugschluessel ist gueltig.', {
        hasKey = true,
        vehicle = formatVehicle(vehicle, ensureGarageState(vehicleId, vehicle.garage_name))
    }, nil, nil)
end

function grantVehicleKey(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesseldaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local targetCharacterId = normalizeId(payload.characterId)
    local keyType = normalizeKeyType(payload.keyType)
    local reason = normalizeReason(payload.reason, 'vehicle.key.grant')

    if vehicleId == nil or targetCharacterId == nil or keyType == nil or reason == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesseldaten.', nil, nil, nil)
    end

    local durationMinutes = nil

    if keyType == 'temporary' then
        durationMinutes = normalizeDurationMinutes(payload.durationMinutes)

        if durationMinutes == nil then
            return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesseldauer.', nil, nil, nil)
        end
    end

    local _, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if tonumber(vehicle.owner_character_id) ~= tonumber(actor.id) then
        return respond(false, 'NO_PERMISSION', 'Du darfst fuer dieses Fahrzeug keine Schluessel vergeben.', nil, nil, nil)
    end

    if findCharacter(targetCharacterId) == nil then
        return respond(false, 'NOT_FOUND', 'Zielcharakter wurde nicht gefunden.', nil, nil, nil)
    end

    local expiresExpression = 'NULL'
    local values = {
        vehicleId,
        targetCharacterId,
        keyType,
        actor.id
    }

    if keyType == 'temporary' then
        expiresExpression = 'DATE_ADD(NOW(), INTERVAL ? MINUTE)'
        values[#values + 1] = durationMinutes
    end

    MySQL.insert.await(([[
        INSERT INTO vehicle_keys (vehicle_id, character_id, key_type, granted_by_character_id, expires_at)
        VALUES (?, ?, ?, ?, %s)
        ON DUPLICATE KEY UPDATE granted_by_character_id = VALUES(granted_by_character_id),
            expires_at = VALUES(expires_at),
            created_at = NOW()
    ]]):format(expiresExpression), values)

    writeVehicleHistory(vehicleId, 'vehicle.key.grant', actor.id, {}, {
        characterId = targetCharacterId,
        keyType = keyType,
        durationMinutes = durationMinutes
    }, reason)

    local auditId = writeVehicleAudit('vehicle.key.grant', actor, vehicleId, {
        targetCharacterId = targetCharacterId,
        keyType = keyType,
        durationMinutes = durationMinutes,
        reason = reason
    })
    logVehicle('Fahrzeugschluessel wurde vergeben.', {
        source = source,
        vehicleId = vehicleId,
        targetCharacterId = targetCharacterId,
        keyType = keyType
    })

    return respond(true, 'CREATED', 'Fahrzeugschluessel wurde vergeben.', {
        vehicleId = vehicleId,
        characterId = targetCharacterId,
        keyType = keyType,
        temporary = keyType == 'temporary',
        durationMinutes = durationMinutes
    }, nil, auditId)
end

function revokeVehicleKey(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesseldaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local targetCharacterId = normalizeId(payload.characterId)
    local keyType = normalizeKeyType(payload.keyType or 'shared')
    local reason = normalizeReason(payload.reason, 'vehicle.key.revoke')

    if vehicleId == nil or targetCharacterId == nil or keyType == nil or reason == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Schluesseldaten.', nil, nil, nil)
    end

    local _, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if tonumber(vehicle.owner_character_id) ~= tonumber(actor.id) then
        return respond(false, 'NO_PERMISSION', 'Du darfst fuer dieses Fahrzeug keine Schluessel entziehen.', nil, nil, nil)
    end

    if keyType == 'owner' then
        return respond(false, 'CONFLICT', 'Besitzerschluessel koennen hier nicht entzogen werden.', nil, nil, nil)
    end

    local removed = MySQL.update.await([[
        DELETE FROM vehicle_keys
        WHERE vehicle_id = ? AND character_id = ? AND key_type = ?
    ]], {
        vehicleId,
        targetCharacterId,
        keyType
    }) or 0

    if removed < 1 then
        return respond(false, 'NOT_FOUND', 'Fahrzeugschluessel wurde nicht gefunden.', nil, nil, nil)
    end

    writeVehicleHistory(vehicleId, 'vehicle.key.revoke', actor.id, {
        characterId = targetCharacterId,
        keyType = keyType
    }, {}, reason)

    local auditId = writeVehicleAudit('vehicle.key.revoke', actor, vehicleId, {
        targetCharacterId = targetCharacterId,
        keyType = keyType,
        reason = reason
    })
    logVehicle('Fahrzeugschluessel wurde entzogen.', {
        source = source,
        vehicleId = vehicleId,
        targetCharacterId = targetCharacterId,
        keyType = keyType
    })

    return respond(true, 'UPDATED', 'Fahrzeugschluessel wurde entzogen.', {
        vehicleId = vehicleId,
        characterId = targetCharacterId,
        keyType = keyType
    }, nil, auditId)
end

function cleanupVehicleKeys()
    local removed = cleanupExpiredVehicleKeys(nil)
    local auditId = writeVehicleAudit('vehicle.key.cleanupExpired', nil, nil, {
        removed = removed
    })

    logVehicle('Abgelaufene temporaere Fahrzeugschluessel wurden entfernt.', {
        removed = removed
    })

    return respond(true, 'OK', 'Abgelaufene Fahrzeugschluessel wurden entfernt.', {
        removed = removed
    }, nil, auditId)
end

function toggleVehicleLock(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fahrzeugdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Fahrzeug.', nil, nil, nil)
    end

    local allowed, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du besitzt keinen Fahrzeugschluessel.', nil, nil, nil)
    end

    if vehicle.status == 'impounded' or vehicle.status == 'seized' or vehicle.status == 'deleted' then
        return respond(false, 'CONFLICT', 'Fahrzeugstatus erlaubt keine Schlossaktion.', nil, nil, nil)
    end

    local current = lockStates[vehicleId]
    local locked = not (current and current.locked == true)

    lockStates[vehicleId] = {
        locked = locked,
        updatedAt = os.time(),
        actorCharacterId = actor.id
    }

    local metadata = decodeJson(vehicle.metadata)
    metadata.locked = locked

    MySQL.update.await([[
        UPDATE vehicles
        SET metadata = ?, updated_at = NOW()
        WHERE id = ?
    ]], {
        encodeJson(metadata),
        vehicleId
    })

    writeVehicleHistory(vehicleId, locked and 'vehicle.lock' or 'vehicle.unlock', actor.id, {
        locked = not locked
    }, {
        locked = locked
    }, locked and 'vehicle.lock' or 'vehicle.unlock')

    local auditId = writeVehicleAudit(locked and 'vehicle.lock' or 'vehicle.unlock', actor, vehicleId, {
        locked = locked
    })

    return respond(true, 'UPDATED', locked and 'Fahrzeug wurde abgeschlossen.' or 'Fahrzeug wurde aufgeschlossen.', {
        vehicleId = vehicleId,
        locked = locked
    }, nil, auditId)
end

function purchaseDealerVehicle(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_vehicledealer' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur vom Fahrzeughaendler genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    local dealerId = normalizeText(payload.dealerId, nil, vehicleLimits.maxCatalogIdLength)
    local catalogItem = validateCatalogItem(payload.catalogItem)

    if dealerId == nil or catalogItem == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    local accountPayload = {
        accountId = payload.accountId,
        accountNumber = payload.accountNumber,
        amount = catalogItem.price,
        reason = ('Fahrzeugkauf: %s'):format(catalogItem.label),
        transactionPrefix = 'vehicle_purchase',
        resourceName = 'nexa_vehicledealer',
        metadata = {
            source = source,
            dealerId = dealerId,
            catalogId = catalogItem.id,
            model = catalogItem.model,
            label = catalogItem.label,
            garageName = catalogItem.garageName
        }
    }

    local result = NexaAccountExecuteVehiclePurchase(source, accountPayload, function(context)
        local plate = generatePlate()

        if plate == nil then
            return nil, 'CONFLICT', 'Es konnte kein eindeutiges Kennzeichen erzeugt werden.'
        end

        local vehicleId = MySQL.insert.await([[
            INSERT INTO vehicles (owner_character_id, plate, model, vehicle_type, status, garage_name, metadata)
            VALUES (?, ?, ?, ?, 'stored', ?, ?)
        ]], {
            context.actor.id,
            plate,
            catalogItem.model,
            catalogItem.vehicleType,
            catalogItem.garageName,
            encodeJson({
                dealerId = dealerId,
                catalogId = catalogItem.id,
                label = catalogItem.label,
                purchaseTransactionId = context.transactionId,
                purchaseLedgerId = context.ledgerId
            })
        })

        if vehicleId == nil then
            return nil, 'DATABASE_ERROR', 'Fahrzeug konnte nicht erstellt werden.'
        end

        MySQL.insert.await([[
            INSERT INTO vehicle_garage_states (vehicle_id, state, garage_name, stored_at)
            VALUES (?, 'stored', ?, NOW())
        ]], {
            vehicleId,
            catalogItem.garageName
        })

        MySQL.insert.await([[
            INSERT INTO vehicle_keys (vehicle_id, character_id, key_type, granted_by_character_id, expires_at)
            VALUES (?, ?, 'owner', ?, NULL)
        ]], {
            vehicleId,
            context.actor.id,
            context.actor.id
        })

        writeVehicleHistory(vehicleId, 'vehicle.dealer.purchase', context.actor.id, {}, {
            ownerCharacterId = context.actor.id,
            plate = plate,
            model = catalogItem.model,
            dealerId = dealerId,
            catalogId = catalogItem.id,
            price = context.amount,
            ledgerId = context.ledgerId
        }, 'vehicle.dealer.purchase')

        local vehicle = findOwnedVehicle(context.actor.id, vehicleId)

        return {
            vehicle = mapPurchasedVehicle(vehicle),
            key = {
                vehicleId = vehicleId,
                characterId = context.actor.id,
                keyType = 'owner'
            },
            garageState = {
                vehicleId = vehicleId,
                state = 'stored',
                garageName = catalogItem.garageName
            }
        }
    end)

    if type(result) == 'table' and result.success == true then
        local vehicle = result.data and result.data.vehicle or nil
        local auditId = writeVehicleAudit('vehicle.dealer.purchase', actor, vehicle and vehicle.id or nil, {
            dealerId = dealerId,
            catalogId = catalogItem.id,
            price = catalogItem.price
        })

        result.audit_id = result.audit_id or auditId

        logVehicle('Fahrzeug wurde ueber Haendler gekauft.', {
            source = source,
            dealerId = dealerId,
            catalogId = catalogItem.id,
            vehicleId = vehicle and vehicle.id or nil
        })
    end

    return result
end

function prepareDealerVehicleSale(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_vehicledealer' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur vom Fahrzeughaendler genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Fahrzeug.', nil, nil, nil)
    end

    local vehicle = findOwnedVehicle(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NO_PERMISSION', 'Fahrzeug gehoert nicht zu deinem Charakter.', nil, nil, nil)
    end

    return respond(true, 'OK', 'Fahrzeugverkauf ist vorbereitet, aber noch nicht aktiviert.', {
        vehicle = formatVehicle(vehicle, ensureGarageState(vehicleId, vehicle.garage_name)),
        salePrepared = false
    }, {
        mutatesState = false
    }, nil)
end

function getVehicleFuel(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Tankstandabfrage.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Fahrzeug.', nil, nil, nil)
    end

    local allowed, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du besitzt keinen Zugriff auf dieses Fahrzeug.', nil, nil, nil)
    end

    return respond(true, 'OK', 'Tankstand wurde geladen.', {
        vehicleId = vehicleId,
        fuelLevel = tonumber(vehicle.fuel_level) or 0
    }, nil, nil)
end

function purchaseVehicleFuel(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_fuel' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur vom Kraftstoffsystem genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Tankdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local liters = normalizeFuelDelta(payload.liters, vehicleLimits.maxFuelLiters)
    local pricePerLiter = normalizePrice(payload.pricePerLiter)
    local stationId = normalizeText(payload.stationId, nil, vehicleLimits.maxCatalogIdLength)

    if vehicleId == nil or liters == nil or pricePerLiter == nil or stationId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Tankdaten.', nil, nil, nil)
    end

    local allowed, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du besitzt keinen Zugriff auf dieses Fahrzeug.', nil, nil, nil)
    end

    if vehicle.status == 'impounded' or vehicle.status == 'seized' or vehicle.status == 'deleted' then
        return respond(false, 'CONFLICT', 'Fahrzeugstatus erlaubt keinen Tankvorgang.', nil, nil, nil)
    end

    local currentFuel = tonumber(vehicle.fuel_level) or 0
    local targetFuel = math.min(vehicleLimits.maxFuelLevel, currentFuel + liters)
    local appliedLiters = math.floor((targetFuel - currentFuel) * 100 + 0.5) / 100

    if appliedLiters < vehicleLimits.minFuelLiters then
        return respond(false, 'CONFLICT', 'Der Tank ist bereits ausreichend voll.', nil, nil, nil)
    end

    local accountPayload = {
        accountId = payload.accountId,
        accountNumber = payload.accountNumber,
        reason = ('Kraftstoff: %.2f Liter'):format(appliedLiters),
        transactionPrefix = 'fuel_purchase',
        resourceName = 'nexa_fuel',
        metadata = {
            source = source,
            vehicleId = vehicleId,
            stationId = stationId,
            liters = appliedLiters,
            pricePerLiter = pricePerLiter,
            oldFuelLevel = currentFuel,
            newFuelLevel = targetFuel
        }
    }

    local result = NexaAccountExecuteFuelPurchase(source, accountPayload, function(context)
        if context.stage == 'prepare' then
            local lockedVehicle = MySQL.single.await([[
                SELECT id, owner_character_id, fuel_level, status
                FROM vehicles
                WHERE id = ? AND deleted_at IS NULL
                LIMIT 1
                FOR UPDATE
            ]], {
                vehicleId
            })

            if lockedVehicle == nil then
                return nil, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.'
            end

            if lockedVehicle.status == 'impounded' or lockedVehicle.status == 'seized' or lockedVehicle.status == 'deleted' then
                return nil, 'CONFLICT', 'Fahrzeugstatus erlaubt keinen Tankvorgang.'
            end

            local lockedFuel = tonumber(lockedVehicle.fuel_level) or 0
            local lockedTargetFuel = math.min(vehicleLimits.maxFuelLevel, lockedFuel + liters)
            local lockedAppliedLiters = math.floor((lockedTargetFuel - lockedFuel) * 100 + 0.5) / 100

            if lockedAppliedLiters < vehicleLimits.minFuelLiters then
                return nil, 'CONFLICT', 'Der Tank ist bereits ausreichend voll.'
            end

            local lockedAmount = math.floor((lockedAppliedLiters * pricePerLiter) + 0.5)

            return {
                vehicleId = vehicleId,
                oldFuelLevel = lockedFuel,
                fuelLevel = lockedTargetFuel,
                liters = lockedAppliedLiters,
                stationId = stationId,
                amount = lockedAmount,
                reason = ('Kraftstoff: %.2f Liter'):format(lockedAppliedLiters),
                metadata = {
                    source = source,
                    vehicleId = vehicleId,
                    stationId = stationId,
                    liters = lockedAppliedLiters,
                    pricePerLiter = pricePerLiter,
                    oldFuelLevel = lockedFuel,
                    newFuelLevel = lockedTargetFuel
                }
            }
        end

        local plan = context.plan

        if type(plan) ~= 'table' or tonumber(plan.vehicleId) ~= vehicleId then
            return nil, 'INVALID_INPUT', 'Tankvorgang konnte nicht gespeichert werden.'
        end

        local lockedVehicle = MySQL.single.await([[
            SELECT id, owner_character_id, fuel_level, status
            FROM vehicles
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if lockedVehicle == nil then
            return nil, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.'
        end

        if lockedVehicle.status == 'impounded' or lockedVehicle.status == 'seized' or lockedVehicle.status == 'deleted' then
            return nil, 'CONFLICT', 'Fahrzeugstatus erlaubt keinen Tankvorgang.'
        end

        local lockedFuel = tonumber(lockedVehicle.fuel_level) or 0
        local lockedTargetFuel = tonumber(plan.fuelLevel)
        local lockedAppliedLiters = math.floor((lockedTargetFuel - lockedFuel) * 100 + 0.5) / 100

        if lockedTargetFuel == nil or lockedAppliedLiters < vehicleLimits.minFuelLiters or math.abs(lockedAppliedLiters - tonumber(plan.liters)) > 0.01 then
            return nil, 'CONFLICT', 'Tankstand hat sich waehrend des Vorgangs geaendert.'
        end

        local updated = MySQL.update.await([[
            UPDATE vehicles
            SET fuel_level = ?, updated_at = NOW()
            WHERE id = ?
        ]], {
            lockedTargetFuel,
            vehicleId
        })

        if updated ~= 1 then
            return nil, 'DATABASE_ERROR', 'Tankstand konnte nicht gespeichert werden.'
        end

        writeVehicleHistory(vehicleId, 'vehicle.fuel.purchase', context.actor.id, {
            fuelLevel = lockedFuel
        }, {
            fuelLevel = lockedTargetFuel,
            liters = lockedAppliedLiters,
            ledgerId = context.ledgerId,
            stationId = stationId
        }, 'vehicle.fuel.purchase')

        return {
            vehicleId = vehicleId,
            oldFuelLevel = lockedFuel,
            fuelLevel = lockedTargetFuel,
            liters = lockedAppliedLiters,
            stationId = stationId,
            amount = context.amount,
            ledgerId = context.ledgerId
        }
    end)

    if type(result) == 'table' and result.success == true then
        local auditId = writeVehicleAudit('vehicle.fuel.purchase', actor, vehicleId, {
            stationId = stationId,
            liters = result.data and result.data.fuel and result.data.fuel.liters or appliedLiters,
            amount = result.data and result.data.ledger and result.data.ledger.amount or nil
        })

        result.audit_id = result.audit_id or auditId

        logVehicle('Fahrzeug wurde betankt.', {
            source = source,
            vehicleId = vehicleId,
            stationId = stationId
        })
    end

    return result
end

function applyVehicleFuelConsumption(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_fuel' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur vom Kraftstoffsystem genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verbrauchsdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local consumed = normalizeFuelDelta(payload.consumed, vehicleLimits.maxFuelConsumptionDelta)

    if vehicleId == nil or consumed == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verbrauchsdaten.', nil, nil, nil)
    end

    local allowed, vehicle = hasActiveKey(actor.id, vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du besitzt keinen Zugriff auf dieses Fahrzeug.', nil, nil, nil)
    end

    MySQL.query.await('START TRANSACTION')

    local success, result = pcall(function()
        local lockedVehicle = MySQL.single.await([[
            SELECT id, fuel_level, status
            FROM vehicles
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if lockedVehicle == nil then
            error(json.encode({
                code = 'NOT_FOUND',
                message = 'Fahrzeug wurde nicht gefunden.'
            }), 0)
        end

        local oldFuel = tonumber(lockedVehicle.fuel_level) or 0
        local newFuel = math.max(vehicleLimits.minFuelLevel, oldFuel - consumed)
        local actualDelta = math.floor((oldFuel - newFuel) * 100 + 0.5) / 100

        if actualDelta < vehicleLimits.minFuelPersistDelta then
            return {
                persisted = false,
                vehicleId = vehicleId,
                oldFuelLevel = oldFuel,
                fuelLevel = oldFuel,
                consumed = 0
            }
        end

        local updated = MySQL.update.await([[
            UPDATE vehicles
            SET fuel_level = ?, updated_at = NOW()
            WHERE id = ?
        ]], {
            newFuel,
            vehicleId
        })

        if updated ~= 1 then
            error(json.encode({
                code = 'DATABASE_ERROR',
                message = 'Tankstand konnte nicht fortgeschrieben werden.'
            }), 0)
        end

        writeVehicleHistory(vehicleId, 'vehicle.fuel.consume', actor.id, {
            fuelLevel = oldFuel
        }, {
            fuelLevel = newFuel,
            consumed = actualDelta,
            serverValidated = true
        }, 'vehicle.fuel.consume')

        return {
            persisted = true,
            vehicleId = vehicleId,
            oldFuelLevel = oldFuel,
            fuelLevel = newFuel,
            consumed = actualDelta
        }
    end)

    if success then
        MySQL.query.await('COMMIT')
    else
        MySQL.query.await('ROLLBACK')
        local errorData = nil

        if type(result) == 'string' then
            local decodeOk, decoded = pcall(json.decode, result)

            if decodeOk and type(decoded) == 'table' then
                errorData = decoded
            end
        end

        return respond(false, errorData and errorData.code or 'DATABASE_ERROR', errorData and errorData.message or 'Tankstand konnte nicht fortgeschrieben werden.', nil, nil, nil)
    end

    if result.persisted ~= true then
        return respond(true, 'OK', 'Verbrauch wurde vorbereitet, aber nicht persistiert.', {
            vehicleId = vehicleId,
            fuelLevel = result.fuelLevel,
            persisted = false
        }, {
            minPersistDelta = vehicleLimits.minFuelPersistDelta
        }, nil)
    end

    return respond(true, 'UPDATED', 'Verbrauch wurde gespeichert.', {
        vehicleId = vehicleId,
        oldFuelLevel = result.oldFuelLevel,
        fuelLevel = result.fuelLevel,
        consumed = result.consumed,
        persisted = true
    }, nil, writeVehicleAudit('vehicle.fuel.consume', actor, vehicleId, {
        consumed = result.consumed,
        fuelLevel = result.fuelLevel
    }))
end

local function canManageImpound(source)
    return hasGlobalPermission(source, 'impound.create')
        or hasGlobalPermission(source, 'impound.manage')
        or hasGlobalPermission(source, 'admin.impound')
end

local function canViewImpound(source)
    return canManageImpound(source)
        or hasGlobalPermission(source, 'impound.status')
        or hasGlobalPermission(source, 'impound.audit')
end

local function canReleaseForeignImpound(source)
    return hasGlobalPermission(source, 'impound.release')
        or hasGlobalPermission(source, 'impound.manage')
        or hasGlobalPermission(source, 'admin.impound')
end

local function mapImpoundVehicle(vehicle, state, fine)
    return {
        id = vehicle.id,
        ownerCharacterId = vehicle.owner_character_id,
        plate = vehicle.plate,
        model = vehicle.model,
        vehicleType = vehicle.vehicle_type,
        status = vehicle.status,
        garageState = state and state.state or vehicle.status,
        garageName = state and state.garage_name or vehicle.garage_name,
        reason = state and state.impound_reason or nil,
        fine = fine
    }
end

local function getOpenImpoundFine(vehicleId)
    return MySQL.single.await([[
        SELECT id, vehicle_id, character_id, amount, status, reason, ledger_id, created_at, paid_at
        FROM vehicle_fines
        WHERE vehicle_id = ? AND fine_type = 'impound' AND status = 'open'
        ORDER BY created_at DESC, id DESC
        LIMIT 1
    ]], {
        vehicleId
    })
end

function getImpoundStatus(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verwahrungsabfrage.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Fahrzeug.', nil, nil, nil)
    end

    local vehicle = findVehicle(vehicleId)

    if vehicle == nil then
        return respond(false, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.', nil, nil, nil)
    end

    if tonumber(vehicle.owner_character_id) ~= tonumber(actor.id) and not canViewImpound(source) then
        return respond(false, 'NO_PERMISSION', 'Du darfst diesen Verwahrungsstatus nicht einsehen.', nil, nil, nil)
    end

    local state = ensureGarageState(vehicleId, vehicle.garage_name)
    local fine = getOpenImpoundFine(vehicleId)

    return respond(true, 'OK', 'Verwahrungsstatus wurde geladen.', {
        vehicle = mapImpoundVehicle(vehicle, state, fine),
        isImpounded = vehicle.status == 'impounded' or state.state == 'impounded',
        fee = fine and fine.amount or 0
    }, nil, nil)
end

function impoundVehicle(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_impound' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur von der Verwahrung genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not canManageImpound(source) then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verwahrungsdaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local fee = normalizeImpoundFee(payload.fee)
    local reason = normalizeReason(payload.reason, 'vehicle.impound')
    local location = normalizeText(payload.location, 'standard', vehicleLimits.maxImpoundLocationLength)

    if vehicleId == nil or fee == nil or reason == nil or location == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Verwahrungsdaten.', nil, nil, nil)
    end

    MySQL.query.await('START TRANSACTION')

    local success, result = pcall(function()
        local vehicle = MySQL.single.await([[
            SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name
            FROM vehicles
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if vehicle == nil then
            error(json.encode({
                code = 'NOT_FOUND',
                message = 'Fahrzeug wurde nicht gefunden.'
            }), 0)
        end

        if vehicle.status == 'impounded' or vehicle.status == 'seized' or vehicle.status == 'deleted' then
            error(json.encode({
                code = 'CONFLICT',
                message = 'Fahrzeugstatus erlaubt keine Verwahrung.'
            }), 0)
        end

        MySQL.insert.await([[
            INSERT IGNORE INTO vehicle_garage_states (vehicle_id, state, garage_name, stored_at)
            VALUES (?, 'stored', ?, NOW())
        ]], {
            vehicleId,
            vehicle.garage_name
        })

        local state = MySQL.single.await([[
            SELECT id, state, garage_name, impound_reason
            FROM vehicle_garage_states
            WHERE vehicle_id = ?
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if state ~= nil and (state.state == 'impounded' or state.state == 'seized') then
            error(json.encode({
                code = 'CONFLICT',
                message = 'Fahrzeug ist bereits verwahrt.'
            }), 0)
        end

        local updatedVehicle = MySQL.update.await([[
            UPDATE vehicles
            SET status = 'impounded', updated_at = NOW()
            WHERE id = ? AND status NOT IN ('impounded', 'seized', 'deleted')
        ]], {
            vehicleId
        })

        if updatedVehicle ~= 1 then
            error(json.encode({
                code = 'CONFLICT',
                message = 'Fahrzeug wird bereits verarbeitet.'
            }), 0)
        end

        MySQL.update.await([[
            UPDATE vehicle_garage_states
            SET state = 'impounded', garage_name = ?, impound_reason = ?, stored_at = NULL, out_at = NULL
            WHERE vehicle_id = ?
        ]], {
            location,
            reason,
            vehicleId
        })

        local fineId = nil

        if fee > 0 then
            fineId = MySQL.insert.await([[
                INSERT INTO vehicle_fines (vehicle_id, character_id, fine_type, amount, status, reason, created_by_character_id, metadata)
                VALUES (?, ?, 'impound', ?, 'open', ?, ?, ?)
            ]], {
                vehicleId,
                vehicle.owner_character_id,
                fee,
                reason,
                actor.id,
                encodeJson({
                    location = location,
                    resource = 'nexa_impound'
                })
            })
        end

        writeVehicleHistory(vehicleId, 'vehicle.impound', actor.id, {
            status = vehicle.status,
            state = state and state.state or nil
        }, {
            status = 'impounded',
            state = 'impounded',
            fee = fee,
            fineId = fineId,
            location = location
        }, reason)

        return {
            vehicleId = vehicleId,
            oldStatus = vehicle.status,
            status = 'impounded',
            fee = fee,
            fineId = fineId,
            location = location,
            reason = reason
        }
    end)

    if success then
        MySQL.query.await('COMMIT')
    else
        MySQL.query.await('ROLLBACK')

        local code = 'DATABASE_ERROR'
        local message = 'Fahrzeug konnte nicht verwahrt werden.'

        if type(result) == 'string' then
            local ok, decoded = pcall(json.decode, result)

            if ok and type(decoded) == 'table' then
                code = decoded.code or code
                message = decoded.message or message
            end
        end

        return respond(false, code, message, nil, nil, nil)
    end

    local auditId = writeVehicleAudit('vehicle.impound', actor, vehicleId, {
        fee = fee,
        location = location,
        reason = reason
    })

    logVehicle('Fahrzeug wurde verwahrt.', {
        source = source,
        vehicleId = vehicleId,
        fee = fee,
        location = location
    })

    return respond(true, 'UPDATED', 'Fahrzeug wurde verwahrt.', {
        impound = result
    }, nil, auditId)
end

local function releaseImpoundWithoutFee(source, actor, vehicleId, reason, releaseGarageName)
    MySQL.query.await('START TRANSACTION')

    local success, result = pcall(function()
        local vehicle = MySQL.single.await([[
            SELECT id, owner_character_id, plate, model, vehicle_type, status, garage_name
            FROM vehicles
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if vehicle == nil then
            error(json.encode({
                code = 'NOT_FOUND',
                message = 'Fahrzeug wurde nicht gefunden.'
            }), 0)
        end

        if tonumber(vehicle.owner_character_id) ~= tonumber(actor.id) and not canReleaseForeignImpound(source) then
            error(json.encode({
                code = 'NO_PERMISSION',
                message = 'Du darfst dieses Fahrzeug nicht freigeben.'
            }), 0)
        end

        if vehicle.status ~= 'impounded' then
            error(json.encode({
                code = 'CONFLICT',
                message = 'Fahrzeug ist nicht verwahrt.'
            }), 0)
        end

        local openFine = getOpenImpoundFine(vehicleId)

        if openFine ~= nil and tonumber(openFine.amount) > 0 then
            error(json.encode({
                code = 'INSUFFICIENT_FUNDS',
                message = 'Vor der Freigabe muss die Verwahrungsgebuehr bezahlt werden.'
            }), 0)
        end

        local updated = MySQL.update.await([[
            UPDATE vehicles
            SET status = 'stored', garage_name = ?, updated_at = NOW()
            WHERE id = ? AND status = 'impounded'
        ]], {
            releaseGarageName,
            vehicleId
        })

        if updated ~= 1 then
            error(json.encode({
                code = 'CONFLICT',
                message = 'Fahrzeug wird bereits freigegeben.'
            }), 0)
        end

        MySQL.update.await([[
            UPDATE vehicle_garage_states
            SET state = 'stored', garage_name = ?, impound_reason = NULL, stored_at = NOW(), out_at = NULL
            WHERE vehicle_id = ?
        ]], {
            releaseGarageName,
            vehicleId
        })

        writeVehicleHistory(vehicleId, 'vehicle.impound.release', actor.id, {
            status = 'impounded'
        }, {
            status = 'stored',
            fee = 0,
            garageName = releaseGarageName
        }, reason)

        return {
            vehicleId = vehicleId,
            status = 'stored',
            fee = 0,
            garageName = releaseGarageName
        }
    end)

    if success then
        MySQL.query.await('COMMIT')
        return result
    end

    MySQL.query.await('ROLLBACK')
    local code = 'DATABASE_ERROR'
    local message = 'Fahrzeug konnte nicht freigegeben werden.'

    if type(result) == 'string' then
        local ok, decoded = pcall(json.decode, result)

        if ok and type(decoded) == 'table' then
            code = decoded.code or code
            message = decoded.message or message
        end
    end

    return nil, code, message
end

function releaseImpoundVehicle(source, payload)
    local invokingResource = GetInvokingResource()

    if invokingResource ~= nil and invokingResource ~= 'nexa_impound' and invokingResource ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Fahrzeug-API darf nur von der Verwahrung genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Freigabedaten.', nil, nil, nil)
    end

    local vehicleId = normalizeId(payload.vehicleId)
    local expectedFee = normalizeImpoundFee(payload.fee)
    local reason = normalizeReason(payload.reason, 'vehicle.impound.release')
    local releaseGarageName = normalizeText(payload.garageName, 'stadtgarage', vehicleLimits.maxGarageNameLength)

    if vehicleId == nil or expectedFee == nil or reason == nil or releaseGarageName == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Freigabedaten.', nil, nil, nil)
    end

    if expectedFee <= 0 then
        local release, releaseCode, releaseMessage = releaseImpoundWithoutFee(source, actor, vehicleId, reason, releaseGarageName)

        if release == nil then
            return respond(false, releaseCode, releaseMessage, nil, nil, nil)
        end

        local auditId = writeVehicleAudit('vehicle.impound.release', actor, vehicleId, {
            fee = 0,
            garageName = releaseGarageName
        })

        return respond(true, 'UPDATED', 'Fahrzeug wurde freigegeben.', {
            release = release
        }, nil, auditId)
    end

    local accountPayload = {
        accountId = payload.accountId,
        accountNumber = payload.accountNumber,
        reason = ('Verwahrungsgebuehr: Fahrzeug %d'):format(vehicleId),
        transactionPrefix = 'impound_release',
        resourceName = 'nexa_impound',
        metadata = {
            source = source,
            vehicleId = vehicleId,
            expectedFee = expectedFee
        }
    }

    local result = NexaAccountExecuteImpoundRelease(source, accountPayload, function(context)
        if context.stage == 'prepare' then
            local vehicle = MySQL.single.await([[
                SELECT id, owner_character_id, status, garage_name
                FROM vehicles
                WHERE id = ? AND deleted_at IS NULL
                LIMIT 1
                FOR UPDATE
            ]], {
                vehicleId
            })

            if vehicle == nil then
                return nil, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.'
            end

            if tonumber(vehicle.owner_character_id) ~= tonumber(context.actor.id) and not canReleaseForeignImpound(source) then
                return nil, 'NO_PERMISSION', 'Du darfst dieses Fahrzeug nicht freigeben.'
            end

            if vehicle.status ~= 'impounded' then
                return nil, 'CONFLICT', 'Fahrzeug ist nicht verwahrt.'
            end

            local fine = getOpenImpoundFine(vehicleId)

            if fine == nil or tonumber(fine.amount) <= 0 then
                return nil, 'CONFLICT', 'Fuer dieses Fahrzeug ist keine offene Verwahrungsgebuehr vorhanden.'
            end

            if tonumber(fine.amount) ~= expectedFee then
                return nil, 'CONFLICT', 'Die Verwahrungsgebuehr hat sich geaendert.'
            end

            return {
                vehicleId = vehicleId,
                fineId = fine.id,
                amount = tonumber(fine.amount),
                reason = reason,
                garageName = releaseGarageName,
                metadata = {
                    source = source,
                    vehicleId = vehicleId,
                    fineId = fine.id,
                    garageName = releaseGarageName
                }
            }
        end

        local plan = context.plan

        if type(plan) ~= 'table' or tonumber(plan.vehicleId) ~= vehicleId or tonumber(plan.amount) ~= expectedFee then
            return nil, 'INVALID_INPUT', 'Freigabe konnte nicht gespeichert werden.'
        end

        local vehicle = MySQL.single.await([[
            SELECT id, owner_character_id, status, garage_name
            FROM vehicles
            WHERE id = ? AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
        ]], {
            vehicleId
        })

        if vehicle == nil then
            return nil, 'NOT_FOUND', 'Fahrzeug wurde nicht gefunden.'
        end

        if vehicle.status ~= 'impounded' then
            return nil, 'CONFLICT', 'Fahrzeug ist nicht verwahrt.'
        end

        local fine = getOpenImpoundFine(vehicleId)

        if fine == nil or tonumber(fine.id) ~= tonumber(plan.fineId) or tonumber(fine.amount) ~= expectedFee then
            return nil, 'CONFLICT', 'Die Verwahrungsgebuehr ist nicht mehr offen.'
        end

        local updated = MySQL.update.await([[
            UPDATE vehicles
            SET status = 'stored', garage_name = ?, updated_at = NOW()
            WHERE id = ? AND status = 'impounded'
        ]], {
            releaseGarageName,
            vehicleId
        })

        if updated ~= 1 then
            return nil, 'CONFLICT', 'Fahrzeug wird bereits freigegeben.'
        end

        MySQL.update.await([[
            UPDATE vehicle_garage_states
            SET state = 'stored', garage_name = ?, impound_reason = NULL, stored_at = NOW(), out_at = NULL
            WHERE vehicle_id = ?
        ]], {
            releaseGarageName,
            vehicleId
        })

        local fineUpdated = MySQL.update.await([[
            UPDATE vehicle_fines
            SET status = 'paid', paid_at = NOW(), ledger_id = ?
            WHERE id = ? AND status = 'open'
        ]], {
            context.ledgerId,
            plan.fineId
        })

        if fineUpdated ~= 1 then
            return nil, 'CONFLICT', 'Die Verwahrungsgebuehr konnte nicht geschlossen werden.'
        end

        writeVehicleHistory(vehicleId, 'vehicle.impound.release', context.actor.id, {
            status = 'impounded',
            fineId = plan.fineId
        }, {
            status = 'stored',
            fee = expectedFee,
            fineId = plan.fineId,
            ledgerId = context.ledgerId,
            garageName = releaseGarageName
        }, reason)

        return {
            vehicleId = vehicleId,
            status = 'stored',
            amount = expectedFee,
            fineId = plan.fineId,
            ledgerId = context.ledgerId,
            garageName = releaseGarageName
        }
    end)

    if type(result) == 'table' and result.success == true then
        local auditId = writeVehicleAudit('vehicle.impound.release', actor, vehicleId, {
            fee = expectedFee,
            garageName = releaseGarageName,
            ledgerId = result.data and result.data.ledger and result.data.ledger.id or nil
        })

        result.audit_id = result.audit_id or auditId

        logVehicle('Fahrzeug wurde aus Verwahrung freigegeben.', {
            source = source,
            vehicleId = vehicleId,
            fee = expectedFee
        })
    end

    return result
end

function reconcileGarageStates()
    local updatedStates = MySQL.update.await([[
        UPDATE vehicle_garage_states gs
        JOIN vehicles v ON v.id = gs.vehicle_id
        SET gs.state = 'stored',
            gs.stored_at = NOW(),
            gs.out_at = NULL,
            v.status = 'stored'
        WHERE gs.state = 'out'
            AND v.status = 'active'
            AND v.deleted_at IS NULL
    ]]) or 0

    local auditId = writeVehicleAudit('vehicle.garage.reconcileRestart', nil, nil, {
        updatedStates = updatedStates
    })

    logVehicle('Garagenstatus wurde nach Restart abgeglichen.', {
        updatedStates = updatedStates
    })

    return respond(true, 'OK', 'Garagenstatus wurde abgeglichen.', {
        updatedStates = updatedStates
    }, {
        restartSafe = true
    }, auditId)
end

exports('vehicle.listGarage', listGarageVehicles)
exports('vehicle.storeGarage', storeGarageVehicle)
exports('vehicle.retrieveGarage', retrieveGarageVehicle)
exports('vehicle.reconcileGarage', reconcileGarageStates)
exports('vehicle.hasKey', hasVehicleKey)
exports('vehicle.grantKey', grantVehicleKey)
exports('vehicle.revokeKey', revokeVehicleKey)
exports('vehicle.cleanupExpiredKeys', cleanupVehicleKeys)
exports('vehicle.toggleLock', toggleVehicleLock)
exports('vehicle.purchaseDealer', purchaseDealerVehicle)
exports('vehicle.prepareDealerSale', prepareDealerVehicleSale)
exports('vehicle.getFuel', getVehicleFuel)
exports('vehicle.purchaseFuel', purchaseVehicleFuel)
exports('vehicle.consumeFuel', applyVehicleFuelConsumption)
exports('vehicle.getImpoundStatus', getImpoundStatus)
exports('vehicle.impound', impoundVehicle)
exports('vehicle.releaseImpound', releaseImpoundVehicle)
