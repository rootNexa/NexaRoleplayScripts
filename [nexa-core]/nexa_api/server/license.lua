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

local governmentLicensePermissions = {
    ['licenses.issue'] = 'government.licenses.issue',
    ['licenses.revoke'] = 'government.licenses.revoke'
}

local function hasLicensePermission(source, permission)
    if hasPermission(source, permission) then
        return true
    end

    local governmentPermission = governmentLicensePermissions[permission]

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

local function getLicenseType(payload)
    local typeId = normalizeId(payload.licenseTypeId)
    local typeName = validateTypeName(payload.licenseType)

    if typeId == nil and typeName == nil then
        return nil, 'INVALID_INPUT'
    end

    local row

    if typeId ~= nil then
        row = MySQL.single.await([[
            SELECT id, name, label, category, is_active
            FROM license_types
            WHERE id = ? AND is_active = TRUE
            LIMIT 1
        ]], {
            typeId
        })
    else
        row = MySQL.single.await([[
            SELECT id, name, label, category, is_active
            FROM license_types
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

local function mapLicense(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        license_type_id = row.license_type_id,
        license_type = row.license_type,
        license_label = row.license_label,
        category = row.category,
        character_id = row.character_id,
        status = row.status,
        issued_by_character_id = row.issued_by_character_id,
        issued_at = row.issued_at,
        expires_at = row.expires_at
    }
end

local function getLicenseById(licenseId)
    return mapLicense(MySQL.single.await([[
        SELECT l.id, l.license_type_id, lt.name AS license_type, lt.label AS license_label, lt.category,
            l.character_id, l.status, l.issued_by_character_id, l.issued_at, l.expires_at
        FROM licenses l
        INNER JOIN license_types lt ON lt.id = l.license_type_id
        WHERE l.id = ?
        LIMIT 1
    ]], {
        licenseId
    }))
end

local function writeLicenseAudit(action, source, actorCharacterId, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'license',
        severity = 'info',
        actorCharacterId = actorCharacterId,
        targetType = 'license',
        targetId = targetId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

function listLicenseTypes()
    local rows = MySQL.query.await([[
        SELECT id, name, label, category, is_active
        FROM license_types
        WHERE is_active = TRUE
        ORDER BY category ASC, label ASC
    ]])

    return respond(true, 'OK', 'Lizenztypen wurden geladen.', {
        licenseTypes = rows or {}
    }, nil, nil)
end

function issueLicense(source, payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    if not hasLicensePermission(source, 'licenses.issue') then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local actorCharacterId, actorCode = getActiveCharacterId(source)

    if actorCharacterId == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local targetCharacterId = normalizeId(payload.characterId)

    if targetCharacterId == nil or not characterExists(targetCharacterId) then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Lizenzinhaber.', nil, nil, nil)
    end

    local licenseType, typeCode = getLicenseType(payload)

    if licenseType == nil then
        return respond(false, typeCode, 'Lizenztyp wurde nicht gefunden.', nil, nil, nil)
    end

    local expiresAt = validateDateTime(payload.expiresAt)

    if expiresAt == false then
        return respond(false, 'INVALID_INPUT', 'Ungueltiges Ablaufdatum.', nil, nil, nil)
    end

    local existing = MySQL.single.await([[
        SELECT id, license_type_id, character_id, status
        FROM licenses
        WHERE license_type_id = ? AND character_id = ?
        LIMIT 1
    ]], {
        licenseType.id,
        targetCharacterId
    })

    if existing ~= nil and existing.status == 'active' then
        return respond(false, 'CONFLICT', 'Lizenz ist bereits aktiv.', nil, nil, nil)
    end

    local licenseId
    local action = 'issued'
    local oldStatus = existing and existing.status or nil

    local reason = normalizeText(payload.reason)
    local transaction

    if existing == nil then
        transaction = {
            {
                query = [[
                    INSERT INTO licenses (license_type_id, character_id, status, issued_by_character_id, issued_at, expires_at)
                    VALUES (?, ?, 'active', ?, NOW(), ?)
                ]],
                values = {
                    licenseType.id,
                    targetCharacterId,
                    actorCharacterId,
                    expiresAt
                }
            },
            {
                query = [[
                    INSERT INTO license_history (license_id, license_type_id, character_id, actor_character_id, action, old_status, new_status, reason, metadata, created_at)
                    SELECT id, license_type_id, character_id, ?, 'issued', NULL, 'active', ?, ?, NOW()
                    FROM licenses
                    WHERE license_type_id = ? AND character_id = ?
                    LIMIT 1
                ]],
                values = {
                    actorCharacterId,
                    reason,
                    json.encode({
                        source = source
                    }),
                    licenseType.id,
                    targetCharacterId
                }
            }
        }
    else
        licenseId = existing.id
        action = oldStatus == 'revoked' and 'restored' or 'renewed'

        transaction = {
            {
                query = [[
                    UPDATE licenses
                    SET status = 'active', issued_by_character_id = ?, issued_at = NOW(), expires_at = ?
                    WHERE id = ?
                ]],
                values = {
                    actorCharacterId,
                    expiresAt,
                    licenseId
                }
            },
            {
                query = [[
                    INSERT INTO license_history (license_id, license_type_id, character_id, actor_character_id, action, old_status, new_status, reason, metadata, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, NOW())
                ]],
                values = {
                    existing.id,
                    existing.license_type_id,
                    existing.character_id,
                    actorCharacterId,
                    action,
                    oldStatus,
                    reason,
                    json.encode({
                        source = source
                    })
                }
            }
        }
    end

    local success, transactionResult = pcall(function()
        return MySQL.transaction.await(transaction)
    end)

    if not success or transactionResult == false then
        logApi('error', 'Lizenz konnte nicht transaktional ausgestellt werden.', {
            source = source,
            characterId = targetCharacterId,
            licenseType = licenseType.name
        })

        return respond(false, 'DATABASE_ERROR', 'Lizenz konnte nicht ausgestellt werden.', nil, nil, nil)
    end

    licenseId = licenseId or MySQL.scalar.await([[
        SELECT id
        FROM licenses
        WHERE license_type_id = ? AND character_id = ?
        LIMIT 1
    ]], {
        licenseType.id,
        targetCharacterId
    })

    if licenseId == nil then
        return respond(false, 'DATABASE_ERROR', 'Lizenz konnte nicht ausgestellt werden.', nil, nil, nil)
    end

    local license = getLicenseById(licenseId)

    local auditId = writeLicenseAudit('license.issue', source, actorCharacterId, licenseId, {
        source = source,
        characterId = targetCharacterId,
        licenseType = licenseType.name,
        action = action
    })

    logApi('info', 'Lizenz wurde ausgestellt.', {
        source = source,
        licenseId = licenseId,
        characterId = targetCharacterId
    })

    return respond(true, existing == nil and 'CREATED' or 'UPDATED', 'Lizenz wurde ausgestellt.', {
        license = license
    }, nil, auditId)
end

function revokeLicense(source, payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    if not hasLicensePermission(source, 'licenses.revoke') then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local actorCharacterId, actorCode = getActiveCharacterId(source)

    if actorCharacterId == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local licenseId = normalizeId(payload.licenseId)

    if licenseId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenz.', nil, nil, nil)
    end

    local license = getLicenseById(licenseId)

    if license == nil then
        return respond(false, 'NOT_FOUND', 'Lizenz wurde nicht gefunden.', nil, nil, nil)
    end

    if license.status ~= 'active' and license.status ~= 'suspended' then
        return respond(false, 'CONFLICT', 'Lizenz kann in diesem Status nicht entzogen werden.', nil, nil, nil)
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > 255 then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Entzugsgrund.', nil, nil, nil)
    end

    local success, transactionResult = pcall(function()
        return MySQL.transaction.await({
            {
                query = "UPDATE licenses SET status = 'revoked' WHERE id = ? AND status IN ('active','suspended')",
                values = {
                    licenseId
                }
            },
            {
                query = [[
                    INSERT INTO license_history (license_id, license_type_id, character_id, actor_character_id, action, old_status, new_status, reason, metadata, created_at)
                    VALUES (?, ?, ?, ?, 'revoked', ?, 'revoked', ?, ?, NOW())
                ]],
                values = {
                    license.id,
                    license.license_type_id,
                    license.character_id,
                    actorCharacterId,
                    license.status,
                    reason,
                    json.encode({
                        source = source
                    })
                }
            }
        })
    end)

    if not success or transactionResult == false then
        logApi('error', 'Lizenz konnte nicht transaktional entzogen werden.', {
            source = source,
            licenseId = licenseId,
            reason = reason
        })

        return respond(false, 'DATABASE_ERROR', 'Lizenz konnte nicht entzogen werden.', nil, nil, nil)
    end

    local auditId = writeLicenseAudit('license.revoke', source, actorCharacterId, licenseId, {
        source = source,
        reason = reason,
        oldStatus = license.status,
        newStatus = 'revoked'
    })

    logApi('warning', 'Lizenz wurde entzogen.', {
        source = source,
        licenseId = licenseId,
        reason = reason
    })

    return respond(true, 'UPDATED', 'Lizenz wurde entzogen.', {
        license = getLicenseById(licenseId)
    }, nil, auditId)
end

function validateLicense(payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)

    if characterId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Lizenzinhaber.', nil, nil, nil)
    end

    local licenseType, typeCode = getLicenseType(payload)

    if licenseType == nil then
        return respond(false, typeCode, 'Lizenztyp wurde nicht gefunden.', nil, nil, nil)
    end

    local license = mapLicense(MySQL.single.await([[
        SELECT l.id, l.license_type_id, lt.name AS license_type, lt.label AS license_label, lt.category,
            l.character_id, l.status, l.issued_by_character_id, l.issued_at, l.expires_at
        FROM licenses l
        INNER JOIN license_types lt ON lt.id = l.license_type_id
        WHERE l.character_id = ? AND l.license_type_id = ?
        LIMIT 1
    ]], {
        characterId,
        licenseType.id
    }))

    if license == nil then
        return respond(false, 'NOT_FOUND', 'Lizenz wurde nicht gefunden.', nil, nil, nil)
    end

    local isExpired = license.expires_at ~= nil and MySQL.scalar.await('SELECT NOW() > ? AS expired', {
        license.expires_at
    }) == 1
    local isValid = license.status == 'active' and not isExpired

    if isExpired and license.status == 'active' then
        local success, transactionResult = pcall(function()
            return MySQL.transaction.await({
                {
                    query = "UPDATE licenses SET status = 'expired' WHERE id = ? AND status = 'active'",
                    values = {
                        license.id
                    }
                },
                {
                    query = [[
                        INSERT INTO license_history (license_id, license_type_id, character_id, actor_character_id, action, old_status, new_status, reason, metadata, created_at)
                        VALUES (?, ?, ?, NULL, 'expired', 'active', 'expired', 'Automatisch abgelaufen.', ?, NOW())
                    ]],
                    values = {
                        license.id,
                        license.license_type_id,
                        license.character_id,
                        json.encode({
                            source = 'nexa_api'
                        })
                    }
                }
            })
        end)

        if not success or transactionResult == false then
            return respond(false, 'DATABASE_ERROR', 'Lizenzstatus konnte nicht aktualisiert werden.', nil, nil, nil)
        end

        license.status = 'expired'
    end

    return respond(true, 'OK', isValid and 'Lizenz ist gueltig.' or 'Lizenz ist nicht gueltig.', {
        license = license,
        isValid = isValid
    }, nil, nil)
end

function getLicenseHistory(payload)
    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    local licenseId = normalizeId(payload.licenseId)

    if licenseId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Lizenz.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT id, license_id, license_type_id, character_id, actor_character_id, action, old_status, new_status, reason, metadata, created_at
        FROM license_history
        WHERE license_id = ?
        ORDER BY created_at DESC
        LIMIT 50
    ]], {
        licenseId
    })

    return respond(true, 'OK', 'Lizenzhistorie wurde geladen.', {
        history = rows or {}
    }, {
        limit = 50
    }, nil)
end

exports('listLicenseTypes', listLicenseTypes)
exports('license.listTypes', listLicenseTypes)
exports('issueLicense', issueLicense)
exports('license.issue', issueLicense)
exports('revokeLicense', revokeLicense)
exports('license.revoke', revokeLicense)
exports('validateLicense', validateLicense)
exports('license.validate', validateLicense)
exports('getLicenseHistory', getLicenseHistory)
exports('license.history', getLicenseHistory)
