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
/gsweather clear
/gsweather rain
/gsweather thunder
/gsweather fog
/gsweather sync
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
```

Other GS resources should treat these as read-only modifiers. For example, police can reduce visibility during `FOGGY`, traffic can increase road risk during `RAIN`, and civilian systems can lower pedestrian density during storms.

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
- Flooding and drainage systems
- Marine patrol and harbor logic
