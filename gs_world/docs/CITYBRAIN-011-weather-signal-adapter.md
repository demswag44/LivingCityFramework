# CITYBRAIN-011 Weather Signal Adapter

`gs_world` can optionally report environmental conditions into `gs_citybrain` as passive signals.

## Enable

The integration is disabled by default:

```lua
Config.CityBrainWeatherIntegrationEnabled = false
```

Set it to `true` in `gs_world/shared/config.lua` to allow reporting.

## Safety

The adapter is one-way and passive:

- Checks `GetResourceState('gs_citybrain') == 'started'`.
- City Brain export calls are wrapped with `pcall`.
- Missing or stopped `gs_citybrain` never crashes `gs_world`.
- `gs_citybrain` does not control weather or world behavior.

## Reporting

Callable helpers:

```lua
SubmitWeatherCityBrainSignal(signalData)
ReportWeatherCityBrainCondition(conditionData)
```

Server exports:

```lua
exports.gs_world:SubmitWeatherCityBrainSignal(signalData)
exports.gs_world:ReportWeatherCityBrainCondition(conditionData)
```

Server event:

```lua
TriggerEvent('gs_world:server:reportWeatherCondition', conditionData)
```

Supported condition types:

- `storm_risk` -> `STORM_RISK`
- `heavy_rain` -> `HEAVY_RAIN`
- `fog` / `low_visibility` -> `LOW_VISIBILITY`
- `high_wind` -> `HIGH_WIND`
- `heat_stress` -> `HEAT_STRESS`
- `cold_stress` -> `COLD_STRESS`
- `flood_risk` -> `FLOOD_RISK`

Example:

```lua
exports.gs_world:ReportWeatherCityBrainCondition({
    conditionType = 'storm_risk',
    zone = 'paleto_bay',
    strength = 85,
    confidence = 80,
    windSpeed = 42.0,
    rainfall = 0.8
})
```

When enabled, submitted weather signals should appear through City Brain:

```text
/citysignals
```

Strong `STORM_RISK` signals may create City Brain storm events:

```text
/cityevents
```

## Read-Only Recommendations

CITYBRAIN-015 adds optional recommendation reads:

```lua
Config.CityBrainReadRecommendationsEnabled = false
```

Server helpers:

```lua
exports.gs_world:GetCityBrainDecisions()
exports.gs_world:GetCityBrainDecisionsByType(decisionType)
```

These helpers return `{}` when disabled or unavailable and do not change weather behavior. Client UI should request recommendations through `gs_world` server code and treat them as display-only data.
