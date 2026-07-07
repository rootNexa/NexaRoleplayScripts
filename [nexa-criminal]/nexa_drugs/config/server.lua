NexaDrugsServer = {
    cooldowns = {
        plant = 'drugs.plant',
        harvest = 'drugs.harvest',
        process = 'drugs.process',
        sell = 'drugs.sell'
    },
    crops = {
        weed = {
            seedItem = 'weed_seed',
            rawItem = 'weed_leaf',
            growthSeconds = 1800,
            harvestAmount = 4,
            maxActive = 3,
            reputationType = 'drugs',
            reputationDelta = 1
        }
    },
    recipes = {
        weed_bag = {
            inputItem = 'weed_leaf',
            inputAmount = 2,
            outputItem = 'weed_bag',
            outputAmount = 1,
            reputationType = 'drugs',
            reputationDelta = 2
        }
    },
    buyers = {
        southside_contact = {
            itemName = 'weed_bag',
            unitPrice = 350,
            maxAmount = 5,
            reputationType = 'drugs',
            reputationDelta = 3
        },
        sandy_contact = {
            itemName = 'weed_bag',
            unitPrice = 300,
            maxAmount = 4,
            reputationType = 'drugs',
            reputationDelta = 2
        }
    }
}
