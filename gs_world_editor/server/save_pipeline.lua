---------------------------------------------------------------------
-- GS World Editor
--
-- File: save_pipeline.lua
-- Purpose:
--     Server-side editor save pipeline and tool adapter router
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.SavePipeline = GSWorldEditor.SavePipeline or {}

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

local function Failure(message)
    Log("Save Failed")

    return {
        success = false,
        error = message or "save failed.",
    }
end

local function Success(result)
    result = result or {}
    result.success = true
    result.message = result.message or "Territory saved."

    Log("Save Complete")

    return result
end

local function ActionAllowed(tool, action)
    if not action then
        return true
    end

    for _, allowedAction in ipairs(tool.actions or {}) do
        if allowedAction == action then
            return true
        end
    end

    return false
end

local function MarkWorldEditorPayload(source, payload, session)
    payload.source = source
    payload.data = payload.data or {}
    payload.data.metadata = payload.data.metadata or {}

    payload.data.metadata.createdBy = source
    payload.data.metadata.createdFrom = "gs_world_editor"
    payload.data.metadata.editorVersion =
        payload.data.metadata.editorVersion or "WORLD-004"
    payload.data.metadata.worldEditor = true

    payload.actor = {
        source = source,
        identifier = tostring(source),
        isWorldEditor = true,
        bypassGameplayPermissions = true,
        origin = "gs_world_editor",
        session = Copy(session),
    }
end

local function RouteToExport(tool, source, payload)
    if not tool.saveExport then
        return nil
    end

    if GetResourceState(tool.resource) ~= "started" then
        return {
            success = false,
            error = ("resource '%s' is not started."):format(tool.resource),
        }
    end

    local ok, result =
        pcall(function()
            return exports[tool.resource][tool.saveExport](source, payload)
        end)

    if not ok then
        return {
            success = false,
            error = tostring(result),
        }
    end

    return result
end

local function RouteToEvent(tool, source, payload)
    if not tool.saveEvent then
        return nil
    end

    local response = nil

    TriggerEvent(tool.saveEvent, source, payload, function(result)
        response = result
    end)

    return response
end

local function RouteSave(tool, source, payload)
    Log(("Save Routed: %s"):format(tool.id))

    local result = RouteToExport(tool, source, payload)

    if result ~= nil then
        return result
    end

    result = RouteToEvent(tool, source, payload)

    if result ~= nil then
        return result
    end

    return {
        success = false,
        error = "territory editor unavailable.",
    }
end

function GSWorldEditor.SavePipeline.Save(source, payload)
    Log("Save Requested")

    if type(payload) ~= "table" then
        return Failure("invalid save payload.")
    end

    local session =
        GSWorldEditor.GetMutableSession(source)

    if not session then
        return Failure("no active session.")
    end

    if session.toolId ~= payload.toolId then
        return Failure("tool mismatch.")
    end

    local tool =
        GSWorldEditor.GetTool(payload.toolId)

    if not tool then
        return Failure("tool not found.")
    end

    if not GSWorldEditor.HasToolSavePermission(source, tool.permission) then
        return Failure("access denied.")
    end

    if not ActionAllowed(tool, payload.action) then
        return Failure("action is not allowed for this tool.")
    end

    payload.session = Copy(session)
    payload.draft = payload.draft or Copy(session.draft or {})
    MarkWorldEditorPayload(source, payload, session)

    local result =
        RouteSave(tool, source, payload)

    if not result or result.success ~= true then
        return Failure(result and (result.error or result.message) or "save failed.")
    end

    session.dirty = false
    session.transactions = {}
    session.redoTransactions = {}
    session.draft = payload.draft or session.draft or {}

    if result.toolData then
        TriggerClientEvent(
            GSWorldEditor.SavePipeline.Events.ToolDataUpdated,
            source,
            tool.id,
            result.toolData
        )
    end

    TriggerClientEvent(
        "gs_world_editor:client:clearTransactions",
        source
    )

    return Success(result)
end

RegisterNetEvent(GSWorldEditor.SavePipeline.Events.ServerSave, function(payload)
    local src = source
    local result =
        GSWorldEditor.SavePipeline.Save(src, payload)

    TriggerClientEvent(
        GSWorldEditor.SavePipeline.Events.SaveComplete,
        src,
        result
    )
end)

exports("Save", function(source, payload)
    return GSWorldEditor.SavePipeline.Save(source, payload)
end)
