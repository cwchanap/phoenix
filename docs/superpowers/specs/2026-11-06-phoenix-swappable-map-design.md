# HPA-685 — Extract the farm into a swappable map: design specification

**Status:** Draft for review; implementation belongs in this same PR after approval.  
**Linear:** https://linear.app/cwchanap/issue/HPA-685/let-worldshell-host-swappable-map-scenes-farm-extracted-no-behavior  
**Base reviewed:** `main` at `d39fed7aef9c4596ef12d518b5596c1ac7787367` (2026-11-06).  
**Dependencies:** HPA-683 (empty farm/seed box) is done; this ticket unblocks HPA-686 (town and travel). HPA-684 (diary) is independent and HPA-687 (town art) is already done.  
**Delivery:** One PR for both planning and eventual implementation. No new art.

## Player-visible goal

Exactly the same 24×20 starting farm, controls, world depth ordering, collisions, crop visuals, feedback, ambience, camera, HUD, clock, shop, shipping, sleep, and Day 14 market. The change is architectural: the farm becomes its own authored `FarmMap` scene, and `WorldShell.load_map(map_id)` installs exactly one active map. Only the farm map exists in this ticket.

The immediate value is removing the scene-tree dependency that currently prevents HPA-686 from introducing a separate town map without duplicating the game session, player, or HUD.

## What exists on the reviewed main

- `scenes/world/world.tscn` combines four ground TileMapLayers, `FarmSoil`, `FarmActionEffects`, `HomesteadAmbience`, `StaticCollision`, `Entities` (the **only** Y-sort owner), `TargetHighlight`, and `GameHud`. `Player` is currently the *first child* of `Entities`.
- `WorldShell._ready()` creates/restores the only `GameSession`, generates farm-specific static collision polygons, binds HUD signals, wires farming effects, and refreshes the view.
- `FarmView._ready()` looks up `../FarmSoil` and generates 30 soil/crop presentations; the harvest pop is parented into `Entities`. `FarmActionEffects` also creates temporary overlays under the player.
- `PlayerController._ready()` hardcodes farm spawn/camera bounds and resolves its highlight with `../../TargetHighlight`. `WorldMath` uses the shared 64×32 / 2:1 farm projection and the farm-size bound for target lookup.
- `tests/headless/world_shell_smoke.gd`, `tests/integration/test_gameplay_shell.gd`, and `tests/e2e/gameplay_day_one_test.gd` address the current flat scene paths. Tests also pin the unique Y-sort owner, entity order, crop roots, terrain, collision polygons, camera, and draw layers.

The flat hierarchy, not game rules, is the work to change. Keep `GameSession`, `GameRules`, `WorldMath`, and current farm interactions as the behavioral source of truth.

## Decision 1 — Two authored scenes; no map framework

`scenes/world/world.tscn` stays the `WorldShell` packed scene used by `AppRoot`. It keeps the persistent `Player` instance (including its `Camera2D`), `TargetHighlight`, and `GameHud`. Farm-specific content moves, with existing property values and transforms unchanged, into:

- `scenes/world/farm_map.tscn`, root `FarmMap` (`Node2D`) at the same world origin.
- `scripts/world/farm_map.gd`, a small script for farm-only collision setup and exposing the contract data WorldShell actually needs.

Move `Ground`, `Water`, `Paths`, `GroundDecoration`, `FarmSoil`, `FarmActionEffects`, `HomesteadAmbience`, `StaticCollision` and its polygons, and `Entities` with all the same farm props/crop-view script under `FarmMap`. Do **not** copy the player into `farm_map.tscn`. `FarmMap/Entities` remains the single Y-sorted world node (`z_index=20`); `FarmSoil` and `FarmActionEffects` remain separate unsorted layers at z=5, ambience at z=6, and the shell-owned highlight at its existing z-index.

All map art is the already committed art. Do not generate town art, add `TownMap`, or introduce a base `Map` type, interface hierarchy, factory, registry, scene-service, or map manager. A direct `match map_id` in `WorldShell.load_map()`, with one `&"farm"` branch and a clear unknown-ID refusal, is sufficient. HPA-686 adds the town branch when it becomes real.

## Decision 2 — Map supplies its geometry; WorldContract remains the farm truth

`WorldContract` remains the **farm** contract; do not rename it or mirror its farm constants in the new scene script. `FarmMap` exposes the small map context needed by `load_map`: `map_id`, logical `MAP_SIZE`, `PLAYER_SPAWN`, and `CAMERA_BOUNDS`, all derived from `WorldContract`, plus its existing `Entities`/effects/ambience nodes. Farm-specific interactable cells, scene anchors, footprints, and collision mapping continue to come from the same `WorldContract` constants.

Move collision polygon initialization out of `WorldShell._ready()` into `FarmMap._ready()`. Keep the current `WorldMath.footprint_to_polygon()` and perimeter geometry unchanged; move the perimeter-footprint helper to the farm side (for example, `WorldContract.perimeter_footprints()`) rather than leave a farm-only geometry helper on the shared shell. Keep all authored collision children, including the four perimeter polygons, in the farm scene.

The future `TownContract` can mirror the same minimal size/spawn/bounds/cells/footprints shape. **Do not** parameterize every `WorldMath` projection method, create polymorphic contract classes, or write the town contract here. Because `WorldMath.target_cell()` currently uses `WorldContract.MAP_SIZE`, it is reasonable to add one map-size argument supplied by `PlayerController` without changing its farm results; any town-specific projection/origin decisions remain in HPA-686.

## Decision 3 — The player and session survive map replacement

`WorldShell` keeps one `player: PlayerController` reference and one `GameSession` for its entire lifetime. `WorldShell.load_map(map_id: StringName)` is the sole lifecycle entry point:

1. Resolve the known map ID before mutating anything. Cancel a held farm action and neutralize the old preview.
2. If a map is active, **detach the existing Player** from its `Entities` container to the shell *before* removing the old map from the scene tree. Remove/queue-free the old map so old collisions/FX/ambience cannot stay active. Never free/reinstantiate the player, camera, session, or HUD.
3. Instantiate the matching authored map as the sole `World/FarmMap` node. Read its contract context and bind the new `farm_view`, `FarmActionEffects`, and `HomesteadAmbience`.
4. Reparent the persistent Player into `FarmMap/Entities` and move it to **child index 0**. This preserves exact-Y tie ordering, front/behind occlusion, and harvest-pop Y sorting. Place the player at the contract spawn in projected coordinates; set camera bounds and target grid bounds from the active map context, keeping the existing camera zoom/smoothing.
5. Bind the shell-owned `TargetHighlight` to the player by a stable reference, not the current relative `../../TargetHighlight` path (which breaks on reparent). Reconnect farming-effect presentation to the current player and `FarmView`. Refresh map visuals and HUD from the **same existing** session snapshot and reapply the modal input gate.

Startup calls `load_map(&"farm")` after session initialization. Repeated farm loads should still leave exactly one active map, one player, one camera, one HUD, and the original session state. No active-map location is persisted: continue still starts at the farm, and overnight save remains the existing `GameSession.state()` JSON.

Use direct typed nodes and methods, not signal buses or a generalized lifecycle abstraction. Do not change `AppRoot`'s world instantiation, `GameHud`'s modal ownership, `GameSession` commands, or their save shape.

## Decision 4 — Keep the farm behavior, not obsolete scene paths

- Continue to route farm previews, Space/hold farming, E seed-box/bed/shipping/market interactions, and all HUD requests exactly as before. This ticket introduces **no travel command**, time cost, town residents, or location-validation rule change. HPA-686 will own those choices when both maps exist.
- `FarmView` must still see `FarmSoil` as a sibling, and the effect handler must still attach its harvest pop to that map's `Entities` and its tool overlay to the persistent player. Existing player/controller input, camera zoom, weather, rain ripples, audio gating, and HUD z-order remain identical.
- Preserve `WorldContract` farm cell/footprint/camera values, `WorldMath` farm projection math, scene-authored TileMap data, sprite frames, textures, local offsets, z-index values, colliders, and `Entities` child ordering. Avoid a regeneration of art or TSCN geometry.
- `AppRoot` continues to instantiate `res://scenes/world/world.tscn` and to destroy the whole shell on finale; no changes to the save repository or result flow.

## Acceptance / regression contract

1. Starting `world.tscn` (or launching `app.tscn`) creates one farm map under WorldShell. `WorldShell.player` is exactly `FarmMap/Entities/Player`, the first Y-sort child. FarmView is under the new map, and the HUD remains shell-owned.
2. All existing fixed farm cells, tile data, soil count, sprite positions, collisions, z layers, rain ripples, camera limits, target highlight, and front/behind depth assertions still pass, with their paths updated to the new hierarchy.
3. `load_map(&"farm")` called again does not duplicate colliders, node trees, camera, HUD, effects, or session; Player object identity and meaningful snapshot state survive, while its position is reset to the farm spawn. Unknown map IDs leave the active world intact.
4. New Game and Continue, farm actions, hold-to-work, buy/upgrade, shipping, sleeping and saving, clock/modal gates, Day 14 market and finale remain unchanged. The pinned five-Turnip / 175G Promising route remains valid.
5. Four release gates remain green: `tools/verify-clean.sh` (GUT/headless/audio), GdUnit4, godot-e2e, import + unsigned macOS export. Visual inspection at native 1080p verifies occlusion/positioning. PR #29 removed screenshot-golden CI, so do not recreate or update goldens.

## Deliberate non-goals and deferred issues

- **HPA-686:** TownMap/TownContract, travel, truck, town shops/NPCs/market, location checks, travel-time budgets and any projection differences.
- **HPA-684:** Morning diary and revised opening/result text.
- No new art/SFX, no gameplay data/balance changes, no save-schema/version change or migration, no cross-scene service architecture, and no compatibility shims for old internal node paths. Tests should be updated to the new authored layout instead.
