local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaLspdConfig.featureFlag)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs:info(NEXA_LSPD.resourceName, message, metadata or {})
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'lspd',
        severity = 'info',
        action = action,
        resourceName = NEXA_LSPD.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function checkRequest(source, eventName)
    if not featureEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'LSPD ist derzeit deaktiviert.', nil, nil, nil)
    end

    if not exports.nexa_security:validateSource(source) then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

local function hasFactionPermission(source, permission)
    local result = exports.nexa_api['faction.hasPermission'](source, {
        factionName = NexaLspdConfig.factionName,
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getMdtAvailability(source)
    local mdtStarted = GetResourceState('nexa_mdt') == 'started'
    local canView = hasFactionPermission(source, NexaLspdServer.permissions.recordsView)
    local canRead = hasFactionPermission(source, NexaLspdServer.permissions.recordsRead)

    return {
        started = mdtStarted,
        canView = canView,
        canRead = canRead,
        canOpen = mdtStarted and canView
    }
end

lib.callback.register('nexa:lspd:cb:getStatus', function(source)
    local rejected = checkRequest(source, 'nexa:lspd:cb:getStatus')

    if rejected ~= nil then
        return rejected
    end

    local overview = exports.nexa_api['faction.getCurrent'](source, {
        factionName = NexaLspdConfig.factionName
    })

    if type(overview) ~= 'table' or overview.success ~= true then
        return overview
    end

    local mdt = getMdtAvailability(source)

    return buildResponse(true, 'OK', 'LSPD-Status wurde geladen.', {
        membership = overview.data and overview.data.membership or nil,
        dutySession = overview.data and overview.data.dutySession or nil,
        radioChannels = overview.data and overview.data.radioChannels or {},
        permissions = overview.data and overview.data.permissions or {},
        lspdPermissions = {
            dispatchView = hasFactionPermission(source, NexaLspdServer.permissions.dispatchView),
            recordsView = mdt.canView,
            recordsRead = mdt.canRead,
            viewMembers = hasFactionPermission(source, NexaLspdServer.permissions.viewMembers)
        },
        mdt = mdt
    }, nil, nil)
end)

lib.callback.register('nexa:lspd:cb:listMembers', function(source, payload)
    local rejected = checkRequest(source, 'nexa:lspd:cb:listMembers')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLspdMemberPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Mitgliederanfrage.', nil, nil, nil)
    end

    local response = exports.nexa_api['faction.listMembers'](source, {
        factionName = NexaLspdConfig.factionName,
        limit = math.min(tonumber(payload and payload.limit) or NexaLspdServer.memberLimit, NexaLspdServer.memberLimit)
    })

    if type(response) == 'table' and response.success == true then
        logInfo('LSPD-Mitglieder wurden geladen.', {
            source = source,
            count = #(response.data and response.data.members or {})
        })
    end

    return response
end)

lib.callback.register('nexa:lspd:cb:listDispatch', function(source, payload)
    local rejected = checkRequest(source, 'nexa:lspd:cb:listDispatch')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLspdDispatchPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Dispatch-Anfrage.', nil, nil, nil)
    end

    if not hasFactionPermission(source, NexaLspdServer.permissions.dispatchView) then
        return buildResponse(false, 'NO_PERMISSION', 'Du darfst keine Dispatch-Daten lesen.', nil, nil, nil)
    end

    local response = exports.nexa_api['dispatch.listCalls'](source, {
        faction = NexaLspdConfig.factionName,
        status = payload and payload.status or nil,
        limit = math.min(tonumber(payload and payload.limit) or NexaLspdServer.dispatchLimit, NexaLspdServer.dispatchLimit)
    })

    if type(response) == 'table' and response.success == true then
        local auditId = writeAudit('lspd.dispatch.view', source, {
            status = payload and payload.status or nil,
            count = #(response.data and response.data.calls or {})
        })
        logInfo('LSPD-Dispatch-Daten wurden geladen.', {
            source = source,
            auditId = auditId
        })
    end

    return response
end)

lib.callback.register('nexa:lspd:cb:getRecordsStatus', function(source)
    local rejected = checkRequest(source, 'nexa:lspd:cb:getRecordsStatus')

    if rejected ~= nil then
        return rejected
    end

    local mdt = getMdtAvailability(source)
    local auditId = writeAudit('lspd.records.status', source, {
        started = mdt.started,
        canOpen = mdt.canOpen,
        canRead = mdt.canRead
    })

    logInfo('LSPD-Aktenstatus wurde geprueft.', {
        source = source,
        auditId = auditId,
        canOpen = mdt.canOpen
    })

    return buildResponse(true, 'OK', 'Aktenstatus wurde geladen.', {
        mdt = mdt
    }, nil, auditId)
end)
