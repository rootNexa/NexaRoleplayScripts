NexaInteriorsServer = {
    maxClientInteriors = 64,
    accessDistance = 4.0,
    interiors = {
        {
            id = 'stadtarchiv_unten',
            label = 'Stadtarchiv Untergeschoss',
            type = 'civic',
            mlo = {
                registryName = 'nexa_city_archive_basement',
                assetStatus = 'planned',
                version = '1.0.0'
            },
            entryPoints = {
                {
                    id = 'archive_front',
                    label = 'Archiveingang',
                    coords = { x = -552.4, y = -191.7, z = 38.2 },
                    heading = 210.0
                }
            },
            exitPoints = {
                {
                    id = 'archive_lobby',
                    label = 'Archivlobby',
                    coords = { x = -548.2, y = -185.1, z = 38.2 },
                    heading = 30.0
                }
            },
            permission = nil,
            doorlock = {
                prepared = true,
                group = 'archive_public',
                doors = {}
            },
            links = {
                storage = nil,
                garage = nil,
                faction = nil
            }
        },
        {
            id = 'stadtwache_besprechung',
            label = 'Stadtwache Besprechungsraum',
            type = 'faction',
            mlo = {
                registryName = 'nexa_watch_meeting_room',
                assetStatus = 'planned',
                version = '1.0.0'
            },
            entryPoints = {
                {
                    id = 'watch_reception',
                    label = 'Wachfoyer',
                    coords = { x = 440.8, y = -985.2, z = 30.7 },
                    heading = 90.0
                }
            },
            exitPoints = {
                {
                    id = 'watch_hallway',
                    label = 'Dienstflur',
                    coords = { x = 445.1, y = -980.4, z = 30.7 },
                    heading = 270.0
                }
            },
            permission = 'police.mdt.view',
            doorlock = {
                prepared = true,
                group = 'city_watch_staff',
                doors = {
                    'watch_meeting_main'
                }
            },
            links = {
                storage = 'registry_only:watch_case_storage',
                garage = nil,
                faction = 'lspd'
            }
        },
        {
            id = 'sanitaetsdienst_ruheraum',
            label = 'Sanitaetsdienst Ruheraum',
            type = 'faction',
            mlo = {
                registryName = 'nexa_medic_rest_room',
                assetStatus = 'planned',
                version = '1.0.0'
            },
            entryPoints = {
                {
                    id = 'medic_side',
                    label = 'Seiteneingang',
                    coords = { x = 311.4, y = -1436.8, z = 29.9 },
                    heading = 140.0
                }
            },
            exitPoints = {
                {
                    id = 'medic_hall',
                    label = 'Ruheflur',
                    coords = { x = 318.1, y = -1430.2, z = 29.9 },
                    heading = 320.0
                }
            },
            permission = 'ems.records.view',
            doorlock = {
                prepared = true,
                group = 'medic_staff',
                doors = {
                    'medic_rest_main'
                }
            },
            links = {
                storage = 'registry_only:medic_linen_storage',
                garage = nil,
                faction = 'ems'
            }
        }
    }
}
