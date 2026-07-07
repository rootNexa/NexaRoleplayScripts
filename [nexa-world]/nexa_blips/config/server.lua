NexaBlipsServer = {
    maxDynamicBlips = 50,
    publicBlips = {
        {
            id = 'city_hall',
            label = 'Rathaus Los Santos',
            category = 'government',
            coords = { x = -545.12, y = -204.18, z = 38.22 },
            sprite = 419,
            color = 0,
            scale = 0.8
        },
        {
            id = 'pillbox_hospital',
            label = 'Pillbox Medical Center',
            category = 'medical',
            coords = { x = 298.63, y = -584.23, z = 43.26 },
            sprite = 61,
            color = 2,
            scale = 0.85
        },
        {
            id = 'legion_garage',
            label = 'Stadtgarage Legion Square',
            category = 'garage',
            coords = { x = 215.8, y = -810.12, z = 30.73 },
            sprite = 357,
            color = 3,
            scale = 0.75
        },
        {
            id = 'little_seoul_ltd',
            label = 'LTD Little Seoul',
            category = 'shop',
            coords = { x = -706.12, y = -914.55, z = 19.22 },
            sprite = 52,
            color = 2,
            scale = 0.7
        },
        {
            id = 'sandy_fuel',
            label = 'RON Sandy Shores',
            category = 'fuel',
            coords = { x = 2001.31, y = 3779.72, z = 32.18 },
            sprite = 361,
            color = 1,
            scale = 0.75
        }
    },
    restrictedBlips = {
        {
            id = 'mission_row_pd',
            label = 'Mission Row Police Department',
            category = 'faction',
            faction = 'lspd',
            permission = 'police.mdt.view',
            coords = { x = 441.21, y = -981.92, z = 30.69 },
            sprite = 60,
            color = 29,
            scale = 0.8
        },
        {
            id = 'ems_station',
            label = 'SAMS Dienststelle',
            category = 'faction',
            faction = 'ems',
            permission = 'ems.records.view',
            coords = { x = 307.24, y = -1433.41, z = 29.86 },
            sprite = 61,
            color = 2,
            scale = 0.8
        },
        {
            id = 'weazel_news',
            label = 'Weazel News Redaktion',
            category = 'faction',
            faction = 'weazel',
            permission = 'weazel.announcement.create',
            coords = { x = -598.21, y = -929.93, z = 23.86 },
            sprite = 184,
            color = 1,
            scale = 0.75
        },
        {
            id = 'downtown_cab',
            label = 'Downtown Cab Co.',
            category = 'job',
            job = 'taxi',
            coords = { x = 894.91, y = -179.08, z = 74.7 },
            sprite = 198,
            color = 5,
            scale = 0.75
        },
        {
            id = 'los_santos_customs',
            label = 'Los Santos Customs',
            category = 'job',
            job = 'mechanic',
            coords = { x = -347.29, y = -133.35, z = 39.01 },
            sprite = 446,
            color = 47,
            scale = 0.75
        }
    }
}
