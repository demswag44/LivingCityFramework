Config = {}

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

    shots_fired = {
        baseThreat = "deadly",
        response = "active_threat_response",
        forcePolicy = "deadly_force_authorized_if_necessary",
        unitsRecommended = 4,
        description = "Shots fired."
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
