NexaVehicleDealerServerConfig = {
    defaultGarageName = 'stadtgarage',
    maxDealerIdLength = 64,
    maxCatalogIdLength = 64,
    maxCatalogItems = 50,
    purchaseLockTtlMs = 15000,
    callbackRateLimits = {
        catalog = 'nexa:vehicledealer:cb:getCatalog',
        purchase = 'nexa:vehicledealer:cb:purchaseVehicle',
        prepareSale = 'nexa:vehicledealer:cb:prepareSale'
    },
    dealers = {
        {
            id = 'premium_deluxe',
            label = 'Premium Deluxe Motorsport',
            garageName = 'stadtgarage',
            isActive = true,
            catalog = {
                {
                    id = 'compacts_blista',
                    model = 'blista',
                    label = 'Blista',
                    vehicleType = 'car',
                    price = 18000
                },
                {
                    id = 'sedans_asea',
                    model = 'asea',
                    label = 'Asea',
                    vehicleType = 'car',
                    price = 22000
                },
                {
                    id = 'sedans_tailgater',
                    model = 'tailgater',
                    label = 'Tailgater',
                    vehicleType = 'car',
                    price = 52000
                },
                {
                    id = 'sports_sultan',
                    model = 'sultan',
                    label = 'Sultan',
                    vehicleType = 'car',
                    price = 84000
                }
            }
        }
    }
}
