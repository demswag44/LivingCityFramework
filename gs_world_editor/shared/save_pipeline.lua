---------------------------------------------------------------------
-- GS World Editor
--
-- File: save_pipeline.lua
-- Purpose:
--     Shared save pipeline constants
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.SavePipeline = GSWorldEditor.SavePipeline or {}

GSWorldEditor.SavePipeline.Actions = {
    Create = "create",
    Edit = "edit",
    Delete = "delete",
}

GSWorldEditor.SavePipeline.Events = {
    ClientRequestSave = "gs_world_editor:client:requestSave",
    ServerSave = "gs_world_editor:server:save",
    SaveComplete = "gs_world_editor:client:saveComplete",
    ToolDataUpdated = "gs_world_editor:client:toolDataUpdated",
}
