# Phoenix Godot Gameplay Port Design (HPA-589)

**Status:** Ready for implementation on this same draft PR

**Date:** 2026-08-22

**Delivery:** HPA-589 is one PR. Planning and implementation stay on this branch/PR.

## Source of truth

This design implements HPA-589, `[Godot Gameplay Port] Restore farming, daily rhythm, and the three-crop economy`.

The Linear issue remains authoritative for product scope, delivery order, priority, and non-goals. This reviewed spec freezes the HPA-589 behavior values, command-code vocabulary, and repository contracts used by the implementation. An intentional behavior change updates both Linear and this spec rather than silently allowing them to drift.

HPA-590 is complete and `main` contains the Godot 4.7.1 isometric shell. The completed Phaser/Tauri farming, daily-rhythm, and economy slices are behavior references only; do not port their runtime architecture.

## Outcome

Restore one complete, repeatable Godot loop:

`buy seed → hoe → plant → water → sleep → grow → harvest → ship → receive income → buy more seeds`

The player can use the existing nine-cell farm, grow Turnip/Potato/Pumpkin, spend time and stamina, experience sunny/rainy days, buy seeds, deposit harvested crops, sleep, receive one overnight payout, dismiss a blocking morning summary, and repeat through playable Day 14.

## Chosen shape

Use the smallest Godot-native structure that preserves one gameplay authority and the HPA-590 scene contract:

- `GameRules`: closed enums/content plus pure formulas.
- `GameSession`: the only mutable gameplay-rules authority.
- `WorldContract`: fixed authored world coordinates and footprints.
- `WorldMath`: existing projection/target/footprint math; no gameplay state.
- `WorldShell`: thin runtime coordinator and the single production holder of `GameSession`.
- `PlayerController`: movement, facing, collision, camera, and target selection only.
- `FarmView`: the script on the existing `Entities` node; reconciles farm presentation only.
- `GameHud`: one consolidated `CanvasLayer` for HUD/panels and presentation-only state.

Do not add managers, services, event buses, registries, generic item systems, save abstractions, command middleware, test doubles, or compatibility layers.

## HPA-590 repository contracts inherited by this slice

HPA-589 extends the shell instead of weakening its contracts:

- `Entities` remains the **only** `CanvasItem` with Y-sort enabled.
- Player, tree, building, shipping bin, and every farm-plot root are direct children of `Entities` and share the same entity z-index. Do not add a nested Y-sorted farm container.
- Farm/scenery roots represent bottom-center ground contact. For an integer logical cell, the cell center is `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`; `grid_to_world(cell)` is a diamond vertex and is not a farm-entity anchor.
- `StaticCollision` remains the one static world-collision owner.
- `tests/headless/world_shell_smoke.gd` intentionally checks exact world/entity/collision child lists, the single Y-sort node, shared z-order, and InputMap bindings. Any intentional tree change updates that smoke in the same task.
- `tests/headless/world_math_smoke.gd` pins `WorldContract` constants. New HPA-589 interaction constants are added there in the same task.
- Player-facing keyboard controls use Godot `InputMap`; `WorldShell` does not compare raw keycodes.

## Fixed platform decisions

- Standard non-.NET Godot **4.7.1**.
- Statically typed GDScript.
- GUT **9.7.1**, vendored under `addons/gut/`, only for isolated rules/session tests.
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

All crops use four visual stages:

```text
min(3, floor(progress * 3 / growth_nights))
```

### New game and day constants

`GameRules` owns these closed values so session code/tests do not repeat literals:

- `DAY_START_MINUTES = 360` (`06:00`).
- `ACTION_CUTOFF_MINUTES = 1320` (`22:00`).
- `MAX_STAMINA = 20`.
- `MAX_DAY = 14`.
- `RAIN_CHANCE = 0.25`.
- `STARTING_MONEY = 150`.
- `STARTING_TURNIP_SEEDS = 3`; Potato/Pumpkin start at zero.
- Starting action: Hoe.
- Starting selected seed: Turnip.
- Day 1 weather: Sunny.
- All nine farm cells: untilled and empty.

### Action costs

| Action | Time | Stamina |
| --- | ---: | ---: |
| Hoe | 30 min | 3 |
| Seeds | 20 min | 1 |
| Watering Can | 20 min | 2 |
| Hands | 20 min | 1 |

An action ending exactly at `22:00` succeeds. Walking, selection, shop/shipping interaction, sleep confirmation, panel navigation, and summary acknowledgment are free.

### Weather and day boundary

- Day 1 is sunny.
- Later successful day transitions use a 25% rain chance.
- Rain makes planted non-mature crops eligible to advance overnight.
- Manual watering on a rainy day returns `rain-waters-crops` without changing time, stamina, or watering flags.
- Day 14 is playable.
- Sleeping on Day 14 returns `day-limit-reached`, does not consume the weather source, does not settle shipping, and does not advance to Day 15.

## `GameRules`

Create `scripts/game/game_rules.gd` as a statically typed `RefCounted` helper, following the existing `WorldMath` shape.

It owns only closed, immutable gameplay content/rules:

- `CropKind`: Turnip, Potato, Pumpkin.
- `FarmingAction`: Hoe, Seeds, Watering Can, Hands.
- `Weather`: Sunny, Rainy.
- `CommandCode`: the closed command/interaction result vocabulary below.
- crop display names, growth nights, seed prices, sale values.
- action costs and the fixed starter/day constants above.
- stable crop/action/weather keys.
- `starting_seed_counts()` returning a fresh `[3, 0, 0]` array.
- `command_code_key(code)` returning the historical stable `StringName` for diagnostics/copy tests.
- `visual_stage(kind, progress)`.
- `is_mature(kind, progress)`.
- `evaluate_action_budget(time_minutes, stamina, action)`.
- `shipment_payout(counts)`.
- `weather_from_roll(value)`.
- `format_time(minutes)`.

It owns no farm, inventory, money, day instance state, RNG state, node, signal, callback, or mutable stock.

### Closed command codes

`GameSession` command results contain a `GameRules.CommandCode` enum value, not an arbitrary `StringName`. `GameHud` uses an exhaustive `match` over the enum. `command_code_key` preserves the established spellings so tests can catch accidental renames.

Stable success keys:

- `action-selected`
- `seed-selected`
- `soil-tilled`
- `crop-planted`
- `crop-watered`
- `crop-harvested`
- `seeds-purchased`
- `crop-deposited`
- `day-advanced`
- `day-started`

Stable failure/feedback keys:

- `no-target`
- `not-farm-cell`
- `already-tilled`
- `soil-untilled`
- `crop-present`
- `no-selected-seeds`
- `no-crop`
- `already-watered`
- `crop-mature`
- `crop-immature`
- `not-at-bed`
- `not-at-shop`
- `not-at-shipping-bin`
- `invalid-quantity`
- `insufficient-funds`
- `insufficient-crops`
- `action-too-late`
- `insufficient-stamina`
- `rain-waters-crops`
- `day-summary-pending`
- `no-day-summary`
- `day-limit-reached`
- `nothing-to-interact`

`evaluate_action_budget` checks the 22:00 cutoff before stamina and returns `ACTION_TOO_LATE` / `INSUFFICIENT_STAMINA`, preserving the completed daily-rhythm contract.

## `GameSession`

Create `scripts/game/game_session.gd` as a statically typed `RefCounted`.

It owns all mutable gameplay state:

- day, time, stamina, weather;
- selected action and selected seed;
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

`target_cell` is `Variant` only because targeting may be `null` or `Vector2i`; each command validates it immediately.

Every command result is a fresh dictionary with exactly:

```gdscript
{"ok": bool, "code": GameRules.CommandCode}
```

Do not add generic dispatch or a result class hierarchy.

## Snapshot boundary

`GameSession.snapshot()` is the current read model consumed by `FarmView` and `GameHud`. It exists so presentation reads one authoritative value and cannot mutate session-owned collections.

The snapshot contains:

- day, time, stamina, max stamina, weather key;
- selected action and selected seed keys;
- money;
- seed, harvested-crop, and pending-shipment counts keyed by `turnip`, `potato`, `pumpkin`;
- nine farm entries containing authored cell position, soil state, and optional crop `{kind, growth, watered_today}`;
- optional pending morning summary.

Every nested array/dictionary is deep-copied. The snapshot excludes fixed shop/bed/shipping coordinates, player/facing/camera state, projected coordinates, sprite frames, Godot nodes/resources, panel/focus state, and the weather callable.

This ticket does not define a save schema, serialization format, restore path, or versioning contract.

## Command semantics

### Shared active-day gate

While a morning summary is pending, selection, farming, buying, depositing, and sleep return `DAY_SUMMARY_PENDING` without mutation. `acknowledge_morning_summary` is the only gameplay command allowed through that gate.

Farming validation order is:

`active-day → target → farm membership → command-specific state → time → stamina`

Failed commands preserve the complete snapshot.

### Hoe

Reject crop-bearing soil with `CROP_PRESENT`, then already-tilled soil with `ALREADY_TILLED`. Evaluate budget, then commit soil/time/stamina together and return `SOIL_TILLED`.

### Plant

Reject `SOIL_UNTILLED`, then `CROP_PRESENT`, then `NO_SELECTED_SEEDS`. Evaluate Seeds budget, then create the selected crop at growth 0, decrement one matching seed, commit budget, and return `CROP_PLANTED`.

### Water

Reject `NO_CROP`, then `CROP_MATURE`. On rain return `RAIN_WATERS_CROPS` before checking `ALREADY_WATERED` and without charging budget. Otherwise reject `ALREADY_WATERED`, evaluate Water budget, set `watered_today`, and return `CROP_WATERED`.

### Harvest

Reject `NO_CROP`, then `CROP_IMMATURE`. Evaluate Hands budget, then remove the crop, leave tilled soil, increment carried harvested inventory, commit budget, and return `CROP_HARVESTED`.

### Buying

`buy_seeds` validates:

`active-day → target == WorldContract.SHOP_CELL → quantity > 0 → sufficient funds`

Success deducts `seed_price × quantity`, adds seeds, and returns `SEEDS_PURCHASED`. Stock is unlimited.

### Shipping

`deposit_crop` validates:

`active-day → target == WorldContract.SHIPPING_CELL → quantity > 0 → sufficient carried crop`

Success removes carried crops immediately, increments pending shipment, and returns `CROP_DEPOSITED`. Deposits are final.

### Sleep and one-time settlement

`sleep` validates before mutation:

`active-day → target == WorldContract.BED_CELL → day < GameRules.MAX_DAY → next weather valid → payout valid`

Only after all validation succeeds:

1. advance each non-mature crop once when manually watered or when the completed day was rainy;
2. reset surviving `watered_today` flags;
3. credit shipping payout;
4. clear pending shipment;
5. increment day;
6. reset time/stamina to starter values;
7. store next weather;
8. create one authoritative morning summary;
9. return `DAY_ADVANCED`.

The summary contains completed/next day, crops advanced, next weather, restored stamina, itemized shipping lines, shipping income, and money after shipping.

Summary acknowledgment only clears the summary and returns `DAY_STARTED`. Calling it without a summary returns `NO_DAY_SUMMARY` without mutation.

## World adapters and scene ownership

### `WorldContract`

Extend `scripts/world/world_contract.gd` only with:

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Pin all four in `tests/headless/world_math_smoke.gd`. Keep all HPA-590 constants unchanged.

### `PlayerController`

Keep movement, facing, collision, camera, and target highlight ownership here. Add:

```gdscript
func set_input_enabled(enabled: bool) -> void
func current_target_cell() -> Variant
```

When disabled, velocity becomes zero immediately and movement sampling stops. `current_target_cell()` uses the existing `WorldMath.target_cell`; the highlight calls the same method rather than duplicating target math.

### `FarmView` / `Entities`

Attach `scripts/world/farm_view.gd` to the existing `Entities` node. `Entities` keeps its existing `y_sort_enabled = true`; `FarmView` must not create or enable another Y-sort container.

`FarmView._ready()` creates exactly nine deterministic farm-plot roots as direct `Entities` children in `WorldContract.farm_cells()` row-major order. Each root is positioned at:

```gdscript
WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

Each root owns presentation children only:

- `Soil`: 64×32 frame from `proof-soil.png`, centered on the logical cell;
- `Crop`: 32×48 frame from `proof-crops.png`, bottom-center contact with `offset = Vector2(0, -24)`.

`FarmView.refresh(snapshot)` updates only visibility/frames:

- untilled: hide soil/crop;
- tilled dry/sunny: dry soil frame;
- tilled watered or rainy: wet soil frame;
- crop frame: `int(kind) * 4 + GameRules.visual_stage(kind, growth)`.

Gameplay state never lives on plot nodes.

### Shipping entity

Add `Shipping` as a direct `Entities` child, after `Building`, at:

```gdscript
WorldMath.grid_to_world(Vector2(WorldContract.SHIPPING_CELL) + Vector2(0.5, 0.5))
```

Reuse frame 2 of `proof-scenery.png`, `hframes = 3`, `offset = Vector2(0, -48)`. Add `ShippingCollision` as a direct `StaticCollision` child and derive its polygon with `WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)`.

After this scene change, `world_shell_smoke.gd` is updated in the same commit to accept the shipping/farm children while preserving:

- exactly one Y-sort-enabled `CanvasItem` (`Entities`);
- direct entity membership;
- shared entity z-index;
- existing tree/building exact-Y checks;
- exact `StaticCollision` children; and
- deterministic farm-root order/center anchors.

### `WorldShell`

`WorldShell` remains the thin runtime coordinator and the only production holder of `GameSession`.

It constructs the session, connects HUD intentions, routes normal controls to direct session methods, refreshes one fresh snapshot into `FarmView`/`GameHud`, and derives one `world_input_enabled` value from modal/summary state.

The same boolean controls both:

1. `player.set_input_enabled(world_input_enabled)`; and
2. `WorldShell` action/interact routing.

Do not introduce independent movement/action/modal lock flags.

## InputMap and normal controls

Extend `project.godot` with named actions:

| Action | Physical key |
| --- | --- |
| `select_hoe` | `1` / 49 |
| `select_seeds` | `2` / 50 |
| `select_water` | `3` / 51 |
| `select_hands` | `4` / 52 |
| `use_action` | Space |
| `interact` | E |

Keep existing WASD actions unchanged. `WorldShell._unhandled_input` uses `event.is_action_pressed(...)` / InputMap action names rather than raw keycodes.

Normal behavior:

- `1/2/3/4`: select farming action.
- Space: apply selected action to `player.current_target_cell()`.
- E at shop: open Shop.
- E at shipping: open Shipping.
- E at bed: open Sleep Confirmation.
- E elsewhere: presentation-only `NOTHING_TO_INTERACT` feedback.

Buy/deposit/sleep handlers re-read the current target and pass it to `GameSession`; opening a panel is not authorization.

## HUD and panels

Create one `CanvasLayer` + `Control` scene at `scenes/ui/game_hud.tscn` with `scripts/ui/game_hud.gd`.

`GameHud` is a root child of `World`, never a child of `Entities`. Adding it intentionally changes the exact world-root list, so `world_shell_smoke.gd` is updated in Task 5 in the same commit.

Always-visible HUD:

- day/time/weather/stamina/money;
- four farming actions;
- selected seed and three seed counts;
- three harvested counts;
- pending shipment total;
- contextual interaction hint/feedback.

Mutually exclusive panels:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Shop/Shipping each use three crop rows, one `SpinBox`, one `Max` button, and one explicit Buy/Deposit button. Quantity, selected row, focus, and panel state are UI-only.

Escape closes Shop/Shipping/Sleep Confirmation. Morning Summary closes only through successful Start Day acknowledgment.

`GameHud` maps `GameRules.CommandCode` to player-facing copy through one exhaustive `match`; no stringly-typed fallback is accepted for a known command.

## Testing

### Direct GUT

Create:

- `tests/unit/test_game_rules.gd`;
- `tests/unit/test_game_session.gd`.

Use real `GameRules`/`GameSession`; do not add doubles/mocks.

Rules coverage:

- exact crop order/values;
- starter/day constants including `MAX_DAY = 14` and 150G/3 Turnip seeds;
- exact command-code enum-to-key mapping, including `action-too-late` and `insufficient-stamina`;
- 3/5/7 maturity and visual-stage boundaries;
- exact action costs;
- 22:00 cutoff and time-before-stamina precedence;
- 25% weather mapping;
- stable itemized payout math.

Session coverage:

- exact starter state and nine farm cells;
- ordered farming guards and full-snapshot atomicity;
- sunny/rainy watering behavior;
- all three crop lifecycles;
- buying/deposit rollback;
- immediate carried-crop removal on deposit;
- one-time overnight payout and pending clear;
- blocking summary for selection/farming/economy/sleep;
- duplicate sleep/ack cannot pay twice;
- Day 14 rejection preserves pending shipment and does not consume RNG;
- deep snapshot isolation;
- one public-command-only buy→farm→ship→payout→reinvest journey.

### Existing shell contract smokes

`tests/headless/world_math_smoke.gd` continues to own exact `WorldContract` constants and adds the four HPA-589 interaction values.

`tests/headless/world_shell_smoke.gd` changes when the authored tree changes:

- Task 4: shipping/farm entity children and `ShippingCollision`, while preserving one Y-sort node and center anchors.
- Task 5: root `GameHud` child and the six new InputMap actions/physical keys.

Do not postpone these updates to final cleanup.

### Gameplay composition smoke

Add `tests/headless/gameplay_shell_smoke.gd` using the real `world.tscn`.

Task 4 coverage:

- `FarmView`/nine plot composition and center anchors;
- player input disable/reenable behavior;
- current target helper matches the existing highlight logic.

Task 5 extends the same smoke with:

- real `GameSession`/HUD composition;
- shop/bed/shipping panel routing through production coordinator helpers;
- any modal blocks both movement and select/use/interact routing;
- blocked routing preserves the session snapshot;
- Morning Summary remains blocking until acknowledgment;
- closing a non-summary panel restores world input when no other blocker exists.

Do not synthesize OS keyboard events in the composition smoke; InputMap physical bindings are separately pinned by `world_shell_smoke.gd`.

### Clean verifier

Extend the existing archive verifier in place:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

The bounded manual proof is one normal-control economy loop plus one modal-input check. Day-14/RNG behavior is deterministic GUT coverage and is not replayed manually through fourteen sleeps.

## Risks kept explicit

1. **Y-sort/tree drift:** adding nested farm containers or forgetting exact-child smoke updates would break HPA-590 depth assumptions. Mitigation: farm/shipping roots are direct `Entities` children and `world_shell_smoke.gd` changes in the same task.
2. **Vendored GUT from a clean archive:** editor import/plugin assumptions could work locally but fail in `git archive`. Mitigation: run the GUT command immediately after vendoring and keep it inside the archive-first `verify-clean.sh`.
3. **Dictionary boundary typos:** snapshots remain dictionaries for lean UI rendering. Mitigation: closed enum command codes, stable key helpers, exact snapshot tests, and exhaustive HUD code mapping; do not add a typed DTO framework for this MVP.

`AGENTS.md` is the repository symlink to `CLAUDE.md`; handoff edits target `CLAUDE.md` only and final verification preserves that symlink.

## Alternatives considered

### A. One `GameSession` + pure `GameRules` + thin adapters — chosen

This is the smallest structure that keeps farming/day/economy transactions atomic and directly testable.

### B. Separate farming/day/economy managers — rejected

Planting, harvest inventory, rain growth, shipping settlement, and morning blocking cross those boundaries immediately. Separate managers add coordination without current product value.

### C. Mutable gameplay state on scene nodes — rejected

That scatters rules across world/UI nodes and weakens atomic tests.

### D. Generic command/event/item framework — rejected

Four farming actions, three crops, and three authored interaction cells do not justify it.

## Non-goals

No villagers, dialogue, gifting, relationships, persistence, save migration/schema, tutorial prompts, Day-14 finale behavior, audio, broad polish, seasons, crop death, tool upgrades, inventory capacity, dynamic pricing, generic item database, event bus, registry, service locator, multiple maps, browser export, release packaging, or unrelated shell refactoring.

## Acceptance summary

HPA-589 is complete when one normal Godot session can buy seeds, grow and harvest all three crops across repeatable days, ship crops, receive one exact overnight payout, acknowledge the blocking morning summary, and reinvest; sunny/rainy behavior and atomic failures are directly proven; modal UI blocks all world gameplay input; the HPA-590 one-Y-sort scene contract remains explicit; Day 14 remains playable without Day 15; and the single clean Godot verifier stays green.