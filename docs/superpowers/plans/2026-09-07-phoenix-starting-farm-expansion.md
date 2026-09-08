# Phoenix Starting Farm 2.5D Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Phoenix's compact proof ground with the approved `24x20` isometric homestead, including a `6x5` farm, player house, river/forest boundaries, workbench yard, eastbound future-village road, and smooth camera travel while preserving the complete 14-day game loop.

**Architecture:** Extend the owners already in production. `WorldContract` owns every fixed logical footprint and camera bound; `WorldShell` remains the only collision/runtime coordinator; `Entities` remains the only enabled Y-sort root; `FarmView` creates soil/crop presentation; the player keeps the one `Camera2D`. `starting_farm_map.tscn` is scriptless tiles/ground decals only—no collision, no tall scenery, no map type.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, 64x32 isometric `TileMapLayer`, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, existing Phoenix native visual-regression harness, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`

## Global Constraints

- One task, one branch, one PR. Continue implementation on `docs/starting-farm-2-5d-expansion`; do not open a second implementation PR.
- Keep Phoenix technically 2D: no `Node3D`, 3D camera, 3D physics, `NavigationServer`, or engine migration.
- `WorldContract.MAP_SIZE` becomes exactly `Vector2i(24, 20)`.
- `WorldContract.FARM_PATCH` becomes exactly `Rect2i(4, 10, 6, 5)` and therefore exposes exactly 30 authored farm cells.
- Keep `WorldContract.TILE_SIZE = Vector2(64.0, 32.0)` and the existing projection functions.
- Set `PROJECTION_ORIGIN = Vector2(768.0, 0.0)` and `CAMERA_BOUNDS = Rect2(128.0, -96.0, 1408.0, 800.0)` in the same contract cutover.
- `GameSession` remains the only mutable gameplay authority; views/map code must not duplicate farm legality.
- `WorldShell` remains the one collision author: every `CollisionPolygon2D` is filled from `WorldContract` through `WorldMath.footprint_to_polygon()`.
- `starting_farm_map.tscn` contains only Ground/Water/Paths/GroundDecoration. It owns no `StaticBody2D`, collision polygon, gameplay prop, tall scenery, or script.
- `Entities` remains the only enabled Y-sort node. Every occluding house/tree/rock/fence/workbench/sign prop is a direct `Entities` child.
- Reuse the existing player-owned `Camera2D`; no manual pan, zoom, edge scroll, camera manager, clamp interpolator, or persisted camera state.
- The future village road is presentation-only. No village scene, transition trigger, area ID, or map registry in this slice.
- Keep crop, stamina, time, shop, shipping, relationship, tutorial, finale, and UI rules unchanged.
- Old 9-cell development saves may become incompatible. Add no migration, schema adapter, remapping, or backward-compatibility layer.
- `PATH_ROW` / `path_cells()` and old Tree/Building-specific contract constants are removed during the cutover; do not maintain duplicate representations.
- Workbench, river, forest, rocks, fences, and village-road sign are non-interactive scenery.
- Do not weaken visual-regression tolerances. Recapture gameplay-world states `01` through `12`; leave `13` and `14` alone unless a real dependency changes them.

---

## Test setup and command contract

`./tools/verify-clean.sh` archives committed `HEAD`. Use it **after a checkpoint commit**, not as an uncommitted RED runner.

For worktree GUT runs, bootstrap the same ignored GUT version/checksum used by `verify-clean.sh` if `addons/gut/gut_cmdln.gd` is absent:

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

Run worktree GUT directly with:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Run focused headless smokes directly against the worktree:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

GdUnit/e2e use the repository shell runner:

```bash
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

Final export remains the existing unsigned ZIP:

```bash
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

---

## File map

### Create

- `scenes/world/starting_farm_map.tscn` — scriptless `Ground` / `Water` / `Paths` / `GroundDecoration` PackedScene.
- `scenes/world/starting_farm_tileset.tres` — final 64x32 starting-farm tile atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — grass/path/water/bank atlas.
- final scenery PNGs or one compact scenery atlas covering House, tree clusters, rocks, farm fences, workbench, and village sign.

### Modify

- `scripts/world/world_contract.gd`
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `scripts/player/player_controller.gd` only if a concrete camera defect requires tuning; do not add a new helper/controller
- `tests/headless/world_math_smoke.gd`
- `tests/headless/world_shell_smoke.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_save_file.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/gdunit/test_world_math.gd`
- `tests/gdunit/test_game_session_flows.gd` only where farm-size assumptions exist
- `tests/e2e/gameplay_day_one_test.gd`
- visual goldens `tests/visual/goldens/01-*.png` through `12-*.png`
- `CLAUDE.md`
- `README.md` only if it contains stale proof-ground geometry

### Retire after references are gone

- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- `PATH_ROW` / `path_cells()`
- `TREE_FOOTPRINT`, `TREE_ANCHOR`, `BUILDING_FOOTPRINT`, `BUILDING_ANCHOR`
- `proof-scenery.png` only if the final scene/tests no longer reference it

Do not delete proof player/crop/villager/shadow assets unless this PR actually replaces their production use.

---

## Task 1: Atomic world-contract and scene-ownership cutover

This task is intentionally broader than a constants-only commit. Changing the farm/origin/map size immediately affects `FarmView`, `world.tscn`, camera limits, and the two headless world oracles. Land those tightly coupled changes together so the checkpoint is runnable rather than leaving the repository half-cut-over.

**Files:**
- Create: `scenes/world/starting_farm_map.tscn`
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/world/farm_view.gd`
- Modify: `tests/headless/world_math_smoke.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/gdunit/test_world_math.gd`

**Interfaces:**
- Produces: final `24x20` / `6x5` `WorldContract` constants.
- Produces: `StartingFarmMap` as tiles/ground decals only.
- Produces: `World/StaticCollision` as the sole static collision body.
- Produces: direct `Entities/House` plus the closed direct scenery inventory; no nested scenery group.
- Produces: dynamic soil and crop roots for all 30 cells.
- Preserves: `GameSession` authority, `WorldShell` interaction order, one `Camera2D`, one enabled Y-sort root.

### 1.1 RED — update the real contract oracles before production code

- [ ] Replace the top-level farm literals in `tests/unit/test_game_session.gd`:

```gdscript
const FARM_CELL := WorldContract.farm_cells()[0]
const SECOND_FARM_CELL := WorldContract.farm_cells()[1]
```

Change helper defaults such as `_grow_and_harvest_turnip()` to default to `FARM_CELL`; do not leave `Vector2i(2, 7)` in farming fixtures.

- [ ] Replace the stale save fixture in `tests/unit/test_save_file.gd`:

```gdscript
var cell := WorldContract.farm_cells()[0]
```

- [ ] Rewrite the opening contract assertions in `tests/headless/world_math_smoke.gd` to pin:

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

Remove PATH_ROW/tree/building assertions and add environment-footprint assertions matching the spec.

- [ ] Replace the old `12x12` edge cases in the same smoke with:

```gdscript
var edge_cases := [
    [Vector2(0.5, 0.5), Vector2i(0, 0)],
    [Vector2(23.999999, 19.999999), Vector2i(23, 19)],
    [Vector2(0.5, 10.5), Vector2i(0, 10)],
    [Vector2(23.5, 10.5), Vector2i(23, 10)],
    [Vector2(12.5, 0.5), Vector2i(12, 0)],
    [Vector2(12.5, 19.5), Vector2i(12, 19)],
]
```

Update the cell-diamond and footprint expected projected points for origin `(768, 0)`.

- [ ] Add the GdUnit edge target case in `tests/gdunit/test_world_math.gd`:

```gdscript
func test_target_cell_uses_expanded_map_edges() -> void:
    assert_that(
        WorldMath.target_cell(Vector2(22.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_equal(Vector2i(23, 9))
    assert_that(
        WorldMath.target_cell(Vector2(23.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_null()
```

- [ ] Update `tests/headless/world_shell_smoke.gd` ownership expectations before implementation:

```text
World children:
StartingFarmMap, FarmSoil, StaticCollision, Entities, TargetHighlight, GameHud

StartingFarmMap children:
Ground, Water, Paths, GroundDecoration

StaticCollision:
HouseCollision,
ForestNorthwestCollision,
ForestNortheastCollision,
ForestWestCollision,
RiverWestCollision,
RiverSouthCollision,
WorkbenchCollision,
ShippingCollision,
HarvestMarketCollision,
VillagerShopkeeperCollision,
VillagerFarmerCollision,
VillagerResidentCollision,
PerimeterTop,
PerimeterRight,
PerimeterBottom,
PerimeterLeft
```

The smoke must expect exactly one enabled Y-sort node (`Entities`) and must not mention `EnvironmentScenery`.

- [ ] Run RED worktree checks:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

**Expected:** failures identify the old map/origin/scene ownership.

### 1.2 GREEN — replace the complete fixed contract

- [ ] Replace the old map/Tree/Building/path constants in `scripts/world/world_contract.gd` with the locked spec values:

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
    Vector2i(16, 8),
    Vector2i(18, 8),
    Vector2i(17, 11),
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

Keep `farm_cells()` unchanged and row-major. Delete `PATH_ROW/path_cells()`.

### 1.3 GREEN — make FarmSoil dynamic before increasing the farm

- [ ] Remove all authored `Soil_*` children from `world.tscn`; leave:

```text
FarmSoil (Node2D)
y_sort_enabled = false
z_index = 5
```

- [ ] In `FarmView._ready()`, create soil before each crop root:

```gdscript
const SOIL_TEXTURE: Texture2D = preload("res://assets/sprites/proof-soil.png")

func _ready() -> void:
    _farm_soil = get_node("../FarmSoil") as Node2D
    for cell in WorldContract.farm_cells():
        var soil := Sprite2D.new()
        soil.name = "Soil_%d_%d" % [cell.x, cell.y]
        soil.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
        soil.texture = SOIL_TEXTURE
        soil.hframes = 2
        soil.visible = false
        _farm_soil.add_child(soil)
        _soil_sprites[cell] = soil

        # Keep the existing crop-root/shadow/sprite creation immediately after this.
```

Do not add a soil scene or factory abstraction.

### 1.4 GREEN — create the map scene as tiles/ground decals only

- [ ] Create `scenes/world/starting_farm_map.tscn` with exactly:

```text
StartingFarmMap (Node2D)
├── Ground (TileMapLayer)
├── Water (TileMapLayer)
├── Paths (TileMapLayer)
└── GroundDecoration (Node2D)
```

For this structural checkpoint, the three layers may reuse `proof_ground_tileset.tres`; Task 2 swaps in the final starting-farm tileset without changing ownership.

- [ ] Set each tile layer to:

```gdscript
position = Vector2(736.0, 0.0)
```

- [ ] Author `Ground` with every cell in `x=0..23`, `y=0..19` (exactly 480 cells).

- [ ] Author the water subset exactly as:

```text
x=0..1, y=9..19
x=2..8, y=18..19
```

- [ ] Author the path subset exactly as the union of:

```text
x=11..12, y=7..10      # house approach
x=10..23, y=9..10      # main eastbound village road
x=9..11,  y=10..14     # farm/shipping spur
x=13..16, y=13..15     # workbench spur
```

Path/water overlap resolves visually by layer order; neither layer owns gameplay legality.

### 1.5 GREEN — flatten the world scene and keep collision in WorldShell

- [ ] Replace the old `Ground` instance in `world.tscn` with one `StartingFarmMap` instance.

- [ ] Keep `StaticCollision` under `World`, delete `TreeCollision`/`BuildingCollision`, and add the exact empty collision children listed in 1.1.

- [ ] Replace direct `Entities/Building` with direct `Entities/House` at `WorldContract.HOUSE_ANCHOR`.

- [ ] Add the closed direct scenery inventory under `Entities` (no grouping node):

```text
TreeClusterNorthwest
TreeClusterNorth
TreeClusterWest
TreeClusterNortheast
RockNorth
RockRiver
FenceFarmNorth
FenceFarmWest
Workbench
VillageSign
```

For this structural checkpoint, reuse `proof-scenery.png` frames/shadows where practical. Each root must be a direct `Entities` child at its ground-contact point; Task 2 only swaps final art.

- [ ] In `WorldShell._ready()`, replace Tree/Building collision setup with House + the closed environment loop:

```gdscript
var static_collision := get_node("StaticCollision") as StaticBody2D

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

Keep shipping, market, villagers, and perimeter on the same existing code path.

### 1.6 GREEN — make the smoke match production ownership

- [ ] In `world_shell_smoke.gd`, fetch ground as:

```gdscript
var map := world.get_node("StartingFarmMap") as Node2D
var ground := map.get_node("Ground") as TileMapLayer
```

Assert:

```gdscript
ground.position == Vector2(736.0, 0.0)
ground.get_used_cells().size() == 480
```

For every logical map cell, retain the current center-alignment invariant:

```gdscript
ground.to_global(ground.map_to_local(cell)) \
    == WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

- [ ] Replace the old Tree/Building collision assertions with House plus each environment footprint; keep one Y-sort-root assertion.

- [ ] Replace exact entity inventory with the flattened direct list plus 30 runtime `FarmCrop_*` children.

- [ ] Replace the nine-soil expectations with 30 named soils generated from `farm_cells()`.

### 1.7 Verify and commit

- [ ] Run worktree gates:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

**Expected:** all pass against the expanded structural world.

- [ ] Commit:

```bash
git add scenes/world/starting_farm_map.tscn scenes/world/world.tscn \
  scripts/world/world_contract.gd scripts/world/world_shell.gd scripts/world/farm_view.gd \
  tests/headless/world_math_smoke.gd tests/headless/world_shell_smoke.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd \
  tests/integration/test_gameplay_shell.gd tests/gdunit/test_world_math.gd
git commit -m "feat: cut over to expanded starting farm contract"
./tools/verify-clean.sh
```

**Expected:** clean archived GUT + all three headless smokes pass.

---

## Task 2: Replace proof visuals with the approved starting-farm environment

**Files:**
- Create: `assets/sprites/starting-farm-tiles.png`
- Create: final scenery PNGs or one compact scenery atlas
- Create: `scenes/world/starting_farm_tileset.tres`
- Modify: `scenes/world/starting_farm_map.tscn`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Consumes: final scene ownership and logical positions from Task 1.
- Produces: production environment art matching the approved composition.
- Preserves: exact node hierarchy, direct Y-sort children, logical footprints, interaction cells, and collision ownership.

### 2.1 RED — pin final asset ownership without changing architecture

- [ ] Update smoke expectations so `StartingFarmMap/Ground` uses:

```text
res://scenes/world/starting_farm_tileset.tres
res://assets/sprites/starting-farm-tiles.png
64x32 atlas regions
```

- [ ] Add integration assertions that the old generic `Building` node is absent and direct `House`, `Workbench`, and `VillageSign` nodes exist under `Entities`.

- [ ] Keep the exact-one-Y-sort-root assertion unchanged.

- [ ] Run:

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

**Expected:** asset-path assertions fail while proof textures are still in use.

### 2.2 GREEN — author the final tile atlas

- [ ] Create `starting-farm-tiles.png` using exactly these atlas slots:

```text
(0,0) grass
(1,0) grass detail
(2,0) dirt/path
(3,0) dark-ground accent
(0,1) water
(1,1) north-west bank
(2,1) north-east bank
(3,1) south/edge bank
```

- [ ] Create `starting_farm_tileset.tres` with:

```text
tile_shape = isometric
tile_layout = diamond-down
tile_size = 64x32
texture_region_size = 64x32
```

Do not add terrain auto-connect metadata.

- [ ] Switch all three map layers to the new tileset and replace proof atlas coordinates with the matching final slots. Keep the exact cell sets/positions from Task 1.

### 2.3 GREEN — replace direct scenery textures only

- [ ] Produce final art for the closed scene inventory:

```text
House
TreeClusterNorthwest
TreeClusterNorth
TreeClusterWest
TreeClusterNortheast
RockNorth
RockRiver
FenceFarmNorth
FenceFarmWest
Workbench
VillageSign
```

Shipping/HarvestMarket/villagers may retain their current production sprites unless the approved composition requires a direct replacement in this same art pass.

- [ ] Keep every root direct under `Entities`, at the existing Task-1 ground-contact position. Use child shadows and upward sprite offsets; do not add `EnvironmentScenery`.

- [ ] Put only non-occluding flower/foam/path-detail decals in `StartingFarmMap/GroundDecoration`.

### 2.4 Verify and commit

- [ ] Run:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

- [ ] Commit:

```bash
git add assets/sprites scenes/world/starting_farm_tileset.tres \
  scenes/world/starting_farm_map.tscn scenes/world/world.tscn \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: author starting farm environment"
./tools/verify-clean.sh
```

---

## Task 3: Prove expanded farming, persistence, interactions, and reachability

**Files:**
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify runtime files only if these tests expose a real layout/collision defect

**Interfaces:**
- Consumes: 30-cell `farm_cells()`, relocated interaction cells, WorldShell-generated collision.
- Produces: automated evidence that the larger map remains a complete playable 14-day scene.
- Preserves: command semantics and save schema.

### 3.1 RED — prove a cell outside the old 3x3 farm works and persists

- [ ] Add a domain test using the last authored cell, which is outside the old patch:

```gdscript
func test_expanded_farm_cell_supports_normal_farming_rules() -> void:
    var session := GameSession.new()
    var cell := WorldContract.farm_cells()[-1]
    assert_false(Rect2i(2, 7, 3, 3).has_point(cell))
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
```

The old patch literal exists only as a test assertion proving this is genuinely new capacity; it is not used for runtime targeting.

- [ ] Extend the persistence integration route so the changed cell is:

```gdscript
var expanded_cell := WorldContract.farm_cells()[-1]
```

Hoe/plant/water it, save through the existing sleep/autosave path, reopen/Continue, then assert the restored `farm` entry for `expanded_cell` retains the expected tilled/crop/watered state.

### 3.2 RED — prove every relocated interaction uses the existing path

- [ ] Keep the existing interaction-modal test table but use only contract cells:

```gdscript
for entry in [
    {"cell": WorldContract.SHOP_CELL, "panel": "ShopPanel", "close": "close_shop"},
    {"cell": WorldContract.SHIPPING_CELL, "panel": "ShippingPanel", "close": "close_shipping"},
    {"cell": WorldContract.BED_CELL, "panel": "SleepPanel", "close": "close_sleep_confirmation"},
]:
    await _place_target(world, entry["cell"])
    world.interact()
    assert_true(_panel(hud, entry["panel"]).visible)
```

Keep villager and Harvest Market tests on `WorldContract.villager_cell(id)` / `MARKET_CELL`. Do not add a new interaction abstraction.

### 3.3 RED — replace proof-ground detours with house/river/farm-edge reachability

- [ ] In `world_shell_smoke.gd`, replace Tree/Building detour cases with three deterministic movement/collision cases:

1. **House detour:** start south-west of `HOUSE_FOOTPRINT`, move toward/along its lower edge, prove the player cannot penetrate the footprint and can slide around its side.
2. **River stop:** place the player immediately east of `RiverWestCollision`, move west, prove the projected player footprint remains outside the river footprint.
3. **Farm edge:** walk representative positions along the north/east/south edges of `FARM_PATCH` and assert the player can stand close enough that `current_target_cell()` can resolve first/last-row farm cells.

Use `WorldMath.grid_to_world()` for placements; do not introduce pixel literals derived from the old map.

- [ ] Run RED/GREEN worktree gates while adjusting only scene-authored prop positions or the locked environment footprints if a real route is blocked:

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Do not add pathfinding, navigation, or special movement code to solve an authored collision problem.

### 3.4 Verify and commit

- [ ] Run:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

- [ ] Commit:

```bash
git add tests/unit/test_game_session.gd tests/integration/test_gameplay_shell.gd \
  tests/integration/test_persistence_flow.gd tests/headless/world_shell_smoke.gd \
  scripts/world/world_contract.gd scenes/world/world.tscn
git commit -m "test: prove expanded homestead gameplay routes"
./tools/verify-clean.sh
```

Only add `world_contract.gd` / `world.tscn` to this commit if reachability required an authored layout correction.

---

## Task 4: Make camera acceptance deterministic and retarget Day-1 E2E

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/e2e/gameplay_day_one_test.gd`
- Modify: `scripts/player/player_controller.gd` or `scenes/player/player.tscn` only if the tests expose a real camera defect

**Interfaces:**
- Consumes: `WorldContract.CAMERA_BOUNDS`, existing `PlayerController.camera`, existing smoothing.
- Produces: deterministic bounds/follow evidence and a layout-source-of-truth E2E route.

### 4.1 RED — assert the camera copies the authored contract

- [ ] Add an integration test:

```gdscript
func test_camera_limits_match_world_contract() -> void:
    var world := _world()
    var player := world.get_node("Entities/Player") as PlayerController
    var camera := player.get_node("Camera2D") as Camera2D
    var bounds := WorldContract.CAMERA_BOUNDS

    assert_eq(camera.limit_left, int(bounds.position.x))
    assert_eq(camera.limit_top, int(bounds.position.y))
    assert_eq(camera.limit_right, int(bounds.end.x))
    assert_eq(camera.limit_bottom, int(bounds.end.y))
    assert_true(camera.position_smoothing_enabled)
```

- [ ] Add a deterministic extreme-position helper that teleports the player, zeros velocity, calls `camera.reset_smoothing()`, waits one process frame, and checks the visible rectangle remains inside `CAMERA_BOUNDS`:

```gdscript
func _assert_camera_inside_bounds(player: PlayerController, logical: Vector2) -> void:
    player.global_position = WorldMath.grid_to_world(logical)
    player.velocity = Vector2.ZERO
    player.camera.reset_smoothing()
    await get_tree().process_frame

    var center := player.camera.get_screen_center_position()
    var half_view := Vector2(320.0, 180.0)
    var bounds := WorldContract.CAMERA_BOUNDS
    assert_gte(center.x - half_view.x, bounds.position.x - 0.001)
    assert_lte(center.x + half_view.x, bounds.end.x + 0.001)
    assert_gte(center.y - half_view.y, bounds.position.y - 0.001)
    assert_lte(center.y + half_view.y, bounds.end.y + 0.001)
```

Call it for representative reachable west/east/north/south logical points chosen outside collision footprints. Do not encode "camera moves within two frames" as the smoothing contract.

### 4.2 GREEN — keep production camera code minimal

- [ ] If limits already pass, make **no** production camera change.

- [ ] If a concrete empty-canvas defect appears, adjust only `WorldContract.CAMERA_BOUNDS` and its pinned tests. Do not create `WorldMath.camera_bounds()`, a camera manager, manual clamp code, or per-map camera data.

- [ ] Retain current smoothing speed unless visual play shows a specific defect.

### 4.3 RED/GREEN — retarget E2E from WorldContract, never a literal fallback

- [ ] In `tests/e2e/gameplay_day_one_test.gd`, derive the farm target:

```gdscript
var farm_cell := WorldContract.farm_cells()[0]
var target_offset: Vector2i = WorldMath.TARGET_OFFSETS[WorldMath.Facing.UP]
var stand := Vector2(farm_cell - target_offset) + Vector2(0.5, 0.5)
```

Use `WorldMath.grid_to_world(stand)` / the existing test node positioning path. Remove stale `Soil_3_8`, `(4, 10)`, or old proof-ground stand assumptions rather than keeping an IPC fallback.

- [ ] Run:

```bash
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

### 4.4 Commit

- [ ] Commit:

```bash
git add tests/integration/test_gameplay_shell.gd tests/e2e/gameplay_day_one_test.gd \
  scripts/player/player_controller.gd scenes/player/player.tscn scripts/world/world_contract.gd
git commit -m "test: verify homestead camera and e2e targeting"
./tools/verify-clean.sh
```

Only include production camera files if they actually changed.

---

## Task 5: Visual re-approval, stale-proof cleanup, docs, and release gates

**Files:**
- Modify: `tests/visual/goldens/01-hud.png` through `12-intro.png`
- Leave unchanged: `tests/visual/goldens/13-title.png`, `14-result-heart-of-harvest.png` unless a real dependency proves otherwise
- Modify: `CLAUDE.md`
- Modify: `README.md` only if stale map geometry exists
- Delete: retired proof tile/scenery resources only after repository search proves no references remain

**Interfaces:**
- Consumes: completed runtime map.
- Produces: approved production visual evidence and updated handoff docs.

### 5.1 Recapture only gameplay-world visual states

- [ ] Run the existing native macOS capture flow and recapture states:

```text
01-hud
02-seed-shop
03-shipping-day14
04-bag
05-almanac
06-calendar
07-dialogue
08-morning-summary
09-sleep
10-pause
11-settings
12-intro
```

Do not re-bless `13-title` or `14-result-heart-of-harvest` just because other goldens changed.

- [ ] Keep `tests/visual/compare_ui_states.gd` thresholds unchanged:

```gdscript
const CHANNEL_TOLERANCE := 1
const MISMATCH_RATIO_LIMIT := 0.0005
const CONTRACT_CHANNEL_CEILING := 12
const CONTRACT_MISMATCH_RATIO_CEILING := 0.002
```

- [ ] Run:

```bash
./tools/verify-visual.sh
```

**Expected:** all 14 states pass, with 01–12 using newly approved production captures and 13–14 matching their unchanged goldens.

### 5.2 Remove proof resources only when unused

- [ ] Search for references:

```bash
git grep -n "proof_ground_tileset\|proof-tiles.png\|proof-scenery.png\|PATH_ROW\|path_cells"
```

- [ ] Delete `proof_ground_tileset.tres`, `proof-tiles.png`, and `proof-scenery.png` only when the grep shows no production/test references. `PATH_ROW/path_cells()` should already be gone from Task 1.

Do not remove `proof-player.png`, `proof-crops.png`, `proof-villagers.png`, `proof-soil.png`, or `proof-shadow.png` unless their production uses were actually replaced.

### 5.3 Update handoff docs to the real contract

- [ ] In `CLAUDE.md`, replace the old closed-shell section with:

```text
- logical map: 24x20
- tile geometry: 64x32
- projection origin: (768, 0)
- spawn: (11.5, 8.5)
- farm: Rect2i(4, 10, 6, 5), 30 cells
- house footprint/anchor and relocated interaction cells from WorldContract
- camera bounds: Rect2(128, -96, 1408, 800)
- StartingFarmMap owns only Ground/Water/Paths/GroundDecoration
- WorldShell/WorldContract remain the one collision author
- Entities remains the one Y-sort root; occluding scenery is direct children
- future village road has no transition behavior
```

Update the architecture bullet that currently says `FarmSoil` holds authored soil decals: it is now an empty scene owner filled dynamically by `FarmView`.

- [ ] Update README only if it contains stale geometry/proof-ground claims.

### 5.4 Run the full release gates

- [ ] Run:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
./tools/verify-visual.sh
```

**Expected:** every gate exits 0. Do not waive a failing visual/import/export gate by changing thresholds or adding compatibility machinery.

### 5.5 Final acceptance walkthrough

- [ ] In the exported app, verify these qualitative facts once:

1. New Game starts outside the house.
2. The starting viewport does not show the whole `24x20` map.
3. Walking from house/farm toward the east road visibly pans the existing camera.
4. River/forest/house/workbench collision matches the visible art and does not trap the player.
5. Farm, shipping, shop, three villagers, sleep, and Harvest Market are all reachable.
6. The east road visibly continues toward a future village but cannot leave the scene.
7. No blank canvas appears at reachable camera extremes.

The automated tests own exact collision, farm, save, and camera contracts; this manual pass is only for composition/readability.

### 5.6 Commit and PR handoff

- [ ] Commit:

```bash
git add tests/visual/goldens CLAUDE.md README.md assets scenes

git commit -m "docs: close out expanded starting farm"
```

Stage only files that actually changed; omit `README.md` or deleted assets when not applicable.

- [ ] Update the existing draft PR body with implementation results and verification. Do not open another PR.

---

## Self-review checklist

Before implementation starts, the plan must still satisfy:

- **One Y-sort owner:** no `EnvironmentScenery` grouping node.
- **One collision owner:** no `StaticCollision` or polygons inside `starting_farm_map.tscn`.
- **One map seam:** `StartingFarmMap` is tiles/ground decals only, not a map type.
- **One farm source:** every domain/view/test target comes from `WorldContract.farm_cells()` except the explicit old-patch assertion proving expanded capacity.
- **One camera:** player-owned `Camera2D`; bounds live in `WorldContract`.
- **No compatibility work:** old 9-cell saves may fail.
- **Correct verifier semantics:** direct worktree tests before commits; `verify-clean.sh` after commits.
- **Correct GdUnit invocation:** `./addons/gdUnit4/runtest.sh`, not `godot -s`.
- **Correct export artifact:** `build/Phoenix.zip`.
- **Visual scope:** re-approve 01–12; do not loosen thresholds or churn 13–14.

If any implementation task needs a second map/collision/Y-sort/camera abstraction to proceed, stop and fix the authored scene/contract instead.