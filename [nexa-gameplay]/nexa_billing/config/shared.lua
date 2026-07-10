NexaBillingConfig = {
    autoMigrate = true,
    maxItems = 25,
    maxAmount = 2147483647,
    defaultCurrency = 'bank',
    allowPartialPayments = false,
    permissions = {
        view = 'nexa.billing.view',
        create = 'nexa.billing.create',
        cancel = 'nexa.billing.cancel',
        credit = 'nexa.billing.credit',
        adminViewAll = 'nexa.billing.admin.view_all',
        adminModify = 'nexa.billing.admin.modify'
    }
}
