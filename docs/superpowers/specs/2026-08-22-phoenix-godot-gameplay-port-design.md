# Phoenix Godot Gameplay Port Design (HPA-589)

**Status:** Ready for implementation on this same draft PR

**Date:** 2026-08-22

**Delivery:** HPA-589 is one PR. The planning branch is the delivery branch; implementation continues here rather than opening a second implementation PR.

## Source of truth

This design implements HPA-589, `[Godot Gameplay Port] Restore farming, daily rhythm, and the three-crop economy`.

HPA-590 is complete and `main` now contains the Godot 4.7.1 isometric world shell. HPA-589 is the next unblocked Phoenix slice and blocks HPA-594. The completed Phaser/Tauri slices remain behavioral references only; do not port their architecture.

The live Linear issue wins if this document and the ticket disagree.

## Outcome

Restore one complete, repeatable Godot gameplay loop:

`buy seed → hoe → plant → water → sleep → grow → harvest → ship → receive income → buy more seeds`

The player can use the existing nine-cell farm, grow Turnip/Potato/Pumpkin, manage time and stamina, experience sunny/rainy days, buy seeds, deposit harvested crops, sleep, receive one overnight payout, dismiss a blocking morning summary, and repeat through playable Day 14.

## Chosen shape

Use the smallest Godot-native structure that gives one clear rules authority without recreating the old web layering:

- `GameRules`: closed enums/tables plus pure formulas.
- `GameSession`: the only mutable gameplay-rules authority.
- `WorldContract`: fixed authored world coordinates and footprints.
- `WorldShell`: runtime coordinator and the single production holder of `GameSession`.
- `PlayerController`: movement/facing/targeting only.
- `FarmView`: snapshot-to-sprite adapter only.
- `GameHud`: HUD/panel presentation plus intention signals only.

Do not add managers, services, event buses, registries, generic item systems, save abstractions, command frameworks, or compatibility layers.

## Fixed platform decisions

- Standard non-.NET Godot **4.7.1**.
- Statically typed GDScript.
- GUT **9.7.1**, the Godot 4.7-compatible GUT line, vendored under `addons/gut/`.
- Keep the existing single GitHub Actions verification job.
- Keep `./tools/verify-clean.sh` as the single clean-checkout verification entry point.
- No C#, GDExtension, browser runtime, Tauri runtime, Tiled runtime importer, or second renderer.

## Frozen gameplay values

Balance changes belong to HPA-599.

### World interactions

- Farm: existing `WorldContract.FARM_PATCH`, `x=2..4`, `y=7..9`, nine cells.
- Shop interaction: `Vector2i(6, 7)` beside the existing building.
- Bed interaction: `Vector2i(6, 8)`.
- Shipping interaction: `Vector2i(6, 10)`.
- Shipping footprint: `Rect2(6.2, 10.2, 0.6, 0.6)`.
- Existing map size, projection, spawn, tree/building footprints, camera bounds, and movement speed remain unchanged.

### Crops

| Crop | Watered nights | Seed price | Sale value |
| --- | ---: | ---: | ---: |
| Turnip | 3 | 20G | 35G |
| Potato | 5 | 40G | 75G |
| Pumpkin | 7 | 70G | 140G |

All crops use four visual stages. Rendering derives the stage from authoritative growth progress:

```text
min(3, floor(progress * 3 / growth_nights))
```

### New game

- Day `1`.
- Time `06:00` / `360` minutes.
- Stamina `20 / 20`.
- Day 1 weather is sunny.
- Money `150G`.
- Seeds: Turnip `3`, Potato `0`, Pumpkin `0`.
- Harvested crops and pending shipment: all `0`.
- Selected action: Hoe.
- Selected seed: Turnip.
- All nine farm cells: untilled, empty, unwatered.

### Action costs

| Action | Time | Stamina |
| --- | ---: | ---: |
| Hoe | 30 min | 3 |
| Seeds | 20 min | 1 |
| Watering Can | 20 min | 2 |
| Hands | 20 min | 1 |

The activity cutoff is `22:00` / `1320`; an action ending exactly at 22:00 succeeds. Walking, selection, shop/shipping interaction, sleep confirmation, panel navigation, and summary acknowledgment are free.

### Weather and day boundary

- Day 1 is sunny.
- Later successful day transitions use a 25% rain chance.
- Rain makes planted crops eligible to advance overnight.
- Manual watering on a rainy day is rejected without changing time, stamina, or watering flags.
- Sleep is allowed during an active day from 06:00 through 22:00.
- Day 14 is playable.
- Sleeping on Day 14 returns `day-limit-reached`, does not consume the weather source, does not settle shipping, and does not advance to Day 15.

## `GameRules`

Create `scripts/game/game_rules.gd` as a statically typed `RefCounted` helper.

It owns only closed, immutable rules/content:

- `CropKind`: Turnip, Potato, Pumpkin.
- `FarmingAction`: Hoe, Seeds, Watering Can, Hands.
- `Weather`: Sunny, Rainy.
- crop display names, growth nights, seed prices, sale values.
- action costs and fixed daily constants.
- stable crop/action/weather keys.
- `visual_stage(kind, progress)`.
- `is_mature(kind, progress)`.
- `evaluate_action_budget(time_minutes, stamina, action)`.
- `shipment_payout(counts)`.
- `weather_from_roll(value)`.
- `format_time(minutes)`.

It owns no farm, inventory, money, day, RNG state, node, signal, callback, or mutable stock.

Budget validation checks time before stamina. `weather_from_roll` accepts `[0.0, 1.0)` and maps `< 0.25` to rain. Invalid helper inputs are programmer/configuration errors.

## `GameSession`

Create `scripts/game/game_session.gd` as a statically typed `RefCounted`.

`GameSession` owns all mutable gameplay state:

- day, time, stamina, weather;
- selected action and seed;
- row-major state for the nine authored farm cells;
- seed inventory and harvested-crop inventory;
- money;
- pending shipment;
- optional pending morning summary; and
- one private weather-roll callable used only by successful day transitions.

Production uses `randf()` for later-day weather. Tests may inject a deterministic callable. The callable never appears in the snapshot.

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

`target_cell` is `Variant` only because targeting may be `null` or `Vector2i`. Commands validate it immediately. Do not add generic dispatch.

Every command result is a fresh dictionary with exactly:

```gdscript
{"ok": bool, "code": StringName}
```

The UI maps stable codes to player-facing text.

## Snapshot boundary

`GameSession.snapshot()` returns fresh gameplay state needed by rendering/UI and later persistence:

- day, time, stamina, max stamina, weather key;
- selected action and selected seed keys;
- money;
- seed, harvested-crop, and pending-shipment counts keyed by `turnip`, `potato`, `pumpkin`;
- nine farm entries containing authored cell position, soil state, and optional crop `{kind, growth, watered_today}`;
- optional pending morning summary.

Every nested dictionary/array is deep-copied.

The snapshot deliberately excludes fixed bed/shop/shipping coordinates. Those are authored world configuration in `WorldContract`, not mutable game state and not something HPA-598 should persist.

It also excludes player position/facing, camera state, projected coordinates, sprite frames, Godot nodes/resources, panel state, quantity/focus state, and the weather callable.

HPA-598 owns the versioned JSON schema, structural validation, and native-to-JSON conversion. HPA-589 only keeps the mutable gameplay boundary clean enough to serialize later.

## Command semantics

### Shared active-day gate

While a morning summary is pending, farming, selection, buying, depositing, and sleep return `day-summary-pending` without mutation. `acknowledge_morning_summary` is the only gameplay command allowed through that gate.

Farming validation order is:

`target → farm membership → command-specific state → time → stamina`

Failed commands preserve the complete snapshot.

### Hoe

Reject crop-bearing soil with `crop-present`, then already-tilled soil with `already-tilled`. Evaluate budget, then commit soil/time/stamina together and return `soil-tilled`.

### Plant

Reject `soil-untilled`, then `crop-present`, then `no-selected-seeds`. Evaluate Seeds budget, then create the selected crop at growth 0, decrement one matching seed, commit budget, and return `crop-planted`.

### Water

Reject `no-crop`, then `crop-mature`. On rain return `rain-waters-crops` before checking `already-watered` and without charging budget. Otherwise reject `already-watered`, evaluate Water budget, set `watered_today`, and return `crop-watered`.

### Harvest

Reject `no-crop`, then `crop-immature`. Evaluate Hands budget, then remove the crop, leave tilled soil, increment carried harvested inventory, commit budget, and return `crop-harvested`.

### Buying

`buy_seeds` validates:

`active-day gate → target == WorldContract.SHOP_CELL → quantity > 0 → sufficient funds`

Success deducts `seed_price × quantity`, adds seeds, and returns `seeds-purchased`. Stock is unlimited.

### Shipping

`deposit_crop` validates:

`active-day gate → target == WorldContract.SHIPPING_CELL → quantity > 0 → sufficient carried crop`

Success removes carried crops immediately, increments pending shipment, and returns `crop-deposited`. Deposits are final.

### Sleep and one-time settlement

`sleep` validates before mutation:

`no summary → target == WorldContract.BED_CELL → day < 14 → next weather roll valid → payout valid`

One successful transition then:

1. advances each non-mature crop by one when manually watered or when the completed day was rainy;
2. resets surviving `watered_today` flags;
3. credits shipping payout;
4. clears pending shipment;
5. increments day;
6. resets time to `360` and stamina to `20`;
7. stores next weather;
8. creates one authoritative morning summary;
9. returns `day-advanced`.

The summary contains completed/next day, crops advanced, next weather, restored stamina, itemized shipping lines, shipping income, and money after shipping.

Summary acknowledgment only clears the summary and returns `day-started`; it never pays again.

## World adapters

### `WorldContract`

Extend `scripts/world/world_contract.gd` only with:

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Keep all HPA-590 constants unchanged.

### `PlayerController`

Keep movement, facing, collision, camera, and target highlight ownership here.

Add:

```gdscript
func set_input_enabled(enabled: bool) -> void
func current_target_cell() -> Variant
```

When disabled, velocity is zero and movement is not processed. Player position/facing never moves into `GameSession`.

### `WorldShell`

`WorldShell` is the thin runtime coordinator and the only production holder of `GameSession`.

It:

- constructs the session;
- connects HUD intentions;
- routes normal-control actions to direct session commands;
- refreshes one fresh snapshot into `FarmView` and `GameHud` after commands;
- opens presentation panels for E interactions;
- owns one derived `world_input_enabled` gate.

The single `world_input_enabled` value is computed from:

- `not hud.has_blocking_modal()`; and
- `snapshot["pending_morning_summary"] == null`.

That same gate must control **both** sides of gameplay input:

1. call `player.set_input_enabled(world_input_enabled)` for movement; and
2. make `WorldShell` ignore `1/2/3/4`, Space, and E while the gate is false.

Do not merely disable player movement while leaving coordinator key routing active behind Shop, Shipping, Sleep Confirmation, or Morning Summary. Do not introduce independent lock flags.

Normal controls:

- `1/2/3/4`: select farming action.
- `Space`: apply selected action to `player.current_target_cell()`.
- `E` at shop: open Shop.
- `E` at shipping: open Shipping.
- `E` at bed: open Sleep Confirmation.
- `E` elsewhere: presentation-only `nothing-to-interact` feedback.

Economy and sleep commands still receive/revalidate the current target in `GameSession`.

## Farm/world rendering

Create `scripts/world/farm_view.gd` and a `FarmView` node.

`FarmView.refresh(snapshot)` reconciles exactly nine soil/crop sprite pairs from `WorldContract.farm_cells()`.

- untilled: no soil/crop sprite;
- tilled dry/sunny: dry soil frame;
- tilled watered or rainy: wet soil frame;
- crop frame: `int(kind) * 4 + GameRules.visual_stage(kind, growth)`.

World positions come from `WorldMath.grid_to_world`; gameplay state never stores frame indices.

Reuse frame 2 of `proof-scenery.png` as the shipping bin. Anchor it at logical center `(6.5, 10.5)`, add the shipping collision footprint, and keep it under the existing Y-sorted `Entities` container. The existing building remains the shop.

## HUD and panels

Create one `CanvasLayer` + `Control` scene at `scenes/ui/game_hud.tscn` with `scripts/ui/game_hud.gd`.

Keep UI consolidated for the MVP rather than introducing one controller/scene per panel.

Always-visible HUD:

- day/time/weather/stamina/money;
- four farming actions;
- selected seed and three seed counts;
- three harvested counts;
- pending shipment total;
- contextual interaction hint.

Mutually exclusive panels:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Shop and Shipping each use three crop rows, one `SpinBox`, one `Max` button, and one explicit Buy/Deposit button. Quantity, selected row, focus, and panel state are UI-only.

Escape closes Shop/Shipping/Sleep Confirmation. Morning Summary can only close through successful Start Day acknowledgment.

Panels block movement **and** farming/interact key routing through the single `WorldShell` gate above.

## Testing

### Direct GUT

Create:

- `tests/unit/test_game_rules.gd`;
- `tests/unit/test_game_session.gd`.

Rules coverage:

- exact crop values/order;
- 3/5/7 maturity boundaries;
- visual-stage boundaries;
- exact action costs;
- 22:00 cutoff and time-before-stamina precedence;
- 25% weather mapping;
- stable itemized payout math.

Session coverage:

- exact starter state and nine farm cells;
- ordered farming guards and full-snapshot atomicity;
- sunny watering cost;
- rainy watering zero-mutation rejection plus rainy overnight growth;
- all three crop lifecycles;
- buying/deposit rollback;
- immediate carried-crop removal on deposit;
- one-time overnight payout and pending clear;
- blocking summary;
- duplicate sleep/ack cannot pay twice;
- Day 14 rejection preserves pending shipment and does not consume RNG;
- deep snapshot isolation;
- one public-command-only buy→farm→ship→payout→reinvest journey.

### Headless composition smoke

Add `tests/headless/gameplay_shell_smoke.gd` using the real `world.tscn`.

Prove:

- session/FarmView/HUD/shipping composition;
- nine projected farm anchors;
- shop/bed/shipping panel routing;
- any modal disables movement;
- the same modal state also blocks `WorldShell` farming/interact routing and leaves the session snapshot unchanged;
- morning summary remains blocking until acknowledgment;
- closing a non-summary panel restores input when no other blocker exists.

Do not synthesize OS keyboard events; exercise production coordinator routing/helpers directly.

Keep existing project/world-math/world-shell smokes intact.

### Clean verifier

Append GUT and gameplay composition smoke to the existing archive verifier:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Final verification also runs `git diff --check main...HEAD` and one normal-control playthrough.

## Alternatives considered

### A. One `GameSession` + pure `GameRules` + thin adapters — chosen

This is the smallest structure that preserves atomic overnight behavior, gives GUT a framework-free seam, and leaves HPA-598 one obvious mutable save boundary.

### B. Separate farming/day/economy managers — rejected

Planting, harvest inventory, rain growth, shipping settlement, and morning blocking cross those boundaries immediately. Separate managers create coordination before the MVP needs it.

### C. Mutable gameplay state on scene nodes — rejected

That scatters rules across world/UI nodes, weakens atomic tests, and makes persistence harder.

### D. Generic command/event/item framework — rejected

Four farming actions, three crops, and three interaction types do not justify it.

## Non-goals

No villagers, dialogue, gifting, relationships, persistence, save migration, tutorial prompts, Day-14 finale behavior, audio, broad polish, seasons, crop death, tool upgrades, inventory capacity, dynamic pricing, generic item database, event bus, registry, service locator, multiple maps, browser export, release packaging, or unrelated shell refactoring.

## Acceptance summary

HPA-589 is complete when one normal Godot play session can buy seeds, grow and harvest all three crops across repeatable days, ship crops, receive one exact overnight payout, acknowledge the blocking morning summary, and reinvest; sunny/rainy behavior and atomic failures are directly proven; modal UI blocks all world gameplay input rather than movement only; Day 14 remains playable without Day 15; and the existing clean Godot shell stays green.