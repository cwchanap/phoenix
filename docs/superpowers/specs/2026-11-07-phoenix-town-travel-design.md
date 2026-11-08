# HPA-686 — Town map and driving: design specification

**Status:** Proposed; planning only. Implementation and verification have not been run.  
**Linear:** https://linear.app/cwchanap/issue/HPA-686/add-the-town-map-and-drive-between-farm-and-town  
**Reviewed baseline:** `main` at `736a3bc97ea00d450cb499e0296ef48899922777` (HPA-685 extracted FarmMap).  
**Dependencies:** HPA-683 and HPA-685 are Done; HPA-687's town/kei-truck runtime atlases are committed. HPA-684 diary/copy and HPA-546 walking animation are independent.  
**Delivery:** One issue, one PR. This PR starts as design and implementation planning; implement the complete HPA-686 slice on this same PR after review.

## Player-visible outcome

The farm is home, but its seed box and Day 14 market are no longer on the farm. The player walks to a parked kei truck, presses E, spends 30 in-game minutes traveling to a small town, shops at Sato-san's seed shop, talks to and gifts the three existing residents, and drives back to tend crops, ship produce, and sleep. The town also hosts the Day 14 market. A drive remains possible at 22:00, so the player can never be stranded in town.

Restore both the shipping-based Promising Farmer route (five turnips -> 175G shipped) and a real town-social route to Heart of the Harvest (at least one Close Friend plus >=300G shipped). Existing farm behavior, economy, 14-day ending ladder, City Pop UI, and three languages stay intact except for interactions explicitly moved to town.

## Current main and constraints

- `WorldShell.load_map(MapId.FARM)` swaps a single FarmMap while preserving the one Player/Camera2D, GameSession, GameHud and target highlight. It closes user-opened modals, cancels held farming actions, and clears stale target/prompt state.
- `FarmMap` owns farm terrain, Y-sorted `Entities`, soil, transient effects, ambience, and farm collisions. `WorldContract` still contains provisional farm-side seed-box and market cells and footprints.
- `GameSession` is the sole mutable gameplay authority. Farm actions, seed buying, upgrade, shipping, sleep, social, and finale commands already exist; social commands no longer accept farm target coordinates. `state()` is persisted and strictly validated; `snapshot()` is the UI read model.
- `WorldMath.target_cell()` currently bounds against `WorldContract.MAP_SIZE`, and `PlayerController.enter_map()` currently accepts only spawn and camera bounds.
- `ContentRules.TUTORIALS` currently has seven entries because talk/gift were temporarily removed. `SessionStateValidator` requires an exact tutorial key set.
- Art already exists: `town-terrain.png` (three 64x32 diamonds), `town-props.png` (station, seed shop, cafe, market in four 96x96 frames), `kei-truck.png` (two 96x96 views), plus existing villager sprites/portraits. `assets/sprites/town-art-source.md` documents ground contact, frames and provenance.

Use Godot 4.7.1 and statically typed GDScript. No new art, SFX, dialogue system, generic map inheritance, services, migration framework, screenshot goldens, or second session holder.

## Decision 1 — One authored TownMap, not a map framework

Add `scenes/world/town_map.tscn`, `scripts/world/town_map.gd`, `scripts/world/town_contract.gd`, and a small authored town TileSet resource if needed for the already-committed ground atlas.

- `TownContract` owns a roughly `16x12` logical footprint; truck/arrival spawn, shop, station cafe, market, and the three resident target cells; placed building footprints and camera bounds. Keep town literals out of `WorldShell`, `GameSession`, and tests.
- Build one small walkable street/plaza with those four visible landmarks and three villagers: Sato-san near the shop, Gen-san along the road, Hana near the cafe. Use committed atlases rather than creating new imagery. Building collision footprints must not block adjacent interaction cells or access from truck to each destination.
- Like FarmMap, TownMap owns its own `Entities` (the sole Y-sort root for the active map), ground, scenery, shadows, and static collisions; WorldShell continues to own the persistent Player and HUD. Retain the stable `World/%Player` unique-name lookup.
- Extend `WorldMath.target_cell(position, facing, map_size)` and `WorldMath.map_camera_bounds(map_size)` to accept map size (defaulting to the existing farm size where suitable). `PlayerController.enter_map` takes the active map size as well as spawn and camera bounds. The 64x32 projection, origin, speed, hitbox, zoom, camera ownership, and farm geometry do not change.
- Keep `WorldShell` selecting FarmMap or TownMap explicitly with a two-arm `match`. Its `_map` may become a `Node2D` with narrow typed branch access; avoid a `BaseMap`, registry, scene factory, or duplicated mutable farm/town view caches. Refresh FarmView/effects/ambience only on FarmMap; town has no crop renderers/effects.

## Decision 2 — One authoritative *transient* location

Move the two-value map identity to `GameRules.MapId { FARM, TOWN }` (replace `WorldShell.MapId` rather than maintaining parallel enum identities). `GameSession` holds an in-memory `_location` initialized to FARM. Include it as a read-only key in `snapshot()`, but **not** in `state()` or `SaveFile`. `restore_state()` resets it to FARM. Sleeping is only allowed on the farm, so every overnight save and Continue begins at the farm. Do not change persisted schema version or add a save migration.

Use `GameSession.travel_to(destination: GameRules.MapId) -> GameRules.CommandCode` as the *only* travel command. `WorldShell` only calls it when the player targets the active map's truck and presses E. On a successful `TRAVELLED` result, WorldShell installs the destination map, places the same Player beside that map's parked truck, and refreshes its HUD. On failure, neither location, clock, player position nor map changes. A fresh New Game/Continue uses the normal farm spawn; a drive home uses a farm truck-side arrival spawn.

The session is authoritative for the location transition; the shell is a renderer/controller of the accepted location. Do not store a second authoritative map location in the UI.

## Decision 3 — Fixed travel budget with a safe 22:00 cutoff

Add `GameRules.TRAVEL_MINUTES := 30`. A successful drive advances `_time_minutes` by 30, capped at `GameRules.ACTION_CUTOFF_MINUTES` (22:00), and consumes no stamina. At 21:45 it arrives at 22:00; at 22:00 it still succeeds and remains 22:00. Driving never auto-sleeps or enters Day 15.

Keep `_active_day_failure()` checks for pending morning summary/finale. Same-location travel is refused without mutation. Farm tools continue to refuse late action; truck, seed shop, shipping, dialogue, market and bed remain available at the cutoff, as applicable to their respective maps. Avoid a new travel UI/transition animation.

## Decision 4 — Explicit interaction/location policy

The UI resolves *physical target cells* from the active map contract; GameSession checks the *authoritative location* before executing every location-bound command. Existing commands that take a target cell also verify the correct contract cell. The narrowed `talk_to(villager_id)` and `gift_crop(villager_id, crop_kind)` remain target-free: TownMap/WorldShell resolves which villager was actually faced, and GameSession checks TOWN. Travel is similarly initiated only at a truck target in WorldShell and verified as a location change in GameSession. Do not restore the redundant farm-coordinate social parameter.

| Action | Farm | Town | Session guard |
| --- | --- | --- | --- |
| Till/plant/water/harvest and preview | Yes | No | FARM + existing farm-cell/action rules |
| Shipping bin | Yes | No | FARM + `WorldContract.SHIPPING_CELL` |
| Bed/sleep | Yes | No | FARM + `WorldContract.BED_CELL` |
| Buy seeds / Efficient Can | No | Yes | TOWN + `TownContract.SHOP_CELL` |
| Talk/gift | No | Yes | TOWN + existing social rules |
| Day 14 harvest market | No | Yes | TOWN + `TownContract.MARKET_CELL` + day gate |
| Truck E / drive | Yes | Yes | Correct active truck target in WorldShell; destination must differ in GameSession |

On TownMap, Space never works a farm tile, even when a town cell has the same coordinates as one in the farm patch. The town prompt should show `Seed Shop`, named residents, `Harvest Market`, and `Drive home`; farm prompts retain bed and shipping and gain `Drive to town`. Remove the now-obsolete farm seed stall/box and farm market scenery/collision/interaction targets (without deleting their shared art files). The existing farm sign/road is the natural truck-side access point; use the current `VILLAGE_SIGN_CELL` vicinity initially and confirm reachability in the running game. Town cell/spawn coordinates should be fixed once in TownContract, then tested for collision-free paths.

The town's Sato-san shop continues using the existing ShopPanel, seed prices, and Efficient Can command. Rename self-service `Seed Box` copy back to staffed `Seed Shop` where visible; do not change economy. The existing dialogue/gifting panel and villager portraits remain unchanged.

## Decision 5 — Restore the two social tutorials and localized prompts

Restore `talk` and `gift` entries in `ContentRules.TUTORIALS`, completed by successful `VILLAGER_TALKED` and `CROP_GIFTED`. Present them contextually when the player is in town; the gift card should wait until a harvest crop is available. No tutorial should prompt social interaction while still on the farm. Preserve the table-driven completion path inside `GameSession._commit()`.

For each new or changed English UI string, add Traditional Chinese (Taiwan wording) and Japanese in `assets/i18n/strings.csv` in the same implementation commit. Existing old saves with seven-key tutorial dictionaries may be rejected by strict validation after reintroducing the nine-key table; this is an accepted pre-release incompatibility, **not** a reason to add schema migrations or compatibility shims. New saves round-trip with the existing schema.

## Acceptance contract

1. New Game opens on the farm with a single session, HUD and player; the unattended seed box and farm market no longer respond. E by the farm truck drives to town.
2. In town, one can walk from truck to the seed shop, buy seeds/upgrade, talk and gift Sato-san, Gen-san and Hana, and return to the truck. Driving home places the player beside the farm truck, not through an obstruction; shipping and sleeping still work.
3. Farm-only actions and targets are rejected in town and town-only actions/targets are rejected at the farm, **including direct GameSession command calls**. Failed travel/commands do not mutate money, relationships, time, or location.
4. Driving costs 30 minutes and zero stamina, caps at 22:00, remains available after the cutoff, never duplicates entities/modals/connection callbacks, and does not change persisted state shape.
5. Day 14 market works only in town; farm bed on Day 14 remains the finale fallback. The real town dialogue/gift loop can reach Close Friend and, with >=300G shipped, Heart of the Harvest. The existing five-turnip/175G Promising route remains green.
6. All new copy works in en/zh_TW/ja; visually inspect the farm and the authored town at native 1080p, including camera edges, prop Y-sort, collisions and contextual prompts. Existing four release gates pass after implementation; screenshot-golden CI was removed in PR #29.

## Explicit non-goals

HPA-684 lottery diary/opening/result rewrite; HPA-546 walk-cycle playback; new characters/portraits/tiles/SFX; truck driving animation; interiors, quests, cafe trading, economy rebalance, social schedules, dynamic destinations, multi-save, or a generic map/interaction engine. Those should not enter this PR.
