# Phoenix Godot Gameplay Port Design (HPA-589)

**Status:** Ready for implementation on the same draft PR

**Date:** 2026-08-22

**Delivery:** One PR for HPA-589. This planning branch is the delivery branch; implementation extends the same PR rather than opening a second implementation PR.

## Source of truth

This design implements [HPA-589](https://linear.app/cwchanap/issue/HPA-589/godot-gameplay-port-restore-farming-daily-rhythm-and-the-three-crop), the second active Godot slice under HPA-587.

HPA-590 is complete and `main` now contains only the Godot 4.7.1 isometric shell. The prior Phaser/Tauri code remains in Git history and its completed HPA-591, HPA-592, and HPA-593 specifications remain behavioral and balance references only. Reimplement the behavior in Godot; do not recreate the previous TypeScript/Svelte/Phaser layering.

The live Linear issue remains authoritative if this document and the ticket disagree.

## Outcome

Restore one complete, repeatable gameplay loop in Godot:

`buy seed → hoe → plant → water → sleep → grow → harvest → ship → receive income → buy more seeds`

The player can use the existing nine-cell farm, grow Turnip/Potato/Pumpkin, manage action time and stamina, experience sunny/rainy days, buy seeds, deposit harvested crops, sleep, receive one overnight shipping payout, dismiss a blocking morning summary, and repeat through playable Day 14.

`GameSession` is the only mutable gameplay-rules authority. Player/world position, Godot rendering nodes, camera state, current panel selection, quantity widgets, focus, and other presentation state stay outside the authoritative gameplay snapshot.

## Design principles

1. **One authority, not three managers.** Farming, day rhythm, and economy share mutation ordering and the overnight transaction. Keep them in one `GameSession` instead of coordinating `FarmingManager`, `DayManager`, and `EconomyManager` objects.
2. **Pure content/rules may be extracted; mutable authority may not.** A small `GameRules` helper owns closed crop tables, action costs, formatting, visual-stage math, and payout math. It has no mutable game state.
3. **Godot-native adapters stay thin.** `WorldShell` coordinates input and UI; `FarmView` mirrors snapshots; `GameHud` emits intentions and renders data. None owns prices, crop growth, time costs, shipping totals, or day transitions.
4. **Expected failures are atomic values.** Gameplay mistakes return stable result codes after validation and before mutation. Exceptions are reserved for programmer/configuration errors.
5. **No speculative framework.** No event bus, command middleware, registry, service locator, generic inventory/item system, save abstraction, quest system, or plugin architecture is introduced for this slice.

## Fixed platform and dependency decisions

- Godot: standard non-.NET **4.7.1**, statically typed GDScript.
- GUT: pin **9.7.1**, the GUT line with Godot 4.7 compatibility, and run it from the existing clean verifier.
- Keep the existing single GitHub Actions verification job; do not add a parallel unit-test job or CI matrix.
- Keep `./tools/verify-clean.sh` as the one clean-checkout entry point.
- No C#, GDExtension, JavaScript bridge, Tiled runtime importer, browser packaging, or legacy runtime compatibility.

## Closed gameplay values

Parity work preserves these values. Balance changes belong to HPA-599.

### World interactions

- Farm cells: the existing `WorldContract.FARM_PATCH`, `x=2..4`, `y=7..9`, nine cells total.
- Shop interaction: `Vector2i(6, 7)`, using the existing building as the seed shop.
- Bed interaction: `Vector2i(6, 8)`.
- Shipping interaction: `Vector2i(6, 10)`.
- Shipping-bin collision footprint: `Rect2(6.2, 10.2, 0.6, 0.6)`.
- Existing map size, projection, player spawn, tree/building footprints, and camera bounds remain unchanged.

### Crops

| Crop | Watered nights to mature | Seed price | Sale value |
| --- | ---: | ---: | ---: |
| Turnip | 3 | 20G | 35G |
| Potato | 5 | 40G | 75G |
| Pumpkin | 7 | 70G | 140G |

All three use four visual stages. Authoritative growth remains integer watered-night progress; rendering derives a stage using:

```text
min(3, floor(progress * 3 / growth_nights))
```

### New-game state

- Day: `1`.
- Time: `06:00` / `360` minutes since midnight.
- Action cutoff: `22:00` / `1320` minutes; ending exactly at 22:00 is allowed.
- Stamina: `20 / 20`.
- Weather: sunny.
- Money: `150G`.
- Seeds: Turnip `3`, Potato `0`, Pumpkin `0`.
- Harvested crops: all `0`.
- Pending shipment: all `0`.
- Selected farming action: Hoe.
- Selected seed: Turnip.
- All nine farm cells: untilled, empty, unwatered.

### Farming action costs

| Action | Time | Stamina |
| --- | ---: | ---: |
| Hoe | 30 min | 3 |
| Seeds / Plant | 20 min | 1 |
| Watering Can | 20 min | 2 |
| Hands / Harvest | 20 min | 1 |

Walking, facing, target selection, farming-action selection, seed selection, buying, depositing, sleep confirmation, panel navigation, and morning-summary acknowledgment are free.

### Weather and day boundary

- Day 1 is sunny.
- Later days use a 25% rain chance.
- Rain makes every planted crop eligible to advance overnight and makes tilled soil visually wet.
- Manual watering on a rainy day returns a failure without changing time, stamina, or watering flags.
- Day 14 is fully playable.
- Sleeping on Day 14 returns `day-limit-reached` without advancing to Day 15 and without settling pending shipment. HPA-597 replaces this temporary boundary.

## Architecture

### `GameRules`: closed pure tables and helpers

Create `scripts/game/game_rules.gd` as a statically typed `RefCounted` helper. It owns:

- `CropKind`: Turnip, Potato, Pumpkin.
- `FarmingAction`: Hoe, Seeds, Watering Can, Hands.
- `Weather`: Sunny, Rainy.
- crop display names, growth nights, seed prices, and sale values;
- action costs and the fixed daily constants;
- `visual_stage(kind, progress) -> int`;
- `is_mature(kind, progress) -> bool`;
- `evaluate_action_budget(time_minutes, stamina, action) -> Dictionary`;
- `shipment_payout(counts) -> Dictionary`;
- `weather_from_roll(value) -> Weather`; and
- `format_time(minutes) -> String`.

`GameRules` owns no farm, inventory, money, day, weather source, nodes, signals, or callbacks. The helper does not become a generic item/economy framework.

Action-budget validation checks the 22:00 cutoff before stamina. `weather_from_roll` accepts values in `[0.0, 1.0)` and maps values below `0.25` to rain. Invalid helper inputs are programmer errors and assert/fail loudly rather than becoming player-facing result codes.

### `GameSession`: the only mutable gameplay authority

Create `scripts/game/game_session.gd` as a statically typed `RefCounted` class. It imports `GameRules` and the logical cells from `WorldContract`, but it owns no Godot scene node.

The session owns:

- day, time, stamina, and current weather;
- selected farming action and selected seed;
- nine farm-cell states in deterministic row-major order;
- seed counts and harvested-crop counts;
- money and pending-shipment counts;
- optional pending morning summary; and
- one private weather-roll callable used only by successful day transitions.

The production constructor uses `randf` for later-day weather. Tests may inject a callable returning deterministic floats. The callable never appears in a snapshot.

The runtime calls these direct methods; do not add a generic `dispatch` API:

```gdscript
func snapshot() -> Dictionary
func select_action(action: GameRules.FarmingAction) -> Dictionary
func select_seed(kind: GameRules.CropKind) -> Dictionary
func apply_selected_action(target_cell: Variant) -> Dictionary
func hoe(target_cell: Variant) -> Dictionary
func plant(target_cell: Variant) -> Dictionary
func water(target_cell: Variant) -> Dictionary
func harvest(target_cell: Variant) -> Dictionary
func buy_seeds(kind: GameRules.CropKind, quantity: int, target_cell: Variant) -> Dictionary
func deposit_crop(kind: GameRules.CropKind, quantity: int, target_cell: Variant) -> Dictionary
func sleep(target_cell: Variant) -> Dictionary
func acknowledge_morning_summary() -> Dictionary
```

`target_cell` is `Variant` only because the current world targeting contract can be `null` or `Vector2i`. Every command validates that boundary immediately.

A command result is a fresh dictionary with exactly `ok: bool` and `code: StringName`. UI maps codes to text; UI does not infer whether a mutation succeeded from snapshot differences.

### Snapshot boundary

`GameSession.snapshot()` returns fresh, JSON-serializable data containing gameplay state only:

- `day`, `time_minutes`, `stamina`, `max_stamina`, and weather key;
- selected action and selected seed keys;
- `money`;
- seed, harvested-crop, and pending-shipment counts keyed by stable crop keys;
- nine farm entries with `position`, `soil`, and optional crop `{kind, growth, watered_today}`;
- the fixed bed/shop/shipping logical cells; and
- optional pending morning-summary data.

The snapshot excludes player position/facing, camera, projected coordinates, sprite frames, Godot nodes/resources, panel state, focus, quantity selection, and the injected weather callable.

Nested dictionaries/arrays are duplicated on every snapshot. This is the shape HPA-598 may later serialize; HPA-589 does not add persistence.

## Command semantics

### Shared lifecycle and target validation

While a morning summary is pending, farming, selection, buying, depositing, and sleep return `day-summary-pending` without mutation. `acknowledge_morning_summary` is the only gameplay command allowed through that gate.

Farming commands then validate:

1. target is a `Vector2i`;
2. target is one of the nine farm cells;
3. command-specific farm prerequisites;
4. action time budget;
5. stamina budget.

This preserves the previous precedence: an invalid farm state wins over affordability, and time wins over stamina when both budgets are insufficient.

### Hoe

After common target validation:

1. reject a crop-bearing cell with `crop-present`;
2. reject already-tilled soil with `already-tilled`;
3. evaluate Hoe budget;
4. commit soil + time + stamina together; return `soil-tilled`.

### Plant

After common target validation:

1. reject untilled soil with `soil-untilled`;
2. reject an existing crop with `crop-present`;
3. reject zero selected-seed inventory with `no-selected-seeds`;
4. evaluate Seeds budget;
5. create selected crop at growth `0`, decrement that seed, and commit budget together; return `crop-planted`.

### Water

After common target validation:

1. reject empty soil with `no-crop`;
2. reject mature crop with `crop-mature`;
3. when rainy, return `rain-waters-crops` before the already-watered check and without cost;
4. reject already-watered crop with `already-watered`;
5. evaluate Water budget;
6. set `watered_today = true` and commit budget together; return `crop-watered`.

### Harvest

After common target validation:

1. reject empty soil with `no-crop`;
2. reject non-mature crop with `crop-immature`;
3. evaluate Hands budget;
4. remove crop, preserve tilled soil, increment matching carried crop, and commit budget together; return `crop-harvested`.

### Seed selection and buying

`select_seed` is free during active play and returns `seed-selected`.

`buy_seeds` validates in this order:

1. active-day gate;
2. target equals `WorldContract.SHOP_CELL`;
3. quantity is a positive integer and multiplication is within normal integer range;
4. player has enough money.

Success deducts `seed_price * quantity`, increments the matching seed count, and returns `seeds-purchased`. Shop stock is unlimited. Failure is `not-at-shop`, `invalid-quantity`, or `insufficient-funds` with no mutation.

### Shipping deposit

`deposit_crop` validates in this order:

1. active-day gate;
2. target equals `WorldContract.SHIPPING_CELL`;
3. quantity is positive;
4. carried harvested inventory has enough of that crop.

Success removes the exact carried quantity immediately, adds it to pending shipment, and returns `crop-deposited`. Deposits are final. Failure is `not-at-shipping-bin`, `invalid-quantity`, or `insufficient-crops` with no mutation.

### Sleep, crop growth, and one-time shipping settlement

`sleep` validates before mutation:

1. no morning summary is already pending;
2. target equals `WorldContract.BED_CELL`;
3. current day is below 14;
4. obtain and validate the next weather roll;
5. calculate the pending-shipment payout from `GameRules`.

A successful transition performs one direct transaction:

1. For each non-mature crop, advance growth by one if `watered_today` is true **or** the completed day's weather is rainy.
2. Reset `watered_today` on every surviving crop.
3. Credit the exact shipping payout to money.
4. Clear all pending-shipment counts.
5. Increment day by one.
6. Reset time to `360` and stamina to `20`.
7. Store the next day's weather.
8. Create one authoritative morning summary.
9. Return `day-advanced`.

The summary contains `completed_day`, `next_day`, `crops_advanced`, `next_weather`, `stamina_restored`, itemized shipment lines, `shipping_income`, and `money_after_shipping`.

Income is credited only in step 3. `acknowledge_morning_summary` only clears the summary and returns `day-started`; it never pays again. Duplicate sleep is blocked by the summary gate. Day-14 rejection does not call the weather source or settle shipping.

## World and interaction adapter

### `WorldContract`

Extend `scripts/world/world_contract.gd` with only fixed logical interaction data:

- `BED_CELL`;
- `SHOP_CELL`;
- `SHIPPING_CELL`;
- `SHIPPING_FOOTPRINT`.

Keep the existing shell constants unchanged.

### `PlayerController`

Keep movement/facing/collision ownership in `PlayerController`. Add only:

- `var input_enabled: bool = true`;
- `func set_input_enabled(enabled: bool) -> void`;
- `func current_target_cell() -> Variant`.

When disabled, `_physics_process` sets velocity to zero and still keeps visuals/target stable without accepting movement. Do not move player position/facing into `GameSession`.

### `WorldShell`

`WorldShell` becomes the runtime coordinator and the only production holder of a `GameSession` reference. It:

- constructs the session;
- routes 1/2/3/4 and Space to direct session commands;
- routes `E` by current target to sleep confirmation, shop panel, or shipping panel;
- forwards HUD button intentions to the same direct session commands;
- refreshes HUD and farm visuals after every command;
- disables world input while any modal panel is open or a morning summary is pending; and
- maps an unrelated `E` target to presentation feedback `nothing-to-interact` without mutating `GameSession`.

Economy commands still revalidate their required target inside `GameSession`; UI routing is convenience, not authority.

Project input actions become `farm_hoe`, `farm_seeds`, `farm_water`, `farm_hands`, `farm_apply`, and `interact` alongside the existing WASD actions.

## Farm and world rendering

Create `scripts/world/farm_view.gd` and a `FarmView` node under the world scene.

`FarmView.refresh(snapshot)` owns only visual reconciliation for the nine farm cells. It uses the already committed `proof-soil.png` and `proof-crops.png` assets:

- untilled: no soil/crop sprite;
- tilled sunny/dry: dry soil frame;
- tilled watered or rainy: wet soil frame;
- crop frame: crop row × 4 + `GameRules.visual_stage(kind, growth)`.

World position comes from `WorldMath.grid_to_world`. Gameplay snapshots never contain frame indices.

Reuse frame 2 of the existing `proof-scenery.png` as the shipping bin, anchor it at logical center `(6.5, 10.5)`, add its collision footprint, and keep it in the Y-sorted `Entities` container. The existing building is the shop. No new broad asset pipeline is required.

## HUD and panels

Create one `CanvasLayer` + `Control` UI scene, `scenes/ui/game_hud.tscn`, with one script `scripts/ui/game_hud.gd`.

Keep this presentation deliberately consolidated for the MVP instead of creating one scene/controller per panel.

The HUD displays:

- day, formatted time, weather, stamina, money;
- four farming action controls with 1–4 shortcuts;
- selected seed and seed counts;
- harvested crop counts;
- pending-shipment total; and
- a context hint for current target (`E: Seed Shop`, `E: Sleep`, `E: Shipping`).

The same Control owns four mutually exclusive panels:

1. seed shop;
2. shipping;
3. sleep confirmation;
4. morning summary.

Shop and shipping each use the three stable crop rows, one selected row, one quantity `SpinBox`, and an explicit Buy/Deposit button. Quantity and selected row are UI-only and reset on close. No generic quantity component is introduced until there is a third consumer.

Panels block movement and farming input. The morning summary cannot be closed locally; its Start Day button must call `acknowledge_morning_summary` successfully. Sleep confirmation itself is presentation-only and is not included in the authoritative snapshot.

## Tests and verification

### GUT unit tests

Vendor/pin GUT 9.7.1 under `addons/gut` and create:

- `tests/unit/test_game_rules.gd`;
- `tests/unit/test_game_session.gd`.

`test_game_rules.gd` proves:

- exact crop table and stable crop order;
- visual-stage boundaries and maturity at 3/5/7;
- exact action costs;
- 22:00 cutoff and time-before-stamina precedence;
- 25% weather mapping; and
- itemized shipment payout totals in stable crop order.

`test_game_session.gd` proves:

- exact starter state and nine farm cells;
- ordered Hoe/Plant/Water/Harvest guards and atomic failure snapshots;
- sunny watering costs and rainy watering rejection without mutation;
- all three crop lifecycles and maturity boundaries;
- purchases, insufficient funds, and wrong-location rollback;
- deposits, immediate carried-inventory removal, and insufficient-crop rollback;
- one successful sleep credits shipping once, clears pending shipment, advances crops, resets daily budgets, and creates the blocking summary;
- duplicate sleep/acknowledgment cannot pay twice;
- Day 14 cannot advance or settle shipping; and
- one full reinvestment journey completes end to end.

The full-loop test uses only `GameSession` commands; it does not reach into private state or expose mutation hooks.

### Headless scene smoke

Add `tests/headless/gameplay_shell_smoke.gd` to load the real `world.tscn` and prove:

- the `GameSession`, `FarmView`, HUD, shipping-bin collision, and interaction cells compose without parse/runtime errors;
- the nine farm visual anchors use the same projection as target highlighting;
- the player can be input-gated while a panel/summary is blocking;
- shop/bed/shipping targets route to the correct panels; and
- existing world collision, camera, targeting, and depth smoke remain green.

This is a bounded composition smoke, not a new E2E framework.

### Clean verifier

Keep one verifier and append GUT plus gameplay smoke:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Final verification also runs `git diff --check main...HEAD` and confirms `./tools/verify-clean.sh` succeeds from committed `HEAD`.

## Files and ownership

Expected production shape:

```text
scripts/game/game_rules.gd            # closed tables + pure helpers
scripts/game/game_session.gd          # only mutable gameplay authority
scripts/world/world_contract.gd       # fixed world/interact coordinates
scripts/world/world_shell.gd          # runtime coordinator only
scripts/world/farm_view.gd             # snapshot -> soil/crop sprites
scripts/player/player_controller.gd   # movement/facing/target + input gate
scripts/ui/game_hud.gd                 # HUD/panels + intention signals
scenes/world/world.tscn               # compose farm, shipping bin, HUD
scenes/ui/game_hud.tscn               # one consolidated gameplay UI
project.godot                          # gameplay input actions
```

Tests:

```text
addons/gut/**                          # pinned GUT 9.7.1
tests/unit/test_game_rules.gd
tests/unit/test_game_session.gd
tests/headless/gameplay_shell_smoke.gd
tools/verify-clean.sh
```

No other production subsystem is required by the design.

## Alternatives considered

### A. One `GameSession` + pure `GameRules` + thin adapters — chosen

Smallest shape that preserves atomic overnight behavior, gives GUT a framework-free seam, and gives HPA-598 one obvious future save boundary.

### B. Separate farming, clock/weather, inventory, and economy managers — rejected

The managers would immediately need cross-manager transactions for plant costs, harvest inventory, sleep growth, shipping settlement, and summary blocking. That creates more failure ordering and plumbing than the MVP needs.

### C. Put gameplay state directly on scene nodes/resources — rejected

It looks initially Godot-native but scatters mutation across UI/world nodes, makes atomic rollback tests harder, and leaves the persistence port without a clean authoritative model.

### D. Generic command/event/item framework — rejected

There are four farming actions, three crops, and three interaction types. Closed enums/direct methods are clearer and cheaper until the product actually outgrows them.

## Non-goals

HPA-589 does not add villagers, dialogue, gifting, relationships, persistence, save migration, tutorial prompts, Day-14 finale content, audio, broad polish, seasons, crop death, tool upgrades, inventory capacity, dynamic pricing, generic item databases, event buses, registries, service locators, multiple maps, browser export, or release packaging.

It also does not redesign the HPA-590 movement/camera/projection shell or rebalance values from the completed prototype.

## Acceptance summary

HPA-589 is complete when one normal Godot play session can buy seeds, farm all three crops across repeatable days, harvest, ship, receive one exact overnight payout, acknowledge the blocking summary, and reinvest; rainy/sunny action rules and atomic invalid actions are proven directly; Day 14 remains playable but cannot reach Day 15; direct GUT coverage protects rules/economy/day transitions; and the existing clean Godot shell remains green.