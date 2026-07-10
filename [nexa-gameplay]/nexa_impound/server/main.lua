local migrated = false

Impound = {}

local function response(success, code, message, data, meta)
    return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_IMPOUND_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } }
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
    print(('[%s] [%s] %s'):format(NEXA_IMPOUND.resourceName, level, message))
end

local function actorContext(actor)
    actor = type(actor) == 'table' and actor or {}
    return { actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_IMPOUND.resourceName, 64) }
end

function Impound.Create(actor, payload)
    payload = type(payload) == 'table' and payload or {}
    local context = actorContext(actor)
    local vehicleId = normalizeId(payload.vehicle_id)
    local reason = normalizeString(payload.reason or NexaImpoundConfig.defaultReason, 255)
    if not vehicleId or not reason then return fail(NEXA_IMPOUND_ERRORS.invalidInput, 'Impound payload is invalid.') end
    local id, err = NexaImpoundDatabase.InsertImpound({ vehicle_id = vehicleId, impound_type = normalizeString(payload.impound_type or 'standard', 32), reason = reason, status = NEXA_IMPOUND_STATUS.active, fee_amount = normalizeId(payload.fee_amount) or 0, billing_invoice_id = normalizeId(payload.billing_invoice_id), impounded_by_account_id = context.actor_account_id, impounded_by_character_id = context.actor_character_id, release_garage_id = payload.release_garage_id, metadata = payload.metadata or {} })
    if err then return fail(NEXA_IMPOUND_ERRORS.databaseError, 'Vehicle could not be impounded.', err) end
    exports['nexa_vehicles']:MarkVehicleImpounded(vehicleId, id)
    return ok({ impound_id = id, vehicle_id = vehicleId }, 'Vehicle impounded.')
end

function Impound.Get(id)
    local row, err = NexaImpoundDatabase.GetImpound(normalizeId(id))
    if err then return fail(NEXA_IMPOUND_ERRORS.databaseError, 'Impound could not be loaded.', err) end
    return row and ok(row, 'Impound loaded.') or fail(NEXA_IMPOUND_ERRORS.notFound, 'Impound not found.')
end

function Impound.List(filter) local rows, err = NexaImpoundDatabase.ListImpounds(filter); return err and fail(NEXA_IMPOUND_ERRORS.databaseError, 'Impounds could not be listed.', err) or ok(rows or {}, 'Impounds listed.') end

function Impound.Release(actor, impoundId, releaseGarageId)
    local context = actorContext(actor)
    local impound = Impound.Get(impoundId)
    if not impound.ok then return impound end
    if impound.data.status ~= NEXA_IMPOUND_STATUS.active then return fail(NEXA_IMPOUND_ERRORS.alreadyReleased, 'Impound is not active.') end
    local _, err = NexaImpoundDatabase.Release(impound.data.id, context, releaseGarageId or impound.data.release_garage_id)
    if err then return fail(NEXA_IMPOUND_ERRORS.databaseError, 'Impound could not be released.', err) end
    exports['nexa_vehicles']:SetVehicleGarage(impound.data.vehicle_id, releaseGarageId or impound.data.release_garage_id, 'stored')
    return ok({ impound_id = impound.data.id, vehicle_id = impound.data.vehicle_id }, 'Vehicle released.')
end

function Impound.Cancel(actor, impoundId)
    local id = normalizeId(impoundId)
    if not id then return fail(NEXA_IMPOUND_ERRORS.invalidInput, 'Impound id is invalid.') end
    local _, err = NexaImpoundDatabase.Cancel(id)
    return err and fail(NEXA_IMPOUND_ERRORS.databaseError, 'Impound could not be cancelled.', err) or ok({ impound_id = id }, 'Impound cancelled.')
end

function ImpoundVehicle(...) return Impound.Create(...) end
function ReleaseVehicle(...) return Impound.Release(...) end
function GetImpound(...) return Impound.Get(...) end
function ListImpounds(...) return Impound.List(...) end
function CancelImpound(...) return Impound.Cancel(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if NexaImpoundConfig.autoMigrate then migrated = NexaImpoundDatabase.Migrate() == true end
    log('Info', 'impound.start', 'nexa_impound started.', { migrated = migrated })
end)

exports('ImpoundVehicle', ImpoundVehicle)
exports('ReleaseVehicle', ReleaseVehicle)
exports('GetImpound', GetImpound)
exports('ListImpounds', ListImpounds)
exports('CancelImpound', CancelImpound)
exports('getStatus', function() return { resourceName = NEXA_IMPOUND.resourceName, version = NEXA_IMPOUND.version, migrated = migrated } end)
exports('getSchema', NexaImpoundDatabase.GetSchema)
