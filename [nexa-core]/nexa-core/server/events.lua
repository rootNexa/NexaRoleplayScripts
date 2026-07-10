Nexa.Events = Nexa.Events or {}
Nexa.EventBus = Nexa.EventBus or {
    listeners = {},
    subscriptions = {},
    nextId = 0,
    dispatchDepth = {},
    maxListeners = 32,
    maxDepth = 8
}

local INTERNAL_EVENT_PATTERN = '^nexa:internal:[a-z0-9_%-]+:[a-z0-9_%-]+$'

local function isValidInternalEventName(name)
    return type(name) == 'string' and name:match(INTERNAL_EVENT_PATTERN) ~= nil
end

local function cloneContext(context)
    if type(context) ~= 'table' then
        return {}
    end

    local cloned = {}

    for key, value in pairs(context) do
        cloned[key] = value
    end

    return cloned
end

local function sortListeners(name)
    table.sort(Nexa.EventBus.listeners[name], function(left, right)
        if left.priority == right.priority then
            return left.id < right.id
        end

        return left.priority > right.priority
    end)
end

local function makeSubscription(name, callback, options, once)
    options = options or {}

    if not isValidInternalEventName(name) or type(callback) ~= 'function' then
        return nil, 'INVALID_INPUT'
    end

    local listeners = Nexa.EventBus.listeners[name] or {}

    if #listeners >= (tonumber(options.maxListeners) or Nexa.EventBus.maxListeners) then
        return nil, 'MAX_LISTENERS'
    end

    Nexa.EventBus.nextId = Nexa.EventBus.nextId + 1

    local subscription = {
        id = ('internal:%s:%s'):format(name, Nexa.EventBus.nextId),
        name = name,
        callback = callback,
        once = once == true,
        async = options.async == true,
        priority = tonumber(options.priority) or 0,
        failFast = options.failFast == true,
        metadata = type(options.metadata) == 'table' and options.metadata or {},
        createdAt = os.time()
    }

    listeners[#listeners + 1] = subscription
    Nexa.EventBus.listeners[name] = listeners
    Nexa.EventBus.subscriptions[subscription.id] = subscription
    sortListeners(name)

    if options.debug == true then
        Nexa.Logger.Debug('eventbus.register', 'Interner Event-Listener registriert.', {
            event = name,
            subscriptionId = subscription.id,
            priority = subscription.priority,
            async = subscription.async,
            once = subscription.once,
            metadata = subscription.metadata
        })
    end

    return subscription.id, nil
end

function Nexa.EventBus.On(name, callback, options)
    return makeSubscription(name, callback, options, false)
end

function Nexa.EventBus.Once(name, callback, options)
    return makeSubscription(name, callback, options, true)
end

function Nexa.EventBus.Off(subscriptionId)
    local subscription = Nexa.EventBus.subscriptions[subscriptionId]

    if not subscription then
        return false, 'NOT_FOUND'
    end

    local listeners = Nexa.EventBus.listeners[subscription.name] or {}

    for index, listener in ipairs(listeners) do
        if listener.id == subscriptionId then
            table.remove(listeners, index)
            break
        end
    end

    Nexa.EventBus.subscriptions[subscriptionId] = nil
    return true, nil
end

local function dispatchListener(listener, payload, context)
    local ok, err = pcall(listener.callback, payload, context)

    if not ok then
        Nexa.Logger.Error('eventbus.listener', 'Interner Event-Listener fehlgeschlagen.', {
            event = listener.name,
            subscriptionId = listener.id,
            async = listener.async,
            metadata = listener.metadata,
            error = err
        })

        return false, err
    end

    return true, nil
end

function Nexa.EventBus.Emit(name, payload, context)
    if not isValidInternalEventName(name) then
        Nexa.Logger.Warn('eventbus.emit', 'Ungueltiger interner Eventname blockiert.', {
            event = name
        })
        return false, 'INVALID_EVENT_NAME'
    end

    local depth = (Nexa.EventBus.dispatchDepth[name] or 0) + 1

    if depth > Nexa.EventBus.maxDepth then
        Nexa.Logger.Error('eventbus.recursion', 'Interner Event rekursiv blockiert.', {
            event = name,
            depth = depth,
            maxDepth = Nexa.EventBus.maxDepth
        })
        return false, 'RECURSION_LIMIT'
    end

    local listeners = Nexa.EventBus.listeners[name] or {}

    if #listeners == 0 then
        return true, {
            event = name,
            listenerCount = 0,
            errors = {}
        }
    end

    Nexa.EventBus.dispatchDepth[name] = depth

    local dispatchContext = cloneContext(context)
    dispatchContext.event = name
    dispatchContext.listenerCount = #listeners
    dispatchContext.emittedAt = os.time()

    local snapshot = {}

    for index, listener in ipairs(listeners) do
        snapshot[index] = listener
    end

    local errors = {}

    for _, listener in ipairs(snapshot) do
        if Nexa.EventBus.subscriptions[listener.id] then
            if listener.once then
                Nexa.EventBus.Off(listener.id)
            end

            if listener.async then
                CreateThread(function()
                    dispatchListener(listener, payload, dispatchContext)
                end)
            else
                local ok, err = dispatchListener(listener, payload, dispatchContext)

                if not ok then
                    errors[#errors + 1] = {
                        subscriptionId = listener.id,
                        error = tostring(err)
                    }

                    if listener.failFast or dispatchContext.failFast == true then
                        Nexa.EventBus.dispatchDepth[name] = depth - 1
                        return false, {
                            event = name,
                            listenerCount = #snapshot,
                            errors = errors
                        }
                    end
                end
            end
        end
    end

    Nexa.EventBus.dispatchDepth[name] = depth - 1

    return #errors == 0, {
        event = name,
        listenerCount = #snapshot,
        errors = errors
    }
end

function Nexa.EventBus.HasListeners(name)
    return Nexa.EventBus.GetListenerCount(name) > 0
end

function Nexa.EventBus.GetListenerCount(name)
    if not isValidInternalEventName(name) then
        return 0
    end

    return #(Nexa.EventBus.listeners[name] or {})
end

function Nexa.Events.RegisterNet(name, handler)
    RegisterNetEvent(name, function(...)
        local source = source

        if type(source) ~= 'number' or source <= 0 then
            Nexa.Log('warn', 'Serverevent ohne gueltige Source blockiert.', {
                event = name
            })
            return
        end

        local ready = Nexa.Lifecycle.RequireReady(('event:%s'):format(name))

        if not ready then
            return
        end

        local player = Nexa.Players.Get(source)

        if not player then
            Nexa.Log('warn', 'Serverevent ohne geladene Session blockiert.', {
                event = name,
                source = source
            })
            return
        end

        local ok, err = pcall(handler, source, ...)

        if not ok then
            Nexa.Log('error', 'Serverevent fehlgeschlagen.', {
                event = name,
                source = source,
                error = err
            })
        end
    end)
end

function Nexa.Events.EmitClient(source, name, payload)
    if type(source) ~= 'number' or source <= 0 or type(name) ~= 'string' then
        return false
    end

    TriggerClientEvent(name, source, payload)
    return true
end

function Nexa.Events.EmitInternal(name, payload, context)
    return Nexa.EventBus.Emit(name, payload, context)
end

Nexa.Events.RegisterNet(Nexa.Constants.serverEvents.selectCharacter, function(source, characterId)
    local character, err = Nexa.Characters.Select(source, tonumber(characterId))

    if not character then
        TriggerClientEvent('nexa:core:client:characterSelectFailed', source, {
            code = err or 'INTERNAL_ERROR',
            message = 'Charakter konnte nicht geladen werden.'
        })
    end
end)

AddEventHandler('playerDropped', function(reason)
    if not Nexa.Lifecycle.IsReady() and Nexa.Lifecycle.GetState() ~= Nexa.Constants.lifecycle.states.stopping then
        return
    end

    Nexa.Players.Drop(source, reason)
end)
