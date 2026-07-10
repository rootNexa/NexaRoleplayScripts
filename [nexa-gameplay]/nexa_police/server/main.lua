local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_POLICE_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_POLICE.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_POLICE.resourceName }) end end

local function registerDefaultAgencies()
    for key, label in pairs(NexaPoliceConfig.agencies) do
        NexaPoliceDatabase.InsertAgency({ agency_key = key, label = label, agency_type = NEXA_POLICE_AGENCY_TYPES[key] or 'custom', enabled = true, metadata = { foundation = true } })
    end
end

function RegisterPoliceAgency(definition) definition = type(definition) == 'table' and definition or {}; local key = normalizeString(definition.agency_key or definition.key, 64); if not key then return fail(NEXA_POLICE_ERRORS.invalidInput, 'Police agency is invalid.') end; local id, err = NexaPoliceDatabase.InsertAgency({ agency_key = key, label = definition.label or key, agency_type = definition.agency_type or 'custom', organization_id = normalizeId(definition.organization_id), enabled = definition.enabled ~= false, metadata = definition.metadata or {} }); return err and fail(NEXA_POLICE_ERRORS.databaseError, 'Police agency could not be registered.', err) or ok({ agency_id = id, agency_key = key }, 'Police agency registered.') end
function GetPoliceAgency(key) local row, err = NexaPoliceDatabase.GetAgency(key); return err and fail(NEXA_POLICE_ERRORS.databaseError, 'Police agency could not be loaded.', err) or (row and ok(row, 'Police agency loaded.') or fail(NEXA_POLICE_ERRORS.agencyNotFound, 'Police agency not found.')) end
function ListPoliceAgencies() local rows, err = NexaPoliceDatabase.ListAgencies(); return err and fail(NEXA_POLICE_ERRORS.databaseError, 'Police agencies could not be listed.', err) or ok(rows or {}, 'Police agencies listed.') end
function CreateArrest(subjectCharacterId, payload) payload = type(payload) == 'table' and payload or {}; local reason = normalizeString(payload.reason, 255); if not reason then return fail(NEXA_POLICE_ERRORS.reasonRequired, 'Reason is required.') end; local id, err = NexaPoliceDatabase.InsertArrest({ subject_character_id = normalizeId(subjectCharacterId), officer_character_id = normalizeId(payload.officer_character_id), agency_key = payload.agency_key, reason = reason, status = payload.status or 'created', metadata = payload.metadata or {} }); if err then return fail(NEXA_POLICE_ERRORS.databaseError, 'Arrest could not be created.', err) end; emit(NEXA_POLICE_EVENTS.arrestCreated, { arrest_id = id, subject_character_id = subjectCharacterId }); return ok({ arrest_id = id }, 'Arrest created.') end
function SetHandcuffed(subjectCharacterId, enabled, payload) payload = type(payload) == 'table' and payload or {}; local id = NexaPoliceDatabase.InsertRestraint({ subject_character_id = normalizeId(subjectCharacterId), officer_character_id = normalizeId(payload.officer_character_id), restraint_type = 'handcuff', enabled = enabled == true, reason = payload.reason, metadata = payload.metadata or {} }); emit(NEXA_POLICE_EVENTS.restraintChanged, { restraint_id = id, subject_character_id = subjectCharacterId, handcuffed = enabled == true }); return ok({ restraint_id = id, handcuffed = enabled == true }, 'Handcuff state recorded.') end
function SetEscorted(subjectCharacterId, enabled, payload) payload = type(payload) == 'table' and payload or {}; local id = NexaPoliceDatabase.InsertRestraint({ subject_character_id = normalizeId(subjectCharacterId), officer_character_id = normalizeId(payload.officer_character_id), restraint_type = 'escort', enabled = enabled == true, reason = payload.reason, metadata = payload.metadata or {} }); return ok({ restraint_id = id, escorted = enabled == true }, 'Escort state recorded.') end
function SearchPerson(subjectCharacterId, payload) payload = type(payload) == 'table' and payload or {}; local reason = normalizeString(payload.reason or NexaPoliceConfig.defaultSearchReason, 255); local result = { inventory_required = 'nexa_inventory', server_authoritative = true }; local id = NexaPoliceDatabase.InsertSearch({ subject_character_id = normalizeId(subjectCharacterId), officer_character_id = normalizeId(payload.officer_character_id), search_type = payload.search_type or 'person', reason = reason, result = result, metadata = payload.metadata or {} }); emit(NEXA_POLICE_EVENTS.searchPerformed, { search_id = id, subject_character_id = subjectCharacterId }); return ok({ search_id = id, result = result }, 'Person search recorded.') end
function SeizeItem(subjectCharacterId, itemReference, payload) payload = type(payload) == 'table' and payload or {}; local reason = normalizeString(payload.reason, 255); if not reason then return fail(NEXA_POLICE_ERRORS.reasonRequired, 'Reason is required.') end; local id = NexaPoliceDatabase.InsertSeizure({ subject_character_id = normalizeId(subjectCharacterId), officer_character_id = normalizeId(payload.officer_character_id), item_reference = tostring(itemReference), reason = reason, evidence_id = normalizeId(payload.evidence_id), metadata = payload.metadata or {} }); emit(NEXA_POLICE_EVENTS.itemSeized, { seizure_id = id, subject_character_id = subjectCharacterId }); return ok({ seizure_id = id }, 'Item seizure recorded.') end
function CheckWeapon(weaponReference, payload) return ok({ weapon = weaponReference, evidence_required = true, license_required = true }, 'Weapon check foundation recorded.') end
function CheckVehicle(vehicleReference, payload) emit(NEXA_POLICE_EVENTS.vehicleChecked, { vehicle = vehicleReference }); return ok({ vehicle = vehicleReference, registration_required = true, owner_lookup_required = true }, 'Vehicle check foundation recorded.') end
function CheckPerson(characterId, payload) return ok({ character_id = normalizeId(characterId), warrants_required = true, licenses_required = true, mdt_required = true }, 'Person check foundation recorded.') end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaPoliceConfig.autoMigrate then migrated = NexaPoliceDatabase.Migrate() == true end; registerDefaultAgencies(); log('Info', 'police.start', 'nexa_police started.', { migrated = migrated }) end)
exports('RegisterPoliceAgency', RegisterPoliceAgency)
exports('GetPoliceAgency', GetPoliceAgency)
exports('ListPoliceAgencies', ListPoliceAgencies)
exports('CreateArrest', CreateArrest)
exports('SetHandcuffed', SetHandcuffed)
exports('SetEscorted', SetEscorted)
exports('SearchPerson', SearchPerson)
exports('SeizeItem', SeizeItem)
exports('CheckWeapon', CheckWeapon)
exports('CheckVehicle', CheckVehicle)
exports('CheckPerson', CheckPerson)
exports('getStatus', function() return { resourceName = NEXA_POLICE.resourceName, version = NEXA_POLICE.version, migrated = migrated } end)
exports('getSchema', NexaPoliceDatabase.GetSchema)
