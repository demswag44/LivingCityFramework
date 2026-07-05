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
        enabled = true
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
        maxQuantity = 2
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
        maxQuantity = 10
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
        maxQuantity = 1
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
        maxQuantity = 6
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
        maxQuantity = 10
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
        maxQuantity = 4
    }
}

GSBlackMarket.Config = Config
