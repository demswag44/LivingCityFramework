fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'GOAT3DG7'
description 'GS World Module'
version '0.1.0-alpha'

dependency 'gs_core'

shared_scripts {
    'shared/config.lua',
    'shared/weather_config.lua'
}

server_scripts {
    'server/weather.lua',
    'server/citybrain_weather_adapter.lua',
    'server/events.lua',
    'server/exports.lua',
    'server/main.lua'
}

client_scripts {
    'client/weather.lua',
    'client/main.lua'
}
