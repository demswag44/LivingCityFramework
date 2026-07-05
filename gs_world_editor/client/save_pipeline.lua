---------------------------------------------------------------------
-- GS World Editor
--
-- File: save_pipeline.lua
-- Purpose:
--     Client-side save payload builder and response handler
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}
GSWorldEditor.SavePipeline = GSWorldEditor.SavePipeline or {}

local SavePipeline = GSWorldEditor.SavePipeline

GSWorldEditor.Client.SavePipeline = SavePipeline

local function Notify(message)
    TriggerEvent("chat:addMessage", {
        args = {
            "World Editor",
            message,
        },
    })
end

local function ToPlainCoords(coords)
    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }
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

local function BuildTerritoryPayload()
    local draft = GSWorldEditor.VisualMode.draft or {}
    local coords = GSWorldEditor.Preview.GetCoords()
        or GSWorldEditor.Raycast.GetHitPosition()
    local defaultName =
        ("New Territory %s-%s"):format(
            GetPlayerServerId(PlayerId()),
            GetGameTimer()
        )

    if not coords then
        return nil, "no preview position."
    end

    coords = ToPlainCoords(coords)

    return {
        toolId = "territories",
        action = GSWorldEditor.SavePipeline.Actions.Create,
        data = {
            name = draft.name or defaultName,
            type = draft.type or "radius",
            center = coords,
            radius = tonumber(draft.radius) or 50.0,
            height = tonumber(draft.height) or 50.0,
            owner_id = draft.owner_id,
            enabled = draft.enabled ~= false,
            metadata = {
                createdBy = GetPlayerServerId(PlayerId()),
                createdFrom = "gs_world_editor",
                editorVersion = "WORLD-004",
                worldEditor = true,
            },
        },
        draft = Copy(draft),
    }
end

function SavePipeline.BuildPayload()
    if not GSWorldEditor.Client.IsVisualModeActive() then
        return nil, "no active visual mode."
    end

    local toolId = GSWorldEditor.VisualMode.toolId

    if toolId == "territories" then
        return BuildTerritoryPayload()
    end

    return {
        toolId = toolId,
        action = GSWorldEditor.SavePipeline.Actions.Create,
        data = Copy(GSWorldEditor.VisualMode.draft or {}),
        draft = Copy(GSWorldEditor.VisualMode.draft or {}),
    }
end

function SavePipeline.RequestSave()
    local payload, errorMessage =
        SavePipeline.BuildPayload()

    if not payload then
        Notify(("Save failed: %s"):format(errorMessage or "unable to build payload."))
        return false
    end

    Notify("Saving territory...")
    TriggerServerEvent(GSWorldEditor.SavePipeline.Events.ServerSave, payload)

    return true
end

function SavePipeline.OnSaveResult(result)
    result = result or {}

    if result.success then
        if GSWorldEditor.Transactions and GSWorldEditor.Transactions.ClearLocal then
            GSWorldEditor.Transactions.ClearLocal()
        end

        if GSWorldEditor.VisualMode then
            GSWorldEditor.VisualMode.dirty = false
        end

        Notify(result.message or "Territory saved.")
        return
    end

    Notify(("Save failed: %s"):format(result.error or result.message or "unknown error."))
end

function SavePipeline.Cancel()
    TriggerServerEvent("gs_world_editor:endSession")
end

RegisterNetEvent(GSWorldEditor.SavePipeline.Events.ClientRequestSave, function()
    SavePipeline.RequestSave()
end)

RegisterNetEvent(GSWorldEditor.SavePipeline.Events.SaveComplete, function(result)
    SavePipeline.OnSaveResult(result)
end)

RegisterNetEvent(GSWorldEditor.SavePipeline.Events.ToolDataUpdated, function(toolId, data)
    if not GSWorldEditor.VisualMode
    or GSWorldEditor.VisualMode.toolId ~= toolId then
        return
    end

    local draft = GSWorldEditor.VisualMode.draft or {}

    if toolId == "territories" then
        draft.existingTerritories = data and data.territories or draft.existingTerritories
    end

    GSWorldEditor.VisualMode.draft = draft
end)

exports("RequestSave", SavePipeline.RequestSave)
