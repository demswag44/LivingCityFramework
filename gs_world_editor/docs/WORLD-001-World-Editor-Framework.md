# WORLD-001 - GS World Editor Framework

## Purpose

`gs_world_editor` is the shared foundation for Living City Operations Center editor tools. It does not implement territory, business, property, road, construction, police district, weather, ocean, or AI zone gameplay. It provides the common registry, session, permission, selection, command, and event surfaces those tools will use.

## Architecture

- `shared/config.lua` defines framework metadata, ACE permission names, and supported selection types.
- `shared/tools.lua` owns the shared `GSWorldEditor.Tools` table and registry helpers.
- `server/tools.lua` wraps tool registration with production logging and registers the placeholder `territories` tool.
- `server/permissions.lua` centralizes ACE checks.
- `server/sessions.lua` tracks active editor sessions by player source.
- `server/main.lua` exposes chat commands and event bridges for future UI clients.
- `client/selection.lua` stores the current client-side selection and publishes changes to the server.
- `client/session.lua` caches the active session for future phone, tablet, or web UI.

## Tool Registry

Tools register with:

```lua
GSWorldEditor.RegisterTool({
    id = "territories",
    label = "Territory Editor",
    resource = "gs_organizations",
    permission = "gs_world_editor.territories",
    category = "World",
    actions = {
        "create",
        "edit",
        "delete",
        "save",
        "cancel",
    },
})
```

Available APIs:

- `GSWorldEditor.Tools`
- `GSWorldEditor.RegisterTool(tool)`
- `GSWorldEditor.GetTool(id)`
- `GSWorldEditor.GetTools()`

Server exports mirror the registry:

- `exports["gs_world_editor"]:RegisterTool(tool)`
- `exports["gs_world_editor"]:GetTool(id)`
- `exports["gs_world_editor"]:GetTools()`

## Session Lifecycle

A session is server-owned and keyed by player source. Starting a session validates the tool id and checks the tool permission. Ending a session clears only that player's active editor state.

Session shape:

```lua
{
    source = 1,
    toolId = "territories",
    startedAt = 1783170000,
    selectedType = nil,
    selectedId = nil,
    draft = {},
    dirty = false,
}
```

Available APIs:

- `GSWorldEditor.StartSession(source, toolId)`
- `GSWorldEditor.EndSession(source)`
- `GSWorldEditor.GetSession(source)`
- `GSWorldEditor.IsEditing(source)`
- `StartSession(source, toolId)`
- `EndSession(source)`
- `GetSession(source)`
- `IsEditing(source)`

Server exports:

- `exports["gs_world_editor"]:StartSession(source, toolId)`
- `exports["gs_world_editor"]:EndSession(source)`
- `exports["gs_world_editor"]:GetSession(source)`
- `exports["gs_world_editor"]:IsEditing(source)`

## Permission Model

The framework uses ACE permissions:

- `gs_world_editor.admin` grants full editor access.
- `gs_world_editor.use` grants base access to list tools and use the framework.
- `gs_world_editor.territories` grants access to the territory editor tool.
- `gs_world_editor.businesses` is reserved for the business editor tool.
- `gs_world_editor.properties` is reserved for the property editor tool.

Helper:

```lua
GSWorldEditor.HasEditorPermission(source, permission)
HasEditorPermission(source, permission)
```

Server export:

```lua
exports["gs_world_editor"]:HasEditorPermission(source, permission)
```

## Commands

- `/worldeditor`
- `/we`
- `/we tools`
- `/we start <toolId>`
- `/we stop`
- `/we status`

The initial implementation uses chat messages only. No full UI is included in WORLD-001.

## Events

Current event bridge:

- `gs_world_editor:getTools`
- `gs_world_editor:runCommand`
- `gs_world_editor:getTools:response`
- `gs_world_editor:startSession`
- `gs_world_editor:startSession:response`
- `gs_world_editor:endSession`
- `gs_world_editor:endSession:response`
- `gs_world_editor:getSession`
- `gs_world_editor:getSession:response`
- `gs_world_editor:selectionChanged`
- `gs_world_editor:notify`
- `gs_world_editor:sessionStarted`
- `gs_world_editor:sessionEnded`

Future UI can use request ids on request/response events to correlate phone, tablet, or web callbacks.

## Selection System

The client stores one active selection at a time.

Supported types:

- `entity`
- `zone`
- `building`
- `road`
- `npc_spawn`
- `business`
- `property`
- `territory`

Client APIs:

- `SetSelection(type, id, data)`
- `ClearSelection()`
- `GetSelection()`

Client exports:

- `exports["gs_world_editor"]:SetSelection(type, id, data)`
- `exports["gs_world_editor"]:ClearSelection()`
- `exports["gs_world_editor"]:GetSelection()`

## Future Device UI Path

Phone, tablet, and web UI resources should treat `gs_world_editor` as the backend contract. The UI should request tools, start or end sessions, display session status, and publish selection changes through the event bridge or exports. Save and cancel workflows should be implemented per tool resource while keeping the active session and dirty state in this framework.

## Territory Editor Integration

`gs_organizations` will plug in by owning the actual territory editor behavior and using this framework for access control and session state. In WORLD-001, `gs_world_editor` only registers the placeholder `territories` tool:

- `id = "territories"`
- `label = "Territory Editor"`
- `resource = "gs_organizations"`
- `permission = "gs_world_editor.territories"`

Later, `gs_organizations` can call `exports["gs_world_editor"]:RegisterTool(...)` during startup, or the placeholder can be replaced with richer metadata once the territory editing flow is ready.

## WORLD-002 Visual Editing Mode

Starting an editor session now enters client visual mode through `gs_world_editor:client:startVisualMode`. Ending a session exits through `gs_world_editor:client:stopVisualMode`.

Client visual mode state:

```lua
GSWorldEditor.VisualMode = {
    active = false,
    toolId = nil,
    toolLabel = nil,
    mode = "create",
    selectedType = nil,
    selectedId = nil,
    draft = nil,
}
```

Client APIs:

- `StartVisualMode(session)`
- `StopVisualMode()`
- `IsVisualModeActive()`
- `SetVisualModeMode(mode)`
- `SetVisualDraft(data)`

The HUD is drawn with native FiveM text functions and shows the active tool, mode, selection, dirty state, and control hints. No NUI is used.

For the `territories` tool, the preview layer draws a marker and a static `50.0` radius circle at the player's current position. This is only a visual proof of editor mode; it does not save or create territory data.

Visual mode controls:

- `E` shows a select placeholder message.
- `G` switches to move mode and shows a placeholder message.
- `R` switches to radius mode and shows a placeholder message.
- `ENTER` shows a save placeholder message.
- `BACKSPACE` shows a cancel placeholder and ends the editor session.

## WORLD-003 Interactive Selection And Gizmo

WORLD-003 adds the reusable editor engine pieces: camera raycast, selection engine, preview engine, gizmo modes, snap state, input manager, hover HUD, and cursor-following territory preview. See `docs/WORLD-003-Selection-Gizmo.md` for the API details and Living City editing rule.

## WORLD-003.5 Editor Transactions

WORLD-003.5 adds reusable structured transactions for undo, redo, dirty state, save/cancel foundations, and future audit logging. See `docs/WORLD-003.5-Editor-Transactions.md` for API details.

## WORLD-004 Editor Save Pipeline

WORLD-004 adds a generic save pipeline and tool adapter system. The World Editor builds visual save payloads and routes them to registered backend resources. The first end-to-end adapter saves territories through `gs_organizations` without writing SQL from `gs_world_editor`. See `docs/WORLD-004-Editor-Save-Pipeline.md` for API details.

## Validation

Add this to `server.cfg`:

```text
ensure gs_world_editor
```

Expected startup:

```text
[WORLD EDITOR] Framework Initialized
[WORLD EDITOR] Tool Registered: territories
```

In-game smoke test:

```text
/we tools
/we start territories
/we status
/we stop
```

Expected result:

- The tools list shows `Territory Editor`.
- Starting `territories` creates a session.
- Status shows the active tool.
- Stop ends the session.
- No Lua errors are emitted.
