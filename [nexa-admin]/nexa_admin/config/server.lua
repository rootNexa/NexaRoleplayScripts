NexaAdminServer = {
    roles = {
        {
            id = 'support',
            label = 'Support',
            permissions = {
                'admin.menu',
                'admin.players.view',
                'admin.actions.preview',
                'admin.reports.view',
                'admin.tickets.view',
                'admin.moderation.notes.add'
            }
        },
        {
            id = 'team',
            label = 'Team',
            permissions = {
                'admin.menu',
                'admin.players.view',
                'admin.actions.preview',
                'admin.audit.view',
                'admin.reports.view',
                'admin.reports.accept',
                'admin.reports.close',
                'admin.tickets.view',
                'admin.tickets.assign',
                'admin.tickets.close',
                'admin.moderation.warn',
                'admin.moderation.kick',
                'admin.moderation.freeze',
                'admin.moderation.spectate.prepare',
                'admin.moderation.notes.add',
                'admin.moderation.notes.view',
                'admin.utility.bring',
                'admin.utility.goto',
                'admin.utility.return',
                'admin.utility.coords',
                'admin.utility.heal.prepare',
                'admin.utility.revive.prepare'
            }
        },
        {
            id = 'admin',
            label = 'Administration',
            permissions = {
                'admin.menu',
                'admin.players.view',
                'admin.actions.preview',
                'admin.audit.view',
                'admin.permissions.view',
                'admin.reports.view',
                'admin.reports.accept',
                'admin.reports.close',
                'admin.tickets.view',
                'admin.tickets.assign',
                'admin.tickets.close',
                'admin.moderation.warn',
                'admin.moderation.kick',
                'admin.moderation.freeze',
                'admin.moderation.tempban.prepare',
                'admin.moderation.spectate.prepare',
                'admin.moderation.notes.add',
                'admin.moderation.notes.view',
                'admin.utility.bring',
                'admin.utility.goto',
                'admin.utility.return',
                'admin.utility.coords',
                'admin.utility.heal.prepare',
                'admin.utility.revive.prepare'
            }
        }
    },
    actions = {
        {
            id = 'player_overview',
            label = 'Spieleruebersicht ansehen',
            permission = 'admin.players.view',
            audit = true,
            contract = 'admin.listPlayers'
        },
        {
            id = 'player_inspect',
            label = 'Spielerdaten pruefen',
            permission = 'admin.players.view',
            audit = true,
            contract = 'admin.inspectPlayer'
        },
        {
            id = 'resource_status',
            label = 'Resource-Status ansehen',
            permission = 'admin.audit.view',
            audit = true,
            contract = 'admin.getResourceStatus'
        },
        {
            id = 'reports_overview',
            label = 'Reports ansehen',
            permission = 'admin.reports.view',
            audit = true,
            contract = 'admin.reports.list'
        },
        {
            id = 'tickets_overview',
            label = 'Tickets ansehen',
            permission = 'admin.tickets.view',
            audit = true,
            contract = 'admin.tickets.list'
        },
        {
            id = 'moderation_overview',
            label = 'Moderation',
            permission = 'admin.moderation.warn',
            audit = true,
            contract = 'admin.moderation.list'
        },
        {
            id = 'utility_overview',
            label = 'Admin-Utility',
            permission = 'admin.utility.goto',
            audit = true,
            contract = 'admin.utility.list'
        }
    },
    overview = {
        maxPlayers = 64,
        includeIdentifiers = false
    },
    reports = {
        maxOpenPerPlayer = 3,
        maxReports = 250,
        historyLimit = 20,
        categories = {
            support = 'Support',
            bug = 'Fehler melden',
            rule = 'Regelfrage',
            other = 'Sonstiges'
        }
    },
    tickets = {
        maxOpenPerPlayer = 2,
        maxTickets = 250,
        reasons = {
            support = 'Support',
            technical = 'Technisches Problem',
            roleplay = 'RP-Klaerung',
            other = 'Sonstiges'
        }
    },
    moderation = {
        maxNotesPerTarget = 25,
        tempbanPreparedOnly = true,
        spectatePreparedOnly = true,
        allowedFreezeStates = {
            frozen = true,
            unfrozen = true
        }
    },
    utility = {
        maxCoordinateDistance = 20000.0,
        healPreparedOnly = true,
        revivePreparedOnly = true
    }
}
