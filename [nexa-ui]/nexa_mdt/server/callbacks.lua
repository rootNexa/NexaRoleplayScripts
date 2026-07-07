local function checkRequest(source, callbackName)
    if GetResourceState('nexa_security') ~= 'started' then
        return true
    end

    if not exports.nexa_security:validateSource(source) then
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

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

local function hasFactionPermission(source, permission)
    if type(permission) ~= 'string' or permission == '' then
        return false
    end

    if GetResourceState('nexa_api') ~= 'started' then
        return false
    end

    local ok, result = pcall(function()
        return exports.nexa_api['faction.hasPermission'](source, {
            factionName = 'lspd',
            permission = permission
        })
    end)

    return ok and type(result) == 'table' and result.success == true
end

local function canViewMdt(source)
    return hasPermission(source, NexaMdtServerConfig.permissions.view)
        or hasFactionPermission(source, NexaMdtServerConfig.permissions.view)
end

local function auditAccess(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'mdt',
            severity = 'info',
            action = action,
            resourceName = 'nexa_mdt',
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info('nexa_mdt', 'MDT-Aktenzugriff wurde protokolliert.', metadata or {
            source = source
        })
    end
end

local function getDispatchCalls(source)
    if not hasPermission(source, NexaMdtServerConfig.permissions.dispatch)
        and not hasFactionPermission(source, NexaMdtServerConfig.permissions.dispatch) then
        return {}
    end

    if GetResourceState('nexa_api') ~= 'started' then
        return {}
    end

    local ok, result = pcall(function()
        return exports.nexa_api['dispatch.listCalls'](source, {
            limit = NexaMdtServerConfig.limits.maxDispatch
        })
    end)

    if not ok or type(result) ~= 'table' or result.success ~= true then
        return {}
    end

    return result.data and result.data.calls or {}
end

local function buildSnapshot(source)
    local snapshot = NexaMdtGetLocalSnapshot()
    snapshot.dispatch = getDispatchCalls(source)
    return snapshot
end

lib.callback.register(NexaMdtConfig.snapshotCallback, function(source)
    if not checkRequest(source, NexaMdtServerConfig.callbacks.snapshot) then
        return NexaMdtBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    if not canViewMdt(source) then
        return NexaMdtBuildResponse(false, 'NO_PERMISSION', 'Zugriff verweigert.', nil, nil)
    end

    auditAccess('mdt.snapshot.view', source, {
        source = source
    })

    return NexaMdtBuildResponse(true, 'OK', 'MDT-Daten wurden geladen.', buildSnapshot(source), {
        vehicleReadOnly = true,
        evidenceReadOnly = true,
        dispatchViaApi = true
    })
end)

lib.callback.register(NexaMdtConfig.personSearchCallback, function(source, payload)
    if not checkRequest(source, NexaMdtServerConfig.callbacks.personSearch) then
        return NexaMdtBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    if not canViewMdt(source)
        or (not hasPermission(source, NexaMdtServerConfig.permissions.records)
            and not hasFactionPermission(source, NexaMdtServerConfig.permissions.records)) then
        return NexaMdtBuildResponse(false, 'NO_PERMISSION', 'Zugriff verweigert.', nil, nil)
    end

    local query = type(payload) == 'table' and payload.query or ''
    local normalizedQuery = NexaMdtLimitText(query, NexaMdtServerConfig.limits.maxQueryLength)
    local persons = NexaMdtSearchPersons(normalizedQuery)

    auditAccess('mdt.person.search', source, {
        source = source,
        queryLength = #normalizedQuery,
        resultCount = #persons
    })

    return NexaMdtBuildResponse(true, 'OK', 'Personenabfrage wurde ausgefuehrt.', {
        persons = persons
    }, nil)
end)
