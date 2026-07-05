fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'GOAT3DG7'
description 'GS Organizations Module'
version '0.1.0-alpha'

dependencies {
    'gs_core',
    'ox_lib',
    'oxmysql'
}

shared_scripts {

    '@ox_lib/init.lua',

    'shared/permissions.lua',
    'shared/rank_templates.lua',
    'shared/territories.lua',
    'shared/territory_zones.lua',
    'shared/territory_editor.lua',
    'shared/config.lua',
    'shared/ui.lua',
    'shared/locale.lua',

}

client_scripts {

    'client/main.lua',
    'client/menu.lua',
    'client/dashboard.lua',
    'client/create.lua',
    'client/invites.lua',
    'client/ranks.lua',
    'client/treasury.lua',
    'client/territory_zones.lua',
    'client/callbacks.lua',
    'client/events.lua',

}

server_scripts {

    '@oxmysql/lib/MySQL.lua',

    -----------------------------------------------------------------
    -- Repository
    -----------------------------------------------------------------

    'server/repository/organizations.lua',
    'server/repository/members.lua',
    'server/repository/ranks.lua',
    'server/repository/invites.lua',
    'server/repository/treasury.lua',
    'server/repository/activity.lua',
    'server/repository/history.lua',

    -----------------------------------------------------------------
    -- Organization Core
    -----------------------------------------------------------------

    'server/database.lua',
    'server/manager.lua',

    -----------------------------------------------------------------
    -- Security
    -----------------------------------------------------------------

    'server/security/manager.lua',
    'server/security/permissions.lua',
    'server/security/hierarchy.lua',
    'server/security/validator.lua',
    'server/security/audit.lua',
    'server/security/exports.lua',
    'server/security/tests.lua',

    -----------------------------------------------------------------
    -- Dynamic Rank System (ORG-007)
    -----------------------------------------------------------------

    'server/ranks/manager.lua',
    'server/ranks/create.lua',
    'server/ranks/delete.lua',
    'server/ranks/rename.lua',
    'server/ranks/permissions.lua',
    'server/ranks/salary.lua',
    'server/ranks/runtime.lua',
    'server/ranks/database.lua',
    'server/ranks/events.lua',
    'server/ranks/tests.lua',

    -----------------------------------------------------------------
    -- Organization Modules
    -----------------------------------------------------------------

    'server/modules/activity.lua',
    'server/modules/create.lua',
    'server/modules/load.lua',
    'server/modules/members.lua',
    'server/modules/ranks.lua',
    'server/modules/treasury.lua',
    'server/modules/leadership.lua',
    'server/modules/invites.lua',
    'server/modules/delete.lua',

    -----------------------------------------------------------------
    -- API
    -----------------------------------------------------------------

    'server/api/organization.lua',

    -----------------------------------------------------------------
    -- UI Callbacks
    -----------------------------------------------------------------

    'server/callbacks.lua',

    -----------------------------------------------------------------
    -- Events
    -----------------------------------------------------------------

    'server/events/organization.lua',
    'server/events.lua',

    -----------------------------------------------------------------
    -- Runtime Tests
    -----------------------------------------------------------------

    'server/tests/runtime.lua',

    -----------------------------------------------------------------
    -- Territory Framework
    -----------------------------------------------------------------

    'server/repository/territories.lua',
    'server/modules/territories.lua',

    'server/modules/territory_zones.lua',

    'server/repository/territory_editor.lua',
    'server/modules/territory_editor.lua',

    -----------------------------------------------------------------
    -- Startup
    -----------------------------------------------------------------

    'server/main.lua'

}
