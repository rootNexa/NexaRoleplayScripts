local policeLimits = {
    maxEvidenceLimit = 50,
    defaultEvidenceLimit = 25,
    maxDescriptionLength = 500,
    maxLocationLength = 160,
    maxSampleRefLength = 96,
    defaultStashSlots = 20,
    defaultStashWeight = 25000
}

local policePermissions = {
    evidenceCollect = 'police.evidence.collect',
    evidenceRead = 'police.evidence.read',
    evidenceManage = 'police.evidence.manage'
}

local defaultEvidenceTypes = {
    dna = {
        itemName = 'evidence_dna',
        label = 'DNA-Spur'
    },
    fingerprint = {
        itemName = 'evidence_fingerprint',
        label = 'Fingerabdruck'
    },
    shell_casing = {
        itemName = 'evidence_shell_casing',
        label = 'Hülse'
    },
    blood = {
        itemName = 'evidence_blood',
        label = 'Blutspur'
    },
    generic = {
        itemName = 'evidence_item',
        label = 'Beweismittel'
    }
}

local allowedEvidenceStatus = {
    stored = true,
    released = true,
    destroyed = true,
    transferred = true
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

local function normalizeLimit(value)
    local number = tonumber(value) or policeLimits.defaultEvidenceLimit

    if number < 1 then
        return policeLimits.defaultEvidenceLimit
    end

    return math.min(math.floor(number), policeLimits.maxEvidenceLimit)
end

local function normalizeText(value, fallback, maxLength)
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

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function encodeJson(value)
    if type(value) ~= 'table' then
        return json.encode({})
    end

    return json.encode(value)
end

local function decodeJson(value)
    if value == nil or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)

    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    return decoded
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

local function ensurePoliceCaller()
    local caller = getInvokingResourceName()

    return caller == 'nexa_evidence' or caller == 'nexa_lspd' or caller == NEXA_API.resourceName
end

local function hasPolicePermission(source, permission)
    if type(hasFactionPermission) ~= 'function' then
        return false
    end

    local result = hasFactionPermission(source, {
        factionName = 'lspd',
        permission = permission
    })

    return type(result) == 'table' and result.success == true
end

local function getPoliceDutyContext(source)
    if type(getCurrentFaction) ~= 'function' then
        return nil
    end

    local result = getCurrentFaction(source, {
        factionName = 'lspd'
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

local function ensurePoliceAccess(source, permission, requireDuty)
    if not ensurePoliceCaller() then
        return false, 'NO_PERMISSION', 'Diese Resource darf keine Polizeidaten verwalten.'
    end

    if not hasPolicePermission(source, permission) then
        return false, 'NO_PERMISSION', 'Du hast dafuer keine Police-Berechtigung.'
    end

    if requireDuty and getPoliceDutyContext(source) == nil then
        return false, 'NO_PERMISSION', 'Du musst dafuer im LSPD-Dienst sein.'
    end

    return true, 'OK', 'OK'
end

local function writePoliceAudit(action, actor, targetType, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'police',
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

local function generateEvidenceNumber()
    local randomPart = math.random(100000, 999999)

    return ('EV-%s-%d'):format(os.date('%Y%m%d%H%M%S'), randomPart)
end

local function normalizeEvidenceType(value, config)
    local evidenceType = normalizeText(value, nil, 64)

    if evidenceType == nil then
        return nil, nil
    end

    evidenceType = evidenceType:gsub('-', '_'):lower()

    local configured = type(config) == 'table' and type(config.evidenceTypes) == 'table'
        and config.evidenceTypes[evidenceType] or nil
    local definition = configured or defaultEvidenceTypes[evidenceType]

    if definition == nil then
        return nil, nil
    end

    return evidenceType, definition
end

local function normalizeCollectPayload(payload, forcedType)
    if type(payload) ~= 'table' then
        return nil
    end

    local config = type(payload.config) == 'table' and payload.config or nil
    local evidenceType, definition = normalizeEvidenceType(forcedType or payload.evidenceType, config)

    if evidenceType == nil or definition == nil then
        return nil
    end

    local incidentReportId = nil

    if payload.incidentReportId ~= nil then
        incidentReportId = normalizeId(payload.incidentReportId)

        if incidentReportId == nil then
            return nil
        end
    end

    local subjectCharacterId = nil

    if payload.subjectCharacterId ~= nil then
        subjectCharacterId = normalizeId(payload.subjectCharacterId)

        if subjectCharacterId == nil then
            return nil
        end
    end

    local description = normalizeText(payload.description, definition.label, policeLimits.maxDescriptionLength)
    local location = normalizeText(payload.location, nil, policeLimits.maxLocationLength)
    local sampleRef = normalizeText(payload.sampleRef, nil, policeLimits.maxSampleRefLength)

    if description == nil then
        return nil
    end

    return {
        evidenceType = evidenceType,
        definition = definition,
        incidentReportId = incidentReportId,
        subjectCharacterId = subjectCharacterId,
        description = description,
        location = location,
        sampleRef = sampleRef,
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }
end

local function getLspdFactionId()
    return MySQL.scalar.await("SELECT id FROM factions WHERE name = 'lspd' LIMIT 1")
end

local function registerEvidenceStash(stashName, label, factionId)
    if GetResourceState('ox_inventory') ~= 'started' then
        return false
    end

    local ok = pcall(function()
        exports.ox_inventory:RegisterStash(
            stashName,
            label,
            policeLimits.defaultStashSlots,
            policeLimits.defaultStashWeight,
            false
        )
    end)

    return ok
end

local function createEvidenceStorage(evidenceNumber, incidentReportId, actor)
    local stashName = ('evidence_%s'):format(evidenceNumber:gsub('[^%w]', '_'):lower())
    local factionId = getLspdFactionId()
    local stashId = MySQL.scalar.await('SELECT id FROM stash_registry WHERE stash_name = ? LIMIT 1', {
        stashName
    })

    if stashId == nil then
        stashId = MySQL.insert.await([[
            INSERT INTO stash_registry (
                stash_name, label, owner_type, owner_id, slots, max_weight,
                is_temporary, is_active, metadata
            )
            VALUES (?, ?, 'faction', ?, ?, ?, FALSE, TRUE, ?)
        ]], {
            stashName,
            ('Evidence %s'):format(evidenceNumber),
            factionId,
            policeLimits.defaultStashSlots,
            policeLimits.defaultStashWeight,
            encodeJson({
                source = 'phase9f.evidence',
                evidenceNumber = evidenceNumber
            })
        })
    end

    MySQL.insert.await([[
        INSERT INTO evidence_stashes (
            evidence_stash_code, stash_id, incident_report_id, faction_id,
            created_by_character_id, status
        )
        VALUES (?, ?, ?, ?, ?, 'active')
        ON DUPLICATE KEY UPDATE
            status = 'active',
            incident_report_id = VALUES(incident_report_id),
            faction_id = VALUES(faction_id)
    ]], {
        evidenceNumber,
        stashId,
        incidentReportId,
        factionId,
        actor and actor.id or nil
    })

    registerEvidenceStash(stashName, ('Evidence %s'):format(evidenceNumber), factionId)

    return stashName
end

local function mapEvidence(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        evidenceNumber = row.evidence_number,
        incidentReportId = row.incident_report_id,
        subjectCharacterId = row.character_id,
        itemName = row.item_name,
        description = row.description,
        storageRef = row.storage_ref,
        status = row.status,
        metadata = decodeJson(row.metadata),
        createdAt = row.created_at
    }
end

function collectPoliceEvidence(source, payload, forcedType)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensurePoliceAccess(source, policePermissions.evidenceCollect, true)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local normalized = normalizeCollectPayload(payload, forcedType)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Beweisdaten.', nil, nil, nil)
    end

    if normalized.incidentReportId ~= nil then
        local incidentExists = MySQL.scalar.await('SELECT id FROM incident_reports WHERE id = ? LIMIT 1', {
            normalized.incidentReportId
        })

        if incidentExists == nil then
            return respond(false, 'NOT_FOUND', 'Fall wurde nicht gefunden.', nil, nil, nil)
        end
    end

    if normalized.subjectCharacterId ~= nil then
        local subjectExists = MySQL.scalar.await('SELECT id FROM characters WHERE id = ? LIMIT 1', {
            normalized.subjectCharacterId
        })

        if subjectExists == nil then
            return respond(false, 'NOT_FOUND', 'Zielcharakter wurde nicht gefunden.', nil, nil, nil)
        end
    end

    local evidenceNumber = generateEvidenceNumber()
    local storageRef = createEvidenceStorage(evidenceNumber, normalized.incidentReportId, actor)
    local metadata = normalized.metadata

    metadata.evidenceType = normalized.evidenceType
    metadata.sampleRef = normalized.sampleRef
    metadata.location = normalized.location
    metadata.collectedByCharacterId = actor.id
    metadata.chain = {
        {
            action = 'collected',
            actorCharacterId = actor.id,
            at = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    local evidenceId = MySQL.insert.await([[
        INSERT INTO evidence_items (
            evidence_number, incident_report_id, character_id, item_name,
            description, storage_ref, status, metadata
        )
        VALUES (?, ?, ?, ?, ?, ?, 'stored', ?)
    ]], {
        evidenceNumber,
        normalized.incidentReportId,
        normalized.subjectCharacterId,
        normalized.definition.itemName,
        normalized.description,
        storageRef,
        encodeJson(metadata)
    })

    local auditId = writePoliceAudit('police.evidence.collect', actor, 'evidence_item', evidenceId, {
        evidenceNumber = evidenceNumber,
        evidenceType = normalized.evidenceType,
        incidentReportId = normalized.incidentReportId,
        subjectCharacterId = normalized.subjectCharacterId,
        storageRef = storageRef
    })

    return respond(true, 'OK', 'Beweismittel wurde gesichert.', {
        evidence = {
            id = evidenceId,
            evidenceNumber = evidenceNumber,
            evidenceType = normalized.evidenceType,
            itemName = normalized.definition.itemName,
            storageRef = storageRef,
            status = 'stored'
        }
    }, nil, auditId)
end

function listPoliceEvidence(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensurePoliceAccess(source, policePermissions.evidenceRead, false)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local incidentReportId = payload and payload.incidentReportId ~= nil and normalizeId(payload.incidentReportId) or nil
    local subjectCharacterId = payload and payload.subjectCharacterId ~= nil and normalizeId(payload.subjectCharacterId) or nil
    local status = normalizeText(payload and payload.status, nil, 32)
    local limit = normalizeLimit(payload and payload.limit)

    if payload and payload.incidentReportId ~= nil and incidentReportId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fall-ID.', nil, nil, nil)
    end

    if payload and payload.subjectCharacterId ~= nil and subjectCharacterId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Charakter-ID.', nil, nil, nil)
    end

    if status ~= nil and not allowedEvidenceStatus[status] then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Beweisstatus.', nil, nil, nil)
    end

    local where = {}
    local values = {}

    if incidentReportId ~= nil then
        where[#where + 1] = 'incident_report_id = ?'
        values[#values + 1] = incidentReportId
    end

    if subjectCharacterId ~= nil then
        where[#where + 1] = 'character_id = ?'
        values[#values + 1] = subjectCharacterId
    end

    if status ~= nil then
        where[#where + 1] = 'status = ?'
        values[#values + 1] = status
    end

    local whereSql = ''

    if #where > 0 then
        whereSql = 'WHERE ' .. table.concat(where, ' AND ')
    end

    values[#values + 1] = limit

    local rows = MySQL.query.await(([[ 
        SELECT id, evidence_number, incident_report_id, character_id, item_name,
            description, storage_ref, status, metadata, created_at
        FROM evidence_items
        %s
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]]):format(whereSql), values) or {}
    local evidence = {}

    for _, row in ipairs(rows) do
        evidence[#evidence + 1] = mapEvidence(row)
    end

    local auditId = writePoliceAudit('police.evidence.list', actor, 'evidence_item', nil, {
        incidentReportId = incidentReportId,
        subjectCharacterId = subjectCharacterId,
        status = status,
        count = #evidence
    })

    return respond(true, 'OK', 'Beweismittel wurden geladen.', {
        evidence = evidence
    }, {
        limit = limit
    }, auditId)
end

function updatePoliceEvidenceStatus(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensurePoliceAccess(source, policePermissions.evidenceManage, true)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local evidenceId = normalizeId(payload and payload.evidenceId)
    local status = normalizeText(payload and payload.status, nil, 32)
    local reason = normalizeText(payload and payload.reason, nil, policeLimits.maxDescriptionLength)

    if evidenceId == nil or status == nil or not allowedEvidenceStatus[status] then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Statusdaten.', nil, nil, nil)
    end

    local current = MySQL.single.await([[
        SELECT id, evidence_number, metadata, status
        FROM evidence_items
        WHERE id = ?
        LIMIT 1
    ]], {
        evidenceId
    })

    if current == nil then
        return respond(false, 'NOT_FOUND', 'Beweismittel wurde nicht gefunden.', nil, nil, nil)
    end

    local metadata = decodeJson(current.metadata)
    metadata.chain = type(metadata.chain) == 'table' and metadata.chain or {}
    metadata.chain[#metadata.chain + 1] = {
        action = 'status:' .. status,
        reason = reason,
        actorCharacterId = actor.id,
        at = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    MySQL.update.await([[
        UPDATE evidence_items
        SET status = ?,
            metadata = ?
        WHERE id = ?
    ]], {
        status,
        encodeJson(metadata),
        evidenceId
    })

    if status ~= 'stored' then
        MySQL.update.await([[
            UPDATE evidence_stashes
            SET status = ?,
                closed_at = NOW()
            WHERE evidence_stash_code = ?
        ]], {
            status == 'transferred' and 'sealed' or status,
            current.evidence_number
        })
    end

    local auditId = writePoliceAudit('police.evidence.status', actor, 'evidence_item', evidenceId, {
        evidenceNumber = current.evidence_number,
        previousStatus = current.status,
        status = status,
        reason = reason
    })

    return respond(true, 'OK', 'Beweisstatus wurde aktualisiert.', {
        evidence = {
            id = evidenceId,
            evidenceNumber = current.evidence_number,
            previousStatus = current.status,
            status = status
        }
    }, nil, auditId)
end

function collectPoliceDna(source, payload)
    return collectPoliceEvidence(source, payload, 'dna')
end

function collectPoliceFingerprint(source, payload)
    return collectPoliceEvidence(source, payload, 'fingerprint')
end

function collectPoliceShellCasing(source, payload)
    return collectPoliceEvidence(source, payload, 'shell_casing')
end

function collectPoliceBlood(source, payload)
    return collectPoliceEvidence(source, payload, 'blood')
end

exports('police.collectEvidence', collectPoliceEvidence)
exports('police.collectDna', collectPoliceDna)
exports('police.collectFingerprint', collectPoliceFingerprint)
exports('police.collectShellCasing', collectPoliceShellCasing)
exports('police.collectBlood', collectPoliceBlood)
exports('police.listEvidence', listPoliceEvidence)
exports('police.updateEvidenceStatus', updatePoliceEvidenceStatus)
