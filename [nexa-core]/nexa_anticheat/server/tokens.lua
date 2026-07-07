local tokens = {}

local function buildToken(source, eventName)
    return ('ac:%s:%s:%s:%s'):format(tostring(source), eventName, tostring(os.time()), tostring(math.random(100000, 999999)))
end

local function purgeExpiredTokens(now)
    for token, entry in pairs(tokens) do
        if now >= entry.expiresAt then
            tokens[token] = nil
        end
    end
end

function NexaAnticheatIssueToken(source, eventName, metadata)
    local sourceValid, sourceCode, normalizedSource = NexaAnticheatValidateSource(source)

    if not sourceValid then
        return false, sourceCode
    end

    local eventValid, eventCode, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return false, eventCode
    end

    local token = buildToken(normalizedSource, normalizedEventName)
    local now = os.time()

    purgeExpiredTokens(now)

    tokens[token] = {
        source = normalizedSource,
        eventName = normalizedEventName,
        metadata = metadata or {},
        createdAt = now,
        expiresAt = now + NexaAnticheatServer.tokenTtlSeconds
    }

    return true, 'OK', {
        token = token,
        expiresAt = tokens[token].expiresAt
    }
end

function NexaAnticheatValidateToken(source, eventName, token, consume)
    if type(token) ~= 'string' or token == '' then
        return false, 'TOKEN_REQUIRED'
    end

    local sourceValid, sourceCode, normalizedSource = NexaAnticheatValidateSource(source)

    if not sourceValid then
        return false, sourceCode
    end

    local eventValid, eventCode, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return false, eventCode
    end

    local entry = tokens[token]

    if entry == nil then
        return false, 'INVALID_TOKEN'
    end

    if os.time() >= entry.expiresAt then
        tokens[token] = nil
        return false, 'TOKEN_EXPIRED'
    end

    if entry.source ~= normalizedSource or entry.eventName ~= normalizedEventName then
        return false, 'TOKEN_SCOPE_MISMATCH'
    end

    if consume == true then
        tokens[token] = nil
    end

    return true, 'OK', entry
end

function NexaAnticheatClearTokensForSource(source)
    local sourceNumber = tonumber(source)

    if sourceNumber == nil then
        return
    end

    for token, entry in pairs(tokens) do
        if entry.source == sourceNumber then
            tokens[token] = nil
        end
    end
end
