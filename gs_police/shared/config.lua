Config = Config or {}

Config.Debug = false
Config.CityBrainIntegrationEnabled = true
Config.CityBrainReadRecommendationsEnabled = true
Config.CityBrainPoliceResponseEnabled = true
Config.CityBrainPatrolBiasEnabled = true
Config.CityBrainPatrolPressureTuningEnabled = true
Config.CityBrainShotsFiredCooldownMs = 10000

Config.WeatherIntegration = Config.WeatherIntegration or {}
Config.WeatherIntegration.Enabled = true
Config.WeatherIntegration.Debug = false
Config.WeatherIntegration.ResourceName = 'gs_world'

Config.WeatherIntegration.VisibilityEnabled = true
Config.WeatherIntegration.WitnessEnabled = true
Config.WeatherIntegration.ResponseDelayEnabled = true
Config.WeatherIntegration.RoadRiskEnabled = true
Config.WeatherIntegration.TrafficEnabled = true

Config.WeatherIntegration.MinVisibilityModifier = 0.35
Config.WeatherIntegration.MaxResponseDelayMs = 20000
Config.WeatherIntegration.MaxRoadRiskModifier = 2.5

Config.IncidentRecords = {
    enabled = true,
    maxRecords = 100,
    resetOnRestart = true,
    showMetadataInConsole = true,
    restrictToPolice = true,
    requireOnDuty = true,
    allowServerConsole = true,
    allowAceBypass = true,
    acePermission = "gs_police.incidents",

    policeJobs = {
        police = true,
        sheriff = true,
        state = true
    },

    messages = {
        denied = "You are not authorized to access police incidents.",
        noPlayer = "Unable to verify your police access."
    }
}

-- Optional ACE bypass:
-- add_ace group.admin gs_police.incidents allow

Config.Dispatch = {
    enabled = true,
    aiUnitsEnabled = true,
    defaultAiUnitType = "patrol",

    aiUnitTypes = {
        patrol = {
            label = "AI Patrol Unit",
            responseStatus = "ai_assigned",
            note = "AI patrol unit requested."
        },
        backup = {
            label = "AI Backup Unit",
            responseStatus = "ai_assigned",
            note = "AI backup unit requested."
        },
        supervisor = {
            label = "AI Supervisor Unit",
            responseStatus = "ai_assigned",
            note = "AI supervisor unit requested."
        }
    },

    statuses = {
        open = true,
        assigned = true,
        responding = true,
        ai_assigned = true,
        ai_responding = true,
        ai_arrived = true,
        ai_investigating = true,
        ai_staging = true,
        ai_containing = true,
        ai_clearing = true,
        ai_cleared = true,
        ai_failed = true,
        patrol_dispatched = true,
        patrol_responding = true,
        patrol_arrived = true,
        patrol_on_scene = true,
        patrol_cleared = true,
        patrol_returning = true,
        pursuit_active = true,
        pursuit_lost = true,
        felony_stop = true,
        pursuit_cleared = true,
        suspect_vehicle_occupied = true,
        suspect_vehicle_empty = true,
        suspect_vehicle_missing = true,
        issuing_commands = true,
        holding_position = true,
        suspect_compliant = true,
        suspect_detained = true,
        suspect_refused = true,
        suspect_fled = true,
        foot_pursuit = true,
        searching_last_known = true,
        contact_suspect = true,
        suspect_lost = true,
        no_suspect_found = true,
        closed = true,
        cancelled = true
    },

    messages = {
        aiAssigned = "AI unit requested for incident.",
        playerAssigned = "Incident assigned.",
        invalidIncident = "Invalid incident.",
        invalidUnit = "Invalid unit.",
        dispatchDisabled = "Dispatch system is disabled."
    }
}

Config.PatrolDispatch = Config.PatrolDispatch or {}

Config.PatrolDispatch.enabled = true
Config.PatrolDispatch.debug = true

Config.PatrolDispatch.maxDispatchDistance = 450.0
Config.PatrolDispatch.arrivalDistance = 28.0
Config.PatrolDispatch.driveSpeed = 32.0
Config.PatrolDispatch.drivingStyle = 786603

Config.PatrolDispatch.allowFallbackAiSpawn = false
Config.PatrolDispatch.returnToPatrolAfterClear = true
Config.PatrolDispatch.autoDispatchDetectedSignals = false

Config.PatrolDispatch.emergencyResponse = {
    enabled = true,

    useSirenForThreats = {
        high = true,
        deadly = true
    },

    useSirenForIncidentTypes = {
        shots_fired = true,
        armed_suspect = true,
        officer_needs_help = true
    },

    emergencyDriveSpeed = 44.0,
    normalDriveSpeed = 32.0
}

Config.PatrolDispatch.scene = Config.PatrolDispatch.scene or {}

Config.PatrolDispatch.scene.keepEmergencyLightsOnArrival = true
Config.PatrolDispatch.scene.muteSirenOnArrival = true
Config.PatrolDispatch.scene.autoReturnAfterSeconds = 60
Config.PatrolDispatch.scene.autoReturnEnabled = true
Config.PatrolDispatch.scene.getBackInVehicleTimeoutMs = 10000

Config.PatrolDispatch.statuses = {
    patrol_dispatched = true,
    patrol_responding = true,
    patrol_arrived = true,
    patrol_on_scene = true,
    patrol_cleared = true,
    patrol_returning = true,
    pursuit_active = true,
    pursuit_lost = true,
    felony_stop = true,
    pursuit_cleared = true,
    suspect_vehicle_occupied = true,
    suspect_vehicle_empty = true,
    suspect_vehicle_missing = true,
    issuing_commands = true,
    holding_position = true,
    suspect_compliant = true,
    suspect_detained = true,
    suspect_refused = true,
    suspect_fled = true,
    foot_pursuit = true,
    searching_last_known = true,
    contact_suspect = true,
    suspect_lost = true,
    no_suspect_found = true
}

Config.PatrolDispatch.messages = {
    disabled = "Patrol dispatch is disabled.",
    noIncident = "Invalid incident.",
    noPatrolAvailable = "No available patrol unit nearby.",
    patrolDispatched = "Nearby patrol dispatched.",
    patrolArrived = "Patrol arrived on scene.",
    patrolCleared = "Patrol cleared from incident.",
    invalidPatrol = "Invalid patrol unit."
}

Config.MovingTargets = Config.MovingTargets or {}

Config.MovingTargets.enabled = true
Config.MovingTargets.debug = true

Config.MovingTargets.updateIntervalMs = 2000
Config.MovingTargets.staleAfterSeconds = 30
Config.MovingTargets.expireAfterSeconds = 180
Config.MovingTargets.maxTargets = 50

Config.MovingTargets.trackableSignalTypes = {
    stolen_vehicle_activity = true,
    suspect_vehicle = true,
    fleeing_vehicle = true
}

Config.MovingTargets.trackableIncidentTypes = {
    stolen_vehicle_delivery = true,
    stolen_vehicle_activity = true,
    suspect_vehicle = true,
    fleeing_vehicle = true
}

Config.MovingTargets.messages = {
    targetAdded = "Moving target added.",
    targetUpdated = "Moving target updated.",
    targetLost = "Moving target lost. Using last known location.",
    targetExpired = "Moving target expired.",
    invalidTarget = "Invalid moving target."
}

Config.Pursuit = Config.Pursuit or {}

Config.Pursuit.enabled = true
Config.Pursuit.debug = true

Config.Pursuit.followDistance = 18.0
Config.Pursuit.arrivalDistance = 28.0
Config.Pursuit.updateRouteIntervalMs = 2000

Config.Pursuit.driveSpeed = 55.0
Config.Pursuit.drivingStyle = 786603

Config.Pursuit.useSiren = true
Config.Pursuit.keepLightsOn = true

Config.Pursuit.targetStoppedSpeedMps = 0.8
Config.Pursuit.targetStoppedSeconds = 6
Config.Pursuit.felonyStopDistance = 18.0

Config.Pursuit.maxPursuitSeconds = 300
Config.Pursuit.returnToPatrolAfterClear = true

Config.Pursuit.trackIncidentTypes = {
    stolen_vehicle_delivery = true,
    stolen_vehicle_activity = true,
    suspect_vehicle = true,
    fleeing_vehicle = true
}

Config.Pursuit.messages = {
    disabled = "Pursuit system is disabled.",
    noMovingTarget = "Incident has no moving target.",
    pursuitStarted = "Patrol is pursuing moving target.",
    felonyStop = "Patrol is staging a felony stop.",
    pursuitCleared = "Pursuit cleared.",
    invalidIncident = "Invalid incident."
}

Config.EmergencyDriving = Config.EmergencyDriving or {}

Config.EmergencyDriving.enabled = true
Config.EmergencyDriving.debug = true

Config.EmergencyDriving.driveSpeed = 55.0
Config.EmergencyDriving.drivingStyle = 1074528293

Config.EmergencyDriving.repathIntervalMs = 2500
Config.EmergencyDriving.stuckCheckIntervalMs = 3000
Config.EmergencyDriving.stuckSpeedThreshold = 1.0
Config.EmergencyDriving.stuckSecondsBeforeRepath = 6

Config.EmergencyDriving.moveOverEnabled = true
Config.EmergencyDriving.moveOverRadius = 40.0
Config.EmergencyDriving.moveOverCooldownMs = 2500

Config.EmergencyDriving.overtakeOffsetDistance = 8.0
Config.EmergencyDriving.overtakeForwardDistance = 35.0

Config.EmergencyDriving.messages = {
    repath = "Emergency unit repathing around traffic.",
    stuck = "Emergency unit appears blocked."
}

Config.PursuitTuning = Config.PursuitTuning or {}

Config.PursuitTuning.enabled = true
Config.PursuitTuning.debug = true

Config.PursuitTuning.routeUpdateIntervalMs = 1500

Config.PursuitTuning.speedByDistance = {
    far = {
        distance = 160.0,
        speed = 34.0
    },
    medium = {
        distance = 75.0,
        speed = 28.0
    },
    close = {
        distance = 35.0,
        speed = 20.0
    },
    stopApproach = {
        distance = 18.0,
        speed = 10.0
    }
}

Config.PursuitTuning.drivingStyle = 1074528293
Config.PursuitTuning.closeDrivingStyle = 786603

Config.PursuitTuning.maxCrashSpeedNearTarget = 18.0
Config.PursuitTuning.followDistance = 22.0

Config.PursuitTuning.arrival = {
    enabled = true,
    parkBehindDistance = 13.0,
    parkSideOffset = -3.5,
    parkAngleOffset = 8.0,
    arrivalDistance = 18.0,
    finalStopDistance = 12.0,
    useTempBrakeMs = 2500,
    keepLightsOn = true,
    muteSiren = true
}

Config.PursuitTuning.felonyStop = Config.PursuitTuning.felonyStop or {}

Config.PursuitTuning.felonyStop.requireCloseDistance = true
Config.PursuitTuning.felonyStop.triggerDistance = 35.0
Config.PursuitTuning.felonyStop.finalParkingDistance = 18.0
Config.PursuitTuning.felonyStop.requireRecentTargetUpdate = true
Config.PursuitTuning.felonyStop.maxTargetUpdateAgeSeconds = 8

Config.PursuitTuning.stuck = {
    enabled = true,
    checkIntervalMs = 2500,
    minSpeed = 1.0,
    stuckAfterSeconds = 5,
    repathSideOffset = 8.0,
    repathForwardDistance = 35.0,
    maxRepathAttempts = 5
}

Config.PursuitTuning.messages = {
    pursuitTuned = "Pursuit route updated.",
    parking = "Patrol positioning for felony stop.",
    stuckRepath = "Pursuit unit repathing."
}

Config.SuspectInteraction = Config.SuspectInteraction or {}

Config.SuspectInteraction.enabled = true
Config.SuspectInteraction.debug = true

Config.SuspectInteraction.vehicleCheckRadius = 30.0
Config.SuspectInteraction.commandDistance = 12.0
Config.SuspectInteraction.coverDistance = 9.0

Config.SuspectInteraction.commandDurationSeconds = 20
Config.SuspectInteraction.emptyVehicleInvestigateSeconds = 20
Config.SuspectInteraction.autoReturnAfterInteraction = true

Config.SuspectInteraction.behaviors = {
    occupied_vehicle = {
        label = "Vehicle Occupied",
        status = "suspect_vehicle_occupied",
        note = "Officer identified an occupied suspect vehicle and is issuing commands."
    },

    empty_vehicle = {
        label = "Vehicle Empty",
        status = "suspect_vehicle_empty",
        note = "Officer found the suspect vehicle empty and is investigating."
    },

    vehicle_missing = {
        label = "Vehicle Missing",
        status = "suspect_vehicle_missing",
        note = "Officer could not locate the suspect vehicle at the last known location."
    },

    command_stage = {
        label = "Issuing Commands",
        status = "issuing_commands",
        note = "Officer is issuing commands to the suspect vehicle."
    },

    holding_position = {
        label = "Holding Position",
        status = "holding_position",
        note = "Officer is holding position and awaiting further instructions."
    }
}

Config.SuspectInteraction.messages = {
    occupied = "Suspect vehicle occupied.",
    empty = "Suspect vehicle empty.",
    missing = "Suspect vehicle missing.",
    commands = "Officer issuing commands.",
    holding = "Officer holding position."
}

Config.SuspectCompliance = Config.SuspectCompliance or {}

Config.SuspectCompliance.enabled = true
Config.SuspectCompliance.debug = true

Config.SuspectCompliance.commandDelaySeconds = 4
Config.SuspectCompliance.complianceDurationSeconds = 20
Config.SuspectCompliance.detainedHoldSeconds = 30
Config.SuspectCompliance.autoReturnAfterDetention = true

Config.SuspectCompliance.outcomeChance = {
    low = {
        comply = 75,
        refuse = 20,
        flee = 5
    },

    medium = {
        comply = 55,
        refuse = 30,
        flee = 15
    },

    high = {
        comply = 35,
        refuse = 35,
        flee = 30
    },

    deadly = {
        comply = 20,
        refuse = 30,
        flee = 50
    }
}

Config.SuspectCompliance.behaviors = {
    compliant = {
        label = "Compliant",
        status = "suspect_compliant",
        note = "Suspect complied with officer commands."
    },

    detained = {
        label = "Detained",
        status = "suspect_detained",
        note = "Suspect is detained at the scene."
    },

    refused = {
        label = "Refused Commands",
        status = "suspect_refused",
        note = "Suspect refused officer commands and remains in vehicle."
    },

    fled = {
        label = "Fled",
        status = "suspect_fled",
        note = "Suspect fled from the stop."
    },

    no_suspect = {
        label = "No Suspect Found",
        status = "no_suspect_found",
        note = "No suspect was located at the scene."
    }
}

Config.SuspectCompliance.messages = {
    compliant = "Suspect complied.",
    detained = "Suspect detained.",
    refused = "Suspect refused commands.",
    fled = "Suspect fled.",
    noSuspect = "No suspect found."
}

Config.Telemetry = Config.Telemetry or {}

Config.Telemetry.enabled = true
Config.Telemetry.debug = true

Config.Telemetry.includeCoords = true
Config.Telemetry.includeIncidents = true
Config.Telemetry.includePatrols = true
Config.Telemetry.includeMovingTargets = true
Config.Telemetry.includeDetectionSignals = true
Config.Telemetry.includeAiResponseUnits = true

Config.Telemetry.maxIncidents = 20
Config.Telemetry.maxSignals = 20
Config.Telemetry.maxPatrols = 20
Config.Telemetry.maxTargets = 20

Config.Telemetry.printPretty = true

-- File writing may not work in all environments depending on resource permissions.
-- Keep it optional and guarded.
Config.Telemetry.writeFileEnabled = true
Config.Telemetry.fileName = "runtime_state.json"

Config.Telemetry.messages = {
    disabled = "Telemetry is disabled.",
    dumped = "Telemetry dumped.",
    written = "Telemetry file written.",
    failed = "Telemetry failed."
}

Config.ResponseCodes = Config.ResponseCodes or {}

Config.ResponseCodes.enabled = true
Config.ResponseCodes.debug = true

Config.ResponseCodes.codes = {
    code1 = {
        label = "Code 1",
        description = "Routine response. No lights or siren. Obey traffic laws but move with purpose.",
        lights = false,
        siren = false,
        mutedSiren = true,
        driveSpeed = 22.0,
        drivingStyle = 786603,
        obeyTraffic = true,
        trafficYield = false,
        trafficYieldRadius = 0.0,
        urgency = 1
    },

    code2 = {
        label = "Code 2",
        description = "Urgent response. Lights only, due regard.",
        lights = true,
        siren = false,
        mutedSiren = true,
        driveSpeed = 32.0,
        drivingStyle = 1074528293,
        obeyTraffic = false,
        trafficYield = true,
        trafficYieldRadius = 35.0,
        urgency = 2
    },

    code3 = {
        label = "Code 3",
        description = "Emergency response. Lights and siren.",
        lights = true,
        siren = true,
        mutedSiren = false,
        driveSpeed = 55.0,
        drivingStyle = 1074528293,
        obeyTraffic = false,
        trafficYield = true,
        trafficYieldRadius = 55.0,
        urgency = 3
    }
}

Config.ResponseCodes.threatDefaults = {
    low = "code1",
    medium = "code2",
    high = "code3",
    deadly = "code3"
}

Config.ResponseCodes.incidentOverrides = {
    blackmarket_activity = "code1",
    shadowmarket_order = "code1",
    shadowmarket_pickup = "code2",
    chopshop_activity = "code2",
    stolen_vehicle_delivery = "code2",
    stolen_vehicle_activity = "code2",
    suspect_vehicle = "code2",
    fleeing_vehicle = "code3",
    shots_fired = "code3",
    officer_needs_help = "code3",
    armed_suspect = "code3",
    robbery_in_progress = "code3",
    citizen_threatened = "code2",
    vehicle_used_as_weapon = "code3"
}

Config.CitizenBehavior = Config.CitizenBehavior or {}

Config.CitizenBehavior.enabled = true
Config.CitizenBehavior.debug = true

Config.CitizenBehavior.scanIntervalMs = 750
Config.CitizenBehavior.playerThreatRadius = 35.0
Config.CitizenBehavior.shotsRadius = 75.0
Config.CitizenBehavior.robberyThreatDistance = 12.0

Config.CitizenBehavior.cooldowns = {
    weaponThreatSeconds = 10,
    shotsFiredSeconds = 20,
    robberySeconds = 20,
    citizenReportSeconds = 30
}

Config.CitizenBehavior.reactionChance = {
    normal = {
        comply = 45,
        flee = 35,
        freeze = 10,
        fight = 8,
        armedDefense = 2
    },

    tough = {
        comply = 25,
        flee = 25,
        freeze = 10,
        fight = 25,
        armedDefense = 15
    },

    fearful = {
        comply = 35,
        flee = 50,
        freeze = 10,
        fight = 4,
        armedDefense = 1
    },

    criminal = {
        comply = 15,
        flee = 35,
        freeze = 5,
        fight = 25,
        armedDefense = 20
    }
}

Config.CitizenBehavior.defaultProfile = "normal"

Config.CitizenBehavior.armedDefense = {
    enabled = true,
    maxChance = 20,
    weaponModels = {
        "WEAPON_PISTOL",
        "WEAPON_SNSPISTOL"
    }
}

Config.CitizenBehavior.reporting = {
    enabled = true,
    reportChance = 35,
    reportIncidentType = "citizen_threatened"
}

Config.CitizenBehavior.messages = {
    citizenComplied = "Citizen complied.",
    citizenFled = "Citizen fled.",
    citizenFought = "Citizen fought back.",
    citizenArmed = "Citizen defended themselves with a firearm.",
    citizenReported = "Citizen reported suspicious activity."
}

Config.PoliceAwareness = Config.PoliceAwareness or {}

Config.PoliceAwareness.enabled = true
Config.PoliceAwareness.debug = true

Config.PoliceAwareness.scanIntervalMs = 500
Config.PoliceAwareness.weaponVisibleRadius = 45.0
Config.PoliceAwareness.weaponAimedRadius = 55.0
Config.PoliceAwareness.shotsRadius = 90.0
Config.PoliceAwareness.attackRadius = 65.0

Config.PoliceAwareness.behaviors = {
    weaponVisible = {
        incidentType = "armed_suspect",
        threat = "high",
        responseCode = "code2",
        note = "Weapon visible near police."
    },

    weaponAimed = {
        incidentType = "armed_suspect",
        threat = "deadly",
        responseCode = "code3",
        note = "Weapon aimed near police."
    },

    shotsFired = {
        incidentType = "shots_fired",
        threat = "deadly",
        responseCode = "code3",
        note = "Shots fired near police."
    },

    officerHit = {
        incidentType = "officer_needs_help",
        threat = "deadly",
        responseCode = "code3",
        note = "Officer attacked."
    },

    vehicleRammedPolice = {
        incidentType = "vehicle_used_as_weapon",
        threat = "high",
        responseCode = "code3",
        note = "Police vehicle rammed."
    }
}

Config.OfficerSkill = Config.OfficerSkill or {}

Config.OfficerSkill.enabled = true
Config.OfficerSkill.debug = true

Config.OfficerSkill.defaultProfile = "patrol_trained"

Config.OfficerSkill.profiles = {
    rookie = {
        label = "Rookie Officer",

        drivingSkill = 0.45,
        pursuitSkill = 0.35,
        trafficNavigation = 0.40,
        reactionSpeed = 0.45,
        scenePositioning = 0.40,
        commandPresence = 0.45,
        weaponDiscipline = 0.50,
        decisionQuality = 0.45,

        driveSpeedMultiplier = 0.90,
        crashRisk = 0.25,
        repathDelayMultiplier = 1.35,
        backupRequestChance = 70
    },

    patrol_trained = {
        label = "Trained Patrol Officer",

        drivingSkill = 0.70,
        pursuitSkill = 0.65,
        trafficNavigation = 0.70,
        reactionSpeed = 0.70,
        scenePositioning = 0.70,
        commandPresence = 0.70,
        weaponDiscipline = 0.75,
        decisionQuality = 0.70,

        driveSpeedMultiplier = 1.00,
        crashRisk = 0.12,
        repathDelayMultiplier = 1.00,
        backupRequestChance = 45
    },

    field_training = {
        label = "Field Training Officer",

        drivingSkill = 0.82,
        pursuitSkill = 0.78,
        trafficNavigation = 0.82,
        reactionSpeed = 0.78,
        scenePositioning = 0.82,
        commandPresence = 0.82,
        weaponDiscipline = 0.85,
        decisionQuality = 0.82,

        driveSpeedMultiplier = 1.05,
        crashRisk = 0.08,
        repathDelayMultiplier = 0.85,
        backupRequestChance = 35
    },

    supervisor = {
        label = "Supervisor",

        drivingSkill = 0.78,
        pursuitSkill = 0.74,
        trafficNavigation = 0.78,
        reactionSpeed = 0.75,
        scenePositioning = 0.88,
        commandPresence = 0.90,
        weaponDiscipline = 0.88,
        decisionQuality = 0.90,

        driveSpeedMultiplier = 1.00,
        crashRisk = 0.08,
        repathDelayMultiplier = 0.85,
        backupRequestChance = 30
    },

    pursuit_certified = {
        label = "Pursuit Certified Officer",

        drivingSkill = 0.90,
        pursuitSkill = 0.90,
        trafficNavigation = 0.86,
        reactionSpeed = 0.82,
        scenePositioning = 0.80,
        commandPresence = 0.78,
        weaponDiscipline = 0.82,
        decisionQuality = 0.82,

        driveSpeedMultiplier = 1.08,
        crashRisk = 0.05,
        repathDelayMultiplier = 0.70,
        backupRequestChance = 40
    }
}

Config.PursuitPressure = Config.PursuitPressure or {}

Config.PursuitPressure.enabled = true
Config.PursuitPressure.debug = true

Config.PursuitPressure.immediateBackupOnPursuit = true
Config.PursuitPressure.immediateBackupRequiresDistance = false

Config.PursuitPressure.maxUnitsPerPursuit = 4
Config.PursuitPressure.maxBackupUnitsInitial = 1
Config.PursuitPressure.maxBackupUnitsEscalated = 3

Config.PursuitPressure.backupDelaySeconds = 2
Config.PursuitPressure.escalationIntervalSeconds = 45
Config.PursuitPressure.minTimeBetweenBackupRequests = 20

Config.PursuitPressure.distanceEscalationEnabled = true
Config.PursuitPressure.tooFarDistance = 180.0
Config.PursuitPressure.criticalDistance = 300.0
Config.PursuitPressure.lostDistance = 450.0

Config.PursuitPressure.allowSpawnedBackupFallback = true
Config.PursuitPressure.spawnedBackupUnitType = "backup"

Config.PursuitPressure.hidePoliceBlipsForNonPolice = true
Config.PursuitPressure.showDebugBlips = false

Config.PursuitPressure.backupResponseCode = "code3"

Config.PursuitPressure.messages = {
    backupRequested = "Backup requested for pursuit.",
    backupAssigned = "Backup assigned to pursuit.",
    noBackupAvailable = "No backup units available.",
    pursuitEscalated = "Pursuit pressure escalated.",
    pursuitContained = "Pursuit containment active."
}

Config.PursuitBackup = {
    enabled = true,
    maxBackupUnits = 3,
    backupDispatchCooldownSeconds = 20,
    interceptDistanceAhead = 120.0,
    interceptSideOffset = 18.0,
    secondaryFollowDistance = 22.0,
    switchToChaseDistance = 70.0,
    containmentDistance = 160.0,
    updateIntervalMs = 2500,
    debug = true
}

Config.LivePursuit = Config.LivePursuit or {}

Config.LivePursuit.enabled = true
Config.LivePursuit.debug = true

Config.LivePursuit.preferEntityChase = true
Config.LivePursuit.chaseRefreshMs = 500
Config.LivePursuit.resumeSpeedThreshold = 1.0
Config.LivePursuit.disableLastKnownRoutingWhenEntityExists = true
Config.LivePursuit.useHybridFollow = true
Config.LivePursuit.followBehindDistance = 14.0
Config.LivePursuit.followSideOffset = 0.0
Config.LivePursuit.closeDistance = 18.0
Config.LivePursuit.tooCloseDistance = 8.0
Config.LivePursuit.backoffDistance = 12.0
Config.LivePursuit.entityLostFallbackMs = 1200

Config.ContinuousPursuit = Config.ContinuousPursuit or {}

Config.ContinuousPursuit.enabled = true
Config.ContinuousPursuit.debug = true

Config.ContinuousPursuit.minTaskRefreshMs = 3500
Config.ContinuousPursuit.useTaskVehicleChase = true
Config.ContinuousPursuit.hybridOnlyWhenStuck = true
Config.ContinuousPursuit.gateEmergencyRepathUntilConfirmedStuck = true
Config.ContinuousPursuit.removePursuitSpeedCaps = true
Config.ContinuousPursuit.basePursuitSpeed = 55.0
Config.ContinuousPursuit.maxConfiguredPursuitSpeed = 75.0
Config.ContinuousPursuit.requireCloseForStop = true
Config.ContinuousPursuit.felonyStopTriggerDistance = 30.0
Config.ContinuousPursuit.felonyStopSpeedThreshold = 0.6
Config.ContinuousPursuit.felonyStopHoldSeconds = 5
Config.ContinuousPursuit.resumeSpeedThreshold = 1.0
Config.ContinuousPursuit.neverStopIfDistanceGreaterThan = 35.0
Config.ContinuousPursuit.targetLostGraceMs = 2500
Config.ContinuousPursuit.stuckSpeedThreshold = 0.75
Config.ContinuousPursuit.stuckConfirmMs = 6500
Config.ContinuousPursuit.minDistanceProgress = 8.0
Config.ContinuousPursuit.minPositionProgress = 3.0
Config.ContinuousPursuit.ignoreStuckIfDistanceImproving = true
Config.ContinuousPursuit.disableHybridWhenCloseDistance = 30.0

Config.DispatchEscalation = {
    enabled = true,
    debug = true,
    defaultPlan = "patrol_only",

    plans = {
        patrol_only = {
            label = "Patrol Only",
            recommendedUnits = {
                { type = "patrol", count = 1 }
            },
            recommendedStatus = "ai_assigned",
            note = "Dispatch recommends one patrol unit."
        },

        patrol_backup = {
            label = "Patrol + Backup",
            recommendedUnits = {
                { type = "patrol", count = 1 },
                { type = "backup", count = 1 }
            },
            recommendedStatus = "ai_assigned",
            note = "Dispatch recommends patrol and backup."
        },

        backup_supervisor = {
            label = "Backup + Supervisor",
            recommendedUnits = {
                { type = "backup", count = 1 },
                { type = "supervisor", count = 1 }
            },
            recommendedStatus = "ai_assigned",
            note = "Dispatch recommends backup and supervisor response."
        },

        containment = {
            label = "Containment Response",
            recommendedUnits = {
                { type = "patrol", count = 1 },
                { type = "backup", count = 2 },
                { type = "supervisor", count = 1 }
            },
            recommendedStatus = "ai_assigned",
            note = "Dispatch recommends containment response."
        }
    },

    threatPlans = {
        low = "patrol_only",
        medium = "patrol_backup",
        high = "backup_supervisor",
        deadly = "containment"
    },

    incidentOverrides = {
        blackmarket_activity = "patrol_only",
        shadowmarket_order = "patrol_only",
        shadowmarket_pickup = "patrol_backup",
        chopshop_activity = "patrol_backup",
        stolen_vehicle_delivery = "patrol_backup",
        shots_fired = "containment"
    },

    messages = {
        planApplied = "Dispatch plan applied.",
        invalidPlan = "Invalid dispatch plan.",
        alreadyCleared = "Incident has already been cleared.",
        noIncident = "Invalid incident."
    }
}

Config.AIResponse = {
    enabled = true,
    debug = true,
    requirePlayerPoliceJob = false,

    spawnDistance = 120.0,
    minSpawnDistance = 95.0,
    maxSpawnDistance = 145.0,
    spawnAttempts = 12,
    spawnSideOffsetMin = 25.0,
    spawnSideOffsetMax = 70.0,
    arrivalDistance = 25.0,
    despawnDistance = 250.0,
    maxActiveUnits = 5,
    cleanupAfterSeconds = 600,

    vehicleModels = {
        patrol = "police",
        backup = "police2",
        supervisor = "police3"
    },

    pedModels = {
        "s_m_y_cop_01",
        "s_f_y_cop_01"
    },

    drivingSpeed = 30.0,
    drivingStyle = 786603,
    emergencyDrivingStyle = 1074528293,
    responseRefreshMs = 4000,
    defaultDriverAbility = 1.0,
    defaultDriverAggressiveness = 0.55,
    highThreatDriverAggressiveness = 0.85,
    officerAccuracyBase = 35,
    officerAccuracyPerThreat = 8,
    officerAccuracyMax = 70,
    engageDistance = 45.0,
    forceDismountAfterMs = 25000,

    speedByThreat = {
        low = 30.0,
        medium = 34.0,
        high = 42.0,
        deadly = 48.0
    },

    behavior = {
        low = "investigate",
        medium = "stage",
        high = "contain",
        deadly = "contain"
    },

    messages = {
        disabled = "AI police response is disabled.",
        maxUnits = "Maximum AI police units are already active.",
        noCoords = "Incident has no valid location.",
        spawnFailed = "Unable to spawn AI police unit.",
        dispatched = "AI police unit dispatched.",
        arrived = "AI police unit arrived on scene.",
        cleared = "AI police unit cleared."
    }
}

Config.AIScene = {
    enabled = true,
    debug = true,

    investigationDurationSeconds = 90,
    autoClearEnabled = true,
    autoClearAfterSeconds = 120,

    stageRadius = 8.0,
    lookAroundDuration = 8000,
    walkSpeed = 1.0,

    behaviors = {
        investigate = {
            label = "Investigating",
            note = "AI officers are investigating the scene.",
            durationSeconds = 90,
            autoClear = true
        },
        stage = {
            label = "Staging",
            note = "AI officers are staging near the incident.",
            durationSeconds = 120,
            autoClear = true
        },
        contain = {
            label = "Containing Scene",
            note = "AI officers are containing the scene and awaiting support.",
            durationSeconds = 150,
            autoClear = false
        }
    },

    threatBehavior = {
        low = "investigate",
        medium = "stage",
        high = "contain",
        deadly = "contain"
    },

    messages = {
        investigating = "AI officers are investigating the scene.",
        staging = "AI officers are staging near the scene.",
        containing = "AI officers are containing the scene.",
        cleared = "AI officers cleared the incident.",
        clearRequested = "AI clear requested.",
        invalidTask = "Invalid AI task."
    }
}

Config.AIPatrol = {
    enabled = true,
    debug = true,

    maxActivePatrols = 4,
    defaultVehicle = "police",
    defaultPedModel = "s_m_y_cop_01",

    drivingSpeed = 15.0,
    drivingStyle = 786603,
    waypointArrivalDistance = 18.0,
    waypointWaitMs = 2500,

    autoStartOnResourceStart = false,

    zones = {
        mission_row = {
            label = "Mission Row Patrol",
            enabled = true,
            maxUnits = 1,
            skillProfile = "patrol_trained",
            vehicle = "police",
            pedModel = "s_m_y_cop_01",
            spawn = vector4(448.3168, -1024.1874, 28.5991, 95.3422),
            waypoints = {
                vector3(425.58, -1025.52, 29.05),
                vector3(300.20, -1065.56, 29.40),
                vector3(185.62, -1012.37, 29.32),
                vector3(215.93, -846.65, 30.73),
                vector3(409.51, -814.82, 29.30),
                vector3(452.64, -960.44, 28.47)
            }
        },

        davis = {
            label = "Davis Patrol",
            enabled = true,
            maxUnits = 1,
            skillProfile = "patrol_trained",
            vehicle = "police2",
            pedModel = "s_m_y_cop_01",
            spawn = vector4(379.35, -1608.25, 29.29, 230.0),
            waypoints = {
                vector3(353.93, -1616.31, 29.29),
                vector3(163.72, -1470.28, 29.14),
                vector3(86.44, -1379.18, 29.31),
                vector3(118.48, -1205.39, 29.32),
                vector3(298.24, -1245.42, 29.24),
                vector3(390.51, -1444.28, 29.42)
            }
        },

        vinewood = {
            label = "Vinewood Patrol",
            enabled = true,
            maxUnits = 1,
            skillProfile = "field_training",
            vehicle = "police3",
            pedModel = "s_m_y_cop_01",
            spawn = vector4(638.65, 1.42, 82.78, 250.0),
            waypoints = {
                vector3(661.67, 20.34, 84.17),
                vector3(716.63, 198.51, 87.05),
                vector3(561.01, 271.03, 103.12),
                vector3(381.70, 258.31, 103.02),
                vector3(308.29, 178.75, 103.84),
                vector3(471.54, 85.94, 99.15)
            }
        }
    },

    messages = {
        disabled = "AI patrols are disabled.",
        zoneDisabled = "This patrol zone is disabled.",
        invalidZone = "Invalid patrol zone.",
        maxUnits = "Maximum active patrol units reached.",
        zoneMaxUnits = "This patrol zone already has the maximum patrol units.",
        spawnFailed = "Unable to spawn AI patrol.",
        spawned = "AI patrol unit spawned.",
        cleared = "AI patrol units cleared.",
        noPatrols = "No AI patrols active."
    }
}

Config.PatrolDetection = {
    enabled = true,
    debug = true,

    scanIntervalMs = 5000,
    defaultDetectionRadius = 85.0,
    defaultCooldownSeconds = 90,
    maxSignals = 50,

    detectionChance = {
        low = 45,
        medium = 65,
        high = 85,
        deadly = 100
    },

    signalTypes = {
        suspicious_activity = {
            label = "Suspicious Activity",
            incidentType = "blackmarket_activity",
            threatLevel = "low",
            detectionRadius = 85.0,
            cooldownSeconds = 90
        },

        stolen_vehicle_activity = {
            label = "Stolen Vehicle Activity",
            incidentType = "stolen_vehicle_delivery",
            threatLevel = "medium",
            detectionRadius = 100.0,
            cooldownSeconds = 120
        },

        chopshop_activity = {
            label = "Chop Shop Activity",
            incidentType = "chopshop_activity",
            threatLevel = "low",
            detectionRadius = 100.0,
            cooldownSeconds = 120
        },

        shots_fired = {
            label = "Shots Fired",
            incidentType = "shots_fired",
            threatLevel = "deadly",
            detectionRadius = 180.0,
            cooldownSeconds = 180
        },

        gang_activity = {
            label = "Gang Activity",
            incidentType = "gang_activity",
            threatLevel = "medium",
            detectionRadius = 110.0,
            cooldownSeconds = 120
        }
    },

    messages = {
        signalAdded = "Patrol detection signal added.",
        signalDetected = "Patrol detected suspicious activity.",
        invalidSignal = "Invalid detection signal.",
        noPatrolNearby = "No patrol nearby detected this signal.",
        disabled = "Patrol detection is disabled."
    }
}

Config.ThreatLevels = {
    low = {
        label = "Low",
        score = 1,
        defaultResponse = "investigate",
        forcePolicy = "less_lethal_preferred",
        backupRecommended = false
    },

    medium = {
        label = "Medium",
        score = 2,
        defaultResponse = "investigate_with_caution",
        forcePolicy = "less_lethal_preferred",
        backupRecommended = true
    },

    high = {
        label = "High",
        score = 3,
        defaultResponse = "contain_and_backup",
        forcePolicy = "less_lethal_if_safe",
        backupRecommended = true
    },

    deadly = {
        label = "Deadly",
        score = 4,
        defaultResponse = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary",
        backupRecommended = true
    }
}

Config.IncidentTypes = {
    blackmarket_activity = {
        baseThreat = "low",
        response = "investigate",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 1,
        description = "Suspicious black market activity."
    },

    shadowmarket_order = {
        baseThreat = "low",
        response = "investigate",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 1,
        description = "Suspicious encrypted-market activity."
    },

    shadowmarket_pickup = {
        baseThreat = "low",
        response = "investigate",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 1,
        description = "Possible black market pickup."
    },

    chopshop_activity = {
        baseThreat = "low",
        response = "investigate",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 1,
        description = "Suspicious stolen vehicle chop activity."
    },

    shadowmarket_vehicle_offer = {
        baseThreat = "low",
        response = "investigate",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 1,
        description = "Suspicious stolen vehicle offer activity."
    },

    stolen_vehicle_delivery = {
        baseThreat = "medium",
        response = "investigate_with_caution",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 2,
        description = "Possible stolen vehicle delivery."
    },

    stolen_vehicle_activity = {
        baseThreat = "medium",
        response = "investigate_with_caution",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 2,
        description = "Moving stolen vehicle activity."
    },

    suspect_vehicle = {
        baseThreat = "medium",
        response = "investigate_with_caution",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 2,
        description = "Suspicious moving vehicle."
    },

    fleeing_vehicle = {
        baseThreat = "high",
        response = "contain_and_backup",
        forcePolicy = "less_lethal_if_safe",
        unitsRecommended = 3,
        description = "Fleeing suspect vehicle."
    },

    shots_fired = {
        baseThreat = "deadly",
        response = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary",
        unitsRecommended = 4,
        description = "Shots fired."
    },

    gang_activity = {
        baseThreat = "medium",
        response = "investigate_with_caution",
        forcePolicy = "less_lethal_preferred",
        unitsRecommended = 2,
        description = "Possible gang activity detected by patrol."
    }
}

Config.IncidentTypes.citizen_threatened = Config.IncidentTypes.citizen_threatened or {
    baseThreat = "medium",
    response = "investigate_with_caution",
    forcePolicy = "less_lethal_preferred",
    unitsRecommended = 2,
    description = "Citizen threatened or robbed at gunpoint."
}

Config.IncidentTypes.robbery_in_progress = Config.IncidentTypes.robbery_in_progress or {
    baseThreat = "high",
    response = "contain_and_backup",
    forcePolicy = "less_lethal_if_safe",
    unitsRecommended = 3,
    description = "Robbery in progress."
}

Config.IncidentTypes.armed_suspect = Config.IncidentTypes.armed_suspect or {
    baseThreat = "high",
    response = "contain_and_challenge",
    forcePolicy = "less_lethal_if_safe",
    unitsRecommended = 3,
    description = "Armed suspect observed."
}

Config.IncidentTypes.officer_needs_help = Config.IncidentTypes.officer_needs_help or {
    baseThreat = "deadly",
    response = "active_threat_response",
    forcePolicy = "deadly_force_authorized_if_necessary",
    unitsRecommended = 4,
    description = "Officer needs help."
}

Config.IncidentTypes.vehicle_used_as_weapon = Config.IncidentTypes.vehicle_used_as_weapon or {
    baseThreat = "high",
    response = "contain_and_backup",
    forcePolicy = "less_lethal_if_safe",
    unitsRecommended = 3,
    description = "Vehicle used as a weapon."
}

Config.EscalationRules = {
    suspectFleeing = {
        threatModifier = 1,
        response = "pursuit",
        backupRecommended = true
    },

    weaponVisible = {
        threatModifier = 1,
        response = "contain_and_challenge",
        backupRecommended = true
    },

    weaponAimed = {
        setThreat = "deadly",
        response = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary"
    },

    shotsFired = {
        setThreat = "deadly",
        response = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary"
    },

    hostage = {
        setThreat = "deadly",
        response = "contain_negotiate_tactical",
        forcePolicy = "deadly_force_authorized_if_necessary"
    },

    vehicleUsedAsWeapon = {
        setThreat = "deadly",
        response = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary"
    }
}

Config.OrganizationContext = {
    enabled = true,
    failOpenIfMissing = true,

    modifiers = {
        knownCriminalOrg = 1,
        activeTerritory = 1,
        contestedTerritory = 1,
        recentViolence = 1,
        rivalConflict = 1
    },

    messages = {
        missing = "Organization context unavailable.",
    }
}

Config.Awareness = Config.Awareness or {}

Config.Awareness.enabled = true
Config.Awareness.requirePoliceJob = false
Config.Awareness.allowAIOnlyResponse = true
Config.Awareness.witnessReportEnabled = true
Config.Awareness.witnessRange = 80.0
Config.Awareness.officerAwarenessRange = 120.0
Config.Awareness.gunshotRange = 180.0
Config.Awareness.vehicleCrimeRange = 100.0
Config.Awareness.scanIntervalMs = 500
Config.Awareness.updateIntervalMs = 2500
Config.Awareness.reportCooldownSeconds = 8
Config.Awareness.activeIncidentTimeoutSeconds = 180
Config.Awareness.duplicateDispatchCooldownSeconds = 20
Config.Awareness.reportLogCooldownMs = 5000
Config.Awareness.reportEventCooldownMs = 3500
Config.Awareness.sameIncidentUpdateCooldownMs = 3000
Config.Awareness.reportPrintCooldownMs = 10000
Config.Awareness.reportHardPrintCooldownMs = 15000
Config.Awareness.reportSendCooldownMs = 5000
Config.Awareness.lastKnownUpdateCooldownMs = 3000
Config.Awareness.recklessSpeedMph = 75.0
Config.Awareness.reportDelayMs = {
    min = 1500,
    max = 6000
}
Config.Awareness.debug = true
Config.Awareness.highPriorityThreshold = 65

Config.Awareness.behaviors = {
    shotsFired = {
        incidentType = "shots_fired",
        threat = "deadly",
        responseCode = "code3",
        priority = 100,
        note = "Shots fired observed by police network."
    },
    weaponAimed = {
        incidentType = "armed_suspect",
        threat = "deadly",
        responseCode = "code3",
        priority = 90,
        note = "Suspect aimed a weapon in public view."
    },
    assault = {
        incidentType = "robbery_in_progress",
        threat = "high",
        responseCode = "code3",
        priority = 70,
        note = "Assault observed by witness or officer."
    },
    stolenVehicle = {
        incidentType = "stolen_vehicle_activity",
        threat = "medium",
        responseCode = "code2",
        priority = 60,
        note = "Vehicle theft observed."
    },
    fleeingVehicle = {
        incidentType = "fleeing_vehicle",
        threat = "high",
        responseCode = "code3",
        priority = 65,
        note = "Suspect fled in a vehicle after a crime."
    },
    recklessDriving = {
        incidentType = "fleeing_vehicle",
        threat = "medium",
        responseCode = "code2",
        priority = 40,
        note = "Reckless driving observed near police."
    },
    suspiciousBehavior = {
        incidentType = "armed_suspect",
        threat = "low",
        responseCode = "code1",
        priority = 20,
        note = "Suspicious masked or armed behavior observed."
    },
    runningFromScene = {
        incidentType = "robbery_in_progress",
        threat = "medium",
        responseCode = "code2",
        priority = 25,
        note = "Suspect ran from a reported crime scene."
    }
}

Config.Awareness.messages = {
    reportSent = "Crime report sent to police radio.",
    debugPrinted = "AI police awareness debug printed.",
    radioDebugPrinted = "Police radio debug printed."
}
