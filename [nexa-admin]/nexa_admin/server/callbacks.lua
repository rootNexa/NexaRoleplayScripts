local function registerCallback(name, handler)
    if not NexaAdminServer.callbacksEnabled then
        return
    end

    if GetResourceState('nexa_api') ~= 'started' then
        return
    end

    exports.nexa_api:RegisterServerCallback(name, function(source, payload)
        return handler(source, payload or {})
    end, {
        resource = NEXA_ADMIN.resourceName
    })
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    registerCallback('nexa:admin:cb:listActions', function(source)
        return ListActions()
    end)

    registerCallback('nexa:admin:cb:warnPlayer', function(source, payload)
        return WarnPlayer(source, payload.targetSource, payload.reason)
    end)

    registerCallback('nexa:admin:cb:kickPlayer', function(source, payload)
        return KickPlayer(source, payload.targetSource, payload.reason)
    end)

    registerCallback('nexa:admin:cb:tempBanPlayer', function(source, payload)
        return BanPlayer(source, payload.targetSource or payload.accountId, payload.reason, payload.durationMinutes)
    end)

    registerCallback('nexa:admin:cb:banPlayer', function(source, payload)
        return BanPlayer(source, payload.targetSource or payload.accountId, payload.reason)
    end)

    registerCallback('nexa:admin:cb:unbanPlayer', function(source, payload)
        return UnbanPlayer(source, payload.banId, payload.reason)
    end)

    registerCallback('nexa:admin:cb:goToPlayer', function(source, payload)
        return GoToPlayer(source, payload.targetSource)
    end)

    registerCallback('nexa:admin:cb:bringPlayer', function(source, payload)
        return BringPlayer(source, payload.targetSource)
    end)

    registerCallback('nexa:admin:cb:returnPlayer', function(source, payload)
        return ReturnPlayer(source, payload.targetSource or source)
    end)

    registerCallback('nexa:admin:cb:setPlayerFrozen', function(source, payload)
        return SetPlayerFrozen(source, payload.targetSource, payload.state, payload.reason)
    end)

    registerCallback('nexa:admin:cb:healPlayer', function(source, payload)
        return HealPlayer(source, payload.targetSource, payload.reason)
    end)

    registerCallback('nexa:admin:cb:revivePlayer', function(source, payload)
        return RevivePlayer(source, payload.targetSource, payload.reason)
    end)

    registerCallback('nexa:admin:cb:startSpectate', function(source, payload)
        return StartSpectate(source, payload.targetSource)
    end)

    registerCallback('nexa:admin:cb:stopSpectate', function(source)
        return StopSpectate(source)
    end)

    registerCallback('nexa:admin:cb:startNoclip', function(source)
        return StartNoclip(source)
    end)

    registerCallback('nexa:admin:cb:stopNoclip', function(source)
        return StopNoclip(source)
    end)

    registerCallback('nexa:admin:cb:createAdminNote', function(source, payload)
        return CreateAdminNote(source, payload.targetSource or payload.accountId, payload)
    end)

    registerCallback('nexa:admin:cb:listAdminNotes', function(source, payload)
        return ListAdminNotes(source, payload.targetSource or payload.accountId)
    end)

    registerCallback('nexa:admin:cb:getState', function(source)
        return GetAdminActionState(source)
    end)
end)
