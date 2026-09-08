# Phoenix Starting Farm 2.5D Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Phoenix's compact proof ground with the approved `24x20` isometric homestead, visible `6x5` farm, player house, river/forest boundary, roadside shop/market, workbench yard, eastbound future-village road, and camera travel while preserving the existing 14-day gameplay rules.

**Architecture:** Extend existing owners only. `WorldContract` owns fixed logical geometry; `WorldMath` owns projection/derived geometry; `WorldShell` fills every world collision polygon; `Entities` remains the single Y-sort root; `FarmView` creates soil/crops; the player keeps the one `Camera2D`. Keep `Ground`, `Water`, `Paths`, and `GroundDecoration` as direct `World` children; do not extract a map PackedScene until a second map exists.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, 64x32 isometric `TileMapLayer`, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, existing Phoenix visual-regression harness, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`

## Global Constraints

- One task / one branch / one PR. Continue implementation on `docs/starting-farm-2-5d-expansion`; do not open a second implementation PR.
- `MAP_SIZE = Vector2i(24, 20)`, `FARM_PATCH = Rect2i(4, 10, 6, 5)`, `PROJECTION_ORIGIN = Vector2(768, 0)`.
- `CAMERA_BOUNDS = Rect2(128, -96, 1408, 800)` lands atomically with the map contract and must equal `WorldMath.map_camera_bounds()`.
- Keep Phoenix technically 2D isometric. No `Node3D`, navigation, streaming, map registry, scene-transition framework, or generic world-object system.
- `GameSession` remains the only mutable gameplay authority.
- `WorldContract -> WorldShell -> CollisionPolygon2D` remains the only collision-authoring path.
- `Entities` remains the only enabled Y-sort node; every occluding prop is a direct child.
- Reuse the existing player-owned `Camera2D`; no pan/zoom/camera manager/persisted camera state.
- The 30 farm cells are visual scale/future headroom. Do not retune stamina, time, crops, economy, or the 14-day loop to make all 30 simultaneously workable.
- The village road, workbench, river, forest, rocks, fences, and sign are non-interactive.
- Old 9-cell development saves may fail through existing farm validation. Add no schema bump, migration, or compatibility layer.
- Remove `PATH_ROW/path_cells()` and obsolete Tree/Building/Market anchor constants; do not keep duplicate representations.
- Do not add `starting_farm_map.tscn`; direct world layers are the YAGNI choice for the only map.
- Do not recapture UI goldens for the world change. The visual harness uses static plates; run it unchanged as a regression gate.

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

### Create

- `scenes/world/starting_farm_tileset.tres` — final 64x32 environment atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — grass/detail/path/farm/water/bank atlas.
- final house/shop-stall/tree-cluster/rock/fence/workbench/sign PNGs or one compact scenery atlas.

### Modify

- `scripts/world/world_contract.gd`
- `scripts/world/world_math.gd`
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `tests/headless/world_math_smoke.gd`
- `tests/headless/world_shell_smoke.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_save_file.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/gdunit/test_world_math.gd`
- `tests/gdunit/test_game_session_flows.gd` only where farm-size assumptions exist
- `tests/e2e/gameplay_day_one_test.gd`
- `CLAUDE.md`
- `README.md` only if stale geometry is present

`player_controller.gd` is not a planned modification. Its existing camera-limit copy path should continue to work unchanged.

### Retire when unreferenced

- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- `proof-scenery.png` only if no longer used
- `PATH_ROW/path_cells()`
- `TREE_FOOTPRINT`, `TREE_ANCHOR`, `BUILDING_FOOTPRINT`, `BUILDING_ANCHOR`, and `MARKET_ANCHOR`

Keep proof player/crop/villager/soil/shadow assets while production still uses them.

---

## Task 1: Atomic expanded-world contract and structural cutover

Changing map/farm/origin constants immediately affects scene startup, FarmView, camera limits, and both world smokes. Land the contract, derived geometry, direct tile-layer hierarchy, dynamic farm presentation, collisions, and real oracles together so this checkpoint stays runnable.

### Files

- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/world/world_math.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/world/farm_view.gd`
- Modify: `tests/headless/world_math_smoke.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/gdunit/test_world_math.gd`

### Interfaces

- Produces: `WorldMath.footprint_ground_anchor(footprint: Rect2) -> Vector2`
- Produces: `WorldMath.map_camera_bounds() -> Rect2`
- Produces: direct `World/Ground`, `World/Water`, `World/Paths`, `World/GroundDecoration`
- Preserves: `World/StaticCollision`, `World/FarmSoil`, `World/Entities`, `World/TargetHighlight`, `World/GameHud`
- Preserves: `WorldContract.farm_cells()` row-major rectangle behavior

### 1.1 RED — move the real contract oracles first

- [ ] In `tests/unit/test_game_session.gd`, replace stale farm constants with compile-time expressions from the authored patch:

```gdscript
const FARM_CELL := WorldContract.FARM_PATCH.position
const SECOND_FARM_CELL := WorldContract.FARM_PATCH.position + Vector2i.RIGHT
```

Also change helper defaults such as `_grow_and_harvest_turnip()` to `FARM_CELL`. Do not call `WorldContract.farm_cells()` from a `const` initializer.

- [ ] In `tests/unit/test_save_file.gd`, replace the stale literal:

```gdscript
var cell := WorldContract.farm_cells()[0]
```

- [ ] Change `tests/headless/world_math_smoke.gd` contract expectations to:

```gdscript
WorldContract.MAP_SIZE == Vector2i(24, 20)
WorldContract.PROJECTION_ORIGIN == Vector2(768.0, 0.0)
WorldContract.PLAYER_SPAWN == Vector2(11.5, 8.5)
WorldContract.CAMERA_BOUNDS == Rect2(128.0, -96.0, 1408.0, 800.0)
WorldContract.FARM_PATCH == Rect2i(4, 10, 6, 5)
WorldContract.farm_cells().size() == 30
WorldContract.HOUSE_FOOTPRINT == Rect2(10.0, 4.0, 4.0, 3.0)
WorldContract.SHOP_STALL_FOOTPRINT == Rect2(15.0, 7.0, 1.0, 2.0)
```

Remove PATH_ROW/Tree/Building/Market-anchor expectations. Replace 12x12 edge cases with 24x20 corners, including `(23.999999, 19.999999) -> (23, 19)`.

- [ ] Add RED helper expectations to `world_math_smoke.gd`:

```gdscript
if not _expect_vec2(
    WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT),
    Vector2(976.0, 336.0),
    "house ground anchor",
):
    return

if not _expect(
    WorldContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds(),
    "camera bounds derived from map geometry",
):
    return
```

- [ ] Extend `tests/gdunit/test_world_math.gd`:

```gdscript
func test_target_cell_uses_expanded_map_edges() -> void:
    assert_that(
        WorldMath.target_cell(Vector2(22.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_equal(Vector2i(23, 9))
    assert_that(
        WorldMath.target_cell(Vector2(23.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_null()

func test_derived_map_geometry_matches_locked_contract() -> void:
    assert_vector(
        WorldMath.footprint_ground_anchor(Rect2(10.0, 4.0, 4.0, 3.0))
    ).is_equal_approx(Vector2(976.0, 336.0), Vector2(0.0001, 0.0001))
    assert_that(WorldMath.map_camera_bounds()).is_equal(WorldContract.CAMERA_BOUNDS)
```

- [ ] Update `world_shell_smoke.gd` ownership expectations to direct world layers:

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

`StaticCollision` expects House + ShopStall + closed environment + shipping + market + villagers + four perimeter polygons. `Entities` remains the only enabled Y-sort node and has no nested scenery group.

- [ ] Run the direct worktree GUT/headless/GdUnit commands from the Verification Contract.

**Expected:** failures point at the old `12x12` contract, missing helpers/layers/entities, stale collision names, and old nine-soil scene.

### 1.2 GREEN — add the two derived WorldMath helpers

- [ ] Add to `scripts/world/world_math.gd` beside the existing footprint helpers:

```gdscript
static func footprint_ground_anchor(footprint: Rect2) -> Vector2:
    var center := footprint.position + footprint.size * 0.5
    var bottom := footprint.position + footprint.size
    return Vector2(grid_to_world(center).x, grid_to_world(bottom).y)

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

Do not move camera ownership out of `WorldContract`/`PlayerController`; these are pure derivation/oracle helpers only.

### 1.3 GREEN — replace the fixed world contract atomically

- [ ] Replace the old map/Tree/Building/path constants in `scripts/world/world_contract.gd` with:

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
const BED_CELL := Vector2i(12, 7)

const SHIPPING_CELL := Vector2i(10, 13)
const SHIPPING_FOOTPRINT := Rect2(10.2, 13.2, 0.6, 0.6)

const SHOP_CELL := Vector2i(17, 9)
const SHOP_STALL_FOOTPRINT := Rect2(15.0, 7.0, 1.0, 2.0)

const MARKET_CELL := Vector2i(19, 10)
const MARKET_FOOTPRINT := Rect2(19.2, 10.2, 0.6, 0.6)

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
    "HouseYardWestCollision",
    "HouseYardEastCollision",
    "RiverWestCollision",
    "RiverSouthCollision",
    "WorkbenchCollision",
]
const ENVIRONMENT_FOOTPRINTS: Array[Rect2] = [
    Rect2(1.0, 1.0, 7.0, 3.0),
    Rect2(15.0, 1.0, 7.0, 2.5),
    Rect2(1.0, 4.0, 2.0, 5.0),
    Rect2(8.0, 4.0, 2.0, 3.0),
    Rect2(14.0, 4.0, 1.0, 3.0),
    Rect2(0.0, 9.0, 2.0, 11.0),
    Rect2(2.0, 18.0, 7.0, 2.0),
    Rect2(14.2, 14.2, 1.6, 1.2),
]
```

Keep `VILLAGER_COLLISION_NAMES` and `farm_cells()` unchanged in behavior. Delete `PATH_ROW/path_cells()` and the retired anchor constants.

### 1.4 GREEN — make soil dynamic

- [ ] Leave `FarmSoil` authored but empty (`y_sort_enabled = false`, `z_index = 5`).
- [ ] In `FarmView._ready()`, create each soil in the same farm-cell loop as crops:

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

### 1.5 GREEN — author direct world layers and non-overlapping paths

- [ ] Keep/expand the direct `Ground` node and add direct siblings `Water`, `Paths`, `GroundDecoration` in `world.tscn`.
- [ ] Set all three TileMapLayer transforms to:

```gdscript
position = Vector2(736.0, 0.0)
```

- [ ] For this structural checkpoint, keep `proof_ground_tileset.tres` temporarily:
  - `Ground`: exactly 480 cells; use proof `FARM_TILE (1,0)` for every `FARM_PATCH` cell and proof default grass elsewhere.
  - `Paths`: use proof `PATH_TILE (2,0)` for the locked path union below.
  - `Water`: may remain empty until Task 2 supplies the final water atlas.
  - `GroundDecoration`: empty until Task 2.

Locked path union:

```text
x=11..12, y=7..10
x=10..23, y=9..10
x=10..12, y=10..14
x=12..16, y=13..15
```

The farm occupies `x=4..9, y=10..14`, so no Paths cell may satisfy `FARM_PATCH.has_point(cell)`. The workbench spur intersects the farm-side path at `x=12`.

### 1.6 GREEN — flatten static world entities and keep one collision path

- [ ] Replace generic `Building` with direct `House` and add direct `ShopStall` plus the closed scenery roots. No grouping node:

```text
Player
House
ShopStall
TreeClusterNorthwest
TreeClusterNorth
TreeClusterWest
TreeClusterNortheast
RockNorth
RockRiver
FenceHouseWest
FenceHouseEast
FenceFarmNorth
FenceFarmWest
Workbench
VillageSign
Shipping
HarvestMarket
VillagerShopkeeper
VillagerFarmer
VillagerResident
FarmCrop_* (runtime)
```

- [ ] Use temporary proof scenery where final art does not exist yet. The two critical structural root positions are:

```gdscript
House.position = Vector2(976.0, 336.0)
ShopStall.position = Vector2(1008.0, 400.0)
```

`world_shell_smoke.gd` derives those expected values through `footprint_ground_anchor()` rather than copying the literals.

- [ ] Keep `StaticCollision` directly under `World`. Add `HouseCollision`, `ShopStallCollision`, the eight environment named children, existing shipping/market/villager children, and the four perimeter children.

- [ ] Extend `WorldShell._ready()` only along its current pattern:

```gdscript
var house_collision := static_collision.get_node("HouseCollision") as CollisionPolygon2D
house_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.HOUSE_FOOTPRINT)

var shop_collision := static_collision.get_node("ShopStallCollision") as CollisionPolygon2D
shop_collision.polygon = WorldMath.footprint_to_polygon(
    WorldContract.SHOP_STALL_FOOTPRINT
)

for index in WorldContract.ENVIRONMENT_COLLISION_NAMES.size():
    var collision := static_collision.get_node(
        WorldContract.ENVIRONMENT_COLLISION_NAMES[index]
    ) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(
        WorldContract.ENVIRONMENT_FOOTPRINTS[index]
    )
```

Keep shipping/market/villager/perimeter generation on the existing path.

### 1.7 GREEN — finish the real smoke cutover

- [ ] Update `world_shell_smoke.gd` to fetch direct `Ground`, expect position `(736,0)`, 480 cells, and keep the existing alignment invariant:

```gdscript
ground.to_global(ground.map_to_local(cell)) \
    == WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

- [ ] Keep a farm-tile oracle even though `PATH_ROW` is gone:

```gdscript
func _expected_ground_tile(cell: Vector2i) -> Vector2i:
    return FARM_TILE if WorldContract.FARM_PATCH.has_point(cell) else DEFAULT_TILE
```

For every Ground cell, assert the atlas coords equal `_expected_ground_tile(cell)`.

- [ ] For `Paths`, assert:
  - no used cell is inside `FARM_PATCH`;
  - representative connection cells exist: `(11,7)`, `(10,10)`, `(12,13)`, `(16,15)`, `(23,10)`.

Do not create a second `WorldContract` path table.

- [ ] Assert every WorldShell-generated polygon equals its corresponding `WorldContract` footprint.
- [ ] Assert exactly 30 named soil sprites and 30 direct `FarmCrop_*` roots.
- [ ] Assert exactly one enabled Y-sort node and the closed direct scenery inventory.
- [ ] Keep the existing camera limit/smoothing assertion, but replace the hand-typed camera-contract duplicate in `world_math_smoke.gd` with the `map_camera_bounds()` equality.

- [ ] Run all worktree gates, then commit:

```bash
git add scripts/world/world_contract.gd scripts/world/world_math.gd \
  scenes/world/world.tscn scripts/world/world_shell.gd scripts/world/farm_view.gd \
  tests/headless/world_math_smoke.gd tests/headless/world_shell_smoke.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd \
  tests/integration/test_gameplay_shell.gd tests/gdunit/test_world_math.gd
git commit -m "feat: cut over to expanded starting farm contract"
./tools/verify-clean.sh
```

**Expected:** clean archived GUT and all headless smokes pass.

---

## Task 2: Final starting-farm environment art and composition

This checkpoint replaces structural proof visuals with the approved homestead art without changing runtime ownership or gameplay rules.

### Files

- Create: `assets/sprites/starting-farm-tiles.png`
- Create: `scenes/world/starting_farm_tileset.tres`
- Create: final scenery PNGs or one compact scenery atlas
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`

### 2.1 RED — pin the final atlas contract

- [ ] Change asset/tile smoke expectations to the final atlas and these exact slots:

```text
(0,0) grass
(1,0) grass detail
(2,0) dirt/path
(3,0) farm-field base
(0,1) water
(1,1) north-west bank
(2,1) north-east bank
(3,1) south/edge bank
```

- [ ] Change `_expected_ground_tile()` so every `FARM_PATCH` cell expects final `FARM_TILE := Vector2i(3, 0)`.
- [ ] Run `world_shell_smoke.gd`; it must fail while proof resources are still installed.

### 2.2 GREEN — author final tile layers

- [ ] Create `starting-farm-tiles.png` at `64x32` per atlas cell with the exact slots above.
- [ ] Create `starting_farm_tileset.tres` as one isometric diamond-down atlas:

```text
tile_shape = TILE_SHAPE_ISOMETRIC
tile_layout = TILE_LAYOUT_DIAMOND_DOWN
tile_size = Vector2i(64, 32)
```

No terrain auto-connect metadata.

- [ ] Switch `Ground`, `Water`, and `Paths` to the final tileset.
- [ ] `Ground`: keep all 480 cells; farm cells use `(3,0)`, other cells use grass/detail without altering farm identity.
- [ ] `Paths`: keep the Task-1 locked cells and use `(2,0)`.
- [ ] `Water`: author the river strip at `x=0..1,y=9..19` plus the south bend `x=2..8,y=18..19`; use bank edge variants on the visible transition.
- [ ] `GroundDecoration`: only flowers, foam, and path accents that cannot occlude the player.

### 2.3 GREEN — replace proof scenery while preserving direct roots

- [ ] Replace temporary scenery with final art for:

```text
House, ShopStall,
TreeClusterNorthwest, TreeClusterNorth, TreeClusterWest, TreeClusterNortheast,
RockNorth, RockRiver,
FenceHouseWest, FenceHouseEast, FenceFarmNorth, FenceFarmWest,
Workbench, VillageSign
```

- [ ] Keep every root direct under `Entities`; keep root positions at ground contact, optional `Shadow` child at the root, and visible sprite offset upward.
- [ ] `House` must visually cover `HOUSE_FOOTPRINT` while keeping its root at the derived `(976,336)` ground anchor.
- [ ] `ShopStall` sits north-west of `SHOP_CELL` and must not block the two-row main road; its collision remains `Rect2(15,7,1,2)` and root derives to `(1008,400)`.
- [ ] House-side fence/vegetation should visually explain the `HouseYardWestCollision`/`HouseYardEastCollision` blocks so the player only approaches the house from sensible front/back directions.
- [ ] Keep current shipping/market/villager assets unless the approved art pass explicitly replaces them; no asset registry.

### 2.4 Verify and commit

- [ ] Run worktree GUT + both smokes + GdUnit.
- [ ] Manually open the scene and verify the map reads as house / visible farm / river-forest / shop-market road / workbench / village exit before committing.
- [ ] Commit:

```bash
git add assets/sprites scenes/world/starting_farm_tileset.tres \
  scenes/world/world.tscn tests/headless/world_shell_smoke.gd
git commit -m "feat: author expanded starting farm environment"
./tools/verify-clean.sh
```

---

## Task 3: Expanded persistence, interactions, reachability, and E2E retarget

No new runtime system belongs here. This task proves that the larger authored shell preserves the existing game loop and removes every stale layout literal from the focused E2E route.

### Files

- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/e2e/gameplay_day_one_test.gd`
- Modify runtime scene/contract only if a test exposes a real authored-layout defect

### 3.1 Expanded farm + persistence

- [ ] Add a domain test using the last authored farm cell:

```gdscript
func test_expanded_farm_cell_outside_old_patch_supports_normal_actions() -> void:
    var session := GameSession.new()
    var cell := WorldContract.farm_cells()[-1]
    assert_false(Rect2i(2, 7, 3, 3).has_point(cell))
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
```

This proves individual legality/headroom; do not add a test that attempts to work all 30 cells in one day.

- [ ] Extend the existing production persistence flow with:

```gdscript
var expanded_cell := WorldContract.farm_cells()[-1]
```

Hoe/plant/water that cell, sleep/autosave through `WorldShell`, reopen/Continue, and assert the restored farm entry preserves its tilled/crop state.

### 3.2 Relocated interactions and shop visual

- [ ] Keep the existing interaction tests but target only the contract:

```gdscript
WorldContract.SHOP_CELL
WorldContract.SHIPPING_CELL
WorldContract.BED_CELL
WorldContract.MARKET_CELL
WorldContract.villager_cell(id)
```

- [ ] Add structural assertions that `Entities/ShopStall` and `StaticCollision/ShopStallCollision` exist and that the shop collision polygon equals `SHOP_STALL_FOOTPRINT`.
- [ ] Do not create a shop component or route; `WorldShell.interact()` stays unchanged.

### 3.3 Collision/reachability

- [ ] Replace old Tree/Building detour cases with:
  1. House south-edge collision + slide.
  2. Attempted west/east house-flank movement remains outside the yard-block footprints.
  3. River-west collision stop.
  4. Representative first-row and last-row farm cells can be targeted from reachable adjacent positions.

Use `WorldMath.grid_to_world()` for all placements. If a case fails, fix the authored footprint/path; do not add pathfinding or special movement code.

### 3.4 Retarget all layout-dependent Day-1 E2E stands

- [ ] Add beside `_stand()` in `gameplay_day_one_test.gd`:

```gdscript
func _stand_for_target(
    game,
    target: Vector2i,
    facing: WorldMath.Facing,
) -> void:
    var target_offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
    var grid := Vector2(target - target_offset) + Vector2(0.5, 0.5)
    await _stand(game, grid, facing)
```

- [ ] Replace the farm literal and node names with:

```gdscript
var farm_cell := WorldContract.farm_cells()[0]
await _stand_for_target(game, farm_cell, WorldMath.Facing.UP)
var soil_path := WORLD + "/FarmSoil/Soil_%d_%d" % [farm_cell.x, farm_cell.y]
var crop_path := WORLD + "/Entities/FarmCrop_%d_%d/Sprite2D" % [farm_cell.x, farm_cell.y]
```

- [ ] Replace the hard-coded bed stand:

```gdscript
await _stand_for_target(game, WorldContract.BED_CELL, WorldMath.Facing.UP)
```

- [ ] Replace the hard-coded shop stand:

```gdscript
await _stand_for_target(game, WorldContract.SHOP_CELL, WorldMath.Facing.RIGHT)
```

No coordinate fallback and no IPC-specific duplicate constants.

### 3.5 Verify and commit

- [ ] Run GUT + both smokes + GdUnit + e2e shell runner.
- [ ] Commit:

```bash
git add tests/unit/test_game_session.gd tests/integration/test_gameplay_shell.gd \
  tests/integration/test_persistence_flow.gd tests/headless/world_shell_smoke.gd \
  tests/e2e/gameplay_day_one_test.gd
git commit -m "test: prove expanded starting farm gameplay"
./tools/verify-clean.sh
```

---

## Task 4: Cleanup, handoff, regression gates, and real-world visual acceptance

The existing UI visual harness uses static plates for states 01–12, so this task does **not** re-bless those PNGs. Run the harness unchanged to prove the UI redesign did not regress, and inspect the actual game for map composition.

### Files

- Modify: `CLAUDE.md`
- Modify: `README.md` only if stale geometry exists
- Delete stale proof ground/scenery resources only after grep proves they are unreferenced

### 4.1 UI visual regression stays unchanged

- [ ] Run:

```bash
./tools/verify-visual.sh
```

Expected: all existing 14 states pass against their existing goldens. Do not rewrite 01–12 and do not change:

```gdscript
CHANNEL_TOLERANCE = 1
MISMATCH_RATIO_LIMIT = 0.0005
CONTRACT_CHANNEL_CEILING = 12
CONTRACT_MISMATCH_RATIO_CEILING = 0.002
```

This is UI regression evidence only; it is not live-world visual coverage.

### 4.2 Clean stale proof resources

- [ ] Run:

```bash
git grep -n "proof_ground_tileset\|proof-tiles.png\|proof-scenery.png\|PATH_ROW\|path_cells\|BUILDING_ANCHOR\|TREE_ANCHOR\|MARKET_ANCHOR"
```

- [ ] Delete `proof_ground_tileset.tres`, `proof-tiles.png`, and `proof-scenery.png` only when the grep shows no production/test reference. Keep proof player/crop/villager/soil/shadow resources while still used.

### 4.3 Update handoff docs

- [ ] Replace the old closed-shell geometry in `CLAUDE.md` with:

```text
map 24x20; tiles 64x32; origin (768,0); spawn (11.5,8.5)
farm Rect2i(4,10,6,5) / 30 cells, visual scale/headroom rather than balance target
camera constant Rect2(128,-96,1408,800), smoke-checked against WorldMath.map_camera_bounds()
Ground/Water/Paths/GroundDecoration are direct World children
WorldContract + WorldShell remain the single collision path
Entities remains the single Y-sort root; occluding props are direct children
House/ShopStall ground anchors derive from logical footprints
FarmSoil is authored empty and filled dynamically by FarmView
future village road has no transition behavior
UI visual harness uses static plates and does not validate the live world
```

Update README only if it contains stale `12x12`/`3x3` geometry.

### 4.4 Final automated gates

- [ ] Run the complete Verification Contract commands:
  - `./tools/verify-clean.sh`
  - GdUnit lane
  - godot-e2e lane
  - `godot --headless --path . --import`
  - unsigned `build/Phoenix.zip` export + executable check
  - unchanged `./tools/verify-visual.sh`

### 4.5 Real-game qualitative acceptance

- [ ] Run the real game/export, not `UiCaptureHost`, and verify:
  1. New Game starts outside the house.
  2. The starting viewport does not contain the whole `24x20` homestead.
  3. Walking from house/farm toward the east road visibly moves the existing smoothed camera.
  4. House sprite/root/collision align; the player cannot enter the ambiguous house flanks.
  5. The untouched farm visibly reads as a `6x5` farm before soil is tilled.
  6. River/forest, ShopStall/roadside cluster, workbench yard, and village road match the approved concept composition.
  7. Shipping, shop, villagers, bed, and Harvest Market are reachable.
  8. The east road reaches the authored boundary but has no transition behavior.
  9. There are no unintended holes/unpainted cells inside the authored world layers. Do not require the rectangular camera bound to eliminate every off-diamond corner; that is not the current camera model.

- [ ] Commit docs/cleanup on this same branch and update PR #14. Do not open another PR.

---

## Self-review

Before implementation, confirm all are still true:

- no `starting_farm_map.tscn` or other premature map abstraction;
- no nested scenery Y-sort group;
- no second collision path;
- House and ShopStall roots derive from footprint geometry rather than hand-maintained anchor constants;
- `CAMERA_BOUNDS` is smoke-checked against `map_camera_bounds()` and no duplicate camera-acceptance task exists;
- Paths do not overlap `FARM_PATCH`; workbench spur is connected at `x=12`;
- Ground keeps a farm-base tile derived from `FARM_PATCH`/`farm_cells()`;
- Shop has a visible `ShopStall` and collision;
- house flanks are blocked by authored yard collision rather than multi-root sorting machinery;
- 30 farm cells remain scale/headroom, not a balance retune;
- E2E derives farm, bed, and shop stands from `WorldContract`;
- old saves intentionally fail instead of migrating;
- direct worktree tests run before commits; `verify-clean.sh` runs after commits;
- GdUnit uses `./addons/gdUnit4/runtest.sh`;
- export target is `build/Phoenix.zip`;
- existing UI goldens remain untouched and `verify-visual.sh` is a regression check only.

If implementation appears to require a second owner for map, collision, Y-sort, camera, or interaction behavior, fix the authored scene/contract instead.