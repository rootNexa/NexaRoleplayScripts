local migrated = false
local entryTokens = {}
local reservedBuckets = {}

InteriorDefinitions = {}
PropertyInteriors = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_INTERIOR_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function timer() return GetGameTimer and GetGameTimer() or math.floor(os.clock() * 1000) end
local function log(level, category, message, context) local coreOk, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); if coreOk and core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s'):format(NEXA_PROPERTY_INTERIORS.resourceName, level, message)) end

local function reserveBucket(propertyId)
    local existing = reservedBuckets[propertyId]
    if existing then return existing end
    for _ = 1, 100 do
        local bucket = math.random(NexaPropertyInteriorsConfig.bucketBase, NexaPropertyInteriorsConfig.bucketMax)
        local used = false
        for _, value in pairs(reservedBuckets) do if value == bucket then used = true end end
        if not used then reservedBuckets[propertyId] = bucket; return bucket end
    end
    return nil
end

local function cleanupTokens()
    local current = timer()
    for token, entry in pairs(entryTokens) do if entry.used or entry.expires_at < current then entryTokens[token] = nil end end
end

function InteriorDefinitions.Register(definition, actor)
    definition = type(definition) == 'table' and definition or {}
    local key = normalizeString(definition.interior_key or definition.key, 64)
    local interiorType = normalizeString(definition.interior_type or NEXA_INTERIOR_TYPES.routing_instance, 32)
    if not key or not NEXA_INTERIOR_TYPES[interiorType] then return fail(NEXA_INTERIOR_ERRORS.invalidInput, 'Interior definition is invalid.') end
    local id, err = NexaPropertyInteriorsDatabase.InsertDefinition({ interior_key = key, interior_type = interiorType, shell_model = definition.shell_model, entry_point = definition.entry_point or {}, exit_point = definition.exit_point or {}, spawn_point = definition.spawn_point or {}, routing_strategy = definition.routing_strategy or 'per_property', furniture_bounds = definition.furniture_bounds or {}, storage_points = definition.storage_points or {}, wardrobe_points = definition.wardrobe_points or {}, garage_link = definition.garage_link or {}, status = definition.status or 'active', metadata = definition.metadata or {} })
    return err and fail(NEXA_INTERIOR_ERRORS.databaseError, 'Interior definition could not be registered.', err) or ok({ definition_id = id, interior_key = key }, 'Interior definition registered.')
end
function InteriorDefinitions.Get(key) local row, err = NexaPropertyInteriorsDatabase.GetDefinition(normalizeString(key, 64)); return err and fail(NEXA_INTERIOR_ERRORS.databaseError, 'Interior definition could not be loaded.', err) or (row and ok(row, 'Interior definition loaded.') or fail(NEXA_INTERIOR_ERRORS.notFound, 'Interior definition not found.')) end
function InteriorDefinitions.List(filters) local rows, err = NexaPropertyInteriorsDatabase.ListDefinitions(); return err and fail(NEXA_INTERIOR_ERRORS.databaseError, 'Interior definitions could not be listed.', err) or ok(rows or {}, 'Interior definitions listed.') end

function PropertyInteriors.Enter(source, propertyId, context)
    cleanupTokens()
    source = normalizeId(source)
    propertyId = normalizeId(propertyId)
    if not source or not propertyId then return fail(NEXA_INTERIOR_ERRORS.invalidInput, 'Entry request is invalid.') end
    local bucket = reserveBucket(propertyId)
    if not bucket then return fail(NEXA_INTERIOR_ERRORS.bucketInvalid, 'Routing bucket could not be reserved.') end
    local token = ('propentry:%s:%s:%s:%s'):format(propertyId, source, timer(), math.random(100000,999999))
    entryTokens[token] = { property_id = propertyId, source = source, character_id = context and context.actor_character_id or nil, routing_bucket = bucket, expires_at = timer() + (NexaPropertyInteriorsConfig.entryTokenTtlSeconds * 1000), used = false }
    NexaPropertyInteriorsDatabase.UpsertInstance({ property_id = propertyId, definition_id = nil, interior_type = NEXA_INTERIOR_TYPES.routing_instance, shell_model = nil, routing_bucket = bucket, entry_point = {}, exit_point = {}, spawn_state = NEXA_INTERIOR_STATE.loading, status = NEXA_INTERIOR_STATE.loading, configuration = {} })
    return ok({ property_id = propertyId, entry_token = token, routing_bucket = bucket }, 'Property entry authorized.')
end

function PropertyInteriors.ConfirmEnter(source, token, context)
    cleanupTokens()
    source = normalizeId(source)
    local entry = type(token) == 'string' and entryTokens[token] or nil
    if not entry or entry.used then return fail(NEXA_INTERIOR_ERRORS.tokenInvalid, 'Entry token is invalid.') end
    if entry.expires_at < timer() then return fail(NEXA_INTERIOR_ERRORS.tokenExpired, 'Entry token expired.') end
    if entry.source ~= source then return fail(NEXA_INTERIOR_ERRORS.tokenInvalid, 'Entry token source mismatch.') end
    entry.used = true
    NexaPropertyInteriorsDatabase.UpsertInstance({ property_id = entry.property_id, definition_id = nil, interior_type = NEXA_INTERIOR_TYPES.routing_instance, shell_model = nil, routing_bucket = entry.routing_bucket, entry_point = {}, exit_point = {}, spawn_state = NEXA_INTERIOR_STATE.active, status = NEXA_INTERIOR_STATE.active, configuration = {} })
    NexaPropertyInteriorsDatabase.InsertOccupant({ property_id = entry.property_id, source = source, character_id = entry.character_id, routing_bucket = entry.routing_bucket, metadata = {} })
    if SetPlayerRoutingBucket then SetPlayerRoutingBucket(source, entry.routing_bucket) end
    return ok({ property_id = entry.property_id, routing_bucket = entry.routing_bucket }, 'Property entry confirmed.')
end

function PropertyInteriors.Exit(source, propertyId, context)
    source = normalizeId(source)
    propertyId = normalizeId(propertyId)
    NexaPropertyInteriorsDatabase.ExitOccupant(propertyId, source)
    if SetPlayerRoutingBucket then SetPlayerRoutingBucket(source, 0) end
    return ok({ property_id = propertyId, source = source }, 'Property exited.')
end

function PropertyInteriors.Get(propertyId) local row, err = NexaPropertyInteriorsDatabase.GetInstance(normalizeId(propertyId)); return err and fail(NEXA_INTERIOR_ERRORS.databaseError, 'Property interior could not be loaded.', err) or (row and ok(row, 'Property interior loaded.') or fail(NEXA_INTERIOR_ERRORS.notFound, 'Property interior not found.')) end
function PropertyInteriors.GetOccupants(propertyId) local rows, err = NexaPropertyInteriorsDatabase.ListOccupants(normalizeId(propertyId)); return err and fail(NEXA_INTERIOR_ERRORS.databaseError, 'Property occupants could not be listed.', err) or ok(rows or {}, 'Property occupants listed.') end
function PropertyInteriors.Reset(propertyId, reason) reservedBuckets[normalizeId(propertyId)] = nil; return ok({ property_id = normalizeId(propertyId), reason = reason }, 'Property interior reset.') end

function RegisterInteriorDefinition(...) return InteriorDefinitions.Register(...) end
function GetInteriorDefinition(...) return InteriorDefinitions.Get(...) end
function ListInteriorDefinitions(...) return InteriorDefinitions.List(...) end
function EnterProperty(...) return PropertyInteriors.Enter(...) end
function ConfirmEnterProperty(...) return PropertyInteriors.ConfirmEnter(...) end
function ExitProperty(...) return PropertyInteriors.Exit(...) end
function GetPropertyInterior(...) return PropertyInteriors.Get(...) end
function GetPropertyOccupants(...) return PropertyInteriors.GetOccupants(...) end
function ResetPropertyInterior(...) return PropertyInteriors.Reset(...) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaPropertyInteriorsConfig.autoMigrate then migrated = NexaPropertyInteriorsDatabase.Migrate() == true end; log('Info', 'propertyinteriors.start', 'nexa_property_interiors started.', { migrated = migrated }) end)
AddEventHandler('playerDropped', function() local source = source; for propertyId in pairs(reservedBuckets) do NexaPropertyInteriorsDatabase.ExitOccupant(propertyId, source) end end)
AddEventHandler('onResourceStop', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; entryTokens = {}; reservedBuckets = {} end)

exports('RegisterInteriorDefinition', RegisterInteriorDefinition)
exports('GetInteriorDefinition', GetInteriorDefinition)
exports('ListInteriorDefinitions', ListInteriorDefinitions)
exports('EnterProperty', EnterProperty)
exports('ConfirmEnterProperty', ConfirmEnterProperty)
exports('ExitProperty', ExitProperty)
exports('GetPropertyInterior', GetPropertyInterior)
exports('GetPropertyOccupants', GetPropertyOccupants)
exports('ResetPropertyInterior', ResetPropertyInterior)
exports('getStatus', function() return { resourceName = NEXA_PROPERTY_INTERIORS.resourceName, version = NEXA_PROPERTY_INTERIORS.version, migrated = migrated, entryTokens = entryTokens } end)
exports('getSchema', NexaPropertyInteriorsDatabase.GetSchema)
