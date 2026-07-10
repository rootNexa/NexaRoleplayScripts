local states = Nexa.Constants.lifecycle.states
local requiredResources = Nexa.Constants.lifecycle.requiredResources

local allowedTransitions = {
    [states.created] = {
        [states.initializing] = true,
        [states.stopping] = true,
        [states.failed] = true
    },
    [states.initializing] = {
        [states.initialized] = true,
        [states.failed] = true
    },
    [states.initialized] = {
        [states.starting] = true,
        [states.stopping] = true,
        [states.failed] = true
    },
    [states.starting] = {
        [states.ready] = true,
        [states.stopping] = true,
        [states.failed] = true
    },
    [states.ready] = {
        [states.stopping] = true,
        [states.failed] = true
    },
    [states.stopping] = {
        [states.stopped] = true,
        [states.failed] = true
    },
    [states.stopped] = {
        [states.initializing] = true
    },
    [states.failed] = {
        [states.stopping] = true
    }
}

Nexa.Lifecycle = Nexa.Lifecycle or {
    state = states.created,
    hooks = {},
    startTimestamp = nil,
    failureReason = nil
}

Nexa.Bootstrap = Nexa.Bootstrap or {
    started = false,
    errors = {}
}

local function transition(nextState, reason)
    local currentState = Nexa.Lifecycle.state

    if currentState == nextState then
        Nexa.Log('warn', 'Lifecycle-Zustand bereits aktiv.', {
            state = currentState,
            reason = reason
        })
        return false, 'STATE_UNCHANGED'
    end

    if not allowedTransitions[currentState] or not allowedTransitions[currentState][nextState] then
        Nexa.Log('error', 'Ungueltiger Lifecycle-Zustandswechsel blockiert.', {
            from = currentState,
            to = nextState,
            reason = reason
        })
        return false, 'INVALID_STATE_TRANSITION'
    end

    Nexa.Lifecycle.state = nextState

    if nextState == states.failed then
        Nexa.Lifecycle.failureReason = reason or 'UNKNOWN'
        Nexa.Bootstrap.started = false
    elseif nextState == states.ready then
        Nexa.Bootstrap.started = true
    elseif nextState == states.initializing then
        Nexa.Lifecycle.failureReason = nil
        Nexa.Lifecycle.startTimestamp = os.time()
        Nexa.Bootstrap.errors = {}
        Nexa.Bootstrap.started = false
    elseif nextState == states.stopped then
        Nexa.Bootstrap.started = false
    end

    Nexa.Log('info', 'Lifecycle-Zustand gewechselt.', {
        from = currentState,
        to = nextState,
        reason = reason
    })

    return true, nil
end

local function runHooks(stage)
    local hooks = Nexa.Lifecycle.hooks[stage] or {}

    for index, callback in ipairs(hooks) do
        local ok, err = pcall(callback, stage, Nexa.Lifecycle.state)

        if not ok then
            Nexa.Log('error', 'Lifecycle-Hook fehlgeschlagen.', {
                stage = stage,
                index = index,
                error = err
            })

            return false, err
        end
    end

    return true, nil
end

local function fail(reason, context)
    reason = reason or 'UNKNOWN'
    Nexa.Bootstrap.errors[#Nexa.Bootstrap.errors + 1] = reason

    Nexa.Log('error', 'Core Lifecycle fehlgeschlagen.', {
        reason = reason,
        context = context
    })

    if Nexa.Lifecycle.state ~= states.failed then
        transition(states.failed, reason)
    else
        Nexa.Lifecycle.failureReason = reason
    end

    if Nexa.EventBus then
        Nexa.EventBus.Emit(Nexa.Constants.internalEvents.coreFailed, {
            reason = reason,
            context = context
        }, {
            module = 'lifecycle'
        })
    end

    runHooks(states.failed)
    return false, reason
end

local function requireResource(name)
    local state = GetResourceState(name)

    if state ~= 'started' then
        return false, ('Pflichtabhaengigkeit nicht gestartet: %s (%s)'):format(name, state)
    end

    return true, nil
end

local function checkDependencies()
    for _, resourceName in ipairs(requiredResources) do
        local ok, err = requireResource(resourceName)

        if not ok then
            return false, err
        end
    end

    return true, nil
end

local function checkConfig()
    local ok, errors, warnings = Nexa.Config.Validate()

    for _, warning in ipairs(warnings or {}) do
        Nexa.Log('warn', 'Konfigurationswarnung.', {
            path = warning.path,
            code = warning.code,
            message = warning.message
        })
    end

    if ok then
        return true, nil
    end

    for _, configError in ipairs(errors or {}) do
        Nexa.Log('error', 'Konfigurationsfehler.', {
            path = configError.path,
            code = configError.code,
            message = configError.message
        })
    end

    return false, 'CONFIG_INVALID'
end

function Nexa.Lifecycle.GetState()
    return Nexa.Lifecycle.state
end

function Nexa.Lifecycle.IsReady()
    return Nexa.Lifecycle.state == states.ready
end

function Nexa.Lifecycle.GetStartTimestamp()
    return Nexa.Lifecycle.startTimestamp
end

function Nexa.Lifecycle.GetFailureReason()
    return Nexa.Lifecycle.failureReason
end

function Nexa.Lifecycle.RegisterLifecycleHook(stage, callback)
    if type(stage) ~= 'string' or type(callback) ~= 'function' then
        Nexa.Log('error', 'Lifecycle-Hook-Registrierung ungueltig.', {
            stage = stage
        })
        return false, 'INVALID_INPUT'
    end

    if not Nexa.Constants.lifecycle.stages[stage] then
        Nexa.Log('error', 'Unbekannte Lifecycle-Hook-Stage.', {
            stage = stage
        })
        return false, 'UNKNOWN_STAGE'
    end

    Nexa.Lifecycle.hooks[stage] = Nexa.Lifecycle.hooks[stage] or {}
    Nexa.Lifecycle.hooks[stage][#Nexa.Lifecycle.hooks[stage] + 1] = callback
    return true, nil
end

function Nexa.Lifecycle.Fail(reason, context)
    return fail(reason, context)
end

function Nexa.Lifecycle.RequireReady(operation)
    if Nexa.Lifecycle.IsReady() then
        return true, nil
    end

    Nexa.Log('warn', 'Core-Zugriff vor Bereitschaft blockiert.', {
        operation = operation,
        state = Nexa.Lifecycle.GetState(),
        failureReason = Nexa.Lifecycle.GetFailureReason()
    })

    return false, Nexa.Constants.errors.coreNotReady
end

function Nexa.Audit(action, actor, context)
    local actorSource = type(actor) == 'number' and actor or nil
    local player = actorSource and Nexa.Players.Get(actorSource) or nil
    local character = actorSource and Nexa.Characters.GetActive(actorSource) or nil

    local ok, err = Nexa.Database.Insert([[
        INSERT INTO nexa_audit_log (action, actor_source, player_id, character_id, resource, context)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        action,
        actorSource,
        player and player.id or nil,
        character and character.id or nil,
        GetInvokingResource() or Nexa.Constants.resourceName,
        json.encode(context or {})
    })

    if not ok and err then
        Nexa.Log('error', 'Audit-Log konnte nicht geschrieben werden.', {
            action = action,
            error = err
        })
    end
end

function Nexa.Bootstrap.Initialize()
    if Nexa.Lifecycle.IsReady() or Nexa.Lifecycle.state == states.initializing or Nexa.Lifecycle.state == states.starting then
        Nexa.Log('warn', 'Doppelte Core-Initialisierung blockiert.', {
            state = Nexa.Lifecycle.GetState()
        })
        return false, 'ALREADY_INITIALIZED'
    end

    local transitioned, transitionErr = transition(states.initializing, 'bootstrap_initialize')

    if not transitioned then
        return false, transitionErr
    end

    local hooksOk, hookErr = runHooks(states.initializing)

    if not hooksOk then
        return fail('INITIALIZING_HOOK_FAILED', hookErr)
    end

    local configOk, configErr = checkConfig()

    if not configOk then
        return fail(configErr)
    end

    local depsOk, depsErr = checkDependencies()

    if not depsOk then
        return fail(depsErr)
    end

    local ok, err = pcall(Nexa.Database.CheckReady)

    if not ok or err ~= true then
        return fail('Datenbank ist nicht erreichbar.', err)
    end

    local migrationsOk, migrationsErr = Nexa.Database.RunMigrations()

    if not migrationsOk then
        return fail('DATABASE_MIGRATIONS_FAILED', migrationsErr)
    end

    if Nexa.Modules then
        local modulesOk, modulesErr = Nexa.Modules.InitializeAll()

        if not modulesOk then
            return fail('MODULE_INITIALIZE_FAILED', modulesErr)
        end
    end

    transitioned, transitionErr = transition(states.initialized, 'bootstrap_initialized')

    if not transitioned then
        return fail('INITIALIZED_TRANSITION_FAILED', transitionErr)
    end

    hooksOk, hookErr = runHooks(states.initialized)

    if not hooksOk then
        return fail('INITIALIZED_HOOK_FAILED', hookErr)
    end

    return true, nil
end

function Nexa.Bootstrap.Start()
    if Nexa.Lifecycle.IsReady() then
        Nexa.Log('warn', 'Doppelter Core-Start blockiert.', {
            state = Nexa.Lifecycle.GetState()
        })
        return false, 'ALREADY_READY'
    end

    if Nexa.Lifecycle.state == states.failed then
        Nexa.Log('error', 'Core-Start nach Fehlerzustand blockiert.', {
            failureReason = Nexa.Lifecycle.GetFailureReason()
        })
        return false, 'FAILED'
    end

    local initialized, initErr = Nexa.Bootstrap.Initialize()

    if not initialized then
        return false, initErr
    end

    local transitioned, transitionErr = transition(states.starting, 'bootstrap_start')

    if not transitioned then
        return fail('STARTING_TRANSITION_FAILED', transitionErr)
    end

    local hooksOk, hookErr = runHooks(states.starting)

    if not hooksOk then
        return fail('STARTING_HOOK_FAILED', hookErr)
    end

    if Nexa.Cache then
        Nexa.Cache.Start()
    end

    if Nexa.Modules then
        local modulesOk, modulesErr = Nexa.Modules.StartAll()

        if not modulesOk then
            return fail('MODULE_START_FAILED', modulesErr)
        end

        modulesOk, modulesErr = Nexa.Modules.ReadyAll()

        if not modulesOk then
            return fail('MODULE_READY_FAILED', modulesErr)
        end
    end

    transitioned, transitionErr = transition(states.ready, 'bootstrap_ready')

    if not transitioned then
        return fail('READY_TRANSITION_FAILED', transitionErr)
    end

    hooksOk, hookErr = runHooks(states.ready)

    if not hooksOk then
        return fail('READY_HOOK_FAILED', hookErr)
    end

    if Nexa.EventBus then
        Nexa.EventBus.Emit(Nexa.Constants.internalEvents.coreReady, {
            version = Nexa.Version,
            environment = Nexa.Config.GetEnvironment(),
            startTimestamp = Nexa.Lifecycle.GetStartTimestamp()
        }, {
            module = 'lifecycle'
        })
    end

    Nexa.Log('info', 'Nexa Framework Foundation gestartet.', {
        version = Nexa.Version,
        environment = Nexa.Config.environment,
        startTimestamp = Nexa.Lifecycle.GetStartTimestamp()
    })

    return true, nil
end

function Nexa.Bootstrap.Stop(reason)
    reason = reason or 'resource_stop'

    if Nexa.Lifecycle.state == states.stopped or Nexa.Lifecycle.state == states.stopping then
        Nexa.Log('warn', 'Doppelter Core-Stop blockiert.', {
            state = Nexa.Lifecycle.GetState(),
            reason = reason
        })
        return false, 'ALREADY_STOPPING'
    end

    local transitioned, transitionErr = transition(states.stopping, reason)

    if not transitioned then
        return false, transitionErr
    end

    if Nexa.EventBus then
        Nexa.EventBus.Emit(Nexa.Constants.internalEvents.coreStopping, {
            reason = reason
        }, {
            module = 'lifecycle'
        })
    end

    local hooksOk, hookErr = runHooks(states.stopping)

    if not hooksOk then
        Nexa.Log('error', 'Lifecycle-Stop-Hook fehlgeschlagen; Stop wird fortgesetzt.', {
            error = hookErr
        })
    end

    if Nexa.Modules then
        Nexa.Modules.StopAll(reason)
    end

    if Nexa.Cache then
        Nexa.Cache.Stop()
    end

    transitioned, transitionErr = transition(states.stopped, reason)

    if not transitioned then
        return fail('STOPPED_TRANSITION_FAILED', transitionErr)
    end

    hooksOk, hookErr = runHooks(states.stopped)

    if not hooksOk then
        Nexa.Log('error', 'Lifecycle-Stopped-Hook fehlgeschlagen.', {
            error = hookErr
        })
    end

    Nexa.Log('info', 'Nexa Framework Foundation gestoppt.', {
        reason = reason
    })

    return true, nil
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == Nexa.Constants.resourceName then
        return
    end

    for _, dependencyName in ipairs(requiredResources) do
        if resourceName == dependencyName then
            Nexa.Log('info', 'Core-Abhaengigkeit gestartet.', {
                dependency = dependencyName,
                state = Nexa.Lifecycle.GetState()
            })
            return
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == Nexa.Constants.resourceName then
        Nexa.Bootstrap.Stop('resource_stop')
        return
    end

    for _, dependencyName in ipairs(requiredResources) do
        if resourceName == dependencyName and Nexa.Lifecycle.IsReady() then
            Nexa.Lifecycle.Fail(('Pflichtabhaengigkeit gestoppt: %s'):format(dependencyName), {
                dependency = dependencyName
            })
            return
        end
    end
end)
