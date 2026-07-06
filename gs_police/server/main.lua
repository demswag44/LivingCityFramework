local QBCore =
    exports['qb-core']:GetCoreObject()

local recentIncidents = {}
local incidentRecords = {}
local incidentIdCounter = 0

local function DebugPrint(message)
    if Config.Debug then
        print("[gs_police] " .. message)
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
        return nil
    end

    return {
        x = x,
        y = y,
        z = z
    }
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
    elseif status == "failed" then
        record.status =
            "ai_failed"
        AddIncidentNote(record, "AI Dispatch", ("AI unit failed to respond: %s."):format(data.reason or "unknown"))
    elseif status == "cleared" then
        record.status =
            "closed"
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
        dispatch = SanitizeForNui(record.dispatch or {})
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
        notes = {}
    }

    EnsureDispatchFields(record)

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
        records = GetSerializedIncidentRecords()
    })
end)

QBCore.Functions.CreateCallback("gs_police:server:updateMdtIncident", function(source, cb, payload)
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
            AssignIncidentToUnit(source, incidentId, unit)

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
            RequestAiUnitForIncident(source, incidentId, payload.aiUnitType)

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
    elseif action == "note" then
        local noteText =
            tostring(payload.note or "")

        if noteText == "" then
            cb({ ok = false, message = "Note text is required." })
            return
        end

        AddIncidentNote(record, GetOfficerName(source), noteText)
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
        records = GetSerializedIncidentRecords()
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

CreateThread(function()
    print("[gs_police] Threat assessment policy layer initialized.")
end)
