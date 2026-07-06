GSBlackMarket = GSBlackMarket or {}

Config = Config or {}

Config.LogPrefix = 'GS BLACKMARKET'
Config.Enabled = true
Config.Debug = false
Config.KnockDelay = 2500
Config.PromptDrawDistance = 12.0
Config.MaxPurchaseDistance = 5.0
Config.UseCustomUI = true
Config.UI = {
    enabled = true,
    title = "Black Market",
    subtitle = "No refunds. No questions.",
    flavor = "Cash only. No names.",
    theme = "dark",
    assetPath = "assets/",
    maxQuantity = 10
}

Config.PoliceAlert = {
    enabled = true,
    chance = 15,
    triggerOnKnock = true,
    triggerOnPurchase = true,
    alertCooldownSeconds = 180,
    title = "Suspicious Activity",
    message = "Suspicious activity reported near a residence.",
    threatLevel = "low",
    incidentType = "blackmarket_activity",
    preferredResponse = "investigate",
    forcePolicy = "less_lethal_preferred",
    dispatchEvent = "gs_dispatch:server:createAlert"
}

Config.DealerCooldown = {
    enabled = true,

    -- Player must wait 30 seconds before knocking again.
    knockCooldownSeconds = 30,

    -- Player must wait 2 minutes after a successful purchase.
    purchaseCooldownSeconds = 120,

    message = "The door goes quiet. Come back later."
}

Config.Stock = {
    enabled = true,
    restockSeconds = 1800,
    perLocationStock = true,
    resetOnRestart = true,
    outOfStockMessage = "The dealer is out of that item.",
    restockMessage = "The dealer has restocked.",
}

Config.Reputation = {
    enabled = true,
    perDealer = true,
    defaultRep = 0,
    gainPerPurchase = 2,
    gainPerDollarSpent = 0.001,
    maxRep = 100,
    resetOnRestart = true,
    messages = {
        gained = "Dealer trust increased.",
        tooLow = "The dealer does not trust you enough for that.",
    }
}

Config.Access = {
    enabled = true,
    requireGangForWeapons = false,
    useOrganizations = true,
    useTerritories = true,
    failOpenForMissingSystems = true,
    messages = {
        locked = "The dealer will not sell you that.",
        gangRequired = "You need the right connections for that.",
        territoryLocked = "This dealer is controlled by someone else.",
    }
}

Config.RotatingInventory = {
    enabled = true,
    rotateSeconds = 3600,
    keepAlwaysAvailable = true,
    maxRotatingItems = 4,
    resetOnRestart = true,
}

Config.Relocation = {
    enabled = true,
    relocateSeconds = 7200,
    singleActiveLocation = true,
    resetOnRestart = true,
    requireEnabledLocation = true,
    debugRelocation = false,
    messages = {
        unavailable = "Nobody answers the door.",
        moved = "Word on the street says the dealer moved."
    }
}

Config.PhoneApp = {
    enabled = true,
    visibleName = "Calculator",
    hiddenName = "ShadowMarket",
    unlockCode = "7723",
    requireDealerRep = true,
    requiredRep = 10,
    requireEncryptedSim = false,
    encryptedSimItem = "encrypted_sim",
    policeRequireEvidence = true,
    icon = {
        background = "black",
        accent = "green",
        image = "calculator_shadowmarket.png"
    },
    messages = {
        locked = "Calculator",
        unlocked = "ShadowMarket unlocked.",
        accessDenied = "Nothing happens.",
        wiped = "App data wiped.",
        failedCode = "Invalid calculation."
    },
    failedCodeEvidence = {
        enabled = true,
        maxAttempts = 3,
        evidenceType = "metadata_recovered"
    },
    wipe = {
        enabled = true,
        failureChance = 10,
        evidenceTypeOnFailure = "failed_wipe"
    }
}

Config.PhoneOrders = {
    enabled = true,
    expireSeconds = 1800,
    maxActiveOrders = 2,
    depositPercent = 1.0,
    returnStockOnExpire = true,
    requireActiveLocation = true,
    followRelocation = true,
    policeAlertOnOrder = true,
    policeAlertOnPickup = true,
    createMetadataEvidence = true,
    messages = {
        orderPlaced = "Order placed. Pickup location sent.",
        orderFailed = "Order could not be placed.",
        orderExpired = "Your order expired.",
        noOrders = "You have no pending orders.",
        pickedUp = "Order picked up.",
        tooManyOrders = "You already have too many pending orders.",
        pickupWrongLocation = "Nobody here knows about that order.",
        notEnoughCash = "You don't have enough cash.",
        outOfStock = "The dealer cannot reserve that item.",
    }
}

Config.VehicleOffers = {
    enabled = true,
    expireSeconds = 1800,
    maxActiveOffers = 1,
    acceptPoliceAlertChance = 8,
    deliveryPoliceAlertChance = 18,
    createEvidenceOnAccept = true,
    createEvidenceOnDelivery = true,
    repGainOnDelivery = 4,
    messages = {
        accepted = "Vehicle offer accepted. Deliver the vehicle to Benny's.",
        completed = "Vehicle offer completed.",
        alreadyActive = "You already have an active vehicle offer.",
        unavailable = "That vehicle offer is no longer available.",
        locked = "You need more ShadowMarket reputation for that offer.",
        noMatch = "That vehicle does not match your active ShadowMarket offer.",
    },
    offers = {
        {
            id = "muscle_any",
            label = "Wanted: Any Muscle Car",
            type = "class",
            vehicleClass = 4,
            requestLabel = "Any Muscle car",
            bonus = 3500,
            policeHeat = "Medium",
            requiredRep = 10,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "suv_any",
            label = "Wanted: Any SUV",
            type = "class",
            vehicleClass = 2,
            requestLabel = "Any SUV",
            bonus = 3000,
            policeHeat = "Low",
            requiredRep = 10,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "sports_any",
            label = "Wanted: Sports Class",
            type = "class",
            vehicleClass = 6,
            requestLabel = "Any Sports class vehicle",
            bonus = 5000,
            policeHeat = "High",
            requiredRep = 18,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "sultan",
            label = "Wanted: Sultan",
            type = "model",
            model = `sultan`,
            requestLabel = "Sultan",
            bonus = 4200,
            policeHeat = "Medium",
            requiredRep = 12,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "buffalo",
            label = "Wanted: Buffalo",
            type = "model",
            models = {
                [`buffalo`] = true,
                [`buffalo2`] = true,
                [`buffalo3`] = true,
            },
            requestLabel = "Buffalo",
            bonus = 4400,
            policeHeat = "Medium",
            requiredRep = 12,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "dominator",
            label = "Wanted: Dominator",
            type = "model",
            models = {
                [`dominator`] = true,
                [`dominator2`] = true,
                [`dominator3`] = true,
            },
            requestLabel = "Dominator",
            bonus = 4700,
            policeHeat = "High",
            requiredRep = 14,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
        {
            id = "oracle",
            label = "Wanted: Oracle",
            type = "model",
            models = {
                [`oracle`] = true,
                [`oracle2`] = true,
            },
            requestLabel = "Oracle",
            bonus = 3200,
            policeHeat = "Low",
            requiredRep = 10,
            deliveryShopId = "bennys_chop_01",
            deliveryLabel = "Benny's Back Room",
        },
    },
}

Config.VehicleOfferDemand = {
    enabled = true,
    rotateSeconds = 1800,
    offersPerCycle = 5,
    levels = {
        low = {
            label = "Low",
            bonusMultiplier = 0.75,
            weight = 25
        },
        normal = {
            label = "Normal",
            bonusMultiplier = 1.0,
            weight = 40
        },
        high = {
            label = "High",
            bonusMultiplier = 1.35,
            weight = 25
        },
        hot = {
            label = "Hot",
            bonusMultiplier = 1.75,
            weight = 10
        }
    },
    reduceDemandOnDelivery = true,
    resetOnRestart = true
}

Config.VehicleOfferHeat = {
    enabled = true,
    defaultHeat = "low",
    levels = {
        low = {
            label = "Low",
            alertChance = 10,
            evidenceChance = 10,
            bonusRiskMultiplier = 1.0,
            weight = 45
        },
        medium = {
            label = "Medium",
            alertChance = 20,
            evidenceChance = 25,
            bonusRiskMultiplier = 1.15,
            weight = 35
        },
        high = {
            label = "High",
            alertChance = 35,
            evidenceChance = 45,
            bonusRiskMultiplier = 1.35,
            weight = 15
        },
        hot = {
            label = "Hot",
            alertChance = 50,
            evidenceChance = 65,
            bonusRiskMultiplier = 1.6,
            weight = 5
        }
    },
    increaseHeatOnDelivery = true,
    coolDownSeconds = 3600
}

Config.VehicleOfferTemplates = {
    {
        id = "any_muscle",
        label = "Any Muscle Car",
        matchType = "class",
        vehicleClass = 4,
        baseBonus = 1500,
        requiredRep = 0,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 25
    },
    {
        id = "any_suv",
        label = "Any SUV",
        matchType = "class",
        vehicleClass = 2,
        baseBonus = 1250,
        requiredRep = 0,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 25
    },
    {
        id = "any_sports",
        label = "Any Sports Car",
        matchType = "class",
        vehicleClass = 6,
        baseBonus = 3000,
        requiredRep = 10,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 15
    },
    {
        id = "sultan",
        label = "Karin Sultan",
        matchType = "model",
        model = "sultan",
        baseBonus = 2500,
        requiredRep = 5,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 15
    },
    {
        id = "buffalo",
        label = "Bravado Buffalo",
        matchType = "model",
        model = "buffalo",
        models = { "buffalo", "buffalo2", "buffalo3" },
        baseBonus = 2750,
        requiredRep = 5,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 15
    },
    {
        id = "dominator",
        label = "Vapid Dominator",
        matchType = "model",
        model = "dominator",
        models = { "dominator", "dominator2", "dominator3" },
        baseBonus = 3000,
        requiredRep = 10,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 10
    },
    {
        id = "oracle",
        label = "Ubermacht Oracle",
        matchType = "model",
        model = "oracle",
        models = { "oracle", "oracle2" },
        baseBonus = 3500,
        requiredRep = 15,
        deliveryShopId = "bennys_chop_01",
        deliveryLabel = "Benny's Back Room",
        weight = 10
    }
}

Config.KnockAnimation = {
    dict = "timetable@jimmy@doorknock@",
    anim = "knockdoor_idle",
    duration = 1800,
    flag = 49
}

Config.BlackMarketLocations = {
    {
        id = "house_dealer_01",
        label = "Unknown Door",
        coords = vector3(-32.3613, -1432.7159, 31.8825),
        heading = 85.4257,
        knockDistance = 2.0,
        enabled = true,
        relocationEligible = true,
        active = true
    },
    {
        id = "house_dealer_02",
        label = "Back Door",
        coords = vector3(-1039.2036, -1610.2296, 5.1120),
        heading = 123.8938,
        knockDistance = 2.0,
        enabled = true,
        relocationEligible = true,
        active = false
    },
    {
        id = "house_dealer_03",
        label = "Side Door",
        coords = vector3(473.9066, -1718.6511, 29.3271),
        heading = 285.7741,
        knockDistance = 2.0,
        enabled = true,
        relocationEligible = true,
        active = false
    },
    {
        id = "house_dealer_04",
        label = "Quiet Door",
        coords = vector3(1314.9633, -1684.9619, 58.2330),
        heading = 189.9987,
        knockDistance = 2.0,
        enabled = true,
        relocationEligible = true,
        active = false
    }
}

Config.Items = {
    {
        label = "Pistol",
        item = "weapon_pistol",
        price = 2500,
        amount = 1,
        category = "weapon",
        description = "Standard illegal sidearm.",
        image = "pistol.png",
        stock = 3,
        restockAmount = 3,
        maxQuantity = 2,
        requiredRep = 0,
        requiresGang = false,
        requiresTerritoryControl = false,
        alwaysAvailable = false,
        rotationGroup = "weapons"
    },
    {
        label = "Pistol Ammo",
        item = "pistol_ammo",
        price = 350,
        amount = 1,
        category = "ammo",
        description = "A box of pistol ammunition.",
        image = "pistol_ammo.png",
        stock = 20,
        restockAmount = 20,
        maxQuantity = 10,
        requiredRep = 0,
        requiresGang = false,
        requiresTerritoryControl = false,
        alwaysAvailable = true,
        rotationGroup = "ammo"
    },
    {
        label = "SMG",
        item = "weapon_smg",
        price = 8500,
        amount = 1,
        category = "weapon",
        description = "Compact automatic weapon.",
        image = "smg.png",
        stock = 1,
        restockAmount = 1,
        maxQuantity = 1,
        requiredRep = 10,
        requiresGang = true,
        requiresTerritoryControl = false,
        alwaysAvailable = false,
        rotationGroup = "weapons"
    },
    {
        label = "SMG Ammo",
        item = "smg_ammo",
        price = 750,
        amount = 1,
        category = "ammo",
        description = "A box of SMG ammunition.",
        image = "smg_ammo.png",
        stock = 12,
        restockAmount = 12,
        maxQuantity = 6,
        requiredRep = 5,
        requiresGang = false,
        requiresTerritoryControl = false,
        alwaysAvailable = false,
        rotationGroup = "ammo"
    },
    {
        label = "Lockpick",
        item = "lockpick",
        price = 500,
        amount = 1,
        category = "tool",
        description = "Basic tool for breaking into locks.",
        image = "lockpick.png",
        stock = 15,
        restockAmount = 15,
        maxQuantity = 10,
        requiredRep = 0,
        requiresGang = false,
        requiresTerritoryControl = false,
        alwaysAvailable = true,
        rotationGroup = "tools"
    },
    {
        label = "Advanced Lockpick",
        item = "advancedlockpick",
        price = 1200,
        amount = 1,
        category = "tool",
        description = "Stronger lock bypass tool.",
        image = "advancedlockpick.png",
        stock = 6,
        restockAmount = 6,
        maxQuantity = 4,
        requiredRep = 10,
        requiresGang = false,
        requiresTerritoryControl = false,
        alwaysAvailable = false,
        rotationGroup = "tools"
    }
}

GSBlackMarket.Config = Config
