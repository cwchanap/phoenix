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

1. **One authority, not three managers.** Farming, day rhythm, and economy share mutation ordering and the overnight transaction. Keep them in one `GameSession` instead of coordinating separate farming/day/economy managers.
2. **Pure content/rules may be extracted; mutable authority may not.** A small `GameRules` helper owns closed crop tables, action costs, formatting, visual-stage math, and payout math. It has no mutable game state.
3. **Godot-native adapters stay thin.** `WorldShell` coordinates input and UI; `FarmView` mirrors snapshots; `GameHud` emits intentions and renders data. None owns prices, crop growth, time costs, shipping totals, or day transitions.
4. **Expected failures are atomic values.** Gameplay mistakes return stable result codes after validation and before mutation. Programmer/configuration errors fail loudly.
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

- Farm cells: existing `WorldContract.FARM_PATCH`, `x=2..4`, `y=7..9`, nine cells total.
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

- Day `1`, time `06:00` / `360`, stamina `20 / 20`, sunny weather.
- Action cutoff `22:00` / `1320`; an action ending exactly at 22:00 succeeds.
- Money `150G`.
- Seeds: Turnip `3`, Potato `0`, Pumpkin `0`.
- Harvested crops and pending shipment: all `0`.
- Selected farming action: Hoe; selected seed: Turnip.
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

- Day 1 is sunny; later days use a 25% rain chance.
- Rain makes every planted crop eligible to advance overnight and makes tilled soil visually wet.
- Manual watering on a rainy day returns a failure without changing time, stamina, or watering flags.
- Sleep is allowed at any active-day time from 06:00 through 22:00.
- Day 14 is fully playable.
- Sleeping on Day 14 returns `day-limit-reached` without advancing to Day 15 and without settling pending shipment. HPA-597 replaces this temporary boundary.

## Architecture

### `GameRules`: closed pure tables and helpers

Create `scripts/game/game_rules.gd` as a statically typed `RefCounted` helper. It owns:

- `CropKind`: Turnip, Potato, Pumpkin;
- `FarmingAction`: Hoe, Seeds, Watering Can, Hands;
- `Weather`: Sunny, Rainy;
- crop display names, growth nights, seed prices, and sale values;
- action costs and fixed daily constants;
- stable crop-key conversion via `crop_key(kind)` and `crop_kind_from_key(key)`;
- `visual_stage(kind, progress) -> int` and `is_mature(kind, progress) -> bool`;
- `evaluate_action_budget(time_minutes, stamina, action) -> Dictionary`;
- `shipment_payout(counts) -> Dictionary`;
- `weather_from_roll(value) -> Weather`; and
- `format_time(minutes) -> String`.

`GameRules` owns no farm, inventory, money, day, weather source, nodes, signals, or callbacks. The helper does not become a generic item/economy framework.

Action-budget validation checks the 22:00 cutoff before stamina. `weather_from_roll` accepts values in `[0.0, 1.0)` and maps values below `0.25` to rain. Invalid helper inputs are programmer errors.

### `GameSession`: the only mutable gameplay authority

Create `scripts/game/game_session.gd` as a statically typed `RefCounted`. It imports `GameRules` and logical cells from `WorldContract`, but owns no Godot scene node.

The session owns day/time/stamina/weather, selected action/seed, row-major nine-cell farm state, seed and harvested-crop counts, money, pending shipment, optional pending morning summary, and one private weather-roll callable used only by successful day transitions.

The production constructor uses `randf` for later-day weather. Tests may inject a callable returning deterministic floats. The callable never appears in a snapshot.

Use direct methods only:

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

`target_cell` is `Variant` only because current targeting can be `null` or `Vector2i`; commands validate it immediately. Do not add a generic dispatch API.

A command result is a fresh dictionary with exactly `ok: bool` and `code: StringName`. UI maps codes to text rather than inferring success from state differences.

### Snapshot boundary

`GameSession.snapshot()` returns fresh, JSON-serializable gameplay data:

- day, time, stamina, max stamina, and stable weather key;
- stable selected-action and selected-seed keys;
- money;
- seed, harvested-crop, and pending-shipment counts keyed by `turnip`, `potato`, `pumpkin`;
- nine farm entries with `position`, `soil`, and optional crop `{kind, growth, watered_today}`, where `kind` is the stable crop key;
- fixed bed/shop/shipping logical cells; and
- optional pending morning-summary data.

The snapshot excludes player position/facing, camera, projected coordinates, sprite frames, Godot nodes/resources, panel state, focus, quantity selection, and the weather callable. Nested dictionaries/arrays are deep-copied on every snapshot. This is the shape HPA-598 may later serialize; HPA-589 itself adds no persistence.

## Command semantics

### Shared lifecycle and validation

While a morning summary is pending, farming, selection, buying, depositing, and sleep return `day-summary-pending` without mutation. `acknowledge_morning_summary` is the only gameplay command allowed through that gate.

Farming commands validate target → farm membership → command-specific state → time → stamina. Invalid farm state therefore wins over affordability; time wins over stamina when both budgets are insufficient.

### Hoe

Reject crop-bearing with `crop-present`; reject already tilled with `already-tilled`; evaluate Hoe budget; then commit soil/time/stamina together and return `soil-tilled`.

### Plant

Reject `soil-untilled`, then `crop-present`, then `no-selected-seeds`; evaluate Seeds budget; then create selected crop at growth 0, decrement its seed count, commit budget, and return `crop-planted`.

### Water

Reject `no-crop`, then `crop-mature`; on rain return `rain-waters-crops` before checking `already-watered` and without cost; otherwise reject `already-watered`, evaluate Water budget, set `watered_today`, and return `crop-watered`.

### Harvest

Reject `no-crop`, then `crop-immature`; evaluate Hands budget; then remove crop, leave tilled soil, increment its harvested count, commit budget, and return `crop-harvested`.

### Seed selection and buying

`select_seed` is free during active play and returns `seed-selected`.

`buy_seeds` validates active-day gate → target equals shop → positive quantity → funds. Success deducts `seed_price × quantity`, adds seeds, and returns `seeds-purchased`. Stock is unlimited. Failures are `not-at-shop`, `invalid-quantity`, `insufficient-funds`, with no mutation.

### Shipping deposit

`deposit_crop` validates active-day gate → target equals shipping → positive quantity → carried harvested count. Success removes the carried quantity immediately, adds it to pending shipment, and returns `crop-deposited`. Deposits are final. Failures are `not-at-shipping-bin`, `invalid-quantity`, `insufficient-crops`, with no mutation.

### Sleep, crop growth, and one-time settlement

`sleep` validates before mutation: no summary pending → target is bed → day below 14 → next weather roll valid → pending payout valid.

One successful transition then:

1. advances each non-mature crop by one when manually watered or when the completed day was rainy;
2. resets daily watering flags;
3. credits shipping payout to money;
4. clears pending shipment;
5. increments day;
6. resets time to 360 and stamina to 20;
7. stores next weather;
8. creates one authoritative morning summary;
9. returns `day-advanced`.

The summary contains `completed_day`, `next_day`, `crops_advanced`, `next_weather`, `stamina_restored`, itemized shipment lines, `shipping_income`, and `money_after_shipping`.

Income is credited only during successful sleep. Summary acknowledgment only clears the summary and returns `day-started`; it never pays again. Duplicate sleep is blocked. Day-14 rejection does not call the weather source or settle shipping.

## World and interaction adapter

### `WorldContract`

Extend `scripts/world/world_contract.gd` only with `BED_CELL`, `SHOP_CELL`, `SHIPPING_CELL`, and `SHIPPING_FOOTPRINT`. Keep all HPA-590 shell constants unchanged.

### `PlayerController`

Keep movement/facing/collision ownership in `PlayerController`. Add `input_enabled`, `set_input_enabled(enabled)`, and `current_target_cell()`. When disabled, accept no movement and zero velocity; do not move player position/facing into `GameSession`.

### `WorldShell`

`WorldShell` becomes the thin runtime coordinator and the only production holder of a `GameSession` reference. It constructs the session, routes keyboard/HUD intentions to direct commands, refreshes HUD and FarmView after commands, and disables player/world input while a modal or morning summary blocks play.

Inputs are 1/2/3/4 for farming action, Space to apply to the current target, and E to interact. E at bed/shop/shipping opens the corresponding UI; E elsewhere shows `nothing-to-interact` without mutating the session. Economy commands still revalidate target inside `GameSession`.

## Farm and world rendering

Create `scripts/world/farm_view.gd` plus a `FarmView` world node. `FarmView.refresh(snapshot)` reconciles exactly nine soil/crop sprite pairs using existing `proof-soil.png` and `proof-crops.png`.

- untilled: no soil/crop sprite;
- tilled sunny/dry: dry soil frame;
- tilled watered or rainy: wet soil frame;
- crop frame: convert snapshot crop key through `GameRules.crop_kind_from_key`, then `int(kind) * 4 + GameRules.visual_stage(kind, growth)`.

World position comes from `WorldMath.grid_to_world`. Gameplay snapshots never contain frame indices.

Reuse frame 2 of `proof-scenery.png` as the shipping bin, anchor at logical center `(6.5, 10.5)`, add its collision footprint, and keep it in the Y-sorted `Entities` container. The existing building remains the shop. No broad new asset pipeline is required.

## HUD and panels

Create one `CanvasLayer` + `Control` UI scene, `scenes/ui/game_hud.tscn`, with `scripts/ui/game_hud.gd`. Keep presentation consolidated for the MVP rather than one controller/scene per panel.

The always-visible HUD shows day, formatted time, weather, stamina, money, four farming actions, selected seed and three seed counts, three harvested counts, pending shipment total, and contextual E hint.

The same Control owns four mutually exclusive panels: Seed Shop, Shipping, Sleep Confirmation, Morning Summary.

Shop and Shipping preserve the prior interaction shape without extracting a reusable component yet: three crop rows, one `SpinBox` (providing minus/plus adjustment), one `Max` button, and explicit Buy/Deposit. Shop Max is `floor(money / seed_price)`; Shipping Max is carried quantity. Quantity/selected row/focus/submission are UI-only and reset when closed. Escape closes Shop/Shipping/Sleep Confirmation; Morning Summary can only leave through a successful Start Day acknowledgment.

Panels block movement/farming input. Morning summary is authoritative; sleep confirmation is presentation-only and absent from the gameplay snapshot.

## Testing and verification

### Direct GUT

Vendor/pin GUT 9.7.1 and create `tests/unit/test_game_rules.gd` plus `tests/unit/test_game_session.gd`.

Rules tests prove exact crop/order tables, 3/5/7 maturity, visual-stage boundaries, exact action costs, 22:00 cutoff/time-before-stamina precedence, 25% weather mapping, and stable itemized payout math.

Session tests prove starter state/nine cells; ordered farming guards and atomic failures; sunny watering cost; rainy watering zero-mutation rejection plus rainy overnight growth; all three crop lifecycles; purchases/deposits and rollback; immediate carried-crop removal; one-time overnight payout and pending clear; blocking summary; duplicate sleep/ack cannot pay twice; Day 14 preserves pending shipment; deep snapshot isolation; and one full buy→farm→ship→payout→reinvest journey using public commands only.

### Headless scene smoke

Add `tests/headless/gameplay_shell_smoke.gd` that loads real `world.tscn` and proves GameSession/FarmView/HUD/shipping composition, nine projected farm anchors, input gating, interaction-panel routing, and summary blocking. Keep existing project/world-math/world-shell smokes intact. This is a bounded composition smoke, not a new E2E framework.

### Clean verifier

Keep one verifier and append direct GUT plus gameplay smoke:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Final verification also runs `git diff --check main...HEAD` and the committed-archive `./tools/verify-clean.sh`.

## Expected production shape

```text
scripts/game/game_rules.gd            # closed tables + pure helpers
scripts/game/game_session.gd          # only mutable gameplay authority
scripts/world/world_contract.gd       # fixed world/interaction coordinates
scripts/world/world_shell.gd          # runtime coordinator only
scripts/world/farm_view.gd             # snapshot -> soil/crop sprites
scripts/player/player_controller.gd   # movement/facing/target + input gate
scripts/ui/game_hud.gd                 # HUD/panels + intention signals
scenes/world/world.tscn               # compose farm, shipping bin, HUD
scenes/ui/game_hud.tscn               # one consolidated gameplay UI
project.godot                          # gameplay input actions
```

Tests add pinned `addons/gut`, two unit files, one gameplay scene smoke, and verifier updates. No other production subsystem is required.

## Alternatives considered

### A. One `GameSession` + pure `GameRules` + thin adapters — chosen

Smallest shape that preserves atomic overnight behavior, gives GUT a framework-free seam, and gives HPA-598 one obvious future save boundary.

### B. Separate farming, clock/weather, inventory, and economy managers — rejected

They immediately require cross-manager transactions for plant costs, harvest inventory, sleep growth, shipping settlement, and summary blocking. That is more coordination than the MVP needs.

### C. Put gameplay state directly on scene nodes/resources — rejected

This scatters mutation across UI/world nodes, weakens atomic rollback tests, and leaves the persistence port without one authoritative model.

### D. Generic command/event/item framework — rejected

There are four farming actions, three crops, and three interaction types. Closed enums/direct methods are clearer and cheaper until the product actually outgrows them.

## Non-goals

No villagers, dialogue, gifting, relationships, persistence, save migration, tutorial prompts, Day-14 finale, audio, broad polish, seasons, crop death, tool upgrades, inventory capacity, dynamic pricing, generic item database, event bus, registry, service locator, multiple maps, browser export, or release packaging. Do not redesign HPA-590 movement/camera/projection or rebalance completed-prototype values.

## Acceptance summary

HPA-589 is complete when one normal Godot play session can buy seeds, farm all three crops across repeatable days, harvest, ship, receive one exact overnight payout, acknowledge the blocking summary, and reinvest; rainy/sunny action rules and atomic invalid actions are proven directly; Day 14 remains playable but cannot reach Day 15; direct GUT coverage protects rules/economy/day transitions; and the existing clean Godot shell remains green.