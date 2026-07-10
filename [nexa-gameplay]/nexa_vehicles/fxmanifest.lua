fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_vehicles'
author 'Nexa Roleplay'
description 'Server-authoritative vehicle definitions, ownership, lifecycle and state foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}

server_exports {
    'RegisterVehicleDefinition',
    'GetVehicleDefinition',
    'ListVehicleDefinitions',
    'GetVehicle',
    'GetVehicleByVin',
    'GetVehicleByPlate',
    'ListCharacterVehicles',
    'ListOrganizationVehicles',
    'CreateVehicle',
    'TransferVehicle',
    'RequestVehicleSpawn',
    'ConfirmVehicleSpawn',
    'RequestVehicleDespawn',
    'GetVehicleState',
    'UpdateVehicleState',
    'RecordVehicleDamage',
    'RepairVehicleDamage',
    'GetVehicleFuel',
    'SetVehicleFuel',
    'ConsumeVehicleFuel',
    'GetVehicleMileage',
    'RecordVehicleMileage',
    'GetVehicleMods',
    'ApplyVehicleMods',
    'CreateVehicleInsurance',
    'GetVehicleInsurance',
    'RecordVehicleMaintenance',
    'GetVehicleMaintenanceHistory',
    'IsVehicleMaintenanceDue',
    'BeginVehicleLockpick',
    'BeginVehicleHotwire',
    'GetVehicleTheftStatus',
    'MarkVehicleImpounded',
    'SetVehicleGarage',
    'getStatus',
    'getSchema'
}
