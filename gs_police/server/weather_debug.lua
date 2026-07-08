print('[gs_police] weather_debug.lua loaded')

RegisterCommand('police_weatherdebug', function(source, args, rawCommand)
    local resourceName = 'gs_world'

    local function safeExport(exportName, fallback)
        if GetResourceState(resourceName) ~= 'started' then
            return fallback
        end

        local ok, result = pcall(function()
            return exports[resourceName][exportName]()
        end)

        if not ok or result == nil then
            return fallback
        end

        return result
    end

    local current = safeExport('GetCurrentWeather', {})
    local profile = safeExport('GetCurrentWeatherProfile', 'UNKNOWN')
    local visibility = safeExport('GetVisibilityModifier', 1.0)
    local witness = safeExport('GetWitnessModifier', 1.0)
    local response = safeExport('GetPoliceResponseModifier', 1.0)
    local traffic = safeExport('GetTrafficModifier', 1.0)
    local pedestrian = safeExport('GetPedestrianModifier', 1.0)
    local roadRisk = safeExport('GetRoadRiskModifier', 1.0)
    local windSpeed = safeExport('GetWindSpeed', 0.0)
    local windDirection = safeExport('GetWindDirection', 0.0)
    local windGusts = safeExport('GetWindGusts', 0.0)
    local windRisk = safeExport('GetWindRiskModifier', 1.0)

    local weatherType = 'UNKNOWN'

    if type(current) == 'table' then
        weatherType = current.type or current.baseWeather or 'UNKNOWN'
    end

    local msg = string.format(
        '[gs_police] WeatherDebug gs_world=%s profile=%s base=%s visibility=%.2f witness=%.2f response=%.2f traffic=%.2f pedestrian=%.2f roadRisk=%.2f windSpeed=%.1f windDir=%.1f windGusts=%.1f windRisk=%.2f',
        GetResourceState(resourceName),
        tostring(profile),
        tostring(weatherType),
        tonumber(visibility) or 1.0,
        tonumber(witness) or 1.0,
        tonumber(response) or 1.0,
        tonumber(traffic) or 1.0,
        tonumber(pedestrian) or 1.0,
        tonumber(roadRisk) or 1.0,
        tonumber(windSpeed) or 0.0,
        tonumber(windDirection) or 0.0,
        tonumber(windGusts) or 0.0,
        tonumber(windRisk) or 1.0
    )

    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'gs_police', msg }
        })
    end
end, false)

print('[gs_police] Weather debug command registered: /police_weatherdebug')
