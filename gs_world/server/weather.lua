print('[gs_world] server/weather.lua loaded')

CurrentWeather = CurrentWeather or {}
local NextWeatherChangeAt = 0
local LastDynamicProfile = nil

math.randomseed(os.time())

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

local function normalizeProfileName(profileName)
    if type(profileName) ~= 'string' then
        return nil
    end

    return string.upper(profileName)
end

local function getCurrentServerHour()
    local hour = tonumber(os.date('%H'))
    return hour or 12
end

local function isHourInRange(hour, minHour, maxHour)
    minHour = tonumber(minHour) or 0
    maxHour = tonumber(maxHour) or 23

    if minHour <= maxHour then
        return hour >= minHour and hour <= maxHour
    end

    return hour >= minHour or hour <= maxHour
end

local function clampDurationMinutes(value, fallback)
    local duration = tonumber(value) or fallback

    if duration < 1 then
        duration = 1
    end

    return math.floor(duration)
end

local function clampWindDirection(value)
    local direction = tonumber(value) or 0.0
    direction = direction % 360.0

    if direction < 0.0 then
        direction = direction + 360.0
    end

    return direction
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
        baseWeather = normalizedType,
        temperature = tonumber(overrides.temperature) or tonumber(weatherConfig.DefaultTemperature) or 72,
        windSpeed = tonumber(overrides.windSpeed) or tonumber(weatherConfig.DefaultWindSpeed) or 0.0,
        windDirection = clampWindDirection(overrides.windDirection or weatherConfig.DefaultWindDirection or 0.0),
        windGusts = tonumber(overrides.windGusts) or tonumber(weatherConfig.DefaultWindGusts) or 0.0,
        windRisk = tonumber(overrides.windRisk) or tonumber(weatherConfig.DefaultWindRisk) or 1.0,
        fogLevel = tonumber(overrides.fogLevel) or tonumber(weatherConfig.DefaultFogLevel) or 0.0,
        rainIntensity = tonumber(overrides.rainIntensity) or getRainIntensity(normalizedType),
        isStorm = normalizedType == 'THUNDER',
        transitionMs = tonumber(overrides.transitionMs) or tonumber(weatherConfig.TransitionMs) or 15000,
        profile = overrides.profile,
        profileLabel = overrides.profileLabel,
        durationMinutes = tonumber(overrides.durationMinutes),
        endsAt = tonumber(overrides.endsAt),
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
    local weatherConfig = getWeatherConfig()
    local remainingMinutes = 0

    if NextWeatherChangeAt > os.time() then
        remainingMinutes = math.ceil((NextWeatherChangeAt - os.time()) / 60)
    end

    return ('[gs_world] Weather=%s profile=%s cycle=%s dynamic=%s nextChangeMinutes=%s windSpeed=%s windDirection=%s windGusts=%s windRisk=%s qb-weathersync=%s cd_easytime=%s vSync=%s Renewed-Weathersync=%s'):format(
        tostring(CurrentWeather.type),
        tostring(CurrentWeather.profile or LastDynamicProfile or 'manual'),
        tostring(weatherConfig.CycleEnabled == true),
        tostring(weatherConfig.DynamicEnabled == true),
        tostring(remainingMinutes),
        tostring(CurrentWeather.windSpeed or 0.0),
        tostring(CurrentWeather.windDirection or 0.0),
        tostring(CurrentWeather.windGusts or 0.0),
        tostring(CurrentWeather.windRisk or 1.0),
        tostring(conflictStates['qb-weathersync']),
        tostring(conflictStates.cd_easytime),
        tostring(conflictStates.vSync),
        tostring(conflictStates['Renewed-Weathersync'])
    )
end

local function BuildWindStatusMessage()
    return ('[gs_world] Wind profile=%s baseWeather=%s speed=%s direction=%s gusts=%s risk=%s'):format(
        tostring(CurrentWeather.profile or LastDynamicProfile or 'manual'),
        tostring(CurrentWeather.baseWeather or CurrentWeather.type),
        tostring(CurrentWeather.windSpeed or 0.0),
        tostring(CurrentWeather.windDirection or 0.0),
        tostring(CurrentWeather.windGusts or 0.0),
        tostring(CurrentWeather.windRisk or 1.0)
    )
end

local function getProfileWeatherType(profileName, profile)
    local weatherType = normalizeWeatherType(profile and profile.weatherType)

    if weatherType and IsAllowedWeatherType(weatherType) then
        return weatherType
    end

    local profileTypes = {
        CLEAR_DAY = 'EXTRASUNNY',
        PARTLY_CLOUDY = 'CLOUDS',
        CLOUDY = 'CLOUDS',
        OVERCAST_DAY = 'OVERCAST',
        LIGHT_RAIN = 'RAIN',
        STEADY_RAIN = 'RAIN',
        HEAVY_RAIN = 'RAIN',
        THUNDERSTORM = 'THUNDER',
        SEVERE_STORM = 'THUNDER',
        MORNING_FOG = 'FOGGY',
        DENSE_FOG = 'FOGGY',
        HOT_CLEAR = 'EXTRASUNNY',
        HEATWAVE = 'EXTRASUNNY',
        WINDY = 'CLOUDS',
        COASTAL_STORM = 'THUNDER',
        HURRICANE_CONDITIONS = 'THUNDER'
    }

    return profileTypes[profileName] or 'CLEAR'
end

local function getDynamicProfile(profileName)
    local normalizedName = normalizeProfileName(profileName)

    if not normalizedName then
        return nil, nil
    end

    local profiles = getWeatherConfig().DynamicProfiles or getWeatherConfig().Profiles or {}
    return normalizedName, profiles[normalizedName]
end

local function isDynamicProfileAllowed(profile, hour)
    local weatherConfig = getWeatherConfig()

    if type(profile) ~= 'table' then
        return false
    end

    if not isHourInRange(hour, profile.minHour, profile.maxHour) then
        return false
    end

    if profile.severe == true and weatherConfig.AllowSevereWeather == false then
        return false
    end

    if profile.heatwave == true and weatherConfig.AllowHeatwaves == false then
        return false
    end

    if profile.fog == true and weatherConfig.AllowFog == false then
        return false
    end

    return tonumber(profile.weight) and tonumber(profile.weight) > 0
end

local function chooseDynamicProfile()
    local weatherConfig = getWeatherConfig()
    local profiles = weatherConfig.DynamicProfiles or {}
    local hour = getCurrentServerHour()
    local weightedProfiles = {}
    local totalWeight = 0

    for profileName, profile in pairs(profiles) do
        if isDynamicProfileAllowed(profile, hour) then
            local weight = tonumber(profile.weight) or 0

            totalWeight = totalWeight + weight
            weightedProfiles[#weightedProfiles + 1] = {
                name = normalizeProfileName(profileName),
                profile = profile,
                weight = weight
            }
        end
    end

    if totalWeight <= 0 or #weightedProfiles == 0 then
        return 'PARTLY_CLOUDY', {
            weatherType = 'CLOUDS',
            temperature = getWeatherConfig().DefaultTemperature,
            windSpeed = getWeatherConfig().DefaultWindSpeed,
            windDirection = getWeatherConfig().DefaultWindDirection,
            windGusts = getWeatherConfig().DefaultWindGusts,
            windRisk = getWeatherConfig().DefaultWindRisk,
            fogLevel = getWeatherConfig().DefaultFogLevel
        }
    end

    local roll = math.random() * totalWeight
    local cursor = 0

    for _, entry in ipairs(weightedProfiles) do
        cursor = cursor + entry.weight

        if roll <= cursor then
            return entry.name, entry.profile
        end
    end

    local fallback = weightedProfiles[#weightedProfiles]
    return fallback.name, fallback.profile
end

local function getNextDynamicDurationMinutes()
    local weatherConfig = getWeatherConfig()
    local minDuration = clampDurationMinutes(weatherConfig.MinDurationMinutes, 20)
    local maxDuration = clampDurationMinutes(weatherConfig.MaxDurationMinutes, 60)

    if maxDuration < minDuration then
        maxDuration = minDuration
    end

    return math.random(minDuration, maxDuration)
end

local function applyDynamicWeather(reason)
    local profileName, profile = chooseDynamicProfile()
    profile = type(profile) == 'table' and profile or {}
    local durationMinutes = getNextDynamicDurationMinutes()
    local endsAt = os.time() + (durationMinutes * 60)
    local weatherType = getProfileWeatherType(profileName, profile)
    local windDirection = profile.windDirection

    if getWeatherConfig().RandomizeWindDirection == true then
        windDirection = math.random(0, 359)
    end

    local overrides = {
        temperature = profile.temperature,
        windSpeed = profile.windSpeed,
        windDirection = windDirection,
        windGusts = profile.windGusts,
        windRisk = profile.windRisk,
        fogLevel = profile.fogLevel,
        rainIntensity = profile.rainIntensity,
        transitionMs = profile.transitionMs,
        profile = profileName,
        profileLabel = profile.label or profileName,
        durationMinutes = durationMinutes,
        endsAt = endsAt
    }
    local ok, result = setWeather(weatherType, overrides, reason or ('dynamic:%s'):format(profileName))

    if ok then
        LastDynamicProfile = profileName
        NextWeatherChangeAt = endsAt
        debugPrint(('dynamic profile=%s type=%s duration=%sm'):format(profileName, tostring(result.type), tostring(durationMinutes)))
    end

    return ok, result
end

local function applyWeatherProfile(profileName, source, reason)
    local normalizedName, profile = getDynamicProfile(profileName)

    if type(profile) ~= 'table' then
        SendWeatherMessage(source, ('[gs_world] Unknown weather profile: %s'):format(tostring(profileName)))
        return false, 'unknown_profile'
    end

    local weatherType = getProfileWeatherType(normalizedName, profile)
    local windDirection = profile.windDirection

    if getWeatherConfig().RandomizeWindDirection == true then
        windDirection = math.random(0, 359)
    end

    local overrides = {
        temperature = profile.temperature,
        windSpeed = profile.windSpeed,
        windDirection = windDirection,
        windGusts = profile.windGusts,
        windRisk = profile.windRisk,
        fogLevel = profile.fogLevel,
        rainIntensity = profile.rainIntensity,
        transitionMs = profile.transitionMs,
        profile = normalizedName,
        profileLabel = profile.label or normalizedName
    }
    local ok, result = setWeather(weatherType, overrides, reason or ('profile:%s'):format(normalizedName))

    if not ok then
        SendWeatherMessage(source, ('[gs_world] Weather profile failed: %s'):format(tostring(result)))
        return false, result
    end

    LastDynamicProfile = normalizedName
    SendWeatherMessage(source, ('[gs_world] Weather profile %s applied type=%s wind=%s dir=%s gusts=%s risk=%s.'):format(
        normalizedName,
        tostring(result.type),
        tostring(result.windSpeed),
        tostring(result.windDirection),
        tostring(result.windGusts),
        tostring(result.windRisk)
    ))
    return true, result
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
            Wait(60000)

            if weatherConfig.Enabled ~= false and weatherConfig.CycleEnabled == true then
                if weatherConfig.DynamicEnabled == true then
                    if NextWeatherChangeAt <= 0 then
                        NextWeatherChangeAt = os.time() + (getNextDynamicDurationMinutes() * 60)
                    end

                    if os.time() >= NextWeatherChangeAt then
                        applyDynamicWeather('dynamic_cycle')
                    end
                else
                    local intervalMinutes = tonumber(weatherConfig.CycleIntervalMinutes) or 30

                    if intervalMinutes < 1 then
                        intervalMinutes = 1
                    end

                    if NextWeatherChangeAt <= 0 then
                        NextWeatherChangeAt = os.time() + math.floor(intervalMinutes * 60)
                    end

                    if os.time() >= NextWeatherChangeAt then
                        local cycleTypes = weatherConfig.CycleTypes or {}

                        if #cycleTypes > 0 then
                            local nextType = cycleTypes[math.random(1, #cycleTypes)]
                            debugPrint(('cycle selected type=%s'):format(tostring(nextType)))
                            setWeather(nextType, nil, 'cycle')
                            NextWeatherChangeAt = os.time() + math.floor(intervalMinutes * 60)
                        end
                    end
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

    if action == 'dynamic' then
        local value = string.lower(args[2] or '')

        if value == 'on' or value == 'true' or value == 'enable' or value == 'enabled' then
            getWeatherConfig().DynamicEnabled = true
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Dynamic weather enabled.')
            return
        end

        if value == 'off' or value == 'false' or value == 'disable' or value == 'disabled' then
            getWeatherConfig().DynamicEnabled = false
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Dynamic weather disabled.')
            return
        end

        SendWeatherMessage(source, '[gs_world] Usage: /gsweather dynamic on|off')
        return
    end

    if action == 'cycle' then
        local value = string.lower(args[2] or '')

        if value == 'on' or value == 'true' or value == 'enable' or value == 'enabled' then
            getWeatherConfig().CycleEnabled = true
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Weather cycle enabled.')
            return
        end

        if value == 'off' or value == 'false' or value == 'disable' or value == 'disabled' then
            getWeatherConfig().CycleEnabled = false
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Weather cycle disabled.')
            return
        end

        SendWeatherMessage(source, '[gs_world] Usage: /gsweather cycle on|off')
        return
    end

    if action == 'next' then
        if getWeatherConfig().DynamicEnabled == true then
            local ok, result = applyDynamicWeather(('command:%s'):format(tostring(source)))

            if ok then
                SendWeatherMessage(source, ('[gs_world] Dynamic weather changed to %s profile=%s duration=%sm.'):format(
                    tostring(result.type),
                    tostring(result.profile),
                    tostring(result.durationMinutes)
                ))
                return
            end

            SendWeatherMessage(source, ('[gs_world] Dynamic weather change failed: %s'):format(tostring(result)))
            return
        end

        local cycleTypes = getWeatherConfig().CycleTypes or {}

        if #cycleTypes > 0 then
            local nextType = cycleTypes[math.random(1, #cycleTypes)]
            SetLivingCityWeather(nextType, source)
            return
        end

        SendWeatherMessage(source, '[gs_world] No cycle weather types are configured.')
        return
    end

    if action == 'wind' then
        SendWeatherMessage(source, BuildWindStatusMessage())
        return
    end

    if action == 'winddir' then
        local direction = tonumber(args[2])

        if not direction then
            SendWeatherMessage(source, '[gs_world] Usage: /gsweather winddir [0-359]')
            return
        end

        CurrentWeather.windDirection = clampWindDirection(direction)
        SyncWeatherToAll()
        SendWeatherMessage(source, ('[gs_world] Wind direction set to %s.'):format(tostring(CurrentWeather.windDirection)))
        return
    end

    if action == 'windspeed' then
        local speed = tonumber(args[2])

        if not speed then
            SendWeatherMessage(source, '[gs_world] Usage: /gsweather windspeed [number]')
            return
        end

        if speed < 0.0 then
            speed = 0.0
        end

        CurrentWeather.windSpeed = speed
        SyncWeatherToAll()
        SendWeatherMessage(source, ('[gs_world] Wind speed set to %s.'):format(tostring(CurrentWeather.windSpeed)))
        return
    end

    local profileName, profile = getDynamicProfile(action)

    if profile then
        applyWeatherProfile(profileName, source, ('command:%s'):format(tostring(source)))
        return
    end

    SendWeatherMessage(source, '[gs_world] Usage: /gsweather status|clear|rain|thunder|fog|sync|wind|winddir [0-359]|windspeed [number]|dynamic on|off|cycle on|off|next|profile_name')
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

    if action == 'dynamic' then
        local value = string.lower(args[2] or '')

        if value == 'on' or value == 'true' or value == 'enable' or value == 'enabled' then
            getWeatherConfig().DynamicEnabled = true
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Dynamic weather enabled.')
            return
        end

        if value == 'off' or value == 'false' or value == 'disable' or value == 'disabled' then
            getWeatherConfig().DynamicEnabled = false
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Dynamic weather disabled.')
            return
        end

        SendWeatherMessage(source, '[gs_world] Usage: /weather dynamic on|off')
        return
    end

    if action == 'cycle' then
        local value = string.lower(args[2] or '')

        if value == 'on' or value == 'true' or value == 'enable' or value == 'enabled' then
            getWeatherConfig().CycleEnabled = true
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Weather cycle enabled.')
            return
        end

        if value == 'off' or value == 'false' or value == 'disable' or value == 'disabled' then
            getWeatherConfig().CycleEnabled = false
            NextWeatherChangeAt = 0
            SendWeatherMessage(source, '[gs_world] Weather cycle disabled.')
            return
        end

        SendWeatherMessage(source, '[gs_world] Usage: /weather cycle on|off')
        return
    end

    if action == 'next' then
        if getWeatherConfig().DynamicEnabled == true then
            local ok, result = applyDynamicWeather(('command:%s'):format(tostring(source)))

            if ok then
                SendWeatherMessage(source, ('[gs_world] Dynamic weather changed to %s profile=%s duration=%sm.'):format(
                    tostring(result.type),
                    tostring(result.profile),
                    tostring(result.durationMinutes)
                ))
                return
            end

            SendWeatherMessage(source, ('[gs_world] Dynamic weather change failed: %s'):format(tostring(result)))
            return
        end

        local cycleTypes = getWeatherConfig().CycleTypes or {}

        if #cycleTypes > 0 then
            local nextType = cycleTypes[math.random(1, #cycleTypes)]
            SetLivingCityWeather(nextType, source)
            return
        end

        SendWeatherMessage(source, '[gs_world] No cycle weather types are configured.')
        return
    end

    if action == 'wind' then
        SendWeatherMessage(source, BuildWindStatusMessage())
        return
    end

    if action == 'winddir' then
        local direction = tonumber(args[2])

        if not direction then
            SendWeatherMessage(source, '[gs_world] Usage: /weather winddir [0-359]')
            return
        end

        CurrentWeather.windDirection = clampWindDirection(direction)
        SyncWeatherToAll()
        SendWeatherMessage(source, ('[gs_world] Wind direction set to %s.'):format(tostring(CurrentWeather.windDirection)))
        return
    end

    if action == 'windspeed' then
        local speed = tonumber(args[2])

        if not speed then
            SendWeatherMessage(source, '[gs_world] Usage: /weather windspeed [number]')
            return
        end

        if speed < 0.0 then
            speed = 0.0
        end

        CurrentWeather.windSpeed = speed
        SyncWeatherToAll()
        SendWeatherMessage(source, ('[gs_world] Wind speed set to %s.'):format(tostring(CurrentWeather.windSpeed)))
        return
    end

    local profileName, profile = getDynamicProfile(action)

    if profile then
        applyWeatherProfile(profileName, source, ('command:%s'):format(tostring(source)))
        return
    end

    SendWeatherMessage(source, '[gs_world] Usage: /weather status|clear|rain|thunder|fog|sync|wind|winddir [0-359]|windspeed [number]|dynamic on|off|cycle on|off|next|profile_name')
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    debugPrint(('resource start weather type=%s'):format(tostring(CurrentWeather.type)))
    warnIfWeatherConflictActive()
    if getWeatherConfig().Enabled ~= false and getWeatherConfig().CycleEnabled == true and getWeatherConfig().DynamicEnabled == true then
        applyDynamicWeather('resource_start')
    end
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

exports('GetWindSpeed', function()
    return tonumber(CurrentWeather.windSpeed) or 0.0
end)

exports('GetWindDirection', function()
    return tonumber(CurrentWeather.windDirection) or 0.0
end)

exports('GetWindGusts', function()
    return tonumber(CurrentWeather.windGusts) or 0.0
end)

exports('GetWindRiskModifier', function()
    return tonumber(CurrentWeather.windRisk) or 1.0
end)

exports('GetCurrentWind', function()
    return {
        speed = tonumber(CurrentWeather.windSpeed) or 0.0,
        direction = tonumber(CurrentWeather.windDirection) or 0.0,
        gusts = tonumber(CurrentWeather.windGusts) or 0.0,
        risk = tonumber(CurrentWeather.windRisk) or 1.0
    }
end)

runWeatherCycle()
