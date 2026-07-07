NexaMoneywashServer = {
    cooldowns = {
        wash = 'moneywash.wash'
    },
    stations = {
        vespucci_laundry = {
            dirtyItem = 'dirty_money',
            ratePercent = 80,
            minAmount = 100,
            maxAmount = 1000,
            reputationType = 'moneywash',
            reputationDelta = 2
        },
        sandy_cleaners = {
            dirtyItem = 'dirty_money',
            ratePercent = 75,
            minAmount = 250,
            maxAmount = 1000,
            reputationType = 'moneywash',
            reputationDelta = 3
        }
    }
}
