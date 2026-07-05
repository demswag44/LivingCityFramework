# ORG-013 Territory Editor Backend

## Architecture

The territory editor is a UI-agnostic backend module exposed as
`GSOrganizations.TerritoryEditor`. Chat commands and the future phone UI should
call the same callbacks or public module functions instead of implementing
editor logic directly.

## Public API

- `CreateTerritory(data, actor)`
- `UpdateTerritory(id, data, actor)`
- `DeleteTerritory(id, actor)`
- `GetDraft(actor)`
- `SaveDraft(actor, data)`
- `ClearDraft(actor)`
- `ValidateTerritoryData(data)`
- `GetEditorState(actor)`

## Callbacks And Events

- `gs_organizations:territoryEditor:create`
- `gs_organizations:territoryEditor:update`
- `gs_organizations:territoryEditor:delete`
- `gs_organizations:territoryEditor:getState`
- `gs_organizations:territoryEditor:saveDraft`
- `gs_organizations:territoryEditor:clearDraft`

Network events emit `:<result>` events with the callback response shape for
non-callback consumers.

## Permission Model

All create, update, and delete actions require one of these ACE permissions:

- `command`
- `command.org`
- `gs_organizations.admin`
- `gs_organizations.territories`

Draft read/write is per actor and does not persist to SQL in this phase.

## Persistence Notes

The current `organization_territories` schema stores editor zone metadata in
the existing `polygon` JSON column as an envelope containing `points`, `type`,
`radius`, `height`, `enabled`, and `metadata`. This keeps the backend compatible
with the existing schema while preserving future polygon support.

After create, update, or delete, the backend reloads `GSOrganizations.Territories`
and `GSOrganizations.TerritoryZones` so changes are visible without a resource
restart.

## Future Phone Integration

The phone UI should use the same callback names and `GetEditorState` payload to
load current draft/config state, save incremental drafts, and submit final
create/update/delete actions.
