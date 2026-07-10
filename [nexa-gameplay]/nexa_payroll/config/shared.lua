NexaPayrollConfig = {
    autoMigrate = true,
    defaultIntervalSeconds = 7200,
    defaultFundingPolicy = 'all_or_nothing',
    maxAmount = 2147483647,
    permissions = {
        view = 'nexa.payroll.view',
        manage = 'nexa.payroll.manage',
        run = 'nexa.payroll.run',
        retry = 'nexa.payroll.retry',
        cancel = 'nexa.payroll.cancel'
    }
}
