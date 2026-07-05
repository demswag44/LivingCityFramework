---------------------------------------------------------------------
-- GS World Editor
--
-- File: raycast.lua
-- Purpose:
--     Reusable gameplay camera raycast engine
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Raycast = GSWorldEditor.Raycast or {}

local CurrentRaycast = {
    hit = false,
    coords = nil,
    normal = nil,
    entity = 0,
    entityType = nil,
    distance = 0.0,
    surfaceMaterial = nil,
}

local function CopyRaycast()
    return {
        hit = CurrentRaycast.hit,
        coords = CurrentRaycast.coords,
        normal = CurrentRaycast.normal,
        entity = CurrentRaycast.entity,
        entityType = CurrentRaycast.entityType,
        distance = CurrentRaycast.distance,
        surfaceMaterial = CurrentRaycast.surfaceMaterial,
    }
end

local function DistanceBetween(left, right)
    if not left or not right then
        return 0.0
    end

    return #(left - right)
end

function GSWorldEditor.Raycast.Update()
    local origin, target = GSWorldEditor.Camera.GetAimRay(1000.0)
    local handle = StartShapeTestRay(
        origin.x,
        origin.y,
        origin.z,
        target.x,
        target.y,
        target.z,
        -1,
        PlayerPedId(),
        7
    )

    local _, hit, coords, normal, material, entity =
        GetShapeTestResultIncludingMaterial(handle)

    CurrentRaycast.hit = hit == 1
    CurrentRaycast.coords = coords
    CurrentRaycast.normal = normal
    CurrentRaycast.entity = entity or 0
    CurrentRaycast.entityType = entity and entity ~= 0 and GetEntityType(entity) or nil
    CurrentRaycast.distance = DistanceBetween(origin, coords)
    CurrentRaycast.surfaceMaterial = material

    return CopyRaycast()
end

function GSWorldEditor.Raycast.Get()
    return CopyRaycast()
end

function GSWorldEditor.Raycast.GetHitPosition()
    return CurrentRaycast.coords
end

function GSWorldEditor.Raycast.GetHitEntity()
    return CurrentRaycast.entity
end

function GSWorldEditor.Raycast.IsHit()
    return CurrentRaycast.hit == true
end

CreateThread(function()
    while true do
        if GSWorldEditor.Client
        and GSWorldEditor.Client.IsVisualModeActive
        and GSWorldEditor.Client.IsVisualModeActive() then
            GSWorldEditor.Raycast.Update()
            Wait(0)
        else
            Wait(500)
        end
    end
end)
