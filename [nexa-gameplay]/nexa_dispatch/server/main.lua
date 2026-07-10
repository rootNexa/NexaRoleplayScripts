local migrated = false
local adapters = {}
local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_DISPATCH_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_DISPATCH.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_DISPATCH.resourceName }) end end
function CreateDispatchCall(payload) payload = type(payload) == 'table' and payload or {}; local id, err = NexaDispatchDatabase.InsertCall({ call_type = payload.call_type or 'emergency', status = NEXA_DISPATCH_CALL_STATUS.created, priority = tonumber(payload.priority) or NexaDispatchConfig.defaultCallPriority, caller_character_id = tonumber(payload.caller_character_id), location = payload.location or {}, description = payload.description, metadata = payload.metadata or {} }); if err then return fail(NEXA_DISPATCH_ERRORS.databaseError, 'Dispatch call could not be created.', err) end; emit(NEXA_DISPATCH_EVENTS.callCreated, { call_id = id }); return ok({ call_id = id }, 'Dispatch call created.') end
function ListDispatchCalls() local rows, err = NexaDispatchDatabase.ListCalls(); return err and fail(NEXA_DISPATCH_ERRORS.databaseError, 'Dispatch calls could not be listed.', err) or ok(rows or {}, 'Dispatch calls listed.') end
function AssignDispatchUnit(callId, unitKey, actor) local id, err = NexaDispatchDatabase.InsertAssignment({ call_id = tonumber(callId), unit_key = unitKey, assigned_by = type(actor) == 'table' and tonumber(actor.character_id) or nil, status = 'assigned', metadata = {} }); if err then return fail(NEXA_DISPATCH_ERRORS.databaseError, 'Dispatch unit could not be assigned.', err) end; emit(NEXA_DISPATCH_EVENTS.unitAssigned, { assignment_id = id, call_id = callId, unit_key = unitKey }); return ok({ assignment_id = id }, 'Dispatch unit assigned.') end
function UpdateDispatchStatus(callId, status) NexaDispatchDatabase.SetCallStatus(tonumber(callId), status); emit(NEXA_DISPATCH_EVENTS.callStatusChanged, { call_id = callId, status = status }); return ok({ call_id = callId, status = status }, 'Dispatch status updated.') end
function SetUnitStatus(unitKey, status, payload) payload = type(payload) == 'table' and payload or {}; NexaDispatchDatabase.UpsertUnit({ unit_key = unitKey, label = payload.label or unitKey, unit_type = payload.unit_type or 'police', status = status or NexaDispatchConfig.defaultUnitStatus, gps = payload.gps or {}, organization_id = tonumber(payload.organization_id), metadata = payload.metadata or {} }); emit(NEXA_DISPATCH_EVENTS.unitStatusChanged, { unit_key = unitKey, status = status }); return ok({ unit_key = unitKey, status = status }, 'Unit status updated.') end
function GetUnitStatus(unitKey) local row, err = NexaDispatchDatabase.GetUnit(unitKey); return err and fail(NEXA_DISPATCH_ERRORS.databaseError, 'Unit could not be loaded.', err) or (row and ok(row, 'Unit loaded.') or fail(NEXA_DISPATCH_ERRORS.unitNotFound, 'Unit not found.')) end
function RegisterDispatchAdapter(name, adapter) if type(name) ~= 'string' or type(adapter) ~= 'table' then return false end; adapters[name] = adapter; return true end
AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaDispatchConfig.autoMigrate then migrated = NexaDispatchDatabase.Migrate() == true end; log('Info', 'dispatch.start', 'nexa_dispatch started.', { migrated = migrated }) end)
exports('CreateDispatchCall', CreateDispatchCall)
exports('ListDispatchCalls', ListDispatchCalls)
exports('AssignDispatchUnit', AssignDispatchUnit)
exports('UpdateDispatchStatus', UpdateDispatchStatus)
exports('SetUnitStatus', SetUnitStatus)
exports('GetUnitStatus', GetUnitStatus)
exports('RegisterDispatchAdapter', RegisterDispatchAdapter)
exports('getStatus', function() return { resourceName = NEXA_DISPATCH.resourceName, version = NEXA_DISPATCH.version, migrated = migrated, adapters = adapters } end)
exports('getSchema', NexaDispatchDatabase.GetSchema)
