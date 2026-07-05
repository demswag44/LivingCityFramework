---------------------------------------------------------------------
-- GS World Editor
--
-- File: sessions.lua
-- Purpose:
--     Server-owned editor session lifecycle
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Sessions = GSWorldEditor.Sessions or {}

local function Log(message)
    print(("[%s] %s"):format(GSWorldEditor.Config.LogPrefix, message))
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

local function SessionKey(source)
    return tostring(tonumber(source) or source)
end

local function SendToolData(playerSource, tool)
    if not tool.dataExport then
        return
    end

    if GetResourceState(tool.resource) ~= "started" then
        return
    end

    local ok, result =
        pcall(function()
            return exports[tool.resource][tool.dataExport](playerSource)
        end)

    if not ok or type(result) ~= "table" then
        return
    end

    TriggerClientEvent(
        "gs_world_editor:client:toolDataUpdated",
        playerSource,
        tool.id,
        result
    )
end

function GSWorldEditor.GetMutableSession(source)
    return GSWorldEditor.Sessions[SessionKey(source)]
end

function GSWorldEditor.StartSession(source, toolId)
    local playerSource = tonumber(source)

    if not playerSource then
        return false, "Invalid editor source."
    end

    if type(toolId) == "string" then
        toolId = toolId:lower()
    end

    local tool = GSWorldEditor.GetTool(toolId)

    if not tool then
        return false, ("Tool '%s' not found."):format(tostring(toolId))
    end

    if not GSWorldEditor.HasEditorPermission(playerSource, tool.permission) then
        return false, "Access denied."
    end

    local session = {
        source = playerSource,
        toolId = tool.id,
        toolLabel = tool.label,
        mode = "create",
        startedAt = os.time(),
        selectedType = nil,
        selectedId = nil,
        draft = {},
        transactions = {},
        redoTransactions = {},
        dirty = false,
    }

    GSWorldEditor.Sessions[SessionKey(playerSource)] = session

    Log("Session Started")
    TriggerClientEvent("gs_world_editor:sessionStarted", playerSource, Copy(session))
    TriggerClientEvent("gs_world_editor:client:startVisualMode", playerSource, Copy(session))
    SendToolData(playerSource, tool)

    return true, Copy(session)
end

function GSWorldEditor.EndSession(source)
    local key = SessionKey(source)
    local session = GSWorldEditor.Sessions[key]

    if not session then
        return false, "No active editor session."
    end

    GSWorldEditor.Sessions[key] = nil

    Log("Session Ended")
    TriggerClientEvent("gs_world_editor:sessionEnded", session.source)
    TriggerClientEvent("gs_world_editor:client:stopVisualMode", session.source)

    return true, Copy(session)
end

function GSWorldEditor.GetSession(source)
    return Copy(GSWorldEditor.Sessions[SessionKey(source)])
end

function GSWorldEditor.IsEditing(source)
    return GSWorldEditor.Sessions[SessionKey(source)] ~= nil
end

function GSWorldEditor.SetSessionSelection(source, selectionType, selectionId, data)
    local session = GSWorldEditor.Sessions[SessionKey(source)]

    if not session then
        return false, "No active editor session."
    end

    session.selectedType = selectionType
    session.selectedId = selectionId
    session.draft.selection = data or {}
    session.dirty = true

    return true, Copy(session)
end

StartSession = GSWorldEditor.StartSession
EndSession = GSWorldEditor.EndSession
GetSession = GSWorldEditor.GetSession
IsEditing = GSWorldEditor.IsEditing
GetMutableSession = GSWorldEditor.GetMutableSession

AddEventHandler("playerDropped", function()
    local playerSource = source

    if GSWorldEditor.IsEditing(playerSource) then
        GSWorldEditor.EndSession(playerSource)
    end
end)

exports("StartSession", function(source, toolId)
    return GSWorldEditor.StartSession(source, toolId)
end)

exports("EndSession", function(source)
    return GSWorldEditor.EndSession(source)
end)

exports("GetSession", function(source)
    return GSWorldEditor.GetSession(source)
end)

exports("IsEditing", function(source)
    return GSWorldEditor.IsEditing(source)
end)
