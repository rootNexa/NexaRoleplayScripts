local RESOURCE = GetCurrentResourceName()
local REQUEST_EVENT = 'nexa-spawn:server:requestInitialSpawn'
local APPROVED_EVENT = 'nexa-spawn:client:spawnApproved'

local spawnedSources = {}

local function log(level, message, context)
    local suffix = ''

    if context ~= nil then
        suffix = (' %s'):format(json.encode(context))
    end

    print(('[%s] [%s] %s%s'):format(RESOURCE, level, message, suffix))
end

local function normalizeSource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    return source
end

local function getDefaultSpawn()
    local spawn = NexaSpawnConfig and NexaSpawnConfig.DefaultSpawn

    return {
        x = tonumber(spawn and spawn.x) or -1037.68,
        y = tonumber(spawn and spawn.y) or -2737.88,
        z = tonumber(spawn and spawn.z) or 20.17,
        heading = tonumber(spawn and spawn.heading) or 330.0
    }
end

RegisterNetEvent(REQUEST_EVENT, function()
    local playerSource = normalizeSource(source)

    if not playerSource then
        log('warn', 'Initial spawn denied: invalid source.', {
            source = source
        })
        return
    end

    if GetPlayerName(playerSource) == nil then
        log('warn', 'Initial spawn denied: player is not active.', {
            source = playerSource
        })
        return
    end

    local spawn = getDefaultSpawn()
    spawnedSources[playerSource] = true

    log('info', 'Initial spawn approved.', {
        source = playerSource,
        spawn = spawn
    })

    TriggerClientEvent(APPROVED_EVENT, playerSource, spawn)
end)

AddEventHandler('playerDropped', function()
    local playerSource = normalizeSource(source)

    if playerSource then
        spawnedSources[playerSource] = nil
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    log('info', 'Nexa development spawn resource started.')
end)
