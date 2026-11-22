# HPA-863 — Farm map v2 and refreshed world art: implementation plan

**Status:** Planned, not implemented. This is a specification/implementation-plan PR only; all acceptance boxes below begin unchecked.
**Issue:** https://linear.app/cwchanap/issue/HPA-863/build-the-bigger-farm-map-and-show-the-refreshed-world-art
**Design:** [Farm v2 world-art specification](../specs/2026-11-21-phoenix-farm-v2-world-art-design.md)
**Main inspected:** b14a3756e54c9949ca437c9f9ecfe0598140dd35.
**Delivery:** One HPA-863 PR, initially draft with these two docs. Implement directly on the same PR branch. HPA-861 already owns all image generation; **no art or SFX generation in this PR**.

## Preflight and constraints

- Read the HPA-863 farm-map-v2-plan.png, farm-map-v2-layout.json, three camera blockouts and mockup comparison. The layout attachment is an **authoring input**, not a runtime JSON file.
- Confirm current main and HPA-743 behavior before editing: scripts/world/world_contract.gd, world_math.gd, farm_map.gd, game_map.gd, town_map.gd, farm_view.gd, world_shell.gd; scenes/world/farm_map.tscn, town_map.tscn, terrain_tileset.tres, town_tileset.tres; and tests/headless/world_shell_smoke.gd.
- Inspect assets/sprites/hpa-861-review/README.md and the committed cutouts, ground-v2 tiles, crop, soil and review scenes. These are candidate outputs; verify their rendered edges, transparent backgrounds, sizes and anchors in-engine rather than treating offline preview PNGs as accepted implementation evidence.
- Establish baseline import, clean verification and current farm/town screenshots before replacing textures. Use temporary/ignored output directories; no generated test reports, caches or large raw captures in the commit.

## Task 1 — Contract-first tests and hard-cutover geometry

**Files:** scripts/world/world_contract.gd; tests/headless/world_shell_smoke.gd; tests/headless/world_math_smoke.gd; tests/gdunit/test_world_math.gd; related integration fixtures.

1. **Red-first:** replace the old 24×20, farm patch (4,10), bed (12,7), bin (10,13), truck (22,9), old camera, old forestry/river bands and old prop/frame assertions with the approved 48×40 target. Keep existing farm/town behavior checks; do not delete tests just to make the new layout pass.
2. Author one canonical WorldContract layout definition using the attached 60 objects, terrain blocker regions, 35 bamboo segments and 50 wooden segments. Keep map size, spawn, patch, key cells, footprint/anchor metadata, blocking and walk-through semantics there. Prefer small data arrays and existing WorldMath projection helpers over a generic scene/asset framework.
3. Update BED_CELL=(23,10), SHIPPING_CELL=(22,19), TRUCK_CELL=(33,12), TRUCK_ARRIVAL=(32,13), FARM_PATCH=Rect2i(15,19,6,5), and PLAYER_SPAWN=(23.5,11.5). Preserve MOVE_SPEED, PLAYER_HALF_EXTENT, TILE_SIZE, camera zoom and the 14 px E reach.
4. **Important:** the v2 HOUSE_FOOTPRINT Rect2(22,7,3,3) ends exactly at the south-door cell boundary, so HPA-743's old BED_CELL/house intersection becomes empty. In WorldContract.interact_regions() derive a narrow south-door contact strip from the house's south boundary, then test valid side/facing E contact and rejection from behind the house. The bed remains an E action, while plot cells remain Space targets.
5. Add contract-derived collision and reachable-path assertions, including all gates, field/lot walk-through cells and the four farm coordinates. A 4-connected design-grid audit of the attached JSON yielded 1,129 reachable of 1,129 non-blocked cells; in-engine geometry also needs to pass because the player is not a point. Pin approximate door→bin and door→truck projected path costs at the existing 96 px/s.
6. Use WorldMath.map_camera_bounds(WorldContract.MAP_SIZE) plus the existing top padding, with the resulting bound owned only once by WorldContract. Update expectations for camera corner coverage. Keep TownContract's 16×12 geometry unchanged.

**Task 1 gate:** new tests fail for the old world and pass for the canonical new contract; no change to GameSession or player/gameplay rules.

## Task 2 — Seamless authored ground, TileSets and backdrop

**Files:** scenes/world/terrain_tileset.tres, town_tileset.tres, farm_map.tscn, town_map.tscn; scripts/world/farm_map.gd, game_map.gd, town_map.gd; HPA-861 terrain assets as consumed.

1. Pick the smallest HPA-861 64×32 atlas/TileSet combination that produces continuous grass, paths, farm soil, yard, gravel, banks and towns paving at the 3× native camera. Prefer supplied ground-v2 four-phase tiles, edge/corner transitions and precomputed multi-junctions over a custom real-time blending system. Retain ordinary authored TileMapLayers.
2. Paint the 48×40 farm terrain from the approved layout in the **existing** Ground, Water, Paths and GroundDecoration layers. If repeated phase placements make manual authoring error-prone, use a tiny **one-time editor-side** helper to stamp committed static cells; runtime cannot read the attached JSON or generate the map.
3. Rebuild farm Backdrop using the existing shared GameMap._fill_backdrop() seam and the new contract tile coordinates. Ensure no camera corner reveals grey, and appropriate road, riverbank and grass continuations exist at map edges. Use the same revised compatible backdrop source for the town.
4. Retexture the existing 16×12 TownMap Ground and edge decorations, keeping shop/market/truck/villager cells exactly where TownContract already defines them. Fix dotted paving and grass seams without moving any town collision or gameplay object.
5. Review 1920×1080 native screenshots for joins at grass/path/yard, water banks, road/paddy and three-material corners. Adjust atlas choice/authoring only within delivered assets; do not ship the ground-v2 experiment merely because its offline mosaic looks acceptable.

**Task 2 gate:** scene imports successfully; all ground atlas tiles are 64×32 nearest-filtered diamonds; the farm and town show continuous painted ground from each required camera position.

## Task 3 — Author props, fences, collision and depth

**Files:** scripts/world/world_contract.gd, farm_map.gd; scenes/world/farm_map.tscn; assets/sprites/hpa-861-review/cutouts/*; tests/headless/world_shell_smoke.gd and integration tests.

1. Replace the old farm entity list with the approved 60 object records. Author all needed prop Sprite2D roots under FarmMap/Entities; farm visual anchors are derived from WorldContract footprints through WorldMath.footprint_ground_anchor() or corresponding scene-wiring placement. Use the HPA-861 bottom-centre cutout dimensions: farmhouse 224×192; storehouse/greenhouse 320×256; shed/shrine/camphor 160×144; ordinary props 96×96. Treat all dimensions as candidates until checked against Godot collisions.
2. Add bamboo and wooden fence segments, corners and posts at the 35+50 designated positions. Leave the approved west/east/south yard gateways and the field gate at x=21, y=20..21 genuinely traversable. Fences and large scenery use contract-derived collision; flower beds, lot ropes, torii and fallow plots remain walk-through.
3. The field remains exactly one 6×5 farmable patch. Scenic old plots, lots, storehouse, orchard, greenhouse, shrine, pier and build board have **no** E interactions and no added GameSession data.
4. Construct named or contract-driven CollisionPolygon2D children in FarmMap._ready() using the existing GameMap._fill_collision() and WorldMath footprint polygon conversion. Consolidate large contiguous terrain blockers when useful. Keep contract as the single geometry authority, not parallel arrays embedded in the collision script.
5. Preserve Entities' Y-sort, the Player-as-first-child reparenting on world swap, ground-contact shadows and the HPA-743 occluder fade group. Use actual native movement around large buildings, fence corners and the bin to catch incorrect overlap ordering.

**Task 3 gate:** collisions match authored obstacle footprints; all approved traversable cells and gates are reachable; the player can walk and depth-sort around the new scenery without getting stuck or disappearing.

## Task 4 — Crop/soil/bin assets and town visual swap

**Files:** scripts/world/farm_view.gd; scenes/world/farm_map.tscn and town_map.tscn; the existing terrain/prop TileSets; relevant tests.

1. Swap FarmView's crop sheet to HPA-861's four-stage-per-crop 128×144 candidate while retaining 4 columns × 3 rows, current GameRules visual_stage(), dry tint, shadows and readiness sparkle. Check that Turnip, Potato and Pumpkin are distinguishable at stages 2–4 in game.
2. Swap tilled and watered soil to the supplied 128×32 two-frame atlas, with wet/dry/rain switches unchanged. Replace the brown-box shipping artwork with the lidded transparent bin and adjust only visual frame/offset/shadow to meet its actual cell footprint.
3. Rebind existing farm and town props to the accepted cutouts without grass islands. Keep the town entity positions, collisions, villager sprites and truck unchanged. Check every frame for residual magenta/red fringe at native zoom; minor cutout cleanup is fine, generating new art is not.
4. Preserve FarmActionEffects, HomesteadAmbience, RainLayer, TargetHighlight, GameHud and the existing travel overlay. Confirm season/day rules and screenshot compositions do not change beyond the world art and geometry.
5. After searching all scene/script/test/prologue references, remove only **unreferenced** retired source sheets and atlases. Preserve unrelated proof assets still consumed in the game. Update README.md and CLAUDE.md, and AGENTS.md if still mirrored, with new cells, camera, source names and no-outdated-coordinates guidance.

**Task 4 gate:** the original crop, soil, shipping and town interaction behaviors still work using the new presentation.

## Task 5 — End-to-end verification, mockup comparison and PR completion

**Files:** tests/headless/world_shell_smoke.gd, world_math_smoke.gd; tests/integration/test_gameplay_shell.gd; tests/gdunit/test_world_math.gd; tests/e2e/world_readability_test.gd and related e2e scenarios; docs/superpowers/validation/…; README.md and handoff.

1. **Static/model checks:** validate every contract-defined obstacle and declared gate against the authored scene; the 48×40 dimension and exactly 30 farmable cells; canonical interact regions and the door-contact fix; 1,129 expected walkable grid cells and live player clearance; continuous camera Backdrop coverage; correct crop and tile frames; no references to retired assets.
2. **Headless/regression:** run Godot asset import; ./tools/verify-clean.sh on the committed head (GUT + headless project/world smokes); bootstrap GdUnit4 and run the existing GdUnit and godot-e2e suites. Specifically retain Promising Farmer and Heart of the Harvest route assertions, existing 30-minute farm↔town travel and 14-day finish. Verify GitHub CI verify/unit-tests/e2e-tests lanes for the pushed implementation SHA.
3. **MCP-driven real-session e2e:** using a Godot MCP-connected native runtime on **one** supported platform, launch the actual app, New Game, skip the prologue, walk from v2 spawn to a real farm patch cell, till/plant/water/harvest as valid for its day, use the bin, sleep into the next day, drive from the farm truck to town, interact there and return. Exercise physical E contact at bed/bin/truck and confirm decorative props do not answer to E. Record actual steps, tool provenance, runtime and any deviations in a validation note.
4. **Native visual comparison:** use that MCP-controlled Godot session at **1920×1080** to capture front door, field, storehouse yard and town edge/paving. Compare side by side with the attached three blockout views and world-mockup-vs-game.jpg; assess grass grid, props sitting on their ground, path continuity, soil wetness, crop readability, fence gates, building Y-sort, town seams and all camera extremes. A screenshot/reference comparison is a required acceptance check, **not** a screenshot-golden CI assertion. Keep raw test captures out of source control; link small evidence screenshots/artifacts and summarize any accepted differences in the validation note.
5. **Performance and regressions:** verify smooth camera-follow and visible rain/river effects at the largest farm locations; test save/Continue from a town visit restores to the new farm spawn; check no Day 15 and no change to income, stamina, travel or social actions.
6. If art cannot match the approved mockup without **new generation**, record the exact missing cutout/junction/anchor and spin the art change into an **independent follow-up art ticket**. Do not manufacture imagery inside the HPA-863 coding PR. Keep this PR draft until its visual and functional gates pass.

## End-to-end acceptance checklist

- [ ] **Map source:** 48×40 authored layout matches attached top-down plan and JSON, including 60 objects and both fence runs; one 6×5 farmable patch only.
- [ ] **Reachability:** all intended walkable cells reachable from spawn, no blocked gates, approx. 3.0 s door→bin and 3.3 s door→truck feasible at today's movement speed.
- [ ] **Interactions:** MCP-controlled real movement and E on house door/bin/truck work; scenery doesn't trigger E; town round-trip and the current session/save/clock behavior remain correct.
- [ ] **Depth and camera:** no grey at reachable farm camera extremes; player Y-sorts and occluder-fades correctly around large/new props; backgrounds and rain are preserved during map swaps.
- [ ] **Crop visuals:** all three crops visibly distinct at growth stages 2–4, dry/wet soil and shipping-bin artwork correct, 30-cell farming rules unchanged.
- [ ] **1080p visual gate:** MCP-controlled in-game screenshots compared to attached approved mockup/blockouts at front door, field, storehouse and town; no obvious tile grid, raised islands, road/paving seams or unacceptable junctions.
- [ ] **Automated gates:** clean-head GUT, headless smokes, GdUnit4, godot-e2e and CI green, including Promising Farmer and Heart of the Harvest routes. Record which literal suites ran under their own runner versus which e2e steps were physically driven through MCP.
- [ ] **Maintenance:** outdated 24×20 documentation and coordinate assumptions updated, retired atlases removed only if unused, no runtime JSON loader, no art/SFX generation and no second PR.
- [ ] **Evidence:** PR validation note links screenshots, exact checked commit, automation results and MCP walkthrough. No human sign-off criterion.

## Risk and fallback

- **Art readiness:** HPA-861's preview sheets are not in-engine accepted. Fail visibly mismatching textures and request a narrowly scoped art task instead of silently replacing them with placeholder art.
- **Door interaction:** the new house geometry makes the existing HPA-743 bed-cell intersection empty; fix and test before declaring E parity.
- **Scene/test churn:** world_shell_smoke.gd pins many old static names and pixel frames. Rewrite assertions around the new contract and actual TileSet resources, not a permanently duplicated layout fixture.
- **Overengineering:** all approved geometry is fixed and authored. A compact contract plus static Godot scene and TileSet data is sufficient; avoid a generic map compiler, new navigation subsystem or runtime renderer.

**PR policy:** one ticket → one PR; keep this draft PR as the implementation home. The docs-only plan intentionally claims **zero** test runs or completed acceptance criteria.
