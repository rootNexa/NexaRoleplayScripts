NexaFuelServerConfig = {
    maxStationIdLength = 64,
    maxStations = 25,
    maxFuelLiters = 80,
    maxConsumptionDelta = 10,
    minConsumptionPersistDelta = 0.5,
    maxStationDistance = 12.0,
    pricePerLiter = 12,
    callbackRateLimits = {
        stations = 'nexa:fuel:cb:getStations',
        fuel = 'nexa:fuel:cb:getFuel',
        purchase = 'nexa:fuel:cb:purchaseFuel',
        consumption = 'nexa:fuel:cb:reportConsumption'
    },
    stations = {
        {
            id = 'little_seoul_ltd',
            label = 'LTD Little Seoul',
            pricePerLiter = 12,
            isActive = true,
            coords = {
                x = -706.12,
                y = -915.42,
                z = 19.22
            }
        },
        {
            id = 'sandy_ron',
            label = 'RON Sandy Shores',
            pricePerLiter = 10,
            isActive = true,
            coords = {
                x = 2001.91,
                y = 3779.44,
                z = 32.18
            }
        },
        {
            id = 'paleto_ltd',
            label = 'LTD Paleto Bay',
            pricePerLiter = 11,
            isActive = true,
            coords = {
                x = 1702.95,
                y = 6416.94,
                z = 32.76
            }
        }
    }
}
