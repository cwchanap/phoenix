# HPA-683 — Empty farm / unattended seed box: single-PR implementation plan

**Status:** Draft for review, 2026-11-04. This initial PR contains documentation only; no implementation, automated test or manual playtest has been performed.  
**Design:** [HPA-683 design specification](../specs/2026-11-04-phoenix-empty-farm-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-683/empty-the-farm-remove-villagers-make-the-seed-stall-an-unattended-seed  
**Delivery:** Complete HPA-683 in **this same draft PR** after plan review. One Linear issue → one PR; no separate implementation PR and no art task.

## Current-main baseline and guardrails

- Godot 4.7.1, statically typed GDScript, one `GameSession` owned by `WorldShell`, `GameHud` still owns the modal/input gate.
- HPA-681/682 native City Pop 1080p controls and HPA-713 localization already landed. `ShopPanel` is code-built with no seller portrait.
- On `main`, the farm currently places three villager scene nodes and collisions; `WorldContract` owns their geometry, `WorldShell` routes E to them and `GameSession` validates social target coordinates against that farm contract.
- `ShopStall`, `SHOP_CELL` and existing `buy_seeds` / `buy_watering_can_upgrade` target checks can remain as-is. HPA-686 will move the shop when town exists.
- HPA-685 is a separate, future map-extraction ticket. Do not pull its scene architecture into HPA-683.
- `SessionStateValidator` rejects a saved tutorial dictionary whose key set differs from current `ContentRules.tutorial_keys()`. Save migrations/backwards compatibility are not required.
- PR #29 removed screenshot goldens. Human visual review is required, but no goldens need updating.

## Step 1 — Remove farm residents without changing any other world geometry

**Production files:** `scenes/world/world.tscn`, `scripts/world/world_contract.gd`, `scripts/world/world_shell.gd`, `scripts/game/game_session.gd`.

1. In `world.tscn` delete exactly three villager entity roots (including shadows/sprites) and three villager collision polygons. Clean unused scene resource entries, **not** the underlying committed art files. Keep `ShopStall` and `HarvestMarket` unchanged.
2. Delete the three farm-only villager geometry arrays and their `villager_cell` / `villager_footprint` / `villager_at` accessors from `WorldContract`. Keep all other cell/footprint/camera/projection constants unchanged.
3. Remove villager collision setup, farm-villager target hint and farm talk branch from `WorldShell`. Preserve ordinary shop, shipping, bed, market and non-target dispatch. E on a former villager cell now returns `NOTHING_TO_INTERACT`.
4. Decouple `GameSession.talk_to()` and `gift_crop()` from deleted farm geometry by removing their `target_cell` argument and location comparison. Keep the active-day, gift-count, inventory and relationship logic identical. `WorldShell` remains responsible for mapping a reachable scene entity to a villager ID; for this ticket, no production map exposes such an entity. Retain existing HUD dialogue/gift resources and the gift signal path so the component can be exercised in isolation.
5. Revise affected social-domain tests to the narrow new signatures; preserve their outcomes/guard assertions for pending summary, duplicate gifts, insufficient crops, relation tiers, dialogue variants, snapshot isolation and restore. Drop only the obsolete `NOT_AT_VILLAGER` coordinate assertion (do not replace it with hardcoded ghost positions).

**Immediate test updates (same commit):**
- `tests/headless/world_shell_smoke.gd`: remove resident names from ordered entity/collision expectations and all geometry, anchor, sprite and z-index loops for the old residents. Add explicit absence assertions; preserve all other exact scene contracts, including sole Y-sort owner.
- `tests/integration/test_gameplay_shell.gd`: replace the farm-villager success routing test with no-name-prompt/no-dialogue/no-social-mutation checks for the three former cells, including a walkable collision-free path. Keep `ShopStall` input/modal assertions.
- Existing dialogue panel behavior tests that currently enter via `world.interact()` can use a small **test-only** helper that calls `GameSession.talk_to(id)` and `GameHud.open_dialogue(id, result, snapshot)`. Preserve focus, close, gift controls and portraits, but do not imply that the farm can reach them.
- `tests/unit/test_game_session.gd` and `tests/gdunit/test_game_session_flows.gd`: update social function calls to omit the target argument. Do not remove the pure social rules tests.

Commit this coherent change before running `./tools/verify-clean.sh` because the script validates archived committed `HEAD`.

## Step 2 — Make the remaining shop explicitly self-service

**Files:** `scripts/world/world_shell.gd`, `scripts/ui/shop_panel.gd`, `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, focused integration/localization tests.

1. Change `WorldShell._interact_label(SHOP_CELL)` from “Shop” to “Seed Box”; change the `ShopPanel` visible header to “SEED BOX”, reusing the existing 1080p card, nodes, buttons, icon and layout. No portrait or new shop prop is needed.
2. Keep the store’s seed prices, three crop rows, one upgrade row, buying requests, maximum quantity shortcut, modal focus and purchasing feedback untouched. In `ContentRules`, update “Reinvest” tutorial text to refer to the seed box rather than a staffed seed counter.
3. Remove `talk` and `gift` from `ContentRules.TUTORIALS` and from `_tutorial_relevant`. Keep the other seven cards in their existing relative order. A fresh run should show the remaining tutorials normally and never guide the player to nonexistent farm residents.
4. Update the Pause controls help item that currently describes E as “Talk, shop, bin, bed” so it truthfully lists the seed box, bin and bed. Do **not** touch the opening, result, morning diary or resident dialogue prose (HPA-684/HPA-688).
5. Update `assets/i18n/strings.csv` for new/changed English source keys with proper Taiwanese Traditional Chinese and Japanese translations in the **same commit**. The file uses `keys,zh_TW,ja`, not an extra English column.
6. Update `tests/unit/test_content_rules.gd`: exact table is now seven cards; verify `talk`/`gift` are never suggested, `buy_seeds` still appears on a valid Day 2 state, and shipping still follows a harvest. Update visible shop header/prompt/help assertions in `tests/integration/test_commerce_panels.gd` and `tests/integration/test_gameplay_shell.gd` as appropriate. Keep `tests/unit/test_localisation.gd` passing.

**Save behavior:** Fresh tutorial state and its round trip use the seven-key table. Existing schema-4 saves carrying `talk` and `gift` can be rejected by the existing strict validator; do not write a migration or change the saved relationship fields. Keep `SaveFile` transport unchanged.

Commit this coherent presentation/tutorial change and rerun `./tools/verify-clean.sh` against committed HEAD.

## Step 3 — Verify the whole playable slice

**Tests and documentation:** `tests/e2e/gameplay_day_one_test.gd`, any affected unit/integration suites, `README.md`, `AGENTS.md` and `CLAUDE.md` where they describe live farm villagers.

Automated release gates, using repository-provided commands:

```bash
# 1. GUT unit + integration, headless project/world smokes and audio check
./tools/verify-clean.sh

# 2. GdUnit4 behavior
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c

# 3. godot-e2e
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c

# 4. Import and unsigned macOS export
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

`tools/verify-clean.sh` downloads GUT into its temporary archived checkout and needs network access. The GdUnit4 bootstrap may be needed locally: `./tools/bootstrap-gdunit.sh`. Do not claim any gate is green until the implementation commits have actually been run and passed.

**Focused regression checklist:**

- New Game at native 1920×1080: three resident sprites absent; walk through all three former resident footprints; face those cells and E — no name hint or dialogue, and session social state unchanged.
- Face `(17, 9)`: “Seed Box” prompt, E opens shop, buy/upgrade/money and close/restore-input flows still work. Check the pinned `test_representative_reinvestment_route_reaches_promising()`: 5 Turnips, 175G shipped, `promising_farmer`.
- Farm/bed/shipping/market positions and action feedback remain unchanged. Day 14 can still end at the existing farm market.
- Seven tutorial cards remain table-driven with no talk/gift card. Social rules, relationship snapshot/save fields, dialogue renderer and portraits remain testable.
- New save + Continue works; an old tutorial key shape is rejected as incompatible (no migration). Preview, pause and day clock still gate correctly.
- Check menu copy in `en`, `zh_TW` and `ja`, and inspect the farm + shop in the running game at 1920×1080 and 960×540. There is no screenshot-golden test to re-bless.

## Completion criteria

One PR includes the implementation plus updated focused tests/docs. All four release gates pass, manual farm/seed-box checks pass, and no new art, town, diary, map-switching, legacy-save migration, generic interaction layer or balance changes sneak in. Move HPA-683 to Done only when the implementation has merged; HPA-686 remains blocked until HPA-685 also lands.
