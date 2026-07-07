NexaMapsServer = {
    maxClientEntries = 128,
    categories = {
        civic = {
            label = 'Stadtumgebung',
            description = 'Neutrale Stadt- und Verwaltungsbereiche ohne echte Marken.'
        },
        commercial = {
            label = 'Gewerbe',
            description = 'Lore-freundliche Geschaefts- und Servicebereiche.'
        },
        utility = {
            label = 'Infrastruktur',
            description = 'Technische Umgebungserweiterungen und Betriebsflaechen.'
        },
        interior_shell = {
            label = 'Interior-Vorbereitung',
            description = 'Registry-Eintraege fuer spaetere MLO-/Interior-Resources.'
        }
    },
    environment = {
        weatherProfile = 'default_san_andreas',
        timecycleProfile = 'default',
        collisionPolicy = 'external_resource_validated',
        streamingPolicy = 'registered_resource_only'
    },
    entries = {
        {
            id = 'stadtarchiv_umfeld',
            label = 'Stadtarchiv Umfeld',
            category = 'civic',
            resourceName = 'map_city_archive_area',
            assetType = 'ymap',
            loadState = 'planned',
            active = false,
            environment = {
                weatherProfile = 'default_san_andreas',
                timecycleProfile = 'default'
            },
            files = {
                'stream/city_archive_area.ymap'
            },
            notes = 'Platzhalter fuer spaetere Add-on-Map-Resource.'
        },
        {
            id = 'stadtwache_interior_shell',
            label = 'Stadtwache Interior-Vorbereitung',
            category = 'interior_shell',
            resourceName = 'mlo_city_watch_shell',
            assetType = 'mlo',
            loadState = 'planned',
            active = false,
            environment = {
                weatherProfile = 'interior_neutral',
                timecycleProfile = 'default'
            },
            files = {
                'stream/city_watch_shell.ymap',
                'stream/city_watch_shell.ytyp'
            },
            notes = 'Nur Registry fuer spaetere MLO-Resource, keine Assets in nexa_maps.'
        },
        {
            id = 'sanitaetsdienst_nebengebaeude',
            label = 'Sanitaetsdienst Nebengebaeude',
            category = 'utility',
            resourceName = 'map_medic_annex',
            assetType = 'ymap',
            loadState = 'planned',
            active = false,
            environment = {
                weatherProfile = 'default_san_andreas',
                timecycleProfile = 'default'
            },
            files = {
                'stream/medic_annex.ymap'
            },
            notes = 'Lore-freundlicher Registry-Eintrag ohne echte Behoerdenmarke.'
        }
    }
}
