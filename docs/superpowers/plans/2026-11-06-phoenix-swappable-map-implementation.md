# HPA-685 — Swappable FarmMap: single-PR implementation and verification plan

**Status:** Revised for PR #37 design-review findings; runtime implementation is still pending.  
**Design:** [HPA-685 design specification](../specs/2026-11-06-phoenix-swappable-map-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-685/let-worldshell-host-swappable-map-scenes-farm-extracted-no-behavior  
**Baseline:** `main` `d39fed7aef9c4596ef12d518b5596c1ac7787367`. HPA-683 (PR #36) is merged; HPA-686 remains blocked.  
**Delivery:** Implement **on this same draft PR** after review. One ticket → one PR. No separate planning/implementation PRs or art tasks.

## Outcome and constraints

Extract the authored farm into `FarmMap`, keep `WorldShell` the only session/input/HUD holder, and add `load_map(MapId.FARM)`. Runtime behavior and output must match current main. Only farm exists now; HPA-686 supplies the town and its distinct interactions.

Keep Godot 4.7.1, statically typed GDScript, `WorldMath` projection values, `WorldContract` authoritative farm data, fixed 1080p presentation, current translation strings, and the existing v4 save path. No generalized map framework and no backward-compatibility shim for old *internal* scene paths.

## Implementation sequence — all in one PR

### Step 0 — Specify the risky reload behavior before moving scenes

**Test first, implemented and committed with the atomic scene rewrite (Steps 1–3).** Write one focused `WorldShell` reload regression in an existing smoke/integration suite *before* refactoring the scenes. It should start with the existing farm instance, exercise an action that creates a `ToolFx`, and specify that after `load_map(MapId.FARM)`: the same Player, Camera2D, `GameSession`, and HUD objects survive; `world.get_node("%Player") == world.player`; the player is the first child of the new `FarmMap/Entities`; farm spawn is restored; the active map, `StaticCollision`, Y-sort root, effects, and ambience are each unique; and the session snapshot and HUD request-signal connection count have not changed. Wait one frame and assert no stale `ToolFx`, the viewport still uses `player.camera`, and camera screen center is correct for the newly placed, bounds-clamped player after `reset_smoothing()`. No unknown-string test: `MapId` is a closed enum.

Write the test contract first, then implement the scene move and controller changes as **one coherent commit** alongside the updated smoke/integration assertions. The standalone intermediate scene extraction is not expected to run; it temporarily invalidates `@onready` paths. Immediately after the atomic commit, run headless smoke and GUT and fix any render/physics/parse regressions before e2e/docs cleanup. This is test-first planning, not a promise that a red test commit should land on the PR.

### Step 1 — Extract the authored farm scene without changing any pixels

**Files:** `scenes/world/world.tscn` (edit), `scenes/world/farm_map.tscn` (new), `scripts/world/farm_map.gd` + `.gd.uid` (new).

1. Copy the existing authored TileMapLayers `Ground`, `Water`, `Paths` and `GroundDecoration`, including the packed tile data and exact `position = Vector2(736, 0)` transforms, into `farm_map.tscn`. Move, without redrawing, `FarmSoil`, `FarmActionEffects`, `HomesteadAmbience`, `StaticCollision` and all its polygon children, and `Entities` with the farm props/scene ordering. Retain exact z-index values and Y-sort on `Entities` only.
2. Move the existing farm scene resource references (tileset, textures, FarmView, effects, ambience) to the farm scene. `world.tscn` retains the WorldShell script, `Player` PackedScene, shell-owned `TargetHighlight` and `GameHud`; remove the old farm nodes and old external-resource entries from the shell scene. Do not put a second Player under FarmMap.
3. Give `FarmMap` a `Node2D` root at identity transform with `farm_map.gd` attached. Expose direct typed access to its `Entities`/FarmView, effects and ambience children, plus the only two player-placement values needed now: `WorldContract.PLAYER_SPAWN` and `WorldContract.CAMERA_BOUNDS`. No `map_id` getter, separate map-size field, registry, or duplicated geometry literal. Provide a small `bind_player(player)` method that calls the existing `effects.setup(player, entities)` **after** WorldShell has reparented Player; `_ready()` must not attempt to bind a Player that hasn't joined the map yet.
4. Preserve `FarmView._ready()`'s sibling lookup `../FarmSoil`: moving both nodes into the same `FarmMap` parent should keep this valid. Crops and soil are still created from `WorldContract.farm_cells()`.

**Checkpoint after atomic Steps 1–3:** Open `farm_map.tscn` in the editor and verify farm props, ground and obstacles. Do not treat the isolated Step 1 state as runnable: existing WorldShell node paths remain invalid until Step 3.

### Step 2 — Put farm-only collision setup on the farm side

**Files:** `scripts/world/farm_map.gd`, `scripts/world/world_contract.gd`, `scripts/world/world_shell.gd`.

1. Move `_fill_collision()`, the eight named farm polygon setup calls, and the four perimeter polygon setup calls from `WorldShell._ready()` into `FarmMap._ready()`. Continue using `WorldMath.footprint_to_polygon()` for every footprint.
2. Move the farm perimeter helper and its 1.0-cell band width to the farm side, preferably `WorldContract.perimeter_footprints()` so all farm geometry is in one contract. Keep the exact four footprints. No duplicate geometry constants in either scene or tests.
3. Retain `StaticCollision` inside FarmMap, so removing the map removes its bodies/polygons with it. Do not create a physics abstraction, separate collision service, or an additional collision root on WorldShell.

**Checkpoint after atomic Steps 1–3:** The generated collision polygon vertices must match the current `world_shell_smoke` expectations exactly, including forest, river, house, seed stall, workbench, shipping, market and perimeter.

### Step 3 — Introduce a single map-loading path while preserving the Player instance

**Files:** `scripts/world/world_shell.gd`, `scripts/player/player_controller.gd`, `scenes/world/world.tscn`. Leave `scripts/world/world_math.gd` unchanged in HPA-685.

1. Add `enum MapId { FARM }`, `const FARM_MAP_SCENE := preload("res://scenes/world/farm_map.tscn")`, and **one** `var _map: FarmMap` reference. Keep `farm_view` as a typed getter into `_map.entities` (existing `world.farm_view` test callers use it); read effects/ambience through `_map` instead of storing and rebinding separate fields that can become stale on reload. Keep the existing public `player` and `hud` handles for tests/controllers.
2. Keep a single Player scene instance directly under WorldShell in `world.tscn` **before** first loading a map. Mark it `unique_name_in_owner = true` so tests/e2e can find it with `World/%Player` even after it is reparented under the active map. Its `Camera2D` stays its child. Do not free or instantiate another Player when `load_map` runs. Assign the existing public field `player.target_highlight = $TargetHighlight` directly; delete the broken `../../TargetHighlight` relative lookup, with no new binding method.
3. In `_ready()`, create/restore the one `GameSession`, configure the HUD and focus state, call `load_map(MapId.FARM)`, and connect HUD callbacks **once**. Do not connect once per map load. The single `_refresh_from_session()` path still updates `farm_view`, `_map.ambience`, HUD and input gate. Keep `load_map` **presentation-only**: it must not own/alter gameplay location, and HPA-686 will derive map changes from a session snapshot.
4. In `load_map(map_id: MapId)`:
   - `match map_id` has the only production branch, `MapId.FARM`. No string IDs, registry, impossible-ID no-op or speculative failure test.
   - Cancel any in-progress hold and clear stale prompt/target presentation.
   - Detach the persistent Player temporarily to WorldShell; call `remove_child(old_map)` then `old_map.queue_free()` **before** adding the new map. The existing `FarmActionEffects._exit_tree()` already kills tweens and cleans external nodes, including Player-attached `ToolFx`; do not reimplement its cleanup.
   - Instantiate the FarmMap, name it `FarmMap`, add it under WorldShell, and store it once in `_map`. The map supplies children via typed properties; do not rebind three parallel cached references.
   - Reparent **the same Player** into `_map.entities`; move it to index 0 to preserve exact-Y sorting. Call `player.enter_map(WorldContract.PLAYER_SPAWN, WorldContract.CAMERA_BOUNDS)` to set projected spawn and Camera2D limits, then `player.camera.reset_smoothing()` to avoid a stale pan from the old position. Preserve current zoom/smoothing config.
   - Assign `player.target_highlight = $TargetHighlight` and call `_map.bind_player(player)` **after** the reparent so its effects script can run the existing `setup(player, entities)`. Refresh from the unchanged session snapshot. `GameHud` and `GameSession` are never reinstantiated.
5. Keep `PlayerController` responsible for movement, facing, target highlighting and the camera, but move the startup spawn and camera-limit lines out of its `_ready()` into `enter_map(spawn: Vector2, camera_bounds: Rect2)`. The setter takes **only those two values**. Keep current `WorldContract.PLAYER_HALF_EXTENT`, move speed, projection, zoom, and existing `WorldMath.target_cell()` unchanged. HPA-686 can add a size argument once TownMap truly exists; its town bounds can be derived by extending `WorldMath.map_camera_bounds()` to take size rather than introducing a second hand-typed literal.
6. Keep `_interact_label()`, `interact()`, farming action/hold dispatch and `GameSession` exactly on their present farm logic. The seed box, bed, shipping, and market remain on this farm until HPA-686. No travel button or `GameSession.travel_to` yet.

**Critical lifecycle checks (captured in Step 0):** Player/Camera2D instance IDs and session snapshot survive repeated `load_map(MapId.FARM)`; `%Player` lookup remains stable; the Y-sort container has Player at index 0; only one map/StaticCollision/effects/ambience/HUD exists. Camera remains current with correct screen center after resetting smoothing; pending ToolFx is cleaned; HUD `buy_requested.get_connections().size()` does not increase across reloads.

### Step 4 — Update all path-based tests; preserve their assertions

**Primary tests:**
- `tests/headless/world_shell_smoke.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/e2e/gameplay_day_one_test.gd`
- Other `tests/` helpers with references found in the complete audit below.

1. Replace **farm-content path expectations**, not gameplay assertions: `World/Ground` → `World/FarmMap/Ground`, `World/FarmSoil` → `World/FarmMap/FarmSoil`, `World/Entities` → `World/FarmMap/Entities`, and farm crop/effects/ambience/static-collision paths acquire `FarmMap/`. **Do not bake the player map into test lookup paths:** use `world.player` in GUT/smoke and `const PLAYER := WORLD + "/%Player"` in godot-e2e; `world.get_node("%Player")` resolves the same player after map replacement. Keep `World/GameHud` and `World/TargetHighlight` as shell-owned paths.
2. In the world-shell smoke, verify the **new two-level authored tree**, while preserving checks of 24×20 terrain and exact tile IDs, 30 soil sprites, 30 crop roots, static scenery names/order/frames, all collision polygons, player collider, camera limits, target highlight, touch/occlusion and rain-ripple properties. Assert there is still exactly one Y-sort CanvasItem (`FarmMap/Entities`) and that `world.player.get_parent()` is that node with Player first. Assert `world.get_node("%Player") == world.player` so the stable e2e path is proven.
3. In GUT, keep existing modal/input-gate, farming/hold, effects, audio, weather, shop, sleep/save, and Day 14/finale assertions. Only revise scene paths/test helpers broken by the extraction.
4. In godot-e2e, set `const PLAYER := WORLD + "/%Player"` and update only the **farm-specific** `_soil_path()` and `_crop_path()` in the Day 1 suite. Continue exercising a real keyboard-driven new game, farm, Seed Box, overnight save, and Continue. Do not add a fake test-only world instance.
5. Keep the **Step 0** focused reload regression as the single new lifecycle test (write it before implementation and land it in the atomic scene refactor). It covers player/camera identity, `%Player`, spawn + camera smoothing/current camera, stale ToolFx teardown, no duplicate HUD connections, session snapshot and no duplicate map/colliders. Do not create a separate test harness or unknown-ID no-op test.

**Required audit before finishing code changes:**

```bash
grep -RInE 'get_node(_or_null)?\("?(Ground|Water|Paths|GroundDecoration|FarmSoil|FarmActionEffects|HomesteadAmbience|StaticCollision|Entities)|/Entities/Player|/FarmSoil/|/Entities/FarmCrop|\.\./\.\./TargetHighlight|perimeter_footprints|WorldContract\.CAMERA_BOUNDS' scripts tests scenes
grep -RInE 'scenes/world/world\.tscn|FarmActionEffects|FarmView|WorldShell' scripts tests
```

Check each match by behavior: new paths are expected, but original farm coordinates, timing, UI strings, and rule assertions must remain. Do not leave alias nodes purely to satisfy stale tests.

### Step 5 — Update the live handoff docs and run the four gates

**Docs:** Update `CLAUDE.md` in this **same PR**; `AGENTS.md` is a symlink to it, not a separate mirrored file (confirmed from main's Git tree mode `120000`). Refresh now-outdated world ownership, Player parenting/camera-context and test-path statements. Also correct the stale "direct World child" source comments in `scripts/world/farm_action_effects.gd` and `scripts/world/homestead_ambience.gd`, and the message "FarmActionEffects exists directly under World" at `tests/integration/test_gameplay_shell.gd:2142`. Any README scene-path descriptions that change should be corrected too. Historical documents remain immutable.

**Automated verification** (run on the committed implementation branch; this design-only draft does not claim any test result):

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

As the existing project instructions explain, GUT is bootstrapped by `verify-clean.sh`, and local GdUnit4 first requires `./tools/bootstrap-gdunit.sh`. The `verify-clean.sh` script archives *committed HEAD*, so commit code before relying on its results. CI also runs these lanes on the PR. The prior screenshot-golden gate was removed in PR #29; do **not** add new golden fixtures.

**Native 1080p manual verification:**
- Start from New Game and from Continue. Compare the farm terrain, objects, water, rain, HUD placement, player/crop depth order and camera framing before/after the extraction.
- Walk around house, seed stall, river/forest obstacles and crop rows, checking projected collision and correct front/behind occlusion.
- Till/plant/water/harvest, observe soil/crop and tool/harvest FX, interact with Seed Box, shipping, bed and Day 14 market.
- Repeat loading the farm in a test fixture and confirm there are no doubled sound/visual effects or active colliders.

## Completion checklist

- [ ] `FarmMap` contains all farm-only nodes; shell keeps one session, one Player + camera, one HUD and highlight.
- [ ] `load_map(MapId.FARM)` is the only startup/replace path, presentation-only, and preserves identity/state without duplicate connections.
- [ ] Farm contract and Y-sort/depth/collision/target rendering are equivalent; no new art, town code, translation or balance changes.
- [ ] Headless smoke, GUT, GdUnit4 and godot-e2e assertions are updated to the new hierarchy and pass; export passes.
- [ ] Native visual comparison is recorded; no screenshot-golden CI is recreated.
- [ ] `CLAUDE.md` (and its `AGENTS.md` symlink) reflects final runtime hierarchy; stale farm-effects/ambience comments and assertion message are corrected; PR body carries actual evidence.
- [ ] HPA-686 remains the sole owner of town/travel/location semantics: GameSession will hold **transient runtime** location exposed in snapshots (not overnight `state()`/save), and WorldShell will load maps in response to session snapshots, without recursive refresh. Its town rain will not reuse farm-only ripple ambience. HPA-684 retains diary/copy ownership.

## Review focus before implementation

The principal design risk is accidentally giving the Player a new sibling rendering context instead of keeping it in the active map's original Y-sort owner. Next are unique-owned `%Player` lookup, camera smoothing after teleport, existing `FarmActionEffects._exit_tree()` cleanup when Player is detached first, the sibling Soil lookup, and stale test paths. The test-first atomic refactor verifies these before e2e/doc churn without expanding to a multi-map framework.
