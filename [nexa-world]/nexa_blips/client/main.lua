local activeBlips = {}

local function clearBlips()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    activeBlips = {}
end

local function createBlip(entry)
    local blip = AddBlipForCoord(entry.coords.x, entry.coords.y, entry.coords.z)

    SetBlipSprite(blip, entry.sprite)
    SetBlipDisplay(blip, entry.display or 4)
    SetBlipScale(blip, entry.scale or 0.75)
    SetBlipColour(blip, entry.color or 0)
    SetBlipAsShortRange(blip, entry.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(entry.label)
    EndTextCommandSetBlipName(blip)

    activeBlips[entry.id] = blip
end

local function applyBlips(blips)
    clearBlips()

    for _, entry in ipairs(blips or {}) do
        if type(entry) == 'table' and type(entry.coords) == 'table' then
            createBlip(entry)
        end
    end
end

local function refreshBlips()
    local response = lib.callback.await('nexa:blips:cb:getAvailable', false)

    if type(response) == 'table' and response.success and response.data ~= nil then
        applyBlips(response.data.blips or {})
    end
end

RegisterNetEvent(NEXA_BLIPS_EVENTS.refresh, refreshBlips)

CreateThread(function()
    Wait(1500)
    refreshBlips()
end)
