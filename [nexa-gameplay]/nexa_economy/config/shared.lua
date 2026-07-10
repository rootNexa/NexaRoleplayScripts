NexaEconomyConfig = {
    autoMigrate = true,
    maxAmount = 2147483647,
    defaultCurrency = 'bank',
    cashItem = 'currency_cash',
    dirtyCashItem = 'currency_dirty_cash',
    defaultCharacterAccountType = 'character_bank',
    defaultReservationTtlSeconds = 300,
    requireReasonForAdminMutations = true,
    callbacks = {
        rateLimitMs = 750
    },
    permissions = {
        view = 'nexa.admin.money.view',
        modify = 'nexa.admin.money.modify'
    }
}
