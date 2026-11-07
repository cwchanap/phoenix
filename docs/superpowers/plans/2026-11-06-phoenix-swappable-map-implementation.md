# HPA-685 — Swappable FarmMap: single-PR implementation and verification plan

**Status:** Planned; no runtime implementation is included in the initial draft PR.  
**Design:** [HPA-685 design specification](../specs/2026-11-06-phoenix-swappable-map-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-685/let-worldshell-host-swappable-map-scenes-farm-extracted-no-behavior  
**Baseline:** `main` `d39fed7aef9c4596ef12d518b5596c1ac7787367`. HPA-683 (PR #36) is merged; HPA-686 remains blocked.  
**Delivery:** Implement **on this same draft PR** after review. One ticket → one PR. No separate planning/implementation PRs or art tasks.

## Outcome and constraints

Extract the authored farm into `FarmMap`, keep `WorldShell` the only session/input/HUD holder, and add `load_map(&"farm")`. Runtime behavior and output must match current main. Only farm exists now; HPA-686 supplies the town and its distinct interactions.

Keep Godot 4.7.1, statically typed GDScript, `WorldMath` projection values, `WorldContract` authoritative farm data, fixed 1080p presentation, current translation strings, and the existing v4 save path. No generalized map framework and no backward-compatibility shim for old *internal* scene paths.

## Implementation sequence — all in one PR

### Step 1 — Extract the authored farm scene without changing any pixels

**Files:** `scenes/world/world.tscn` (edit), `scenes/world/farm_map.tscn` (new), `scripts/world/farm_map.gd` + `.gd.uid` (new).

1. Copy the existing authored TileMapLayers `Ground`, `Water`, `Paths` and `GroundDecoration`, including the packed tile data and exact `position = Vector2(736, 0)` transforms, into `farm_map.tscn`. Move, without redrawing, `FarmSoil`, `FarmActionEffects`, `HomesteadAmbience`, `StaticCollision` and all its polygon children, and `Entities` with the farm props/scene ordering. Retain exact z-index values and Y-sort on `Entities` only.
2. Move the existing farm scene resource references (tileset, textures, FarmView, effects, ambience) to the farm scene. `world.tscn` retains the WorldShell script, `Player` PackedScene, shell-owned `TargetHighlight` and `GameHud`; remove the old farm nodes and old external-resource entries from the shell scene. Do not put a second Player under FarmMap.
3. Give `FarmMap` a `Node2D` root at identity transform with `farm_map.gd` attached. Its contract-facing getters should be tiny and sourced from `WorldContract`: ID `&"farm"`, `MAP_SIZE`, `PLAYER_SPAWN`, `CAMERA_BOUNDS`, and the already-authored view/effects/ambience nodes. Do not copy any cell, anchor, footprint or bounds literal.
4. Preserve `FarmView._ready()`'s sibling lookup `../FarmSoil`: moving both nodes into the same `FarmMap` parent should keep this valid. Crops and soil are still created from `WorldContract.farm_cells()`.

**Sanity checkpoint:** Opening `farm_map.tscn` in the editor shows exactly the existing farm props, ground and obstacles. The script parser resolves all moved resources before changing the shell controller.

### Step 2 — Put farm-only collision setup on the farm side

**Files:** `scripts/world/farm_map.gd`, `scripts/world/world_contract.gd`, `scripts/world/world_shell.gd`.

1. Move `_fill_collision()`, the eight named farm polygon setup calls, and the four perimeter polygon setup calls from `WorldShell._ready()` into `FarmMap._ready()`. Continue using `WorldMath.footprint_to_polygon()` for every footprint.
2. Move the farm perimeter helper and its 1.0-cell band width to the farm side, preferably `WorldContract.perimeter_footprints()` so all farm geometry is in one contract. Keep the exact four footprints. No duplicate geometry constants in either scene or tests.
3. Retain `StaticCollision` inside FarmMap, so removing the map removes its bodies/polygons with it. Do not create a physics abstraction, separate collision service, or an additional collision root on WorldShell.

**Sanity checkpoint:** The generated collision polygon vertices match the current `world_shell_smoke` expectations exactly, including forest, river, house, seed stall, workbench, shipping, market and perimeter.

### Step 3 — Introduce a single map-loading path while preserving the Player instance

**Files:** `scripts/world/world_shell.gd`, `scripts/player/player_controller.gd`, optionally `scripts/world/world_math.gd` for the narrow target-size seam.

1. Add `const FARM_MAP_SCENE := preload("res://scenes/world/farm_map.tscn")` and `var _active_map: FarmMap` (or a `Node2D` with the same tiny map context). Make `farm_view`, `_farm_effects`, and `_homestead_ambience` runtime references populated by `load_map`, rather than the obsolete shell-level `@onready` paths. Keep the existing public `player` and `hud` handles for tests/controllers.
2. Keep a single Player scene instance under the shell in `world.tscn` **before** first loading a map. Its `Camera2D` stays its child. Do not free or instantiate a new Player when `load_map` runs. Assign the shell-owned target highlight explicitly to the Player via a small binding method, rather than relying on `../../TargetHighlight` (the player changes parents).
3. In `_ready()`, create/restore the one `GameSession`, configure the HUD and focus state, call `load_map(&"farm")`, and connect HUD callbacks **once**. Do not connect once per map load. The single `_refresh_from_session()` path still updates FarmView, weather ambience, HUD and input gate.
4. In `load_map(map_id: StringName)`:
   - Reject an unknown ID without destroying an existing map. The only branch in this ticket is `&"farm"`; use a direct `match`, not an extensible scene registry.
   - Cancel any in-progress hold and clear stale prompt/target presentation before changing the map.
   - If there is an old map, reparent the existing Player temporarily to WorldShell; remove the old map from the active scene tree and queue it free **before** adding the replacement (no overlapping live collision worlds). Ensure the old effects script can clear external sprites/tweens.
   - Instantiate `FarmMap`, assign its exact name `FarmMap`, add it to WorldShell, and bind `farm_view = $FarmMap/Entities`, `_farm_effects`, and `_homestead_ambience`.
   - Reparent **the same Player** into `FarmMap/Entities`; move it to index 0 so the old Y-sort draw order and exact-Y ties survive. Apply the map spawn and camera bounds from the farm contract, preserving the zoom and smoothing settings.
   - Run `_farm_effects.setup(player, farm_view)` on the new effects node and refresh from the existing session snapshot. `GameHud` and the session are never reinstantiated.
5. Keep `PlayerController` responsible for movement, facing, target highlighting and the camera, but stop treating farm camera bounds and spawn as immutable Player-owned startup data. Add a narrow map-context setter for spawn, camera limits and target grid size. Keep the current shared `WorldContract.PLAYER_HALF_EXTENT`, speed, projection and zoom unchanged. If the target lookup needs the map's dimensions, pass `map_size` into `WorldMath.target_cell()` with existing farm call behavior unchanged; do not generalize all the world math.
6. Keep `_interact_label()`, `interact()`, farming action/hold dispatch and `GameSession` exactly on their present farm logic. The seed box, bed, shipping, and market remain on this farm until HPA-686. No travel button or `GameSession.travel_to` yet.

**Critical lifecycle checks:** Player's `get_instance_id()` and `Camera2D` identity are unchanged after calling `load_map(&"farm")` again; the Y-sort container has exactly one Player at child index 0; there is only one active map/StaticCollision, effects node, ambience and HUD; the session snapshot (including day, inventory, seeds and relationships) does not reset.

### Step 4 — Update all path-based tests; preserve their assertions

**Primary tests:**
- `tests/headless/world_shell_smoke.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/e2e/gameplay_day_one_test.gd`
- Other `tests/` helpers with references found in the complete audit below.

1. Replace **path expectations**, not gameplay assertions. For example, `World/Ground` becomes `World/FarmMap/Ground`, `World/FarmSoil` becomes `World/FarmMap/FarmSoil`, `World/Entities` becomes `World/FarmMap/Entities`, `World/Entities/Player` becomes `World/FarmMap/Entities/Player`, and world crop/effects/ambience/static-collision paths acquire `FarmMap/`. Keep `World/GameHud` and `World/TargetHighlight` as shell-owned paths.
2. In the world-shell smoke, verify the **new two-level authored tree**, while preserving checks of 24×20 terrain and exact tile IDs, 30 soil sprites, 30 crop roots, static scenery names/order/frames, all collision polygons, player collider, camera limits, target highlight, touch/occlusion and rain-ripple properties. Assert there is still exactly one Y-sort CanvasItem, and it is `FarmMap/Entities`; assert the Player is its first child.
3. In GUT, keep existing modal/input-gate, farming/hold, effects, audio, weather, shop, sleep/save, and Day 14/finale assertions. Only revise scene paths/test helpers broken by the extraction.
4. In godot-e2e, update `PLAYER`, `_soil_path()`, and `_crop_path()` in the Day 1 suite. Continue exercising a real keyboard-driven new game, farm, Seed Box, overnight save, and Continue. Do not add a fake test-only world instance.
5. Add one small focused map-load regression (in an existing scene integration or smoke suite): inspect the player/camera IDs and session snapshot, call `load_map(&"farm")` again, assert the IDs and snapshot match, the spawn resets, the old map is detached, and all views/colliders exist exactly once. Test an unknown ID as a no-op. This is sufficient; do not build a generalized multi-map test harness when no second map exists.

**Required audit before finishing code changes:**

```bash
grep -RInE 'get_node(_or_null)?\("?(Ground|Water|Paths|GroundDecoration|FarmSoil|FarmActionEffects|HomesteadAmbience|StaticCollision|Entities)|/Entities/Player|/FarmSoil/|/Entities/FarmCrop|\.\./\.\./TargetHighlight|perimeter_footprints|WorldContract\.CAMERA_BOUNDS' scripts tests scenes
grep -RInE 'scenes/world/world\.tscn|FarmActionEffects|FarmView|WorldShell' scripts tests
```

Check each match by behavior: new paths are expected, but original farm coordinates, timing, UI strings, and rule assertions must remain. Do not leave alias nodes purely to satisfy stale tests.

### Step 5 — Update the live handoff docs and run the four gates

**Docs:** `AGENTS.md` and its mirrored `CLAUDE.md` in the **same PR**, updating only the now-outdated world-scene ownership, player-parenting/camera-context, and test-path statements. Any README scene-path documentation that changes should be corrected as well. Historical design documents remain immutable.

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
- [ ] `load_map(&"farm")` is the only startup/replace path and preserves identity/state without duplicate connections.
- [ ] Farm contract and Y-sort/depth/collision/target rendering are equivalent; no new art, town code, translation or balance changes.
- [ ] Headless smoke, GUT, GdUnit4 and godot-e2e assertions are updated to the new hierarchy and pass; export passes.
- [ ] Native visual comparison is recorded; no screenshot-golden CI is recreated.
- [ ] `AGENTS.md`/`CLAUDE.md` reflect final runtime hierarchy; PR body carries actual evidence.
- [ ] HPA-686 remains the sole owner of town/travel/location semantics; HPA-684 retains diary/copy ownership.

## Review focus before implementation

The principal design risk is accidentally giving the Player a new sibling rendering context instead of keeping it in the active map's original Y-sort owner. Second are `PlayerController`'s relative target-highlight reference, `FarmView`'s sibling Soil lookup, effect ownership during map teardown, and test fixtures that assert direct World child paths. All are handled explicitly above without expanding to a multi-map framework.
