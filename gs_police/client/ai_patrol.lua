local QBCore =
    exports["qb-core"]:GetCoreObject()

local ActivePatrols = {}

local function DebugPrint(...)
    if Config
    and Config.AIPatrol
    and Config.AIPatrol.debug then
        print("[gs_police:ai_patrol]", ...)
    end
end

local function CountActivePatrols()
    local count =
        0

    for _ in pairs(ActivePatrols) do
        count =
            count + 1
    end

    return count
end

local function CountZonePatrols(zoneKey)
    local count =
        0

    for _, patrol in pairs(ActivePatrols) do
        if patrol.zoneKey == zoneKey then
            count =
                count + 1
        end
    end

    return count
end

local function LoadModel(model)
    local hash =
        joaat(model)

    if not IsModelInCdimage(hash)
    or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)

    local timeout =
        GetGameTimer() + 5000

    while not HasModelLoaded(hash) do
        Wait(25)

        if GetGameTimer() > timeout then
            return nil
        end
    end

    return hash
end

local function GetPatrolCoords(patrol)
    if patrol
    and patrol.vehicle
    and DoesEntityExist(patrol.vehicle) then
        local coords =
            GetEntityCoords(patrol.vehicle)

        return {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    end

    return nil
end

local function DrivePatrolToWaypoint(patrol)
    if not patrol
    or not patrol.driver
    or not patrol.vehicle then
        return
    end

    if not DoesEntityExist(patrol.driver)
    or not DoesEntityExist(patrol.vehicle) then
        return
    end

    local zone =
        Config.AIPatrol
        and Config.AIPatrol.zones
        and Config.AIPatrol.zones[patrol.zoneKey]

    if not zone
    or not zone.waypoints
    or #zone.waypoints <= 0 then
        return
    end

    local waypoint =
        zone.waypoints[patrol.waypointIndex]

    if not waypoint then
        patrol.waypointIndex =
            1
        waypoint =
            zone.waypoints[1]
    end

    TaskVehicleDriveToCoordLongrange(
        patrol.driver,
        patrol.vehicle,
        waypoint.x,
        waypoint.y,
        waypoint.z,
        Config.AIPatrol.drivingSpeed or 15.0,
        Config.AIPatrol.drivingStyle or 786603,
        15.0
    )

    patrol.status =
        "patrolling"
end

local function SpawnPatrolUnit(zoneKey)
    local cfg =
        Config.AIPatrol or {}

    if cfg.enabled == false then
        return false, "disabled"
    end

    local zone =
        cfg.zones and cfg.zones[zoneKey]

    if not zone then
        return false, "invalidZone"
    end

    if zone.enabled == false then
        return false, "zoneDisabled"
    end

    if CountActivePatrols() >= (cfg.maxActivePatrols or 4) then
        return false, "maxUnits"
    end

    if CountZonePatrols(zoneKey) >= (zone.maxUnits or 1) then
        return false, "zoneMaxUnits"
    end

    local vehicleModel =
        zone.vehicle or cfg.defaultVehicle or "police"
    local pedModel =
        zone.pedModel or cfg.defaultPedModel or "s_m_y_cop_01"
    local vehicleHash =
        LoadModel(vehicleModel)
    local pedHash =
        LoadModel(pedModel)

    if not vehicleHash
    or not pedHash then
        return false, "spawnFailed"
    end

    local spawn =
        zone.spawn

    if not spawn then
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        return false, "spawnFailed"
    end

    local vehicle =
        CreateVehicle(vehicleHash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        return false, "spawnFailed"
    end

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleSiren(vehicle, false)

    local driver =
        CreatePedInsideVehicle(vehicle, 4, pedHash, -1, true, true)

    if not DoesEntityExist(driver) then
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        return false, "spawnFailed"
    end

    SetPedAsCop(driver, true)
    SetPedKeepTask(driver, true)
    SetBlockingOfNonTemporaryEvents(driver, true)

    local patrolId =
        ("PATROL-%s-%s"):format(zoneKey, GetGameTimer())

    ActivePatrols[patrolId] = {
        patrolId = patrolId,
        zoneKey = zoneKey,
        zoneLabel = zone.label or zoneKey,
        vehicle = vehicle,
        driver = driver,
        waypointIndex = 1,
        status = "patrolling",
        spawnedAt = GetGameTimer(),
        lastWaypointAt = GetGameTimer()
    }

    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(pedHash)

    DrivePatrolToWaypoint(ActivePatrols[patrolId])

    DebugPrint("spawned patrol", patrolId, zoneKey)

    TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
        zoneKey = zoneKey,
        zoneLabel = zone.label or zoneKey,
        status = "patrolling",
        waypointIndex = 1,
        coords = GetPatrolCoords(ActivePatrols[patrolId])
    })

    return true, ActivePatrols[patrolId]
end

local function CleanupPatrol(patrolId)
    local patrol =
        ActivePatrols[patrolId]

    if not patrol then
        return
    end

    if patrol.driver
    and DoesEntityExist(patrol.driver) then
        DeleteEntity(patrol.driver)
    end

    if patrol.vehicle
    and DoesEntityExist(patrol.vehicle) then
        DeleteEntity(patrol.vehicle)
    end

    ActivePatrols[patrolId] =
        nil

    TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
        status = "cleared"
    })
end

local function CleanupAllPatrols()
    for patrolId in pairs(ActivePatrols) do
        CleanupPatrol(patrolId)
    end
end

CreateThread(function()
    while true do
        Wait(2500)

        for patrolId, patrol in pairs(ActivePatrols) do
            if not patrol.vehicle
            or not DoesEntityExist(patrol.vehicle)
            or not patrol.driver
            or not DoesEntityExist(patrol.driver) then
                ActivePatrols[patrolId] =
                    nil

                TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
                    status = "lost"
                })
            else
                local zone =
                    Config.AIPatrol
                    and Config.AIPatrol.zones
                    and Config.AIPatrol.zones[patrol.zoneKey]

                if zone
                and zone.waypoints
                and #zone.waypoints > 0 then
                    TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
                        zoneKey = patrol.zoneKey,
                        zoneLabel = patrol.zoneLabel,
                        status = patrol.status,
                        waypointIndex = patrol.waypointIndex,
                        coords = GetPatrolCoords(patrol)
                    })

                    local waypoint =
                        zone.waypoints[patrol.waypointIndex]

                    if waypoint then
                        local vehicleCoords =
                            GetEntityCoords(patrol.vehicle)
                        local distance =
                            #(vehicleCoords - waypoint)

                        if distance <= (Config.AIPatrol.waypointArrivalDistance or 18.0) then
                            patrol.status =
                                "waiting"
                            patrol.lastWaypointAt =
                                GetGameTimer()

                            Wait(Config.AIPatrol.waypointWaitMs or 2500)

                            patrol.waypointIndex =
                                patrol.waypointIndex + 1

                            if patrol.waypointIndex > #zone.waypoints then
                                patrol.waypointIndex =
                                    1
                            end

                            DrivePatrolToWaypoint(patrol)

                            TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
                                zoneKey = patrol.zoneKey,
                                zoneLabel = patrol.zoneLabel,
                                status = "patrolling",
                                waypointIndex = patrol.waypointIndex,
                                coords = GetPatrolCoords(patrol)
                            })
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("gs_police:client:spawnPatrolUnit", function(zoneKey)
    local success, result =
        SpawnPatrolUnit(zoneKey)

    if not success then
        local message =
            Config.AIPatrol.messages[result] or "Unable to spawn AI patrol."

        QBCore.Functions.Notify(message, "error")
        return
    end

    QBCore.Functions.Notify(Config.AIPatrol.messages.spawned or "AI patrol unit spawned.", "success")
end)

RegisterNetEvent("gs_police:client:clearPatrols", function()
    CleanupAllPatrols()
    QBCore.Functions.Notify(Config.AIPatrol.messages.cleared or "AI patrol units cleared.", "success")
end)

RegisterCommand("police_patrolstate", function()
    local count =
        0

    for patrolId, patrol in pairs(ActivePatrols) do
        count =
            count + 1

        print(("[gs_police:patrol] id=%s zone=%s status=%s waypoint=%s"):format(
            patrolId,
            patrol.zoneKey,
            patrol.status,
            tostring(patrol.waypointIndex)
        ))
    end

    QBCore.Functions.Notify(("Active AI patrols: %s"):format(count), "primary")
end, false)

RegisterCommand("police_clearpatrols_client", function()
    CleanupAllPatrols()
    QBCore.Functions.Notify("Client AI patrols cleared.", "success")
end, false)
