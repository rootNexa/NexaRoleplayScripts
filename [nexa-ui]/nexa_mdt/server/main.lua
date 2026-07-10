local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_MDT_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[nexa_mdt] [%s] %s %s'):format(level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = 'nexa_mdt' }) end end

function CreateCase(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.title) ~= 'string' or payload.title == '' then return fail(NEXA_MDT_ERRORS.invalidInput, 'Case title is required.') end
    local caseNumber = payload.case_number or ('CASE-' .. os.time() .. '-' .. math.random(1000, 9999))
    local id, err = NexaMdtDatabase.InsertCase({ case_number = caseNumber, title = payload.title, mdt_type = payload.mdt_type or 'police', status = payload.status or 'open', created_by = normalizeId(payload.created_by), metadata = payload.metadata or {} })
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'Case could not be created.', err) end
    emit(NEXA_MDT_EVENTS.caseCreated, { case_id = id, case_number = caseNumber })
    return ok({ case_id = id, case_number = caseNumber }, 'Case created.')
end

function CreateReport(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.title) ~= 'string' or payload.title == '' then return fail(NEXA_MDT_ERRORS.invalidInput, 'Report title is required.') end
    local id, err = NexaMdtDatabase.InsertReport({ case_id = normalizeId(payload.case_id), report_type = payload.report_type or 'general', title = payload.title, narrative = payload.narrative, status = payload.status or NEXA_MDT_RECORD_STATUS.draft, created_by = normalizeId(payload.created_by), metadata = payload.metadata or {} })
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'Report could not be created.', err) end
    emit(NEXA_MDT_EVENTS.reportCreated, { report_id = id })
    return ok({ report_id = id }, 'Report created.')
end

function FinalizeReport(reportId)
    local updated, err = NexaMdtDatabase.FinalizeReport(normalizeId(reportId))
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'Report could not be finalized.', err) end
    return ok({ report_id = reportId, updated = updated }, 'Report finalized.')
end

function CreateWarrant(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.reason) ~= 'string' or payload.reason == '' then return fail(NEXA_MDT_ERRORS.invalidInput, 'Warrant reason is required.') end
    local id, err = NexaMdtDatabase.InsertWarrant({ case_id = normalizeId(payload.case_id), subject_character_id = normalizeId(payload.subject_character_id), warrant_type = payload.warrant_type or 'arrest', reason = payload.reason, status = payload.status or NEXA_MDT_WARRANT_STATUS.requested, requested_by = normalizeId(payload.requested_by), approved_by = normalizeId(payload.approved_by), expires_hours = payload.expires_hours, metadata = payload.metadata or {} })
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'Warrant could not be created.', err) end
    emit(NEXA_MDT_EVENTS.warrantCreated, { warrant_id = id })
    return ok({ warrant_id = id }, 'Warrant created.')
end

function CreateBolo(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.target_reference) ~= 'string' or payload.target_reference == '' then return fail(NEXA_MDT_ERRORS.invalidInput, 'BOLO target is required.') end
    local id, err = NexaMdtDatabase.InsertBolo({ target_type = payload.target_type or 'person', target_reference = payload.target_reference, reason = payload.reason or 'bolo', status = payload.status or 'active', created_by = normalizeId(payload.created_by), expires_hours = payload.expires_hours, metadata = payload.metadata or {} })
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'BOLO could not be created.', err) end
    emit(NEXA_MDT_EVENTS.boloCreated, { bolo_id = id })
    return ok({ bolo_id = id }, 'BOLO created.')
end

function AddNote(payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.note) ~= 'string' or payload.note == '' then return fail(NEXA_MDT_ERRORS.invalidInput, 'Note is required.') end
    local id, err = NexaMdtDatabase.InsertNote({ case_id = normalizeId(payload.case_id), subject_reference = payload.subject_reference, visibility = payload.visibility or 'organization', note = payload.note, created_by = normalizeId(payload.created_by), metadata = payload.metadata or {} })
    if err then return fail(NEXA_MDT_ERRORS.databaseError, 'Note could not be created.', err) end
    return ok({ note_id = id }, 'Note created.')
end

local function registerCallbacks()
    if GetResourceState('nexa_api') ~= 'started' then return end
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:createCase', function(_, payload) return CreateCase(payload) end)
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:createReport', function(_, payload) return CreateReport(payload) end)
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:finalizeReport', function(_, payload) payload = type(payload) == 'table' and payload or {}; return FinalizeReport(payload.report_id) end)
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:createWarrant', function(_, payload) return CreateWarrant(payload) end)
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:createBolo', function(_, payload) return CreateBolo(payload) end)
    exports.nexa_api:RegisterServerCallback('nexa:mdt:cb:addNote', function(_, payload) return AddNote(payload) end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    migrated = NexaMdtDatabase.Migrate() == true
    registerCallbacks()
    log('Info', 'mdt.start', 'nexa_mdt ready.', { migrated = migrated })
end)

exports('CreateCase', CreateCase)
exports('CreateReport', CreateReport)
exports('FinalizeReport', FinalizeReport)
exports('CreateWarrant', CreateWarrant)
exports('CreateBolo', CreateBolo)
exports('AddNote', AddNote)
exports('getSchema', NexaMdtDatabase.GetSchema)
