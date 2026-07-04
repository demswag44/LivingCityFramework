---------------------------------------------------------------------
-- GS Framework
-- Resource Manifest
---------------------------------------------------------------------

fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'GOAT3DG7'
description 'GS Framework Core Engine'
version '0.1.0-alpha'

---------------------------------------------------------------------
-- Dependencies
---------------------------------------------------------------------

dependency 'oxmysql'

---------------------------------------------------------------------
-- Shared Scripts
---------------------------------------------------------------------

shared_scripts {
    'shared/manifest.lua',
    'shared/config.lua',
    'shared/constants.lua',
    'shared/enums.lua',
    'shared/locale.lua'
}

---------------------------------------------------------------------
-- Client Scripts
---------------------------------------------------------------------

client_scripts {
    'client/functions.lua',
    'client/events.lua',
    'client/main.lua'
}

---------------------------------------------------------------------
-- Server Scripts
---------------------------------------------------------------------

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- Core
    'server/core/banner.lua',
    'server/core/logger.lua',
    'server/core/module_factory.lua',
    'server/core/cache.lua',
    'server/core/events.lua',
    'server/core/database.lua',
    'server/database/organization.lua',
    'server/database/territory.lua',
    'server/database/player.lua',
    'server/database/npc.lua',
    'server/database/business.lua',
    'server/database/property.lua',
    'server/database/relationship.lua',
    'server/database/history.lua',
    'server/core/clock.lua',
    'server/core/modules.lua',
    'server/core/manager.lua',

    -- API
    'server/api/organization.lua',
    'server/api/territory.lua',
    'server/api/npc.lua',
    'server/api/police.lua',
    'server/api/business.lua',
    'server/api/world.lua',

    -- Commands
    'server/commands/admin.lua',
    'server/commands/developer.lua',

        -- Startup
    'server/core/bootstrap.lua',

    -- Public Exports
    'server/exports.lua',

    'server/main.lua'
}

---------------------------------------------------------------------
-- Files
---------------------------------------------------------------------

files {
    'README.md'
}