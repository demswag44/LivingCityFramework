fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'GOAT3DG7'
description 'GS World Editor Framework'
version '0.1.0-alpha'

shared_scripts {
    'shared/config.lua',
    'shared/tools.lua',
    'shared/gizmo.lua',
    'shared/transactions.lua',
    'shared/save_pipeline.lua'
}

client_scripts {
    'client/main.lua',
    'client/session.lua',
    'client/visual_mode.lua',
    'client/save_pipeline.lua',
    'client/camera.lua',
    'client/raycast.lua',
    'client/selection_engine.lua',
    'client/selection.lua',
    'client/gizmo.lua',
    'client/transactions.lua',
    'client/preview.lua',
    'client/input.lua',
    'client/debug_draw.lua',
    'client/hud.lua'
}

server_scripts {
    'server/main.lua',
    'server/permissions.lua',
    'server/tools.lua',
    'server/transactions.lua',
    'server/save_pipeline.lua',
    'server/sessions.lua'
}

files {
    'docs/WORLD-001-World-Editor-Framework.md',
    'docs/WORLD-003-Selection-Gizmo.md',
    'docs/WORLD-003.5-Editor-Transactions.md',
    'docs/WORLD-004-Editor-Save-Pipeline.md'
}
