local propertyLimits = {
    defaultListLimit = 25,
    maxListLimit = 50,
    maxCodeLength = 32,
    maxTextLength = 64,
    maxReasonLength = 128,
    maxTemporaryMinutes = 43200,
    defaultStorageSlots = 40,
    defaultStorageWeight = 120000,
    maxFurniturePerUnit = 100,
    maxFurnitureModelLength = 64,
    maxFurnitureDistance = 120.0,
    minWorldZ = -200.0,
    maxWorldZ = 2000.0,
    maxWorldCoordinate = 10000.0,
    minPrice = 0,
    maxPrice = 100000000
}

local validStatuses = {
    available = true,
    owned = true,
    rented = true,
    locked = true,
    disabled = true
}

local validAccessTypes = {
    owner = true,
    tenant = true,
    guest = true,
    temporary = true
}

local validStorageTypes = {
    private = true,
    shared = true
}

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
    local number = tonumber(value) or propertyLimits.defaultListLimit

    if number < 1 then
        return propertyLimits.defaultListLimit
    end

    return math.min(math.floor(number), propertyLimits.maxListLimit)
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

local function normalizePrice(value)
    local price = tonumber(value)

    if price == nil or price < propertyLimits.minPrice or price > propertyLimits.maxPrice then
        return nil
    end

    if math.floor(price) ~= price then
        return nil
    end

    return price
end

local function normalizeStorageType(value)
    local storageType = normalizeText(value, 'private', propertyLimits.maxTextLength)

    if storageType == nil or not validStorageTypes[storageType] then
        return nil
    end

    return storageType
end

local function normalizeFurnitureModel(value)
    local model = normalizeText(value, nil, propertyLimits.maxFurnitureModelLength)

    if model == nil or not model:match('^[%w_%-]+$') then
        return nil
    end

    return model
end

local function normalizeVector(value, isRotation)
    if type(value) ~= 'table' then
        return nil
    end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)

    if x == nil or y == nil or z == nil then
        return nil
    end

    if x ~= x or y ~= y or z ~= z then
        return nil
    end

    if isRotation then
        if math.abs(x) > 360.0 or math.abs(y) > 360.0 or math.abs(z) > 360.0 then
            return nil
        end
    else
        if math.abs(x) > propertyLimits.maxWorldCoordinate
            or math.abs(y) > propertyLimits.maxWorldCoordinate
            or z < propertyLimits.minWorldZ
            or z > propertyLimits.maxWorldZ
        then
            return nil
        end
    end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function getFurnitureBounds(unit)
    local metadata = unit and unit.metadata or {}
    local furniture = type(metadata.furniture) == 'table' and metadata.furniture or {}
    local bounds = type(furniture.bounds) == 'table' and furniture.bounds or nil

    if bounds == nil then
        bounds = type(metadata.furnitureBounds) == 'table' and metadata.furnitureBounds or nil
    end

    if bounds == nil then
        return nil
    end

    local center = normalizeVector(bounds.center, false)
    local radius = tonumber(bounds.radius)

    if center == nil or radius == nil or radius <= 0 or radius > propertyLimits.maxFurnitureDistance then
        return nil
    end

    return center, radius
end

local function isFurniturePositionPlausible(unit, position)
    local center, radius = getFurnitureBounds(unit)

    if center == nil then
        return false
    end

    local dx = position.x - center.x
    local dy = position.y - center.y
    local dz = position.z - center.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    return distance <= radius
end

local function normalizeDurationMinutes(value)
    local minutes = tonumber(value)

    if minutes == nil then
        return nil
    end

    minutes = math.floor(minutes)

    if minutes < 1 or minutes > propertyLimits.maxTemporaryMinutes then
        return nil
    end

    return minutes
end

local function normalizeExpiresAt(value)
    if value == nil then
        return nil
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return nil
    end

    if not trimmed:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$') then
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

local function writePropertyAudit(action, actor, propertyUnitId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'property',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'property_unit',
        targetId = propertyUnitId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logProperty(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NEXA_API.resourceName, message, metadata or {})
    end
end

local function mapUnit(row)
    if row == nil then
        return nil
    end

    local metadata = decodeJson(row.unit_metadata)

    return {
        id = row.unit_id,
        propertyId = row.property_id,
        propertyCode = row.property_code,
        unitCode = row.unit_code,
        name = row.property_name,
        label = row.unit_label,
        propertyType = row.property_type,
        propertyStatus = row.property_status,
        status = row.unit_status,
        ownerCharacterId = row.owner_character_id,
        price = tonumber(metadata.price) or 0,
        rent = tonumber(metadata.rent) or 0,
        metadata = metadata
    }
end

local function findUnit(propertyUnitId, forUpdate)
    local lock = forUpdate and ' FOR UPDATE' or ''

    return mapUnit(MySQL.single.await(([[
        SELECT
            p.id AS property_id,
            p.property_code,
            p.name AS property_name,
            p.property_type,
            p.status AS property_status,
            u.id AS unit_id,
            u.unit_code,
            u.owner_character_id,
            u.label AS unit_label,
            u.status AS unit_status,
            u.metadata AS unit_metadata
        FROM property_units u
        JOIN properties p ON p.id = u.property_id
        WHERE u.id = ?
        LIMIT 1%s
    ]]):format(lock), {
        propertyUnitId
    }))
end

local function hasActiveAccess(characterId, propertyUnitId)
    local unit = findUnit(propertyUnitId, false)

    if unit == nil then
        return false, nil, nil
    end

    if unit.ownerCharacterId ~= nil and tonumber(unit.ownerCharacterId) == tonumber(characterId) then
        return true, unit, 'owner'
    end

    local access = MySQL.single.await([[
        SELECT access_type
        FROM property_access
        WHERE property_unit_id = ?
            AND character_id = ?
            AND (expires_at IS NULL OR expires_at > NOW())
        LIMIT 1
    ]], {
        propertyUnitId,
        characterId
    })

    if access == nil then
        return false, unit, nil
    end

    return true, unit, access.access_type
end

local function getActiveAccess(characterId, propertyUnitId, forUpdate)
    local lock = forUpdate and ' FOR UPDATE' or ''

    return MySQL.single.await(([[
        SELECT id, access_type, granted_by_character_id, expires_at
        FROM property_access
        WHERE property_unit_id = ?
            AND character_id = ?
            AND (expires_at IS NULL OR expires_at > NOW())
        LIMIT 1%s
    ]]):format(lock), {
        propertyUnitId,
        characterId
    })
end

local function getAccessManager(actor, unit, forUpdate)
    if unit == nil or actor == nil then
        return nil
    end

    if unit.ownerCharacterId ~= nil and tonumber(unit.ownerCharacterId) == tonumber(actor.id) then
        return 'owner'
    end

    local access = getActiveAccess(actor.id, unit.id, forUpdate)

    if access ~= nil and access.access_type == 'tenant' then
        return 'tenant'
    end

    return nil
end

local function withPropertyAccessTransaction(callback)
    MySQL.query.await('START TRANSACTION')

    local ok, result = pcall(callback)

    if ok and type(result) == 'table' and result.success == true then
        MySQL.query.await('COMMIT')
        return result
    end

    MySQL.query.await('ROLLBACK')

    if ok then
        return result
    end

    return respond(false, 'DATABASE_ERROR', 'Immobilienzugriff konnte nicht gespeichert werden.', nil, nil, nil)
end

local function canGrantAccess(managerType, accessType)
    if managerType == 'owner' then
        return accessType == 'tenant' or accessType == 'guest' or accessType == 'temporary'
    end

    if managerType == 'tenant' then
        return accessType == 'guest' or accessType == 'temporary'
    end

    return false
end

local function canRevokeAccess(managerType, targetAccessType, actorCharacterId, access)
    if targetAccessType == 'owner' then
        return false
    end

    if managerType == 'owner' then
        return true
    end

    if managerType == 'tenant' then
        return targetAccessType == 'guest'
            or targetAccessType == 'temporary'
            or tonumber(access.granted_by_character_id) == tonumber(actorCharacterId)
    end

    return false
end

local function mapAccess(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        propertyUnitId = row.property_unit_id,
        characterId = row.character_id,
        accessType = row.access_type,
        grantedByCharacterId = row.granted_by_character_id,
        expiresAt = row.expires_at,
        createdAt = row.created_at
    }
end

local function mapStorage(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        propertyUnitId = row.property_unit_id,
        storageType = row.storage_type,
        isActive = row.is_active == true or row.is_active == 1,
        stash = {
            id = row.stash_id,
            name = row.stash_name,
            label = row.label,
            slots = row.slots,
            maxWeight = row.max_weight
        }
    }
end

local function mapStorageForResponse(storage)
    if storage == nil then
        return nil
    end

    return {
        id = storage.id,
        propertyUnitId = storage.propertyUnitId,
        storageType = storage.storageType,
        isActive = storage.isActive,
        stash = {
            id = storage.stash.id,
            label = storage.stash.label,
            slots = storage.stash.slots,
            maxWeight = storage.stash.maxWeight
        }
    }
end

local function mapFurniture(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        propertyUnitId = row.property_unit_id,
        placedByCharacterId = row.placed_by_character_id,
        model = row.model,
        label = row.label,
        position = decodeJson(row.position),
        rotation = decodeJson(row.rotation),
        metadata = decodeJson(row.metadata),
        isActive = row.is_active == true or row.is_active == 1,
        createdAt = row.created_at,
        updatedAt = row.updated_at
    }
end

local function canManageFurniture(accessType)
    return accessType == 'owner' or accessType == 'tenant'
end

local function isFurnitureCaller()
    local invokingResource = GetInvokingResource()

    return invokingResource == nil or invokingResource == 'nexa_furniture' or invokingResource == NEXA_API.resourceName
end

local function buildStorageName(propertyUnitId, storageType)
    return ('prop_%d_%s_%06d'):format(propertyUnitId, storageType, math.random(0, 999999))
end

local function buildStorageDefaults(unit, storageType)
    local metadata = unit.metadata or {}
    local storage = type(metadata.storage) == 'table' and metadata.storage or {}
    local storageConfig = type(storage[storageType]) == 'table' and storage[storageType] or {}
    local label = storageConfig.label or ('%s Lager'):format(unit.label or unit.unitCode)
    local slots = tonumber(storageConfig.slots) or propertyLimits.defaultStorageSlots
    local maxWeight = tonumber(storageConfig.maxWeight) or propertyLimits.defaultStorageWeight

    if #label > propertyLimits.maxTextLength then
        label = label:sub(1, propertyLimits.maxTextLength)
    end

    if slots < 1 then
        slots = propertyLimits.defaultStorageSlots
    end

    if maxWeight < 1 then
        maxWeight = propertyLimits.defaultStorageWeight
    end

    return {
        stashName = buildStorageName(unit.id, storageType),
        label = label,
        slots = math.floor(slots),
        maxWeight = math.floor(maxWeight)
    }
end

local function findPropertyStorage(propertyUnitId, storageType, forUpdate)
    local lock = forUpdate and ' FOR UPDATE' or ''

    return mapStorage(MySQL.single.await(([[ 
        SELECT
            ps.id,
            ps.property_unit_id,
            ps.storage_type,
            ps.is_active,
            sr.id AS stash_id,
            sr.stash_name,
            sr.label,
            sr.slots,
            sr.max_weight
        FROM property_storage ps
        JOIN stash_registry sr ON sr.id = ps.stash_id
        WHERE ps.property_unit_id = ?
            AND ps.storage_type = ?
            AND ps.is_active = TRUE
            AND sr.is_active = TRUE
        LIMIT 1%s
    ]]):format(lock), {
        propertyUnitId,
        storageType
    }))
end

local function registerOxStash(storage)
    if GetResourceState('ox_inventory') ~= 'started' then
        return false
    end

    local ok = pcall(function()
        exports.ox_inventory:RegisterStash(
            storage.stash.name,
            storage.stash.label,
            storage.stash.slots,
            storage.stash.maxWeight,
            false
        )
    end)

    return ok
end

local function openOxStash(source, storage)
    if GetResourceState('ox_inventory') ~= 'started' then
        return false
    end

    local registered = registerOxStash(storage)

    if not registered then
        return false
    end

    local ok = pcall(function()
        exports.ox_inventory:forceOpenInventory(source, 'stash', storage.stash.name)
    end)

    return ok
end

local function ensureStorageForUnit(unit, storageType, actor, accessType)
    local existing = findPropertyStorage(unit.id, storageType, false)

    if existing ~= nil then
        registerOxStash(existing)
        return existing, false
    end

    local defaults = buildStorageDefaults(unit, storageType)

    MySQL.query.await('START TRANSACTION')

    local ok, result = pcall(function()
        local lockedUnit = findUnit(unit.id, true)

        if lockedUnit == nil then
            return nil, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.'
        end

        local lockedStorage = findPropertyStorage(unit.id, storageType, true)

        if lockedStorage ~= nil then
            return {
                storage = lockedStorage,
                created = false
            }
        end

        local stashId = MySQL.scalar.await([[ 
            SELECT id
            FROM stash_registry
            WHERE stash_name = ?
            LIMIT 1
            FOR UPDATE
        ]], {
            defaults.stashName
        })

        if stashId == nil then
            stashId = MySQL.insert.await([[ 
                INSERT INTO stash_registry (
                    stash_name, label, owner_type, owner_id, slots, max_weight,
                    is_temporary, is_active, metadata
                )
                VALUES (?, ?, 'property', ?, ?, ?, FALSE, TRUE, ?)
            ]], {
                defaults.stashName,
                defaults.label,
                unit.id,
                defaults.slots,
                defaults.maxWeight,
                encodeJson({
                    source = 'phase7c.property_storage',
                    propertyUnitId = unit.id,
                    storageType = storageType
                })
            })
        else
            MySQL.update.await([[ 
                UPDATE stash_registry
                SET owner_type = 'property',
                    owner_id = ?,
                    label = ?,
                    slots = ?,
                    max_weight = ?,
                    is_temporary = FALSE,
                    is_active = TRUE
                WHERE id = ?
            ]], {
                unit.id,
                defaults.label,
                defaults.slots,
                defaults.maxWeight,
                stashId
            })
        end

        MySQL.insert.await([[ 
            INSERT INTO property_storage (property_unit_id, stash_id, storage_type, is_active)
            VALUES (?, ?, ?, TRUE)
            ON DUPLICATE KEY UPDATE
                storage_type = VALUES(storage_type),
                is_active = TRUE
        ]], {
            unit.id,
            stashId,
            storageType
        })

        return {
            storage = findPropertyStorage(unit.id, storageType, true),
            created = true
        }
    end)

    if ok and type(result) == 'table' and result.storage ~= nil then
        MySQL.query.await('COMMIT')
        registerOxStash(result.storage)

        if result.created then
            writePropertyAudit('property.storage.create', actor, unit.id, {
                storageId = result.storage.id,
                stashId = result.storage.stash.id,
                stashName = result.storage.stash.name,
                storageType = storageType,
                accessType = accessType
            })
        end

        return result.storage, result.created
    end

    MySQL.query.await('ROLLBACK')

    return nil, false
end

local function buildTransactionNumber(prefix)
    return ('%s_%s_%04d'):format(prefix, os.date('%Y%m%d%H%M%S'), math.random(0, 9999))
end

local function insertPropertyTransaction(unit, actor, accountId, ledgerId, transactionType, amount, transactionNumber, metadata)
    return MySQL.insert.await([[
        INSERT INTO property_transactions (
            transaction_number, property_id, property_unit_id, from_character_id, to_character_id,
            account_id, ledger_id, transaction_type, amount, status, metadata, created_at
        )
        VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, 'completed', ?, NOW())
    ]], {
        transactionNumber,
        unit.propertyId,
        unit.id,
        actor.id,
        accountId,
        ledgerId,
        transactionType,
        amount,
        encodeJson(metadata)
    })
end

local function isHousingCaller()
    local invokingResource = GetInvokingResource()

    return invokingResource == nil or invokingResource == 'nexa_housing' or invokingResource == NEXA_API.resourceName
end

function listProperties(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local limit = normalizeLimit(payload.limit)
    local status = normalizeText(payload.status, nil, propertyLimits.maxTextLength)

    if status ~= nil and not validStatuses[status] then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Immobilienstatus.', nil, nil, nil)
    end

    local query = [[
        SELECT
            p.id AS property_id,
            p.property_code,
            p.name AS property_name,
            p.property_type,
            p.status AS property_status,
            u.id AS unit_id,
            u.unit_code,
            u.owner_character_id,
            u.label AS unit_label,
            u.status AS unit_status,
            u.metadata AS unit_metadata
        FROM property_units u
        JOIN properties p ON p.id = u.property_id
        WHERE p.status <> 'disabled' AND u.status <> 'disabled'
    ]]
    local values = {}

    if status ~= nil then
        query = query .. ' AND u.status = ?'
        values[#values + 1] = status
    end

    query = query .. ' ORDER BY p.name ASC, u.label ASC LIMIT ?'
    values[#values + 1] = limit

    local rows = MySQL.query.await(query, values) or {}
    local properties = {}

    for _, row in ipairs(rows) do
        properties[#properties + 1] = mapUnit(row)
    end

    return respond(true, 'OK', 'Immobilienliste wurde geladen.', {
        properties = properties
    }, {
        limit = limit
    }, nil)
end

function listAccessibleProperties(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local limit = normalizeLimit(payload.limit)

    local rows = MySQL.query.await([[
        SELECT DISTINCT
            p.id AS property_id,
            p.property_code,
            p.name AS property_name,
            p.property_type,
            p.status AS property_status,
            u.id AS unit_id,
            u.unit_code,
            u.owner_character_id,
            u.label AS unit_label,
            u.status AS unit_status,
            u.metadata AS unit_metadata
        FROM property_units u
        JOIN properties p ON p.id = u.property_id
        LEFT JOIN property_access a ON a.property_unit_id = u.id
            AND a.character_id = ?
            AND (a.expires_at IS NULL OR a.expires_at > NOW())
        WHERE u.owner_character_id = ? OR a.id IS NOT NULL
        ORDER BY p.name ASC, u.label ASC
        LIMIT ?
    ]], {
        actor.id,
        actor.id,
        limit
    }) or {}

    local properties = {}

    for _, row in ipairs(rows) do
        properties[#properties + 1] = mapUnit(row)
    end

    return respond(true, 'OK', 'Zugreifbare Immobilien wurden geladen.', {
        properties = properties
    }, {
        limit = limit
    }, nil)
end

function getPropertyStatus(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Statusabfrage.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)

    if propertyUnitId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Wohneinheit.', nil, nil, nil)
    end

    local allowed, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    return respond(true, 'OK', 'Immobilienstatus wurde geladen.', {
        property = unit,
        hasAccess = allowed,
        accessType = accessType
    }, nil, nil)
end

function hasPropertyAccess(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)

    if propertyUnitId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Wohneinheit.', nil, nil, nil)
    end

    local allowed, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf diese Immobilie.', {
            hasAccess = false
        }, nil, nil)
    end

    return respond(true, 'OK', 'Immobilienzugriff wurde bestaetigt.', {
        hasAccess = true,
        accessType = accessType,
        property = unit
    }, nil, nil)
end

function ensurePropertyStorage(source, payload)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lagerdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local storageType = normalizeStorageType(payload.storageType)

    if propertyUnitId == nil or storageType == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lagerdaten.', nil, nil, nil)
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Inventory ist nicht verfuegbar.', nil, nil, nil)
    end

    local allowed, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed or (accessType ~= 'owner' and accessType ~= 'tenant') then
        return respond(false, 'NO_PERMISSION', 'Nur Besitzer oder Mieter koennen Property-Storage anlegen.', nil, nil, nil)
    end

    local storage, created = ensureStorageForUnit(unit, storageType, actor, accessType)

    if storage == nil then
        return respond(false, 'DATABASE_ERROR', 'Property-Storage konnte nicht vorbereitet werden.', nil, nil, nil)
    end

    return respond(true, created and 'CREATED' or 'OK', 'Property-Storage wurde vorbereitet.', {
        storage = mapStorageForResponse(storage),
        created = created
    }, nil, nil)
end

function openPropertyStorage(source, payload)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lagerdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local storageType = normalizeStorageType(payload.storageType)

    if propertyUnitId == nil or storageType == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lagerdaten.', nil, nil, nil)
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Inventory ist nicht verfuegbar.', nil, nil, nil)
    end

    local allowed, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not allowed then
        writePropertyAudit('property.storage.denied', actor, propertyUnitId, {
            storageType = storageType
        })

        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf dieses Lager.', nil, nil, nil)
    end

    local storage, created = ensureStorageForUnit(unit, storageType, actor, accessType)

    if storage == nil then
        return respond(false, 'DATABASE_ERROR', 'Property-Storage konnte nicht geoeffnet werden.', nil, nil, nil)
    end

    if not openOxStash(source, storage) then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Property-Storage konnte nicht im Inventory geoeffnet werden.', nil, nil, nil)
    end

    local auditId = writePropertyAudit('property.storage.open', actor, propertyUnitId, {
        storageId = storage.id,
        stashId = storage.stash.id,
        stashName = storage.stash.name,
        storageType = storageType,
        accessType = accessType,
        created = created
    })

    logProperty('Property-Storage wurde geoeffnet.', {
        source = source,
        propertyUnitId = propertyUnitId,
        storageType = storageType,
        stashName = storage.stash.name,
        accessType = accessType
    })

    return respond(true, 'OK', 'Property-Storage wurde freigegeben.', {
        property = unit,
        storage = mapStorageForResponse(storage),
        inventory = {
            type = 'stash',
            opened = true
        },
        accessType = accessType
    }, nil, auditId)
end

function listPropertyFurniture(source, payload)
    if not isFurnitureCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Furniture genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Moebeldaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)

    if propertyUnitId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Wohneinheit.', nil, nil, nil)
    end

    local hasAccess, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not hasAccess then
        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf diese Einrichtung.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT id, property_unit_id, placed_by_character_id, model, label, position, rotation, metadata, is_active, created_at, updated_at
        FROM property_furniture
        WHERE property_unit_id = ?
            AND is_active = TRUE
        ORDER BY id ASC
        LIMIT ?
    ]], {
        propertyUnitId,
        propertyLimits.maxFurniturePerUnit
    }) or {}

    local furniture = {}

    for _, row in ipairs(rows) do
        furniture[#furniture + 1] = mapFurniture(row)
    end

    return respond(true, 'OK', 'Einrichtung wurde geladen.', {
        property = unit,
        furniture = furniture,
        accessType = accessType
    }, {
        count = #furniture
    }, nil)
end

local function normalizeFurniturePayload(payload, requireFurnitureId)
    if type(payload) ~= 'table' then
        return nil
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local furnitureId = requireFurnitureId and normalizeId(payload.furnitureId) or nil
    local model = requireFurnitureId and normalizeFurnitureModel(payload.model or 'prop_placeholder') or normalizeFurnitureModel(payload.model)
    local label = normalizeText(payload.label, model, propertyLimits.maxTextLength)
    local position = normalizeVector(payload.position, false)
    local rotation = normalizeVector(payload.rotation, true)

    if propertyUnitId == nil or model == nil or label == nil or position == nil or rotation == nil then
        return nil
    end

    if requireFurnitureId and furnitureId == nil then
        return nil
    end

    return {
        propertyUnitId = propertyUnitId,
        furnitureId = furnitureId,
        model = model,
        label = label,
        position = position,
        rotation = rotation,
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }
end

function placePropertyFurniture(source, payload)
    if not isFurnitureCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Furniture genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local furniturePayload = normalizeFurniturePayload(payload, false)

    if furniturePayload == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Moebeldaten.', nil, nil, nil)
    end

    local hasAccess, unit, accessType = hasActiveAccess(actor.id, furniturePayload.propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not hasAccess or not canManageFurniture(accessType) then
        return respond(false, 'NO_PERMISSION', 'Nur Besitzer oder Mieter koennen Moebel platzieren.', nil, nil, nil)
    end

    if not isFurniturePositionPlausible(unit, furniturePayload.position) then
        return respond(false, 'INVALID_INPUT', 'Moebelposition liegt ausserhalb der erlaubten Flaeche.', nil, nil, nil)
    end

    MySQL.query.await('START TRANSACTION')

    local ok, result = pcall(function()
        local lockedUnit = findUnit(furniturePayload.propertyUnitId, true)

        if lockedUnit == nil then
            return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
        end

        local lockedAccessType = nil

        if lockedUnit.ownerCharacterId ~= nil and tonumber(lockedUnit.ownerCharacterId) == tonumber(actor.id) then
            lockedAccessType = 'owner'
        else
            local activeAccess = getActiveAccess(actor.id, furniturePayload.propertyUnitId, true)
            lockedAccessType = activeAccess and activeAccess.access_type or nil
        end

        if not canManageFurniture(lockedAccessType) then
            return respond(false, 'NO_PERMISSION', 'Nur Besitzer oder Mieter koennen Moebel platzieren.', nil, nil, nil)
        end

        if not isFurniturePositionPlausible(lockedUnit, furniturePayload.position) then
            return respond(false, 'INVALID_INPUT', 'Moebelposition liegt ausserhalb der erlaubten Flaeche.', nil, nil, nil)
        end

        local count = MySQL.scalar.await([[
            SELECT COUNT(*)
            FROM property_furniture
            WHERE property_unit_id = ?
                AND is_active = TRUE
        ]], {
            furniturePayload.propertyUnitId
        }) or 0

        if tonumber(count) >= propertyLimits.maxFurniturePerUnit then
            return respond(false, 'CONFLICT', 'Moebellimit fuer diese Wohneinheit wurde erreicht.', nil, nil, nil)
        end

        local furnitureId = MySQL.insert.await([[
            INSERT INTO property_furniture (
                property_unit_id, placed_by_character_id, model, label, position, rotation, metadata, is_active
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, TRUE)
        ]], {
            furniturePayload.propertyUnitId,
            actor.id,
            furniturePayload.model,
            furniturePayload.label,
            encodeJson(furniturePayload.position),
            encodeJson(furniturePayload.rotation),
            encodeJson(furniturePayload.metadata)
        })

        local row = MySQL.single.await([[
            SELECT id, property_unit_id, placed_by_character_id, model, label, position, rotation, metadata, is_active, created_at, updated_at
            FROM property_furniture
            WHERE id = ?
            LIMIT 1
        ]], {
            furnitureId
        })

        return respond(true, 'CREATED', 'Moebel wurde gespeichert.', {
            furniture = mapFurniture(row),
            accessType = lockedAccessType
        }, nil, nil)
    end)

    if ok and type(result) == 'table' and result.success == true then
        MySQL.query.await('COMMIT')
    else
        MySQL.query.await('ROLLBACK')

        if ok then
            return result
        end

        return respond(false, 'DATABASE_ERROR', 'Moebel konnte nicht gespeichert werden.', nil, nil, nil)
    end

    accessType = result.data.accessType
    local furnitureId = result.data.furniture and result.data.furniture.id or nil

    local auditId = writePropertyAudit('property.furniture.place', actor, furniturePayload.propertyUnitId, {
        furnitureId = furnitureId,
        model = furniturePayload.model,
        accessType = accessType
    })

    logProperty('Moebel wurde platziert.', {
        source = source,
        propertyUnitId = furniturePayload.propertyUnitId,
        furnitureId = furnitureId,
        model = furniturePayload.model,
        accessType = accessType
    })

    return respond(true, 'CREATED', 'Moebel wurde gespeichert.', {
        furniture = result.data.furniture,
        accessType = accessType
    }, nil, auditId)
end

function savePropertyFurniture(source, payload)
    if not isFurnitureCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Furniture genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local furniturePayload = normalizeFurniturePayload(payload, true)

    if furniturePayload == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Moebeldaten.', nil, nil, nil)
    end

    local hasAccess, unit, accessType = hasActiveAccess(actor.id, furniturePayload.propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not hasAccess or not canManageFurniture(accessType) then
        return respond(false, 'NO_PERMISSION', 'Nur Besitzer oder Mieter koennen Moebel speichern.', nil, nil, nil)
    end

    if not isFurniturePositionPlausible(unit, furniturePayload.position) then
        return respond(false, 'INVALID_INPUT', 'Moebelposition liegt ausserhalb der erlaubten Flaeche.', nil, nil, nil)
    end

    local updated = MySQL.update.await([[
        UPDATE property_furniture
        SET model = ?,
            label = ?,
            position = ?,
            rotation = ?,
            metadata = ?,
            updated_at = NOW()
        WHERE id = ?
            AND property_unit_id = ?
            AND is_active = TRUE
    ]], {
        furniturePayload.model,
        furniturePayload.label,
        encodeJson(furniturePayload.position),
        encodeJson(furniturePayload.rotation),
        encodeJson(furniturePayload.metadata),
        furniturePayload.furnitureId,
        furniturePayload.propertyUnitId
    })

    if updated ~= 1 then
        return respond(false, 'NOT_FOUND', 'Moebel wurde nicht gefunden.', nil, nil, nil)
    end

    local row = MySQL.single.await([[
        SELECT id, property_unit_id, placed_by_character_id, model, label, position, rotation, metadata, is_active, created_at, updated_at
        FROM property_furniture
        WHERE id = ?
        LIMIT 1
    ]], {
        furniturePayload.furnitureId
    })

    local auditId = writePropertyAudit('property.furniture.save', actor, furniturePayload.propertyUnitId, {
        furnitureId = furniturePayload.furnitureId,
        model = furniturePayload.model,
        accessType = accessType
    })

    logProperty('Moebel wurde gespeichert.', {
        source = source,
        propertyUnitId = furniturePayload.propertyUnitId,
        furnitureId = furniturePayload.furnitureId,
        model = furniturePayload.model,
        accessType = accessType
    })

    return respond(true, 'UPDATED', 'Moebel wurde gespeichert.', {
        furniture = mapFurniture(row),
        accessType = accessType
    }, nil, auditId)
end

function removePropertyFurniture(source, payload)
    if not isFurnitureCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Furniture genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Moebeldaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local furnitureId = normalizeId(payload.furnitureId)
    local reason = normalizeText(payload.reason, 'removed', propertyLimits.maxReasonLength)

    if propertyUnitId == nil or furnitureId == nil or reason == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Moebeldaten.', nil, nil, nil)
    end

    local hasAccess, unit, accessType = hasActiveAccess(actor.id, propertyUnitId)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if not hasAccess or not canManageFurniture(accessType) then
        return respond(false, 'NO_PERMISSION', 'Nur Besitzer oder Mieter koennen Moebel entfernen.', nil, nil, nil)
    end

    local updated = MySQL.update.await([[
        UPDATE property_furniture
        SET is_active = FALSE,
            metadata = JSON_SET(COALESCE(metadata, JSON_OBJECT()), '$.removedByCharacterId', ?, '$.removeReason', ?),
            updated_at = NOW()
        WHERE id = ?
            AND property_unit_id = ?
            AND is_active = TRUE
    ]], {
        actor.id,
        reason,
        furnitureId,
        propertyUnitId
    })

    if updated ~= 1 then
        return respond(false, 'NOT_FOUND', 'Moebel wurde nicht gefunden.', nil, nil, nil)
    end

    local auditId = writePropertyAudit('property.furniture.remove', actor, propertyUnitId, {
        furnitureId = furnitureId,
        accessType = accessType,
        reason = reason
    })

    logProperty('Moebel wurde entfernt.', {
        source = source,
        propertyUnitId = propertyUnitId,
        furnitureId = furnitureId,
        accessType = accessType
    })

    return respond(true, 'UPDATED', 'Moebel wurde entfernt.', {
        propertyUnitId = propertyUnitId,
        furnitureId = furnitureId,
        accessType = accessType
    }, nil, auditId)
end

function grantPropertyAccess(source, payload)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local targetCharacterId = normalizeId(payload.characterId)
    local accessType = normalizeText(payload.accessType, 'guest', propertyLimits.maxTextLength)
    local durationMinutes = normalizeDurationMinutes(payload.durationMinutes)
    local expiresAt = normalizeExpiresAt(payload.expiresAt)

    if propertyUnitId == nil or targetCharacterId == nil or accessType == nil or not validAccessTypes[accessType] then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    if accessType == 'temporary' and durationMinutes == nil and expiresAt == nil then
        return respond(false, 'INVALID_INPUT', 'Temporaerer Zugriff braucht eine gueltige Ablaufzeit.', nil, nil, nil)
    end

    local character = MySQL.scalar.await([[
        SELECT id
        FROM characters
        WHERE id = ? AND is_active = TRUE AND deleted_at IS NULL
        LIMIT 1
    ]], {
        targetCharacterId
    })

    if character == nil then
        return respond(false, 'NOT_FOUND', 'Charakter wurde nicht gefunden.', nil, nil, nil)
    end

    if accessType ~= 'temporary' then
        expiresAt = nil
        durationMinutes = nil
    end

    local result = withPropertyAccessTransaction(function()
        local unit = findUnit(propertyUnitId, true)

        if unit == nil then
            return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
        end

        local managerType = getAccessManager(actor, unit, true)

        if not canGrantAccess(managerType, accessType) then
            return respond(false, 'NO_PERMISSION', 'Nur berechtigte Besitzer oder Mieter koennen diesen Zugriff vergeben.', nil, nil, nil)
        end

        if tonumber(targetCharacterId) == tonumber(unit.ownerCharacterId) then
            return respond(false, 'CONFLICT', 'Besitzrechte werden nicht ueber Zugriffseintraege geaendert.', nil, nil, nil)
        end

        if durationMinutes ~= nil then
            MySQL.insert.await([[
                INSERT INTO property_access (property_unit_id, character_id, access_type, granted_by_character_id, expires_at)
                VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
                ON DUPLICATE KEY UPDATE
                    access_type = VALUES(access_type),
                    granted_by_character_id = VALUES(granted_by_character_id),
                    expires_at = VALUES(expires_at)
            ]], {
                propertyUnitId,
                targetCharacterId,
                accessType,
                actor.id,
                durationMinutes
            })
        else
            MySQL.insert.await([[
                INSERT INTO property_access (property_unit_id, character_id, access_type, granted_by_character_id, expires_at)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    access_type = VALUES(access_type),
                    granted_by_character_id = VALUES(granted_by_character_id),
                    expires_at = VALUES(expires_at)
            ]], {
                propertyUnitId,
                targetCharacterId,
                accessType,
                actor.id,
                expiresAt
            })
        end

        return respond(true, 'UPDATED', 'Immobilienzugriff wurde vergeben.', {
            propertyUnitId,
            characterId = targetCharacterId,
            accessType = accessType,
            managerType = managerType,
            durationMinutes = durationMinutes,
            expiresAt = expiresAt
        }, nil, nil)
    end)

    if type(result) ~= 'table' or result.success ~= true then
        return result
    end

    local auditId = writePropertyAudit('property.access.grant', actor, propertyUnitId, {
        targetCharacterId = targetCharacterId,
        accessType = accessType,
        managerType = result.data.managerType,
        durationMinutes = durationMinutes,
        expiresAt = expiresAt
    })

    logProperty('Immobilienzugriff wurde vergeben.', {
        source = source,
        propertyUnitId = propertyUnitId,
        targetCharacterId = targetCharacterId,
        accessType = accessType,
        managerType = result.data.managerType
    })

    result.audit_id = auditId

    return respond(true, 'UPDATED', 'Immobilienzugriff wurde vergeben.', {
        propertyUnitId = propertyUnitId,
        characterId = targetCharacterId,
        accessType = accessType,
        durationMinutes = durationMinutes,
        expiresAt = expiresAt
    }, nil, auditId)
end

function listPropertyAccess(source, payload)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)

    if propertyUnitId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Wohneinheit.', nil, nil, nil)
    end

    local unit = findUnit(propertyUnitId, false)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    local managerType = getAccessManager(actor, unit)

    if managerType == nil then
        return respond(false, 'NO_PERMISSION', 'Du darfst Zugriffe fuer diese Immobilie nicht verwalten.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT id, property_unit_id, character_id, access_type, granted_by_character_id, expires_at, created_at
        FROM property_access
        WHERE property_unit_id = ?
            AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY access_type ASC, created_at ASC
    ]], {
        propertyUnitId
    }) or {}

    local access = {}

    for _, row in ipairs(rows) do
        access[#access + 1] = mapAccess(row)
    end

    return respond(true, 'OK', 'Immobilienzugriffe wurden geladen.', {
        property = unit,
        access = access,
        managerType = managerType
    }, {
        count = #access
    }, nil)
end

function revokePropertyAccess(source, payload)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)
    local targetCharacterId = normalizeId(payload.characterId)
    local reason = normalizeText(payload.reason, nil, propertyLimits.maxReasonLength)

    if propertyUnitId == nil or targetCharacterId == nil or reason == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zugriffsdaten.', nil, nil, nil)
    end

    local result = withPropertyAccessTransaction(function()
        local unit = findUnit(propertyUnitId, true)

        if unit == nil then
            return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
        end

        if tonumber(targetCharacterId) == tonumber(unit.ownerCharacterId) then
            return respond(false, 'CONFLICT', 'Besitzrechte duerfen durch Zugriffsentzug nicht beschaedigt werden.', nil, nil, nil)
        end

        local managerType = getAccessManager(actor, unit, true)

        if managerType == nil then
            return respond(false, 'NO_PERMISSION', 'Du darfst Zugriffe fuer diese Immobilie nicht verwalten.', nil, nil, nil)
        end

        local access = getActiveAccess(targetCharacterId, propertyUnitId, true)

        if access == nil then
            return respond(false, 'NOT_FOUND', 'Aktiver Immobilienzugriff wurde nicht gefunden.', nil, nil, nil)
        end

        if not canRevokeAccess(managerType, access.access_type, actor.id, access) then
            return respond(false, 'NO_PERMISSION', 'Du darfst diesen Immobilienzugriff nicht entziehen.', nil, nil, nil)
        end

        local deleted = MySQL.update.await([[
            DELETE FROM property_access
            WHERE property_unit_id = ?
                AND character_id = ?
                AND access_type <> 'owner'
        ]], {
            propertyUnitId,
            targetCharacterId
        })

        if deleted ~= 1 then
            return respond(false, 'CONFLICT', 'Immobilienzugriff konnte nicht eindeutig entzogen werden.', nil, nil, nil)
        end

        return respond(true, 'UPDATED', 'Immobilienzugriff wurde entzogen.', {
            propertyUnitId = propertyUnitId,
            characterId = targetCharacterId,
            accessType = access.access_type,
            managerType = managerType
        }, nil, nil)
    end)

    if type(result) ~= 'table' or result.success ~= true then
        return result
    end

    local auditId = writePropertyAudit('property.access.revoke', actor, propertyUnitId, {
        targetCharacterId = targetCharacterId,
        accessType = result.data.accessType,
        managerType = result.data.managerType,
        reason = reason
    })

    logProperty('Immobilienzugriff wurde entzogen.', {
        source = source,
        propertyUnitId = propertyUnitId,
        targetCharacterId = targetCharacterId,
        accessType = result.data.accessType,
        managerType = result.data.managerType
    })

    result.audit_id = auditId

    return respond(true, 'UPDATED', 'Immobilienzugriff wurde entzogen.', {
        propertyUnitId = propertyUnitId,
        characterId = targetCharacterId,
        accessType = result.data.accessType
    }, nil, auditId)
end

local function purchaseOrRentProperty(source, payload, transactionType)
    if not isHousingCaller() then
        return respond(false, 'NO_PERMISSION', 'Diese Immobilien-API darf nur von Housing genutzt werden.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Immobiliendaten.', nil, nil, nil)
    end

    local propertyUnitId = normalizeId(payload.propertyUnitId)

    if propertyUnitId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Wohneinheit.', nil, nil, nil)
    end

    local unit = findUnit(propertyUnitId, false)

    if unit == nil then
        return respond(false, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.', nil, nil, nil)
    end

    if unit.propertyStatus == 'disabled' or unit.propertyStatus == 'locked' or unit.status == 'disabled' then
        return respond(false, 'CONFLICT', 'Wohneinheit ist nicht verfuegbar.', nil, nil, nil)
    end

    local amount = transactionType == 'purchase' and normalizePrice(unit.price) or normalizePrice(unit.rent)

    if amount == nil or amount <= 0 then
        return respond(false, 'CONFLICT', 'Fuer diese Wohneinheit ist kein gueltiger Preis hinterlegt.', nil, nil, nil)
    end

    local desiredStatus = transactionType == 'purchase' and 'owned' or 'rented'
    local desiredAccess = transactionType == 'purchase' and 'owner' or 'tenant'
    local transactionNumber = buildTransactionNumber(transactionType == 'purchase' and 'prop_buy' or 'prop_rent')
    local accountPayload = {
        accountId = payload.accountId,
        accountNumber = payload.accountNumber,
        reason = transactionType == 'purchase' and ('Immobilienkauf: %s'):format(unit.label) or ('Immobilienmiete: %s'):format(unit.label),
        transactionPrefix = transactionType == 'purchase' and 'property_purchase' or 'property_rent',
        resourceName = 'nexa_housing',
        metadata = {
            source = source,
            propertyUnitId = propertyUnitId,
            propertyCode = unit.propertyCode,
            unitCode = unit.unitCode,
            transactionType = transactionType
        }
    }

    local result = NexaAccountExecutePropertyPurchase(source, accountPayload, function(context)
        local lockedUnit = findUnit(propertyUnitId, true)

        if lockedUnit == nil then
            return nil, 'NOT_FOUND', 'Wohneinheit wurde nicht gefunden.'
        end

        if lockedUnit.status ~= 'available' or lockedUnit.ownerCharacterId ~= nil then
            return nil, 'CONFLICT', 'Wohneinheit ist bereits vergeben.'
        end

        local lockedAmount = transactionType == 'purchase' and normalizePrice(lockedUnit.price) or normalizePrice(lockedUnit.rent)

        if lockedAmount == nil or lockedAmount <= 0 or lockedAmount ~= amount then
            return nil, 'CONFLICT', 'Der Immobilienpreis hat sich geaendert.'
        end

        if context.stage == 'prepare' then
            return {
                propertyUnitId = propertyUnitId,
                amount = lockedAmount,
                reason = accountPayload.reason,
                category = transactionType == 'purchase' and 'property_purchase' or 'property_rent',
                transactionType = transactionType,
                desiredStatus = desiredStatus,
                desiredAccess = desiredAccess,
                transactionNumber = transactionNumber,
                metadata = accountPayload.metadata
            }
        end

        local plan = context.plan

        if type(plan) ~= 'table'
            or tonumber(plan.propertyUnitId) ~= propertyUnitId
            or tonumber(plan.amount) ~= amount
            or plan.transactionType ~= transactionType
        then
            return nil, 'INVALID_INPUT', 'Immobilientransaktion konnte nicht gespeichert werden.'
        end

        local updated = MySQL.update.await([[
            UPDATE property_units
            SET owner_character_id = ?, status = ?, metadata = JSON_SET(COALESCE(metadata, JSON_OBJECT()), '$.lastLedgerId', ?, '$.lastTransactionType', ?)
            WHERE id = ? AND owner_character_id IS NULL AND status = 'available'
        ]], {
            context.actor.id,
            desiredStatus,
            context.ledgerId,
            transactionType,
            propertyUnitId
        })

        if updated ~= 1 then
            return nil, 'CONFLICT', 'Wohneinheit wird bereits verarbeitet.'
        end

        MySQL.insert.await([[
            INSERT INTO property_access (property_unit_id, character_id, access_type, granted_by_character_id, expires_at)
            VALUES (?, ?, ?, ?, NULL)
            ON DUPLICATE KEY UPDATE
                access_type = VALUES(access_type),
                granted_by_character_id = VALUES(granted_by_character_id),
                expires_at = NULL
        ]], {
            propertyUnitId,
            context.actor.id,
            desiredAccess,
            context.actor.id
        })

        local propertyTransactionId = insertPropertyTransaction(lockedUnit, context.actor, context.fromAccount.id, context.ledgerId, transactionType, amount, plan.transactionNumber, {
            transactionId = context.transactionId,
            propertyUnitId = propertyUnitId,
            accessType = desiredAccess,
            status = desiredStatus
        })

        return {
            property = findUnit(propertyUnitId, false),
            propertyTransactionId = propertyTransactionId,
            transactionNumber = plan.transactionNumber,
            amount = amount,
            accessType = desiredAccess,
            status = desiredStatus,
            ledgerId = context.ledgerId
        }
    end)

    if type(result) == 'table' and result.success == true then
        local property = result.data and result.data.property or nil
        local auditId = writePropertyAudit('property.' .. transactionType, actor, propertyUnitId, {
            amount = amount,
            ledgerId = result.data and result.data.ledger and result.data.ledger.id or nil,
            propertyTransactionId = result.data and result.data.propertyTransactionId or nil
        })

        result.audit_id = result.audit_id or auditId

        logProperty('Immobilientransaktion wurde abgeschlossen.', {
            source = source,
            propertyUnitId = propertyUnitId,
            propertyCode = property and property.propertyCode or nil,
            transactionType = transactionType
        })
    end

    return result
end

function purchaseProperty(source, payload)
    return purchaseOrRentProperty(source, payload, 'purchase')
end

function rentProperty(source, payload)
    return purchaseOrRentProperty(source, payload, 'rent')
end

math.randomseed(os.time())

exports('property.list', listProperties)
exports('property.listAccessible', listAccessibleProperties)
exports('property.getStatus', getPropertyStatus)
exports('property.hasAccess', hasPropertyAccess)
exports('property.ensureStorage', ensurePropertyStorage)
exports('property.openStorage', openPropertyStorage)
exports('property.listFurniture', listPropertyFurniture)
exports('property.placeFurniture', placePropertyFurniture)
exports('property.saveFurniture', savePropertyFurniture)
exports('property.removeFurniture', removePropertyFurniture)
exports('property.grantAccess', grantPropertyAccess)
exports('property.listAccess', listPropertyAccess)
exports('property.revokeAccess', revokePropertyAccess)
exports('property.purchase', purchaseProperty)
exports('property.rent', rentProperty)
