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
    DoScreenFadeOut(250)
    setUiOpen(true, payload or {})
end)

RegisterNetEvent(EVENTS.client.close, function()
    setUiOpen(false)
end)

RegisterNetEvent(EVENTS.client.error, function(payload)
    SendNUIMessage({
        type = 'error',
        payload = payload or {
            message = 'Action failed.'
        }
    })
end)

RegisterNetEvent(EVENTS.client.selected, function(character)
    selectedCharacter = character
    setUiOpen(false)
    TriggerEvent('nexa-spawn:client:requestSpawn')
end)

RegisterNUICallback('nexa_identity:createCharacter', function(data, cb)
    TriggerServerEvent(EVENTS.server.createCharacter, data or {})
    cb({
        ok = true
    })
end)

RegisterNUICallback('nexa_identity:selectCharacter', function(data, cb)
    local characterId = data and tonumber(data.id)

    if not characterId then
        SendNUIMessage({
            type = 'error',
            payload = {
                message = 'Select a valid character.'
            }
        })
        cb({
            ok = false
        })
        return
    end

    TriggerServerEvent(EVENTS.server.selectCharacter, characterId)
    cb({
        ok = true
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
