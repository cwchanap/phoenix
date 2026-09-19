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
- One-slot persistence serializes `GameSession.state()` through `SaveFileCodec`; unsupported schema versions already disable Continue instead of migrating.
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

UI that needs static explanatory cost text, such as the Almanac, calls the same rules function with the snapshot flag. It must not duplicate “2 vs 1” policy constants.

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

## Shop design

Keep the existing fixed seed shop and add exactly one fourth row.

### Selection model

The current panel assumes three crop rows. Replace that panel-local assumption with one selected row index:

- rows 0–2: existing Turnip/Potato/Pumpkin purchase behavior;
- row 3: efficient watering-can upgrade.

No product catalog, SKU type, equipment list, or data-driven shop registry is needed.

For seed rows, existing A/D quantity and M max behavior remains. On the upgrade row, A/D/M are no-ops; Enter emits one dedicated `upgrade_requested` signal.

Signal flow stays explicit:

`ShopPanel.upgrade_requested`
→ `GameHud.upgrade_requested`
→ `WorldShell._on_upgrade_requested()`
→ `GameSession.buy_watering_can_upgrade()`

### Fourth-row presentation

Use `assets/ui/icons/watering-can-efficient.png`.

Show:

- name: **Efficient Can**
- price: **200**
- benefit copy: **Water 2→1 STA**
- action state: **BUY** when available / **OWNED** after purchase.

When owned, Enter does not emit another request from the panel, while the session duplicate guard remains authoritative for direct callers/tests.

Keep the existing 50px row treatment and grow/reposition the current fixed panel vertically so four rows plus footer fit inside 640×360. Do not add scrolling for one extra row.

## Immediate player feedback

A successful purchase must refresh the same snapshot-driven UI immediately:

- shop row becomes Owned;
- money decreases;
- watering toolbar icon swaps to `watering-can-efficient.png`;
- a currently targeted valid watering hint reports **1 stamina** because HPA-459 reads preview cost;
- Almanac watering cost reports the effective value.

There is no new action slot and no alternate watering command.

Reuse the existing commerce SFX path for the purchase; no new audio asset or audio framework is needed.

## Persistence

Bump `SaveFileCodec.SCHEMA_VERSION` from **2 to 3**.

The new state field is required and must be boolean. `restore_state()` restores it before gameplay resumes.

Intentional compatibility behavior:

- schema 3 + valid boolean → load;
- schema 2 → existing “Unsupported save schema” path;
- missing/non-boolean `watering_can_upgraded` → invalid state;
- no migration and no defaulting old saves to false.

New Game naturally resets the flag by constructing a fresh `GameSession`.

The existing overnight save timing stays unchanged. Purchasing the upgrade does not add a mid-day save.

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
- restore preserves true/false;
- schema 3 round trip preserves ownership;
- schema 2 is rejected;
- missing/wrong-type flag is rejected;
- Continue stays disabled through the existing incompatible-save path.

### UI and integration

Pin:

- shop has four keyboard-reachable rows;
- seed rows retain quantity behavior;
- upgrade row ignores quantity keys;
- 150G shows the upgrade but cannot buy it;
- successful purchase immediately updates money, row state, toolbar icon, and watering hint;
- Owned cannot be purchased twice;
- buy → water → sleep → Continue restores the efficient cost.

### Pacing and finale

Keep the existing no-upgrade Day-14 route unchanged.

Add one deterministic session-level reinvestment route using the 255G starter-shipment checkpoint, buying the upgrade and at least two Turnip seeds, then reaching a valid Day-14 result. Finale scoring assertions stay based on shipped produce only.

Do not clone the entire finale into another E2E. One focused real-input E2E should prove the cross-surface path: buy → updated hint/icon → water → overnight save → Continue.

## Files expected to change

Primary implementation:

- `scripts/game/game_rules.gd`
- `scripts/game/game_session.gd`
- `scripts/ui/shop_panel.gd`
- `scenes/ui/shop_panel.tscn`
- `scripts/ui/game_hud.gd`
- `scripts/ui/almanac_panel.gd`
- `scripts/world/world_shell.gd`
- `scripts/persistence/save_file.gd`

Focused tests:

- `tests/unit/test_game_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_save_file.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/e2e/gameplay_day_one_test.gd`

Documentation may update `README.md` / `CLAUDE.md` only where the shipped behavior or ownership seam needs recording.

## Non-goals

No second watering tier, upgrade tree, equipment inventory, resale, crafting, workbench, can capacity/refill, durability, charge mechanic, area watering, range increase, automatic tool switching, stamina refill, passive recovery, crop-price rebalance, new crop/map/content, extra save slot, mid-day autosave, migration layer, new art, new SFX, or generic shop/item framework.
