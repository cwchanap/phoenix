# HPA-686 — Town map and driving: single-PR implementation plan

**Status:** Revised after the design review; **planning only**, not yet implemented or verified.  
**Design:** [Town map/travel design specification](../specs/2026-11-07-phoenix-town-travel-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-686/add-the-town-map-and-drive-between-farm-and-town  
**Reviewed `main`:** `736a3bc97ea00d450cb499e0296ef48899922777`.  
**Delivery:** Implement everything on **this same PR**. One Linear ticket -> one PR, and keep each implementation checkpoint runnable. The HPA-687 art already exists; leave HPA-684 diary and HPA-546 walk animation for their own tickets.

## Preflight — preserve current behavior and reuse deleted code

The current code is Godot 4.7.1, statically typed GDScript with `GameSession` as the only mutable gameplay authority, `WorldShell` as its only runtime owner, the HPA-685 FarmMap, strict v4 SaveFile transport and native 1080p localized UI.

The earlier plan incorrectly moved shop/market guards to TOWN in Step 1, before TownContract or the travel scene existed. That breaks runtime and many tests. **Do not implement the old Step 1–3 ordering.** Keep old farm shop/market behavior working until the **single migration commit in Step C**.

Recover reviewed *patterns*, not their old farm coordinates:

- Inspect `0d8667b^` (parent of the HPA-683 removal): `villager_at`, villager collision footprints, three `Entities/Villager*` sprites with child shadows, E-to-talk handling, and focused world/relationship tests. Port those into **TownContract/TownMap** only; do not reintroduce redundant farm target parameters on `GameSession.talk_to`/`gift_crop`.
- Inspect `c478f18^` (parent of the HPA-683 tutorial/copy removal): `talk`/`gift` ContentRules entries, relevance and their tested English/Traditional-Chinese/Japanese strings. Restore the entries and CSV rows, then adapt relevance to current location. Do not cherry-pick the whole historical commit or revert later game code.
- Use existing `town-terrain.png`, `town-props.png`, `kei-truck.png`, `villagers.png` and portraits. The decided town prop/truck render scale is **1x** (including the atlas frames); farm House stays 2x. Verify against visible ground-contact bases before fixing footprints.

Reference audit before edits:

```bash
grep -RInE 'WorldShell\.MapId|load_map\(|_map\.|farm_view|WorldContract\.(SHOP_CELL|MARKET_CELL|SHOP_STALL_FOOTPRINT|MARKET_FOOTPRINT|VILLAGE_SIGN_CELL)' scripts scenes tests
grep -RInE 'target_cell\(|map_camera_bounds\(|perimeter_footprints\(|enter_map\(|talk_to\(|gift_crop\(|buy_seeds\(|buy_watering_can_upgrade\(|deposit_crop\(|trigger_harvest_finale\(' scripts tests
grep -RInE 'Seed Box|SEED BOX|ShopStall|HarvestMarket|TUTORIALS|tutorial_keys|NOT_AT_SHOP|NOT_AT_MARKET|NOT_FARM_CELL' scripts scenes tests assets/i18n/strings.csv
```

The current farm shop/market geometry is referenced by many tests (about 70 test-site references in the review); search for all matches rather than assuming only unit tests need updates. `AGENTS.md` is a symlink to `CLAUDE.md`: edit CLAUDE.md only.

### Verification during development

For an **uncommitted working tree**, run headless import and direct smoke checks. If GUT is installed locally at `addons/gut`, run its direct command. `verify-clean.sh` does **not** see uncommitted edits: it archives `HEAD` into a temporary checkout and fetches its own GUT dependency.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
# When addons/gut is present in the working checkout:
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
```

After **each coherent committed checkpoint** run `./tools/verify-clean.sh` on that `HEAD`. Run GdUnit4/e2e when changing their suite/call sites, and rerun every release gate at the end. No red intermediate commits.

## Step A — Additive session/geometry/HUD preparation (farm behavior unchanged)

**Files:** `scripts/game/game_rules.gd`, `scripts/game/game_session.gd`, `scripts/world/town_contract.gd` + UID (initial constants only), `scripts/world/world_contract.gd`, `scripts/world/world_math.gd`, `scripts/player/player_controller.gd`, `scripts/ui/game_hud.gd`, relevant `tests/unit` / `tests/gdunit` / `tests/headless` suites.

1. Add `GameRules.MapId { FARM, TOWN }` (replacing the shell enum during integration), `TRAVEL_MINUTES := 30`, `CommandCode.TRAVELLED`. Map TRAVELLED to `""` in `GameHud.feedback_text` and to the existing `ACTION_SFX` in `_sfx_for_code` **in this same commit**. Omitting either branch makes a successful drive assert or play the cancel sound.
2. Add private `GameSession._location = FARM`, expose `location` only in `snapshot()`, leave `state()` unchanged and reset location to FARM on successful `restore_state()`. Do not change the persisted schema or validator beyond tests of the unchanged shape.
3. Add minimal `TownContract` with `MAP_SIZE := Vector2i(16, 12)`, `TRUCK_CELL` and `TRUCK_ARRIVAL`. Add farm `TRUCK_CELL` and `TRUCK_ARRIVAL` in `WorldContract` near its existing road/sign. Keep the old farm seed-box and market cells intact for now. Truck geometry is for future scene binding; this step need not yet draw a truck.
4. Add **`GameSession.travel(target_cell: Variant) -> GameRules.CommandCode`**. It chooses the opposite location implicitly, checks `_active_day_failure()` and the truck cell of the current map, returns existing `NOTHING_TO_INTERACT` for a wrong target with no mutation, and otherwise flips the location and adds `mini(time+30, 22:00)` with **no stamina cost**. Add focused tests for both directions, no remote travel, 21:45->22:00, success at 22:00, morning-summary/finale gate, and unchanged `state()` shape.
5. Put `if _location != FARM: return -1` in `GameSession._farm_index()` to cover every farm preview/action and the direct low-level commands without duplicate location branches. Leave **shop, watering-can upgrade, shipping, sleep, market and social guards unchanged** until Step C. After successful direct travel to TOWN, farm action preview naturally says NOT_FARM_CELL.
6. Thread a **required** map size through `WorldMath.target_cell(position, facing, map_size)` and `WorldMath.map_camera_bounds(map_size)`, including all tests that call them. Make `WorldContract.perimeter_footprints(map_size)` accept a required size, passing `WorldContract.MAP_SIZE` from the existing FarmMap. Pass map size into `PlayerController.enter_map(spawn, camera_bounds, map_size)`; store the active size for current targeting. Use farm size from WorldShell until TownMap exists. Never fall back silently to a default 24x20 in town.
7. Update existing tests mechanically for the required parameters and snapshot's new transient location field. This is a coherent additive change: New Game, farm shop, shipping, sleep and farm market remain playable and tested.

**Step A checkpoint:** With the working-tree commands above, confirm Godot imports, both world smokes pass and GUT passes if installed. Commit the additive changes together; run:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

Do not proceed with a red checkpoint or skip the HPA-685 map-reload regression.

## Step B — Build TownMap and wire round-trip trucks without moving commerce yet

**Files:** `scenes/world/town_map.tscn`, `scripts/world/town_map.gd` + UID, `scripts/world/town_contract.gd`, town TileSet if needed, `scenes/world/farm_map.tscn`, `scripts/world/farm_map.gd`, `scripts/world/world_shell.gd`, `tests/headless/world_shell_smoke.gd`, `tests/integration/test_gameplay_shell.gd`.

1. Author a small paved town with shop, station, cafe, market building props and truck, one `Entities` Y-sort root, and static collision with a 16x12 perimeter. Add villager *placements* in the following migration step, to keep code/test deltas focused. Source collision footprints from TownContract and keep the truck and each building's bottom-center contact matched to the **1x** atlases.
2. Add the parked truck to FarmMap at the existing road/sign side, with no new imagery. Add a free farm truck-side arrival spawn. Construct both maps' perimeter bands with the supplied map size: **never reuse the farm 24x20 perimeter on TownMap**. Preserve farm soil, ambience, harvest/action effects, bed and shipping as-is.
3. Replace `WorldShell.MapId` with the shared `GameRules.MapId`. Implement `load_map(arrived_by_truck: bool = false)` which chooses the map **from `GameSession.snapshot()["location"]`**; never accept an independent map ID. `_ready()` calls `load_map()` (farm house SPAWN); a successful E at the active truck calls `_session.travel(player.current_target_cell())` then `load_map(true)` (destination's TRUCK_ARRIVAL). A failed drive neither changes session nor swaps scene.
4. Preserve HPA-685 teardown exactly: cancel hold, close user-opened modals, clear prompt/tint, detach same Player, queue-free old map, install one new map at World index 0, reparent Player first under active `Entities`, restore `owner = self` / `%Player`, reset camera smoothing and refresh once. Keep HUD signals connected only once, and never recreate GameSession/HUD/Camera2D.
5. Switch `_map` to a narrow `Node2D` with typed `FarmMap`/`TownMap` branches, not an inherited BaseMap. A nullable typed FarmMap getter is enough for existing `farm_view` accesses. Keep `WorldShell._process()` using the ordinary session preview in **both** maps; in town it falls through to town interaction labels. Gate only `FarmView.set_target_cell/refresh`, `FarmActionEffects.play_success` and `HomesteadAmbience.render` behind `_map as FarmMap`, which is null in town.
6. During this checkpoint, intentionally retain the **old farm seed box and harvest market** as active. Round-trip driving exists but town shopping/social and market are *not* enabled yet. Update HPA-685 tests that called `load_map(MapId.FARM)` to call `load_map()`. Add one two-way truck integration test pinning same Player, Camera2D, session and HUD IDs, arrival cells, target clearing, no stale FX/modals and no duplicate HUD connections.

**Step B checkpoint:** Exercise farm E -> town truck E -> farm and verify existing farm shopping, bed and Day 14 market **still work**. Run working-tree headless/GUT commands above, then commit and run:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

This deliberate temporary town (scenery + travel, but no residents/commerce) is an intermediate state only; it must not remain as the final PR.

## Step C — Atomic town migration: shop, market, villagers, tutorials and tests

**Do all Step C edits together in one coherent commit**, because moving a command guard to TOWN before updating shell and its tests would break gameplay. Do not land isolated red guard changes.

**Files:** `scripts/game/game_session.gd`, `scripts/world/town_contract.gd`, `scripts/world/world_contract.gd`, `scripts/world/world_shell.gd`, `scenes/world/farm_map.tscn`, `scenes/world/town_map.tscn`, `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `scripts/ui/shop_panel.gd`, other affected UI and every referencing test.

1. Move shop/upgrade target guards from `WorldContract.SHOP_CELL` to **TOWN + `TownContract.SHOP_CELL`**; move the Day 14 market to **TOWN + `TownContract.MARKET_CELL`**. Shipping remains **FARM + WorldContract.SHIPPING_CELL**; bed/sleep **FARM + WorldContract.BED_CELL**. `GameSession.talk_to`/`gift_crop` require **TOWN** but keep their existing target-free signatures. These are domain checks, not just shell UI filtering. Keep `_complete_finale()` shared; Day 14 farm bed remains terminal fallback.
2. Remove the temporary farm seed box/stall and farm market scene nodes, geometry, collisions and interact labels. Do not remove farm shipping/bed or any shared art. On TownMap, use the same existing ShopPanel and upgrade controls, Sato-san shop prompt, and the existing market interaction. Town E-facing cells must map to their TownContract target IDs.
3. Restore three `Entities/Villager*` node/sprite/shadow patterns from **`0d8667b^`** and villager lookup/interaction logic into **TownMap/TownContract**. Adapt their actual cells/footprints to the current authored town, not the retired farm positions. Wire E to `_session.talk_to(villager_id)` via existing `_finish_social_command()`; keep `hud.gift_requested` and DialoguePanel as-is. Restore useful tests from history but not old farm geometry assertions.
4. Restore `talk` and `gift` tutorial entries and existing EN/zh_TW/ja translations from **`c478f18^`**. Make talk/gift relevant only in TOWN and gifting also require harvested inventory. **Also gate `&"buy_seeds"` on `snapshot()["location"] == GameRules.MapId.TOWN`**, preserving its `day >= 2` and sufficient-money checks. A Day 2 player on the farm must not receive a face-the-counter prompt before reaching town. Update `tests/unit/test_content_rules.gd` to assert that the same Day 2 snapshot shows no Reinvest card on FARM and does show it on TOWN. Keep `GameSession._commit()` as the single completion seam.
   
   Restore staffed shop copy (`Seed Shop` rather than `Seed Box`), including its existing reviewed translations. **Explicitly add CSV English keys + `zh_TW`/`ja` translations** for the two truck prompts `Drive to town` and `Drive home`, the `Seed Shop` prompt, and the updated `PausePanel` E-key help `Talk, shop, bin, bed, truck`; replace the old `Seed box, bin, bed` help row. The CSV header is `keys,zh_TW,ja`, so the English string is the key rather than a separate `en` column. The existing localization test only enumerates rules strings, **not** UI strings in `WorldShell`/`PausePanel`: add explicit `tr()` assertions in `tests/unit/test_localisation.gd` for all four new/changed UI keys in both locales, alongside existing panel help tests.
5. Update **all** moved-shop/market references found in the preflight grep: GUT unit tests, `test_gameplay_shell.gd`, `test_finale_cue.gd`, `test_persistence_flow.gd`, two headless smokes, e2e Day 1, and any other caller. Use **one** `_drive_to_town(session)` unit-test helper for real domain commerce scenarios; use the real truck E and map swap in shell/e2e tests, and return home before testing farm-only commands. Update `_purchase_upgrade(session)` and its callers so the ordinary upgrade tests really buy at `TownContract.SHOP_CELL` while in town. Account for 30-minute drive effects on time assertions and pinned gameplay routes.
   
   **Special-case the existing throughput benchmark, not the production code:** `tests/unit/test_game_session.gd::test_balance_gate_two_hundred_gold_buys_real_throughput_by_day_nine` (helpers `_benchmark_session`, `_run_benchmark_route`, currently ~lines 1961–2126) is a prepared fixture meant to isolate stamina throughput, not seed-shop accessibility. For that benchmark **only**, initialize validated `state()` fields with `money = 0` and `watering_can_upgraded = true` in the upgraded fixture (the 200G cost has been accounted for), versus `money = 200` and `watering_can_upgraded = false` in the baseline; do not call `_purchase_upgrade` from this fixture. Drop its obsolete Day 1 `WorldContract.SHOP_CELL` detour/stand and reset the first-crop index to the same farm-only route in both cases. Recalculate the `travel_minutes` and `time_minutes` exact assertions from the new stand sequence, and preserve the Day 9 **6 vs 10 pumpkins**, **840G vs 1400G shipped**, and **+360G final money** assertions. Actual travel/purchase timing belongs to the separate real truck/shop command tests, rather than contaminating this balance test. Do not keep stale WorldContract shop/market constants or alias nodes solely to pass outdated tests.
6. Restore the nine-key tutorial tests and new save/Continue round trip. Add regression coverage for a Day 2 farm snapshot with enough money that **does not** surface Reinvest before travel, versus a town snapshot that does. Check `Drive to town`, `Drive home`, `Seed Shop`, and `Talk, shop, bin, bed, truck` against `zh_TW` and `ja` translation output and rendered shop/Pause surfaces. Strict validation can reject pre-release seven-key saves; do not write a migration, schema bump, or fallback.

**Step C checkpoint:** Verify both map-only interactions (including direct session calls from the wrong map), plus a real E-to-dialogue + gift UI flow. Run working-tree headless/GUT commands above and **both** other affected test suites before committing; then commit and rerun:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

Do not defer broken integration/visual feedback to Step D.

## Step D — Deterministic paths, minimal reachability test, live docs

**Files:** Existing `tests/unit/test_game_session.gd`, `tests/unit/test_content_rules.gd`, `tests/headless/world_math_smoke.gd`, `tests/headless/world_shell_smoke.gd`, `tests/integration/test_gameplay_shell.gd` / `test_persistence_flow.gd`, `tests/e2e/gameplay_day_one_test.gd`, `README.md`, `CLAUDE.md`.

1. Add one small **flood-fill reachability test** for the authored town and farm truck: start from `TRUCK_ARRIVAL`, explore in-bounds orthogonally adjacent logical cells that do not overlap contract building/truck/perimeter footprints, considering the player half-extent. For every shop/NPC/market/truck target, assert that at least one adjacent stand cell reachable from the start faces it using `WorldMath.TARGET_OFFSETS`. Assert farm initial spawn and both truck arrival cells do not collide. No new pathfinder runtime or scripted held-walk scenario for each target; keep a small real WorldShell E interaction regression to verify dispatch.
2. Prove the **175G shipped/Promising** route with the same five turnips and updated town shop trip(s), without changing the achieved outcome. Update its timing expectations for drives; farm can still sleep at Day 14.
3. Add a deterministic real-command route to **Heart of the Harvest**: deliver >=300G of shipped crops, visit town on at least three days, talk to Hana and give a favourite **Turnip** on each of those days (1+5 points/day; 18 => Close Friend), reach Day 14 and trigger the **town** market. Use existing weather injection or real production commands to keep farming deterministic; do not seed the relationship dictionary, skip gifting or invent a special ending path. The daytime travel budget, startup money and seed inventory must remain valid.
4. Extend the existing real-keyboard Day 1 godot-e2e to drive to the town shop, buy seeds and return before farming/overnight save. Do not add a 14-day GUI e2e; GUT handles the long deterministic route.
5. Assert `GameSession.state()` excludes location, valid fresh v4 saves round-trip, and Continue begins at farm; pending morning summaries gate travel, completed-run Continue still displays result. Assert map reload identity, correct map-size/perimeter targeting and successful `TRAVELLED`'s no-toast/ACTION_SFX behavior. Keep the separate Day 9 watering-can throughput balance gate intact after removing its obsolete farm shop detour; real town shopping/travel regressions cover the new location and time cost.
6. Update `README.md` with current controls, two maps and real available social/market location. Update `CLAUDE.md` ownership, map contracts, transient location and game rules; do **not** edit the `AGENTS.md` symlink or frozen historic specs. Ensure EN/zh_TW/ja strings are complete and render at 1920x1080.
7. **Accepted interim weather limitation:** Farm-owned `HomesteadAmbience` rain streaks/river ripples are absent from town, but HUD rainy tint, rain/river audio and the existing music continue. No separate weather/audio task inside this PR. Visual inspection must confirm it is an understandable interim result, not claim parity.

**Step D checkpoint:** With a committed implementation, run all four final release gates below plus 1080p native visual checks of town prop scale (1x), camera bounds, occlusion, street collision, contextual hints and truck access. A deterministic flood-fill establishes contract reachability; the native visual check is for appearance and physics feel.

## Four final release gates — do not claim they pass on a docs-only PR

```bash
# 1. Clean Git HEAD archive: GUT unit/integration, project/world smokes, audio
./tools/verify-clean.sh

# 2. GdUnit4
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c

# 3. godot-e2e
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c

# 4. Godot import and unsigned macOS export
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record the exact commit SHA, results and any unverified human checks in PR #38 after running them. Screenshot goldens were removed in PR #29; do not regenerate them.

## Completion criteria

This **one PR** holds the design, implementation, focused tests, localized copy and live docs. All committed checkpoints are green; truck travel cannot be initiated off-target, cannot strand the player after 22:00, and cannot desynchronize the session and rendered map. The town's shop/social/market and farm's crops/shipping/bed each reject inappropriate direct session calls. The current five-turnip 175G Promising route and the real three-day friendship + >=300G shipped Heart route both pass; all four release gates and a native 1080p visual inspection are recorded. HPA-686 stays open until implementation is merged.
