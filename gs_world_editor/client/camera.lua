---------------------------------------------------------------------
-- GS World Editor
--
-- File: camera.lua
-- Purpose:
--     Gameplay camera helpers for editor systems
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Camera = GSWorldEditor.Camera or {}

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local cosX = math.abs(math.cos(x))

    return vector3(
        -math.sin(z) * cosX,
        math.cos(z) * cosX,
        math.sin(x)
    )
end

function GSWorldEditor.Camera.GetPosition()
    return GetGameplayCamCoord()
end

function GSWorldEditor.Camera.GetRotation()
    return GetGameplayCamRot(2)
end

function GSWorldEditor.Camera.GetForwardVector()
    return RotationToDirection(GSWorldEditor.Camera.GetRotation())
end

function GSWorldEditor.Camera.GetAimRay(distance)
    local origin = GSWorldEditor.Camera.GetPosition()
    local direction = GSWorldEditor.Camera.GetForwardVector()
    local target = origin + (direction * (distance or 1000.0))

    return origin, target, direction
end
