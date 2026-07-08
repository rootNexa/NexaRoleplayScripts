NexaCharacterClient = {
    characters = {},
    activeCharacter = nil,
    lastError = nil
}

local EVENTS = NEXA_CHARACTER_CONSTANTS.events

local function applyResponse(payload, onSuccess)
    if type(payload) ~= 'table' then
        NexaCharacterClient.lastError = {
            code = 'INVALID_RESPONSE',
            message = 'Invalid character response.'
        }
        return
    end

    if payload.success ~= true then
        NexaCharacterClient.lastError = {
            code = payload.code,
            message = payload.message
        }
        return
    end

    NexaCharacterClient.lastError = nil

    if onSuccess then
        onSuccess(payload.data)
    end
end

RegisterNetEvent(EVENTS.client.charactersLoaded, function(payload)
    applyResponse(payload, function(data)
        if type(data) == 'table' and data.character then
            NexaCharacterClient.characters[#NexaCharacterClient.characters + 1] = data.character
            return
        end

        NexaCharacterClient.characters = type(data) == 'table' and data or {}
    end)
end)

RegisterNetEvent(EVENTS.client.characterSelected, function(payload)
    applyResponse(payload, function(character)
        NexaCharacterClient.activeCharacter = character
    end)
end)

RegisterNetEvent(EVENTS.client.characterUpdated, function(payload)
    applyResponse(payload, function(character)
        NexaCharacterClient.activeCharacter = character
    end)
end)
