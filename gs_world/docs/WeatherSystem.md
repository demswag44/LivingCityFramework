# Living City Weather System

`gs_world` is the official Living City weather controller. The server is authoritative: clients request the current state and apply the synchronized GTA weather locally.

Only one weather sync resource should control GTA weather at a time. `qb-weathersync` should remain disabled while Living City weather is enabled. If `qb-weathersync`, `cd_easytime`, `vSync`, `Renewed-Weathersync`, `ps-weathersync`, or another weather controller is active, conflicts may happen until an explicit compatibility layer is added.

If `/gsweather` changes the server weather state but visuals do not change in-game, check `/gsweather status` and stop any other active weather sync resource.

## Files Added

- `shared/weather_config.lua`
- `server/weather.lua`
- `client/weather.lua`
- `docs/WeatherSystem.md`

## Commands

Console is always allowed. Player ACE checks are controlled by `Config.Weather.RequireAce`. When enabled, players need `Config.Weather.AdminAce`, which defaults to `gs.admin`.

```text
/gsweather status
/gsweather effects
/gsweather clear
/gsweather rain
/gsweather thunder
/gsweather fog
/gsweather sync
/gsweather dynamic on
/gsweather dynamic off
/gsweather cycle on
/gsweather cycle off
/gsweather next
/gsweather wind
/gsweather winddir [0-359]
/gsweather windspeed [number]
/gsweather severe_storm
/gsweather coastal_storm
/gsweather hurricane_conditions
```

`/weather` is kept as a compatibility alias, but `/gsweather` is the primary Living City command.

On `restart gs_world`, the server console should show:

```text
[gs_world] server/weather.lua loaded
[gs_world] Weather command registered: /gsweather
```

If `/gsweather` returns `No such command`, first confirm both startup lines appeared. If they did not, verify `fxmanifest.lua` still loads `shared/weather_config.lua` before `server/weather.lua`.

`/gsweather status` prints the current weather, cycle status, and resource states for:

- `qb-weathersync`
- `cd_easytime`
- `vSync`
- `Renewed-Weathersync`

The status output also shows the active dynamic profile and the approximate minutes until the next automatic weather change.
It also includes current wind speed, wind direction, wind gusts, and wind risk.

## Dynamic Weather

Dynamic weather is enabled by default:

```lua
Config.Weather.CycleEnabled = true
Config.Weather.DynamicEnabled = true
Config.Weather.MinDurationMinutes = 20
Config.Weather.MaxDurationMinutes = 60
Config.Weather.AllowSevereWeather = true
Config.Weather.AllowHeatwaves = true
Config.Weather.AllowFog = true
```

When `DynamicEnabled` is true, the server chooses from `Config.Weather.DynamicProfiles` using weighted random selection. Profiles are filtered by server hour and by the severe/fog/heatwave safety flags. Each selected profile maps to a GTA weather type plus temperature, wind, and fog metadata.

Examples:

- `CLEAR_DAY` maps to `EXTRASUNNY`
- `LIGHT_RAIN`, `STEADY_RAIN`, and `HEAVY_RAIN` map to `RAIN`
- `THUNDERSTORM`, `SEVERE_STORM`, and `COASTAL_STORM` map to `THUNDER`
- `MORNING_FOG` and `DENSE_FOG` map to `FOGGY`
- `HEATWAVE` maps to `EXTRASUNNY` with higher temperature metadata

Use `/gsweather next` to force the next weighted forecast immediately. Use `/gsweather dynamic off` to fall back to the legacy `CycleTypes` list while keeping the weather cycle enabled.

Any dynamic profile can also be applied directly by command using its profile name in lowercase, for example:

```text
/gsweather severe_storm
/gsweather coastal_storm
/gsweather hurricane_conditions
```

## Wind System

Wind is a first-class weather property. Every dynamic profile defines:

- `windSpeed`: steady GTA wind speed applied by the client
- `windDirection`: GTA wind direction in degrees
- `windGusts`: gameplay gust strength for future systems and optional client gust pulses
- `windRisk`: gameplay modifier for city systems

The server stores these values in `CurrentWeather` and sends them through `gs_world:client:weather:sync` with the rest of the weather state. If `Config.Weather.RandomizeWindDirection` is true, dynamic profile selection randomizes the final synced direction between `0.0` and `359.0`.

Wind commands:

```text
/gsweather wind
/gsweather winddir [0-359]
/gsweather windspeed [number]
```

`/gsweather effects` prints gameplay modifiers for integrated systems, including visibility, witness chance, police response, traffic, pedestrian density, road risk, crime chance, ocean risk, and wind risk.

`/gsweather wind` prints only wind state: profile, base weather, speed, direction, gusts, and risk. `winddir` and `windspeed` are admin/dev controls that update the current weather state and resync clients.

Client gust simulation is controlled by:

```lua
Config.Weather.EnableWindGusts = true
Config.Weather.WindGustIntervalSeconds = 45
Config.Weather.WindGustDurationSeconds = 8
```

Gusts only run when `windGusts` is greater than `windSpeed` and `windRisk` is above calm conditions. They are profile-scoped and do not run every frame.

Profile examples:

- `CLEAR_DAY`: low wind, low gusts, neutral risk
- `LIGHT_RAIN`: moderate wind and light road/ocean risk
- `HEAVY_RAIN`: stronger gusts and elevated risk
- `THUNDERSTORM`: high gusts and storm risk
- `SEVERE_STORM`: severe wind and high city risk
- `COASTAL_STORM`: stronger coastal/ocean wind risk
- `HURRICANE_CONDITIONS`: highest wind and wind risk

## Server Events

```lua
TriggerServerEvent('gs_world:server:weather:requestSync')
TriggerServerEvent('gs_world:server:weather:setWeather', 'RAIN')
```

The server broadcasts:

```lua
TriggerClientEvent('gs_world:client:weather:sync', target, weatherState)
```

## Exports

```lua
exports.gs_world:GetCurrentWeather()
exports.gs_world:GetCurrentWeatherProfile()
exports.gs_world:IsRaining()
exports.gs_world:IsStorming()
exports.gs_world:IsFoggy()
exports.gs_world:GetWeatherEffects()
exports.gs_world:GetVisibilityModifier()
exports.gs_world:GetCrimeModifier()
exports.gs_world:GetTrafficModifier()
exports.gs_world:GetWitnessModifier()
exports.gs_world:GetPoliceResponseModifier()
exports.gs_world:GetPedestrianModifier()
exports.gs_world:GetRoadRiskModifier()
exports.gs_world:GetOceanRiskModifier()
exports.gs_world:GetWindSpeed()
exports.gs_world:GetWindDirection()
exports.gs_world:GetWindGusts()
exports.gs_world:GetWindRiskModifier()
exports.gs_world:GetCurrentWind()
```

Other GS resources should treat these as read-only modifiers. For example, police can reduce visibility during `FOGGY`, traffic can increase road risk during `RAIN`, and civilian systems can lower pedestrian density during storms.

## Consumers / Integrated Systems

`gs_police` consumes Living City weather as a guarded, read-only integration. Weather affects police visibility, witness reliability, bounded non-pursuit response delay, road risk debug output, and wind risk debug output. Police pursuit behavior remains active and is not hard speed-capped by weather.

Future consumers may include:

- `gs_dispatch`
- `gs_ai`
- `gs_blackmarket`
- `gs_organizations`
- Ocean and coastal systems

## Weather Effects

`Config.Weather.Effects` defines modifiers for every supported weather type:

- `visibility`
- `traffic`
- `pedestrianDensity`
- `policeResponse`
- `witnessChance`
- `crimeChance`
- `roadRisk`
- `oceanRisk`

A value of `1.0` is neutral. Lower values reduce the effect. Higher values increase the effect.

## Supported Types

- `CLEAR`
- `EXTRASUNNY`
- `CLOUDS`
- `OVERCAST`
- `RAIN`
- `THUNDER`
- `FOGGY`
- `SMOG`
- `CLEARING`

## Future Expansion

- Police visibility and response adjustments
- Traffic behavior and road risk
- Civilian density and witness chance
- Gang and crime opportunity modifiers
- Storm warnings and lightning behavior
- Road condition tracking
- Ocean waves and marine risk
- Ocean wave strength
- Boat handling and boating difficulty
- Traffic accident risk
- Debris events
- Power outages
- Hurricane conditions
- Flooding and drainage systems
- Marine patrol and harbor logic
