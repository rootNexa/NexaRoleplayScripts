local migrated = false

VehicleKeys = {}
VehicleAccess = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_VEHICLEKEY_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
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
    print(('[%s] [%s] %s'):format(NEXA_VEHICLEKEYS.resourceName, level, message))
end

local function actorContext(actor)
    actor = type(actor) == 'table' and actor or {}
    return { actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_VEHICLEKEYS.resourceName, 64) }
end

function VehicleKeys.Has(vehicleId, holderType, holderId)
    vehicleId = normalizeId(vehicleId)
    holderType = normalizeString(holderType or 'character', 32)
    holderId = normalizeString(tostring(holderId or ''), 64)
    if not vehicleId or not holderType or not holderId then return false end
    local row = NexaVehicleKeysDatabase.GetKey(vehicleId, holderType, holderId)
    return row ~= nil
end

function VehicleKeys.List(vehicleId)
    local rows, err = NexaVehicleKeysDatabase.ListKeys(normalizeId(vehicleId))
    return err and fail(NEXA_VEHICLEKEY_ERRORS.databaseError, 'Vehicle keys could not be listed.', err) or ok(rows or {}, 'Vehicle keys listed.')
end

function VehicleKeys.Issue(actor, payload)
    payload = type(payload) == 'table' and payload or {}
    local context = actorContext(actor)
    local vehicleId = normalizeId(payload.vehicle_id)
    local holderType = normalizeString(payload.holder_type or 'character', 32)
    local holderId = normalizeString(tostring(payload.holder_id or ''), 64)
    local accessLevel = normalizeString(payload.access_level or NexaVehicleKeysConfig.defaultAccessLevel, 32)
    if not vehicleId or not holderType or not holderId or not accessLevel then return fail(NEXA_VEHICLEKEY_ERRORS.invalidInput, 'Vehicle key payload is invalid.') end
    if NexaVehicleKeysDatabase.GetKey(vehicleId, holderType, holderId) then return fail(NEXA_VEHICLEKEY_ERRORS.duplicate, 'Vehicle key already exists.') end
    local id, err = NexaVehicleKeysDatabase.InsertKey({ vehicle_id = vehicleId, holder_type = holderType, holder_id = holderId, access_level = accessLevel, issued_by_account_id = context.actor_account_id, issued_by_character_id = context.actor_character_id, expires_at = payload.expires_at or 2147483647, metadata = payload.metadata or {} })
    return err and fail(NEXA_VEHICLEKEY_ERRORS.databaseError, 'Vehicle key could not be issued.', err) or ok({ key_id = id, vehicle_id = vehicleId }, 'Vehicle key issued.')
end

function VehicleKeys.Revoke(actor, keyId)
    keyId = normalizeId(keyId)
    if not keyId then return fail(NEXA_VEHICLEKEY_ERRORS.invalidInput, 'Vehicle key id is invalid.') end
    local _, err = NexaVehicleKeysDatabase.RevokeKey(keyId)
    return err and fail(NEXA_VEHICLEKEY_ERRORS.databaseError, 'Vehicle key could not be revoked.', err) or ok({ key_id = keyId }, 'Vehicle key revoked.')
end

function VehicleKeys.Share(actor, vehicleId, targetCharacterId, options)
    options = type(options) == 'table' and options or {}
    return VehicleKeys.Issue(actor, { vehicle_id = vehicleId, holder_type = 'character', holder_id = targetCharacterId, access_level = options.access_level or 'temporary', expires_at = options.expires_at, metadata = options.metadata })
end

function VehicleAccess.CanAccess(vehicleId, holderType, holderId)
    return ok({ vehicle_id = normalizeId(vehicleId), can_access = VehicleKeys.Has(vehicleId, holderType, holderId) }, 'Vehicle access evaluated.')
end

function VehicleAccess.SetLockState(actor, vehicleId, locked, engineEnabled, alarmActive)
    vehicleId = normalizeId(vehicleId)
    if not vehicleId then return fail(NEXA_VEHICLEKEY_ERRORS.invalidInput, 'Vehicle id is invalid.') end
    local _, err = NexaVehicleKeysDatabase.SetLockState(vehicleId, locked == true, engineEnabled == true, alarmActive == true)
    return err and fail(NEXA_VEHICLEKEY_ERRORS.databaseError, 'Vehicle access state could not be saved.', err) or ok({ vehicle_id = vehicleId, locked = locked == true, engine_enabled = engineEnabled == true, alarm_active = alarmActive == true }, 'Vehicle access state saved.')
end

function HasVehicleKey(...) return VehicleKeys.Has(...) end
function ListVehicleKeys(...) return VehicleKeys.List(...) end
function IssueVehicleKey(...) return VehicleKeys.Issue(...) end
function RevokeVehicleKey(...) return VehicleKeys.Revoke(...) end
function ShareVehicleKey(...) return VehicleKeys.Share(...) end
function CanAccessVehicle(...) return VehicleAccess.CanAccess(...) end
function SetVehicleLockState(...) return VehicleAccess.SetLockState(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaVehicleKeysConfig.autoMigrate then migrated = NexaVehicleKeysDatabase.Migrate() == true end
    log('Info', 'vehiclekeys.start', 'nexa_vehiclekeys started.', { migrated = migrated })
end)

exports('HasVehicleKey', HasVehicleKey)
exports('ListVehicleKeys', ListVehicleKeys)
exports('IssueVehicleKey', IssueVehicleKey)
exports('RevokeVehicleKey', RevokeVehicleKey)
exports('ShareVehicleKey', ShareVehicleKey)
exports('CanAccessVehicle', CanAccessVehicle)
exports('SetVehicleLockState', SetVehicleLockState)
exports('getStatus', function() return { resourceName = NEXA_VEHICLEKEYS.resourceName, version = NEXA_VEHICLEKEYS.version, migrated = migrated } end)
exports('getSchema', NexaVehicleKeysDatabase.GetSchema)
