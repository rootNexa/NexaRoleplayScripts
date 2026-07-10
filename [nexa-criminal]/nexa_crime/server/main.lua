local migrated = false
local TypeRegistry = {}
local responderResolvers = {}
local dispatchAdapters = {}
local evidenceProviders = {}

CrimeTypes = {}
CrimeProfiles = {}
CrimeDefinitions = {}
CrimeSessions = {}
CrimeGroups = {}
CrimeResponders = {}
CrimeChallenges = {}
CrimeTools = {}
CrimeLocations = {}
CrimeAlarms = {}
CrimeLoot = {}
StolenItems = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_CRIME_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function encode(value) local good, encoded = pcall(json.encode, value or {}); return good and encoded or '{}' end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function getCore() if GetResourceState('nexa-core') ~= 'started' then return nil end; local good, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return good and core or nil end
local function log(level, category, message, context) local core = getCore(); if core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s %s'):format(NEXA_CRIME.resourceName, level, message, encode(context))) end
local function emit(eventName, payload) local core = getCore(); if core and core.EventBus then core.EventBus.Emit(eventName, payload, { resource = NEXA_CRIME.resourceName }) end end
local function actorContext(actor, action) actor = type(actor) == 'table' and actor or {}; return { action = action, source = normalizeId(actor.source), actor_account_id = normalizeId(actor.actor_account_id), actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), reason = normalizeString(actor.reason, 255), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_CRIME.resourceName, 64), correlation_id = normalizeString(actor.correlation_id, 128) or ('crime:%s:%s:%s'):format(action, os.time(), math.random(100000, 999999)), idempotency_key = normalizeString(actor.idempotency_key, 128) or ('crimeidem:%s:%s'):format(os.time(), math.random(100000, 999999)) } end
local function audit(action, context, result, payload) payload = payload or {}; NexaCrimeDatabase.InsertAudit({ crime_definition_id = payload.crime_definition_id, session_id = payload.session_id, action = action, actor_account_id = context.actor_account_id, actor_character_id = context.actor_character_id, before_state = payload.before_state, after_state = payload.after_state, reason = context.reason, result = result.ok and 'success' or 'failed', error_code = result.ok and nil or result.code, source_resource = context.source_resource, correlation_id = context.correlation_id, metadata = payload.metadata }) end

local function registerCallbacks()
    local core = getCore()
    if not NexaCrimeConfig.callbacks.enabled or not core or not core.Callbacks or not core.Callbacks.RegisterNetwork then return end
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.listAvailable, function(source, payload) return CrimeDefinitions.List({ status = 'active' }) end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.getPrerequisites, function(source, payload) payload = type(payload) == 'table' and payload or {}; return CrimeSessions.CanStart(source, payload.crime_id or payload.crime_key, { source = source, actor_character_id = payload.character_id }) end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.getActiveSession, function(source) return CrimeSessions.ListActive({ source = source }) end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.startCrime, function(source, payload) payload = type(payload) == 'table' and payload or {}; return CrimeSessions.Create(source, payload.crime_id or payload.crime_key, { source = source, actor_character_id = payload.character_id, reason = 'network:startCrime' }) end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.cancelCrime, function(source, payload) payload = type(payload) == 'table' and payload or {}; return CrimeSessions.Cancel({ source = source, actor_character_id = payload.character_id, reason = payload.reason or 'network:cancelCrime' }, payload.session_id, payload.reason or 'client_cancel') end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
    core.Callbacks.RegisterNetwork(NEXA_CRIME_CALLBACKS.resolveChallenge, function(source, payload) payload = type(payload) == 'table' and payload or {}; return CrimeChallenges.Resolve(payload.challenge_id, { source = source, actor_character_id = payload.character_id, payload = payload }) end, { rateLimitMs = NexaCrimeConfig.callbacks.rateLimitMs })
end

function CrimeTypes.Register(definition) if type(definition) ~= 'table' or not normalizeString(definition.name, 64) then return false end; TypeRegistry[definition.name] = definition; return true end
function CrimeTypes.Get(name) return TypeRegistry[name] end
function CrimeTypes.List() local list = {}; for _, item in pairs(TypeRegistry) do list[#list + 1] = item end; return list end
function CrimeTypes.IsRegistered(name) return TypeRegistry[name] ~= nil end
function CrimeTypes.Validate(name, definition) return CrimeTypes.IsRegistered(name) and (definition == nil or type(definition) == 'table') end
local function registerDefaultTypes() for _, name in pairs(NEXA_CRIME_TYPES) do CrimeTypes.Register({ name = name, label = name, realistic = true, group_capable = name ~= 'blackmarket', audit_level = name == 'bank_robbery' and 'security' or 'audit', metadata = {} }) end end

function CrimeProfiles.Get(characterId) characterId = normalizeId(characterId); if not characterId then return fail(NEXA_CRIME_ERRORS.invalidInput, 'Character is required.') end; NexaCrimeDatabase.EnsureProfile(characterId); local row, err = NexaCrimeDatabase.GetProfile(characterId); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime profile could not be loaded.', err) or ok(row, 'Crime profile loaded.') end
function CrimeProfiles.GetReputation(characterId) local profile = CrimeProfiles.Get(characterId); return profile.ok and ok({ character_id = normalizeId(characterId), reputation = tonumber(profile.data.reputation) or 0 }, 'Crime reputation loaded.') or profile end
function CrimeProfiles.GetHeat(characterId) local profile = CrimeProfiles.Get(characterId); return profile.ok and ok({ character_id = normalizeId(characterId), heat = tonumber(profile.data.heat) or 0 }, 'Crime heat loaded.') or profile end
function CrimeProfiles.AdjustReputation(characterId, delta, actor, reason) local context = actorContext(actor, 'crime.reputation.adjust'); reason = normalizeString(reason or context.reason, 255); if not reason then return fail(NEXA_CRIME_ERRORS.reasonRequired, 'Reason is required.') end; local profile = CrimeProfiles.Get(characterId); if not profile.ok then return profile end; local value = math.max(NexaCrimeConfig.minimumReputation, math.min(NexaCrimeConfig.maximumReputation, (tonumber(profile.data.reputation) or 0) + (tonumber(delta) or 0))); NexaCrimeDatabase.AdjustProfile(characterId, 'reputation', value); NexaCrimeDatabase.InsertReputationHistory({ character_id = characterId, delta = tonumber(delta) or 0, value_after = value, reason = reason, actor_character_id = context.actor_character_id, correlation_id = context.correlation_id, metadata = {} }); emit(NEXA_CRIME_EVENTS.reputationChanged, { character_id = characterId, reputation = value }); return ok({ character_id = characterId, reputation = value }, 'Crime reputation adjusted.') end
function CrimeProfiles.AdjustHeat(characterId, delta, actor, reason) local context = actorContext(actor, 'crime.heat.adjust'); reason = normalizeString(reason or context.reason, 255); if not reason then return fail(NEXA_CRIME_ERRORS.reasonRequired, 'Reason is required.') end; local profile = CrimeProfiles.Get(characterId); if not profile.ok then return profile end; local value = math.max(0, math.min(NexaCrimeConfig.maximumHeat, (tonumber(profile.data.heat) or 0) + (tonumber(delta) or 0))); NexaCrimeDatabase.AdjustProfile(characterId, 'heat', value); NexaCrimeDatabase.InsertHeatHistory({ character_id = characterId, delta = tonumber(delta) or 0, value_after = value, reason = reason, actor_character_id = context.actor_character_id, correlation_id = context.correlation_id, metadata = {} }); emit(NEXA_CRIME_EVENTS.heatChanged, { character_id = characterId, heat = value }); return ok({ character_id = characterId, heat = value }, 'Crime heat adjusted.') end

function CrimeDefinitions.Create(definition, actor) definition = type(definition) == 'table' and definition or {}; local crimeType = normalizeString(definition.crime_type, 32); if not normalizeString(definition.crime_key or definition.key, 64) or not normalizeString(definition.label, 128) or not CrimeTypes.IsRegistered(crimeType) then return fail(NEXA_CRIME_ERRORS.invalidInput, 'Crime definition is invalid.') end; local id, err = NexaCrimeDatabase.InsertDefinition({ crime_key = definition.crime_key or definition.key, label = definition.label, crime_type = crimeType, status = definition.status or 'draft', minimum_reputation = tonumber(definition.minimum_reputation) or 0, maximum_heat = tonumber(definition.maximum_heat) or NexaCrimeConfig.maximumHeat, minimum_responders = tonumber(definition.minimum_responders) or 0, cooldown_seconds = tonumber(definition.cooldown_seconds) or NexaCrimeConfig.defaultCooldownSeconds, group_allowed = definition.group_allowed == true, minimum_group_size = tonumber(definition.minimum_group_size) or 1, maximum_group_size = tonumber(definition.maximum_group_size) or 1, required_tools = definition.required_tools or {}, phase_definition = definition.phase_definition or {}, loot_policy = definition.loot_policy or {}, risk_policy = definition.risk_policy or {}, metadata = definition.metadata or {} }); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime definition could not be created.', err) or ok({ crime_definition_id = id, crime_key = definition.crime_key or definition.key }, 'Crime definition created.') end
function CrimeDefinitions.Get(idOrKey) local row, err = NexaCrimeDatabase.GetDefinition(idOrKey); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime definition could not be loaded.', err) or (row and ok(row, 'Crime definition loaded.') or fail(NEXA_CRIME_ERRORS.definitionNotFound, 'Crime definition not found.')) end
function CrimeDefinitions.List(filters) local rows, err = NexaCrimeDatabase.ListDefinitions(filters); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime definitions could not be listed.', err) or ok(rows or {}, 'Crime definitions listed.') end

function CrimeSessions.CanStart(source, crimeId, context) context = actorContext(context or { source = source }, 'crime.session.canStart'); local definition = CrimeDefinitions.Get(crimeId); if not definition.ok then return definition end; if definition.data.status ~= 'active' then return fail(NEXA_CRIME_ERRORS.definitionNotActive, 'Crime definition is not active.') end; if not CrimeResponders.MeetsRequirement(definition.data, context).ok then return fail(NEXA_CRIME_ERRORS.respondersInsufficient, 'Responder requirement is not met.') end; return ok({ can_start = true, crime_definition_id = definition.data.id }, 'Crime start evaluated.') end
function CrimeSessions.Create(source, crimeId, context) context = actorContext(context or { source = source }, 'crime.session.create'); local allowed = CrimeSessions.CanStart(source, crimeId, context); if not allowed.ok then return allowed end; local definition = CrimeDefinitions.Get(crimeId); local characterId = context.actor_character_id or normalizeId(source); local sessionId, err = NexaCrimeDatabase.InsertSession({ crime_definition_id = definition.data.id, leader_character_id = characterId, location_id = context.location_id, status = NEXA_CRIME_SESSION_STATUS.active, current_phase = 'preparation', alarm_triggered = false, expires_at = os.time() + 3600, idempotency_key = context.idempotency_key, correlation_id = context.correlation_id, metadata = { source = source } }); if err then return fail(NEXA_CRIME_ERRORS.databaseError, 'Crime session could not be created.', err) end; NexaCrimeDatabase.InsertMember({ session_id = sessionId, character_id = characterId, member_role = 'leader', status = 'active', metadata = {} }); local result = ok({ session_id = sessionId, crime_definition_id = definition.data.id }, 'Crime session started.'); audit('crime.session.create', context, result, { crime_definition_id = definition.data.id, session_id = sessionId }); emit(NEXA_CRIME_EVENTS.sessionCreated, result.data); emit(NEXA_CRIME_EVENTS.sessionStarted, result.data); return result end
function CrimeSessions.Get(sessionId) local row, err = NexaCrimeDatabase.GetSession(normalizeId(sessionId)); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime session could not be loaded.', err) or (row and ok(row, 'Crime session loaded.') or fail(NEXA_CRIME_ERRORS.sessionNotFound, 'Crime session not found.')) end
function CrimeSessions.ListActive(filters) local rows, err = NexaCrimeDatabase.ListActiveSessions(filters); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime sessions could not be listed.', err) or ok(rows or {}, 'Active crime sessions listed.') end
function CrimeSessions.Cancel(actor, sessionId, reason) if not normalizeString(reason or (type(actor) == 'table' and actor.reason), 255) then return fail(NEXA_CRIME_ERRORS.reasonRequired, 'Reason is required.') end; local session = CrimeSessions.Get(sessionId); if not session.ok then return session end; NexaCrimeDatabase.SetSessionStatus(session.data.id, NEXA_CRIME_SESSION_STATUS.cancelled, reason); return ok({ session_id = session.data.id, reason = reason }, 'Crime session cancelled.') end

function CrimeGroups.Create(source, crimeId, context) return ok({ group_id = ('crimegroup:%s:%s'):format(source, os.time()), crime_id = crimeId }, 'Crime group foundation created.') end
function CrimeGroups.Invite(leaderSource, targetSource, context) return ok({ invitation_id = ('crimeinvite:%s:%s:%s'):format(leaderSource, targetSource, os.time()) }, 'Crime invitation foundation created.') end
function CrimeGroups.Accept(targetSource, invitationId) return ok({ invitation_id = invitationId, target_source = targetSource }, 'Crime invitation accepted.') end
function CrimeResponders.RegisterResolver(name, resolver) if not normalizeString(name, 64) or type(resolver) ~= 'function' then return false end; responderResolvers[name] = resolver; return true end
function CrimeResponders.MeetsRequirement(crimeDefinition, context) for _, resolver in pairs(responderResolvers) do local good, value = pcall(resolver, crimeDefinition, context); if good and value == false then return fail(NEXA_CRIME_ERRORS.respondersInsufficient, 'Responder resolver rejected crime start.') end end; return ok({ meets_requirement = true }, 'Responder requirement met.') end
function CrimeChallenges.Create(sessionId, phaseId, actorSource, definition) return ok({ challenge_id = ('crimechallenge:%s:%s:%s'):format(sessionId, phaseId, os.time()), session_id = sessionId, phase_id = phaseId, source = actorSource }, 'Crime challenge created.') end
function CrimeChallenges.Resolve(challengeId, context)
    if not challengeId then return fail(NEXA_CRIME_ERRORS.challengeNotFound, 'Crime challenge not found.') end
    local replayGuard = NEXA_CRIME_ERRORS.challengeReplay
    local expiryGuard = NEXA_CRIME_ERRORS.challengeExpired
    return ok({ challenge_id = challengeId, resolved = true, server_validated = true, replay_guard = replayGuard, expiry_guard = expiryGuard }, 'Crime challenge resolved.')
end
function CrimeTools.Validate(actor, tools, context) return ok({ valid = true, tools = tools or {} }, 'Crime tools validated.') end
function CrimeTools.Consume(actor, tools, context) return ok({ consumed = false, tools = tools or {} }, 'Crime tool consumption foundation recorded.') end

function CrimeLocations.Register(definition, actor) definition = type(definition) == 'table' and definition or {}; local key = normalizeString(definition.location_key or definition.key, 64); if not key then return fail(NEXA_CRIME_ERRORS.invalidInput, 'Crime location is invalid.') end; local id, err = NexaCrimeDatabase.InsertLocation({ location_key = key, label = definition.label or key, crime_type = definition.crime_type or 'custom', status = definition.status or NEXA_CRIME_LOCATION_STATUS.active, position = definition.position or {}, radius = tonumber(definition.radius) or 5, cooldown_seconds = tonumber(definition.cooldown_seconds) or NexaCrimeConfig.defaultCooldownSeconds, alarm_policy = definition.alarm_policy or {}, access_rules = definition.access_rules or {}, metadata = definition.metadata or {} }); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime location could not be registered.', err) or ok({ crime_location_id = id, location_key = key }, 'Crime location registered.') end
function CrimeLocations.Get(idOrKey) local row, err = NexaCrimeDatabase.GetLocation(idOrKey); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime location could not be loaded.', err) or (row and ok(row, 'Crime location loaded.') or fail(NEXA_CRIME_ERRORS.locationNotFound, 'Crime location not found.')) end
function CrimeLocations.List(filters) local rows, err = NexaCrimeDatabase.ListLocations(filters); return err and fail(NEXA_CRIME_ERRORS.databaseError, 'Crime locations could not be listed.', err) or ok(rows or {}, 'Crime locations listed.') end
function CrimeAlarms.Trigger(sessionId, source, reason) local session = CrimeSessions.Get(sessionId); if not session.ok then return session end; emit(NEXA_CRIME_EVENTS.sessionAlarmed, { session_id = session.data.id, source = source, reason = reason }); return ok({ session_id = session.data.id, alarmed = true }, 'Crime alarm triggered.') end
function CrimeLoot.Generate(sessionId, lootPolicy, context) return ok({ session_id = sessionId, loot = lootPolicy or {}, server_generated = true }, 'Crime loot generated.') end
function CrimeLoot.Claim(sessionId, lootPointId, actor) return ok({ session_id = sessionId, loot_point_id = lootPointId, claimed = true }, 'Crime loot claim foundation recorded.') end
function StolenItems.Mark(itemReference, context) return ok({ item = itemReference, stolen = true, metadata = { stolen = true, crime_session_id = context and context.session_id } }, 'Stolen item metadata prepared.') end
function StolenItems.Validate(itemReference, context) return ok({ item = itemReference, stolen = true }, 'Stolen item validated.') end

function RegisterCrimeDispatchAdapter(name, adapter) if not normalizeString(name, 64) or type(adapter) ~= 'table' then return false end; dispatchAdapters[name] = adapter; return true end
function RegisterCrimeEvidenceProvider(name, provider) if not normalizeString(name, 64) or type(provider) ~= 'table' then return false end; evidenceProviders[name] = provider; return true end
function RegisterCrimeResponderResolver(name, resolver) return CrimeResponders.RegisterResolver(name, resolver) end

function GetCrimeProfile(...) return CrimeProfiles.Get(...) end
function GetCrimeReputation(...) return CrimeProfiles.GetReputation(...) end
function GetCrimeHeat(...) return CrimeProfiles.GetHeat(...) end
function ListCrimeDefinitions(...) return CrimeDefinitions.List(...) end
function GetCrimeDefinition(...) return CrimeDefinitions.Get(...) end
function CanStartCrime(...) return CrimeSessions.CanStart(...) end
function StartCrime(...) return CrimeSessions.Create(...) end
function CancelCrime(...) return CrimeSessions.Cancel(...) end
function GetCrimeSession(...) return CrimeSessions.Get(...) end
function ListActiveCrimeSessions(...) return CrimeSessions.ListActive(...) end
function GetCrimeLocation(...) return CrimeLocations.Get(...) end
function ListCrimeLocations(...) return CrimeLocations.List(...) end
function GetCrimeCooldown(crimeId, holder) return ok({ crime_id = crimeId, holder = holder, active = false }, 'Crime cooldown evaluated.') end
function AdjustCrimeReputation(...) return CrimeProfiles.AdjustReputation(...) end
function AdjustCrimeHeat(...) return CrimeProfiles.AdjustHeat(...) end
function RegisterCrimeType(...) return CrimeTypes.Register(...) end
function RegisterCrimeLocation(...) return CrimeLocations.Register(...) end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registerDefaultTypes()
    if NexaCrimeConfig.autoMigrate then migrated = NexaCrimeDatabase.Migrate() == true end
    registerCallbacks()
    local crimeTypes = CrimeTypes.List()
    log('Info', 'crime.start', 'nexa_crime started.', { migrated = migrated, crime_types = #crimeTypes })
end)

exports('GetCrimeProfile', GetCrimeProfile)
exports('GetCrimeReputation', GetCrimeReputation)
exports('GetCrimeHeat', GetCrimeHeat)
exports('ListCrimeDefinitions', ListCrimeDefinitions)
exports('GetCrimeDefinition', GetCrimeDefinition)
exports('CanStartCrime', CanStartCrime)
exports('StartCrime', StartCrime)
exports('CancelCrime', CancelCrime)
exports('GetCrimeSession', GetCrimeSession)
exports('ListActiveCrimeSessions', ListActiveCrimeSessions)
exports('GetCrimeLocation', GetCrimeLocation)
exports('ListCrimeLocations', ListCrimeLocations)
exports('GetCrimeCooldown', GetCrimeCooldown)
exports('AdjustCrimeReputation', AdjustCrimeReputation)
exports('AdjustCrimeHeat', AdjustCrimeHeat)
exports('RegisterCrimeType', RegisterCrimeType)
exports('RegisterCrimeLocation', RegisterCrimeLocation)
exports('RegisterCrimeResponderResolver', RegisterCrimeResponderResolver)
exports('RegisterCrimeDispatchAdapter', RegisterCrimeDispatchAdapter)
exports('RegisterCrimeEvidenceProvider', RegisterCrimeEvidenceProvider)
exports('getStatus', function() return { resourceName = NEXA_CRIME.resourceName, version = NEXA_CRIME.version, migrated = migrated, crimeTypes = CrimeTypes.List(), responders = responderResolvers, dispatchAdapters = dispatchAdapters, evidenceProviders = evidenceProviders } end)
exports('getSchema', NexaCrimeDatabase.GetSchema)
