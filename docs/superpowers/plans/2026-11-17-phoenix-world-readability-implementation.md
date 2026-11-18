# HPA-743 — Make the world easy to use and read: implementation plan

**Status:** Proposed, documentation-only draft. Implementation and verification are **not done**.  
**Linear issue:** https://linear.app/cwchanap/issue/HPA-743/make-the-world-easy-to-use-and-read  
**Design:** [2026-11-17 world-readability spec](../specs/2026-11-17-phoenix-world-readability-design.md)  
**Inspected base:** `cwchanap/phoenix` `main` at `39a25b2be357a121fe5d715ed347028cacdb347d`.  
**Delivery:** **One Linear ticket, one draft PR**. Add the implementation, tests, visual evidence and final documentation to **this same PR**. Do not create follow-up code PRs for parts of HPA-743. No new image art or SFX is needed; HPA-861/HPA-863 separately own the refreshed world artwork/map.

## Preflight: what already exists

- `scripts/world/world_shell.gd` currently reads `player.current_target_cell()` for the farming preview, E prompt/dispatch and again for five modal callbacks (buy, watering-can upgrade, deposit, sleep, market confirm). All five callbacks need the same **resolved** contract cell as E, or a panel can open but its domain command can still be rejected.
- `scripts/player/player_controller.gd` owns the raw diamond highlight and `WorldMath.target_cell()`; `Space` / hold farming must continue to use the raw cell, not the E resolver.
- `WorldContract` / `TownContract` hold interactable cells, collision footprints and camera bounds. `FarmMap` and `TownMap` build collision from those constants; `GameSession` must not change.
- `TownContract.backdrop_cells()` and `TownMap._ready()` already calculate/paint non-playable camera coverage. Farm needs the same behavior, not another map size or camera.
- Farm/town scenes already have Y-sorted `Entities` children with visual `Sprite2D` nodes. Player is inserted as first `Entities` child after each map swap; a prop at equal Y is drawn in front.
- GUT regression helpers `tests/integration/test_gameplay_shell.gd:_place_target()` and e2e `_stand_at_target()` currently teleport to an exact-cell stand location. Keep those existing checks and **add reachable, collision-stop proximity scenarios**, rather than loosening interaction reach to satisfy teleports. `tests/e2e/gameplay_day_one_test.gd` already drives input on the running game through godot-e2e.
- Localization uses `assets/i18n/strings.csv` columns `keys,zh_TW,ja`; the English text *is* the key.

## Task 1 — Red-first focused contact and gameplay regressions

**Files:** `tests/integration/test_gameplay_shell.gd`, `tests/gdunit/test_world_math.gd` (one pure-math suite, **not** nonexistent `tests/unit/test_world_math.gd`), and existing `tests/headless/world_math_smoke.gd` only when an existing invariant needs updating.

1. In **one** GdUnit pure-math test suite, test `WorldMath` closest projected-polygon contact, `dot > 0` half-plane direction and the strict near-contact gap boundary. Use `WorldMath.footprint_to_polygon()` and `Geometry2D.get_closest_point_to_segment()` in implementation; no custom polygon-distance algorithm or cone parameter.
2. Add a **table-driven GUT integration suite** for `WorldContract.interact_regions()` and `TownContract.interact_regions()`. Derive sample contact positions and approach directions from each collision footprint's **projected four sides**, rejecting faces actually blocked by the map/perimeter/other props. For **every physically reachable side**, cover its **two** positive-dot screen facings, both negative-dot facings, a full empty-cell-gap refusal and nearest-candidate/tie determinism. Include house-door slice for Bed (not the other house walls), farm truck/bin, and town truck/shop/market/all villagers. Drive a collision-stop pose, not just remote teleports.
3. Keep existing exact-target teleport-fixture tests (e.g. `_place_target()`) intact; those are an explicit compatibility path and can be farther than the physical 14px reach. Add a case where raw target misses the prop but valid physical contact opens it on the first E. Ensure `WorldShell` resolves back to the **canonical contract cell**, not a nearby farm/town grid cell.
4. For E hint cases, assert `_process()` shows the E label, gold diamond and anchored cell that `interact()` actually opens. Add the **shipping-bin overlap** test: touching the bin with LEFT facing while raw target is `(9,14)` gives a Space farm hint/green-red raw diamond, but E opens Shipping; pressing Space still works that farm tile. Assert wrong-facing E refuses without state mutation.
5. From physical fallback contacts, open the real shop/upgrade, shipping, sleep and Day-14 market-confirmation panels and **submit** their existing actions. Check canonical-cell ownership through one successful domain command each, original money/time/day/save effects, and no mutations on refusals. Keep the Day-14 market confirmation and travel gate regression coverage.

**RED checkpoint:** New contact and panel-submit GUT tests reproduce the UAT bug on old behavior. Do **not** add slow Godot e2e before the core resolver is green. Keep all existing exact-cell and Space/hold tests.

## Task 2 — Contract-defined interaction regions and one E resolver

**Files:** `scripts/world/world_contract.gd`, `scripts/world/town_contract.gd`, `scripts/world/world_math.gd`, `scripts/world/world_shell.gd`, `assets/i18n/strings.csv`; GUT/GdUnit tests above. **No `PlayerController` modifications needed.**

1. Add `WorldContract.interact_regions()` and `TownContract.interact_regions()` mapping canonical contract cells to already-defined **collision footprint** rects; derive `WorldContract.BED_CELL`'s reachable door region as `HOUSE_FOOTPRINT.intersection(Rect2(BED_CELL, Vector2.ONE))` (currently `Rect2(12, 7, 1, 0.25)`). Pair town villager cells with existing `VILLAGER_FOOTPRINTS`. Do not duplicate these constants in `WorldShell`.
2. Add a tiny `WorldMath.closest_contact(world_ground_position, collision_rect)` helper implemented using existing `footprint_to_polygon` and `Geometry2D.get_closest_point_to_segment` for its four projected edges. The fallback's initial reach is **14 projected/world px**, not 32; require `facing_direction.dot(contact_direction) > 0` with **no angle cone** and no zero-distance special path. Tune only to satisfy both valid into-edge facings at real collision stops while rejecting one empty cell gap.
3. `WorldShell._resolve_interactable()` tries the exact `player.current_target_cell()` through existing `_interactable(cell)` first, then contract region candidates by nearest valid physical contact, with stable ordering for ties; it returns `{cell, label, action}` or empty. Use `WorldShell._interactable()` for the existing action routing instead of duplicating its switch or adding a registry.
4. Route `_process()` E hints, `_prompt_anchor(resolved.cell)`, `interact()` and **all five** modal submit handlers through this same resolver. Re-resolve the frozen pose on submit (input gate already freezes the Player); **do not** hardcode `TownContract.SHOP_CELL` etc. into session calls. Session guard, cost and save behavior remain authoritative.
5. For an E hint, in `WorldShell._process()` set the existing `player.target_highlight.points = WorldMath.cell_diamond(resolved.cell)` **after** Player's physics target paint; the world-shell frame pass is last before draw. No highlight override field or explicit map/modal reset. When a farming hint has priority, show its original Space raw-target diamond; E still independently uses `_resolve_interactable()` at the bin boundary. Keep an initial highlight from `enter_map()` before any physics tick.
6. Replace `Bed,床,ベッド` at existing `assets/i18n/strings.csv` row ~327 with **one** `Go to bed,去睡覺,寝る` entry. The E hint in `_interactable()` uses the new English key. Verify all three languages; do not append a duplicate key.

**GREEN checkpoint:** Same session/gameplay rules, modal submissions succeed from a real contact, no E false positives, Space/hold remain tile-exact, and no extra PlayerController state.

## Task 3 — Shared per-sprite foreground fade, no cached nodes

**Files:** `scenes/world/farm_map.tscn`, `scenes/world/town_map.tscn`, `scripts/world/world_shell.gd`, `tests/integration/test_gameplay_shell.gd`.

1. Opt relevant static Y-sorted `Entities` roots into one `player_occluder` Godot group: farm house/bin/fences/truck and genuinely tall props; town buildings/truck and occluding scenery. Keep crops, villagers, harvest FX/pops and player out, so this fade does not interfere with existing alpha effects.
2. In one `WorldShell` presentation helper, `get_tree().get_nodes_in_group("player_occluder")` **per frame**, restricted to active map roots. Compute transformed `Sprite2D.get_rect()` bounds versus the player's drawn sprite bounds. Fade only if bounds overlap and `prop.global_position.y >= player.global_position.y` (Player is index 0 for exact Y ties).
3. Use one constant `FADE_ALPHA` around 0.45–0.50, but let **each prop's own** `Sprite2D.self_modulate.a` track opacity via `move_toward` toward FADE_ALPHA or 1.0. No shared mutable alpha, new shader, per-prop tuning table, tween registry, stored node references or map-replacement cleanup.
4. Test farm house/bin/fence/truck and town building fade/restoration from reachable poses, non-overlapping prop unchanged, stable tie and opacity 1 on new map after travel. Include a case proving a crop/harvest effect is never faded.

**GREEN checkpoint:** Only covering foreground props fade in both maps, with no flicker or leaked state across map replacement.

## Task 4 — Shared map backdrop painter and farm edge

**Files:** `scripts/world/world_math.gd`, `scripts/world/game_map.gd`, `scripts/world/world_contract.gd`, `scripts/world/town_contract.gd`, `scripts/world/town_map.gd`, `scripts/world/farm_map.gd`, `scenes/world/farm_map.tscn`, `tests/headless/world_shell_smoke.gd`, GUT tests.

1. Factor the pure camera-corners → overdraw cells calculation from `TownContract.backdrop_cells()` into `WorldMath.backdrop_cells(camera_bounds, map_size)` returning **only the off-map cells**. Preserve existing one-cell coverage margin and current town appearance. Remove `TownContract.backdrop_cells()` **rather than adding a redundant thin wrapper**; update its existing `world_shell_smoke.gd` caller at ~1100.
2. Add `GameMap._fill_backdrop(layer: TileMapLayer, is_road: Callable)` next to `_fill_collision()` and `_fill_perimeters()`. Both maps call this helper rather than duplicate the TileMapLayer painting loop. Move existing `TownContract.BACKDROP_GRASS_TILE` and `BACKDROP_ROAD_TILE` to common `WorldContract` and update the town reference.
3. Insert FarmMap `Backdrop` as the first `TileMapLayer`, with the existing `terrain_tileset.tres` and Ground's projected origin; call `_fill_backdrop` from `FarmMap._ready()`. Outside `WorldContract.MAP_SIZE`, fill grass and continue the authored east road with `cell.y == WorldContract.TRUCK_CELL.y and cell.x >= WorldContract.MAP_SIZE.x` (authored Paths road row is y=9). Town keeps `TownContract.is_backdrop_road`.
4. Headless/GUT verifies all off-map camera cells filled, none inside playable map, shared tile atlas correct, camera and collision unchanged, town visual/road predicate unchanged, and both maps surviving a truck round-trip. Add assertions for the east edge and south-west river corner, then perform native B2 screenshot comparison in Task 5.

**GREEN checkpoint:** The farm has no grey camera-corner triangles; both maps share a tiny backdrop painter while their authored playable surfaces remain intact.

## Task 5 — Representative e2e, named native tour, CI and evidence (same PR)

**Files:** `tests/e2e/world_readability_test.gd` or focused additions to `gameplay_day_one_test.gd`; **new** `tests/native_tour/hpa_743_tour.gd` extending the already-shipped `tests/native_tour/rain_tour_base.gd`; docs/README/CLAUDE.md only as needed.

1. **After Task 2 is green**, add focused real-input Godot e2e smoke on **one supported desktop platform**: farm bed/bin/truck, town shop and at least one villager, plus a wrong-facing E refusal. The GUT derived-pose table is exhaustive across **every reachable face × both valid facings**; e2e intentionally samples **five** interactables plus refusal. Do not pretend the e2e sample itself covers every side. Preserve the existing full-day e2e and travel overlay waits.
2. Add `tests/native_tour/hpa_743_tour.gd`, reuse `rain_tour_base.gd`'s native app bootstrap, `PHOENIX_SAVE_PATH` / `PHOENIX_SETTINGS_PATH` isolation, key input and window-handling helpers. At named contract-derived farm/town contact poses, check E prompt/gold diamond, wrong-facing no-prompt, faded/restored house/bin/fence/truck and town props, the farm truck/east edge and south-west river. Write **1920×1080 PNGs** with `root.get_texture().get_image().save_png()` into `TOUR_OUT`, following `rain_tour.gd` and `hpa_775_day_tour.gd`; no new browser, rendering or test runtime.
3. Agent runs the repo's existing GdUnit4 and native-tour commands through an **available MCP-connected command/desktop execution environment**, and visually opens its saved PNGs for B2 vs actual east edge plus before/after non-mockup views. **There is no repo-specific Godot MCP.** If the execution/capture connection is absent, report that as evidence not verified and leave this criterion unchecked; GitHub CI alone is not the claimed MCP visual check. No human sign-off step.
4. Iterate with Godot import, focused GUT and headless smoke:
   ```sh
   godot --headless --path . --editor --quit
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
   godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
   ```
5. **After committing implementation** to this branch, run `./tools/verify-clean.sh` (it archives **committed HEAD**), `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c`; require GitHub unit and e2e CI green. Attach command results and images to PR #46. Mark acceptance as done only with captured evidence. Keep all HPA-743 work in **this one PR**.

**GREEN checkpoint:** A documented real desktop e2e path, visual comparison with attached Linear B2, committed-head verifier and CI results, all linked to PR #46 without human acceptance.

## Acceptance checklist (automated and agent verification; all unchecked until implementation)

- [ ] Collision-derived **GUT table** covers **every physically reachable face × both positive-dot screen facings** for bed, bin, farm/town truck, shop, market and three villagers; both wrong facings and an empty-cell gap refuse. Existing exact-cell fixtures still work.
- [ ] A real near-contact E opens each object on its canonical cell, and a visible **E-labeled** prompt, gold diamond and E command agree. When Space preview and bin E overlap, Space is tile-exact and E opens the bin; both regression tests pass.
- [ ] All five modal-submit callbacks (shop, upgrade, deposit, sleep, market) re-resolve canonical cells from the frozen pose; existing session guards, time, money, save and travel are unchanged; `Bed` translation row is **replaced**, not duplicated.
- [ ] Both maps fade only occluding opt-in sprites using their own `self_modulate.a`, restore to full opacity when clear, and preserve Y-tie order, crops/FX and map-swap resets.
- [ ] GameMap shared backdrop painter fills farm camera corner triangles with grass/continued east road, paints no playable cells, and preserves town appearance, collisions and camera limits.
- [ ] Focused **Godot e2e smoke** through the actual game covers bed, bin, farm truck, town shop, one villager and wrong-facing E on **one** desktop platform; existing full-day e2e remains green.
- [ ] Agent drives `tests/native_tour/hpa_743_tour.gd` through MCP-connected execution, saves 1920×1080 captures to `TOUR_OUT` and visually checks east truck against **Linear B2** plus screenshot comparisons of town/farm prompts, fade/restoration and south-west edge; evidence linked in PR. If MCP execution is unavailable, mark **not verified**, not passing.
- [ ] Committed `./tools/verify-clean.sh`, GUT, GdUnit4, godot-e2e and GitHub CI pass. No human acceptance, new art/SFX, save schema change, or speculative framework.

## Out of scope

HPA-861/HPA-863 world-asset generation or enlarged farm reconstruction; new interaction inventory/registry/Area2D framework; silhouette shaders; extra NPC behaviors; controller/UI redesign; changes to farming, travel minutes, economy, persistence, localization beyond the changed prompt, or 14-day finale balancing.
