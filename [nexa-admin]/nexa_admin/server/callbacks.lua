local function rejectRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:admin:cb:getMenu', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:getMenu')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.getMenu'](source)
end)

lib.callback.register('nexa:admin:cb:listPlayers', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listPlayers')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.listPlayers'](source)
end)

lib.callback.register('nexa:admin:cb:validateAction', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:validateAction')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.validateAction'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:createReport', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:createReport')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.create'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:listOwnReports', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listOwnReports')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.listOwn'](source)
end)

lib.callback.register('nexa:admin:cb:listReports', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listReports')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.list'](source)
end)

lib.callback.register('nexa:admin:cb:getReportHistory', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:getReportHistory')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.history'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:acceptReport', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:acceptReport')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.accept'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:closeReport', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:closeReport')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.reports.close'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:createTicket', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:createTicket')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.tickets.create'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:listTickets', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listTickets')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.tickets.list'](source)
end)

lib.callback.register('nexa:admin:cb:assignTicket', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:assignTicket')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.tickets.assign'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:closeTicket', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:closeTicket')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.tickets.close'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:listModerationActions', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listModerationActions')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.list'](source)
end)

lib.callback.register('nexa:admin:cb:warnPlayer', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:warnPlayer')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.warn'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:kickPlayer', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:kickPlayer')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.kick'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:prepareTempban', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:prepareTempban')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.tempban.prepare'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:setPlayerFrozen', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:setPlayerFrozen')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.freeze'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:prepareSpectate', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:prepareSpectate')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.spectate.prepare'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:addAdminNote', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:addAdminNote')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.notes.add'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:listAdminNotes', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listAdminNotes')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.moderation.notes.list'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:listUtilityActions', function(source)
    local rejected = rejectRequest(source, 'nexa:admin:cb:listUtilityActions')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.list'](source)
end)

lib.callback.register('nexa:admin:cb:bringPlayer', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:bringPlayer')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.bring'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:gotoPlayer', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:gotoPlayer')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.goto'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:returnPlayer', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:returnPlayer')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.return'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:teleportToCoords', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:teleportToCoords')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.coords'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:prepareAdminHeal', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:prepareAdminHeal')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.heal.prepare'](source, payload or {})
end)

lib.callback.register('nexa:admin:cb:prepareAdminRevive', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:admin:cb:prepareAdminRevive')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_admin['admin.utility.revive.prepare'](source, payload or {})
end)
