# Phoenix Starting Farm 2.5D Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the compact proof ground with the approved `24x20` isometric homestead, `6x5` farm, house, river/forest boundaries, workbench yard, future-village road, and smooth camera travel while preserving the complete 14-day game loop.

**Architecture:** Extend existing owners only. `WorldContract` owns every fixed footprint and camera bound; `WorldShell` fills every world collision polygon; `Entities` stays the one Y-sort root; `FarmView` creates soil/crops; the player keeps the one `Camera2D`. `starting_farm_map.tscn` is scriptless Ground/Water/Paths/GroundDecoration only.

**Tech Stack:** Godot 4.7.1, statically typed GDScript, 64x32 isometric `TileMapLayer`, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, Phoenix visual-regression harness, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`

## Global Constraints

- One task / one branch / one PR: continue on `docs/starting-farm-2-5d-expansion`.
- `MAP_SIZE = Vector2i(24, 20)`, `FARM_PATCH = Rect2i(4, 10, 6, 5)`, `PROJECTION_ORIGIN = Vector2(768, 0)`.
- `CAMERA_BOUNDS = Rect2(128, -96, 1408, 800)` lands with the contract, not later.
- Keep Phoenix 2D isometric. No `Node3D`, navigation, streaming, map registry, scene-transition framework, or generic world-object system.
- `GameSession` remains the only mutable gameplay authority.
- `WorldContract -> WorldShell -> CollisionPolygon2D` remains the only collision path.
- `Entities` remains the only enabled Y-sort node; all occluding scenery is a direct child.
- Reuse the existing player-owned `Camera2D`; no pan/zoom/camera manager/persisted camera state.
- The village road, workbench, river, forest, rocks, fences, and sign are non-interactive.
- No balance retune and no save migration. Old 9-cell saves may fail through existing farm validation.
- Remove `PATH_ROW/path_cells()` and obsolete Tree/Building contract constants; do not keep duplicate representations.
- Recapture gameplay-world visual states 01–12 only; do not loosen visual tolerances.

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

**Create**
- `scenes/world/starting_farm_map.tscn` — scriptless Ground/Water/Paths/GroundDecoration.
- `scenes/world/starting_farm_tileset.tres` — final 64x32 environment atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — grass/path/water/bank atlas.
- final house/tree-cluster/rock/fence/workbench/sign scenery PNGs or one compact scenery atlas.

**Modify**
- `scripts/world/world_contract.gd`
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
- visual goldens 01–12
- `CLAUDE.md`; `README.md` only if stale geometry is present

**Retire when unreferenced**
- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- `proof-scenery.png` only if no longer used
- `PATH_ROW/path_cells()` and old Tree/Building footprint/anchor constants

Do not remove proof player/crop/villager/soil/shadow assets unless this PR actually replaces their production use.

---

## Task 1: Atomic expanded-world cutover

Changing map/farm/origin constants immediately affects scene startup, FarmView, camera limits, and both world smokes. Land the contract and those dependent owners together so this checkpoint stays runnable.

**Files:** `world_contract.gd`, `starting_farm_map.tscn`, `world.tscn`, `world_shell.gd`, `farm_view.gd`, both headless world smokes, `test_game_session.gd`, `test_save_file.gd`, `test_gameplay_shell.gd`, `test_world_math.gd`.

### 1.1 RED — move the real oracles first

- [ ] In `test_game_session.gd`, replace stale farm constants with compile-time expressions from the one authored patch:

```gdscript
const FARM_CELL := WorldContract.FARM_PATCH.position
const SECOND_FARM_CELL := WorldContract.FARM_PATCH.position + Vector2i.RIGHT
```

Also change helper defaults such as `_grow_and_harvest_turnip()` to `FARM_CELL`. Do not call `WorldContract.farm_cells()` from a `const` initializer; user-defined function calls are not compile-time constant expressions.

- [ ] In `test_save_file.gd`, use the runtime source directly:

```gdscript
var cell := WorldContract.farm_cells()[0]
```

- [ ] Update `world_math_smoke.gd` to expect:

```gdscript
WorldContract.MAP_SIZE == Vector2i(24, 20)
WorldContract.PROJECTION_ORIGIN == Vector2(768.0, 0.0)
WorldContract.PLAYER_SPAWN == Vector2(11.5, 8.5)
WorldContract.CAMERA_BOUNDS == Rect2(128.0, -96.0, 1408.0, 800.0)
WorldContract.FARM_PATCH == Rect2i(4, 10, 6, 5)
WorldContract.farm_cells().size() == 30
WorldContract.HOUSE_FOOTPRINT == Rect2(10.0, 4.0, 4.0, 3.0)
WorldContract.HOUSE_ANCHOR == Vector2(928.0, 304.0)
```

Remove PATH_ROW/Tree/Building expectations. Replace 12x12 edge cases with 24x20 corners, including `(23.999999, 19.999999) -> (23,19)`.

- [ ] Extend `tests/gdunit/test_world_math.gd`:

```gdscript
func test_target_cell_uses_expanded_map_edges() -> void:
    assert_that(
        WorldMath.target_cell(Vector2(22.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_equal(Vector2i(23, 9))
    assert_that(
        WorldMath.target_cell(Vector2(23.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_null()
```

- [ ] Update `world_shell_smoke.gd` ownership expectations to:

```text
World
├── StartingFarmMap
├── FarmSoil
├── StaticCollision
├── Entities
├── TargetHighlight
└── GameHud

StartingFarmMap
├── Ground
├── Water
├── Paths
└── GroundDecoration
```

`StaticCollision` expects House + closed environment + shipping + market + villagers + four perimeter polygons. `Entities` remains the single Y-sort root and has no `EnvironmentScenery` child.

- [ ] Run RED worktree smokes/GdUnit; failures should point at the old contract/scene.

### 1.2 GREEN — replace the fixed contract together

- [ ] Replace the old map/Tree/Building/path constants with:

```gdscript
const MAP_SIZE := Vector2i(24, 20)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(11.5, 8.5)
const PLAYER_HALF_EXTENT := 0.18
const MOVE_SPEED := 96.0
const CAMERA_TOP_PADDING := 96.0
const CAMERA_BOUNDS := Rect2(128.0, -96.0, 1408.0, 800.0)

const FARM_PATCH := Rect2i(4, 10, 6, 5)
const HOUSE_FOOTPRINT := Rect2(10.0, 4.0, 4.0, 3.0)
const HOUSE_ANCHOR := Vector2(928.0, 304.0)
const BED_CELL := Vector2i(12, 7)
const SHIPPING_CELL := Vector2i(10, 13)
const SHIPPING_FOOTPRINT := Rect2(10.2, 13.2, 0.6, 0.6)
const SHOP_CELL := Vector2i(17, 9)
const MARKET_CELL := Vector2i(19, 10)
const MARKET_FOOTPRINT := Rect2(19.2, 10.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(1056.0, 480.0)

const VILLAGER_CELLS: Array[Vector2i] = [
    Vector2i(16, 8), Vector2i(18, 8), Vector2i(17, 11),
]
const VILLAGER_FOOTPRINTS: Array[Rect2] = [
    Rect2(16.2, 8.2, 0.6, 0.6),
    Rect2(18.2, 8.2, 0.6, 0.6),
    Rect2(17.2, 11.2, 0.6, 0.6),
]

const ENVIRONMENT_COLLISION_NAMES: Array[String] = [
    "ForestNorthwestCollision",
    "ForestNortheastCollision",
    "ForestWestCollision",
    "RiverWestCollision",
    "RiverSouthCollision",
    "WorkbenchCollision",
]
const ENVIRONMENT_FOOTPRINTS: Array[Rect2] = [
    Rect2(1.0, 1.0, 7.0, 3.0),
    Rect2(15.0, 1.0, 7.0, 2.5),
    Rect2(1.0, 4.0, 2.0, 5.0),
    Rect2(0.0, 9.0, 2.0, 11.0),
    Rect2(2.0, 18.0, 7.0, 2.0),
    Rect2(14.2, 14.2, 1.6, 1.2),
]
```

Keep `farm_cells()` rectangular/row-major. Delete `PATH_ROW/path_cells()`.

### 1.3 GREEN — make soil dynamic

- [ ] Leave `FarmSoil` authored but empty (`y_sort_enabled=false`, `z_index=5`).
- [ ] In `FarmView._ready()`, create each soil from the same loop as crops:

```gdscript
const SOIL_TEXTURE: Texture2D = preload("res://assets/sprites/proof-soil.png")

var soil := Sprite2D.new()
soil.name = "Soil_%d_%d" % [cell.x, cell.y]
soil.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
soil.texture = SOIL_TEXTURE
soil.hframes = 2
soil.visible = false
_farm_soil.add_child(soil)
_soil_sprites[cell] = soil
```

Keep the existing crop root/shadow/sprite creation immediately after it. No soil scene/factory.

### 1.4 GREEN — cut scene ownership over without a second path

- [ ] Create `starting_farm_map.tscn` with only Ground/Water/Paths/GroundDecoration. For this structural checkpoint it may reuse `proof_ground_tileset.tres`; Task 2 replaces art.
- [ ] Set Ground/Water/Paths position to `Vector2(736, 0)`. Ground contains every `x=0..23,y=0..19` cell: exactly 480.
- [ ] Water cells: `x=0..1,y=9..19` plus `x=2..8,y=18..19`.
- [ ] Path cells are the union of:

```text
x=11..12,y=7..10
x=10..23,y=9..10
x=9..11,y=10..14
x=13..16,y=13..15
```

- [ ] Instance `StartingFarmMap` in `world.tscn`; keep `StaticCollision` directly under World.
- [ ] Replace `Building` with direct `House`. Add these direct `Entities` children—no grouping node:

```text
TreeClusterNorthwest, TreeClusterNorth, TreeClusterWest, TreeClusterNortheast,
RockNorth, RockRiver, FenceFarmNorth, FenceFarmWest, Workbench, VillageSign
```

Use proof scenery as temporary visual content if needed; roots stay at scene-authored ground-contact positions.

- [ ] `WorldShell._ready()` fills House plus environment polygons from `WorldContract`:

```gdscript
var house_collision := static_collision.get_node("HouseCollision") as CollisionPolygon2D
house_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.HOUSE_FOOTPRINT)

for index in WorldContract.ENVIRONMENT_COLLISION_NAMES.size():
    var collision := static_collision.get_node(
        WorldContract.ENVIRONMENT_COLLISION_NAMES[index]
    ) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(
        WorldContract.ENVIRONMENT_FOOTPRINTS[index]
    )
```

Keep shipping/market/villager/perimeter generation on the existing path.

### 1.5 GREEN — finish the real smoke cutover

- [ ] `world_shell_smoke.gd` fetches `StartingFarmMap/Ground`, expects position `(736,0)`, 480 cells, and keeps the alignment invariant:

```gdscript
ground.to_global(ground.map_to_local(cell)) \
    == WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

- [ ] Assert all WorldShell-generated polygons equal their `WorldContract` footprints.
- [ ] Assert exactly 30 named soil sprites and 30 direct `FarmCrop_*` roots.
- [ ] Assert exactly one enabled Y-sort node and the closed direct scenery inventory.

- [ ] Run all worktree gates, then commit:

```bash
git add scenes/world/starting_farm_map.tscn scenes/world/world.tscn \
  scripts/world/world_contract.gd scripts/world/world_shell.gd scripts/world/farm_view.gd \
  tests/headless/world_math_smoke.gd tests/headless/world_shell_smoke.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd \
  tests/integration/test_gameplay_shell.gd tests/gdunit/test_world_math.gd
git commit -m "feat: cut over to expanded starting farm contract"
./tools/verify-clean.sh
```

Expected: clean archived GUT and all headless smokes pass.

---

## Task 2: Final starting-farm environment art

**Files:** create final tile/scenery assets + `starting_farm_tileset.tres`; modify map/world scene and asset-path smokes.

- [ ] RED: change smoke expectations from proof tile/scenery resources to final starting-farm resources; keep hierarchy/Y-sort assertions unchanged.
- [ ] Create `starting-farm-tiles.png` with exact atlas slots:

```text
(0,0) grass; (1,0) grass detail; (2,0) dirt/path; (3,0) dark accent
(0,1) water; (1,1) NW bank; (2,1) NE bank; (3,1) south/edge bank
```

- [ ] Create `starting_farm_tileset.tres` as one 64x32 isometric diamond-down atlas. No terrain auto-connect metadata.
- [ ] Switch Ground/Water/Paths to the final tileset without changing cell ownership or map geometry.
- [ ] Replace temporary proof scenery for the closed direct inventory: House, four tree clusters, two rocks, two farm fences, Workbench, VillageSign. Keep roots direct under `Entities`, shadows on the ground plane, visible sprites offset upward.
- [ ] `GroundDecoration` gets only non-occluding flowers/foam/path detail.
- [ ] Keep shipping/market/villager sprites unless the approved art pass explicitly replaces them; no asset registry.

Verify worktree smoke/GUT, commit, then run `./tools/verify-clean.sh`.

---

## Task 3: Expanded farming, persistence, interactions, reachability

**Files:** `test_game_session.gd`, `test_gameplay_shell.gd`, `test_persistence_flow.gd`, `world_shell_smoke.gd`; runtime scene/contract only if a real layout defect appears.

### 3.1 Expanded farm + persistence

- [ ] Add a domain test using `WorldContract.farm_cells()[-1]`; assert it is outside `Rect2i(2,7,3,3)` and supports normal hoe/plant/water commands.
- [ ] Extend persistence acceptance with:

```gdscript
var expanded_cell := WorldContract.farm_cells()[-1]
```

Mutate that cell, sleep/autosave through the existing production path, reopen/Continue, and assert the restored entry preserves its state. This proves 30-cell persistence rather than merely reusing an old cell.

### 3.2 Relocated interactions

- [ ] Keep existing interaction tests but target only `WorldContract.SHOP_CELL`, `SHIPPING_CELL`, `BED_CELL`, `MARKET_CELL`, and `villager_cell(id)`. Do not create a new interaction abstraction.

### 3.3 Collision/reachability

- [ ] Replace Tree/Building detour smoke cases with:
  1. House lower-edge collision + side slide.
  2. River-west collision stop.
  3. Representative north/east/south farm-edge positions proving first/last-row farm cells can be targeted.
- [ ] Use `WorldMath.grid_to_world()` for all placements. Fix authored footprints/positions if blocked; do not add pathfinding or special movement code.

Run GUT + both smokes, commit the test/layout checkpoint, then `./tools/verify-clean.sh`.

---

## Task 4: Deterministic camera acceptance + Day-1 E2E

**Files:** `test_gameplay_shell.gd`, `gameplay_day_one_test.gd`; production camera files only if tests expose a real defect.

### 4.1 Camera contract

- [ ] Assert the existing camera copies all four `WorldContract.CAMERA_BOUNDS` edges and still has position smoothing enabled.
- [ ] Add a helper that receives `Camera2D`, teleports the player to representative reachable west/east/north/south logical positions, calls `camera.reset_smoothing()`, waits one process frame, then verifies the visible `640x360` rectangle remains inside `CAMERA_BOUNDS`:

```gdscript
var center := camera.get_screen_center_position()
var half_view := Vector2(320.0, 180.0)
var bounds := WorldContract.CAMERA_BOUNDS
assert_gte(center.x - half_view.x, bounds.position.x - 0.001)
assert_lte(center.x + half_view.x, bounds.end.x + 0.001)
assert_gte(center.y - half_view.y, bounds.position.y - 0.001)
assert_lte(center.y + half_view.y, bounds.end.y + 0.001)
```

Do not specify "moves after two frames" and do not add clamp interpolation. If the existing camera passes, change no production camera code.

### 4.2 E2E source of truth

- [ ] Retarget Day-1 E2E using runtime contract values only:

```gdscript
var farm_cell := WorldContract.farm_cells()[0]
var target_offset: Vector2i = WorldMath.TARGET_OFFSETS[WorldMath.Facing.UP]
var stand := Vector2(farm_cell - target_offset) + Vector2(0.5, 0.5)
```

Remove stale soil-node/literal-map assumptions. No `(4,10)` fallback.

Run GUT + e2e shell runner, commit, then `./tools/verify-clean.sh`.

---

## Task 5: Visual approval, cleanup, docs, release gates

### 5.1 Visual states

- [ ] Recapture/approve exactly states 01–12 with the existing native macOS flow.
- [ ] Leave `13-title` and `14-result-heart-of-harvest` unchanged unless a real dependency changes them.
- [ ] Keep these thresholds unchanged:

```gdscript
CHANNEL_TOLERANCE = 1
MISMATCH_RATIO_LIMIT = 0.0005
CONTRACT_CHANNEL_CEILING = 12
CONTRACT_MISMATCH_RATIO_CEILING = 0.002
```

Run `./tools/verify-visual.sh`.

### 5.2 Cleanup

- [ ] Run:

```bash
git grep -n "proof_ground_tileset\|proof-tiles.png\|proof-scenery.png\|PATH_ROW\|path_cells"
```

Delete proof ground/scenery resources only when no production/test reference remains. Keep proof player/crop/villager/soil/shadow assets if still used.

### 5.3 Handoff docs

- [ ] Update `CLAUDE.md` from the old `12x12`/`3x3` shell to:

```text
map 24x20; tiles 64x32; origin (768,0); spawn (11.5,8.5)
farm Rect2i(4,10,6,5) / 30 cells
camera Rect2(128,-96,1408,800)
StartingFarmMap = Ground/Water/Paths/GroundDecoration only
WorldContract + WorldShell = single collision author
Entities = single Y-sort root; occluding props direct children
FarmSoil authored empty and filled dynamically by FarmView
future village road has no transition behavior
```

Update README only if it contains stale geometry.

### 5.4 Final gates

- [ ] Run the complete Verification Contract commands, including `build/Phoenix.zip` export and visual verification.
- [ ] In the exported app, qualitatively verify: spawn outside house; start view does not show whole map; camera visibly pans house/farm -> east road; collision matches visible house/river/forest/workbench; all gameplay interactions remain reachable; road cannot leave the scene; no blank canvas at reachable camera extremes.

Commit closeout evidence/docs on this same branch and update PR #14. Do not open another PR.

---

## Self-review

Before implementation, confirm all are still true:

- no nested scenery Y-sort group;
- no collision inside `StartingFarmMap`;
- no second map/camera/interaction abstraction;
- `farm_cells()` / `FARM_PATCH` are the only farm geometry sources;
- old saves intentionally fail instead of migrating;
- direct worktree tests run before commits; `verify-clean.sh` runs after commits;
- GdUnit uses `./addons/gdUnit4/runtest.sh`;
- export target is `build/Phoenix.zip`;
- visual scope is 01–12 without threshold changes.

If implementation appears to require a second owner for map, collision, Y-sort, or camera behavior, fix the authored scene/contract instead.