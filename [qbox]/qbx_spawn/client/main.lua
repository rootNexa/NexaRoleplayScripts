local config = require 'config.client'
local spawns
local previewCam
local scaleform
local buttonsScaleform
local currentButtonId = 1
local previousButtonId = 1
local identitySpawnCompletedAt = nil

local function getRenderingCamState()
    local success, renderingCam = pcall(function()
        return GetRenderingCam()
    end)

    return success and renderingCam or 'unavailable'
end

local function traceVisual(functionName, metadata)
    local payload = metadata or {}
    payload.resource = GetCurrentResourceName()
    payload.event = functionName
    payload.gameTimer = GetGameTimer()
    payload.identitySpawnMarker = identitySpawnCompletedAt and 'after' or 'before_or_unknown'
    payload.identitySpawnCompletedAt = identitySpawnCompletedAt
    payload.screenFadedIn = IsScreenFadedIn()
    payload.screenFadedOut = IsScreenFadedOut()
    payload.screenFadingIn = IsScreenFadingIn()
    payload.screenFadingOut = IsScreenFadingOut()
    payload.renderingCam = getRenderingCamState()

    print(('[nexa_black_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceVisual('nexa:identity:client:spawnPreparedCompleted observed')
end)

local function beginScaleformMovieMethod(handle, method, functionName, metadata)
    local payload = metadata or {}
    payload.method = method
    traceVisual(functionName, payload)
    BeginScaleformMovieMethod(handle, method)
end

local function setupCamera()
    traceVisual('setupCamera CreateCamWithParams', {
        cameraType = 'DEFAULT_SCRIPTED_CAMERA'
    })
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', -24.77, -590.35, 90.8, -2.0, 0.0, 160.0, 45.0, false, 2)
    traceVisual('setupCamera SetCamActive(true)', {
        camera = previewCam
    })
    SetCamActive(previewCam, true)
    traceVisual('setupCamera RenderScriptCams(true)')
    RenderScriptCams(true, false, 1, true, true)
end

local function stopCamera()
    traceVisual('stopCamera SetCamActive(false)', {
        camera = previewCam
    })
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, true)
    traceVisual('stopCamera RenderScriptCams(false)')
    RenderScriptCams(false, false, 1, true, true)

    beginScaleformMovieMethod(scaleform, 'CLEANUP', 'stopCamera BeginScaleformMovieMethod')
    EndScaleformMovieMethod()
end

local function managePlayer()
    SetEntityCoords(cache.ped, -21.58, -583.76, 86.31, false, false, false, false)
    FreezeEntityPosition(cache.ped, true)
    DisplayRadar(false)

    SetTimeout(500, function()
        DoScreenFadeIn(5000)
    end)
end

local function createSpawnArea()
    for i = 1, #spawns, 1 do
        local spawn = spawns[i]
        beginScaleformMovieMethod(scaleform, 'ADD_AREA', 'createSpawnArea BeginScaleformMovieMethod', {
            index = i
        })
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamFloat(spawn.coords.x)
        ScaleformMovieMethodAddParamFloat(spawn.coords.y)
        ScaleformMovieMethodAddParamFloat(500.0)
        ScaleformMovieMethodAddParamInt(255)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(100)
        EndScaleformMovieMethod()
    end
end

local function setupInstructionalButton(index, control, text)
    beginScaleformMovieMethod(buttonsScaleform, 'SET_DATA_SLOT', 'setupInstructionalButton BeginScaleformMovieMethod', {
        index = index,
        control = control,
        text = text
    })

    ScaleformMovieMethodAddParamInt(index)

    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, control, true))

    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()

    EndScaleformMovieMethod()
end

local function setupInstructionalScaleform()
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 0, 0)

    beginScaleformMovieMethod(buttonsScaleform, 'CLEAR_ALL', 'setupInstructionalScaleform BeginScaleformMovieMethod')
    EndScaleformMovieMethod()

    beginScaleformMovieMethod(buttonsScaleform, 'SET_CLEAR_SPACE', 'setupInstructionalScaleform BeginScaleformMovieMethod')
    ScaleformMovieMethodAddParamInt(200)
    EndScaleformMovieMethod()

    setupInstructionalButton(0, 191, 'Submit')
    setupInstructionalButton(1, 187, 'Down')
    setupInstructionalButton(2, 188, 'Up')

    beginScaleformMovieMethod(buttonsScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS', 'setupInstructionalScaleform BeginScaleformMovieMethod')
    EndScaleformMovieMethod()
end

local function setupMap()
    scaleform = lib.requestScaleformMovie('HEISTMAP_MP', 5000) or 0
    buttonsScaleform = lib.requestScaleformMovie('INSTRUCTIONAL_BUTTONS', 5000) or 0
    CreateThread(function()
        setupInstructionalScaleform()
        createSpawnArea()
        while DoesCamExist(previewCam) do
            DrawScaleformMovie_3d(scaleform, -24.86, -593.38, 91.8, -180.0, -180.0, -20.0, 0.0, 2.0, 0.0, 3.815, 2.27, 1.0, 2)

            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(9)

            DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
        SetScaleformMovieAsNoLongerNeeded(buttonsScaleform)
    end)
end

local function scaleformDetails(index)
    local spawn = spawns[index]
    local arrowStart = {
        vec2(-3150.25, -1427.83),
        vec2(4173.08, 1338.72),
        vec2(-2390.23, 6262.24)
    }

    beginScaleformMovieMethod(scaleform, 'ADD_HIGHLIGHT', 'scaleformDetails BeginScaleformMovieMethod', {
        index = index
    })
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(500.0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()

    beginScaleformMovieMethod(scaleform, 'COLOUR_AREA', 'scaleformDetails BeginScaleformMovieMethod', {
        index = index
    })
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()

    beginScaleformMovieMethod(scaleform, 'ADD_TEXT', 'scaleformDetails BeginScaleformMovieMethod', {
        index = index
    })
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamTextureNameString(spawn.label)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y - 500)
    ScaleformMovieMethodAddParamFloat(25 - math.random(0, 50))
    ScaleformMovieMethodAddParamInt(24)
    ScaleformMovieMethodAddParamInt(100)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamBool(true)
    EndScaleformMovieMethod()

    local randomCoords = arrowStart[math.random(#arrowStart)]

    beginScaleformMovieMethod(scaleform, 'ADD_ARROW', 'scaleformDetails BeginScaleformMovieMethod', {
        index = index
    })
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamFloat(randomCoords.x)
    ScaleformMovieMethodAddParamFloat(randomCoords.y)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(math.random(30, 80))
    EndScaleformMovieMethod()

    beginScaleformMovieMethod(scaleform, 'COLOUR_ARROW', 'scaleformDetails BeginScaleformMovieMethod', {
        index = index
    })
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()
end

local function updateScaleform()
    if previousButtonId == currentButtonId then return end

    for i = 1, #spawns, 1 do
        beginScaleformMovieMethod(scaleform, 'REMOVE_HIGHLIGHT', 'updateScaleform BeginScaleformMovieMethod', {
            index = i
        })
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        beginScaleformMovieMethod(scaleform, 'REMOVE_TEXT', 'updateScaleform BeginScaleformMovieMethod', {
            index = i
        })
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        beginScaleformMovieMethod(scaleform, 'REMOVE_ARROW', 'updateScaleform BeginScaleformMovieMethod', {
            index = i
        })
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        beginScaleformMovieMethod(scaleform, 'COLOUR_AREA', 'updateScaleform BeginScaleformMovieMethod', {
            index = i
        })
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamInt(255)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(100)
        EndScaleformMovieMethod()
    end

    scaleformDetails(currentButtonId)
end

local function inputHandler()
    while DoesCamExist(previewCam) do
        if IsControlJustReleased(0, 188) then
            previousButtonId = currentButtonId
            currentButtonId -= 1

            if currentButtonId < 1 then
                currentButtonId = #spawns
            end

            updateScaleform()
        elseif IsControlJustReleased(0, 187) then
            previousButtonId = currentButtonId
            currentButtonId += 1

            if currentButtonId > #spawns then
                currentButtonId = 1
            end

            updateScaleform()
        elseif IsControlJustReleased(0, 191) then
            DoScreenFadeOut(1000)

            while not IsScreenFadedOut() do
                Wait(0)
            end

            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            FreezeEntityPosition(cache.ped, false)
            DisplayRadar(true)

            local spawnData = spawns[currentButtonId]

            if spawnData.propertyId then
                TriggerServerEvent('qbx_properties:server:enterProperty', { id = spawnData.propertyId, isSpawn = true })
            else
                SetEntityCoords(cache.ped, spawnData.coords.x, spawnData.coords.y, spawnData.coords.z, false, false, false, false)
                SetEntityHeading(cache.ped, spawnData.coords.w or 0.0)
            end

            DoScreenFadeIn(1000)

            break
        end

        Wait(0)
    end

    stopCamera()
end

RegisterNetEvent('qb-spawn:client:setupSpawns', function()
    spawns = {}

    local lastCoords, lastPropertyId = lib.callback.await('qbx_spawn:server:getLastLocation')
    spawns[#spawns + 1] = {
        label = locale('last_location'),
        coords = lastCoords,
        propertyId = lastPropertyId
    }

    for i = 1, #config.spawns do
        spawns[#spawns + 1] = config.spawns[i]
    end

    local properties = lib.callback.await('qbx_spawn:server:getProperties')
    for i = 1, #properties do
        spawns[#spawns + 1] = properties[i]
    end

    Wait(400)

    managePlayer()
    setupCamera()
    setupMap()

    Wait(400)

    scaleformDetails(currentButtonId)
    inputHandler()
end)
