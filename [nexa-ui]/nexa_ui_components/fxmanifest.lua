fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_ui_components'
author 'Nexa Roleplay'
description 'Shared GP17 NUI component contracts and stylesheet'
version '0.1.0'

dependencies {
    'nexa_theme'
}

files {
    'web/components.css'
}

shared_scripts {
    'shared/components.lua'
}

client_scripts {
    'client/main.lua'
}

client_exports {
    'getComponents',
    'getStylesheet'
}
