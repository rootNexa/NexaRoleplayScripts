local noclipState = {
    active = false,
    speed = 1.5
}

local function notify(message, notifyType)
    if GetResourceState(NexaAdminClient.notifyResource) == 'started' then
        exports[NexaAdminClient.notifyResource]:notify({
            title = 'Nexa Admin',
            description = message,
            type = notifyType or 'inform'
        })
    end
end

RegisterNetEvent(NEXA_ADMIN.events.applyControl, function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, payload.frozen == true)
    notify(payload.frozen and 'Du wurdest eingefroren.' or 'Du wurdest freigegeben.', payload.frozen and 'warning' or 'inform')
end)

RegisterNetEvent(NEXA_ADMIN.events.applyTeleport, function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then
        return
    end

    local coords = payload.coords
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, coords.heading or 0.0)
    notify('Admin-Teleport ausgefuehrt.', 'inform')
end)

RegisterNetEvent(NEXA_ADMIN.events.applyRecovery, function(payload)
    if type(payload) ~= 'table' then
        return
    end

    local ped = PlayerPedId()

    if payload.type == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        notify('Admin-Heal ausgefuehrt.', 'inform')
        return
    end

    if payload.type == 'revive' then
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedTasksImmediately(ped)
        notify('Admin-Revive ausgefuehrt.', 'inform')
    end
end)

RegisterNetEvent(NEXA_ADMIN.events.applySpectate, function(payload)
    if type(payload) ~= 'table' then
        return
    end

    if payload.active == false then
        NetworkSetInSpectatorMode(false, PlayerPedId())
        notify('Spectate beendet.', 'inform')
        return
    end

    local target = tonumber(payload.targetSource)

    if not target then
        return
    end

    local targetPlayer = GetPlayerFromServerId(target)

    if targetPlayer == -1 then
        return
    end

    NetworkSetInSpectatorMode(true, GetPlayerPed(targetPlayer))
    notify('Spectate gestartet.', 'inform')
end)

RegisterNetEvent(NEXA_ADMIN.events.applyNoclip, function(payload)
    if type(payload) ~= 'table' then
        return
    end

    noclipState.active = payload.active == true
    noclipState.speed = tonumber(payload.speed) or noclipState.speed
    SetEntityCollision(PlayerPedId(), not noclipState.active, not noclipState.active)
    FreezeEntityPosition(PlayerPedId(), noclipState.active)
    notify(noclipState.active and 'Noclip gestartet.' or 'Noclip beendet.', 'inform')
end)

CreateThread(function()
    while true do
        if not noclipState.active then
            Wait(500)
        else
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local forward = GetEntityForwardVector(ped)
            local speed = noclipState.speed

            if IsControlPressed(0, 32) then
                coords = coords + (forward * speed)
            elseif IsControlPressed(0, 33) then
                coords = coords - (forward * speed)
            end

            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, true, true, true)
        end
    end
end)
