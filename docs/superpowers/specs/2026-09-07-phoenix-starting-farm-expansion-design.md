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

## Architecture and ownership

The existing owners stay in place:

- `WorldContract` owns fixed map, interaction, and collision geometry.
- `WorldMath` owns isometric projection and the two small derived helpers `footprint_ground_anchor()` and `map_camera_bounds()`.
- `WorldShell` remains the only live coordinator and the only code that fills world collision polygons.
- `Entities` / `FarmView` remains the sole enabled Y-sort root; every occluding prop is a direct child.
- `FarmView` creates both soil and crop presentation from `WorldContract.farm_cells()`.
- `GameSession` remains the only mutable gameplay authority.
- `PlayerController` retains the one player-owned `Camera2D`.
- `Ground`, `Water`, `Paths`, and `GroundDecoration` remain direct `World` children; do not extract a map scene until a second map exists.

## Locked world contract

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
    Vector2i(18, 7),
    Vector2i(17, 11),
]
```

`WorldMath.footprint_ground_anchor()` derives large-prop ground anchors. It yields House `(976,336)` and ShopStall `(1008,400)` with the locked footprints. `WorldMath.map_camera_bounds()` derives the map AABB and must equal the frozen `CAMERA_BOUNDS` in smoke coverage.

The House node displays its `96x96` prop frame at `2.5x` so the drawn yard ellipse (~`220x115` px) covers the locked `4x3` footprint's `224x112` projected diamond; the world-shell smoke pins that display scale.

`TREE_*`, `BUILDING_*`, `PATH_ROW`, and `path_cells()` are retired rather than kept as stale parallel representations.

## Scene and collision shape

```text
World / WorldShell
├── Ground
├── Water
├── Paths
├── GroundDecoration
├── FarmSoil
├── StaticCollision
├── Entities / FarmView
│   ├── Player
│   ├── House
│   ├── ShopStall
│   ├── reused tree / rock / fence instances
│   ├── Workbench
│   ├── VillageSign
│   ├── Shipping
│   ├── HarvestMarket
│   ├── Villagers
│   └── FarmCrop_*
├── TargetHighlight
└── GameHud
```

Collision has one path only: `WorldContract` footprints -> empty named polygons in `world.tscn` -> `WorldShell._ready()` -> `WorldMath.footprint_to_polygon()`. This includes House, ShopStall, coarse forest/river/workbench blockers, small house-yard flank blockers, interactables, villagers, and perimeter.

Tall props remain direct `Entities` children. Small house-yard blockers make the intended House approach from the south, avoiding ambiguous Y-sort behavior from its flanks without splitting the House into multiple roots.

## Map composition

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

The farm-side path begins at `x=10`, outside the farm's final `x=9` column. The workbench spur reaches `x=12` so it joins the main path. Ground paints a farm-base tile over all 30 `FARM_PATCH` cells even before dynamic tilled soil is visible.

## Farming and persistence

`GameSession` continues deriving initialization and persisted-state validation from `WorldContract.farm_cells()`. `FarmView` creates soil and crop presentation from that same list. No plot IDs or second farm representation are introduced.

The 30 cells are scale/headroom, not a requirement to work all 30 in one day.

Changing the authored farm from 9 to 30 entries intentionally makes old development saves incompatible through existing exact-size/exact-order farm validation. No schema bump or migration is added. Acceptance must mutate and restore at least one cell outside the old 3x3 footprint.

## Camera

Reuse the current `Camera2D`. Existing smoke already verifies limits and smoothing; add only the meaningful invariant that frozen `CAMERA_BOUNDS` equals `WorldMath.map_camera_bounds()`. Do not add a second clamp implementation or timing-sensitive camera test.

Because a projected diamond is contained by a rectangular camera AABB, the acceptance target is not literal zero blank canvas at every corner. Intended traversal should not expose materially worse blank canvas than the current authored-camera behavior.

## Testing and visual verification

The atomic cutover updates the real existing oracles together: `world_math_smoke.gd`, `world_shell_smoke.gd`, `test_game_session.gd`, `test_save_file.gd`, `test_gameplay_shell.gd`, and focused GdUnit edge cases.

Reachability coverage replaces the old Tree/Building checks with House, river-west, and farm-edge cases. Day-1 E2E derives **farm, bed, and shop** stand positions from `WorldContract` + `WorldMath.TARGET_OFFSETS`; no literal fallback is allowed.

The current visual harness uses static PNG plates for UI states 01–12 rather than instantiating `world.tscn`. Do not recapture those goldens for this map work. Run `./tools/verify-visual.sh` unchanged as a UI regression check; visually accept the real homestead in the actual game/export against the approved concept and these committed source sheets.

## Acceptance criteria

The slice is complete when:

1. The `24x20` / `6x5` world contract lands atomically with its existing test oracles.
2. The two committed regular-cut source sheets are used for the new terrain/props; no additional image generation is required.
3. New Game starts outside the House and camera travel is visible across the larger homestead.
4. Ground/Water/Paths/GroundDecoration stay direct World layers; no premature map framework is added.
5. `WorldContract -> WorldShell` remains the single collision path.
6. `Entities` remains the single Y-sort root and all occluding props are direct children.
7. The map clearly reads as house + farm + river/forest + workbench yard + eastbound village road.
8. All 30 farm cells remain legal farming capacity without retuning the loop around using all 30 simultaneously.
9. House sleep, shipping, visible ShopStall/shop interaction, villagers, and Harvest Market remain reachable.
10. Save/Continue restores a changed cell outside the old 3x3 footprint; old 9-cell development saves may be rejected without migration.
11. The future-village road has no transition behavior.
12. GUT/headless, GdUnit4, godot-e2e, import, unsigned `build/Phoenix.zip`, and unchanged UI visual regression all pass.

## Delivery rule

This remains one task / one PR. Implementation continues on `docs/starting-farm-2-5d-expansion` / PR #14; do not open a second implementation PR.