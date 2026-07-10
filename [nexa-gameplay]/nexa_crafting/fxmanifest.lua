fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_crafting'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa crafting recipe and station foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_items',
    'nexa_inventory',
    'nexa_organizations',
    'nexa_jobs',
    'nexa_properties'
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
    'GetRecipe',
    'ListRecipes',
    'CanCraft',
    'BeginCrafting',
    'CancelCrafting',
    'CompleteCrafting',
    'GetCraftingJob',
    'ListCraftingJobs',
    'GetCraftingStation',
    'ListCraftingStations',
    'CreateRecipe',
    'UpdateRecipe',
    'RegisterCraftingStation',
    'GrantRecipeKnowledge',
    'RevokeRecipeKnowledge',
    'CalculateCraftingQuality',
    'ValidateCraftingTools',
    'getStatus',
    'getSchema'
}
