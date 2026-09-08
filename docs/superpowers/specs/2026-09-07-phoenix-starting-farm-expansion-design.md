# Phoenix Starting Farm 2.5D Expansion Design

## Summary

Expand Phoenix's current compact isometric proof-ground into a larger authored starting homestead that can support a more convincing farming-game world without introducing a general map framework.

The approved composition is:

- a player house in the north-central area;
- a larger farm in the west/central area;
- river and forest boundaries on the west/north sides;
- a small workbench yard southeast of the farm;
- the current shop, villagers, shipping/finale interactions relocated into believable places along the main path;
- a road that reaches the east edge and clearly reserves a future connection to a separate village scene.

This slice stays 2D technically. Phoenix already uses a 64x32 isometric projection, Y-sorted entities, projected collision footprints, and a player-follow `Camera2D`; those remain the rendering/movement model. "2.5D" here means a larger layered isometric world with depth ordering, tall scenery, occlusion-by-Y-sort, and camera travel—not a migration to Godot 3D nodes.

## Goals

1. Make the gameplay scene feel like a real homestead instead of a single-screen proof ground.
2. Increase the authored walkable area from `12x12` to `24x20` logical cells.
3. Expand the farm from `3x3` (9 cells) to `6x5` (30 cells) while keeping the current farming rules and balance.
4. Reuse the existing smooth player-follow camera and make traversal visibly pan across the larger map.
5. Add a recognizable player house and use its doorstep as the existing sleep interaction.
6. Preserve the current complete game loop: farming, shop, shipping, villagers, sleep, and Harvest Market finale all remain reachable.
7. Reserve an obvious village road at the east edge without implementing a village scene or transition system yet.
8. Keep the implementation lean enough to land as one task / one PR.

## Non-goals

This slice does **not** add:

- a separate village scene;
- scene transitions or an area/map registry;
- house interiors;
- fishing, foraging, crafting, or workbench gameplay;
- NPC schedules or pathfinding;
- manual mouse/keyboard camera panning;
- camera zoom controls;
- a minimap;
- procedural generation, chunk streaming, or map loading infrastructure;
- new crops, villagers, shops, economy rules, or finale rules;
- save migration or backward compatibility for old development saves;
- a new rendering engine, Godot 3D, NavigationServer, or generic world-object framework.

## Current baseline

The current world is intentionally small and hand-authored:

- `WorldContract.MAP_SIZE = Vector2i(12, 12)`;
- `FARM_PATCH = Rect2i(2, 7, 3, 3)`;
- the ground is one `TileMapLayer` backed by a three-tile 64x32 isometric proof tileset;
- `Entities` is the one Y-sorted presentation container;
- the player owns the only `Camera2D`, already using position smoothing;
- `WorldShell` builds projected collision polygons from `WorldContract` footprints;
- `GameSession` initializes and validates farm state directly from `WorldContract.farm_cells()`.

That means the expansion can stay within the existing ownership model. No second world/session abstraction is needed.

## Approved map composition

Use this topology as the authored target:

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

### Logical layout

Lock the first implementation to a `24x20` logical grid.

Recommended authored anchors:

- `MAP_SIZE = Vector2i(24, 20)`
- `FARM_PATCH = Rect2i(4, 10, 6, 5)`
- `PLAYER_SPAWN = Vector2(11.5, 8.5)`
- player house footprint: `Rect2(10.0, 4.0, 4.0, 3.0)`
- house/bed interaction cell: `Vector2i(12, 7)`
- shipping interaction cell: `Vector2i(10, 13)`
- shop interaction cell: `Vector2i(17, 9)`
- Harvest Market interaction cell: `Vector2i(19, 10)`
- villagers: `Vector2i(16, 8)`, `Vector2i(18, 8)`, `Vector2i(17, 11)`
- future village-road terminus: east edge around `Vector2i(23, 10)`; visual only in this slice.

These coordinates are the implementation contract, not a new data-driven map format. If one or two cells must move during scene authoring to avoid overlap with the final art footprint, update the constants and tests together rather than adding configuration machinery.

### Area intent

**North / northwest — forest boundary**

Dense trees, rocks, and elevation-like scenery form a visual/non-walkable boundary. These are decorative collision objects only. No foraging interaction is added.

**North-central — player house**

The house becomes the visual home base. The existing sleep action moves from the generic proof building interaction to the house doorstep. The house has exterior collision; there is no interior scene.

**West / central — farm**

The `6x5` patch provides 30 farmable cells. It remains one rectangular authored patch, not multiple plots and not an arbitrary farm-region system. Current stamina/time/crop balance stays unchanged; the extra cells provide capacity, not a mandate to work all 30 cells every day.

**Southwest / west boundary — river**

Water and bank scenery create a strong edge and visual landmark. River tiles are not walkable and expose no fishing hook in this slice.

**Southeast — workbench yard**

A workbench/shed/kiln-style composition reserves space for future processing/crafting. It is scenery only and has collision where needed.

**East-central — roadside social/market cluster**

The current shop, villagers, and Harvest Market stay in the starting scene so the complete 14-day loop remains intact. They are rearranged along the road toward the future village exit so later relocation to a village scene is conceptually clean.

**East edge — future village road**

The road visibly continues to the boundary with a sign/landmark. It is not interactive and cannot transition scenes yet. The walkable perimeter stops before the player can leave the authored map.

## Scene ownership

Keep the current runtime ownership and extract only static environment composition.

```text
World / WorldShell
├── StartingFarmMap                 # new PackedScene, static environment only
│   ├── Ground                      # TileMapLayer(s)
│   ├── Paths                       # presentation layer
│   ├── Water                       # presentation layer
│   ├── Scenery                     # trees/house/fences/rocks/workbench/sign
│   └── StaticCollision             # projected environmental collision
├── FarmSoil                        # dynamic tilled/wet soil presentation
├── Entities                        # existing one Y-sorted container
│   ├── Player
│   ├── Shipping / Shop / Market
│   ├── Villagers
│   └── runtime crops
├── TargetHighlight
└── GameHud
```

`StartingFarmMap` is deliberately **not** a generic map type. It has no script unless scene authoring needs one trivial presentation helper. `WorldShell` still owns runtime wiring and `GameSession` remains the only mutable gameplay authority.

## Environment rendering

### Ground and paths

Replace the three-frame proof ground with a small starting-farm isometric environment tileset using the existing `64x32` tile geometry.

The minimum tile vocabulary is:

- base grass;
- alternate grass/detail tile;
- dirt/path;
- dark soil/edge accent where needed;
- water;
- river bank/edge variants sufficient for the authored river shape.

Do not build terrain auto-tiling unless authoring the fixed map becomes materially harder without it. A manually authored `TileMapLayer` is preferred for this one map.

### Tall scenery

Use separate sprites for the house, trees, rocks, fences, roadside sign, shipping prop, and workbench-yard props where the object needs independent depth/collision placement.

Tall scenery that can overlap the player belongs under the existing Y-sorted `Entities` container or a single Y-sorted static-scenery child that participates in the same Y order. Do not create multiple competing Y-sort roots.

Ground, water, and soil stay outside Y-sort.

### Art direction

Follow the approved concept composition: bright pastoral anime-inspired colors, readable silhouettes, warm house roof, lush green farm/forest, blue river, and an obvious eastbound village road.

The concept is a composition reference, not a pixel-perfect runtime background. Runtime placement must remain grid/collision driven.

## Farming presentation

The farm grows from 9 to 30 authored cells. `GameSession` should continue deriving farm state from `WorldContract.farm_cells()`.

`FarmView` currently creates crop roots dynamically but expects manually authored soil sprites. Change that asymmetry: create both soil and crop presentation from `WorldContract.farm_cells()` at runtime.

Desired ownership:

- `FarmView` creates one soil sprite per authored farm cell under `FarmSoil`;
- `FarmView` creates one crop root/shadow/sprite per authored farm cell under `Entities`;
- `FarmView.refresh(snapshot)` remains presentation-only;
- farm legality remains in `GameSession`, not in the view.

This avoids adding 30 repeated `Soil_x_y` nodes to `world.tscn` while keeping the existing simple dictionary lookup model.

## Camera behavior

Reuse the player-owned `Camera2D`.

Required behavior:

- smooth automatic follow while the player moves;
- camera travel across the larger map is visible and continuous;
- keep the existing position smoothing behavior as the baseline;
- clamp the viewport to authored camera limits so normal traversal never exposes empty world outside the environment art;
- camera state is not persisted;
- no manual pan, zoom, edge scroll, camera mode, or second camera controller.

Camera limits remain an authored world contract. Prefer one `WorldContract.CAMERA_BOUNDS` (or one small helper deriving an equivalent `Rect2` from locked map geometry plus fixed art margins) over a new camera abstraction.

## Collision and traversal

Keep projected `CollisionPolygon2D` footprints and the current `WorldMath.footprint_to_polygon()` approach.

Collision groups needed in this slice:

- house footprint;
- tree/forest clusters;
- river/non-walkable bank;
- workbench props where they visibly occupy space;
- existing shop/shipping/market/villager footprints;
- perimeter bands preventing exit through the village-road edge or other boundaries.

Do not add navigation meshes, tile metadata collision rules, or an obstacle registry solely for this map.

The full playable path must allow the player to walk:

1. from the house spawn to the farm;
2. around the entire usable farm edge;
3. from farm to shipping;
4. from farm/house to shop and all three villagers;
5. from the main path to the Harvest Market;
6. from the central area to the visible future-village road terminus.

## Existing interaction relocation

Preserve all current interaction semantics.

- `BED_CELL` becomes the house doorstep/sleep target.
- `SHIPPING_CELL` moves beside the farm.
- `SHOP_CELL` moves into the roadside cluster.
- `MARKET_CELL` moves farther east along the village road.
- the three `VILLAGER_CELLS` move into the roadside cluster.

`WorldShell.interact()` and the current hint chain remain structurally the same. This slice should be mostly constant/scene relocation, not interaction-system redesign.

## Persistence contract

The farm cell list is part of persisted state validation today. Increasing the authored farm from 9 to 30 cells therefore intentionally makes saves created against the old farm layout incompatible.

That is acceptable for the current development stage.

Required behavior:

- new games initialize exactly 30 farm entries in authored order;
- new saves persist all 30 entries;
- Continue restores those 30 entries normally;
- old 9-cell development saves fail the existing compatibility validation and leave New Game usable;
- no schema bump, migration function, compatibility adapter, or legacy farm remapping is added solely for this change.

## UI and visual-regression impact

The UI redesign remains unchanged. This work changes the world visible behind HUD/modal states, so visual goldens that include the gameplay world must be recaptured and manually approved against the already-approved UI design.

Do not weaken the visual regression tolerance to absorb map changes. Update the expected production captures instead.

Title/result-only states that do not render the world should remain unchanged unless a real dependency proves otherwise.

## Testing strategy

### Unit / GdUnit

- `WorldMath` projection round-trip continues to pass with the larger map.
- `target_cell()` accepts valid targets near the new edges and rejects coordinates outside `24x20`.
- `GameSession.new()` creates 30 farm entries.
- farm state validation requires the new exact authored cell sequence.

### Integration / GUT

- world scene instantiates with the new `StartingFarmMap`.
- soil/crop presentation count equals `WorldContract.farm_cells().size()` instead of asserting nine hard-coded nodes.
- all existing shop/shipping/bed/market/villager interactions work at relocated cells.
- player can be positioned/traversed at representative west, north, and east map locations without leaving camera/world bounds.
- camera follows the player and clamps within the authored limits.
- save/Continue round-trip preserves a changed farm cell in the expanded patch.

### E2E

Keep E2E focused. Update the existing Day-1 gameplay route to target cells from `WorldContract.farm_cells()` rather than stale literal proof-ground assumptions. Add one travel assertion only if it can be made deterministic without turning E2E into a movement-duration test suite.

### Visual

Recapture the gameplay-world goldens affected by the new background and approve them side-by-side. Keep the existing visual harness and tolerance policy.

## File-level design

### Create

- `scenes/world/starting_farm_map.tscn` — fixed static environment composition.
- `scenes/world/starting_farm_tileset.tres` — fixed 64x32 environment tile atlas mapping.
- `assets/sprites/starting-farm-tiles.png` — ground/path/water tile sheet.
- `assets/sprites/starting-farm-house.png` — house exterior.
- `assets/sprites/starting-farm-tree.png` — reusable tree/forest prop.
- `assets/sprites/starting-farm-rock.png` — reusable rock prop.
- `assets/sprites/starting-farm-fence.png` — fence/edge prop.
- `assets/sprites/starting-farm-workbench.png` — decorative workbench-yard prop.
- `assets/sprites/starting-farm-sign.png` — future-village road sign.

The final implementation may combine small scenery PNGs into fewer atlases if that is simpler for the asset-generation workflow, but it must not introduce a runtime atlas/asset registry abstraction.

### Modify

- `scenes/world/world.tscn` — instantiate the static map; remove proof-ground/static-scenery duplication and manually authored farm soil nodes.
- `scripts/world/world_contract.gd` — larger map, farm patch, spawn, interaction cells, footprints, and camera bounds.
- `scripts/world/world_shell.gd` — point collision setup at the extracted map scene and preserve existing interaction wiring.
- `scripts/world/farm_view.gd` — dynamically create soil presentation for all farm cells.
- `scripts/player/player_controller.gd` / `scenes/player/player.tscn` — camera-limit tuning only if needed; retain one player-owned camera.
- relevant unit, integration, GdUnit, E2E, headless smoke, and visual-golden files.

### Remove/retire

- `scenes/world/proof_ground_tileset.tres` once no production scene references it.
- obsolete proof-ground tile/scenery assets only when no test or production scene references them.
- `PATH_ROW/path_cells()` if they are no longer used after path authorship lives entirely in `starting_farm_map.tscn`.

Do not delete shared proof player/crop/villager/shadow assets unless this same PR actually replaces them.

## Acceptance criteria

The slice is complete when all of the following are true:

1. New Game starts outside the authored player house.
2. The player cannot see the entire map from the starting viewport.
3. Walking naturally pans the existing camera across the `24x20` homestead.
4. Camera limits prevent visible empty world at reachable traversal extremes.
5. The map clearly reads as house + farm + river/forest + workbench yard + eastbound village road.
6. All 30 farm cells support the existing hoe/plant/water/harvest rules.
7. The sleep interaction is at the house, shipping is beside the farm, and shop/villagers/Harvest Market are reachable along the village road.
8. The future-village road is visible but does not transition scenes.
9. Save/Continue persists gameplay using the new 30-cell farm contract.
10. Old 9-cell development saves may be rejected without migration.
11. Existing 14-day gameplay rules, balance, UI surfaces, and finale behavior remain unchanged.
12. GUT, GdUnit4, godot-e2e, headless smoke/import/export checks, and applicable visual-regression checks pass.

## Scope guard

If implementation pressure suggests adding any of the following, stop and keep it out of this slice unless a concrete blocker proves it necessary:

- generic `MapDefinition` resources;
- area IDs in save state;
- scene-transition services;
- global camera managers;
- object registries;
- navigation/pathfinding;
- procedural map generation;
- tile streaming;
- generic interaction components;
- crafting/fishing/foraging stubs;
- compatibility code for old saves.

The purpose of this work is one better starting map, not an overworld architecture.