local function checkRequest(source)
    if GetResourceState('nexa_security') ~= 'started' then
        return true
    end

    if not exports.nexa_security:validateSource(source) then
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, NexaTabletServerConfig.callbackRateLimit)

    return rateLimit ~= nil and rateLimit.success == true
end

local function hasPermission(source, permission)
    if type(permission) ~= 'string' or permission == '' then
        return false
    end

    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local ok, result = pcall(function()
        return exports.nexa_permissions:has(source, permission)
    end)

    return ok and type(result) == 'table' and result.success == true
end

local function getVisibleApps(source)
    local apps = {}

    for _, app in ipairs(NexaTabletServerConfig.placeholderApps) do
        if hasPermission(source, app.permission) then
            local entry = NexaTabletCopyTable(app)
            entry.permission = nil
            apps[#apps + 1] = entry
        end
    end

    return apps
end

lib.callback.register(NexaTabletConfig.appsCallback, function(source)
    if not checkRequest(source) then
        return NexaTabletBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    return NexaTabletBuildResponse(true, 'OK', 'Tablet-Eintraege wurden geladen.', {
        apps = getVisibleApps(source)
    }, {
        shellOnly = true
    })
end)
