local QBCore =
    exports["qb-core"]:GetCoreObject()

local ActiveAIUnits = {}
local LastPursuitBackupDebug = {}
local LastRadioBackupDebug = {}

local function DebugPrint(...)
    if Config
    and Config.AIResponse
    and Config.AIResponse.debug then
        print("[gs_police:ai_response]", ...)
    end
end

local function GetWeatherModifier(exportName, fallback)
    local resourceName = (Config.WeatherIntegration and Config.WeatherIntegration.ResourceName) or 'gs_world'

    if not Config.WeatherIntegration or not Config.WeatherIntegration.Enabled then
        return fallback
    end

    if GetResourceState(resourceName) ~= 'started' then
        return fallback
    end

    local ok, result = pcall(function()
        return exports[resourceName][exportName]()
    end)

    if not ok or result == nil then
        return fallback
    end

    return result
end

local function GetWeatherResponseDelayMs(task)
    if not Config.WeatherIntegration
    or Config.WeatherIntegration.Enabled ~= true
    or Config.WeatherIntegration.ResponseDelayEnabled == false
    or task and task.pursuitBackup then
        return 0
    end

    local baseDelayMs = tonumber(task and task.baseDelayMs) or 0
    local policeResponseModifier = tonumber(GetWeatherModifier('GetPoliceResponseModifier', 1.0)) or 1.0
    local windRisk = tonumber(GetWeatherModifier('GetWindRiskModifier', 1.0)) or 1.0
    local weatherDelay = math.floor(baseDelayMs * math.max(0.0, policeResponseModifier - 1.0))
    local windDelay = math.floor(3000 * math.max(0.0, windRisk - 1.0))
    local maxDelay = tonumber(Config.WeatherIntegration.MaxResponseDelayMs) or 20000
    local finalDelay = math.min(baseDelayMs + weatherDelay + windDelay, maxDelay)

    if task and (task.threatLevel == 'high' or task.threatLevel == 'deadly') then
        finalDelay = math.min(finalDelay, 5000)
    end

    return math.max(0, finalDelay)
end

local function CountActiveUnits()
    local count =
        0

    for _ in pairs(ActiveAIUnits) do
        count =
            count + 1
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

local function NormalizeCoords(coords)
    if not coords then
        return nil
    end

    local x =
        tonumber(coords.x)
    local y =
        tonumber(coords.y)
    local z =
        tonumber(coords.z)

    if not x
    or not y
    or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function ToCoordsTable(coords)
    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function ResolvePursuitTargetVehicle(backup)
    if not backup then
        return nil
    end

    local netId =
        tonumber(backup.netId)

    if netId
    and netId ~= 0
    and NetworkDoesNetworkIdExist(netId) then
        local vehicle =
            NetworkGetEntityFromNetworkId(netId)

        if vehicle
        and vehicle ~= 0
        and DoesEntityExist(vehicle) then
            return vehicle
        end
    end

    if backup.plate
    and backup.plate ~= "" then
        local wantedPlate =
            tostring(backup.plate):upper():gsub("%s+", "")

        for _, vehicle in ipairs(GetGamePool("CVehicle")) do
            if DoesEntityExist(vehicle) then
                local plate =
                    (GetVehicleNumberPlateText(vehicle) or ""):upper():gsub("%s+", "")

                if plate == wantedPlate then
                    return vehicle
                end
            end
        end
    end

    return nil
end

local function GetHeadingForward(heading)
    local radians =
        math.rad(tonumber(heading) or 0.0)

    return vector3(-math.sin(radians), math.cos(radians), 0.0)
end

local function CalculatePursuitInterceptPoint(unit, targetVehicle)
    local cfg =
        Config.PursuitBackup or {}
    local backup =
        unit and unit.pursuitBackup or {}
    local coords =
        targetVehicle
        and DoesEntityExist(targetVehicle)
        and GetEntityCoords(targetVehicle)
        or NormalizeCoords(backup.lastKnownCoords)
        or unit.coords
    local heading =
        targetVehicle
        and DoesEntityExist(targetVehicle)
        and GetEntityHeading(targetVehicle)
        or tonumber(backup.heading) or 0.0
    local forward =
        GetHeadingForward(heading)
    local right =
        vector3(forward.y, -forward.x, 0.0)
    local ahead =
        tonumber(cfg.interceptDistanceAhead) or 120.0
    local side =
        tonumber(cfg.interceptSideOffset) or 18.0

    if backup.role == "containment" then
        ahead =
            tonumber(cfg.containmentDistance) or 160.0
        side =
            side * 1.5
    elseif backup.role == "parallel_route" then
        side =
            side * 2.0
    elseif backup.role == "roadblock_candidate" then
        ahead =
            ahead * 1.35
        side =
            0.0
    end

    local sideSign =
        unit.taskId
        and (#tostring(unit.taskId) % 2 == 0 and 1.0 or -1.0)
        or 1.0

    return coords + (forward * ahead) + (right * side * sideSign)
end

local function ConfigurePursuitBackupDriving(unit)
    if not unit
    or not unit.driver
    or not unit.vehicle
    or not DoesEntityExist(unit.driver)
    or not DoesEntityExist(unit.vehicle) then
        return
    end

    SetVehicleSiren(unit.vehicle, true)
    SetVehicleHasMutedSirens(unit.vehicle, false)
    SetDriverAbility(unit.driver, 1.0)
    SetDriverAggressiveness(unit.driver, 0.95)
end

local function ApplyPursuitBackupMetadata(taskId, unit, metadata)
    if not unit
    or not metadata then
        return
    end

    local role =
        metadata.role or unit.pursuitRole or "interceptor"

    unit.pursuitBackup =
        metadata
    unit.pursuitBackup.role =
        role
    unit.pursuitBackup.unitId =
        taskId
    unit.mode =
        role == "containment" and "containment" or "pursuit_backup"
    unit.status =
        unit.mode
    unit.pursuitRole =
        role
    unit.assignedIncidentId =
        metadata.incidentId
    unit.incidentId =
        metadata.incidentId or unit.incidentId
    unit.targetPlate =
        metadata.plate
    unit.targetNetId =
        metadata.netId
    unit.interceptPoint =
        metadata.interceptPoint or metadata.lastKnownCoords

    local logKey =
        ("%s:%s:%s:%s"):format(
            tostring(taskId),
            tostring(role),
            tostring(metadata.incidentId),
            tostring(metadata.plate)
        )

    if unit.lastPursuitBackupAssignedLogKey ~= logKey then
        unit.lastPursuitBackupAssignedLogKey =
            logKey

        print(("[gs_police:pursuit_backup] assigned unit=%s role=%s incident=%s plate=%s"):format(
            tostring(taskId),
            tostring(role),
            tostring(metadata.incidentId),
            tostring(metadata.plate)
        ))

        print(("[gs_police:pursuit_backup] local unit hydrated task=%s role=%s mode=%s incident=%s"):format(
            tostring(taskId),
            tostring(role),
            tostring(unit.mode),
            tostring(metadata.incidentId)
        ))
    end
end

local function GetActiveAIUnitByTaskId(taskId)
    if not taskId then
        return nil
    end

    local direct =
        ActiveAIUnits[taskId]
        or ActiveAIUnits[tostring(taskId)]

    if direct then
        return direct, tostring(taskId)
    end

    for activeTaskId, unit in pairs(ActiveAIUnits) do
        if tostring(activeTaskId) == tostring(taskId) then
            return unit, activeTaskId
        end
    end

    return nil
end

local function BuildBackupMetadataFromRadio(data, receiver)
    if not data
    or not receiver
    or not receiver.taskId then
        return nil
    end

    local suspectInfo =
        data.suspectInfo or {}
    local vehicle =
        data.vehicle
        or suspectInfo.vehicle
        or {}

    return {
        enabled = true,
        role = receiver.role or "interceptor",
        incidentId = receiver.assignedIncidentId or data.incidentId or suspectInfo.incidentId,
        targetId = suspectInfo.targetId,
        plate = receiver.plate or vehicle.plate,
        netId = receiver.netId or vehicle.netId,
        heading = suspectInfo.heading or vehicle.heading,
        direction = data.direction or suspectInfo.direction or suspectInfo.lastSeenDirection,
        street = data.street or suspectInfo.street,
        lastKnownCoords = data.lastKnownCoords or suspectInfo.lastKnownCoords or vehicle.coords,
        interceptPoint = receiver.interceptPoint or receiver.lastInterceptPoint,
        distanceToSuspect = receiver.distanceToSuspect or receiver.distance
    }
end

local function CacheRadioBackupReceivers(data)
    if not data
    or type(data.receivingUnits) ~= "table" then
        return
    end

    for _, receiver in ipairs(data.receivingUnits) do
        if receiver
        and receiver.taskId
        and (
            receiver.unitType == "ai_response"
            or receiver.mode == "pursuit_backup"
            or receiver.role
        ) then
            local taskId =
                tostring(receiver.taskId)
            local metadata =
                BuildBackupMetadataFromRadio(data, receiver)

            if metadata then
                local targetVehicle =
                    ResolvePursuitTargetVehicle(metadata)

                LastRadioBackupDebug[taskId] = {
                    taskId = taskId,
                    mode = receiver.mode or "pursuit_backup",
                    status = receiver.status or receiver.mode or "ai_assigned",
                    assignedIncidentId = metadata.incidentId,
                    pursuitRole = metadata.role,
                    targetPlate = metadata.plate,
                    targetNetId = metadata.netId,
                    interceptPoint = metadata.interceptPoint,
                    distanceToSuspect = metadata.distanceToSuspect,
                    liveTargetResolved = targetVehicle ~= nil and DoesEntityExist(targetVehicle),
                    receivedAt = GetGameTimer()
                }

                local unit, activeTaskId =
                    GetActiveAIUnitByTaskId(taskId)

                if unit then
                    ApplyPursuitBackupMetadata(activeTaskId, unit, metadata)
                end
            end
        end
    end
end

local function GetThreatScore(threatLevel)
    local threat =
        Config.ThreatLevels
        and Config.ThreatLevels[threatLevel or "low"]
        or nil

    return threat and tonumber(threat.score) or 1
end

local function GetResponseDrivingSpeed(threatLevel)
    local response =
        Config.AIResponse or {}
    local speeds =
        response.speedByThreat or {}

    return speeds[threatLevel or "low"]
        or response.drivingSpeed
        or 30.0
end

local function GetResponseDrivingStyle(threatLevel)
    if threatLevel == "high"
    or threatLevel == "deadly" then
        return (Config.AIResponse and Config.AIResponse.emergencyDrivingStyle)
            or (Config.EmergencyDriving and Config.EmergencyDriving.drivingStyle)
            or 1074528293
    end

    return (Config.AIResponse and Config.AIResponse.drivingStyle) or 786603
end

local function GetSpawnPointNearIncident(coords)
    local response =
        Config.AIResponse or {}
    local minDistance =
        tonumber(response.minSpawnDistance) or tonumber(response.spawnDistance) or 95.0
    local maxDistance =
        tonumber(response.maxSpawnDistance) or tonumber(response.spawnDistance) or 145.0
    local attempts =
        tonumber(response.spawnAttempts) or 12
    local sideMin =
        tonumber(response.spawnSideOffsetMin) or 25.0
    local sideMax =
        tonumber(response.spawnSideOffsetMax) or 70.0

    if maxDistance < minDistance then
        maxDistance =
            minDistance
    end

    local playerPed =
        PlayerPedId()
    local forward =
        DoesEntityExist(playerPed)
        and GetEntityForwardVector(playerPed)
        or vector3(0.0, 1.0, 0.0)
    local right =
        vector3(-forward.y, forward.x, 0.0)

    for attempt = 1, attempts do
        local side =
            attempt % 2 == 0 and 1.0 or -1.0
        local distance =
            math.random(math.floor(minDistance), math.floor(maxDistance))
        local sideOffset =
            math.random(math.floor(sideMin), math.floor(sideMax))
        local wantedCoords =
            coords - (forward * distance) + (right * side * sideOffset)
        local found, spawnPos, heading =
            GetClosestVehicleNodeWithHeading(
                wantedCoords.x,
                wantedCoords.y,
                wantedCoords.z,
                1,
                3.0,
                0
            )

        if found
        and #(spawnPos - coords) >= (minDistance * 0.75) then
            return vector4(spawnPos.x, spawnPos.y, spawnPos.z, heading)
        end
    end

    local fallbackDistance =
        tonumber(response.spawnDistance) or 120.0
    local fallbackCoords =
        coords - (forward * fallbackDistance)

    return vector4(fallbackCoords.x, fallbackCoords.y, fallbackCoords.z, GetEntityHeading(playerPed))
end

local function ConfigureResponseOfficer(ped, threatLevel)
    if not ped
    or not DoesEntityExist(ped) then
        return
    end

    local response =
        Config.AIResponse or {}
    local score =
        GetThreatScore(threatLevel)
    local accuracy =
        math.min(
            tonumber(response.officerAccuracyMax) or 70,
            (tonumber(response.officerAccuracyBase) or 35)
                + (score * (tonumber(response.officerAccuracyPerThreat) or 8))
        )

    SetPedAsCop(ped, true)
    SetPedRelationshipGroupHash(ped, joaat("COP"))
    SetPedAccuracy(ped, accuracy)
    SetPedCombatAbility(ped, score >= 3 and 2 or 1)
    SetPedCombatMovement(ped, score >= 2 and 2 or 1)
    SetPedCombatRange(ped, 2)
    SetPedKeepTask(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if threatLevel == "high"
    or threatLevel == "deadly" then
        GiveWeaponToPed(ped, joaat("WEAPON_CARBINERIFLE"), 120, false, true)
    else
        GiveWeaponToPed(ped, joaat("WEAPON_PISTOL"), 80, false, true)
    end
end

local function GetSceneBehaviorForUnit(unit)
    local threatLevel =
        unit.threatLevel or "low"
    local sceneCfg =
        Config.AIScene or {}
    local behaviorKey =
        sceneCfg.threatBehavior and sceneCfg.threatBehavior[threatLevel]

    if not behaviorKey then
        behaviorKey =
            "investigate"
    end

    local behavior =
        sceneCfg.behaviors and sceneCfg.behaviors[behaviorKey]

    if not behavior then
        behaviorKey =
            "investigate"
        behavior =
            sceneCfg.behaviors and sceneCfg.behaviors.investigate
    end

    return behaviorKey, behavior
end

local function SendPedToScenePosition(ped, coords, offsetX, offsetY)
    if not ped
    or not DoesEntityExist(ped) then
        return
    end

    TaskGoToCoordAnyMeans(
        ped,
        coords.x + (offsetX or 0.0),
        coords.y + (offsetY or 0.0),
        coords.z,
        (Config.AIScene and Config.AIScene.walkSpeed) or 1.0,
        0,
        false,
        786603,
        0.0
    )
end

local function StartPedSceneBehavior(ped, coords, behaviorKey)
    if not ped
    or not DoesEntityExist(ped) then
        return
    end

    ClearPedTasks(ped)

    if behaviorKey == "investigate" then
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
    elseif behaviorKey == "stage" then
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_MOBILE", 0, true)
    elseif behaviorKey == "contain" then
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_GUARD_STAND", 0, true)
    else
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_COP_IDLES", 0, true)
    end
end

local function IsEmergencyAiResponse(task)
    if not Config.EmergencyDriving
    or Config.EmergencyDriving.enabled == false then
        return false
    end

    local threatLevel =
        task and task.threatLevel

    if threatLevel then
        threatLevel =
            tostring(threatLevel):lower()
    end

    return threatLevel == "high"
        or threatLevel == "deadly"
end

local function EmergencyDriveToCoords(driver, vehicle, coords)
    if not driver
    or not vehicle
    or not coords then
        return
    end

    if not DoesEntityExist(driver)
    or not DoesEntityExist(vehicle) then
        return
    end

    local speed =
        (
            Config.EmergencyDriving
            and Config.EmergencyDriving.driveSpeed
        )
        or (
            Config.AIResponse
            and Config.AIResponse.drivingSpeed
        )
        or 30.0
    local style =
        (
            Config.EmergencyDriving
            and Config.EmergencyDriving.drivingStyle
        )
        or (
            Config.AIResponse
            and Config.AIResponse.drivingStyle
        )
        or 1074528293

    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        coords.x,
        coords.y,
        coords.z,
        speed,
        style,
        10.0
    )
end

local function DriveResponseUnitToCoords(unit, coords)
    if not unit
    or not unit.driver
    or not unit.vehicle
    or not coords then
        return
    end

    if not DoesEntityExist(unit.driver)
    or not DoesEntityExist(unit.vehicle) then
        return
    end

    local threatLevel =
        unit.threatLevel or "low"
    local speed =
        GetResponseDrivingSpeed(threatLevel)
    local style =
        GetResponseDrivingStyle(threatLevel)

    if unit.pursuitBackup then
        speed =
            math.max(speed, (Config.EmergencyDriving and Config.EmergencyDriving.driveSpeed) or 42.0)
        style =
            (Config.EmergencyDriving and Config.EmergencyDriving.drivingStyle) or style
    end

    SetVehicleSiren(unit.vehicle, true)
    SetVehicleHasMutedSirens(unit.vehicle, unit.pursuitBackup and false or (threatLevel ~= "high" and threatLevel ~= "deadly"))
    SetDriverAbility(unit.driver, unit.pursuitBackup and 1.0 or ((Config.AIResponse and Config.AIResponse.defaultDriverAbility) or 1.0))
    SetDriverAggressiveness(
        unit.driver,
        unit.pursuitBackup
        and 0.95
        or
        (
            threatLevel == "high"
            or threatLevel == "deadly"
        )
        and ((Config.AIResponse and Config.AIResponse.highThreatDriverAggressiveness) or 0.85)
        or ((Config.AIResponse and Config.AIResponse.defaultDriverAggressiveness) or 0.55)
    )

    TaskVehicleDriveToCoordLongrange(
        unit.driver,
        unit.vehicle,
        coords.x,
        coords.y,
        coords.z,
        speed,
        style,
        12.0
    )

    unit.lastDriveTaskAt =
        GetGameTimer()
end

local function UpdatePursuitBackupUnit(taskId, unit)
    if not unit
    or not unit.pursuitBackup
    or not unit.vehicle
    or not unit.driver
    or not DoesEntityExist(unit.vehicle)
    or not DoesEntityExist(unit.driver) then
        return
    end

    local cfg =
        Config.PursuitBackup or {}
    local targetVehicle =
        ResolvePursuitTargetVehicle(unit.pursuitBackup)
    local vehicleCoords =
        GetEntityCoords(unit.vehicle)
    local suspectCoords =
        targetVehicle
        and DoesEntityExist(targetVehicle)
        and GetEntityCoords(targetVehicle)
        or NormalizeCoords(unit.pursuitBackup.lastKnownCoords)
    local distanceToSuspect =
        suspectCoords and #(vehicleCoords - suspectCoords) or nil
    local switchDistance =
        tonumber(cfg.switchToChaseDistance) or 70.0
    local updateMs =
        tonumber(cfg.updateIntervalMs) or 2500

    ConfigurePursuitBackupDriving(unit)

    if targetVehicle
    and DoesEntityExist(targetVehicle)
    and distanceToSuspect
    and distanceToSuspect <= switchDistance then
        if unit.status ~= "pursuit_secondary" then
            ClearPedTasks(unit.driver)
            TaskVehicleChase(unit.driver, targetVehicle)
            unit.status =
                "pursuit_secondary"
            unit.mode =
                "pursuit_secondary"
            unit.lastDriveTaskAt =
                GetGameTimer()

            TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "pursuit_secondary", {
                incidentId = unit.incidentId,
                role = unit.pursuitBackup.role,
                distanceToSuspect = distanceToSuspect
            })

            if cfg.debug then
                DebugPrint("backup joined chase", taskId, "dist", distanceToSuspect)
            end
        end

        LastPursuitBackupDebug[taskId] = {
            incidentId = unit.incidentId,
            role = unit.pursuitBackup.role,
            mode = unit.mode or unit.status,
            plate = unit.pursuitBackup.plate,
            netId = unit.pursuitBackup.netId,
            distanceToSuspect = distanceToSuspect,
            interceptPoint = unit.lastInterceptPoint
        }
        return
    end

    if GetGameTimer() - (unit.lastDriveTaskAt or 0) < updateMs then
        return
    end

    local interceptPoint =
        CalculatePursuitInterceptPoint(unit, targetVehicle)

    if not interceptPoint then
        return
    end

    unit.lastInterceptPoint =
        ToCoordsTable(interceptPoint)
    unit.status =
        unit.pursuitBackup.role == "containment" and "containment" or "pursuit_intercept"
    unit.mode =
        unit.status

    DriveResponseUnitToCoords(unit, interceptPoint)

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, unit.status, {
        incidentId = unit.incidentId,
        role = unit.pursuitBackup.role,
        interceptPoint = unit.lastInterceptPoint,
        distanceToSuspect = distanceToSuspect
    })

    LastPursuitBackupDebug[taskId] = {
        incidentId = unit.incidentId,
        role = unit.pursuitBackup.role,
        mode = unit.mode,
        plate = unit.pursuitBackup.plate,
        netId = unit.pursuitBackup.netId,
        distanceToSuspect = distanceToSuspect,
        interceptPoint = unit.lastInterceptPoint
    }

    if cfg.debug then
        DebugPrint("backup intercept", taskId, unit.pursuitBackup.role, "dist", distanceToSuspect or "unknown")
    end
end

local function CleanupAIUnit(taskId, manualClose)
    local unit =
        ActiveAIUnits[taskId]

    if not unit then
        return
    end

    if unit.driver
    and DoesEntityExist(unit.driver) then
        DeleteEntity(unit.driver)
    end

    if unit.passenger
    and DoesEntityExist(unit.passenger) then
        DeleteEntity(unit.passenger)
    end

    if unit.vehicle
    and DoesEntityExist(unit.vehicle) then
        DeleteEntity(unit.vehicle)
    end

    ActiveAIUnits[taskId] =
        nil

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "cleared", {
        incidentId = unit.incidentId,
        manual = manualClose == true
    })
end

local function BeginAIUnitScene(taskId, unit, forced)
    if not unit
    or unit.sceneStarted then
        return
    end

    unit.arrived =
        true
    unit.status =
        "arrived"

    if unit.vehicle
    and DoesEntityExist(unit.vehicle) then
        SetVehicleSiren(unit.vehicle, forced == true)
        SetVehicleHasMutedSirens(unit.vehicle, true)
    end

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "arrived", {
        incidentId = unit.incidentId,
        forced = forced == true
    })

    if Config.AIScene
    and Config.AIScene.enabled ~= false then
        local behaviorKey, behavior =
            GetSceneBehaviorForUnit(unit)

        unit.sceneBehavior =
            behaviorKey
        unit.sceneStarted =
            true
        unit.sceneStartedAt =
            GetGameTimer()
        unit.status =
            behaviorKey

        local durationSeconds =
            behavior and behavior.durationSeconds
            or Config.AIScene.autoClearAfterSeconds
            or Config.AIScene.investigationDurationSeconds
            or 90

        if behavior
        and behavior.autoClear == false then
            unit.clearAfter =
                nil
        else
            unit.clearAfter =
                GetGameTimer() + (durationSeconds * 1000)
        end

        StartPedSceneBehavior(unit.driver, unit.coords, behaviorKey)

        if unit.passenger
        and DoesEntityExist(unit.passenger) then
            StartPedSceneBehavior(unit.passenger, unit.coords, behaviorKey)
        end

        TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "scene_" .. behaviorKey, {
            incidentId = unit.incidentId,
            behavior = behaviorKey
        })
    end
end

local function SpawnAIUnit(task)
    if not Config.AIResponse.enabled then
        return false, "disabled"
    end

    local weatherDelayMs =
        GetWeatherResponseDelayMs(task)

    if weatherDelayMs > 0 then
        DebugPrint("weather response delay", weatherDelayMs, "ms")
        Wait(weatherDelayMs)
    end

    if CountActiveUnits() >= (Config.AIResponse.maxActiveUnits or 5) then
        return false, "maxUnits"
    end

    local coords =
        task and NormalizeCoords(task.coords) or nil

    if not coords then
        return false, "noCoords"
    end

    local unitType =
        task.unitType or "patrol"
    local vehicleModel =
        (Config.AIResponse.vehicleModels and Config.AIResponse.vehicleModels[unitType])
        or (Config.AIResponse.vehicleModels and Config.AIResponse.vehicleModels.patrol)
        or "police"
    local vehicleHash =
        LoadModel(vehicleModel)

    if not vehicleHash then
        return false, "spawnFailed"
    end

    local spawn =
        GetSpawnPointNearIncident(coords)
    local vehicle =
        CreateVehicle(vehicleHash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(vehicleHash)
        return false, "spawnFailed"
    end

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleSiren(vehicle, true)
    SetVehicleHasMutedSirens(vehicle, false)

    local pedModels =
        Config.AIResponse.pedModels or { "s_m_y_cop_01" }
    local driverHash =
        LoadModel(pedModels[1] or "s_m_y_cop_01")
    local passengerHash =
        LoadModel(pedModels[2] or pedModels[1] or "s_m_y_cop_01")

    if not driverHash then
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(vehicleHash)
        return false, "spawnFailed"
    end

    local driver =
        CreatePedInsideVehicle(vehicle, 4, driverHash, -1, true, true)
    local passenger =
        nil

    if passengerHash then
        passenger =
            CreatePedInsideVehicle(vehicle, 4, passengerHash, 0, true, true)
    end

    ConfigureResponseOfficer(driver, task.threatLevel or "low")

    if passenger
    and DoesEntityExist(passenger) then
        ConfigureResponseOfficer(passenger, task.threatLevel or "low")
    end

    local unit = {
        taskId = task.taskId,
        incidentId = task.incidentId,
        unitType = unitType,
        vehicle = vehicle,
        driver = driver,
        passenger = passenger,
        coords = coords,
        threatLevel = task.threatLevel or "low",
        forcePolicy = task.forcePolicy,
        response = task.response,
        pursuitBackup = task.pursuitBackup,
        mode = task.pursuitBackup and "pursuit_backup" or "responding",
        status = "responding",
        createdAt = GetGameTimer(),
        arrived = false,
        sceneBehavior = nil,
        sceneStarted = false,
        sceneStartedAt = nil,
        clearRequested = false,
        clearAfter = nil,
        lastDriveTaskAt = 0,
        forceDismountAt = GetGameTimer() + ((Config.AIResponse and Config.AIResponse.forceDismountAfterMs) or 25000)
    }

    ActiveAIUnits[task.taskId] =
        unit

    if unit.pursuitBackup then
        ApplyPursuitBackupMetadata(task.taskId, unit, unit.pursuitBackup)
        ConfigurePursuitBackupDriving(unit)
        UpdatePursuitBackupUnit(task.taskId, unit)
    else
        DriveResponseUnitToCoords(unit, coords)
    end

    DebugPrint("spawned AI unit", task.taskId, "incident", task.incidentId)

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", task.taskId, unit.status, {
        incidentId = task.incidentId,
        role = unit.pursuitBackup and unit.pursuitBackup.role or nil
    })

    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(driverHash)

    if passengerHash then
        SetModelAsNoLongerNeeded(passengerHash)
    end

    return true, unit
end

CreateThread(function()
    while true do
        Wait(2500)

        for taskId, unit in pairs(ActiveAIUnits) do
            if not unit.vehicle
            or not DoesEntityExist(unit.vehicle) then
                ActiveAIUnits[taskId] =
                    nil
            else
                local vehicleCoords =
                    GetEntityCoords(unit.vehicle)
                local distance =
                    #(vehicleCoords - unit.coords)
                local lifetimeSeconds =
                    (GetGameTimer() - unit.createdAt) / 1000

                if unit.pursuitBackup then
                    UpdatePursuitBackupUnit(taskId, unit)
                elseif not unit.arrived
                and distance <= (Config.AIResponse.arrivalDistance or 25.0) then
                    SetVehicleSiren(unit.vehicle, false)
                    TaskVehicleTempAction(unit.driver, unit.vehicle, 27, 2000)

                    Wait(1500)

                    if DoesEntityExist(unit.driver) then
                        TaskLeaveVehicle(unit.driver, unit.vehicle, 0)
                    end

                    if unit.passenger
                    and DoesEntityExist(unit.passenger) then
                        TaskLeaveVehicle(unit.passenger, unit.vehicle, 0)
                    end

                    Wait(2000)

                    SendPedToScenePosition(unit.driver, unit.coords, 0.0, 0.0)
                    SendPedToScenePosition(unit.passenger, unit.coords, 3.0, 3.0)

                    Wait(2500)

                    BeginAIUnitScene(taskId, unit, false)

                    DebugPrint("AI unit arrived", taskId)
                elseif not unit.arrived then
                    local response =
                        Config.AIResponse or {}
                    local refreshMs =
                        tonumber(response.responseRefreshMs) or 4000
                    local shouldRefresh =
                        GetGameTimer() - (unit.lastDriveTaskAt or 0) >= refreshMs
                    local shouldForceDismount =
                        unit.forceDismountAt
                        and GetGameTimer() >= unit.forceDismountAt
                        and distance <= (tonumber(response.engageDistance) or 45.0)

                    if shouldForceDismount then
                        SetVehicleSiren(unit.vehicle, true)
                        SetVehicleHasMutedSirens(unit.vehicle, true)
                        TaskVehicleTempAction(unit.driver, unit.vehicle, 27, 1500)

                        Wait(1000)

                        if DoesEntityExist(unit.driver) then
                            TaskLeaveVehicle(unit.driver, unit.vehicle, 0)
                        end

                        if unit.passenger
                        and DoesEntityExist(unit.passenger) then
                            TaskLeaveVehicle(unit.passenger, unit.vehicle, 0)
                        end

                        SendPedToScenePosition(unit.driver, unit.coords, 0.0, 0.0)
                        SendPedToScenePosition(unit.passenger, unit.coords, 3.0, 3.0)
                        BeginAIUnitScene(taskId, unit, true)
                    elseif shouldRefresh then
                        DriveResponseUnitToCoords(unit, unit.coords)
                    end
                elseif unit.sceneStarted
                and not unit.clearRequested
                and unit.clearAfter
                and Config.AIScene
                and Config.AIScene.autoClearEnabled
                and GetGameTimer() >= unit.clearAfter then
                    unit.clearRequested =
                        true
                    unit.status =
                        "clearing"

                    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "clearing", {
                        incidentId = unit.incidentId
                    })

                    CreateThread(function()
                        Wait(5000)
                        CleanupAIUnit(taskId, false)
                    end)
                elseif lifetimeSeconds >= (Config.AIResponse.cleanupAfterSeconds or 600) then
                    CleanupAIUnit(taskId, false)
                end
            end
        end
    end
end)

RegisterNetEvent("gs_police:client:spawnAiUnit", function(task)
    local success, result =
        SpawnAIUnit(task)

    if not success then
        TriggerServerEvent("gs_police:server:updateAiUnitStatus", task and task.taskId, "failed", {
            incidentId = task and task.incidentId,
            reason = result
        })

        local message =
            Config.AIResponse.messages[result]
            or Config.AIResponse.messages.spawnFailed
            or "Unable to spawn AI police unit."

        QBCore.Functions.Notify(message, "error")
        return
    end

    QBCore.Functions.Notify(Config.AIResponse.messages.dispatched or "AI police unit dispatched.", "success")
end)

RegisterNetEvent("gs_police:client:updatePursuitBackup", function(data)
    if not data
    or not data.incidentId then
        return
    end

    for taskId, unit in pairs(ActiveAIUnits) do
        if tostring(unit.incidentId) == tostring(data.incidentId) then
            local role =
                unit.pursuitBackup and unit.pursuitBackup.role

            data.role =
                role or data.role or "interceptor"
            ApplyPursuitBackupMetadata(taskId, unit, data)

            UpdatePursuitBackupUnit(taskId, unit)
        end
    end
end)

RegisterNetEvent("gs_police:client:receiveSuspectBroadcast", function(data)
    if not data then
        return
    end

    CacheRadioBackupReceivers(data)

    if data.pursuitBackup then
        TriggerEvent("gs_police:client:updatePursuitBackup", data.pursuitBackup)
    end
end)

RegisterNetEvent("gs_police:client:clearAiUnit", function(taskId)
    CleanupAIUnit(taskId, true)
end)

RegisterCommand("police_clearai", function()
    for taskId in pairs(ActiveAIUnits) do
        CleanupAIUnit(taskId, true)
    end

    QBCore.Functions.Notify("AI police units cleared.", "success")
end, false)

RegisterCommand("police_clearaiunit", function(_, args)
    local taskId =
        args and args[1]

    if not taskId
    or taskId == "" then
        QBCore.Functions.Notify("Usage: /police_clearaiunit <taskId>", "error")
        return
    end

    local unit =
        ActiveAIUnits[taskId]

    if not unit then
        QBCore.Functions.Notify(
            (Config.AIScene and Config.AIScene.messages and Config.AIScene.messages.invalidTask)
            or "Invalid AI task.",
            "error"
        )
        return
    end

    unit.clearRequested =
        true

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "clearing", {
        incidentId = unit.incidentId
    })

    CleanupAIUnit(taskId, true)
    QBCore.Functions.Notify("AI unit cleared.", "success")
end, false)

RegisterCommand("police_aistate", function()
    local count =
        0

    for taskId, unit in pairs(ActiveAIUnits) do
        count =
            count + 1

        print(("[gs_police:ai] task=%s incident=%s status=%s arrived=%s scene=%s"):format(
            tostring(taskId),
            tostring(unit.incidentId),
            tostring(unit.status),
            tostring(unit.arrived),
            tostring(unit.sceneBehavior)
        ))
    end

    QBCore.Functions.Notify(("Active AI police units: %s"):format(count), "primary")
end, false)

RegisterCommand("police_backupdebug", function()
    local count =
        0
    local printedRadioFallback =
        0

    print("[gs_police:backup_debug] ===== Pursuit Backup =====")

    for taskId, unit in pairs(ActiveAIUnits) do
        count =
            count + 1

        local debugInfo =
            LastPursuitBackupDebug[taskId] or {}
        local backup =
            unit.pursuitBackup or {}
        local hasPursuitMetadata =
            unit.pursuitBackup ~= nil
            or unit.pursuitRole ~= nil
            or unit.interceptPoint ~= nil
        local targetVehicle =
            ResolvePursuitTargetVehicle(backup)
        local distanceToSuspect =
            debugInfo.distanceToSuspect

        if not distanceToSuspect
        and targetVehicle
        and DoesEntityExist(targetVehicle)
        and unit.vehicle
        and DoesEntityExist(unit.vehicle) then
            distanceToSuspect =
                #(GetEntityCoords(unit.vehicle) - GetEntityCoords(targetVehicle))
        end

        if not hasPursuitMetadata then
            print(("[gs_police:backup_debug] unit exists but no pursuit metadata task=%s"):format(
                tostring(taskId)
            ))
        end

        print(("[gs_police:backup_debug] taskId=%s mode=%s status=%s assignedIncidentId=%s pursuitRole=%s targetPlate=%s targetNetId=%s interceptPoint=%s liveTargetResolved=%s distanceToSuspect=%s"):format(
            tostring(taskId),
            tostring(unit.mode),
            tostring(unit.status),
            tostring(unit.assignedIncidentId or unit.incidentId),
            tostring(unit.pursuitRole or backup.role),
            tostring(unit.targetPlate or backup.plate),
            tostring(unit.targetNetId or backup.netId),
            json.encode(debugInfo.interceptPoint or unit.interceptPoint or unit.lastInterceptPoint or {}),
            tostring(targetVehicle ~= nil and DoesEntityExist(targetVehicle)),
            tostring(distanceToSuspect or "unknown")
        ))
    end

    if count == 0 then
        print("[gs_police:backup_debug] no local AI response units found")
    end

    for taskId, debugInfo in pairs(LastRadioBackupDebug) do
        local localUnit =
            GetActiveAIUnitByTaskId(taskId)

        if not localUnit then
            printedRadioFallback =
                printedRadioFallback + 1

            print(("[gs_police:backup_debug] radioReceiver taskId=%s mode=%s status=%s assignedIncidentId=%s pursuitRole=%s targetPlate=%s targetNetId=%s interceptPoint=%s liveTargetResolved=%s distanceToSuspect=%s"):format(
                tostring(debugInfo.taskId or taskId),
                tostring(debugInfo.mode),
                tostring(debugInfo.status),
                tostring(debugInfo.assignedIncidentId),
                tostring(debugInfo.pursuitRole),
                tostring(debugInfo.targetPlate),
                tostring(debugInfo.targetNetId),
                json.encode(debugInfo.interceptPoint or {}),
                tostring(debugInfo.liveTargetResolved),
                tostring(debugInfo.distanceToSuspect or "unknown")
            ))
        end
    end

    QBCore.Functions.Notify(("AI response units: %s radio backups: %s"):format(count, printedRadioFallback), "primary")
end, false)
