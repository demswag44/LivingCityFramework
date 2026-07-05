---------------------------------------------------------------------
-- GS World Editor
--
-- File: gizmo.lua
-- Purpose:
--     Shared gizmo and snap constants
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.GizmoConfig = GSWorldEditor.GizmoConfig or {}

GSWorldEditor.GizmoConfig.Modes = {
    Move = "move",
    Scale = "scale",
    Rotate = "rotate",
}

GSWorldEditor.GizmoConfig.SnapModes = {
    None = "none",
    Grid = "grid",
    Terrain = "terrain",
    Road = "road",
    Building = "building",
}

GSWorldEditor.GizmoConfig.GridSizes = {
    0.5,
    1.0,
    2.0,
    5.0,
    10.0,
}
