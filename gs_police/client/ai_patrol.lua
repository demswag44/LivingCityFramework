local QBCore =
    exports["qb-core"]:GetCoreObject()

print("[gs_police:ai_patrol] client file loaded")

local ActivePatrols = {}
local PendingTargetSnapshots = {}
local LastMoveOverAt = 0
local LastEmergencyRepathSkipLogAt = 0
local ForcedComplianceOutcome = nil
local PendingCityBrainPatrolBiasRequests = {}
local NextCityBrainPatrolBiasRequestId = 1
local PendingCityBrainPatrolPressureRequests = {}
local NextCityBrainPatrolPressureRequestId = 1
local CityBrainPatrolPressureCache = {}
local LastCityBrainPatrolPressureRefreshAt = 0

local function DebugPrint(...)
    if Config
    and Config.AIPatrol
    and Config.AIPatrol.debug then
        print("[gs_police:ai_patrol]", ...)
    end
end

local function DebugCompliance(...)
    if Config
    and Config.SuspectCompliance
    and Config.SuspectCompliance.debug then
        print("[gs_police:compliance]", ...)
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

local function GetConfiguredPatrolZoneKeys()
    local zones =
        Config.AIPatrol
        and Config.AIPatrol.zones
        or {}
    local zoneKeys = {}

    for zoneKey, zone in pairs(zones) do
        if zone
        and zone.enabled ~= false then
            zoneKeys[#zoneKeys + 1] =
                zoneKey
        end
    end

    table.sort(zoneKeys)

    return zoneKeys
end

local function RequestCityBrainPatrolBiases(zoneKeys)
    if not Config.CityBrainPatrolBiasEnabled then
        return {}
    end

    local requestId =
        NextCityBrainPatrolBiasRequestId
    NextCityBrainPatrolBiasRequestId =
        NextCityBrainPatrolBiasRequestId + 1

    PendingCityBrainPatrolBiasRequests[requestId] = nil
    TriggerServerEvent("gs_police:server:getCityBrainPatrolBiases", requestId, zoneKeys)

    local startedAt =
        GetGameTimer()

    while GetGameTimer() - startedAt < 500 do
        if PendingCityBrainPatrolBiasRequests[requestId] ~= nil then
            local biases =
                PendingCityBrainPatrolBiasRequests[requestId]
            PendingCityBrainPatrolBiasRequests[requestId] =
                nil

            return biases
        end

        Wait(0)
    end

    return {}
end

local function SelectPatrolZoneWithCityBrainBias()
    local zoneKeys =
        GetConfiguredPatrolZoneKeys()

    if #zoneKeys == 0 then
        return nil, nil
    end

    local fallbackZoneKey =
        zoneKeys[1]
    local biases =
        RequestCityBrainPatrolBiases(zoneKeys)
    local bestZoneKey =
        fallbackZoneKey
    local bestWeight =
        1.0
    local bestBias =
        nil

    for _, zoneKey in ipairs(zoneKeys) do
        local bias =
            biases and biases[zoneKey]
        local weight =
            tonumber(bias and bias.patrolWeight) or 1.0

        if weight > bestWeight then
            bestZoneKey =
                zoneKey
            bestWeight =
                weight
            bestBias =
                bias
        end
    end

    return bestZoneKey, bestBias
end

local function GetNeutralCityBrainPatrolPressure(reason)
    return {
        patrolIntervalModifier = 1.0,
        lingerTimeModifier = 1.0,
        awarenessModifier = 1.0,
        felonyStopSensitivityModifier = 1.0,
        reason = reason or "disabled"
    }
end

local function IsCityBrainPressureEmergencyMode(mode)
    return mode == "responding"
        or mode == "pursuit"
        or mode == "felony_stop"
        or mode == "foot_pursuit"
end

local function NormalizeCityBrainPatrolPressure(pressure)
    if type(pressure) ~= "table" then
        return GetNeutralCityBrainPatrolPressure("invalid_pressure")
    end

    local intervalModifier =
        tonumber(pressure.patrolIntervalModifier) or 1.0
    local lingerModifier =
        tonumber(pressure.lingerTimeModifier) or 1.0
    local awarenessModifier =
        tonumber(pressure.awarenessModifier) or 1.0
    local felonyModifier =
        tonumber(pressure.felonyStopSensitivityModifier) or 1.0

    return {
        patrolIntervalModifier = math.max(0.70, math.min(intervalModifier, 1.25)),
        lingerTimeModifier = math.max(0.75, math.min(lingerModifier, 1.75)),
        awarenessModifier = math.max(1.0, math.min(awarenessModifier, 1.50)),
        felonyStopSensitivityModifier = math.max(0.75, math.min(felonyModifier, 1.10)),
        reason = pressure.reason or "ok",
        zone = pressure.zone,
        recommendationCount = tonumber(pressure.recommendationCount) or 0
    }
end

local function RequestCityBrainPatrolPressures(zoneKeys)
    if not Config.CityBrainPatrolPressureTuningEnabled then
        return {}
    end

    local requestId =
        NextCityBrainPatrolPressureRequestId
    NextCityBrainPatrolPressureRequestId =
        NextCityBrainPatrolPressureRequestId + 1

    PendingCityBrainPatrolPressureRequests[requestId] = nil
    TriggerServerEvent("gs_police:server:getCityBrainPatrolPressures", requestId, zoneKeys)

    local startedAt =
        GetGameTimer()

    while GetGameTimer() - startedAt < 500 do
        if PendingCityBrainPatrolPressureRequests[requestId] ~= nil then
            local pressures =
                PendingCityBrainPatrolPressureRequests[requestId]
            PendingCityBrainPatrolPressureRequests[requestId] =
                nil

            return pressures
        end

        Wait(0)
    end

    return {}
end

local function RefreshCityBrainPatrolPressureCache()
    if not Config.CityBrainPatrolPressureTuningEnabled then
        CityBrainPatrolPressureCache =
            {}
        return
    end

    local zoneKeys =
        GetConfiguredPatrolZoneKeys()

    if #zoneKeys == 0 then
        CityBrainPatrolPressureCache =
            {}
        return
    end

    local pressures =
        RequestCityBrainPatrolPressures(zoneKeys)
    local normalized =
        {}

    for _, zoneKey in ipairs(zoneKeys) do
        normalized[zoneKey] =
            NormalizeCityBrainPatrolPressure(pressures and pressures[zoneKey])
    end

    CityBrainPatrolPressureCache =
        normalized
    LastCityBrainPatrolPressureRefreshAt =
        GetGameTimer()
end

local function GetCityBrainPatrolPressureForZone(zoneKey)
    if not Config.CityBrainPatrolPressureTuningEnabled then
        return GetNeutralCityBrainPatrolPressure("disabled")
    end

    return CityBrainPatrolPressureCache[zoneKey]
        or GetNeutralCityBrainPatrolPressure("not_cached")
end

local function GetCityBrainPatrolPressureForPatrol(patrol)
    return GetCityBrainPatrolPressureForZone(patrol and patrol.zoneKey)
end

local function GetCityBrainPatrolLoopWaitMs()
    local baseWait =
        2500

    if not Config.CityBrainPatrolPressureTuningEnabled then
        return baseWait
    end

    local modifier =
        1.0

    for _, patrol in pairs(ActivePatrols or {}) do
        if patrol
        and not IsCityBrainPressureEmergencyMode(patrol.mode) then
            local pressure =
                GetCityBrainPatrolPressureForPatrol(patrol)
            modifier =
                math.min(modifier, tonumber(pressure.patrolIntervalModifier) or 1.0)
            patrol.cityBrainAwarenessModifier =
                pressure.awarenessModifier
            patrol.cityBrainPressureReason =
                pressure.reason
        end
    end

    return math.floor(baseWait * math.max(0.70, math.min(modifier, 1.0)))
end

local function GetCityBrainWaypointWaitMs(patrol)
    local baseWait =
        Config.AIPatrol.waypointWaitMs or 2500

    if not Config.CityBrainPatrolPressureTuningEnabled
    or IsCityBrainPressureEmergencyMode(patrol and patrol.mode) then
        return baseWait
    end

    local pressure =
        GetCityBrainPatrolPressureForPatrol(patrol)

    patrol.cityBrainAwarenessModifier =
        pressure.awarenessModifier
    patrol.cityBrainPressureReason =
        pressure.reason

    return math.floor(baseWait * (tonumber(pressure.lingerTimeModifier) or 1.0))
end

local function ApplyCityBrainFelonySensitivity(patrol, milliseconds)
    if not Config.CityBrainPatrolPressureTuningEnabled then
        return milliseconds
    end

    local pressure =
        GetCityBrainPatrolPressureForPatrol(patrol)

    return math.floor(milliseconds * (tonumber(pressure.felonyStopSensitivityModifier) or 1.0))
end

local function RequestMovingTargetSnapshot(targetId)
    targetId =
        tonumber(targetId)

    if not targetId then
        return
    end

    PendingTargetSnapshots[targetId] =
        nil

    TriggerServerEvent("gs_police:server:requestMovingTargetSnapshot", targetId)
end

local function IsEmergencyDrivingActive(patrol)
    return patrol
        and patrol.emergencyResponse == true
        and Config.EmergencyDriving
        and Config.EmergencyDriving.enabled ~= false
end

local function IsEmergencyMode(mode)
    return mode == "responding"
        or mode == "pursuit"
        or mode == "felony_stop"
end

local function ToVector3(coords)
    if not coords then
        return nil
    end

    if coords.x
    and coords.y
    and coords.z then
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end

    return nil
end

local function DistanceBetweenVectors(a, b)
    local aVector =
        ToVector3(a)
    local bVector =
        ToVector3(b)

    if not aVector
    or not bVector then
        return 999999.0
    end

    return #(aVector - bVector)
end

local function GetPursuitSpeedForDistance(distance)
    local cfg =
        Config.PursuitTuning or {}
    local speeds =
        cfg.speedByDistance or {}

    if speeds.stopApproach
    and distance <= (speeds.stopApproach.distance or 18.0) then
        return speeds.stopApproach.speed or 10.0, cfg.closeDrivingStyle or 786603
    end

    if speeds.close
    and distance <= (speeds.close.distance or 35.0) then
        return speeds.close.speed or 20.0, cfg.closeDrivingStyle or 786603
    end

    if speeds.medium
    and distance <= (speeds.medium.distance or 75.0) then
        return speeds.medium.speed or 28.0, cfg.drivingStyle or 1074528293
    end

    local speed =
        (
        speeds.far
        and speeds.far.speed
    )
    or (
        Config.Pursuit
        and Config.Pursuit.driveSpeed
    )
    or 32.0
    local style =
        cfg.drivingStyle
        or (
            Config.Pursuit
            and Config.Pursuit.drivingStyle
        )
        or 1074528293

    return speed, style
end

local function GetOfficerSkillProfile(patrol)
    local cfg =
        Config.OfficerSkill or {}
    local profileKey =
        patrol and patrol.skillProfile or cfg.defaultProfile or "patrol_trained"
    local profile =
        cfg.profiles and cfg.profiles[profileKey]

    if not profile then
        profileKey =
            "patrol_trained"
        profile =
            cfg.profiles and cfg.profiles.patrol_trained
    end

    return profileKey, profile
end

local function BuildOfficerReadiness(skill)
    skill =
        skill or {}

    return {
        commandPresence = skill.commandPresence or 0.70,
        weaponDiscipline = skill.weaponDiscipline or 0.70,
        decisionQuality = skill.decisionQuality or 0.70
    }
end

local function ApplyOfficerSkillToSpeed(patrol, driveSpeed, isPursuit)
    local _, skill =
        GetOfficerSkillProfile(patrol)

    driveSpeed =
        driveSpeed or 0.0

    if not skill then
        return driveSpeed
    end

    driveSpeed =
        driveSpeed * (skill.driveSpeedMultiplier or 1.0)

    if isPursuit then
        local pursuitSkill =
            skill.pursuitSkill or 0.70

        if pursuitSkill < 0.5 then
            driveSpeed =
                driveSpeed * 0.90
        elseif pursuitSkill > 0.85 then
            driveSpeed =
                driveSpeed * 1.05
        end
    end

    return driveSpeed
end

local function ApplyPursuitSkillToSpeed(patrol, driveSpeed)
    local _, skill =
        GetOfficerSkillProfile(patrol)
    local pursuitSkill =
        skill and skill.pursuitSkill or 0.70

    driveSpeed =
        driveSpeed or 0.0

    if pursuitSkill < 0.5 then
        driveSpeed =
            driveSpeed * 0.90
    elseif pursuitSkill > 0.85 then
        driveSpeed =
            driveSpeed * 1.05
    end

    local codeKey =
        patrol and patrol.responseCode

    if codeKey == "code1" then
        return math.min(driveSpeed, 28.0)
    elseif codeKey == "code2" then
        return math.min(driveSpeed, 38.0)
    elseif codeKey == "code3" then
        if Config.ContinuousPursuit
        and Config.ContinuousPursuit.removePursuitSpeedCaps
        and patrol
        and patrol.mode == "pursuit" then
            return math.min(
                driveSpeed,
                Config.ContinuousPursuit.maxConfiguredPursuitSpeed or 75.0
            )
        end

        return math.min(driveSpeed, 60.0)
    end

    return driveSpeed
end

local function ApplyContinuousPursuitSpeed(patrol, driveSpeed)
    driveSpeed =
        driveSpeed
        or (
            Config.ContinuousPursuit
            and Config.ContinuousPursuit.basePursuitSpeed
        )
        or 55.0

    driveSpeed =
        ApplyPursuitSkillToSpeed(patrol, driveSpeed)

    if Config.ContinuousPursuit
    and Config.ContinuousPursuit.removePursuitSpeedCaps then
        return math.min(
            driveSpeed,
            Config.ContinuousPursuit.maxConfiguredPursuitSpeed or 75.0
        )
    end

    return driveSpeed
end

local function GetSkillRepathMultiplier(patrol)
    local _, skill =
        GetOfficerSkillProfile(patrol)

    return skill and skill.repathDelayMultiplier or 1.0
end

local function GetSkillFollowDistance(patrol, fallback)
    local _, skill =
        GetOfficerSkillProfile(patrol)
    local pursuitSkill =
        skill and skill.pursuitSkill or 0.70

    fallback =
        fallback or 22.0

    if pursuitSkill >= 0.85 then
        return math.max(16.0, fallback - 3.0)
    elseif pursuitSkill <= 0.50 then
        return fallback + 5.0
    end

    return fallback
end

local function GetSkillFelonyParkingDistance(patrol, fallback)
    local _, skill =
        GetOfficerSkillProfile(patrol)
    local sceneSkill =
        skill and skill.scenePositioning or 0.70

    fallback =
        fallback or 12.0

    if sceneSkill >= 0.85 then
        return math.max(fallback, 15.0)
    elseif sceneSkill <= 0.50 then
        return math.min(fallback, 10.0)
    end

    return fallback
end

local function IsTargetSnapshotFresh(snapshot)
    if not snapshot then
        return false
    end

    local felonyCfg =
        Config.PursuitTuning
        and Config.PursuitTuning.felonyStop
        or {}

    if felonyCfg.requireRecentTargetUpdate == false then
        return true
    end

    local updatedAt =
        tonumber(snapshot.updatedAt)

    if not updatedAt then
        return false
    end

    local nowSeconds =
        math.floor(GetCloudTimeAsInt and GetCloudTimeAsInt() or 0)

    if nowSeconds <= 0 then
        return true
    end

    local maxAge =
        felonyCfg.maxTargetUpdateAgeSeconds or 8

    return (nowSeconds - updatedAt) <= maxAge
end

local function GetEntityForwardOffset(entity, forwardDistance, rightDistance)
    local coords =
        GetEntityCoords(entity)
    local heading =
        math.rad(GetEntityHeading(entity))

    local forwardX =
        math.sin(heading) * -1.0
    local forwardY =
        math.cos(heading)

    local rightX =
        math.cos(heading)
    local rightY =
        math.sin(heading)

    return vector3(
        coords.x + (forwardX * forwardDistance) + (rightX * rightDistance),
        coords.y + (forwardY * forwardDistance) + (rightY * rightDistance),
        coords.z
    )
end

local function GetFelonyStopParkingPoint(targetCoords, targetHeading, patrol)
    local arrivalCfg =
        Config.PursuitTuning
        and Config.PursuitTuning.arrival
        or {}
    local behind =
        arrivalCfg.parkBehindDistance or 13.0
    local _, skill =
        GetOfficerSkillProfile(patrol)
    local sceneSkill =
        skill and skill.scenePositioning or 0.70

    if sceneSkill >= 0.85 then
        behind =
            15.0
    elseif sceneSkill <= 0.50 then
        behind =
            10.0
    end

    local side =
        arrivalCfg.parkSideOffset or -3.5

    targetHeading =
        tonumber(targetHeading) or 0.0

    local headingRad =
        math.rad(targetHeading)
    local forwardX =
        math.sin(headingRad) * -1.0
    local forwardY =
        math.cos(headingRad)
    local rightX =
        math.cos(headingRad)
    local rightY =
        math.sin(headingRad)
    local x =
        targetCoords.x - (forwardX * behind) + (rightX * side)
    local y =
        targetCoords.y - (forwardY * behind) + (rightY * side)
    local z =
        targetCoords.z
    local policeHeading =
        targetHeading + (arrivalCfg.parkAngleOffset or 8.0)

    return vector4(x, y, z, policeHeading)
end

local function ResetSuspectInteraction(patrol)
    if not patrol then
        return
    end

    patrol.suspectInteraction =
        nil
    patrol.interactionStartedAt =
        nil
    patrol.interactionCompleted =
        false
    patrol.compliance =
        nil
    patrol.complianceStartedAt =
        nil
    patrol.complianceCompleted =
        false
    patrol.detainedPed =
        nil
    patrol.suspectPed =
        nil
    patrol.suspectVehicle =
        nil
end

local function RollSuspectCompliance(threatLevel)
    local cfg =
        Config.SuspectCompliance or {}
    local chances =
        cfg.outcomeChance or {}
    local profile =
        chances[threatLevel or "medium"]
        or chances.medium
        or {
            comply = 55,
            refuse = 30,
            flee = 15
        }
    local roll =
        math.random(1, 100)
    local complyLimit =
        tonumber(profile.comply) or 55
    local refuseLimit =
        complyLimit + (tonumber(profile.refuse) or 30)

    if roll <= complyLimit then
        return "comply", roll
    end

    if roll <= refuseLimit then
        return "refuse", roll
    end

    return "flee", roll
end

local function FindSuspectVehicleForPatrol(patrol)
    if not patrol
    or not patrol.pursuit then
        return nil
    end

    local plate =
        patrol.pursuit.plate
    local normalizedPlate =
        plate and tostring(plate):gsub("%s+", "") or nil
    local lastKnown =
        patrol.pursuit.lastKnownCoords
    local bestVehicle =
        nil
    local bestDistance =
        nil
    local bestPlateMatch =
        false
    local vehicles =
        GetGamePool("CVehicle")

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle)
        and vehicle ~= patrol.vehicle then
            local vehiclePlate =
                tostring(GetVehicleNumberPlateText(vehicle) or ""):gsub("%s+", "")
            local matchesPlate =
                normalizedPlate
                and normalizedPlate ~= ""
                and vehiclePlate == normalizedPlate
            local vehicleCoords =
                GetEntityCoords(vehicle)
            local distance =
                999999.0

            if lastKnown
            and lastKnown.x then
                distance =
                    #(vehicleCoords - vector3(lastKnown.x, lastKnown.y, lastKnown.z))
            elseif patrol.vehicle
            and DoesEntityExist(patrol.vehicle) then
                local patrolCoords =
                    GetEntityCoords(patrol.vehicle)

                distance =
                    #(vehicleCoords - patrolCoords)
            end

            local interactionCfg =
                Config.SuspectInteraction or {}

            if matchesPlate
            or distance <= (interactionCfg.vehicleCheckRadius or 30.0) then
                if matchesPlate
                and not bestPlateMatch then
                    bestVehicle =
                        vehicle
                    bestDistance =
                        distance
                    bestPlateMatch =
                        true
                elseif matchesPlate == bestPlateMatch
                and (
                    not bestDistance
                    or distance < bestDistance
                ) then
                    bestVehicle =
                        vehicle
                    bestDistance =
                        distance
                end
            end
        end
    end

    return bestVehicle, bestDistance
end

local function IsVehicleOccupied(vehicle)
    if not vehicle
    or not DoesEntityExist(vehicle) then
        return false
    end

    local driver =
        GetPedInVehicleSeat(vehicle, -1)

    if driver
    and driver ~= 0
    and DoesEntityExist(driver) then
        return true, driver
    end

    local maxPassengers =
        GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = 0, maxPassengers - 1 do
        local ped =
            GetPedInVehicleSeat(vehicle, seat)

        if ped
        and ped ~= 0
        and DoesEntityExist(ped) then
            return true, ped
        end
    end

    return false, nil
end

local function GetPrimarySuspectFromVehicle(vehicle)
    if not vehicle
    or not DoesEntityExist(vehicle) then
        return nil
    end

    local driver =
        GetPedInVehicleSeat(vehicle, -1)

    if driver
    and driver ~= 0
    and DoesEntityExist(driver) then
        return driver
    end

    local maxPassengers =
        GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = 0, maxPassengers - 1 do
        local ped =
            GetPedInVehicleSeat(vehicle, seat)

        if ped
        and ped ~= 0
        and DoesEntityExist(ped) then
            return ped
        end
    end

    return nil
end

local function FaceEntity(ped, targetEntity)
    if not ped
    or not DoesEntityExist(ped) then
        return
    end

    if not targetEntity
    or not DoesEntityExist(targetEntity) then
        return
    end

    TaskTurnPedToFaceEntity(ped, targetEntity, 2000)
end

local function StartOfficerCommandBehavior(patrol, suspectVehicle, occupied)
    if not patrol
    or not patrol.driver
    or not DoesEntityExist(patrol.driver) then
        return
    end

    ClearPedTasks(patrol.driver)

    if suspectVehicle
    and DoesEntityExist(suspectVehicle) then
        FaceEntity(patrol.driver, suspectVehicle)
    end

    if occupied then
        TaskStartScenarioInPlace(patrol.driver, "WORLD_HUMAN_COP_IDLES", 0, true)
    else
        TaskStartScenarioInPlace(patrol.driver, "WORLD_HUMAN_CLIPBOARD", 0, true)
    end
end

local function StartSuspectComplyBehavior(patrol, suspectPed, suspectVehicle)
    if not suspectPed
    or not DoesEntityExist(suspectPed) then
        return false
    end

    patrol.suspectPed =
        suspectPed
    patrol.suspectVehicle =
        suspectVehicle

    ClearPedTasks(suspectPed)

    if suspectVehicle
    and DoesEntityExist(suspectVehicle)
    and IsPedInVehicle(suspectPed, suspectVehicle, false) then
        TaskLeaveVehicle(suspectPed, suspectVehicle, 0)
        Wait(2500)
    end

    if DoesEntityExist(suspectPed) then
        ClearPedTasks(suspectPed)

        local officer =
            patrol.driver

        if officer
        and DoesEntityExist(officer) then
            TaskTurnPedToFaceEntity(suspectPed, officer, 2000)
        end

        TaskHandsUp(
            suspectPed,
            ((Config.SuspectCompliance and Config.SuspectCompliance.complianceDurationSeconds) or 20) * 1000,
            patrol.driver or 0,
            -1,
            true
        )
        SetBlockingOfNonTemporaryEvents(suspectPed, true)

        patrol.detainedPed =
            suspectPed
        patrol.compliance =
            "compliant"
        patrol.complianceStartedAt =
            GetGameTimer()
        patrol.complianceCompleted =
            false
        patrol.interactionCompleted =
            true

        return true
    end

    return false
end

local function StartSuspectRefuseBehavior(patrol, suspectPed, suspectVehicle)
    if not suspectPed
    or not DoesEntityExist(suspectPed) then
        return false
    end

    patrol.suspectPed =
        suspectPed
    patrol.suspectVehicle =
        suspectVehicle
    patrol.compliance =
        "refused"
    patrol.complianceStartedAt =
        GetGameTimer()
    patrol.complianceCompleted =
        false
    patrol.interactionCompleted =
        true

    ClearPedTasks(suspectPed)

    if suspectVehicle
    and DoesEntityExist(suspectVehicle) then
        TaskVehicleTempAction(suspectPed, suspectVehicle, 1, 3000)
    end

    SetBlockingOfNonTemporaryEvents(suspectPed, true)

    return true
end

local function StartSuspectFleeBehavior(patrol, suspectPed, suspectVehicle)
    if not suspectPed
    or not DoesEntityExist(suspectPed) then
        return false
    end

    patrol.suspectPed =
        suspectPed
    patrol.suspectVehicle =
        suspectVehicle
    patrol.compliance =
        "fled"
    patrol.complianceStartedAt =
        GetGameTimer()
    patrol.complianceCompleted =
        true
    patrol.interactionCompleted =
        true

    ClearPedTasks(suspectPed)
    SetBlockingOfNonTemporaryEvents(suspectPed, false)

    if suspectVehicle
    and DoesEntityExist(suspectVehicle) then
        if not IsPedInVehicle(suspectPed, suspectVehicle, false) then
            TaskEnterVehicle(suspectPed, suspectVehicle, 5000, -1, 2.0, 1, 0)
            Wait(2500)
        end

        if IsPedInVehicle(suspectPed, suspectVehicle, false) then
            local fleeCoords =
                GetOffsetFromEntityInWorldCoords(suspectVehicle, 0.0, 200.0, 0.0)

            TaskVehicleDriveToCoordLongrange(
                suspectPed,
                suspectVehicle,
                fleeCoords.x,
                fleeCoords.y,
                fleeCoords.z,
                28.0,
                1074528293,
                10.0
            )
        end
    else
        TaskSmartFleePed(suspectPed, patrol.driver or PlayerPedId(), 150.0, -1, false, false)
    end

    return true
end

local function BeginSuspectInteraction(patrolId, patrol)
    if not Config.SuspectInteraction
    or Config.SuspectInteraction.enabled == false then
        return
    end

    if not patrol
    or patrol.interactionCompleted then
        return
    end

    local suspectVehicle =
        FindSuspectVehicleForPatrol(patrol)

    patrol.interactionStartedAt =
        GetGameTimer()
    patrol.interactionCompleted =
        false

    if not suspectVehicle
    or not DoesEntityExist(suspectVehicle) then
        patrol.suspectInteraction =
            "vehicle_missing"

        TriggerServerEvent("gs_police:server:suspectInteractionStatus", patrolId, "vehicle_missing", {
            incidentId = patrol.assignedIncidentId
        })

        return
    end

    local occupied =
        IsVehicleOccupied(suspectVehicle)

    patrol.suspectVehicle =
        suspectVehicle

    if occupied then
        patrol.suspectInteraction =
            "occupied_vehicle"

        StartOfficerCommandBehavior(patrol, suspectVehicle, true)

        TriggerServerEvent("gs_police:server:suspectInteractionStatus", patrolId, "occupied_vehicle", {
            incidentId = patrol.assignedIncidentId
        })

        TriggerServerEvent("gs_police:server:suspectInteractionStatus", patrolId, "command_stage", {
            incidentId = patrol.assignedIncidentId
        })

        CreateThread(function()
            Wait(((Config.SuspectCompliance and Config.SuspectCompliance.commandDelaySeconds) or 4) * 1000)

            if not Config.SuspectCompliance
            or Config.SuspectCompliance.enabled == false then
                return
            end

            if not patrol
            or patrol.compliance then
                return
            end

            local currentSuspectVehicle =
                patrol.suspectVehicle

            if not currentSuspectVehicle
            or not DoesEntityExist(currentSuspectVehicle) then
                currentSuspectVehicle =
                    FindSuspectVehicleForPatrol(patrol)
            end

            if not currentSuspectVehicle
            or not DoesEntityExist(currentSuspectVehicle) then
                patrol.compliance =
                    "no_suspect"
                patrol.complianceCompleted =
                    true
                patrol.interactionCompleted =
                    true

                TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "no_suspect", {
                    incidentId = patrol.assignedIncidentId
                })

                return
            end

            local suspectPed =
                GetPrimarySuspectFromVehicle(currentSuspectVehicle)

            if not suspectPed
            or not DoesEntityExist(suspectPed) then
                patrol.compliance =
                    "no_suspect"
                patrol.complianceCompleted =
                    true
                patrol.interactionCompleted =
                    true

                TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "no_suspect", {
                    incidentId = patrol.assignedIncidentId
                })

                return
            end

            local threatLevel =
                patrol.pursuit
                and patrol.pursuit.threatLevel
                or "medium"
            local outcome =
                nil
            local roll =
                nil

            if ForcedComplianceOutcome then
                outcome =
                    ForcedComplianceOutcome
                roll =
                    0
                ForcedComplianceOutcome =
                    nil
            else
                outcome, roll =
                    RollSuspectCompliance(threatLevel)
            end

            DebugCompliance("outcome", outcome, "roll", roll, "incident", patrol.assignedIncidentId)

            if outcome == "comply" then
                if StartSuspectComplyBehavior(patrol, suspectPed, currentSuspectVehicle) then
                    TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "compliant", {
                        incidentId = patrol.assignedIncidentId
                    })
                end
            elseif outcome == "refuse" then
                if StartSuspectRefuseBehavior(patrol, suspectPed, currentSuspectVehicle) then
                    TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "refused", {
                        incidentId = patrol.assignedIncidentId
                    })
                end
            elseif outcome == "flee" then
                if StartSuspectFleeBehavior(patrol, suspectPed, currentSuspectVehicle) then
                    TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "fled", {
                        incidentId = patrol.assignedIncidentId
                    })
                end
            end
        end)
    else
        patrol.suspectInteraction =
            "empty_vehicle"

        StartOfficerCommandBehavior(patrol, suspectVehicle, false)

        TriggerServerEvent("gs_police:server:suspectInteractionStatus", patrolId, "empty_vehicle", {
            incidentId = patrol.assignedIncidentId
        })
    end
end

local function GetResponseCodeConfig(responseCode)
    local codeKey =
        nil

    if type(responseCode) == "table" then
        codeKey =
            responseCode.code
    elseif type(responseCode) == "string" then
        codeKey =
            responseCode
    end

    codeKey =
        codeKey or "code1"

    local cfg =
        Config.ResponseCodes or {}

    return codeKey, cfg.codes and cfg.codes[codeKey] or nil
end

local function ShouldShowPoliceBlip()
    if Config.PursuitPressure
    and Config.PursuitPressure.hidePoliceBlipsForNonPolice
    and not Config.PursuitPressure.showDebugBlips then
        return false
    end

    return true
end

local function GetCleanPlate(vehicle)
    if not vehicle
    or not DoesEntityExist(vehicle) then
        return nil
    end

    return string.gsub(GetVehicleNumberPlateText(vehicle) or "", "%s+", "")
end

local function IsPoliceVehicle(vehicle)
    if not vehicle
    or not DoesEntityExist(vehicle) then
        return false
    end

    return GetVehicleClass(vehicle) == 18
end

local function GetClosestNonPoliceVehicle(coords, radius)
    local closestVehicle =
        nil
    local closestDistance =
        radius or 50.0
    local vehicles =
        GetGamePool("CVehicle")

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle)
        and not IsPoliceVehicle(vehicle) then
            local vehicleCoords =
                GetEntityCoords(vehicle)
            local distance =
                #(coords - vehicleCoords)

            if distance <= closestDistance then
                closestVehicle =
                    vehicle
                closestDistance =
                    distance
            end
        end
    end

    return closestVehicle, closestDistance
end

local function ResolveLivePursuitVehicle(pursuit)
    if not pursuit then
        return nil
    end

    if pursuit.netId then
        local netId =
            tonumber(pursuit.netId)

        if netId
        and NetworkDoesNetworkIdExist(netId) then
            local entity =
                NetworkGetEntityFromNetworkId(netId)

            if entity
            and entity ~= 0
            and DoesEntityExist(entity)
            and GetEntityType(entity) == 2 then
                return entity
            end
        end
    end

    if pursuit.plate
    and pursuit.plate ~= "" then
        local targetPlate =
            string.upper(string.gsub(pursuit.plate, "%s+", ""))
        local vehicles =
            GetGamePool("CVehicle")

        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local plate =
                    GetCleanPlate(vehicle)

                if plate
                and string.upper(plate) == targetPlate then
                    return vehicle
                end
            end
        end
    end

    return nil
end

local function ShouldRefreshPursuitTask(pursuit)
    local now =
        GetGameTimer()
    local minRefresh =
        (
            Config.ContinuousPursuit
            and Config.ContinuousPursuit.minTaskRefreshMs
        )
        or 3500

    return now - (pursuit.lastChaseTaskAt or 0) >= minRefresh
end

local function StartOrMaintainDirectChase(patrol, targetVehicle)
    if not patrol
    or not patrol.pursuit then
        return false
    end

    if not patrol.driver
    or not DoesEntityExist(patrol.driver)
    or not patrol.vehicle
    or not DoesEntityExist(patrol.vehicle)
    or not targetVehicle
    or not DoesEntityExist(targetVehicle) then
        return false
    end

    local pursuit =
        patrol.pursuit
    local now =
        GetGameTimer()
    local _, skill =
        GetOfficerSkillProfile(patrol)

    SetDriverAbility(
        patrol.driver,
        math.min(1.0, math.max(0.75, skill and skill.drivingSkill or 0.85))
    )
    SetDriverAggressiveness(
        patrol.driver,
        math.min(1.0, math.max(0.75, skill and skill.pursuitSkill or 0.85))
    )

    if Config.ContinuousPursuit
    and Config.ContinuousPursuit.useTaskVehicleChase == false then
        return false
    end

    if not pursuit.directChaseStarted
    or ShouldRefreshPursuitTask(pursuit) then
        pursuit.lastChaseTaskAt =
            now
        pursuit.directChaseStarted =
            true
        pursuit.controllerMode =
            "direct_chase"

        TaskVehicleChase(patrol.driver, targetVehicle)

        if SetTaskVehicleChaseIdealPursuitDistance then
            pcall(function()
                SetTaskVehicleChaseIdealPursuitDistance(
                    patrol.driver,
                    Config.LivePursuit and Config.LivePursuit.followBehindDistance or 14.0
                )
            end)
        end

        if Config.ContinuousPursuit
        and Config.ContinuousPursuit.debug then
            print("[gs_police:continuous_pursuit] direct chase task set/maintained")
        end
    end

    return true
end

local function ClearLivePursuitStuckState(pursuit, reason, distance, distanceProgress, positionProgress, now)
    pursuit.confirmedStuck = false
    pursuit.stuckCandidateSince = nil
    pursuit.stuckReason = reason
    pursuit.lastStuckCheckDistance = distance
    pursuit.lastStuckCheckAt = now

    if Config.ContinuousPursuit and Config.ContinuousPursuit.debug then
        if reason == "distance_improving" then
            print(("[gs_police:continuous_pursuit] stuck=false reason=distance_improving dist=%.2f progress=%.2f"):format(
                distance or 0.0,
                distanceProgress or 0.0
            ))
        elseif reason == "position_improving" then
            print(("[gs_police:continuous_pursuit] stuck=false reason=position_improving moved=%.2f"):format(
                positionProgress or 0.0
            ))
        end
    end
end

local function UpdateLivePursuitStuckState(patrol, pursuit, patrolCoords, distance, now)
    local pursuitConfig = Config.ContinuousPursuit or {}
    local previousDistance = pursuit.lastStuckCheckDistance
    local previousCoords = pursuit.lastStuckCheckCoords
    local distanceProgress = previousDistance and (previousDistance - distance) or 0.0
    local positionProgress = 0.0

    pursuit.lastStuckCheckAt = now

    if previousCoords then
        positionProgress = #(patrolCoords - vector3(previousCoords.x, previousCoords.y, previousCoords.z))
    end

    if not previousDistance or not previousCoords then
        pursuit.lastStuckCheckCoords = { x = patrolCoords.x, y = patrolCoords.y, z = patrolCoords.z }
        pursuit.lastStuckCheckDistance = distance
        pursuit.stuckReason = "baseline"
        pursuit.confirmedStuck = false
        pursuit.stuckCandidateSince = nil
        return
    end

    if pursuitConfig.ignoreStuckIfDistanceImproving ~= false
    and distanceProgress >= (pursuitConfig.minDistanceProgress or 8.0) then
        pursuit.lastStuckCheckCoords = { x = patrolCoords.x, y = patrolCoords.y, z = patrolCoords.z }
        ClearLivePursuitStuckState(pursuit, "distance_improving", distance, distanceProgress, positionProgress, now)
        return
    end

    if positionProgress >= (pursuitConfig.minPositionProgress or 3.0) then
        pursuit.lastStuckCheckCoords = { x = patrolCoords.x, y = patrolCoords.y, z = patrolCoords.z }
        ClearLivePursuitStuckState(pursuit, "position_improving", distance, distanceProgress, positionProgress, now)
        return
    end

    local policeSpeed = patrol.vehicle and DoesEntityExist(patrol.vehicle) and GetEntitySpeed(patrol.vehicle) or 0.0
    local closeDistance = pursuitConfig.disableHybridWhenCloseDistance or 30.0

    if distance <= closeDistance then
        pursuit.lastStuckCheckDistance = distance
        pursuit.stuckReason = "close_distance"
        pursuit.confirmedStuck = false
        pursuit.stuckCandidateSince = nil
        return
    end

    if policeSpeed > (pursuitConfig.stuckSpeedThreshold or 0.75) then
        pursuit.lastStuckCheckCoords = { x = patrolCoords.x, y = patrolCoords.y, z = patrolCoords.z }
        pursuit.lastStuckCheckDistance = distance
        pursuit.stuckReason = "speed_ok"
        pursuit.confirmedStuck = false
        pursuit.stuckCandidateSince = nil
        return
    end

    pursuit.stuckCandidateSince = pursuit.stuckCandidateSince or now
    pursuit.stuckReason = "no_progress"

    local elapsed = now - pursuit.stuckCandidateSince

    if Config.ContinuousPursuit and Config.ContinuousPursuit.debug then
        print(("[gs_police:continuous_pursuit] stuck=candidate reason=no_progress elapsed=%s"):format(
            tostring(elapsed)
        ))
    end

    if elapsed >= (pursuitConfig.stuckConfirmMs or 6500) then
        pursuit.confirmedStuck = true
        pursuit.stuckReason = "no_progress_confirmed"

        if Config.ContinuousPursuit and Config.ContinuousPursuit.debug then
            print("[gs_police:continuous_pursuit] stuck=true reason=no_progress_confirmed")
        end
    else
        pursuit.confirmedStuck = false
    end
end

local function ApplyResponseCodeToPatrol(patrol, responseCode)
    if not patrol then
        return
    end

    local codeKey, code =
        GetResponseCodeConfig(responseCode)

    patrol.responseCode =
        codeKey
    patrol.responseCodeData =
        code

    if not patrol.vehicle
    or not DoesEntityExist(patrol.vehicle)
    or not code then
        return
    end

    if code.lights then
        SetVehicleSiren(patrol.vehicle, true)
        SetVehicleHasMutedSirens(patrol.vehicle, code.mutedSiren == true)
    else
        SetVehicleSiren(patrol.vehicle, false)
        SetVehicleHasMutedSirens(patrol.vehicle, true)
    end

    patrol.emergencyResponse =
        (code.urgency or 1) >= 2
    patrol.code3Response =
        codeKey == "code3"
end

local function GetResponseSpeedForPatrol(patrol, responseCode)
    local codeKey, code =
        GetResponseCodeConfig(responseCode or (patrol and patrol.responseCode) or "code1")
    local _, skill =
        GetOfficerSkillProfile(patrol)
    local baseSpeed =
        code and code.driveSpeed or 22.0
    local multiplier =
        skill and skill.driveSpeedMultiplier or 1.0
    local speed =
        baseSpeed * multiplier

    if codeKey == "code1" then
        return math.min(speed, 28.0)
    end

    if codeKey == "code2" then
        return math.min(speed, 38.0)
    end

    if codeKey == "code3" then
        if Config.ContinuousPursuit
        and Config.ContinuousPursuit.removePursuitSpeedCaps
        and patrol
        and patrol.mode == "pursuit" then
            return math.min(
                speed,
                Config.ContinuousPursuit.maxConfiguredPursuitSpeed or 75.0
            )
        end

        return math.min(speed, 60.0)
    end

    return speed
end

local function GetPatrolDriveSettings(patrol, fallbackSpeed, fallbackStyle)
    local codeKey, code =
        GetResponseCodeConfig(patrol and patrol.responseCode)

    if code then
        return GetResponseSpeedForPatrol(patrol, codeKey), code.drivingStyle or fallbackStyle
    end

    return ApplyOfficerSkillToSpeed(patrol, fallbackSpeed, false), fallbackStyle
end

local function EncourageTrafficMoveOver(policeVehicle, patrol)
    if not Config.EmergencyDriving
    or Config.EmergencyDriving.moveOverEnabled == false then
        return
    end

    if not policeVehicle
    or not DoesEntityExist(policeVehicle) then
        return
    end

    local now =
        GetGameTimer()

    if now - LastMoveOverAt < (Config.EmergencyDriving.moveOverCooldownMs or 2500) then
        return
    end

    LastMoveOverAt =
        now

    local policeCoords =
        GetEntityCoords(policeVehicle)
    local radius =
        Config.EmergencyDriving.moveOverRadius or 40.0
    local shouldYield =
        true

    if patrol and patrol.responseCode then
        local _, code =
            GetResponseCodeConfig(patrol.responseCode)

        if code then
            shouldYield =
                code.trafficYield == true
            radius =
                code.trafficYieldRadius or radius
        end
    end

    if not shouldYield then
        return
    end

    local vehicles =
        GetGamePool("CVehicle")

    for _, vehicle in ipairs(vehicles) do
        if vehicle ~= policeVehicle
        and DoesEntityExist(vehicle) then
            local driver =
                GetPedInVehicleSeat(vehicle, -1)

            if driver
            and driver ~= 0
            and DoesEntityExist(driver)
            and not IsPedAPlayer(driver) then
                local vehicleCoords =
                    GetEntityCoords(vehicle)
                local distance =
                    #(policeCoords - vehicleCoords)

                if distance <= radius then
                    local moveTo =
                        GetEntityForwardOffset(vehicle, 14.0, 9.0)

                    TaskVehicleDriveToCoordLongrange(
                        driver,
                        vehicle,
                        moveTo.x,
                        moveTo.y,
                        moveTo.z,
                        14.0,
                        786603,
                        10.0
                    )
                end
            end
        end
    end
end

local function EmergencyDriveToCoords(patrol, coords)
    if not patrol
    or not patrol.driver
    or not patrol.vehicle
    or not coords then
        return
    end

    if not DoesEntityExist(patrol.driver)
    or not DoesEntityExist(patrol.vehicle) then
        return
    end

    if Config.ContinuousPursuit
    and Config.ContinuousPursuit.gateEmergencyRepathUntilConfirmedStuck ~= false
    and patrol.mode == "pursuit"
    and patrol.pursuit
    and patrol.pursuit.usingLiveChase == true
    and patrol.pursuit.confirmedStuck ~= true then
        local now =
            GetGameTimer()

        if now - LastEmergencyRepathSkipLogAt >= 5000 then
            print("[gs_police:emergency_driving] repath skipped: pursuit not confirmed stuck")
            LastEmergencyRepathSkipLogAt =
                now
        end

        return false
    end

    local speed =
        (
            Config.EmergencyDriving
            and Config.EmergencyDriving.driveSpeed
        )
        or (
            Config.Pursuit
            and Config.Pursuit.driveSpeed
        )
        or (
            Config.PatrolDispatch
            and Config.PatrolDispatch.driveSpeed
        )
        or 32.0
    local style =
        (
            Config.EmergencyDriving
            and Config.EmergencyDriving.drivingStyle
        )
        or (
            Config.Pursuit
            and Config.Pursuit.drivingStyle
        )
        or (
            Config.PatrolDispatch
            and Config.PatrolDispatch.drivingStyle
        )
        or 1074528293

    speed, style =
        GetPatrolDriveSettings(patrol, speed, style)

    TaskVehicleDriveToCoordLongrange(
        patrol.driver,
        patrol.vehicle,
        coords.x,
        coords.y,
        coords.z,
        speed,
        style,
        10.0
    )

    EncourageTrafficMoveOver(patrol.vehicle, patrol)

    return true
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
        responseCode = patrol.responseCode,
        code3Response = patrol.code3Response,
        skillProfile = patrol.skillProfile,
        skillLabel = patrol.skillLabel,
        drivingSkill = patrol.drivingSkill,
        pursuitSkill = patrol.pursuitSkill,
        scenePositioning = patrol.scenePositioning,
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
    patrol.pursuit =
        nil
    patrol.lastEmergencyRepath =
        0
    patrol.lastStuckCheck =
        0
    patrol.stuckSince =
        nil
    patrol.lastKnownSpeed =
        0.0
    patrol.repathAttempts =
        0
    patrol.felonyStopFinalized =
        false
    ResetSuspectInteraction(patrol)

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
        patrol.pursuit =
            nil
        patrol.lastEmergencyRepath =
            0
        patrol.lastStuckCheck =
            0
        patrol.stuckSince =
            nil
        patrol.lastKnownSpeed =
            0.0
        patrol.repathAttempts =
            0
        patrol.felonyStopFinalized =
            false
        ResetSuspectInteraction(patrol)
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
    print(("[gs_police:ai_patrol] SpawnPatrolUnit called zone=%s"):format(tostring(zoneKey)))

    local cfg =
        Config.AIPatrol or {}

    if cfg.enabled == false then
        print("[gs_police:ai_patrol] spawn failed: disabled", zoneKey)
        return false, "disabled"
    end

    local zone =
        cfg.zones and cfg.zones[zoneKey]

    if not zone then
        print("[gs_police:ai_patrol] spawn failed: invalidZone", zoneKey)
        return false, "invalidZone"
    end

    if zone.enabled == false then
        print("[gs_police:ai_patrol] spawn failed: zoneDisabled", zoneKey)
        return false, "zoneDisabled"
    end

    if CountActivePatrols() >= (cfg.maxActivePatrols or 4) then
        print("[gs_police:ai_patrol] spawn failed: maxUnits", zoneKey)
        return false, "maxUnits"
    end

    if CountZonePatrols(zoneKey) >= (zone.maxUnits or 1) then
        print("[gs_police:ai_patrol] spawn failed: zoneMaxUnits", zoneKey)
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
        print("[gs_police:ai_patrol] spawn failed: spawnFailed", zoneKey)
        return false, "spawnFailed"
    end

    local spawn =
        zone.spawn

    if not spawn then
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        print("[gs_police:ai_patrol] spawn failed: spawnFailed", zoneKey)
        return false, "spawnFailed"
    end

    local vehicle =
        CreateVehicle(vehicleHash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        print("[gs_police:ai_patrol] spawn failed: spawnFailed", zoneKey)
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
        print("[gs_police:ai_patrol] spawn failed: spawnFailed", zoneKey)
        return false, "spawnFailed"
    end

    SetPedAsCop(driver, true)
    SetPedKeepTask(driver, true)
    SetBlockingOfNonTemporaryEvents(driver, true)

    local patrolId =
        ("PATROL-%s-%s"):format(zoneKey, GetGameTimer())
    local skillProfile =
        zone.skillProfile
        or (
            Config.OfficerSkill
            and Config.OfficerSkill.defaultProfile
        )
        or "patrol_trained"
    local skillProfileKey, skill =
        GetOfficerSkillProfile({
            skillProfile = skillProfile
        })

    ActivePatrols[patrolId] = {
        patrolId = patrolId,
        zoneKey = zoneKey,
        zoneLabel = zone.label or zoneKey,
        vehicle = vehicle,
        driver = driver,
        skillProfile = skillProfileKey,
        skillLabel = skill and skill.label or skillProfileKey,
        drivingSkill = skill and skill.drivingSkill or 0.70,
        pursuitSkill = skill and skill.pursuitSkill or 0.70,
        scenePositioning = skill and skill.scenePositioning or 0.70,
        officerReadiness = BuildOfficerReadiness(skill),
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
        responseCode = "code1",
        responseCodeData = nil,
        code3Response = false,
        pursuit = nil,
        lastEmergencyRepath = 0,
        lastStuckCheck = 0,
        stuckSince = nil,
        lastKnownSpeed = 0.0,
        repathAttempts = 0,
        felonyStopFinalized = false,
        suspectInteraction = nil,
        interactionStartedAt = nil,
        interactionCompleted = false,
        compliance = nil,
        complianceStartedAt = nil,
        complianceCompleted = false,
        detainedPed = nil,
        suspectPed = nil,
        suspectVehicle = nil,
        spawnedAt = GetGameTimer(),
        lastWaypointAt = GetGameTimer()
    }

    print(("[gs_police:ai_patrol] patrol stored id=%s activeCount=%s"):format(
        tostring(patrolId),
        tostring(CountActivePatrols())
    ))

    TriggerServerEvent("gs_police:server:registerClientPatrol", patrolId, {
        zoneKey = ActivePatrols[patrolId].zoneKey,
        zoneLabel = ActivePatrols[patrolId].zoneLabel,
        status = ActivePatrols[patrolId].status,
        mode = ActivePatrols[patrolId].mode,
        coords = GetPatrolCoords(ActivePatrols[patrolId])
    })

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
        if Config.CityBrainPatrolPressureTuningEnabled then
            RefreshCityBrainPatrolPressureCache()
            Wait(15000)
        else
            CityBrainPatrolPressureCache =
                {}
            Wait(5000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(GetCityBrainPatrolLoopWaitMs())

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

                    if IsEmergencyDrivingActive(patrol)
                    and IsEmergencyMode(patrol.mode)
                    and patrol.vehicle
                    and DoesEntityExist(patrol.vehicle) then
                        local now =
                            GetGameTimer()
                        local stuckCfg =
                            (
                                Config.PursuitTuning
                                and Config.PursuitTuning.stuck
                            )
                            or {}

                        EncourageTrafficMoveOver(patrol.vehicle, patrol)

                        if stuckCfg.enabled ~= false
                        and now - (patrol.lastStuckCheck or 0) >= (stuckCfg.checkIntervalMs or Config.EmergencyDriving.stuckCheckIntervalMs or 3000) then
                            patrol.lastStuckCheck =
                                now

                            local speed =
                                GetEntitySpeed(patrol.vehicle)

                            patrol.lastKnownSpeed =
                                speed

                            if speed <= (stuckCfg.minSpeed or Config.EmergencyDriving.stuckSpeedThreshold or 1.0) then
                                patrol.stuckSince =
                                    patrol.stuckSince or now
                            else
                                patrol.stuckSince =
                                    nil
                            end
                        end

                        local repathMultiplier =
                            GetSkillRepathMultiplier(patrol)
                        local stuckAfterMs =
                            ((stuckCfg.stuckAfterSeconds or Config.EmergencyDriving.stuckSecondsBeforeRepath or 6) * 1000) * repathMultiplier
                        local repathInterval =
                            (Config.EmergencyDriving.repathIntervalMs or 2500) * repathMultiplier

                        if patrol.stuckSince
                        and now - patrol.stuckSince >= stuckAfterMs
                        and now - (patrol.lastEmergencyRepath or 0) >= repathInterval
                        and ((patrol.repathAttempts or 0) < (stuckCfg.maxRepathAttempts or 5)) then
                            patrol.lastEmergencyRepath =
                                now
                            patrol.stuckSince =
                                nil
                            patrol.repathAttempts =
                                (patrol.repathAttempts or 0) + 1

                            local offset =
                                stuckCfg.repathSideOffset or Config.EmergencyDriving.overtakeOffsetDistance or 8.0
                            local forward =
                                stuckCfg.repathForwardDistance or Config.EmergencyDriving.overtakeForwardDistance or 35.0
                            local _, skill =
                                GetOfficerSkillProfile(patrol)
                            local trafficSkill =
                                skill and skill.trafficNavigation or 0.70

                            if trafficSkill >= 0.80 then
                                offset =
                                    offset + 2.0
                                forward =
                                    forward + 8.0
                            elseif trafficSkill <= 0.50 then
                                offset =
                                    math.max(5.0, offset - 2.0)
                                forward =
                                    math.max(24.0, forward - 8.0)
                            end

                            local bypass =
                                GetEntityForwardOffset(patrol.vehicle, forward, offset)

                            local repathStarted =
                                EmergencyDriveToCoords(patrol, bypass)

                            if repathStarted ~= false
                            and patrol.mode == "pursuit"
                            and patrol.pursuit
                            and patrol.pursuit.usingLiveChase then
                                CreateThread(function()
                                    Wait(1500)

                                    if patrol.mode == "pursuit"
                                    and patrol.pursuit
                                    and patrol.pursuit.targetVehicle
                                    and DoesEntityExist(patrol.pursuit.targetVehicle) then
                                        patrol.pursuit.directChaseStarted =
                                            false
                                        StartOrMaintainDirectChase(patrol, patrol.pursuit.targetVehicle)
                                    end
                                end)
                            end

                            if repathStarted ~= false
                            and Config.EmergencyDriving.debug then
                                print("[gs_police:emergency_driving] emergency repath/bypass attempted")
                            end
                        end
                    end

                    if patrol.mode == "pursuit"
                    and patrol.pursuit then
                        local pursuit =
                            patrol.pursuit
                        local now =
                            GetGameTimer()
                        local maxPursuitMs =
                            ((Config.Pursuit and Config.Pursuit.maxPursuitSeconds) or 300) * 1000
                        local routeUpdateInterval =
                            (
                                Config.PursuitTuning
                                and Config.PursuitTuning.routeUpdateIntervalMs
                            )
                            or (
                                Config.Pursuit
                                and Config.Pursuit.updateRouteIntervalMs
                            )
                            or 2000
                        routeUpdateInterval =
                            routeUpdateInterval * GetSkillRepathMultiplier(patrol)

                        SendPatrolStatus(patrolId, patrol, "pursuit_active")

                        if Config.LivePursuit
                        and Config.LivePursuit.enabled ~= false
                        and Config.LivePursuit.preferEntityChase ~= false then
                            pursuit.lastLiveChaseUpdate =
                                now

                            local targetVehicle =
                                ResolveLivePursuitVehicle(pursuit)

                            if targetVehicle
                            and DoesEntityExist(targetVehicle) then
                                pursuit.targetVehicle =
                                    targetVehicle
                                pursuit.targetVehicleExists =
                                    true
                                pursuit.usingLiveChase =
                                    true
                                pursuit.lastEntitySeenAt =
                                    now

                                local targetCoords =
                                    GetEntityCoords(targetVehicle)
                                local targetSpeed =
                                    GetEntitySpeed(targetVehicle)
                                local patrolCoords =
                                    GetEntityCoords(patrol.vehicle)
                                local distance =
                                    #(patrolCoords - targetCoords)

                                UpdateLivePursuitStuckState(patrol, pursuit, patrolCoords, distance, now)

                                pursuit.lastKnownCoords = {
                                    x = targetCoords.x,
                                    y = targetCoords.y,
                                    z = targetCoords.z
                                }
                                pursuit.speed =
                                    targetSpeed
                                pursuit.lastDistance =
                                    distance
                                pursuit.heading =
                                    GetEntityHeading(targetVehicle)
                                pursuit.targetEntityLastSeen =
                                    now
                                pursuit.targetEntityLostAt =
                                    nil

                                if targetSpeed >= (
                                    (
                                        Config.ContinuousPursuit
                                        and Config.ContinuousPursuit.resumeSpeedThreshold
                                    )
                                    or 1.0
                                ) then
                                    pursuit.targetStoppedSince =
                                        nil
                                    pursuit.stopCandidateSince =
                                        nil
                                    pursuit.felonyStopStarted =
                                        false
                                    pursuit.felonyStopStaged =
                                        false
                                    patrol.felonyStopFinalized =
                                        false

                                    if patrol.mode ~= "pursuit" then
                                        patrol.mode =
                                            "pursuit"
                                        patrol.status =
                                            "pursuit_active"
                                    end
                                end

                                StartOrMaintainDirectChase(patrol, targetVehicle)

                                local closeEnough =
                                    distance <= (
                                        (
                                            Config.ContinuousPursuit
                                            and Config.ContinuousPursuit.felonyStopTriggerDistance
                                        )
                                        or 25.0
                                    )
                                local targetStopped =
                                    targetSpeed <= (
                                        (
                                            Config.ContinuousPursuit
                                            and Config.ContinuousPursuit.felonyStopSpeedThreshold
                                        )
                                        or 0.6
                                    )
                                local tooFarToStop =
                                    distance > (
                                        (
                                            Config.ContinuousPursuit
                                            and Config.ContinuousPursuit.neverStopIfDistanceGreaterThan
                                        )
                                        or 35.0
                                    )

                                if closeEnough
                                and targetStopped
                                and not tooFarToStop then
                                    pursuit.stopCandidateSince =
                                        pursuit.stopCandidateSince or now
                                    pursuit.targetStoppedSince =
                                        pursuit.stopCandidateSince
                                    local stopElapsed =
                                        now - pursuit.stopCandidateSince

                                    if Config.ContinuousPursuit
                                    and Config.ContinuousPursuit.debug then
                                        print(("[gs_police:pursuit_stop] candidate dist=%.2f targetSpeed=%.2f elapsed=%s"):format(
                                            distance or 0.0,
                                            targetSpeed or 0.0,
                                            tostring(stopElapsed)
                                        ))
                                    end

                                    local felonyStopHoldMs =
                                        (
                                            (
                                                Config.ContinuousPursuit
                                                and Config.ContinuousPursuit.felonyStopHoldSeconds
                                            )
                                            or 5
                                        ) * 1000
                                    felonyStopHoldMs =
                                        ApplyCityBrainFelonySensitivity(patrol, felonyStopHoldMs)

                                    if stopElapsed >= felonyStopHoldMs then
                                        patrol.mode =
                                            "felony_stop"
                                        patrol.status =
                                            "felony_stop"
                                        pursuit.felonyStopStarted =
                                            true
                                        pursuit.targetHeading =
                                            pursuit.heading or 0.0
                                        pursuit.controllerMode =
                                            "felony_stop"

                                        ClearPedTasks(patrol.driver)
                                        TaskVehicleTempAction(patrol.driver, patrol.vehicle, 27, 1500)

                                        print(("[gs_police:pursuit_stop] felony stop triggered incident=%s plate=%s"):format(
                                            tostring(patrol.assignedIncidentId),
                                            tostring(pursuit.plate)
                                        ))

                                        TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "felony_stop", {
                                            incidentId = patrol.assignedIncidentId
                                        })
                                    end
                                else
                                    pursuit.stopCandidateSince =
                                        nil
                                    pursuit.targetStoppedSince =
                                        nil
                                end

                                local shouldUseHybrid =
                                    false

                        if Config.ContinuousPursuit
                        and Config.ContinuousPursuit.hybridOnlyWhenStuck then
                            shouldUseHybrid =
                                pursuit.confirmedStuck == true
                        else
                            shouldUseHybrid =
                                Config.LivePursuit
                                        and Config.LivePursuit.useHybridFollow == true
                                end

                                if shouldUseHybrid
                                and patrol.driver
                                and DoesEntityExist(patrol.driver)
                                and patrol.vehicle
                                and DoesEntityExist(patrol.vehicle)
                                and distance > (Config.LivePursuit.closeDistance or 18.0)
                                and now - (pursuit.lastHybridTaskAt or 0) >= 1500 then
                                    pursuit.lastHybridTaskAt =
                                        now
                                    pursuit.controllerMode =
                                        "hybrid_stuck"

                                    local followDistance =
                                        Config.LivePursuit.followBehindDistance or 14.0
                                    local sideOffset =
                                        Config.LivePursuit.followSideOffset or 0.0
                                    local followCoords =
                                        GetOffsetFromEntityInWorldCoords(targetVehicle, sideOffset, -followDistance, 0.0)
                                    local driveSpeed, drivingStyle =
                                        GetPatrolDriveSettings(
                                            patrol,
                                            (
                                                Config.ContinuousPursuit
                                                and Config.ContinuousPursuit.basePursuitSpeed
                                            )
                                            or 55.0,
                                            1074528293
                                        )
                                    driveSpeed =
                                        ApplyContinuousPursuitSpeed(patrol, driveSpeed)

                                    TaskVehicleDriveToCoordLongrange(
                                        patrol.driver,
                                        patrol.vehicle,
                                        followCoords.x,
                                        followCoords.y,
                                        followCoords.z,
                                        driveSpeed,
                                        drivingStyle,
                                        followDistance
                                    )

                                    CreateThread(function()
                                        Wait(1500)

                                        if patrol.mode == "pursuit"
                                        and patrol.pursuit
                                        and patrol.pursuit.targetVehicle
                                        and DoesEntityExist(patrol.pursuit.targetVehicle) then
                                            patrol.pursuit.directChaseStarted =
                                                false
                                            StartOrMaintainDirectChase(patrol, patrol.pursuit.targetVehicle)
                                        end
                                    end)
                                end

                                if Config.LivePursuit.debug then
                                    print(("[gs_police:live_pursuit] live chase plate=%s controller=%s dist=%.2f speed=%.2f"):format(
                                        tostring(pursuit.plate),
                                        tostring(pursuit.controllerMode),
                                        distance,
                                        targetSpeed
                                    ))
                                end
                            else
                                pursuit.targetVehicleExists =
                                    false
                                pursuit.usingLiveChase =
                                    false
                                pursuit.controllerMode =
                                    "lost_grace"
                                pursuit.targetEntityLostAt =
                                    pursuit.targetEntityLostAt or now

                                if not pursuit.lastEntitySeenAt then
                                    pursuit.lastEntitySeenAt =
                                        now
                                end
                            end
                        end

                        local targetLostGraceMs =
                            (
                                Config.ContinuousPursuit
                                and Config.ContinuousPursuit.targetLostGraceMs
                            )
                            or 2500
                        local targetLostLongEnough =
                            not pursuit.targetVehicleExists
                            and now - (pursuit.lastEntitySeenAt or 0) >= targetLostGraceMs

                        if pursuit.targetVehicleExists then
                            pursuit.controllerMode =
                                pursuit.controllerMode or "direct_chase"
                        elseif not targetLostLongEnough then
                            pursuit.controllerMode =
                                "lost_grace"
                        end

                        if pursuit.startedAt
                        and now - pursuit.startedAt >= maxPursuitMs then
                            ReturnPatrolToRoute(patrolId)
                        else
                            local canUseLastKnownFallback =
                                targetLostLongEnough

                            if not Config.LivePursuit
                            or Config.LivePursuit.enabled == false
                            or Config.LivePursuit.preferEntityChase == false then
                                canUseLastKnownFallback =
                                    true
                            end

                            if Config.LivePursuit
                            and Config.LivePursuit.disableLastKnownRoutingWhenEntityExists
                            and pursuit.targetVehicleExists then
                                canUseLastKnownFallback =
                                    false
                            end

                            if Config.LivePursuit
                            and pursuit.targetEntityLostAt
                            and now - pursuit.targetEntityLostAt < (Config.LivePursuit.entityLostFallbackMs or 1200) then
                                canUseLastKnownFallback =
                                    false
                            end

                            if canUseLastKnownFallback
                            and now - (pursuit.lastRouteUpdate or 0) >= routeUpdateInterval then
                                pursuit.controllerMode =
                                    "last_known_fallback"
                                pursuit.lastRouteUpdate =
                                    now

                                RequestMovingTargetSnapshot(pursuit.targetId)
                                Wait(100)

                                local snapshot =
                                    PendingTargetSnapshots[tonumber(pursuit.targetId)]

                                if snapshot
                                and snapshot.lastKnownCoords then
                                    pursuit.lastKnownCoords =
                                        snapshot.lastKnownCoords
                                    pursuit.speed =
                                        tonumber(snapshot.speed) or 0.0
                                    pursuit.heading =
                                        tonumber(snapshot.heading) or pursuit.heading or 0.0
                                    pursuit.updatedAt =
                                        snapshot.updatedAt

                                    local targetCoords =
                                        snapshot.lastKnownCoords
                                    local targetVector =
                                        ToVector3(targetCoords)

                                    if not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
                                        TaskEnterVehicle(patrol.driver, patrol.vehicle, 8000, -1, 1.0, 1, 0)
                                        Wait(1500)
                                    end

                                    ApplyResponseCodeToPatrol(patrol, patrol.responseCode or "code3")

                                    if targetVector
                                    and patrol.vehicle
                                    and DoesEntityExist(patrol.vehicle) then
                                        local patrolCoords =
                                            GetEntityCoords(patrol.vehicle)
                                        local distance =
                                            #(patrolCoords - targetVector)
                                        local driveSpeed, drivingStyle =
                                            GetPursuitSpeedForDistance(distance)
                                        driveSpeed, drivingStyle =
                                            GetPatrolDriveSettings(patrol, driveSpeed, drivingStyle)
                                        driveSpeed =
                                            ApplyPursuitSkillToSpeed(patrol, driveSpeed)
                                        local stoppedSpeedMph =
                                            ((Config.Pursuit and Config.Pursuit.targetStoppedSpeedMps) or 0.8) * 2.236936
                                        local arrivalCfg =
                                            Config.PursuitTuning
                                            and Config.PursuitTuning.arrival
                                            or {}
                                        local felonyCfg =
                                            Config.PursuitTuning
                                            and Config.PursuitTuning.felonyStop
                                            or {}
                                        local triggerDistance =
                                            felonyCfg.triggerDistance or 35.0
                                        local targetSpeed =
                                            tonumber(snapshot.speed) or 999.0
                                        local targetFresh =
                                            IsTargetSnapshotFresh(snapshot)

                                        pursuit.lastDistance =
                                            distance

                                        local patrolCloseEnough =
                                            distance <= triggerDistance
                                        local canConsiderFelonyStop =
                                            targetFresh
                                            and targetSpeed <= stoppedSpeedMph
                                            and (
                                                felonyCfg.requireCloseDistance == false
                                                or patrolCloseEnough
                                            )

                                        if canConsiderFelonyStop then
                                            pursuit.targetStoppedSince =
                                                pursuit.targetStoppedSince or now
                                        else
                                            pursuit.targetStoppedSince =
                                                nil
                                        end

                                        if not canConsiderFelonyStop
                                        or distance > (arrivalCfg.arrivalDistance or 18.0) then
                                            local followDistance =
                                                GetSkillFollowDistance(patrol, (
                                                    Config.PursuitTuning
                                                    and Config.PursuitTuning.followDistance
                                                )
                                                or (
                                                    Config.Pursuit
                                                    and Config.Pursuit.followDistance
                                                )
                                                or 22.0)

                                            TaskVehicleDriveToCoordLongrange(
                                                patrol.driver,
                                                patrol.vehicle,
                                                targetVector.x,
                                                targetVector.y,
                                                targetVector.z,
                                                driveSpeed,
                                                drivingStyle,
                                                followDistance
                                            )

                                            if IsEmergencyDrivingActive(patrol) then
                                                EncourageTrafficMoveOver(patrol.vehicle, patrol)
                                            end
                                        end

                                        if pursuit.targetStoppedSince then
                                            local stoppedSeconds =
                                                (Config.Pursuit and Config.Pursuit.targetStoppedSeconds) or 6

                                            local stoppedMs =
                                                ApplyCityBrainFelonySensitivity(patrol, stoppedSeconds * 1000)

                                            if now - pursuit.targetStoppedSince >= stoppedMs then
                                                patrol.mode =
                                                    "felony_stop"
                                                patrol.status =
                                                    "felony_stop"
                                                pursuit.felonyStopStarted =
                                                    true
                                                pursuit.targetHeading =
                                                    tonumber(snapshot.heading) or pursuit.heading or 0.0
                                                pursuit.lastKnownCoords =
                                                    snapshot.lastKnownCoords

                                                TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "felony_stop", {
                                                    incidentId = patrol.assignedIncidentId
                                                })
                                            end
                                        end
                                    end
                                else
                                    patrol.status =
                                        "pursuit_lost"

                                    TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "pursuit_lost", {
                                        incidentId = patrol.assignedIncidentId
                                    })
                                end
                            end
                        end
                    elseif patrol.mode == "felony_stop"
                    and patrol.pursuit then
                        local pursuit =
                            patrol.pursuit
                        local targetVector =
                            ToVector3(pursuit.lastKnownCoords)

                        if targetVector then
                            local arrivalCfg =
                                Config.PursuitTuning
                                and Config.PursuitTuning.arrival
                                or {}
                            local felonyCfg =
                                Config.PursuitTuning
                                and Config.PursuitTuning.felonyStop
                                or {}
                            local parking =
                                GetFelonyStopParkingPoint(
                                    targetVector,
                                    pursuit.targetHeading or pursuit.heading or 0.0,
                                    patrol
                                )
                            local vehicleCoords =
                                GetEntityCoords(patrol.vehicle)
                            local parkingVector =
                                vector3(parking.x, parking.y, parking.z)
                            local distance =
                                #(vehicleCoords - parkingVector)

                            local finalParkingDistance =
                                GetSkillFelonyParkingDistance(patrol, felonyCfg.finalParkingDistance or arrivalCfg.finalStopDistance or 12.0)

                            if distance > finalParkingDistance then
                                TaskVehicleDriveToCoordLongrange(
                                    patrol.driver,
                                    patrol.vehicle,
                                    parking.x,
                                    parking.y,
                                    parking.z,
                                    10.0,
                                    (
                                        Config.PursuitTuning
                                        and Config.PursuitTuning.closeDrivingStyle
                                    )
                                    or 786603,
                                    8.0
                                )
                            elseif not patrol.felonyStopFinalized then
                                patrol.felonyStopFinalized =
                                    true
                                pursuit.felonyStopStaged =
                                    true

                                if patrol.vehicle
                                and DoesEntityExist(patrol.vehicle) then
                                    SetVehicleSiren(patrol.vehicle, arrivalCfg.keepLightsOn ~= false)
                                    SetVehicleHasMutedSirens(patrol.vehicle, arrivalCfg.muteSiren ~= false)
                                    SetEntityHeading(patrol.vehicle, parking.w)
                                end

                                TaskVehicleTempAction(
                                    patrol.driver,
                                    patrol.vehicle,
                                    27,
                                    arrivalCfg.useTempBrakeMs or 2500
                                )

                                Wait(1500)

                                if patrol.driver
                                and DoesEntityExist(patrol.driver) then
                                    TaskLeaveVehicle(patrol.driver, patrol.vehicle, 0)
                                end

                                Wait(2000)

                                if patrol.driver
                                and DoesEntityExist(patrol.driver) then
                                    ClearPedTasks(patrol.driver)
                                    TaskStartScenarioInPlace(patrol.driver, "WORLD_HUMAN_COP_IDLES", 0, true)
                                end

                                patrol.mode =
                                    "on_scene"
                                patrol.status =
                                    "felony_stop"
                                patrol.onScene =
                                    true
                                patrol.returnAfter =
                                    GetGameTimer() + (((Config.PatrolDispatch and Config.PatrolDispatch.scene and Config.PatrolDispatch.scene.autoReturnAfterSeconds) or 60) * 1000)

                                TriggerServerEvent("gs_police:server:patrolStatus", patrolId, {
                                    zoneKey = patrol.zoneKey,
                                    zoneLabel = patrol.zoneLabel,
                                    status = "felony_stop",
                                    mode = "on_scene",
                                    assignedIncidentId = patrol.assignedIncidentId,
                                    coords = GetPatrolCoords(patrol)
                                })

                                TriggerServerEvent("gs_police:server:patrolDispatchStatus", patrolId, "felony_stop", {
                                    incidentId = patrol.assignedIncidentId
                                })

                                BeginSuspectInteraction(patrolId, patrol)
                            else
                                SendPatrolStatus(patrolId, patrol, "felony_stop")
                            end
                        end
                    elseif patrol.mode == "responding"
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

                        if patrol.compliance == "compliant"
                        and patrol.complianceStartedAt
                        and not patrol.complianceCompleted then
                            local duration =
                                Config.SuspectCompliance
                                and Config.SuspectCompliance.complianceDurationSeconds
                                or 20

                            if GetGameTimer() - patrol.complianceStartedAt >= (duration * 1000) then
                                patrol.compliance =
                                    "detained"
                                patrol.complianceCompleted =
                                    true

                                if patrol.detainedPed
                                and DoesEntityExist(patrol.detainedPed) then
                                    ClearPedTasks(patrol.detainedPed)
                                    TaskStartScenarioInPlace(patrol.detainedPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
                                    SetBlockingOfNonTemporaryEvents(patrol.detainedPed, true)
                                end

                                TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "detained", {
                                    incidentId = patrol.assignedIncidentId
                                })

                                if not Config.SuspectCompliance
                                or Config.SuspectCompliance.autoReturnAfterDetention ~= false then
                                    CreateThread(function()
                                        Wait(((Config.SuspectCompliance and Config.SuspectCompliance.detainedHoldSeconds) or 30) * 1000)
                                        ReturnPatrolToRoute(patrolId)
                                    end)
                                end
                            else
                                SendPatrolStatus(patrolId, patrol, "suspect_compliant")
                            end
                        elseif patrol.compliance == "refused"
                        and patrol.complianceStartedAt
                        and not patrol.complianceCompleted then
                            local duration =
                                Config.SuspectCompliance
                                and Config.SuspectCompliance.commandDelaySeconds
                                or 4

                            if GetGameTimer() - patrol.complianceStartedAt >= (duration * 1000) then
                                patrol.complianceCompleted =
                                    true

                                TriggerServerEvent("gs_police:server:suspectComplianceStatus", patrolId, "refused", {
                                    incidentId = patrol.assignedIncidentId
                                })
                            else
                                SendPatrolStatus(patrolId, patrol, "suspect_refused")
                            end
                        elseif patrol.suspectInteraction
                        and patrol.interactionStartedAt
                        and not patrol.interactionCompleted then
                            local duration =
                                Config.SuspectInteraction
                                and Config.SuspectInteraction.commandDurationSeconds
                                or 20

                            if patrol.suspectInteraction == "empty_vehicle" then
                                duration =
                                    Config.SuspectInteraction
                                    and Config.SuspectInteraction.emptyVehicleInvestigateSeconds
                                    or 20
                            end

                            if GetGameTimer() - patrol.interactionStartedAt >= (duration * 1000) then
                                patrol.interactionCompleted =
                                    true
                                patrol.suspectInteraction =
                                    "holding_position"

                                TriggerServerEvent("gs_police:server:suspectInteractionStatus", patrolId, "holding_position", {
                                    incidentId = patrol.assignedIncidentId
                                })

                                if not Config.SuspectInteraction
                                or Config.SuspectInteraction.autoReturnAfterInteraction ~= false then
                                    ReturnPatrolToRoute(patrolId)
                                end
                            else
                                SendPatrolStatus(patrolId, patrol, patrol.suspectInteraction)
                            end
                        elseif sceneCfg.autoReturnEnabled ~= false
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

                                Wait(GetCityBrainWaypointWaitMs(patrol))

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
    print(("[gs_police:ai_patrol] spawnPatrolUnit event received zone=%s"):format(tostring(zoneKey)))

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

RegisterNetEvent("gs_police:client:citybrainPatrolBiases", function(requestId, biases)
    requestId =
        tonumber(requestId)

    if not requestId then
        return
    end

    PendingCityBrainPatrolBiasRequests[requestId] =
        type(biases) == "table" and biases or {}
end)

RegisterNetEvent("gs_police:client:citybrainPatrolPressures", function(requestId, pressures)
    requestId =
        tonumber(requestId)

    if not requestId then
        return
    end

    PendingCityBrainPatrolPressureRequests[requestId] =
        type(pressures) == "table" and pressures or {}
end)

RegisterNetEvent("gs_police:client:clearPatrols", function()
    CleanupAllPatrols()
    QBCore.Functions.Notify(Config.AIPatrol.messages.cleared or "AI patrol units cleared.", "success")
end)

RegisterNetEvent("gs_police:client:receiveMovingTargetSnapshot", function(targetId, snapshot)
    PendingTargetSnapshots[tonumber(targetId)] =
        snapshot
end)

local function StartPatrolPursuitFromTask(task)
    if not task then
        print("[gs_police:pursuit_start] failed: missing task")
        return false, "missing task"
    end

    if not task.patrolId then
        print("[gs_police:pursuit_start] failed: missing patrolId")
        return false, "missing patrolId"
    end

    if not task.targetId then
        print("[gs_police:pursuit_start] failed: missing targetId")
        return false, "missing targetId"
    end

    local patrol =
        ActivePatrols[task.patrolId]

    if not patrol then
        print(("[gs_police:pursuit_start] failed: patrol not found patrol=%s"):format(tostring(task.patrolId)))
        return false, "patrol not found"
    end

    if not patrol.vehicle
    or not DoesEntityExist(patrol.vehicle) then
        print(("[gs_police:pursuit_start] failed: patrol vehicle missing patrol=%s"):format(tostring(task.patrolId)))
        return false, "patrol vehicle missing"
    end

    if not patrol.driver
    or not DoesEntityExist(patrol.driver) then
        print(("[gs_police:pursuit_start] failed: patrol driver missing patrol=%s"):format(tostring(task.patrolId)))
        return false, "patrol driver missing"
    end

    local oldMode =
        patrol.mode
    local oldStatus =
        patrol.status

    print(("[gs_police:ai_patrol] waypoint interrupted for pursuit patrol=%s incident=%s oldMode=%s oldStatus=%s"):format(
        tostring(task.patrolId),
        tostring(task.incidentId),
        tostring(oldMode),
        tostring(oldStatus)
    ))

    ClearPedTasks(patrol.driver)

    patrol.mode =
        "pursuit"
    patrol.status =
        "pursuit_active"
    patrol.assignedIncidentId =
        task.incidentId
    patrol.assignedIncidentCoords =
        task.lastKnownCoords
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
    patrol.emergencyResponse =
        true
    patrol.pursuit = {
        targetId = task.targetId,
        plate = task.plate,
        netId = task.netId,
        lastKnownCoords = task.lastKnownCoords,
        lastRouteUpdate = 0,
        lastLiveChaseUpdate = 0,
        lastChaseTaskAt = 0,
        lastHybridTaskAt = 0,
        lastEntitySeenAt = GetGameTimer(),
        controllerMode = "direct_chase",
        directChaseStarted = false,
        targetVehicle = nil,
        targetVehicleExists = false,
        targetEntityLastSeen = nil,
        targetEntityLostAt = nil,
        usingLiveChase = false,
        stopCandidateSince = nil,
        lastStuckCheckCoords = nil,
        lastStuckCheckDistance = nil,
        lastStuckCheckAt = 0,
        stuckReason = nil,
        confirmedStuck = false,
        stuckCandidateSince = nil,
        startedAt = GetGameTimer(),
        targetStoppedSince = nil,
        felonyStopStarted = false,
        felonyStopStaged = false,
        threatLevel = task.threatLevel or "medium"
    }

    print(("[gs_police:ai_patrol] patrol pursuit active patrol=%s incident=%s"):format(
        tostring(task.patrolId),
        tostring(task.incidentId)
    ))

    print(("[gs_police:pursuit_start] pursuit assigned patrol=%s targetId=%s plate=%s netId=%s"):format(
        tostring(task.patrolId),
        tostring(task.targetId),
        tostring(task.plate),
        tostring(task.netId)
    ))

    patrol.lastEmergencyRepath =
        0
    patrol.lastStuckCheck =
        0
    patrol.stuckSince =
        nil
    patrol.lastKnownSpeed =
        0.0
    patrol.repathAttempts =
        0
    patrol.felonyStopFinalized =
        false
    ResetSuspectInteraction(patrol)

    ApplyResponseCodeToPatrol(patrol, task.responseCode or "code3")

    if not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
        TaskEnterVehicle(patrol.driver, patrol.vehicle, 8000, -1, 1.0, 1, 0)
        Wait(1500)
    end

    TriggerServerEvent("gs_police:server:patrolDispatchStatus", task.patrolId, "pursuit_active", {
        incidentId = task.incidentId
    })

    QBCore.Functions.Notify("Patrol pursuit started.", "primary")
    return true, patrol
end

RegisterNetEvent("gs_police:client:startPatrolPursuit", function(task)
    print("[gs_police:pursuit_start] client event received", json.encode(task or {}))
    StartPatrolPursuitFromTask(task)
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

    ClearPedTasks(patrol.driver)

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
    patrol.lastEmergencyRepath =
        0
    patrol.lastStuckCheck =
        0
    patrol.stuckSince =
        nil
    patrol.lastKnownSpeed =
        0.0
    patrol.repathAttempts =
        0
    patrol.felonyStopFinalized =
        false
    ResetSuspectInteraction(patrol)

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

    ApplyResponseCodeToPatrol(patrol, task.responseCode or (emergencyResponse and "code3" or "code1"))

    if not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
        TaskEnterVehicle(patrol.driver, patrol.vehicle, 8000, -1, 1.0, 1, 0)
        Wait(2000)
    end

    local targetCoords =
        vector3(task.coords.x, task.coords.y, task.coords.z)
    local driveStyle =
        (
            Config.PatrolDispatch
            and Config.PatrolDispatch.drivingStyle
            or 786603
        )

    driveSpeed, driveStyle =
        GetPatrolDriveSettings(patrol, driveSpeed, driveStyle)

    if IsEmergencyDrivingActive(patrol) then
        EmergencyDriveToCoords(patrol, targetCoords)
    else
        TaskVehicleDriveToCoordLongrange(
            patrol.driver,
            patrol.vehicle,
            targetCoords.x,
            targetCoords.y,
            targetCoords.z,
            driveSpeed,
            driveStyle,
            15.0
        )
    end

    SendPatrolStatus(task.patrolId, patrol, "responding")

    TriggerServerEvent("gs_police:server:patrolDispatchStatus", task.patrolId, "responding", {
        incidentId = task.incidentId
    })

    QBCore.Functions.Notify("Patrol redirected to incident.", "primary")
end)

RegisterNetEvent("gs_police:client:respondToFootSuspect", function(task)
    if not task
    or not task.patrolId
    or not task.coords then
        return
    end

    local patrol =
        ActivePatrols[task.patrolId]

    if not patrol
    or not patrol.vehicle
    or not DoesEntityExist(patrol.vehicle)
    or not patrol.driver
    or not DoesEntityExist(patrol.driver) then
        return
    end

    ClearPedTasks(patrol.driver)

    patrol.mode =
        "foot_pursuit"
    patrol.status =
        "searching_last_known"
    patrol.assignedIncidentId =
        task.incidentId
    patrol.assignedIncidentCoords =
        task.coords
    patrol.suspectInfo =
        task.suspectInfo
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
    patrol.emergencyResponse =
        true

    ResetSuspectInteraction(patrol)
    ApplyResponseCodeToPatrol(patrol, task.responseCode or "code3")

    if not IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
        TaskEnterVehicle(patrol.driver, patrol.vehicle, 8000, -1, 1.0, 1, 0)
        Wait(1500)
    end

    local targetCoords =
        vector3(task.coords.x, task.coords.y, task.coords.z)

    EmergencyDriveToCoords(patrol, targetCoords)
    SendPatrolStatus(task.patrolId, patrol, "searching_last_known")

    TriggerServerEvent("gs_police:server:patrolDispatchStatus", task.patrolId, "responding", {
        incidentId = task.incidentId
    })

    CreateThread(function()
        local startedAt =
            GetGameTimer()
        local suspectServerId =
            task.suspectInfo and tonumber(task.suspectInfo.targetId)

        while patrol
        and patrol.mode == "foot_pursuit"
        and GetGameTimer() - startedAt < 180000 do
            Wait(750)

            if not patrol.driver
            or not DoesEntityExist(patrol.driver) then
                return
            end

            local currentPatrolCoords =
                patrol.vehicle
                and DoesEntityExist(patrol.vehicle)
                and GetEntityCoords(patrol.vehicle)
                or GetEntityCoords(patrol.driver)
            local distance =
                #(currentPatrolCoords - targetCoords)
            local suspectPed =
                nil

            if suspectServerId then
                local player =
                    GetPlayerFromServerId(suspectServerId)

                if player
                and player ~= -1 then
                    suspectPed =
                        GetPlayerPed(player)
                end
            end

            if suspectPed
            and DoesEntityExist(suspectPed)
            and IsPedInAnyVehicle(suspectPed, false) then
                local suspectVehicle =
                    GetVehiclePedIsIn(suspectPed, false)
                local suspectCoords =
                    GetEntityCoords(suspectVehicle)
                local netId =
                    NetworkGetNetworkIdFromEntity(suspectVehicle)
                local plate =
                    GetVehicleNumberPlateText(suspectVehicle)

                TriggerEvent("gs_police:client:startPatrolPursuit", {
                    patrolId = task.patrolId,
                    incidentId = task.incidentId,
                    targetId = suspectServerId,
                    netId = netId,
                    plate = plate,
                    lastKnownCoords = {
                        x = suspectCoords.x,
                        y = suspectCoords.y,
                        z = suspectCoords.z
                    },
                    threatLevel = task.threatLevel or "high",
                    responseCode = "code3",
                    incidentType = task.incidentType or "fleeing_vehicle"
                })

                TriggerServerEvent("gs_police:server:broadcastSuspectInfo", {
                    incidentId = task.incidentId,
                    crimeType = "enteredVehicle",
                    suspectInfo = {
                        targetId = suspectServerId,
                        type = "vehicle",
                        coords = {
                            x = suspectCoords.x,
                            y = suspectCoords.y,
                            z = suspectCoords.z
                        },
                        vehicle = {
                            netId = netId,
                            plate = plate,
                            model = tostring(GetEntityModel(suspectVehicle))
                        },
                        direction = "vehicle pursuit"
                    }
                })
                return
            end

            if distance <= 35.0 then
                if IsPedInVehicle(patrol.driver, patrol.vehicle, false) then
                    TaskVehicleTempAction(patrol.driver, patrol.vehicle, 27, 1500)
                    Wait(900)
                    TaskLeaveVehicle(patrol.driver, patrol.vehicle, 0)
                    Wait(1500)
                end

                if suspectPed
                and DoesEntityExist(suspectPed)
                and HasEntityClearLosToEntity(patrol.driver, suspectPed, 17) then
                    patrol.status =
                        "contact_suspect"
                    FaceEntity(patrol.driver, suspectPed)
                    TaskGoToEntity(patrol.driver, suspectPed, -1, 8.0, 2.0, 1073741824, 0)
                    SendPatrolStatus(task.patrolId, patrol, "contact_suspect")

                    if IsPedSprinting(suspectPed)
                    or IsPedRunning(suspectPed) then
                        patrol.status =
                            "foot_pursuit"
                        TaskGoToEntity(patrol.driver, suspectPed, -1, 4.0, 3.0, 1073741824, 0)
                        SendPatrolStatus(task.patrolId, patrol, "foot_pursuit")
                    end
                elseif patrol.status ~= "searching_last_known" then
                    patrol.status =
                        "searching_last_known"
                    SendPatrolStatus(task.patrolId, patrol, "searching_last_known")
                else
                    TaskStartScenarioInPlace(patrol.driver, "WORLD_HUMAN_COP_IDLES", 0, true)
                end
            elseif GetGameTimer() - (patrol.lastEmergencyRepath or 0) > 4000 then
                patrol.lastEmergencyRepath =
                    GetGameTimer()
                EmergencyDriveToCoords(patrol, targetCoords)
            end
        end

        if patrol
        and patrol.mode == "foot_pursuit" then
            patrol.status =
                "suspect_lost"
            SendPatrolStatus(task.patrolId, patrol, "suspect_lost")
            TriggerServerEvent("gs_police:server:patrolDispatchStatus", task.patrolId, "pursuit_lost", {
                incidentId = task.incidentId
            })
        end
    end)

    QBCore.Functions.Notify("Patrol responding to foot suspect.", "primary")
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

RegisterCommand("police_listpatrolzones", function()
    local zones =
        Config.AIPatrol
        and Config.AIPatrol.zones
        or {}
    local count =
        0

    print("[gs_police:ai_patrol] configured patrol zones:")

    for zoneKey, zone in pairs(zones) do
        count =
            count + 1

        print(("[gs_police:ai_patrol] zone=%s enabled=%s label=%s maxUnits=%s"):format(
            tostring(zoneKey),
            tostring(not zone or zone.enabled ~= false),
            tostring(zone and zone.label or "unknown"),
            tostring(zone and zone.maxUnits or "default")
        ))
    end

    if count == 0 then
        print("[gs_police:ai_patrol] no patrol zones configured")
    end

    local message =
        ("Patrol zones printed. Count: %s"):format(count)

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, "primary")
    end

    TriggerEvent("chat:addMessage", {
        color = { 0, 180, 255 },
        multiline = true,
        args = { "gs_police", message }
    })
end, false)

RegisterCommand("police_spawnpatrolclient", function(_, args)
    local zoneKey =
        args and args[1] or nil

    if not zoneKey
    or zoneKey == "" then
        local bias
        zoneKey, bias =
            SelectPatrolZoneWithCityBrainBias()

        if bias
        and bias.priorityZone then
            print(("[gs_police:ai_patrol] CityBrain patrol bias selected zone=%s weight=%s awareness=%s reason=%s"):format(
                tostring(zoneKey),
                tostring(bias.patrolWeight),
                tostring(bias.awarenessBoost),
                tostring(bias.reason)
            ))
        end
    end

    print(("[gs_police:ai_patrol] police_spawnpatrolclient requested zone=%s"):format(tostring(zoneKey)))

    local success, result =
        SpawnPatrolUnit(zoneKey)
    local message

    if success then
        message =
            ("Client patrol spawned. Zone: %s | Active: %s"):format(
                tostring(zoneKey),
                tostring(CountActivePatrols())
            )
        print("[gs_police:ai_patrol] " .. message)
    else
        message =
            ("Client patrol spawn failed. Zone: %s | Reason: %s"):format(
                tostring(zoneKey),
                tostring(result)
            )
        print("[gs_police:ai_patrol] " .. message)
    end

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, success and "success" or "error")
    end

    TriggerEvent("chat:addMessage", {
        color = success and { 0, 180, 255 } or { 255, 90, 90 },
        multiline = true,
        args = { "gs_police", message }
    })
end, false)

RegisterCommand("police_forcepursuitclient", function()
    local selectedPatrolId =
        nil

    for patrolId in pairs(ActivePatrols or {}) do
        selectedPatrolId =
            patrolId
        break
    end

    if not selectedPatrolId then
        print("[gs_police:pursuit_start] force failed: no active patrols")

        if QBCore
        and QBCore.Functions
        and QBCore.Functions.Notify then
            QBCore.Functions.Notify("Forced pursuit failed: no active patrols", "error")
        end

        return
    end

    local playerPed =
        PlayerPedId()
    local targetVehicle =
        nil

    if playerPed
    and DoesEntityExist(playerPed)
    and IsPedInAnyVehicle(playerPed, false) then
        targetVehicle =
            GetVehiclePedIsIn(playerPed, false)
    end

    if not targetVehicle
    or not DoesEntityExist(targetVehicle) then
        local playerCoords =
            GetEntityCoords(playerPed)
        targetVehicle =
            GetClosestNonPoliceVehicle(playerCoords, 50.0)
    end

    if not targetVehicle
    or not DoesEntityExist(targetVehicle) then
        print("[gs_police:pursuit_start] force failed: no target vehicle")

        if QBCore
        and QBCore.Functions
        and QBCore.Functions.Notify then
            QBCore.Functions.Notify("Forced pursuit failed: no target vehicle", "error")
        end

        return
    end

    local targetCoords =
        GetEntityCoords(targetVehicle)
    local netId =
        NetworkGetNetworkIdFromEntity(targetVehicle)
    local plate =
        GetVehicleNumberPlateText(targetVehicle)
    local task = {
        patrolId = selectedPatrolId,
        targetId = GetPlayerServerId(PlayerId()),
        netId = netId,
        plate = plate,
        lastKnownCoords = {
            x = targetCoords.x,
            y = targetCoords.y,
            z = targetCoords.z
        },
        incidentId = ("DEBUG-PURSUIT-%s"):format(GetGameTimer()),
        responseCode = "code3",
        threatLevel = "medium"
    }

    print(("[gs_police:pursuit_start] force selected patrol=%s vehicle=%s plate=%s netId=%s"):format(
        tostring(selectedPatrolId),
        tostring(targetVehicle),
        tostring(plate),
        tostring(netId)
    ))

    local success, result =
        StartPatrolPursuitFromTask(task)
    local message

    if success then
        message =
            "Forced pursuit started"
    else
        message =
            ("Forced pursuit failed: %s"):format(tostring(result))
    end

    print(("[gs_police:pursuit_start] force result success=%s result=%s"):format(
        tostring(success),
        tostring(result)
    ))

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, success and "success" or "error")
    end

    TriggerEvent("chat:addMessage", {
        color = success and { 0, 180, 255 } or { 255, 90, 90 },
        multiline = true,
        args = { "gs_police", message }
    })
end, false)

RegisterCommand("police_pursuitdebug", function()
    print("[gs_police:pursuit_debug] command received")

    local patrolCount =
        0
    local pursuitCount =
        0

    for patrolId, patrol in pairs(ActivePatrols or {}) do
        patrolCount =
            patrolCount + 1

        if patrol.pursuit then
            pursuitCount =
                pursuitCount + 1

            print(("[gs_police:pursuit_debug] patrol=%s mode=%s status=%s controller=%s directStarted=%s lastChaseTaskAt=%s live=%s targetExists=%s dist=%s speed=%s stopCandidate=%s confirmedStuck=%s stuckReason=%s stuckCandidate=%s lastStuckDist=%s currentDist=%s"):format(
                tostring(patrolId),
                tostring(patrol.mode),
                tostring(patrol.status),
                tostring(patrol.pursuit.controllerMode),
                tostring(patrol.pursuit.directChaseStarted),
                tostring(patrol.pursuit.lastChaseTaskAt),
                tostring(patrol.pursuit.usingLiveChase),
                tostring(patrol.pursuit.targetVehicleExists),
                tostring(patrol.pursuit.lastDistance),
                tostring(patrol.pursuit.speed),
                tostring(patrol.pursuit.stopCandidateSince),
                tostring(patrol.pursuit.confirmedStuck),
                tostring(patrol.pursuit.stuckReason),
                tostring(patrol.pursuit.stuckCandidateSince),
                tostring(patrol.pursuit.lastStuckCheckDistance),
                tostring(patrol.pursuit.lastDistance)
            ))
        else
            print(("[gs_police:pursuit_debug] patrol=%s mode=%s status=%s no active pursuit"):format(
                tostring(patrolId),
                tostring(patrol.mode),
                tostring(patrol.status)
            ))
        end
    end

    if patrolCount == 0 then
        print("[gs_police:pursuit_debug] command working, no active patrols found")
    elseif pursuitCount == 0 then
        print(("[gs_police:pursuit_debug] command working, patrols=%s, no active pursuits found"):format(patrolCount))
    end

    local message =
        ("Pursuit debug printed. Patrols: %s | Pursuits: %s"):format(patrolCount, pursuitCount)

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, "primary")
    end

    TriggerEvent("chat:addMessage", {
        color = { 0, 180, 255 },
        multiline = true,
        args = { "gs_police", message }
    })
end, false)

RegisterCommand("police_interactiondebug", function()
    for patrolId, patrol in pairs(ActivePatrols) do
        if patrol.suspectInteraction then
            print(("[gs_police:interaction_debug] patrol=%s mode=%s status=%s interaction=%s completed=%s incident=%s"):format(
                patrolId,
                tostring(patrol.mode),
                tostring(patrol.status),
                tostring(patrol.suspectInteraction),
                tostring(patrol.interactionCompleted),
                tostring(patrol.assignedIncidentId)
            ))
        end
    end

    QBCore.Functions.Notify("Interaction debug printed to F8.", "primary")
end, false)

RegisterCommand("police_compliancedebug", function()
    for patrolId, patrol in pairs(ActivePatrols) do
        if patrol.compliance then
            print(("[gs_police:compliance_debug] patrol=%s mode=%s status=%s compliance=%s completed=%s incident=%s suspect=%s"):format(
                patrolId,
                tostring(patrol.mode),
                tostring(patrol.status),
                tostring(patrol.compliance),
                tostring(patrol.complianceCompleted),
                tostring(patrol.assignedIncidentId),
                tostring(patrol.suspectPed)
            ))
        end
    end

    QBCore.Functions.Notify("Compliance debug printed to F8.", "primary")
end, false)

RegisterCommand("police_clienttelemetry", function()
    print("[gs_police:client_telemetry] ===== Client Patrol Snapshot =====")

    local count =
        0

    for patrolId, patrol in pairs(ActivePatrols or {}) do
        count =
            count + 1

        local speed =
            0.0

        if patrol.vehicle
        and DoesEntityExist(patrol.vehicle) then
            speed =
                GetEntitySpeed(patrol.vehicle)
        end

        print(("[gs_police:client_telemetry] PATROL %s | zone=%s | mode=%s | status=%s | skill=%s | driving=%.2f | pursuit=%.2f | scene=%.2f | responseCode=%s | speed=%.2f | incident=%s | emergency=%s | code3=%s | stuckSince=%s"):format(
            tostring(patrolId),
            tostring(patrol.zoneKey),
            tostring(patrol.mode),
            tostring(patrol.status),
            tostring(patrol.skillProfile),
            tonumber(patrol.drivingSkill) or 0.0,
            tonumber(patrol.pursuitSkill) or 0.0,
            tonumber(patrol.scenePositioning) or 0.0,
            tostring(patrol.responseCode),
            speed,
            tostring(patrol.assignedIncidentId),
            tostring(patrol.emergencyResponse),
            tostring(patrol.code3Response),
            tostring(patrol.stuckSince)
        ))

        if patrol.pursuit then
            print(("[gs_police:client_telemetry]  pursuit target=%s dist=%s targetSpeed=%s stoppedSince=%s felonyStarted=%s"):format(
                tostring(patrol.pursuit.targetId),
                tostring(patrol.pursuit.lastDistance),
                tostring(patrol.pursuit.speed),
                tostring(patrol.pursuit.targetStoppedSince),
                tostring(patrol.pursuit.felonyStopStarted)
            ))
        end

        if patrol.suspectInteraction then
            print(("[gs_police:client_telemetry]  interaction=%s completed=%s suspectVehicle=%s"):format(
                tostring(patrol.suspectInteraction),
                tostring(patrol.interactionCompleted),
                tostring(patrol.suspectVehicle)
            ))
        end

        if patrol.compliance then
            print(("[gs_police:client_telemetry]  compliance=%s completed=%s suspect=%s detainedPed=%s"):format(
                tostring(patrol.compliance),
                tostring(patrol.complianceCompleted),
                tostring(patrol.suspectPed),
                tostring(patrol.detainedPed)
            ))
        end
    end

    QBCore.Functions.Notify(("Client telemetry printed. Patrols: %s"):format(count), "primary")
end, false)

RegisterCommand("police_forcecomply", function()
    ForcedComplianceOutcome =
        "comply"
    QBCore.Functions.Notify("Next suspect outcome forced: comply", "success")
end, false)

RegisterCommand("police_forcerefuse", function()
    ForcedComplianceOutcome =
        "refuse"
    QBCore.Functions.Notify("Next suspect outcome forced: refuse", "success")
end, false)

RegisterCommand("police_forceflee", function()
    ForcedComplianceOutcome =
        "flee"
    QBCore.Functions.Notify("Next suspect outcome forced: flee", "success")
end, false)

RegisterCommand("police_clearpatrols_client", function()
    CleanupAllPatrols()
    QBCore.Functions.Notify("Client AI patrols cleared.", "success")
end, false)

RegisterCommand("police_debugping", function()
    print("[gs_police] police_debugping command working")

    if QBCore
    and QBCore.Functions
    and QBCore.Functions.Notify then
        QBCore.Functions.Notify("gs_police debug ping working", "success")
    end

    TriggerEvent("chat:addMessage", {
        color = { 0, 180, 255 },
        multiline = true,
        args = { "gs_police", "debug ping working" }
    })
end, false)
