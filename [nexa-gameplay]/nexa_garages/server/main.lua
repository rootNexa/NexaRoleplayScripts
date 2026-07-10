local migrated = false

Garages = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_GARAGE_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return good and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end
    print(('[%s] [%s] %s'):format(NEXA_GARAGES.resourceName, level, message))
end

local function actorContext(actor)
    actor = type(actor) == 'table' and actor or {}
    return { actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), source = normalizeId(actor.source), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_GARAGES.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('garage:%s:%s'):format(os.time(), math.random(100000,999999)) }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaGaragesDatabase.InsertAudit({ garage_id = payload.garage_id, vehicle_id = payload.vehicle_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata })
end

function Garages.Register(payload)
    payload = type(payload) == 'table' and payload or {}
    local name = normalizeString(payload.name, 64)
    local label = normalizeString(payload.label, 128)
    local garageType = normalizeString(payload.garage_type or payload.type or NEXA_GARAGE_TYPES.public, 32)
    if not name or not label or not garageType then return fail(NEXA_GARAGE_ERRORS.invalidInput, 'Garage payload is invalid.') end
    if NexaGaragesDatabase.GetGarage(name) then return fail(NEXA_GARAGE_ERRORS.invalidInput, 'Garage already exists.') end
    local id, err = NexaGaragesDatabase.InsertGarage({ name = name, label = label, garage_type = garageType, owner_type = normalizeString(payload.owner_type, 32), owner_id = payload.owner_id and tostring(payload.owner_id) or nil, capacity = normalizeId(payload.capacity) or NexaGaragesConfig.defaultCapacity, enabled = payload.enabled ~= false, location = payload.location or {}, rules = payload.rules or {}, metadata = payload.metadata or {} })
    return err and fail(NEXA_GARAGE_ERRORS.databaseError, 'Garage could not be registered.', err) or ok({ garage_id = id, name = name }, 'Garage registered.')
end

function Garages.Get(idOrName)
    local row, err = NexaGaragesDatabase.GetGarage(idOrName)
    if err then return fail(NEXA_GARAGE_ERRORS.databaseError, 'Garage could not be loaded.', err) end
    return row and ok(row, 'Garage loaded.') or fail(NEXA_GARAGE_ERRORS.notFound, 'Garage not found.')
end

function Garages.List() local rows, err = NexaGaragesDatabase.ListGarages(); return err and fail(NEXA_GARAGE_ERRORS.databaseError, 'Garages could not be listed.', err) or ok(rows or {}, 'Garages listed.') end
function Garages.CanUse(actor, garageIdOrName) local garage = Garages.Get(garageIdOrName); return garage.ok and ok({ garage = garage.data, allowed = tonumber(garage.data.enabled) == 1 }, 'Garage access evaluated.') or garage end
function Garages.GetStoredVehicles(garageIdOrName) local garage = Garages.Get(garageIdOrName); if not garage.ok then return garage end; local rows, err = NexaGaragesDatabase.ListStored(garage.data.name); return err and fail(NEXA_GARAGE_ERRORS.databaseError, 'Stored vehicles could not be listed.', err) or ok(rows or {}, 'Stored vehicles listed.') end

function Garages.Store(actor, vehicleId, garageIdOrName, state)
    local context = actorContext(actor)
    local garage = Garages.Get(garageIdOrName)
    if not garage.ok then return garage end
    local updateState = type(state) == 'table' and exports['nexa_vehicles']:UpdateVehicleState(context, vehicleId, state) or nil
    if updateState and not updateState.ok then return updateState end
    local result = exports['nexa_vehicles']:SetVehicleGarage(vehicleId, garage.data.name, 'stored')
    if not result or not result.ok then return fail(NEXA_GARAGE_ERRORS.vehicleUnavailable, 'Vehicle could not be stored.', result) end
    audit('garage.store', context, result, { garage_id = garage.data.id, vehicle_id = normalizeId(vehicleId) })
    return ok({ vehicle_id = normalizeId(vehicleId), garage = garage.data.name }, 'Vehicle stored.')
end

function Garages.Retrieve(actor, vehicleId, garageIdOrName, options)
    local context = actorContext(actor)
    local garage = Garages.Get(garageIdOrName)
    if not garage.ok then return garage end
    local result = exports['nexa_vehicles']:RequestVehicleSpawn(context, vehicleId, { garage_id = garage.data.name, routing_bucket = options and options.routing_bucket })
    if not result or not result.ok then return fail(NEXA_GARAGE_ERRORS.vehicleUnavailable, 'Vehicle could not be retrieved.', result) end
    audit('garage.retrieve', context, result, { garage_id = garage.data.id, vehicle_id = normalizeId(vehicleId) })
    return result
end

function RegisterGarage(...) return Garages.Register(...) end
function GetGarage(...) return Garages.Get(...) end
function ListGarages(...) return Garages.List(...) end
function GetStoredVehicles(...) return Garages.GetStoredVehicles(...) end
function StoreVehicle(...) return Garages.Store(...) end
function RetrieveVehicle(...) return Garages.Retrieve(...) end
function CanUseGarage(...) return Garages.CanUse(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaGaragesConfig.autoMigrate then migrated = NexaGaragesDatabase.Migrate() == true end
    log('Info', 'garages.start', 'nexa_garages started.', { migrated = migrated })
end)

exports('RegisterGarage', RegisterGarage)
exports('GetGarage', GetGarage)
exports('ListGarages', ListGarages)
exports('GetStoredVehicles', GetStoredVehicles)
exports('StoreVehicle', StoreVehicle)
exports('RetrieveVehicle', RetrieveVehicle)
exports('CanUseGarage', CanUseGarage)
exports('getStatus', function() return { resourceName = NEXA_GARAGES.resourceName, version = NEXA_GARAGES.version, migrated = migrated } end)
exports('getSchema', NexaGaragesDatabase.GetSchema)
