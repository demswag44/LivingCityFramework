# WORLD-004 - Editor Save Pipeline

## Purpose

WORLD-004 adds the first reusable save pipeline to `gs_world_editor`. The editor still owns visual editing mechanics, while each registered tool resource owns validation, persistence, reload, and domain behavior.

The first implemented flow is the Territory Editor:

```text
/gswe start territories
aim at ground
adjust radius
press ENTER or /gswe save
gs_world_editor routes save
gs_organizations validates and persists
territories and zones reload
editor preview refreshes
```

## Save Pipeline

Client save requests are built from active visual mode state and sent through:

```lua
gs_world_editor:client:requestSave
gs_world_editor:server:save
GSWorldEditor.SavePipeline.Save(source, payload)
```

Payload shape:

```lua
{
    toolId = "territories",
    action = "create",
    data = {},
    session = {},
    draft = {},
}
```

The server pipeline verifies:

- active editor session
- tool id matches session
- tool exists in the registry
- player has tool permission
- action is allowed by the tool
- backend adapter exists

Dirty state and transaction history are cleared only after a successful save.

## Tool Adapter

Tools can register backend adapters:

```lua
GSWorldEditor.RegisterTool({
    id = "territories",
    resource = "gs_organizations",
    saveEvent = "gs_organizations:territoryEditor:worldEditorSave",
    saveExport = "WorldEditorSaveTerritory",
    dataExport = "WorldEditorGetTerritories",
})
```

`saveExport` is preferred for synchronous server-side saves. `saveEvent` remains available for future resources that expose event-style adapters.

## Territory Data

The client builds territory create data from the current preview position and draft:

```lua
{
    name = "New Territory",
    type = "radius",
    center = { x = 0.0, y = 0.0, z = 0.0 },
    radius = 50.0,
    height = 50.0,
    owner_id = nil,
    enabled = true,
    metadata = {
        createdBy = source,
        createdFrom = "gs_world_editor",
        editorVersion = "WORLD-004",
    },
}
```

`gs_world_editor` does not write SQL. `gs_organizations` owns validation, repository calls, and runtime reload.

## Commands

- `/gswe save` asks the client to build the same payload as ENTER.
- `/gswe start territories` loads existing territory data through the tool `dataExport`.
- `/gswe status`, `/gswe undo`, `/gswe redo`, `/gswe cancel`, and `/gswe stop` remain unchanged.

## Refresh

After save, `gs_organizations` returns refreshed territory data. The editor emits:

```lua
gs_world_editor:client:saveComplete
gs_world_editor:client:toolDataUpdated
```

The client stores refreshed territory data in `VisualMode.draft.existingTerritories`, enabling highlight preview without restarting the editor.
