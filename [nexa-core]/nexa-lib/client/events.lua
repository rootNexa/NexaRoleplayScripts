NexaLib.ClientEvents = {}

function NexaLib.ClientEvents.Register(name, handler)
    if type(name) ~= 'string' or type(handler) ~= 'function' then
        return false
    end

    RegisterNetEvent(name, function(payload)
        local ok, err = pcall(handler, payload)

        if not ok then
            NexaLib.Logger.error('nexa-lib', 'Client event failed.', {
                event = name,
                error = err
            })
        end
    end)

    return true
end

function NexaLib.ClientEvents.Emit(name, payload)
    if type(name) ~= 'string' then
        return false
    end

    TriggerServerEvent(name, payload)
    return true
end
