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
    'server/weather_debug.lua',
    'server/citybrain_adapter.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/ai_response.lua',
    'client/citizen_behavior.lua',
    'client/police_awareness.lua',
    'client/ai_patrol.lua',
    'client/moving_target.lua'
}

dependency 'qb-core'

lua54 'yes'
