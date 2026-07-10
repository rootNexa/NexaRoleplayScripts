local migrated = false
local lastBurglary = {}

PropertySecurity = {}
Burglary = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_PROPERTY_SECURITY_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function actorContext(actor) actor = type(actor) == 'table' and actor or {}; return { actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), correlation_id = normalizeString(actor.correlation_id, 128) or ('propertysecurity:%s:%s'):format(os.time(), math.random(100000,999999)) } end
local function log(level, category, message, context) local coreOk, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); if coreOk and core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s'):format(NEXA_PROPERTY_SECURITY.resourceName, level, message)) end

local function recordEvent(propertyId, eventType, context, result, alarmTriggered, metadata)
    NexaPropertySecurityDatabase.InsertEvent({ property_id = propertyId, event_type = eventType, actor_character_id = context and context.actor_character_id or nil, result = result, security_level = (metadata or {}).security_level, alarm_triggered = alarmTriggered == true, correlation_id = context and context.correlation_id or nil, metadata = metadata or {} })
end

function PropertySecurity.Get(propertyId)
    local row, err = NexaPropertySecurityDatabase.GetState(normalizeId(propertyId))
    if err then return fail(NEXA_PROPERTY_SECURITY_ERRORS.databaseError, 'Property security could not be loaded.', err) end
    return ok(row or { property_id = normalizeId(propertyId), alarm_status = NEXA_PROPERTY_ALARM_STATUS.inactive, security_level = NEXA_PROPERTY_SECURITY_LEVEL.basic }, 'Property security loaded.')
end
function PropertySecurity.Arm(actor, propertyId, context) context = actorContext(context or actor); NexaPropertySecurityDatabase.UpsertState(normalizeId(propertyId), NEXA_PROPERTY_ALARM_STATUS.armed, NEXA_PROPERTY_SECURITY_LEVEL.standard, {}); recordEvent(normalizeId(propertyId), 'alarm.arm', context, 'success', false, {}); return ok({ property_id = normalizeId(propertyId), alarm_status = NEXA_PROPERTY_ALARM_STATUS.armed }, 'Property alarm armed.') end
function PropertySecurity.Disarm(actor, propertyId, context) context = actorContext(context or actor); NexaPropertySecurityDatabase.UpsertState(normalizeId(propertyId), NEXA_PROPERTY_ALARM_STATUS.inactive, NEXA_PROPERTY_SECURITY_LEVEL.standard, {}); recordEvent(normalizeId(propertyId), 'alarm.disarm', context, 'success', false, {}); return ok({ property_id = normalizeId(propertyId), alarm_status = NEXA_PROPERTY_ALARM_STATUS.inactive }, 'Property alarm disarmed.') end
function PropertySecurity.Trigger(propertyId, triggerContext) triggerContext = actorContext(triggerContext); NexaPropertySecurityDatabase.UpsertState(normalizeId(propertyId), NEXA_PROPERTY_ALARM_STATUS.triggered, NEXA_PROPERTY_SECURITY_LEVEL.standard, triggerContext); recordEvent(normalizeId(propertyId), 'alarm.trigger', triggerContext, 'success', true, triggerContext); return ok({ property_id = normalizeId(propertyId), alarm_status = NEXA_PROPERTY_ALARM_STATUS.triggered }, 'Property alarm triggered.') end
function PropertySecurity.Reset(actor, propertyId, reason) local context = actorContext(actor); NexaPropertySecurityDatabase.UpsertState(normalizeId(propertyId), NEXA_PROPERTY_ALARM_STATUS.inactive, NEXA_PROPERTY_SECURITY_LEVEL.standard, { reason = reason }); recordEvent(normalizeId(propertyId), 'alarm.reset', context, 'success', false, { reason = reason }); return ok({ property_id = normalizeId(propertyId) }, 'Property alarm reset.') end

function Burglary.CanAttempt(source, propertyId, context)
    local key = tostring(propertyId)
    local last = lastBurglary[key] or 0
    if os.time() - last < NexaPropertySecurityConfig.burglaryCooldownSeconds then return false end
    return true
end
function Burglary.Begin(source, propertyId, entryPoint, context)
    context = actorContext(context or { actor_character_id = source })
    propertyId = normalizeId(propertyId)
    if not Burglary.CanAttempt(source, propertyId, context) then return fail(NEXA_PROPERTY_SECURITY_ERRORS.burglaryRateLimited, 'Burglary is rate limited.') end
    lastBurglary[tostring(propertyId)] = os.time()
    local id, err = NexaPropertySecurityDatabase.InsertBurglary({ property_id = propertyId, actor_character_id = context.actor_character_id, entry_point = normalizeString(entryPoint or 'main', 64), status = NEXA_PROPERTY_BURGLARY_STATUS.active, access_expires_at = os.time() + NexaPropertySecurityConfig.burglaryAccessSeconds, metadata = {} })
    if err then return fail(NEXA_PROPERTY_SECURITY_ERRORS.databaseError, 'Burglary attempt could not be recorded.', err) end
    recordEvent(propertyId, 'burglary.begin', context, 'success', false, { attempt_id = id })
    return ok({ attempt_id = id, property_id = propertyId }, 'Burglary attempt started.')
end
function Burglary.Resolve(source, attemptId, result, context) NexaPropertySecurityDatabase.ResolveBurglary(normalizeId(attemptId), NEXA_PROPERTY_BURGLARY_STATUS.resolved, normalizeString(result or 'failed', 32)); return ok({ attempt_id = normalizeId(attemptId), result = result }, 'Burglary attempt resolved.') end
function Burglary.GetActive(propertyId) local row, err = NexaPropertySecurityDatabase.GetActiveBurglary(normalizeId(propertyId)); return err and fail(NEXA_PROPERTY_SECURITY_ERRORS.databaseError, 'Active burglary could not be loaded.', err) or ok(row, 'Active burglary loaded.') end
function Burglary.End(propertyId, reason) local active = Burglary.GetActive(propertyId); if active.ok and active.data then NexaPropertySecurityDatabase.ResolveBurglary(active.data.id, NEXA_PROPERTY_BURGLARY_STATUS.ended, reason or 'ended') end; return ok({ property_id = normalizeId(propertyId), reason = reason }, 'Burglary ended.') end

function GetPropertySecurity(...) return PropertySecurity.Get(...) end
function ArmProperty(...) return PropertySecurity.Arm(...) end
function DisarmProperty(...) return PropertySecurity.Disarm(...) end
function TriggerPropertyAlarm(...) return PropertySecurity.Trigger(...) end
function ResetPropertyAlarm(...) return PropertySecurity.Reset(...) end
function BeginPropertyBurglary(...) return Burglary.Begin(...) end
function ResolvePropertyBurglary(...) return Burglary.Resolve(...) end
function GetActivePropertyBurglary(...) return Burglary.GetActive(...) end
function EndPropertyBurglary(...) return Burglary.End(...) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaPropertySecurityConfig.autoMigrate then migrated = NexaPropertySecurityDatabase.Migrate() == true end; log('Info', 'propertysecurity.start', 'nexa_property_security started.', { migrated = migrated }) end)

exports('GetPropertySecurity', GetPropertySecurity)
exports('ArmProperty', ArmProperty)
exports('DisarmProperty', DisarmProperty)
exports('TriggerPropertyAlarm', TriggerPropertyAlarm)
exports('ResetPropertyAlarm', ResetPropertyAlarm)
exports('BeginPropertyBurglary', BeginPropertyBurglary)
exports('ResolvePropertyBurglary', ResolvePropertyBurglary)
exports('GetActivePropertyBurglary', GetActivePropertyBurglary)
exports('EndPropertyBurglary', EndPropertyBurglary)
exports('getStatus', function() return { resourceName = NEXA_PROPERTY_SECURITY.resourceName, version = NEXA_PROPERTY_SECURITY.version, migrated = migrated } end)
exports('getSchema', NexaPropertySecurityDatabase.GetSchema)
