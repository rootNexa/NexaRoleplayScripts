local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_EMS_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_EMS.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_EMS.resourceName }) end end
local function registerCallback(name, handler) if GetResourceState('nexa_api') == 'started' then exports.nexa_api:RegisterServerCallback(name, handler) end end

function InspectPatient(patientCharacterId, payload)
    payload = type(payload) == 'table' and payload or {}
    local patient = normalizeId(patientCharacterId)
    if not patient then return fail(NEXA_EMS_ERRORS.patientInvalid, 'Patient is invalid.') end
    local medical = GetResourceState('nexa_medical') == 'started' and exports.nexa_medical:InspectPatient(patient) or nil
    local id, err = NexaEmsDatabase.InsertInspection({ patient_character_id = patient, provider_character_id = normalizeId(payload.provider_character_id), triage_status = payload.triage_status, summary = payload.summary, metadata = { medical = medical and medical.data or nil } })
    if err then return fail(NEXA_EMS_ERRORS.databaseError, 'EMS inspection could not be recorded.', err) end
    emit(NEXA_EMS_EVENTS.inspectionCreated, { inspection_id = id, patient_character_id = patient })
    return ok({ inspection_id = id, medical = medical and medical.data or nil }, 'EMS inspection recorded.')
end

function StartPatientTransport(patientCharacterId, payload)
    payload = type(payload) == 'table' and payload or {}
    local patient = normalizeId(patientCharacterId)
    if not patient then return fail(NEXA_EMS_ERRORS.patientInvalid, 'Patient is invalid.') end
    local id, err = NexaEmsDatabase.InsertTransport({ patient_character_id = patient, provider_character_id = normalizeId(payload.provider_character_id), vehicle_reference = payload.vehicle_reference, hospital_key = payload.hospital_key or NexaEmsConfig.defaultHospital, status = NEXA_EMS_TRANSPORT_STATUS.active, metadata = payload.metadata or {} })
    if err then return fail(NEXA_EMS_ERRORS.databaseError, 'EMS transport could not be started.', err) end
    emit(NEXA_EMS_EVENTS.transportStarted, { transport_id = id, patient_character_id = patient })
    return ok({ transport_id = id }, 'EMS transport started.')
end

function CompletePatientTransport(transportId, payload)
    payload = type(payload) == 'table' and payload or {}
    local id = normalizeId(transportId)
    if not id then return fail(NEXA_EMS_ERRORS.transportInvalid, 'EMS transport is invalid.') end
    NexaEmsDatabase.CompleteTransport(id, NEXA_EMS_TRANSPORT_STATUS.delivered)
    emit(NEXA_EMS_EVENTS.transportCompleted, { transport_id = id })
    return ok({ transport_id = id, hospital_key = payload.hospital_key or NexaEmsConfig.defaultHospital }, 'EMS transport completed.')
end

function CreateHospitalRecord(patientCharacterId, payload)
    payload = type(payload) == 'table' and payload or {}
    local patient = normalizeId(patientCharacterId)
    if not patient then return fail(NEXA_EMS_ERRORS.patientInvalid, 'Patient is invalid.') end
    local id, err = NexaEmsDatabase.InsertHospitalRecord({ patient_character_id = patient, provider_character_id = normalizeId(payload.provider_character_id), hospital_key = payload.hospital_key or NexaEmsConfig.defaultHospital, record_type = payload.record_type or 'treatment', summary = payload.summary, metadata = payload.metadata or {} })
    if err then return fail(NEXA_EMS_ERRORS.databaseError, 'Hospital record could not be created.', err) end
    emit(NEXA_EMS_EVENTS.recordCreated, { hospital_record_id = id, patient_character_id = patient })
    return ok({ hospital_record_id = id }, 'Hospital record created.')
end

local function registerCallbacks()
    registerCallback('nexa:ems:cb:inspectPatient', function(_, payload) payload = type(payload) == 'table' and payload or {}; return InspectPatient(payload.patient_character_id, payload) end)
    registerCallback('nexa:ems:cb:startTransport', function(_, payload) payload = type(payload) == 'table' and payload or {}; return StartPatientTransport(payload.patient_character_id, payload) end)
    registerCallback('nexa:ems:cb:completeTransport', function(_, payload) payload = type(payload) == 'table' and payload or {}; return CompletePatientTransport(payload.transport_id, payload) end)
    registerCallback('nexa:ems:cb:createHospitalRecord', function(_, payload) payload = type(payload) == 'table' and payload or {}; return CreateHospitalRecord(payload.patient_character_id, payload) end)
end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaEmsConfig.autoMigrate then migrated = NexaEmsDatabase.Migrate() == true end; registerCallbacks(); log('Info', 'ems.start', 'nexa_ems started.', { migrated = migrated }) end)

exports('InspectPatient', InspectPatient)
exports('StartPatientTransport', StartPatientTransport)
exports('CompletePatientTransport', CompletePatientTransport)
exports('CreateHospitalRecord', CreateHospitalRecord)
exports('getStatus', function() return { resourceName = NEXA_EMS.resourceName, version = NEXA_EMS.version, migrated = migrated } end)
exports('getSchema', NexaEmsDatabase.GetSchema)
