NexaLib.ServerEvents = {
    lastCall = {}
}

local function canCall(source, name, cooldownMs)
    cooldownMs = cooldownMs or NexaLib.Defaults.eventCooldownMs

    if cooldownMs <= 0 then
        return true
    end

    local key = ('%s:%s'):format(source, name)
    local now = GetGameTimer()
    local last = NexaLib.ServerEvents.lastCall[key] or 0

    if last > 0 and now - last < cooldownMs then
        return false
    end

    NexaLib.ServerEvents.lastCall[key] = now
    return true
end

function NexaLib.ServerEvents.Register(name, handler, options)
    if type(name) ~= 'string' or type(handler) ~= 'function' then
        return false
    end

    options = options or {}

    RegisterNetEvent(name, function(payload)
        local source = source

        if type(source) ~= 'number' or source <= 0 then
            return
        end

        if not canCall(source, name, options.cooldownMs) then
            return
        end

        local ok, err = pcall(handler, source, payload)

        if not ok then
            NexaLib.Logger.error('nexa-lib', 'Server event failed.', {
                event = name,
                source = source,
                error = err
            })
        end
    end)

    return true
end

function NexaLib.ServerEvents.Emit(source, name, payload)
    source = tonumber(source)

    if not source or source <= 0 or type(name) ~= 'string' then
        return false
    end

    TriggerClientEvent(name, source, payload)
    return true
end
