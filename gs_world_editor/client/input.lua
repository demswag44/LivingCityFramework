---------------------------------------------------------------------
-- GS World Editor
--
-- File: input.lua
-- Purpose:
--     Visual editor input manager
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Input = GSWorldEditor.Input or {}

local function Notify(message)
    TriggerEvent("chat:addMessage", {
        args = {
            "World Editor",
            message,
        },
    })
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function UpdateRadius(delta)
    local draft = GSWorldEditor.VisualMode.draft or {}
    local beforeRadius = tonumber(draft.radius) or 50.0
    local afterRadius = Clamp(beforeRadius + delta, 5.0, 1000.0)

    if beforeRadius == afterRadius then
        return
    end

    draft.radius = afterRadius

    GSWorldEditor.Client.SetVisualDraft(draft)
    GSWorldEditor.Transactions.Record(
        GSWorldEditor.TransactionConfig.Actions.RadiusChange,
        "Changed territory radius",
        {
            radius = beforeRadius,
        },
        {
            radius = afterRadius,
        }
    )
    print("[WORLD EDITOR] Radius Updated")
end

local function SelectHover()
    local hover = GSWorldEditor.Preview and GSWorldEditor.Preview.GetHover
        and GSWorldEditor.Preview.GetHover()
        or nil

    if not hover or not hover.type or hover.type == "None" then
        Notify("Select placeholder.")
        return
    end

    GSWorldEditor.Selection.Select(hover.type, hover.id, hover)
    Notify("Select placeholder.")
end

local function RequestSave()
    if GSWorldEditor
    and GSWorldEditor.SavePipeline
    and GSWorldEditor.SavePipeline.RequestSave then
        GSWorldEditor.SavePipeline.RequestSave()
        return
    end

    Notify("Save system unavailable.")
end

CreateThread(function()
    while true do
        if not GSWorldEditor.Client.IsVisualModeActive() then
            Wait(500)
        else
            Wait(0)
            DisableControlAction(0, 245, true)

            if IsControlJustPressed(0, 38) then
                SelectHover()
            elseif IsControlJustPressed(0, 47) then
                GSWorldEditor.Gizmo.SetMode(GSWorldEditor.GizmoConfig.Modes.Move)
                Notify("Move placeholder.")
            elseif IsControlJustPressed(0, 45) then
                GSWorldEditor.Gizmo.SetMode(GSWorldEditor.GizmoConfig.Modes.Scale)
                Notify("Scale placeholder.")
            elseif IsDisabledControlJustPressed(0, 245) then
                GSWorldEditor.Gizmo.SetMode(GSWorldEditor.GizmoConfig.Modes.Rotate)
                Notify("Rotate placeholder.")
            elseif IsControlJustPressed(0, 241) then
                UpdateRadius(5.0)
            elseif IsControlJustPressed(0, 242) then
                UpdateRadius(-5.0)
            elseif IsControlJustPressed(0, 191) then
                RequestSave()
            elseif IsControlJustPressed(0, 177) then
                Notify("Cancel placeholder.")
                TriggerServerEvent("gs_world_editor:endSession")
            end
        end
    end
end)
