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

## Task 1 — Red-first interaction/visual regression cases

**Files:** `tests/integration/test_gameplay_shell.gd`, `tests/unit/test_world_math.gd` (or an existing focused pure-math suite), `tests/gdunit/test_world_math.gd`, `tests/e2e/gameplay_day_one_test.gd` or one focused `tests/e2e/world_readability_test.gd`.

1. Add pure tests for near-contact selection: contact on each facing side, a wrong-facing pose, a two-tile gap, nearest candidate/tie determinism, map boundary, and the exact-cell path. Construct the poses from current world-projection and contract footprints; avoid extra literal cell maps.
2. Add GUT integration tests on *both* active maps for bed, shipping, both trucks, shop, market and each villager. For every physically accessible side, place/move the player at the reachable side of the prop, aim toward it, and assert resolver returns the **canonical contract cell**. A collision-stopped player with raw `current_target_cell()` missing the prop must still get the E prompt. Wrong-facing and two-tile-away samples must have no interactable.
3. Assert after `_process()` that a displayed E hint and neutral/gold diamond point to the same resolved cell; a real `interact()` invokes that interaction. Assert that facing away removes the hint/override and that Space still works on the raw farm cell. Preserve existing target-tint and hold-to-work tests.
4. Add regressions that open an interaction modal via a **proximity fallback** then submit the real HUD command: shop seed purchase, shop upgrade, shipping deposit, sleep, Day-14 market confirmation. Verify the command gets the contract cell, succeeds once, and retains original authoritative state/time/money/save behavior; a refusal must not mutate.
5. Add real-input e2e on **one supported platform**, using the existing app and GdUnit4 e2e integration (agent invokes through MCP): at least farm bed/bin/truck, town shop and a villager, plus one wrong-facing E attempt. Existing full-day e2e is still required. Do not add a browser or second test runtime.

**Red checkpoint:** New adjacency / modal-submit cases fail against current `main`; preexisting exact-cell/farming cases remain passing.

## Task 2 — Implement one E resolver and keep downstream commands in sync

**Files:** `scripts/world/world_math.gd`, `scripts/world/world_shell.gd`, `scripts/player/player_controller.gd`, `assets/i18n/strings.csv`, tests above.

1. Add only the pure geometry needed in `WorldMath`: projected ground-point to projected footprint polygon/edge distance and a facing-toward-contact test, using existing `WorldContract.TILE_SIZE` / projection. The proposed reach is a **one-cell near-contact** tolerance, with final threshold derived from the red tests and current collision footprints; no raycasting or physics/area registry.
2. In `WorldShell`, enumerate the known farm or town interaction cells/footprints from contracts and run a **single** `_resolve_interactable()`. First preserve valid existing exact-cell matching; then use bounded proximity + facing and choose the nearest qualified candidate. The resolver returns a small dictionary (`cell`, `label`, `action`) or empty. Do not duplicate actionable logic in `_process()`, `interact()`, and modal handlers.
3. Use the resolver for E prompt, `_prompt_anchor()`, E action, and all five HUD modal-submit commands. Do **not** recompute/guess target based on a modal's selected row. The player is stationary while the modal gate holds, so re-resolving the same facing/pose is sufficient. Continue passing that canonical target to unchanged `GameSession` guard/commands. Keep Day-14 `MarketConfirmPanel` and travel overlay behavior.
4. Add a tiny, transient interaction highlight override in `PlayerController` (or world-shell-set override of the existing `TargetHighlight`) that survives the next physics redraw and is cleared when no E candidate, when blocked by a modal or after `load_map()`. Space farming preview and its green/red tint still use the original raw cell and take priority for the farming UI.
5. Change only the E prompt label `Bed` to `Go to bed`; add `Go to bed,去睡覺,寝る` to the CSV (adjust wording if neighboring UI has a more consistent translation), run localization assertions.

**Green checkpoint:** The original one-tile Space and hold/seed flows are unchanged; E prompt and execution target are identical; all proximity E and panel-submit regressions pass. No changes to `GameSession`, `GameRules`, persistence or economy.

## Task 3 — One shared foreground-opacity mechanism for farm and town

**Files:** `scenes/world/farm_map.tscn`, `scenes/world/town_map.tscn`, `scripts/world/world_shell.gd`, `tests/integration/test_gameplay_shell.gd`; optional focused GdUnit presentation regression.

1. Opt the existing scenery roots into one `player_occluder` group **in the committed Godot scenes**. Include farm house, shipping bin, fence segments and truck; town station/shop/cafe/market and truck; other tall props that demonstrably hide the player. Keep ground/soil, crop roots and villagers out. No new source art or per-prop alpha table.
2. Use one shell helper to compare each active-map opted-in prop's drawn `Sprite2D` world bounds against the player's drawn sprite bounds; fade only when the prop truly renders in front by Y-sort and the bounds overlap. On equal Y, account for Player being index 0. Update a single shared alpha value toward an approximate 0.45–0.50 occluded goal, and return to 1.0 when clear. Prefer a bounded `move_toward` update over creating multiple tweens.
3. Apply opacity to the opt-in prop visuals, not the collision, player or session. Use the same logic after `load_map()`; no references to freed map nodes should persist. A new map begins fully opaque. Prevent per-frame alpha restart and Y-tie flicker.
4. Add GUT integration tests that place a character behind a farm house/bin/fence/truck and town building, observe fade, move clear, observe restoration; assert that a non-overlapping or behind-player prop stays opaque. Assert Y-tie deterministic behavior and map-swap reset.

**Green checkpoint:** The character is readable behind the listed scenery in both maps with no outline shader, collision change, opacity leak or flicker.

## Task 4 — Extend the farm backdrop using the existing terrain

**Files:** `scripts/world/world_math.gd`, `scripts/world/world_contract.gd`, `scripts/world/town_contract.gd`, `scripts/world/farm_map.gd`, `scenes/world/farm_map.tscn`; `scripts/world/town_map.gd` only if needed for the shared helper; GUT/contract tests.

1. Move the pure camera-corners-to-overdraw-cells code presently in `TownContract.backdrop_cells()` into one `WorldMath` helper taking camera bounds; keep `TownContract.backdrop_cells()` as the thin caller so town rendering remains identical. Tests pin camera-corner coverage in both maps.
2. Add farm `Backdrop` as the **first** `TileMapLayer`, configured with the current `terrain_tileset.tres` and same tile origin as `Ground`. `FarmMap._ready()` fills only cells outside `Rect2i(Vector2i.ZERO, WorldContract.MAP_SIZE)`, using camera coverage plus the existing one-cell margin; keep authored playable ground untouched.
3. Fill with existing grass tile; continue the existing east road from the farm's last road cells to off-map camera coverage. Derive the exit alignment from `WorldContract.TRUCK_CELL` / authored path, never a parallel hardcoded map. Keep shared terrain atlas IDs in the existing world/terrain contract. No new sprite/texture resources.
4. Add tests comparing `WorldContract.MAP_SIZE`, camera limits, static collision polygon count and farm path cells before/after; verify backdrop fills every off-map camera-visible cell and does not paint on playable cells. Smoke both map scene loads and a truck round-trip.
5. Capture real native **1920×1080** east-truck and south-west river frames. Visually compare to the ticket's **B2** before/after mockup: continuous grass instead of grey, and road continuation at the eastern exit. This check belongs to the agent's MCP-operated visual test, with screenshots attached/referenced in the PR.

**Green checkpoint:** No exposed grey at any reachable farm camera edge; town remains unchanged; no movement/collision or authored terrain regression.

## Task 5 — Full e2e and documentation closeout (same PR)

**Files:** Tests, optionally `README.md` and `CLAUDE.md` only for changed interaction controls/visual behavior; this plan/spec checklists.

1. Run headless editor import and targeted GUT while iterating:
   ```sh
   godot --headless --path . --editor --quit
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
   godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
   ```
2. After committing coherent code to this branch, run the committed-tree verifier (it archives **HEAD**, so running it before the code commit does **not** test current working changes):
   ```sh
   ./tools/verify-clean.sh
   GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
   GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
   ```
3. Through the agent's MCP-operated Godot/e2e/native desktop testing route on **one supported desktop platform**, drive the actual game with E/Space, walk along relevant walls and props, travel between maps, and capture **1920×1080** screenshots of: correct farm/town E prompt+diamond, no-prompt wrong-facing case, player hidden/faded/restored behind farm and town props, B2 east-truck camera edge and south-west river corner. Check captured UI visually against **Linear HPA-743 B2** wherever a mockup is provided; otherwise compare before/after screenshots and ensure player/props/prompt legibility. This is an **agent-performed visual verification**, not a human acceptance step or a screenshot-golden diff.
4. Record commands and results, screenshots and evidence limitations in the PR. CI must be green for the unit and godot-e2e GitHub workflows. Mark acceptance criteria complete in this document **only after verified**. Keep the PR draft until implementation evidence is complete; do not create a second implementation PR.

## Acceptance checklist (all via automated/agent verification; initially unchecked)

- [ ] Real E works on the first try from **every physically reachable side** of farm bed, bin and truck, town shop, market, truck and all three villagers; facing away or two tiles away does not activate.
- [ ] The displayed E prompt, gold highlight and dispatched contract cell always agree. Space/hold farming still uses raw tile-exact targets and existing green/red feedback.
- [ ] Shop purchase + upgrade, shipping deposit, sleep and Day-14 market confirmation work from proximity after opening their panels; authoritative session guards and saved effects remain unchanged.
- [ ] Occluding farm house, bin, fences, truck and town buildings fade smoothly only when in front/overlapping; restore to opacity 1 when clear; map swaps and Y ties do not flicker.
- [ ] Farm camera extremes—including truck/east and river/south-west—show continuous existing grass and correctly continued east road; no visible grey, no enlarged playable region, collision or camera limit changes.
- [ ] Agent visually reviews MCP/native 1920×1080 captures against **HPA-743 B2** and before/after screenshots for unmapped views, and records the evidence in this PR.
- [ ] `./tools/verify-clean.sh` passes on committed HEAD; GUT, GdUnit4 and godot-e2e suites pass, including one complete MCP-operated end-to-end path on one desktop platform; GitHub CI green.
- [ ] All new player-facing strings have English source key plus `zh_TW` and `ja` translations; no new art, SFX, save migration, physics framework, or additional runtime.

## Out of scope

HPA-861/HPA-863 world-asset generation or enlarged farm reconstruction; new interaction inventory/registry/Area2D framework; silhouette shaders; extra NPC behaviors; controller/UI redesign; changes to farming, travel minutes, economy, persistence, localization beyond the changed prompt, or 14-day finale balancing.
