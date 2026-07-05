# ORG-013 Territory Zone Framework

## Runtime Architecture

The territory zone layer is split into a server registry and a client detector.
The server owns `GSOrganizations.TerritoryZones`, registers zones from the
persistent territory runtime, and maintains occupant caches for players and
observed NPCs. Clients receive the compact zone list once, poll their own
position at a configurable interval, and report territory transitions plus
nearby NPC observations back to the server.

## Public APIs

- `GSOrganizations.TerritoryZones.GetTerritory(id)`
- `GSOrganizations.TerritoryZones.GetTerritoryByPosition(coords)`
- `GSOrganizations.TerritoryZones.GetPlayersInTerritory(id)`
- `GSOrganizations.TerritoryZones.GetNPCsInTerritory(id)`
- `GSOrganizations.TerritoryZones.IsPlayerInsideTerritory(source)`
- `GSOrganizations.TerritoryZones.GetTerritoryOccupants(id)`

## Events

- `gs_org:territoryEntered`
- `gs_org:territoryExited`
- `gs_org:territoryOccupancyChanged`

## Extension Points

Runtime zone objects include `Type`, `Radius`, `Polygon`, and `Height`.
This release uses radius checks for detection. Polygon support can replace the
inside-zone check later without changing public APIs or event payloads.

## Performance Notes

The server does not scan all players every tick. Each client reports its own
current zone at `GS.TerritoryZoneConfig.UpdateInterval`, and the server updates
cached occupant tables only when reported state changes. NPC detection is
limited to locally visible peds near the reporting player and can be disabled or
tuned through shared configuration.
