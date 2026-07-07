local function notify(message, notifyType)
    lib.notify({
        title = 'Teamverwaltung',
        description = message,
        type = notifyType or 'inform'
    })
end

local function buildPlayerOptions(players)
    local options = {}

    for _, player in ipairs(players or {}) do
        options[#options + 1] = {
            title = ('%s [%s]'):format(player.name or 'Unbekannter Spieler', tostring(player.source)),
            description = 'Serverseitig geladene Spieleruebersicht',
            icon = 'user'
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = 'Keine Spieler gefunden',
            icon = 'circle-info',
            disabled = true
        }
    end

    return options
end

local function openPlayerOverview()
    local response = lib.callback.await('nexa:admin:cb:listPlayers', false)

    if type(response) ~= 'table' or response.success ~= true then
        notify(response and response.message or 'Spieleruebersicht konnte nicht geladen werden.', 'error')
        return
    end

    lib.registerContext({
        id = 'nexa_admin_players',
        title = 'Spieleruebersicht',
        menu = 'nexa_admin_main',
        options = buildPlayerOptions(response.data and response.data.players or {})
    })

    lib.showContext('nexa_admin_players')
end

local function askTargetAndReason(title, reasonLabel)
    return lib.inputDialog(title, {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        },
        {
            type = 'textarea',
            label = reasonLabel or 'Grund',
            required = true,
            min = 3,
            max = 240
        }
    })
end

local function runSimpleModerationCallback(callbackName, title, reasonLabel)
    local input = askTargetAndReason(title, reasonLabel)

    if input == nil then
        return
    end

    local response = lib.callback.await(callbackName, false, {
        targetSource = input[1],
        reason = input[2]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Moderationsaktion konnte nicht ausgefuehrt werden.', 'error')
end

local function warnPlayer()
    runSimpleModerationCallback('nexa:admin:cb:warnPlayer', 'Spieler verwarnen', 'Verwarnungsgrund')
end

local function kickPlayer()
    runSimpleModerationCallback('nexa:admin:cb:kickPlayer', 'Spieler kicken', 'Kick-Grund')
end

local function prepareTempban()
    local input = lib.inputDialog('Tempban vorbereiten', {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        },
        {
            type = 'number',
            label = 'Dauer in Minuten',
            required = true,
            min = 5,
            max = 43200
        },
        {
            type = 'textarea',
            label = 'Grund',
            required = true,
            min = 3,
            max = 240
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:prepareTempban', false, {
        targetSource = input[1],
        durationMinutes = input[2],
        reason = input[3]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Tempban konnte nicht vorbereitet werden.', 'error')
end

local function setPlayerFrozen(state)
    local input = askTargetAndReason(state == 'frozen' and 'Spieler einfrieren' or 'Spieler freigeben', 'Grund')

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:setPlayerFrozen', false, {
        targetSource = input[1],
        state = state,
        reason = input[2]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Freeze-Status konnte nicht geaendert werden.', 'error')
end

local function prepareSpectate()
    local input = lib.inputDialog('Spectate vorbereiten', {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:prepareSpectate', false, {
        targetSource = input[1]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Spectate konnte nicht vorbereitet werden.', 'error')
end

local function addAdminNote()
    local input = lib.inputDialog('Admin-Notiz', {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        },
        {
            type = 'textarea',
            label = 'Notiz',
            required = true,
            min = 4,
            max = 1000
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:addAdminNote', false, {
        targetSource = input[1],
        reason = input[2]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Admin-Notiz konnte nicht gespeichert werden.', 'error')
end

local function openModerationOverview()
    local options = {
        {
            title = 'Verwarnen',
            icon = 'triangle-alert',
            onSelect = warnPlayer
        },
        {
            title = 'Kicken',
            icon = 'log-out',
            onSelect = kickPlayer
        },
        {
            title = 'Tempban vorbereiten',
            icon = 'timer',
            onSelect = prepareTempban
        },
        {
            title = 'Einfrieren',
            icon = 'snowflake',
            onSelect = function()
                setPlayerFrozen('frozen')
            end
        },
        {
            title = 'Freigeben',
            icon = 'unlock',
            onSelect = function()
                setPlayerFrozen('unfrozen')
            end
        },
        {
            title = 'Spectate vorbereiten',
            icon = 'eye',
            onSelect = prepareSpectate
        },
        {
            title = 'Admin-Notiz',
            icon = 'notebook-pen',
            onSelect = addAdminNote
        }
    }

    lib.registerContext({
        id = 'nexa_admin_moderation',
        title = 'Moderation',
        menu = 'nexa_admin_main',
        options = options
    })

    lib.showContext('nexa_admin_moderation')
end

local function askTarget(title)
    return lib.inputDialog(title, {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        }
    })
end

local function runTargetUtility(callbackName, title)
    local input = askTarget(title)

    if input == nil then
        return
    end

    local response = lib.callback.await(callbackName, false, {
        targetSource = input[1]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Admin-Utility konnte nicht ausgefuehrt werden.', 'error')
end

local function bringPlayer()
    runTargetUtility('nexa:admin:cb:bringPlayer', 'Spieler bringen')
end

local function gotoPlayer()
    runTargetUtility('nexa:admin:cb:gotoPlayer', 'Zu Spieler teleportieren')
end

local function returnPlayer()
    runTargetUtility('nexa:admin:cb:returnPlayer', 'Spieler zuruecksetzen')
end

local function teleportToCoords()
    local input = lib.inputDialog('Koordinaten-Teleport', {
        {
            type = 'number',
            label = 'X',
            required = true
        },
        {
            type = 'number',
            label = 'Y',
            required = true
        },
        {
            type = 'number',
            label = 'Z',
            required = true
        },
        {
            type = 'number',
            label = 'Heading',
            required = false
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:teleportToCoords', false, {
        x = input[1],
        y = input[2],
        z = input[3],
        heading = input[4] or 0.0
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Koordinaten-Teleport konnte nicht ausgefuehrt werden.', 'error')
end

local function runPreparedUtility(callbackName, title)
    local input = lib.inputDialog(title, {
        {
            type = 'number',
            label = 'Spieler-ID',
            required = true,
            min = 1
        },
        {
            type = 'textarea',
            label = 'Grund',
            required = true,
            min = 3,
            max = 240
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await(callbackName, false, {
        targetSource = input[1],
        reason = input[2]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Admin-Utility konnte nicht vorbereitet werden.', 'error')
end

local function prepareAdminHeal()
    runPreparedUtility('nexa:admin:cb:prepareAdminHeal', 'Admin-Heal vorbereiten')
end

local function prepareAdminRevive()
    runPreparedUtility('nexa:admin:cb:prepareAdminRevive', 'Admin-Revive vorbereiten')
end

local function openUtilityOverview()
    local options = {
        {
            title = 'Bring',
            icon = 'user-round-plus',
            onSelect = bringPlayer
        },
        {
            title = 'GoTo',
            icon = 'move-right',
            onSelect = gotoPlayer
        },
        {
            title = 'Return',
            icon = 'undo-2',
            onSelect = returnPlayer
        },
        {
            title = 'Koordinaten',
            icon = 'map-pin',
            onSelect = teleportToCoords
        },
        {
            title = 'Heal vorbereiten',
            icon = 'heart-pulse',
            onSelect = prepareAdminHeal
        },
        {
            title = 'Revive vorbereiten',
            icon = 'shield-plus',
            onSelect = prepareAdminRevive
        }
    }

    lib.registerContext({
        id = 'nexa_admin_utility',
        title = 'Admin-Utility',
        menu = 'nexa_admin_main',
        options = options
    })

    lib.showContext('nexa_admin_utility')
end

local function reportStatusLabel(status)
    if status == 'open' then
        return 'Offen'
    end

    if status == 'accepted' then
        return 'Angenommen'
    end

    if status == 'closed' then
        return 'Geschlossen'
    end

    return 'Unbekannt'
end

local function ticketStatusLabel(status)
    if status == 'open' then
        return 'Offen'
    end

    if status == 'assigned' then
        return 'Zugewiesen'
    end

    if status == 'closed' then
        return 'Geschlossen'
    end

    return 'Unbekannt'
end

local function openOwnReports()
    local response = lib.callback.await('nexa:admin:cb:listOwnReports', false)

    if type(response) ~= 'table' or response.success ~= true then
        notify(response and response.message or 'Reports konnten nicht geladen werden.', 'error')
        return
    end

    local options = {}

    for _, report in ipairs(response.data and response.data.reports or {}) do
        options[#options + 1] = {
            title = ('%s - %s'):format(report.id, report.subject),
            description = reportStatusLabel(report.status),
            icon = 'message-square'
        }
    end

    if #options == 0 then
        options[1] = {
            title = 'Keine Reports vorhanden',
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'nexa_admin_own_reports',
        title = 'Meine Reports',
        menu = 'nexa_admin_main',
        options = options
    })

    lib.showContext('nexa_admin_own_reports')
end

local function createReport()
    local input = lib.inputDialog('Report erstellen', {
        {
            type = 'select',
            label = 'Kategorie',
            required = true,
            options = {
                { value = 'support', label = 'Support' },
                { value = 'bug', label = 'Fehler melden' },
                { value = 'rule', label = 'Regelfrage' },
                { value = 'other', label = 'Sonstiges' }
            }
        },
        {
            type = 'input',
            label = 'Betreff',
            required = true,
            min = 8,
            max = 80
        },
        {
            type = 'textarea',
            label = 'Beschreibung',
            required = true,
            min = 16,
            max = 1000
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:createReport', false, {
        category = input[1],
        subject = input[2],
        message = input[3]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Report konnte nicht erstellt werden.', 'error')
end

local function createTicket()
    local input = lib.inputDialog('Ticket erstellen', {
        {
            type = 'select',
            label = 'Grund',
            required = true,
            options = {
                { value = 'support', label = 'Support' },
                { value = 'technical', label = 'Technisches Problem' },
                { value = 'roleplay', label = 'RP-Klaerung' },
                { value = 'other', label = 'Sonstiges' }
            }
        },
        {
            type = 'textarea',
            label = 'Beschreibung',
            required = true,
            min = 12,
            max = 1000
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:createTicket', false, {
        reason = input[1],
        description = input[2]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Ticket konnte nicht erstellt werden.', 'error')
end

local function assignTicket(ticketId)
    local response = lib.callback.await('nexa:admin:cb:assignTicket', false, {
        ticketId = ticketId
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Ticket konnte nicht zugewiesen werden.', 'error')
end

local function closeTicket(ticketId)
    local input = lib.inputDialog('Ticket schliessen', {
        {
            type = 'textarea',
            label = 'Abschlussnotiz',
            required = true,
            min = 3,
            max = 240
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:closeTicket', false, {
        ticketId = ticketId,
        note = input[1]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Ticket konnte nicht geschlossen werden.', 'error')
end

local function openTicketActions(ticket)
    local options = {
        {
            title = 'Mir zuweisen',
            description = ticket.id,
            icon = 'user-check',
            disabled = ticket.status == 'closed',
            onSelect = function()
                assignTicket(ticket.id)
            end
        },
        {
            title = 'Schliessen',
            description = ticket.id,
            icon = 'circle-check',
            disabled = ticket.status == 'closed',
            onSelect = function()
                closeTicket(ticket.id)
            end
        }
    }

    lib.registerContext({
        id = 'nexa_admin_ticket_actions',
        title = ticket.reasonLabel or ticket.id,
        menu = 'nexa_admin_tickets',
        options = options
    })

    lib.showContext('nexa_admin_ticket_actions')
end

local function openTicketOverview()
    local response = lib.callback.await('nexa:admin:cb:listTickets', false)

    if type(response) ~= 'table' or response.success ~= true then
        notify(response and response.message or 'Ticketliste konnte nicht geladen werden.', 'error')
        return
    end

    local options = {}

    for _, ticket in ipairs(response.data and response.data.tickets or {}) do
        options[#options + 1] = {
            title = ('%s - %s'):format(ticket.id, ticket.reasonLabel or ticket.reason),
            description = ('%s | %s'):format(ticketStatusLabel(ticket.status), ticket.ownerName or 'Unbekannt'),
            icon = 'ticket',
            onSelect = function()
                openTicketActions(ticket)
            end
        }
    end

    if #options == 0 then
        options[1] = {
            title = 'Keine Tickets vorhanden',
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'nexa_admin_tickets',
        title = 'Tickets',
        menu = 'nexa_admin_main',
        options = options
    })

    lib.showContext('nexa_admin_tickets')
end

local function acceptReport(reportId)
    local response = lib.callback.await('nexa:admin:cb:acceptReport', false, {
        reportId = reportId
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Report konnte nicht angenommen werden.', 'error')
end

local function closeReport(reportId)
    local input = lib.inputDialog('Report schliessen', {
        {
            type = 'textarea',
            label = 'Abschlussnotiz',
            required = true,
            min = 3,
            max = 240
        }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:admin:cb:closeReport', false, {
        reportId = reportId,
        reason = input[1]
    })

    if type(response) == 'table' and response.success == true then
        notify(response.message, 'success')
        return
    end

    notify(response and response.message or 'Report konnte nicht geschlossen werden.', 'error')
end

local function openReportActions(report)
    local options = {
        {
            title = 'Annehmen',
            description = report.id,
            icon = 'handshake',
            disabled = report.status ~= 'open',
            onSelect = function()
                acceptReport(report.id)
            end
        },
        {
            title = 'Schliessen',
            description = report.id,
            icon = 'circle-check',
            disabled = report.status == 'closed',
            onSelect = function()
                closeReport(report.id)
            end
        }
    }

    lib.registerContext({
        id = 'nexa_admin_report_actions',
        title = report.subject,
        menu = 'nexa_admin_reports',
        options = options
    })

    lib.showContext('nexa_admin_report_actions')
end

local function openReportOverview()
    local response = lib.callback.await('nexa:admin:cb:listReports', false)

    if type(response) ~= 'table' or response.success ~= true then
        notify(response and response.message or 'Reportuebersicht konnte nicht geladen werden.', 'error')
        return
    end

    local options = {}

    for _, report in ipairs(response.data and response.data.reports or {}) do
        options[#options + 1] = {
            title = ('%s - %s'):format(report.id, report.subject),
            description = ('%s | %s'):format(reportStatusLabel(report.status), report.ownerName or 'Unbekannt'),
            icon = 'clipboard-list',
            onSelect = function()
                openReportActions(report)
            end
        }
    end

    if #options == 0 then
        options[1] = {
            title = 'Keine Reports vorhanden',
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'nexa_admin_reports',
        title = 'Reports',
        menu = 'nexa_admin_main',
        options = options
    })

    lib.showContext('nexa_admin_reports')
end

local function openAdminMenu()
    local response = lib.callback.await('nexa:admin:cb:getMenu', false)

    if type(response) ~= 'table' or response.success ~= true then
        notify(response and response.message or 'Admin-Menue konnte nicht geladen werden.', 'error')
        return
    end

    local options = {
        {
            title = 'Report erstellen',
            description = 'Supportanfrage an das Team senden',
            icon = 'message-square-plus',
            onSelect = createReport
        },
        {
            title = 'Meine Reports',
            description = 'Eigene Reports anzeigen',
            icon = 'message-square-text',
            onSelect = openOwnReports
        },
        {
            title = 'Spieleruebersicht',
            description = 'Aktive Spieler serverseitig laden',
            icon = 'users',
            onSelect = openPlayerOverview
        }
    }

    for _, action in ipairs(response.data and response.data.actions or {}) do
        local onSelect = nil

        if action.id == 'reports_overview' then
            onSelect = openReportOverview
        end

        if action.id == 'tickets_overview' then
            onSelect = openTicketOverview
        end

        if action.id == 'moderation_overview' then
            onSelect = openModerationOverview
        end

        if action.id == 'utility_overview' then
            onSelect = openUtilityOverview
        end

        options[#options + 1] = {
            title = action.label,
            description = action.contract,
            icon = 'shield-check',
            disabled = onSelect == nil,
            onSelect = onSelect
        }
    end

    lib.registerContext({
        id = 'nexa_admin_main',
        title = NexaAdminClient.menuTitle,
        options = options
    })

    lib.showContext('nexa_admin_main')
end

RegisterCommand(NexaAdminClient.menuCommand, openAdminMenu, false)
RegisterCommand(NexaAdminClient.reportCommand, createReport, false)
RegisterCommand(NexaAdminClient.reportsCommand, openOwnReports, false)
RegisterCommand(NexaAdminClient.ticketCommand, createTicket, false)
RegisterNetEvent(NEXA_ADMIN_EVENTS.refresh, openAdminMenu)
RegisterNetEvent(NEXA_ADMIN_EVENTS.applyControl, function(payload)
    local ped = PlayerPedId()
    local frozen = type(payload) == 'table' and payload.frozen == true

    FreezeEntityPosition(ped, frozen)

    if frozen then
        notify('Du wurdest durch das Team eingefroren.', 'warning')
        return
    end

    notify('Du wurdest durch das Team freigegeben.', 'inform')
end)
RegisterNetEvent(NEXA_ADMIN_EVENTS.applyUtility, function(payload)
    if type(payload) ~= 'table' then
        return
    end

    if payload.type == 'teleport' and type(payload.coords) == 'table' then
        local ped = PlayerPedId()
        local coords = payload.coords

        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, coords.heading or 0.0)
        notify('Admin-Teleport wurde ausgefuehrt.', 'inform')
        return
    end

    if payload.type == 'heal_prepare' then
        notify('Admin-Heal wurde vorbereitet und auditierbar erfasst.', 'inform')
        return
    end

    if payload.type == 'revive_prepare' then
        notify('Admin-Revive wurde vorbereitet; EMS-Logik bleibt unveraendert.', 'inform')
    end
end)
