# HPA-683 — Empty the farm and keep an unattended seed box: design specification

**Status:** Draft for design review, 2026-11-04 (planning only; no runtime code changed)  
**Linear:** https://linear.app/cwchanap/issue/HPA-683/empty-the-farm-remove-villagers-make-the-seed-stall-an-unattended-seed  
**Base reviewed:** `main` at `16da783ae7a74db0703f75c7f7822add332564a7`  
**Related:** HPA-684 (independent diary/copy), HPA-685 (map extraction), HPA-686 (town/travel; blocked by HPA-683 and HPA-685), HPA-687 (town art; done)  
**Delivery:** One PR for HPA-683. Implement on this same draft PR after design review, not in a second PR.

## Player-visible goal

The starting farm feels deliberately empty. Sato-san, Gen-san and Hana no longer appear, block movement, or respond to E on the farm. The existing seed stall remains a **self-service seed box** at the same cell, with exactly the existing seed purchases, watering-can upgrade, prices, quantities, time/stamina semantics and modal/input behavior.

This is a small story-world correction, not the town implementation. HPA-686 later restores the three residents, social interactions, tutorial cards, seed shop and Day 14 market **in town**. Until then the Day 14 harvest market remains on the farm.

## Decisions

### 1. Delete farm-only villager geometry rather than leave dormant coordinates

- Delete `VillagerShopkeeper`, `VillagerFarmer` and `VillagerResident` scene nodes (including child sprites/shadows) from `scenes/world/world.tscn` and the corresponding three collision children of `StaticCollision`. Remove now-unused scene `ExtResource` references, but **keep** the committed villager sprite and portrait files for HPA-686.
- Delete `VILLAGER_CELLS`, `VILLAGER_FOOTPRINTS`, `VILLAGER_COLLISION_NAMES` and `villager_cell` / `villager_footprint` / `villager_at` from the **farm-specific** `WorldContract`. Do not retain ghost cells in that contract merely to satisfy existing tests.
- In `WorldShell._ready()` remove all three villager collision polygon initializations. In `_interact_label()` and `interact()` remove farm-villager lookup and talk routing. The former resident cells become ordinary walkable/non-interactable farm cells: no name prompt, no dialogue, E reports the normal nothing-to-interact response.
- Preserve the existing `Entities` Y-sort owner, `Player`, `ShopStall`, all farm and scenery props, `FarmSoil`, ambience, camera, market, shop/bed/shipping cells and collision geometry.
- Do **not** split `world.tscn`, introduce a `Map` interface, or add a map switcher. HPA-685 owns that later refactor.

### 2. Reuse the current shop, clarify self-service copy only

- Retain `WorldContract.SHOP_CELL == Vector2i(17, 9)`, the `ShopStall` sprite/collision and `ShopPanel` mechanics. The shop panel already has no seller portrait; removing the nearby seller entity is sufficient visually. Do not add or generate art.
- Change the world interaction hint from “Shop” to “Seed Box” and the shop header from “SEED SHOP” to “SEED BOX”. Retain its seed/tools subtitle, three crop rows, upgrade row, action buttons, selection, input gates and all existing prices.
- Update the `buy_seeds` tutorial body to refer to the seed box, and change the Pause controls help text that currently promises a farm “Talk” interaction. Do not rewrite the title, opening or result-story prose; HPA-684 owns that.
- HPA-713 is already on `main`: add matching `zh_TW` (Taiwan wording) and `ja` translations for **each changed or new player-facing English key** in `assets/i18n/strings.csv`, whose actual columns are `keys,zh_TW,ja`. Use the existing `tr()` / Godot auto-translation convention. No localization framework changes.

### 3. Keep social domain state, remove the spatial dependency on the farm

`GameSession.talk_to(id, target_cell)` and `gift_crop(id, crop_kind, target_cell)` currently validate against `WorldContract.villager_cell(id)`, which disappears with the farm placements. Two options:

- **Rejected:** keep old villager farm coordinates in `WorldContract` as latent test fixtures. This leaves obsolete scene geography masquerading as the live contract and makes HPA-686 harder.
- **Chosen:** narrow social commands to `talk_to(villager_id)` / `gift_crop(villager_id, crop_kind)`. `GameSession` owns whether a day is active, dialogue/relationship progression, gift inventory, daily limits and state mutation; the *world interaction layer* owns whether the player is facing an actual villager. Today's farm has no such entry point; HPA-686 will check `TownContract` target proximity before invoking these commands.

Preserve `VillagerRules`, `GameSession` relationship arrays, social command codes, dialogue/portrait UI resources, `GameHud.open_dialogue()` and gift-request signal support. Do not delete or reset social save/snapshot fields. Existing pure social tests should still prove dialogue and gift rules; remove only their dependency on old farm coordinates. The dormant `NOT_AT_VILLAGER` result value need not be removed as part of this focused slice.

There is no production farm path that opens dialogue once `WorldShell.interact()` loses the villager branch. Dialogue can still be exercised directly in isolated panel tests so HPA-686 has a verified component to reuse. Do not invent a temporary villager spawn, remote social endpoint or generic interaction framework.

### 4. Tutorial state reflects the available world

Remove only `talk` and `gift` entries from `ContentRules.TUTORIALS` and the now-unreachable `_tutorial_relevant()` match arms. The exact remaining table order is:

1. `farm_basics`
2. `plant`
3. `water`
4. `sleep`
5. `buy_seeds`
6. `harvest`
7. `shipping`

`initial_tutorial_progress()`, `tutorial_keys()` and `tutorial_for_code()` remain table-driven. Fresh runs never receive “Meet the village” or “Give a gift” cards; the remaining hints still appear based on the real game state. HPA-686 restores the social entries when there is a usable town interaction.

**Save consequence:** `SessionStateValidator._tutorial_state_error()` requires *exactly* the current tutorial keys. Existing schema-4 saves containing `talk`/`gift` will therefore be rejected by the existing Continue validation, while fresh saves from this build round-trip. This is an intentional breaking content change for a pre-release hobby project: no migration, alternative shape, fallback keys or new save subsystem. Keep other save fields and schema transport unchanged.

## Acceptance and regression contract

- Farm has zero villager entities, collisions, name prompts and interactable resident targets. Old resident cells can be walked over and E produces no social state change.
- Facing `SHOP_CELL` displays “Seed Box”; E opens the existing Shop modal. Seed buying, the 200G Efficient Can upgrade, the purchase UI, blocking behavior and current prices work exactly as on `main`.
- Farming, weather/clock, bed, shipping and **farm** Day 14 market remain unchanged. The pinned five-Turnip / 175G `promising_farmer` route is still green.
- `ContentRules.TUTORIALS` contains seven entries; neither farm social tutorial appears. Relationship/save/snapshot fields, social rules, dialogue rendering and portrait assets stay available.
- New/changed UI copy works in English, Traditional Chinese (Taiwan) and Japanese, at native 1920×1080 and the existing 960×540 minimum window.
- Pass all **four current release gates**: (1) GUT + headless clean verifier, (2) GdUnit4, (3) godot-e2e, (4) import and unsigned macOS export. Review the live farm visually. PR #29 removed screenshot-golden CI; do not restore or re-bless goldens.

## Out of scope

No new images, audio, dialogue content, diary, lottery-premise rewrite, town map, truck, travel budget, generic map architecture, new NPC systems, game balance, new persistence format, backward-compatibility adapter or screenshot-golden test infrastructure.
