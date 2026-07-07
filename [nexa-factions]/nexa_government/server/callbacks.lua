local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaGovernmentConfig.featureFlag)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs:info(NEXA_GOVERNMENT.resourceName, message, metadata or {})
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'government',
        severity = 'info',
        action = action,
        resourceName = NEXA_GOVERNMENT.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function checkRequest(source, eventName)
    if not featureEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Government ist derzeit deaktiviert.', nil, nil, nil)
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
        factionName = NexaGovernmentConfig.factionName,
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getGovernmentPermissions(source)
    return {
        viewMembers = hasFactionPermission(source, NexaGovernmentServer.permissions.viewMembers),
        documentsIssue = hasFactionPermission(source, NexaGovernmentServer.permissions.documentsIssue),
        documentsRevoke = hasFactionPermission(source, NexaGovernmentServer.permissions.documentsRevoke),
        licensesIssue = hasFactionPermission(source, NexaGovernmentServer.permissions.licensesIssue),
        licensesRevoke = hasFactionPermission(source, NexaGovernmentServer.permissions.licensesRevoke),
        feesCreate = hasFactionPermission(source, NexaGovernmentServer.permissions.feesCreate)
    }
end

lib.callback.register('nexa:government:cb:getStatus', function(source)
    local rejected = checkRequest(source, 'nexa:government:cb:getStatus')

    if rejected ~= nil then
        return rejected
    end

    local overview = exports.nexa_api['faction.getCurrent'](source, {
        factionName = NexaGovernmentConfig.factionName
    })

    if type(overview) ~= 'table' or overview.success ~= true then
        return overview
    end

    return buildResponse(true, 'OK', 'Government-Status wurde geladen.', {
        membership = overview.data and overview.data.membership or nil,
        dutySession = overview.data and overview.data.dutySession or nil,
        radioChannels = overview.data and overview.data.radioChannels or {},
        permissions = overview.data and overview.data.permissions or {},
        governmentPermissions = getGovernmentPermissions(source)
    }, nil, nil)
end)

lib.callback.register('nexa:government:cb:listMembers', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:listMembers')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentMemberPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Mitgliederanfrage.', nil, nil, nil)
    end

    local response = exports.nexa_api['faction.listMembers'](source, {
        factionName = NexaGovernmentConfig.factionName,
        limit = math.min(tonumber(payload and payload.limit) or NexaGovernmentServer.memberLimit, NexaGovernmentServer.memberLimit)
    })

    if type(response) == 'table' and response.success == true then
        logInfo('Government-Mitglieder wurden geladen.', {
            source = source,
            count = #(response.data and response.data.members or {})
        })
    end

    return response
end)

lib.callback.register('nexa:government:cb:listDocumentTypes', function(source)
    local rejected = checkRequest(source, 'nexa:government:cb:listDocumentTypes')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api['document.listTypes']()
end)

lib.callback.register('nexa:government:cb:listLicenseTypes', function(source)
    local rejected = checkRequest(source, 'nexa:government:cb:listLicenseTypes')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api['license.listTypes']()
end)

lib.callback.register('nexa:government:cb:issueDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:issueDocument')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentDocumentIssuePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    local response = exports.nexa_api['document.issue'](source, payload)

    if type(response) == 'table' and response.success == true then
        local auditId = writeAudit('government.document.issue', source, {
            ownerCharacterId = payload.ownerCharacterId,
            documentType = payload.documentType,
            documentTypeId = payload.documentTypeId
        })
        response.audit_id = response.audit_id or auditId
        logInfo('Government-Dokument wurde ausgestellt.', {
            source = source,
            auditId = auditId
        })
    end

    return response
end)

lib.callback.register('nexa:government:cb:revokeDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:revokeDocument')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentDocumentRevokePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    return exports.nexa_api['document.revoke'](source, payload)
end)

lib.callback.register('nexa:government:cb:issueLicense', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:issueLicense')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentLicenseIssuePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    return exports.nexa_api['license.issue'](source, payload)
end)

lib.callback.register('nexa:government:cb:revokeLicense', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:revokeLicense')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentLicenseRevokePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    return exports.nexa_api['license.revoke'](source, payload)
end)

lib.callback.register('nexa:government:cb:createInvoice', function(source, payload)
    local rejected = checkRequest(source, 'nexa:government:cb:createInvoice')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateGovernmentInvoicePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Gebuehrendaten.', nil, nil, nil)
    end

    return exports.nexa_api['account.createGovernmentInvoice'](source, payload)
end)
