fx_version 'cerulean'
game 'gta5'

author 'Living City / GS Framework'
description 'Living City Police Threat Assessment and Response Policy'
version '0.1.0'

shared_scripts {
    'shared/config.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/ai_response.lua'
}

dependency 'qb-core'

lua54 'yes'
