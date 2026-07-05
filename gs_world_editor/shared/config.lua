---------------------------------------------------------------------
-- GS World Editor
--
-- File: config.lua
-- Purpose:
--     Shared configuration for editor framework behavior
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}

GSWorldEditor.Config = {
    Name = "GS World Editor",
    Version = "0.1.0-alpha",
    LogPrefix = "WORLD EDITOR",

    Permissions = {
        Admin = "gs_world_editor.admin",
        Use = "gs_world_editor.use",
        Territories = "gs_world_editor.territories",
        Businesses = "gs_world_editor.businesses",
        Properties = "gs_world_editor.properties",
    },

    SelectionTypes = {
        entity = true,
        zone = true,
        building = true,
        road = true,
        npc_spawn = true,
        business = true,
        property = true,
        territory = true,
    },
}
