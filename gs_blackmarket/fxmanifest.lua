fx_version 'cerulean'
game 'gta5'

author 'Living City / GS Framework'
description 'Hidden Black Market Door Dealer'
version '0.2.0'

dependency 'gs_core'
dependency 'qb-core'
dependency 'qb-menu'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.png'
}

lua54 'yes'
