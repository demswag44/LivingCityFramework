Config = Config or {}
Config.Weather = Config.Weather or {}

Config.Weather.Enabled = true
Config.Weather.Debug = false
Config.Weather.RequireAce = false
Config.Weather.AdminAce = 'gs.admin'
Config.Weather.DefaultWeather = 'CLEAR'
Config.Weather.DefaultTemperature = 72
Config.Weather.DefaultWindSpeed = 0.0
Config.Weather.DefaultFogLevel = 0.0
Config.Weather.TransitionMs = 15000
Config.Weather.CycleEnabled = false
Config.Weather.CycleIntervalMinutes = 30

Config.Weather.AllowedTypes = {
    CLEAR = true,
    EXTRASUNNY = true,
    CLOUDS = true,
    OVERCAST = true,
    RAIN = true,
    THUNDER = true,
    FOGGY = true,
    SMOG = true,
    CLEARING = true
}

Config.Weather.CycleTypes = {
    'CLEAR',
    'EXTRASUNNY',
    'CLOUDS',
    'OVERCAST',
    'RAIN',
    'FOGGY',
    'CLEARING'
}

Config.Weather.Effects = {
    CLEAR = {
        visibility = 1.0,
        traffic = 1.0,
        pedestrianDensity = 1.0,
        policeResponse = 1.0,
        witnessChance = 1.0,
        crimeChance = 1.0,
        roadRisk = 1.0,
        oceanRisk = 1.0
    },
    EXTRASUNNY = {
        visibility = 1.05,
        traffic = 1.0,
        pedestrianDensity = 1.05,
        policeResponse = 0.95,
        witnessChance = 1.05,
        crimeChance = 0.95,
        roadRisk = 0.9,
        oceanRisk = 0.9
    },
    CLOUDS = {
        visibility = 0.95,
        traffic = 1.0,
        pedestrianDensity = 0.95,
        policeResponse = 1.0,
        witnessChance = 0.95,
        crimeChance = 1.0,
        roadRisk = 1.0,
        oceanRisk = 1.0
    },
    OVERCAST = {
        visibility = 0.9,
        traffic = 0.95,
        pedestrianDensity = 0.85,
        policeResponse = 1.05,
        witnessChance = 0.9,
        crimeChance = 1.05,
        roadRisk = 1.05,
        oceanRisk = 1.05
    },
    RAIN = {
        visibility = 0.75,
        traffic = 0.85,
        pedestrianDensity = 0.6,
        policeResponse = 1.15,
        witnessChance = 0.7,
        crimeChance = 1.1,
        roadRisk = 1.25,
        oceanRisk = 1.2
    },
    THUNDER = {
        visibility = 0.55,
        traffic = 0.7,
        pedestrianDensity = 0.4,
        policeResponse = 1.3,
        witnessChance = 0.55,
        crimeChance = 1.2,
        roadRisk = 1.6,
        oceanRisk = 1.6
    },
    FOGGY = {
        visibility = 0.45,
        traffic = 0.8,
        pedestrianDensity = 0.7,
        policeResponse = 1.25,
        witnessChance = 0.55,
        crimeChance = 1.15,
        roadRisk = 1.35,
        oceanRisk = 1.1
    },
    SMOG = {
        visibility = 0.6,
        traffic = 0.9,
        pedestrianDensity = 0.8,
        policeResponse = 1.15,
        witnessChance = 0.75,
        crimeChance = 1.05,
        roadRisk = 1.15,
        oceanRisk = 1.0
    },
    CLEARING = {
        visibility = 0.85,
        traffic = 0.95,
        pedestrianDensity = 0.8,
        policeResponse = 1.05,
        witnessChance = 0.85,
        crimeChance = 1.05,
        roadRisk = 1.15,
        oceanRisk = 1.1
    }
}
