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

local function ShouldUseEmergencyResponse(task)
    local cfg =
        Config.PatrolDispatch or {}
    local emergency =
        cfg.emergencyResponse or {}

    if emergency.enabled == false then
        return false
    end

    local threatLevel =
        task and task.threatLevel
    local incidentType =
        task and task.incidentType

    if threatLevel then
        threatLevel =
            tostring(threatLevel):lower()
    end

    if incidentType then
        incidentType =
            tostring(incidentType):lower()
    end

    if threatLevel
    and emergency.useSirenForThreats
    and emergency.useSirenForThreats[threatLevel] then
        return true
    end

    if incidentType
    and emergency.useSirenForIncidentTypes
    and emergency.useSirenForIncidentTypes[incidentType] then
        return true
    end

    return false
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

local function SendPatrolStatus(patrolId, patrol, statusOverride)
    if not patrolId
    or not patrol then
        return
    end

    TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
        zoneKey = patrol.zoneKey,
        zoneLabel = patrol.zoneLabel,
        status = statusOverride or patrol.status,
        mode = patrol.mode or "patrol",
        waypointIndex = patrol.waypointIndex,
        assignedIncidentId = patrol.assignedIncidentId,
        coords = GetPatrolCoords(patrol)
    })
end

local function ReturnPatrolToRoute(patrolId)
    local patrol =
        ActivePatrols[patrolId]

    if not patrol then
        return false
    end

    if patrol.vehicle
    and DoesEntityExist(patrol.vehicle) then
        SetVehicleSiren(patrol.vehicle, false)
        SetVehicleHasMutedSirens(patrol.vehicle, true)
    end

    patrol.mode =
        "returning"
    patrol.status =
        "returning"
    patrol.clearRequested =
        true
    patrol.onScene =
        false
    patrol.emergencyResponse =
        false

    if patrol.driver
    and DoesEntityExist(patrol.driver) then
        ClearPedTasks(patrol.driver)

        if patrol.vehicle
        and DoesEntityExist(patrol.vehicle) then
            local sceneCfg =
                Config.PatrolDispatch
                and Config.PatrolDispatch.scene
                or {}

            TaskEnterVehicle(
                patrol.driver,
                patrol.vehicle,
                sceneCfg.getBackInVehicleTimeoutMs or 10000,
                -1,
                1.0,
                1,
                0
            )
        end
    end

    SendPatrolStatus(patrolId, patrol, "returning")

    CreateThread(function()
        local sceneCfg =
            Config.PatrolDispatch
            and Config.PatrolDispatch.scene
            or {}
        local timeout =
            GetGameTimer() + (sceneCfg.getBackInVehicleTimeoutMs or 10000)

        while GetGameTimer() < timeout do
            Wait(500)

            if patrol.driver
            and DoesEntityExist(patrol.driver)
            and patrol.vehicle
            and DoesEntityExist(patrol.vehicle)
            and IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
                break
            end
        end

        if patrol.driver
        and DoesEntityExist(patrol.driver)
        and patrol.vehicle
        and DoesEntityExist(patrol.vehicle)
        and not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
            SetPedIntoVehicle(patrol.driver, patrol.vehicle, -1)
        end

        local incidentId =
            patrol.assignedIncidentId

        patrol.assignedIncidentId =
            nil
        patrol.assignedIncidentCoords =
            nil
        patrol.arrivedAt =
            nil
        patrol.returnAfter =
            nil
        patrol.onScene =
            false

        if patrol.previousWaypointIndex then
            patrol.waypointIndex =
                patrol.previousWaypointIndex
        end

        patrol.mode =
            "patrol"
        patrol.status =
            "patrolling"

        DrivePatrolToWaypoint(patrol)

        SendPatrolStatus(patrolId, patrol, "patrolling")

        if incidentId then
            TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "returned", {
                incidentId = incidentId
            })
        end

        DebugPrint("patrol returned to service", patrolId)
    end)

    return true
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
        mode = "patrol",
        assignedIncidentId = nil,
        assignedIncidentCoords = nil,
        previousWaypointIndex = nil,
        respondingStartedAt = nil,
        arrivedAt = nil,
        returnAfter = nil,
        onScene = false,
        clearRequested = false,
        emergencyResponse = false,
        spawnedAt = GetGameTimer(),
        lastWaypointAt = GetGameTimer()
    }

    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(pedHash)

    DrivePatrolToWaypoint(ActivePatrols[patrolId])

    DebugPrint("spawned patrol", patrolId, zoneKey)

    SendPatrolStatus(patrolId, ActivePatrols[patrolId], "patrolling")

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
                    SendPatrolStatus(patrolId, patrol)

                    if patrol.mode == "responding"
                    and patrol.assignedIncidentCoords then
                        local vehicleCoords =
                            GetEntityCoords(patrol.vehicle)
                        local targetCoords =
                            vector3(
                                patrol.assignedIncidentCoords.x,
                                patrol.assignedIncidentCoords.y,
                                patrol.assignedIncidentCoords.z
                            )
                        local distance =
                            #(vehicleCoords - targetCoords)

                        if distance <= (
                            Config.PatrolDispatch
                            and Config.PatrolDispatch.arrivalDistance
                            or 28.0
                        ) then
                            patrol.mode =
                                "on_scene"
                            patrol.status =
                                "on_scene"
                            patrol.arrivedAt =
                                GetGameTimer()
                            patrol.onScene =
                                true
                            patrol.clearRequested =
                                false

                            local sceneCfg =
                                Config.PatrolDispatch
                                and Config.PatrolDispatch.scene
                                or {}
                            local autoReturnSeconds =
                                sceneCfg.autoReturnAfterSeconds or 60

                            patrol.returnAfter =
                                GetGameTimer() + (autoReturnSeconds * 1000)

                            if patrol.vehicle
                            and DoesEntityExist(patrol.vehicle) then
                                if patrol.emergencyResponse
                                and sceneCfg.keepEmergencyLightsOnArrival ~= false then
                                    SetVehicleSiren(patrol.vehicle, true)
                                    SetVehicleHasMutedSirens(patrol.vehicle, sceneCfg.muteSirenOnArrival ~= false)
                                else
                                    SetVehicleSiren(patrol.vehicle, false)
                                    SetVehicleHasMutedSirens(patrol.vehicle, true)
                                end
                            end

                            TaskVehicleTempAction(patrol.driver, patrol.vehicle, 27, 2000)
                            Wait(1500)
                            TaskLeaveVehicle(patrol.driver, patrol.vehicle, 0)
                            Wait(2000)

                            if DoesEntityExist(patrol.driver) then
                                TaskStartScenarioInPlace(patrol.driver, "WORLD_HUMAN_COP_IDLES", 0, true)
                            end

                            SendPatrolStatus(patrolId, patrol, "on_scene")

                            TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "arrived", {
                                incidentId = patrol.assignedIncidentId
                            })
                        end
                    elseif patrol.mode == "on_scene" then
                        local sceneCfg =
                            Config.PatrolDispatch
                            and Config.PatrolDispatch.scene
                            or {}

                        if sceneCfg.autoReturnEnabled ~= false
                        and patrol.returnAfter
                        and GetGameTimer() >= patrol.returnAfter then
                            if ReturnPatrolToRoute(patrolId) then
                                SendPatrolStatus(patrolId, patrol, "returning")
                            end
                        else
                            SendPatrolStatus(patrolId, patrol, "on_scene")
                        end
                    else
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
                                SendPatrolStatus(patrolId, patrol, "patrolling")
                            end
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

RegisterNetEvent("gs_police:client:dispatchPatrolToIncident", function(task)
    if not task
    or not task.patrolId
    or not task.coords then
        return
    end

    local patrol =
        ActivePatrols[task.patrolId]

    if not patrol then
        return
    end

    if not patrol.vehicle
    or not DoesEntityExist(patrol.vehicle)
    or not patrol.driver
    or not DoesEntityExist(patrol.driver) then
        return
    end

    patrol.mode =
        "responding"
    patrol.status =
        "responding"
    patrol.assignedIncidentId =
        task.incidentId
    patrol.assignedIncidentCoords =
        task.coords
    patrol.previousWaypointIndex =
        patrol.waypointIndex
    patrol.respondingStartedAt =
        GetGameTimer()
    patrol.arrivedAt =
        nil
    patrol.returnAfter =
        nil
    patrol.onScene =
        false
    patrol.clearRequested =
        false

    local emergencyResponse =
        ShouldUseEmergencyResponse(task)
    local driveSpeed =
        (
            Config.PatrolDispatch
            and Config.PatrolDispatch.driveSpeed
            or 24.0
        )

    if Config.PatrolDispatch
    and Config.PatrolDispatch.emergencyResponse
    and Config.PatrolDispatch.emergencyResponse.normalDriveSpeed then
        driveSpeed =
            Config.PatrolDispatch.emergencyResponse.normalDriveSpeed
    end

    if emergencyResponse then
        driveSpeed =
            (
                Config.PatrolDispatch
                and Config.PatrolDispatch.emergencyResponse
                and Config.PatrolDispatch.emergencyResponse.emergencyDriveSpeed
            )
            or 30.0
    end

    patrol.emergencyResponse =
        emergencyResponse

    if patrol.vehicle
    and DoesEntityExist(patrol.vehicle) then
        SetVehicleSiren(patrol.vehicle, emergencyResponse)
        SetVehicleHasMutedSirens(patrol.vehicle, not emergencyResponse)
    end

    if not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
        TaskEnterVehicle(patrol.driver, patrol.vehicle, 8000, -1, 1.0, 1, 0)
        Wait(2000)
    end

    TaskVehicleDriveToCoordLongrange(
        patrol.driver,
        patrol.vehicle,
        task.coords.x,
        task.coords.y,
        task.coords.z,
        driveSpeed,
        (
            Config.PatrolDispatch
            and Config.PatrolDispatch.drivingStyle
            or 786603
        ),
        15.0
    )

    SendPatrolStatus(task.patrolId, patrol, "responding")

    TriggerServerEvent("gs_police:server:patrolDispatchStatus", task.patrolId, "responding", {
        incidentId = task.incidentId
    })

    QBCore.Functions.Notify("Patrol redirected to incident.", "primary")
end)

RegisterNetEvent("gs_police:client:returnPatrolToRoute", function(patrolId)
    if ReturnPatrolToRoute(patrolId) then
        QBCore.Functions.Notify("Patrol returning to route.", "success")
    end
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
