local migrated = false
local spawnTokens = {}
local theftAttempts = {}

VehicleDefinitions = {}
Vehicles = {}
VehicleIdentity = {}
VehicleOwnership = {}
VehicleState = {}
VehicleDamage = {}
VehicleFuel = {}
VehicleMileage = {}
VehicleInsurance = {}
VehicleMaintenance = {}
VehicleMods = {}
VehicleTheft = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_VEHICLE_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function decode(value) if type(value) ~= 'string' or value == '' then return {} end; local good, decoded = pcall(json.decode, value); return good and type(decoded) == 'table' and decoded or {} end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function now() return os.time() end
local function timer() return GetGameTimer and GetGameTimer() or math.floor(os.clock() * 1000) end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return good and core or nil
end

local function log(level, category, message, context)
    local core = getCore()
    if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end
    print(('[%s] [%s] %s %s'):format(NEXA_VEHICLES.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()
    if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_VEHICLES.resourceName }) end
end

local function actorContext(actor, action)
    actor = type(actor) == 'table' and actor or {}
    return { action = action, actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), source = normalizeId(actor.source), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_VEHICLES.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('vehicle:%s:%s:%s'):format(action, now(), math.random(100000, 999999)) }
end

local function audit(action, context, result, payload)
    payload = payload or {}
    NexaVehiclesDatabase.InsertAudit({ vehicle_id = payload.vehicle_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata })
end

local function hydrateVehicle(row)
    if not row then return nil end
    row.mods = decode(row.mods_json)
    row.state = decode(row.state_json)
    row.metadata = decode(row.metadata_json)
    return row
end

local function ownerAllowed(ownerType)
    for _, allowed in pairs(NEXA_VEHICLE_OWNER_TYPES) do if ownerType == allowed then return true end end
    return false
end

function VehicleDefinitions.Register(payload)
    payload = type(payload) == 'table' and payload or {}
    local model = normalizeString(payload.model, 64)
    local label = normalizeString(payload.label, 128)
    local vehicleType = normalizeString(payload.vehicle_type or payload.type or 'car', 32)
    if not model or not label or not vehicleType then return fail(NEXA_VEHICLE_ERRORS.invalidDefinition, 'Vehicle definition is invalid.') end
    local exists = NexaVehiclesDatabase.GetDefinition(model)
    if exists then return ok(exists, 'Vehicle definition already exists.') end
    local id, err = NexaVehiclesDatabase.InsertDefinition({ model = model, label = label, vehicle_type = vehicleType, class = normalizeString(payload.class, 64), manufacturer = normalizeString(payload.manufacturer, 64), seats = normalizeId(payload.seats), default_fuel_capacity = normalizeId(payload.default_fuel_capacity), enabled = payload.enabled ~= false, metadata = payload.metadata or {} })
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle definition could not be saved.', err) end
    return ok({ id = id, model = model }, 'Vehicle definition registered.')
end

function VehicleDefinitions.Get(model)
    local row, err = NexaVehiclesDatabase.GetDefinition(normalizeString(model, 64))
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle definition could not be loaded.', err) end
    return row and ok(row, 'Vehicle definition loaded.') or fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle definition not found.')
end

function VehicleDefinitions.List() local rows, err = NexaVehiclesDatabase.ListDefinitions(); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle definitions could not be listed.', err) or ok(rows or {}, 'Vehicle definitions listed.') end
function VehicleDefinitions.Enable(model) NexaVehiclesDatabase.SetDefinitionEnabled(normalizeString(model, 64), true); return ok({ model = model }, 'Vehicle definition enabled.') end
function VehicleDefinitions.Disable(model) NexaVehiclesDatabase.SetDefinitionEnabled(normalizeString(model, 64), false); return ok({ model = model }, 'Vehicle definition disabled.') end

local function randomChars(chars, count)
    local out = {}
    for i = 1, count do
        local index = math.random(1, #chars)
        out[i] = chars:sub(index, index)
    end
    return table.concat(out)
end

function VehicleIdentity.GenerateVin()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    for _ = 1, 20 do
        local vin = 'NX' .. randomChars(chars, NexaVehicleConfig.vinLength - 2)
        if not NexaVehiclesDatabase.GetByVin(vin) then return vin end
    end
    return nil
end

function VehicleIdentity.GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    for _ = 1, 20 do
        local plate = randomChars(chars, NexaVehicleConfig.plateLength)
        if not NexaVehiclesDatabase.GetByPlate(plate) then return plate end
    end
    return nil
end

function VehicleOwnership.Get(vehicleId)
    local vehicle = hydrateVehicle(NexaVehiclesDatabase.GetVehicle(normalizeId(vehicleId)))
    if not vehicle then return fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.') end
    return ok({ owner_type = vehicle.owner_type, owner_id = vehicle.owner_id }, 'Ownership loaded.')
end

function VehicleOwnership.Transfer(actor, vehicleId, ownerType, ownerId, reason)
    local context = actorContext(actor or { reason = reason }, 'vehicle.transfer')
    vehicleId = normalizeId(vehicleId)
    ownerType = normalizeString(ownerType, 32)
    ownerId = normalizeString(tostring(ownerId or ''), 64)
    if not vehicleId or not ownerAllowed(ownerType) or not ownerId then return fail(NEXA_VEHICLE_ERRORS.invalidOwner, 'Vehicle owner is invalid.') end
    local before = hydrateVehicle(NexaVehiclesDatabase.GetVehicle(vehicleId))
    if not before then return fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.') end
    local _, err = NexaVehiclesDatabase.UpdateOwnership(vehicleId, ownerType, ownerId)
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Ownership could not be updated.', err) end
    local result = ok({ vehicle_id = vehicleId, owner_type = ownerType, owner_id = ownerId }, 'Vehicle transferred.')
    audit('vehicle.transfer', context, result, { vehicle_id = vehicleId, before_state = before, after_state = result.data })
    emit(NEXA_VEHICLE_EVENTS.transferred, result.data)
    return result
end

function Vehicles.Create(actor, payload)
    payload = type(payload) == 'table' and payload or {}
    local context = actorContext(actor, 'vehicle.create')
    local model = normalizeString(payload.model, 64)
    local ownerType = normalizeString(payload.owner_type, 32)
    local ownerId = normalizeString(tostring(payload.owner_id or ''), 64)
    if not model or not ownerAllowed(ownerType) or not ownerId then return fail(NEXA_VEHICLE_ERRORS.invalidInput, 'Vehicle creation payload is invalid.') end
    local definition = NexaVehiclesDatabase.GetDefinition(model)
    if definition and tonumber(definition.enabled) == 0 then return fail(NEXA_VEHICLE_ERRORS.invalidDefinition, 'Vehicle definition is disabled.') end
    local vin = normalizeString(payload.vin, 32) or VehicleIdentity.GenerateVin()
    local plate = normalizeString(payload.plate, 16) or VehicleIdentity.GeneratePlate()
    if not vin or not plate then return fail(NEXA_VEHICLE_ERRORS.invalidInput, 'Vehicle identity could not be generated.') end
    if NexaVehiclesDatabase.GetByVin(vin) then return fail(NEXA_VEHICLE_ERRORS.vinExists, 'VIN already exists.') end
    if NexaVehiclesDatabase.GetByPlate(plate) then return fail(NEXA_VEHICLE_ERRORS.plateExists, 'Plate already exists.') end
    local id, err = NexaVehiclesDatabase.InsertVehicle({ vin = vin, plate = plate, model = model, owner_type = ownerType, owner_id = ownerId, status = payload.status or NEXA_VEHICLE_STATUS.stored, garage_id = payload.garage_id or NexaVehicleConfig.defaultGarage, fuel = NexaVehicleConfig.defaultState.fuel, mileage = NexaVehicleConfig.defaultState.mileage, engine_health = NexaVehicleConfig.defaultState.engineHealth, body_health = NexaVehicleConfig.defaultState.bodyHealth, tank_health = NexaVehicleConfig.defaultState.tankHealth, damage_state = NEXA_VEHICLE_DAMAGE_STATE.none, mods = payload.mods or {}, state = payload.state or {}, metadata = payload.metadata or {}, created_by_account_id = context.actor_account_id, created_by_character_id = context.actor_character_id })
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle could not be created.', err) end
    local result = ok({ vehicle_id = id, vin = vin, plate = plate, model = model }, 'Vehicle created.')
    audit('vehicle.create', context, result, { vehicle_id = id, after_state = payload })
    emit(NEXA_VEHICLE_EVENTS.created, result.data)
    return result
end

function Vehicles.Get(vehicleId)
    local row, err = NexaVehiclesDatabase.GetVehicle(normalizeId(vehicleId))
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle could not be loaded.', err) end
    return row and ok(hydrateVehicle(row), 'Vehicle loaded.') or fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.')
end
function Vehicles.GetByVin(vin) local row, err = NexaVehiclesDatabase.GetByVin(normalizeString(vin, 32)); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle could not be loaded.', err) or (row and ok(hydrateVehicle(row), 'Vehicle loaded.') or fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.')) end
function Vehicles.GetByPlate(plate) local row, err = NexaVehiclesDatabase.GetByPlate(normalizeString(plate, 16)); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle could not be loaded.', err) or (row and ok(hydrateVehicle(row), 'Vehicle loaded.') or fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.')) end
function Vehicles.ListForOwner(ownerType, ownerId) local rows, err = NexaVehiclesDatabase.ListForOwner(normalizeString(ownerType, 32), tostring(ownerId)); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicles could not be listed.', err) or ok(rows or {}, 'Vehicles listed.') end

local function makeSpawnToken(vehicleId, source, characterId, garageId, routingBucket)
    local token = ('vehspawn:%s:%s:%s:%s'):format(vehicleId, source or 0, timer(), math.random(100000, 999999))
    spawnTokens[token] = { vehicle_id = vehicleId, source = normalizeId(source), character_id = normalizeId(characterId), garage_id = garageId, routing_bucket = normalizeId(routingBucket) or 0, expires_at = timer() + (NexaVehicleConfig.spawnTokenTtlSeconds * 1000), used = false }
    return token
end

function Vehicles.RequestSpawn(actor, vehicleId, options)
    options = type(options) == 'table' and options or {}
    local context = actorContext(actor, 'vehicle.spawn.request')
    vehicleId = normalizeId(vehicleId)
    local vehicle = hydrateVehicle(NexaVehiclesDatabase.GetVehicle(vehicleId))
    if not vehicle then return fail(NEXA_VEHICLE_ERRORS.notFound, 'Vehicle not found.') end
    if vehicle.status == NEXA_VEHICLE_STATUS.impounded or vehicle.status == NEXA_VEHICLE_STATUS.deleted then return fail(NEXA_VEHICLE_ERRORS.spawnDenied, 'Vehicle cannot be spawned.') end
    local token = makeSpawnToken(vehicleId, context.source, context.actor_character_id, options.garage_id, options.routing_bucket)
    local result = ok({ vehicle_id = vehicleId, model = vehicle.model, plate = vehicle.plate, vin = vehicle.vin, spawn_token = token, routing_bucket = options.routing_bucket or 0 }, 'Vehicle spawn authorized.')
    audit('vehicle.spawn.request', context, result, { vehicle_id = vehicleId })
    emit(NEXA_VEHICLE_EVENTS.spawnRequested, result.data)
    return result
end

function Vehicles.ConfirmSpawn(actor, token, netId, entityHandle)
    local context = actorContext(actor, 'vehicle.spawn.confirm')
    local entry = type(token) == 'string' and spawnTokens[token] or nil
    if not entry or entry.used or entry.expires_at < timer() then return fail(NEXA_VEHICLE_ERRORS.tokenInvalid, 'Spawn token is invalid.') end
    if entry.source and context.source and entry.source ~= context.source then return fail(NEXA_VEHICLE_ERRORS.tokenInvalid, 'Spawn token source mismatch.') end
    entry.used = true
    NexaVehiclesDatabase.UpdateSpawn(entry.vehicle_id, NEXA_VEHICLE_STATUS.spawned, normalizeId(netId), normalizeId(entityHandle), entry.routing_bucket)
    local result = ok({ vehicle_id = entry.vehicle_id, net_id = normalizeId(netId), entity_handle = normalizeId(entityHandle) }, 'Vehicle spawn confirmed.')
    audit('vehicle.spawn.confirm', context, result, { vehicle_id = entry.vehicle_id })
    emit(NEXA_VEHICLE_EVENTS.spawned, result.data)
    return result
end

function Vehicles.RequestDespawn(actor, vehicleId, reason)
    local context = actorContext(actor or { reason = reason }, 'vehicle.despawn.request')
    vehicleId = normalizeId(vehicleId)
    local _, err = NexaVehiclesDatabase.UpdateSpawn(vehicleId, NEXA_VEHICLE_STATUS.stored, nil, nil, nil)
    if err then return fail(NEXA_VEHICLE_ERRORS.databaseError, 'Vehicle could not be despawned.', err) end
    local result = ok({ vehicle_id = vehicleId }, 'Vehicle despawned.')
    audit('vehicle.despawn', context, result, { vehicle_id = vehicleId })
    emit(NEXA_VEHICLE_EVENTS.despawned, result.data)
    return result
end

function VehicleState.Get(vehicleId) local vehicle = Vehicles.Get(vehicleId); if not vehicle.ok then return vehicle end; return ok({ fuel = vehicle.data.fuel, mileage = vehicle.data.mileage, engine_health = vehicle.data.engine_health, body_health = vehicle.data.body_health, tank_health = vehicle.data.tank_health, damage_state = vehicle.data.damage_state, state = vehicle.data.state }, 'Vehicle state loaded.') end
function VehicleState.Update(actor, vehicleId, snapshot)
    snapshot = type(snapshot) == 'table' and snapshot or {}
    local context = actorContext(actor, 'vehicle.state.update')
    local vehicle = Vehicles.Get(vehicleId); if not vehicle.ok then return vehicle end
    local state = { fuel = math.max(0, math.min(NexaVehicleConfig.maxFuel, tonumber(snapshot.fuel or vehicle.data.fuel) or vehicle.data.fuel)), mileage = math.max(0, tonumber(snapshot.mileage or vehicle.data.mileage) or vehicle.data.mileage), engine_health = math.max(0, math.min(1000, tonumber(snapshot.engine_health or vehicle.data.engine_health) or vehicle.data.engine_health)), body_health = math.max(0, math.min(1000, tonumber(snapshot.body_health or vehicle.data.body_health) or vehicle.data.body_health)), tank_health = math.max(0, math.min(1000, tonumber(snapshot.tank_health or vehicle.data.tank_health) or vehicle.data.tank_health)), damage_state = normalizeString(snapshot.damage_state or vehicle.data.damage_state, 32) or NEXA_VEHICLE_DAMAGE_STATE.none, state = snapshot.state or vehicle.data.state or {} }
    NexaVehiclesDatabase.UpdateState(vehicle.data.id, state)
    local result = ok({ vehicle_id = vehicle.data.id, state = state }, 'Vehicle state updated.')
    audit('vehicle.state.update', context, result, { vehicle_id = vehicle.data.id, before_state = vehicle.data, after_state = state })
    emit(NEXA_VEHICLE_EVENTS.stateUpdated, result.data)
    return result
end

function VehicleFuel.Get(vehicleId) local state = VehicleState.Get(vehicleId); return state.ok and ok({ vehicle_id = vehicleId, fuel = state.data.fuel }, 'Fuel loaded.') or state end
function VehicleFuel.Set(actor, vehicleId, fuel) return VehicleState.Update(actor, vehicleId, { fuel = fuel }) end
function VehicleFuel.Consume(actor, vehicleId, amount) local state = VehicleState.Get(vehicleId); if not state.ok then return state end; return VehicleState.Update(actor, vehicleId, { fuel = math.max(0, tonumber(state.data.fuel) - (tonumber(amount) or 0)) }) end
function VehicleFuel.CanStart(vehicleId) local state = VehicleState.Get(vehicleId); return state.ok and tonumber(state.data.fuel or 0) > 0 end

function VehicleMileage.Get(vehicleId) local state = VehicleState.Get(vehicleId); return state.ok and ok({ vehicle_id = vehicleId, mileage = state.data.mileage }, 'Mileage loaded.') or state end
function VehicleMileage.Record(actor, vehicleId, delta) local state = VehicleState.Get(vehicleId); if not state.ok then return state end; delta = math.max(0, math.min(NexaVehicleConfig.maxMileageDelta, tonumber(delta) or 0)); return VehicleState.Update(actor, vehicleId, { mileage = tonumber(state.data.mileage or 0) + delta }) end

function VehicleDamage.Evaluate(snapshot)
    snapshot = type(snapshot) == 'table' and snapshot or {}
    local engine = tonumber(snapshot.engine_health or snapshot.engineHealth or 1000) or 1000
    local body = tonumber(snapshot.body_health or snapshot.bodyHealth or 1000) or 1000
    if engine <= 100 or body <= 100 then return NEXA_VEHICLE_DAMAGE_STATE.wrecked end
    if engine <= 350 or body <= 350 then return NEXA_VEHICLE_DAMAGE_STATE.heavy end
    if engine < 900 or body < 900 then return NEXA_VEHICLE_DAMAGE_STATE.light end
    return NEXA_VEHICLE_DAMAGE_STATE.none
end
function VehicleDamage.Record(actor, vehicleId, snapshot) snapshot = type(snapshot) == 'table' and snapshot or {}; snapshot.damage_state = VehicleDamage.Evaluate(snapshot); return VehicleState.Update(actor, vehicleId, snapshot) end
function VehicleDamage.Repair(actor, vehicleId) return VehicleState.Update(actor, vehicleId, { engine_health = 1000, body_health = 1000, tank_health = 1000, damage_state = NEXA_VEHICLE_DAMAGE_STATE.none }) end
function VehicleDamage.CanDrive(vehicleId) local state = VehicleState.Get(vehicleId); return state.ok and state.data.damage_state ~= NEXA_VEHICLE_DAMAGE_STATE.wrecked end

function VehicleMods.Get(vehicleId) local vehicle = Vehicles.Get(vehicleId); return vehicle.ok and ok(vehicle.data.mods or {}, 'Vehicle mods loaded.') or vehicle end
function VehicleMods.Apply(actor, vehicleId, mods) if type(mods) ~= 'table' then return fail(NEXA_VEHICLE_ERRORS.invalidInput, 'Vehicle mods are invalid.') end; local context = actorContext(actor, 'vehicle.mods.apply'); NexaVehiclesDatabase.UpdateMods(normalizeId(vehicleId), mods); local result = ok({ vehicle_id = normalizeId(vehicleId), mods = mods }, 'Vehicle mods applied.'); audit('vehicle.mods.apply', context, result, { vehicle_id = normalizeId(vehicleId), after_state = mods }); return result end
function VehicleMods.Reset(actor, vehicleId) return VehicleMods.Apply(actor, vehicleId, {}) end

function VehicleInsurance.Create(actor, vehicleId, payload) payload = type(payload) == 'table' and payload or {}; local policy = normalizeString(payload.policy_number, 64) or ('POL-%s-%s'):format(now(), math.random(1000,9999)); local id, err = NexaVehiclesDatabase.InsertInsurance({ vehicle_id = normalizeId(vehicleId), provider = normalizeString(payload.provider, 64), policy_number = policy, status = payload.status or 'active', expires_at = payload.expires_at or (now() + 2592000), metadata = payload.metadata or {} }); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Insurance could not be created.', err) or ok({ insurance_id = id, policy_number = policy }, 'Insurance created.') end
function VehicleInsurance.Get(vehicleId) local row, err = NexaVehiclesDatabase.GetInsurance(normalizeId(vehicleId)); return err and fail(NEXA_VEHICLE_ERRORS.databaseError, 'Insurance could not be loaded.', err) or ok(row, 'Insurance loaded.') end

function VehicleMaintenance.Record(actor, vehicleId, payload) local vehicle = Vehicles.Get(vehicleId); if not vehicle.ok then return vehicle end; local metadata = vehicle.data.metadata or {}; metadata.maintenance = metadata.maintenance or {}; metadata.maintenance[#metadata.maintenance + 1] = payload or {}; return ok({ vehicle_id = vehicleId, maintenance = metadata.maintenance }, 'Maintenance recorded.') end
function VehicleMaintenance.GetHistory(vehicleId) local vehicle = Vehicles.Get(vehicleId); return vehicle.ok and ok((vehicle.data.metadata or {}).maintenance or {}, 'Maintenance history loaded.') or vehicle end

function VehicleTheft.BeginLockpick(actor, vehicleId) local context = actorContext(actor, 'vehicle.theft.lockpick'); local id = normalizeId(vehicleId); theftAttempts[id] = { type = 'lockpick', actor_character_id = context.actor_character_id, started_at = now() }; emit(NEXA_VEHICLE_EVENTS.theftAttempted, { vehicle_id = id, type = 'lockpick' }); return ok({ vehicle_id = id, allowed = true }, 'Lockpick attempt recorded.') end
function VehicleTheft.BeginHotwire(actor, vehicleId) local context = actorContext(actor, 'vehicle.theft.hotwire'); local id = normalizeId(vehicleId); theftAttempts[id] = { type = 'hotwire', actor_character_id = context.actor_character_id, started_at = now() }; emit(NEXA_VEHICLE_EVENTS.theftAttempted, { vehicle_id = id, type = 'hotwire' }); return ok({ vehicle_id = id, allowed = true }, 'Hotwire attempt recorded.') end
function VehicleTheft.GetStatus(vehicleId) return ok(theftAttempts[normalizeId(vehicleId)], 'Theft status loaded.') end

function MarkVehicleImpounded(vehicleId, impoundId) NexaVehiclesDatabase.MarkImpounded(normalizeId(vehicleId), normalizeId(impoundId)); emit(NEXA_VEHICLE_EVENTS.impounded, { vehicle_id = normalizeId(vehicleId), impound_id = normalizeId(impoundId) }); return ok({ vehicle_id = normalizeId(vehicleId), impound_id = normalizeId(impoundId) }, 'Vehicle marked impounded.') end
function SetVehicleGarage(vehicleId, garageId, status) NexaVehiclesDatabase.SetGarage(normalizeId(vehicleId), normalizeString(tostring(garageId or ''), 64), status or NEXA_VEHICLE_STATUS.stored); return ok({ vehicle_id = normalizeId(vehicleId), garage_id = garageId }, 'Vehicle garage updated.') end

function RegisterVehicleDefinition(...) return VehicleDefinitions.Register(...) end
function GetVehicleDefinition(...) return VehicleDefinitions.Get(...) end
function ListVehicleDefinitions(...) return VehicleDefinitions.List(...) end
function GetVehicle(...) return Vehicles.Get(...) end
function GetVehicleByVin(...) return Vehicles.GetByVin(...) end
function GetVehicleByPlate(...) return Vehicles.GetByPlate(...) end
function ListCharacterVehicles(characterId) return Vehicles.ListForOwner(NEXA_VEHICLE_OWNER_TYPES.character, characterId) end
function ListOrganizationVehicles(organizationId) return Vehicles.ListForOwner(NEXA_VEHICLE_OWNER_TYPES.organization, organizationId) end
function CreateVehicle(...) return Vehicles.Create(...) end
function TransferVehicle(...) return VehicleOwnership.Transfer(...) end
function RequestVehicleSpawn(...) return Vehicles.RequestSpawn(...) end
function ConfirmVehicleSpawn(...) return Vehicles.ConfirmSpawn(...) end
function RequestVehicleDespawn(...) return Vehicles.RequestDespawn(...) end
function GetVehicleState(...) return VehicleState.Get(...) end
function UpdateVehicleState(...) return VehicleState.Update(...) end
function RecordVehicleDamage(...) return VehicleDamage.Record(...) end
function RepairVehicleDamage(...) return VehicleDamage.Repair(...) end
function GetVehicleFuel(...) return VehicleFuel.Get(...) end
function SetVehicleFuel(...) return VehicleFuel.Set(...) end
function ConsumeVehicleFuel(...) return VehicleFuel.Consume(...) end
function GetVehicleMileage(...) return VehicleMileage.Get(...) end
function RecordVehicleMileage(...) return VehicleMileage.Record(...) end
function GetVehicleMods(...) return VehicleMods.Get(...) end
function ApplyVehicleMods(...) return VehicleMods.Apply(...) end
function CreateVehicleInsurance(...) return VehicleInsurance.Create(...) end
function GetVehicleInsurance(...) return VehicleInsurance.Get(...) end
function RecordVehicleMaintenance(...) return VehicleMaintenance.Record(...) end
function GetVehicleMaintenanceHistory(...) return VehicleMaintenance.GetHistory(...) end
function BeginVehicleLockpick(...) return VehicleTheft.BeginLockpick(...) end
function BeginVehicleHotwire(...) return VehicleTheft.BeginHotwire(...) end
function GetVehicleTheftStatus(...) return VehicleTheft.GetStatus(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaVehicleConfig.autoMigrate then migrated = NexaVehiclesDatabase.Migrate() == true end
    log('Info', 'vehicles.start', 'nexa_vehicles started.', { migrated = migrated })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    spawnTokens = {}
    theftAttempts = {}
end)

exports('RegisterVehicleDefinition', RegisterVehicleDefinition)
exports('GetVehicleDefinition', GetVehicleDefinition)
exports('ListVehicleDefinitions', ListVehicleDefinitions)
exports('GetVehicle', GetVehicle)
exports('GetVehicleByVin', GetVehicleByVin)
exports('GetVehicleByPlate', GetVehicleByPlate)
exports('ListCharacterVehicles', ListCharacterVehicles)
exports('ListOrganizationVehicles', ListOrganizationVehicles)
exports('CreateVehicle', CreateVehicle)
exports('TransferVehicle', TransferVehicle)
exports('RequestVehicleSpawn', RequestVehicleSpawn)
exports('ConfirmVehicleSpawn', ConfirmVehicleSpawn)
exports('RequestVehicleDespawn', RequestVehicleDespawn)
exports('GetVehicleState', GetVehicleState)
exports('UpdateVehicleState', UpdateVehicleState)
exports('RecordVehicleDamage', RecordVehicleDamage)
exports('RepairVehicleDamage', RepairVehicleDamage)
exports('GetVehicleFuel', GetVehicleFuel)
exports('SetVehicleFuel', SetVehicleFuel)
exports('ConsumeVehicleFuel', ConsumeVehicleFuel)
exports('GetVehicleMileage', GetVehicleMileage)
exports('RecordVehicleMileage', RecordVehicleMileage)
exports('GetVehicleMods', GetVehicleMods)
exports('ApplyVehicleMods', ApplyVehicleMods)
exports('CreateVehicleInsurance', CreateVehicleInsurance)
exports('GetVehicleInsurance', GetVehicleInsurance)
exports('RecordVehicleMaintenance', RecordVehicleMaintenance)
exports('GetVehicleMaintenanceHistory', GetVehicleMaintenanceHistory)
exports('BeginVehicleLockpick', BeginVehicleLockpick)
exports('BeginVehicleHotwire', BeginVehicleHotwire)
exports('GetVehicleTheftStatus', GetVehicleTheftStatus)
exports('MarkVehicleImpounded', MarkVehicleImpounded)
exports('SetVehicleGarage', SetVehicleGarage)
exports('getStatus', function() return { resourceName = NEXA_VEHICLES.resourceName, version = NEXA_VEHICLES.version, migrated = migrated, spawnTokens = spawnTokens } end)
exports('getSchema', NexaVehiclesDatabase.GetSchema)
