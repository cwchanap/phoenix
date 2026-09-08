# Phoenix Starting Farm 2.5D Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Phoenix's compact single-screen proof ground with the approved `24x20` isometric homestead, including a `6x5` farm, player house, river/forest boundaries, workbench yard, eastbound future-village road, and smooth camera travel while preserving the current complete 14-day game loop.

**Architecture:** Keep the current owners: `GameSession` remains the only mutable gameplay authority, `WorldShell` remains the runtime coordinator, `PlayerController` keeps the one player-owned `Camera2D`, and `FarmView` remains presentation-only. Extract one fixed `starting_farm_map.tscn` for static environment composition; do not introduce a map framework, scene-transition service, navigation layer, or second camera system.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, 64x32 isometric `TileMapLayer`, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, existing Phoenix visual-regression harness, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`

## Global Constraints

- One task, one branch, one PR. Continue implementation on `docs/starting-farm-2-5d-expansion`; do not open a second implementation PR.
- Keep Phoenix technically 2D: no `Node3D`, 3D camera, 3D physics, or engine migration.
- `WorldContract.MAP_SIZE` becomes exactly `Vector2i(24, 20)`.
- `WorldContract.FARM_PATCH` becomes exactly `Rect2i(4, 10, 6, 5)` and therefore exposes exactly 30 authored farm cells.
- Keep `WorldContract.TILE_SIZE = Vector2(64.0, 32.0)` and the existing isometric projection functions.
- `GameSession` remains the only mutable gameplay authority; world/map/view code must not duplicate farm legality.
- Reuse the existing player-owned `Camera2D`; no manual pan, zoom, edge scroll, camera manager, or persisted camera state.
- The future village road is presentation-only. No village scene, scene transition, area ID, or map registry in this slice.
- Keep existing crop, stamina, time, shop, shipping, relationship, tutorial, finale, and UI rules unchanged.
- Old 9-cell development saves may become incompatible. Add no migration, schema adapter, or backward-compatibility layer.
- Keep one Y-sort authority for overlapping world entities/scenery.
- Workbench, river, forest, rocks, fences, and village-road sign are non-interactive scenery in this slice.
- Do not weaken visual-regression tolerances to accept the new map; replace approved gameplay-world goldens instead.

---

## File map

### Create

- `scenes/world/starting_farm_map.tscn` — fixed static environment composition and environmental collisions.
- `scenes/world/starting_farm_tileset.tres` — 64x32 isometric environment tile atlas.
- `assets/sprites/starting-farm-tiles.png` — grass/path/water/bank tile sheet.
- `assets/sprites/starting-farm-house.png` — player-house exterior.
- `assets/sprites/starting-farm-tree.png` — reusable tree prop.
- `assets/sprites/starting-farm-rock.png` — reusable rock prop.
- `assets/sprites/starting-farm-fence.png` — reusable fence prop.
- `assets/sprites/starting-farm-workbench.png` — decorative workbench-yard prop.
- `assets/sprites/starting-farm-sign.png` — future-village sign.

If the image-generation pass produces fewer packed PNGs, use those directly and adjust `.tres` regions; do not add an asset registry.

### Modify

- `scripts/world/world_contract.gd`
- `scripts/world/world_math.gd` only if a tiny camera/map-bounds helper is needed
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `scripts/player/player_controller.gd`
- `scenes/player/player.tscn`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/gdunit/test_world_math.gd`
- `tests/gdunit/test_game_session_flows.gd` only where the farm-size contract is asserted
- `tests/e2e/gameplay_day_one_test.gd`
- relevant `tests/headless/*` smoke assertions that enumerate old world children
- gameplay-world files under `tests/visual/goldens/`
- visual capture metadata/fixtures only where their starting world position must change
- `README.md` and `CLAUDE.md` only if they describe the old proof-ground map or 3x3 farm

### Retire after references are gone

- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- proof scenery assets only if production/tests no longer reference them
- `WorldContract.PATH_ROW` / `path_cells()` if path authorship is fully scene-owned

Do not delete `proof-player.png`, `proof-crops.png`, `proof-villagers.png`, or `proof-shadow.png` unless this PR actually replaces their production use.

---

## Task 1: Lock the expanded world contract and make tests describe the new map

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/gdunit/test_world_math.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces: `WorldContract.MAP_SIZE == Vector2i(24, 20)`
- Produces: `WorldContract.FARM_PATCH == Rect2i(4, 10, 6, 5)`
- Produces: `WorldContract.PLAYER_SPAWN == Vector2(11.5, 8.5)`
- Produces relocated `BED_CELL`, `SHIPPING_CELL`, `SHOP_CELL`, `MARKET_CELL`, `VILLAGER_CELLS`, and corresponding footprints.
- Reuses: `WorldContract.farm_cells()`, `WorldMath.grid_to_world()`, `WorldMath.world_to_grid()`, `WorldMath.target_cell()`.

### 1.1 RED — pin map size, farm geometry, and the new authored anchors

- [ ] Add/extend assertions in `tests/integration/test_gameplay_shell.gd`:

```gdscript
func test_starting_farm_contract_is_large_authored_homestead() -> void:
    assert_eq(WorldContract.MAP_SIZE, Vector2i(24, 20))
    assert_eq(WorldContract.FARM_PATCH, Rect2i(4, 10, 6, 5))
    assert_eq(WorldContract.farm_cells().size(), 30)
    assert_eq(WorldContract.PLAYER_SPAWN, Vector2(11.5, 8.5))
    assert_eq(WorldContract.BED_CELL, Vector2i(12, 7))
    assert_eq(WorldContract.SHIPPING_CELL, Vector2i(10, 13))
    assert_eq(WorldContract.SHOP_CELL, Vector2i(17, 9))
    assert_eq(WorldContract.MARKET_CELL, Vector2i(19, 10))
    assert_eq(
        WorldContract.VILLAGER_CELLS,
        [Vector2i(16, 8), Vector2i(18, 8), Vector2i(17, 11)],
    )
```

- [ ] Add a farm-state-size assertion beside existing `GameSession.new()` initialization tests in `tests/unit/test_game_session.gd`:

```gdscript
func test_new_session_uses_all_thirty_authored_farm_cells() -> void:
    var session := GameSession.new()
    var farm: Array = session.state()["farm"]
    assert_eq(farm.size(), 30)
    for index in farm.size():
        assert_eq(farm[index]["cell"], WorldContract.farm_cells()[index])
```

- [ ] Extend `tests/gdunit/test_world_math.gd` with new edge coverage:

```gdscript
func test_target_cell_uses_expanded_map_edges() -> void:
    assert_that(
        WorldMath.target_cell(Vector2(22.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_equal(Vector2i(23, 9))
    assert_that(
        WorldMath.target_cell(Vector2(23.5, 10.5), WorldMath.Facing.RIGHT)
    ).is_null()
```

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** failures report the old `12x12`, 9-cell farm, and old interaction positions.

### 1.2 GREEN — change only the authored contract

- [ ] Replace the old size/anchor constants in `scripts/world/world_contract.gd` with:

```gdscript
const MAP_SIZE := Vector2i(24, 20)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(11.5, 8.5)

const FARM_PATCH := Rect2i(4, 10, 6, 5)

const HOUSE_FOOTPRINT := Rect2(10.0, 4.0, 4.0, 3.0)
const BED_CELL := Vector2i(12, 7)
const SHIPPING_CELL := Vector2i(10, 13)
const SHOP_CELL := Vector2i(17, 9)
const MARKET_CELL := Vector2i(19, 10)

const VILLAGER_CELLS: Array[Vector2i] = [
    Vector2i(16, 8),
    Vector2i(18, 8),
    Vector2i(17, 11),
]
```

The new `PROJECTION_ORIGIN` keeps the wider diamond in positive screen-space near its north edge. Update interactable footprints to stay centered on their new cells using the existing `0.2..0.8` footprint convention, for example:

```gdscript
const SHIPPING_FOOTPRINT := Rect2(10.2, 13.2, 0.6, 0.6)
const MARKET_FOOTPRINT := Rect2(19.2, 10.2, 0.6, 0.6)
const VILLAGER_FOOTPRINTS: Array[Rect2] = [
    Rect2(16.2, 8.2, 0.6, 0.6),
    Rect2(18.2, 8.2, 0.6, 0.6),
    Rect2(17.2, 11.2, 0.6, 0.6),
]
```

- [ ] Keep `farm_cells()` exactly rectangular and row-major. Do not add plot IDs or region objects.

- [ ] Remove `PATH_ROW/path_cells()` only if repository search confirms no runtime/test caller remains after later map authoring. Until then, leave it compiling and move the deletion to Task 2.

- [ ] Run focused tests:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
godot --headless -s addons/gdUnit4/runtest.sh -a tests/gdunit/test_world_math.gd
```

**Expected:** new contract tests pass; scene/integration tests that encode the old geometry may still fail and are handled in later tasks.

### 1.3 Commit

- [ ] Commit the contract/test checkpoint:

```bash
git add scripts/world/world_contract.gd tests/unit/test_game_session.gd tests/gdunit/test_world_math.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: expand starting farm world contract"
```

---

## Task 2: Author the static starting-farm map without adding a map framework

**Files:**
- Create: `scenes/world/starting_farm_map.tscn`
- Create: `scenes/world/starting_farm_tileset.tres`
- Create: environment PNGs listed in the File map
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/world/world_contract.gd` if obsolete proof/path constants can now be removed
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: relevant `tests/headless/*`

**Interfaces:**
- Produces: one instantiated `$StartingFarmMap` under `World`.
- Produces: `$StartingFarmMap/StaticCollision` as the environmental static-body owner.
- Preserves: `$FarmSoil`, `$Entities`, `$TargetHighlight`, and `$GameHud` as runtime/presentation nodes owned by `world.tscn`.
- Reuses: `WorldMath.footprint_to_polygon()` for collision footprints.

### 2.1 RED — pin scene ownership before moving nodes

- [ ] Replace brittle proof-ground child-count assertions in `tests/integration/test_gameplay_shell.gd` with ownership assertions:

```gdscript
func test_world_owns_one_fixed_starting_farm_map() -> void:
    var world := _world()
    var map := world.get_node_or_null("StartingFarmMap") as Node2D
    assert_not_null(map)
    if map == null:
        return
    assert_not_null(map.get_node_or_null("Ground"))
    assert_not_null(map.get_node_or_null("StaticCollision"))
    assert_not_null(world.get_node_or_null("FarmSoil"))
    assert_not_null(world.get_node_or_null("Entities"))
```

- [ ] Add a Y-sort invariant that continues to allow only the existing entity ordering root. If static tall scenery needs Y ordering, put it under `Entities/EnvironmentScenery` rather than creating another enabled Y-sort root.

```gdscript
func test_entities_remains_the_single_y_sort_root() -> void:
    var world := _world()
    var enabled: Array[CanvasItem] = []
    if world.y_sort_enabled:
        enabled.append(world)
    for node in world.find_children("*", "CanvasItem", true, false):
        var item := node as CanvasItem
        if item != null and item.y_sort_enabled:
            enabled.append(item)
    assert_eq(enabled, [world.get_node("Entities")])
```

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** the new map-node assertion fails because `StartingFarmMap` does not exist.

### 2.2 GREEN — create the fixed environment assets and tileset

- [ ] Generate/author `assets/sprites/starting-farm-tiles.png` at the existing `64x32` tile size with at least these atlas cells:

```text
(0,0) grass
(1,0) grass detail
(2,0) dirt/path
(3,0) dark-ground accent
(0,1) water
(1,1) north-west river bank
(2,1) north-east river bank
(3,1) south bank / authored edge
```

Do not add terrain auto-connect rules unless direct TileMap authoring proves unworkable.

- [ ] Create `scenes/world/starting_farm_tileset.tres` using those atlas coordinates and:

```text
tile_shape = 1
tile_layout = 5
tile_size = Vector2i(64, 32)
```

- [ ] Generate/author the scenery PNGs from the approved composition. Keep transparent backgrounds and feet/ground contact near the local sprite origin so Y-sort placement is predictable.

### 2.3 GREEN — build `starting_farm_map.tscn`

- [ ] Create this fixed hierarchy:

```text
StartingFarmMap (Node2D)
├── Ground (TileMapLayer)
├── Water (TileMapLayer)
├── Paths (TileMapLayer)
├── GroundDecoration (Node2D)
└── StaticCollision (StaticBody2D)
    ├── HouseCollision (CollisionPolygon2D)
    ├── ForestCollision (CollisionPolygon2D or a few fixed polygons)
    ├── RiverCollision (CollisionPolygon2D)
    ├── WorkbenchCollision (CollisionPolygon2D)
    ├── PerimeterTop
    ├── PerimeterRight
    ├── PerimeterBottom
    └── PerimeterLeft
```

- [ ] Paint the `24x20` logical diamond with grass and the approved authored path/river composition. Keep the future-village road visually open to the east edge but retain collision/perimeter before the player exits the map.

- [ ] Place non-overlapping ground decoration under `GroundDecoration`.

- [ ] Put tall sprites that need player occlusion under a new `Entities/EnvironmentScenery` **without enabling Y-sort on that child**; it inherits ordering from `Entities`. Suggested direct children:

```text
House
Tree_01 ... Tree_N
Rock_01 ... Rock_N
Fence_01 ... Fence_N
Workbench
VillageRoadSign
```

Each child root's `position.y` is its ground-contact sort point; the visible sprite uses a negative Y offset if needed.

### 2.4 GREEN — compose the map into `world.tscn`

- [ ] Replace the old direct `Ground` and proof static scenery with:

```gdscript
[ext_resource type="PackedScene" path="res://scenes/world/starting_farm_map.tscn" id="starting_map"]

[node name="StartingFarmMap" parent="." instance=ExtResource("starting_map")]
```

- [ ] Keep `FarmSoil`, `Entities`, `TargetHighlight`, and `GameHud` in `world.tscn`.

- [ ] Move existing gameplay props (Shipping, HarvestMarket, villagers) to their new `WorldContract` anchors. Keep their current gameplay sprites if the environment-art pass does not replace them.

### 2.5 GREEN — point collision setup at the extracted map

- [ ] In `WorldShell._ready()`, replace:

```gdscript
var static_collision := get_node("StaticCollision") as StaticBody2D
```

with:

```gdscript
var static_collision := get_node(
    "StartingFarmMap/StaticCollision"
) as StaticBody2D
```

- [ ] Set house collision from `WorldContract.HOUSE_FOOTPRINT` and keep existing shipping/market/villager projected polygons. Build the four perimeter polygons through the existing `perimeter_footprints()` helper.

- [ ] If forest/river/workbench polygons are authored directly in the scene, do not duplicate them in `WorldContract`.

### 2.6 Verify and commit

- [ ] Run:

```bash
godot --headless --path . --import
./tools/verify-clean.sh
```

**Expected:** import succeeds; GUT/headless scene smokes pass with `StartingFarmMap` present and only `Entities` Y-sorted.

- [ ] Commit:

```bash
git add assets/sprites scenes/world scripts/world/world_shell.gd scripts/world/world_contract.gd tests/integration tests/headless
git commit -m "feat: author expanded starting farm map"
```

---

## Task 3: Make the 30-cell farm presentation dynamic and preserve save semantics

**Files:**
- Modify: `scripts/world/farm_view.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/integration/test_persistence_flow.gd`
- Modify: `tests/gdunit/test_game_session_flows.gd` only if it pins old farm size

**Interfaces:**
- Produces: one runtime soil sprite and one runtime crop root per `WorldContract.farm_cells()` entry.
- Preserves: `FarmView.refresh(snapshot: Dictionary) -> void`.
- Preserves: `GameSession.state()` / `restore_state()` schema shape; only the authored `farm` array length/cells change.

### 3.1 RED — replace nine-node assumptions with the 30-cell invariant

- [ ] Replace `test_nine_soil_sprites_use_farm_cell_centers()` with:

```gdscript
func test_soil_sprites_are_created_for_every_authored_farm_cell() -> void:
    var world := _world()
    var farm_soil := world.get_node("FarmSoil") as Node2D
    var cells := WorldContract.farm_cells()
    assert_eq(cells.size(), 30)
    assert_eq(farm_soil.get_child_count(), cells.size())

    for cell in cells:
        var soil := farm_soil.get_node_or_null(
            "Soil_%d_%d" % [cell.x, cell.y]
        ) as Sprite2D
        assert_not_null(soil)
        if soil == null:
            continue
        assert_true(
            soil.position.distance_to(_cell_center(cell)) <= 0.0001,
            "soil %s center" % cell,
        )
        assert_eq(soil.hframes, 2)
```

- [ ] Replace crop child-index assumptions with name-based lookup:

```gdscript
func test_crop_roots_exist_for_every_authored_farm_cell() -> void:
    var world := _world()
    var entities := world.get_node("Entities") as Node2D
    for cell in WorldContract.farm_cells():
        var root := entities.get_node_or_null(
            "FarmCrop_%d_%d" % [cell.x, cell.y]
        ) as Node2D
        assert_not_null(root)
        if root != null:
            assert_true(root.position.distance_to(_cell_center(cell)) <= 0.0001)
```

- [ ] Add persistence coverage in `tests/integration/test_persistence_flow.gd` that mutates an expanded-cell entry, saves, restores, and verifies the exact cell survives. Use a late patch cell so the test cannot accidentally pass against the old 3x3 set:

```gdscript
var expanded_cell := Vector2i(9, 14)
assert_true(WorldContract.farm_cells().has(expanded_cell))
```

Use the existing command-driven save/Continue helper style; do not mutate serialized JSON directly except where existing persistence tests already do so for validation.

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** soil assertions fail because soil is still manually authored for the old set.

### 3.2 GREEN — create soil and crop presentation from one cell source

- [ ] In `scripts/world/farm_view.gd`, preload the existing soil texture:

```gdscript
const SOIL_TEXTURE: Texture2D = preload("res://assets/sprites/proof-soil.png")
```

- [ ] Replace the lookup-only soil setup in `_ready()` with creation from `WorldContract.farm_cells()`:

```gdscript
func _ready() -> void:
    _farm_soil = get_node("../FarmSoil") as Node2D
    for cell in WorldContract.farm_cells():
        var center := WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

        var soil := Sprite2D.new()
        soil.name = "Soil_%d_%d" % [cell.x, cell.y]
        soil.position = center
        soil.texture = SOIL_TEXTURE
        soil.hframes = 2
        soil.visible = false
        _farm_soil.add_child(soil)
        _soil_sprites[cell] = soil

        var crop_root := Node2D.new()
        crop_root.name = _crop_name(cell)
        crop_root.position = center

        var crop_shadow := Sprite2D.new()
        crop_shadow.name = "Shadow"
        crop_shadow.texture = SHADOW_TEXTURE
        crop_shadow.visible = false
        crop_root.add_child(crop_shadow)

        var crop_sprite := Sprite2D.new()
        crop_sprite.name = "Sprite2D"
        crop_sprite.texture = CROP_TEXTURE
        crop_sprite.hframes = 4
        crop_sprite.vframes = 3
        crop_sprite.offset = Vector2(0, -24)
        crop_sprite.visible = false
        crop_root.add_child(crop_sprite)
        add_child(crop_root)

        _crop_sprites[cell] = crop_sprite
        _crop_shadows[cell] = crop_shadow
```

- [ ] Remove all manually authored `Soil_*` child nodes from `scenes/world/world.tscn`. Keep only:

```text
FarmSoil (Node2D)
  y_sort_enabled = false
  z_index = 5
```

- [ ] Do **not** change `FarmView.refresh()`, farming action guards, crop growth, or farm save schema beyond what is forced by the new authored cell list.

### 3.3 GREEN — prove the intentional old-save break rather than migrating it

- [ ] Keep `GameSession._farm_state_error()` strict: candidate farm length must equal `WorldContract.farm_cells().size()` and cells must match authored order.

- [ ] Add a unit test using a valid new state with its farm truncated to 9 entries:

```gdscript
func test_old_nine_cell_farm_state_is_incompatible() -> void:
    var candidate := GameSession.new().state()
    candidate["farm"] = (candidate["farm"] as Array).slice(0, 9)
    assert_eq(
        GameSession.state_error(candidate),
        "farm must contain exactly the authored farm cells",
    )
```

- [ ] Do not bump `SaveFileCodec` schema solely for this map change.

### 3.4 Verify and commit

- [ ] Run:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
godot --headless -s addons/gdUnit4/runtest.sh -a tests/gdunit
```

**Expected:** farm size/presentation/persistence tests pass; old 9-cell candidate is rejected.

- [ ] Commit:

```bash
git add scripts/world/farm_view.gd scenes/world/world.tscn tests/unit/test_game_session.gd tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd tests/gdunit
git commit -m "feat: expand farm presentation to thirty cells"
```

---

## Task 4: Relocate interactions and make the existing camera pan cleanly across the homestead

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/gdunit/test_world_math.gd`

**Interfaces:**
- Preserves: `PlayerController.current_target_cell() -> Variant`.
- Preserves: `WorldShell.interact()` and its villager/shop/shipping/bed/market chain.
- Produces: camera limits wide enough for the authored homestead and clamped so traversal never exposes empty world.
- Reuses: one `$Entities/Player/Camera2D` with position smoothing.

### 4.1 RED — pin interaction reachability after relocation

- [ ] Keep the existing `test_interaction_targets_open_only_their_modal()` table-driven test but let it consume the relocated `WorldContract` cells. Add house/market assertions if they are not already covered by neighboring tests.

- [ ] Add a single contract test ensuring all interactive cells are in-bounds and not farm cells:

```gdscript
func test_relocated_interaction_cells_are_inside_map_and_outside_farm() -> void:
    var cells: Array[Vector2i] = [
        WorldContract.BED_CELL,
        WorldContract.SHIPPING_CELL,
        WorldContract.SHOP_CELL,
        WorldContract.MARKET_CELL,
    ]
    cells.append_array(WorldContract.VILLAGER_CELLS)

    for cell in cells:
        assert_true(cell.x >= 0 and cell.x < WorldContract.MAP_SIZE.x)
        assert_true(cell.y >= 0 and cell.y < WorldContract.MAP_SIZE.y)
        assert_false(WorldContract.farm_cells().has(cell))
```

### 4.2 RED — pin camera follow/clamp behavior without a new camera abstraction

- [ ] Add one integration test that samples the actual camera limits and moves the player between representative positions:

```gdscript
func test_player_camera_is_smoothed_and_clamped_to_starting_farm() -> void:
    var world := _world()
    var player := world.get_node("Entities/Player") as PlayerController
    var camera := player.get_node("Camera2D") as Camera2D

    assert_true(camera.position_smoothing_enabled)
    assert_true(camera.position_smoothing_speed > 0.0)
    assert_true(camera.limit_right > camera.limit_left)
    assert_true(camera.limit_bottom > camera.limit_top)

    var start_camera := camera.get_screen_center_position()
    player.global_position = WorldMath.grid_to_world(Vector2(21.5, 10.5))
    await get_tree().process_frame
    await get_tree().process_frame
    assert_true(
        camera.get_screen_center_position().distance_to(start_camera) > 1.0,
        "camera pans when player crosses the larger map",
    )
```

The test proves the current camera moves; do not turn it into a timing/smoothing-curve assertion.

### 4.3 GREEN — keep the existing follow camera and tune only authored limits

- [ ] Keep this existing scene shape in `scenes/player/player.tscn`:

```text
Player
└── Camera2D
    position_smoothing_enabled = true
    position_smoothing_speed = 5.0
```

- [ ] Do not add a `CameraController` script.

- [ ] Set `WorldContract.CAMERA_BOUNDS` to one authored `Rect2` that covers the playable route while keeping the viewport over environment art at supported window sizes. Start from the projected `24x20` footprint and trim the extreme diamond corners rather than allowing reachable centers that show empty canvas.

- [ ] In `PlayerController._ready()`, keep the existing four assignments:

```gdscript
var bounds := WorldContract.CAMERA_BOUNDS
camera.limit_left = int(bounds.position.x)
camera.limit_top = int(bounds.position.y)
camera.limit_right = int(bounds.position.x + bounds.size.x)
camera.limit_bottom = int(bounds.position.y + bounds.size.y)
```

If visual inspection shows smoothing crosses the edge, enable Godot's built-in `limit_smoothed`; do not write custom clamp interpolation.

### 4.4 GREEN — relocate gameplay props without changing interaction logic

- [ ] Update `world.tscn` prop positions from `WorldContract` coordinates or matching authored anchors so:

```text
house doorstep -> BED_CELL (12,7)
shipping -> SHIPPING_CELL (10,13)
shop -> SHOP_CELL (17,9)
market -> MARKET_CELL (19,10)
villagers -> (16,8), (18,8), (17,11)
```

- [ ] Keep `WorldShell._process()` and `WorldShell.interact()` structurally unchanged. The existing lookup order remains villager -> shop -> shipping -> bed -> market -> empty.

- [ ] Confirm the future-village sign/road has **no** branch in `WorldShell.interact()`.

### 4.5 Verify and commit

- [ ] Run:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
godot --headless -s addons/gdUnit4/runtest.sh -a tests/gdunit/test_world_math.gd
```

- [ ] Launch the game once and manually walk this route in one run:

```text
House spawn -> farm west edge -> shipping -> house -> all three villagers -> shop -> Harvest Market -> future-village road sign
```

Pass criteria: continuous movement, camera visibly travels, no unreachable interaction, no walk through house/river/forest collision, and no empty-world exposure at reachable extremes.

- [ ] Commit:

```bash
git add scripts/world scripts/player scenes/world scenes/player tests/integration/test_gameplay_shell.gd tests/gdunit/test_world_math.gd
git commit -m "feat: pan camera across expanded homestead"
```

---

## Task 5: Update E2E/visual evidence and close the single PR

**Files:**
- Modify: `tests/e2e/gameplay_day_one_test.gd`
- Modify: relevant `tests/headless/*`
- Modify: relevant visual capture fixtures/scripts
- Replace: gameplay-world PNGs under `tests/visual/goldens/`
- Modify: `README.md` / `CLAUDE.md` only if current map-size/proof-ground statements are stale

**Interfaces:**
- Preserves: existing godot-e2e workflow and visual-regression harness.
- Produces: approved production captures for the expanded starting map.
- Adds no new testing framework.

### 5.1 Update deterministic E2E targets

- [ ] In `tests/e2e/gameplay_day_one_test.gd`, replace stale literal farm coordinates with the current contract-driven target already exposed by game/test helpers where possible. The route must still prove a Day-1 farming action and should not add long movement sleeps solely to cross the larger map.

When an exact cell is required, use:

```gdscript
var farm_cell := WorldContract.farm_cells()[0]
```

rather than a hard-coded old `Vector2i(2, 7)`.

- [ ] If the E2E process cannot directly import `WorldContract`, keep one explicit new coordinate matching the first authored farm cell (`Vector2i(4, 10)`) and cover contract drift in GUT/GdUnit instead of adding test-only IPC.

### 5.2 Recapture only visual states whose world background changed

- [ ] Run the existing visual capture workflow against the implementation branch.

- [ ] Replace every golden whose rendered production state includes the gameplay world. At minimum review these existing states individually:

```text
01-hud.png
02-seed-shop.png
03-shipping-day14.png
04-bag.png
05-almanac.png
06-calendar.png
07-dialogue.png
08-morning-summary.png
09-sleep.png
10-pause.png
11-settings.png
12-intro.png
```

- [ ] Leave title/result-only goldens unchanged if their production render contains no world background.

- [ ] Compare each replacement against the approved Phoenix UI reference to ensure the map change did not alter HUD/modal layout. Approve the new background composition separately: visible house/farm identity at the start, no overlapping props through panels, no off-map void.

- [ ] Do not change renderer tolerance constants merely because every world pixel changed. Golden replacement is the intended mechanism.

### 5.3 Full verification

- [ ] Run the repository's complete clean gate:

```bash
./tools/verify-clean.sh
```

**Expected:** GUT + headless smokes pass.

- [ ] Run GdUnit4:

```bash
./tools/bootstrap-gdunit.sh
godot --headless -s addons/gdUnit4/runtest.sh -a tests/gdunit
```

**Expected:** all suites pass.

- [ ] Run godot-e2e through the repository workflow command used by `.github/workflows/e2e-tests.yml` or trigger the branch CI and require it green.

- [ ] Run the existing visual regression command:

```bash
./tools/verify-visual.sh
```

**Expected:** all approved goldens pass with existing tolerance policy.

- [ ] Re-import and build the existing unsigned macOS release artifact to catch missing environment resources:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "macOS" /tmp/Phoenix-StartingFarm.app
```

**Expected:** import and export exit 0; no missing texture/scene dependency errors.

### 5.4 Final scope audit

- [ ] Verify repository search finds no production implementation of:

```text
MapDefinition
MapRegistry
AreaManager
SceneTransition
CameraManager
NavigationAgent
NavigationRegion
village scene transition
```

A matching historical design-doc mention is fine; no new runtime abstraction should exist.

- [ ] Verify `GameSession.state()` has no `area`, `map`, `camera`, `player_position`, or compatibility/migration field added by this PR.

- [ ] Verify the future-village sign/road is visual only.

### 5.5 Commit and PR handoff

- [ ] Commit closeout evidence:

```bash
git add tests README.md CLAUDE.md
git commit -m "test: verify expanded starting farm experience"
```

- [ ] Keep implementation on this same draft PR. Mark it ready only after all CI lanes and visual approval are green.

---

## Acceptance walkthrough

Perform this walkthrough against the final branch in a normal game window:

1. Start New Game and acknowledge the intro.
2. Confirm spawn is immediately outside the player house.
3. Confirm the initial viewport cannot show the whole `24x20` map.
4. Walk to the farm and confirm camera motion is smooth and automatic.
5. Hoe, plant, and water at least one cell in the 6x5 patch.
6. Walk around the farm boundary and confirm all 30 authored cells remain targetable from valid adjacent positions.
7. Walk to shipping and open/close the shipping panel.
8. Walk back to the house and open/cancel sleep.
9. Visit all three villagers and confirm interaction hints/dialogue still work.
10. Open/close the shop.
11. Reach the Harvest Market interaction.
12. Walk to the eastbound future-village road sign; confirm there is no scene transition and the player cannot leave the authored map.
13. Walk toward river/forest extremes and confirm collision prevents leaving the map and camera does not expose empty world.
14. Complete a successful sleep/save, relaunch, Continue, and verify the expanded farm state restores.

Passing this walkthrough plus all automated/visual gates completes the slice.