# HPA-683 — Empty farm / unattended seed box: single-PR implementation plan

**Status:** Revised after PR #36 design review, 2026-11-05. Documentation only; no implementation, automated test or manual playtest has been performed.  
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
- PR #29 removed screenshot goldens. Human visual review is required, but no goldens need updating. The HPA-683 interim ending ladder is documented in the design spec; do not rebalance it here.

## Step 1 — Remove farm residents without changing any other world geometry

**Production files:** `scenes/world/world.tscn`, `scripts/world/world_contract.gd`, `scripts/world/world_shell.gd`, `scripts/game/game_session.gd`, `scripts/game/game_rules.gd`, `scripts/ui/game_hud.gd`.

1. In `world.tscn` delete exactly three villager entity roots (including shadows/sprites) and three villager collision polygons. Clean unused scene resource entries, **not** the underlying committed art files. Keep `ShopStall` and `HarvestMarket` unchanged.
2. Delete the three farm-only villager geometry arrays and their `villager_cell` / `villager_footprint` / `villager_at` accessors from `WorldContract`. Keep all other cell/footprint/camera/projection constants unchanged.
3. Remove villager collision setup, farm-villager target hint and farm talk branch from `WorldShell`. Preserve ordinary shop, shipping, bed, market and non-target dispatch. E on a former villager cell now returns `NOTHING_TO_INTERACT`.
4. Narrow `GameSession.talk_to(villager_id)` and `gift_crop(villager_id, crop_kind)`: remove the now-redundant target argument and farm-coordinate equality check only, preserving active-day, gift-count, inventory, relationship and result behavior. The previous check duplicated `WorldShell`'s lookup from the same contract. Do **not** establish a universal map-location rule here: `GameSession` still validates shop, upgrade, shipping, bed and market cells; HPA-686 must settle location checks for all map-bound commands when town exists. Update `WorldShell._on_gift_requested` to use the narrow signature while retaining the dialogue/gift signal wiring and HUD resources.
5. Remove `NOT_AT_VILLAGER` from `GameRules.CommandCode`, `GameHud`'s feedback match and its existing translation CSV row. Remove unit/GdUnit assertions that expect the dead code; no command enum is persisted. Keep all other social feedback, UI and domain tests.
6. Revise affected social-domain tests to the narrow signatures, retaining tests for pending summaries, duplicate gifts, insufficient crops, relation tiers, dialogue variants, snapshot isolation and restore. Do not introduce hardcoded former-villager coordinates.

**Complete reference audit (required before edits):**

```bash
# Find removed farm-geometry symbols, dead command code and social call sites.
grep -rnE 'villager_cell|villager_at|villager_footprint|VILLAGER_|NOT_AT_VILLAGER|talk_to\(|gift_crop\(' scripts tests

# Before removing tutorial keys, find every direct key use (not just the table).
grep -rnE '&"talk"|&"gift"' scripts tests
```

Triage the hits rather than blindly deleting them: surviving `VILLAGER_TALKED` / `CROP_GIFTED` codes, `VillagerRules`, dialogue and relationship tests are legitimate. Update every *deleted symbol* reference and every altered command call before committing. In particular:

- `tests/headless/world_math_smoke.gd` pins `WorldContract.VILLAGER_CELLS`; remove that check, keep all other world math contracts.
- `tests/integration/test_persistence_flow.gd` calls both social commands with `WorldContract.villager_cell()`; update signatures while preserving a nonempty social-state save/restore fixture.
- `tests/unit/test_game_session.gd`, `tests/gdunit/test_game_session_flows.gd` and `tests/integration/test_gameplay_shell.gd` contain further old signature and `NOT_AT_VILLAGER` references. Keep social semantics tests and remove only obsolete spatial tests.
- `tests/headless/world_shell_smoke.gd`: remove resident geometry, sprite and collision loops and names from `_static_entity_names()` / exact ordered collision lists. Its existing `_expect_names()` **already asserts exact child count and names**: do not add duplicate absence assertions.
- `tests/integration/test_gameplay_shell.gd`: delete the farm-villager target-name and direct world-interaction success tests rather than recreating the old cells in test fixtures. Existing panel-focus/gift/dialogue tests should reuse one local `_open_dialogue(world, id)` helper based on the existing `test_dialogue_consumes_escape_before_help()` pattern: call `session.talk_to(id)`, then `hud.open_dialogue(id, result, snapshot)`. The standalone dialogue panel is also covered by `tests/integration/test_vn_surfaces.gd`.
- The **existing** `test_off_target_interact_reports_nothing_without_session_mutation()` already covers the generic `NOTHING_TO_INTERACT` fallback. Strengthen it to assert the exact `Nothing to interact with.` toast and unchanged relationships (not merely a substring and total snapshot); **do not add a second fallback test**.

**Verification after Step 1:** Commit the production/test/CSV deletions together. Then run both the clean GUT/headless verifier **and the GdUnit4 lane** (Step 1 edits GdUnit tests, which `verify-clean` does not execute):

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

Both commands must run against this committed state; fix failures in this PR before moving on. The verifier archives committed `HEAD`.

## Step 2 — Make the remaining shop explicitly self-service

**Files:** `scripts/world/world_shell.gd`, `scripts/ui/shop_panel.gd`, `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, focused integration/localization tests.

1. Change `WorldShell._interact_label(SHOP_CELL)` from “Shop” to “Seed Box”; change the `ShopPanel` visible header to “SEED BOX”, reusing the existing 1080p card, nodes, buttons, icon and layout. No portrait or new shop prop is needed.
2. Keep the store’s seed prices, three crop rows, one upgrade row, buying requests, maximum quantity shortcut, modal focus and purchasing feedback untouched. In `ContentRules`, update “Reinvest” tutorial text to refer to the seed box rather than a staffed seed counter.
3. Remove `talk` and `gift` from `ContentRules.TUTORIALS` and from `_tutorial_relevant`. Keep the other seven cards in their existing relative order. A fresh run should show the remaining tutorials normally and never guide the player to nonexistent farm residents.
4. Update the Pause controls help item that currently describes E as “Talk, shop, bin, bed” so it truthfully lists the seed box, bin and bed. Do **not** touch the opening, result, morning diary or resident dialogue prose (HPA-684/HPA-688).
5. **Rename existing CSV rows in place**, updating `zh_TW` (Taiwan wording) and `ja` simultaneously: `Face the seed counter…` → `Face the seed box…`, `Talk, shop, bin, bed` → `Seed box, bin, bed`, `SEED SHOP` → `SEED BOX`, `Shop` → `Seed Box`. Delete obsolete rows for `Meet the village` and its body, `Give a gift` and its body, and `Stand at the villager.` (removed with `NOT_AT_VILLAGER` in Step 1). The file has `keys,zh_TW,ja`; do not leave orphaned old keys or add duplicate keys.
6. Update `tests/unit/test_content_rules.gd` to the exact seven-card table and its real prompt order (no social cards), preserving Day 2 buy-seeds and harvested shipping behavior. Also remove or change **every** direct `state()["tutorial"][&"talk"]` / `[&"gift"]` access, notably `tests/unit/test_game_session.gd` (deep-copy assertions and tutorial-completion flow); replace with meaningful surviving keys instead of indexing deleted keys. Update visible shop header/prompt/help assertions in `tests/integration/test_commerce_panels.gd` and `tests/integration/test_gameplay_shell.gd` as appropriate. Keep `tests/unit/test_localisation.gd` passing.

**Save behavior:** Fresh tutorial state and its round trip use the seven-key table. Existing schema-4 saves carrying `talk` and `gift` can be rejected by the existing strict validator; do not write a migration or change the saved relationship fields. Keep `SaveFile` transport unchanged.

Commit this coherent presentation/tutorial change and rerun `./tools/verify-clean.sh` against committed HEAD.

## Step 3 — Verify the whole playable slice

**Tests and documentation:** `tests/e2e/gameplay_day_one_test.gd`, any affected unit/integration suites, `README.md` and `CLAUDE.md` where they describe live farm villagers. `AGENTS.md` is a **symlink to `CLAUDE.md`**: edit `CLAUDE.md` once and keep the symlink intact. Specifically remove stale claims about farm villager interaction, farm resident cells/footprints and resident locations; update README's controls, social, farm and finale descriptions for the interim state.

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

- New Game at native 1920×1080: resident sprites/collisions absent, unoccupied areas traversable, no farm resident name hint or dialogue. E on an ordinary empty cell uses the generic fallback and leaves relationships untouched; the tests must **not** pin old villager coordinates.
- Face `(17, 9)`: “Seed Box” prompt, E opens shop, buy/upgrade/money and close/restore-input flows still work. Check the pinned `test_representative_reinvestment_route_reaches_promising()`: 5 Turnips, 175G shipped, `promising_farmer`.
- Farm/bed/shipping/market positions and action feedback remain unchanged. Day 14 can still end at the existing farm market. Accept that new runs cannot reach Heart of the Harvest or friendship-only Promising; the result defaults to Sato-san + three Stranger cards. Keep the shipping-based 175G Promising route. HPA-686 re-verifies Heart after town social play returns.
- Seven tutorial cards remain table-driven with no talk/gift card or orphaned localization keys. Social rules, relationship snapshot/save fields, dialogue renderer and portraits remain testable. The existing opening's village invitation / SATO-SAN tag is an accepted interim mismatch owned by HPA-684.
- New save + Continue works; an old tutorial key shape is rejected as incompatible (no migration). Preview, pause and day clock still gate correctly.
- Check menu copy in `en`, `zh_TW` and `ja`, and inspect the farm + shop in the running game at 1920×1080 and 960×540. There is no screenshot-golden test to re-bless.

## Completion criteria

One PR includes the implementation plus updated focused tests/docs. All four release gates pass, manual farm/seed-box checks pass, and no new art, town, diary, map-switching, legacy-save migration, generic interaction layer or balance changes sneak in. Move HPA-683 to Done only when the implementation has merged; HPA-686 remains blocked until HPA-685 also lands.
