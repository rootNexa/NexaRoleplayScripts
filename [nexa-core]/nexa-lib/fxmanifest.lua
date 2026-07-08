fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-lib'
author 'Nexa Roleplay'
description 'Standalone utility library for Nexa Framework resources'
version '0.1.0'

shared_scripts {
    'shared/init.lua',
    'shared/string.lua',
    'shared/table.lua',
    'shared/math.lua',
    'shared/response.lua',
    'shared/logger.lua',
    'shared/validate.lua'
}

server_scripts {
    'server/main.lua',
    'server/callbacks.lua',
    'server/events.lua'
}

client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
    'client/events.lua'
}

server_exports {
    'GetLib',
    'Logger',
    'Response',
    'Validate'
}

client_exports {
    'GetLib',
    'Logger',
    'Response',
    'Validate'
}
