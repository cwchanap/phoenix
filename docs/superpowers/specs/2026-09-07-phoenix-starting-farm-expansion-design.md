# Phoenix Starting Farm 2.5D Expansion Design

## Summary

Expand Phoenix's compact isometric proof-ground into one larger authored starting homestead while keeping the current runtime ownership intact.

The approved product composition remains:

- a player house in the north-central area;
- a larger farm in the west/central area;
- river and forest boundaries on the west/north sides;
- a decorative workbench yard southeast of the farm;
- the current shop, villagers, shipping, and Harvest Market relocated into believable places along the main path;
- a road that reaches the east edge and clearly reserves a future connection to a separate village scene.

Phoenix remains technically 2D. "2.5D" means the existing `64x32` isometric projection, projected collision polygons, bottom-center sprite roots, one Y-sorted entity list, and a player-follow `Camera2D` moving across a larger world. It does not mean Godot `Node3D`.

This revision deliberately removes the previously proposed `starting_farm_map.tscn`. There is still only one world map, so `Ground`, `Water`, `Paths`, and `GroundDecoration` remain direct `World` children. Extracting those layers into a PackedScene can wait until a second map actually exists.

## Goals

1. Replace the single-screen proof ground with a readable homestead that requires camera travel.
2. Increase the authored logical map from `12x12` to exactly `24x20` cells.
3. Expand the farm from `3x3` to exactly `6x5` / 30 farmable cells without retuning crop/time/stamina rules.
4. Treat those 30 cells as visual scale and future headroom, not as a requirement that the current 14-day loop work all 30 simultaneously; the current stamina budget naturally uses only a subset on a normal day.
5. Make the existing player-owned `Camera2D` visibly follow the player across the larger map while remaining on the existing authored rectangular camera-bound model.
6. Add a recognizable player house and move the existing sleep interaction to its doorstep.
7. Keep a visible shop presence after the bed leaves the old generic building by adding one simple roadside `ShopStall`.
8. Preserve the complete current 14-day loop: farming, shop, shipping, villagers, sleep, and Harvest Market finale remain reachable.
9. Reserve an obvious eastbound village road without adding a village scene or transition system.
10. Keep implementation on one branch / one PR with the existing owners.

## Non-goals

This slice does **not** add:

- a separate village scene;
- scene transitions, area IDs, map definitions, or a map registry;
- a reusable map PackedScene before a second map exists;
- house interiors;
- fishing, foraging, crafting, or workbench gameplay;
- NPC schedules, navigation meshes, or pathfinding;
- manual camera pan, edge scroll, zoom, or persisted camera state;
- a minimap;
- procedural generation, chunk streaming, or map-loading infrastructure;
- a generic obstacle/entity/world-object framework;
- new crops, villagers, shops, economy rules, finale rules, or balance retuning;
- save migration or backward compatibility for old development saves;
- Godot 3D, `NavigationServer`, or a rendering-engine migration.

## Current ownership to preserve

The current implementation already has the required owners:

- `WorldContract` is the fixed authored map/interaction/collision contract.
- `WorldMath` owns pure isometric projection and projected footprint math.
- `WorldShell` is the only live gameplay coordinator and currently fills every named world collision polygon from `WorldContract`.
- `Entities` / `FarmView` is the one enabled Y-sort root.
- tall entities are direct `Entities` children with ground-contact roots, child shadows, and upward sprite offsets;
- `FarmView` already creates crop roots dynamically from `WorldContract.farm_cells()`;
- `GameSession` is the only mutable gameplay authority and validates persisted farm state against the exact authored farm-cell sequence;
- `PlayerController` owns the only `Camera2D` and copies `WorldContract.CAMERA_BOUNDS` into its limits.

The expansion extends these owners. It must not introduce alternate scene-authored collision logic, nested scenery ordering, a camera manager, or a second map abstraction.

## Locked world contract

The first implementation lands these values together in one atomic contract change:

```gdscript
const MAP_SIZE := Vector2i(24, 20)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(11.5, 8.5)
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
```

`CAMERA_BOUNDS` is the projected `24x20` map AABB (`x=128..1536`, `y=0..704`) plus the existing 96-pixel top-art allowance. It lands with `MAP_SIZE`/origin/spawn rather than being deferred camera tuning.

Do **not** add hand-maintained `HOUSE_ANCHOR`, `SHOP_STALL_ANCHOR`, or `MARKET_ANCHOR` constants. Scene roots are checked from geometry instead:

- `House.position` must equal `WorldMath.footprint_ground_anchor(HOUSE_FOOTPRINT)`, which is `(976, 336)` for the locked footprint.
- `ShopStall.position` must equal `WorldMath.footprint_ground_anchor(SHOP_STALL_FOOTPRINT)`, which is `(1008, 400)`.
- `HarvestMarket.position` remains the projected center of `MARKET_CELL`.

`TREE_FOOTPRINT`, `TREE_ANCHOR`, `BUILDING_FOOTPRINT`, `BUILDING_ANCHOR`, and `MARKET_ANCHOR` are retired in the same cutover.

`PATH_ROW` / `path_cells()` are also retired. Paths are presentation-only and will live directly in the authored `Paths` tile layer; they have no production gameplay caller.

### Small derived geometry helpers

Add only two pure helpers to the existing `WorldMath`; neither creates a new owner:

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

`footprint_ground_anchor()` prevents large sprites from drifting away from their collision footprint. `map_camera_bounds()` is an oracle for the frozen `CAMERA_BOUNDS` constant; `world_math_smoke.gd` asserts the two match so future map-size changes cannot silently leave stale camera geometry.

## Closed environment collision contract

Environmental collision stays in `WorldContract` and is populated by `WorldShell`, exactly like current world collision.

Use this closed list for non-interactive blocking:

```gdscript
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

The two house-yard side blocks keep the 4x3 house on a simple single Y-sort root: the player can approach the door from the south or pass behind it, but cannot walk through the visually ambiguous east/west flank where one large root would sort incorrectly.

`HouseCollision` and `ShopStallCollision` are explicit named children populated from `HOUSE_FOOTPRINT` and `SHOP_STALL_FOOTPRINT`. Shipping, market, villagers, and four perimeter bands continue on the existing collision path.

These footprints are intentionally coarse. Individual tree/rock/fence sprites do not each need their own physics shape when the authored cluster already blocks that region.

## Map composition

Use this authored topology:

```text
        FOREST / ROCKS
             |
        [ PLAYER HOUSE ]
             |
 River   --- main path ----------------------> Future Village
   |         |                            |
   |     [ FARM 6x5 ]            [shop / roadside market]
   |         |                  NPCs / finale
   |     shipping
   |
   `-------- meadow ------ [workbench yard]
```

### Locked path cells

`Paths` is presentation-only but its initial authored geometry is locked to avoid painting over the farm or disconnecting the workbench spur:

```text
house approach:      x=11..12, y=7..10
main east road:      x=10..23, y=9..10
farm-side path:      x=10..12, y=10..14
workbench spur:      x=12..16, y=13..15
```

The farm is `x=4..9, y=10..14`, so the path begins at `x=10` and never overlays a farm cell. The workbench spur shares `x=12` with the farm-side path and is therefore connected.

### Area intent

**North / northwest — forest boundary**

Tree-cluster and rock sprites create a dense visual boundary over the closed forest footprints. No foraging interaction is exposed.

**North-central — player house**

`House` replaces the current generic `Building` direct entity. The existing sleep action targets `BED_CELL` at the doorstep. West/east yard fencing/vegetation closes the problematic side approaches; there is no interior scene.

**West / central — farm**

`FARM_PATCH = Rect2i(4, 10, 6, 5)` yields 30 row-major cells through the unchanged `farm_cells()` helper. The patch is deliberately larger than the current stamina loop can work in one day. It is visual scale and future headroom, not a balance target.

**West / south boundary — river**

Water tiles and bank decals provide the landmark; river cluster footprints prevent walking into it. No fishing hook is added.

**Southeast — workbench yard**

One direct Y-sorted `Workbench` visual plus the closed workbench footprint reserves future crafting space. It is non-interactive.

**East-central — roadside social/market cluster**

`ShopStall` gives `SHOP_CELL` an actual visual location without occupying the main road. The existing villagers and Harvest Market remain in this scene and move along the future-village road. Their command/hint semantics do not change.

**East edge — future village road**

The path reaches the visual edge with a `VillageSign`. The perimeter still blocks leaving the map. No transition trigger is added.

## Scene ownership

Keep all world layers directly under `World`; no new map PackedScene exists in this slice:

```text
World / WorldShell
├── Ground                      # TileMapLayer, exactly 480 cells
├── Water                       # TileMapLayer
├── Paths                       # TileMapLayer
├── GroundDecoration            # non-occluding decals only
├── FarmSoil                    # empty authored Node2D; FarmView fills it
├── StaticCollision             # one collision owner, filled by WorldShell
│   ├── HouseCollision
│   ├── ShopStallCollision
│   ├── ForestNorthwestCollision
│   ├── ForestNortheastCollision
│   ├── ForestWestCollision
│   ├── HouseYardWestCollision
│   ├── HouseYardEastCollision
│   ├── RiverWestCollision
│   ├── RiverSouthCollision
│   ├── WorkbenchCollision
│   ├── ShippingCollision
│   ├── HarvestMarketCollision
│   ├── Villager...Collision
│   └── Perimeter...
├── Entities / FarmView         # the only enabled Y-sort root
│   ├── Player
│   ├── House
│   ├── ShopStall
│   ├── TreeClusterNorthwest
│   ├── TreeClusterNorth
│   ├── TreeClusterWest
│   ├── TreeClusterNortheast
│   ├── RockNorth
│   ├── RockRiver
│   ├── FenceHouseWest
│   ├── FenceHouseEast
│   ├── FenceFarmNorth
│   ├── FenceFarmWest
│   ├── Workbench
│   ├── VillageSign
│   ├── Shipping
│   ├── HarvestMarket
│   ├── VillagerShopkeeper
│   ├── VillagerFarmer
│   ├── VillagerResident
│   └── FarmCrop_*              # runtime-created direct children
├── TargetHighlight
└── GameHud
```

`Ground`, `Water`, and `Paths` all use the existing `64x32` isometric geometry and the same transform. With `PROJECTION_ORIGIN = (768, 0)`, their authored layer position is:

```gdscript
position = Vector2(736.0, 0.0)
```

The existing alignment invariant remains:

```gdscript
layer.to_global(layer.map_to_local(cell)) \
    == WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

`Entities` remains the only enabled Y-sort node. Every tall prop that can occlude the player is a direct child with a ground-contact root. `GroundDecoration` is only for decals that can never occlude the player, such as flowers, path accents, and water foam.

## Environment art

Replace the three-frame proof ground with a small starting-farm environment tileset using `64x32` atlas cells.

Minimum tile vocabulary:

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

`Ground` paints the `farm-field base` on every `WorldContract.farm_cells()` cell even before soil is tilled. This preserves the current automated tile-to-farm geometry link and gives the untouched 6x5 farm a visible identity while dynamic soil sprites remain hidden.

`Paths` overlays only the locked path cells above and must not contain any `FARM_PATCH` cell.

Do not add terrain auto-connect rules unless direct authoring is demonstrably harder. One fixed map should remain simple.

Tall scenery may use individual PNGs or a compact scenery atlas. Runtime code must not gain an asset registry either way.

All tall art follows the existing contract:

- direct entity root at ground contact;
- shadow child on the ground plane where useful;
- visible sprite offset upward from the root;
- same shared z-index as the player and other Y-sorted world entities.

## Farming presentation

`GameSession` continues deriving initialization and persisted-state validation from `WorldContract.farm_cells()`.

`FarmView` removes the remaining hand-authored soil asymmetry:

- `FarmSoil` stays an empty non-Y-sorted `Node2D` with `z_index = 5`;
- `FarmView._ready()` creates one `Soil_x_y` sprite for every authored farm cell;
- `FarmView._ready()` continues creating one direct `FarmCrop_x_y` root for every authored farm cell;
- soil and crop dictionaries remain keyed by `Vector2i`;
- `refresh(snapshot)` remains presentation-only;
- farm legality remains exclusively in `GameSession`.

No plot IDs, farm-region object, second view model, or 30 authored soil nodes are added.

## Collision ownership

There is exactly one collision-authoring path:

1. `WorldContract` owns fixed logical footprints.
2. `world.tscn` owns empty named `CollisionPolygon2D` children under `World/StaticCollision`.
3. `WorldShell._ready()` fills every polygon using `WorldMath.footprint_to_polygon()`.
4. `world_shell_smoke.gd` asserts the resulting polygons match the contract.

This applies equally to house, shop stall, forest, house-yard flanks, river, workbench, shipping, market, villagers, and perimeter.

## Camera behavior

Reuse the current player-owned camera without a new controller.

Required behavior:

- `position_smoothing_enabled` stays true;
- `position_smoothing_speed` keeps its existing value unless playtesting finds a concrete readability defect;
- `PlayerController._ready()` keeps copying all four edges of `WorldContract.CAMERA_BOUNDS` to the camera;
- `world_shell_smoke.gd` keeps its existing camera-limit and smoothing assertions;
- `world_math_smoke.gd` additionally asserts `CAMERA_BOUNDS == WorldMath.map_camera_bounds()`;
- no camera state enters save data;
- no manual pan, zoom, edge scroll, or camera manager is added.

Do not add a second test that teleports the player only to prove Godot clamps a camera to the four limits it was just assigned. The contract invariant is the map-derived bounds equality.

The camera bound remains a rectangle around an isometric diamond, as it is today. The acceptance target is correct authored bounds and continuous follow, not a literal guarantee that viewport corners can never show off-diamond background.

## Interaction relocation

Only authored cells/scene positions change.

- `BED_CELL` is the house doorstep.
- `SHIPPING_CELL` is beside the farm.
- `SHOP_CELL` is beside `ShopStall` in the roadside cluster.
- `MARKET_CELL` is farther east along the village road.
- `VILLAGER_CELLS` are the three roadside positions.

`WorldShell.interact()` and the existing hint order remain unchanged.

## Persistence contract

Changing `farm_cells()` from 9 to 30 entries intentionally invalidates old development saves through the existing `_farm_state_error()` exact-size/exact-order validation.

Required behavior:

- `GameSession.new()` creates exactly 30 farm entries in authored order;
- a save contains all 30 entries;
- Continue restores all 30 entries;
- acceptance mutates and restores at least one farm cell outside the old `3x3` footprint;
- old 9-cell saves are rejected normally;
- New Game remains available;
- no schema bump, migration, remapping, or compatibility adapter is added.

## Testing contract

### Atomic contract oracles

The first checkpoint updates the real existing oracles together with `WorldContract`:

- `tests/headless/world_math_smoke.gd`: `24x20`, origin, spawn, farm patch/count, `CAMERA_BOUNDS == map_camera_bounds()`, derived house/shop anchors, projected geometry, and new edge cases;
- `tests/headless/world_shell_smoke.gd`: direct `Ground/Water/Paths/GroundDecoration` ownership, 480 Ground cells, farm-base tile identity, direct entity inventory, collisions, camera limits/smoothing, and large-prop ordering assumptions;
- `tests/unit/test_game_session.gd`: replace stale farm literals with compile-time expressions from `WorldContract.FARM_PATCH`;
- `tests/unit/test_save_file.gd`: replace stale farm literal with `WorldContract.farm_cells()[0]`;
- `tests/gdunit/test_world_math.gd`: new edge-target and helper coverage.

The Ground smoke keeps a contract-derived farm tile expectation. Retiring `PATH_ROW` does not retire the automated relationship between farm legality and visible farm-base tiles.

### Scene / traversal oracles

Headless smoke and integration tests pin:

- 480 aligned Ground cells;
- all 30 farm cells use the farm-base tile;
- Paths do not overlap the farm and include the connected house/main-road/farm/workbench/village-edge route;
- exact direct `Entities` scenery inventory and one Y-sort owner;
- exact WorldShell-generated collision polygons;
- derived House/ShopStall ground anchors;
- house lower-edge collision plus blocked flank approach;
- river detour and representative farm-edge reachability;
- 30 dynamic soil and crop roots.

### GdUnit / E2E

Use `WorldContract` directly in tests. Do not duplicate `(4, 10)`, bed coordinates, or shop coordinates as fallbacks.

The Day-1 E2E suite adds one small target-position helper:

```gdscript
func _stand_for_target(game, target: Vector2i, facing: WorldMath.Facing) -> void:
    var offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
    await _stand(game, Vector2(target - offset) + Vector2(0.5, 0.5), facing)
```

Use it for all three layout-dependent stands in that file:

- `WorldContract.farm_cells()[0]` with `Facing.UP`;
- `WorldContract.BED_CELL` with `Facing.UP`;
- `WorldContract.SHOP_CELL` with `Facing.RIGHT`.

### Visual

The existing UI visual harness does **not** instantiate `world.tscn` for states `01` through `12`; it composites static plate PNGs behind the HUD. Therefore this map expansion should not recapture/re-approve those goldens.

Run `./tools/verify-visual.sh` unchanged as a regression check and expect all 14 existing states to remain green. This proves the UI contract was not disturbed; it is not evidence for the live map.

Live-world visual acceptance is manual in the real game/export: compare the actual starting view and traversal composition against the approved homestead concept. Do not add a new visual-regression capture state solely for this slice.

## Verification commands

`./tools/verify-clean.sh` is a **post-commit** clean-tree gate because it archives committed `HEAD`. It is not an uncommitted RED runner.

Use direct worktree commands while iterating, then `verify-clean.sh` after each review checkpoint commit.

Focused headless worktree checks:

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

Final import/export uses the existing unsigned ZIP contract:

```bash
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Native UI regression remains:

```bash
./tools/verify-visual.sh
```

## File-level design

### Create

- `scenes/world/starting_farm_tileset.tres` — fixed 64x32 atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — grass/path/farm/water/bank atlas.
- scenery PNGs or one compact scenery atlas for House, ShopStall, closed tree/rock/fence/workbench/sign inventory.

### Modify

- `scripts/world/world_contract.gd` — complete new map/farm/interaction/environment/camera contract.
- `scripts/world/world_math.gd` — only `footprint_ground_anchor()` and `map_camera_bounds()`.
- `scenes/world/world.tscn` — keep tile layers direct; add Water/Paths/GroundDecoration; empty FarmSoil; direct occluding scenery; named collision children; House + ShopStall.
- `scripts/world/world_shell.gd` — continue filling every collision polygon from `WorldContract`.
- `scripts/world/farm_view.gd` — create soil plus crop presentation dynamically.
- `scripts/player/player_controller.gd` — no planned change; existing camera-copy path remains.
- `tests/headless/world_math_smoke.gd`.
- `tests/headless/world_shell_smoke.gd`.
- `tests/unit/test_game_session.gd`.
- `tests/unit/test_save_file.gd`.
- `tests/integration/test_gameplay_shell.gd`.
- `tests/integration/test_persistence_flow.gd`.
- `tests/gdunit/test_world_math.gd`.
- `tests/gdunit/test_game_session_flows.gd` only if farm-size assumptions exist.
- `tests/e2e/gameplay_day_one_test.gd`.
- `CLAUDE.md` — replace old `12x12`/`3x3` shell geometry and document direct world layers.
- `README.md` only if stale geometry exists.

### Retire after references are removed

- `scenes/world/proof_ground_tileset.tres`.
- `assets/sprites/proof-tiles.png`.
- `PATH_ROW` / `path_cells()`.
- old Tree/Building/Market anchor constants.
- old proof scenery texture only if no production/test reference remains.

Do not delete proof player/crop/villager/soil/shadow assets unless this PR actually replaces their production use.

## Acceptance criteria

The slice is complete when:

1. `WorldContract` exposes the locked `24x20`, `6x5`, origin, spawn, interaction, environment, and camera constants with no stale Tree/Building/path-row contract.
2. `WorldMath.footprint_ground_anchor(HOUSE_FOOTPRINT)` resolves to the House root and `CAMERA_BOUNDS == WorldMath.map_camera_bounds()`.
3. New Game starts outside the authored player house.
4. The starting viewport cannot show the entire homestead, and normal player movement visibly moves the existing smoothed camera.
5. `Ground`, `Water`, `Paths`, and `GroundDecoration` remain direct `World` children; no map PackedScene/framework is added.
6. `Entities` remains the only enabled Y-sort root and every occluding prop is a direct child.
7. The map clearly reads as house + visible 6x5 farm + river/forest + workbench yard + roadside shop + eastbound village road.
8. Every one of the 30 farm cells is individually legal for the existing farming rules; the PR does not promise or retune for 30 simultaneously worked crops.
9. House sleep, shipping, ShopStall/shop, all villagers, and Harvest Market remain reachable and behave exactly as before.
10. House/yard/river/farm-edge collision and reachability are covered by automated smoke/integration checks.
11. Save/Continue restores a changed farm cell outside the old `3x3` footprint.
12. Old 9-cell development saves may be rejected without migration.
13. The future-village road is visible but has no transition behavior.
14. GUT/headless, GdUnit4, godot-e2e, import, unsigned macOS ZIP export, and unchanged native UI visual verification pass.
15. Actual gameplay is qualitatively checked against the approved map concept; existing UI goldens are not re-blessed as fake world coverage.

## Delivery rule

This remains one task / one PR. Review happens at task-level commits on `docs/starting-farm-2-5d-expansion`; implementation continues on the same draft PR after plan approval.