Nexa.Events = Nexa.Events or {}

function Nexa.Events.RegisterNet(name, handler)
    RegisterNetEvent(name, function(...)
        local source = source

        if type(source) ~= 'number' or source <= 0 then
            Nexa.Log('warn', 'Serverevent ohne gueltige Source blockiert.', {
                event = name
            })
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

function Nexa.Events.EmitInternal(name, payload)
    if type(name) ~= 'string' then
        return false
    end

    TriggerEvent(name, payload)
    return true
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
    Nexa.Players.Drop(source, reason)
end)
