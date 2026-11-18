# HPA-743 — Make the world easy to use and read: design specification

**Status:** Proposed, docs-only draft; implementation and verification will be added to this same PR.  
**Issue:** https://linear.app/cwchanap/issue/HPA-743/make-the-world-easy-to-use-and-read  
**Repository/base inspected:** `cwchanap/phoenix`, `main` at `39a25b2be357a121fe5d715ed347028cacdb347d` (17 Nov 2026 Vancouver).  
**Delivery:** One Linear ticket = one PR, including this design, implementation and evidence.

## Outcome and source of truth

A player who approaches an interactable from any reachable side and faces it can press E successfully on the first attempt; the prompt and target diamond agree with that E action. The player stays visible when a foreground prop overlaps the player sprite. The farm camera no longer exposes grey void outside the authored 24×20 playable map, and the east road visibly continues. The farm's collision, camera, and farming gameplay are unchanged.

Source: 15 Nov UAT in HPA-743, including the target/occlusion screenshots and **B2** side-by-side farm-edge mockup (plus HTML board `#b2`). B2 shows the grass-filled edge; the implementation must additionally continue the east dirt road using current terrain art. Compare native 1920×1080 captures visually against B2; this is *agent-operated* visual inspection, not a pixel-golden test.

## Existing architecture and constraints

- Standard Godot 4.7.1 / statically typed GDScript. `WorldShell` is the sole live session holder and world coordinator; `GameSession` is the rules authority. No save-schema, economy, time, or travel-rule changes.
- `PlayerController.current_target_cell()` uses `WorldMath.TARGET_OFFSETS` to find one exact logical farm cell; this is **correct for Space/farming**. `PlayerController._update_target()` currently paints that same cell's diamond even when `WorldShell` is displaying an E hint.
- `WorldShell._interactable(target)`, `_process()`, and `interact()` depend on the exact raw target. The shop, upgrade, shipping, sleep and market-confirmation HUD callbacks also read `current_target_cell()` later, when the modal is open. Fixing E alone would still cause the final domain command to fail.
- The farm/town interactable cells, collision footprints and camera bounds are in `WorldContract` / `TownContract`; `FarmMap` and `TownMap` build static collisions from them. Each active map owns a Y-sorted `Entities` root; `load_map()` reparents the same Player as child index 0, so exact-Y ties draw later props in front.
- `TownMap` already paints non-colliding `Backdrop` tiles using the farm terrain atlas. Move its existing coverage math to `WorldMath` and its painting loop to shared `GameMap` helpers, without expanding the playable map.

## Decision 1 — Collision-contact E resolver; farming stays tile-exact

Keep `PlayerController.current_target_cell()` and Space/hold farming **unchanged**. In `WorldShell`, add a single `_resolve_interactable()` that selects the canonical contract cell and then calls existing `_interactable(cell)` for its label and action. Return `{cell, label, action}` or empty; no new registry, Area2D nodes, service object or domain command.

Pair each interactable cell with an already-authored **collision footprint** in `WorldContract.interact_regions()` and `TownContract.interact_regions()`; WorldShell does not duplicate cell/footprint data. Farm: bed, shipping, truck. Town: truck, Seed Shop, Harvest Market and three villagers. For the bed, use just the door-facing **house slice** `WorldContract.HOUSE_FOOTPRINT.intersection(Rect2(WorldContract.BED_CELL, Vector2.ONE))` = `Rect2(12, 7, 1, 0.25)`; the whole house would permit interacting from its far side. Unlike a logical cell, this physical collision region cannot contain a legitimately standing player. Try the existing **exact raw target cell first** to preserve existing control behavior and teleport fixtures, even if their artificial stand pose is outside the new near-contact radius.

For near-contact fallback, use a tiny pure helper in `WorldMath` to find the nearest point on `WorldMath.footprint_to_polygon(region)` via `Geometry2D.get_closest_point_to_segment()` on its four edges. Compute projected **world-pixel** distance from the player's ground point to this contact. Seed reach at **14 px**, then pin/tune only against physically reachable collision-stop poses and negative one-gap poses; do not use the previous 32 px estimate. Require `facing_direction.dot(contact - player_ground_position) > 0` with **no angle cone or coincident-centre fallback**. Screen-cardinal facings include both directions into each slanted isometric face, including the horizontal tie-break during diagonal movement. Choose the nearest eligible candidate, stable contract order for ties. Facing away or approaching across an empty cell must fail.

Use this one resolver for: E hint and `_prompt_anchor(resolved.cell)`; `interact()` and its travel/market call; and the five modal-submit handlers `_on_buy_requested`, `_on_upgrade_requested`, `_on_deposit_requested`, `_on_sleep_requested`, and `_on_market_confirmed`. Re-resolve at submission because the modal input gate freezes player position/facing, rather than caching the target or bypassing authoritative `GameSession` guards by supplying hardcoded cells.

**Highlight:** No new `PlayerController` override state. In `WorldShell._process()`, the E-hint branch writes the existing `player.target_highlight.points = WorldMath.cell_diamond(resolved.cell)` and neutral/gold tint **after** the Player's `_physics_process` has drawn its raw target for this frame. The shell therefore provides the final draw before render. Farming/blocked-farming and idle paths use the raw diamond; `enter_map()` still draws an initial raw target before the first physics tick. No reset obligations or new state.

**Space/E overlap:** At the shipping bin's edge, a valid E target can coexist with a raw farm tile (e.g. `(9,14)`) that has a Space preview. **Space's green/red farming hint and diamond retain visible priority**, with no concurrent `[E]` hint. **E still dispatches the independent resolver** to Shipping, and Space still works on the raw tile. The promise that label/highlight/E agree applies to an **E-labeled** hint, not a `[Space]` hint. Add a specific boundary test with LEFT-facing bin contact.

Replace the existing **`Bed`** E hint with **`Go to bed`**, and **replace** the single `Bed,床,ベッド` translation row in `assets/i18n/strings.csv` with the new English source key, `zh_TW` and `ja` values; no competing sibling key.

## Decision 2 — Opt-in foreground fading, no cached state

Opt in relevant static prop roots under the Y-sorted `Entities` of both farm and town via a `player_occluder` Godot group: farm house, bin, fences, truck, tall scenery; town station, shop, cafe, market, truck and tall scenery. Exclude crops, harvest FX/pops, villagers and the player, because some already animate their own opacity.

One `WorldShell._process()` helper calls `get_tree().get_nodes_in_group("player_occluder")` each frame and acts only on roots under the active map. Compare the drawn global bounds of each root's `Sprite2D` to the player's visible sprite. A prop fades only when bounds overlap **and** `prop.global_position.y >= player.global_position.y`—the latter matches player-first Y-sort tie order. Adjust the **individual sprite** `self_modulate.a` with `move_toward` toward a single shared `FADE_ALPHA` (roughly 0.45–0.50), otherwise restore toward 1.0. One shared alpha constant, **no shared mutable alpha variable**, shader, tween, pixel mask, per-prop tuning table, or stored node cache.

Map replacement naturally removes old group members and creates fully opaque props; a map-swap regression verifies this, not manual cleanup code. Test overlap, restoration, a non-covering prop and exact-Y ties.

## Decision 3 — Shared backdrop painter, fixed collision and camera

Add a non-colliding farm `Backdrop` `TileMapLayer` **before** Ground/Water/Paths. It uses the existing `terrain_tileset.tres` and the same projected position as the existing farm Ground. Do not change `WorldContract.MAP_SIZE`, camera limits, perimeter geometry, truck arrival or authored playable terrain.

Move the pure camera-corner/one-cell-overdraw coverage calculation from `TownContract.backdrop_cells()` into `WorldMath.backdrop_cells(camera_bounds, map_size)` returning **only off-map cells**. Add a small `GameMap._fill_backdrop(layer: TileMapLayer, is_road: Callable)` next to its `_fill_collision` / `_fill_perimeters` helpers; this paints those cells once for either map. Move grass/road atlas IDs to `WorldContract` from `TownContract` and **delete the redundant town wrapper**, updating town smoke tests. Town calls the shared painter with `TownContract.is_backdrop_road`; farm calls it with a predicate `cell.y == WorldContract.TRUCK_CELL.y and cell.x >= WorldContract.MAP_SIZE.x` to continue the authored east road row 9, with existing grass elsewhere.

The town's current appearance is a regression contract. HPA-863 separately owns the larger playable farm and HPA-861 refreshed artwork; this work paints camera coverage only.

## Regressions and boundaries

- Preserve existing `GameSession` guards and commands, 30-minute travel, Day 14 market confirmation, money/stamina/day rules, save format and modal input gate. Re-resolve the contact on modal submit; never pass a hardcoded cell to the domain merely because a panel is open.
- Preserve exact-cell scripted fixtures while adding the tighter, physical contact path; test both into-edge facings on each **physically reachable** contact face, wrong facings and empty-cell gaps.
- Space and hold use tile-exact raw targets even if E can reach an adjacent object. A `[Space]` preview never claims E is farming.
- No highlight override, retained occluder references, new art/SFX, new interaction framework, additional runtime or compatibility layer.

## End-to-end acceptance contract

1. **Reachability:** A GUT table derived from collision rectangles covers every **physically reachable** interactable face and **both** valid screen facings, including farm bed, bin, truck and town truck, shop, market and three villagers; exact-cell fixtures remain green. Wrong-facing or an empty-cell-gap attempt has no interaction. A focused real-input e2e smoke covers farm bed/bin/truck, town shop and at least one villager, plus one refusal. This is a deliberate breadth split: the GUT table is exhaustive, e2e is representative.
2. **Target/commands:** For any **E hint** the label, neutral/gold diamond and actual E action agree. When the bin contact overlaps a farm tile's Space preview, Space draws/acts on that tile and E independently opens Shipping. Shop purchase/upgrade, bin deposit, sleep and Day 14 market confirmation complete from the resolved contact without altering GameSession rules, save semantics or the 30-minute travel cost.
3. **Visibility:** On farm/town, an opted-in prop sprite dims in front of a real reachable player; fades only that prop, returns smoothly to alpha 1 when clear, and shows no Y-tie flicker or stale state after travel.
4. **Backdrop:** No grey at any reachable farm-camera extreme, including east truck and south-west river. The east road continues beyond the border, and camera, collision, playable cells and town scene remain unchanged. Compare a native 1920×1080 B2 frame with the attached mockup.
5. **Automation/visual checks:** Run the committed-HEAD GUT/headless verifier, GdUnit4, godot-e2e and GitHub CI. A new `tests/native_tour/hpa_743_tour.gd` reuses `rain_tour_base.gd`, boots with isolated saves/settings, drives named farm/town poses, and writes 1920×1080 PNGs to `TOUR_OUT` (E hint, wrong-facing, prop fade/restoration, east edge, south-west corner). An agent runs the native/e2e harness via the available connected command/MCP execution environment and directly inspects the captures against B2 and before/after shots. **There is no repository-specific Godot MCP and no new test runtime.** If MCP command execution/capture is unavailable, keep that acceptance item unchecked and report the evidence gap; do not call CI alone an MCP-native visual check. No human approval criterion.

