Config = Config or {}
Config.Weather = Config.Weather or {}

Config.Weather.Enabled = true
Config.Weather.Debug = false
Config.Weather.RequireAce = false
Config.Weather.AdminAce = 'gs.admin'
Config.Weather.DefaultWeather = 'CLEAR'
Config.Weather.DefaultTemperature = 72
Config.Weather.DefaultWindSpeed = 0.0
Config.Weather.DefaultWindDirection = 0.0
Config.Weather.DefaultWindGusts = 0.0
Config.Weather.DefaultWindRisk = 1.0
Config.Weather.DefaultFogLevel = 0.0
Config.Weather.TransitionMs = 15000
Config.Weather.CycleEnabled = true
Config.Weather.CycleIntervalMinutes = 30
Config.Weather.DynamicEnabled = true
Config.Weather.MinDurationMinutes = 20
Config.Weather.MaxDurationMinutes = 60
Config.Weather.AllowSevereWeather = true
Config.Weather.AllowHeatwaves = true
Config.Weather.AllowFog = true
Config.Weather.RandomizeWindDirection = true
Config.Weather.EnableWindGusts = true
Config.Weather.WindGustIntervalSeconds = 45
Config.Weather.WindGustDurationSeconds = 8

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

Config.Weather.DynamicProfiles = {
    CLEAR_DAY = {
        weight = 22,
        minHour = 6,
        maxHour = 20,
        weatherType = 'EXTRASUNNY',
        temperature = 76,
        windSpeed = 0.5,
        windDirection = 90.0,
        windGusts = 2.0,
        windRisk = 1.0,
        fogLevel = 0.0
    },

    PARTLY_CLOUDY = {
        weight = 18,
        minHour = 0,
        maxHour = 23,
        weatherType = 'CLOUDS',
        temperature = 72,
        windSpeed = 1.5,
        windDirection = 110.0,
        windGusts = 4.0,
        windRisk = 1.0,
        fogLevel = 0.0
    },

    CLOUDY = {
        weight = 16,
        minHour = 0,
        maxHour = 23,
        weatherType = 'CLOUDS',
        temperature = 68,
        windSpeed = 2.0,
        windDirection = 130.0,
        windGusts = 5.0,
        windRisk = 1.05,
        fogLevel = 0.0
    },

    OVERCAST_DAY = {
        weight = 12,
        minHour = 0,
        maxHour = 23,
        weatherType = 'OVERCAST',
        temperature = 66,
        windSpeed = 2.5,
        windDirection = 150.0,
        windGusts = 6.0,
        windRisk = 1.08,
        fogLevel = 0.0
    },

    LIGHT_RAIN = {
        weight = 10,
        minHour = 0,
        maxHour = 23,
        weatherType = 'RAIN',
        temperature = 63,
        windSpeed = 4.0,
        windDirection = 160.0,
        windGusts = 7.0,
        windRisk = 1.1,
        fogLevel = 0.0
    },

    STEADY_RAIN = {
        weight = 7,
        minHour = 0,
        maxHour = 23,
        weatherType = 'RAIN',
        temperature = 61,
        windSpeed = 4.0,
        windDirection = 175.0,
        windGusts = 9.0,
        windRisk = 1.18,
        fogLevel = 0.0
    },

    HEAVY_RAIN = {
        weight = 4,
        minHour = 0,
        maxHour = 23,
        weatherType = 'RAIN',
        temperature = 59,
        windSpeed = 8.0,
        windDirection = 190.0,
        windGusts = 13.0,
        windRisk = 1.3,
        fogLevel = 0.0
    },

    THUNDERSTORM = {
        weight = 3,
        minHour = 12,
        maxHour = 23,
        weatherType = 'THUNDER',
        temperature = 62,
        windSpeed = 12.0,
        windDirection = 220.0,
        windGusts = 20.0,
        windRisk = 1.6,
        fogLevel = 0.0
    },

    SEVERE_STORM = {
        weight = 1,
        minHour = 14,
        maxHour = 23,
        severe = true,
        weatherType = 'THUNDER',
        temperature = 58,
        windSpeed = 16.0,
        windDirection = 240.0,
        windGusts = 26.0,
        windRisk = 1.9,
        fogLevel = 0.0
    },

    MORNING_FOG = {
        weight = 8,
        minHour = 4,
        maxHour = 9,
        fog = true,
        weatherType = 'FOGGY',
        temperature = 57,
        windSpeed = 0.5,
        windDirection = 80.0,
        windGusts = 2.5,
        windRisk = 1.05,
        fogLevel = 0.65
    },

    DENSE_FOG = {
        weight = 3,
        minHour = 0,
        maxHour = 8,
        fog = true,
        weatherType = 'FOGGY',
        temperature = 55,
        windSpeed = 0.2,
        windDirection = 60.0,
        windGusts = 1.0,
        windRisk = 1.0,
        fogLevel = 0.9
    },

    HOT_CLEAR = {
        weight = 5,
        minHour = 10,
        maxHour = 18,
        weatherType = 'EXTRASUNNY',
        temperature = 92,
        windSpeed = 1.0,
        windDirection = 120.0,
        windGusts = 3.0,
        windRisk = 1.0,
        fogLevel = 0.0
    },

    HEATWAVE = {
        weight = 1,
        minHour = 11,
        maxHour = 18,
        heatwave = true,
        weatherType = 'EXTRASUNNY',
        temperature = 101,
        windSpeed = 0.5,
        windDirection = 100.0,
        windGusts = 2.0,
        windRisk = 1.15,
        fogLevel = 0.0
    },

    WINDY = {
        weight = 5,
        minHour = 0,
        maxHour = 23,
        weatherType = 'CLOUDS',
        temperature = 70,
        windSpeed = 10.0,
        windDirection = 180.0,
        windGusts = 16.0,
        windRisk = 1.4,
        fogLevel = 0.0
    },

    COASTAL_STORM = {
        weight = 1,
        minHour = 0,
        maxHour = 23,
        severe = true,
        coastal = true,
        weatherType = 'THUNDER',
        temperature = 60,
        windSpeed = 18.0,
        windDirection = 270.0,
        windGusts = 30.0,
        windRisk = 2.1,
        fogLevel = 0.0
    },

    HURRICANE_CONDITIONS = {
        weight = 1,
        minHour = 0,
        maxHour = 23,
        severe = true,
        coastal = true,
        weatherType = 'THUNDER',
        temperature = 62,
        windSpeed = 25.0,
        windDirection = 270.0,
        windGusts = 40.0,
        windRisk = 2.7,
        fogLevel = 0.0
    }
}

Config.Weather.Profiles = Config.Weather.DynamicProfiles

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
