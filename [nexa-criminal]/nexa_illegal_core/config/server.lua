NexaIllegalCoreServer = {
    permissions = {
        view = 'criminal.reputation.view',
        adjust = 'criminal.reputation.adjust',
        cooldownBypass = 'criminal.cooldown.bypass',
        audit = 'criminal.audit'
    },
    cooldowns = {
        ['illegal.contact'] = 300,
        ['illegal.reputation.adjust'] = 30,
        ['blackmarket.buy'] = 120,
        ['blackmarket.sell'] = 120,
        ['drugs.plant'] = 180,
        ['drugs.harvest'] = 90,
        ['drugs.process'] = 120,
        ['drugs.sell'] = 120,
        ['moneywash.wash'] = 300,
        ['chopshop.dismantle'] = 600,
        ['chopshop.sell'] = 120
    }
}
