---------------------------------------------------------------------
-- GS World Editor
--
-- File: hud.lua
-- Purpose:
--     Simple on-screen text HUD for visual editor mode
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}

local function DrawHudText(text, x, y, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function TitleCase(value)
    value = tostring(value or "")

    if value == "" then
        return "None"
    end

    return value:sub(1, 1):upper() .. value:sub(2)
end

local function BuildSelectedText()
    local selection = GSWorldEditor.Selection.Get()

    if not selection or not selection.type then
        return "None"
    end

    return ("%s:%s"):format(selection.type, tostring(selection.id or "none"))
end

local function BuildHoverText()
    local hover = GSWorldEditor.Preview
        and GSWorldEditor.Preview.GetHover
        and GSWorldEditor.Preview.GetHover()
        or nil
    local territory = GSWorldEditor.Preview
        and GSWorldEditor.Preview.GetExistingTerritory
        and GSWorldEditor.Preview.GetExistingTerritory()
        or nil

    if territory then
        return ("Territory: %s | Owner: %s | Radius: %sm | Influence: %s"):format(
            territory.name or "Territory",
            tostring(territory.owner or "Unknown"),
            tostring(territory.radius or "0"),
            tostring(territory.influence or 0)
        )
    end

    if not hover or not hover.type then
        return "None"
    end

    return hover.type
end

local function BuildCoordsText()
    local coords = GSWorldEditor.Raycast.GetHitPosition()

    if not coords then
        return "X: --  Y: --  Z: --"
    end

    return ("X: %.2f  Y: %.2f  Z: %.2f"):format(coords.x, coords.y, coords.z)
end

local function GetRadius()
    local draft = GSWorldEditor.VisualMode.draft or {}

    return tonumber(draft.radius) or 50.0
end

CreateThread(function()
    while true do
        if not GSWorldEditor.Client.IsVisualModeActive() then
            Wait(500)
        else
            Wait(0)

            local mode = GSWorldEditor.VisualMode
            local y = 0.05

            DrawHudText("GS WORLD EDITOR", 0.02, y, 0.42, 120, 220, 255, 255)
            y = y + 0.035
            DrawHudText("Tool", 0.02, y, 0.28, 120, 220, 255, 255)
            y = y + 0.027
            DrawHudText(mode.toolLabel or "Unknown", 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText("Mode", 0.02, y, 0.28, 120, 220, 255, 255)
            y = y + 0.027
            DrawHudText(TitleCase(mode.mode), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText(("Radius: %.1fm"):format(GetRadius()), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText(("Snap: %s"):format(TitleCase(GSWorldEditor.Gizmo.GetSnapMode())), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText(("Hover: %s"):format(BuildHoverText()), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText(("Selection: %s"):format(BuildSelectedText()), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText(("History: %d | Redo: %d"):format(
                GSWorldEditor.Transactions.Count(),
                GSWorldEditor.Transactions.RedoCount()
            ), 0.02, y, 0.32)
            y = y + 0.027
            DrawHudText("Coordinates", 0.02, y, 0.28, 120, 220, 255, 255)
            y = y + 0.027
            DrawHudText(BuildCoordsText(), 0.02, y, 0.30)
            y = y + 0.04
            DrawHudText("Controls:", 0.02, y, 0.32, 120, 220, 255, 255)
            y = y + 0.027
            DrawHudText("E = Select", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("G = Move", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("R = Scale", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("T = Rotate", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("Mouse Wheel = Radius", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("ENTER = Save", 0.02, y, 0.30)
            y = y + 0.024
            DrawHudText("BACKSPACE = Cancel", 0.02, y, 0.30)
        end
    end
end)
