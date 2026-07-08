print('[gs_world] server/weather.lua loaded')

CurrentWeather = CurrentWeather or {}

local function getWeatherConfig()
    return Config.Weather or {}
end

local function debugPrint(message)
    if getWeatherConfig().Debug then
        print(('[gs_world:weather] %s'):format(message))
    end
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

local function normalizeWeatherType(weatherType)
    if type(weatherType) ~= 'string' then
        return nil
    end

    return string.upper(weatherType)
end

function IsAllowedWeatherType(weatherType)
    local normalizedType = normalizeWeatherType(weatherType)
    return normalizedType and getWeatherConfig().AllowedTypes and getWeatherConfig().AllowedTypes[normalizedType] == true
end

local function CanUseWeatherCommand(source)
    if source == 0 then
        return true
    end

    local weatherConfig = getWeatherConfig()

    if not weatherConfig.RequireAce then
        return true
    end

    return type(IsPlayerAceAllowed) == 'function' and IsPlayerAceAllowed(source, weatherConfig.AdminAce or 'gs.admin')
end

local WeatherConflictResources = {
    'qb-weathersync',
    'cd_easytime',
    'vSync',
    'Renewed-Weathersync'
}

local function getWeatherConflictStates()
    local states = {}

    for _, resourceName in ipairs(WeatherConflictResources) do
        local state = 'missing'

        if type(GetResourceState) == 'function' then
            state = GetResourceState(resourceName) or 'missing'
        end

        states[resourceName] = state
    end

    return states
end

local function warnIfWeatherConflictActive()
    local states = getWeatherConflictStates()

    for _, resourceName in ipairs(WeatherConflictResources) do
        if states[resourceName] == 'started' then
            print('[gs_world] WARNING: Another weather sync resource is active and may override Living City weather.')
            return true
        end
    end

    return false
end

function SendWeatherMessage(source, message)
    if source == 0 then
        print(message)
        return
    end

    if source and source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'gs_world', message }
        })
        return
    end

    print(message)
end

local function buildWeatherState(weatherType, overrides)
    local weatherConfig = getWeatherConfig()
    local normalizedType = normalizeWeatherType(weatherType) or weatherConfig.DefaultWeather or 'CLEAR'
    overrides = type(overrides) == 'table' and overrides or {}

    return {
        type = normalizedType,
        temperature = tonumber(overrides.temperature) or tonumber(weatherConfig.DefaultTemperature) or 72,
        windSpeed = tonumber(overrides.windSpeed) or tonumber(weatherConfig.DefaultWindSpeed) or 0.0,
        fogLevel = tonumber(overrides.fogLevel) or tonumber(weatherConfig.DefaultFogLevel) or 0.0,
        isStorm = normalizedType == 'THUNDER',
        transitionMs = tonumber(overrides.transitionMs) or tonumber(weatherConfig.TransitionMs) or 15000,
        updatedAt = os.time()
    }
end

function SyncWeatherToAll()
    TriggerClientEvent('gs_world:client:weather:sync', -1, copyTable(CurrentWeather))
end

local function setWeather(weatherType, overrides, reason)
    if getWeatherConfig().Enabled == false then
        return false, 'weather_disabled'
    end

    local normalizedType = normalizeWeatherType(weatherType)

    if not IsAllowedWeatherType(normalizedType) then
        debugPrint(('invalid weather request type=%s reason=%s'):format(tostring(weatherType), tostring(reason)))
        return false, 'invalid_weather_type'
    end

    CurrentWeather = buildWeatherState(normalizedType, overrides)
    debugPrint(('weather changed type=%s reason=%s'):format(tostring(CurrentWeather.type), tostring(reason or 'manual')))
    SyncWeatherToAll()

    return true, copyTable(CurrentWeather)
end

function SetLivingCityWeather(weatherType, source)
    if not CanUseWeatherCommand(source) then
        SendWeatherMessage(source, 'You do not have permission to use Living City weather commands.')
        return false
    end

    local ok, result = setWeather(weatherType, nil, ('command:%s'):format(tostring(source)))

    if not ok then
        SendWeatherMessage(source, ('[gs_world] Weather change failed: %s'):format(tostring(result)))
        return false
    end

    SendWeatherMessage(source, ('[gs_world] Weather changed to %s.'):format(tostring(result.type)))
    return true
end

function BuildWeatherStatusMessage()
    local conflictStates = getWeatherConflictStates()

    return ('[gs_world] Weather=%s cycle=%s qb-weathersync=%s cd_easytime=%s vSync=%s Renewed-Weathersync=%s'):format(
        tostring(CurrentWeather.type),
        tostring(getWeatherConfig().CycleEnabled == true),
        tostring(conflictStates['qb-weathersync']),
        tostring(conflictStates.cd_easytime),
        tostring(conflictStates.vSync),
        tostring(conflictStates['Renewed-Weathersync'])
    )
end

local function getEffectsForType(weatherType)
    local weatherConfig = getWeatherConfig()
    local normalizedType = normalizeWeatherType(weatherType or CurrentWeather.type)
    local effects = weatherConfig.Effects and weatherConfig.Effects[normalizedType]

    return effects or {}
end

local function getEffectValue(effectName)
    local value = tonumber(getEffectsForType()[effectName])
    return value or 1.0
end

local function runWeatherCycle()
    CreateThread(function()
        while true do
            local weatherConfig = getWeatherConfig()
            local intervalMinutes = tonumber(weatherConfig.CycleIntervalMinutes) or 30

            if intervalMinutes < 1 then
                intervalMinutes = 1
            end

            Wait(math.floor(intervalMinutes * 60000))

            if weatherConfig.Enabled ~= false and weatherConfig.CycleEnabled == true then
                local cycleTypes = weatherConfig.CycleTypes or {}

                if #cycleTypes > 0 then
                    local nextType = cycleTypes[math.random(1, #cycleTypes)]
                    debugPrint(('cycle selected type=%s'):format(tostring(nextType)))
                    setWeather(nextType, nil, 'cycle')
                end
            end
        end
    end)
end

local weatherConfig = getWeatherConfig()
CurrentWeather = buildWeatherState(weatherConfig.DefaultWeather or 'CLEAR')

RegisterNetEvent('gs_world:server:weather:requestSync', function()
    local src = source
    debugPrint(('sync requested source=%s'):format(tostring(src)))
    TriggerClientEvent('gs_world:client:weather:sync', src, copyTable(CurrentWeather))
end)

RegisterNetEvent('gs_world:server:weather:setWeather', function(weatherType, overrides)
    local src = source

    if src and src > 0 and not CanUseWeatherCommand(src) then
        debugPrint(('setWeather denied source=%s type=%s'):format(tostring(src), tostring(weatherType)))
        return
    end

    setWeather(weatherType, overrides, ('event:%s'):format(tostring(src)))
end)

RegisterCommand('gsweather', function(source, args, rawCommand)
    if not CanUseWeatherCommand(source) then
        SendWeatherMessage(source, 'You do not have permission to use Living City weather commands.')
        return
    end

    args = args or {}
    local action = string.lower(args[1] or 'status')

    if action == 'status' then
        SendWeatherMessage(source, BuildWeatherStatusMessage())
        return
    end

    if action == 'clear' then
        SetLivingCityWeather('CLEAR', source)
        return
    end

    if action == 'rain' then
        SetLivingCityWeather('RAIN', source)
        return
    end

    if action == 'thunder' then
        SetLivingCityWeather('THUNDER', source)
        return
    end

    if action == 'fog' then
        SetLivingCityWeather('FOGGY', source)
        return
    end

    if action == 'sync' then
        SyncWeatherToAll()
        SendWeatherMessage(source, '[gs_world] Weather synced to all clients.')
        return
    end

    SendWeatherMessage(source, '[gs_world] Usage: /gsweather status|clear|rain|thunder|fog|sync')
end, false)

print('[gs_world] Weather command registered: /gsweather')

RegisterCommand('weather', function(source, args, rawCommand)
    if not CanUseWeatherCommand(source) then
        SendWeatherMessage(source, 'You do not have permission to use Living City weather commands.')
        return
    end

    args = args or {}
    local action = string.lower(args[1] or 'status')

    if action == 'status' then
        SendWeatherMessage(source, BuildWeatherStatusMessage())
        return
    end

    if action == 'clear' then
        SetLivingCityWeather('CLEAR', source)
        return
    end

    if action == 'rain' then
        SetLivingCityWeather('RAIN', source)
        return
    end

    if action == 'thunder' then
        SetLivingCityWeather('THUNDER', source)
        return
    end

    if action == 'fog' then
        SetLivingCityWeather('FOGGY', source)
        return
    end

    if action == 'sync' then
        SyncWeatherToAll()
        SendWeatherMessage(source, '[gs_world] Weather synced to all clients.')
        return
    end

    SendWeatherMessage(source, '[gs_world] Usage: /weather status|clear|rain|thunder|fog|sync')
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    debugPrint(('resource start weather type=%s'):format(tostring(CurrentWeather.type)))
    warnIfWeatherConflictActive()
    SyncWeatherToAll()
end)

exports('GetCurrentWeather', function()
    return copyTable(CurrentWeather)
end)

exports('IsRaining', function()
    return CurrentWeather.type == 'RAIN' or CurrentWeather.type == 'THUNDER' or CurrentWeather.type == 'CLEARING'
end)

exports('IsStorming', function()
    return CurrentWeather.type == 'THUNDER'
end)

exports('IsFoggy', function()
    return CurrentWeather.type == 'FOGGY' or CurrentWeather.type == 'SMOG'
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

runWeatherCycle()
