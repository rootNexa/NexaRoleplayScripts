local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function logApi(level, message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs[level](NEXA_API.resourceName, message, metadata)
end

local function normalizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return nil
    end

    return trimmed
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function validateTypeName(value)
    local normalized = normalizeText(value)

    if normalized == nil or #normalized > 64 or normalized:find('[^%w_%-]') ~= nil then
        return nil
    end

    return normalized
end

local function validateDateTime(value)
    if value == nil then
        return nil
    end

    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$') then
        return false
    end

    return value
end

local function encodeMetadata(value)
    if value == nil then
        return nil
    end

    if type(value) ~= 'table' then
        return false
    end

    local encoded = json.encode(value)

    if encoded == nil or #encoded > 4096 then
        return false
    end

    return encoded
end

local function getActiveCharacterId(source)
    local response = getActiveCharacter(source)

    if not response.success or response.data == nil or response.data.character == nil then
        return nil, response.code
    end

    return response.data.character.id, 'OK'
end

local function hasPermission(source, permission)
    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local governmentDocumentPermissions = {
    ['documents.issue'] = 'government.documents.issue',
    ['documents.revoke'] = 'government.documents.revoke'
}

local function hasWeazelPressPermission(source, permission, payload)
    if permission ~= 'documents.issue' or type(payload) ~= 'table' then
        return false
    end

    if payload.documentType ~= 'press_card' or payload.documentTypeId ~= nil then
        return false
    end

    if type(hasFactionPermission) ~= 'function' then
        return false
    end

    local result = hasFactionPermission(source, {
        factionName = 'weazel',
        permission = 'weazel.press.issue'
    })

    return type(result) == 'table' and result.success == true
end

local function hasDocumentPermission(source, permission, payload)
    if hasPermission(source, permission) then
        return true
    end

    if hasWeazelPressPermission(source, permission, payload) then
        return true
    end

    local governmentPermission = governmentDocumentPermissions[permission]

    if governmentPermission == nil or type(hasFactionPermission) ~= 'function' then
        return false
    end

    local result = hasFactionPermission(source, {
        factionName = 'government',
        permission = governmentPermission
    })

    return type(result) == 'table' and result.success == true
end

local function characterExists(characterId)
    return MySQL.scalar.await([[
        SELECT id
        FROM characters
        WHERE id = ? AND is_active = TRUE AND deleted_at IS NULL
        LIMIT 1
    ]], {
        characterId
    }) ~= nil
end

local function getDocumentType(payload)
    local typeId = normalizeId(payload.documentTypeId)
    local typeName = validateTypeName(payload.documentType)

    if typeId == nil and typeName == nil then
        return nil, 'INVALID_INPUT'
    end

    local row

    if typeId ~= nil then
        row = MySQL.single.await([[
            SELECT id, name, label, requires_signature, default_valid_days, is_active
            FROM document_types
            WHERE id = ? AND is_active = TRUE
            LIMIT 1
        ]], {
            typeId
        })
    else
        row = MySQL.single.await([[
            SELECT id, name, label, requires_signature, default_valid_days, is_active
            FROM document_types
            WHERE name = ? AND is_active = TRUE
            LIMIT 1
        ]], {
            typeName
        })
    end

    if row == nil then
        return nil, 'NOT_FOUND'
    end

    return row, 'OK'
end

local function mapDocument(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        document_number = row.document_number,
        document_type_id = row.document_type_id,
        document_type = row.document_type,
        document_label = row.document_label,
        owner_character_id = row.owner_character_id,
        issued_by_character_id = row.issued_by_character_id,
        status = row.status,
        data = row.data ~= nil and json.decode(row.data) or nil,
        issued_at = row.issued_at,
        expires_at = row.expires_at
    }
end

local function getDocumentById(documentId)
    return mapDocument(MySQL.single.await([[
        SELECT d.id, d.document_number, d.document_type_id, dt.name AS document_type, dt.label AS document_label,
            d.owner_character_id, d.issued_by_character_id, d.status, d.data, d.issued_at, d.expires_at
        FROM documents d
        INNER JOIN document_types dt ON dt.id = d.document_type_id
        WHERE d.id = ?
        LIMIT 1
    ]], {
        documentId
    }))
end

local function writeDocumentAudit(action, source, actorCharacterId, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'document',
        severity = 'info',
        actorCharacterId = actorCharacterId,
        targetType = 'document',
        targetId = targetId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function buildDocumentNumber()
    return ('ND%s%04d'):format(os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function generateDocumentNumber()
    for _ = 1, 10 do
        local documentNumber = buildDocumentNumber()
        local existing = MySQL.scalar.await('SELECT id FROM documents WHERE document_number = ? LIMIT 1', {
            documentNumber
        })

        if existing == nil then
            return documentNumber
        end
    end

    return nil
end

local function calculateExpiry(documentType, explicitExpiresAt)
    local validDate = validateDateTime(explicitExpiresAt)

    if validDate == false then
        return false
    end

    if validDate ~= nil then
        return validDate
    end

    local days = tonumber(documentType.default_valid_days)

    if days == nil or days <= 0 then
        return nil
    end

    return os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
end

function listDocumentTypes()
    local rows = MySQL.query.await([[
        SELECT id, name, label, requires_signature, default_valid_days, is_active
        FROM document_types
        WHERE is_active = TRUE
        ORDER BY label ASC
    ]])

    return respond(true, 'OK', 'Dokumenttypen wurden geladen.', {
        documentTypes = rows or {}
    }, nil, nil)
end

function issueDocument(source, payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    if not hasDocumentPermission(source, 'documents.issue', payload) then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local actorCharacterId, actorCode = getActiveCharacterId(source)

    if actorCharacterId == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local ownerCharacterId = normalizeId(payload.ownerCharacterId)

    if ownerCharacterId == nil or not characterExists(ownerCharacterId) then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Dokumentinhaber.', nil, nil, nil)
    end

    local documentType, typeCode = getDocumentType(payload)

    if documentType == nil then
        return respond(false, typeCode, 'Dokumenttyp wurde nicht gefunden.', nil, nil, nil)
    end

    local metadata = encodeMetadata(payload.data or {})

    if metadata == false then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    local expiresAt = calculateExpiry(documentType, payload.expiresAt)

    if expiresAt == false then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Ablaufdatum.', nil, nil, nil)
    end

    local documentNumber = generateDocumentNumber()

    if documentNumber == nil then
        return respond(false, 'CONFLICT', 'Dokumentnummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local transaction = {
        {
            query = [[
                INSERT INTO documents (document_number, document_type_id, owner_character_id, issued_by_character_id, status, data, issued_at, expires_at)
                VALUES (?, ?, ?, ?, 'valid', ?, NOW(), ?)
            ]],
            values = {
                documentNumber,
                documentType.id,
                ownerCharacterId,
                actorCharacterId,
                metadata,
                expiresAt
            }
        }
    }

    -- Signaturpflichtige Dokumente duerfen nicht ohne Signatur persistiert werden.
    if documentType.requires_signature == true or documentType.requires_signature == 1 then
        transaction[#transaction + 1] = {
            query = [[
                INSERT INTO document_signatures (document_id, signer_character_id, signature_hash, signed_at, metadata)
                SELECT id, ?, SHA2(CONCAT(document_number, ':', ?, ':', NOW()), 256), NOW(), ?
                FROM documents
                WHERE document_number = ?
                LIMIT 1
            ]],
            values = {
                actorCharacterId,
                actorCharacterId,
                json.encode({
                    source = source,
                    reason = 'issue'
                }),
                documentNumber
            }
        }
    end

    local success, transactionResult = pcall(function()
        return MySQL.transaction.await(transaction)
    end)

    if not success or transactionResult == false then
        logApi('error', 'Dokument konnte nicht transaktional ausgestellt werden.', {
            source = source,
            ownerCharacterId = ownerCharacterId,
            documentType = documentType.name
        })

        return respond(false, 'DATABASE_ERROR', 'Dokument konnte nicht ausgestellt werden.', nil, nil, nil)
    end

    local documentId = MySQL.scalar.await('SELECT id FROM documents WHERE document_number = ? LIMIT 1', {
        documentNumber
    })

    local auditId = writeDocumentAudit('document.issue', source, actorCharacterId, documentId, {
        source = source,
        ownerCharacterId = ownerCharacterId,
        documentType = documentType.name,
        documentNumber = documentNumber
    })

    logApi('info', 'Dokument wurde ausgestellt.', {
        source = source,
        documentId = documentId,
        ownerCharacterId = ownerCharacterId
    })

    return respond(true, 'CREATED', 'Dokument wurde ausgestellt.', {
        document = getDocumentById(documentId)
    }, nil, auditId)
end

function revokeDocument(source, payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    if not hasDocumentPermission(source, 'documents.revoke', payload) then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local actorCharacterId, actorCode = getActiveCharacterId(source)

    if actorCharacterId == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local documentId = normalizeId(payload.documentId)

    if documentId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Dokument.', nil, nil, nil)
    end

    local existing = getDocumentById(documentId)

    if existing == nil then
        return respond(false, 'NOT_FOUND', 'Dokument wurde nicht gefunden.', nil, nil, nil)
    end

    if existing.status ~= 'valid' then
        return respond(false, 'CONFLICT', 'Dokument ist nicht gueltig.', nil, nil, nil)
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > 255 then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Widerrufsgrund.', nil, nil, nil)
    end

    local updated = MySQL.update.await("UPDATE documents SET status = 'revoked' WHERE id = ? AND status = 'valid'", {
        documentId
    })

    if updated == nil or updated < 1 then
        return respond(false, 'DATABASE_ERROR', 'Dokument konnte nicht widerrufen werden.', nil, nil, nil)
    end

    local auditId = writeDocumentAudit('document.revoke', source, actorCharacterId, documentId, {
        source = source,
        reason = reason,
        oldStatus = existing.status,
        newStatus = 'revoked'
    })

    logApi('warning', 'Dokument wurde widerrufen.', {
        source = source,
        documentId = documentId,
        reason = reason
    })

    return respond(true, 'UPDATED', 'Dokument wurde widerrufen.', {
        document = getDocumentById(documentId)
    }, nil, auditId)
end

function validateDocument(payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    local documentId = normalizeId(payload.documentId)
    local documentNumber = normalizeText(payload.documentNumber)

    if documentId == nil and (documentNumber == nil or #documentNumber > 32) then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Dokument.', nil, nil, nil)
    end

    local document

    if documentId ~= nil then
        document = getDocumentById(documentId)
    else
        document = mapDocument(MySQL.single.await([[
            SELECT d.id, d.document_number, d.document_type_id, dt.name AS document_type, dt.label AS document_label,
                d.owner_character_id, d.issued_by_character_id, d.status, d.data, d.issued_at, d.expires_at
            FROM documents d
            INNER JOIN document_types dt ON dt.id = d.document_type_id
            WHERE d.document_number = ?
            LIMIT 1
        ]], {
            documentNumber
        }))
    end

    if document == nil then
        return respond(false, 'NOT_FOUND', 'Dokument wurde nicht gefunden.', nil, nil, nil)
    end

    local isExpired = document.expires_at ~= nil and MySQL.scalar.await('SELECT NOW() > ? AS expired', {
        document.expires_at
    }) == 1
    local isValid = document.status == 'valid' and not isExpired

    if isExpired and document.status == 'valid' then
        MySQL.update.await("UPDATE documents SET status = 'expired' WHERE id = ? AND status = 'valid'", {
            document.id
        })

        document.status = 'expired'
    end

    return respond(true, 'OK', isValid and 'Dokument ist gueltig.' or 'Dokument ist nicht gueltig.', {
        document = document,
        isValid = isValid
    }, nil, nil)
end

math.randomseed(os.time())

exports('listDocumentTypes', listDocumentTypes)
exports('document.listTypes', listDocumentTypes)
exports('issueDocument', issueDocument)
exports('document.issue', issueDocument)
exports('revokeDocument', revokeDocument)
exports('document.revoke', revokeDocument)
exports('validateDocument', validateDocument)
exports('document.validate', validateDocument)
