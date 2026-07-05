---------------------------------------------------------------------
-- GS World Editor
--
-- File: preview.lua
-- Purpose:
--     Cursor-following preview engine for editor tools
---------------------------------------------------------------------

GSWorldEditor = GSWorldEditor or {}
GSWorldEditor.Client = GSWorldEditor.Client or {}
GSWorldEditor.Preview = GSWorldEditor.Preview or {}

GSWorldEditor.Preview.State = GSWorldEditor.Preview.State or {
    hover = nil,
    coords = nil,
    existingTerritory = nil,
}

local function BuildHoverFromRaycast()
    local raycast = GSWorldEditor.Raycast.Get()

    if not raycast.hit or not raycast.coords then
        return {
            type = "None",
            id = nil,
            coords = nil,
            entity = nil,
        }
    end

    if raycast.entity and raycast.entity ~= 0 then
        local entityType = raycast.entityType
        local hoverType = "Entity"

        if entityType == 1 then
            hoverType = "Ped"
        elseif entityType == 2 then
            hoverType = "Vehicle"
        elseif entityType == 3 then
            hoverType = "Entity"
        end

        return {
            type = hoverType,
            id = raycast.entity,
            coords = raycast.coords,
            entity = raycast.entity,
        }
    end

    return {
        type = "Ground",
        id = "ground",
        coords = raycast.coords,
        entity = nil,
    }
end

local function GetTerritoryPreview()
    local coords = GSWorldEditor.Raycast.GetHitPosition()
    local draft = GSWorldEditor.VisualMode.draft or {}

    if not coords then
        local playerPed = PlayerPedId()
        coords = GetEntityCoords(playerPed)
    end

    coords = GSWorldEditor.Gizmo.ApplySnap(coords)

    return vector3(coords.x, coords.y, coords.z), tonumber(draft.radius) or 50.0
end

local function GetExistingTerritoryAt(coords)
    local draft = GSWorldEditor.VisualMode.draft or {}
    local territories = draft.existingTerritories or {}

    for _, territory in ipairs(territories) do
        local center = territory.center

        if center then
            local territoryCoords = vector3(center.x, center.y, center.z)
            local radius = tonumber(territory.radius) or 0.0

            if #(coords - territoryCoords) <= radius then
                return territory
            end
        end
    end

    return nil
end

local function DrawTerritoryCircle(coords, radius, red, green, blue, alpha)
    DrawMarker(
        1,
        coords.x,
        coords.y,
        coords.z - 0.9,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        radius * 2.0,
        radius * 2.0,
        1.0,
        red,
        green,
        blue,
        alpha,
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function DrawTerritoryPreview()
    local coords, radius = GetTerritoryPreview()
    local existing = GetExistingTerritoryAt(coords)

    GSWorldEditor.Preview.State.coords = coords
    GSWorldEditor.Preview.State.existingTerritory = existing

    DrawTerritoryCircle(coords, radius, 0, 180, 255, 80)

    DrawMarker(
        28,
        coords.x,
        coords.y,
        coords.z + 0.35,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.5,
        1.5,
        1.5,
        255,
        255,
        255,
        160,
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )

    DrawLine(
        coords.x,
        coords.y,
        coords.z,
        coords.x,
        coords.y,
        coords.z + 20.0,
        0,
        180,
        255,
        160
    )

    if existing then
        local center = existing.center or {}
        local territoryCoords = vector3(
            center.x or coords.x,
            center.y or coords.y,
            center.z or coords.z
        )

        DrawTerritoryCircle(territoryCoords, tonumber(existing.radius) or radius, 255, 220, 0, 90)
        GSWorldEditor.DebugDraw.DrawText3D(
            vector3(territoryCoords.x, territoryCoords.y, territoryCoords.z + 2.0),
            ("%s | Owner: %s | Influence: %s"):format(
                existing.name or "Territory",
                tostring(existing.owner or "Unknown"),
                tostring(existing.influence or 0)
            )
        )
    end
end

function GSWorldEditor.Preview.UpdateHover()
    local hover = BuildHoverFromRaycast()
    GSWorldEditor.Preview.State.hover = hover

    if GSWorldEditor.VisualMode then
        GSWorldEditor.VisualMode.hover = hover
    end

    return hover
end

function GSWorldEditor.Preview.GetHover()
    return GSWorldEditor.Preview.State.hover
end

function GSWorldEditor.Preview.GetCoords()
    return GSWorldEditor.Preview.State.coords
end

function GSWorldEditor.Preview.GetExistingTerritory()
    return GSWorldEditor.Preview.State.existingTerritory
end

CreateThread(function()
    while true do
        if not GSWorldEditor.Client.IsVisualModeActive() then
            Wait(500)
        else
            Wait(0)
            GSWorldEditor.Preview.UpdateHover()

            if GSWorldEditor.VisualMode.toolId == "territories" then
                DrawTerritoryPreview()
            end
        end
    end
end)
