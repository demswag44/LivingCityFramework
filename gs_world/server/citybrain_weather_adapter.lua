local CITYBRAIN_RESOURCE = 'gs_citybrain'

local WEATHER_SIGNAL_TYPES = {
    storm_risk = 'STORM_RISK',
    heavy_rain = 'HEAVY_RAIN',
    fog = 'LOW_VISIBILITY',
    low_visibility = 'LOW_VISIBILITY',
    high_wind = 'HIGH_WIND',
    heat_stress = 'HEAT_STRESS',
    cold_stress = 'COLD_STRESS',
    flood_risk = 'FLOOD_RISK'
}

local function isIntegrationEnabled()
    return Config and Config.CityBrainWeatherIntegrationEnabled == true
end

local function isRecommendationReadEnabled()
    return Config and Config.CityBrainReadRecommendationsEnabled == true
end

local function isCityBrainStarted()
    return type(GetResourceState) == 'function'
        and GetResourceState(CITYBRAIN_RESOURCE) == 'started'
end

local function normalizeCoords(coords)
    if type(coords) ~= 'table' then
        return nil
    end

    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])

    if not x or not y or not z then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function normalizeZone(zone)
    if type(zone) == 'string' and zone ~= '' then
        return zone
    end

    return 'unknown'
end

local function clampPercent(value, fallback)
    local numericValue = tonumber(value) or fallback or 0

    if numericValue < 0 then
        return 0
    end

    if numericValue > 100 then
        return 100
    end

    return numericValue
end

local function getWeatherSignalType(conditionType)
    if type(conditionType) ~= 'string' or conditionType == '' then
        return 'STORM_RISK'
    end

    return WEATHER_SIGNAL_TYPES[conditionType] or conditionType
end

function SubmitWeatherCityBrainSignal(signalData)
    if not isIntegrationEnabled() then
        return false, 'disabled'
    end

    if type(signalData) ~= 'table' then
        return false, 'invalid_signal'
    end

    if not isCityBrainStarted() then
        return false, 'citybrain_not_started'
    end

    local payload = {
        sourceResource = GetCurrentResourceName(),
        signalType = signalData.signalType or 'STORM_RISK',
        category = 'weather',
        zone = normalizeZone(signalData.zone),
        coords = normalizeCoords(signalData.coords),
        strength = clampPercent(signalData.strength, 50),
        confidence = clampPercent(signalData.confidence, 65),
        metadata = signalData.metadata or {}
    }

    local ok, submitOk, signal, createdEvent = pcall(function()
        return exports[CITYBRAIN_RESOURCE]:SubmitSignal(payload)
    end)

    if not ok then
        return false, 'submit_failed'
    end

    return submitOk == true, signal or 'submit_rejected', createdEvent
end

function GetCityBrainDecisions()
    if not isRecommendationReadEnabled() or not isCityBrainStarted() then
        return {}
    end

    local ok, decisions = pcall(function()
        return exports[CITYBRAIN_RESOURCE]:GetActiveDecisions()
    end)

    if not ok or type(decisions) ~= 'table' then
        return {}
    end

    return decisions
end

function GetCityBrainDecisionsByType(decisionType)
    if not isRecommendationReadEnabled() or not isCityBrainStarted() then
        return {}
    end

    if type(decisionType) ~= 'string' or decisionType == '' then
        return {}
    end

    local ok, decisions = pcall(function()
        return exports[CITYBRAIN_RESOURCE]:GetDecisionsByType(decisionType)
    end)

    if not ok or type(decisions) ~= 'table' then
        return {}
    end

    return decisions
end

function ReportWeatherCityBrainCondition(conditionData)
    if type(conditionData) ~= 'table' then
        return false, 'invalid_condition'
    end

    local conditionType = conditionData.conditionType or conditionData.type or conditionData.weatherType
    local signalType = getWeatherSignalType(conditionType)

    return SubmitWeatherCityBrainSignal({
        signalType = signalType,
        zone = conditionData.zone,
        coords = conditionData.coords,
        strength = conditionData.strength or conditionData.intensity or conditionData.risk,
        confidence = conditionData.confidence,
        metadata = {
            conditionType = conditionType,
            weatherType = conditionData.weatherType,
            temperature = conditionData.temperature,
            windSpeed = conditionData.windSpeed,
            rainfall = conditionData.rainfall,
            visibility = conditionData.visibility,
            floodRisk = conditionData.floodRisk,
            source = conditionData.source
        }
    })
end

RegisterNetEvent('gs_world:server:reportWeatherCondition', function(conditionData)
    ReportWeatherCityBrainCondition(conditionData)
end)

exports('SubmitWeatherCityBrainSignal', SubmitWeatherCityBrainSignal)
exports('ReportWeatherCityBrainCondition', ReportWeatherCityBrainCondition)
exports('GetCityBrainDecisions', GetCityBrainDecisions)
exports('GetCityBrainDecisionsByType', GetCityBrainDecisionsByType)
