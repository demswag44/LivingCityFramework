---------------------------------------------------------------------
-- GS World Editor
--
-- File: gizmo.lua
-- Purpose:
--     Reusable editor gizmo and snap state
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Gizmo = GSWorldEditor.Gizmo or {}

GSWorldEditor.Gizmo.State = GSWorldEditor.Gizmo.State or {
    mode = GSWorldEditor.GizmoConfig.Modes.Move,
    snapMode = GSWorldEditor.GizmoConfig.SnapModes.Terrain,
    gridSize = 1.0,
}

local function Log(message)
    print(("[WORLD EDITOR] %s"):format(message))
end

function GSWorldEditor.Gizmo.SetMode(mode)
    if mode ~= GSWorldEditor.GizmoConfig.Modes.Move
    and mode ~= GSWorldEditor.GizmoConfig.Modes.Scale
    and mode ~= GSWorldEditor.GizmoConfig.Modes.Rotate then
        return false
    end

    GSWorldEditor.Gizmo.State.mode = mode

    if GSWorldEditor.Client and GSWorldEditor.Client.SetVisualModeMode then
        GSWorldEditor.Client.SetVisualModeMode(mode)
    end

    Log("Gizmo Mode Changed")

    return true
end

function GSWorldEditor.Gizmo.GetMode()
    return GSWorldEditor.Gizmo.State.mode
end

function GSWorldEditor.Gizmo.SetSnapMode(mode)
    if mode ~= GSWorldEditor.GizmoConfig.SnapModes.None
    and mode ~= GSWorldEditor.GizmoConfig.SnapModes.Grid
    and mode ~= GSWorldEditor.GizmoConfig.SnapModes.Terrain
    and mode ~= GSWorldEditor.GizmoConfig.SnapModes.Road
    and mode ~= GSWorldEditor.GizmoConfig.SnapModes.Building then
        return false
    end

    GSWorldEditor.Gizmo.State.snapMode = mode

    return true
end

function GSWorldEditor.Gizmo.GetSnapMode()
    return GSWorldEditor.Gizmo.State.snapMode
end

function GSWorldEditor.Gizmo.SetGridSize(size)
    size = tonumber(size)

    if not size or size <= 0.0 then
        return false
    end

    GSWorldEditor.Gizmo.State.gridSize = size

    return true
end

function GSWorldEditor.Gizmo.GetGridSize()
    return GSWorldEditor.Gizmo.State.gridSize
end

function GSWorldEditor.Gizmo.ApplySnap(coords)
    if not coords then
        return nil
    end

    if GSWorldEditor.Gizmo.State.snapMode ~= GSWorldEditor.GizmoConfig.SnapModes.Grid then
        return coords
    end

    local size = GSWorldEditor.Gizmo.State.gridSize

    return vector3(
        math.floor((coords.x / size) + 0.5) * size,
        math.floor((coords.y / size) + 0.5) * size,
        coords.z
    )
end
