local migrated = false
PropertyKeys = {}
PropertyDoors = {}

local function response(success, code, message, data, meta) return { ok = success == true, success = success == true, code = code or (success and 'OK' or NEXA_PROPERTYKEY_ERRORS.invalidInput), message = message or '', data = data, meta = meta, error = success == true and nil or { code = code, message = message } } end
local function ok(data, message, meta) return response(true, 'OK', message or 'OK', data, meta) end
local function fail(code, message, meta) return response(false, code, message or code, nil, meta) end
local function normalizeId(value) local id = tonumber(value); return id and id > 0 and id % 1 == 0 and math.floor(id) or nil end
local function normalizeString(value, maxLength) if type(value) ~= 'string' then return nil end; local s = value:gsub('^%s+', ''):gsub('%s+$', ''); if s == '' or (maxLength and #s > maxLength) then return nil end; return s end
local function actorContext(actor) actor = type(actor) == 'table' and actor or {}; return { actor_character_id = normalizeId(actor.actor_character_id or actor.character_id), source_resource = normalizeString(actor.source_resource or GetInvokingResource() or NEXA_PROPERTYKEYS.resourceName, 64) } end
local function log(level, category, message, context) local coreOk, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); if coreOk and core and core.Logger and core.Logger[level] then core.Logger[level](category, message, context); return end; print(('[%s] [%s] %s'):format(NEXA_PROPERTYKEYS.resourceName, level, message)) end

function PropertyKeys.Has(actor, propertyId, permission)
    actor = actorContext(actor)
    propertyId = normalizeId(propertyId)
    if not propertyId or not actor.actor_character_id then return false end
    local key = NexaPropertyKeysDatabase.GetKey(propertyId, 'character', actor.actor_character_id)
    return key ~= nil
end

function PropertyKeys.List(propertyId) local rows, err = NexaPropertyKeysDatabase.ListKeys(normalizeId(propertyId)); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Property keys could not be listed.', err) or ok(rows or {}, 'Property keys listed.') end
function PropertyKeys.Issue(actor, propertyId, holder, keyType, permissions, context) actor = actorContext(context or actor); holder = type(holder) == 'table' and holder or {}; local expiresAt = holder.expires_at or (keyType == NEXA_PROPERTY_KEY_TYPES.temporary and os.time() + NexaPropertyKeysConfig.temporaryKeySeconds or 2147483647); local id, err = NexaPropertyKeysDatabase.InsertKey({ property_id = normalizeId(propertyId), holder_type = normalizeString(holder.holder_type or 'character', 32), holder_id = holder.holder_id, key_type = normalizeString(keyType or 'guest', 32), permissions = permissions or {}, status = NEXA_PROPERTY_KEY_STATUS.active, issued_by = actor.actor_character_id, expires_at = expiresAt, metadata = holder.metadata or {} }); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Property key could not be issued.', err) or ok({ key_id = id, property_id = normalizeId(propertyId) }, 'Property key issued.') end
function PropertyKeys.Revoke(actor, keyId, reason) local _, err = NexaPropertyKeysDatabase.RevokeKey(normalizeId(keyId)); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Property key could not be revoked.', err) or ok({ key_id = normalizeId(keyId) }, 'Property key revoked.') end
function PropertyKeys.Share(actorSource, targetSource, propertyId, context) return PropertyKeys.Issue(context or { actor_character_id = actorSource }, propertyId, { holder_type = 'character', holder_id = targetSource }, NEXA_PROPERTY_KEY_TYPES.temporary, { enter = true, exit = true }, context) end
function PropertyKeys.CleanupExpired() return ok({}, 'Expired key cleanup is handled by SQL time checks in foundation.') end

function PropertyDoors.Register(propertyId, definition, actor) definition = type(definition) == 'table' and definition or {}; local doorKey = normalizeString(definition.door_key or definition.key, 64); if not doorKey then return fail(NEXA_PROPERTYKEY_ERRORS.invalidInput, 'Door definition is invalid.') end; local id, err = NexaPropertyKeysDatabase.InsertDoor({ property_id = normalizeId(propertyId), door_key = doorKey, label = definition.label, locked = definition.locked ~= false, definition = definition, metadata = definition.metadata or {} }); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Door could not be registered.', err) or ok({ door_id = id, property_id = normalizeId(propertyId), door_key = doorKey }, 'Door registered.') end
function PropertyDoors.Get(propertyId) local rows, err = NexaPropertyKeysDatabase.ListDoors(normalizeId(propertyId)); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Doors could not be listed.', err) or ok(rows or {}, 'Doors listed.') end
function PropertyDoors.CanAccess(actor, propertyId, doorKey, action) return ok({ property_id = normalizeId(propertyId), door_key = doorKey, action = action, allowed = PropertyKeys.Has(actor, propertyId, action) }, 'Door access evaluated.') end
function PropertyDoors.SetLocked(actor, propertyId, doorKey, state, context) if not PropertyKeys.Has(actor, propertyId, state and 'lock' or 'unlock') then return fail(NEXA_PROPERTYKEY_ERRORS.accessDenied, 'Missing property key permission.') end; local _, err = NexaPropertyKeysDatabase.SetDoorLocked(normalizeId(propertyId), normalizeString(doorKey, 64), state == true); return err and fail(NEXA_PROPERTYKEY_ERRORS.databaseError, 'Door state could not be saved.', err) or ok({ property_id = normalizeId(propertyId), door_key = doorKey, locked = state == true }, 'Door state saved.') end
function PropertyDoors.Reset(propertyId, reason) return ok({ property_id = normalizeId(propertyId), reason = reason }, 'Door reset foundation recorded.') end

function HasPropertyKey(...) return PropertyKeys.Has(...) end
function ListPropertyKeys(...) return PropertyKeys.List(...) end
function IssuePropertyKey(...) return PropertyKeys.Issue(...) end
function RevokePropertyKey(...) return PropertyKeys.Revoke(...) end
function SharePropertyKey(...) return PropertyKeys.Share(...) end
function RegisterPropertyDoor(...) return PropertyDoors.Register(...) end
function GetPropertyDoors(...) return PropertyDoors.Get(...) end
function SetPropertyDoorLocked(...) return PropertyDoors.SetLocked(...) end
function CanAccessPropertyDoor(...) return PropertyDoors.CanAccess(...) end

AddEventHandler('onResourceStart', function(resourceName) if resourceName ~= GetCurrentResourceName() then return end; if NexaPropertyKeysConfig.autoMigrate then migrated = NexaPropertyKeysDatabase.Migrate() == true end; log('Info', 'propertykeys.start', 'nexa_propertykeys started.', { migrated = migrated }) end)
exports('HasPropertyKey', HasPropertyKey)
exports('ListPropertyKeys', ListPropertyKeys)
exports('IssuePropertyKey', IssuePropertyKey)
exports('RevokePropertyKey', RevokePropertyKey)
exports('SharePropertyKey', SharePropertyKey)
exports('RegisterPropertyDoor', RegisterPropertyDoor)
exports('GetPropertyDoors', GetPropertyDoors)
exports('SetPropertyDoorLocked', SetPropertyDoorLocked)
exports('CanAccessPropertyDoor', CanAccessPropertyDoor)
exports('getStatus', function() return { resourceName = NEXA_PROPERTYKEYS.resourceName, version = NEXA_PROPERTYKEYS.version, migrated = migrated } end)
exports('getSchema', NexaPropertyKeysDatabase.GetSchema)
