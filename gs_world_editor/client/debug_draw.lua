---------------------------------------------------------------------
-- GS World Editor
--
-- File: debug_draw.lua
-- Purpose:
--     Shared lightweight debug drawing helpers for editor systems
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.DebugDraw = GSWorldEditor.DebugDraw or {}

function GSWorldEditor.DebugDraw.DrawText3D(coords, text)
    if not coords then
        return
    end

    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)

    if not onScreen then
        return
    end

    SetTextFont(4)
    SetTextScale(0.28, 0.28)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end
