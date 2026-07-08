local CurrentWeather = nil
local WindGustToken = 0

local function getWeatherConfig()
    return Config.Weather or {}
end

local function debugPrint(message)
    if getWeatherConfig().Debug then
        print(('[gs_world:weather] %s'):format(message))
    end
end

local function getRainIntensity(weatherType)
    if weatherType == 'THUNDER' then
        return 1.0
    end

    if weatherType == 'RAIN' then
        return 0.55
    end

    if weatherType == 'CLEARING' then
        return 0.2
    end

    return 0.0
end

local function copyTable(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return '[cyclic]'
    end

    seen[value] = true

    local copy = {}

    for key, childValue in pairs(value) do
        copy[key] = copyTable(childValue, seen)
    end

    seen[value] = nil
    return copy
end

local function getEffectsForType(weatherType)
    local normalizedType = type(weatherType) == 'string' and string.upper(weatherType) or CurrentWeather and CurrentWeather.type
    local effects = getWeatherConfig().Effects and getWeatherConfig().Effects[normalizedType]

    return effects or {}
end

local function getEffectValue(effectName)
    local value = tonumber(getEffectsForType()[effectName])
    return value or 1.0
end

local function applyWind(speed, direction)
    SetWindSpeed(tonumber(speed) or 0.0)
    SetWindDirection(tonumber(direction) or 0.0)
end

local function startWindGusts(state)
    WindGustToken = WindGustToken + 1
    local gustToken = WindGustToken
    local weatherConfig = getWeatherConfig()

    if weatherConfig.EnableWindGusts ~= true then
        return
    end

    local windSpeed = tonumber(state.windSpeed) or 0.0
    local windDirection = tonumber(state.windDirection) or 0.0
    local windGusts = tonumber(state.windGusts) or 0.0
    local windRisk = tonumber(state.windRisk) or 1.0

    if windGusts <= windSpeed or windRisk <= 1.05 then
        return
    end

    local profile = state.profile or state.type or 'manual'
    local intervalMs = math.max(5, tonumber(weatherConfig.WindGustIntervalSeconds) or 45) * 1000
    local durationMs = math.max(1, tonumber(weatherConfig.WindGustDurationSeconds) or 8) * 1000

    CreateThread(function()
        while gustToken == WindGustToken and CurrentWeather and (CurrentWeather.profile or CurrentWeather.type) == profile do
            Wait(intervalMs)

            if gustToken ~= WindGustToken or not CurrentWeather or (CurrentWeather.profile or CurrentWeather.type) ~= profile then
                break
            end

            applyWind(windGusts, windDirection)
            Wait(durationMs)

            if gustToken ~= WindGustToken or not CurrentWeather or (CurrentWeather.profile or CurrentWeather.type) ~= profile then
                break
            end

            applyWind(windSpeed, windDirection)
        end
    end)
end

local function applyWeather(state)
    if type(state) ~= 'table' or type(state.type) ~= 'string' then
        return
    end

    CurrentWeather = state

    local weatherType = string.upper(state.type)
    local transitionMs = tonumber(state.transitionMs) or tonumber(getWeatherConfig().TransitionMs) or 0
    local transitionSeconds = math.max(0.0, transitionMs / 1000.0)
    local rainIntensity = tonumber(state.rainIntensity) or getRainIntensity(weatherType)
    local windSpeed = tonumber(state.windSpeed) or 0.0
    local windDirection = tonumber(state.windDirection) or 0.0

    debugPrint(('sync type=%s transition=%s wind=%s direction=%s rain=%s'):format(
        tostring(weatherType),
        tostring(transitionSeconds),
        tostring(windSpeed),
        tostring(windDirection),
        tostring(rainIntensity)
    ))

    ClearOverrideWeather()
    ClearWeatherTypePersist()

    if transitionSeconds > 0.0 then
        SetWeatherTypeOverTime(weatherType, transitionSeconds)
    else
        SetWeatherTypeNowPersist(weatherType)
    end

    SetRainFxIntensity(rainIntensity)
    applyWind(windSpeed, windDirection)
    startWindGusts(state)

    CreateThread(function()
        if transitionSeconds > 0.0 then
            Wait(math.floor(transitionSeconds * 1000))
        end

        SetWeatherTypePersist(weatherType)
        SetWeatherTypeNowPersist(weatherType)
        SetRainFxIntensity(rainIntensity)
        applyWind(windSpeed, windDirection)
    end)
end

local function requestWeatherSync()
    TriggerServerEvent('gs_world:server:weather:requestSync')
end

RegisterNetEvent('gs_world:client:weather:sync', function(state)
    applyWeather(state)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    requestWeatherSync()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    CreateThread(function()
        Wait(1000)
        requestWeatherSync()
    end)
end)

exports('GetCurrentWeather', function()
    return copyTable(CurrentWeather or {})
end)

exports('GetCurrentWeatherProfile', function()
    return CurrentWeather and CurrentWeather.profile or 'manual'
end)

exports('GetWeatherEffects', function(weatherType)
    return copyTable(getEffectsForType(weatherType))
end)

exports('GetVisibilityModifier', function()
    return getEffectValue('visibility')
end)

exports('GetCrimeModifier', function()
    return getEffectValue('crimeChance')
end)

exports('GetTrafficModifier', function()
    return getEffectValue('traffic')
end)

exports('GetWitnessModifier', function()
    return getEffectValue('witnessChance')
end)

exports('GetPoliceResponseModifier', function()
    return getEffectValue('policeResponse')
end)

exports('GetPedestrianModifier', function()
    return getEffectValue('pedestrianDensity')
end)

exports('GetRoadRiskModifier', function()
    return getEffectValue('roadRisk')
end)

exports('GetOceanRiskModifier', function()
    return getEffectValue('oceanRisk')
end)

exports('GetWindSpeed', function()
    return tonumber(CurrentWeather and CurrentWeather.windSpeed) or 0.0
end)

exports('GetWindDirection', function()
    return tonumber(CurrentWeather and CurrentWeather.windDirection) or 0.0
end)

exports('GetWindGusts', function()
    return tonumber(CurrentWeather and CurrentWeather.windGusts) or 0.0
end)

exports('GetWindRiskModifier', function()
    return tonumber(CurrentWeather and CurrentWeather.windRisk) or 1.0
end)

exports('GetCurrentWind', function()
    return {
        speed = tonumber(CurrentWeather and CurrentWeather.windSpeed) or 0.0,
        direction = tonumber(CurrentWeather and CurrentWeather.windDirection) or 0.0,
        gusts = tonumber(CurrentWeather and CurrentWeather.windGusts) or 0.0,
        risk = tonumber(CurrentWeather and CurrentWeather.windRisk) or 1.0
    }
end)
