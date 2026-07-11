local EVENTS = NexaIdentityEvents
local nuiOpen = false
local selectedCharacter = nil

local function setUiOpen(open, payload)
    nuiOpen = open == true
    SetNuiFocus(nuiOpen, nuiOpen)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        type = nuiOpen and 'open' or 'close',
        payload = payload
    })
end

local function requestFlow()
    print('[nexa-identity] requesting identity flow')
    TriggerServerEvent(EVENTS.server.requestFlow)
end

local function startFlowWhenReady()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    Wait(NexaIdentityConfig.requestDelayMs)
    requestFlow()
end

RegisterNetEvent(EVENTS.client.open, function(payload)
    print(('[nexa-identity] opening identity UI: %s'):format(json.encode(payload or {})))
    DoScreenFadeOut(250)
    setUiOpen(true, payload or {})
end)

RegisterNetEvent(EVENTS.client.close, function()
    print('[nexa-identity] closing identity UI')
    setUiOpen(false)
end)

RegisterNetEvent(EVENTS.client.error, function(payload)
    print(('[nexa-identity] identity error: %s'):format(json.encode(payload or {})))
    SendNUIMessage({
        type = 'error',
        payload = payload or {
            code = 'INTERNAL_ERROR',
            message = 'Action failed.'
        }
    })
end)

RegisterNetEvent(EVENTS.client.selected, function(character)
    print(('[nexa-identity] character selected: %s'):format(json.encode(character or {})))
    selectedCharacter = character
    setUiOpen(false)
end)

RegisterNUICallback('nexa_identity:createCharacter', function(data, cb)
    print(('[nexa-identity] NUI createCharacter request: %s'):format(json.encode({
        firstNameLength = type(data) == 'table' and type(data.firstName) == 'string' and #data.firstName or nil,
        lastNameLength = type(data) == 'table' and type(data.lastName) == 'string' and #data.lastName or nil,
        birthdate = type(data) == 'table' and data.birthdate or nil,
        gender = type(data) == 'table' and data.gender or nil
    })))
    TriggerServerEvent(EVENTS.server.createCharacter, data or {})
    cb({
        ok = true,
        status = 'sent'
    })
end)

RegisterNUICallback('nexa_identity:selectCharacter', function(data, cb)
    local characterId = data and tonumber(data.id)

    if not characterId then
        print('[nexa-identity] NUI selectCharacter failed: invalid id')
        SendNUIMessage({
            type = 'error',
            payload = {
                code = 'INVALID_INPUT',
                message = 'Select a valid character.'
            }
        })
        cb({
            ok = false
        })
        return
    end

    print(('[nexa-identity] NUI selectCharacter request: %s'):format(characterId))
    TriggerServerEvent(EVENTS.server.selectCharacter, characterId)
    cb({
        ok = true,
        status = 'sent'
    })
end)

RegisterNUICallback('nexa_identity:close', function(_, cb)
    if NexaIdentityConfig.devMode then
        setUiOpen(false)
    end

    cb({
        ok = NexaIdentityConfig.devMode
    })
end)

CreateThread(startFlowWhenReady)
