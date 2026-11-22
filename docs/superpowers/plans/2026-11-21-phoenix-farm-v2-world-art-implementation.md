# HPA-863 — Farm map v2 and refreshed world art: implementation plan

**Status:** Planning only; not implemented or verified. No acceptance gate is complete.
**Linear:** https://linear.app/cwchanap/issue/HPA-863/build-the-bigger-farm-map-and-show-the-refreshed-world-art
**Design:** [HPA-863 design spec](../specs/2026-11-21-phoenix-farm-v2-world-art-design.md)
**Baseline:** main b14a3756e54c9949ca437c9f9ecfe0598140dd35, checked 2026-11-22.
**Delivery:** One ticket = one PR (#48). Implement on this **same** draft PR; do not open a separate implementation PR. All original art generation remains under completed HPA-861. Do not generate new art or SFX inside HPA-863.

## Preflight and constraints

Inspect the HPA-863 approved top-down 48×40 plan, farm-map-v2-layout.json, front-door/field/storehouse blockouts and the world-mockup-vs-game.jpg. The attached JSON is an **authoring input**, not a runtime loader. Inspect candidate assets and their generation notes in assets/sprites/hpa-861-review/README.md and ground-v2/, including the multi-junction index and preview warnings. Use Godot screenshots for acceptance; PNG review scenes are not proof.

Read WorldContract, WorldMath, FarmMap, FarmView, FarmActionEffects, FarmMap.tscn, GameMap, TownMap, HomesteadAmbience, WorldShell, SessionStateValidator, the existing smokes, GUT/GdUnit4/e2e suites, and export_presets.cfg. Establish initial build/test, screenshot and macOS export baselines.

**Maintain a runnable checkout at each pushed checkpoint.** The original plan moved coordinates, camera and plot before the scene, collisions and ambience could follow, which would break intermediate commits. Make geometry and its consumers one coordinated change. Local intermediate edits need not be pushed.

## Task 1 — Promote exportable art; swap visuals independent of geometry

**Files:** assets/sprites/, scripts/world/farm_view.gd, farm_action_effects.gd, scenes/world/farm_map.tscn and town_map.tscn, town tileset, related tests.

1. Select accepted crop, soil, shipping-bin and town candidates. **First move** accepted runtime textures to a live nonexcluded directory, for example assets/sprites/world-v2/, with tracked .import/UID sidecars where relevant. Only then update production references. export_presets.cfg currently excludes assets/sprites/hpa-861-review/*; leaving a production texture there makes it disappear from the macOS export. Keep source sheets/prompt provenance in an excluded source/review location, but delete unused preview scaffolding and rejected candidates later.
2. While the farm still uses its existing 24×20 geometry, switch FarmView's crop sheet to the supplied 128×144 four-stage-per-crop atlas (32×48 frames), tilled/wet soil to 128×32, and shipping bin to the lidded transparent cutout. Preserve growth, rainy wetness, sparkle, shadow and framing rules unless the native image check shows an offset problem.
3. Change FarmActionEffects to reference **FarmView.CROP_TEXTURE**; it currently independently preloads proof-crops.png for the harvest-pop frame. One crop atlas must drive both the standing plant and harvest pop.
4. Retexture town buildings and paving/road on existing TownContract cells, without changing town collision, residents, travel or gameplay. Use the smallest deterministic authored-tile update when four-phase paving requires it; do not introduce a second terrain runtime.
5. Update old hard-coded texture assertions in the same commit, run import/smoke and inspect the current-world native screenshot. Verify that the **exported pack can resolve accepted new texture resources**, not merely that the export ZIP includes a binary.

**Checkpoint:** farm and town still play on the original geometry; crop, harvest effect, bin and town use the accepted art; exported package loads those resources.

## Task 2 — Implement a small, mandatory, deterministic ground stamper

**Files:** tools/stamp_farm_ground.gd, pure tile-selection helper, WorldContract ordered terrain data, ground TileSet resources, headless smoke and candidate atlas integration.

1. Encode the **28 ordered terrain rectangles** from the approved layout in WorldContract. A single material_at(cell) applies **last-writer-wins**. Terrain blockers must derive from the resolved grid, never from a union of source rectangles: road x=42..43,y=0..2 reopens forest, and pier x=23..24,y=35 reopens water (eight otherwise falsely blocked cells).
2. At out-of-map coordinates, material_at clamps each coordinate to the nearest map-edge cell. The supplied experiment's outside-is-grass default would place a visible shore on the north river and a grass rim around the road/paddies.
3. Write one **headless Godot authoring script** at tools/stamp_farm_ground.gd using one pure tile_for(cell) helper. Choose from HPA-861 ground-v2 four-phase material tiles, 23 two-material transition atlases and available multi-junction candidates. Respect the existing source README's per-vertex majority and alphabetic-tie policy, and use **posmod** for negative backdrop coordinates.
4. Generate **ordinary committed Godot tilemap resources**, not a runtime importer. The same tool stamps all 48×40 Ground cells plus WorldMath.backdrop_cells() overdraw with identical tile_for rules. Include a headless smoke that recomputes the tile expectation and compares the authored Ground and Backdrop, with independent fixtures for pier, road/paddy, north river and multi-material corners. Contract changes without restamping must fail the smoke.
5. Prepare the new map scene and TileSet as local changes or separate staged resources while the old map remains playable. Avoid pushing a half-cutover commit.

**Checkpoint:** the tiny authoring tool and fixtures work; current production scene remains importable until geometry switches atomically in Task 3.

## Task 3 — One atomic 48×40 geometry, collision and ambience cutover

**Files:** world_contract.gd, world_math.gd as needed, game_map.gd, farm_map.gd, homestead_ambience.gd, farm_map.tscn, terrain_tileset.tres, tests/headless/world_shell_smoke.gd, world_math_smoke.gd, GUT/GdUnit fixtures.

1. Switch to MAP_SIZE=(48,40), PLAYER_SPAWN=(23.5,11.5), HOUSE_FOOTPRINT=(22,7,3,3), BED_CELL=(23,10), FARM_PATCH=Rect2i(15,19,6,5), SHIPPING_CELL=(22,19), TRUCK_CELL=(33,12), TRUCK_ARRIVAL=(32,13). Keep tile geometry 64×32, movement 96 px/s, player half extent, near-contact reach 14 px and camera zoom 3.
2. Use existing WorldMath.map_camera_bounds(WorldContract.MAP_SIZE) **without adding extra top padding**. The result for 48×40 is Rect2(-512,-96,2816,1504). Populate the authored new ground/backdrop in the same change so the plot and soil match the new coordinates.
3. Keep the **28 ordered materials**, simple blocking-prop records {node, footprint}, and **12 straight fence runs** (seven bamboo and five wooden; 35 + 50 occupied fence cells including proper gate gaps) in the contract. Walk-through decorative-only positions live in the authored scene and do not need unused duplicate contract entries.
4. Add one focused GameMap._add_collisions(body, rects) helper to create CollisionPolygon2D children from WorldMath.footprint_to_polygon(). Get terrain blockers from the final resolved material grid (merge continuous row runs), then combine with blocked prop footprints and fence runs. Keep named HouseCollision, ShippingCollision and TruckCollision for existing test references. Do not author 130 extra named collision nodes by hand, and do not alter TownContract.
5. Fix the HPA-743 door trap: HOUSE_FOOTPRINT ends at y=10 but BED_CELL begins at y=10, so their former intersection becomes an **empty Rect2 at the origin**. Use Rect2(BED_CELL.x, HOUSE_FOOTPRINT.end.y - 0.25, 1, 0.25) for its contact region; assert **has_area() for every farm E region**. Check physically reachable contact, facing, rear refusal and no accidental origin action.
6. **Do not omit HomesteadAmbience.** Its three river-ripple anchors depend on obsolete RIVER_WEST_FOOTPRINT/RIVER_SOUTH_FOOTPRINT and hard-coded 6.5/13.0 locations. Move them to water-cell positions derived from the new contract while retaining the same presentation effect.
7. The farm's Backdrop is now stamped statically with Ground by the authoring tool. Remove FarmMap._fill_backdrop(), _is_backdrop_road/_is_backdrop_water and obsolete BACKDROP_ROAD_ROW. TownMap retains its shared runtime GameMap._fill_backdrop() path and only updates compatible live textures. Remove superseded empty Water/Paths layers and old water-tile expectations if a single opaque ground tile already contains transitions.
8. Rebuild contract-driven tests in the **same commit**: 30 farmable cells, 48×40 map, 28 ordered terrain rects, road and pier reopenings, fence gates, correct collision polygons and anchors. The supplied data's **1,129** connected nominal cells count the bin/truck as walkable; physical bin/truck colliders make it **1,127** genuinely unoccupied nominal cells. Pin both definitions and player-footprint clearance, rather than accepting a misleading reachability count. Check authored visual nodes and colliders against contract tables instead of duplicating all 60 layout records in tests.
9. Use Godot **AStarGrid2D** (8-connected, no corner cutting through solids, weighted iso-world-pixel step lengths) to assert short routes. Define the starting point as a reachable door-adjacent cell and goals as **walkable cells within E reach next to bin/truck**, never their solid cells. Expect about 3–3.5 seconds at the existing speed with a documented tolerance; also pin the actual gate paths. No custom Dijkstra or new navigation subsystem.
10. Bring the smoke, GUT, GdUnit4, existing e2e routes and normal gameplay to green before pushing this coordinated cutover. Retain the single FarmMap/WorldShell/GameSession responsibilities.

**Checkpoint:** new 48×40 map launches, all three farm E interactions work, tile/soil/collider positions agree, town travel works and tests pass. No half-migrated geometry is committed.

## Task 4 — Author and validate final scenery, fences and tile transitions

**Files:** farm_map.tscn, accepted live world-v2 cutouts, terrain_tileset.tres, contract-fed collisions, world smoke and focused visual tests.

1. Apply the approved **60 object records correctly**. Nine of them are painted ground areas (four plots, five building lots), and the bed is the house-door region; **50 sprite/prop entries remain, including already-existing bin and truck**. Do not create 60 new Entity nodes or duplicate data. Reuse existing props where possible, positioning collision-bearing props from WorldMath.footprint_ground_anchor(). Check candidate frame sizes in Godot (farmhouse 224×192, storehouse/greenhouse 320×256, shed/shrine/camphor 160×144, ordinary props 96×96).
2. Place the approved 35 bamboo and 50 wood fence positions from **12 runs**, with suitable corners, posts and intact gaps. The field east gate remains open at (21,20)..(21,21), as do all three yard gates. Walk-through flowers/lot ropes/torii remain free of collision. Shrine, lots, board, greenhouse, orchard, pier and fallow plots remain **inert on E**.
3. Stamp the final accepted four-phase ground, transition and waterbank cells, plus the farm camera overdraw, and visually check junctions at 1920×1080 using actual Godot (not offline PNGs). Match the approved blockouts and mockup: no grass diamond grids, rimmed tiles, separate prop islands or dotted town paving seams. If completely new art is required, create a **separate art ticket**, not new image generation inside this code task.
4. Preserve Entities Y-sort, bottom-centre contacts, ground shadows, player_occluder fade, Shell-held Player, TargetHighlight, RainLayer and HUD. Check real collision around large props/fence posts/field bin and player visibility, water/ripple placement, 30 crop/soil decals and readable crop stages 2–4.

**Checkpoint:** new scenery looks and behaves as specified at native camera scale; no blocked paths or ungrounded props. Update tests to cover authored assets instead of old frame/name fixtures.

## Task 5 — End-to-end MCP evidence, CI, export and clean-up

**Files:** existing tests/headless + tests/integration + tests/gdunit + tests/e2e, docs/superpowers/validation/, release export checks, README.md/CLAUDE.md/AGENTS.md and unused assets.

1. Run clean-head Godot import and ./tools/verify-clean.sh (GUT plus headless project/world smokes), GdUnit4 and godot-e2e; retain Promising Farmer and Heart of the Harvest, 30-minute travel, crop, save and Day-14 ending assertions. Confirm GitHub verify/unit-tests/e2e-tests CI lanes on the **pushed implementation SHA**.
2. **Focused Godot MCP-driven end-to-end acceptance on one supported platform:** launch the actual app, New Game → skip prologue → walk v2 yard/field gates → perform one Space farm action → physically approach/E bin, bed and farm truck → visit town and return → try E on one inert prop. This exercises the changed map, movement and interaction end to end **through MCP** without duplicating all harvest-growth, sleep and ending flows that the existing automated suites already cover.
3. In the same agent-driven 1920×1080, zoom-3 native run, capture **front door, field, storehouse yard, town paving and camera extremes**. Compare screenshots directly with the approved HPA-863 blockouts and world-mockup-vs-game.jpg, noting any deviations. Inspect camera backdrop, fence gaps, wet soil, distinct crops, bin, water banks, Y-sort/occlusion and town seams. Screenshots are visual evidence, not CI pixel-golden tests. Keep raw output and caches out of git; record small evidence images/references and the exact MCP method in one short validation note.
4. Confirm a **new v2-created** save can Continue at the new farm spawn. **Pre-v2 saves are intentionally rejected**, because scripts/game/session_state_validator.gd validates stored farm-cell positions against WorldContract.farm_cells(); do not claim old saves respawn or implement a migration. Add automated assertions for v2 loading and deterministic old-save rejection.
5. Check the **real exported macOS pack contains and can load every accepted runtime texture**. The current export CI's binary-only ZIP check is not adequate. Add a packaged-resource smoke/inspection or boot verification and preserve proof; don't pass solely on export command success.
6. Search references before deleting old proof-/starting-farm atlases or source sheets. Keep generation sources/prompts as provenance in an export-excluded directory; prune rejected candidates, review scenes/previews and unreferenced runtime files. Update README, CLAUDE and mirrored AGENTS with the new WorldContract coordinates, collision rules, art paths and intentional old-save rejection.
7. Remain one PR, initially draft. Only mark an acceptance box complete when actual tool evidence supports it. If art is missing, create a **separate** art ticket. No human-signoff or second-platform requirement.

## End-to-end acceptance criteria

- [ ] **Source and stamping:** WorldContract is the single geometry authority; 28 ordered material regions and mandatory deterministic authoring tool stamp 48×40 Ground plus camera Backdrop with parity, multi-junctions, clamped edge continuation and smoke-detected drift. No runtime JSON or terrain renderer.
- [ ] **Geometry/reach:** approved 30-cell plot, key interactable/arrival cells, 12 fence runs and gate holes, road/pier reopening, 1,129 coarse open cells vs **1,127** excluding bin/truck colliders, footprint-safe paths and AStarGrid2D door→bin/truck ~3–3.5 s with legal contact endpoints.
- [ ] **Native MCP e2e:** app-driven walk through field/yard, Space farm action, E door/bin/truck, town round trip and inert E refusal all work via MCP, with recorded tool steps.
- [ ] **1080p visual:** MCP screenshot comparisons to approved mockup/blockouts of door, field, storehouse, town and camera extremes show continuous grass/paths/paving/water, props grounded, distinct crops/wet soil, no grey void, correct depth/fade.
- [ ] **Regression:** GUT, headless, GdUnit4, godot-e2e and CI green (including Promising and Heart routes); MCP scenario and literal suite runs recorded separately.
- [ ] **Export:** accepted textures live outside excluded review directory and actually load from macOS export pack; binary-only ZIP check is insufficient.
- [ ] **Save policy:** v2 save Continue restores to new farm spawn; old saves reject without migration.
- [ ] **Maintenance/evidence:** accepted art and sources organized, unused assets removed only after reference search, docs updated, one concise validation ledger with actual commit/test/export/screenshot evidence; no second PR, runtime framework or new art/SFX.

## Explicit non-goals

No lot construction, storehouse inventory, farmable fallow plots, town re-layout, save migration, procedural world generation, runtime map import/render system, second-platform acceptance, human acceptance gate, screenshot-golden CI check or full MCP replay of unchanged season simulation.

**This draft contains only the plan. No code, suite, native screenshot or export validation is being claimed as complete.**
