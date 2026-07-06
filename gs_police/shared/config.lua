Config = Config or {}

Config.Debug = false

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
Config.PatrolDispatch.driveSpeed = 24.0
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

    emergencyDriveSpeed = 30.0,
    normalDriveSpeed = 24.0
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

Config.Pursuit.driveSpeed = 32.0
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

Config.EmergencyDriving.driveSpeed = 36.0
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

    spawnDistance = 120.0,
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

    drivingSpeed = 22.0,
    drivingStyle = 786603,

    behavior = {
        low = "investigate",
        medium = "stage",
        high = "stage",
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
        high = "stage",
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
