NexaDevtoolsServer = {
    allowedEnvironments = {
        development = true
    },
    commands = {
        status = 'nexa_devtools_status',
        ping = 'nexa_devtools_ping',
        contracts = 'nexa_devtools_contracts'
    },
    forbiddenCommandFragments = {
        'give',
        'item',
        'money',
        'cash',
        'bank',
        'weapon',
        'ban',
        'kick',
        'teleport',
        'revive',
        'heal',
        'god'
    }
}
