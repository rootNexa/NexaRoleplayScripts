local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaEmsConfig.featureFlag)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs:info(NEXA_EMS.resourceName, message, metadata or {})
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'ems',
        severity = 'info',
        action = action,
        resourceName = NEXA_EMS.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function checkRequest(source, eventName)
    if not featureEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'EMS ist derzeit deaktiviert.', nil, nil, nil)
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
        factionName = NexaEmsConfig.factionName,
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getRecordPermissions(source)
    return {
        view = hasFactionPermission(source, NexaEmsServer.permissions.recordsView),
        create = hasFactionPermission(source, NexaEmsServer.permissions.recordsCreate),
        treat = hasFactionPermission(source, NexaEmsServer.permissions.treatmentCreate),
        bill = hasFactionPermission(source, NexaEmsServer.permissions.billingCreate)
    }
end

lib.callback.register('nexa:ems:cb:getStatus', function(source)
    local rejected = checkRequest(source, 'nexa:ems:cb:getStatus')

    if rejected ~= nil then
        return rejected
    end

    local overview = exports.nexa_api['faction.getCurrent'](source, {
        factionName = NexaEmsConfig.factionName
    })

    if type(overview) ~= 'table' or overview.success ~= true then
        return overview
    end

    local recordPermissions = getRecordPermissions(source)

    return buildResponse(true, 'OK', 'EMS-Status wurde geladen.', {
        membership = overview.data and overview.data.membership or nil,
        dutySession = overview.data and overview.data.dutySession or nil,
        radioChannels = overview.data and overview.data.radioChannels or {},
        permissions = overview.data and overview.data.permissions or {},
        emsPermissions = {
            viewMembers = hasFactionPermission(source, NexaEmsServer.permissions.viewMembers),
            recordsView = recordPermissions.view,
            recordsCreate = recordPermissions.create,
            treatmentCreate = recordPermissions.treat,
            billingCreate = recordPermissions.bill
        }
    }, nil, nil)
end)

lib.callback.register('nexa:ems:cb:listMembers', function(source, payload)
    local rejected = checkRequest(source, 'nexa:ems:cb:listMembers')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEmsMemberPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Mitgliederanfrage.', nil, nil, nil)
    end

    local response = exports.nexa_api['faction.listMembers'](source, {
        factionName = NexaEmsConfig.factionName,
        limit = math.min(tonumber(payload and payload.limit) or NexaEmsServer.memberLimit, NexaEmsServer.memberLimit)
    })

    if type(response) == 'table' and response.success == true then
        logInfo('EMS-Mitglieder wurden geladen.', {
            source = source,
            count = #(response.data and response.data.members or {})
        })
    end

    return response
end)

lib.callback.register('nexa:ems:cb:listRecords', function(source, payload)
    local rejected = checkRequest(source, 'nexa:ems:cb:listRecords')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEmsRecordListPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Patientenakten-Anfrage.', nil, nil, nil)
    end

    local response = exports.nexa_api['ems.listRecords'](source, {
        characterId = payload and payload.characterId or nil,
        limit = math.min(tonumber(payload and payload.limit) or NexaEmsServer.recordLimit, NexaEmsServer.recordLimit)
    })

    if type(response) == 'table' and response.success == true then
        local auditId = writeAudit('ems.records.view', source, {
            characterId = payload and payload.characterId or nil,
            count = #(response.data and response.data.records or {})
        })
        logInfo('EMS-Patientenakten wurden geladen.', {
            source = source,
            auditId = auditId
        })
    end

    return response
end)

lib.callback.register('nexa:ems:cb:createRecord', function(source, payload)
    local rejected = checkRequest(source, 'nexa:ems:cb:createRecord')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEmsCreateRecordPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Patientenakten-Daten.', nil, nil, nil)
    end

    return exports.nexa_api['ems.createRecord'](source, payload)
end)

lib.callback.register('nexa:ems:cb:addTreatment', function(source, payload)
    local rejected = checkRequest(source, 'nexa:ems:cb:addTreatment')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEmsTreatmentPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Behandlungsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['ems.addTreatment'](source, payload)
end)

lib.callback.register('nexa:ems:cb:createInvoice', function(source, payload)
    local rejected = checkRequest(source, 'nexa:ems:cb:createInvoice')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEmsInvoicePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['account.createMedicalInvoice'](source, payload)
end)
