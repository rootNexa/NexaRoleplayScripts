local function banResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Ban-System-Anfrage konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isBanSystemEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.banSystemFeatureFlag)
end

local function writeBanAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logBanInfo(message, metadata)
    exports.nexa_logs:info(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function logBanWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function validateSource(source)
    local valid, code, normalizedSource = NexaAnticheatValidateSource(source)

    if not valid then
        return false, code, nil
    end

    return true, 'OK', normalizedSource
end

local function sanitizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local sanitized = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, maxLength or 128)

    if sanitized == '' then
        return nil
    end

    return sanitized
end

local function getIdentifierType(identifier)
    if type(identifier) ~= 'string' then
        return 'unknown'
    end

    local separator = identifier:find(':', 1, true)

    if separator == nil then
        return 'unknown'
    end

    return identifier:sub(1, separator - 1)
end

local function isAllowedIdentifier(identifier)
    local identifierType = getIdentifierType(identifier)
    return NexaAnticheatServer.banSystem.allowedIdentifierTypes[identifierType] == true
end

local function getSourceIdentifiers(source)
    local identifiers = {}
    local count = GetNumPlayerIdentifiers(source)

    for index = 0, count - 1 do
        local identifier = GetPlayerIdentifier(source, index)

        if type(identifier) == 'string' and identifier ~= '' and isAllowedIdentifier(identifier) then
            identifiers[#identifiers + 1] = identifier
        end
    end

    return identifiers
end

local function getPrimaryIdentifier(source)
    local license = GetPlayerIdentifierByType(source, 'license')

    if type(license) == 'string' and license ~= '' and isAllowedIdentifier(license) then
        return license
    end

    local identifiers = getSourceIdentifiers(source)
    return identifiers[1]
end

local function hasAnyPermission(source, permissions)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false, nil
    end

    for permission, enabled in pairs(permissions or {}) do
        if enabled == true then
            local ok, allowed = pcall(function()
                return exports.nexa_permissions:has(source, permission)
            end)

            if ok and allowed == true then
                return true, permission
            end
        end
    end

    return false, nil
end

local function hasBanTypePermission(source, banType)
    local broadAllowed, broadPermission = hasAnyPermission(source, {
        ['admin.ban'] = true,
        ['anticheat.ban.manual'] = true
    })

    if broadAllowed then
        return true, broadPermission
    end

    if banType == 'temporary' then
        return hasAnyPermission(source, {
            ['admin.ban.temporary'] = true
        })
    end

    if banType == 'permanent' then
        return hasAnyPermission(source, {
            ['admin.ban.permanent'] = true
        })
    end

    return false, nil
end

local function syncPlayerIdentifiers(playerId, identifiers)
    for _, identifier in ipairs(identifiers or {}) do
        if isAllowedIdentifier(identifier) then
            MySQL.insert.await([[
                INSERT INTO player_identifiers (player_id, type, value, first_seen_at, last_seen_at)
                VALUES (?, ?, ?, NOW(), NOW())
                ON DUPLICATE KEY UPDATE player_id = VALUES(player_id), last_seen_at = NOW()
            ]], {
                playerId,
                getIdentifierType(identifier),
                identifier
            })
        end
    end
end

local function getPlayerByIdentifiers(identifiers)
    if type(identifiers) ~= 'table' or #identifiers == 0 then
        return nil
    end

    local placeholders = {}
    local params = {}

    for index, identifier in ipairs(identifiers) do
        placeholders[index] = '?'
        params[index] = identifier
    end

    return MySQL.single.await(([[ 
        SELECT p.id, p.primary_identifier, p.display_name, p.is_banned
        FROM players p
        INNER JOIN player_identifiers pi ON pi.player_id = p.id
        WHERE pi.value IN (%s)
        LIMIT 1
    ]]):format(table.concat(placeholders, ',')), params)
end

local function ensurePlayerFromSource(source)
    local identifiers = getSourceIdentifiers(source)
    local primaryIdentifier = getPrimaryIdentifier(source)

    if primaryIdentifier == nil or #identifiers == 0 then
        return nil, 'IDENTIFIERS_UNAVAILABLE', nil
    end

    local player = getPlayerByIdentifiers(identifiers)

    if player == nil then
        local playerId = MySQL.insert.await([[
            INSERT INTO players (primary_identifier, display_name, first_joined_at, last_seen_at, created_at, updated_at)
            VALUES (?, ?, NOW(), NOW(), NOW(), NOW())
        ]], {
            primaryIdentifier,
            GetPlayerName(source)
        })

        player = {
            id = playerId,
            primary_identifier = primaryIdentifier,
            display_name = GetPlayerName(source),
            is_banned = 0
        }
    else
        MySQL.update.await('UPDATE players SET display_name = ?, last_seen_at = NOW(), updated_at = NOW() WHERE id = ?', {
            GetPlayerName(source),
            player.id
        })
    end

    syncPlayerIdentifiers(player.id, identifiers)

    return player, 'OK', identifiers
end

local function getPlayerById(playerId)
    local normalizedId = tonumber(playerId)

    if normalizedId == nil or normalizedId <= 0 then
        return nil
    end

    return MySQL.single.await('SELECT id, primary_identifier, display_name, is_banned FROM players WHERE id = ? LIMIT 1', {
        normalizedId
    })
end

local function getPlayerByIdentifier(identifier)
    if type(identifier) ~= 'string' or not isAllowedIdentifier(identifier) then
        return nil
    end

    return MySQL.single.await([[
        SELECT p.id, p.primary_identifier, p.display_name, p.is_banned
        FROM players p
        INNER JOIN player_identifiers pi ON pi.player_id = p.id
        WHERE pi.value = ?
        LIMIT 1
    ]], {
        identifier
    })
end

local function resolveTarget(payload)
    if type(payload) ~= 'table' then
        return nil, 'INVALID_INPUT', nil
    end

    if payload.targetSource ~= nil then
        local valid, code, normalizedTarget = validateSource(payload.targetSource)

        if not valid then
            return nil, code, nil
        end

        local player, playerCode, identifiers = ensurePlayerFromSource(normalizedTarget)
        return player, playerCode, identifiers
    end

    if payload.playerId ~= nil then
        local player = getPlayerById(payload.playerId)

        if player ~= nil then
            return player, 'OK', nil
        end
    end

    if payload.identifier ~= nil then
        local player = getPlayerByIdentifier(payload.identifier)

        if player ~= nil then
            return player, 'OK', { payload.identifier }
        end
    end

    return nil, 'PLAYER_NOT_FOUND', nil
end

local function normalizeBanType(payload)
    local banType = sanitizeText(type(payload) == 'table' and payload.banType or nil, 32)

    if banType ~= nil then
        banType = banType:lower()
    end

    if banType == nil and tonumber(payload and payload.durationMinutes) ~= nil then
        banType = 'temporary'
    end

    if banType == nil then
        banType = 'permanent'
    end

    if banType ~= 'temporary' and banType ~= 'permanent' then
        return nil
    end

    return banType
end

local function calculateExpiresAt(payload, banType)
    if banType == 'permanent' then
        return nil, 'OK', nil
    end

    local minutes = tonumber(payload and payload.durationMinutes)

    if minutes == nil then
        return nil, 'INVALID_DURATION', nil
    end

    minutes = math.floor(minutes)

    if minutes < NexaAnticheatServer.banSystem.minTempBanMinutes then
        return nil, 'INVALID_DURATION', nil
    end

    local maxMinutes = (NexaAnticheatServer.banSystem.maxTempBanDays or 365) * 24 * 60

    if minutes > maxMinutes then
        return nil, 'INVALID_DURATION', nil
    end

    return os.date('!%Y-%m-%d %H:%M:%S', os.time() + (minutes * 60)), 'OK', minutes
end

local function buildReviewStatus()
    return {
        appealStatus = 'prepared',
        reviewStatus = NexaAnticheatServer.banSystem.defaultReviewStatus,
        reviewStatuses = NexaAnticheatServer.banSystem.reviewStatuses
    }
end

local function normalizeHistoryLimit(limit)
    local configuredLimit = NexaAnticheatServer.banSystem.historyLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

function createManualBan(actorSource, payload)
    if not isBanSystemEnabled() then
        return banResponse(false, 'FEATURE_DISABLED', 'Ban-System ist deaktiviert.', nil, nil, nil)
    end

    local actorValid, actorCode, normalizedActor = validateSource(actorSource)

    if not actorValid then
        return banResponse(false, actorCode, 'Ungueltige Admin-Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedActor, 'anticheat.ban.manual')

    if not limited then
        return banResponse(false, limitCode, 'Ban-System wurde rate-limited.', nil, nil, nil)
    end

    local reason = sanitizeText(type(payload) == 'table' and payload.reason or nil, NexaAnticheatServer.banSystem.maxReasonLength)

    if reason == nil then
        return banResponse(false, 'INVALID_INPUT', 'Ban-Grund ist erforderlich.', nil, nil, nil)
    end

    local banType = normalizeBanType(payload)

    if banType == nil then
        return banResponse(false, 'INVALID_INPUT', 'Ungueltiger Ban-Typ.', nil, nil, nil)
    end

    local allowed, permission = hasBanTypePermission(normalizedActor, banType)

    if not allowed then
        local auditId = writeBanAudit('ban.manual.denied', 'warning', {
            actorSource = normalizedActor,
            banType = banType,
            reason = 'NO_PERMISSION'
        })

        logBanWarning('Manueller Ban wurde ohne passende Permission verweigert.', {
            actorSource = normalizedActor,
            banType = banType,
            auditId = auditId
        })

        return banResponse(false, 'NO_PERMISSION', 'Ban-Aktion wurde mangels Permission verweigert.', nil, {
            automaticAnticheatBan = false
        }, auditId)
    end

    local target, targetCode, identifiers = resolveTarget(payload)

    if target == nil then
        return banResponse(false, targetCode, 'Ban-Ziel konnte nicht aufgeloest werden.', nil, nil, nil)
    end

    local expiresAt, expiresCode, durationMinutes = calculateExpiresAt(payload, banType)

    if expiresCode ~= 'OK' then
        return banResponse(false, expiresCode, 'Ungueltige Ban-Dauer.', nil, nil, nil)
    end

    local actorPlayer = ensurePlayerFromSource(normalizedActor)
    local actorPlayerId = actorPlayer and actorPlayer.id or nil

    MySQL.query.await('START TRANSACTION')

    local transactionSuccess, transactionResult = pcall(function()
        MySQL.update.await('UPDATE bans SET is_active = 0, revoked_at = NOW() WHERE player_id = ? AND is_active = 1', {
            target.id
        })

        local createdBanId = MySQL.insert.await([[
            INSERT INTO bans (player_id, banned_by_player_id, reason, expires_at, is_active, created_at)
            VALUES (?, ?, ?, ?, 1, NOW())
        ]], {
            target.id,
            actorPlayerId,
            reason,
            expiresAt
        })

        if createdBanId == nil or tonumber(createdBanId) == nil then
            error('BAN_INSERT_FAILED', 0)
        end

        local updated = MySQL.update.await('UPDATE players SET is_banned = 1, updated_at = NOW() WHERE id = ?', {
            target.id
        })

        if updated ~= 1 then
            error('PLAYER_BAN_FLAG_FAILED', 0)
        end

        return createdBanId
    end)

    if not transactionSuccess then
        MySQL.query.await('ROLLBACK')

        local auditId = writeBanAudit('ban.manual.failed', 'error', {
            actorSource = normalizedActor,
            playerId = target.id,
            banType = banType,
            reason = 'DATABASE_ERROR'
        })

        logBanWarning('Manueller Ban konnte nicht atomar erstellt werden.', {
            actorSource = normalizedActor,
            playerId = target.id,
            banType = banType,
            auditId = auditId
        })

        return banResponse(false, 'DATABASE_ERROR', 'Ban konnte nicht atomar erstellt werden.', nil, {
            automaticAnticheatBan = false
        }, auditId)
    end

    MySQL.query.await('COMMIT')

    local banId = transactionResult

    local data = {
        banId = banId,
        playerId = target.id,
        targetDisplayName = target.display_name,
        banType = banType,
        reason = reason,
        expiresAt = expiresAt,
        durationMinutes = durationMinutes,
        identifiersLinked = identifiers ~= nil,
        identifierTypes = {},
        permission = permission,
        automaticAnticheatBan = false,
        review = buildReviewStatus()
    }

    for _, identifier in ipairs(identifiers or {}) do
        data.identifierTypes[#data.identifierTypes + 1] = getIdentifierType(identifier)
    end

    local auditId = writeBanAudit('ban.manual.created', 'warning', data)
    data.auditId = auditId

    logBanWarning('Manueller Ban wurde erstellt.', {
        actorSource = normalizedActor,
        playerId = target.id,
        banId = banId,
        banType = banType,
        auditId = auditId
    })

    return banResponse(true, 'OK', 'Ban wurde manuell und auditierbar erstellt.', data, {
        temporary = banType == 'temporary',
        permanent = banType == 'permanent',
        automaticAnticheatBan = false
    }, auditId)
end

function checkBanForSource(source)
    if not isBanSystemEnabled() then
        return banResponse(false, 'FEATURE_DISABLED', 'Ban-System ist deaktiviert.', nil, nil, nil)
    end

    local valid, code, normalizedSource = validateSource(source)

    if not valid then
        return banResponse(false, code, 'Ungueltige Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.ban.check')

    if not limited then
        return banResponse(false, limitCode, 'Ban-Pruefung wurde rate-limited.', nil, nil, nil)
    end

    local identifiers = getSourceIdentifiers(normalizedSource)
    local player = getPlayerByIdentifiers(identifiers)

    if player == nil then
        return banResponse(true, 'OK', 'Keine Ban-Verknuepfung gefunden.', {
            banned = false,
            identifiersChecked = #identifiers
        }, nil, nil)
    end

    syncPlayerIdentifiers(player.id, identifiers)

    local ban = MySQL.single.await([[
        SELECT id, player_id, reason, expires_at, is_active, created_at
        FROM bans
        WHERE player_id = ?
          AND is_active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC
        LIMIT 1
    ]], {
        player.id
    })

    if ban == nil then
        MySQL.update.await('UPDATE players SET is_banned = 0, updated_at = NOW() WHERE id = ? AND is_banned = 1', {
            player.id
        })

        return banResponse(true, 'OK', 'Kein aktiver Ban gefunden.', {
            banned = false,
            playerId = player.id,
            identifiersChecked = #identifiers
        }, nil, nil)
    end

    local data = {
        banned = true,
        banId = ban.id,
        playerId = player.id,
        reason = ban.reason,
        expiresAt = ban.expires_at,
        permanent = ban.expires_at == nil,
        identifiersChecked = #identifiers,
        review = buildReviewStatus()
    }
    local auditId = writeBanAudit('ban.join.blocked', 'warning', data)
    data.auditId = auditId

    logBanWarning('Join wurde wegen aktivem Ban abgelehnt.', {
        source = normalizedSource,
        playerId = player.id,
        banId = ban.id,
        auditId = auditId
    })

    return banResponse(true, 'BANNED', 'Aktiver Ban gefunden.', data, {
        automaticAnticheatBan = false
    }, auditId)
end

function getBanHistory(payload)
    if not isBanSystemEnabled() then
        return banResponse(false, 'FEATURE_DISABLED', 'Ban-System ist deaktiviert.', nil, nil, nil)
    end

    local source = type(payload) == 'table' and payload.source or nil
    local valid, code, normalizedSource = validateSource(source)

    if not valid then
        return banResponse(false, code, 'Ungueltige Admin-Source.', nil, nil, nil)
    end

    local limited, limitCode = NexaAnticheatCheckRateLimit(normalizedSource, 'anticheat.ban.history')

    if not limited then
        return banResponse(false, limitCode, 'Ban-Historie wurde rate-limited.', nil, nil, nil)
    end

    local allowed = hasAnyPermission(normalizedSource, NexaAnticheatServer.banSystem.historyPermissions)

    if not allowed then
        local auditId = writeBanAudit('ban.history.denied', 'warning', {
            actorSource = normalizedSource,
            reason = 'NO_PERMISSION'
        })

        return banResponse(false, 'NO_PERMISSION', 'Ban-Historie wurde mangels Permission verweigert.', nil, nil, auditId)
    end

    local limit = normalizeHistoryLimit(type(payload) == 'table' and payload.limit or nil)
    local targetPlayerId = tonumber(type(payload) == 'table' and payload.playerId or nil)
    local rows

    if targetPlayerId ~= nil and targetPlayerId > 0 then
        rows = MySQL.query.await([[
            SELECT id, player_id, banned_by_player_id, reason, expires_at, is_active, created_at, revoked_at
            FROM bans
            WHERE player_id = ?
            ORDER BY created_at DESC
            LIMIT ?
        ]], {
            targetPlayerId,
            limit
        })
    else
        rows = MySQL.query.await([[
            SELECT id, player_id, banned_by_player_id, reason, expires_at, is_active, created_at, revoked_at
            FROM bans
            ORDER BY created_at DESC
            LIMIT ?
        ]], {
            limit
        })
    end

    local auditId = writeBanAudit('ban.history.read', 'info', {
        actorSource = normalizedSource,
        playerId = targetPlayerId,
        count = #(rows or {}),
        limit = limit
    })

    logBanInfo('Ban-Historie wurde gelesen.', {
        actorSource = normalizedSource,
        playerId = targetPlayerId,
        count = #(rows or {}),
        auditId = auditId
    })

    return banResponse(true, 'OK', 'Ban-Historie wurde gelesen.', rows or {}, {
        count = #(rows or {}),
        review = buildReviewStatus()
    }, auditId)
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not isBanSystemEnabled() then
        return
    end

    if deferrals == nil then
        return
    end

    deferrals.defer()

    local result = checkBanForSource(source)

    if result and result.success and result.code == 'BANNED' then
        local reason = result.data and result.data.reason or 'Ban aktiv'
        deferrals.done((NexaAnticheatServer.banSystem.joinMessage):format(reason))
        return
    end

    deferrals.done()
end)

exports('createManualBan', createManualBan)
exports('checkBanForSource', checkBanForSource)
exports('getBanHistory', getBanHistory)
