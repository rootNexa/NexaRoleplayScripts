local migrated = false

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code,
        message = message,
        data = data,
        meta = meta,
        error = success == true and nil or {
            code = code,
            message = message,
            details = meta
        }
    }
end

local function responseOk(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function responseFail(code, message, meta)
    return response(false, code, message, nil, meta)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NEXA_JOBSCREATOR.resourceName, message, metadata or {})
        return
    end

    print(('[%s] %s'):format(NEXA_JOBSCREATOR.resourceName, message))
end

local function logError(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:error(NEXA_JOBSCREATOR.resourceName, message, metadata or {})
        return
    end

    print(('[%s] ERROR: %s'):format(NEXA_JOBSCREATOR.resourceName, message))
end

local function runMigrations()
    if not NexaJobsCreatorConfig.autoMigrate then
        logInfo('JobsCreator gestartet, Migrationen sind deaktiviert.', {
            version = NEXA_JOBSCREATOR.version
        })
        return
    end

    local ok, errorMessage = NexaJobsCreatorDatabase.Migrate()
    migrated = ok == true

    if migrated then
        logInfo('JobsCreator Foundation gestartet.', {
            version = NEXA_JOBSCREATOR.version,
            autoMigrate = true
        })
        return
    end

    logError('JobsCreator Migration fehlgeschlagen.', {
        error = errorMessage
    })
end

local function getStatus()
    return {
        resourceName = NEXA_JOBSCREATOR.resourceName,
        version = NEXA_JOBSCREATOR.version,
        migrated = migrated,
        organizationTypes = NexaJobsCreatorSupportedTypes,
        mdtTypes = NexaJobsCreatorMdtTypes
    }
end

local function isSupportedOrganizationType(organizationType)
    return type(organizationType) == 'string' and NexaJobsCreatorSupportedTypes[organizationType] == true
end

local function isSupportedMdtType(mdtType)
    return type(mdtType) == 'string' and NexaJobsCreatorMdtTypes[mdtType] == true
end

local function normalizeString(value)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')

    if normalized == '' then
        return nil
    end

    return normalized
end

local function normalizeSlug(value)
    value = normalizeString(value)

    if not value then
        return nil
    end

    return value:lower()
end

local function normalizeOrganizationRow(row)
    if type(row) ~= 'table' then
        return row
    end

    if row.enabled ~= nil then
        row.enabled = row.enabled == true or tonumber(row.enabled) == 1
    end

    return row
end

local function validateCreatePayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisation ist ungueltig.', nil)
    end

    local name = normalizeSlug(payload.name)
    local label = normalizeString(payload.label)
    local organizationType = normalizeSlug(payload.organization_type)
    local mdtType = normalizeSlug(payload.mdt_type)

    if not name then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisationsname fehlt.', {
            field = 'name'
        })
    end

    if name:find('^[a-z0-9_%-]+$') == nil then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisationsname muss ein Slug sein.', {
            field = 'name'
        })
    end

    if #name > NexaJobsCreatorConfig.maxOrganizationNameLength then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisationsname ist zu lang.', {
            field = 'name',
            max = NexaJobsCreatorConfig.maxOrganizationNameLength
        })
    end

    if not label then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisationslabel fehlt.', {
            field = 'label'
        })
    end

    if #label > NexaJobsCreatorConfig.maxOrganizationLabelLength then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisationslabel ist zu lang.', {
            field = 'label',
            max = NexaJobsCreatorConfig.maxOrganizationLabelLength
        })
    end

    if not isSupportedOrganizationType(organizationType) then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidType, 'Organisationstyp ist nicht erlaubt.', {
            field = 'organization_type',
            value = payload.organization_type
        })
    end

    if not isSupportedMdtType(mdtType) then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidMdtType, 'MDT-Typ ist nicht erlaubt.', {
            field = 'mdt_type',
            value = payload.mdt_type
        })
    end

    return {
        name = name,
        label = label,
        organization_type = organizationType,
        mdt_type = mdtType,
        enabled = payload.enabled ~= false
    }, nil
end

local function validateId(id)
    id = tonumber(id)

    if not id or id < 1 or id % 1 ~= 0 then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Organisations-ID ist ungueltig.', {
            field = 'id'
        })
    end

    return id, nil
end

local function normalizeListFilter(filter)
    if filter == nil then
        return {}, nil
    end

    if type(filter) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Filter ist ungueltig.', nil)
    end

    local normalized = {}

    if filter.organization_type ~= nil then
        normalized.organization_type = normalizeSlug(filter.organization_type)

        if not isSupportedOrganizationType(normalized.organization_type) then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidType, 'Organisationstyp ist nicht erlaubt.', {
                field = 'organization_type',
                value = filter.organization_type
            })
        end
    end

    if filter.mdt_type ~= nil then
        normalized.mdt_type = normalizeSlug(filter.mdt_type)

        if not isSupportedMdtType(normalized.mdt_type) then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidMdtType, 'MDT-Typ ist nicht erlaubt.', {
                field = 'mdt_type',
                value = filter.mdt_type
            })
        end
    end

    if filter.enabled ~= nil then
        if type(filter.enabled) ~= 'boolean' then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Enabled-Filter muss boolean sein.', {
                field = 'enabled'
            })
        end

        normalized.enabled = filter.enabled
    end

    return normalized, nil
end

local function databaseFail(message, details)
    logError(message, details)
    return responseFail(NEXA_JOBSCREATOR_ERRORS.databaseError, message, details)
end

local function rejectCallbackRequest(source, callbackName)
    if GetResourceState('nexa_security') ~= 'started' then
        return nil
    end

    if not exports.nexa_security:validateSource(source) then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Ungueltige Anfrage.', nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

    if not rateLimit or rateLimit.success ~= true then
        return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
    end

    return nil
end

local function CreateOrganization(payload)
    local normalized, invalid = validateCreatePayload(payload)

    if invalid then
        return invalid
    end

    local existingOk, existing = pcall(NexaJobsCreatorDatabase.FindOrganizationByName, normalized.name)

    if not existingOk then
        return databaseFail('Organisation konnte nicht geprueft werden.', existing)
    end

    if existing then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.duplicateName, 'Organisationsname ist bereits vergeben.', {
            name = normalized.name
        })
    end

    local insertOk, organizationId = pcall(NexaJobsCreatorDatabase.InsertOrganization, normalized)

    if not insertOk then
        return databaseFail('Organisation konnte nicht erstellt werden.', organizationId)
    end

    local getOk, organization = pcall(NexaJobsCreatorDatabase.GetOrganization, organizationId)

    if not getOk then
        return databaseFail('Organisation wurde erstellt, konnte aber nicht geladen werden.', organization)
    end

    return responseOk(normalizeOrganizationRow(organization), 'Organisation wurde erstellt.')
end

local function GetOrganization(id)
    local organizationId, invalid = validateId(id)

    if invalid then
        return invalid
    end

    local ok, organization = pcall(NexaJobsCreatorDatabase.GetOrganization, organizationId)

    if not ok then
        return databaseFail('Organisation konnte nicht geladen werden.', organization)
    end

    if not organization then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.notFound, 'Organisation wurde nicht gefunden.', {
            id = organizationId
        })
    end

    return responseOk(normalizeOrganizationRow(organization), 'Organisation wurde geladen.')
end

local function ListOrganizations(filter)
    local normalizedFilter, invalid = normalizeListFilter(filter)

    if invalid then
        return invalid
    end

    local ok, organizations = pcall(NexaJobsCreatorDatabase.ListOrganizations, normalizedFilter)

    if not ok then
        return databaseFail('Organisationen konnten nicht geladen werden.', organizations)
    end

    for _, organization in ipairs(organizations or {}) do
        normalizeOrganizationRow(organization)
    end

    return responseOk(organizations or {}, 'Organisationen wurden geladen.', {
        count = #(organizations or {})
    })
end

local function SetOrganizationEnabled(id, enabled)
    local organizationId, invalid = validateId(id)

    if invalid then
        return invalid
    end

    if type(enabled) ~= 'boolean' then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Enabled muss boolean sein.', {
            field = 'enabled'
        })
    end

    local updateOk, affectedRows = pcall(NexaJobsCreatorDatabase.SetOrganizationEnabled, organizationId, enabled)

    if not updateOk then
        return databaseFail('Organisation konnte nicht aktualisiert werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.notFound, 'Organisation wurde nicht gefunden.', {
            id = organizationId
        })
    end

    return GetOrganization(organizationId)
end

local function registerCallbacks()
    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.createOrganization, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.createOrganization)

        if rejected then
            return rejected
        end

        return CreateOrganization(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.getOrganization, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.getOrganization)

        if rejected then
            return rejected
        end

        local id = type(payload) == 'table' and payload.id or payload
        return GetOrganization(id)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.listOrganizations, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.listOrganizations)

        if rejected then
            return rejected
        end

        return ListOrganizations(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.setOrganizationEnabled, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.setOrganizationEnabled)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return SetOrganizationEnabled(payload.id, payload.enabled)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    runMigrations()
    registerCallbacks()
end)

exports('getStatus', getStatus)
exports('getSchema', NexaJobsCreatorDatabase.GetSchema)
exports('isSupportedOrganizationType', isSupportedOrganizationType)
exports('isSupportedMdtType', isSupportedMdtType)
exports('CreateOrganization', CreateOrganization)
exports('GetOrganization', GetOrganization)
exports('ListOrganizations', ListOrganizations)
exports('SetOrganizationEnabled', SetOrganizationEnabled)
