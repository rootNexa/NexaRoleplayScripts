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

local function getFactionNameForMdtType(mdtType)
    return NexaMdtServerConfig.mdtTypeFactionNames[NexaMdtNormalizeType(mdtType)] or NexaMdtNormalizeType(mdtType)
end

local function hasFactionPermission(source, mdtType, permission)
    if type(permission) ~= 'string' or permission == '' then
        return false
    end

    if GetResourceState('nexa_api') ~= 'started' then
        return false
    end

    local ok, result = pcall(function()
        return exports.nexa_api['faction.hasPermission'](source, {
            factionName = getFactionNameForMdtType(mdtType),
            permission = permission
        })
    end)

    return ok and type(result) == 'table' and result.success == true
end

local function canViewMdt(source, mdtType)
    return hasPermission(source, NexaMdtServerConfig.permissions.view)
        or hasFactionPermission(source, mdtType, NexaMdtServerConfig.permissions.view)
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

local function getDispatchCalls(source, mdtType)
    if not hasPermission(source, NexaMdtServerConfig.permissions.dispatch)
        and not hasFactionPermission(source, mdtType, NexaMdtServerConfig.permissions.dispatch) then
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

local function buildSnapshot(source, mdtType)
    local normalizedType = NexaMdtNormalizeType(mdtType)
    local snapshot = NexaMdtGetLocalSnapshot()
    snapshot.mdtType = normalizedType
    snapshot.modules = NexaMdtGetModulesForType(normalizedType)
    snapshot.availableTypes = NexaMdtCopyTable(MDT_TYPES)
    snapshot.dispatch = getDispatchCalls(source, normalizedType)
    return snapshot
end

exports.nexa_api:RegisterServerCallback(NexaMdtConfig.snapshotCallback, function(source, payload)
    local mdtType = NexaMdtNormalizeType(type(payload) == 'table' and payload.mdtType or nil)

    if not checkRequest(source, NexaMdtServerConfig.callbacks.snapshot) then
        return NexaMdtBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    if not canViewMdt(source, mdtType) then
        return NexaMdtBuildResponse(false, 'NO_PERMISSION', 'Zugriff verweigert.', nil, nil)
    end

    auditAccess('mdt.snapshot.view', source, {
        source = source
    })

    return NexaMdtBuildResponse(true, 'OK', 'MDT-Daten wurden geladen.', buildSnapshot(source, mdtType), {
        mdtType = mdtType,
        vehicleReadOnly = true,
        evidenceReadOnly = true,
        dispatchViaApi = true
    })
end)

exports.nexa_api:RegisterServerCallback(NexaMdtConfig.personSearchCallback, function(source, payload)
    local mdtType = NexaMdtNormalizeType(type(payload) == 'table' and payload.mdtType or nil)

    if not checkRequest(source, NexaMdtServerConfig.callbacks.personSearch) then
        return NexaMdtBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    if not canViewMdt(source, mdtType)
        or (not hasPermission(source, NexaMdtServerConfig.permissions.records)
            and not hasFactionPermission(source, mdtType, NexaMdtServerConfig.permissions.records)) then
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
