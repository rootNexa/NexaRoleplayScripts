local emsLimits = {
    maxRecordLimit = 25,
    maxSummaryLength = 500,
    maxTreatmentNotesLength = 500
}

local emsPermissions = {
    recordsView = 'ems.records.view',
    recordsCreate = 'ems.records.create',
    treatmentCreate = 'ems.treatments.create'
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    return trimmed
end

local function encodeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return json.encode({})
    end

    return json.encode(metadata)
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function getInvokingResourceName()
    return GetInvokingResource() or NEXA_API.resourceName
end

local function ensureEmsCaller()
    local caller = getInvokingResourceName()

    return caller == 'nexa_ems' or caller == NEXA_API.resourceName
end

local function hasEmsPermission(source, permission)
    if type(hasFactionPermission) ~= 'function' then
        return false
    end

    local result = hasFactionPermission(source, {
        factionName = 'ems',
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getEmsDutyContext(source)
    if type(getCurrentFaction) ~= 'function' then
        return nil
    end

    local result = getCurrentFaction(source, {
        factionName = 'ems'
    })

    if type(result) ~= 'table' or result.success ~= true then
        return nil
    end

    local data = result.data or {}

    if data.membership == nil or data.dutySession == nil then
        return nil
    end

    return data
end

local function ensureEmsAccess(source, permission, requireDuty)
    if not ensureEmsCaller() then
        return false, 'NO_PERMISSION', 'Diese Resource darf keine EMS-Daten verwalten.'
    end

    if not hasEmsPermission(source, permission) then
        return false, 'NO_PERMISSION', 'Du hast dafuer keine EMS-Berechtigung.'
    end

    if requireDuty and getEmsDutyContext(source) == nil then
        return false, 'NO_PERMISSION', 'Du musst dafuer im EMS-Dienst sein.'
    end

    return true, 'OK', 'OK'
end

local function writeEmsAudit(action, actor, targetType, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'ems',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = targetType,
        targetId = targetId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function mapRecord(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        character_id = row.character_id,
        record_type = row.record_type,
        summary = row.summary,
        status = row.status,
        created_by_character_id = row.created_by_character_id,
        created_at = row.created_at,
        citizenid = row.citizenid,
        firstname = row.firstname,
        lastname = row.lastname
    }
end

function listEmsRecords(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureEmsAccess(source, emsPermissions.recordsView, false)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local characterId = normalizeId(payload and payload.characterId)
    local limit = normalizeId(payload and payload.limit) or 10

    if limit > emsLimits.maxRecordLimit then
        limit = emsLimits.maxRecordLimit
    end

    local where = ''
    local values = {}

    if characterId ~= nil then
        where = 'WHERE er.character_id = ?'
        values[#values + 1] = characterId
    end

    values[#values + 1] = limit

    local rows = MySQL.query.await(([[ 
        SELECT er.id, er.character_id, er.record_type, er.summary, er.status,
            er.created_by_character_id, er.created_at,
            c.citizenid, c.firstname, c.lastname
        FROM ems_records er
        JOIN characters c ON c.id = er.character_id
        %s
        ORDER BY er.created_at DESC, er.id DESC
        LIMIT ?
    ]]):format(where), values) or {}
    local records = {}

    for _, row in ipairs(rows) do
        records[#records + 1] = mapRecord(row)
    end

    return respond(true, 'OK', 'EMS-Patientenakten wurden geladen.', {
        records = records
    }, {
        limit = limit
    }, nil)
end

function createEmsRecord(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureEmsAccess(source, emsPermissions.recordsCreate, true)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Patientenakten-Daten.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)
    local recordType = normalizeText(payload.recordType, 'patient_contact')
    local summary = normalizeText(payload.summary, nil)

    if characterId == nil or recordType == nil or #recordType > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Patientenakten-Daten.', nil, nil, nil)
    end

    if summary ~= nil and #summary > emsLimits.maxSummaryLength then
        return respond(false, 'INVALID_INPUT', 'Zusammenfassung ist zu lang.', nil, nil, nil)
    end

    local patient = MySQL.single.await([[ 
        SELECT id, citizenid, firstname, lastname
        FROM characters
        WHERE id = ? AND is_active = TRUE
        LIMIT 1
    ]], {
        characterId
    })

    if patient == nil then
        return respond(false, 'NOT_FOUND', 'Patient wurde nicht gefunden.', nil, nil, nil)
    end

    local recordId = MySQL.insert.await([[ 
        INSERT INTO ems_records (character_id, record_type, summary, status, created_by_character_id, created_at)
        VALUES (?, ?, ?, 'open', ?, NOW())
    ]], {
        patient.id,
        recordType,
        summary,
        actor.id
    })

    local auditId = writeEmsAudit('ems.record.create', actor, 'ems_record', recordId, {
        patientCharacterId = patient.id,
        recordType = recordType
    })

    return respond(true, 'CREATED', 'EMS-Patientenakte wurde erstellt.', {
        recordId = recordId,
        patient = patient
    }, nil, auditId)
end

function addEmsTreatment(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureEmsAccess(source, emsPermissions.treatmentCreate, true)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Behandlungsdaten.', nil, nil, nil)
    end

    local recordId = normalizeId(payload.recordId)
    local treatmentType = normalizeText(payload.treatmentType, nil)
    local notes = normalizeText(payload.notes, nil)

    if recordId == nil or treatmentType == nil or #treatmentType > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Behandlungsdaten.', nil, nil, nil)
    end

    if notes ~= nil and #notes > emsLimits.maxTreatmentNotesLength then
        return respond(false, 'INVALID_INPUT', 'Behandlungsnotizen sind zu lang.', nil, nil, nil)
    end

    local record = MySQL.single.await([[ 
        SELECT id, character_id, status
        FROM ems_records
        WHERE id = ?
        LIMIT 1
    ]], {
        recordId
    })

    if record == nil then
        return respond(false, 'NOT_FOUND', 'EMS-Patientenakte wurde nicht gefunden.', nil, nil, nil)
    end

    if record.status ~= 'open' then
        return respond(false, 'CONFLICT', 'EMS-Patientenakte ist nicht offen.', nil, nil, nil)
    end

    local treatmentId = MySQL.insert.await([[ 
        INSERT INTO medical_treatments (ems_record_id, treated_by_character_id, treatment_type, notes, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], {
        record.id,
        actor.id,
        treatmentType,
        notes,
        encodeMetadata(payload.metadata)
    })

    local auditId = writeEmsAudit('ems.treatment.create', actor, 'medical_treatment', treatmentId, {
        recordId = record.id,
        patientCharacterId = record.character_id,
        treatmentType = treatmentType
    })

    if type(allowGodmodeException) == 'function' and tonumber(payload.patientSource) ~= nil then
        pcall(allowGodmodeException, tonumber(payload.patientSource), 'ems_treatment', {
            actorSource = source,
            recordId = record.id,
            treatmentId = treatmentId,
            auditId = auditId
        })
    end

    return respond(true, 'CREATED', 'EMS-Behandlung wurde erfasst.', {
        treatmentId = treatmentId,
        recordId = record.id
    }, nil, auditId)
end

exports('ems.listRecords', listEmsRecords)
exports('ems.createRecord', createEmsRecord)
exports('ems.addTreatment', addEmsTreatment)
