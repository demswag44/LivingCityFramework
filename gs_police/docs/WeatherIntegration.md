# Police Weather Integration

`gs_police` can read Living City weather from `gs_world` and apply small, guarded modifiers to police awareness, witness reports, and non-pursuit AI response timing.

## Config

```lua
Config.WeatherIntegration.Enabled = true
Config.WeatherIntegration.Debug = false
Config.WeatherIntegration.ResourceName = 'gs_world'

Config.WeatherIntegration.VisibilityEnabled = true
Config.WeatherIntegration.WitnessEnabled = true
Config.WeatherIntegration.ResponseDelayEnabled = true
Config.WeatherIntegration.RoadRiskEnabled = true
Config.WeatherIntegration.TrafficEnabled = true

Config.WeatherIntegration.MinVisibilityModifier = 0.35
Config.WeatherIntegration.MaxResponseDelayMs = 20000
Config.WeatherIntegration.MaxRoadRiskModifier = 2.5
```

If `gs_world` is stopped or an export is unavailable, police falls back to neutral values.

## Safe Export Wrapper

Police files use a guarded helper pattern:

```lua
local function GetWeatherModifier(exportName, fallback)
    local resourceName = (Config.WeatherIntegration and Config.WeatherIntegration.ResourceName) or 'gs_world'

    if not Config.WeatherIntegration or not Config.WeatherIntegration.Enabled then
        return fallback
    end

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
```

## Current Effects

- Visibility reduces police awareness and patrol detection range in rain, fog, smog, and storms.
- Witness modifier can suppress civilian or witness reports in poor weather.
- Police response modifier plus wind risk can add a bounded delay to non-pursuit AI response spawning.
- Road, traffic, pedestrian, and wind risk values are exposed through `/police_weatherdebug` for future tuning.

## Debug Command

```text
/police_weatherdebug
/police_weatherclient
```

`/police_weatherdebug` is registered server-side and works from server console or in-game. `/police_weatherclient` is the optional client-local view from the current player's synced `gs_world` state.

Both print:

- Weather profile and base weather
- Visibility, witness, police response, traffic, pedestrian, and road risk modifiers
- Wind speed, direction, gusts, and wind risk
- `gs_world` resource state
- Whether police weather integration is enabled

## Safety Boundaries

- No hard pursuit speed cap is added.
- Active pursuits and pursuit backup are not delayed.
- Police do not ignore felony calls because of weather.
- No new traffic system is created.
- Weather failures fall back to neutral values.

## Future Expansion

- Wet road pursuit tuning
- Traffic accident chance
- Civilian shelter behavior
- Storm-related dispatch calls
- Power outage events
- Ocean and coastal storm integration
