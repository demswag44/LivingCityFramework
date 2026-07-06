Config = {}

Config.Debug = false

Config.UseTarget = false

Config.InteractKey = 38 -- E

Config.InteractDistance = 2.0

Config.ChopDuration = 8000

Config.ChopShops = {
    {
        id = "bennys_chop_01",
        label = "Benny's Back Room",

        vehicleZone = {
            coords = vector3(-222.8768, -1324.4647, 30.8908),
            heading = 86.2746,
            radius = 4.0
        },

        ped = {
            model = "s_m_m_autoshop_01",
            coords = vector4(-223.0859, -1320.1456, 30.8908, 186.6843),
            scenario = "WORLD_HUMAN_CLIPBOARD"
        },

        enabled = true,
        policeAlertChance = 15,
        cooldownSeconds = 120
    }
}

Config.VehicleBayMarker = {
    enabled = true,
    drawDistance = 35.0,
    type = 36,
    scale = vector3(3.0, 3.0, 1.0),
    color = { r = 0, g = 255, b = 120, a = 120 },
    bobUpAndDown = false,
    rotate = false,
    showArrow = true,
    showText = true,
    text = "Park Here",
    showGroundStrips = true,
    stripCount = 3,
    stripSpacing = 1.25
}

Config.DebugVehicleInfo = {
    show3DText = true,
    displaySeconds = 8
}

Config.Payment = {
    account = "cash",

    useQBCoreVehiclePrices = true,

    defaultVehicleValue = 25000,

    minPayout = 500,
    maxPayout = 25000,

    recoverablePartsPercent = 0.35,
    thiefCutPercent = 0.35,
    shopCutPercent = 0.65,

    conditionAffectsPrice = true,
    minConditionMultiplier = 0.45,

    demandMultiplier = 1.0,
    policeHeatMultiplier = 1.0,

    randomBonusMin = -250,
    randomBonusMax = 500,

    classMultipliers = {
        [0] = 0.85, -- Compacts
        [1] = 0.90, -- Sedans
        [2] = 1.00, -- SUVs
        [3] = 1.05, -- Coupes
        [4] = 1.10, -- Muscle
        [5] = 1.20, -- Sports Classics
        [6] = 1.35, -- Sports
        [7] = 1.60, -- Super
        [8] = 0.70, -- Motorcycles
        [9] = 1.05, -- Off-road
        [10] = 1.15, -- Industrial
        [11] = 0.90, -- Utility
        [12] = 0.95, -- Vans
        [18] = 0.50 -- Emergency, usually blocked
    }
}

Config.VehicleValues = Config.VehicleValues or {
    [`adder`] = 1000000,
    [`zentorno`] = 725000,
    [`t20`] = 2200000,

    [`sultan`] = 35000,
    [`buffalo`] = 45000,
    [`buffalo2`] = 55000,
    [`dominator`] = 35000,
    [`gauntlet`] = 32000,
    [`oracle`] = 80000,
    [`sentinel`] = 60000,
    [`asea`] = 12000,
    [`blista`] = 18000
}

Config.VehicleRules = {
    allowNpcVehicles = true,
    allowPlayerOwnedVehicles = false,
    blockEmergencyVehicles = true,

    -- If true, vehicles must not be owned by the player.
    requireNotOwnedByPlayer = true,

    blockedClasses = {
        [13] = true, -- Cycles
        [14] = true, -- Boats
        [15] = true, -- Helicopters
        [16] = true, -- Planes
        [21] = true -- Trains
    },

    blockedModels = {
        -- [`police`] = true,
    }
}

Config.Messages = {
    noVehicle = "No car in the bay.",
    getOut = "Get out first. I don't do business while you're sitting in it.",
    tooFar = "You're too far from the shop.",
    busy = "Give me a minute. I'm already working.",
    started = "Give me a second. I'll strip it down.",
    prompt = "Press [E] to talk",
    greeting = "You got something for me?",
    registered = "I don't touch registered cars.",
    invalidVehicle = "I can't use that one.",
    pullIntoBay = "Pull it into the marked bay.",
    cannotProcess = "Couldn't process that vehicle.",
    cooldown = "Come back in %ss.",
    paid = "Vehicle stripped. You got $%s.",
    failed = "Something went wrong. Move the car and try again."
}

-- Future ShadowMarket Sell integration:
-- Phone app can generate chop shop offers.
-- Accepted offers can require delivery to this shop.
-- Vehicle value, demand, and police heat can be dynamic.
