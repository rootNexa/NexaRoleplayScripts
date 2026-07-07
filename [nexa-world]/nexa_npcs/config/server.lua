NexaNpcsServer = {
    maxClientNpcs = 64,
    interactionDistance = 3.0,
    npcs = {
        {
            id = 'stadtservice_info',
            label = 'Stadtservice Auskunft',
            category = 'civic',
            ped = {
                model = 'a_m_m_business_01',
                coords = { x = -545.2, y = -204.1, z = 38.2 },
                heading = 210.0,
                scenario = 'WORLD_HUMAN_CLIPBOARD'
            },
            interaction = {
                id = 'city_info',
                label = 'Informationen ansehen',
                icon = 'fa-solid fa-circle-info',
                event = 'nexa:npcs:client:placeholder',
                distance = 2.0,
                critical = false
            },
            permission = nil,
            job = nil,
            faction = nil
        },
        {
            id = 'stadtgarage_empfang',
            label = 'Stadtgarage Empfang',
            category = 'service',
            ped = {
                model = 'a_m_m_business_01',
                coords = { x = 215.8, y = -810.1, z = 30.7 },
                heading = 160.0,
                scenario = 'WORLD_HUMAN_CLIPBOARD'
            },
            interaction = {
                id = 'garage_info',
                label = 'Garagenhinweis ansehen',
                icon = 'fa-solid fa-warehouse',
                event = 'nexa:npcs:client:placeholder',
                distance = 2.0,
                critical = false
            },
            permission = nil,
            job = nil,
            faction = nil
        },
        {
            id = 'werkstatt_planung',
            label = 'Werkstatt Planungspunkt',
            category = 'job',
            ped = {
                model = 'a_m_m_business_01',
                coords = { x = -347.3, y = -133.3, z = 39.0 },
                heading = 250.0,
                scenario = 'WORLD_HUMAN_CLIPBOARD'
            },
            interaction = {
                id = 'mechanic_board',
                label = 'Werkstatttafel ansehen',
                icon = 'fa-solid fa-screwdriver-wrench',
                event = 'nexa:npcs:client:placeholder',
                distance = 2.0,
                critical = false
            },
            permission = nil,
            job = 'mechanic',
            faction = nil
        },
        {
            id = 'presse_empfang',
            label = 'Redaktion Empfang',
            category = 'faction',
            ped = {
                model = 'a_f_y_business_02',
                coords = { x = -598.2, y = -929.9, z = 23.9 },
                heading = 90.0,
                scenario = 'WORLD_HUMAN_CLIPBOARD'
            },
            interaction = {
                id = 'press_desk',
                label = 'Redaktionshinweis ansehen',
                icon = 'fa-solid fa-newspaper',
                event = 'nexa:npcs:client:placeholder',
                distance = 2.0,
                critical = false
            },
            permission = 'weazel.announcement.create',
            job = nil,
            faction = 'weazel'
        }
    }
}
