# Phoenix Starting Farm 2.5D Expansion Design

## Summary

Expand Phoenix's compact isometric proof-ground into one larger authored starting homestead without introducing a general map framework, a second collision owner, or a second Y-sort path.

The approved composition remains:

- a player house in the north-central area;
- a larger farm in the west/central area;
- river and forest boundaries on the west/north sides;
- a decorative workbench yard southeast of the farm;
- the current shop, villagers, shipping, and Harvest Market relocated into believable places along the main path;
- a road that reaches the east edge and clearly reserves a future connection to a separate village scene.

Phoenix remains technically 2D. "2.5D" means the existing 64x32 isometric projection, projected collision polygons, bottom-center sprite roots, one Y-sorted entity list, and a player-follow `Camera2D` moving across a larger world. It does not mean Godot `Node3D`.

## Goals

1. Replace the single-screen proof ground with a readable homestead that requires camera travel.
2. Increase the authored logical map from `12x12` to exactly `24x20` cells.
3. Expand the farm from `3x3` to exactly `6x5` / 30 farmable cells while preserving the current crop/time/stamina balance.
4. Make the existing player-owned `Camera2D` visibly follow the player across the larger map while remaining inside authored bounds.
5. Add a recognizable player house and move the existing sleep interaction to its doorstep.
6. Preserve the complete current 14-day loop: farming, shop, shipping, villagers, sleep, and Harvest Market finale remain reachable.
7. Reserve an obvious eastbound village road without adding a village scene or transition system.
8. Keep implementation on one branch / one PR with the existing owners.

## Non-goals

This slice does **not** add:

- a separate village scene;
- scene transitions, area IDs, map definitions, or a map registry;
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
- tall entities are direct `Entities` children with bottom-center roots, child shadows, and upward sprite offsets;
- `FarmView` already creates crop roots dynamically from `WorldContract.farm_cells()`;
- `GameSession` is the only mutable gameplay authority and validates persisted farm state against the exact authored farm-cell sequence;
- `PlayerController` owns the only `Camera2D` and copies `WorldContract.CAMERA_BOUNDS` into its limits.

The expansion extends these owners. It must not introduce alternate scene-authored collision logic or nested scenery ordering.

## Locked world contract

The first implementation locks these values together in one contract change:

```gdscript
const MAP_SIZE := Vector2i(24, 20)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(11.5, 8.5)
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
```

`CAMERA_BOUNDS` is the projected `24x20` map AABB (`x=128..1536`, `y=0..704`) plus the existing 96-pixel top art allowance. It is part of the Task-1 contract rather than deferred camera tuning, so the new spawn/origin cannot temporarily disagree with the old `768`-pixel-wide camera bounds.

`TREE_FOOTPRINT`, `TREE_ANCHOR`, `BUILDING_FOOTPRINT`, and `BUILDING_ANCHOR` are retired in the same change. `House` replaces the generic `Building` visual/collision role.

`PATH_ROW` / `path_cells()` are retired when the tilemap becomes the path author. They have no production gameplay owner and should not survive as a second path representation.

### Closed environment collision contract

Environmental collision stays in `WorldContract` and is populated by `WorldShell`, exactly like current world collision. The map scene does **not** author collision polygons.

Use this small closed list for non-interactive environment blocking:

```gdscript
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

These are intentionally coarse cluster footprints. Individual tree/rock/fence sprites do not each need their own physics shape when the authored forest/river cluster already blocks that region.

Perimeter bands remain derived by `WorldShell.perimeter_footprints()` from `MAP_SIZE`.

## Map composition

Use this authored topology:

```text
        FOREST / ROCKS
             |
        [ PLAYER HOUSE ]
             |
 River   --- main path ----------------------> Future Village
   |         |                            |
   |     [ FARM 6x5 ]            [roadside market]
   |         |                  NPCs / shop / finale
   |     shipping
   |
   `-------- meadow ------ [workbench yard]
```

### Area intent

**North / northwest — forest boundary**

Tree-cluster and rock sprites create a dense visual boundary over the closed forest footprints. No foraging interaction is exposed.

**North-central — player house**

`House` replaces the current generic `Building` direct entity. The existing sleep action targets `BED_CELL` at the doorstep. There is no interior scene.

**West / central — farm**

`FARM_PATCH = Rect2i(4, 10, 6, 5)` yields 30 row-major cells through the unchanged `farm_cells()` helper. Extra cells are capacity only; no stamina/time/economy retune belongs in this PR.

**West / south boundary — river**

Water tiles and bank decals provide the landmark; the two river cluster footprints prevent walking into it. No fishing hook is added.

**Southeast — workbench yard**

One direct Y-sorted `Workbench` visual plus the closed workbench footprint reserves future crafting space. It is non-interactive.

**East-central — roadside social/market cluster**

The existing shop cell, villagers, and Harvest Market remain in this scene and move along the future-village road. Their command/hint semantics do not change.

**East edge — future village road**

The path reaches the visual edge with a `VillageSign`. The perimeter still blocks leaving the map. No transition trigger is added.

## Scene ownership

### `starting_farm_map.tscn`

The new PackedScene is **tiles and ground decals only**:

```text
StartingFarmMap (Node2D)
├── Ground             # TileMapLayer
├── Water              # TileMapLayer
├── Paths              # TileMapLayer
└── GroundDecoration   # non-occluding decals only
```

It is scriptless, typeless, and has no area ID. It does not own gameplay props, collision, farm state, or tall scenery.

All three tile layers use the existing `64x32` isometric geometry and the same alignment. With `PROJECTION_ORIGIN = (768, 0)`, their authored layer transform is:

```gdscript
position = Vector2(736.0, 0.0)
```

The smoke invariant remains:

```gdscript
layer.to_global(layer.map_to_local(cell)) \
    == WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

`Ground` contains exactly `24 * 20 = 480` logical cells. `Water` and `Paths` contain only their authored subsets.

### `world.tscn`

`World` keeps the runtime/presentation owners:

```text
World / WorldShell
├── StartingFarmMap
├── FarmSoil                    # empty authored Node2D; FarmView fills it
├── StaticCollision             # one collision owner, filled by WorldShell
│   ├── HouseCollision
│   ├── ForestNorthwestCollision
│   ├── ForestNortheastCollision
│   ├── ForestWestCollision
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
│   ├── TreeClusterNorthwest
│   ├── TreeClusterNorth
│   ├── TreeClusterWest
│   ├── TreeClusterNortheast
│   ├── RockNorth
│   ├── RockRiver
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

This is a closed scenery inventory for this slice. Do not add `Entities/EnvironmentScenery` or any nested Y-sort group. Godot Y-sort compares direct children of the enabled node; every tall prop that can occlude the player therefore remains a direct `Entities` child with a bottom-center ground-contact root.

`GroundDecoration` is only for decals that can never overlap/occlude the player, such as flowers, path accents, water foam, or painted ground detail.

## Environment art

Replace the three-frame proof ground with a small starting-farm environment tileset using `64x32` atlas cells.

Minimum tile vocabulary:

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

Do not add terrain auto-connect rules unless direct authoring is demonstrably harder. One fixed authored map should remain simple.

Tall scenery may use individual PNGs or a compact scenery atlas. Runtime code must not gain an asset registry either way.

All tall art follows the existing contract:

- direct entity root at ground contact;
- shadow child on the ground plane where useful;
- visible sprite offset upward from the root;
- same shared z-index as the player and other Y-sorted world entities.

## Farming presentation

`GameSession` continues deriving both initialization and persisted-state validation from `WorldContract.farm_cells()`.

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

`starting_farm_map.tscn` owns no `StaticBody2D` or `CollisionPolygon2D`.

This applies equally to house, forest, river, workbench, shipping, market, villagers, and perimeter.

## Camera behavior

Reuse the current player-owned camera without a new controller.

Required behavior:

- `position_smoothing_enabled` stays true;
- `position_smoothing_speed` keeps its existing value unless playtesting finds a concrete readability defect;
- `PlayerController._ready()` copies all four edges of `WorldContract.CAMERA_BOUNDS` to the camera;
- normal traversal never reveals canvas outside those limits;
- no camera state enters save data;
- no manual pan, zoom, edge scroll, or camera manager is added.

Camera verification is contract-based rather than timing-based:

- assert the camera's four limits equal `CAMERA_BOUNDS`;
- place the player at representative west/east/north/south reachable extremes;
- reset camera smoothing for the assertion and verify the screen center/viewport remains inside the authored bounds;
- keep one broad movement-follow check if useful, but do not specify "moves after two frames" as behavior.

## Interaction relocation

Only authored cells/scene positions change.

- `BED_CELL` is the house doorstep.
- `SHIPPING_CELL` is beside the farm.
- `SHOP_CELL` is in the roadside cluster.
- `MARKET_CELL` is farther east along the village road.
- `VILLAGER_CELLS` are the three roadside positions.

`WorldShell.interact()` and the existing hint order remain unchanged.

## Persistence contract

Changing `farm_cells()` from 9 to 30 entries intentionally invalidates old development saves through the existing `_farm_state_error()` exact-size/exact-order validation.

Required behavior:

- `GameSession.new()` creates exactly 30 farm entries in authored order;
- a save contains all 30 entries;
- Continue restores all 30 entries;
- acceptance must mutate and restore at least one farm cell outside the old `3x3` footprint so the test proves expanded persistence rather than merely reusing an old cell;
- old 9-cell saves are rejected normally;
- New Game remains available;
- no schema bump, migration, remapping, or compatibility adapter is added.

## Testing contract

### Task-1 contract oracles

The contract change must update the real existing oracles in the same checkpoint:

- `tests/headless/world_math_smoke.gd`: map size, origin, spawn, camera bounds, farm patch/count, environment/house constants, projected diamonds/footprints, and new 24x20 edge cases;
- `tests/headless/world_shell_smoke.gd`: scene names/anchors/collision expectations affected by removing Tree/Building and expanding the map;
- `tests/unit/test_game_session.gd`: replace top-level `Vector2i(2, 7)` / `(3, 7)` farm literals with `WorldContract.farm_cells()[0]` / `[1]`, including helper defaults;
- `tests/unit/test_save_file.gd`: replace the stale `Vector2i(2, 7)` fixture with `WorldContract.farm_cells()[0]`;
- `tests/gdunit/test_world_math.gd`: new edge target coverage.

Do not leave those updates to a late cleanup task; once `WorldContract` changes, these files are part of the same contract.

### Scene / traversal oracles

`world_shell_smoke.gd` and integration tests then pin:

- `StartingFarmMap/Ground`, `/Water`, `/Paths`, `/GroundDecoration` ownership;
- 480 `Ground` cells;
- layer-to-`WorldMath` center alignment;
- exact direct `Entities` scenery inventory and one Y-sort owner;
- exact WorldShell-generated collision polygons;
- House/river detour and representative farm-edge reachability;
- 30 dynamic soil and crop roots.

### GdUnit / E2E

Use `WorldContract` directly in tests. Do not duplicate `(4, 10)` or other layout literals as an IPC fallback.

The Day-1 E2E route retargets through `WorldContract.farm_cells()[0]` plus a stand position derived from `WorldMath.TARGET_OFFSETS`.

### Visual

The larger gameplay world changes production captures for states `01` through `12`; recapture and approve those states. `13-title` and `14-result-heart-of-harvest` remain unchanged because they do not render the live world.

Do not change `CHANNEL_TOLERANCE`, `MISMATCH_RATIO_LIMIT`, or the contract ceilings to absorb the new map.

## Verification commands

`./tools/verify-clean.sh` is a **post-commit** clean-tree gate because it archives committed `HEAD`. It is not an uncommitted RED runner.

Use direct worktree commands while iterating, then `verify-clean.sh` after each review checkpoint commit.

Focused headless worktree checks:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

GdUnit/e2e use the repository's shell runner:

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

Native visual acceptance remains:

```bash
./tools/verify-visual.sh
```

## File-level design

### Create

- `scenes/world/starting_farm_map.tscn` — scriptless Ground/Water/Paths/GroundDecoration PackedScene.
- `scenes/world/starting_farm_tileset.tres` — fixed 64x32 atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — grass/path/water/bank atlas.
- scenery PNGs or one compact scenery atlas for the closed direct-entity inventory.

### Modify

- `scripts/world/world_contract.gd` — the complete new contract, environment footprints, and camera AABB.
- `scenes/world/world.tscn` — instance StartingFarmMap; keep `StaticCollision`; keep empty `FarmSoil`; flatten all occluding scenery as direct `Entities` children; replace `Building` with `House`.
- `scripts/world/world_shell.gd` — continue filling every collision polygon from `WorldContract`; no map-scene collision path.
- `scripts/world/farm_view.gd` — create soil plus crop presentation dynamically.
- `scripts/player/player_controller.gd` — continue copying the authored camera bounds; no new camera abstraction.
- `tests/headless/world_math_smoke.gd`.
- `tests/headless/world_shell_smoke.gd`.
- `tests/unit/test_game_session.gd`.
- `tests/unit/test_save_file.gd`.
- `tests/integration/test_gameplay_shell.gd`.
- `tests/integration/test_persistence_flow.gd`.
- `tests/gdunit/test_world_math.gd`.
- `tests/gdunit/test_game_session_flows.gd` only where farm-size assumptions exist.
- `tests/e2e/gameplay_day_one_test.gd`.
- gameplay-world visual goldens `01` through `12`.
- `CLAUDE.md` — replace the old closed-shell `12x12`/`3x3` contract and document the new map-scene boundary.
- `README.md` only if repository text references the old proof-ground geometry.

### Retire after references are removed

- `scenes/world/proof_ground_tileset.tres`.
- `assets/sprites/proof-tiles.png`.
- `PATH_ROW` / `path_cells()`.
- old Tree/Building-specific footprint/anchor constants.
- old proof scenery texture only if no production/test reference remains.

Do not delete proof player/crop/villager/shadow assets unless this PR actually replaces their production use.

## Acceptance criteria

The slice is complete when:

1. `WorldContract` exposes the locked `24x20`, `6x5`, origin, spawn, interaction, environment, and camera constants with no stale Tree/Building/path-row contract.
2. New Game starts outside the authored player house.
3. The starting viewport cannot show the entire homestead.
4. Walking naturally pans the existing camera across the map.
5. Camera limits keep the visible viewport inside `CAMERA_BOUNDS` at reachable extremes.
6. `starting_farm_map.tscn` owns only tiles/ground decals; all collision still comes from `WorldContract -> WorldShell`.
7. `Entities` remains the only enabled Y-sort root and every occluding prop is a direct child.
8. The map clearly reads as house + farm + river/forest + workbench yard + eastbound village road.
9. All 30 farm cells support the existing hoe/plant/water/harvest rules without a balance retune.
10. House sleep, shipping, shop, all villagers, and Harvest Market remain reachable and behave exactly as before.
11. House/river/farm-edge collision detours are covered by automated smoke/integration checks.
12. Save/Continue restores a changed farm cell outside the old `3x3` footprint.
13. Old 9-cell development saves may be rejected without migration.
14. The future-village road is visible but has no transition behavior.
15. GUT/headless, GdUnit4, godot-e2e, import, unsigned macOS ZIP export, and native visual verification pass.
16. Visual states `01` through `12` are re-approved; states `13` and `14` are unchanged unless a real dependency proves otherwise.

## Delivery rule

This remains one task / one PR. Review happens at task-level commits on `docs/starting-farm-2-5d-expansion`; implementation continues on the same draft PR after plan approval.