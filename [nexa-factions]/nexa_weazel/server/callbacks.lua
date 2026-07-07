local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaWeazelConfig.featureFlag)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs:info(NEXA_WEAZEL.resourceName, message, metadata or {})
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'weazel',
        severity = 'info',
        action = action,
        resourceName = NEXA_WEAZEL.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function checkRequest(source, eventName)
    if not featureEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Weazel ist derzeit deaktiviert.', nil, nil, nil)
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
        factionName = NexaWeazelConfig.factionName,
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getWeazelOverview(source)
    return exports.nexa_api['faction.getCurrent'](source, {
        factionName = NexaWeazelConfig.factionName
    })
end

local function isOnDuty(source)
    local overview = getWeazelOverview(source)

    return type(overview) == 'table'
        and overview.success == true
        and overview.data ~= nil
        and overview.data.membership ~= nil
        and overview.data.dutySession ~= nil
end

local function getReporterPermissions(source)
    return {
        viewMembers = hasFactionPermission(source, NexaWeazelServer.permissions.viewMembers),
        pressPassIssue = hasFactionPermission(source, NexaWeazelServer.permissions.pressPassIssue),
        announcementCreate = hasFactionPermission(source, NexaWeazelServer.permissions.announcementCreate)
    }
end

local function createAnnouncement(source, payload)
    if not hasFactionPermission(source, NexaWeazelServer.permissions.announcementCreate) then
        return buildResponse(false, 'NO_PERMISSION', 'Du darfst keine Weazel-Ankuendigungen erstellen.', nil, nil, nil)
    end

    if not isOnDuty(source) then
        return buildResponse(false, 'NO_PERMISSION', 'Du musst fuer Weazel im Dienst sein.', nil, nil, nil)
    end

    local announcement = {
        title = payload.title,
        body = payload.body,
        resourceName = NEXA_WEAZEL.resourceName
    }
    local auditId = writeAudit('weazel.announcement.create', source, {
        title = payload.title,
        bodyLength = #payload.body
    })

    TriggerClientEvent(NEXA_WEAZEL_EVENTS.announcement, -1, announcement)
    logInfo('Weazel-Ankuendigung wurde veroeffentlicht.', {
        source = source,
        auditId = auditId,
        title = payload.title
    })

    return buildResponse(true, 'OK', 'Weazel-Ankuendigung wurde veroeffentlicht.', {
        announcement = announcement
    }, nil, auditId)
end

local function issuePressPass(source, payload)
    local response = exports.nexa_api['document.issue'](source, {
        ownerCharacterId = payload.ownerCharacterId,
        documentType = NexaWeazelConfig.pressDocumentType,
        data = {
            note = payload.note,
            issuedFor = NexaWeazelConfig.factionName
        }
    })

    if type(response) == 'table' and response.success == true then
        local auditId = writeAudit('weazel.pressPass.issue', source, {
            ownerCharacterId = payload.ownerCharacterId,
            documentType = NexaWeazelConfig.pressDocumentType
        })
        response.audit_id = response.audit_id or auditId
        logInfo('Weazel-Presseausweis wurde ausgestellt.', {
            source = source,
            auditId = auditId,
            ownerCharacterId = payload.ownerCharacterId
        })
    end

    return response
end

lib.callback.register('nexa:weazel:cb:getStatus', function(source)
    local rejected = checkRequest(source, 'nexa:weazel:cb:getStatus')

    if rejected ~= nil then
        return rejected
    end

    local overview = getWeazelOverview(source)

    if type(overview) ~= 'table' or overview.success ~= true then
        return overview
    end

    return buildResponse(true, 'OK', 'Weazel-Status wurde geladen.', {
        membership = overview.data and overview.data.membership or nil,
        dutySession = overview.data and overview.data.dutySession or nil,
        radioChannels = overview.data and overview.data.radioChannels or {},
        permissions = overview.data and overview.data.permissions or {},
        reporterPermissions = getReporterPermissions(source)
    }, nil, nil)
end)

lib.callback.register('nexa:weazel:cb:listMembers', function(source, payload)
    local rejected = checkRequest(source, 'nexa:weazel:cb:listMembers')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWeazelMemberPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Mitgliederanfrage.', nil, nil, nil)
    end

    local response = exports.nexa_api['faction.listMembers'](source, {
        factionName = NexaWeazelConfig.factionName,
        limit = math.min(tonumber(payload and payload.limit) or NexaWeazelServer.memberLimit, NexaWeazelServer.memberLimit)
    })

    if type(response) == 'table' and response.success == true then
        logInfo('Weazel-Mitglieder wurden geladen.', {
            source = source,
            count = #(response.data and response.data.members or {})
        })
    end

    return response
end)

lib.callback.register('nexa:weazel:cb:issuePressPass', function(source, payload)
    local rejected = checkRequest(source, 'nexa:weazel:cb:issuePressPass')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWeazelPressPassPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Presseausweis-Daten.', nil, nil, nil)
    end

    return issuePressPass(source, payload)
end)

lib.callback.register('nexa:weazel:cb:createAnnouncement', function(source, payload)
    local rejected = checkRequest(source, 'nexa:weazel:cb:createAnnouncement')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWeazelAnnouncementPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Ankuendigungsdaten.', nil, nil, nil)
    end

    return createAnnouncement(source, payload)
end)

NexaWeazelCreateAnnouncement = createAnnouncement
NexaWeazelIssuePressPass = issuePressPass
