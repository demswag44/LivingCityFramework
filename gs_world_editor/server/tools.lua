---------------------------------------------------------------------
-- GS World Editor
--
-- File: tools.lua
-- Purpose:
--     Server tool registry exports and default tool registration
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}

local function Log(message)
    print(("[%s] %s"):format(GSWorldEditor.Config.LogPrefix, message))
end

Log("Framework Initialized")

local SharedRegisterTool = GSWorldEditor.RegisterTool

function GSWorldEditor.RegisterTool(tool)
    local success, result = SharedRegisterTool(tool)

    if not success then
        return false, result
    end

    Log(("Tool Registered: %s"):format(result.id))

    return true, result
end

GSWorldEditor.RegisterTool({
    id = "territories",
    label = "Territory Editor",
    resource = "gs_organizations",
    permission = "gs_world_editor.territories",
    category = "World",
    saveEvent = "gs_organizations:territoryEditor:worldEditorSave",
    saveExport = "WorldEditorSaveTerritory",
    dataExport = "WorldEditorGetTerritories",
    actions = {
        "create",
        "edit",
        "delete",
        "save",
        "cancel",
    },
})

exports("RegisterTool", function(tool)
    return GSWorldEditor.RegisterTool(tool)
end)

exports("GetTool", function(id)
    return GSWorldEditor.GetTool(id)
end)

exports("GetTools", function()
    return GSWorldEditor.GetTools()
end)
