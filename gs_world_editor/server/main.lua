---------------------------------------------------------------------
-- GS World Editor
--
-- File: main.lua
-- Purpose:
--     Server entry point, commands, and event bridge
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}

local function Log(message)
    print(("[%s] %s"):format(GSWorldEditor.Config.LogPrefix, message))
end

local function Chat(source, message)
    if source == 0 then
        print(("[WORLD EDITOR] %s"):format(message))
        return
    end

    TriggerClientEvent("gs_world_editor:notify", source, message)
end

local function ShowHelp(source)
    Chat(source, "Usage: /gswe tools, /gswe start <toolId>, /gswe stop, /gswe status, /gswe undo, /gswe redo, /gswe save, /gswe cancel")
end

local function ShowTools(source)
    local tools = GSWorldEditor.GetTools()

    if #tools == 0 then
        Chat(source, "No editor tools are registered.")
        return
    end

    Chat(source, "Registered Tools")

    for _, tool in ipairs(tools) do
        Chat(source, ("%s (%s)"):format(tool.label, tool.id))
    end
end

local function ShowStatus(source)
    local session = GSWorldEditor.GetSession(source)

    if not session then
        Chat(source, "No active editor session.")
        return
    end

    local tool = GSWorldEditor.GetTool(session.toolId)
    local label = tool and tool.label or session.toolId

    Chat(source, ("Editing: %s (%s)"):format(label, session.toolId))
    Chat(source, ("Dirty: %s | Selection: %s:%s"):format(
        tostring(session.dirty),
        tostring(session.selectedType or "none"),
        tostring(session.selectedId or "none")
    ))
    Chat(source, ("Transactions: %d | Redo: %d"):format(
        #(session.transactions or {}),
        #(session.redoTransactions or {})
    ))
end

local function HandleWorldEditorCommand(source, args)
    args = args or {}

    if not GSWorldEditor.HasEditorPermission(source, GSWorldEditor.Config.Permissions.Use) then
        Chat(source, "Access denied.")
        return
    end

    local subcommand = tostring(args[1] or ""):lower()

    if subcommand == "" then
        ShowHelp(source)
    elseif subcommand == "tools" then
        ShowTools(source)
    elseif subcommand == "status" then
        ShowStatus(source)
    elseif subcommand == "undo" then
        if not GSWorldEditor.GetSession(source) then
            Chat(source, "No active editor session.")
            return
        end

        TriggerClientEvent("gs_world_editor:client:undoTransaction", source)
    elseif subcommand == "redo" then
        if not GSWorldEditor.GetSession(source) then
            Chat(source, "No active editor session.")
            return
        end

        TriggerClientEvent("gs_world_editor:client:redoTransaction", source)
    elseif subcommand == "save" then
        if not GSWorldEditor.GetSession(source) then
            Chat(source, "No active editor session.")
            return
        end

        TriggerClientEvent("gs_world_editor:client:requestSave", source)
    elseif subcommand == "cancel" then
        local success, result = GSWorldEditor.EndSession(source)

        if not success then
            Chat(source, result or "Unable to cancel editor session.")
            return
        end

        Chat(source, "Editor session cancelled.")
    elseif subcommand == "stop" then
        local success, result = GSWorldEditor.EndSession(source)

        if not success then
            Chat(source, result or "Unable to stop editor session.")
            return
        end

        Chat(source, "Editor session stopped.")
    elseif subcommand == "start" then
        local toolId = tostring(args[2] or ""):lower()

        if toolId == "" then
            Chat(source, "Usage: /gswe start <toolId>")
            return
        end

        local tool = GSWorldEditor.GetTool(toolId)

        if not tool then
            Chat(source, ("Tool '%s' not found."):format(toolId))
            return
        end

        local success, result = GSWorldEditor.StartSession(source, toolId)

        if not success then
            Chat(source, result or "Unable to start editor session.")
            return
        end

        Chat(source, ("Started %s."):format(tool and tool.label or result.toolId))
    else
        ShowHelp(source)
    end
end

RegisterCommand("gswe", function(source, args)
    HandleWorldEditorCommand(source, args or {})
end, false)

RegisterNetEvent("gs_world_editor:runCommand", function(args)
    local src = source
    args = args or {}

    HandleWorldEditorCommand(src, args)
end)

RegisterNetEvent("gs_world_editor:getTools", function(requestId)
    TriggerClientEvent("gs_world_editor:getTools:response", source, requestId, GSWorldEditor.GetTools())
end)

RegisterNetEvent("gs_world_editor:startSession", function(toolId, requestId)
    local success, result = GSWorldEditor.StartSession(source, toolId)
    TriggerClientEvent("gs_world_editor:startSession:response", source, requestId, success, result)
end)

RegisterNetEvent("gs_world_editor:endSession", function(requestId)
    local success, result = GSWorldEditor.EndSession(source)
    TriggerClientEvent("gs_world_editor:endSession:response", source, requestId, success, result)
end)

RegisterNetEvent("gs_world_editor:getSession", function(requestId)
    TriggerClientEvent("gs_world_editor:getSession:response", source, requestId, GSWorldEditor.GetSession(source))
end)

RegisterNetEvent("gs_world_editor:selectionChanged", function(selectionType, selectionId, data)
    GSWorldEditor.SetSessionSelection(source, selectionType, selectionId, data)
end)
