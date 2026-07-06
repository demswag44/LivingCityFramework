local QBCore =
    exports["qb-core"]:GetCoreObject()

local ActiveAIUnits = {}

local function DebugPrint(...)
    if Config
    and Config.AIResponse
    and Config.AIResponse.debug then
        print("[gs_police:ai_response]", ...)
    end
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

local function GetSpawnPointNearIncident(coords)
    local spawnDistance =
        Config.AIResponse.spawnDistance or 120.0
    local found, spawnPos, heading =
        GetClosestVehicleNodeWithHeading(
            coords.x + spawnDistance,
            coords.y + spawnDistance,
            coords.z,
            1,
            3.0,
            0
        )

    if found then
        return vector4(spawnPos.x, spawnPos.y, spawnPos.z, heading)
    end

    return vector4(coords.x + spawnDistance, coords.y + spawnDistance, coords.z, 0.0)
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

local function SpawnAIUnit(task)
    if not Config.AIResponse.enabled then
        return false, "disabled"
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

    SetPedAsCop(driver, true)
    SetPedKeepTask(driver, true)
    SetBlockingOfNonTemporaryEvents(driver, true)

    if passenger
    and DoesEntityExist(passenger) then
        SetPedAsCop(passenger, true)
        SetPedKeepTask(passenger, true)
        SetBlockingOfNonTemporaryEvents(passenger, true)
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
        status = "responding",
        createdAt = GetGameTimer(),
        arrived = false,
        sceneBehavior = nil,
        sceneStarted = false,
        sceneStartedAt = nil,
        clearRequested = false,
        clearAfter = nil
    }

    ActiveAIUnits[task.taskId] =
        unit

    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        coords.x,
        coords.y,
        coords.z,
        Config.AIResponse.drivingSpeed or 22.0,
        Config.AIResponse.drivingStyle or 786603,
        15.0
    )

    DebugPrint("spawned AI unit", task.taskId, "incident", task.incidentId)

    TriggerServerEvent("gs_police:server:updateAiUnitStatus", task.taskId, "responding", {
        incidentId = task.incidentId
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

                if not unit.arrived
                and distance <= (Config.AIResponse.arrivalDistance or 25.0) then
                    unit.arrived =
                        true
                    unit.status =
                        "arrived"

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

                    TriggerServerEvent("gs_police:server:updateAiUnitStatus", taskId, "arrived", {
                        incidentId = unit.incidentId
                    })

                    Wait(2500)

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

                    DebugPrint("AI unit arrived", taskId)
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
