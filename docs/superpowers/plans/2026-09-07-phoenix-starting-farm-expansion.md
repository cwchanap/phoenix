# Phoenix Starting Farm 2.5D Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the compact proof ground with the approved `24x20` isometric homestead, `6x5` farm, house, river/forest boundaries, workbench yard, future-village road, and smooth camera travel while preserving the complete 14-day game loop.

**Architecture:** Extend existing owners only. `WorldContract` owns every fixed footprint and camera bound; `WorldShell` fills every world collision polygon; `Entities` stays the one Y-sort root; `FarmView` creates soil/crops; the player keeps the one `Camera2D`. Ground/Water/Paths/GroundDecoration stay direct children of `World`; do not extract a map scene until a second map exists.

**Tech Stack:** Godot 4.7.1, statically typed GDScript, 64x32 isometric `TileMapLayer`, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, Phoenix visual-regression harness, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`

## Global Constraints

- One task / one branch / one PR: continue on `docs/starting-farm-2-5d-expansion`.
- `MAP_SIZE = Vector2i(24, 20)`, `FARM_PATCH = Rect2i(4, 10, 6, 5)`, `PROJECTION_ORIGIN = Vector2(768, 0)`.
- `CAMERA_BOUNDS = Rect2(128, -96, 1408, 800)` lands with the contract, not later, and must equal `WorldMath.map_camera_bounds()`.
- Keep Phoenix 2D isometric. No `Node3D`, navigation, streaming, map registry, scene-transition framework, or generic world-object system.
- `GameSession` remains the only mutable gameplay authority.
- `WorldContract -> WorldShell -> CollisionPolygon2D` remains the only collision path.
- `Entities` remains the only enabled Y-sort node; all occluding scenery is a direct child.
- Reuse the existing player-owned `Camera2D`; no pan/zoom/camera manager/persisted camera state.
- The village road, workbench, river, forest, rocks, fences, and sign are non-interactive.
- No balance retune and no save migration. Old 9-cell saves may fail through existing farm validation.
- Remove `PATH_ROW/path_cells()` and obsolete Tree/Building contract constants; do not keep duplicate representations.
- The approved regular-cut source art is already committed on this PR. Do **not** regenerate or substitute it during implementation.
- The existing UI visual goldens use static plates and do not render `world.tscn`; run `./tools/verify-visual.sh` unchanged rather than recapturing them.

## Approved Source Art

Use these committed source sheets as the only new art input for this slice:

- `assets/sprites/starting-farm-tiles-source.webp` — transparent regular `4x2` source sheet, `96x96` cells.
  - row 1: grass, grass detail, farm-base tile, dirt/path
  - row 2: water, river-bank A, river-bank B, river-bank C
- `assets/sprites/starting-farm-props-source.webp` — transparent regular `4x2` source sheet, `96x96` cells.
  - row 1: house, shop stall, reusable tree cluster, reusable rock cluster
  - row 2: reusable fence, workbench, village sign, spare cell

These are approved generated source assets. Crop/repack them into the final Godot textures only where needed. Reuse the same tree/rock/fence cells for repeated scene instances. Do not call an image generator, create alternate art, add an asset registry, or introduce per-instance sprite files without a concrete reason.

For terrain, the final runtime atlas still follows Phoenix's existing `64x32` isometric tile geometry. The `96x96` source cells are source artwork, not a change to `WorldContract.TILE_SIZE`.

## Verification Contract

`./tools/verify-clean.sh` archives committed `HEAD`, so use direct worktree commands during RED/GREEN and `verify-clean.sh` only after checkpoint commits.

If local GUT is absent, bootstrap the ignored copy with the same version/checksum as `verify-clean.sh`:

```bash
if [ ! -f addons/gut/gut_cmdln.gd ]; then
  mkdir -p addons/gut
  curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o /tmp/phoenix-gut.tgz
  echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut.tgz" \
    | shasum -a 256 -c -
  tar -xzf /tmp/phoenix-gut.tgz --strip-components=3 -C addons/gut \
    "Gut-9.7.1/addons/gut"
fi
```

Worktree gates:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

Final gates additionally run:

```bash
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
./tools/verify-visual.sh
```

---

## File Map

**Already committed source art**
- `assets/sprites/starting-farm-tiles-source.webp`
- `assets/sprites/starting-farm-props-source.webp`

**Create only if needed for runtime import**
- `scenes/world/starting_farm_tileset.tres` — final 64x32 environment atlas mapping.
- a compact derived runtime terrain texture and/or prop texture cropped from the approved source sheets. Prefer direct region use when simpler.

**Modify**
- `scripts/world/world_contract.gd`
- `scripts/world/world_math.gd`
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `scripts/player/player_controller.gd` only if camera acceptance exposes a real defect
- `tests/headless/world_math_smoke.gd`
- `tests/headless/world_shell_smoke.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_save_file.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/gdunit/test_world_math.gd`
- `tests/gdunit/test_game_session_flows.gd` only where farm-size assumptions exist
- `tests/e2e/gameplay_day_one_test.gd`
- `CLAUDE.md`; `README.md` only if stale geometry is present

**Retire when unreferenced**
- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- `proof-scenery.png` only if no longer used
- `PATH_ROW/path_cells()` and old Tree/Building footprint/anchor constants

Do not remove proof player/crop/villager/soil/shadow assets unless this PR actually replaces their production use.

---

## Task 1: Atomic expanded-world structural cutover

Changing map/farm/origin constants immediately affects scene startup, FarmView, camera limits, and both world smokes. Land the contract and dependent owners together so the checkpoint stays runnable.

**Files:** `world_contract.gd`, `world_math.gd`, `world.tscn`, `world_shell.gd`, `farm_view.gd`, both headless world smokes, `test_game_session.gd`, `test_save_file.gd`, `test_gameplay_shell.gd`, `test_world_math.gd`.

### 1.1 RED — move the real oracles first

- [ ] In `test_game_session.gd`, replace stale farm constants with compile-time expressions from the authored patch:

```gdscript
const FARM_CELL := WorldContract.FARM_PATCH.position
const SECOND_FARM_CELL := WorldContract.FARM_PATCH.position + Vector2i.RIGHT
```

Also change helper defaults such as `_grow_and_harvest_turnip()` to `FARM_CELL`.

- [ ] In `test_save_file.gd`, use the runtime source directly:

```gdscript
var cell := WorldContract.farm_cells()[0]
```

- [ ] Update `world_math_smoke.gd` to expect the new map/origin/spawn/farm/environment contract and assert:

```gdscript
WorldContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds()
WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT) == Vector2(976.0, 336.0)
WorldMath.footprint_ground_anchor(WorldContract.SHOP_STALL_FOOTPRINT) == Vector2(1008.0, 400.0)
```

Remove PATH_ROW/Tree/Building expectations. Replace 12x12 edge cases with 24x20 corners, including `(23.999999, 19.999999) -> (23,19)`.

- [ ] Extend `tests/gdunit/test_world_math.gd` with the expanded edge target coverage.

- [ ] Update `world_shell_smoke.gd` ownership expectations to direct `World` layers:

```text
World
├── Ground
├── Water
├── Paths
├── GroundDecoration
├── FarmSoil
├── StaticCollision
├── Entities
├── TargetHighlight
└── GameHud
```

`StaticCollision` expects House, ShopStall, closed environment, shipping, market, villagers, yard-side blockers, and four perimeter polygons. `Entities` remains the single Y-sort root and has no grouping child.

- [ ] Run RED worktree smokes/GdUnit; failures should point at the old contract/scene.

### 1.2 GREEN — replace the fixed contract together

- [ ] Set the approved map, farm, spawn, interaction, camera, and collision values from the design spec. Add only the two small pure helpers:

```gdscript
static func footprint_ground_anchor(footprint: Rect2) -> Vector2:
    var centroid := footprint.position + footprint.size * 0.5
    var bottom := footprint.position + footprint.size
    return Vector2(grid_to_world(centroid).x, grid_to_world(bottom).y)

static func map_camera_bounds() -> Rect2:
    var map_size := Vector2(WorldContract.MAP_SIZE)
    var west := grid_to_world(Vector2(0.0, map_size.y)).x
    var east := grid_to_world(Vector2(map_size.x, 0.0)).x
    var bottom := grid_to_world(map_size).y
    return Rect2(
        west,
        -WorldContract.CAMERA_TOP_PADDING,
        east - west,
        bottom + WorldContract.CAMERA_TOP_PADDING,
    )
```

Keep `CAMERA_BOUNDS` as the frozen constant but make the smoke assert it equals the derived value. Keep `farm_cells()` rectangular/row-major. Delete `PATH_ROW/path_cells()`.

### 1.3 GREEN — make soil dynamic

- [ ] Leave `FarmSoil` authored but empty (`y_sort_enabled=false`, `z_index=5`).
- [ ] In `FarmView._ready()`, create every soil sprite from the same `farm_cells()` loop that already creates crops. Keep the existing proof-soil texture unless this PR deliberately replaces it.

### 1.4 GREEN — cut scene ownership over without another abstraction

- [ ] Keep `Ground`, `Water`, `Paths`, and `GroundDecoration` directly under `World`.
- [ ] Ground contains exactly 480 logical cells and preserves a contract-derived farm-base tile over all 30 `FARM_PATCH` cells.
- [ ] Water cells cover the west/south river boundary from the design.
- [ ] Path cells use the corrected authored union; the farm-side path begins at `x=10`, and the workbench spur reaches `x=12` so it is connected.
- [ ] Replace `Building` with direct `House` and add direct `ShopStall`, tree cluster(s), rock cluster(s), fence placements, `Workbench`, and `VillageSign`. Reuse visual cells from the approved prop sheet rather than generating variants.
- [ ] `WorldShell._ready()` continues filling all collision polygons from `WorldContract` only.
- [ ] Add small authored house-yard side blockers so the single-root house is only approached from the south.

### 1.5 GREEN — finish the real smoke cutover

- [ ] Assert all three tile layers align through `map_to_local()` / `WorldMath.grid_to_world()`.
- [ ] Keep a farm tile identity oracle derived from `FARM_PATCH`; path identity does not need a second contract.
- [ ] Assert all WorldShell-generated polygons equal their `WorldContract` footprints.
- [ ] Assert exactly 30 named soil sprites and 30 direct `FarmCrop_*` roots.
- [ ] Assert exactly one enabled Y-sort node and the closed direct scenery inventory.

- [ ] Run all worktree gates, then commit and run `./tools/verify-clean.sh`.

---

## Task 2: Integrate the committed starting-farm art

The artwork is already on this branch. This task is an integration pass, **not an image-generation task**.

**Approved inputs:**
- `assets/sprites/starting-farm-tiles-source.webp`
- `assets/sprites/starting-farm-props-source.webp`

- [ ] RED: change smoke expectations from proof tile/scenery resources to the final runtime resources derived from the approved sheets; keep hierarchy/Y-sort assertions unchanged.
- [ ] Crop/repack the terrain cells as needed into a Godot `TileSet` using Phoenix's existing `64x32` isometric diamond geometry. Do not change `TILE_SIZE` to match the `96x96` source grid.
- [ ] Use the committed terrain source in this order:

```text
row 0: grass | grass detail | farm-base | dirt/path
row 1: water | river-bank A | river-bank B | river-bank C
```

- [ ] Use the committed props source in this order:

```text
row 0: house | shop stall | tree cluster | rock cluster
row 1: fence | workbench | village sign | spare
```

- [ ] Reuse the tree cluster, rock cluster, and fence cells for repeated direct `Entities` children. Do not generate per-instance variants.
- [ ] Keep shipping/market/villager sprites unless this approved art pass explicitly contains their replacement—which it currently does not.
- [ ] `GroundDecoration` gets only non-occluding details derived from existing assets or simple tile placement; no new generated art is required.

Verify worktree smoke/GUT, commit, then run `./tools/verify-clean.sh`.

---

## Task 3: Expanded persistence, interactions, reachability, and Day-1 E2E

**Files:** `test_game_session.gd`, `test_gameplay_shell.gd`, `test_persistence_flow.gd`, `world_shell_smoke.gd`, `gameplay_day_one_test.gd`; runtime scene/contract only if a real layout defect appears.

### 3.1 Expanded farm + persistence

- [ ] Add a domain test using `WorldContract.farm_cells()[-1]`; assert it is outside the old `Rect2i(2,7,3,3)` and supports normal hoe/plant/water commands.
- [ ] Extend persistence acceptance by mutating that expanded cell, sleeping/autosaving through the production path, reopening/Continuing, and asserting the restored farm entry preserves its state.

### 3.2 Relocated interactions

- [ ] Keep existing interaction tests but target only `WorldContract.SHOP_CELL`, `SHIPPING_CELL`, `BED_CELL`, `MARKET_CELL`, and `villager_cell(id)`. Do not create a new interaction abstraction.

### 3.3 Collision/reachability

- [ ] Replace old Tree/Building detour smoke cases with House lower-edge/side-slide, river-west stop, and representative farm-edge targetability.
- [ ] Use `WorldMath.grid_to_world()` for all placements. Fix authored footprints/positions if blocked; do not add pathfinding or special movement code.

### 3.4 E2E source of truth

- [ ] Retarget **all three** stale Day-1 stand positions—farm, bed, and shop—from `WorldContract` + `WorldMath.TARGET_OFFSETS`. No fixed map coordinate fallback.

Run GUT + both smokes + e2e shell runner, commit, then `./tools/verify-clean.sh`.

---

## Task 4: Cleanup, docs, unchanged UI visual regression, and release gates

### 4.1 Cleanup

- [ ] Run:

```bash
git grep -n "proof_ground_tileset\|proof-tiles.png\|proof-scenery.png\|PATH_ROW\|path_cells"
```

Delete proof ground/scenery resources only when no production/test reference remains. Keep proof player/crop/villager/soil/shadow assets if still used. Keep the two approved `starting-farm-*-source.webp` sheets as provenance/source art even if derived runtime textures are committed.

### 4.2 Handoff docs

- [ ] Update `CLAUDE.md` from the old shell geometry to the new `24x20` / 30-cell contract, single collision/Y-sort ownership, direct world tile layers, dynamic soil, and future-village non-transition boundary. Document the two approved source-art paths.
- [ ] Update README only if it contains stale geometry.

### 4.3 Visual regression

- [ ] Run `./tools/verify-visual.sh` unchanged. States 01–12 use static plates and are expected to remain byte/threshold compatible; do not recapture them as evidence for this world-map change.
- [ ] Visually inspect the **real game/export** against the approved map concept for the homestead art/layout.

### 4.4 Final gates

- [ ] Run the complete Verification Contract commands, including `build/Phoenix.zip` export.
- [ ] In the exported app, qualitatively verify: spawn outside house; start view does not show whole map; camera visibly pans house/farm -> east road; collision matches visible house/river/forest/workbench; all gameplay interactions remain reachable; road cannot leave the scene; the expanded map does not expose materially worse blank canvas than the current authored-camera behavior.

Commit closeout evidence/docs on this same branch and update PR #14. Do not open another PR.

---

## Self-review

Before implementation, confirm all are still true:

- no nested scenery Y-sort group;
- no second collision owner;
- no second map/camera/interaction abstraction;
- `farm_cells()` / `FARM_PATCH` are the only farm geometry sources;
- farm tile identity remains tied to `FARM_PATCH`;
- old saves intentionally fail instead of migrating;
- approved source art is reused rather than regenerated;
- direct worktree tests run before commits; `verify-clean.sh` runs after commits;
- GdUnit uses `./addons/gdUnit4/runtest.sh`;
- export target is `build/Phoenix.zip`;
- UI visual goldens are regression-checked unchanged, while the real world is visually accepted in-game.

If implementation appears to require a second owner for map, collision, Y-sort, camera behavior, or art identity, fix the authored scene/contract instead.