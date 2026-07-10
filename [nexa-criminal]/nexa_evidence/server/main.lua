local migrated = false
local hooks = {}
local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_EVIDENCE_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_EVIDENCE.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_EVIDENCE.resourceName }) end end
function CollectEvidence(payload) payload = type(payload) == 'table' and payload or {}; local id, err = NexaEvidenceDatabase.InsertEvidence({ evidence_type = payload.evidence_type or 'custom', status = payload.status or NexaEvidenceConfig.defaultStatus, collected_by = tonumber(payload.collected_by), location = payload.location or {}, reference = payload.reference or {}, metadata = payload.metadata or {} }); if err then return fail(NEXA_EVIDENCE_ERRORS.databaseError, 'Evidence could not be collected.', err) end; emit(NEXA_EVIDENCE_EVENTS.collected, { evidence_id = id }); return ok({ evidence_id = id }, 'Evidence collected.') end
function ListEvidence(filters) local rows, err = NexaEvidenceDatabase.ListEvidence(filters); return err and fail(NEXA_EVIDENCE_ERRORS.databaseError, 'Evidence could not be listed.', err) or ok(rows or {}, 'Evidence listed.') end
function UpdateEvidenceStatus(evidenceId, status) NexaEvidenceDatabase.UpdateStatus(tonumber(evidenceId), status); emit(NEXA_EVIDENCE_EVENTS.statusChanged, { evidence_id = evidenceId, status = status }); return ok({ evidence_id = evidenceId, status = status }, 'Evidence status updated.') end
function RegisterEvidenceHook(name, hook) if type(name) ~= 'string' or type(hook) ~= 'table' then return false end; hooks[name] = hook; return true end
function CreateTrace(traceType, sourceReference, payload) payload = type(payload) == 'table' and payload or {}; local id, err = NexaEvidenceDatabase.InsertTrace({ trace_type = traceType or 'custom', source_reference = sourceReference, evidence_id = tonumber(payload.evidence_id), metadata = payload.metadata or {} }); if err then return fail(NEXA_EVIDENCE_ERRORS.databaseError, 'Trace could not be created.', err) end; emit(NEXA_EVIDENCE_EVENTS.traceCreated, { trace_id = id, trace_type = traceType }); return ok({ trace_id = id }, 'Evidence trace created.') end
function StoreEvidenceLocker(evidenceId, lockerKey, payload) payload = type(payload) == 'table' and payload or {}; local id, err = NexaEvidenceDatabase.StoreLocker({ evidence_id = tonumber(evidenceId), locker_key = lockerKey or 'default', stored_by = tonumber(payload.stored_by), metadata = payload.metadata or {} }); if err then return fail(NEXA_EVIDENCE_ERRORS.databaseError, 'Evidence could not be stored.', err) end; emit(NEXA_EVIDENCE_EVENTS.lockerStored, { locker_record_id = id, evidence_id = evidenceId }); return ok({ locker_record_id = id }, 'Evidence stored in locker.') end
AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaEvidenceConfig.autoMigrate then migrated = NexaEvidenceDatabase.Migrate() == true end; log('Info', 'evidence.start', 'nexa_evidence started.', { migrated = migrated }) end)
exports('CollectEvidence', CollectEvidence)
exports('ListEvidence', ListEvidence)
exports('UpdateEvidenceStatus', UpdateEvidenceStatus)
exports('RegisterEvidenceHook', RegisterEvidenceHook)
exports('CreateTrace', CreateTrace)
exports('StoreEvidenceLocker', StoreEvidenceLocker)
exports('getStatus', function() return { resourceName = NEXA_EVIDENCE.resourceName, version = NEXA_EVIDENCE.version, migrated = migrated, hooks = hooks } end)
exports('getSchema', NexaEvidenceDatabase.GetSchema)
