Nexa.Players = {
    bySource = {},
    byIdentifier = {}
}

local function sanitizePlayer(player)
    if not player then
        return nil
    end

    return {
        id = player.id,
        source = player.source,
        identifier = player.identifier,
        sessionId = player.sessionId,
        name = player.name,
        activeCharacterId = player.activeCharacterId,
        loaded = player.loaded
    }
end

function Nexa.Players.Register(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    local session, sessionErr = Nexa.Sessions.Create(source)

    if not session then
        Nexa.Log('warn', 'Spieler ohne gueltige Session abgelehnt.', {
            source = source,
            error = sessionErr
        })
        DropPlayer(source, 'Nexa: Keine gueltige Session.')
        return nil, sessionErr or 'SESSION_REJECTED'
    end

    local primaryIdentifier = session.license
    local identifierType = primaryIdentifier and primaryIdentifier:match('^([^:]+):') or 'license'

    if not primaryIdentifier then
        Nexa.Log('warn', 'Spieler ohne gueltige License abgelehnt.', {
            source = source
        })
        Nexa.Sessions.Close(source, 'missing_license')
        DropPlayer(source, 'Nexa: Kein gueltiger License-Identifier gefunden.')
        return nil, 'MISSING_LICENSE'
    end

    local name = GetPlayerName(source) or ('Spieler %s'):format(source)
    local playerId, err = Nexa.Database.Insert([[
        INSERT INTO nexa_players (identifier, identifier_type, display_name, last_seen_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            identifier_type = VALUES(identifier_type),
            display_name = VALUES(display_name),
            last_seen_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
    ]], { primaryIdentifier, identifierType, name })

    if err then
        Nexa.Log('error', 'Player-Registrierung fehlgeschlagen.', {
            source = source,
            identifier_type = identifierType
        })
        Nexa.Sessions.Close(source, 'player_registration_failed')
        return nil, 'DATABASE_ERROR'
    end

    local row = Nexa.Database.FetchOne(
        'SELECT id, identifier, identifier_type, display_name FROM nexa_players WHERE identifier = ? LIMIT 1',
        { primaryIdentifier }
    )

    if not row then
        Nexa.Sessions.Close(source, 'player_lookup_failed')
        return nil, 'DATABASE_ERROR'
    end

    local player = {
        id = row.id,
        source = source,
        sessionId = session.id,
        identifier = row.identifier,
        identifierType = row.identifier_type,
        identifiers = session.identifiers,
        name = row.display_name,
        activeCharacterId = nil,
        loaded = true,
        joinedAt = os.time()
    }

    Nexa.Players.bySource[source] = player
    Nexa.Players.byIdentifier[player.identifier] = player
    Nexa.Permissions.Load({
        type = 'account',
        id = player.id,
        source = source
    })
    Nexa.Audit('player.session_started', source, {
        player_id = player.id
    })

    TriggerClientEvent(Nexa.Constants.events.playerLoaded, source, sanitizePlayer(player))
    return player, nil
end

function Nexa.Players.Drop(source, reason)
    source = tonumber(source)
    local player = Nexa.Players.bySource[source]

    if not player then
        return
    end

    Nexa.Characters.Unload(source)
    Nexa.Audit('player.session_ended', source, {
        player_id = player.id,
        reason = reason
    })

    Nexa.Permissions.Invalidate({
        type = 'account',
        id = player.id,
        source = source
    })
    Nexa.Players.byIdentifier[player.identifier] = nil
    Nexa.Players.bySource[source] = nil
    Nexa.Sessions.Close(source, reason)
end

function Nexa.Players.Get(source)
    local rawSource = source
    source = tonumber(source)
    local player = Nexa.Players.bySource[source]

    if Nexa.Log then
        Nexa.Log(player and 'info' or 'warn', 'Players.Get lookup.', {
            rawSource = rawSource,
            rawSourceType = type(rawSource),
            normalizedSource = source,
            found = player ~= nil,
            playerId = player and player.id or nil
        })
    end

    return player
end

function Nexa.Players.GetPublic(source)
    return sanitizePlayer(Nexa.Players.Get(source))
end

function Nexa.Players.GetIdentifier(source)
    local player = Nexa.Players.Get(source)
    return player and player.identifier or nil
end
