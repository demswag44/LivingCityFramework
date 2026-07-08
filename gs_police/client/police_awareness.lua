local QBCore =
    exports["qb-core"]:GetCoreObject()

print("[gs_police] client/police_awareness.lua loaded")

local AwarenessCooldowns = {}
local AwarenessReportCooldowns = {}
local AwarenessLogCooldowns = {}
local AwarenessSuppressedReports = {}
local LastObservedCrime = nil
local LastRadioBroadcast = nil
local ActiveAwarenessIncident = nil
local LastKnownUpdateAt = 0
local LastCityBrainShotsFiredAt = 0

local function DebugAwareness(...)
    if Config
    and Config.Awareness
    and Config.Awareness.debug then
        print("[gs_police:awareness]", ...)
    elseif Config
    and Config.PoliceAwareness
    and Config.PoliceAwareness.debug then
        print("[gs_police:police_awareness]", ...)
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

local function GetWeatherVisibilityModifier()
    if not Config.WeatherIntegration or Config.WeatherIntegration.VisibilityEnabled == false then
        return 1.0
    end

    local visibility = tonumber(GetWeatherModifier('GetVisibilityModifier', 1.0)) or 1.0
    local minVisibility = tonumber(Config.WeatherIntegration.MinVisibilityModifier) or 0.35

    return math.max(visibility, minVisibility)
end

local function ShouldWeatherAllowWitnessReport()
    if not Config.WeatherIntegration or Config.WeatherIntegration.WitnessEnabled == false then
        return true
    end

    local witnessModifier = tonumber(GetWeatherModifier('GetWitnessModifier', 1.0)) or 1.0
    local chance = math.max(0.0, math.min(1.0, witnessModifier))

    if math.random() <= chance then
        return true
    end

    if Config.WeatherIntegration.Debug then
        print(('[gs_police:weather] witness report suppressed modifier=%s'):format(tostring(witnessModifier)))
    end

    return false
end

local function CanReportAwareness(key, seconds)
    local now =
        GetGameTimer()
    local last =
        AwarenessCooldowns[key] or 0

    if now - last < ((seconds or 10) * 1000) then
        return false
    end

    AwarenessCooldowns[key] =
        now

    return true
end

local function GetCrimeFamily(behavior)
    if behavior == "fleeingVehicle"
    or behavior == "stolenVehicle"
    or behavior == "recklessDriving"
    or behavior == "vehicleCrime"
    or behavior == "lastKnownUpdate" then
        return "vehicle"
    end

    return behavior or "unknown"
end

local function BuildReportThrottleKey(behavior, observerType, suspectInfo)
    local vehicle =
        suspectInfo and suspectInfo.vehicle or {}
    local incidentId =
        suspectInfo and suspectInfo.incidentId
        or LastRadioBroadcast and LastRadioBroadcast.incidentId
        or "new"
    local subject =
        suspectInfo and suspectInfo.targetId and ("target:" .. tostring(suspectInfo.targetId))
        or vehicle.plate and ("plate:" .. tostring(vehicle.plate))
        or vehicle.netId and ("net:" .. tostring(vehicle.netId))
        or "target:unknown"
    local crimeFamily =
        GetCrimeFamily(behavior)

    return ("incident:%s:%s:crime:%s"):format(
        tostring(incidentId),
        tostring(subject),
        tostring(crimeFamily)
    ), crimeFamily
end

local function CanSendAwarenessReport(key, cooldownMs)
    local now =
        GetGameTimer()
    local last =
        AwarenessReportCooldowns[key] or 0

    if now - last < (cooldownMs or 3500) then
        return false
    end

    AwarenessReportCooldowns[key] =
        now
    return true
end

local function CanLogAwarenessReport(key, cooldownMs)
    local now =
        GetGameTimer()
    local last =
        AwarenessLogCooldowns[key] or 0

    if now - last < (cooldownMs or 5000) then
        return false
    end

    AwarenessLogCooldowns[key] =
        now
    return true
end

local function TrackSuppressedAwarenessReport(key, suspectInfo, behavior, crimeFamily)
    local suppressed =
        AwarenessSuppressedReports[key] or {
            count = 0
        }

    suppressed.count =
        (suppressed.count or 0) + 1
    suppressed.lastAt =
        GetGameTimer()
    suppressed.incidentId =
        suspectInfo and suspectInfo.incidentId
    suppressed.crimeFamily =
        crimeFamily
    suppressed.lastCrimeType =
        behavior
    suppressed.lastDirection =
        suspectInfo and (suspectInfo.direction or suspectInfo.lastSeenDirection)

    AwarenessSuppressedReports[key] =
        suppressed

    return suppressed
end

local function GetSuppressedAwarenessCount()
    local count =
        0

    for _, suppressed in pairs(AwarenessSuppressedReports) do
        count =
            count + (suppressed.count or 0)
    end

    return count
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

local function GetDirectionLabel(heading)
    heading =
        tonumber(heading) or 0.0

    if heading < 0.0 then
        heading =
            heading + 360.0
    end

    local directions = {
        "northbound",
        "northeastbound",
        "eastbound",
        "southeastbound",
        "southbound",
        "southwestbound",
        "westbound",
        "northwestbound"
    }
    local index =
        math.floor(((heading + 22.5) % 360.0) / 45.0) + 1

    return directions[index] or "unknown direction"
end

local function GetStreetLabel(coords)
    if not coords then
        return nil
    end

    local streetHash, crossingHash =
        GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street =
        streetHash and GetStreetNameFromHashKey(streetHash) or nil
    local crossing =
        crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or nil

    if crossing
    and crossing ~= "" then
        return ("%s / %s"):format(street or "Unknown", crossing)
    end

    return street
end

local function GetVehicleInfo(vehicle)
    if not vehicle
    or vehicle == 0
    or not DoesEntityExist(vehicle) then
        return nil
    end

    local color1, color2 =
        GetVehicleColours(vehicle)

    return {
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = (GetVehicleNumberPlateText(vehicle) or ""):gsub("^%s*(.-)%s*$", "%1"),
        model = tostring(GetEntityModel(vehicle)),
        speed = GetEntitySpeed(vehicle),
        color1 = color1,
        color2 = color2
    }
end

local function BuildSuspectInfo(crimeType)
    local ped =
        PlayerPedId()
    local coords =
        GetEntityCoords(ped)
    local heading =
        GetEntityHeading(ped)
    local vehicle =
        IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
    local mask =
        GetPedDrawableVariation(ped, 1)
    local hat =
        GetPedPropIndex(ped, 0)

    return {
        targetId = GetPlayerServerId(PlayerId()),
        crimeType = crimeType,
        type = vehicle ~= 0 and "vehicle" or "foot",
        coords = ToCoordsTable(coords),
        heading = heading,
        direction = GetDirectionLabel(heading),
        onFoot = vehicle == 0,
        inVehicle = vehicle ~= 0,
        vehicle = GetVehicleInfo(vehicle),
        clothing = {
            mask = mask,
            maskTexture = GetPedTextureVariation(ped, 1),
            torso = GetPedDrawableVariation(ped, 11),
            torsoTexture = GetPedTextureVariation(ped, 11),
            legs = GetPedDrawableVariation(ped, 4),
            legsTexture = GetPedTextureVariation(ped, 4),
            shoes = GetPedDrawableVariation(ped, 6),
            shoesTexture = GetPedTextureVariation(ped, 6),
            hat = hat
        },
        hasMask = mask and mask > 0,
        hasHat = hat and hat >= 0,
        sex = IsPedMale(ped) and "male" or "female",
        pedModel = tostring(GetEntityModel(ped)),
        weapon = IsPedArmed(ped, 7) and GetSelectedPedWeapon(ped) or nil,
        lastSeenDirection = GetDirectionLabel(heading),
        lastSeenStreet = GetStreetLabel(coords),
        timestamp = GetCloudTimeAsInt and GetCloudTimeAsInt() or 0
    }
end

local function ForwardCityBrainAwareness(behavior, observerType, suspectInfo, metadata)
    if not Config
    or Config.CityBrainIntegrationEnabled ~= true then
        return false
    end

    if behavior ~= "weaponAimed"
    and behavior ~= "shooting"
    and behavior ~= "shotsFired"
    and behavior ~= "pursuit" then
        return false
    end

    if behavior == "shooting"
    or behavior == "shotsFired" then
        local now =
            GetGameTimer()
        local cooldownMs =
            tonumber(Config.CityBrainShotsFiredCooldownMs) or 10000

        if now - LastCityBrainShotsFiredAt < cooldownMs then
            return false
        end

        LastCityBrainShotsFiredAt =
            now
    end

    suspectInfo =
        suspectInfo or BuildSuspectInfo(behavior)
    metadata =
        metadata or {}

    local coords =
        suspectInfo and suspectInfo.coords or nil
    local zone =
        coords and GetNameOfZone(coords.x, coords.y, coords.z) or "unknown"
    local cityBrainPayload = nil

    if behavior == "shooting"
    or behavior == "shotsFired" then
        cityBrainPayload = {
            type = "shotsFired",
            coords = {
                x = coords and coords.x or 0.0,
                y = coords and coords.y or 0.0,
                z = coords and coords.z or 0.0
            },
            zone = zone,
            direction = "unknown",
            witness = true,
            observerType = "shots_fired_detector"
        }
    else
        cityBrainPayload = {
            type = behavior,
            coords = {
                x = coords and coords.x or 0.0,
                y = coords and coords.y or 0.0,
                z = coords and coords.z or 0.0
            },
            direction = suspectInfo.direction or suspectInfo.lastSeenDirection or "unknown",
            witness = metadata.witnessNearby == true,
            officer = metadata.officerNearby == true,
            zone = zone,
            observerType = observerType or "unknown"
        }
    end

    if Config.Debug then
        if behavior == "shooting"
        or behavior == "shotsFired" then
            print(("[gs_police] CityBrain shots fired forwarded zone=%s"):format(tostring(zone)))
            print("[gs_police] CityBrain TriggerServerEvent shotsFired sending")
        end

        print(("[gs_police] CityBrain client awareness forwarded type=%s"):format(tostring(behavior)))
    end

    local ok = pcall(function()
        TriggerServerEvent("gs_police:server:citybrainPing", "awareness", cityBrainPayload)
    end)

    if not ok and Config.Debug then
        print(("[gs_police] CityBrain client awareness forward failed type=%s"):format(tostring(behavior)))
    end

    return ok
end

local function HasNearbyPoliceVehicle(radius)
    local playerCoords =
        GetEntityCoords(PlayerPedId())

    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle)
        and GetVehicleClass(vehicle) == 18
        and #(playerCoords - GetEntityCoords(vehicle)) <= radius then
            return true
        end
    end

    return false
end

local function HasWitnessInRange(radius)
    local playerPed =
        PlayerPedId()
    local playerCoords =
        GetEntityCoords(playerPed)

    for _, ped in ipairs(GetGamePool("CPed")) do
        if DoesEntityExist(ped)
        and not IsPedAPlayer(ped)
        and not IsPedDeadOrDying(ped, true)
        and #(playerCoords - GetEntityCoords(ped)) <= radius then
            if HasEntityClearLosToEntity(ped, playerPed, 17) then
                return true, ped
            end
        end
    end

    return false, nil
end

local function SendAwarenessReport(behavior, observerType, metadata)
    local cfg =
        Config.Awareness or {}
    local behaviorConfig =
        cfg.behaviors and cfg.behaviors[behavior]
        or Config.PoliceAwareness
        and Config.PoliceAwareness.behaviors
        and Config.PoliceAwareness.behaviors[behavior]

    if not behaviorConfig then
        return
    end

    local suspectInfo =
        BuildSuspectInfo(behavior)

    if LastRadioBroadcast
    and LastRadioBroadcast.incidentId then
        suspectInfo.incidentId =
            LastRadioBroadcast.incidentId
    end

    local throttleKey, crimeFamily =
        BuildReportThrottleKey(behavior, observerType, suspectInfo)
    local hardPrintKey =
        ("hard:%s:crime:%s"):format(
            tostring(suspectInfo.incidentId or "new"),
            tostring(crimeFamily)
        )
    local eventCooldown =
        behavior == "lastKnownUpdate"
        and (cfg.lastKnownUpdateCooldownMs or 3000)
        or suspectInfo.incidentId
        and (cfg.reportSendCooldownMs or 5000)
        or (cfg.reportSendCooldownMs or cfg.reportEventCooldownMs or 5000)

    if not CanSendAwarenessReport(throttleKey, eventCooldown) then
        local suppressed =
            TrackSuppressedAwarenessReport(throttleKey, suspectInfo, behavior, crimeFamily)

        LastObservedCrime =
            LastObservedCrime or {}
        LastObservedCrime.incidentId =
            suspectInfo.incidentId
        LastObservedCrime.crimeFamily =
            crimeFamily
        LastObservedCrime.suppressedReports =
            GetSuppressedAwarenessCount()
        LastObservedCrime.lastCrimeType =
            behavior
        LastObservedCrime.lastDirection =
            suspectInfo.direction or suspectInfo.lastSeenDirection

        if CanLogAwarenessReport(hardPrintKey, cfg.reportHardPrintCooldownMs or 15000)
        and CanLogAwarenessReport("summary:" .. throttleKey, cfg.reportPrintCooldownMs or 10000) then
            print(("[gs_police:awareness] update incident=%s crimeFamily=%s reportsSuppressed=%s"):format(
                tostring(suspectInfo.incidentId or "unknown"),
                tostring(crimeFamily),
                tostring(suppressed.count or 0)
            ))
            suppressed.count =
                0
        end

        return
    end

    local delay =
        0

    if observerType == "witness" then
        local delayCfg =
            cfg.reportDelayMs or {}
        delay =
            math.random(delayCfg.min or 1500, delayCfg.max or 6000)
    end

    LastObservedCrime = {
        behavior = behavior,
        observerType = observerType,
        suspectInfo = suspectInfo,
        incidentId = suspectInfo.incidentId,
        crimeFamily = crimeFamily,
        lastReportAt = GetGameTimer(),
        suppressedReports = GetSuppressedAwarenessCount(),
        lastCrimeType = behavior,
        lastDirection = suspectInfo.direction or suspectInfo.lastSeenDirection,
        reportingStatus = delay > 0 and "queued" or "sent",
        witnesses = metadata and metadata.witnesses or 0,
        timestamp = GetGameTimer()
    }

    CreateThread(function()
        if delay > 0 then
            Wait(delay)
        end

        TriggerServerEvent("gs_police:server:policeAwarenessReport", {
            behavior = behavior,
            observerType = observerType,
            coords = suspectInfo.coords,
            suspectInfo = suspectInfo,
            priority = behaviorConfig.priority,
            metadata = metadata or {}
        })

        ForwardCityBrainAwareness(behavior, observerType, suspectInfo, metadata)

        LastObservedCrime.reportingStatus =
            "sent"
        ActiveAwarenessIncident =
            suspectInfo

        LastObservedCrime.lastReportAt =
            GetGameTimer()
        LastObservedCrime.suppressedReports =
            GetSuppressedAwarenessCount()

        if CanLogAwarenessReport(hardPrintKey, cfg.reportHardPrintCooldownMs or 15000)
        and CanLogAwarenessReport("reported:" .. throttleKey, cfg.reportPrintCooldownMs or 10000) then
            DebugAwareness("reported", behavior, observerType, suspectInfo.direction)
        end
    end)
end

local function ReportIfAllowed(behavior, observerType, metadata)
    local cfg =
        Config.Awareness or {}
    local cooldown =
        (cfg.reportEventCooldownMs and (cfg.reportEventCooldownMs / 1000.0))
        or cfg.reportCooldownSeconds
        or 8
    local key =
        ("%s:%s"):format(observerType or "unknown", behavior or "unknown")

    if CanReportAwareness(key, cooldown) then
        SendAwarenessReport(behavior, observerType, metadata)
        return true
    end

    return false
end

local function ScanForCrime()
    local cfg =
        Config.Awareness or Config.PoliceAwareness or {}

    if cfg.enabled == false then
        return
    end

    local ped =
        PlayerPedId()

    if not DoesEntityExist(ped)
    or IsPedDeadOrDying(ped, true) then
        return
    end

    local officerNearby =
        HasNearbyPoliceVehicle((cfg.officerAwarenessRange or cfg.weaponVisibleRadius or 90.0) * GetWeatherVisibilityModifier())
    local witnessNearby, witnessPed =
        false,
        nil

    if cfg.witnessReportEnabled ~= false then
        witnessNearby, witnessPed =
            HasWitnessInRange((cfg.witnessRange or 80.0) * GetWeatherVisibilityModifier())

        if witnessNearby and not officerNearby and not ShouldWeatherAllowWitnessReport() then
            witnessNearby =
                false
            witnessPed =
                nil
        end
    end

    local observerType =
        officerNearby and "officer" or (witnessNearby and "witness" or nil)

    local metadata = {
        officerNearby = officerNearby,
        witnessNearby = witnessNearby,
        witnessEntity = witnessPed,
        source = "autonomous_awareness"
    }

    if IsPedShooting(ped) then
        ForwardCityBrainAwareness("shotsFired", observerType, BuildSuspectInfo("shotsFired"), metadata)
    end

    if not observerType then
        return
    end

    if IsPedShooting(ped) then
        ReportIfAllowed("shotsFired", observerType, metadata)
    elseif IsPlayerFreeAiming(PlayerId())
    and IsPedArmed(ped, 4) then
        ReportIfAllowed("weaponAimed", observerType, metadata)
    elseif IsPedInMeleeCombat(ped)
    or IsPedJacking(ped)
    or IsPedBeingStunned(ped, 0) then
        ReportIfAllowed("assault", observerType, metadata)
    elseif GetVehiclePedIsTryingToEnter(ped) ~= 0
    or IsPedJacking(ped) then
        ReportIfAllowed("stolenVehicle", observerType, metadata)
    elseif IsPedInAnyVehicle(ped, false) then
        local vehicle =
            GetVehiclePedIsIn(ped, false)
        local speedMph =
            GetEntitySpeed(vehicle) * 2.236936

        if speedMph >= (cfg.recklessSpeedMph or 75.0) then
            ReportIfAllowed("recklessDriving", observerType, metadata)
        elseif ActiveAwarenessIncident then
            ReportIfAllowed("fleeingVehicle", observerType, metadata)
        end
    elseif GetPedDrawableVariation(ped, 1) > 0
    and IsPedArmed(ped, 7) then
        ReportIfAllowed("suspiciousBehavior", observerType, metadata)
    elseif ActiveAwarenessIncident
    and IsPedSprinting(ped) then
        ReportIfAllowed("runningFromScene", observerType, metadata)
    end
end

CreateThread(function()
    while true do
        local cfg =
            Config.Awareness or Config.PoliceAwareness or {}

        Wait(cfg.scanIntervalMs or 500)
        ScanForCrime()
    end
end)

CreateThread(function()
    while true do
        local waitMs =
            500
        local ped =
            PlayerPedId()

        if DoesEntityExist(ped)
        and not IsPedDeadOrDying(ped, true)
        and IsPedArmed(ped, 4) then
            waitMs =
                0

            if IsPedShooting(ped) then
                local suspectInfo =
                    BuildSuspectInfo("shotsFired")
                local coords =
                    suspectInfo.coords
                local zone =
                    coords and GetNameOfZone(coords.x, coords.y, coords.z) or "unknown"

                local forwarded =
                    ForwardCityBrainAwareness("shotsFired", "direct", suspectInfo, {
                    source = "shots_fired_detection_loop",
                    witnessNearby = false,
                    officerNearby = false
                })

                if forwarded
                and Config
                and Config.Debug then
                    print(("[gs_police] CityBrain shots fired detected zone=%s"):format(tostring(zone)))
                end
            end
        end

        Wait(waitMs)
    end
end)

RegisterNetEvent("gs_police:client:citybrainTestForward", function()
    if Config and Config.Debug then
        print("[gs_police] CityBrain client test event received")

        ForwardCityBrainAwareness("shotsFired", "server_test", BuildSuspectInfo("shotsFired"), {
            source = "server_citybrain_test",
            witnessNearby = true,
            officerNearby = false
        })
    end
end)

CreateThread(function()
    while true do
        local cfg =
            Config.Awareness or {}
        local interval =
            cfg.lastKnownUpdateCooldownMs or cfg.updateIntervalMs or 3000

        Wait(interval)

        if not ActiveAwarenessIncident then
            goto continue
        end

        if GetGameTimer() - LastKnownUpdateAt < interval then
            goto continue
        end

        LastKnownUpdateAt =
            GetGameTimer()

        local suspectInfo =
            BuildSuspectInfo("lastKnownUpdate")

        if LastRadioBroadcast
        and LastRadioBroadcast.incidentId then
            suspectInfo.incidentId =
                LastRadioBroadcast.incidentId
        end

        TriggerServerEvent("gs_police:server:updateSuspectLastKnown", suspectInfo)

        ::continue::
    end
end)

RegisterNetEvent("gs_police:client:receiveSuspectBroadcast", function(data)
    LastRadioBroadcast =
        data

    if data
    and data.suspectInfo then
        ActiveAwarenessIncident =
            data.suspectInfo
    end
end)

RegisterCommand("police_awarenesstest", function(_, args)
    local behavior =
        args[1] == "shots" and "shotsFired" or "weaponAimed"

    SendAwarenessReport(behavior, "test", {
        source = "police_awarenesstest"
    })

    QBCore.Functions.Notify(("Police awareness test sent: %s"):format(behavior), "primary")
end, false)

RegisterCommand("police_testcrime", function()
    local ped =
        PlayerPedId()
    local behavior =
        IsPedInAnyVehicle(ped, false) and "fleeingVehicle" or "assault"

    if IsPedShooting(ped) then
        behavior =
            "shotsFired"
    elseif IsPedArmed(ped, 7) then
        behavior =
            "weaponAimed"
    end

    SendAwarenessReport(behavior, "test", {
        source = "police_testcrime",
        testCommand = true
    })

    QBCore.Functions.Notify(Config.Awareness.messages.reportSent or "Crime report sent.", "success")
end, false)

RegisterCommand("police_aiwatchdebug", function()
    local activeIncidentId =
        LastObservedCrime and LastObservedCrime.incidentId
        or LastRadioBroadcast and LastRadioBroadcast.incidentId
        or ActiveAwarenessIncident and ActiveAwarenessIncident.incidentId
    local lastReportAt =
        LastObservedCrime and LastObservedCrime.lastReportAt
        or LastObservedCrime and LastObservedCrime.timestamp
    local suppressedReports =
        GetSuppressedAwarenessCount()
    local lastCrimeType =
        LastObservedCrime and LastObservedCrime.lastCrimeType
        or LastObservedCrime and LastObservedCrime.behavior
    local lastDirection =
        LastObservedCrime and LastObservedCrime.lastDirection
        or LastObservedCrime
        and LastObservedCrime.suspectInfo
        and (LastObservedCrime.suspectInfo.direction or LastObservedCrime.suspectInfo.lastSeenDirection)

    print("[gs_police:aiwatchdebug] ===== Awareness Debug =====")
    print(("[gs_police:aiwatchdebug] activeIncidentId=%s lastReportAt=%s suppressedReports=%s lastCrimeType=%s lastDirection=%s"):format(
        tostring(activeIncidentId or "none"),
        tostring(lastReportAt or "none"),
        tostring(suppressedReports),
        tostring(lastCrimeType or "none"),
        tostring(lastDirection or "unknown")
    ))
    print(("[gs_police:aiwatchdebug] lastObserved=%s"):format(json.encode(LastObservedCrime or {})))
    print(("[gs_police:aiwatchdebug] activeIncident=%s"):format(json.encode(ActiveAwarenessIncident or {})))
    print(("[gs_police:aiwatchdebug] lastRadio=%s"):format(json.encode(LastRadioBroadcast or {})))
    QBCore.Functions.Notify(Config.Awareness.messages.debugPrinted or "Awareness debug printed.", "primary")
end, false)

RegisterCommand("police_weatherclient", function()
    local resourceName =
        (Config.WeatherIntegration and Config.WeatherIntegration.ResourceName) or "gs_world"
    local resourceState =
        GetResourceState(resourceName)
    local currentWeather =
        GetWeatherModifier("GetCurrentWeather", {})

    print("[gs_police:weather] ===== Weather Integration Debug =====")
    print(("[gs_police:weather] integrationEnabled=%s gs_worldState=%s"):format(
        tostring(Config.WeatherIntegration and Config.WeatherIntegration.Enabled == true),
        tostring(resourceState)
    ))
    print(("[gs_police:weather] profile=%s baseWeather=%s weather=%s"):format(
        tostring(GetWeatherModifier("GetCurrentWeatherProfile", currentWeather.profile or "manual")),
        tostring(currentWeather.baseWeather or currentWeather.type or "unknown"),
        tostring(currentWeather.type or "unknown")
    ))
    print(("[gs_police:weather] visibility=%s witness=%s policeResponse=%s traffic=%s pedestrian=%s roadRisk=%s"):format(
        tostring(GetWeatherModifier("GetVisibilityModifier", 1.0)),
        tostring(GetWeatherModifier("GetWitnessModifier", 1.0)),
        tostring(GetWeatherModifier("GetPoliceResponseModifier", 1.0)),
        tostring(GetWeatherModifier("GetTrafficModifier", 1.0)),
        tostring(GetWeatherModifier("GetPedestrianModifier", 1.0)),
        tostring(GetWeatherModifier("GetRoadRiskModifier", 1.0))
    ))
    print(("[gs_police:weather] windSpeed=%s windDirection=%s windGusts=%s windRisk=%s"):format(
        tostring(GetWeatherModifier("GetWindSpeed", 0.0)),
        tostring(GetWeatherModifier("GetWindDirection", 0.0)),
        tostring(GetWeatherModifier("GetWindGusts", 0.0)),
        tostring(GetWeatherModifier("GetWindRiskModifier", 1.0))
    ))

    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify("Police weather debug printed.", "primary")
    end
end, false)

RegisterCommand("police_radio_debug", function()
    print("[gs_police:radio_debug] ===== Last Radio Broadcast =====")

    local broadcast =
        LastRadioBroadcast or {}
    local vehicle =
        broadcast.vehicle
        or broadcast.suspectInfo
        and broadcast.suspectInfo.vehicle
        or {}
    local receivers =
        broadcast.receivingUnits or {}

    print(("[gs_police:radio_debug] incident=%s crimeType=%s targetId=%s plate=%s netId=%s direction=%s receivers=%s reused=%s"):format(
        tostring(broadcast.incidentId),
        tostring(broadcast.crimeType),
        tostring(broadcast.suspectInfo and broadcast.suspectInfo.targetId),
        tostring(vehicle.plate),
        tostring(vehicle.netId),
        tostring(broadcast.direction),
        tostring(#receivers),
        tostring(broadcast.activeIncidentReused)
    ))

    for _, receiver in ipairs(receivers) do
        print(("[gs_police:radio_debug] receiver patrol=%s task=%s owner=%s role=%s mode=%s status=%s assignedIncident=%s distance=%s intercept=%s"):format(
            tostring(receiver.patrolId),
            tostring(receiver.taskId),
            tostring(receiver.owner),
            tostring(receiver.role),
            tostring(receiver.mode),
            tostring(receiver.status),
            tostring(receiver.assignedIncidentId),
            tostring(receiver.distanceToSuspect),
            json.encode(receiver.lastInterceptPoint or {})
        ))
    end

    print(("[gs_police:radio_debug] raw=%s"):format(json.encode(broadcast)))
    QBCore.Functions.Notify(Config.Awareness.messages.radioDebugPrinted or "Radio debug printed.", "primary")
end, false)
