local sessions = {}

local function upsertSession(source)
    local sourceNumber = tonumber(source)

    if sourceNumber == nil or sourceNumber <= 0 then
        return
    end

    sessions[sourceNumber] = {
        source = sourceNumber,
        name = GetPlayerName(sourceNumber),
        endpointPresent = GetPlayerEndpoint(sourceNumber) ~= nil,
        startedAt = sessions[sourceNumber] and sessions[sourceNumber].startedAt or os.date('!%Y-%m-%dT%H:%M:%SZ'),
        lastSeenAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
end

function NexaAnticheatValidateSession(source)
    local sourceValid, sourceCode, normalizedSource = NexaAnticheatValidateSource(source)

    if not sourceValid then
        return false, sourceCode
    end

    if GetPlayerName(normalizedSource) == nil then
        return false, 'SESSION_NOT_FOUND'
    end

    upsertSession(normalizedSource)

    return true, 'OK', sessions[normalizedSource]
end

AddEventHandler('playerDropped', function()
    local droppedSource = source

    NexaAnticheatClearTokensForSource(droppedSource)
    sessions[tonumber(droppedSource)] = nil
end)
