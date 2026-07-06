local QBCore =
    exports['qb-core']:GetCoreObject()

local recentIncidents = {}
local incidentRecords = {}
local incidentIdCounter = 0
local ActivePatrolUnits = {}
local PatrolDetectionSignals = {}
local PatrolDetectionCooldowns = {}
local NextDetectionSignalId = 1

local function DebugPrint(message)
    if Config.Debug then
        print("[gs_police] " .. message)
    end
end

local function DebugPatrolDetection(...)
    if Config
    and Config.PatrolDetection
    and Config.PatrolDetection.debug then
        print("[gs_police:patrol_detection]", ...)
    end
end

local function Notify(src, message, messageType)
    if src and src > 0 then
        TriggerClientEvent("QBCore:Notify", src, message, messageType or "primary")
    end
end

local function CanUsePoliceRecords(src)
    local cfg =
        Config.IncidentRecords or {}

    if src == 0 then
        return cfg.allowServerConsole ~= false
    end

    if cfg.allowAceBypass
    and cfg.acePermission
    and IsPlayerAceAllowed(src, cfg.acePermission) then
        return true
    end

    if not cfg.restrictToPolice then
        return true
    end

    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player
    or not Player.PlayerData then
        return false
    end

    local job =
        Player.PlayerData.job or {}
    local jobName =
        job.name
    local onDuty =
        job.onduty

    if not jobName
    or not cfg.policeJobs
    or not cfg.policeJobs[jobName] then
        return false
    end

    if cfg.requireOnDuty
    and onDuty ~= true then
        return false
    end

    return true
end

local function DenyPoliceRecordAccess(src)
    local message =
        (
            Config.IncidentRecords
            and Config.IncidentRecords.messages
            and Config.IncidentRecords.messages.denied
        )
        or "You are not authorized to access police incidents."

    if src and src > 0 then
        TriggerClientEvent("QBCore:Notify", src, message, "error")
    else
        print("[gs_police] Access denied to police incident records.")
    end
end

local function FormatTimestamp(timestamp)
    return os.date("%Y-%m-%d %H:%M:%S", timestamp or os.time())
end

local function FormatCoords(coords)
    if not coords then
        return "Unknown"
    end

    return ("%.2f, %.2f, %.2f"):format(
        coords.x or 0.0,
        coords.y or 0.0,
        coords.z or 0.0
    )
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
        if type(coords) == "table" then
            x =
                tonumber(coords[1])
            y =
                tonumber(coords[2])
            z =
                tonumber(coords[3])
        end

        if not x
        or not y
        or not z then
            return nil
        end
    end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function DistanceBetweenCoords(a, b)
    if not a
    or not b then
        return 999999.0
    end

    local ax, ay, az =
        a.x or 0.0,
        a.y or 0.0,
        a.z or 0.0
    local bx, by, bz =
        b.x or 0.0,
        b.y or 0.0,
        b.z or 0.0
    local dx =
        ax - bx
    local dy =
        ay - by
    local dz =
        az - bz

    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function FormatValue(value)
    if type(value) == "table" then
        return json.encode(value)
    end

    return tostring(value)
end

local function FormatIncidentLine(record)
    return ("#%s [%s] %s | threat=%s | response=%s | force=%s | src=%s"):format(
        record.id,
        record.status or "open",
        record.incidentType or "unknown",
        record.assessment and record.assessment.finalThreat or "unknown",
        record.assessment and record.assessment.response or "unknown",
        record.assessment and record.assessment.forcePolicy or "unknown",
        record.sourceResource or "unknown"
    )
end

local function Now()
    return os.time()
end

local function GetIncidentRecordById(incidentId)
    local normalizedIncidentId =
        tonumber(incidentId)

    if not normalizedIncidentId then
        return nil
    end

    local directRecord =
        incidentRecords[normalizedIncidentId]
        or incidentRecords[tostring(normalizedIncidentId)]

    if directRecord then
        return directRecord
    end

    for _, record in pairs(incidentRecords) do
        local recordId =
            record and tonumber(record.id)

        if recordId
        and recordId == normalizedIncidentId then
            return record
        end
    end

    return nil
end

local function GetOfficerName(src)
    if src == 0 then
        return "Server Console"
    end

    local Player =
        QBCore.Functions.GetPlayer(src)

    if not Player
    or not Player.PlayerData then
        return ("Officer %s"):format(src)
    end

    local charinfo =
        Player.PlayerData.charinfo or {}
    local firstName =
        charinfo.firstname or ""
    local lastName =
        charinfo.lastname or ""
    local fullName =
        (firstName .. " " .. lastName):gsub("^%s+", ""):gsub("%s+$", "")

    if fullName == "" then
        return Player.PlayerData.name or ("Officer %s"):format(src)
    end

    return fullName
end

local function EnsureDispatchFields(record)
    if not record then
        return nil
    end

    record.dispatch =
        record.dispatch or {}

    if record.dispatch.assignedUnit == nil then
        record.dispatch.assignedUnit =
            record.assignedUnit or nil
    end

    if record.dispatch.aiRequested == nil then
        record.dispatch.aiRequested =
            false
    end

    if record.dispatch.assignedUnit then
        record.assignedUnit =
            record.dispatch.assignedUnit
    end

    return record.dispatch
end

local function EnsureDispatchPlanFields(record)
    if not record then
        return nil
    end

    record.dispatchPlan =
        record.dispatchPlan or {
            planKey = nil,
            label = nil,
            recommendedUnits = {},
            appliedAt = nil,
            appliedBy = nil,
            autoGenerated = false
        }

    if type(record.dispatchPlan.recommendedUnits) ~= "table" then
        record.dispatchPlan.recommendedUnits =
            {}
    end

    if record.dispatchPlan.autoGenerated == nil then
        record.dispatchPlan.autoGenerated =
            false
    end

    if record.dispatchPlan.planKey
    and #record.dispatchPlan.recommendedUnits <= 0 then
        local plan =
            Config.DispatchEscalation
            and Config.DispatchEscalation.plans
            and Config.DispatchEscalation.plans[record.dispatchPlan.planKey]

        if plan
        and plan.recommendedUnits then
            record.dispatchPlan.recommendedUnits =
                {}

            for _, unit in ipairs(plan.recommendedUnits) do
                record.dispatchPlan.recommendedUnits[#record.dispatchPlan.recommendedUnits + 1] = {
                    type = unit.type or "patrol",
                    count = tonumber(unit.count) or 1
                }
            end
        end
    end

    return record.dispatchPlan
end

local function AddIncidentNote(record, author, note)
    if not record then
        return
    end

    record.notes =
        record.notes or {}

    local timestamp =
        Now()

    record.notes[#record.notes + 1] = {
        author = author or "System",
        text = note or "",
        time = timestamp,
        note = note or "",
        timestamp = timestamp
    }
end

local function GetDispatchPlanForIncident(record)
    local cfg =
        Config.DispatchEscalation or {}

    if cfg.enabled == false
    or not record then
        return nil, nil
    end

    local incidentType =
        record.type or record.incidentType
    local threatLevel =
        record.threatLevel
        or record.threat
        or (record.assessment and record.assessment.finalThreat)
        or "low"
    local planKey =
        nil

    if threatLevel == "deadly"
    and cfg.threatPlans then
        planKey =
            cfg.threatPlans.deadly
    end

    if not planKey
    and cfg.incidentOverrides
    and incidentType then
        planKey =
            cfg.incidentOverrides[incidentType]
    end

    if not planKey
    and cfg.threatPlans then
        planKey =
            cfg.threatPlans[threatLevel]
    end

    if not planKey then
        planKey =
            cfg.defaultPlan or "patrol_only"
    end

    local plan =
        cfg.plans and cfg.plans[planKey]

    if not plan then
        return nil, nil
    end

    return planKey, plan
end

local function CopyRecommendedUnits(recommendedUnits)
    local units =
        {}

    for _, unit in ipairs(recommendedUnits or {}) do
        units[#units + 1] = {
            type = unit.type or "patrol",
            count = tonumber(unit.count) or 1
        }
    end

    return units
end

local function ApplyDispatchPlan(record, appliedBy, autoGenerated)
    local planKey, plan =
        GetDispatchPlanForIncident(record)

    if not planKey
    or not plan then
        return false
    end

    record.dispatchPlan = {
        planKey = planKey,
        label = plan.label or planKey,
        recommendedUnits = CopyRecommendedUnits(plan.recommendedUnits),
        appliedAt = os.time(),
        appliedBy = appliedBy or "Dispatch",
        autoGenerated = autoGenerated == true
    }

    AddIncidentNote(record, "Dispatch", plan.note or ("Dispatch recommends: " .. tostring(plan.label or planKey)))

    return true
end

local function AssignIncidentToUnit(src, incidentId, unitName)
    local cfg =
        Config.Dispatch or {}

    if cfg.enabled == false then
        return false, "dispatchDisabled"
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return false, "invalidIncident"
    end

    if not unitName or unitName == "" then
        return false, "invalidUnit"
    end

    local dispatch =
        EnsureDispatchFields(record)

    dispatch.assignedUnit =
        unitName
    dispatch.assignedType =
        "player"
    dispatch.assignedBy =
        src
    dispatch.assignedByName =
        GetOfficerName(src)
    dispatch.assignedAt =
        Now()

    record.assignedUnit =
        unitName
    record.status =
        "assigned"

    AddIncidentNote(record, dispatch.assignedByName, ("Assigned incident to %s."):format(unitName))
    TriggerEvent("gs_police:server:incidentUpdated", record)

    return true, record
end

local function RequestAiUnitForIncident(src, incidentId, aiUnitType)
    local cfg =
        Config.Dispatch or {}

    if cfg.enabled == false
    or cfg.aiUnitsEnabled == false then
        return false, "dispatchDisabled"
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return false, "invalidIncident"
    end

    aiUnitType =
        aiUnitType or cfg.defaultAiUnitType or "patrol"

    local unitConfig =
        cfg.aiUnitTypes and cfg.aiUnitTypes[aiUnitType]

    if not unitConfig then
        return false, "invalidUnit"
    end

    local dispatch =
        EnsureDispatchFields(record)
    local now =
        Now()
    local taskId =
        ("AI-%s-%s"):format(incidentId, now)

    dispatch.assignedUnit =
        unitConfig.label or "AI Unit"
    dispatch.assignedType =
        "ai"
    dispatch.assignedBy =
        src
    dispatch.assignedByName =
        GetOfficerName(src)
    dispatch.assignedAt =
        now
    dispatch.aiRequested =
        true
    dispatch.aiUnitType =
        aiUnitType
    dispatch.aiStatus =
        "requested"
    dispatch.aiTaskId =
        taskId
    dispatch.aiLastUpdate =
        now

    record.assignedUnit =
        dispatch.assignedUnit
    record.status =
        unitConfig.responseStatus or "ai_assigned"

    AddIncidentNote(record, dispatch.assignedByName, unitConfig.note or "AI unit requested.")

    TriggerEvent("gs_police:server:aiUnitRequested", {
        taskId = taskId,
        incidentId = incidentId,
        unitType = aiUnitType,
        record = record,
        requestedBy = src
    })
    TriggerEvent("gs_police:server:incidentUpdated", record)

    return true, record
end

local function RequestRecommendedAiUnitsForIncident(src, incidentId)
    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return false, "noIncident"
    end

    if record.status == "ai_cleared"
    or record.status == "closed" then
        return false, "alreadyCleared"
    end

    if not record.dispatchPlan
    or not record.dispatchPlan.recommendedUnits
    or #record.dispatchPlan.recommendedUnits <= 0 then
        ApplyDispatchPlan(record, GetOfficerName(src), false)
    end

    local recommendedUnits =
        record.dispatchPlan and record.dispatchPlan.recommendedUnits or {}

    if #recommendedUnits <= 0 then
        return false, "invalidPlan"
    end

    local firstUnit =
        recommendedUnits[1]
    local unitType =
        firstUnit.type or "patrol"

    return RequestAiUnitForIncident(src, incidentId, unitType)
end

RegisterNetEvent("gs_police:server:aiUnitRequested", function(task)
    local eventSource =
        tonumber(source) or 0

    if eventSource > 0 then
        return
    end

    if not task
    or not task.record
    or not task.taskId then
        return
    end

    local record =
        task.record
    local coords =
        NormalizeCoords(record.coords or record.location or record.position)

    if not coords then
        TriggerEvent("gs_police:server:updateAiUnitStatus", task.taskId, "failed", {
            incidentId = task.incidentId,
            reason = "noCoords"
        })
        return
    end

    local target =
        tonumber(task.requestedBy) or 0

    if target <= 0 then
        local players =
            GetPlayers()

        target =
            tonumber(players[1]) or 0
    end

    if target <= 0 then
        TriggerEvent("gs_police:server:updateAiUnitStatus", task.taskId, "failed", {
            incidentId = task.incidentId,
            reason = "noClientTarget"
        })
        return
    end

    local assessment =
        record.assessment or {}

    TriggerClientEvent("gs_police:client:spawnAiUnit", target, {
        taskId = task.taskId,
        incidentId = task.incidentId,
        unitType = task.unitType,
        coords = coords,
        threatLevel = assessment.finalThreat or record.threatLevel,
        forcePolicy = assessment.forcePolicy or record.forcePolicy,
        response = assessment.response or record.response
    })
end)

RegisterNetEvent("gs_police:server:updateAiUnitStatus", function(taskId, status, data)
    if not taskId
    or not status then
        return
    end

    data =
        data or {}

    local incidentId =
        tonumber(data.incidentId)

    if not incidentId then
        return
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return
    end

    local dispatch =
        EnsureDispatchFields(record)
    local now =
        Now()

    if dispatch.aiTaskId
    and tostring(dispatch.aiTaskId) ~= tostring(taskId) then
        return
    end

    dispatch.aiStatus =
        status
    dispatch.aiLastUpdate =
        now

    if status == "responding" then
        record.status =
            "ai_responding"
    elseif status == "arrived" then
        record.status =
            "ai_arrived"
        AddIncidentNote(record, "AI Dispatch", "AI unit arrived on scene.")
    elseif status == "scene_investigate" then
        record.status =
            "ai_investigating"
        dispatch.aiStatus =
            "investigating"
        dispatch.aiSceneBehavior =
            data.behavior or "investigate"
        AddIncidentNote(record, "AI Dispatch", "AI officers are investigating the scene.")
    elseif status == "scene_stage" then
        record.status =
            "ai_staging"
        dispatch.aiStatus =
            "staging"
        dispatch.aiSceneBehavior =
            data.behavior or "stage"
        AddIncidentNote(record, "AI Dispatch", "AI officers are staging near the incident.")
    elseif status == "scene_contain" then
        record.status =
            "ai_containing"
        dispatch.aiStatus =
            "containing"
        dispatch.aiSceneBehavior =
            data.behavior or "contain"
        AddIncidentNote(record, "AI Dispatch", "AI officers are containing the scene.")
    elseif status == "clearing" then
        record.status =
            "ai_clearing"
        dispatch.aiStatus =
            "clearing"
        AddIncidentNote(record, "AI Dispatch", "AI unit is clearing the incident.")
    elseif status == "failed" then
        record.status =
            "ai_failed"
        AddIncidentNote(record, "AI Dispatch", ("AI unit failed to respond: %s."):format(data.reason or "unknown"))
    elseif status == "cleared" then
        record.status =
            "ai_cleared"
        dispatch.aiStatus =
            "cleared"
        AddIncidentNote(record, "AI Dispatch", "AI unit cleared from incident.")
    end

    TriggerEvent("gs_police:server:incidentUpdated", record)
end)

local function SanitizeForNui(value, depth)
    depth =
        depth or 0

    if depth > 6 then
        return tostring(value)
    end

    local valueType =
        type(value)

    if valueType == "number"
    or valueType == "string"
    or valueType == "boolean"
    or value == nil then
        return value
    end

    if valueType == "vector3"
    or (
        valueType == "table"
        and value.x
        and value.y
        and value.z
    ) then
        return {
            x = tonumber(value.x) or 0.0,
            y = tonumber(value.y) or 0.0,
            z = tonumber(value.z) or 0.0
        }
    end

    if valueType ~= "table" then
        return tostring(value)
    end

    local sanitized = {}

    for key, item in pairs(value) do
        sanitized[tostring(key)] =
            SanitizeForNui(item, depth + 1)
    end

    return sanitized
end

local function SerializeIncidentRecord(record)
    if not record then
        return nil
    end

    EnsureDispatchFields(record)
    EnsureDispatchPlanFields(record)

    local dispatchPlan =
        {
            planKey = record.dispatchPlan.planKey,
            label = record.dispatchPlan.label,
            recommendedUnits = {},
            appliedAt = record.dispatchPlan.appliedAt,
            appliedBy = record.dispatchPlan.appliedBy,
            autoGenerated = record.dispatchPlan.autoGenerated == true
        }

    for _, unit in ipairs(record.dispatchPlan.recommendedUnits or {}) do
        dispatchPlan.recommendedUnits[#dispatchPlan.recommendedUnits + 1] = {
            type = unit.type or "patrol",
            count = tonumber(unit.count) or 1
        }
    end

    return {
        id = record.id,
        source = record.source,
        sourceResource = record.sourceResource or "unknown",
        incidentType = record.incidentType or "unknown",
        title = record.title or "Police Incident",
        message = record.message or "Incident reported.",
        coords = SanitizeForNui(record.coords),
        locationText = record.locationText or "Unknown",
        createdAt = record.createdAt,
        assessment = SanitizeForNui(record.assessment or {}),
        orgContext = SanitizeForNui(record.orgContext or {}),
        metadata = SanitizeForNui(record.metadata or {}),
        status = record.status or "open",
        assignedUnit = record.assignedUnit,
        notes = SanitizeForNui(record.notes or {}),
        dispatch = SanitizeForNui(record.dispatch or {}),
        dispatchPlan = dispatchPlan
    }
end

local function GetSerializedIncidentRecords()
    local ids = {}
    local records = {}

    for id in pairs(incidentRecords) do
        ids[#ids + 1] =
            id
    end

    table.sort(ids, function(a, b)
        return tonumber(a) > tonumber(b)
    end)

    for _, id in ipairs(ids) do
        records[#records + 1] =
            SerializeIncidentRecord(incidentRecords[id])
    end

    return records
end

RegisterNetEvent("gs_police:server:patrolStatus", function(patrolId, data)
    if not patrolId then
        return
    end

    data =
        data or {}

    if data.status == "cleared"
    or data.status == "lost" then
        ActivePatrolUnits[patrolId] =
            nil
        return
    end

    ActivePatrolUnits[patrolId] =
        ActivePatrolUnits[patrolId] or {}

    for key, value in pairs(data) do
        ActivePatrolUnits[patrolId][key] =
            value
    end

    ActivePatrolUnits[patrolId].patrolId =
        patrolId
    ActivePatrolUnits[patrolId].owner =
        tonumber(source) or 0
    ActivePatrolUnits[patrolId].updatedAt =
        os.time()
end)

local function GetActivePatrolUnits()
    local units =
        {}

    for _, patrol in pairs(ActivePatrolUnits) do
        units[#units + 1] =
            SanitizeForNui(patrol)
    end

    table.sort(units, function(a, b)
        return tostring(a.patrolId) < tostring(b.patrolId)
    end)

    return units
end

local function IsPatrolAvailableForDispatch(patrol)
    if not patrol then
        return false
    end

    local mode =
        patrol.mode or "patrol"
    local status =
        patrol.status or "unknown"

    if mode ~= "patrol" then
        return false
    end

    if status == "lost"
    or status == "cleared" then
        return false
    end

    if patrol.assignedIncidentId then
        return false
    end

    return true
end

local function FindNearestAvailablePatrol(coords, maxDistance)
    local nearest =
        nil
    local nearestDistance =
        nil
    local normalizedCoords =
        NormalizeCoords(coords)

    if not normalizedCoords then
        return nil, nil
    end

    maxDistance =
        maxDistance
        or (
            Config.PatrolDispatch
            and Config.PatrolDispatch.maxDispatchDistance
        )
        or 450.0

    for patrolId, patrol in pairs(ActivePatrolUnits or {}) do
        local patrolCoords =
            NormalizeCoords(patrol.coords)

        if IsPatrolAvailableForDispatch(patrol)
        and patrolCoords then
            local distance =
                DistanceBetweenCoords(normalizedCoords, patrolCoords)

            if distance <= maxDistance
            and (
                not nearestDistance
                or distance < nearestDistance
            ) then
                nearest =
                    patrol
                nearest.patrolId =
                    patrolId
                nearestDistance =
                    distance
            end
        end
    end

    return nearest, nearestDistance
end

local function DispatchNearestPatrolToIncident(src, incidentId)
    local cfg =
        Config.PatrolDispatch or {}

    if cfg.enabled == false then
        return false, "disabled"
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return false, "noIncident"
    end

    local coords =
        NormalizeCoords(
            record.coords
            or record.position
            or (
                record.alertData
                and record.alertData.coords
            )
        )

    if not coords then
        return false, "noIncident"
    end

    local patrol, distance =
        FindNearestAvailablePatrol(coords, cfg.maxDispatchDistance or 450.0)

    if not patrol then
        return false, "noPatrolAvailable"
    end

    local patrolId =
        patrol.patrolId

    ActivePatrolUnits[patrolId] =
        ActivePatrolUnits[patrolId] or patrol
    ActivePatrolUnits[patrolId].mode =
        "responding"
    ActivePatrolUnits[patrolId].status =
        "responding"
    ActivePatrolUnits[patrolId].assignedIncidentId =
        record.id
    ActivePatrolUnits[patrolId].assignedAt =
        os.time()

    record.dispatch =
        record.dispatch or {}
    record.dispatch.assignedUnit =
        patrol.zoneLabel or patrolId
    record.dispatch.assignedType =
        "patrol"
    record.dispatch.assignedBy =
        src
    record.dispatch.assignedByName =
        GetOfficerName(src)
    record.dispatch.assignedAt =
        os.time()
    record.dispatch.patrolId =
        patrolId
    record.dispatch.patrolStatus =
        "responding"
    record.dispatch.patrolDistance =
        distance
    record.dispatch.patrolLastUpdate =
        os.time()

    record.assignedUnit =
        record.dispatch.assignedUnit
    record.status =
        "patrol_dispatched"

    AddIncidentNote(record, "Dispatch", ("Nearest patrol dispatched: %s."):format(record.dispatch.assignedUnit))

    TriggerClientEvent("gs_police:client:dispatchPatrolToIncident", -1, {
        patrolId = patrolId,
        incidentId = record.id,
        coords = coords,
        incidentType = record.type or record.incidentType,
        threatLevel = record.threatLevel or (
            record.assessment
            and record.assessment.finalThreat
        ),
        forcePolicy = record.forcePolicy or (
            record.assessment
            and record.assessment.forcePolicy
        ),
        response = record.response or (
            record.assessment
            and record.assessment.response
        )
    })

    TriggerEvent("gs_police:server:incidentUpdated", record)

    return true, record
end

RegisterNetEvent("gs_police:server:patrolDispatchStatus", function(patrolId, status, data)
    if not patrolId
    or not status then
        return
    end

    data =
        data or {}

    local incidentId =
        tonumber(data.incidentId)

    if not incidentId then
        return
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        return
    end

    record.dispatch =
        record.dispatch or {}
    record.dispatch.patrolId =
        patrolId
    record.dispatch.patrolStatus =
        status
    record.dispatch.patrolLastUpdate =
        os.time()

    if status == "responding" then
        record.status =
            "patrol_responding"
        AddIncidentNote(record, "Dispatch", "Nearby patrol is responding.")
    elseif status == "arrived" then
        record.status =
            "patrol_arrived"
        AddIncidentNote(record, "Dispatch", "Nearby patrol arrived on scene.")
    elseif status == "cleared" then
        record.status =
            "patrol_cleared"
        AddIncidentNote(record, "Dispatch", "Nearby patrol cleared the incident.")
    elseif status == "returned" then
        record.status =
            "patrol_cleared"
        record.dispatch.patrolStatus =
            "returned_to_service"
        AddIncidentNote(record, "Dispatch", "Patrol returned to service.")

        if ActivePatrolUnits
        and ActivePatrolUnits[patrolId] then
            ActivePatrolUnits[patrolId].mode =
                "patrol"
            ActivePatrolUnits[patrolId].status =
                "patrolling"
            ActivePatrolUnits[patrolId].assignedIncidentId =
                nil
        end
    end

    TriggerEvent("gs_police:server:incidentUpdated", record)
end)

local function GetPatrolDetectionSignals()
    local signals =
        {}

    for _, signal in pairs(PatrolDetectionSignals) do
        signals[#signals + 1] = {
            id = signal.id,
            signalType = signal.signalType,
            label = signal.label,
            sourceResource = signal.sourceResource,
            detected = signal.detected == true,
            detectedByPatrolId = signal.detectedByPatrolId,
            detectedAt = signal.detectedAt,
            createdAt = signal.createdAt
        }
    end

    table.sort(signals, function(a, b)
        return (a.id or 0) > (b.id or 0)
    end)

    return signals
end

local function AddPatrolDetectionSignal(signalType, coords, metadata)
    local cfg =
        Config.PatrolDetection or {}

    if cfg.enabled == false then
        return false, "disabled"
    end

    local signalConfig =
        cfg.signalTypes and cfg.signalTypes[signalType]

    if not signalConfig then
        return false, "invalidSignal"
    end

    local normalizedCoords =
        NormalizeCoords(coords)

    if not normalizedCoords then
        return false, "invalidSignal"
    end

    local signalId =
        NextDetectionSignalId

    NextDetectionSignalId =
        NextDetectionSignalId + 1
    metadata =
        metadata or {}

    local signal = {
        id = signalId,
        signalType = signalType,
        label = signalConfig.label or signalType,
        coords = normalizedCoords,
        sourceResource = metadata.sourceResource or metadata.resource or "unknown",
        metadata = metadata,
        createdAt = os.time(),
        expiresAt = os.time() + (metadata.ttlSeconds or 300),
        detected = false,
        detectedByPatrolId = nil,
        detectedAt = nil
    }

    PatrolDetectionSignals[signalId] =
        signal

    local signalCount =
        0

    for _ in pairs(PatrolDetectionSignals) do
        signalCount =
            signalCount + 1
    end

    if signalCount > (cfg.maxSignals or 50) then
        local oldestId =
            nil
        local oldestTime =
            os.time()

        for id, existing in pairs(PatrolDetectionSignals) do
            if existing.createdAt
            and existing.createdAt <= oldestTime then
                oldestTime =
                    existing.createdAt
                oldestId =
                    id
            end
        end

        if oldestId then
            PatrolDetectionSignals[oldestId] =
                nil
        end
    end

    DebugPatrolDetection("signal added", signalId, signalType)

    return true, signal
end

local function RollPatrolDetection(threatLevel)
    local cfg =
        Config.PatrolDetection or {}
    local chances =
        cfg.detectionChance or {}
    local chance =
        chances[threatLevel or "low"] or chances.low or 50
    local roll =
        math.random(1, 100)

    return roll <= chance, roll, chance
end

local function TrimIncidentRecords()
    local maxRecords =
        (Config.IncidentRecords and Config.IncidentRecords.maxRecords) or 100
    local ids = {}

    for id in pairs(incidentRecords) do
        ids[#ids + 1] =
            id
    end

    table.sort(ids)

    while #ids > maxRecords do
        local removeId =
            table.remove(ids, 1)

        incidentRecords[removeId] =
            nil
    end
end

local function IsValidIncidentStatus(status)
    local dispatchStatuses =
        Config.Dispatch and Config.Dispatch.statuses

    if dispatchStatuses then
        return dispatchStatuses[status] == true
    end

    return status == "open"
        or status == "assigned"
        or status == "responding"
        or status == "ai_assigned"
        or status == "ai_responding"
        or status == "patrol_dispatched"
        or status == "patrol_responding"
        or status == "patrol_arrived"
        or status == "patrol_on_scene"
        or status == "patrol_cleared"
        or status == "patrol_returning"
        or status == "closed"
        or status == "cancelled"
end

local function ThreatToScore(level)
    local data =
        Config.ThreatLevels[level]

    return data and data.score or 1
end

local function ScoreToThreat(score)
    score =
        tonumber(score) or 1

    if score >= 4 then
        return "deadly"
    end

    if score >= 3 then
        return "high"
    end

    if score >= 2 then
        return "medium"
    end

    return "low"
end

local function GetSafePlayerCoords(src)
    src =
        tonumber(src) or 0

    if src <= 0 then
        return nil
    end

    local ped =
        GetPlayerPed(src)

    if not ped
    or ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function GetOrganizationContext(src, alertData)
    local context = {
        available = false,
        suspectOrgId = nil,
        suspectOrgName = nil,
        suspectOrgType = nil,
        isKnownCriminalOrg = false,
        territoryId = nil,
        territoryOwnerOrgId = nil,
        territoryOwnerName = nil,
        territoryStatus = "unknown",
        isContestedTerritory = false,
        recentViolence = false,
        rivalConflict = false,
        riskModifier = 0
    }

    if not Config.OrganizationContext
    or not Config.OrganizationContext.enabled then
        return context
    end

    if GetResourceState("gs_organizations") ~= "started" then
        DebugPrint("gs_organizations not started; org context skipped")
        return context
    end

    local ok, result =
        pcall(function()
            return exports['gs_organizations']:GetPoliceContext(src, alertData)
        end)

    if ok
    and type(result) == "table" then
        context.available =
            true

        for key, value in pairs(result) do
            context[key] =
                value
        end
    elseif not ok then
        DebugPrint(("Organization context export unavailable: %s"):format(tostring(result)))
    end

    local modifiers =
        Config.OrganizationContext.modifiers or {}

    if context.isKnownCriminalOrg then
        context.riskModifier =
            context.riskModifier + (modifiers.knownCriminalOrg or 0)
    end

    if context.territoryOwnerOrgId then
        context.riskModifier =
            context.riskModifier + (modifiers.activeTerritory or 0)
    end

    if context.isContestedTerritory then
        context.riskModifier =
            context.riskModifier + (modifiers.contestedTerritory or 0)
    end

    if context.recentViolence then
        context.riskModifier =
            context.riskModifier + (modifiers.recentViolence or 0)
    end

    if context.rivalConflict then
        context.riskModifier =
            context.riskModifier + (modifiers.rivalConflict or 0)
    end

    return context
end

local function AssessThreat(src, alertData)
    if type(alertData) ~= "table" then
        alertData = {}
    end

    local incidentType =
        alertData.incidentType or "unknown"
    local incidentConfig =
        Config.IncidentTypes[incidentType] or {}
    local baseThreat =
        alertData.threatLevel or incidentConfig.baseThreat or "low"
    local threatScore =
        ThreatToScore(baseThreat)
    local orgContext =
        GetOrganizationContext(src, alertData)

    threatScore =
        threatScore + (orgContext.riskModifier or 0)

    if threatScore > 3 then
        threatScore =
            3
    end

    local response =
        alertData.preferredResponse or incidentConfig.response or "investigate"
    local forcePolicy =
        alertData.forcePolicy or incidentConfig.forcePolicy or "less_lethal_preferred"
    local unitsRecommended =
        tonumber(incidentConfig.unitsRecommended) or 1
    local backupRecommended =
        unitsRecommended > 1
    local factors =
        alertData.factors or {}

    for factorName, active in pairs(factors) do
        local rule =
            active and Config.EscalationRules[factorName] or nil

        if rule then
            if rule.setThreat then
                threatScore =
                    ThreatToScore(rule.setThreat)
            elseif rule.threatModifier then
                threatScore =
                    threatScore + rule.threatModifier
            end

            if rule.response then
                response =
                    rule.response
            end

            if rule.forcePolicy then
                forcePolicy =
                    rule.forcePolicy
            end

            if rule.backupRecommended then
                backupRecommended =
                    true
            end
        end
    end

    local finalThreat =
        ScoreToThreat(threatScore)
    local threatConfig =
        Config.ThreatLevels[finalThreat] or Config.ThreatLevels.low

    if finalThreat == "deadly" then
        forcePolicy =
            "deadly_force_authorized_if_necessary"
        backupRecommended =
            true
        unitsRecommended =
            math.max(unitsRecommended, 4)
    elseif finalThreat == "high" then
        backupRecommended =
            true
        unitsRecommended =
            math.max(unitsRecommended, 3)

        if forcePolicy == "less_lethal_preferred" then
            forcePolicy =
                "less_lethal_if_safe"
        end
    elseif finalThreat == "medium" then
        backupRecommended =
            true
        unitsRecommended =
            math.max(unitsRecommended, 2)
    end

    return {
        incidentType = incidentType,
        baseThreat = baseThreat,
        finalThreat = finalThreat,
        threatScore = threatScore,
        response = response or threatConfig.defaultResponse,
        forcePolicy = forcePolicy or threatConfig.forcePolicy,
        backupRecommended = backupRecommended,
        unitsRecommended = unitsRecommended,
        lessLethalPreferred = forcePolicy ~= "deadly_force_authorized_if_necessary",
        orgContext = orgContext,
        description = incidentConfig.description or alertData.message or "Police incident."
    }
end

local function ForwardToDispatch(incident)
    if GetResourceState("gs_dispatch") ~= "started" then
        DebugPrint("gs_dispatch not started; assessed incident retained locally")
        return
    end

    TriggerEvent("gs_dispatch:server:createPoliceIncident", incident)
end

local function NormalizeIncidentRecord(incident)
    local alertData =
        incident.alertData or {}
    local assessment =
        incident.assessment or {}
    local metadata =
        alertData.metadata or {}
    local orgContext =
        assessment.orgContext or {}

    local record = {
        id = incident.id,
        source = incident.source,
        sourceResource = alertData.sourceResource or incident.sourceResource or "unknown",
        incidentType = assessment.incidentType or alertData.incidentType or "unknown",
        title = alertData.title or "Police Incident",
        message = alertData.message or assessment.description or "Incident reported.",
        coords = alertData.coords,
        locationText = alertData.locationText or "Unknown",
        createdAt = incident.createdAt or os.time(),

        assessment = {
            baseThreat = assessment.baseThreat or "low",
            finalThreat = assessment.finalThreat or "low",
            threatScore = assessment.threatScore or 1,
            response = assessment.response or "investigate",
            forcePolicy = assessment.forcePolicy or "less_lethal_preferred",
            lessLethalPreferred = assessment.lessLethalPreferred == true,
            backupRecommended = assessment.backupRecommended == true,
            unitsRecommended = assessment.unitsRecommended or 1
        },

        orgContext = {
            available = orgContext.available == true,
            suspectOrgId = orgContext.suspectOrgId,
            suspectOrgName = orgContext.suspectOrgName,
            territoryOwnerOrgId = orgContext.territoryOwnerOrgId,
            territoryOwnerName = orgContext.territoryOwnerName,
            territoryStatus = orgContext.territoryStatus or "unknown",
            riskModifier = orgContext.riskModifier or 0
        },

        metadata = metadata,
        status = "open",
        assignedUnit = nil,
        dispatch = {
            assignedUnit = nil,
            assignedType = nil,
            assignedBy = nil,
            assignedByName = nil,
            assignedAt = nil,
            aiRequested = false,
            aiUnitType = nil,
            aiStatus = nil,
            aiTaskId = nil,
            aiLastUpdate = nil
        },
        dispatchPlan = {
            planKey = nil,
            label = nil,
            recommendedUnits = {},
            appliedAt = nil,
            appliedBy = nil,
            autoGenerated = false
        },
        notes = {}
    }

    EnsureDispatchFields(record)
    EnsureDispatchPlanFields(record)
    ApplyDispatchPlan(record, "Dispatch", true)

    return record
end

local function StoreIncident(src, alertData, assessment)
    if type(alertData) ~= "table" then
        alertData = {}
    end

    alertData.sourceResource =
        alertData.sourceResource or "unknown"

    incidentIdCounter =
        incidentIdCounter + 1

    local incident = {
        id = incidentIdCounter,
        source = src,
        sourceResource = alertData.sourceResource,
        alertData = alertData,
        assessment = assessment,
        createdAt = os.time()
    }

    recentIncidents[incident.id] =
        incident

    local record =
        NormalizeIncidentRecord(incident)

    incidentRecords[record.id] =
        record

    TrimIncidentRecords()

    DebugPrint(("Incident assessed id=%s sourceResource=%s type=%s finalThreat=%s force=%s"):format(
        incident.id,
        tostring(alertData.sourceResource),
        assessment.incidentType,
        assessment.finalThreat,
        assessment.forcePolicy
    ))

    TriggerEvent("gs_police:server:incidentAssessed", incident)
    TriggerEvent("gs_police:server:incidentRecorded", record)
    ForwardToDispatch(incident)

    return incident
end

local function CreateIncidentFromPatrolDetection(signal, patrol)
    if not signal
    or not patrol then
        return false, "invalidSignal"
    end

    local cfg =
        Config.PatrolDetection or {}
    local signalConfig =
        cfg.signalTypes and cfg.signalTypes[signal.signalType]

    if not signalConfig then
        return false, "invalidSignal"
    end

    local metadata =
        signal.metadata or {}

    metadata.detectedByPatrol =
        true
    metadata.detectedByPatrolId =
        patrol.patrolId
    metadata.detectedByPatrolZone =
        patrol.zoneKey
    metadata.detectedByPatrolLabel =
        patrol.zoneLabel
    metadata.detectionSignalId =
        signal.id

    local alertData = {
        incidentType = signalConfig.incidentType,
        type = signalConfig.incidentType,
        title = signal.label or "Patrol Detected Activity",
        message = ("Detected by %s."):format(patrol.zoneLabel or patrol.patrolId or "AI Patrol"),
        coords = signal.coords,
        sourceResource = "gs_police_patrol",
        metadata = metadata,
        escalation = metadata.escalation or {},
        patrolDetection = {
            signalId = signal.id,
            signalType = signal.signalType,
            patrolId = patrol.patrolId,
            zoneKey = patrol.zoneKey,
            zoneLabel = patrol.zoneLabel
        }
    }

    local assessment =
        AssessThreat(0, alertData)
    local incident =
        StoreIncident(0, alertData, assessment)
    local record =
        incident and GetIncidentRecordById(incident.id)

    if record then
        AddIncidentNote(record, "Patrol", ("Detected by %s."):format(patrol.zoneLabel or patrol.patrolId or "AI Patrol"))
        TriggerEvent("gs_police:server:incidentUpdated", record)

        if Config.PatrolDispatch
        and Config.PatrolDispatch.autoDispatchDetectedSignals then
            DispatchNearestPatrolToIncident(0, record.id)
        end

        return true, record
    end

    return false, "invalidSignal"
end

CreateThread(function()
    while true do
        local cfg =
            Config.PatrolDetection or {}

        Wait(cfg.scanIntervalMs or 5000)

        if cfg.enabled ~= false then
            local now =
                os.time()

            for signalId, signal in pairs(PatrolDetectionSignals) do
                if signal.expiresAt
                and signal.expiresAt <= now then
                    PatrolDetectionSignals[signalId] =
                        nil
                elseif not signal.detected then
                    local signalConfig =
                        cfg.signalTypes and cfg.signalTypes[signal.signalType]

                    if signalConfig then
                        local radius =
                            signalConfig.detectionRadius
                            or cfg.defaultDetectionRadius
                            or 85.0

                        for patrolId, patrol in pairs(ActivePatrolUnits or {}) do
                            if patrol
                            and patrol.coords then
                                local patrolCoords =
                                    NormalizeCoords(patrol.coords)
                                local distance =
                                    DistanceBetweenCoords(signal.coords, patrolCoords)

                                if distance <= radius then
                                    local cooldownKey =
                                        ("%s:%s"):format(patrolId, signal.signalType)
                                    local cooldownUntil =
                                        PatrolDetectionCooldowns[cooldownKey] or 0

                                    if cooldownUntil <= now then
                                        local threatLevel =
                                            signalConfig.threatLevel or "low"
                                        local detected =
                                            RollPatrolDetection(threatLevel)

                                        PatrolDetectionCooldowns[cooldownKey] =
                                            now + (
                                                signalConfig.cooldownSeconds
                                                or cfg.defaultCooldownSeconds
                                                or 90
                                            )

                                        if detected then
                                            signal.detected =
                                                true
                                            signal.detectedByPatrolId =
                                                patrolId
                                            signal.detectedAt =
                                                now

                                            CreateIncidentFromPatrolDetection(signal, patrol)

                                            DebugPatrolDetection(
                                                "signal detected",
                                                signalId,
                                                "by",
                                                patrolId,
                                                "distance",
                                                distance
                                            )

                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("gs_police:server:assessIncident", function(alertData)
    local src =
        source

    if (not src or src == 0)
    and type(alertData) == "table"
    and alertData.source then
        src =
            tonumber(alertData.source) or 0
    end

    local assessment =
        AssessThreat(src, alertData)

    StoreIncident(src, alertData, assessment)
end)

QBCore.Functions.CreateCallback("gs_police:server:getMdtData", function(source, cb)
    if not CanUsePoliceRecords(source) then
        cb({
            ok = false,
            message = (
                Config.IncidentRecords
                and Config.IncidentRecords.messages
                and Config.IncidentRecords.messages.denied
            )
            or "You are not authorized to access police incidents."
        })
        return
    end

    cb({
        ok = true,
        records = GetSerializedIncidentRecords(),
        patrols = GetActivePatrolUnits(),
        signals = GetPatrolDetectionSignals()
    })
end)

QBCore.Functions.CreateCallback("gs_police:server:updateMdtIncident", function(source, cb, payload)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        cb({
            ok = false,
            message = (
                Config.IncidentRecords
                and Config.IncidentRecords.messages
                and Config.IncidentRecords.messages.denied
            )
            or "You are not authorized to access police incidents."
        })
        return
    end

    if type(payload) ~= "table" then
        cb({ ok = false, message = "Invalid incident update." })
        return
    end

    local incidentId =
        tonumber(payload.incidentId or payload.id)

    if not incidentId then
        cb({
            success = false,
            ok = false,
            error = "invalidIncident",
            message = "Invalid incident."
        })
        return
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        cb({ ok = false, message = "Incident not found." })
        return
    end

    local action =
        payload.action

    if action == "assign" then
        local unit =
            tostring(payload.unit or "")
        local success, result =
            AssignIncidentToUnit(eventSource, incidentId, unit)

        if not success then
            local message =
                Config.Dispatch
                and Config.Dispatch.messages
                and Config.Dispatch.messages[result]
                or "Unable to assign incident."

            cb({ ok = false, success = false, message = message, error = result })
            return
        end

        record =
            result
    elseif action == "assign_ai" then
        local success, result =
            RequestAiUnitForIncident(eventSource, incidentId, payload.aiUnitType)

        if not success then
            local message =
                Config.Dispatch
                and Config.Dispatch.messages
                and Config.Dispatch.messages[result]
                or "Unable to request AI unit."

            cb({ ok = false, success = false, message = message, error = result })
            return
        end

        record =
            result
    elseif action == "dispatch_recommended" then
        local success, result =
            RequestRecommendedAiUnitsForIncident(eventSource, incidentId)

        if not success then
            local message =
                Config.DispatchEscalation
                and Config.DispatchEscalation.messages
                and Config.DispatchEscalation.messages[result]
                or "Unable to dispatch recommended unit."

            cb({ ok = false, success = false, message = message, error = result })
            return
        end

        record =
            result
    elseif action == "dispatch_patrol" then
        local success, result =
            DispatchNearestPatrolToIncident(eventSource, incidentId)

        if not success then
            local message =
                Config.PatrolDispatch
                and Config.PatrolDispatch.messages
                and Config.PatrolDispatch.messages[result]
                or "Unable to dispatch patrol."

            cb({ ok = false, success = false, message = message, error = result })
            return
        end

        record =
            result
    elseif action == "recalculate_plan" then
        if not ApplyDispatchPlan(record, GetOfficerName(eventSource), false) then
            cb({
                ok = false,
                success = false,
                error = "invalidPlan",
                message = "Unable to calculate dispatch recommendation."
            })
            return
        end

        TriggerEvent("gs_police:server:incidentUpdated", record)
    elseif action == "clear_ai" then
        if not record.dispatch
        or not record.dispatch.aiTaskId then
            cb({
                success = false,
                ok = false,
                error = "invalidTask",
                message = "No AI unit found for this incident."
            })
            return
        end

        TriggerClientEvent("gs_police:client:clearAiUnit", eventSource, record.dispatch.aiTaskId)
        TriggerEvent("gs_police:server:updateAiUnitStatus", record.dispatch.aiTaskId, "clearing", {
            incidentId = incidentId
        })

        cb({
            success = true,
            ok = true,
            incident = SerializeIncidentRecord(record),
            records = GetSerializedIncidentRecords(),
            patrols = GetActivePatrolUnits(),
            signals = GetPatrolDetectionSignals()
        })
        return
    elseif action == "note" then
        local noteText =
            tostring(payload.note or "")

        if noteText == "" then
            cb({ ok = false, message = "Note text is required." })
            return
        end

        AddIncidentNote(record, GetOfficerName(eventSource), noteText)
        TriggerEvent("gs_police:server:incidentUpdated", record)
    elseif action == "close" then
        record.status =
            "closed"
        TriggerEvent("gs_police:server:incidentUpdated", record)
    else
        cb({ ok = false, message = "Unsupported incident action." })
        return
    end

    cb({
        ok = true,
        success = true,
        record = SerializeIncidentRecord(record),
        incident = SerializeIncidentRecord(record),
        records = GetSerializedIncidentRecords(),
        patrols = GetActivePatrolUnits(),
        signals = GetPatrolDetectionSignals()
    })
end)

RegisterCommand("police_testincident", function(source, args)
    local src =
        source
    local incidentType =
        args[1] or "chopshop_activity"
    local alertData = {
        title = "Test Police Incident",
        message = "Testing police threat assessment.",
        incidentType = incidentType,
        threatLevel = "low",
        preferredResponse = "investigate",
        forcePolicy = "less_lethal_preferred",
        coords = GetSafePlayerCoords(src),
        source = src,
        sourceResource = "gs_police",
        factors = {}
    }
    local assessment =
        AssessThreat(src, alertData)

    StoreIncident(src, alertData, assessment)

    print("[gs_police] Test Incident Assessment:")
    print(json.encode(assessment))

    if src > 0 then
        TriggerClientEvent(
            "QBCore:Notify",
            src,
            ("Threat: %s | Response: %s | Force: %s"):format(
                assessment.finalThreat,
                assessment.response,
                assessment.forcePolicy
            ),
            "primary"
        )
    end
end, false)

RegisterCommand("police_testdeadly", function(source)
    local src =
        source
    local alertData = {
        incidentType = "chopshop_activity",
        threatLevel = "low",
        preferredResponse = "investigate",
        forcePolicy = "less_lethal_preferred",
        coords = GetSafePlayerCoords(src),
        source = src,
        sourceResource = "gs_police",
        factors = {
            shotsFired = true
        }
    }
    local assessment =
        AssessThreat(src, alertData)

    StoreIncident(src, alertData, assessment)

    print("[gs_police] Deadly Test Assessment:")
    print(json.encode(assessment))

    if src > 0 then
        TriggerClientEvent(
            "QBCore:Notify",
            src,
            ("Threat: %s | Force: %s"):format(
                assessment.finalThreat,
                assessment.forcePolicy
            ),
            "error"
        )
    end
end, false)

RegisterCommand("police_accesscheck", function(source)
    local allowed =
        CanUsePoliceRecords(source)

    if source == 0 then
        print(("[gs_police] police_accesscheck allowed=%s source=console"):format(tostring(allowed)))
        return
    end

    local Player =
        QBCore.Functions.GetPlayer(source)
    local jobName =
        "unknown"
    local onDuty =
        false

    if Player
    and Player.PlayerData
    and Player.PlayerData.job then
        jobName =
            Player.PlayerData.job.name or "unknown"
        onDuty =
            Player.PlayerData.job.onduty == true
    end

    print(("[gs_police] police_accesscheck src=%s allowed=%s job=%s onduty=%s"):format(
        source,
        tostring(allowed),
        jobName,
        tostring(onDuty)
    ))

    TriggerClientEvent(
        "QBCore:Notify",
        source,
        ("Police access: %s | Job: %s | Duty: %s"):format(
            tostring(allowed),
            jobName,
            tostring(onDuty)
        ),
        allowed and "success" or "error"
    )
end, false)

local function PrintIncidentDetail(record)
    print(("[gs_police] ===== Incident #%s ====="):format(record.id))
    print(("Status: %s"):format(record.status or "open"))
    print(("Created: %s"):format(FormatTimestamp(record.createdAt)))
    print(("Source: %s"):format(record.sourceResource or "unknown"))
    print(("Type: %s"):format(record.incidentType or "unknown"))
    print(("Title: %s"):format(record.title or "Police Incident"))
    print(("Message: %s"):format(record.message or "Incident reported."))
    print(("Coords: %s"):format(FormatCoords(record.coords)))
    print(("Threat: %s"):format(record.assessment and record.assessment.finalThreat or "unknown"))
    print(("Response: %s"):format(record.assessment and record.assessment.response or "unknown"))
    print(("Force Policy: %s"):format(record.assessment and record.assessment.forcePolicy or "unknown"))
    print(("Units: %s"):format(record.assessment and record.assessment.unitsRecommended or 1))
    print(("Less-lethal preferred: %s"):format(tostring(record.assessment and record.assessment.lessLethalPreferred == true)))

    if record.assignedUnit then
        print(("Assigned Unit: %s"):format(record.assignedUnit))
    end

    EnsureDispatchFields(record)
    print(("Dispatch Type: %s"):format(record.dispatch.assignedType or "None"))

    if record.dispatch.assignedByName then
        print(("Assigned By: %s"):format(record.dispatch.assignedByName))
    end

    if record.dispatch.assignedAt then
        print(("Assigned At: %s"):format(FormatTimestamp(record.dispatch.assignedAt)))
    end

    if record.dispatch.aiRequested then
        print(("AI Status: %s"):format(record.dispatch.aiStatus or "unknown"))
        print(("AI Task ID: %s"):format(record.dispatch.aiTaskId or "unknown"))
    end

    if record.orgContext and record.orgContext.available then
        print(("Org Context: suspectOrg=%s territoryOwner=%s status=%s risk=%s"):format(
            tostring(record.orgContext.suspectOrgId or "unknown"),
            tostring(record.orgContext.territoryOwnerOrgId or "unknown"),
            tostring(record.orgContext.territoryStatus or "unknown"),
            tostring(record.orgContext.riskModifier or 0)
        ))
    else
        print("Org Context: unavailable")
    end

    if Config.IncidentRecords
    and Config.IncidentRecords.showMetadataInConsole ~= false then
        print("Metadata:")

        local hasMetadata =
            false

        for key, value in pairs(record.metadata or {}) do
            hasMetadata =
                true
            print(("  %s = %s"):format(key, FormatValue(value)))
        end

        if not hasMetadata then
            print("  none")
        end
    end

    if record.notes and #record.notes > 0 then
        print("Notes:")

        for index, note in ipairs(record.notes) do
            print(("  %s. [%s] %s: %s"):format(
                index,
                FormatTimestamp(note.time or note.timestamp),
                tostring(note.author or "unknown"),
                note.text or note.note or ""
            ))
        end
    end

    print("[gs_police] =========================")
end

RegisterCommand("police_incidents", function(source)
    if not CanUsePoliceRecords(source) then
        DenyPoliceRecordAccess(source)
        return
    end

    print("[gs_police] Recent incident records:")

    local count =
        0

    local ids = {}

    for id in pairs(incidentRecords) do
        ids[#ids + 1] =
            id
    end

    table.sort(ids)

    for _, id in ipairs(ids) do
        local record =
            incidentRecords[id]

        count =
            count + 1

        print(("[gs_police] %s"):format(FormatIncidentLine(record)))
    end

    if count == 0 then
        print("[gs_police] No recent incident records.")
    end

    Notify(source, "Recent police incidents printed to console.", "primary")
end, false)

RegisterCommand("police_incident", function(source, args)
    if not CanUsePoliceRecords(source) then
        DenyPoliceRecordAccess(source)
        return
    end

    local id =
        tonumber(args[1])
    local record =
        id and incidentRecords[id] or nil

    if not record then
        print("[gs_police] Incident not found.")
        Notify(source, "Incident not found.", "error")
        return
    end

    PrintIncidentDetail(record)
    Notify(source, "Police incident printed to console.", "primary")
end, false)

RegisterCommand("police_closeincident", function(source, args)
    if not CanUsePoliceRecords(source) then
        DenyPoliceRecordAccess(source)
        return
    end

    local id =
        tonumber(args[1])
    local record =
        id and incidentRecords[id] or nil

    if not record then
        Notify(source, "Incident not found.", "error")
        return
    end

    record.status =
        "closed"
    TriggerEvent("gs_police:server:incidentUpdated", record)

    Notify(source, "Incident closed.", "success")
end, false)

RegisterCommand("police_assignincident", function(source, args)
    if not CanUsePoliceRecords(source) then
        DenyPoliceRecordAccess(source)
        return
    end

    local id =
        tonumber(args[1])
    local unit =
        args[2]

    if not unit or unit == "" then
        Notify(source, "Usage: /police_assignincident <id> <unit>", "error")
        return
    end

    local success, result =
        AssignIncidentToUnit(source, id, unit)

    if not success then
        local message =
            Config.Dispatch
            and Config.Dispatch.messages
            and Config.Dispatch.messages[result]
            or "Unable to assign incident."

        Notify(source, message, "error")
        return
    end

    Notify(source, "Incident assigned.", "success")
end, false)

RegisterCommand("police_dispatchai", function(source, args)
    local commandSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(commandSource) then
        DenyPoliceRecordAccess(commandSource)
        return
    end

    local incidentId =
        tonumber(args[1])
    local aiUnitType =
        args[2] or (Config.Dispatch and Config.Dispatch.defaultAiUnitType) or "patrol"

    if not incidentId then
        if commandSource == 0 then
            print("[gs_police] Usage: police_dispatchai <incidentId> <patrol|backup|supervisor>")
        else
            Notify(commandSource, "Usage: /police_dispatchai <incidentId> <patrol|backup|supervisor>", "error")
        end
        return
    end

    local success, result =
        RequestAiUnitForIncident(commandSource, incidentId, aiUnitType)

    if not success then
        local message =
            Config.Dispatch
            and Config.Dispatch.messages
            and Config.Dispatch.messages[result]
            or "Unable to request AI unit."

        if commandSource == 0 then
            print(("[gs_police] %s"):format(message))
        else
            Notify(commandSource, message, "error")
        end
        return
    end

    if commandSource == 0 then
        print("[gs_police] AI unit requested for incident.")
    else
        Notify(commandSource, "AI unit requested for incident.", "success")
    end
end, false)

RegisterCommand("police_recommend", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local incidentId =
        tonumber(args[1])

    if not incidentId then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_recommend <incidentId>", "error")
        else
            print("[gs_police] Usage: police_recommend <incidentId>")
        end
        return
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record then
        if eventSource > 0 then
            Notify(eventSource, "Invalid incident.", "error")
        else
            print("[gs_police] Invalid incident.")
        end
        return
    end

    if not ApplyDispatchPlan(record, GetOfficerName(eventSource), false) then
        if eventSource > 0 then
            Notify(eventSource, "Unable to calculate dispatch recommendation.", "error")
        else
            print("[gs_police] Unable to calculate dispatch recommendation.")
        end
        return
    end

    TriggerEvent("gs_police:server:incidentUpdated", record)

    if eventSource > 0 then
        Notify(eventSource, "Dispatch recommendation updated.", "success")
    else
        print("[gs_police] Dispatch recommendation updated.")
    end
end, false)

RegisterCommand("police_dispatchrecommended", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local incidentId =
        tonumber(args[1])

    if not incidentId then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_dispatchrecommended <incidentId>", "error")
        else
            print("[gs_police] Usage: police_dispatchrecommended <incidentId>")
        end
        return
    end

    local success, result =
        RequestRecommendedAiUnitsForIncident(eventSource, incidentId)

    if not success then
        local message =
            Config.DispatchEscalation
            and Config.DispatchEscalation.messages
            and Config.DispatchEscalation.messages[result]
            or "Unable to dispatch recommended unit."

        if eventSource > 0 then
            Notify(eventSource, message, "error")
        else
            print("[gs_police] " .. message)
        end
        return
    end

    if eventSource > 0 then
        Notify(eventSource, "Recommended AI unit dispatched.", "success")
    else
        print("[gs_police] Recommended AI unit dispatched.")
    end
end, false)

RegisterCommand("police_clearincidentai", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local incidentId =
        tonumber(args[1])

    if not incidentId then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_clearincidentai <incidentId>", "error")
        else
            print("[gs_police] Usage: police_clearincidentai <incidentId>")
        end
        return
    end

    local record =
        GetIncidentRecordById(incidentId)

    if not record
    or not record.dispatch
    or not record.dispatch.aiTaskId then
        if eventSource > 0 then
            Notify(eventSource, "No AI unit found for this incident.", "error")
        else
            print("[gs_police] No AI unit found for this incident.")
        end
        return
    end

    local taskId =
        record.dispatch.aiTaskId

    if eventSource > 0 then
        TriggerClientEvent("gs_police:client:clearAiUnit", eventSource, taskId)
        Notify(eventSource, "AI clear requested.", "success")
    else
        print(("[gs_police] AI clear requested for incident %s task %s"):format(incidentId, taskId))
    end

    TriggerEvent("gs_police:server:updateAiUnitStatus", taskId, "clearing", {
        incidentId = incidentId
    })
end, false)

RegisterCommand("police_spawnpatrol", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local zoneKey =
        args[1]

    if not zoneKey
    or zoneKey == "" then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_spawnpatrol <zoneKey>", "error")
        else
            print("[gs_police] Usage: police_spawnpatrol <zoneKey>")
        end
        return
    end

    if not Config.AIPatrol
    or not Config.AIPatrol.zones
    or not Config.AIPatrol.zones[zoneKey] then
        if eventSource > 0 then
            Notify(eventSource, "Invalid patrol zone.", "error")
        else
            print("[gs_police] Invalid patrol zone.")
        end
        return
    end

    if eventSource > 0 then
        TriggerClientEvent("gs_police:client:spawnPatrolUnit", eventSource, zoneKey)
    else
        print("[gs_police] Console cannot spawn client-owned patrol yet. Use this command in-game.")
    end
end, false)

RegisterCommand("police_clearpatrols", function(source)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    if eventSource > 0 then
        TriggerClientEvent("gs_police:client:clearPatrols", eventSource)
        Notify(eventSource, "AI patrol clear requested.", "success")
    else
        ActivePatrolUnits =
            {}
        print("[gs_police] Patrol state cleared server-side. Client-owned patrols require in-game clear.")
    end
end, false)

RegisterCommand("police_patrols", function(source)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local patrols =
        GetActivePatrolUnits()

    if eventSource == 0 then
        print(("[gs_police] Active patrols: %s"):format(#patrols))

        for _, patrol in ipairs(patrols) do
            print(("[gs_police] %s | zone=%s | status=%s | mode=%s | waypoint=%s | incident=%s"):format(
                patrol.patrolId,
                patrol.zoneKey or "unknown",
                patrol.status or "unknown",
                patrol.mode or "patrol",
                tostring(patrol.waypointIndex or "n/a"),
                tostring(patrol.assignedIncidentId or "none")
            ))
        end
        return
    end

    Notify(eventSource, ("Active patrols: %s"):format(#patrols), "primary")

    for _, patrol in ipairs(patrols) do
        TriggerClientEvent("chat:addMessage", eventSource, {
            args = {
                "GS Police",
                ("%s | %s | %s | waypoint %s"):format(
                    patrol.patrolId,
                    patrol.zoneLabel or patrol.zoneKey or "unknown",
                    ("%s/%s"):format(patrol.status or "unknown", patrol.mode or "patrol"),
                    tostring(patrol.waypointIndex or "n/a")
                )
            }
        })
    end
end, false)

RegisterCommand("police_dispatchpatrol", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local incidentId =
        tonumber(args[1])

    if not incidentId then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_dispatchpatrol <incidentId>", "error")
        else
            print("[gs_police] Usage: police_dispatchpatrol <incidentId>")
        end
        return
    end

    local success, result =
        DispatchNearestPatrolToIncident(eventSource, incidentId)

    if not success then
        local message =
            Config.PatrolDispatch
            and Config.PatrolDispatch.messages
            and Config.PatrolDispatch.messages[result]
            or "Unable to dispatch patrol."

        if eventSource > 0 then
            Notify(eventSource, message, "error")
        else
            print("[gs_police] " .. message)
        end
        return
    end

    if eventSource > 0 then
        Notify(eventSource, Config.PatrolDispatch.messages.patrolDispatched or "Nearby patrol dispatched.", "success")
    else
        print("[gs_police] Nearby patrol dispatched.")
    end
end, false)

RegisterCommand("police_returnpatrol", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local patrolId =
        args[1]

    if not patrolId
    or patrolId == "" then
        if eventSource > 0 then
            Notify(eventSource, "Usage: /police_returnpatrol <patrolId>", "error")
        else
            print("[gs_police] Usage: police_returnpatrol <patrolId>")
        end
        return
    end

    TriggerClientEvent("gs_police:client:returnPatrolToRoute", -1, patrolId)

    if ActivePatrolUnits
    and ActivePatrolUnits[patrolId] then
        ActivePatrolUnits[patrolId].mode =
            "returning"
        ActivePatrolUnits[patrolId].status =
            "returning"
    end

    if eventSource > 0 then
        Notify(eventSource, "Patrol return requested.", "success")
    else
        print("[gs_police] Patrol return requested.")
    end
end, false)

RegisterCommand("police_addsignal", function(source, args)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local signalType =
        args[1] or "suspicious_activity"

    if eventSource <= 0 then
        print("[gs_police] police_addsignal must be run in-game so player coords can be used.")
        return
    end

    local ped =
        GetPlayerPed(eventSource)

    if not ped
    or ped == 0 then
        Notify(eventSource, "Unable to get player position.", "error")
        return
    end

    local coords =
        GetEntityCoords(ped)
    local success, result =
        AddPatrolDetectionSignal(signalType, coords, {
            sourceResource = "test_command",
            createdBy = eventSource
        })

    if not success then
        local message =
            Config.PatrolDetection
            and Config.PatrolDetection.messages
            and Config.PatrolDetection.messages[result]
            or "Unable to add signal."

        Notify(eventSource, message, "error")
        return
    end

    Notify(eventSource, "Patrol detection signal added.", "success")
end, false)

RegisterCommand("police_signals", function(source)
    local eventSource =
        tonumber(source) or 0

    if not CanUsePoliceRecords(eventSource) then
        DenyPoliceRecordAccess(eventSource)
        return
    end

    local count =
        0

    for _, signal in pairs(PatrolDetectionSignals) do
        count =
            count + 1

        local line =
            ("Signal #%s | %s | detected=%s | patrol=%s"):format(
                signal.id,
                signal.signalType,
                tostring(signal.detected),
                tostring(signal.detectedByPatrolId or "none")
            )

        if eventSource > 0 then
            TriggerClientEvent("chat:addMessage", eventSource, {
                args = { "GS Police", line }
            })
        else
            print("[gs_police] " .. line)
        end
    end

    if eventSource > 0 then
        Notify(eventSource, ("Signals: %s"):format(count), "primary")
    else
        print(("[gs_police] Signals: %s"):format(count))
    end
end, false)

RegisterCommand("police_noteincident", function(source, args)
    if not CanUsePoliceRecords(source) then
        DenyPoliceRecordAccess(source)
        return
    end

    local id =
        tonumber(args[1])
    local record =
        id and incidentRecords[id] or nil

    if not record then
        Notify(source, "Incident not found.", "error")
        return
    end

    table.remove(args, 1)

    local noteText =
        table.concat(args, " ")

    if noteText == "" then
        Notify(source, "Usage: /police_noteincident <id> <note>", "error")
        return
    end

    AddIncidentNote(record, GetOfficerName(source), noteText)
    TriggerEvent("gs_police:server:incidentUpdated", record)

    Notify(source, "Incident note added.", "success")
end, false)

exports("AssessThreat", function(src, alertData)
    return AssessThreat(src, alertData)
end)

exports("GetRecentIncidents", function()
    return recentIncidents
end)

exports("GetIncidentRecords", function()
    return incidentRecords
end)

exports("GetIncidentRecord", function(id)
    return incidentRecords[tonumber(id)]
end)

exports("UpdateIncidentStatus", function(id, status)
    local record =
        incidentRecords[tonumber(id)]

    if not record
    or not IsValidIncidentStatus(status) then
        return false
    end

    record.status =
        status

    return true
end)

exports("RequestAiUnitForIncident", function(src, incidentId, aiUnitType)
    return RequestAiUnitForIncident(src or 0, incidentId, aiUnitType)
end)

exports("AssignIncidentToUnit", function(src, incidentId, unitName)
    return AssignIncidentToUnit(src or 0, incidentId, unitName)
end)

exports("GetDispatchPlanForIncident", function(record)
    return GetDispatchPlanForIncident(record)
end)

exports("ApplyDispatchPlan", function(record, appliedBy, autoGenerated)
    return ApplyDispatchPlan(record, appliedBy, autoGenerated)
end)

exports("RequestRecommendedAiUnitsForIncident", function(src, incidentId)
    return RequestRecommendedAiUnitsForIncident(src or 0, incidentId)
end)

exports("GetActivePatrolUnits", function()
    return GetActivePatrolUnits()
end)

exports("DispatchNearestPatrolToIncident", function(src, incidentId)
    return DispatchNearestPatrolToIncident(src or 0, incidentId)
end)

exports("AddPatrolDetectionSignal", function(signalType, coords, metadata)
    return AddPatrolDetectionSignal(signalType, coords, metadata)
end)

CreateThread(function()
    print("[gs_police] Threat assessment policy layer initialized.")
end)
