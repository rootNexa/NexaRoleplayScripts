local hudVisible = NexaHudClientConfig.enabledByDefault
local identitySpawnCompletedAt = nil
local voiceState = {
    mode = 'Normal',
    talking = false,
    radio = false,
    radioLabel = NexaHudLocale.radioUnavailable
}

local function traceAfterIdentitySpawn(eventName, metadata)
    if identitySpawnCompletedAt == nil then
        return
    end

    local payload = metadata or {}
    payload.resource = GetCurrentResourceName()
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
    payload.afterIdentitySpawnCompletedAt = identitySpawnCompletedAt
    payload.hudVisible = hudVisible

    print(('[nexa_post_spawn_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceAfterIdentitySpawn('nexa:identity:client:spawnPreparedCompleted observed')
end)

local function sendHudMessage(messageType, payload)
    if messageType == NEXA_HUD_MESSAGES.init or messageType == NEXA_HUD_MESSAGES.visibility then
        traceAfterIdentitySpawn(('SendNUIMessage:%s'):format(messageType), {
            fullscreenNui = false
        })
    end

    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function debugLog(message, metadata)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    print(('[nexa_hud] %s %s'):format(message, metadata and json.encode(metadata) or ''))
end

local function getDesignPayload()
    local theme = {}
    local locale = {}

    if GetResourceState(NexaHudConfig.designSystemResource) == 'started' then
        theme = exports.nexa_ui:getTheme() or {}
        locale = exports.nexa_ui:getLocale() or {}
    end

    return {
        theme = theme,
        uiLocale = locale,
        hudLocale = NexaHudLocale
    }
end

local function setVisible(visible)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.setVisible or 'nexa_hud:setVisible', {
        requestedVisible = visible == true,
        fullscreenNui = false
    })

    hudVisible = visible == true
    sendHudMessage(NEXA_HUD_MESSAGES.visibility, {
        visible = hudVisible
    })
end

local function updateStatus(payload)
    if type(payload) ~= 'table' then
        return
    end

    sendHudMessage(NEXA_HUD_MESSAGES.status, {
        health = NexaHudPercent(payload.health),
        armor = NexaHudPercent(payload.armor),
        hunger = NexaHudPercent(payload.hunger),
        thirst = NexaHudPercent(payload.thirst),
        stress = NexaHudPercent(payload.stress)
    })
end

local function updateVoice(payload)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.updateVoice or 'nexa_hud:updateVoice', {
        source = 'event/export',
        fullscreenNui = false
    })

    if type(payload) ~= 'table' then
        return
    end

    voiceState.mode = payload.mode or voiceState.mode
    voiceState.talking = payload.talking == true
    sendHudMessage(NEXA_HUD_MESSAGES.voice, voiceState)
end

local function updateRadio(payload)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.updateRadio or 'nexa_hud:updateRadio', {
        source = 'event/export',
        fullscreenNui = false
    })

    if type(payload) ~= 'table' then
        return
    end

    voiceState.radio = payload.active == true
    voiceState.radioLabel = payload.label or NexaHudLocale.radioUnavailable
    sendHudMessage(NEXA_HUD_MESSAGES.voice, voiceState)
end

local function getLocalStatus()
    local playerPed = PlayerPedId()
    local health = math.max(GetEntityHealth(playerPed) - 100, 0)
    local maxHealth = math.max(GetEntityMaxHealth(playerPed) - 100, 1)

    return {
        health = (health / maxHealth) * 100,
        armor = GetPedArmour(playerPed),
        hunger = 0,
        thirst = 0,
        stress = 0
    }
end

local function getVehicleDisplay()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        return {
            inVehicle = false
        }
    end

    return {
        inVehicle = true,
        speed = math.floor(GetEntitySpeed(vehicle) * 3.6),
        engine = GetIsVehicleEngineRunning(vehicle),
        fuel = nil
    }
end

local function refreshSnapshot()
    local snapshot = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(NexaHudConfig.snapshotCallback, {}, function(response)
        snapshot:resolve(response)
    end, NexaHudClientConfig.snapshotTimeoutMs)

    if type(request) == 'table' and request.ok == false then
        return
    end

    local response = Citizen.Await(snapshot)

    if type(response) ~= 'table' or response.ok ~= true then
        return
    end

    sendHudMessage(NEXA_HUD_MESSAGES.snapshot, response.data or {})
end

CreateThread(function()
    traceAfterIdentitySpawn('nexa_hud:init thread start', {
        fullscreenNui = false
    })

    sendHudMessage(NEXA_HUD_MESSAGES.init, getDesignPayload())
    setVisible(hudVisible)
    refreshSnapshot()
    debugLog('14 HUD initialisiert', {
        visible = hudVisible
    })

    while true do
        Wait(NexaHudClientConfig.snapshotRefreshMs)
        refreshSnapshot()
    end
end)

CreateThread(function()
    while true do
        Wait(NexaHudClientConfig.localUpdateMs)
        updateStatus(getLocalStatus())
    end
end)

CreateThread(function()
    while true do
        Wait(NexaHudClientConfig.vehicleUpdateMs)
        sendHudMessage(NEXA_HUD_MESSAGES.vehicle, getVehicleDisplay())
    end
end)

RegisterNetEvent(NEXA_HUD_EVENTS.updateStatus, function(payload)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.updateStatus, {
        source = 'event',
        fullscreenNui = false
    })
    updateStatus(payload)
end)

RegisterNetEvent(NEXA_HUD_EVENTS.setVisible, function(visible)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.setVisible, {
        source = 'event',
        requestedVisible = visible == true,
        fullscreenNui = false
    })
    setVisible(visible)
end)

RegisterNetEvent(NEXA_HUD_EVENTS.updateVoice, function(payload)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.updateVoice, {
        source = 'event',
        fullscreenNui = false
    })
    updateVoice(payload)
end)

RegisterNetEvent(NEXA_HUD_EVENTS.updateRadio, function(payload)
    traceAfterIdentitySpawn(NEXA_HUD_EVENTS.updateRadio, {
        source = 'event',
        fullscreenNui = false
    })
    updateRadio(payload)
end)

exports('setVisible', setVisible)
exports('isVisible', function()
    return hudVisible
end)
exports('refresh', refreshSnapshot)
