---------------------------------------------------------------------
-- GS Organizations
--
-- File: territory_zones.lua
-- Purpose:
--     Client-side territory zone detection and optional debug drawing
---------------------------------------------------------------------

GSOrganizations = GSOrganizations or {}
GSOrganizations.Client = GSOrganizations.Client or {}
GSOrganizations.Client.TerritoryZones =
    GSOrganizations.Client.TerritoryZones or {}

local TerritoryZones =
    GSOrganizations.Client.TerritoryZones

TerritoryZones.Zones = TerritoryZones.Zones or {}
TerritoryZones.Config = TerritoryZones.Config or {}
TerritoryZones.CurrentTerritoryId = nil

local function Distance2D(left, right)
    local x = (left.x or 0) - (right.x or 0)
    local y = (left.y or 0) - (right.y or 0)

    return math.sqrt((x * x) + (y * y))
end

local function IsInsideZone(zone, coords)
    local center =
        zone.Center or {}

    local height =
        tonumber(zone.Height)
        or GS.TerritoryZoneConfig.DefaultHeight

    local withinHeight =
        math.abs((coords.z or center.z) - (center.z or 0))
            <= (height / 2)

    if not withinHeight then
        return false
    end

    return Distance2D(coords, center)
        <= (
            tonumber(zone.Radius)
            or GS.TerritoryZoneConfig.DefaultRadius
        )
end

local function GetCurrentZone(coords)
    for _, zone in ipairs(TerritoryZones.Zones) do
        if zone.Enabled
        and IsInsideZone(zone, coords) then
            return zone
        end
    end

    return nil
end

local function EnumeratePeds()
    return coroutine.wrap(function()
        local handle, ped =
            FindFirstPed()

        if not handle or handle == -1 then
            return
        end

        local success = true

        repeat
            coroutine.yield(ped)
            success, ped = FindNextPed(handle)
        until not success

        EndFindPed(handle)
    end)
end

local function GetNearbyNPCs(zone)
    local npcs = {}
    local playerPed =
        PlayerPedId()
    local playerCoords =
        GetEntityCoords(playerPed)
    local radius =
        TerritoryZones.Config.NPCScanRadius
        or GS.TerritoryZoneConfig.NPCScanRadius

    for ped in EnumeratePeds() do
        if ped ~= playerPed
        and DoesEntityExist(ped)
        and not IsPedAPlayer(ped)
        and not IsPedDeadOrDying(ped, true) then
            local coords =
                GetEntityCoords(ped)

            if Distance2D(playerCoords, coords) <= radius
            and IsInsideZone(zone, coords) then
                local networkId =
                    NetworkGetNetworkIdFromEntity(ped)

                if networkId and networkId ~= 0 then
                    npcs[#npcs + 1] = networkId
                else
                    npcs[#npcs + 1] = ped
                end
            end
        end
    end

    return npcs
end

local function ReportZoneState(zone)
    local territoryId =
        zone and zone.Id or nil
    local npcs = {}

    if zone then
        npcs =
            GetNearbyNPCs(zone)
    end

    TriggerServerEvent(
        "gs_org:territoryZoneState",
        territoryId,
        npcs
    )
end

local function DrawDebugZone(zone)
    local config =
        TerritoryZones.Config

    if not config.Debug
    or not config.DrawZones then
        return
    end

    local playerCoords =
        GetEntityCoords(PlayerPedId())

    if Distance2D(playerCoords, zone.Center)
        > (config.DrawDistance or 150.0) then
        return
    end

    DrawMarker(
        1,
        zone.Center.x,
        zone.Center.y,
        zone.Center.z - 1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        zone.Radius * 2.0,
        zone.Radius * 2.0,
        1.5,
        212,
        175,
        55,
        65,
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )

    SetDrawOrigin(
        zone.Center.x,
        zone.Center.y,
        zone.Center.z + 1.0,
        0
    )
    SetTextScale(0.0, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(
        ("#%s %s"):format(
            tostring(zone.Id),
            zone.Name or "Territory"
        )
    )
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function TerritoryZones.Load()
    local result =
        lib.callback.await(
            "gs_organizations:getTerritoryZones",
            false
        )

    if not result
    or not result.success then
        TerritoryZones.Zones = {}
        return false
    end

    TerritoryZones.Zones =
        result.zones or {}
    TerritoryZones.Config =
        result.config or GS.TerritoryZoneConfig

    return true
end

CreateThread(function()
    while not TerritoryZones.Load() do
        Wait(5000)
    end

    while true do
        local interval =
            TerritoryZones.Config.UpdateInterval
            or GS.TerritoryZoneConfig.UpdateInterval
        local playerPed =
            PlayerPedId()

        if playerPed and playerPed ~= 0 then
            local coords =
                GetEntityCoords(playerPed)
            local zone =
                GetCurrentZone(coords)
            local territoryId =
                zone and zone.Id or nil

            if territoryId ~= TerritoryZones.CurrentTerritoryId then
                TerritoryZones.CurrentTerritoryId =
                    territoryId
            end

            ReportZoneState(zone)
        end

        Wait(interval)
    end
end)

CreateThread(function()
    while true do
        local config =
            TerritoryZones.Config

        if config.Debug and config.DrawZones then
            for _, zone in ipairs(TerritoryZones.Zones) do
                DrawDebugZone(zone)
            end

            Wait(0)
        else
            Wait(1000)
        end
    end
end)
