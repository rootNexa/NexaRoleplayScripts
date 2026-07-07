NexaChopshopServer = {
    cooldowns = {
        dismantle = 'chopshop.dismantle',
        sell = 'chopshop.sell'
    },
    yards = {
        la_puerta_yard = {
            allowedStatuses = { active = true, stored = true },
            rewards = {
                { itemName = 'vehicle_parts', count = 4 },
                { itemName = 'scrap_metal', count = 8 }
            },
            reputationType = 'chopshop',
            reputationDelta = 3
        },
        sandy_yard = {
            allowedStatuses = { active = true, stored = true },
            rewards = {
                { itemName = 'vehicle_parts', count = 3 },
                { itemName = 'scrap_metal', count = 10 }
            },
            reputationType = 'chopshop',
            reputationDelta = 2
        }
    },
    buyers = {
        parts_broker = {
            items = {
                vehicle_parts = 275,
                scrap_metal = 45
            },
            maxAmount = 25,
            reputationType = 'chopshop',
            reputationDelta = 1
        }
    }
}
