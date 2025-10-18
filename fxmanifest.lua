fx_version 'cerulean'
game 'gta5'

author 'Muhaddil'
description 'Horror System for FiveM'
version '0.1.0'

dependencies {
    'PolyZone'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'config.lua',
    'client/*',
}

server_scripts {
    'config.lua',
    'server/*'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/sounds.js',
    'web/images/*.jpg',
    'web/images/*.png',
    'web/images/*.gif'
}

lua54 'yes'

provide 'horror-system'