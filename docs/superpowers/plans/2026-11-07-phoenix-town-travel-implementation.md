# HPA-686 — Town map and driving: single-PR implementation plan

**Status:** Proposed; this is a planning-only draft, not verified implementation.  
**Design:** [Town map/travel design specification](../specs/2026-11-07-phoenix-town-travel-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-686/add-the-town-map-and-drive-between-farm-and-town  
**Reviewed `main`:** `736a3bc97ea00d450cb499e0296ef48899922777`.  
**Delivery:** Implement in **this same PR** after design review; one ticket -> one PR, no second implementation PR. HPA-687 already delivered art. Do not include HPA-684 diary or HPA-546 walk animation.

## Preflight — audit current assumptions before editing

Godot 4.7.1, statically typed GDScript, single GameSession and GameHud, authored FarmMap from HPA-685, strict save-state validator, three languages, no screenshot-golden gate. The shell currently loads only FarmMap, `_map` is typed `FarmMap`, `farm_view` is a direct getter, and `_process()` assumes there is always a farm view. The session currently validates shop/market cells using `WorldContract` even though those facilities must move.

Check all references before changing symbols or scenes:

```bash
grep -RInE 'WorldShell\.MapId|load_map\(|_map\.|farm_view|WorldContract\.(SHOP_CELL|MARKET_CELL|SHOP_STALL_FOOTPRINT|MARKET_FOOTPRINT|VILLAGE_SIGN_CELL)' scripts scenes tests
grep -RInE 'target_cell\(|map_camera_bounds\(|enter_map\(|talk_to\(|gift_crop\(|buy_seeds\(|buy_watering_can_upgrade\(|deposit_crop\(|trigger_harvest_finale\(' scripts tests
grep -RInE 'Seed Box|SEED BOX|ShopStall|HarvestMarket|TUTORIALS|tutorial_keys|NOT_AT_SHOP|NOT_AT_MARKET|NOT_FARM_CELL' scripts scenes tests assets/i18n/strings.csv
```

Do not change any frozen farm coordinates except the removed farm-only shop/market/truck placement. Use Godot to check that the selected farm truck location, its arrival point, and town building footprints are actually reachable; authored layout is the source of truth for coordinates, not an inferred screenshot.

## Step 1 — Session-owned location, command rules, and unit coverage

**Files:** `scripts/game/game_rules.gd`, `scripts/game/game_session.gd`, `scripts/world/world_contract.gd` (move town-only constants later), `tests/unit/test_game_rules.gd`, `tests/unit/test_game_session.gd`, `tests/gdunit/test_game_session_flows.gd`.

1. Define `GameRules.MapId { FARM, TOWN }` as the one enum shared by session and shell, add `TRAVEL_MINUTES := 30` and one success `CommandCode.TRAVELLED`. Prefer existing failure codes (`NOT_FARM_CELL`, `NOT_AT_SHOP`, `NOT_AT_SHIPPING_BIN`, `NOT_AT_BED`, `NOT_AT_MARKET`, `NOTHING_TO_INTERACT`) rather than new overlapping error enums.
2. Add private, non-persisted `GameSession._location: GameRules.MapId = FARM`. `snapshot()` exposes location; `state()` does not. `restore_state()` resets location to FARM after successful restore. Add a focused test asserting `state()` has no location key, unchanged persisted shape, snapshot is read-only, and a restored save begins at farm.
3. Add `travel_to(destination: GameRules.MapId) -> GameRules.CommandCode`. Reject active-day failures and same-location travel without mutation; on success, set location and `_time_minutes = mini(_time_minutes + 30, ACTION_CUTOFF_MINUTES)`, with no stamina debit, no tutorial completion, no day change. Test 06:00, 21:45 and 22:00 cases, round trips, a failed same-destination request, morning-summary gate, and terminal finale gate. Reuse the existing clock cap rather than building a new travel-time evaluator.
4. Guard `preview_target_action()` and the shared farm-target failure path so town coordinates cannot become valid farm actions. Both public action wrappers and low-level `hoe/plant/water/harvest` must reject TOWN. Keep successful farm budgets/effects unchanged.
5. For `buy_seeds` and `buy_watering_can_upgrade` require TOWN and `TownContract.SHOP_CELL`; for `deposit_crop` and `sleep` require FARM and their current WorldContract cells; for `trigger_harvest_finale` require TOWN, Day 14, and `TownContract.MARKET_CELL`. For `talk_to`/`gift_crop` require TOWN but keep their existing target-free signature and all gift/point semantics. Test a direct call to every moved command from the wrong map and verify state is unchanged. There is no need for a general authorization policy object.
6. Keep `_complete_finale()` shared by town market and farm sleep; no Day 15 and no ending rebalance.

**Checkpoint:** Unit tests establish that location is authoritative, a town cell overlapping a farm cell never farms, round trips work after cutoff, and the saved state shape is unchanged. Compile/update old callers of moved constants atomically with their changes; do not leave a broken intermediate commit on the PR.

## Step 2 — Author the town scene with existing art and a narrow contract

**Files:** `scripts/world/town_contract.gd` + Godot-generated UID, `scripts/world/town_map.gd` + UID, `scenes/world/town_map.tscn`, a minimal town TileSet resource if required, `scripts/world/world_math.gd`, `scripts/player/player_controller.gd`, `tests/headless/world_math_smoke.gd`, `tests/headless/world_shell_smoke.gd`.

1. Define a single ~`16x12` town grid in `TownContract` with town entrance/truck target, near-truck arrival spawn, shop, station cafe, market, Sato-san/Gen-san/Hana cells, static building footprints and camera bounds. Include a tiny `villager_at(cell)` lookup from the same data. Do not put duplicate town positions in tests or WorldShell.
2. Make `TownMap` an authored `Node2D` scene with a 16x12 paved/road TileMapLayer; an `Entities` Y-sort root; visual station/shop/cafe/market props; three existing villager sprite instances; an authored kei truck; and `StaticCollision` polygons derived from TownContract with `WorldMath.footprint_to_polygon()`. Use `town-terrain.png`, `town-props.png`, `kei-truck.png` and the existing `villagers.png`/portraits. Keep bottom-center ground contact and child shadows; use nearest filtering. No art-generation changes.
3. Give TownMap only the data WorldShell needs for placement and interaction (e.g. `entities`, `SPAWN`, `CAMERA_BOUNDS`, `MAP_SIZE`). Give FarmMap a separate truck-side arrival spawn while preserving its initial house-side `SPAWN`. Remove the temporary farm seed stall, unattended seed-box and market scene nodes/colliders; keep farm soil, shipping, bed, rivers, FX, ambience and the road. Replace/position the farm-side truck close to the existing village-road/sign area; do not duplicate the truck artwork.
4. Make `WorldMath.target_cell()` map-size-aware, and calculate camera bounds from the supplied map size. Adjust `PlayerController.enter_map()` to set current map size before updating its target; preserve projection/hitbox/speed/zoom and camera instance. Verify a town edge target is null when outside 16x12 and farm 24x20 behavior remains unchanged.
5. Add smoke assertions for exact authored scene children, map-size limits, truck/prop frames, static geometry, collision-free navigation to shop/NPCs/market/truck, and the one Y-sort root. Inspect the town at 1920x1080 rather than relying on removed visual goldens.

**Checkpoint:** TownMap can be instantiated by itself; authored tile coverage, positioning, depth and collision are visually plausible. No crop FX or second Player exists in TownMap.

## Step 3 — Wire truck travel and location-aware world interaction

**Files:** `scripts/world/world_shell.gd`, `scripts/world/farm_map.gd`, `scenes/world/farm_map.tscn`, `scripts/ui/game_hud.gd` if success feedback needs mapping, `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_commerce_panels.gd`, `tests/e2e/gameplay_day_one_test.gd`.

1. Replace `WorldShell.MapId` with `GameRules.MapId` and add the TownMap packed scene to the existing closed two-way `load_map` match. Make `_map` a narrow `Node2D` reference, with typed FarmMap/TownMap branches for `entities`, spawn and camera bounds; do **not** introduce a MapBase or duplicate child caches. Keep the same Player instance under the current map's `Entities` at index 0 with `owner = self`. The shell's `%Player` lookup and one HUD/session/camera survive both directions.
2. Preserve HPA-685 teardown on swap: cancel hold, hide prompt, neutralize target tint, close user-opened modals, detach Player, free old map, install new map at World child index 0, reparent Player, reset camera smoothing, bind farm FX if applicable, and refresh once. Keep morning summary and opening overlay session-owned as before.
3. Add an arrival-spawn parameter (or a two-map-specific decision) to `load_map` so initial farm New Game/Continue starts by the house and travel home starts by the parked farm truck. The town always arrives beside its truck. Test that neither arrival point overlaps any static collision and that the truck remains targetable to return.
4. `interact()` and `_interact_label()` use *only the active map's* contract: farm bed/shipping/truck; town truck/shop/NPCs/Day 14 market. For a villager, dispatch `_session.talk_to(id)` through the existing `_finish_social_command` and DialoguePanel; gift signal wiring is unchanged. For the truck, check the faced truck target first, call `travel_to(other_map)`, and call `load_map` **only** for `TRAVELLED`. Failure leaves the old scene intact.
5. `_process()` uses farm action preview and `farm_view.set_target_cell()` only while on FARM; on TOWN show neutral target tint and town interactions, never call farm-specific render/effects on a TownMap. `_refresh_from_session()` always renders HUD but refreshes `FarmView` and farm ambience only when the active map is FarmMap. Preserve held-action/input/modal/clock behavior from HPA-685.
6. Keep ShopPanel and Efficient Can behavior; restore staffed `Seed Shop` labels instead of self-service `Seed Box`. No new commerce screen. Do not reset the transient session location during map swaps.

**Checkpoint:** Play E on farm truck -> town, reach each NPC and shop, E on town truck -> farm, ship crops and sleep. Test direct commands cannot cross location boundaries. A repeated round trip must not duplicate Player, Camera2D, HUD signal connections, map/collider/effects nodes, or stale modals.

## Step 4 — Social tutorials, strings, and live documentation

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `scripts/ui/shop_panel.gd`, `scripts/ui/pause_panel.gd` if wording changes, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`, `tests/integration/test_phone_surfaces.gd`, `README.md`, `CLAUDE.md`.

1. Re-add table entries `talk` (successful `VILLAGER_TALKED`) and `gift` (successful `CROP_GIFTED`) to `ContentRules.TUTORIALS`. Make both relevant only while in town; the gift card also requires available harvested crops. Keep the existing ordering of farm tutorials and ensure the social cards do not obscure early farming.
2. Update shop prompt/header/tutorial/help from unattended `Seed Box` to staffed `Seed Shop`. Put every changed/new English UI key, corresponding zh_TW (Taiwan) and ja translations together in the existing CSV; do not retain obsolete temporary strings. Do not rewrite opening, diary, result or existing village dialogue (HPA-684 owns story copy).
3. Update tutorial-key assertions, localization tests and any expected snapshot-shape assertions. `SessionStateValidator` strict key validation means an old pre-release seven-key save may be rejected; keep schema transport at v4 with no compatibility path. New save/Continue, overnight summary and completed-run Continue must still work.
4. Update `README.md` gameplay/control/map/ending descriptions and `CLAUDE.md` architecture, two-map ownership, source-of-truth constants, and world interaction policy. `AGENTS.md` is a symlink to CLAUDE.md; edit CLAUDE.md only. Preserve historical design documents.

**Checkpoint:** All strings render correctly for en, zh_TW and ja at native 1920x1080. The farm no longer claims to provide a seed box or market; town cards surface only when useful.

## Step 5 — Regression tests and playable outcome verification

Focus on a small set of high-value tests, extending existing suites instead of creating a new harness.

| Test location | Required assertions |
| --- | --- |
| `tests/unit/test_game_session.gd` | Transient location, travel clock cap/zero stamina, failed-travel immutability, every map-bound command's location guard, fresh-state round-trip, town market vs farm sleep |
| `tests/unit/test_content_rules.gd` | Nine tutorial keys, town-only talk/gift relevance, successful completion, no farm social prompts |
| `tests/headless/world_math_smoke.gd` / `world_shell_smoke.gd` | 16x12 town targeting/camera, authoritative footprints, correct new farm child list, prop and collision ownership |
| `tests/integration/test_gameplay_shell.gd` | Player/session/HUD/camera identity across multiple truck trips, arrival reachability, modal/hold/prompt teardown, no duplicate signals, town E -> dialogue/gift, UI shop vs farm shipping/bed |
| `tests/integration/test_persistence_flow.gd` | After successful farm sleep, save is still v4 without location; Continue reloads farm, never town |
| `tests/e2e/gameplay_day_one_test.gd` | Extend real-keyboard flow for farm truck -> town seed shop -> back home; keep current farming and save/Continue assertions |

Prove both endings without building a giant new 14-day e2e suite:

- Keep the existing deterministic five-Turnip / 175G shipped `promising_farmer` GUT route unchanged in outcome; update its seed-purchasing steps to visit the real town shop if the route drives commerce.
- Add a deterministic route using real `GameSession` farming/shipping/travel/talk/gift commands (plus one WorldShell E/dialogue integration test) that earns a Close Friend from in-town visits, ships >=300G, reaches Day 14, and triggers `heart_of_harvest` at the town market. A short manual native playthrough must also demonstrate that social targets are physically reachable. Do not pass just by seeding a close-friend result dictionary.
- Assert that Day 14 farm-bed sleep remains a terminal fallback and that driving home after 22:00 works with no stranded player.

## Four required release gates — run after implementation, not on this docs-only draft

```bash
# 1. GUT unit/integration and headless project/world/audio smokes
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

Visually inspect town/farm at 1920x1080 and minimum 960x540, test shop/market/NPC prompts, all four travel directions (initial farm -> town -> farm; subsequent visits), 22:00 rescue trip, Y-sort/occlusion, and collision/arrival. The screenshot-golden gate was removed in PR #29; do not reintroduce it. Record exact commands/results and any unverifiable manual checks on this PR once code exists.

## Completion criteria

One PR contains the planning docs, implementation, focused test updates, translations, and handoff docs. Both maps and their interaction boundaries work end to end; no new art or audio ticket is needed for this scope. All four automated gates pass on the final implementation commit, the player can make it back from town after cutoff, and both Promising Farmer and Heart of the Harvest are reachable. Keep this draft open until those conditions are met; do not mark HPA-686 Done merely because the design was approved.
