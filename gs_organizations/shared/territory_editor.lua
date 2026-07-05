---------------------------------------------------------------------
-- GS Organizations
--
-- File: territory_editor.lua
-- Purpose:
--     Territory editor shared API names and defaults
---------------------------------------------------------------------

GS = GS or {}
GS.TerritoryEditor = GS.TerritoryEditor or {}

GS.TerritoryEditor.Callbacks = {
    Create = "gs_organizations:territoryEditor:create",
    Update = "gs_organizations:territoryEditor:update",
    Delete = "gs_organizations:territoryEditor:delete",
    GetState = "gs_organizations:territoryEditor:getState",
    SaveDraft = "gs_organizations:territoryEditor:saveDraft",
    ClearDraft = "gs_organizations:territoryEditor:clearDraft",
}

GS.TerritoryEditor.ValidTypes = {
    radius = true,
    polygon = true,
}

GS.TerritoryEditor.DefaultType = "radius"
