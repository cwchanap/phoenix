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
  - row 0: grass, grass detail, farm-base tile, dirt/path
  - row 1: water, river-bank A, river-bank B, river-bank C
- `assets/sprites/starting-farm-props-source.webp` — transparent regular `4x2` source sheet, `96x96` cells.
  - row 0: house, shop stall, reusable tree cluster, reusable rock cluster
  - row 1: reusable fence, workbench, village sign, spare cell

These are approved generated source assets. Crop/repack them into the final Godot textures only where needed. Reuse the same tree/rock/fence cells for repeated scene instances. Do not call an image generator, create alternate art, add an asset registry, or introduce per-instance sprite files without a concrete reason.

For terrain, the final runtime atlas still follows Phoenix's existing `64x32` isometric tile geometry. The `96x96` source cells are source artwork, not a change to `WorldContract.TILE_SIZE`.

## Verification Contract

`./tools/verify-clean.sh` archives committed `HEAD`, so use direct worktree commands during RED/GREEN and `verify-clean.sh` only after checkpoint commits.

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
./tools/verify-clean.sh
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
- compact derived runtime terrain/prop textures cropped from the approved sheets if direct regions are less convenient.

**Modify**
- `scripts/world/world_contract.gd`
- `scripts/world/world_math.gd`
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `scripts/player/player_controller.gd` only if acceptance exposes a real defect
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

- [ ] In `test_save_file.gd`, use `WorldContract.farm_cells()[0]`.
- [ ] Update `world_math_smoke.gd` for the new map/origin/spawn/farm/environment contract and assert `CAMERA_BOUNDS == WorldMath.map_camera_bounds()` plus derived House/ShopStall anchors.
- [ ] Replace 12x12 edge cases with 24x20 corners.
- [ ] Extend `tests/gdunit/test_world_math.gd` with expanded edge targeting.
- [ ] Update `world_shell_smoke.gd` to the direct `World` layer ownership and single Y-sort/collision owners.
- [ ] Run RED worktree smokes/GdUnit; failures should point at the old contract/scene.

### 1.2 GREEN — replace the fixed contract together

- [ ] Set the approved map, farm, spawn, interaction, camera, and collision values from the design spec.
- [ ] Add only `WorldMath.footprint_ground_anchor(footprint)` and `WorldMath.map_camera_bounds()` as the two pure derived-geometry helpers.
- [ ] Keep `CAMERA_BOUNDS` frozen but assert it equals the derived value.
- [ ] Keep `farm_cells()` rectangular/row-major. Delete `PATH_ROW/path_cells()`.

### 1.3 GREEN — make soil dynamic

- [ ] Leave `FarmSoil` authored but empty (`y_sort_enabled=false`, `z_index=5`).
- [ ] In `FarmView._ready()`, create every soil sprite from the same `farm_cells()` loop that already creates crops.

### 1.4 GREEN — cut scene ownership over without another abstraction

- [ ] Keep `Ground`, `Water`, `Paths`, and `GroundDecoration` directly under `World`.
- [ ] Ground contains exactly 480 logical cells and a contract-derived farm-base tile over all 30 `FARM_PATCH` cells.
- [ ] Water covers the west/south river boundary.
- [ ] Corrected paths start at `x=10` by the farm and connect the workbench spur at `x=12`.
- [ ] Replace `Building` with direct `House`; add direct `ShopStall`, reused tree/rock/fence instances, `Workbench`, and `VillageSign`.
- [ ] `WorldShell._ready()` continues filling all collision polygons from `WorldContract` only.
- [ ] Add small house-yard side blockers so the single-root house is approached from the south.

### 1.5 GREEN — finish the real smoke cutover

- [ ] Assert tile-layer alignment, contract-derived farm tile identity, WorldShell-generated collision polygons, exactly 30 soil sprites and 30 crop roots, and exactly one enabled Y-sort node.
- [ ] Run all worktree gates, commit, then run `./tools/verify-clean.sh`.

---

## Task 2: Integrate the committed starting-farm art

The artwork is already on this branch. This task is an integration pass, **not an image-generation task**.

**Approved inputs:**
- `assets/sprites/starting-farm-tiles-source.webp`
- `assets/sprites/starting-farm-props-source.webp`

- [ ] RED: change smoke expectations from proof tile/scenery resources to runtime resources derived from the approved sheets.
- [ ] Crop/repack terrain cells into the Godot `TileSet` using Phoenix's existing `64x32` isometric diamond geometry. Do not change `TILE_SIZE` to match the `96x96` source grid.
- [ ] Terrain order: `grass | grass detail | farm-base | dirt/path` then `water | bank A | bank B | bank C`.
- [ ] Props order: `house | shop stall | tree cluster | rock cluster` then `fence | workbench | village sign | spare`.
- [ ] Reuse the tree cluster, rock cluster, and fence cells for repeated direct `Entities` children; do not generate variants.
- [ ] Keep existing shipping/market/villager art.
- [ ] No additional generated art is required for `GroundDecoration`; use existing assets/simple tile placement.

Verify worktree smoke/GUT, commit, then run `./tools/verify-clean.sh`.

---

## Task 3: Expanded persistence, interactions, reachability, and Day-1 E2E

- [ ] Add domain and persistence coverage using a farm cell outside the old 3x3 footprint.
- [ ] Keep interaction tests targeting `WorldContract` cells only.
- [ ] Replace Tree/Building detour smoke cases with House, river-west, and farm-edge reachability cases.
- [ ] Retarget **all three** stale Day-1 E2E stand positions—farm, bed, and shop—from `WorldContract` + `WorldMath.TARGET_OFFSETS`; no literal fallback.
- [ ] Run GUT + smokes + E2E, commit, then `./tools/verify-clean.sh`.

---

## Task 4: Cleanup, docs, unchanged UI visual regression, and release gates

- [ ] Delete obsolete proof ground/scenery resources only after `git grep` proves they are unreferenced. Keep the two `starting-farm-*-source.webp` sheets as source provenance even when derived runtime textures exist.
- [ ] Update `CLAUDE.md` for the new map/farm/camera/art contract; update README only if stale geometry exists.
- [ ] Run `./tools/verify-visual.sh` unchanged. Do not recapture static UI plates as evidence for this world-map change.
- [ ] Visually accept the real game/export against the approved map composition and committed art.
- [ ] Run all final gates including `build/Phoenix.zip`.
- [ ] Commit closeout on this same branch and keep PR #14 as the only PR.

---

## Self-review

Before implementation, confirm all are still true:

- no nested scenery Y-sort group;
- no second collision owner;
- no second map/camera/interaction abstraction;
- `farm_cells()` / `FARM_PATCH` remain the farm geometry sources;
- farm tile identity remains tied to `FARM_PATCH`;
- old saves intentionally fail instead of migrating;
- approved source art is reused rather than regenerated;
- direct worktree tests run before commits; `verify-clean.sh` runs after commits;
- GdUnit uses `./addons/gdUnit4/runtest.sh`;
- export target is `build/Phoenix.zip`;
- UI visual goldens are regression-checked unchanged, while the real world is visually accepted in-game.