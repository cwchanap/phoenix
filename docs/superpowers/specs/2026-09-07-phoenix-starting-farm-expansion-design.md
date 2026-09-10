# Phoenix Starting Farm 2.5D Expansion Design

## Summary

Expand Phoenix's compact isometric proof-ground into one larger authored starting homestead without introducing a general map framework, a second collision owner, or a second Y-sort path.

The approved composition remains:

- a player house in the north-central area;
- a larger farm in the west/central area;
- river and forest boundaries on the west/north sides;
- a decorative workbench yard southeast of the farm;
- a visible roadside shop stall plus the existing villagers and Harvest Market along the main path;
- a road that reaches the east edge and clearly reserves a future connection to a separate village scene.

Phoenix remains technically 2D. "2.5D" means the existing 64x32 isometric projection, projected collision polygons, bottom-center sprite roots, one Y-sorted entity list, and a player-follow `Camera2D` moving across a larger world. It does not mean Godot `Node3D`.

## Goals

1. Replace the single-screen proof ground with a readable homestead that requires camera travel.
2. Increase the authored logical map from `12x12` to exactly `24x20` cells.
3. Expand the farm from `3x3` to exactly `6x5` / 30 farmable cells as visual scale and future headroom; the current loop is still balanced around roughly 8–10 actively worked crops/day and is not retuned to consume all 30 cells.
4. Make the existing player-owned `Camera2D` visibly follow the player across the larger map while remaining inside authored bounds.
5. Add a recognizable player house and move the existing sleep interaction to its doorstep.
6. Preserve the complete current 14-day loop: farming, shop, shipping, villagers, sleep, and Harvest Market finale remain reachable.
7. Reserve an obvious eastbound village road without adding a village scene or transition system.
8. Use the approved generated regular-cut source sheets already committed on this PR; implementation is an art-integration task, not another image-generation pass.
9. Keep implementation on one branch / one PR with the existing owners.

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
- new crops, villagers, economy rules, finale rules, or balance retuning;
- save migration or backward compatibility for old development saves;
- Godot 3D, `NavigationServer`, or a rendering-engine migration;
- additional image generation for this task.

## Current ownership to preserve

The current implementation already has the required owners:

- `WorldContract` is the fixed authored map/interaction/collision contract.
- `WorldMath` owns pure isometric projection and projected footprint math.
- `WorldShell` is the only live gameplay coordinator and fills named world collision polygons from `WorldContract`.
- `Entities` / `FarmView` is the one enabled Y-sort root.
- tall entities are direct `Entities` children with bottom-center roots, child shadows, and upward sprite offsets.
- `FarmView` already creates crop roots dynamically from `WorldContract.farm_cells()`.
- `GameSession` is the only mutable gameplay authority and validates persisted farm state against the exact authored farm-cell sequence.
- `PlayerController` owns the only `Camera2D` and copies `WorldContract.CAMERA_BOUNDS` into its limits.

The expansion extends these owners. It must not introduce alternate scene-authored collision logic or nested scenery ordering.

## Approved source art

Two generated regular-cut source sheets are committed directly on this PR and are the visual source of truth for the new homestead art:

### `assets/sprites/starting-farm-tiles-source.webp`

- transparent `384x192` sheet;
- regular `4x2` grid;
- each source cell is `96x96`;
- row 0: grass, grass detail, farm-base tile, dirt/path;
- row 1: water, river-bank A, river-bank B, river-bank C.

### `assets/sprites/starting-farm-props-source.webp`

- transparent `384x192` sheet;
- regular `4x2` grid;
- each source cell is `96x96`;
- row 0: house, shop stall, reusable tree cluster, reusable rock cluster;
- row 1: reusable fence, workbench, village sign, spare cell.

These are source-art sheets, not a change to Phoenix's runtime tile geometry. Runtime terrain still uses `WorldContract.TILE_SIZE = Vector2(64, 32)`. The implementation agent may crop or repack these cells into derived runtime textures/atlas regions where that makes Godot authoring simpler, but must not regenerate replacement art or invent unique variants for repeated trees/rocks/fences.

Keep the current player, crop, villager, shipping, Harvest Market, soil, and shadow art unless a concrete runtime need requires otherwise.

## Locked world contract

The implementation locks these values together in one contract change:

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
```

`WorldMath.footprint_ground_anchor()` derives large-prop ground anchors from footprints instead of maintaining hand-computed anchor constants. With the locked values it yields:

- House -> `Vector2(976, 336)`;
- ShopStall -> `Vector2(1008, 400)`.

`WorldMath.map_camera_bounds()` derives the map AABB from `MAP_SIZE`, `PROJECTION_ORIGIN`, and `CAMERA_TOP_PADDING`; smoke tests assert that it equals the frozen `CAMERA_BOUNDS` constant.

`TREE_*`, `BUILDING_*`, `PATH_ROW`, and `path_cells()` are retired as the new authored scene takes over their presentation role without creating a second gameplay contract.

## Collision ownership

There is exactly one collision-authoring path:

1. `WorldContract` owns fixed logical footprints.
2. `world.tscn` owns empty named `CollisionPolygon2D` children under `World/StaticCollision`.
3. `WorldShell._ready()` fills every polygon using `WorldMath.footprint_to_polygon()`.
4. `world_shell_smoke.gd` asserts the resulting polygons match the contract.

This applies equally to House, ShopStall, coarse forest/river/workbench blockers, small house-yard side blockers, shipping, market, villagers, and perimeter.

No collision lives in a second map scene or tile metadata.

## Scene ownership

Do not extract `starting_farm_map.tscn` in this slice. There is only one map today, so the extra PackedScene boundary is deferred until a second map makes it useful.

`world.tscn` keeps this direct shape:

```text
World / WorldShell
├── Ground                  # TileMapLayer
├── Water                   # TileMapLayer
├── Paths                   # TileMapLayer
├── GroundDecoration        # non-occluding decals only
├── FarmSoil                # empty authored Node2D, runtime-filled by FarmView
├── StaticCollision         # one collision owner, runtime-filled by WorldShell
├── Entities / FarmView     # only enabled Y-sort root
│   ├── Player
│   ├── House
│   ├── ShopStall
│   ├── reused tree/rock/fence instances
│   ├── Workbench
│   ├── VillageSign
│   ├── Shipping
│   ├── HarvestMarket
│   ├── Villagers
│   └── FarmCrop_*          # runtime-created direct children
├── TargetHighlight
└── GameHud
```

Every tall prop that may overlap the player is a **direct** `Entities` child. `GroundDecoration` is limited to decals that cannot participate in player occlusion.

## Map composition

Use this topology:

```text
        FOREST / ROCKS
             |
        [ PLAYER HOUSE ]
             |
 River   --- main path ----------------------> Future Village
   |         |                            |
   |     [ FARM 6x5 ]            [roadside market]
   |         |                 shop / NPCs / finale
   |     shipping
   |
   `-------- meadow ------ [workbench yard]
```

Path authorship is visual only. The farm-side path begins at `x=10` so it does not paint over farm column `x=9`, and the workbench spur reaches `x=12` so it connects to the main network.

Ground keeps a farm-base tile across all 30 `FARM_PATCH` cells even before dynamic tilled soil is visible. This keeps visual farm identity linked to the gameplay farm contract without resurrecting a path gameplay contract.

## House sorting boundary

A single large House root is kept because splitting one building into multiple Y-sort pieces is unnecessary for this map. Small authored west/east yard blockers prevent the player from walking into ambiguous flank positions; the intended house approach is from the south/doorstep.

## Farming presentation

`GameSession` continues deriving initialization and persisted-state validation from `WorldContract.farm_cells()`.

`FarmView` removes the hand-authored soil asymmetry:

- `FarmSoil` stays an empty non-Y-sorted `Node2D` with `z_index = 5`;
- `FarmView._ready()` creates one `Soil_x_y` sprite for every authored farm cell;
- it continues creating one direct `FarmCrop_x_y` root for every authored farm cell;
- soil/crop dictionaries stay keyed by `Vector2i`;
- `refresh(snapshot)` stays presentation-only;
- farm legality stays exclusively in `GameSession`.

The 30 cells are capacity/headroom, not a requirement that one day cycle can work all 30.

## Camera behavior

Reuse the existing player-owned `Camera2D` without a new controller.

Required behavior:

- `position_smoothing_enabled` stays true;
- existing smoothing speed remains unless actual playtesting exposes a readability defect;
- `PlayerController._ready()` copies all four `CAMERA_BOUNDS` edges;
- `world_math_smoke.gd` asserts the frozen bounds equal `WorldMath.map_camera_bounds()`;
- no camera state enters saves;
- no manual pan, zoom, edge scroll, or camera manager is added.

Do not add a tautological test that merely re-proves Godot clamps a camera after the four limits were copied. Existing smoke already pins those limits and smoothing.

Because the logical map is a projected diamond inside a rectangular camera AABB, the acceptance target is not literal zero blank canvas at every AABB corner. The expanded map must not expose materially worse blank canvas than the existing authored-camera behavior during intended traversal.

## Interaction relocation

Only authored cells/scene positions change.

- `BED_CELL` is the house doorstep.
- `SHIPPING_CELL` is beside the farm.
- `SHOP_CELL` stays on the roadside cluster, with `ShopStall` visually representing it just north of the road.
- `MARKET_CELL` is farther east along the village road.
- `VILLAGER_CELLS` are the three roadside positions.

`WorldShell.interact()` and the existing hint order remain unchanged.

## Persistence contract

Changing `farm_cells()` from 9 to 30 entries intentionally invalidates old development saves through existing exact-size/exact-order farm validation.

Required behavior:

- New Game creates exactly 30 farm entries in authored order;
- a save contains all 30 entries;
- Continue restores all 30 entries;
- acceptance mutates/restores at least one farm cell outside the old `3x3` footprint;
- old 9-cell saves may be rejected;
- New Game remains available;
- no schema bump, migration, remapping, or compatibility adapter is added.

## Testing contract

### Atomic contract oracles

The contract change updates these existing oracles in the same checkpoint:

- `tests/headless/world_math_smoke.gd` — map size, origin, spawn, derived camera equality, farm patch/count, house/shop/environment footprints, projected geometry, 24x20 edge cases;
- `tests/headless/world_shell_smoke.gd` — direct world-layer ownership, 480 ground cells, farm tile identity, direct entity order, collision, anchors, dynamic soil/crops;
- `tests/unit/test_game_session.gd` — farm test constants move to `WorldContract.FARM_PATCH.position` / `+ Vector2i.RIGHT`;
- `tests/unit/test_save_file.gd` — fixture derives its cell from `WorldContract.farm_cells()`;
- `tests/gdunit/test_world_math.gd` — expanded edge targeting.

### Reachability

Replace old Tree/Building detour checks with:

- House lower-edge collision + side slide;
- river-west collision stop;
- representative first/last-row farm targetability;
- interaction reachability at House sleep, Shipping, Shop, villagers, and Harvest Market.

### E2E

The existing Day-1 E2E hard-codes farm, bed, and shop stand positions. Retarget **all three** through `WorldContract` and `WorldMath.TARGET_OFFSETS`. Do not introduce literal fallbacks.

### Visual regression

The existing `tests/visual/ui_capture_host.gd` renders static PNG plates behind states 01–12 rather than `world.tscn`. Therefore this map change should **not** recapture those goldens. Run `./tools/verify-visual.sh` unchanged as a UI regression gate.

The real homestead visuals are accepted in the actual game/export against the approved concept and the committed source sheets.

## Verification commands

`./tools/verify-clean.sh` is a post-commit clean-tree gate because it archives committed `HEAD`.

Use direct worktree checks during RED/GREEN, then `verify-clean.sh` after checkpoints:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

Final gates:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
./tools/verify-visual.sh
```

## File-level design

### Already committed

- `assets/sprites/starting-farm-tiles-source.webp` — approved regular-cut terrain source art.
- `assets/sprites/starting-farm-props-source.webp` — approved regular-cut prop source art.

### Create only as integration output requires

- `scenes/world/starting_farm_tileset.tres` — runtime `64x32` atlas mapping.
- derived cropped/repacked runtime textures if using the source WebP sheets directly is less convenient in Godot.

### Modify

- `scripts/world/world_contract.gd`
- `scripts/world/world_math.gd`
- `scenes/world/world.tscn`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- relevant unit/integration/headless/GdUnit/E2E tests
- `CLAUDE.md`; README only if it contains stale geometry.

### Retire when unreferenced

- `scenes/world/proof_ground_tileset.tres`
- `assets/sprites/proof-tiles.png`
- `proof-scenery.png` if no longer used
- `PATH_ROW/path_cells()`
- old Tree/Building-specific contract constants.

Keep shared proof player/crop/villager/soil/shadow assets while still used.

## Acceptance criteria

The slice is complete when:

1. `WorldContract` exposes the locked `24x20`, `6x5`, origin, spawn, interaction, environment, and camera constants with no stale Tree/Building/path-row representation.
2. The two committed regular-cut source sheets are used for the new homestead terrain/props; no additional image generation is required.
3. New Game starts outside the authored player house.
4. The starting viewport does not show the entire homestead, and walking naturally pans the existing camera.
5. Direct `World` layers own Ground/Water/Paths/GroundDecoration; no premature map abstraction exists.
6. `WorldContract -> WorldShell` remains the sole collision path.
7. `Entities` remains the sole Y-sort root and every occluding prop is a direct child.
8. The map clearly reads as house + farm + river/forest + workbench yard + eastbound village road.
9. All 30 farm cells remain valid capacity for existing farming rules without retuning the loop around working all 30 simultaneously.
10. House sleep, shipping, visible shop stall/shop interaction, all villagers, and Harvest Market remain reachable and preserve behavior.
11. House/river/farm-edge reachability is covered by automated smoke/integration tests.
12. Save/Continue restores a changed farm cell outside the old `3x3` footprint.
13. Old 9-cell development saves may be rejected without migration.
14. The future-village road is visible but has no transition behavior.
15. GUT/headless, GdUnit4, godot-e2e, import, unsigned macOS ZIP export, and unchanged UI visual verification pass.

## Delivery rule

This remains one task / one PR. Implementation continues on `docs/starting-farm-2-5d-expansion` / PR #14 after plan approval; do not open another implementation PR.