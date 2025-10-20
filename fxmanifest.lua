fx_version 'cerulean'
game 'gta5'

author 'Muhaddil'
description 'Horror System for FiveM'
version '0.1.0'

dependencies {
    'PolyZone'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/*',
}

server_scripts {
    'server/*'
}

ui_page 'web/index.html'

files {
    'web/*',
    'web/images/*.jpg',
    'web/images/*.png',
    'web/images/*.gif',
    'web/images/Jumpscares/*.jpg',
    'web/images/Jumpscares/*.png',
    'web/images/Jumpscares/*.gif'
}

lua54 'yes'

provide 'horror-system'