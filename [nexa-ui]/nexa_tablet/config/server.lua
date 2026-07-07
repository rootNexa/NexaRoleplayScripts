NexaTabletServerConfig = {
    callbackRateLimit = 'nexa:tablet:cb:getApps',
    placeholderApps = {
        {
            id = 'job',
            title = 'Dienst',
            description = 'Platzhalter fuer spaetere Dienst-App. Noch nicht freigeschaltet.',
            icon = 'briefcase',
            permission = 'job.tablet.view',
            disabled = true,
            documented = true
        },
        {
            id = 'business',
            title = 'Firmen',
            description = 'Platzhalter fuer spaetere Firmen-App. Noch nicht freigeschaltet.',
            icon = 'building',
            permission = 'business.tablet.view',
            disabled = true,
            documented = true
        },
        {
            id = 'faction',
            title = 'Gruppen',
            description = 'Platzhalter fuer spaetere Gruppen-App. Noch nicht freigeschaltet.',
            icon = 'users',
            permission = 'faction.tablet.view',
            disabled = true,
            documented = true
        }
    }
}
