fx_version 'cerulean'
game 'gta5'

author 'Living City / GS Framework'
description 'Benny\'s Chop Shop System'
version '0.1.0'

dependency 'qb-core'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

lua54 'yes'
