# WORLD-003 - Interactive Selection & Gizmo System

## Purpose

WORLD-003 turns `gs_world_editor` into the reusable in-game editing engine for Living City resources. Selection, raycast, preview, gizmo, snap, input, camera, and HUD mechanics live here so future modules register tools instead of creating their own editor systems.

## Architecture

- `client/camera.lua` provides gameplay camera position, rotation, forward vector, and aim rays.
- `client/raycast.lua` casts from the gameplay camera while visual mode is active.
- `client/selection_engine.lua` owns reusable editor selection.
- `client/gizmo.lua` owns gizmo mode and snap state.
- `client/input.lua` maps editor controls to placeholder actions and radius updates.
- `client/preview.lua` follows the camera hit position and draws tool previews.
- `client/hud.lua` renders live editor state.
- `client/debug_draw.lua` provides lightweight shared draw helpers.
- `shared/gizmo.lua` defines gizmo and snap constants.

## Raycast API

```lua
GSWorldEditor.Raycast.Get()
GSWorldEditor.Raycast.GetHitPosition()
GSWorldEditor.Raycast.GetHitEntity()
GSWorldEditor.Raycast.IsHit()
```

Stored raycast data:

- `hit`
- `coords`
- `normal`
- `entity`
- `entityType`
- `distance`
- `surfaceMaterial`

## Selection API

```lua
GSWorldEditor.Selection.Select(type, id, data)
GSWorldEditor.Selection.Clear()
GSWorldEditor.Selection.Get()
GSWorldEditor.Selection.HasSelection()
GSWorldEditor.Selection.IsSelected(type, id)
```

The selection engine supports reusable editor types such as ground, entity, building, vehicle, ped, territory, business, property, road, utility, and AI zone. Current selection is mirrored into `GSWorldEditor.VisualMode` for HUD display.

## Gizmo And Snap

Gizmo modes:

- `move`
- `scale`
- `rotate`

Snap modes:

- `none`
- `grid`
- `terrain`
- `road`
- `building`

Grid sizes:

- `0.5`
- `1`
- `2`
- `5`
- `10`

API:

```lua
GSWorldEditor.Gizmo.SetMode(mode)
GSWorldEditor.Gizmo.GetMode()
GSWorldEditor.Gizmo.SetSnapMode(mode)
GSWorldEditor.Gizmo.GetSnapMode()
GSWorldEditor.Gizmo.SetGridSize(size)
GSWorldEditor.Gizmo.GetGridSize()
GSWorldEditor.Gizmo.ApplySnap(coords)
```

## Preview Engine

The preview engine follows the camera raycast hit point. For the `territories` tool it draws:

- center marker
- radius circle
- height indicator

The default territory radius is `50.0` meters. Mouse wheel changes radius between `5.0` and `1000.0` meters.

Preview API:

```lua
GSWorldEditor.Preview.UpdateHover()
GSWorldEditor.Preview.GetHover()
GSWorldEditor.Preview.GetCoords()
GSWorldEditor.Preview.GetExistingTerritory()
```

Existing territory highlighting is data-driven through `VisualMode.draft.existingTerritories`. If future territory data is supplied there, the preview can highlight matches without `gs_organizations` owning editor mechanics.

## HUD

The HUD updates every frame while visual mode is active and displays:

- tool
- mode
- radius
- snap mode
- hover type
- selection
- coordinates
- controls

## Controls

- `E` selects the current hover target.
- `G` switches gizmo mode to move.
- `R` switches gizmo mode to scale.
- `T` switches gizmo mode to rotate.
- `Mouse Wheel` adjusts territory radius.
- `ENTER` shows a save placeholder.
- `BACKSPACE` cancels and ends the session.

No saving, database writes, or territory creation are implemented in WORLD-003.

## Living City Rule

From WORLD-003 onward, `gs_world_editor` is the only resource responsible for editing mechanics. Other resources should register tools and provide domain data/actions, not selection systems, raycasts, previews, gizmos, HUDs, or input managers.
