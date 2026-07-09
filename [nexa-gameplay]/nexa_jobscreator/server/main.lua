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
        mdtTypes = NexaJobsCreatorMdtTypes,
        modules = NEXA_JOBSCREATOR_MODULES
    }
end

local function isSupportedOrganizationType(organizationType)
    return type(organizationType) == 'string' and NexaJobsCreatorSupportedTypes[organizationType] == true
end

local function isSupportedMdtType(mdtType)
    return type(mdtType) == 'string' and NexaJobsCreatorMdtTypes[mdtType] == true
end

local function isSupportedModule(moduleName)
    return type(moduleName) == 'string' and NEXA_JOBSCREATOR_MODULES[moduleName] == true
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

local function decodeJsonField(value)
    if type(value) ~= 'string' or value == '' then
        return value
    end

    local ok, decoded = pcall(json.decode, value)

    if ok then
        return decoded
    end

    return value
end

local function encodeJsonField(value)
    if value == nil then
        return nil
    end

    if type(value) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'JSON-Feld muss eine Tabelle sein.', nil)
    end

    local ok, encoded = pcall(json.encode, value)

    if not ok then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'JSON-Feld konnte nicht serialisiert werden.', nil)
    end

    return encoded, nil
end

local function normalizeGradeRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.permissions = decodeJsonField(row.permissions)

    return row
end

local function normalizeMemberRow(row)
    if type(row) ~= 'table' then
        return row
    end

    if row.is_on_duty ~= nil then
        row.is_on_duty = row.is_on_duty == true or tonumber(row.is_on_duty) == 1
    end

    return row
end

local function normalizeModuleRow(row)
    if type(row) ~= 'table' then
        return row
    end

    if row.enabled ~= nil then
        row.enabled = row.enabled == true or tonumber(row.enabled) == 1
    end

    row.config_json = decodeJsonField(row.config_json)

    return row
end

local function normalizeOptionalString(value)
    if value == nil then
        return nil, false, nil
    end

    if type(value) ~= 'string' then
        return nil, true, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Wert muss ein String sein.', nil)
    end

    return normalizeString(value), true, nil
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

local function validatePositiveInteger(value, field, message)
    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, message or 'ID ist ungueltig.', {
            field = field
        })
    end

    return value, nil
end

local function validateLevel(value)
    value = tonumber(value)

    if not value or value % 1 ~= 0 then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Level ist ungueltig.', {
            field = 'level'
        })
    end

    return value, nil
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

local function ensureOrganizationExists(organizationId)
    local ok, organization = pcall(NexaJobsCreatorDatabase.GetOrganization, organizationId)

    if not ok then
        return nil, databaseFail('Organisation konnte nicht geprueft werden.', organization)
    end

    if not organization then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.notFound, 'Organisation wurde nicht gefunden.', {
            id = organizationId
        })
    end

    return organization, nil
end

local function ensureGradeExists(gradeId)
    local ok, grade = pcall(NexaJobsCreatorDatabase.GetGrade, gradeId)

    if not ok then
        return nil, databaseFail('Grade konnte nicht geprueft werden.', grade)
    end

    if not grade then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.gradeNotFound, 'Grade wurde nicht gefunden.', {
            id = gradeId
        })
    end

    return normalizeGradeRow(grade), nil
end

local function ensureMemberExists(memberId)
    local ok, member = pcall(NexaJobsCreatorDatabase.GetMember, memberId)

    if not ok then
        return nil, databaseFail('Mitglied konnte nicht geprueft werden.', member)
    end

    if not member then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.memberNotFound, 'Mitglied wurde nicht gefunden.', {
            id = memberId
        })
    end

    return normalizeMemberRow(member), nil
end

local function validateCreateGradePayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Payload ist ungueltig.', nil)
    end

    local organizationId, invalid = validatePositiveInteger(payload.organization_id, 'organization_id', 'Organisations-ID ist ungueltig.')

    if invalid then
        return nil, invalid
    end

    local name = normalizeSlug(payload.name)
    local label = normalizeString(payload.label)
    local level

    level, invalid = validateLevel(payload.level)

    if invalid then
        return nil, invalid
    end

    if not name then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Name fehlt.', {
            field = 'name'
        })
    end

    if name:find('^[a-z0-9_%-]+$') == nil then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Name muss ein Slug sein.', {
            field = 'name'
        })
    end

    if #name > NexaJobsCreatorConfig.maxGradeNameLength then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Name ist zu lang.', {
            field = 'name',
            max = NexaJobsCreatorConfig.maxGradeNameLength
        })
    end

    if not label then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Label fehlt.', {
            field = 'label'
        })
    end

    if #label > NexaJobsCreatorConfig.maxGradeLabelLength then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Label ist zu lang.', {
            field = 'label',
            max = NexaJobsCreatorConfig.maxGradeLabelLength
        })
    end

    local permissions, permissionInvalid = encodeJsonField(payload.permissions)

    if permissionInvalid then
        return nil, permissionInvalid
    end

    return {
        organization_id = organizationId,
        name = name,
        label = label,
        level = level,
        permissions = permissions
    }, nil
end

local function CreateGrade(payload)
    local normalized, invalid = validateCreateGradePayload(payload)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(normalized.organization_id)

    if missingOrganization then
        return missingOrganization
    end

    local insertOk, gradeId = pcall(NexaJobsCreatorDatabase.InsertGrade, normalized)

    if not insertOk then
        return databaseFail('Grade konnte nicht erstellt werden.', gradeId)
    end

    local grade, gradeError = ensureGradeExists(gradeId)

    if gradeError then
        return gradeError
    end

    return responseOk(grade, 'Grade wurde erstellt.')
end

local function ListGrades(organizationId)
    local id, invalid = validatePositiveInteger(organizationId, 'organization_id', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local ok, grades = pcall(NexaJobsCreatorDatabase.ListGrades, id)

    if not ok then
        return databaseFail('Grades konnten nicht geladen werden.', grades)
    end

    for _, grade in ipairs(grades or {}) do
        normalizeGradeRow(grade)
    end

    return responseOk(grades or {}, 'Grades wurden geladen.', {
        count = #(grades or {})
    })
end

local function validateUpdateGradePayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Payload ist ungueltig.', nil)
    end

    local updates = {}

    if payload.name ~= nil then
        local name = normalizeSlug(payload.name)

        if not name or name:find('^[a-z0-9_%-]+$') == nil then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Name ist ungueltig.', {
                field = 'name'
            })
        end

        if #name > NexaJobsCreatorConfig.maxGradeNameLength then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Name ist zu lang.', {
                field = 'name',
                max = NexaJobsCreatorConfig.maxGradeNameLength
            })
        end

        updates.name = name
    end

    if payload.label ~= nil then
        local label = normalizeString(payload.label)

        if not label then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Label ist ungueltig.', {
                field = 'label'
            })
        end

        if #label > NexaJobsCreatorConfig.maxGradeLabelLength then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade-Label ist zu lang.', {
                field = 'label',
                max = NexaJobsCreatorConfig.maxGradeLabelLength
            })
        end

        updates.label = label
    end

    if payload.level ~= nil then
        local level, invalid = validateLevel(payload.level)

        if invalid then
            return nil, invalid
        end

        updates.level = level
    end

    if payload.permissions ~= nil then
        local permissions, invalid = encodeJsonField(payload.permissions)

        if invalid then
            return nil, invalid
        end

        updates.permissions = permissions
    end

    if next(updates) == nil then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Keine Grade-Aenderung angegeben.', nil)
    end

    return updates, nil
end

local function UpdateGrade(id, payload)
    local gradeId, invalid = validatePositiveInteger(id, 'id', 'Grade-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, gradeError = ensureGradeExists(gradeId)

    if gradeError then
        return gradeError
    end

    local updates

    updates, invalid = validateUpdateGradePayload(payload)

    if invalid then
        return invalid
    end

    local updateOk, affectedRows = pcall(NexaJobsCreatorDatabase.UpdateGrade, gradeId, updates)

    if not updateOk then
        return databaseFail('Grade konnte nicht aktualisiert werden.', affectedRows)
    end

    local grade, reloadedError = ensureGradeExists(gradeId)

    if reloadedError then
        return reloadedError
    end

    return responseOk(grade, 'Grade wurde aktualisiert.')
end

local function DeleteGrade(id)
    local gradeId, invalid = validatePositiveInteger(id, 'id', 'Grade-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, gradeError = ensureGradeExists(gradeId)

    if gradeError then
        return gradeError
    end

    local deleteOk, affectedRows = pcall(NexaJobsCreatorDatabase.DeleteGrade, gradeId)

    if not deleteOk then
        return databaseFail('Grade konnte nicht geloescht werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.gradeNotFound, 'Grade wurde nicht gefunden.', {
            id = gradeId
        })
    end

    return responseOk({
        id = gradeId
    }, 'Grade wurde geloescht.')
end

local function validateCreateMemberPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Member-Payload ist ungueltig.', nil)
    end

    local organizationId, invalid = validatePositiveInteger(payload.organization_id, 'organization_id', 'Organisations-ID ist ungueltig.')

    if invalid then
        return nil, invalid
    end

    local characterId
    characterId, invalid = validatePositiveInteger(payload.character_id, 'character_id', 'Character-ID ist ungueltig.')

    if invalid then
        return nil, invalid
    end

    local gradeId = nil

    if payload.grade_id ~= nil then
        gradeId, invalid = validatePositiveInteger(payload.grade_id, 'grade_id', 'Grade-ID ist ungueltig.')

        if invalid then
            return nil, invalid
        end
    end

    local callsign, _, callsignInvalid = normalizeOptionalString(payload.callsign)

    if callsignInvalid then
        return nil, callsignInvalid
    end

    if payload.is_on_duty ~= nil and type(payload.is_on_duty) ~= 'boolean' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Duty-Status muss boolean sein.', {
            field = 'is_on_duty'
        })
    end

    return {
        organization_id = organizationId,
        character_id = characterId,
        grade_id = gradeId,
        callsign = callsign,
        is_on_duty = payload.is_on_duty == true
    }, nil
end

local function validateMemberGrade(organizationId, gradeId)
    if gradeId == nil then
        return nil
    end

    local grade, gradeError = ensureGradeExists(gradeId)

    if gradeError then
        return gradeError
    end

    if tonumber(grade.organization_id) ~= tonumber(organizationId) then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Grade gehoert nicht zur Organisation.', {
            organization_id = organizationId,
            grade_id = gradeId
        })
    end

    return nil
end

local function AddMember(payload)
    local normalized, invalid = validateCreateMemberPayload(payload)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(normalized.organization_id)

    if missingOrganization then
        return missingOrganization
    end

    local gradeInvalid = validateMemberGrade(normalized.organization_id, normalized.grade_id)

    if gradeInvalid then
        return gradeInvalid
    end

    local insertOk, memberId = pcall(NexaJobsCreatorDatabase.InsertMember, normalized)

    if not insertOk then
        return databaseFail('Mitglied konnte nicht hinzugefuegt werden.', memberId)
    end

    local member, memberError = ensureMemberExists(memberId)

    if memberError then
        return memberError
    end

    return responseOk(member, 'Mitglied wurde hinzugefuegt.')
end

local function ListMembers(organizationId)
    local id, invalid = validatePositiveInteger(organizationId, 'organization_id', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local ok, members = pcall(NexaJobsCreatorDatabase.ListMembers, id)

    if not ok then
        return databaseFail('Mitglieder konnten nicht geladen werden.', members)
    end

    for _, member in ipairs(members or {}) do
        normalizeMemberRow(member)
    end

    return responseOk(members or {}, 'Mitglieder wurden geladen.', {
        count = #(members or {})
    })
end

local function validateUpdateMemberPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Member-Payload ist ungueltig.', nil)
    end

    local updates = {}

    if payload.grade_id ~= nil then
        local gradeId, invalid = validatePositiveInteger(payload.grade_id, 'grade_id', 'Grade-ID ist ungueltig.')

        if invalid then
            return nil, invalid
        end

        updates.grade_id = gradeId
        updates.grade_id_set = true
    end

    if payload.callsign ~= nil then
        local callsign, _, invalid = normalizeOptionalString(payload.callsign)

        if invalid then
            return nil, invalid
        end

        updates.callsign = callsign
        updates.callsign_set = true
    end

    if payload.is_on_duty ~= nil then
        if type(payload.is_on_duty) ~= 'boolean' then
            return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Duty-Status muss boolean sein.', {
                field = 'is_on_duty'
            })
        end

        updates.is_on_duty = payload.is_on_duty
        updates.is_on_duty_set = true
    end

    if not updates.grade_id_set and not updates.callsign_set and not updates.is_on_duty_set then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Keine Member-Aenderung angegeben.', nil)
    end

    return updates, nil
end

local function UpdateMember(id, payload)
    local memberId, invalid = validatePositiveInteger(id, 'id', 'Member-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local currentMember, memberError = ensureMemberExists(memberId)

    if memberError then
        return memberError
    end

    local updates

    updates, invalid = validateUpdateMemberPayload(payload)

    if invalid then
        return invalid
    end

    if updates.grade_id_set then
        local gradeInvalid = validateMemberGrade(currentMember.organization_id, updates.grade_id)

        if gradeInvalid then
            return gradeInvalid
        end
    end

    local updateOk, affectedRows = pcall(NexaJobsCreatorDatabase.UpdateMember, memberId, updates)

    if not updateOk then
        return databaseFail('Mitglied konnte nicht aktualisiert werden.', affectedRows)
    end

    local member, reloadedError = ensureMemberExists(memberId)

    if reloadedError then
        return reloadedError
    end

    return responseOk(member, 'Mitglied wurde aktualisiert.')
end

local function RemoveMember(id)
    local memberId, invalid = validatePositiveInteger(id, 'id', 'Member-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, memberError = ensureMemberExists(memberId)

    if memberError then
        return memberError
    end

    local deleteOk, affectedRows = pcall(NexaJobsCreatorDatabase.RemoveMember, memberId)

    if not deleteOk then
        return databaseFail('Mitglied konnte nicht entfernt werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.memberNotFound, 'Mitglied wurde nicht gefunden.', {
            id = memberId
        })
    end

    return responseOk({
        id = memberId
    }, 'Mitglied wurde entfernt.')
end

local function SetDuty(memberId, isOnDuty)
    local id, invalid = validatePositiveInteger(memberId, 'memberId', 'Member-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    if type(isOnDuty) ~= 'boolean' then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Duty-Status muss boolean sein.', {
            field = 'isOnDuty'
        })
    end

    local _, memberError = ensureMemberExists(id)

    if memberError then
        return memberError
    end

    local updateOk, affectedRows = pcall(NexaJobsCreatorDatabase.SetDuty, id, isOnDuty)

    if not updateOk then
        return databaseFail('Duty-Status konnte nicht aktualisiert werden.', affectedRows)
    end

    local member, reloadedError = ensureMemberExists(id)

    if reloadedError then
        return reloadedError
    end

    return responseOk(member, 'Duty-Status wurde aktualisiert.')
end

local function validateModuleName(moduleName)
    moduleName = normalizeSlug(moduleName)

    if not moduleName then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Modulname fehlt.', {
            field = 'moduleName'
        })
    end

    if not isSupportedModule(moduleName) then
        return nil, responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Modul ist nicht erlaubt.', {
            field = 'moduleName',
            value = moduleName
        })
    end

    return moduleName, nil
end

local function encodeModuleConfig(config)
    if config == nil then
        config = {}
    end

    return encodeJsonField(config)
end

local function getModule(organizationId, moduleName)
    local ok, module = pcall(NexaJobsCreatorDatabase.GetModule, organizationId, moduleName)

    if not ok then
        return nil, databaseFail('Organisationsmodul konnte nicht geladen werden.', module)
    end

    return normalizeModuleRow(module), nil
end

local function AssignModule(organizationId, moduleName)
    local id, invalid = validatePositiveInteger(organizationId, 'organizationId', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local normalizedModule
    normalizedModule, invalid = validateModuleName(moduleName)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local existing, existingError = getModule(id, normalizedModule)

    if existingError then
        return existingError
    end

    if existing then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.moduleExists, 'Modul ist der Organisation bereits zugewiesen.', {
            organization_id = id,
            module_name = normalizedModule
        })
    end

    local configJson
    configJson, invalid = encodeModuleConfig({})

    if invalid then
        return invalid
    end

    local insertOk, moduleId = pcall(NexaJobsCreatorDatabase.InsertModule, {
        organization_id = id,
        module_name = normalizedModule,
        enabled = true,
        config_json = configJson
    })

    if not insertOk then
        return databaseFail('Modul konnte nicht zugewiesen werden.', moduleId)
    end

    local ok, module = pcall(NexaJobsCreatorDatabase.GetModuleById, moduleId)

    if not ok then
        return databaseFail('Modul wurde zugewiesen, konnte aber nicht geladen werden.', module)
    end

    return responseOk(normalizeModuleRow(module), 'Modul wurde zugewiesen.')
end

local function RemoveModule(organizationId, moduleName)
    local id, invalid = validatePositiveInteger(organizationId, 'organizationId', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local normalizedModule
    normalizedModule, invalid = validateModuleName(moduleName)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local existing, existingError = getModule(id, normalizedModule)

    if existingError then
        return existingError
    end

    if not existing then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.moduleNotFound, 'Modul wurde nicht gefunden.', {
            organization_id = id,
            module_name = normalizedModule
        })
    end

    local deleteOk, affectedRows = pcall(NexaJobsCreatorDatabase.RemoveModule, id, normalizedModule)

    if not deleteOk then
        return databaseFail('Modul konnte nicht entfernt werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.moduleNotFound, 'Modul wurde nicht gefunden.', {
            organization_id = id,
            module_name = normalizedModule
        })
    end

    return responseOk({
        organization_id = id,
        module_name = normalizedModule
    }, 'Modul wurde entfernt.')
end

local function HasModule(organizationId, moduleName)
    local id, invalid = validatePositiveInteger(organizationId, 'organizationId', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local normalizedModule
    normalizedModule, invalid = validateModuleName(moduleName)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local module, moduleError = getModule(id, normalizedModule)

    if moduleError then
        return moduleError
    end

    return responseOk({
        organization_id = id,
        module_name = normalizedModule,
        hasModule = module ~= nil and module.enabled == true,
        module = module
    }, 'Modulstatus wurde geladen.')
end

local function ListModules(organizationId)
    local id, invalid = validatePositiveInteger(organizationId, 'organizationId', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local ok, modules = pcall(NexaJobsCreatorDatabase.ListModules, id)

    if not ok then
        return databaseFail('Module konnten nicht geladen werden.', modules)
    end

    for _, module in ipairs(modules or {}) do
        normalizeModuleRow(module)
    end

    return responseOk(modules or {}, 'Module wurden geladen.', {
        count = #(modules or {})
    })
end

local function UpdateModuleConfig(organizationId, moduleName, config)
    local id, invalid = validatePositiveInteger(organizationId, 'organizationId', 'Organisations-ID ist ungueltig.')

    if invalid then
        return invalid
    end

    local normalizedModule
    normalizedModule, invalid = validateModuleName(moduleName)

    if invalid then
        return invalid
    end

    local _, missingOrganization = ensureOrganizationExists(id)

    if missingOrganization then
        return missingOrganization
    end

    local existing, existingError = getModule(id, normalizedModule)

    if existingError then
        return existingError
    end

    if not existing then
        return responseFail(NEXA_JOBSCREATOR_ERRORS.moduleNotFound, 'Modul wurde nicht gefunden.', {
            organization_id = id,
            module_name = normalizedModule
        })
    end

    local configJson
    configJson, invalid = encodeModuleConfig(config)

    if invalid then
        return invalid
    end

    local updateOk, affectedRows = pcall(NexaJobsCreatorDatabase.UpdateModuleConfig, id, normalizedModule, configJson)

    if not updateOk then
        return databaseFail('Modul-Konfiguration konnte nicht aktualisiert werden.', affectedRows)
    end

    local module, moduleError = getModule(id, normalizedModule)

    if moduleError then
        return moduleError
    end

    return responseOk(module, 'Modul-Konfiguration wurde aktualisiert.')
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

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.createGrade, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.createGrade)

        if rejected then
            return rejected
        end

        return CreateGrade(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.listGrades, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.listGrades)

        if rejected then
            return rejected
        end

        local organizationId = type(payload) == 'table' and payload.organization_id or payload
        return ListGrades(organizationId)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.updateGrade, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.updateGrade)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateGrade(payload.id, payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.deleteGrade, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.deleteGrade)

        if rejected then
            return rejected
        end

        local id = type(payload) == 'table' and payload.id or payload
        return DeleteGrade(id)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.addMember, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.addMember)

        if rejected then
            return rejected
        end

        return AddMember(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.listMembers, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.listMembers)

        if rejected then
            return rejected
        end

        local organizationId = type(payload) == 'table' and payload.organization_id or payload
        return ListMembers(organizationId)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.updateMember, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.updateMember)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateMember(payload.id, payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.removeMember, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.removeMember)

        if rejected then
            return rejected
        end

        local id = type(payload) == 'table' and payload.id or payload
        return RemoveMember(id)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.setDuty, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.setDuty)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        local isOnDuty = payload.isOnDuty

        if isOnDuty == nil then
            isOnDuty = payload.is_on_duty
        end

        return SetDuty(payload.memberId or payload.id, isOnDuty)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.assignModule, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.assignModule)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return AssignModule(payload.organizationId or payload.organization_id, payload.moduleName or payload.module_name)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.removeModule, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.removeModule)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return RemoveModule(payload.organizationId or payload.organization_id, payload.moduleName or payload.module_name)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.hasModule, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.hasModule)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return HasModule(payload.organizationId or payload.organization_id, payload.moduleName or payload.module_name)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.listModules, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.listModules)

        if rejected then
            return rejected
        end

        local organizationId = type(payload) == 'table' and (payload.organizationId or payload.organization_id) or payload
        return ListModules(organizationId)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_JOBSCREATOR_CALLBACKS.updateModuleConfig, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_JOBSCREATOR_CALLBACKS.updateModuleConfig)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_JOBSCREATOR_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateModuleConfig(payload.organizationId or payload.organization_id, payload.moduleName or payload.module_name, payload.config)
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
exports('CreateGrade', CreateGrade)
exports('ListGrades', ListGrades)
exports('UpdateGrade', UpdateGrade)
exports('DeleteGrade', DeleteGrade)
exports('AddMember', AddMember)
exports('ListMembers', ListMembers)
exports('UpdateMember', UpdateMember)
exports('RemoveMember', RemoveMember)
exports('SetDuty', SetDuty)
exports('AssignModule', AssignModule)
exports('RemoveModule', RemoveModule)
exports('HasModule', HasModule)
exports('ListModules', ListModules)
exports('UpdateModuleConfig', UpdateModuleConfig)
