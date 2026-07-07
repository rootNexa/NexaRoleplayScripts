NexaBlackmarketServer = {
    cooldowns = {
        buy = 'blackmarket.buy',
        sell = 'blackmarket.sell'
    },
    catalog = {
        lockpick_basic = {
            itemName = 'lockpick',
            label = 'Einfaches Werkzeugset',
            category = 'tools',
            buyPrice = 750,
            sellPrice = 250,
            maxAmount = 5,
            dealers = { 'vespucci_broker', 'sandy_runner' }
        },
        radio_scrambler = {
            itemName = 'radio_scrambler',
            label = 'Funkstoerer',
            category = 'parts',
            buyPrice = 2500,
            sellPrice = 900,
            maxAmount = 2,
            dealers = { 'vespucci_broker' }
        },
        blank_card = {
            itemName = 'blank_card',
            label = 'Leere Karte',
            category = 'documents',
            buyPrice = 1200,
            sellPrice = 400,
            maxAmount = 3,
            dealers = { 'sandy_runner' }
        }
    }
}
