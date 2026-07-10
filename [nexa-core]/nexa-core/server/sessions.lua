Nexa.Sessions = Nexa.Sessions or {
    byId = {},
    bySource = {},
    byLicense = {},
    counter = 0
}

local states = {
    connecting = 'connecting',
    authenticated = 'authenticated',
    active = 'active',
    dropping = 'dropping',
    closed = 'closed',
    rejected = 'rejected'
}

local allowedTransitions = {
    [states.connecting] = {
        [states.authenticated] = true,
        [states.rejected] = true,
        [states.dropping] = true
    },
    [states.authenticated] = {
        [states.active] = true,
        [states.rejected] = true,
        [states.dropping] = true
    },
    [states.active] = {
        [states.dropping] = true,
        [states.closed] = true
    },
    [states.dropping] = {
        [states.closed] = true,
        [states.rejected] = true
    },
    [states.rejected] = {},
    [states.closed] = {}
}

local function now()
    return os.time()
end

local function nowMs()
    if GetGameTimer then
        return GetGameTimer()
    end

    return math.floor(os.clock() * 1000)
end

local function sessionLog(level, category, message, context)
    if Nexa.Logger and Nexa.Logger[level] then
        Nexa.Logger[level](category, message, context)
        return
    end

    Nexa.Log(level:lower(), message, context)
end

local function normalizeIdentifierValue(value)
    if type(value) ~= 'string' then
        return nil, nil
    end

    local key, identifier = value:match('^([^:]+):(.+)$')

    if not key or not identifier then
        return nil, nil
    end

    key = key:lower()
    identifier = identifier:lower():gsub('%s+', '')

    if identifier == '' then
        return nil, nil
    end

    return key, ('%s:%s'):format(key, identifier)
end

local function maskIp(value)
    if type(value) ~= 'string' or value == '' then
        return nil
    end

    local first, second = value:match('^(%d+)%.(%d+)%.%d+%.%d+$')

    if first and second then
        return ('%s.%s.x.x'):format(first, second)
    end

    local prefix = value:match('^([%x:]+):[%x:]+:[%x:]+:[%x:]+$')

    if prefix then
        return prefix .. ':x:x:x'
    end

    return '<masked>'
end

local function maskIdentifier(value)
    if type(value) ~= 'string' then
        return nil
    end

    local key, identifier = value:match('^([^:]+):(.+)$')

    if not key or not identifier then
        return '<masked>'
    end

    if #identifier <= 8 then
        return key .. ':<masked>'
    end

    return ('%s:%s...%s'):format(key, identifier:sub(1, 4), identifier:sub(-4))
end

local function maskedIdentifiers(identifiers)
    local masked = {}

    for key, value in pairs(identifiers or {}) do
        masked[key] = maskIdentifier(value)
    end

    return masked
end

local function collectIdentifiers(source, provided)
    local identifiers = {}

    if type(provided) == 'table' then
        for key, value in pairs(provided) do
            if type(value) == 'string' then
                local rawValue = value

                if type(key) == 'string' and not value:find(':', 1, true) then
                    rawValue = key .. ':' .. value
                end

                local normalizedKey, normalizedValue = normalizeIdentifierValue(rawValue)

                if normalizedKey and normalizedKey ~= 'ip' then
                    identifiers[normalizedKey] = normalizedValue
                end
            end
        end
    elseif GetPlayerIdentifiers then
        for _, value in ipairs(GetPlayerIdentifiers(source)) do
            local key, normalized = normalizeIdentifierValue(value)

            if key and key ~= 'ip' then
                identifiers[key] = normalized
            end
        end
    end

    return identifiers
end

local function getPrimaryLicense(identifiers)
    return identifiers.license or identifiers.license2
end

local function makeSessionId(source)
    Nexa.Sessions.counter = Nexa.Sessions.counter + 1
    return ('session:%s:%s:%s'):format(source, nowMs(), Nexa.Sessions.counter)
end

local function publicSession(session)
    if not session then
        return nil
    end

    return {
        id = session.id,
        source = session.source,
        state = session.state,
        license = session.license,
        identifiers = session.identifiers,
        connectedAt = session.connectedAt,
        lastActivityAt = session.lastActivityAt,
        dropReason = session.dropReason,
        metadata = session.metadata
    }
end

local function emit(name, payload, context)
    if Nexa.EventBus then
        Nexa.EventBus.Emit(name, payload, context)
    end
end

local function isTerminal(state)
    return state == states.closed or state == states.rejected
end

local function setState(session, nextState, reason)
    if not session or not states[nextState] then
        return false, 'INVALID_STATE'
    end

    if session.state == nextState then
        return true, nil
    end

    if not allowedTransitions[session.state] or not allowedTransitions[session.state][nextState] then
        sessionLog('Warn', 'sessions.state', 'Ungueltiger Session-Zustandswechsel blockiert.', {
            sessionId = session.id,
            source = session.source,
            from = session.state,
            to = nextState,
            reason = reason
        })
        return false, 'INVALID_STATE_TRANSITION'
    end

    local previous = session.state
    session.state = nextState
    session.lastActivityAt = now()

    sessionLog('Info', 'sessions.state', 'Session-Zustand gewechselt.', {
        sessionId = session.id,
        source = session.source,
        from = previous,
        to = nextState,
        reason = reason
    })

    return true, nil
end

local function detachSession(session)
    if not session then
        return
    end

    if Nexa.Sessions.bySource[session.source] == session then
        Nexa.Sessions.bySource[session.source] = nil
    end

    if session.license and Nexa.Sessions.byLicense[session.license] == session then
        Nexa.Sessions.byLicense[session.license] = nil
    end
end

function Nexa.Sessions.Create(source, identifiers)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil, 'INVALID_SOURCE'
    end

    local normalizedIdentifiers = collectIdentifiers(source, identifiers)
    local license = getPrimaryLicense(normalizedIdentifiers)
    local sessionId = makeSessionId(source)

    local session = {
        id = sessionId,
        source = source,
        state = states.connecting,
        license = license,
        identifiers = {
            license = normalizedIdentifiers.license,
            license2 = normalizedIdentifiers.license2,
            discord = normalizedIdentifiers.discord,
            fivem = normalizedIdentifiers.fivem,
            steam = normalizedIdentifiers.steam
        },
        connectedAt = now(),
        lastActivityAt = now(),
        heartbeatAt = now(),
        dropReason = nil,
        metadata = {
            ipMasked = GetPlayerEndpoint and maskIp(GetPlayerEndpoint(source)) or nil,
            name = GetPlayerName and GetPlayerName(source) or nil
        }
    }

    Nexa.Sessions.byId[session.id] = session

    if not license then
        session.dropReason = 'MISSING_LICENSE'
        setState(session, states.rejected, 'missing_license')
        sessionLog('Warn', 'sessions.create', 'Session ohne Pflicht-Identifier abgelehnt.', {
            sessionId = session.id,
            source = source
        })
        return nil, 'MISSING_LICENSE'
    end

    local existingBySource = Nexa.Sessions.bySource[source]

    if existingBySource and not isTerminal(existingBySource.state) then
        Nexa.Sessions.Close(source, 'source_reused')
    end

    local existingByLicense = Nexa.Sessions.byLicense[license]

    if existingByLicense and existingByLicense.source ~= source and not isTerminal(existingByLicense.state) then
        if Nexa.Players and Nexa.Players.bySource and Nexa.Players.bySource[existingByLicense.source] then
            pcall(Nexa.Players.Drop, existingByLicense.source, 'reconnect')
        else
            Nexa.Sessions.Close(existingByLicense.source, 'reconnect')
        end
    end

    Nexa.Sessions.bySource[source] = session
    Nexa.Sessions.byLicense[license] = session

    setState(session, states.authenticated, 'license_present')
    setState(session, states.active, 'session_active')

    sessionLog('Info', 'sessions.create', 'Player-Session erstellt.', {
        sessionId = session.id,
        source = source,
        license = maskIdentifier(license),
        identifiers = maskedIdentifiers(session.identifiers),
        metadata = session.metadata
    })

    emit(Nexa.Constants.internalEvents.sessionCreated, {
        session = publicSession(session)
    }, {
        module = 'sessions',
        source = source
    })

    return session, nil
end

function Nexa.Sessions.GetBySource(source)
    return Nexa.Sessions.bySource[tonumber(source)]
end

function Nexa.Sessions.GetById(sessionId)
    return Nexa.Sessions.byId[sessionId]
end

function Nexa.Sessions.GetByLicense(license)
    if type(license) ~= 'string' then
        return nil
    end

    local key, normalized = normalizeIdentifierValue(license:find(':', 1, true) and license or ('license:' .. license))

    if key ~= 'license' and key ~= 'license2' then
        return nil
    end

    return Nexa.Sessions.byLicense[normalized]
end

function Nexa.Sessions.SetState(sessionId, state)
    return setState(Nexa.Sessions.byId[sessionId], state, 'manual')
end

function Nexa.Sessions.Touch(sessionId)
    local session = Nexa.Sessions.byId[sessionId]

    if not session or isTerminal(session.state) then
        return false, 'SESSION_NOT_ACTIVE'
    end

    session.lastActivityAt = now()
    session.heartbeatAt = now()
    return true, nil
end

function Nexa.Sessions.Close(source, reason)
    source = tonumber(source)
    local session = Nexa.Sessions.bySource[source]

    if not session then
        return false, 'SESSION_NOT_FOUND'
    end

    if isTerminal(session.state) then
        detachSession(session)
        return true, nil
    end

    session.dropReason = reason or 'closed'
    setState(session, states.dropping, reason)
    setState(session, states.closed, reason)
    detachSession(session)

    sessionLog('Info', 'sessions.close', 'Player-Session geschlossen.', {
        sessionId = session.id,
        source = source,
        reason = session.dropReason
    })

    emit(Nexa.Constants.internalEvents.sessionRemoved, {
        session = publicSession(session),
        reason = session.dropReason
    }, {
        module = 'sessions',
        source = source
    })

    return true, nil
end

function Nexa.Sessions.IsActive(source)
    local session = Nexa.Sessions.GetBySource(source)
    return session ~= nil and session.state == states.active
end

function Nexa.Sessions.GetCount()
    local count = 0

    for _, session in pairs(Nexa.Sessions.bySource) do
        if session.state == states.active then
            count = count + 1
        end
    end

    return count
end

function Nexa.Sessions.Cleanup()
    for sessionId, session in pairs(Nexa.Sessions.byId) do
        if isTerminal(session.state) then
            Nexa.Sessions.byId[sessionId] = nil
        end
    end

    return true, nil
end

function Nexa.Sessions.GetStates()
    return states
end
