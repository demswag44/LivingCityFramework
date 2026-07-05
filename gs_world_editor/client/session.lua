---------------------------------------------------------------------
-- GS World Editor
--
-- File: session.lua
-- Purpose:
--     Client session cache and event bridge
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}

GSWorldEditor.Client.Session = nil

RegisterNetEvent("gs_world_editor:sessionStarted", function(session)
    GSWorldEditor.Client.Session = session
end)

RegisterNetEvent("gs_world_editor:sessionEnded", function()
    GSWorldEditor.Client.Session = nil
    GSWorldEditor.Client.ClearSelection()
end)

function GSWorldEditor.Client.GetSession()
    return GSWorldEditor.Client.Session
end

exports("GetSession", GSWorldEditor.Client.GetSession)
