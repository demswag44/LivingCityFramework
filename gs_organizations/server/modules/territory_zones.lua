---------------------------------------------------------------------
-- GS Organizations
--
-- File: territory_zones.lua
-- Purpose:
--     Runtime territory zone registry and occupancy state
---------------------------------------------------------------------

local Logger = exports["gs_core"]:Logger()

Logger.Info(
    "TERRITORY ZONES",
    "Module Loaded"
)

GSOrganizations = GSOrganizations or {}

local TerritoryZones = {}

Logger.Info(
    "TERRITORY ZONES",
    "Publishing Module"
)

GSOrganizations.TerritoryZones = TerritoryZones

Logger.Info(
    "TERRITORY ZONES",
    "Module Published"
)

TerritoryZones.Zones = TerritoryZones.Zones or {}
TerritoryZones.PlayerOccupants = TerritoryZones.PlayerOccupants or {}
TerritoryZones.NPCOccupants = TerritoryZones.NPCOccupants or {}
TerritoryZones.PlayerLocations = TerritoryZones.PlayerLocations or {}
TerritoryZones.NPCObservers = TerritoryZones.NPCObservers or {}
TerritoryZones.Ready = false

local function Number(value, fallback)
    local number = tonumber(value)

    if number == nil then
        return fallback
    end

    return number
end

local function CopyCenter(center)
    center = center or {}

    return {
        x = Number(center.x or center[1], 0),
        y = Number(center.y or center[2], 0),
        z = Number(center.z or center[3], 0),
    }
end

local function BuildZone(territory)
    local center =
        CopyCenter(territory.Center)

    return {
        Id = territory.Id,
        Name = territory.Name,
        Type = territory.Type or "radius",
        Center = center,
        Radius = Number(
            territory.Radius,
            GS.TerritoryZoneConfig.DefaultRadius
        ),
        Polygon = territory.Polygon or {},
        Height = Number(
            territory.Height,
            GS.TerritoryZoneConfig.DefaultHeight
        ),
        OwnerId = territory.OwnerOrganizationId,
        Enabled = territory.Enabled ~= false,
    }
end

local function Distance2D(left, right)
    local x = (left.x or 0) - (right.x or 0)
    local y = (left.y or 0) - (right.y or 0)

    return math.sqrt((x * x) + (y * y))
end

local function IsInsideZone(zone, coords)
    if not zone
    or not zone.Enabled
    or not coords then
        return false
    end

    local center =
        zone.Center

    local withinHeight =
        math.abs((coords.z or center.z) - center.z)
            <= (zone.Height / 2)

    if not withinHeight then
        return false
    end

    return Distance2D(coords, center) <= zone.Radius
end

local function GetOrCreateOccupants(container, territoryId)
    container[territoryId] =
        container[territoryId] or {}

    return container[territoryId]
end

local function Count(value)
    local total = 0

    for _ in pairs(value or {}) do
        total = total + 1
    end

    return total
end

local function CopyConfig(config)
    local copy = {}

    for key, value in pairs(config or {}) do
        copy[key] = value
    end

    return copy
end

local function SetsEqual(left, right)
    if Count(left) ~= Count(right) then
        return false
    end

    for key in pairs(left or {}) do
        if not right[key] then
            return false
        end
    end

    return true
end

local function EmitOccupancyChanged(territoryId)
    TriggerEvent(
        "gs_org:territoryOccupancyChanged",
        territoryId,
        TerritoryZones.GetTerritoryOccupants(territoryId)
    )
end

local function SetPlayerTerritory(source, territoryId)
    source = tonumber(source)
    territoryId = territoryId and tonumber(territoryId) or nil

    local previousTerritoryId =
        TerritoryZones.PlayerLocations[source]

    if previousTerritoryId == territoryId then
        return
    end

    if previousTerritoryId then
        local previousOccupants =
            GetOrCreateOccupants(
                TerritoryZones.PlayerOccupants,
                previousTerritoryId
            )

        previousOccupants[source] = nil

        TriggerEvent(
            "gs_org:territoryExited",
            source,
            previousTerritoryId,
            "player"
        )

        TriggerClientEvent(
            "gs_org:territoryExited",
            source,
            previousTerritoryId,
            "player"
        )

        EmitOccupancyChanged(previousTerritoryId)
    end

    TerritoryZones.PlayerLocations[source] =
        territoryId

    if territoryId then
        local occupants =
            GetOrCreateOccupants(
                TerritoryZones.PlayerOccupants,
                territoryId
            )

        occupants[source] = true

        TriggerEvent(
            "gs_org:territoryEntered",
            source,
            territoryId,
            "player"
        )

        TriggerClientEvent(
            "gs_org:territoryEntered",
            source,
            territoryId,
            "player"
        )

        EmitOccupancyChanged(territoryId)
    end
end

local function SetNPCObservations(source, territoryId, npcs)
    source = tonumber(source)
    territoryId = territoryId and tonumber(territoryId) or nil

    local previous =
        TerritoryZones.NPCObservers[source]

    local normalizedNPCs = {}

    for _, npcId in ipairs(npcs or {}) do
        normalizedNPCs[tostring(npcId)] = true
    end

    if previous
    and previous.TerritoryId == territoryId
    and SetsEqual(previous.NPCs or {}, normalizedNPCs) then
        return
    end

    if previous and previous.TerritoryId then
        local occupants =
            GetOrCreateOccupants(
                TerritoryZones.NPCOccupants,
                previous.TerritoryId
            )

        for npcId in pairs(previous.NPCs or {}) do
            if previous.TerritoryId ~= territoryId
            or not normalizedNPCs[npcId] then
                occupants[npcId] = nil

                TriggerEvent(
                    "gs_org:territoryExited",
                    npcId,
                    previous.TerritoryId,
                    "npc"
                )
            end
        end

        if previous.TerritoryId ~= territoryId then
            EmitOccupancyChanged(previous.TerritoryId)
        end
    end

    TerritoryZones.NPCObservers[source] = {
        TerritoryId = territoryId,
        NPCs = normalizedNPCs,
    }

    if not territoryId then
        return
    end

    local occupants =
        GetOrCreateOccupants(
            TerritoryZones.NPCOccupants,
            territoryId
        )

    local previousNPCs =
        previous
        and previous.TerritoryId == territoryId
        and previous.NPCs
        or {}

    for npcId in pairs(normalizedNPCs) do
        if not previousNPCs[npcId] then
            occupants[npcId] = true

            TriggerEvent(
                "gs_org:territoryEntered",
                npcId,
                territoryId,
                "npc"
            )
        else
            occupants[npcId] = true
        end
    end

    EmitOccupancyChanged(territoryId)
end

function TerritoryZones.Initialize()
    local Territories =
        GSOrganizations.Territories

    if not Territories
    or not Territories.GetAll then
        Logger.Error(
            "TERRITORY ZONES",
            "Territory zone initialization failed: territories unavailable."
        )
        return false
    end

    TerritoryZones.Zones = {}
    TerritoryZones.PlayerOccupants = {}
    TerritoryZones.NPCOccupants = {}
    TerritoryZones.PlayerLocations = {}
    TerritoryZones.NPCObservers = {}

    for _, territory in pairs(Territories.GetAll() or {}) do
        local zone =
            BuildZone(territory)

        TerritoryZones.Zones[zone.Id] =
            zone
    end

    TerritoryZones.Ready = true

    Logger.Success(
        "TERRITORY ZONES",
        ("Territory Zones Loaded (%d)")
            :format(Count(TerritoryZones.Zones))
    )

    Logger.Success(
        "TERRITORY ZONES",
        "Runtime Zones Registered"
    )

    Logger.Success(
        "TERRITORY ZONES",
        "Zone Detection Started"
    )

    Logger.Success(
        "TERRITORY ZONES",
        "Territory Zones Initialized"
    )

    return true
end

function TerritoryZones.GetTerritory(id)
    return TerritoryZones.Zones[tonumber(id)]
end

function TerritoryZones.GetTerritoryByPosition(coords)
    for _, zone in pairs(TerritoryZones.Zones) do
        if IsInsideZone(zone, coords) then
            return zone
        end
    end

    return nil
end

function TerritoryZones.GetPlayersInTerritory(id)
    local players = {}

    for source in pairs(TerritoryZones.PlayerOccupants[tonumber(id)] or {}) do
        players[#players + 1] = source
    end

    return players
end

function TerritoryZones.GetNPCsInTerritory(id)
    local npcs = {}

    for npcId in pairs(TerritoryZones.NPCOccupants[tonumber(id)] or {}) do
        npcs[#npcs + 1] = npcId
    end

    return npcs
end

function TerritoryZones.IsPlayerInsideTerritory(source)
    local territoryId =
        TerritoryZones.PlayerLocations[tonumber(source)]

    if not territoryId then
        return false, nil
    end

    return true, territoryId
end

function TerritoryZones.GetTerritoryOccupants(id)
    return {
        Players = TerritoryZones.GetPlayersInTerritory(id),
        NPCs = TerritoryZones.GetNPCsInTerritory(id),
    }
end

function TerritoryZones.GetClientZones()
    local zones = {}

    for _, zone in pairs(TerritoryZones.Zones) do
        if zone.Enabled then
            zones[#zones + 1] = zone
        end
    end

    table.sort(zones, function(left, right)
        return tostring(left.Name) < tostring(right.Name)
    end)

    return zones
end

RegisterNetEvent("gs_org:territoryZoneState", function(territoryId, npcs)
    SetPlayerTerritory(source, territoryId)
    SetNPCObservations(source, territoryId, npcs)
end)

AddEventHandler("playerDropped", function()
    local playerSource =
        source

    SetPlayerTerritory(playerSource, nil)
    SetNPCObservations(playerSource, nil, {})
end)

lib.callback.register("gs_organizations:getTerritoryZones", function(source)
    local config =
        CopyConfig(GS.TerritoryZoneConfig)

    if config.Debug
    and config.DebugAdminsOnly
    and not IsPlayerAceAllowed(source, "gs_organizations.admin")
    and not IsPlayerAceAllowed(source, "command") then
        config.Debug = false
        config.DrawZones = false
    end

    return {
        success = true,
        zones = TerritoryZones.GetClientZones(),
        config = config,
    }
end)

return TerritoryZones
