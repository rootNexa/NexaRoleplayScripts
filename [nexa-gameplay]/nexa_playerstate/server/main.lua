NexaPlayerState = {
    statesBySource = {},
    sourceByAccount = {},
    sourceByCharacter = {},
    spawnTokens = {},
    providers = {},
    bucketRanges = {},
    positionJumpAllowances = {}
}

local RESOURCE = GetCurrentResourceName()
local TRANSITIONS = {
    disconnected = { connected = true, session_ready = true },
    connected = { session_ready = true, unloading = true, failed = true },
    session_ready = { identity_ready = true, character_selection = true, unloading = true, failed = true },
    identity_ready = { character_selection = true, character_selected = true, unloading = true, failed = true },
    character_selection = { character_selected = true, unloading = true, failed = true },
    character_selected = { state_loading = true, unloading = true, failed = true },
    state_loading = { spawn_preparing = true, unloading = true, failed = true },
    spawn_preparing = { spawn_authorized = true, unloading = true, failed = true },
    spawn_authorized = { spawning = true, unloading = true, failed = true },
    spawning = { active = true, unloading = true, failed = true },
    active = { incapacitated = true, dead = true, unloading = true, failed = true },
    incapacitated = { active = true, dead = true, unloading = true, failed = true },
    dead = { active = true, spawn_preparing = true, unloading = true, failed = true },
    failed = { unloading = true, disconnected = true },
    unloading = { disconnected = true }
}

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

local function correlationId()
    return ('ps:%s:%s:%s'):format(os.time(), math.random(100000, 999999), GetGameTimer and GetGameTimer() or 0)
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

local function log(level, category, message, context)
    local core = getCore()

    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(RESOURCE, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()

    if core and core.EventBus then
        core.EventBus.Emit(eventName, payload, {
            resource = RESOURCE
        })
    end
end

local function dbCall(method, sql, params, category)
    local core = getCore()
    local database = core and core.Database

    if not database or not database[method] then
        return nil, {
            code = NEXA_PLAYERSTATE.errors.dependencyNotReady
        }
    end

    return database[method](sql, params or {}, {
        category = category or 'playerstate.db'
    })
end

local function getAccountId(source)
    local ok, accountId = pcall(function()
        return exports['nexa_identity']:GetAccountId(source)
    end)

    return ok and NexaPlayerStateNormalizeId(accountId) or nil
end

local function getActiveCharacter(source)
    local ok, result = pcall(function()
        return exports['nexa_characters']:GetActiveCharacter(source)
    end)

    if not ok or type(result) ~= 'table' then
        return nil
    end

    local data = result.data or result
    return data.character or data
end

local function getCharacterId(source)
    local character = getActiveCharacter(source)
    return NexaPlayerStateNormalizeId(character and character.id)
end

local function ensureState(source)
    source = NexaPlayerStateNormalizeSource(source)

    if not source then
        return nil
    end

    local state = NexaPlayerState.statesBySource[source]

    if not state then
        state = {
            source = source,
            state = 'connected',
            accountId = getAccountId(source),
            characterId = getCharacterId(source),
            lifeState = 'alive',
            bucket = NexaPlayerStateConfig.defaultBucket,
            history = {},
            createdAt = os.time(),
            updatedAt = os.time()
        }
        NexaPlayerState.statesBySource[source] = state
    end

    if state.accountId then
        NexaPlayerState.sourceByAccount[state.accountId] = source
    end

    if state.characterId then
        NexaPlayerState.sourceByCharacter[state.characterId] = source
    end

    return state
end

local function pushHistory(state, fromState, toState, context, result)
    state.history[#state.history + 1] = {
        from = fromState,
        to = toState,
        at = os.time(),
        reason = context and context.reason or nil,
        correlationId = context and context.correlationId or correlationId(),
        resource = context and context.resource or GetInvokingResource() or RESOURCE,
        result = result or 'success'
    }

    while #state.history > NexaPlayerStateConfig.transitionHistoryLimit do
        table.remove(state.history, 1)
    end
end

function PlayerStateGet(source)
    return ensureState(source)
end

local function publicState(state)
    if not state then
        return nil
    end

    return {
        source = state.source,
        state = state.state,
        accountId = state.accountId,
        characterId = state.characterId,
        lifeState = state.lifeState,
        bucket = state.bucket,
        active = state.state == 'active',
        readyForGameplay = state.state == 'active',
        lastPosition = state.lastPosition,
        updatedAt = state.updatedAt
    }
end

function PlayerStateCanTransition(source, targetState)
    local state = ensureState(source)

    if not state or not NEXA_PLAYERSTATE.states[targetState] then
        return false
    end

    return TRANSITIONS[state.state] and TRANSITIONS[state.state][targetState] == true
end

function PlayerStateTransition(source, targetState, context)
    local state = ensureState(source)

    if not state then
        return response(false, NEXA_PLAYERSTATE.errors.notFound, 'Player state not found.')
    end

    if not PlayerStateCanTransition(source, targetState) then
        pushHistory(state, state.state, targetState, context, 'denied')
        log('Warn', 'playerstate.transition', 'Invalid player state transition.', {
            source = source,
            from = state.state,
            to = targetState
        })
        return response(false, NEXA_PLAYERSTATE.errors.invalidTransition, 'Invalid transition.')
    end

    local previous = state.state
    state.state = targetState
    state.updatedAt = os.time()
    state.accountId = state.accountId or getAccountId(source)
    state.characterId = state.characterId or getCharacterId(source)
    pushHistory(state, previous, targetState, context, 'success')

    emit(NEXA_PLAYERSTATE.events.stateChanged, {
        source = source,
        from = previous,
        to = targetState,
        accountId = state.accountId,
        characterId = state.characterId
    })

    if targetState == 'active' then
        emit(NEXA_PLAYERSTATE.events.active, publicState(state))
        TriggerEvent(NEXA_PLAYERSTATE.events.publicReady, publicState(state))
    elseif targetState == 'unloading' then
        emit(NEXA_PLAYERSTATE.events.unloading, publicState(state))
        TriggerEvent(NEXA_PLAYERSTATE.events.publicUnloading, publicState(state))
    elseif targetState == 'failed' then
        emit(NEXA_PLAYERSTATE.events.failed, publicState(state))
    elseif targetState == 'spawn_preparing' then
        emit(NEXA_PLAYERSTATE.events.spawnPreparing, publicState(state))
    elseif targetState == 'spawn_authorized' then
        emit(NEXA_PLAYERSTATE.events.spawnAuthorized, publicState(state))
    end

    return response(true, 'OK', 'Transition complete.', publicState(state))
end

function PlayerStateFail(source, code, context)
    return PlayerStateTransition(source, 'failed', {
        reason = code,
        context = context
    })
end

local function savePosition(characterId, positionType, coords, metadata)
    coords = NexaPlayerStateNormalizeCoords(coords)
    characterId = NexaPlayerStateNormalizeId(characterId)

    if not characterId or not coords then
        return false, NEXA_PLAYERSTATE.errors.positionInvalid
    end

    local _, err = dbCall('Update', [[
        INSERT INTO nexa_character_positions (
            character_id, x, y, z, heading, routing_bucket, position_type, is_valid, metadata_json, version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, 1)
        ON DUPLICATE KEY UPDATE
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading),
            routing_bucket = VALUES(routing_bucket),
            is_valid = 1,
            metadata_json = VALUES(metadata_json),
            version = version + 1,
            updated_at = CURRENT_TIMESTAMP
    ]], {
        characterId,
        coords.x,
        coords.y,
        coords.z,
        coords.heading,
        coords.bucket,
        positionType or 'last_known',
        encode(metadata or {})
    }, 'playerstate.position.save')

    return err == nil, err and err.code or nil
end

local function loadPosition(characterId, positionType)
    local row = dbCall('Single', [[
        SELECT *
        FROM nexa_character_positions
        WHERE character_id = ? AND position_type = ? AND is_valid = 1
        LIMIT 1
    ]], { characterId, positionType or 'last_known' }, 'playerstate.position.load')

    if not row then
        return nil
    end

    return NexaPlayerStateNormalizeCoords({
        x = row.x,
        y = row.y,
        z = row.z,
        heading = row.heading,
        bucket = row.routing_bucket
    })
end

local function saveLifeState(characterId, lifeState, health, armour, metadata)
    if not NEXA_PLAYERSTATE.lifeStates[lifeState] then
        return false, NEXA_PLAYERSTATE.errors.lifeStateInvalid
    end

    local _, err = dbCall('Update', [[
        INSERT INTO nexa_character_states (
            character_id, life_state, health, armour, is_incapacitated, is_dead, metadata_json, version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE
            life_state = VALUES(life_state),
            health = VALUES(health),
            armour = VALUES(armour),
            is_incapacitated = VALUES(is_incapacitated),
            is_dead = VALUES(is_dead),
            metadata_json = VALUES(metadata_json),
            version = version + 1,
            updated_at = CURRENT_TIMESTAMP
    ]], {
        characterId,
        lifeState,
        tonumber(health) or 200,
        tonumber(armour) or 0,
        lifeState == 'incapacitated' and 1 or 0,
        lifeState == 'dead' and 1 or 0,
        encode(metadata or {})
    }, 'playerstate.life.save')

    return err == nil, err and err.code or nil
end

local function loadLifeState(characterId)
    local row = dbCall('Single', 'SELECT * FROM nexa_character_states WHERE character_id = ? LIMIT 1', { characterId }, 'playerstate.life.load')

    if not row then
        return {
            lifeState = 'alive',
            health = 200,
            armour = 0
        }
    end

    return {
        lifeState = row.life_state or 'alive',
        health = tonumber(row.health) or 200,
        armour = tonumber(row.armour) or 0,
        metadata = decode(row.metadata_json, {})
    }
end

SpawnProviders = {}

function SpawnProviders.Register(definition)
    if type(definition) ~= 'table' or type(definition.name) ~= 'string' or type(definition.Resolve) ~= 'function' then
        return false
    end

    NexaPlayerState.providers[definition.name] = definition
    return true
end

function SpawnProviders.Unregister(name)
    NexaPlayerState.providers[name] = nil
    return true
end

function SpawnProviders.Get(name)
    return NexaPlayerState.providers[name]
end

function SpawnProviders.List()
    local providers = {}

    for _, provider in pairs(NexaPlayerState.providers) do
        providers[#providers + 1] = {
            name = provider.name,
            priority = provider.priority or 0
        }
    end

    table.sort(providers, function(left, right)
        return left.priority > right.priority
    end)
    return providers
end

function SpawnProviders.Resolve(context)
    local providers = SpawnProviders.List()

    for _, entry in ipairs(providers) do
        local provider = NexaPlayerState.providers[entry.name]
        local canProvide = provider.CanProvide == nil or provider.CanProvide(context) == true

        if canProvide then
            local ok, result = pcall(provider.Resolve, context)

            if ok and provider.Validate(result) == true then
                result.provider = provider.name
                return result, nil
            end

            log('Warn', 'playerstate.spawn_provider', 'Spawn provider failed.', {
                provider = provider.name,
                error = ok and 'invalid_result' or result
            })
        end
    end

    return nil, NEXA_PLAYERSTATE.errors.providerNotFound
end

Buckets = {}

function Buckets.RegisterRange(owner, range)
    if type(owner) ~= 'string' or type(range) ~= 'table' then
        return false
    end

    local startBucket = NexaPlayerStateNormalizeBucket(range.start)
    local endBucket = NexaPlayerStateNormalizeBucket(range.finish or range['end'])

    if not startBucket or not endBucket or endBucket < startBucket then
        return false
    end

    NexaPlayerState.bucketRanges[owner] = {
        start = startBucket,
        finish = endBucket
    }
    return true
end

function Buckets.Validate(bucket)
    bucket = NexaPlayerStateNormalizeBucket(bucket)

    if bucket == nil then
        return false
    end

    if bucket == NexaPlayerStateConfig.defaultBucket then
        return true
    end

    for _, range in pairs(NexaPlayerState.bucketRanges) do
        if bucket >= range.start and bucket <= range.finish then
            return true
        end
    end

    return false
end

function Buckets.Get(source)
    local state = ensureState(source)
    return state and state.bucket or NexaPlayerStateConfig.defaultBucket
end

function Buckets.Set(source, bucket, context)
    local state = ensureState(source)
    bucket = NexaPlayerStateNormalizeBucket(bucket)

    if not state or not bucket or not Buckets.Validate(bucket) then
        return response(false, NEXA_PLAYERSTATE.errors.bucketInvalid, 'Bucket is invalid.')
    end

    state.bucket = bucket
    SetPlayerRoutingBucket(state.source, bucket)
    return response(true, 'OK', 'Bucket set.', {
        bucket = bucket
    })
end

function Buckets.Reset(source, reason)
    return Buckets.Set(source, NexaPlayerStateConfig.defaultBucket, {
        reason = reason or 'reset'
    })
end

LifeState = {}

function LifeState.Get(sourceOrCharacter)
    local source = NexaPlayerStateNormalizeSource(sourceOrCharacter)

    if source then
        local state = ensureState(source)
        return state and state.lifeState or 'alive'
    end

    local characterId = NexaPlayerStateNormalizeId(sourceOrCharacter)
    local loaded = characterId and loadLifeState(characterId)
    return loaded and loaded.lifeState or 'alive'
end

function LifeState.Set(actor, target, lifeState, context)
    if not NEXA_PLAYERSTATE.lifeStates[lifeState] then
        return response(false, NEXA_PLAYERSTATE.errors.lifeStateInvalid, 'Life state is invalid.')
    end

    local source = NexaPlayerStateNormalizeSource(target)
    local characterId = source and getCharacterId(source) or NexaPlayerStateNormalizeId(target)

    if not characterId then
        return response(false, NEXA_PLAYERSTATE.errors.notFound, 'Character not found.')
    end

    if source then
        local state = ensureState(source)
        state.lifeState = lifeState

        if lifeState == 'dead' then
            PlayerStateTransition(source, 'dead', context)
        elseif lifeState == 'incapacitated' then
            PlayerStateTransition(source, 'incapacitated', context)
        elseif (state.state == 'dead' or state.state == 'incapacitated') and lifeState == 'alive' then
            PlayerStateTransition(source, 'active', context)
        end
    end

    saveLifeState(characterId, lifeState, context and context.health, context and context.armour, context)
    return response(true, 'OK', 'Life state set.', {
        characterId = characterId,
        lifeState = lifeState
    })
end

function LifeState.IsAlive(target)
    return LifeState.Get(target) == 'alive'
end

function LifeState.IsIncapacitated(target)
    return LifeState.Get(target) == 'incapacitated'
end

function LifeState.IsDead(target)
    return LifeState.Get(target) == 'dead'
end

local function generateToken()
    return ('%s:%s:%s:%s'):format(math.random(100000, 999999), os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function authorizeSpawn(source, state, spawn)
    local token = generateToken()

    NexaPlayerState.spawnTokens[token] = {
        token = token,
        source = source,
        characterId = state.characterId,
        position = spawn,
        expiresAt = os.time() + NexaPlayerStateConfig.spawnTokenTtlSeconds,
        used = false
    }

    PlayerStateTransition(source, 'spawn_authorized', {
        reason = 'spawn_token_created',
        correlationId = token
    })
    TriggerClientEvent(NEXA_PLAYERSTATE.events.spawnExecute, source, {
        token = token,
        characterId = state.characterId,
        position = spawn
    })

    SetTimeout(NexaPlayerStateConfig.spawnConfirmationTimeoutMs, function()
        local pending = NexaPlayerState.spawnTokens[token]

        if pending and pending.used ~= true then
            NexaPlayerState.spawnTokens[token] = nil
            PlayerStateFail(source, NEXA_PLAYERSTATE.errors.confirmationTimeout, {
                token = token
            })
        end
    end)

    return response(true, 'OK', 'Spawn authorized.', {
        token = token,
        position = spawn
    })
end

function RequestSpawn(source)
    source = NexaPlayerStateNormalizeSource(source)
    local state = ensureState(source)

    if not state then
        return response(false, NEXA_PLAYERSTATE.errors.notFound, 'Player state not found.')
    end

    if state.state == 'active' then
        return response(false, NEXA_PLAYERSTATE.errors.alreadyActive, 'Player is already active.')
    end

    state.accountId = getAccountId(source)
    state.characterId = getCharacterId(source)

    if not state.accountId or not state.characterId then
        return response(false, NEXA_PLAYERSTATE.errors.dependencyNotReady, 'Account or character is not ready.')
    end

    if state.state == 'connected' then
        PlayerStateTransition(source, 'session_ready', { reason = 'request_spawn' })
    end

    if state.state == 'session_ready' then
        PlayerStateTransition(source, 'identity_ready', { reason = 'request_spawn' })
    end

    if state.state == 'identity_ready' then
        PlayerStateTransition(source, 'character_selection', { reason = 'request_spawn' })
    end

    if state.state == 'character_selection' then
        PlayerStateTransition(source, 'character_selected', { reason = 'request_spawn' })
    end

    if state.state == 'character_selected' then
        PlayerStateTransition(source, 'state_loading', { reason = 'request_spawn' })
    end

    local life = loadLifeState(state.characterId)
    state.lifeState = life.lifeState or 'alive'
    local spawn, err = SpawnProviders.Resolve({
        source = source,
        accountId = state.accountId,
        characterId = state.characterId,
        lifeState = state.lifeState
    })

    if not spawn then
        return response(false, err or NEXA_PLAYERSTATE.errors.providerFailed, 'Spawn provider failed.')
    end

    state.pendingSpawn = spawn
    PlayerStateTransition(source, 'spawn_preparing', { reason = 'spawn_provider_resolved' })
    return authorizeSpawn(source, state, spawn)
end

function PlayerStateUnload(source, reason)
    local state = ensureState(source)

    if not state then
        return response(false, NEXA_PLAYERSTATE.errors.notFound, 'Player state not found.')
    end

    PlayerStateTransition(source, 'unloading', {
        reason = reason or 'unload'
    })

    if state.characterId and state.lastPosition then
        savePosition(state.characterId, 'last_known', state.lastPosition, {
            reason = reason
        })
    end

    if state.characterId then
        saveLifeState(state.characterId, state.lifeState or 'alive', nil, nil, {
            reason = reason
        })
    end

    for token, pending in pairs(NexaPlayerState.spawnTokens) do
        if pending.source == state.source then
            NexaPlayerState.spawnTokens[token] = nil
        end
    end

    Buckets.Reset(state.source, reason or 'unload')
    NexaPlayerState.sourceByAccount[state.accountId or -1] = nil
    NexaPlayerState.sourceByCharacter[state.characterId or -1] = nil
    PlayerStateTransition(source, 'disconnected', {
        reason = reason or 'unload'
    })
    NexaPlayerState.statesBySource[state.source] = nil
    return response(true, 'OK', 'Player unloaded.')
end

RegisterNetEvent(NEXA_PLAYERSTATE.events.spawnConfirm, function(payload)
    local playerSource = source
    local token = type(payload) == 'table' and payload.token or nil
    local pending = token and NexaPlayerState.spawnTokens[token] or nil

    if not pending then
        PlayerStateFail(playerSource, NEXA_PLAYERSTATE.errors.tokenInvalid, {})
        return
    end

    if pending.used then
        PlayerStateFail(playerSource, NEXA_PLAYERSTATE.errors.tokenUsed, {})
        return
    end

    if pending.expiresAt < os.time() then
        NexaPlayerState.spawnTokens[token] = nil
        PlayerStateFail(playerSource, NEXA_PLAYERSTATE.errors.tokenExpired, {})
        return
    end

    if pending.source ~= playerSource or tonumber(payload.characterId) ~= pending.characterId then
        PlayerStateFail(playerSource, NEXA_PLAYERSTATE.errors.tokenInvalid, {})
        return
    end

    pending.used = true
    NexaPlayerState.spawnTokens[token] = nil
    local state = ensureState(playerSource)
    state.lastPosition = pending.position
    state.bucket = pending.position.bucket or NexaPlayerStateConfig.defaultBucket
    PlayerStateTransition(playerSource, 'spawning', { reason = 'client_confirmed_spawn', correlationId = token })
    PlayerStateTransition(playerSource, 'active', { reason = 'spawn_complete', correlationId = token })
    savePosition(state.characterId, 'last_known', pending.position, {
        reason = 'spawn_complete'
    })
end)

RegisterNetEvent(NEXA_PLAYERSTATE.events.positionSnapshot, function(payload)
    local playerSource = source
    local state = ensureState(playerSource)

    if not state or state.state ~= 'active' or not state.characterId then
        return
    end

    local now = os.time()

    if state.lastSnapshotAt and now - state.lastSnapshotAt < NexaPlayerStateConfig.positionSnapshotMinIntervalSeconds then
        return
    end

    local coords = NexaPlayerStateNormalizeCoords(payload)

    if not coords then
        return
    end

    coords.bucket = Buckets.Get(playerSource)
    local previous = state.lastPosition
    local allowance = NexaPlayerState.positionJumpAllowances[playerSource]

    if previous and not allowance then
        local distance = NexaPlayerStateDistance(previous, coords)

        if distance and distance > NexaPlayerStateConfig.maxSnapshotDistance then
            log('Warn', 'playerstate.position', 'Implausible position snapshot ignored.', {
                source = playerSource,
                distance = distance
            })
            return
        end
    end

    if allowance then
        NexaPlayerState.positionJumpAllowances[playerSource] = nil
    end

    state.lastPosition = coords
    state.lastSnapshotAt = now

    if not state.lastSaveAt or now - state.lastSaveAt >= NexaPlayerStateConfig.positionSaveIntervalSeconds then
        state.lastSaveAt = now
        savePosition(state.characterId, 'last_known', coords, {
            source = 'snapshot'
        })
    end
end)

local function registerProviders()
    SpawnProviders.Register({
        name = 'last_position',
        priority = 100,
        Resolve = function(context)
            return loadPosition(context.characterId, 'last_known')
        end,
        Validate = function(result)
            return NexaPlayerStateNormalizeCoords(result) ~= nil and Buckets.Validate(result.bucket or 0)
        end
    })

    SpawnProviders.Register({
        name = 'safe_fallback',
        priority = 0,
        Resolve = function()
            log('Warn', 'playerstate.spawn', 'Using safe fallback spawn.', {})
            return NexaPlayerStateConfig.safeFallback
        end,
        Validate = function(result)
            return NexaPlayerStateNormalizeCoords(result) ~= nil
        end
    })
end

local function registerMigration()
    local core = getCore()

    if not core or not core.Database then
        return false
    end

    core.Database.RegisterMigration({
        id = '050_playerstate_foundation',
        description = 'Create playerstate character position and life state tables',
        transaction = false,
        statements = {
            [[CREATE TABLE IF NOT EXISTS nexa_character_positions (
                character_id BIGINT UNSIGNED NOT NULL,
                position_type VARCHAR(32) NOT NULL,
                x DOUBLE NOT NULL,
                y DOUBLE NOT NULL,
                z DOUBLE NOT NULL,
                heading DOUBLE NOT NULL DEFAULT 0,
                routing_bucket INT NOT NULL DEFAULT 0,
                interior_id VARCHAR(64) NULL,
                is_valid TINYINT(1) NOT NULL DEFAULT 1,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                version BIGINT UNSIGNED NOT NULL DEFAULT 1,
                metadata_json LONGTEXT NULL,
                PRIMARY KEY (character_id, position_type),
                KEY idx_nexa_character_positions_valid (is_valid),
                KEY idx_nexa_character_positions_updated (updated_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_character_states (
                character_id BIGINT UNSIGNED NOT NULL,
                life_state VARCHAR(32) NOT NULL DEFAULT 'alive',
                health INT NOT NULL DEFAULT 200,
                armour INT NOT NULL DEFAULT 0,
                is_incapacitated TINYINT(1) NOT NULL DEFAULT 0,
                is_dead TINYINT(1) NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                version BIGINT UNSIGNED NOT NULL DEFAULT 1,
                metadata_json LONGTEXT NULL,
                PRIMARY KEY (character_id),
                KEY idx_nexa_character_states_life (life_state)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
        }
    })

    local ok, err = core.Database.RunMigrations()

    if not ok then
        log('Error', 'playerstate.migration', 'Playerstate migrations failed.', { error = err })
    end

    return ok
end

local function registerCharacterEvents()
    local core = getCore()

    if not core or not core.EventBus then
        return
    end

    core.EventBus.On('nexa:internal:characters:selected', function(payload)
        local playerSource = payload and NexaPlayerStateNormalizeSource(payload.source)

        if playerSource then
            RequestSpawn(playerSource)
        end
    end, {
        metadata = {
            resource = RESOURCE
        }
    })

    core.EventBus.On('nexa:internal:characters:released', function(payload)
        local playerSource = payload and NexaPlayerStateNormalizeSource(payload.source)

        if playerSource then
            PlayerStateUnload(playerSource, 'character_released')
        end
    end, {
        metadata = {
            resource = RESOURCE
        }
    })
end

AddEventHandler('playerDropped', function(reason)
    PlayerStateUnload(source, reason)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    for source in pairs(NexaPlayerState.statesBySource) do
        PlayerStateUnload(source, 'resource_stop')
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    registerMigration()
    Buckets.RegisterRange('default', { start = 0, finish = 0 })
    registerProviders()
    registerCharacterEvents()
    log('Info', 'playerstate.start', 'nexa_playerstate started.', {
        providers = #SpawnProviders.List()
    })
end)

function GetPlayerState(source)
    return response(true, 'OK', 'Player state loaded.', publicState(ensureState(source)))
end

function IsPlayerActive(source)
    local state = ensureState(source)
    return state and state.state == 'active' or false
end

function IsPlayerReadyForGameplay(source)
    return IsPlayerActive(source)
end

function GetActiveCharacter(source)
    return getActiveCharacter(source)
end

function GetLastPosition(sourceOrCharacterId)
    local source = NexaPlayerStateNormalizeSource(sourceOrCharacterId)
    local characterId = source and getCharacterId(source) or NexaPlayerStateNormalizeId(sourceOrCharacterId)
    local position = characterId and loadPosition(characterId, 'last_known') or nil
    return response(position ~= nil, position and 'OK' or NEXA_PLAYERSTATE.errors.positionInvalid, position and 'Position loaded.' or 'Position not found.', position)
end

function RegisterSpawnProvider(definition)
    return SpawnProviders.Register(definition)
end

function GetByAccount(accountId)
    local source = NexaPlayerState.sourceByAccount[NexaPlayerStateNormalizeId(accountId)]
    return source and publicState(ensureState(source)) or nil
end

function GetByCharacter(characterId)
    local source = NexaPlayerState.sourceByCharacter[NexaPlayerStateNormalizeId(characterId)]
    return source and publicState(ensureState(source)) or nil
end

function GetTransitionHistory(source)
    local state = ensureState(source)
    return state and state.history or {}
end

function SetLifeState(actor, target, state, context)
    return LifeState.Set(actor, target, state, context or {})
end

function GetLifeState(target)
    return LifeState.Get(target)
end

function SetBucket(source, bucket, context)
    return Buckets.Set(source, bucket, context)
end

function GetBucket(source)
    return Buckets.Get(source)
end

function AllowPositionJump(source, context)
    source = NexaPlayerStateNormalizeSource(source)

    if source then
        NexaPlayerState.positionJumpAllowances[source] = {
            at = os.time(),
            context = context
        }
    end

    return true
end

exports('GetPlayerState', GetPlayerState)
exports('IsPlayerActive', IsPlayerActive)
exports('IsPlayerReadyForGameplay', IsPlayerReadyForGameplay)
exports('GetActiveCharacter', GetActiveCharacter)
exports('GetLastPosition', GetLastPosition)
exports('RequestSpawn', RequestSpawn)
exports('RegisterSpawnProvider', RegisterSpawnProvider)
exports('GetByAccount', GetByAccount)
exports('GetByCharacter', GetByCharacter)
exports('GetTransitionHistory', GetTransitionHistory)
exports('SetLifeState', SetLifeState)
exports('GetLifeState', GetLifeState)
exports('SetBucket', SetBucket)
exports('GetBucket', GetBucket)
exports('AllowPositionJump', AllowPositionJump)
