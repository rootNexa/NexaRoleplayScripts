NEXA_BOOTSTRAP = {
    resourceName = 'nexa_bootstrap',
    version = '0.1.0',
    allowedEnvironments = {
        development = true,
        staging = true,
        production = true
    },
    requiredResources = {
        'oxmysql',
        'ox_lib',
        'qbx_core',
        'ox_inventory',
        'ox_target',
        'nexa_config',
        'nexa_locales',
        'nexa_audit',
        'nexa_logs',
        'nexa_security',
        'nexa_permissions',
        'nexa_featureflags'
    }
}
