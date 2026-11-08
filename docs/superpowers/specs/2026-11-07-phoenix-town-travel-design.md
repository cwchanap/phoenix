# HPA-686 — Town map and driving: design specification

**Status:** Proposed, revised after the November 7 design review; planning only. No implementation or verification has been run.  
**Linear:** https://linear.app/cwchanap/issue/HPA-686/add-the-town-map-and-drive-between-farm-and-town  
**Reviewed baseline:** `main` at `736a3bc97ea00d450cb499e0296ef48899922777` (HPA-685 FarmMap extraction).  
**Dependencies:** HPA-683 and HPA-685 are Done; HPA-687 town/kei-truck runtime atlases are committed. HPA-684 diary/copy and HPA-546 walk animation remain separate.  
**Delivery:** One issue, one PR. Use this draft for design and then implement on this **same PR**, with green intermediate commits.

## Player-visible outcome

The farm is home, but its unattended seed box and Day 14 market move to town. The player faces a parked kei truck, presses E, and spends up to 30 in-game minutes driving to a compact town. There they can buy seeds and the watering-can upgrade, talk/gift to Sato-san, Gen-san and Hana, and attend the Day 14 market. They can drive home, ship produce and sleep even at 22:00: they cannot get stranded in town.

The shipping-based Promising Farmer route (five turnips -> 175G shipped) and the real town-social Heart of the Harvest route (Close Friend plus >=300G shipped) must both remain reachable.

## Current main and constraints

- `WorldShell.load_map(MapId.FARM)` already swaps a single FarmMap while retaining Player/Camera2D, GameSession, GameHud and target highlight. It cancels holds, clears stale prompts/tints and closes user-opened modals. The current `farm_view` getter and `_process()` assume a farm scene; only those calls need town-safe typing.
- `FarmMap` owns farm terrain, Y-sorted `Entities`, soil, effects, ambience and collisions. `WorldContract` still holds temporary farm shop/market geometry.
- `GameSession` is the sole mutable gameplay authority, with `state()` for strict persistence and `snapshot()` for presentation. It has existing farm, shopping, shipping, social, sleep and finale commands; social commands are target-free.
- `WorldMath.target_cell()` and `WorldMath.map_camera_bounds()` currently assume the farm dimensions. Farm perimeter collision comes from `WorldContract.perimeter_footprints()`. Town requires all three geometry operations to accept its 16x12 size explicitly.
- `ContentRules.TUTORIALS` has seven keys after HPA-683 removed talk/gift; `SessionStateValidator` requires the exact keys. The historic removed implementation is available in commits `0d8667b^` (villager entities/collisions/interaction/test patterns) and `c478f18^` (social tutorials and EN/zh_TW/ja strings).
- Art already exists: `town-terrain.png` (three 64x32 diamonds), `town-props.png` (four 96x96 frames), `kei-truck.png` (two 96x96 views), `villagers.png` and portraits. Use `assets/sprites/town-art-source.md` as frame and ground-contact reference. Do not generate art or audio.

Godot 4.7.1, statically typed GDScript, single WorldShell session/HUD holder, existing 14-day economy, City Pop UI, and three translations stay intact. No generic map framework, compatibility shim, or screenshot goldens.

## Decision 1 — One authored TownMap, not a map framework

Add `scenes/world/town_map.tscn`, `scripts/world/town_map.gd`, `scripts/world/town_contract.gd` and a town TileSet only if the existing atlas needs one.

- `TownContract` is the one source for `MAP_SIZE := Vector2i(16, 12)`, town truck target and `TRUCK_ARRIVAL`, shop/market/villager target cells, building/collision footprints and camera bounds. Restore the previously reviewed villager node/shadow/sprite and `villager_at()` patterns from `0d8667b^`, but **place all town coordinates in TownContract**, not old farm constants. Sato-san stands by the shop, Gen-san by the road, Hana by the cafe. Include a small station.
- `TownMap` owns authored ground/road, one Y-sorted `Entities` root, town props, villager sprites, truck, static collision and its perimeter; it owns no player, camera, gameplay session, farm soil or farm effects. WorldShell keeps the single existing Player/Camera2D and GameHud.
- **Scale decision:** Render the 96x96 town building and truck atlas frames at **1x native pixel scale** in the compact 16x12 town, with bottom-center ground-contact roots and child shadows; villager sprites also remain 1x. This is intentionally smaller than the already-committed 2x farm House, which remains unchanged. Design shop/station/cafe/market/truck footprints against these 1x visible bases; then confirm that their appearance, clearance and camera framing work at 1080p. No speculative scale-adjustment logic.
- Extend `WorldMath.target_cell(position, facing, map_size)` and `WorldMath.map_camera_bounds(map_size)` with **required** `map_size` parameters, including every test caller. There must be no default farm size that can silently give the town 24x20 target bounds. Make perimeter footprints size-aware too: `WorldContract.perimeter_footprints(map_size)` takes a required argument and is used by FarmMap with `WorldContract.MAP_SIZE` and TownMap with `TownContract.MAP_SIZE` (or factor the exact shared band math into WorldMath without duplicate literals). `PlayerController.enter_map(spawn, camera_bounds, map_size)` retains the current Camera2D, hitbox, projection, zoom and movement rules.
- `GameRules.MapId { FARM, TOWN }` replaces the shell-local enum. WorldShell selects explicitly between two PackedScenes; no `BaseMap`, map registry or scene factory. Keep a narrow nullable `FarmMap` accessor to call crop rendering, FX and ambience only when the active map actually is a farm.

## Decision 2 — One authoritative *transient* session location

`GameSession` owns a private `_location: GameRules.MapId = FARM`. Add location to the read-only `snapshot()`, **not** `state()` or `SaveFile`. On successful `restore_state()` reset to FARM. Sleep is available only on the farm; Continue always loads the initial farm spawn. A town market finale saves a completed run without a location field; completed Continue still opens results, never a town scene. No schema bump/migration.

`WorldShell.load_map(arrived_by_truck: bool = false)` **reads** the destination from `_session.snapshot()["location"]` rather than accepting a map ID; it cannot install a town on a farm session. Initial New Game/Continue calls `load_map()`, placing the player at the house-side FarmMap `SPAWN`. An accepted truck trip calls `load_map(true)`, choosing the active destination map's `TRUCK_ARRIVAL`. Preserve the same Player/Camera2D, session, HUD, modal teardown, tint reset, first-child map order and stable `World/%Player` lookup. Adapt HPA-685's tests that currently call `load_map(MapId.FARM)` to call `load_map()` and check the session location.

## Decision 3 — Truck-target travel, fixed time and 22:00 safety

**`GameSession.travel(target_cell: Variant) -> GameRules.CommandCode`** is the single travel command. The destination is always the **other** map. It first enforces `_active_day_failure()`, then validates `target_cell` against `WorldContract.TRUCK_CELL` or `TownContract.TRUCK_CELL` depending on its current location. Any other target returns existing `NOTHING_TO_INTERACT` and leaves session, time and map unchanged. The shell's E handler calls it only at the active truck target, and reloads the map only on successful `TRAVELLED`. Unlike `travel_to(destination)`, there is no remote-travel loophole and no same-location refusal branch.

Add `GameRules.TRAVEL_MINUTES := 30`. A successful trip sets `_time_minutes = mini(_time_minutes + 30, GameRules.ACTION_CUTOFF_MINUTES)` and flips `_location`, with no stamina charge and no day advancement. At 21:45 arrival is 22:00; at 22:00 it still succeeds at 22:00. Farm work still refuses late actions, but drive/shop/social/shipping/sleep and finale remain available at 22:00 on their proper maps. Do not add a driving animation or transition UI.

`GameHud.feedback_text(TRAVELLED)` must explicitly return `""` (no red toast) and `_sfx_for_code(TRAVELLED)` must return the **existing** `ACTION_SFX`. Otherwise `feedback_text`'s unknown-code assertion or the default `CANCEL_SFX` would turn a successful drive into a crash or refusal sound.

## Decision 4 — One coherent location and interaction policy

WorldShell resolves visible interaction targets from the active map contract. GameSession validates the **current location** on all place-bound commands, and validates the appropriate target cell for every target-based command. Keep `talk_to(villager_id)` and `gift_crop(villager_id, crop_kind)` target-free: TownMap/WorldShell resolves the actual villager the player faces; GameSession requires TOWN. No extra spatial parameter or interaction framework.

| Action | Farm | Town | Authoritative guard |
| --- | --- | --- | --- |
| Farming and action preview | Yes | No | FARM via `_farm_index()`; existing crop/action validation |
| Shipping bin | Yes | No | FARM + `WorldContract.SHIPPING_CELL` |
| Bed/sleep | Yes | No | FARM + `WorldContract.BED_CELL` |
| Shop / Efficient Can | No | Yes | TOWN + `TownContract.SHOP_CELL` |
| Talk/gift | No | Yes | TOWN + existing social rules |
| Day 14 market | No | Yes | TOWN + `TownContract.MARKET_CELL` + day |
| Truck E / drive | Yes | Yes | Current map's truck cell, checked in `GameSession.travel(target_cell)` |

Put the farm-only guard in `GameSession._farm_index()` (return -1 in town) so preview, `apply_target_action()` and direct hoe/plant/water/harvest all share it. In town `preview_target_action()` naturally returns `NOT_FARM_CELL`, allowing the existing `WorldShell._process()` fallback to show neutral/town interaction prompts. Gate **only** the actual farm presentation calls (`farm_view.set_target_cell`, `farm_view.refresh`, `ambience.render`, `effects.play_success`) behind a typed `_map as FarmMap` check; no second gameplay branch or duplicate cached map reference.

Remove farm-side seed box/stall and market *only after* the town scene/travel is functional; leave farm shipping and bed. Place a truck by the farm road/sign; use `WorldContract.TRUCK_CELL`, footprint and `TRUCK_ARRIVAL` so it is reachable and the returning player does not appear inside its collider. Town gives the opposite `Drive home` interaction. The staffed shop still uses the existing ShopPanel, economy and watering-can upgrade. The existing dialogue/gift panel and villager portraits continue unchanged.

## Decision 5 — Restore social tutorials, localization and proven content

Restore `talk` / `gift` tutorial entries, relevant tests and their reviewed en/zh_TW/ja rows from `c478f18^`; restore villager scene/interaction patterns and tests from `0d8667b^`. Use those commits as **reference only**: do not cherry-pick whole reverted farm geometry or old farm spatial guards. Adapt social tutorial relevance to `location == TOWN`; gift relevance also needs a harvest crop available. Shop wording returns from temporary `Seed Box` to staffed `Seed Shop` with existing translations adapted in one commit. Keep completion through `GameSession._commit()`.

Restoring nine tutorial keys intentionally makes some pre-release seven-key saves fail strict validation. Do not change save schema or add backward compatibility.

Hana's favourite crop is Turnip: one conversation (1) plus one favourite gift (5) per day reaches Close Friend (18) on the third town visit/day. Use **real** travel, talk, gifting and shipping commands to prove Heart of the Harvest; do not seed a relationship dictionary. The current 175G Promising outcome must remain exact.

## Decision 6 — Reachability and accepted weather limitation

Instead of a scripted movement path to every target, add one small **grid flood-fill** per map: start at `TRUCK_ARRIVAL`, walk orthogonally through in-bounds non-blocked cells (exclude cells intersecting contract footprints and player half-extent), and verify that every shop/NPC/market/truck target has a reachable stand cell at the proper `WorldMath.TARGET_OFFSETS`. Verify both farm initial spawn and truck arrival are free of collisions. Retain a few real WorldShell E-key integration checks; visually inspect town at native 1080p for Y-sort, scale, collision/occlusion and layout. A flood-fill is a cheap contract check, not proof of pixel-perfect physics.

Existing HUD rainy tint, rain/river audio and farm-day music continue in town. `HomesteadAmbience` is farm-only and will not draw town rain streaks/ripples: on rainy days the town may sound rainy without showing rain. This is an **accepted visual/audio mismatch** for this slice, not a reason for a new town weather or audio subsystem.

## Acceptance contract

1. New Game/Continue begin on the farm with one Player/HUD/session, and E at the farm truck drives to town. Farm seed box and market are no longer usable or visible.
2. Town shop/upgrade and all three dialogue/gift targets work, with reachable adjacent stand cells. E at town truck returns to a free farm truck-side spawn; farm shipping and sleeping still work.
3. Direct `GameSession` calls cannot farm, shop, gift, ship, sleep, drive or run the market from the wrong map/target. Invalid commands do not mutate state/time/location.
4. Driving costs 30 minutes, 0 stamina, works at the 22:00 cutoff; map reload uses the session's location and preserves identity, modal/hold teardown and camera. `TRAVELLED` never emits a refusal toast/SFX.
5. Day 14 town market and farm-bed fallback share one finale; Close Friend from real town interactions plus >=300G shipping gives Heart. The five-turnip/175G shipping-based Promising route stays green.
6. Tests cover required 16x12 targeting, camera, perimeter, flood-fill, returned spawn and all three languages. All four release gates pass **after implementation**, and native 1080p appearance is inspected. Screenshot goldens were removed in PR #29.

## Implementation order and non-goals

Implement in green steps: **additive types/travel/geometry/HUD** (farm unchanged) -> **authored town and trucks with round-trip travel** (old farm shop/market retained temporarily) -> **one atomic town migration** (move shop/market/social/tutorials and tests together) -> **finale route, e2e and docs**. See the companion plan for per-step commands. Avoid breaking the game for intermediate commits.

No new art/SFX, truck movement animation, town weather streaks or ambience rewrite, interiors, quests, new NPCs, trade/cafe menus, diary/lottery copy (HPA-684), walk animation (HPA-546), third map, generic map framework, save migration or screenshot-golden infrastructure.
