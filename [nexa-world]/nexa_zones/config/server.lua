NexaZonesServer = {
    maxClientZones = 64,
    validationDistance = 3.0,
    zones = {
        {
            id = 'pillbox_umfeld',
            label = 'Pillbox Umfeld',
            type = 'sphere',
            category = 'public',
            coords = { x = 298.63, y = -584.23, z = 43.26 },
            radius = 70.0,
            safezone = true,
            criticalActions = {}
        },
        {
            id = 'legion_square',
            label = 'Legion Square',
            type = 'box',
            category = 'public',
            coords = { x = 215.8, y = -810.12, z = 30.73 },
            size = { x = 85.0, y = 75.0, z = 12.0 },
            rotation = 0.0,
            safezone = false,
            criticalActions = {}
        },
        {
            id = 'rathaus_vorplatz',
            label = 'Rathaus Vorplatz',
            type = 'poly',
            category = 'public',
            points = {
                { x = -579.0, y = -229.0, z = 38.0 },
                { x = -512.0, y = -229.0, z = 38.0 },
                { x = -512.0, y = -175.0, z = 38.0 },
                { x = -579.0, y = -175.0, z = 38.0 }
            },
            thickness = 16.0,
            safezone = false,
            criticalActions = {}
        },
        {
            id = 'mission_row_sicherheitsbereich',
            label = 'Mission Row Sicherheitsbereich',
            type = 'box',
            category = 'permission',
            permission = 'police.mdt.view',
            coords = { x = 441.21, y = -981.92, z = 30.69 },
            size = { x = 80.0, y = 70.0, z = 20.0 },
            rotation = 0.0,
            safezone = false,
            criticalActions = {
                'zone.access.restricted'
            }
        },
        {
            id = 'sams_dienstbereich',
            label = 'SAMS Dienstbereich',
            type = 'sphere',
            category = 'permission',
            permission = 'ems.records.view',
            coords = { x = 307.24, y = -1433.41, z = 29.86 },
            radius = 55.0,
            safezone = true,
            criticalActions = {
                'zone.access.restricted'
            }
        }
    }
}
