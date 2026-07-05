---------------------------------------------------------------------
-- GS World Editor
--
-- File: selection.lua
-- Purpose:
--     Backward-compatible selection exports for the selection engine
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}

function GSWorldEditor.Client.SetSelection(selectionType, id, data)
    return GSWorldEditor.Selection.Select(selectionType, id, data)
end

function GSWorldEditor.Client.ClearSelection()
    return GSWorldEditor.Selection.Clear()
end

function GSWorldEditor.Client.GetSelection()
    return GSWorldEditor.Selection.Get()
end

SetSelection = GSWorldEditor.Client.SetSelection
ClearSelection = GSWorldEditor.Client.ClearSelection
GetSelection = GSWorldEditor.Client.GetSelection

exports("SetSelection", GSWorldEditor.Client.SetSelection)
exports("ClearSelection", GSWorldEditor.Client.ClearSelection)
exports("GetSelection", GSWorldEditor.Client.GetSelection)
