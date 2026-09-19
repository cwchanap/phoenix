# Phoenix Efficient Watering Can Design

**Linear:** HPA-460  
**Repository:** `cwchanap/phoenix`  
**Branch:** `agent/hpa-460-watering-can-upgrade-plan`  
**Base reviewed:** `main` at `3ce489e7c32ef2a5c3aab9931c07baae724d7940`

## Goal

Add one useful, optional watering-can upgrade that turns farming income into a meaningful reinvestment choice without changing Phoenix into an equipment-progression game.

The upgrade is permanent for the current run, costs 200G, and changes only successful single-tile watering stamina from 2 to 1. Time, range, rain behavior, all other action costs, crop values, growth, finale thresholds, and the 14-day structure stay unchanged.

## Current seams to preserve

HPA-459 deliberately prepared the implementation seam this ticket needs:

- `GameSession` is the only mutable gameplay authority.
- Every farming guard, command budget, and farming preview routes through private `GameSession._cost_for(action)`.
- `GameHud.farming_preview_text()` reads the cost already carried by the session preview; it does not own a cost table.
- `WorldShell` coordinates HUD requests and session commands.
- The existing seed shop is one fixed `ShopPanel`; there is no item/equipment/catalog model.
- One-slot persistence serializes `GameSession.state()` through the field-blind schema-2 `SaveFileCodec`; required runtime-state fields are validated by `GameSession.state_error()` before Continue is enabled.
- HPA-458 already delivered `assets/ui/icons/watering-can-efficient.png`. No new image generation belongs in HPA-460.

The feature should extend those owners rather than creating a new upgrade subsystem.

## Product contract

### Purchase

- The efficient watering can costs **200G**.
- A fresh run starts with 150G, so it cannot be purchased immediately.
- Shipping the three starter Turnips adds 105G, reaching 255G.
- Buying the upgrade at 200G leaves 55G.
- Two more Turnip seeds cost 40G, leaving 15G.
- This is the reference reinvestment route, not an optimal-strategy requirement.
- The purchase is permanent for the run and may happen only once.
- Exact funds are valid.
- Insufficient funds, duplicate purchase, or purchase away from the shop changes nothing.

### Watering

Base watering remains:

- 20 minutes;
- 2 stamina;
- one currently targeted farm cell;
- invalid on rain, already-watered crops, mature crops, or invalid targets.

After purchase, only the effective watering stamina changes to **1**. The command still uses the same single-cell targeting, same HPA-459 preview, same hold-to-work behavior, and same success presentation.

The ticket's pacing examples therefore stay mechanically true:

- six successful base waterings from 20 stamina leave 8;
- twelve successful upgraded waterings from 20 stamina leave 8.

### Scoring

Buying the upgrade only subtracts money. It never modifies shipped counts, harvested counts, relationship points, stamina, or finale score inputs.

The existing no-upgrade route must remain valid. The upgrade is optional convenience, not a hidden completion requirement.

## State and rules design

### One state bit

Add one authoritative boolean to `GameSession`:

`_watering_can_upgraded := false`

Expose it as `watering_can_upgraded` in both `state()` and `snapshot()`.

Do not add an equipment collection, upgrade enum, inventory object, or generic unlock registry. There is exactly one upgrade in current scope.

### One effective-cost policy

Keep the existing base arrays in `GameRules` unchanged:

- `ACTION_MINUTES`
- `ACTION_STAMINA`
- `action_cost(action)`

Add:

- `WATERING_CAN_UPGRADE_PRICE := 200`
- pure `effective_action_cost(action, watering_can_upgraded)`

The function starts from `action_cost(action)` and, only for `WATERING_CAN` with the flag true, returns the same minutes with stamina 1.

`GameSession._cost_for(action)` becomes the only session call site that supplies the run state:

`GameRules.effective_action_cost(action, _watering_can_upgraded)`

That automatically keeps HPA-459 preview, guards, and successful command budgets in agreement.

The live farming hint already reads preview cost. The shop's static benefit copy is the only other cost surface: format `Water %d→%d STA` from `effective_action_cost(WATERING_CAN, false/true)` rather than hardcoding a second 2→1 table. The Almanac remains unchanged.

## Purchase command

Add one narrow session command:

`buy_watering_can_upgrade(target_cell)`

Validation order stays consistent with the existing seed purchase:

1. current day is active;
2. target is exactly `WorldContract.SHOP_CELL`;
3. upgrade is not already owned;
4. money is at least `WATERING_CAN_UPGRADE_PRICE`.

On success:

- subtract 200G exactly once;
- set `_watering_can_upgraded = true`;
- commit a dedicated success code.

Add only the command codes needed for truthful UI:

- `WATERING_CAN_UPGRADED`
- `WATERING_CAN_ALREADY_UPGRADED`

Reuse `NOT_AT_SHOP` and `INSUFFICIENT_FUNDS` for existing failure meanings. Do not introduce a generic purchase-result type.

The success still routes through `_commit(WATERING_CAN_UPGRADED)`, but the new upgrade codes are deliberately **not** tutorial completion codes. `ContentRules.tutorial_for_code(WATERING_CAN_UPGRADED)` and `tutorial_for_code(WATERING_CAN_ALREADY_UPGRADED)` must both return `&""`; buying the can must not complete the existing Reinvest / seed-purchase tutorial.

## Shop design

Keep the existing fixed seed shop and add exactly one fourth row.

### Selection model

The current panel assumes three crop rows. Replace that panel-local assumption with one panel-local selected row index `0..3`:

- rows 0–2: existing Turnip/Potato/Pumpkin purchase behavior;
- row 3: efficient watering-can upgrade.

No product catalog, SKU type, equipment list, or data-driven shop registry is needed.

Keep `selected_kind()` crop-only for rows 0–2 so the current seed-shop integration contract remains truthful; add/use a row accessor for tests/navigation rather than representing row 3 as a fake `CropKind`.

Keyboard contract:

- S advances through all four rows and wraps can → Turnip;
- W reverses through all four rows and wraps Turnip → can;
- modulus is 4, never `CropKind.size()`;
- seed rows keep A/D quantity and M max behavior;
- on row 3, hide Minus/Plus/Quantity/Max and make A/D/M no-ops;
- Enter on an unowned row 3 emits one dedicated `upgrade_requested` request even when money is insufficient; the session remains the authority that returns `INSUFFICIENT_FUNDS`;
- Enter on an owned row 3 emits nothing.

Signal flow stays explicit:

`ShopPanel.upgrade_requested`
→ `GameHud.upgrade_requested`
→ `WorldShell._on_upgrade_requested()`
→ `GameSession.buy_watering_can_upgrade()`

### Fourth-row presentation

Use `assets/ui/icons/watering-can-efficient.png`.

Show:

- name: **Efficient Can**;
- price from `GameRules.WATERING_CAN_UPGRADE_PRICE`;
- benefit copy formatted from the base/upgraded results of `GameRules.effective_action_cost()`, yielding **Water 2→1 STA** at current values;
- footer action **BUY · 200G** whenever unowned, whether affordable or not;
- footer action **OWNED** once purchased.

When owned, Enter does not emit another request from the panel, while the session duplicate guard remains authoritative for direct callers/tests.

Keep the existing 50px rows + 6px gaps and use one fixed, non-scrolling layout. Pin the native 640×360 geometry so implementation does not improvise:

- move the existing frame from `x=128..512, y=52..308` to **`x=128..512, y=24..336`**;
- keep Header at local `y=2..40`;
- grow Body to local `y=40..275`;
- keep rows 0–2 at local Body `y=8..58`, `64..114`, `120..170`;
- add row 3 at local Body **`y=176..226`**;
- move Footer to local **`y=275..310`**.

No scrolling or responsive shop layout is needed for one additional row.

## Immediate player feedback

A successful purchase uses the existing `_finish_command() → render() → ShopPanel.present()` refresh path. While the shop modal is open, HUD chrome is intentionally hidden, so the immediately visible changes are:

- shop money decreases;
- row 3 becomes **OWNED**.

The same render also updates the hidden watering action icon from the snapshot. After Esc closes the shop, the normal HUD/world paths expose:

- Action_2 using `watering-can-efficient.png`;
- a valid watering target showing **1 stamina** through HPA-459's preview-driven hint.

Do not add a second refresh path or special-case hint text. There is no new action slot and no alternate watering command. The world watering FX continues using `watering-can-overlay.png`.

Map `WATERING_CAN_UPGRADED` to the existing `COMMERCE_SFX` beside `SEEDS_PURCHASED`; no new audio asset or framework is needed.

## Persistence

Keep `SaveFileCodec.SCHEMA_VERSION == 2`. The codec is intentionally field-blind; this feature does not need a format-envelope change.

The new `watering_can_upgraded` state field is required and must be boolean. Add it to `state()`, validate it in `GameSession.state_error()`, and restore it in `restore_state()`.

Intentional compatibility behavior:

- a current schema-2 save with the boolean loads normally;
- an older schema-2 save that lacks the field still decodes successfully, then fails `GameSession.state_error()`;
- AppRoot therefore follows the existing loaded-but-incompatible path: Continue disabled with **“Save is incompatible; start a New Game.”**;
- non-boolean values are likewise incompatible;
- never default a missing field to false and do not add a migration.

This deliberately avoids the codec-level `invalid` / **“Save unavailable”** path that a schema bump would create.

New Game naturally resets the flag by constructing a fresh `GameSession`. The existing overnight save timing stays unchanged; purchasing the upgrade does not add a mid-day save.

## Verification strategy

### Rules and session

Pin:

- price = 200G;
- base watering = 20 min / 2 stamina;
- upgraded watering = 20 min / 1 stamina;
- every other action cost is identical regardless of the flag;
- six base waterings and twelve upgraded waterings each consume 12 stamina;
- exact-funds purchase succeeds;
- insufficient funds, duplicate purchase, and wrong-location purchase are atomic no-ops;
- rain remains a no-op before budget spending;
- preview cost and actual watering cost agree at base/upgraded stamina boundaries.

### Persistence

Pin:

- new sessions start false;
- state/snapshot include the flag;
- restore preserves true/false and upgraded effective cost;
- `SaveFileCodec.SCHEMA_VERSION` remains 2;
- a schema-2 save missing the field decodes at the repository layer but is rejected by `GameSession.state_error()`;
- missing/wrong-type flag disables Continue with **“Save is incompatible; start a New Game.”**, not **“Save unavailable”**;
- no default or migration is introduced.

### UI and integration

Pin:

- four-row W/S navigation and both wrap directions;
- seed rows retain quantity behavior and `selected_kind()` remains crop-only;
- row 3 hides quantity chrome and A/D/M are no-ops;
- at 150G, row 3 is visible, footer still says **BUY · 200G**, Enter still emits, and the session returns `INSUFFICIENT_FUNDS`;
- successful purchase updates open-shop money + **OWNED** immediately;
- after Esc, Action_2 uses the efficient icon and a valid watering target shows **1 stamina**;
- Owned Enter emits nothing while a direct duplicate session command still returns the dedicated already-owned code;
- buy → water → sleep → Continue restores ownership/effective cost;
- the fixed frame rectangle remains `128..512 × 24..336` at 640×360.

### Pacing and finale

Keep the existing no-upgrade Day-14 route unchanged.

Clone the existing representative reinvestment route and insert the upgrade between the first shipment settlement and the two new Turnip seeds. Pin the exact checkpoints:

- first shipment settlement: **255G**;
- upgrade purchase: **55G** and `watering_can_upgraded == true`;
- two Turnip seeds: **15G**;
- final shipped totals unchanged at **5 crops / 175G**;
- result tier remains **`promising_farmer`**;
- final result money is **85G** after the second 70G shipment;
- finale is triggered on Day 14 and no Day 15 exists.

Do not clone the entire finale into another E2E. One focused restore-based real-input E2E proves the cross-surface path without simulating four growth days: launch from a valid 255G schema-2 state with one planted, unwatered crop → buy through real shop keyboard → Esc → assert icon/hint → water once → sleep/save → relaunch Continue → assert ownership/effective cost persists.

## Files expected to change

Primary implementation:

- `scripts/game/game_rules.gd`
- `scripts/game/game_session.gd`
- `scripts/ui/shop_panel.gd`
- `scenes/ui/shop_panel.tscn`
- `scripts/ui/game_hud.gd`
- `scripts/world/world_shell.gd`

Focused tests:

- `tests/unit/test_game_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_content_rules.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`
- `tests/e2e/gameplay_day_one_test.gd`

Visual review updates only the existing `02-seed-shop` golden. Do not add a 15th visual state for the owned row; pin **OWNED** in gameplay-shell integration. `tests/visual/ui_fixture_factory.gd` already starts from `GameSession.new().state()`, so the required boolean enters fixtures without bespoke fixture state.

Documentation may update `README.md` / `CLAUDE.md` only where the shipped behavior or ownership seam needs recording.

## Non-goals

No second watering tier, upgrade tree, equipment inventory, resale, crafting, workbench, can capacity/refill, durability, charge mechanic, area watering, range increase, automatic tool switching, stamina refill, passive recovery, crop-price rebalance, new crop/map/content, extra save slot, mid-day autosave, migration layer, new art, new SFX, or generic shop/item framework.
