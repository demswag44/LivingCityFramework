---------------------------------------------------------------------
-- GS World Editor
--
-- File: selection_engine.lua
-- Purpose:
--     Reusable editor selection engine
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Selection = GSWorldEditor.Selection or {}

local CurrentSelection = nil

local function Log(message)
    print(("[WORLD EDITOR] %s"):format(message))
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}

    for key, item in pairs(value) do
        copied[key] = Copy(item)
    end

    return copied
end

function GSWorldEditor.Selection.Select(selectionType, id, data)
    CurrentSelection = {
        type = selectionType,
        id = id,
        data = data or {},
    }

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.selectedType = selectionType
        GSWorldEditor.VisualMode.selectedId = id
        GSWorldEditor.VisualMode.dirty = true
    end

    TriggerServerEvent("gs_world_editor:selectionChanged", selectionType, id, data or {})
    Log("Selection Changed")

    return true, Copy(CurrentSelection)
end

function GSWorldEditor.Selection.Clear()
    CurrentSelection = nil

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.selectedType = nil
        GSWorldEditor.VisualMode.selectedId = nil
        GSWorldEditor.VisualMode.dirty = true
    end

    TriggerServerEvent("gs_world_editor:selectionChanged", nil, nil, {})
    Log("Selection Changed")

    return true
end

function GSWorldEditor.Selection.Get()
    return Copy(CurrentSelection)
end

function GSWorldEditor.Selection.HasSelection()
    return CurrentSelection ~= nil
end

function GSWorldEditor.Selection.IsSelected(selectionType, id)
    return CurrentSelection ~= nil
        and CurrentSelection.type == selectionType
        and tostring(CurrentSelection.id) == tostring(id)
end

Select = GSWorldEditor.Selection.Select
ClearSelection = GSWorldEditor.Selection.Clear
GetSelection = GSWorldEditor.Selection.Get
