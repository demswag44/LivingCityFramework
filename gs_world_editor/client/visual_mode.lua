---------------------------------------------------------------------
-- GS World Editor
--
-- File: visual_mode.lua
-- Purpose:
--     Client visual editor mode state and controls
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}

GSWorldEditor.VisualMode = GSWorldEditor.VisualMode or {
    active = false,
    toolId = nil,
    toolLabel = nil,
    mode = "create",
    selectedType = nil,
    selectedId = nil,
    hover = nil,
    draft = nil,
    dirty = false,
}

local function Log(message)
    print(("[WORLD EDITOR] %s"):format(message))
end

local function ApplySelectionToVisualMode()
    local selection = GSWorldEditor.Client.GetSelection()

    if not selection then
        GSWorldEditor.VisualMode.selectedType = nil
        GSWorldEditor.VisualMode.selectedId = nil
        return
    end

    GSWorldEditor.VisualMode.selectedType = selection.type
    GSWorldEditor.VisualMode.selectedId = selection.id
end

function GSWorldEditor.Client.StartVisualMode(session)
    session = session or {}

    GSWorldEditor.VisualMode.active = true
    GSWorldEditor.VisualMode.toolId = session.toolId
    GSWorldEditor.VisualMode.toolLabel = session.toolLabel or session.toolId or "World Editor"
    GSWorldEditor.VisualMode.mode = session.mode or "create"
    GSWorldEditor.VisualMode.selectedType = session.selectedType
    GSWorldEditor.VisualMode.selectedId = session.selectedId
    GSWorldEditor.VisualMode.hover = nil
    GSWorldEditor.VisualMode.draft = session.draft or {}
    GSWorldEditor.VisualMode.dirty = session.dirty or false

    if GSWorldEditor.Transactions and GSWorldEditor.Transactions.ClearLocal then
        GSWorldEditor.Transactions.ClearLocal()
    end

    if GSWorldEditor.VisualMode.toolId == "territories"
    and GSWorldEditor.VisualMode.draft.radius == nil then
        GSWorldEditor.VisualMode.draft.radius = 50.0
    end

    Log("Visual Mode Started")
end

function GSWorldEditor.Client.StopVisualMode()
    if not GSWorldEditor.VisualMode.active then
        return
    end

    GSWorldEditor.VisualMode.active = false
    GSWorldEditor.VisualMode.toolId = nil
    GSWorldEditor.VisualMode.toolLabel = nil
    GSWorldEditor.VisualMode.mode = "create"
    GSWorldEditor.VisualMode.selectedType = nil
    GSWorldEditor.VisualMode.selectedId = nil
    GSWorldEditor.VisualMode.hover = nil
    GSWorldEditor.VisualMode.draft = nil
    GSWorldEditor.VisualMode.dirty = false

    if GSWorldEditor.Transactions and GSWorldEditor.Transactions.ClearLocal then
        GSWorldEditor.Transactions.ClearLocal()
    end

    Log("Visual Mode Stopped")
end

function GSWorldEditor.Client.IsVisualModeActive()
    return GSWorldEditor.VisualMode.active == true
end

function GSWorldEditor.Client.SetVisualModeMode(mode)
    if type(mode) ~= "string" or mode == "" then
        return false
    end

    GSWorldEditor.VisualMode.mode = mode

    return true
end

function GSWorldEditor.Client.SetVisualDraft(data)
    GSWorldEditor.VisualMode.draft = data or {}
    GSWorldEditor.VisualMode.dirty = true

    return true
end

StartVisualMode = GSWorldEditor.Client.StartVisualMode
StopVisualMode = GSWorldEditor.Client.StopVisualMode
IsVisualModeActive = GSWorldEditor.Client.IsVisualModeActive
SetVisualModeMode = GSWorldEditor.Client.SetVisualModeMode
SetVisualDraft = GSWorldEditor.Client.SetVisualDraft

exports("StartVisualMode", GSWorldEditor.Client.StartVisualMode)
exports("StopVisualMode", GSWorldEditor.Client.StopVisualMode)
exports("IsVisualModeActive", GSWorldEditor.Client.IsVisualModeActive)
exports("SetVisualModeMode", GSWorldEditor.Client.SetVisualModeMode)
exports("SetVisualDraft", GSWorldEditor.Client.SetVisualDraft)

RegisterNetEvent("gs_world_editor:client:startVisualMode", function(session)
    GSWorldEditor.Client.StartVisualMode(session)
end)

RegisterNetEvent("gs_world_editor:client:stopVisualMode", function()
    GSWorldEditor.Client.StopVisualMode()
end)
