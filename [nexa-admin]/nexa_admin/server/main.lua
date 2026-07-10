NexaAdmin = {
    Actions = {
        byName = {}
    },
    returnPositions = {},
    freezeStates = {},
    spectateStates = {},
    noclipStates = {},
    rateLimits = {}
}

local RESOURCE = GetCurrentResourceName()

local function response(success, code, message, data, meta)
    return {
        success = success == true,
        ok = success == true,
        code = code or (success and 'OK' or 'INTERNAL_ERROR'),
        message = message or '',
        data = data,
        meta = meta
    }
end

local function correlationId()
    return ('adm:%s:%s'):format(os.time(), math.random(100000, 999999))
end

local function encode(data)
    local ok, encoded = pcall(json.encode, data or {})
    return ok and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or fallback
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return ok and core or nil
end

local function db()
    local core = getCore()
    return core and core.Database or nil
end

local function log(level, category, message, context)
    local core = getCore()

    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(RESOURCE, level, message, encode(context)))
end

local function dbQuery(method, sql, params, category)
    local database = db()

    if not database or not database[method] then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database[method](sql, params or {}, {
        category = category or ('admin.%s'):format(method:lower())
    })
end

local function getAccountId(source)
    source = NexaAdminNormalizeSource(source)

    if not source then
        return nil
    end

    local ok, accountId = pcall(function()
        return exports['nexa_identity']:GetAccountId(source)
    end)

    return ok and NexaAdminNormalizeId(accountId) or nil
end

local function getCharacterId(source)
    source = NexaAdminNormalizeSource(source)

    if not source or GetResourceState('nexa_characters') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return exports['nexa_characters']:GetActiveCharacter(source)
    end)

    if not ok or type(result) ~= 'table' then
        return nil
    end

    local data = result.data or result
    local character = data.character or data
    return NexaAdminNormalizeId(character and character.id)
end

local function getCoords(source)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)

    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped) or 0.0,
        bucket = GetPlayerRoutingBucket(source) or 0
    }
end

local function targetOnline(source)
    source = NexaAdminNormalizeSource(source)
    return source and GetPlayerName(source) ~= nil
end

local function hasPermission(source, permission)
    local result = exports.nexa_permissions:Has(source, permission)
    return type(result) == 'table' and result.ok == true and result.data and result.data.allowed == true
end

local function hasAnyPermission(source, permissions)
    for _, permission in ipairs(permissions or {}) do
        if hasPermission(source, permission) then
            return true, permission
        end
    end

    return false, nil
end

local function dutyState(source)
    local state = exports.nexa_permissions:GetAdminDuty(source)

    if type(state) == 'table' and state.state then
        return state.state
    end

    return 'off_duty'
end

local function ensureDuty(source)
    local state = dutyState(source)

    if state == 'suspended' then
        return false, NEXA_ADMIN.errors.suspended
    end

    if state ~= 'on_duty' then
        return false, NEXA_ADMIN.errors.notOnDuty
    end

    return true
end

local function isProtectedTarget(actorSource, targetSource)
    if actorSource == 0 then
        return false
    end

    if actorSource == targetSource then
        return true, NEXA_ADMIN.errors.selfActionForbidden
    end

    local roles = exports.nexa_permissions:GetRoles(targetSource)

    if type(roles) ~= 'table' or roles.ok ~= true or type(roles.data) ~= 'table' then
        return false
    end

    for _, role in ipairs(roles.data) do
        if (role.name == 'owner' or role.name == 'co_owner') and not hasPermission(actorSource, 'nexa.permissions.manage_owner') then
            return true, NEXA_ADMIN.errors.targetProtected
        end
    end

    return false
end

local function auditAction(actionName, actorSource, target, reason, result, errorCode, correlation, metadata)
    local actorAccountId = actorSource ~= 0 and getAccountId(actorSource) or nil
    local _, err = dbQuery('Insert', [[
        INSERT INTO nexa_admin_actions (
            actor_account_id,
            target_account_id,
            target_character_id,
            action_name,
            reason,
            result,
            error_code,
            correlation_id,
            source_resource,
            metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        actorAccountId,
        target and target.accountId or nil,
        target and target.characterId or nil,
        actionName,
        reason or '',
        result,
        errorCode,
        correlation,
        GetInvokingResource() or RESOURCE,
        encode(metadata or {})
    }, 'admin.audit')

    if err then
        log('Error', 'admin.audit', 'Admin action audit failed.', {
            action = actionName,
            error = err.code
        })
    end
end

local function fail(actionName, actorSource, target, reason, code, message, correlation, metadata)
    auditAction(actionName, actorSource, target, reason, 'failed', code, correlation, metadata)
    return response(false, code, message, nil, {
        correlationId = correlation
    })
end

local function ok(actionName, actorSource, target, reason, message, data, correlation, metadata)
    auditAction(actionName, actorSource, target, reason, 'success', nil, correlation, metadata)
    return response(true, 'OK', message, data, {
        correlationId = correlation
    })
end

local function resolveOnlineTarget(value)
    local source = NexaAdminNormalizeSource(value)

    if not source or not targetOnline(source) then
        return nil
    end

    return {
        source = source,
        accountId = getAccountId(source),
        characterId = getCharacterId(source),
        name = GetPlayerName(source)
    }
end

local function resolveTarget(payload)
    payload = payload or {}

    if payload.targetSource then
        return resolveOnlineTarget(payload.targetSource)
    end

    local accountId = NexaAdminNormalizeId(payload.accountId or payload.targetAccountId)

    if accountId then
        return {
            accountId = accountId,
            characterId = NexaAdminNormalizeId(payload.characterId or payload.targetCharacterId)
        }
    end

    return nil
end

local function checkRateLimit(actorSource, actionName)
    if actorSource == 0 then
        return true
    end

    local key = ('%s:%s'):format(actorSource, actionName)
    local now = os.time()
    local previous = NexaAdmin.rateLimits[key]

    if previous and now - previous < NexaAdminServer.actionRateLimitSeconds then
        return false
    end

    NexaAdmin.rateLimits[key] = now
    return true
end

function NexaAdmin.Actions.Register(definition)
    if type(definition) ~= 'table' or type(definition.name) ~= 'string' or type(definition.handler) ~= 'function' then
        return false
    end

    NexaAdmin.Actions.byName[definition.name] = definition
    return true
end

function NexaAdmin.Actions.Get(actionName)
    return NexaAdmin.Actions.byName[actionName]
end

function NexaAdmin.Actions.List()
    local result = {}

    for _, action in pairs(NexaAdmin.Actions.byName) do
        result[#result + 1] = {
            name = action.name,
            permission = action.permission,
            permissions = action.permissions,
            duty = action.duty == true,
            targetType = action.targetType,
            reasonRequired = action.reasonRequired == true
        }
    end

    table.sort(result, function(a, b)
        return a.name < b.name
    end)

    return result
end

function NexaAdmin.Actions.Validate(actorSource, actionName, payload)
    actorSource = NexaAdminNormalizeSource(actorSource)

    if not actorSource then
        return false, NEXA_ADMIN.errors.targetNotFound
    end

    local action = NexaAdmin.Actions.Get(actionName)

    if not action then
        return false, NEXA_ADMIN.errors.actionNotFound
    end

    if not checkRateLimit(actorSource, actionName) then
        return false, NEXA_ADMIN.errors.rateLimited
    end

    if action.duty == true then
        local dutyOk, dutyErr = ensureDuty(actorSource)

        if not dutyOk then
            return false, dutyErr
        end
    end

    local permissionOk = false

    if action.permissions then
        permissionOk = hasAnyPermission(actorSource, action.permissions)
    elseif action.permission then
        permissionOk = hasPermission(actorSource, action.permission)
    end

    if not permissionOk then
        return false, 'ACTOR_NOT_AUTHORIZED'
    end

    if action.reasonRequired == true and not NexaAdminNormalizeReason(payload and payload.reason, true) then
        return false, NEXA_ADMIN.errors.reasonRequired
    end

    return true
end

function NexaAdmin.Actions.Execute(actorSource, actionName, payload)
    payload = payload or {}
    actorSource = NexaAdminNormalizeSource(actorSource)
    local correlation = correlationId()
    local target = resolveTarget(payload)
    local reason = NexaAdminNormalizeReason(payload.reason, false)
    local valid, validationErr = NexaAdmin.Actions.Validate(actorSource, actionName, payload)

    if not valid then
        return fail(actionName, actorSource or 0, target, reason, validationErr, 'Admin action denied.', correlation, {
            payloadKeys = type(payload) == 'table' and true or false
        })
    end

    local action = NexaAdmin.Actions.Get(actionName)

    if action.targetType == 'online' and not target then
        return fail(actionName, actorSource, nil, reason, NEXA_ADMIN.errors.targetOffline, 'Target is offline.', correlation)
    end

    if target and target.source then
        local protected, protectErr = isProtectedTarget(actorSource, target.source)

        if protected then
            return fail(actionName, actorSource, target, reason, protectErr, 'Target is protected.', correlation)
        end
    end

    local okHandler, result = pcall(action.handler, actorSource, payload, target, correlation, reason)

    if not okHandler then
        return fail(actionName, actorSource, target, reason, 'ADMIN_INTERNAL_ERROR', 'Admin action failed.', correlation, {
            error = result
        })
    end

    if type(result) == 'table' and result.success == false then
        auditAction(actionName, actorSource, target, reason, 'failed', result.code, correlation, result.meta)
        result.meta = result.meta or {}
        result.meta.correlationId = result.meta.correlationId or correlation
        return result
    end

    return ok(actionName, actorSource, target, reason, result and result.message or 'Admin action executed.', result and result.data or result, correlation)
end

function NexaAdmin.Actions.Cancel(actorSource, actionName, context)
    return response(true, 'OK', 'Admin action cancellation acknowledged.', {
        action = actionName,
        context = context
    })
end

local Warnings = {}
local Bans = {}
local Teleport = {}
local Freeze = {}
local Recovery = {}
local Spectate = {}
local Noclip = {}
local Notes = {}

function Warnings.Create(actor, target, payload)
    local reason = NexaAdminNormalizeReason(payload.reason, true)

    if not reason then
        return response(false, NEXA_ADMIN.errors.reasonRequired, 'Reason is required.')
    end

    local warningId, err = dbQuery('Insert', [[
        INSERT INTO nexa_admin_warnings (
            target_account_id,
            target_character_id,
            actor_account_id,
            reason,
            category,
            severity,
            status,
            expires_at,
            correlation_id,
            metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, 'active', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? MINUTE), ?, ?)
    ]], {
        target.accountId,
        target.characterId,
        getAccountId(actor),
        reason,
        NexaAdminNormalizeText(payload.category or 'general', 32, false) or 'general',
        NexaAdminNormalizeText(payload.severity or 'normal', 32, false) or 'normal',
        payload.expiresInMinutes and NexaAdminNormalizeDurationMinutes(payload.expiresInMinutes) or nil,
        payload.correlationId,
        encode({
            targetSource = target.source
        })
    }, 'admin.warnings.create')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Warning could not be saved.')
    end

    return response(true, 'OK', 'Warning created.', {
        warningId = warningId
    })
end

function Warnings.Get(warningId)
    warningId = NexaAdminNormalizeId(warningId)

    if not warningId then
        return response(false, NEXA_ADMIN.errors.warningNotFound, 'Warning not found.')
    end

    local row, err = dbQuery('Single', 'SELECT * FROM nexa_admin_warnings WHERE id = ? LIMIT 1', { warningId }, 'admin.warnings.get')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Warning could not be loaded.')
    end

    if not row then
        return response(false, NEXA_ADMIN.errors.warningNotFound, 'Warning not found.')
    end

    return response(true, 'OK', 'Warning loaded.', row)
end

function Warnings.ListForAccount(accountId, filters)
    accountId = NexaAdminNormalizeId(accountId)

    if not accountId then
        return response(false, NEXA_ADMIN.errors.targetNotFound, 'Account not found.')
    end

    local rows, err = dbQuery('Query', [[
        SELECT *
        FROM nexa_admin_warnings
        WHERE target_account_id = ?
          AND (? IS NULL OR category = ?)
        ORDER BY created_at DESC
        LIMIT 100
    ]], { accountId, filters and filters.category or nil, filters and filters.category or nil }, 'admin.warnings.list_account')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Warnings could not be loaded.')
    end

    return response(true, 'OK', 'Warnings loaded.', {
        warnings = rows or {}
    })
end

function Warnings.ListForCharacter(characterId, filters)
    characterId = NexaAdminNormalizeId(characterId)

    if not characterId then
        return response(false, NEXA_ADMIN.errors.targetNotFound, 'Character not found.')
    end

    local rows, err = dbQuery('Query', [[
        SELECT *
        FROM nexa_admin_warnings
        WHERE target_character_id = ?
          AND (? IS NULL OR category = ?)
        ORDER BY created_at DESC
        LIMIT 100
    ]], { characterId, filters and filters.category or nil, filters and filters.category or nil }, 'admin.warnings.list_character')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Warnings could not be loaded.')
    end

    return response(true, 'OK', 'Warnings loaded.', {
        warnings = rows or {}
    })
end

function Warnings.Revoke(actor, warningId, reason)
    local loaded = Warnings.Get(warningId)

    if not loaded.success then
        return loaded
    end

    if loaded.data.status == 'revoked' then
        return response(false, NEXA_ADMIN.errors.warningAlreadyRevoked, 'Warning already revoked.')
    end

    local normalizedReason = NexaAdminNormalizeReason(reason, true)

    if not normalizedReason then
        return response(false, NEXA_ADMIN.errors.reasonRequired, 'Reason is required.')
    end

    local _, err = dbQuery('Update', [[
        UPDATE nexa_admin_warnings
        SET status = 'revoked', revoked_at = CURRENT_TIMESTAMP, revoked_by = ?, revoked_reason = ?
        WHERE id = ?
    ]], { getAccountId(actor), normalizedReason, warningId }, 'admin.warnings.revoke')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Warning could not be revoked.')
    end

    return response(true, 'OK', 'Warning revoked.')
end

function Bans.GetActiveForAccount(accountId)
    accountId = NexaAdminNormalizeId(accountId)

    if not accountId then
        return nil
    end

    local row = dbQuery('Single', [[
        SELECT *
        FROM nexa_admin_bans
        WHERE target_account_id = ?
          AND active = 1
          AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
        ORDER BY created_at DESC
        LIMIT 1
    ]], { accountId }, 'admin.bans.active')

    return row
end

function Bans.IsAccountBanned(accountId)
    return Bans.GetActiveForAccount(accountId) ~= nil
end

function Bans.GetById(banId)
    banId = NexaAdminNormalizeId(banId)

    if not banId then
        return response(false, NEXA_ADMIN.errors.banNotFound, 'Ban not found.')
    end

    local row, err = dbQuery('Single', 'SELECT * FROM nexa_admin_bans WHERE id = ? LIMIT 1', { banId }, 'admin.bans.get')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Ban could not be loaded.')
    end

    if not row then
        return response(false, NEXA_ADMIN.errors.banNotFound, 'Ban not found.')
    end

    return response(true, 'OK', 'Ban loaded.', row)
end

function Bans.ListForAccount(accountId)
    accountId = NexaAdminNormalizeId(accountId)

    if not accountId then
        return response(false, NEXA_ADMIN.errors.targetNotFound, 'Account not found.')
    end

    local rows, err = dbQuery('Query', 'SELECT * FROM nexa_admin_bans WHERE target_account_id = ? ORDER BY created_at DESC LIMIT 100', { accountId }, 'admin.bans.list')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Bans could not be loaded.')
    end

    return response(true, 'OK', 'Bans loaded.', {
        bans = rows or {}
    })
end

local function createBan(actor, target, banType, durationMinutes, reason, correlation)
    if Bans.IsAccountBanned(target.accountId) then
        return response(false, NEXA_ADMIN.errors.banAlreadyActive, 'Account already has an active ban.')
    end

    if banType == 'temporary' and not durationMinutes then
        return response(false, NEXA_ADMIN.errors.invalidDuration, 'Duration is invalid.')
    end

    local banId, err = dbQuery('Insert', [[
        INSERT INTO nexa_admin_bans (
            target_account_id,
            target_identifier_ref,
            actor_account_id,
            ban_type,
            reason,
            starts_at,
            expires_at,
            active,
            correlation_id,
            metadata_json
        ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CASE WHEN ? IS NULL THEN NULL ELSE DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? MINUTE) END, 1, ?, ?)
    ]], {
        target.accountId,
        target.source and ('source:%s'):format(target.source) or nil,
        getAccountId(actor),
        banType,
        reason,
        durationMinutes,
        durationMinutes,
        correlation,
        encode({
            targetSource = target.source
        })
    }, 'admin.bans.create')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Ban could not be saved.')
    end

    if target.source then
        DropPlayer(target.source, NexaAdminServer.banRejectMessage)
    end

    return response(true, 'OK', 'Ban created.', {
        banId = banId
    })
end

function Bans.CreateTemporary(actor, target, duration, reason, correlation)
    return createBan(actor, target, 'temporary', duration, reason, correlation)
end

function Bans.CreatePermanent(actor, target, reason, correlation)
    return createBan(actor, target, 'permanent', nil, reason, correlation)
end

function Bans.Revoke(actor, banId, reason)
    local loaded = Bans.GetById(banId)

    if not loaded.success then
        return loaded
    end

    if loaded.data.active ~= 1 and loaded.data.active ~= true then
        return response(false, NEXA_ADMIN.errors.banAlreadyRevoked, 'Ban already revoked.')
    end

    local normalizedReason = NexaAdminNormalizeReason(reason, true)

    if not normalizedReason then
        return response(false, NEXA_ADMIN.errors.reasonRequired, 'Reason is required.')
    end

    local _, err = dbQuery('Update', [[
        UPDATE nexa_admin_bans
        SET active = 0, revoked_at = CURRENT_TIMESTAMP, revoked_by = ?, revoked_reason = ?
        WHERE id = ?
    ]], { getAccountId(actor), normalizedReason, banId }, 'admin.bans.revoke')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Ban could not be revoked.')
    end

    return response(true, 'OK', 'Ban revoked.')
end

function Bans.ResolveConnection(identityContext)
    local accountId = NexaAdminNormalizeId(identityContext and (identityContext.accountId or identityContext.account_id))
    local activeBan = accountId and Bans.GetActiveForAccount(accountId) or nil

    if activeBan then
        return response(false, 'ACCOUNT_BANNED', NexaAdminServer.banRejectMessage, {
            banId = activeBan.id,
            expiresAt = activeBan.expires_at
        })
    end

    return response(true, 'OK', 'No active ban.')
end

function Teleport.GoTo(actorSource, targetSource)
    local actorCoords = getCoords(actorSource)
    local targetCoords = getCoords(targetSource)

    if not actorCoords or not targetCoords then
        return response(false, NEXA_ADMIN.errors.teleportPositionMissing, 'Position missing.')
    end

    NexaAdmin.returnPositions[actorSource] = {
        coords = actorCoords,
        expiresAt = os.time() + NexaAdminConfig.returnPositionTtlSeconds
    }
    if GetResourceState('nexa_playerstate') == 'started' then
        exports.nexa_playerstate:AllowPositionJump(actorSource, { action = 'admin.goto', targetSource = targetSource })
    end
    SetPlayerRoutingBucket(actorSource, targetCoords.bucket or 0)
    TriggerClientEvent(NEXA_ADMIN.events.applyTeleport, actorSource, {
        coords = targetCoords
    })
    return response(true, 'OK', 'Teleported to player.')
end

function Teleport.Bring(actorSource, targetSource)
    local actorCoords = getCoords(actorSource)
    local targetCoords = getCoords(targetSource)

    if not actorCoords or not targetCoords then
        return response(false, NEXA_ADMIN.errors.teleportPositionMissing, 'Position missing.')
    end

    NexaAdmin.returnPositions[targetSource] = {
        coords = targetCoords,
        expiresAt = os.time() + NexaAdminConfig.returnPositionTtlSeconds
    }
    if GetResourceState('nexa_playerstate') == 'started' then
        exports.nexa_playerstate:AllowPositionJump(targetSource, { action = 'admin.bring', actorSource = actorSource })
    end
    SetPlayerRoutingBucket(targetSource, actorCoords.bucket or 0)
    TriggerClientEvent(NEXA_ADMIN.events.applyTeleport, targetSource, {
        coords = actorCoords
    })
    return response(true, 'OK', 'Player brought.')
end

function Teleport.Return(actorSource, targetSource)
    local target = targetSource or actorSource
    local stored = NexaAdmin.returnPositions[target]

    if not stored or stored.expiresAt < os.time() then
        NexaAdmin.returnPositions[target] = nil
        return response(false, NEXA_ADMIN.errors.teleportPositionMissing, 'Return position missing.')
    end

    SetPlayerRoutingBucket(target, stored.coords.bucket or 0)
    if GetResourceState('nexa_playerstate') == 'started' then
        exports.nexa_playerstate:AllowPositionJump(target, { action = 'admin.return', actorSource = actorSource })
    end
    TriggerClientEvent(NEXA_ADMIN.events.applyTeleport, target, {
        coords = stored.coords
    })
    NexaAdmin.returnPositions[target] = nil
    return response(true, 'OK', 'Player returned.')
end

function Teleport.ToCoords(actorSource, coords)
    coords = NexaAdminNormalizeCoords(coords)

    if not coords then
        return response(false, NEXA_ADMIN.errors.teleportInvalidCoords, 'Coordinates are invalid.')
    end

    local previous = getCoords(actorSource)

    if previous then
        NexaAdmin.returnPositions[actorSource] = {
            coords = previous,
            expiresAt = os.time() + NexaAdminConfig.returnPositionTtlSeconds
        }
    end

    if GetResourceState('nexa_playerstate') == 'started' then
        exports.nexa_playerstate:AllowPositionJump(actorSource, { action = 'admin.teleport.coords' })
    end
    TriggerClientEvent(NEXA_ADMIN.events.applyTeleport, actorSource, {
        coords = coords
    })
    return response(true, 'OK', 'Teleported to coordinates.')
end

function Freeze.Set(actorSource, targetSource, state, reason)
    if state ~= true and state ~= false then
        return response(false, NEXA_ADMIN.errors.freezeStateInvalid, 'Freeze state is invalid.')
    end

    NexaAdmin.freezeStates[targetSource] = state == true and {
        frozen = true,
        actorSource = actorSource,
        reason = reason,
        createdAt = os.time()
    } or nil
    TriggerClientEvent(NEXA_ADMIN.events.applyControl, targetSource, {
        frozen = state == true
    })
    return response(true, 'OK', state and 'Player frozen.' or 'Player unfrozen.')
end

function Freeze.Get(targetSource)
    return NexaAdmin.freezeStates[targetSource]
end

function Freeze.Clear(targetSource)
    NexaAdmin.freezeStates[targetSource] = nil
    TriggerClientEvent(NEXA_ADMIN.events.applyControl, targetSource, {
        frozen = false
    })
    return response(true, 'OK', 'Freeze cleared.')
end

function Recovery.Heal(actorSource, targetSource)
    TriggerClientEvent(NEXA_ADMIN.events.applyRecovery, targetSource, {
        type = 'heal',
        actorSource = actorSource
    })
    return response(true, 'OK', 'Player healed.')
end

function Recovery.Revive(actorSource, targetSource)
    if GetResourceState('nexa_playerstate') == 'started' then
        exports.nexa_playerstate:SetLifeState(actorSource, targetSource, 'alive', {
            reason = 'admin_revive',
            actorSource = actorSource
        })
    end

    TriggerClientEvent(NEXA_ADMIN.events.applyRecovery, targetSource, {
        type = 'revive',
        actorSource = actorSource
    })
    return response(true, 'OK', 'Player revived.')
end

function Spectate.Start(actorSource, targetSource)
    if NexaAdmin.spectateStates[actorSource] then
        return response(false, NEXA_ADMIN.errors.spectateAlreadyActive, 'Spectate already active.')
    end

    NexaAdmin.spectateStates[actorSource] = {
        targetSource = targetSource,
        original = getCoords(actorSource),
        createdAt = os.time()
    }
    TriggerClientEvent(NEXA_ADMIN.events.applySpectate, actorSource, {
        active = true,
        targetSource = targetSource
    })
    return response(true, 'OK', 'Spectate started.')
end

function Spectate.Stop(actorSource)
    local state = NexaAdmin.spectateStates[actorSource]

    if not state then
        return response(false, NEXA_ADMIN.errors.spectateNotActive, 'Spectate not active.')
    end

    NexaAdmin.spectateStates[actorSource] = nil
    TriggerClientEvent(NEXA_ADMIN.events.applySpectate, actorSource, {
        active = false
    })

    if state.original then
        TriggerClientEvent(NEXA_ADMIN.events.applyTeleport, actorSource, {
            coords = state.original
        })
    end

    return response(true, 'OK', 'Spectate stopped.')
end

function Spectate.SwitchTarget(actorSource, targetSource)
    if not NexaAdmin.spectateStates[actorSource] then
        return response(false, NEXA_ADMIN.errors.spectateNotActive, 'Spectate not active.')
    end

    NexaAdmin.spectateStates[actorSource].targetSource = targetSource
    TriggerClientEvent(NEXA_ADMIN.events.applySpectate, actorSource, {
        active = true,
        targetSource = targetSource
    })
    return response(true, 'OK', 'Spectate target switched.')
end

function Spectate.GetState(actorSource)
    return NexaAdmin.spectateStates[actorSource]
end

function Noclip.Start(actorSource)
    if NexaAdmin.noclipStates[actorSource] then
        return response(false, NEXA_ADMIN.errors.noclipAlreadyActive, 'Noclip already active.')
    end

    NexaAdmin.noclipStates[actorSource] = {
        speedLevel = 1,
        createdAt = os.time()
    }
    TriggerClientEvent(NEXA_ADMIN.events.applyNoclip, actorSource, {
        active = true,
        speed = NexaAdminServer.noclipSpeeds[1]
    })
    return response(true, 'OK', 'Noclip started.')
end

function Noclip.Stop(actorSource)
    if not NexaAdmin.noclipStates[actorSource] then
        return response(false, NEXA_ADMIN.errors.noclipNotActive, 'Noclip not active.')
    end

    NexaAdmin.noclipStates[actorSource] = nil
    TriggerClientEvent(NEXA_ADMIN.events.applyNoclip, actorSource, {
        active = false
    })
    return response(true, 'OK', 'Noclip stopped.')
end

function Noclip.SetSpeed(actorSource, level)
    level = tonumber(level)

    if not level or level < 1 or level > NexaAdminServer.maxNoclipSpeedLevel or not NexaAdmin.noclipStates[actorSource] then
        return response(false, NEXA_ADMIN.errors.noclipNotActive, 'Noclip not active.')
    end

    NexaAdmin.noclipStates[actorSource].speedLevel = level
    TriggerClientEvent(NEXA_ADMIN.events.applyNoclip, actorSource, {
        active = true,
        speed = NexaAdminServer.noclipSpeeds[level]
    })
    return response(true, 'OK', 'Noclip speed changed.')
end

function Noclip.GetState(actorSource)
    return NexaAdmin.noclipStates[actorSource]
end

function Notes.Create(actor, target, payload)
    local content = NexaAdminNormalizeText(payload.content or payload.note or payload.reason, NexaAdminConfig.maxNoteLength, true)

    if not content then
        return response(false, NEXA_ADMIN.errors.reasonRequired, 'Note content is required.')
    end

    local visibility = payload.visibility or 'support'

    if not NexaAdminIsValidVisibility(visibility) then
        return response(false, NEXA_ADMIN.errors.noteVisibilityForbidden, 'Note visibility is invalid.')
    end

    local noteId, err = dbQuery('Insert', [[
        INSERT INTO nexa_admin_notes (
            target_account_id,
            target_character_id,
            actor_account_id,
            content,
            category,
            visibility,
            correlation_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        target.accountId,
        target.characterId,
        getAccountId(actor),
        content,
        NexaAdminNormalizeText(payload.category or 'general', 32, false) or 'general',
        visibility,
        payload.correlationId
    }, 'admin.notes.create')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Note could not be saved.')
    end

    return response(true, 'OK', 'Note created.', {
        noteId = noteId
    })
end

function Notes.List(actor, target)
    local rows, err = dbQuery('Query', [[
        SELECT *
        FROM nexa_admin_notes
        WHERE deleted_at IS NULL
          AND (? IS NULL OR target_account_id = ?)
          AND (? IS NULL OR target_character_id = ?)
        ORDER BY created_at DESC
        LIMIT 100
    ]], { target.accountId, target.accountId, target.characterId, target.characterId }, 'admin.notes.list')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Notes could not be loaded.')
    end

    return response(true, 'OK', 'Notes loaded.', {
        notes = rows or {}
    })
end

function Notes.Update(actor, noteId, changes)
    noteId = NexaAdminNormalizeId(noteId)
    local content = NexaAdminNormalizeText(changes and changes.content, NexaAdminConfig.maxNoteLength, true)

    if not noteId or not content then
        return response(false, NEXA_ADMIN.errors.noteNotFound, 'Note not found.')
    end

    local _, err = dbQuery('Update', 'UPDATE nexa_admin_notes SET content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted_at IS NULL', { content, noteId }, 'admin.notes.update')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Note could not be updated.')
    end

    return response(true, 'OK', 'Note updated.')
end

function Notes.Delete(actor, noteId, reason)
    noteId = NexaAdminNormalizeId(noteId)

    if not noteId then
        return response(false, NEXA_ADMIN.errors.noteNotFound, 'Note not found.')
    end

    local normalizedReason = NexaAdminNormalizeReason(reason, true)

    if not normalizedReason then
        return response(false, NEXA_ADMIN.errors.reasonRequired, 'Reason is required.')
    end

    local _, err = dbQuery('Update', 'UPDATE nexa_admin_notes SET deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted_at IS NULL', { noteId }, 'admin.notes.delete')

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Note could not be deleted.')
    end

    return response(true, 'OK', 'Note deleted.')
end

local function registerActions()
    local function reg(def)
        NexaAdmin.Actions.Register(def)
    end

    reg({ name = 'admin.warn', permission = 'nexa.admin.warn', duty = true, targetType = 'online', reasonRequired = true, handler = function(actor, payload, target, correlation, reason) payload.correlationId = correlation return Warnings.Create(actor, target, payload) end })
    reg({ name = 'admin.kick', permission = 'nexa.admin.kick', duty = true, targetType = 'online', reasonRequired = true, handler = function(actor, payload, target) DropPlayer(target.source, ('Nexa Admin: %s'):format(payload.reason)) return response(true, 'OK', 'Player kicked.') end })
    reg({ name = 'admin.ban.temp', permission = 'nexa.admin.ban.temp', duty = true, targetType = 'account', reasonRequired = true, handler = function(actor, payload, target, correlation, reason) return Bans.CreateTemporary(actor, target, NexaAdminNormalizeDurationMinutes(payload.durationMinutes), reason, correlation) end })
    reg({ name = 'admin.ban.permanent', permission = 'nexa.admin.ban.permanent', duty = true, targetType = 'account', reasonRequired = true, handler = function(actor, payload, target, correlation, reason) return Bans.CreatePermanent(actor, target, reason, correlation) end })
    reg({ name = 'admin.unban', permission = 'nexa.admin.unban', duty = false, targetType = 'ban', reasonRequired = true, handler = function(actor, payload) return Bans.Revoke(actor, payload.banId, payload.reason) end })
    reg({ name = 'admin.goto', permissions = { 'nexa.admin.teleport', 'nexa.support.teleport' }, duty = true, targetType = 'online', reasonRequired = false, handler = function(actor, payload, target) return Teleport.GoTo(actor, target.source) end })
    reg({ name = 'admin.bring', permissions = { 'nexa.admin.teleport', 'nexa.support.teleport' }, duty = true, targetType = 'online', reasonRequired = false, handler = function(actor, payload, target) return Teleport.Bring(actor, target.source) end })
    reg({ name = 'admin.return', permissions = { 'nexa.admin.teleport', 'nexa.support.teleport' }, duty = true, targetType = 'online', reasonRequired = false, handler = function(actor, payload, target) return Teleport.Return(actor, target and target.source or actor) end })
    reg({ name = 'admin.teleport.coords', permission = 'nexa.admin.teleport', duty = true, targetType = 'coords', reasonRequired = true, handler = function(actor, payload) return Teleport.ToCoords(actor, payload) end })
    reg({ name = 'admin.freeze', permissions = { 'nexa.admin.freeze', 'nexa.support.freeze' }, duty = true, targetType = 'online', reasonRequired = true, handler = function(actor, payload, target, correlation, reason) return Freeze.Set(actor, target.source, payload.state == true or payload.state == 'frozen', reason) end })
    reg({ name = 'admin.heal', permission = 'nexa.admin.heal', duty = true, targetType = 'online', reasonRequired = true, handler = function(actor, payload, target) return Recovery.Heal(actor, target.source) end })
    reg({ name = 'admin.revive', permissions = { 'nexa.admin.revive', 'nexa.support.revive' }, duty = true, targetType = 'online', reasonRequired = true, handler = function(actor, payload, target) return Recovery.Revive(actor, target.source) end })
    reg({ name = 'admin.spectate.start', permission = 'nexa.admin.spectate', duty = true, targetType = 'online', reasonRequired = false, handler = function(actor, payload, target) return Spectate.Start(actor, target.source) end })
    reg({ name = 'admin.spectate.stop', permission = 'nexa.admin.spectate', duty = true, targetType = 'self', reasonRequired = false, handler = function(actor) return Spectate.Stop(actor) end })
    reg({ name = 'admin.noclip.start', permission = 'nexa.admin.noclip', duty = true, targetType = 'self', reasonRequired = false, handler = function(actor) return Noclip.Start(actor) end })
    reg({ name = 'admin.noclip.stop', permission = 'nexa.admin.noclip', duty = true, targetType = 'self', reasonRequired = false, handler = function(actor) return Noclip.Stop(actor) end })
    reg({ name = 'admin.note.create', permission = 'nexa.support.notes.create', duty = false, targetType = 'account', reasonRequired = true, handler = function(actor, payload, target, correlation) payload.correlationId = correlation return Notes.Create(actor, target, payload) end })
    reg({ name = 'admin.note.view', permission = 'nexa.support.notes.view', duty = false, targetType = 'account', reasonRequired = false, handler = function(actor, payload, target) return Notes.List(actor, target) end })
end

local function registerMigration()
    local core = getCore()

    if not core or not core.Database then
        return false
    end

    core.Database.RegisterMigration({
        id = '040_admin_foundation',
        description = 'Create admin warnings, bans, notes and action audit tables',
        transaction = false,
        statements = {
            [[CREATE TABLE IF NOT EXISTS nexa_admin_warnings (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                target_account_id BIGINT UNSIGNED NOT NULL,
                target_character_id BIGINT UNSIGNED NULL,
                actor_account_id BIGINT UNSIGNED NULL,
                reason VARCHAR(512) NOT NULL,
                category VARCHAR(32) NOT NULL DEFAULT 'general',
                severity VARCHAR(32) NOT NULL DEFAULT 'normal',
                status VARCHAR(32) NOT NULL DEFAULT 'active',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NULL DEFAULT NULL,
                revoked_at TIMESTAMP NULL DEFAULT NULL,
                revoked_by BIGINT UNSIGNED NULL,
                revoked_reason VARCHAR(512) NULL,
                correlation_id VARCHAR(96) NULL,
                metadata_json LONGTEXT NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_admin_warnings_account (target_account_id),
                KEY idx_nexa_admin_warnings_character (target_character_id),
                KEY idx_nexa_admin_warnings_status (status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_admin_bans (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                target_account_id BIGINT UNSIGNED NOT NULL,
                target_identifier_ref VARCHAR(128) NULL,
                actor_account_id BIGINT UNSIGNED NULL,
                ban_type VARCHAR(32) NOT NULL,
                reason VARCHAR(512) NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                starts_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NULL DEFAULT NULL,
                active TINYINT(1) NOT NULL DEFAULT 1,
                revoked_at TIMESTAMP NULL DEFAULT NULL,
                revoked_by BIGINT UNSIGNED NULL,
                revoked_reason VARCHAR(512) NULL,
                correlation_id VARCHAR(96) NULL,
                metadata_json LONGTEXT NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_admin_bans_account_active (target_account_id, active),
                KEY idx_nexa_admin_bans_expires (expires_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_admin_notes (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                target_account_id BIGINT UNSIGNED NOT NULL,
                target_character_id BIGINT UNSIGNED NULL,
                actor_account_id BIGINT UNSIGNED NULL,
                content TEXT NOT NULL,
                category VARCHAR(32) NOT NULL DEFAULT 'general',
                visibility VARCHAR(32) NOT NULL DEFAULT 'support',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT NULL,
                deleted_at TIMESTAMP NULL DEFAULT NULL,
                correlation_id VARCHAR(96) NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_admin_notes_account (target_account_id),
                KEY idx_nexa_admin_notes_character (target_character_id),
                KEY idx_nexa_admin_notes_deleted (deleted_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_admin_actions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                actor_account_id BIGINT UNSIGNED NULL,
                target_account_id BIGINT UNSIGNED NULL,
                target_character_id BIGINT UNSIGNED NULL,
                action_name VARCHAR(96) NOT NULL,
                reason VARCHAR(512) NOT NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                correlation_id VARCHAR(96) NOT NULL,
                source_resource VARCHAR(64) NOT NULL,
                metadata_json LONGTEXT NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_admin_actions_actor (actor_account_id),
                KEY idx_nexa_admin_actions_target_account (target_account_id),
                KEY idx_nexa_admin_actions_name (action_name),
                KEY idx_nexa_admin_actions_created (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
        }
    })

    local ok, err = core.Database.RunMigrations()

    if not ok then
        log('Error', 'admin.migration', 'Admin migrations failed.', {
            error = err
        })
    end

    return ok
end

local function cleanupSource(source, reason)
    source = tonumber(source)

    if not source then
        return
    end

    NexaAdmin.returnPositions[source] = nil
    NexaAdmin.freezeStates[source] = nil

    if NexaAdmin.spectateStates[source] then
        Spectate.Stop(source)
    end

    if NexaAdmin.noclipStates[source] then
        Noclip.Stop(source)
    end
end

local function execute(action, source, payload)
    return NexaAdmin.Actions.Execute(source, action, payload or {})
end

function WarnPlayer(actorSource, targetSource, reason)
    return execute('admin.warn', actorSource, { targetSource = targetSource, reason = reason })
end

function KickPlayer(actorSource, targetSource, reason)
    return execute('admin.kick', actorSource, { targetSource = targetSource, reason = reason })
end

function BanPlayer(actorSource, targetSourceOrAccountId, reason, durationMinutes)
    local payload = { reason = reason, durationMinutes = durationMinutes }

    if targetOnline(tonumber(targetSourceOrAccountId)) then
        payload.targetSource = targetSourceOrAccountId
    else
        payload.accountId = targetSourceOrAccountId
    end

    return execute(durationMinutes and 'admin.ban.temp' or 'admin.ban.permanent', actorSource, payload)
end

function UnbanPlayer(actorSource, banId, reason)
    return execute('admin.unban', actorSource, { banId = banId, reason = reason })
end

function GoToPlayer(actorSource, targetSource)
    return execute('admin.goto', actorSource, { targetSource = targetSource })
end

function BringPlayer(actorSource, targetSource)
    return execute('admin.bring', actorSource, { targetSource = targetSource })
end

function ReturnPlayer(actorSource, targetSource)
    return execute('admin.return', actorSource, { targetSource = targetSource or actorSource })
end

function SetPlayerFrozen(actorSource, targetSource, state, reason)
    return execute('admin.freeze', actorSource, { targetSource = targetSource, state = state, reason = reason })
end

function HealPlayer(actorSource, targetSource, reason)
    return execute('admin.heal', actorSource, { targetSource = targetSource, reason = reason or 'Admin recovery heal' })
end

function RevivePlayer(actorSource, targetSource, reason)
    return execute('admin.revive', actorSource, { targetSource = targetSource, reason = reason or 'Admin recovery revive' })
end

function StartSpectate(actorSource, targetSource)
    return execute('admin.spectate.start', actorSource, { targetSource = targetSource })
end

function StopSpectate(actorSource)
    return execute('admin.spectate.stop', actorSource, {})
end

function StartNoclip(actorSource)
    return execute('admin.noclip.start', actorSource, {})
end

function StopNoclip(actorSource)
    return execute('admin.noclip.stop', actorSource, {})
end

function CreateAdminNote(actorSource, target, payload)
    payload = payload or {}

    if type(target) == 'table' then
        for key, value in pairs(target) do
            payload[key] = value
        end
    else
        payload.targetSource = target
    end

    return execute('admin.note.create', actorSource, payload)
end

function ListAdminNotes(actorSource, target)
    local payload = type(target) == 'table' and target or { targetSource = target }
    return execute('admin.note.view', actorSource, payload)
end

function GetAdminActionState(source)
    source = tonumber(source)

    return response(true, 'OK', 'Admin state loaded.', {
        freeze = source and NexaAdmin.freezeStates[source] or nil,
        spectate = source and NexaAdmin.spectateStates[source] or nil,
        noclip = source and NexaAdmin.noclipStates[source] or nil,
        returnPosition = source and NexaAdmin.returnPositions[source] or nil,
        actions = NexaAdmin.Actions.List()
    })
end

function ResolveConnection(identityContext)
    return Bans.ResolveConnection(identityContext)
end

function IsAccountBanned(accountId)
    return Bans.IsAccountBanned(accountId)
end

function ListActions()
    return response(true, 'OK', 'Actions loaded.', {
        actions = NexaAdmin.Actions.List()
    })
end

local function registerCommands()
    if not NexaAdminServer.commandsEnabled then
        return
    end

    RegisterCommand('warn', function(source, args) print(json.encode(WarnPlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('kick', function(source, args) print(json.encode(KickPlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('tempban', function(source, args) print(json.encode(BanPlayer(source, args[1], table.concat(args, ' ', 3), args[2]))) end, false)
    RegisterCommand('ban', function(source, args) print(json.encode(BanPlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('unban', function(source, args) print(json.encode(UnbanPlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('goto', function(source, args) print(json.encode(GoToPlayer(source, args[1]))) end, false)
    RegisterCommand('bring', function(source, args) print(json.encode(BringPlayer(source, args[1]))) end, false)
    RegisterCommand('return', function(source, args) print(json.encode(ReturnPlayer(source, args[1] or source))) end, false)
    RegisterCommand('freeze', function(source, args) print(json.encode(SetPlayerFrozen(source, args[1], true, table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('unfreeze', function(source, args) print(json.encode(SetPlayerFrozen(source, args[1], false, table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('heal', function(source, args) print(json.encode(HealPlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('revive', function(source, args) print(json.encode(RevivePlayer(source, args[1], table.concat(args, ' ', 2)))) end, false)
    RegisterCommand('spectate', function(source, args) print(json.encode(StartSpectate(source, args[1]))) end, false)
    RegisterCommand('specoff', function(source) print(json.encode(StopSpectate(source))) end, false)
    RegisterCommand('noclip', function(source) print(json.encode(NexaAdmin.noclipStates[source] and StopNoclip(source) or StartNoclip(source))) end, false)
    RegisterCommand('adminduty', function(source, args)
        local state = args[1] == 'off' and 'off_duty' or 'on_duty'
        print(json.encode(exports.nexa_permissions:SetAdminDuty(source, state, source, 'Admin duty command')))
    end, false)
end

AddEventHandler('playerDropped', function(reason)
    cleanupSource(source, reason)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    for playerSource in pairs(NexaAdmin.freezeStates) do
        Freeze.Clear(playerSource, 'Resource stopped')
    end

    for playerSource in pairs(NexaAdmin.spectateStates) do
        Spectate.Stop(playerSource, 'Resource stopped')
    end

    for playerSource in pairs(NexaAdmin.noclipStates) do
        Noclip.Stop(playerSource, 'Resource stopped')
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    registerMigration()
    registerActions()
    registerCommands()
    log('Info', 'admin.start', 'nexa_admin started.', {
        version = NEXA_ADMIN.version,
        actions = #NexaAdmin.Actions.List()
    })
end)

registerActions()

exports('WarnPlayer', WarnPlayer)
exports('KickPlayer', KickPlayer)
exports('BanPlayer', BanPlayer)
exports('UnbanPlayer', UnbanPlayer)
exports('GoToPlayer', GoToPlayer)
exports('BringPlayer', BringPlayer)
exports('ReturnPlayer', ReturnPlayer)
exports('SetPlayerFrozen', SetPlayerFrozen)
exports('HealPlayer', HealPlayer)
exports('RevivePlayer', RevivePlayer)
exports('StartSpectate', StartSpectate)
exports('StopSpectate', StopSpectate)
exports('StartNoclip', StartNoclip)
exports('StopNoclip', StopNoclip)
exports('CreateAdminNote', CreateAdminNote)
exports('ListAdminNotes', ListAdminNotes)
exports('GetAdminActionState', GetAdminActionState)
exports('ResolveConnection', ResolveConnection)
exports('IsAccountBanned', IsAccountBanned)
exports('ListActions', ListActions)

exports('admin.moderation.warn', function(source, payload) return execute('admin.warn', source, payload) end)
exports('admin.moderation.kick', function(source, payload) return execute('admin.kick', source, payload) end)
exports('admin.moderation.tempban.prepare', function(source, payload) return execute('admin.ban.temp', source, payload) end)
exports('admin.moderation.freeze', function(source, payload) return execute('admin.freeze', source, payload) end)
exports('admin.utility.bring', function(source, payload) return execute('admin.bring', source, payload) end)
exports('admin.utility.goto', function(source, payload) return execute('admin.goto', source, payload) end)
exports('admin.utility.return', function(source, payload) return execute('admin.return', source, payload) end)
