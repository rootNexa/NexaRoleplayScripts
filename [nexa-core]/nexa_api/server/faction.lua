local factionLimits = {
    maxNameLength = 64,
    maxCallsignLength = 16,
    maxReasonLength = 128,
    maxMembersLimit = 50,
    maxAccountsLimit = 10,
    maxTransferAmount = 100000000
}

local officialFactionNames = {
    lspd = true,
    ems = true,
    government = true,
    weazel = true
}

local factionPermissions = {
    viewMembers = 'faction.members.view',
    manageMembers = 'faction.members.manage',
    toggleDuty = 'faction.duty.toggle',
    setOwnCallsign = 'faction.callsign.self',
    manageCallsigns = 'faction.callsign.manage',
    viewAccounts = 'faction.accounts.view',
    manageAccounts = 'faction.accounts.manage',
    transferAccounts = 'faction.accounts.transfer',
    governmentManage = 'government.members.manage'
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

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number < 1 or number > factionLimits.maxTransferAmount then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
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

local function decodePermissions(value)
    if value == nil then
        return {}
    end

    if type(value) == 'table' then
        return value
    end

    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local decoded = json.decode(value)

    if type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

local function permissionsContain(permissions, permission)
    if permissions[permission] == true then
        return true
    end

    for _, value in pairs(permissions) do
        if value == permission then
            return true
        end
    end

    return false
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function hasGlobalPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function writeFactionAudit(action, actor, targetType, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'faction',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = targetType,
        targetId = targetId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function buildOfficialFactionWhere(columnName)
    return ("%s IN ('lspd', 'ems', 'government', 'weazel')"):format(columnName)
end

local function getFactionByReference(payload)
    local factionId = normalizeId(payload and payload.factionId)

    if factionId ~= nil then
        return MySQL.single.await(([[ 
            SELECT id, name, label, faction_type, status, metadata, created_at
            FROM factions
            WHERE id = ? AND status = 'active' AND %s
            LIMIT 1
        ]]):format(buildOfficialFactionWhere('name')), {
            factionId
        })
    end

    local factionName = normalizeText(payload and payload.factionName, nil)

    if factionName == nil or #factionName > factionLimits.maxNameLength or not officialFactionNames[factionName] then
        return nil
    end

    return MySQL.single.await(([[ 
        SELECT id, name, label, faction_type, status, metadata, created_at
        FROM factions
        WHERE name = ? AND status = 'active' AND %s
        LIMIT 1
    ]]):format(buildOfficialFactionWhere('name')), {
        factionName
    })
end

local function mapMembership(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        faction_id = row.faction_id,
        character_id = row.character_id,
        grade_id = row.grade_id,
        callsign = row.callsign,
        joined_at = row.joined_at,
        left_at = row.left_at,
        faction = {
            id = row.faction_id,
            name = row.faction_name,
            label = row.faction_label,
            faction_type = row.faction_type,
            status = row.faction_status,
            metadata = decodePermissions(row.faction_metadata)
        },
        grade = {
            id = row.grade_id,
            level = row.grade_level,
            name = row.grade_name,
            label = row.grade_label,
            permissions = decodePermissions(row.grade_permissions)
        }
    }
end

local function getActiveFactionMembership(characterId, factionId)
    local query = ([[ 
        SELECT fm.id, fm.faction_id, fm.character_id, fm.grade_id, fm.callsign, fm.joined_at, fm.left_at,
            f.name AS faction_name, f.label AS faction_label, f.faction_type, f.status AS faction_status, f.metadata AS faction_metadata,
            fg.grade_level, fg.name AS grade_name, fg.label AS grade_label, fg.permissions AS grade_permissions
        FROM faction_members fm
        JOIN factions f ON f.id = fm.faction_id
        JOIN faction_grades fg ON fg.id = fm.grade_id
        WHERE fm.character_id = ? AND fm.left_at IS NULL AND f.status = 'active' AND %s
    ]]):format(buildOfficialFactionWhere('f.name'))
    local values = { characterId }

    if factionId ~= nil then
        query = query .. ' AND fm.faction_id = ?'
        values[#values + 1] = factionId
    end

    query = query .. ' ORDER BY fm.joined_at DESC LIMIT 1'

    return mapMembership(MySQL.single.await(query, values))
end

local function getFactionGrade(factionId, gradeId, gradeLevel)
    if gradeId ~= nil then
        return MySQL.single.await([[ 
            SELECT id, faction_id, grade_level, name, label, permissions
            FROM faction_grades
            WHERE id = ? AND faction_id = ?
            LIMIT 1
        ]], {
            gradeId,
            factionId
        })
    end

    return MySQL.single.await([[ 
        SELECT id, faction_id, grade_level, name, label, permissions
        FROM faction_grades
        WHERE faction_id = ? AND grade_level = ?
        LIMIT 1
    ]], {
        factionId,
        gradeLevel or 0
    })
end

local function getOpenFactionDutySession(characterId, factionId)
    return MySQL.single.await([[ 
        SELECT id, character_id, duty_type, duty_ref_id, started_at, ended_at, duration_seconds
        FROM duty_sessions
        WHERE character_id = ? AND duty_type = 'faction' AND duty_ref_id = ? AND ended_at IS NULL
        ORDER BY started_at DESC
        LIMIT 1
    ]], {
        characterId,
        factionId
    })
end

local function getFactionRadioChannels(factionId)
    return MySQL.query.await([[ 
        SELECT id, frequency, name, label, channel_type, faction_id, is_active, metadata, created_at
        FROM radio_channels
        WHERE faction_id = ? AND is_active = TRUE
        ORDER BY frequency ASC
    ]], {
        factionId
    }) or {}
end

local function getOpenFactionDutySessionForUpdate(characterId, factionId)
    return MySQL.single.await([[ 
        SELECT id, character_id, duty_type, duty_ref_id, started_at, ended_at, duration_seconds
        FROM duty_sessions
        WHERE character_id = ? AND duty_type = 'faction' AND duty_ref_id = ? AND ended_at IS NULL
        ORDER BY started_at DESC
        LIMIT 1
        FOR UPDATE
    ]], {
        characterId,
        factionId
    })
end

local function beginFactionTransaction()
    MySQL.query.await('START TRANSACTION')
end

local function commitFactionTransaction()
    MySQL.query.await('COMMIT')
end

local function rollbackFactionTransaction()
    MySQL.query.await('ROLLBACK')
end

local function getFactionPermissionMap(gradeId)
    local rows = MySQL.query.await([[ 
        SELECT permission, is_allowed
        FROM faction_permissions
        WHERE faction_grade_id = ?
    ]], {
        gradeId
    }) or {}
    local permissions = {}

    for _, row in ipairs(rows) do
        if row.is_allowed == true or row.is_allowed == 1 then
            permissions[row.permission] = true
        end
    end

    return permissions
end

local function hasMembershipPermission(membership, permission)
    if membership == nil or membership.grade == nil then
        return false
    end

    if permissionsContain(membership.grade.permissions or {}, permission) then
        return true
    end

    local gradePermissions = getFactionPermissionMap(membership.grade.id)

    return gradePermissions[permission] == true
end

local function resolveMembershipForActor(source, actor, payload, fallbackToCurrent)
    local targetFaction = getFactionByReference(payload or {})

    if targetFaction ~= nil then
        local membership = getActiveFactionMembership(actor.id, targetFaction.id)

        return membership, targetFaction
    end

    if fallbackToCurrent then
        local membership = getActiveFactionMembership(actor.id, nil)

        return membership, membership and membership.faction or nil
    end

    return nil, nil
end

local function buildPermissionSnapshot(source, membership)
    local snapshot = {}

    for _, permission in ipairs({
        factionPermissions.viewMembers,
        factionPermissions.manageMembers,
        factionPermissions.toggleDuty,
        factionPermissions.setOwnCallsign,
        factionPermissions.manageCallsigns,
        factionPermissions.viewAccounts,
        factionPermissions.manageAccounts,
        factionPermissions.transferAccounts
    }) do
        snapshot[permission] = hasGlobalPermission(source, permission) or hasMembershipPermission(membership, permission)
    end

    snapshot[factionPermissions.governmentManage] = hasGlobalPermission(source, factionPermissions.governmentManage)

    return snapshot
end

local function ensureFactionPermission(source, membership, permission, options)
    if hasGlobalPermission(source, permission) then
        return true
    end

    if options ~= nil and options.allowGovernmentOverride and hasGlobalPermission(source, factionPermissions.governmentManage) then
        return true
    end

    return hasMembershipPermission(membership, permission)
end

function listFactions()
    local rows = MySQL.query.await([[ 
        SELECT id, name, label, faction_type, status, metadata, created_at
        FROM factions
        WHERE status = 'active' AND name IN ('lspd', 'ems', 'government', 'weazel')
        ORDER BY label ASC
    ]])

    return respond(true, 'OK', 'Fraktionen wurden geladen.', {
        factions = rows or {}
    }, nil, nil)
end

function getCurrentFaction(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership = select(1, resolveMembershipForActor(source, actor, payload, true))
    local dutySession = membership ~= nil and getOpenFactionDutySession(actor.id, membership.faction.id) or nil
    local radioChannels = membership ~= nil and getFactionRadioChannels(membership.faction.id) or {}

    return respond(true, 'OK', 'Fraktionsstatus wurde geladen.', {
        membership = membership,
        dutySession = dutySession,
        radioChannels = radioChannels,
        permissions = buildPermissionSnapshot(source, membership)
    }, nil, nil)
end

function listFactionMembers(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership, targetFaction = resolveMembershipForActor(source, actor, payload, true)

    if targetFaction == nil then
        return respond(false, 'NOT_FOUND', 'Keine aktive Fraktion gefunden.', nil, nil, nil)
    end

    if not ensureFactionPermission(source, membership, factionPermissions.viewMembers, {
        allowGovernmentOverride = true
    }) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Fraktionsmitglieder einsehen.', nil, nil, nil)
    end

    local limit = normalizeId(payload and payload.limit) or 25

    if limit > factionLimits.maxMembersLimit then
        limit = factionLimits.maxMembersLimit
    end

    local rows = MySQL.query.await([[ 
        SELECT fm.id, fm.character_id, fm.callsign, fm.joined_at,
            c.firstname, c.lastname, c.citizenid,
            fg.id AS grade_id, fg.grade_level, fg.name AS grade_name, fg.label AS grade_label
        FROM faction_members fm
        JOIN characters c ON c.id = fm.character_id
        JOIN faction_grades fg ON fg.id = fm.grade_id
        WHERE fm.faction_id = ? AND fm.left_at IS NULL
        ORDER BY fg.grade_level DESC, fm.joined_at ASC
        LIMIT ?
    ]], {
        targetFaction.id,
        limit
    })

    return respond(true, 'OK', 'Fraktionsmitglieder wurden geladen.', {
        faction = targetFaction,
        members = rows or {}
    }, {
        limit = limit
    }, nil)
end

function assignFactionMember(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    local faction = getFactionByReference(payload)
    local characterId = normalizeId(payload.characterId)
    local gradeId = normalizeId(payload.gradeId)
    local gradeLevel = normalizeId(payload.gradeLevel) or 0
    local callsign = normalizeText(payload.callsign, nil)

    if faction == nil or characterId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    if callsign ~= nil and #callsign > factionLimits.maxCallsignLength then
        return respond(false, 'INVALID_INPUT', 'Callsign ist ungueltig.', nil, nil, nil)
    end

    local actorMembership = getActiveFactionMembership(actor.id, faction.id)
    local requiresGovernmentPermission = faction.name == 'government'

    if requiresGovernmentPermission then
        if not hasGlobalPermission(source, factionPermissions.governmentManage) then
            return respond(false, 'NO_PERMISSION', 'Government darf nur durch Administration verwaltet werden.', nil, nil, nil)
        end
    elseif not ensureFactionPermission(source, actorMembership, factionPermissions.manageMembers, nil) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Fraktionsmitglieder verwalten.', nil, nil, nil)
    end

    local grade = getFactionGrade(faction.id, gradeId, gradeLevel)

    if grade == nil then
        return respond(false, 'NOT_FOUND', 'Fraktionsrang wurde nicht gefunden.', nil, nil, nil)
    end

    local targetCharacter = MySQL.single.await([[ 
        SELECT id, citizenid, firstname, lastname
        FROM characters
        WHERE id = ? AND is_active = TRUE
        LIMIT 1
    ]], {
        characterId
    })

    if targetCharacter == nil then
        return respond(false, 'NOT_FOUND', 'Charakter wurde nicht gefunden.', nil, nil, nil)
    end

    local success, transactionResult = pcall(function()
        beginFactionTransaction()

        local existingTargetMembership = MySQL.single.await([[ 
            SELECT id
            FROM faction_members
            WHERE faction_id = ? AND character_id = ?
            LIMIT 1
            FOR UPDATE
        ]], {
            faction.id,
            characterId
        })

        MySQL.update.await([[ 
            UPDATE faction_members
            SET left_at = NOW()
            WHERE character_id = ?
                AND faction_id <> ?
                AND left_at IS NULL
                AND faction_id IN (
                    SELECT id FROM factions
                    WHERE name IN ('lspd', 'ems', 'government', 'weazel')
                )
        ]], {
            characterId,
            faction.id
        })

        if existingTargetMembership ~= nil then
            MySQL.update.await([[ 
                UPDATE faction_members
                SET grade_id = ?, callsign = ?, joined_at = NOW(), left_at = NULL
                WHERE id = ?
            ]], {
                grade.id,
                callsign,
                existingTargetMembership.id
            })

            return existingTargetMembership.id
        end

        return MySQL.insert.await([[ 
            INSERT INTO faction_members (faction_id, character_id, grade_id, callsign, joined_at)
            VALUES (?, ?, ?, ?, NOW())
        ]], {
            faction.id,
            characterId,
            grade.id,
            callsign
        })
    end)

    if not success then
        rollbackFactionTransaction()
        return respond(false, 'DATABASE_ERROR', 'Mitglied konnte nicht zugewiesen werden.', nil, nil, nil)
    end

    commitFactionTransaction()

    local auditId = writeFactionAudit('faction.assignMember', actor, 'character', characterId, {
        factionId = faction.id,
        gradeId = grade.id,
        callsign = callsign
    })

    return respond(true, 'OK', 'Fraktionsmitglied wurde aktualisiert.', {
        faction = faction,
        memberId = transactionResult,
        character = targetCharacter
    }, nil, auditId)
end

function setFactionCallsign(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Callsign-Daten.', nil, nil, nil)
    end

    local targetCharacterId = normalizeId(payload.characterId) or actor.id
    local callsign = normalizeText(payload.callsign, nil)
    local membership, faction = resolveMembershipForActor(source, actor, payload, true)

    if faction == nil then
        return respond(false, 'NOT_FOUND', 'Keine aktive Fraktion gefunden.', nil, nil, nil)
    end

    if callsign ~= nil and #callsign > factionLimits.maxCallsignLength then
        return respond(false, 'INVALID_INPUT', 'Callsign ist ungueltig.', nil, nil, nil)
    end

    local canManageOthers = ensureFactionPermission(source, membership, factionPermissions.manageCallsigns, {
        allowGovernmentOverride = true
    })
    local canSetOwn = ensureFactionPermission(source, membership, factionPermissions.setOwnCallsign, nil)

    if targetCharacterId ~= actor.id and not canManageOthers then
        return respond(false, 'NO_PERMISSION', 'Du darfst fremde Callsigns nicht setzen.', nil, nil, nil)
    end

    if targetCharacterId == actor.id and not (canSetOwn or canManageOthers) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keinen Callsign setzen.', nil, nil, nil)
    end

    local targetMembership = getActiveFactionMembership(targetCharacterId, faction.id)

    if targetMembership == nil then
        return respond(false, 'NOT_FOUND', 'Aktive Fraktionsmitgliedschaft wurde nicht gefunden.', nil, nil, nil)
    end

    MySQL.update.await([[ 
        UPDATE faction_members
        SET callsign = ?
        WHERE id = ?
    ]], {
        callsign,
        targetMembership.id
    })

    local auditId = writeFactionAudit('faction.setCallsign', actor, 'faction_member', targetMembership.id, {
        factionId = faction.id,
        characterId = targetCharacterId,
        callsign = callsign
    })

    return respond(true, 'OK', 'Callsign wurde aktualisiert.', {
        factionId = faction.id,
        characterId = targetCharacterId,
        callsign = callsign
    }, nil, auditId)
end

function startFactionDuty(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership = select(1, resolveMembershipForActor(source, actor, payload, true))

    if membership == nil or membership.id == nil then
        return respond(false, 'NO_PERMISSION', 'Du bist keiner aktiven Fraktion zugeordnet.', nil, nil, nil)
    end

    if not ensureFactionPermission(source, membership, factionPermissions.toggleDuty, nil) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keinen Fraktionsdienst starten.', nil, nil, nil)
    end

    beginFactionTransaction()

    local ok, result = pcall(function()
        local openSession = getOpenFactionDutySessionForUpdate(actor.id, membership.faction.id)

        if openSession ~= nil then
            return {
                conflict = true,
                dutySession = openSession
            }
        end

        local dutySessionId = MySQL.insert.await([[ 
            INSERT INTO duty_sessions (character_id, duty_type, duty_ref_id, started_at)
            VALUES (?, 'faction', ?, NOW())
        ]], {
            actor.id,
            membership.faction.id
        })

        return {
            dutySessionId = dutySessionId
        }
    end)

    if not ok then
        rollbackFactionTransaction()
        return respond(false, 'DATABASE_ERROR', 'Fraktionsdienst konnte nicht gestartet werden.', nil, nil, nil)
    end

    commitFactionTransaction()

    if result.conflict then
        return respond(false, 'CONFLICT', 'Du bist bereits im Fraktionsdienst.', {
            dutySession = result.dutySession
        }, nil, nil)
    end

    local auditId = writeFactionAudit('faction.dutyStart', actor, 'duty_session', result.dutySessionId, {
        factionId = membership.faction.id
    })

    return respond(true, 'OK', 'Fraktionsdienst wurde gestartet.', {
        faction = membership.faction,
        dutySessionId = result.dutySessionId
    }, nil, auditId)
end

function endFactionDuty(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership = select(1, resolveMembershipForActor(source, actor, payload, true))

    if membership == nil or membership.id == nil then
        return respond(false, 'NO_PERMISSION', 'Du bist keiner aktiven Fraktion zugeordnet.', nil, nil, nil)
    end

    if not ensureFactionPermission(source, membership, factionPermissions.toggleDuty, nil) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keinen Fraktionsdienst beenden.', nil, nil, nil)
    end

    beginFactionTransaction()

    local ok, result = pcall(function()
        local openSession = getOpenFactionDutySessionForUpdate(actor.id, membership.faction.id)

        if openSession == nil then
            return {
                missing = true
            }
        end

        MySQL.update.await([[ 
            UPDATE duty_sessions
            SET ended_at = NOW(), duration_seconds = TIMESTAMPDIFF(SECOND, started_at, NOW())
            WHERE id = ? AND ended_at IS NULL
        ]], {
            openSession.id
        })

        return {
            dutySessionId = openSession.id
        }
    end)

    if not ok then
        rollbackFactionTransaction()
        return respond(false, 'DATABASE_ERROR', 'Fraktionsdienst konnte nicht beendet werden.', nil, nil, nil)
    end

    commitFactionTransaction()

    if result.missing then
        return respond(false, 'NOT_FOUND', 'Keine offene Fraktionsdienstzeit gefunden.', nil, nil, nil)
    end

    local ended = MySQL.single.await([[ 
        SELECT id, character_id, duty_type, duty_ref_id, started_at, ended_at, duration_seconds
        FROM duty_sessions
        WHERE id = ?
        LIMIT 1
    ]], {
        result.dutySessionId
    })

    local auditId = writeFactionAudit('faction.dutyEnd', actor, 'duty_session', result.dutySessionId, {
        factionId = membership.faction.id,
        durationSeconds = ended and ended.duration_seconds or nil
    })

    return respond(true, 'OK', 'Fraktionsdienst wurde beendet.', {
        dutySession = ended
    }, nil, auditId)
end

function hasFactionPermission(source, payload)
    local permission = payload
    local reference = {}

    if type(payload) == 'table' then
        permission = payload.permission
        reference = payload
    end

    if type(permission) ~= 'string' or permission == '' then
        return respond(false, 'INVALID_INPUT', 'Permission ist ungueltig.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership = select(1, resolveMembershipForActor(source, actor, reference, true))
    local allowed = ensureFactionPermission(source, membership, permission, {
        allowGovernmentOverride = true
    })

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', {
            permission = permission
        }, nil, nil)
    end

    return respond(true, 'OK', 'Permission wurde bestaetigt.', {
        permission = permission
    }, nil, nil)
end

function listFactionAccounts(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local membership, faction = resolveMembershipForActor(source, actor, payload, true)

    if faction == nil then
        return respond(false, 'NOT_FOUND', 'Keine aktive Fraktion gefunden.', nil, nil, nil)
    end

    if not ensureFactionPermission(source, membership, factionPermissions.viewAccounts, {
        allowGovernmentOverride = true
    }) and not ensureFactionPermission(source, membership, factionPermissions.manageAccounts, {
        allowGovernmentOverride = true
    }) and not ensureFactionPermission(source, membership, factionPermissions.transferAccounts, {
        allowGovernmentOverride = true
    }) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Fraktionskonten einsehen.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[ 
        SELECT id, account_number, owner_type, owner_id, account_type, balance, currency, is_frozen, created_at, updated_at
        FROM accounts
        WHERE owner_type = 'faction' AND owner_id = ? AND account_type = 'faction'
        ORDER BY created_at ASC
        LIMIT ?
    ]], {
        faction.id,
        factionLimits.maxAccountsLimit
    })

    return respond(true, 'OK', 'Fraktionskonten wurden geladen.', {
        faction = faction,
        accounts = rows or {}
    }, nil, nil)
end

function transferFactionFunds(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kontodaten.', nil, nil, nil)
    end

    local membership, faction = resolveMembershipForActor(source, actor, payload, true)
    local toAccountId = normalizeId(payload.toAccountId)
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Fraktionsbuchung')

    if faction == nil or toAccountId == nil or amount == nil or reason == nil or #reason > factionLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kontodaten.', nil, nil, nil)
    end

    if not ensureFactionPermission(source, membership, factionPermissions.transferAccounts, {
        allowGovernmentOverride = true
    }) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Fraktionsbuchungen ausfuehren.', nil, nil, nil)
    end

    local factionAccount = MySQL.single.await([[ 
        SELECT id, account_number
        FROM accounts
        WHERE owner_type = 'faction' AND owner_id = ? AND account_type = 'faction'
        ORDER BY created_at ASC
        LIMIT 1
    ]], {
        faction.id
    })

    if factionAccount == nil then
        return respond(false, 'NOT_FOUND', 'Kein Fraktionskonto gefunden.', nil, nil, nil)
    end

    local result = transferMoney(source, {
        fromAccountId = factionAccount.id,
        toAccountId = toAccountId,
        amount = amount,
        reason = reason,
        category = 'faction_transfer',
        metadata = {
            factionId = faction.id,
            factionName = faction.name
        }
    })

    if not result.success then
        return result
    end

    local auditId = writeFactionAudit('faction.transferFunds', actor, 'account', factionAccount.id, {
        factionId = faction.id,
        toAccountId = toAccountId,
        amount = amount,
        reason = reason
    })

    result.audit_id = auditId

    return result
end

exports('faction.list', listFactions)
exports('faction.getCurrent', getCurrentFaction)
exports('faction.listMembers', listFactionMembers)
exports('faction.assignMember', assignFactionMember)
exports('faction.setCallsign', setFactionCallsign)
exports('faction.startDuty', startFactionDuty)
exports('faction.endDuty', endFactionDuty)
exports('faction.hasPermission', hasFactionPermission)
exports('faction.listAccounts', listFactionAccounts)
exports('faction.transferFunds', transferFactionFunds)
