local actionIndex = {}
local reports = {}
local reportSequence = 0
local tickets = {}
local ticketSequence = 0
local moderationActions = {}
local moderationSequence = 0
local moderationNotes = {}
local utilityActions = {}
local utilitySequence = 0
local returnPositions = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaAdminConfig.featureFlag)
end

local function areReportsEnabled()
    return isEnabled()
        and (GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaAdminConfig.reportsFeatureFlag))
end

local function areTicketsEnabled()
    return isEnabled()
        and (GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaAdminConfig.ticketsFeatureFlag))
end

local function areModerationActionsEnabled()
    return isEnabled()
        and (GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaAdminConfig.moderationFeatureFlag))
end

local function areUtilitiesEnabled()
    return isEnabled()
        and (GetResourceState('nexa_featureflags') ~= 'started'
            or exports.nexa_featureflags:isEnabled(NexaAdminConfig.utilityFeatureFlag))
end

local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function writeAdminAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'admin',
        severity = 'info',
        action = action,
        resourceName = NEXA_ADMIN.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function hasPermission(source, permission)
    local result = exports.nexa_api['permission.has'](source, permission)

    return result == true or (type(result) == 'table' and result.success == true)
end

local function hasAnyPermission(source, permissions)
    for _, permission in ipairs(permissions or {}) do
        if hasPermission(source, permission) then
            return true
        end
    end

    return false
end

local function getRoleForSource(source)
    local bestRole = nil

    for _, role in ipairs(NexaAdminServer.roles) do
        if hasAnyPermission(source, role.permissions) then
            bestRole = {
                id = role.id,
                label = role.label
            }
        end
    end

    return bestRole
end

local function ensureAdminAccess(source, permission)
    if not isEnabled() then
        return false, buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Admin-Core ist deaktiviert.', nil, nil, nil)
    end

    if not hasPermission(source, permission) then
        local auditId = writeAdminAudit('admin.access.denied', source, {
            source = source,
            permission = permission
        })

        return false, buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, auditId)
    end

    return true, nil
end

local function sanitizePlayer(source)
    local playerSource = tonumber(source)
    local character = nil
    local characterResponse = exports.nexa_api['character.getActive'](playerSource)

    if type(characterResponse) == 'table' and characterResponse.success == true then
        character = characterResponse.data
    end

    return {
        source = playerSource,
        name = GetPlayerName(playerSource) or 'Unbekannter Spieler',
        character = character,
        identifiersIncluded = NexaAdminServer.overview.includeIdentifiers == true
    }
end

local function getActiveCharacter(source)
    local response = exports.nexa_api['character.getActive'](source)

    if type(response) ~= 'table' or response.success ~= true or response.data == nil then
        return nil
    end

    return response.data.character
end

local function getActorSnapshot(source)
    local character = getActiveCharacter(source)

    if character == nil then
        return nil
    end

    return {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Unbekannter Spieler',
        characterId = character.id,
        citizenid = character.citizenid,
        displayName = ((character.firstname or '') .. ' ' .. (character.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    }
end

local function getTargetSnapshot(targetSource)
    local playerSource = tonumber(targetSource)

    if playerSource == nil or GetPlayerName(playerSource) == nil then
        return nil
    end

    local character = getActiveCharacter(playerSource)

    return {
        source = playerSource,
        name = GetPlayerName(playerSource) or 'Unbekannter Spieler',
        characterId = character and character.id or nil,
        citizenid = character and character.citizenid or nil,
        displayName = character and (((character.firstname or '') .. ' ' .. (character.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')) or nil
    }
end

local function nextModerationId(prefix)
    moderationSequence = moderationSequence + 1

    return ('%s-%06d'):format(prefix, moderationSequence)
end

local function recordModerationAction(actionType, actor, target, metadata)
    local actionId = nextModerationId('MOD')

    moderationActions[actionId] = {
        id = actionId,
        type = actionType,
        actor = actor,
        target = target,
        metadata = metadata or {},
        createdAt = os.time()
    }

    return moderationActions[actionId]
end

local function ensureModerationAccess(source, permission)
    if not areModerationActionsEnabled() then
        return false, buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Moderation ist deaktiviert.', nil, nil, nil)
    end

    return ensureAdminAccess(source, permission)
end

local function ensureModerationTarget(source, targetSource)
    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }
    local target = getTargetSnapshot(targetSource)

    if target == nil then
        return nil, nil, buildResponse(false, 'NOT_FOUND', 'Spieler wurde nicht gefunden.', nil, nil, nil)
    end

    return actor, target, nil
end

local function writeModerationLog(action, record)
    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Moderationsaktion ausgefuehrt.', {
        action = action,
        actionId = record and record.id or nil,
        actorSource = record and record.actor and record.actor.source or nil,
        targetSource = record and record.target and record.target.source or nil
    })
end

local function sanitizeModerationRecord(record)
    return {
        id = record.id,
        type = record.type,
        actor = record.actor,
        target = record.target,
        metadata = record.metadata,
        createdAt = record.createdAt
    }
end

local function ensureUtilityAccess(source, permission)
    if not areUtilitiesEnabled() then
        return false, buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Admin-Utility ist deaktiviert.', nil, nil, nil)
    end

    return ensureAdminAccess(source, permission)
end

local function getServerCoords(source)
    local ped = GetPlayerPed(tonumber(source))

    if ped == nil or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped) or 0.0

    if coords == nil then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    }
end

local function nextUtilityId(prefix)
    utilitySequence = utilitySequence + 1

    return ('%s-%06d'):format(prefix, utilitySequence)
end

local function recordUtilityAction(actionType, actor, target, metadata)
    local actionId = nextUtilityId('UTL')

    utilityActions[actionId] = {
        id = actionId,
        type = actionType,
        actor = actor,
        target = target,
        metadata = metadata or {},
        createdAt = os.time()
    }

    return utilityActions[actionId]
end

local function sanitizeUtilityRecord(record)
    return {
        id = record.id,
        type = record.type,
        actor = record.actor,
        target = record.target,
        metadata = record.metadata,
        createdAt = record.createdAt
    }
end

local function writeUtilityLog(action, record)
    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Admin-Utility ausgefuehrt.', {
        action = action,
        actionId = record and record.id or nil,
        actorSource = record and record.actor and record.actor.source or nil,
        targetSource = record and record.target and record.target.source or nil
    })
end

local function sendUtilityToClient(targetSource, payload)
    TriggerClientEvent(NEXA_ADMIN_EVENTS.applyUtility, targetSource, payload)
end

local function markTeleportAllowance(targetSource, context, metadata)
    if GetResourceState('nexa_api') ~= 'started' then
        return
    end

    pcall(function()
        exports.nexa_api['teleport.allow'](targetSource, context, metadata or {})
    end)
end

local function markGodmodeException(targetSource, context, metadata)
    if GetResourceState('nexa_api') ~= 'started' then
        return
    end

    pcall(function()
        exports.nexa_api['godmode.allowException'](targetSource, context, metadata or {})
    end)
end

local function listUtilityActions(source)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.goto')

    if not allowed then
        return denied
    end

    local actions = {
        'admin.utility.bring',
        'admin.utility.goto',
        'admin.utility.return',
        'admin.utility.coords',
        'admin.utility.heal.prepare',
        'admin.utility.revive.prepare'
    }
    local auditId = writeAdminAudit('admin.utility.list', source, {
        source = source,
        actionCount = #actions
    })

    return buildResponse(true, 'OK', 'Admin-Utilities wurden geladen.', {
        actions = actions
    }, nil, auditId)
end

local function listModerationActions(source)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.warn')

    if not allowed then
        return denied
    end

    local actions = {
        'admin.moderation.warn',
        'admin.moderation.kick',
        'admin.moderation.tempban.prepare',
        'admin.moderation.freeze',
        'admin.moderation.spectate.prepare',
        'admin.moderation.notes.add'
    }
    local auditId = writeAdminAudit('admin.moderation.list', source, {
        source = source,
        actionCount = #actions
    })

    return buildResponse(true, 'OK', 'Moderationsaktionen wurden geladen.', {
        actions = actions
    }, nil, auditId)
end

local function isReportOwner(source, report)
    local actor = getActorSnapshot(source)

    return actor ~= nil
        and report.ownerCharacterId ~= nil
        and tonumber(report.ownerCharacterId) == tonumber(actor.characterId)
end

local function sanitizeReport(report, includeAdminFields)
    local copy = {
        id = report.id,
        category = report.category,
        categoryLabel = NexaAdminServer.reports.categories[report.category],
        subject = report.subject,
        message = report.message,
        status = report.status,
        createdAt = report.createdAt,
        updatedAt = report.updatedAt,
        closedAt = report.closedAt,
        history = report.history
    }

    if includeAdminFields == true then
        copy.ownerSource = report.ownerSource
        copy.ownerName = report.ownerName
        copy.ownerCharacterId = report.ownerCharacterId
        copy.ownerDisplayName = report.ownerDisplayName
        copy.acceptedBy = report.acceptedBy
        copy.closedBy = report.closedBy
        copy.closeReason = report.closeReason
    end

    return copy
end

local function addReportHistory(report, action, actor, metadata)
    report.history[#report.history + 1] = {
        action = action,
        actorSource = actor and actor.source or nil,
        actorName = actor and actor.name or nil,
        actorCharacterId = actor and actor.characterId or nil,
        metadata = metadata or {},
        createdAt = os.time()
    }
end

local function countOpenReportsForCharacter(characterId)
    local count = 0

    for _, report in pairs(reports) do
        if tonumber(report.ownerCharacterId) == tonumber(characterId)
            and (report.status == 'open' or report.status == 'accepted') then
            count = count + 1
        end
    end

    return count
end

local function countReports()
    local count = 0

    for _ in pairs(reports) do
        count = count + 1
    end

    return count
end

local function countOpenTicketsForCharacter(characterId)
    local count = 0

    for _, ticket in pairs(tickets) do
        if tonumber(ticket.ownerCharacterId) == tonumber(characterId)
            and (ticket.status == 'open' or ticket.status == 'assigned') then
            count = count + 1
        end
    end

    return count
end

local function countTickets()
    local count = 0

    for _ in pairs(tickets) do
        count = count + 1
    end

    return count
end

local function addTicketHistory(ticket, action, actor, metadata)
    ticket.history[#ticket.history + 1] = {
        action = action,
        actorSource = actor and actor.source or nil,
        actorName = actor and actor.name or nil,
        actorCharacterId = actor and actor.characterId or nil,
        metadata = metadata or {},
        createdAt = os.time()
    }
end

local function sanitizeTicket(ticket)
    return {
        id = ticket.id,
        reason = ticket.reason,
        reasonLabel = NexaAdminServer.tickets.reasons[ticket.reason],
        description = ticket.description,
        status = ticket.status,
        ownerSource = ticket.ownerSource,
        ownerName = ticket.ownerName,
        ownerCharacterId = ticket.ownerCharacterId,
        ownerDisplayName = ticket.ownerDisplayName,
        assignedTo = ticket.assignedTo,
        closedBy = ticket.closedBy,
        closeNote = ticket.closeNote,
        createdAt = ticket.createdAt,
        updatedAt = ticket.updatedAt,
        closedAt = ticket.closedAt,
        history = ticket.history
    }
end

local function createTicket(source, payload)
    if not areTicketsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Tickets sind deaktiviert.', nil, nil, nil)
    end

    local valid, code, sanitized = validateTicketCreatePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Ticket-Daten.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source)

    if actor == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if countOpenTicketsForCharacter(actor.characterId) >= NexaAdminServer.tickets.maxOpenPerPlayer then
        return buildResponse(false, 'CONFLICT', 'Du hast bereits zu viele offene Tickets.', nil, nil, nil)
    end

    if countTickets() >= NexaAdminServer.tickets.maxTickets then
        return buildResponse(false, 'CONFLICT', 'Aktuell koennen keine weiteren Tickets erstellt werden.', nil, nil, nil)
    end

    ticketSequence = ticketSequence + 1
    local ticketId = ('TCK-%06d'):format(ticketSequence)
    local now = os.time()

    tickets[ticketId] = {
        id = ticketId,
        ownerSource = actor.source,
        ownerName = actor.name,
        ownerCharacterId = actor.characterId,
        ownerDisplayName = actor.displayName,
        reason = sanitized.reason,
        description = sanitized.description,
        status = 'open',
        history = {},
        createdAt = now,
        updatedAt = now
    }

    addTicketHistory(tickets[ticketId], 'ticket.created', actor, {
        reason = sanitized.reason
    })

    local auditId = writeAdminAudit('admin.ticket.created', source, {
        source = source,
        ticketId = ticketId,
        ownerCharacterId = actor.characterId,
        reason = sanitized.reason
    })

    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Ticket wurde erstellt.', {
        source = source,
        ticketId = ticketId
    })

    return buildResponse(true, 'CREATED', 'Ticket wurde erstellt.', {
        ticket = sanitizeTicket(tickets[ticketId])
    }, nil, auditId)
end

local function listTickets(source)
    if not areTicketsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Tickets sind deaktiviert.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, 'admin.tickets.view')

    if not allowed then
        return denied
    end

    local result = {}

    for _, ticket in pairs(tickets) do
        result[#result + 1] = sanitizeTicket(ticket)
    end

    local auditId = writeAdminAudit('admin.tickets.list', source, {
        source = source,
        count = #result
    })

    return buildResponse(true, 'OK', 'Tickets wurden geladen.', {
        tickets = result
    }, nil, auditId)
end

local function assignTicket(source, payload)
    if not areTicketsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Tickets sind deaktiviert.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, 'admin.tickets.assign')

    if not allowed then
        return denied
    end

    local valid, code = validateTicketAssignPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Ticket-Anfrage.', nil, nil, nil)
    end

    local ticket = tickets[payload.ticketId]

    if ticket == nil then
        return buildResponse(false, 'NOT_FOUND', 'Ticket wurde nicht gefunden.', nil, nil, nil)
    end

    if ticket.status == 'closed' then
        return buildResponse(false, 'CONFLICT', 'Geschlossenes Ticket kann nicht zugewiesen werden.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }
    local assigneeSource = tonumber(payload.assigneeSource) or actor.source

    ticket.status = 'assigned'
    ticket.assignedTo = {
        source = assigneeSource,
        name = GetPlayerName(assigneeSource) or actor.name
    }
    ticket.updatedAt = os.time()

    addTicketHistory(ticket, 'ticket.assigned', actor, {
        assigneeSource = assigneeSource
    })

    local auditId = writeAdminAudit('admin.ticket.assigned', source, {
        source = source,
        ticketId = ticket.id,
        assigneeSource = assigneeSource
    })

    return buildResponse(true, 'OK', 'Ticket wurde zugewiesen.', {
        ticket = sanitizeTicket(ticket)
    }, nil, auditId)
end

local function closeTicket(source, payload)
    if not areTicketsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Tickets sind deaktiviert.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, 'admin.tickets.close')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateTicketClosePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Ticket-Anfrage.', nil, nil, nil)
    end

    local ticket = tickets[payload.ticketId]

    if ticket == nil then
        return buildResponse(false, 'NOT_FOUND', 'Ticket wurde nicht gefunden.', nil, nil, nil)
    end

    if ticket.status == 'closed' then
        return buildResponse(false, 'CONFLICT', 'Ticket ist bereits geschlossen.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }

    ticket.status = 'closed'
    ticket.closedBy = actor
    ticket.closeNote = sanitized.note
    ticket.closedAt = os.time()
    ticket.updatedAt = ticket.closedAt

    addTicketHistory(ticket, 'ticket.closed', actor, {
        note = sanitized.note
    })

    local auditId = writeAdminAudit('admin.ticket.closed', source, {
        source = source,
        ticketId = ticket.id,
        note = sanitized.note
    })

    return buildResponse(true, 'OK', 'Ticket wurde geschlossen.', {
        ticket = sanitizeTicket(ticket)
    }, nil, auditId)
end

local function warnPlayer(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.warn')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationReasonPayload(payload, 240, 3)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Verwarnung.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordModerationAction('warn', actor, target, {
        reason = sanitized.reason
    })
    local auditId = writeAdminAudit('admin.moderation.warned', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.warned', record)

    return buildResponse(true, 'OK', 'Spieler wurde verwarnt.', {
        action = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function kickPlayer(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.kick')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationReasonPayload(payload, 240, 3)

    if not valid then
        return buildResponse(false, code, 'Ungueltiger Kick.', nil, nil, nil)
    end

    if tonumber(source) == tonumber(sanitized.targetSource) then
        return buildResponse(false, 'CONFLICT', 'Du kannst dich nicht selbst kicken.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordModerationAction('kick', actor, target, {
        reason = sanitized.reason
    })
    local auditId = writeAdminAudit('admin.moderation.kicked', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.kicked', record)
    DropPlayer(target.source, ('Nexa Roleplay: %s'):format(sanitized.reason))

    return buildResponse(true, 'OK', 'Spieler wurde gekickt.', {
        action = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function prepareTempban(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.tempban.prepare')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateTempbanPreparePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Tempban-Vorbereitung.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordModerationAction('tempban.prepare', actor, target, {
        reason = sanitized.reason,
        durationMinutes = sanitized.durationMinutes,
        preparedOnly = NexaAdminServer.moderation.tempbanPreparedOnly == true
    })
    local auditId = writeAdminAudit('admin.moderation.tempban.prepared', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.tempban.prepared', record)

    return buildResponse(true, 'OK', 'Tempban wurde vorbereitet.', {
        action = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function setPlayerFrozen(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.freeze')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationFreezePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Freeze-Anfrage.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordModerationAction('freeze', actor, target, {
        state = sanitized.state,
        frozen = sanitized.frozen,
        reason = sanitized.reason
    })
    local auditId = writeAdminAudit('admin.moderation.freezeChanged', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.freezeChanged', record)
    TriggerClientEvent(NEXA_ADMIN_EVENTS.applyControl, target.source, {
        frozen = sanitized.frozen,
        reason = sanitized.reason
    })

    return buildResponse(true, 'OK', sanitized.frozen and 'Spieler wurde eingefroren.' or 'Spieler wurde freigegeben.', {
        action = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function prepareSpectate(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.spectate.prepare')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationTargetPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Spectate-Vorbereitung.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordModerationAction('spectate.prepare', actor, target, {
        preparedOnly = NexaAdminServer.moderation.spectatePreparedOnly == true
    })
    local auditId = writeAdminAudit('admin.moderation.spectate.prepared', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.spectate.prepared', record)

    return buildResponse(true, 'OK', 'Spectate wurde vorbereitet.', {
        action = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function addAdminNote(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.notes.add')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationNotePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Admin-Notiz.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local key = tostring(target.characterId or target.source)

    moderationNotes[key] = moderationNotes[key] or {}

    if #moderationNotes[key] >= NexaAdminServer.moderation.maxNotesPerTarget then
        return buildResponse(false, 'CONFLICT', 'Zu viele Admin-Notizen fuer diesen Spieler.', nil, nil, nil)
    end

    local record = recordModerationAction('note.add', actor, target, {
        note = sanitized.note
    })
    moderationNotes[key][#moderationNotes[key] + 1] = sanitizeModerationRecord(record)

    local auditId = writeAdminAudit('admin.moderation.note.added', source, sanitizeModerationRecord(record))

    writeModerationLog('admin.moderation.note.added', record)

    return buildResponse(true, 'CREATED', 'Admin-Notiz wurde gespeichert.', {
        note = sanitizeModerationRecord(record)
    }, nil, auditId)
end

local function listAdminNotes(source, payload)
    local allowed, denied = ensureModerationAccess(source, 'admin.moderation.notes.view')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateModerationTargetPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Notiz-Anfrage.', nil, nil, nil)
    end

    local _, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local key = tostring(target.characterId or target.source)
    local notes = moderationNotes[key] or {}
    local auditId = writeAdminAudit('admin.moderation.notes.list', source, {
        source = source,
        targetSource = target.source,
        count = #notes
    })

    return buildResponse(true, 'OK', 'Admin-Notizen wurden geladen.', {
        notes = notes
    }, nil, auditId)
end

local function bringPlayer(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.bring')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityTargetPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Bring-Anfrage.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local targetCoords = getServerCoords(target.source)
    local destination = getServerCoords(source)

    if destination == nil or targetCoords == nil then
        return buildResponse(false, 'NOT_FOUND', 'Position konnte nicht bestimmt werden.', nil, nil, nil)
    end

    returnPositions[tostring(target.source)] = targetCoords

    local record = recordUtilityAction('bring', actor, target, {
        destination = destination,
        returnStored = true
    })
    local auditId = writeAdminAudit('admin.utility.brought', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.brought', record)
    markTeleportAllowance(target.source, 'admin_utility', {
        actorSource = source,
        action = 'bring',
        auditId = auditId
    })
    sendUtilityToClient(target.source, {
        type = 'teleport',
        coords = destination
    })

    return buildResponse(true, 'OK', 'Spieler wurde gebracht.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function gotoPlayer(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.goto')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityTargetPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige GoTo-Anfrage.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local actorCoords = getServerCoords(source)
    local destination = getServerCoords(target.source)

    if destination == nil or actorCoords == nil then
        return buildResponse(false, 'NOT_FOUND', 'Position konnte nicht bestimmt werden.', nil, nil, nil)
    end

    returnPositions[tostring(source)] = actorCoords

    local record = recordUtilityAction('goto', actor, target, {
        destination = destination,
        returnStored = true
    })
    local auditId = writeAdminAudit('admin.utility.goto', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.goto', record)
    markTeleportAllowance(source, 'admin_utility', {
        actorSource = source,
        action = 'goto',
        auditId = auditId
    })
    sendUtilityToClient(source, {
        type = 'teleport',
        coords = destination
    })

    return buildResponse(true, 'OK', 'Du wurdest zum Spieler teleportiert.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function returnPlayer(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.return')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityTargetPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Return-Anfrage.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local key = tostring(target.source)
    local destination = returnPositions[key]

    if destination == nil then
        return buildResponse(false, 'NOT_FOUND', 'Keine Rueckkehrposition gespeichert.', nil, nil, nil)
    end

    returnPositions[key] = nil

    local record = recordUtilityAction('return', actor, target, {
        destination = destination
    })
    local auditId = writeAdminAudit('admin.utility.returned', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.returned', record)
    markTeleportAllowance(target.source, 'admin_utility', {
        actorSource = source,
        action = 'return',
        auditId = auditId
    })
    sendUtilityToClient(target.source, {
        type = 'teleport',
        coords = destination
    })

    return buildResponse(true, 'OK', 'Spieler wurde zurueckgesetzt.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function teleportToCoords(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.coords')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityCoordsPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Koordinaten.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }
    local actorCoords = getServerCoords(source)

    if actorCoords ~= nil then
        returnPositions[tostring(source)] = actorCoords
    end

    local record = recordUtilityAction('coords', actor, actor, {
        destination = sanitized,
        returnStored = actorCoords ~= nil
    })
    local auditId = writeAdminAudit('admin.utility.coords', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.coords', record)
    markTeleportAllowance(source, 'admin_teleport', {
        actorSource = source,
        action = 'coords',
        auditId = auditId
    })
    sendUtilityToClient(source, {
        type = 'teleport',
        coords = sanitized
    })

    return buildResponse(true, 'OK', 'Koordinaten-Teleport wurde ausgefuehrt.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function prepareAdminHeal(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.heal.prepare')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityPreparedPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Heal-Vorbereitung.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordUtilityAction('heal.prepare', actor, target, {
        reason = sanitized.reason,
        preparedOnly = NexaAdminServer.utility.healPreparedOnly == true
    })
    local auditId = writeAdminAudit('admin.utility.heal.prepared', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.heal.prepared', record)
    markGodmodeException(target.source, 'admin_heal', {
        actorSource = source,
        action = 'heal.prepare',
        auditId = auditId
    })
    sendUtilityToClient(target.source, {
        type = 'heal_prepare',
        reason = sanitized.reason
    })

    return buildResponse(true, 'OK', 'Admin-Heal wurde vorbereitet.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function prepareAdminRevive(source, payload)
    local allowed, denied = ensureUtilityAccess(source, 'admin.utility.revive.prepare')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateUtilityPreparedPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Revive-Vorbereitung.', nil, nil, nil)
    end

    local actor, target, targetError = ensureModerationTarget(source, sanitized.targetSource)

    if targetError ~= nil then
        return targetError
    end

    local record = recordUtilityAction('revive.prepare', actor, target, {
        reason = sanitized.reason,
        preparedOnly = NexaAdminServer.utility.revivePreparedOnly == true,
        emsOverride = false
    })
    local auditId = writeAdminAudit('admin.utility.revive.prepared', source, sanitizeUtilityRecord(record))

    writeUtilityLog('admin.utility.revive.prepared', record)
    markGodmodeException(target.source, 'admin_revive', {
        actorSource = source,
        action = 'revive.prepare',
        auditId = auditId
    })
    sendUtilityToClient(target.source, {
        type = 'revive_prepare',
        reason = sanitized.reason
    })

    return buildResponse(true, 'OK', 'Admin-Revive wurde vorbereitet.', {
        action = sanitizeUtilityRecord(record)
    }, nil, auditId)
end

local function createReport(source, payload)
    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local valid, code, sanitized = validateReportCreatePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Report-Daten.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source)

    if actor == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if countOpenReportsForCharacter(actor.characterId) >= NexaAdminServer.reports.maxOpenPerPlayer then
        return buildResponse(false, 'CONFLICT', 'Du hast bereits zu viele offene Reports.', nil, nil, nil)
    end

    if countReports() >= NexaAdminServer.reports.maxReports then
        return buildResponse(false, 'CONFLICT', 'Aktuell koennen keine weiteren Reports erstellt werden.', nil, nil, nil)
    end

    reportSequence = reportSequence + 1
    local reportId = ('RPT-%06d'):format(reportSequence)
    local now = os.time()

    reports[reportId] = {
        id = reportId,
        ownerSource = actor.source,
        ownerName = actor.name,
        ownerCharacterId = actor.characterId,
        ownerDisplayName = actor.displayName,
        category = sanitized.category,
        subject = sanitized.subject,
        message = sanitized.message,
        status = 'open',
        history = {},
        createdAt = now,
        updatedAt = now
    }

    addReportHistory(reports[reportId], 'report.created', actor, {
        category = sanitized.category
    })

    local auditId = writeAdminAudit('admin.report.created', source, {
        source = source,
        reportId = reportId,
        ownerCharacterId = actor.characterId,
        category = sanitized.category
    })

    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Report wurde erstellt.', {
        source = source,
        reportId = reportId
    })

    return buildResponse(true, 'CREATED', 'Report wurde erstellt.', {
        report = sanitizeReport(reports[reportId], false)
    }, nil, auditId)
end

local function listOwnReports(source)
    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source)

    if actor == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local ownReports = {}

    for _, report in pairs(reports) do
        if tonumber(report.ownerCharacterId) == tonumber(actor.characterId) then
            ownReports[#ownReports + 1] = sanitizeReport(report, false)
        end
    end

    return buildResponse(true, 'OK', 'Deine Reports wurden geladen.', {
        reports = ownReports
    }, nil, nil)
end

local function listReports(source)
    local allowed, denied = ensureAdminAccess(source, 'admin.reports.view')

    if not allowed then
        return denied
    end

    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local result = {}

    for _, report in pairs(reports) do
        result[#result + 1] = sanitizeReport(report, true)
    end

    local auditId = writeAdminAudit('admin.reports.list', source, {
        source = source,
        count = #result
    })

    return buildResponse(true, 'OK', 'Reports wurden geladen.', {
        reports = result
    }, nil, auditId)
end

local function getReportHistory(source, payload)
    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local valid, code = validateReportIdPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Report-Anfrage.', nil, nil, nil)
    end

    local report = reports[payload.reportId]

    if report == nil then
        return buildResponse(false, 'NOT_FOUND', 'Report wurde nicht gefunden.', nil, nil, nil)
    end

    local includeAdminFields = false

    if isReportOwner(source, report) then
        includeAdminFields = false
    elseif hasPermission(source, 'admin.reports.view') then
        includeAdminFields = true
    else
        local auditId = writeAdminAudit('admin.report.history.denied', source, {
            source = source,
            reportId = payload.reportId
        })

        return buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, auditId)
    end

    return buildResponse(true, 'OK', 'Report-Historie wurde geladen.', {
        report = sanitizeReport(report, includeAdminFields)
    }, nil, nil)
end

local function acceptReport(source, payload)
    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, 'admin.reports.accept')

    if not allowed then
        return denied
    end

    local valid, code = validateReportIdPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Report-Anfrage.', nil, nil, nil)
    end

    local report = reports[payload.reportId]

    if report == nil then
        return buildResponse(false, 'NOT_FOUND', 'Report wurde nicht gefunden.', nil, nil, nil)
    end

    if report.status ~= 'open' then
        return buildResponse(false, 'CONFLICT', 'Report kann nicht angenommen werden.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }

    report.status = 'accepted'
    report.acceptedBy = actor
    report.updatedAt = os.time()
    addReportHistory(report, 'report.accepted', actor, {})

    local auditId = writeAdminAudit('admin.report.accepted', source, {
        source = source,
        reportId = report.id
    })

    return buildResponse(true, 'OK', 'Report wurde angenommen.', {
        report = sanitizeReport(report, true)
    }, nil, auditId)
end

local function closeReport(source, payload)
    if not areReportsEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Reports sind deaktiviert.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, 'admin.reports.close')

    if not allowed then
        return denied
    end

    local valid, code, sanitized = validateReportClosePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Report-Anfrage.', nil, nil, nil)
    end

    local report = reports[payload.reportId]

    if report == nil then
        return buildResponse(false, 'NOT_FOUND', 'Report wurde nicht gefunden.', nil, nil, nil)
    end

    if report.status == 'closed' then
        return buildResponse(false, 'CONFLICT', 'Report ist bereits geschlossen.', nil, nil, nil)
    end

    local actor = getActorSnapshot(source) or {
        source = tonumber(source),
        name = GetPlayerName(source) or 'Admin'
    }

    report.status = 'closed'
    report.closedBy = actor
    report.closeReason = sanitized.reason
    report.closedAt = os.time()
    report.updatedAt = report.closedAt
    addReportHistory(report, 'report.closed', actor, {
        reason = sanitized.reason
    })

    local auditId = writeAdminAudit('admin.report.closed', source, {
        source = source,
        reportId = report.id,
        reason = sanitized.reason
    })

    return buildResponse(true, 'OK', 'Report wurde geschlossen.', {
        report = sanitizeReport(report, true)
    }, nil, auditId)
end

local function listPlayers(source)
    local allowed, denied = ensureAdminAccess(source, 'admin.players.view')

    if not allowed then
        return denied
    end

    local players = {}

    for _, playerSource in ipairs(GetPlayers()) do
        if #players >= NexaAdminServer.overview.maxPlayers then
            break
        end

        players[#players + 1] = sanitizePlayer(playerSource)
    end

    local auditId = writeAdminAudit('admin.players.list', source, {
        source = source,
        count = #players
    })

    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Admin-Spieleruebersicht wurde serverseitig geladen.', {
        source = source,
        count = #players
    })

    return buildResponse(true, 'OK', 'Spieleruebersicht wurde geladen.', {
        players = players
    }, nil, auditId)
end

local function getMenu(source)
    local allowed, denied = ensureAdminAccess(source, 'admin.menu')

    if not allowed then
        return denied
    end

    local role = getRoleForSource(source)
    local actions = {}

    for _, action in ipairs(NexaAdminServer.actions) do
        if hasPermission(source, action.permission) then
            actions[#actions + 1] = {
                id = action.id,
                label = action.label,
                contract = action.contract
            }
        end
    end

    local auditId = writeAdminAudit('admin.menu.open', source, {
        source = source,
        role = role and role.id or nil,
        actionCount = #actions
    })

    return buildResponse(true, 'OK', 'Admin-Menue wurde geladen.', {
        role = role,
        actions = actions
    }, nil, auditId)
end

local function validateAction(source, payload)
    local valid, code = validateAdminActionPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Admin-Anfrage.', nil, nil, nil)
    end

    local action = actionIndex[payload.actionId]

    if action == nil then
        return buildResponse(false, 'NOT_FOUND', 'Admin-Aktion wurde nicht gefunden.', nil, nil, nil)
    end

    local allowed, denied = ensureAdminAccess(source, action.permission)

    if not allowed then
        return denied
    end

    local auditId = writeAdminAudit('admin.action.contractValidated', source, {
        source = source,
        actionId = action.id,
        targetSource = payload.targetSource,
        contract = action.contract
    })

    return buildResponse(true, 'OK', 'Admin-Aktion wurde serverseitig validiert.', {
        actionId = action.id,
        contract = action.contract,
        allowed = true
    }, nil, auditId)
end

local function getStatus()
    return {
        resourceName = NEXA_ADMIN.resourceName,
        version = NEXA_ADMIN.version,
        enabled = isEnabled(),
        actionCount = #NexaAdminServer.actions
    }
end

local function rebuildActionIndex()
    actionIndex = {}

    for _, action in ipairs(NexaAdminServer.actions) do
        actionIndex[action.id] = action
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    rebuildActionIndex()

    exports.nexa_logs:info(NEXA_ADMIN.resourceName, 'Admin-Core gestartet.', {
        version = NEXA_ADMIN.version,
        featureFlag = NexaAdminConfig.featureFlag
    })
end)

rebuildActionIndex()

exports('getStatus', getStatus)
exports('admin.getMenu', getMenu)
exports('admin.listPlayers', listPlayers)
exports('admin.validateAction', validateAction)
exports('admin.reports.create', createReport)
exports('admin.reports.listOwn', listOwnReports)
exports('admin.reports.list', listReports)
exports('admin.reports.history', getReportHistory)
exports('admin.reports.accept', acceptReport)
exports('admin.reports.close', closeReport)
exports('admin.tickets.create', createTicket)
exports('admin.tickets.list', listTickets)
exports('admin.tickets.assign', assignTicket)
exports('admin.tickets.close', closeTicket)
exports('admin.moderation.list', listModerationActions)
exports('admin.moderation.warn', warnPlayer)
exports('admin.moderation.kick', kickPlayer)
exports('admin.moderation.tempban.prepare', prepareTempban)
exports('admin.moderation.freeze', setPlayerFrozen)
exports('admin.moderation.spectate.prepare', prepareSpectate)
exports('admin.moderation.notes.add', addAdminNote)
exports('admin.moderation.notes.list', listAdminNotes)
exports('admin.utility.list', listUtilityActions)
exports('admin.utility.bring', bringPlayer)
exports('admin.utility.goto', gotoPlayer)
exports('admin.utility.return', returnPlayer)
exports('admin.utility.coords', teleportToCoords)
exports('admin.utility.heal.prepare', prepareAdminHeal)
exports('admin.utility.revive.prepare', prepareAdminRevive)
