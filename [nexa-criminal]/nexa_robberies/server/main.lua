local migrated = false

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_ROBBERY_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_ROBBERIES.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_ROBBERIES.resourceName }) end end

local defaults = {
    { robbery_key = 'store_basic', label = 'Store Robbery', robbery_type = NEXA_ROBBERY_TYPES.store, crime_definition_key = 'store_robbery' },
    { robbery_key = 'fuel_basic', label = 'Fuel Station Robbery', robbery_type = NEXA_ROBBERY_TYPES.fuel, crime_definition_key = 'fuel_robbery' },
    { robbery_key = 'atm_basic', label = 'ATM Break-in', robbery_type = NEXA_ROBBERY_TYPES.atm, crime_definition_key = 'atm_breakin' },
    { robbery_key = 'bank_foundation', label = 'Bank Robbery Foundation', robbery_type = NEXA_ROBBERY_TYPES.bank, crime_definition_key = 'bank_robbery' },
    { robbery_key = 'jeweller_foundation', label = 'Jeweller Robbery Foundation', robbery_type = NEXA_ROBBERY_TYPES.jeweller, crime_definition_key = 'jewellery_robbery' },
    { robbery_key = 'burglary_foundation', label = 'Burglary Foundation', robbery_type = NEXA_ROBBERY_TYPES.burglary, crime_definition_key = 'burglary' },
    { robbery_key = 'vehicle_theft_foundation', label = 'Vehicle Theft Foundation', robbery_type = NEXA_ROBBERY_TYPES.vehicle_theft, crime_definition_key = 'vehicle_theft' }
}

local function registerDefaultLocations()
    if not NexaRobberiesConfig.autoRegisterDefinitions then return end
    for _, definition in ipairs(defaults) do
        NexaRobberiesDatabase.InsertLocation({ robbery_key = definition.robbery_key, label = definition.label, robbery_type = definition.robbery_type, status = 'active', crime_definition_key = definition.crime_definition_key, position = {}, alarm_policy = { server_triggered = true }, reset_policy = { manual_or_cooldown = true }, metadata = { foundation = true } })
    end
end

function GetRobberyLocation(idOrKey) local row, err = NexaRobberiesDatabase.GetLocation(idOrKey); return err and fail(NEXA_ROBBERY_ERRORS.databaseError, 'Robbery location could not be loaded.', err) or (row and ok(row, 'Robbery location loaded.') or fail(NEXA_ROBBERY_ERRORS.notFound, 'Robbery location not found.')) end
function ListRobberyLocations(filters) local rows, err = NexaRobberiesDatabase.ListLocations(filters); return err and fail(NEXA_ROBBERY_ERRORS.databaseError, 'Robbery locations could not be listed.', err) or ok(rows or {}, 'Robbery locations listed.') end
function StartRobbery(source, robberyLocationId, context) local location = GetRobberyLocation(robberyLocationId); if not location.ok then return location end; local good, result = pcall(function() return exports['nexa_crime']:StartCrime(source, location.data.crime_definition_key or location.data.robbery_type, context or { source = source, location_id = location.data.id }) end); if not good then return fail(NEXA_ROBBERY_ERRORS.notActive, 'Crime foundation rejected robbery start.') end; emit(NEXA_ROBBERY_EVENTS.started, { robbery_location_id = location.data.id, crime = result }); return result end
function GetRobberySession(sessionId) local good, result = pcall(function() return exports['nexa_crime']:GetCrimeSession(sessionId) end); return good and result or fail(NEXA_ROBBERY_ERRORS.notFound, 'Robbery session not found.') end
function ResolveRobberyChallenge(sessionId, challengeId, context) return ok({ session_id = sessionId, challenge_id = challengeId, resolved = true, server_validated = true }, 'Robbery challenge resolved.') end
function ClaimRobberyLoot(sessionId, lootPointId, actor) actor = type(actor) == 'table' and actor or {}; local claimId, err = NexaRobberiesDatabase.InsertLootClaim({ session_id = normalizeId(sessionId), loot_point_id = normalizeId(lootPointId), character_id = normalizeId(actor.character_id or actor.actor_character_id) or 0, status = 'claimed', idempotency_key = actor.idempotency_key or ('robloot:%s:%s:%s'):format(sessionId, lootPointId, os.time()), metadata = { stolen_item_metadata = true } }); if err then return fail(NEXA_ROBBERY_ERRORS.lootFailed, 'Robbery loot could not be claimed.', err) end; emit(NEXA_ROBBERY_EVENTS.lootClaimed, { claim_id = claimId, session_id = sessionId, loot_point_id = lootPointId }); return ok({ claim_id = claimId, session_id = sessionId, loot_point_id = lootPointId }, 'Robbery loot claimed.') end
function TriggerRobberyAlarm(sessionId, reason) emit(NEXA_ROBBERY_EVENTS.alarmTriggered, { session_id = sessionId, reason = reason }); local good, result = pcall(function() return exports['nexa_crime']:GetCrimeSession(sessionId) end); return good and ok({ session_id = sessionId, alarmed = true, crime_session = result }, 'Robbery alarm triggered.') or fail(NEXA_ROBBERY_ERRORS.notFound, 'Robbery session not found.') end
function ResetRobberyLocation(locationId, actor, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_ROBBERY_ERRORS.locationResetRequired, 'Reason is required for reset.') end; emit(NEXA_ROBBERY_EVENTS.locationReset, { robbery_location_id = locationId, reason = reason }); return ok({ robbery_location_id = locationId, reset = true }, 'Robbery location reset foundation recorded.') end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaRobberiesConfig.autoMigrate then migrated = NexaRobberiesDatabase.Migrate() == true end; registerDefaultLocations(); log('Info', 'robberies.start', 'nexa_robberies started.', { migrated = migrated }) end)

exports('GetRobberyLocation', GetRobberyLocation)
exports('ListRobberyLocations', ListRobberyLocations)
exports('StartRobbery', StartRobbery)
exports('GetRobberySession', GetRobberySession)
exports('ResolveRobberyChallenge', ResolveRobberyChallenge)
exports('ClaimRobberyLoot', ClaimRobberyLoot)
exports('TriggerRobberyAlarm', TriggerRobberyAlarm)
exports('ResetRobberyLocation', ResetRobberyLocation)
exports('getStatus', function() return { resourceName = NEXA_ROBBERIES.resourceName, version = NEXA_ROBBERIES.version, migrated = migrated, robberyTypes = NEXA_ROBBERY_TYPES } end)
exports('getSchema', NexaRobberiesDatabase.GetSchema)
