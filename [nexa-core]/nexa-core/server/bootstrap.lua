Nexa.Bootstrap = {
    started = false,
    errors = {}
}

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

local function requireResource(name)
    local state = GetResourceState(name)

    if state ~= 'started' then
        Nexa.Bootstrap.errors[#Nexa.Bootstrap.errors + 1] = ('Resource nicht gestartet: %s (%s)'):format(name, state)
    end
end

function Nexa.Bootstrap.Run()
    Nexa.Bootstrap.errors = {}

    requireResource('oxmysql')

    local ok, err = pcall(Nexa.Database.CheckReady)

    if not ok or err ~= true then
        Nexa.Bootstrap.errors[#Nexa.Bootstrap.errors + 1] = 'Datenbank ist nicht erreichbar.'
    end

    if #Nexa.Bootstrap.errors > 0 then
        for _, message in ipairs(Nexa.Bootstrap.errors) do
            Nexa.Log('error', message)
        end

        error('nexa-core Bootstrap fehlgeschlagen.', 0)
    end

    Nexa.Bootstrap.started = true
    Nexa.Log('info', 'Nexa Framework Foundation gestartet.', {
        version = Nexa.Version,
        environment = Nexa.Config.environment
    })
end
