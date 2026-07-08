local CurrentWeather = nil

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

local function applyWeather(state)
    if type(state) ~= 'table' or type(state.type) ~= 'string' then
        return
    end

    CurrentWeather = state

    local weatherType = string.upper(state.type)
    local transitionMs = tonumber(state.transitionMs) or tonumber(getWeatherConfig().TransitionMs) or 0
    local transitionSeconds = math.max(0.0, transitionMs / 1000.0)
    local rainIntensity = getRainIntensity(weatherType)
    local windSpeed = tonumber(state.windSpeed) or 0.0

    debugPrint(('sync type=%s transition=%s wind=%s rain=%s'):format(
        tostring(weatherType),
        tostring(transitionSeconds),
        tostring(windSpeed),
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
    SetWindSpeed(windSpeed)

    CreateThread(function()
        if transitionSeconds > 0.0 then
            Wait(math.floor(transitionSeconds * 1000))
        end

        SetWeatherTypePersist(weatherType)
        SetWeatherTypeNowPersist(weatherType)
        SetRainFxIntensity(rainIntensity)
        SetWindSpeed(windSpeed)
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
