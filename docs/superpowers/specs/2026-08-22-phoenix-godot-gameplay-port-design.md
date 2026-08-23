# Phoenix Godot Gameplay Port Design (HPA-589)

**Status:** Ready for implementation on this same draft PR

**Date:** 2026-08-22

**Delivery:** HPA-589 is one PR. Planning and implementation stay on this branch/PR.

## Source of truth

This design implements HPA-589, `[Godot Gameplay Port] Restore farming, daily rhythm, and the three-crop economy`.

The Linear issue remains authoritative for product scope, delivery order, priority, and non-goals. This reviewed spec freezes the HPA-589 behavior values and repository contracts used by the implementation. An intentional behavior change updates both Linear and this spec rather than silently allowing them to drift.

HPA-590 is complete and `main` contains the Godot 4.7.1 isometric shell. The completed Phaser/Tauri farming, daily-rhythm, and economy slices are behavioral references only; do not port their runtime architecture.

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
- `FarmView`: script on the existing `Entities` node; reconciles farm presentation only.
- `FarmSoil`: one non-Y-sorted world layer for soil decals below the target/player/crops.
- `GameHud`: one consolidated `CanvasLayer` for HUD/panels and presentation-only modal state.

Do not add managers, services, event buses, registries, generic item systems, save abstractions, command middleware, test doubles, or compatibility layers.

## HPA-590 repository contracts inherited by this slice

HPA-589 extends the shell instead of weakening its contracts:

- `Entities` remains the **only** `CanvasItem` with Y-sort enabled.
- Player, tree, building, shipping bin, and every crop root are direct children of `Entities` and share the same entity z-index.
- Soil is ground presentation, not an entity. Nine soil sprites live under one non-Y-sorted `FarmSoil` root with a z-index between Ground and TargetHighlight.
- Farm/scenery/crop roots use bottom-center ground contact. For an integer logical cell, the cell center is `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`; `grid_to_world(cell)` is a diamond vertex and is not an entity anchor.
- `StaticCollision` remains the one static world-collision owner.
- `tests/headless/world_shell_smoke.gd` intentionally checks exact root/entity/collision child lists, exact child order, the single Y-sort node, shared z-order, and InputMap bindings. Any intentional tree change updates that smoke in the same task.
- `tests/headless/world_math_smoke.gd` pins `WorldContract` constants. New HPA-589 interaction constants are added there in the same task.
- Player-facing keyboard controls use Godot `InputMap`; `WorldShell` does not compare raw keycodes.

## Fixed platform decisions

- Standard non-.NET Godot **4.7.1**.
- Statically typed GDScript.
- GUT **9.7.1**, not committed; `tools/verify-clean.sh` fetches the tagged upstream tarball into its temp archive (amended 2026-08-23: addons left the git tree by owner decision; clean runs need network).
- GUT owns all new rules/session/composition tests; the three existing SceneTree smokes stay as-is except for intentional contract extensions.
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
- Starter seeds: Turnip `3`, Potato `0`, Pumpkin `0`.
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

An action ending exactly at `22:00` succeeds. Walking, selection, shop/shipping interaction, sleep confirmation, panel navigation, and morning-summary acknowledgment are free. This free-action rule is intentional: the player must never be trapped by exhausted time/stamina away from bed or UI navigation.

### Weather and Day 14

- Day 1 is sunny.
- Later successful day transitions use a 25% rain chance.
- Rain makes planted non-mature crops eligible to advance overnight.
- Manual watering on a rainy day returns `RAIN_WATERS_CROPS` without changing time, stamina, or watering flags.
- Day 14 is playable.
- Sleeping on Day 14 returns `DAY_LIMIT_REACHED`, does not consume the weather callable, does not settle shipping, and does not advance to Day 15.
- Day-14 deposits remain pending under this temporary boundary. UI copy makes that limitation visible; HPA-597 owns replacement finale behavior.

## `GameRules`

Create `scripts/game/game_rules.gd` as a statically typed `RefCounted`, following the existing `WorldMath` shape.

It owns only closed, immutable gameplay content/rules:

- `CropKind`: Turnip, Potato, Pumpkin.
- `FarmingAction`: Hoe, Seeds, Watering Can, Hands.
- `Weather`: Sunny, Rainy.
- `CommandCode`: the closed command/interaction result vocabulary.
- crop display names, growth nights, seed prices, sale values.
- action costs and the fixed starter/day constants above.
- stable crop/action/weather keys used by the snapshot/UI.
- `starting_seed_counts()` returning a fresh `[3, 0, 0]` array.
- `visual_stage(kind, progress)`.
- `is_mature(kind, progress)`.
- `evaluate_action_budget(time_minutes, stamina, action)`.
- `shipment_payout(counts)`.
- `weather_from_roll(value)`.
- `format_time(minutes)`.

It owns no farm, inventory, money, day instance state, RNG state, node, signal, callback, or mutable stock.

Use one row per crop internally rather than four unrelated mutable structures if that keeps the implementation clearer. If parallel constant arrays are used, tests must assert every array size equals `CropKind.size()` and pin every per-crop value.

### Closed command codes

Commands return `GameRules.CommandCode` directly. Do not wrap the code in `{"ok": ..., "code": ...}`; `ok` would duplicate information in GDScript and can drift from the enum value.

Do not add `command_code_key()` or a stable string vocabulary: no current runtime, snapshot, log, or save format consumes command-code strings. `GameHud` maps enum values directly to player copy with one exhaustive `match`.

The enum contains exactly:

```text
ACTION_SELECTED
SEED_SELECTED
SOIL_TILLED
CROP_PLANTED
CROP_WATERED
CROP_HARVESTED
SEEDS_PURCHASED
CROP_DEPOSITED
DAY_ADVANCED
DAY_STARTED
NO_TARGET
NOT_FARM_CELL
ALREADY_TILLED
SOIL_UNTILLED
CROP_PRESENT
NO_SELECTED_SEEDS
NO_CROP
ALREADY_WATERED
CROP_MATURE
CROP_IMMATURE
NOT_AT_BED
NOT_AT_SHOP
NOT_AT_SHIPPING_BIN
INVALID_QUANTITY
INSUFFICIENT_FUNDS
INSUFFICIENT_CROPS
ACTION_TOO_LATE
INSUFFICIENT_STAMINA
RAIN_WATERS_CROPS
DAY_SUMMARY_PENDING
NO_DAY_SUMMARY
DAY_LIMIT_REACHED
NOTHING_TO_INTERACT
```

`evaluate_action_budget` checks the 22:00 cutoff before stamina and returns `ACTION_TOO_LATE` / `INSUFFICIENT_STAMINA` when blocked.

There is no generic `is_success()` helper in HPA-589. Current callers react to specific enum values or simply refresh presentation after a command; adding a classifier without a consumer would be YAGNI.

## `GameSession`

Create `scripts/game/game_session.gd` as a statically typed `RefCounted`.

`GameSession` owns all mutable gameplay state:

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
func select_action(action: GameRules.FarmingAction) -> GameRules.CommandCode
func select_seed(kind: GameRules.CropKind) -> GameRules.CommandCode
func apply_selected_action(target_cell: Variant) -> GameRules.CommandCode
func hoe(target_cell: Variant) -> GameRules.CommandCode
func plant(target_cell: Variant) -> GameRules.CommandCode
func water(target_cell: Variant) -> GameRules.CommandCode
func harvest(target_cell: Variant) -> GameRules.CommandCode
func buy_seeds(kind: GameRules.CropKind, quantity: int, target_cell: Variant) -> GameRules.CommandCode
func deposit_crop(kind: GameRules.CropKind, quantity: int, target_cell: Variant) -> GameRules.CommandCode
func sleep(target_cell: Variant) -> GameRules.CommandCode
func acknowledge_morning_summary() -> GameRules.CommandCode
```

`target_cell` is `Variant` only because targeting may be `null` or `Vector2i`; each command validates it immediately. Do not add generic dispatch or a result hierarchy.

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

`sleep` has exactly three expected validation gates:

`active-day → target == WorldContract.BED_CELL → day < GameRules.MAX_DAY`

Only after those pass does it compute the next weather and shipment payout. Invalid weather rolls or impossible payout inputs are programmer/invariant errors and assert; they are not command-result branches.

A successful transition then:

1. advances each non-mature crop once when manually watered or when the completed day was rainy;
2. resets surviving `watered_today` flags;
3. credits shipping payout;
4. clears pending shipment;
5. increments day;
6. resets time/stamina to starter values;
7. stores next weather;
8. creates one authoritative morning summary;
9. returns `DAY_ADVANCED`.

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

Keep movement, facing, collision, camera, and target-highlight ownership here. Add:

```gdscript
func set_input_enabled(enabled: bool) -> void
func current_target_cell() -> Variant
```

When disabled, velocity becomes zero immediately and movement sampling stops. `current_target_cell()` uses the existing `WorldMath.target_cell`; `_update_target()` calls the same method rather than duplicating target math.

### `FarmSoil`

Add one root `Node2D` sibling named `FarmSoil` under `World`.

- `y_sort_enabled = false`.
- `z_index` is greater than Ground and lower than TargetHighlight; use `5` with the current Ground `0`, TargetHighlight `10`, Entities `20` chain.
- It owns exactly nine soil sprites in row-major `WorldContract.farm_cells()` order.
- Each soil sprite is centered at `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`.
- Soil never participates in entity Y-sort, so it cannot paint over the player's feet.

### `FarmView` / crop roots

Attach `scripts/world/farm_view.gd` to the existing `Entities` node. `Entities` keeps `y_sort_enabled = true`; `FarmView` must not create another Y-sort container.

`FarmView._ready()` creates exactly nine crop roots as direct `Entities` children in row-major farm-cell order. Each root is positioned at:

```gdscript
WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

Each crop root owns one `Sprite2D` using `proof-crops.png`, `hframes = 4`, `vframes = 3`, bottom-center contact with `offset = Vector2(0, -24)`.

`FarmView` also holds a reference to sibling `../FarmSoil` and its nine soil sprites. `refresh(snapshot)` updates only presentation visibility/frames:

- untilled: hide soil and crop;
- tilled dry/sunny: show dry soil frame;
- tilled watered or rainy: show wet soil frame;
- crop frame: `int(kind) * 4 + GameRules.visual_stage(kind, growth)`.

Gameplay state never lives on scene nodes.

### Shipping entity

Add `Shipping` as a direct `Entities` child after Building, at the center of `SHIPPING_CELL`. Reuse frame 2 of `proof-scenery.png`, `hframes = 3`, `offset = Vector2(0, -48)`.

Add `ShippingCollision` as a direct `StaticCollision` child and derive its polygon through `WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)`.

## HUD, panels, and input ownership

Create one `CanvasLayer` + `Control` scene at `scenes/ui/game_hud.tscn` with `scripts/ui/game_hud.gd`. It is a `World` root sibling, never a child of `Entities`.

### Always-visible HUD

Show:

- day/time/weather/stamina/money;
- four farming actions;
- selected seed and three seed counts;
- three harvested counts;
- pending shipment total;
- contextual interaction hint;
- concise command feedback.

The contextual hint is driven from `player.current_target_cell()` by `WorldShell` and uses only three labels:

- `Shop — E`
- `Bed — E`
- `Shipping — E`

Blank it elsewhere. This makes the two invisible interaction cells discoverable without new art.

### Panels

Mutually exclusive modal panels:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Shop/Shipping each use three crop rows, one `SpinBox`, one `Max` button, and one explicit Buy/Deposit button. Quantity/row/focus/panel state is UI-only.

Escape closes Shop/Shipping/Sleep. Morning Summary closes only after successful acknowledgment.

`GameHud.render(snapshot)` owns the session-derived Morning Summary presentation: a non-null `pending_morning_summary` means that modal is open; null means it is closed. Do not maintain a second independent `morning_summary_open` flag.

On Day 14, Shipping and Sleep show a small content-boundary note that pending shipping will not settle and sleeping cannot advance. `DAY_LIMIT_REACHED` feedback is displayed inline in the Sleep panel instead of disappearing only as transient global copy. This is presentation only; command semantics remain unchanged.

### One modal gate

`WorldShell` owns one `_world_input_enabled` boolean. Its source of truth is only:

```gdscript
not hud.has_blocking_modal()
```

`GameHud.modal_state_changed` is connected directly to `WorldShell._refresh_world_input_gate()`. Opening or closing Shop/Shipping/Sleep therefore changes movement/action gating immediately, even though no session command occurred.

`_refresh_from_session()` performs:

1. one fresh `snapshot := _session.snapshot()`;
2. `farm_view.refresh(snapshot)`;
3. `hud.render(snapshot)` (which derives Morning Summary modal state);
4. `_refresh_world_input_gate()`.

Do not deep-copy a snapshot merely to recalculate the input gate.

The same `_world_input_enabled` value controls:

- `player.set_input_enabled(...)`; and
- `WorldShell` routing for action selection, use-action, and interact.

HUD command signals for buy/deposit/sleep/summary acknowledgment remain usable while their intentional modal is open; `GameSession` revalidates target/domain state.

### Normal controls

Add named `InputMap` actions in `project.godot`:

- `select_hoe` → physical `1`;
- `select_seeds` → physical `2`;
- `select_water` → physical `3`;
- `select_hands` → physical `4`;
- `use_action` → Space;
- `interact` → E.

Keep WASD unchanged. `WorldShell._unhandled_input` samples action names only.

`interact()` reads the target every time:

- shop cell: open Shop;
- shipping cell: open Shipping;
- bed cell: open Sleep Confirmation;
- elsewhere: show `NOTHING_TO_INTERACT`.

Buy/deposit/sleep-confirm handlers re-read the current target and pass it into `GameSession`; an open panel is never authorization.

## Testing

### GUT rules/session tests

Create:

- `tests/unit/test_game_rules.gd`;
- `tests/unit/test_game_session.gd`.

Rules coverage:

- exact crop order/values and constant-array size parity with `CropKind.size()`;
- starter/day constants including max day and starter money/seeds;
- exact action costs;
- 3/5/7 maturity and visual-stage boundaries;
- 22:00 cutoff and time-before-stamina precedence;
- 25% weather mapping;
- stable itemized payout math.

Session coverage:

- exact starter state and nine farm cells;
- ordered farming guards and full-snapshot atomicity;
- sunny watering cost;
- rainy watering zero-mutation rejection plus rainy overnight growth;
- all three crop lifecycles;
- buying/deposit rollback and immediate carried-crop removal;
- one-time overnight payout and pending clear;
- blocking summary and duplicate acknowledgment safety;
- Day-14 rejection preserving pending shipping and weather-call count;
- deep snapshot isolation;
- one public-command-only buy→farm→ship→payout→reinvest journey.

Do not use GUT doubles/mocks.

### GUT composition test

Create `tests/integration/test_gameplay_shell.gd` extending `GutTest` and instantiate the real `world.tscn` with `add_child_autofree`/`add_child_autoqfree`.

Prove:

- `FarmSoil` is non-Y-sorted and has nine correctly centered soil sprites below TargetHighlight;
- exactly nine crop roots are direct `Entities` children at cell centers;
- `Entities` remains the only Y-sort-enabled CanvasItem;
- shipping sprite/collision composition;
- player input enable/disable and target-cell accessor;
- Shop/Bed/Shipping panel routing;
- opening any modal immediately disables movement plus world command routing;
- closing a non-summary modal restores input;
- sleeping derives Morning Summary modal from the snapshot and acknowledgment restores input;
- blocked routing leaves the session snapshot unchanged;
- Day-14 warning copy is shown in Shipping/Sleep presentation.

Keep the existing `project_smoke.gd`, `world_math_smoke.gd`, and `world_shell_smoke.gd` as SceneTree contracts rather than rewriting them into GUT.

### Clean verifier sequencing

CI runs only `./tools/verify-clean.sh`, so new tests enter that script in the same task they are introduced:

- Task 1: after rules/unit tests exist, add GUT unit execution to `verify-clean.sh`.
- Task 4: when the integration test exists, expand the GUT command to include `tests/integration`.
- Task 6: documentation only; no delayed test-runner wiring.

Final archive-first verifier order:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

## Manual acceptance

Run one bounded normal-control journey only:

`buy → hoe → plant → water → sleep/grow → harvest → ship → payout → buy again`

Also open/close one modal and verify movement plus 1–4/Space/E are blocked/restored. Do not manually play fourteen days; the deterministic GUT test owns Day-14 behavior.

## Risks and mitigations

1. **Depth regression at farm cells.** Soil under Y-sort would cover the player; keep soil in `FarmSoil` below TargetHighlight and only crop roots in `Entities`. Composition + shell tests pin this.
2. **Vendored GUT clean-archive failure.** The existing archive-first verifier already runs editor import; vendor GUT in its own commit, then add the GUT command to `verify-clean.sh` in the same commit that introduces authored unit tests. CI then exercises it from the archive immediately.
3. **Modal/input drift.** Make HUD modal state the only gate source, derive Morning Summary from snapshot, and connect `modal_state_changed` directly to the no-argument gate refresh.

## Alternatives rejected

### Separate farming/day/economy managers

Planting, rain growth, shipping settlement, and morning blocking cross those boundaries immediately. Separate managers add coordination before the MVP needs it.

### Nested Farm container

A nested Node2D would sort the farm as one unit under the single Y-sort parent. Crop roots must remain direct `Entities` children.

### Soil inside crop Y-sort roots

Ground decals would sort in front of a player standing slightly north of the cell center and cover the player's feet. Soil belongs below entity/target rendering.

### Mutable gameplay state on scene nodes

That scatters authority, weakens transaction tests, and complicates later work.

### Generic command/result framework

The command set is closed and small. Direct methods returning `CommandCode` are simpler and more strongly typed than Dictionary result wrappers or middleware.

## Non-goals

No villagers, dialogue, gifting, relationships, persistence, save migration, tutorial prompts, Day-14 finale behavior, audio, broad polish, seasons, crop death, tool upgrades, inventory capacity, dynamic pricing, generic item database, event bus, registry, service locator, multiple maps, browser export, release packaging, or unrelated shell refactoring.

## Acceptance summary

HPA-589 is complete when one normal Godot session can buy seeds, grow/harvest all three crops, ship crops, receive one exact overnight payout, acknowledge the blocking morning summary, and reinvest; rules failures are atomic; modal UI blocks all world gameplay input immediately; soil cannot cover the player; Day 14 remains playable without Day 15 or payout; contextual hints make shop/bed/shipping discoverable; and the single clean verifier proves the existing shell plus all new tests.