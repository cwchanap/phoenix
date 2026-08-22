# Phoenix Godot Gameplay Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's complete farming, daily-rhythm, and three-crop economy loop in Godot while keeping one authoritative gameplay state and the existing HPA-590 world shell intact.

**Architecture:** Add one pure `GameRules` helper and one mutable `GameSession` authority. Keep `WorldShell` as a thin coordinator, `PlayerController` as movement/targeting only, `FarmView` as snapshot rendering only, and one consolidated `GameHud` for presentation/input intentions. Extend the existing world scene and clean verifier rather than introducing managers, services, a second runtime, or another CI path.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing headless smoke scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-22-phoenix-godot-gameplay-port-design.md`

## Global Constraints

- Deliver HPA-589 in this same PR; do not open a second implementation PR.
- Standard non-.NET Godot 4.7.1 and statically typed GDScript only.
- Preserve HPA-590 map/projection/spawn/movement/camera/tree/building contracts unchanged.
- Farm cells stay `x=2..4,y=7..9`; shop `(6,7)`; bed `(6,8)`; shipping `(6,10)` with footprint `Rect2(6.2,10.2,0.6,0.6)`.
- Crops remain Turnip `3 / 20G / 35G`, Potato `5 / 40G / 75G`, Pumpkin `7 / 70G / 140G` for watered nights / seed price / sale value.
- Day starts at `06:00` (`360`), stamina is `20`, activity cutoff is `22:00` (`1320`), and actions ending exactly at 22:00 succeed.
- Costs remain Hoe `30m/3`, Seeds `20m/1`, Water `20m/2`, Hands `20m/1`.
- Day 1 is sunny; later successful day transitions use a 25% rain chance.
- Rain grows planted crops overnight; manual rainy-day watering is rejected without mutation.
- Shipping removes carried crops immediately; one successful sleep settles the pending shipment exactly once before creating the blocking morning summary.
- Day 14 stays playable and cannot advance, consume the weather source, or settle shipping into Day 15.
- Gameplay snapshots exclude player/world position, camera/rendering nodes, fixed interaction coordinates, panel/focus state, and the weather callable.
- Keep one `./tools/verify-clean.sh` entry point and one existing GitHub Actions verification job.
- No C#, GDExtension, JavaScript/Tauri runtime, compatibility layer, persistence, villagers/social behavior, finale behavior, generic manager/service/event-bus/item-registry/command framework, or unrelated shell refactor.

---

### Task 1: Pin GUT and freeze the closed gameplay rules

**Files:**
- Vendor: `addons/gut/**` from GUT `v9.7.1`
- Create: `scripts/game/game_rules.gd`
- Create: `tests/unit/test_game_rules.gd`

**Interfaces:**
- Produces: `GameRules.CropKind`, `GameRules.FarmingAction`, `GameRules.Weather`
- Produces: stable keys `turnip`, `potato`, `pumpkin`, action/weather keys, exact crop/action constants
- Produces: `crop_key`, `crop_display_name`, `growth_nights`, `seed_price`, `sale_value`, `action_cost`, `visual_stage`, `is_mature`, `evaluate_action_budget`, `shipment_payout`, `weather_from_roll`, `format_time`
- Consumes: no mutable game/world state

- [ ] **Step 1: Vendor exactly GUT 9.7.1 under `addons/gut/`**

Keep the upstream addon layout intact so the committed repository can run GUT from a clean archive without downloading dependencies at test time. Do not enable another test plugin or add a second test runner.

Verify the command surface immediately after vendoring:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected before adding tests: GUT starts successfully and reports no test scripts rather than a missing-script/plugin error.

- [ ] **Step 2: Write RED rules tests with exact tables and boundaries**

Create `tests/unit/test_game_rules.gd` extending `GutTest`. Pin exact values rather than broad invariants:

```gdscript
extends GutTest

func test_crop_table_is_closed_and_exact() -> void:
    assert_eq(GameRules.crop_key(GameRules.CropKind.TURNIP), &"turnip")
    assert_eq(GameRules.growth_nights(GameRules.CropKind.TURNIP), 3)
    assert_eq(GameRules.seed_price(GameRules.CropKind.TURNIP), 20)
    assert_eq(GameRules.sale_value(GameRules.CropKind.TURNIP), 35)
    assert_eq(GameRules.growth_nights(GameRules.CropKind.POTATO), 5)
    assert_eq(GameRules.seed_price(GameRules.CropKind.POTATO), 40)
    assert_eq(GameRules.sale_value(GameRules.CropKind.POTATO), 75)
    assert_eq(GameRules.growth_nights(GameRules.CropKind.PUMPKIN), 7)
    assert_eq(GameRules.seed_price(GameRules.CropKind.PUMPKIN), 70)
    assert_eq(GameRules.sale_value(GameRules.CropKind.PUMPKIN), 140)

func test_action_budget_accepts_exact_2200_boundary() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1290, 3, GameRules.FarmingAction.HOE),
        {"ok": true, "time_minutes": 1320, "stamina": 0},
    )

func test_action_budget_checks_time_before_stamina() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1310, 0, GameRules.FarmingAction.HOE),
        {"ok": false, "code": &"too-late"},
    )

func test_weather_threshold_is_exact() -> void:
    assert_eq(GameRules.weather_from_roll(0.0), GameRules.Weather.RAINY)
    assert_eq(GameRules.weather_from_roll(0.249999), GameRules.Weather.RAINY)
    assert_eq(GameRules.weather_from_roll(0.25), GameRules.Weather.SUNNY)

func test_shipment_payout_is_itemized_and_stable() -> void:
    assert_eq(
        GameRules.shipment_payout({&"turnip": 2, &"potato": 1, &"pumpkin": 1}),
        {
            "lines": [
                {"crop": &"turnip", "quantity": 2, "amount": 70},
                {"crop": &"potato", "quantity": 1, "amount": 75},
                {"crop": &"pumpkin", "quantity": 1, "amount": 140},
            ],
            "total": 285,
        },
    )
```

Also table-drive maturity and visual-stage boundaries for all three crops, exact action costs, `format_time(360) == "06:00"`, and invalid weather rolls outside `[0.0,1.0)`.

- [ ] **Step 3: Run the focused tests and confirm RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

Expected: failures because `GameRules` does not exist yet.

- [ ] **Step 4: Implement the minimal pure `GameRules` helper**

Use a `RefCounted` class with closed enums and constant arrays; do not create Resource objects or registries:

```gdscript
class_name GameRules
extends RefCounted

enum CropKind { TURNIP, POTATO, PUMPKIN }
enum FarmingAction { HOE, SEEDS, WATERING_CAN, HANDS }
enum Weather { SUNNY, RAINY }

const DAY_START_MINUTES := 360
const ACTION_CUTOFF_MINUTES := 1320
const MAX_STAMINA := 20
const RAIN_CHANCE := 0.25
const CROP_KEYS: Array[StringName] = [&"turnip", &"potato", &"pumpkin"]
const GROWTH_NIGHTS: Array[int] = [3, 5, 7]
const SEED_PRICES: Array[int] = [20, 40, 70]
const SALE_VALUES: Array[int] = [35, 75, 140]
const ACTION_MINUTES: Array[int] = [30, 20, 20, 20]
const ACTION_STAMINA: Array[int] = [3, 1, 2, 1]

static func visual_stage(kind: CropKind, progress: int) -> int:
    return mini(3, int(floor(float(progress * 3) / float(growth_nights(kind)))))

static func is_mature(kind: CropKind, progress: int) -> bool:
    return progress >= growth_nights(kind)
```

`evaluate_action_budget` returns either `{"ok": false, "code": &"too-late"}` / `{"ok": false, "code": &"too-tired"}` or the committed next time/stamina values. `shipment_payout` iterates crop kinds in enum order so summary lines are deterministic. Use `assert` for invalid enum indices or weather rolls because those are programmer/configuration errors.

- [ ] **Step 5: Run the rules tests and confirm GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

Expected: all `test_game_rules.gd` tests pass.

- [ ] **Step 6: Commit the closed rules seam**

```bash
git add addons/gut scripts/game/game_rules.gd tests/unit/test_game_rules.gd
git commit -m "test: freeze HPA-589 gameplay rules"
```

---

### Task 2: Add authoritative farm state and atomic farming commands

**Files:**
- Create: `scripts/game/game_session.gd`
- Create/extend: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `GameRules`, `WorldContract.farm_cells()`
- Produces: `GameSession.snapshot() -> Dictionary`
- Produces: `select_action`, `select_seed`, `apply_selected_action`, `hoe`, `plant`, `water`, `harvest`
- Produces command results with exactly `{"ok": bool, "code": StringName}`

- [ ] **Step 1: Write RED starter-state and snapshot-isolation tests**

Create `tests/unit/test_game_session.gd` and pin the complete mutable starter state:

```gdscript
extends GutTest

func test_new_session_has_exact_starter_state() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var snapshot := session.snapshot()
    assert_eq(snapshot["day"], 1)
    assert_eq(snapshot["time_minutes"], 360)
    assert_eq(snapshot["stamina"], 20)
    assert_eq(snapshot["weather"], &"sunny")
    assert_eq(snapshot["money"], 150)
    assert_eq(snapshot["seeds"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["harvested"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["farm"].size(), 9)
    assert_null(snapshot["pending_morning_summary"])

func test_snapshot_is_deeply_isolated() -> void:
    var session := GameSession.new()
    var snapshot := session.snapshot()
    snapshot["farm"][0]["tilled"] = true
    snapshot["seeds"][&"turnip"] = 99
    var fresh := session.snapshot()
    assert_false(fresh["farm"][0]["tilled"])
    assert_eq(fresh["seeds"][&"turnip"], 3)
```

- [ ] **Step 2: Write RED ordered-guard and atomicity tests for all four farming actions**

For each failed command, capture `before := session.snapshot()` and assert `session.snapshot() == before` after failure. Pin validation order:

- target null/out of map before farm membership;
- farm membership before soil/crop state;
- command-specific state before budget;
- time before stamina inside the budget check;
- rainy watering returns `rain-waters-crops` before `already-watered` and charges neither time nor stamina.

Include exact success transitions for one farm cell:

```gdscript
func test_turnip_farming_commands_commit_atomically() -> void:
    var session := GameSession.new()
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), {"ok": true, "code": &"soil-tilled"})
    assert_eq(session.plant(cell), {"ok": true, "code": &"crop-planted"})
    assert_eq(session.water(cell), {"ok": true, "code": &"crop-watered"})
    var snapshot := session.snapshot()
    assert_eq(snapshot["time_minutes"], 430)
    assert_eq(snapshot["stamina"], 14)
    assert_eq(snapshot["seeds"][&"turnip"], 2)
```

Add separate tests for `apply_selected_action`, selected action/seed changes, no-seed rollback, crop-present/already-tilled/no-crop/crop-immature/crop-mature/already-watered guards, and harvest leaving tilled soil while incrementing carried inventory.

- [ ] **Step 3: Run the session tests and confirm RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

Expected: failures because `GameSession` is absent.

- [ ] **Step 4: Implement the minimal mutable `GameSession` state**

Keep one `RefCounted` authority. Closed three-crop counts may be internal arrays; the public snapshot converts them to stable-key dictionaries. Represent the nine farm plots as row-major dictionaries keyed by authored `Vector2i` cells; do not create a generic entity/component model.

```gdscript
class_name GameSession
extends RefCounted

var _day: int = 1
var _time_minutes: int = GameRules.DAY_START_MINUTES
var _stamina: int = GameRules.MAX_STAMINA
var _weather: GameRules.Weather = GameRules.Weather.SUNNY
var _selected_action: GameRules.FarmingAction = GameRules.FarmingAction.HOE
var _selected_seed: GameRules.CropKind = GameRules.CropKind.TURNIP
var _money: int = 150
var _seed_counts: Array[int] = [3, 0, 0]
var _harvested_counts: Array[int] = [0, 0, 0]
var _pending_shipment_counts: Array[int] = [0, 0, 0]
var _farm: Array[Dictionary] = []
var _pending_morning_summary: Variant = null
var _weather_roll: Callable

func _init(weather_roll: Callable = Callable()) -> void:
    _weather_roll = weather_roll if weather_roll.is_valid() else func() -> float: return randf()
    for cell in WorldContract.farm_cells():
        _farm.append({
            "cell": cell,
            "tilled": false,
            "crop": null,
        })
```

Each mutating command validates completely before touching state. Apply time/stamina only after command-specific validation passes. `snapshot()` creates stable-key count dictionaries and returns `duplicate(true)` data so callers cannot mutate authority state.

- [ ] **Step 5: Run all unit tests and confirm GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: rules and current session tests pass.

- [ ] **Step 6: Commit the farming authority**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add authoritative Godot farming session"
```

---

### Task 3: Add weather, sleep, shipping settlement, and reinvestment

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `buy_seeds(kind, quantity, target_cell)`
- Produces: `deposit_crop(kind, quantity, target_cell)`
- Produces: `sleep(target_cell)`
- Produces: `acknowledge_morning_summary()`
- Snapshot adds/uses authoritative pending morning summary data; no persistence schema is introduced

- [ ] **Step 1: Write RED economy rollback tests**

Pin target-first behavior and full rollback:

```gdscript
func test_buy_requires_shop_target_before_funds_check() -> void:
    var session := GameSession.new()
    var before := session.snapshot()
    assert_eq(
        session.buy_seeds(GameRules.CropKind.PUMPKIN, 999, Vector2i(0, 0)),
        {"ok": false, "code": &"not-at-shop"},
    )
    assert_eq(session.snapshot(), before)

func test_deposit_removes_carried_crop_immediately() -> void:
    var session := _session_with_one_harvested_turnip()
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        {"ok": true, "code": &"crop-deposited"},
    )
    var snapshot := session.snapshot()
    assert_eq(snapshot["harvested"][&"turnip"], 0)
    assert_eq(snapshot["pending_shipment"][&"turnip"], 1)
```

Cover quantity `<= 0`, insufficient funds/crop, exact-cost purchases, and reinvestment after payout.

- [ ] **Step 2: Write RED overnight transaction tests**

Use injected weather callables so tests are deterministic. Pin these cases:

- watered sunny crop advances once;
- unwatered sunny crop does not advance;
- any planted crop advances on a rainy completed day;
- surviving `watered_today` resets after sleep;
- next-day weather is rainy for roll `<0.25` and sunny for `>=0.25`;
- pending shipping credits exact itemized payout once and clears before summary;
- morning summary blocks farming/selection/buy/deposit/sleep;
- duplicate sleep while summary is pending cannot pay twice;
- duplicate acknowledgment fails without mutation;
- Day 14 sleep returns `day-limit-reached`, preserves pending shipment, and does not invoke the weather callable.

Use a counting callable for the last assertion:

```gdscript
var roll_count := 0
var session := GameSession.new(func() -> float:
    roll_count += 1
    return 0.0
)
# Drive to Day 14 using public sleep/ack commands.
var before := session.snapshot()
assert_eq(session.sleep(WorldContract.BED_CELL), {"ok": false, "code": &"day-limit-reached"})
assert_eq(roll_count, 13)
assert_eq(session.snapshot(), before)
```

- [ ] **Step 3: Add one public-command-only complete economy journey test**

The test must use only public session commands to prove the ticket's core loop. It should buy at least one non-starter seed, hoe/plant/water/sleep until mature, harvest, deposit, sleep for payout, acknowledge, then buy again from the increased balance. Do not add test-only state mutation methods.

- [ ] **Step 4: Run the focused tests and confirm RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

Expected: new economy/day-transition assertions fail.

- [ ] **Step 5: Implement buying, shipping, and one atomic sleep transaction**

`buy_seeds` validates `summary gate -> shop target -> positive quantity -> funds`; `deposit_crop` validates `summary gate -> shipping target -> positive quantity -> carried count`.

`sleep` validates every precondition before mutation, including Day 14 before reading the weather source. Build the payout and next weather first, then commit in this order:

```text
advance eligible crops
reset watered flags
credit payout
clear pending shipment
increment day
reset time/stamina
store next weather
store morning summary
```

The summary must carry completed/next day, crops advanced, next weather key, restored stamina, itemized shipping lines, shipping income, and money after shipping. `acknowledge_morning_summary` only clears the summary.

- [ ] **Step 6: Run all GUT tests and confirm GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: all direct rules/session tests pass, including the complete buy→farm→ship→payout→reinvest journey.

- [ ] **Step 7: Commit the complete gameplay authority**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore Godot day and crop economy rules"
```

---

### Task 4: Add authored interaction cells, movement gating, farm rendering, and the shipping bin

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/player/player_controller.gd`
- Create: `scripts/world/farm_view.gd`
- Modify: `scenes/world/world.tscn`
- Create: `tests/headless/gameplay_shell_smoke.gd` (initial world-adapter assertions)

**Interfaces:**
- Produces: `WorldContract.SHOP_CELL`, `BED_CELL`, `SHIPPING_CELL`, `SHIPPING_FOOTPRINT`
- Produces: `PlayerController.set_input_enabled(enabled: bool)` and `current_target_cell() -> Variant`
- Produces: `FarmView.refresh(snapshot: Dictionary)`
- Consumes: `GameRules.visual_stage`, `WorldContract.farm_cells`, `WorldMath.grid_to_world`

- [ ] **Step 1: Write RED composition assertions for fixed interaction geometry**

Start `tests/headless/gameplay_shell_smoke.gd` from the real `res://scenes/world/world.tscn`. Assert exact shop/bed/shipping cells, projected farm positions, the new shipping collision polygon, and a shipping sprite under the existing Y-sorted entity composition.

Do not duplicate projection math in expectations; compare scene positions to `WorldMath.grid_to_world(...)` and footprint polygons to `WorldMath.footprint_to_polygon(...)`.

- [ ] **Step 2: Write RED player input-gate assertions**

Instantiate the real world, obtain `Entities/Player`, call `set_input_enabled(false)`, and prove velocity is zeroed immediately and physics input does not move the player until re-enabled. Assert `current_target_cell()` matches the cell already used by target highlighting, including `null` at map edges.

- [ ] **Step 3: Add interaction constants without touching HPA-590 values**

Append only:

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Leave all existing map, projection, spawn, tree/building, camera, farm, and path values byte-for-byte equivalent in behavior.

- [ ] **Step 4: Add one player input-enabled flag and reuse the existing target calculation**

`set_input_enabled(false)` sets the flag and `velocity = Vector2.ZERO`. `_physics_process` skips `Input.get_vector`/movement when disabled but still keeps visuals/target state coherent. `current_target_cell()` computes from the current logical position and facing with the same `WorldMath.target_cell` call used by `_update_target`; do not store a second target state.

- [ ] **Step 5: Create `FarmView` as a snapshot-to-sprite adapter**

`FarmView` owns exactly the nine authored farm presentation roots. `refresh(snapshot)` reconciles soil/crop visuals from snapshot data:

```text
untilled -> no soil/crop sprite
tilled + sunny dry -> dry soil frame
tilled + watered or rainy -> wet soil frame
crop frame -> int(kind) * 4 + GameRules.visual_stage(kind, growth)
```

Use `WorldMath.grid_to_world` for placement. Use committed soil/crop sprite sheets already in `assets/sprites/`; do not store frame indices in `GameSession`.

Keep the farm view under the existing world/entity presentation hierarchy so crop roots use bottom-center logical contact for stable ordering with the player. Do not introduce another renderer or gameplay state on nodes.

- [ ] **Step 6: Author the shipping bin and collision in `world.tscn`**

Reuse frame 2 of `assets/sprites/proof-scenery.png`, anchor it at logical center `(6.5,10.5)`, add `ShippingCollision` under the existing `StaticCollision`, and derive its polygon in `WorldShell` from `WorldContract.SHIPPING_FOOTPRINT`. Do not move the existing tree/building/player nodes.

- [ ] **Step 7: Run the world/composition smokes**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Expected: all existing HPA-590 assertions remain green and the new world-adapter assertions pass.

- [ ] **Step 8: Commit the world adapters**

```bash
git add scripts/world/world_contract.gd scripts/player/player_controller.gd scripts/world/farm_view.gd scenes/world/world.tscn tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: add Godot farm and economy world adapters"
```

---

### Task 5: Add the consolidated HUD and wire `WorldShell` as the single runtime coordinator

**Files:**
- Create: `scripts/ui/game_hud.gd`
- Create: `scenes/ui/game_hud.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- `GameHud.render(snapshot: Dictionary) -> void`
- `GameHud.has_blocking_modal() -> bool`
- `GameHud.show_feedback(code: StringName) -> void`
- `GameHud.open_shop()`, `open_shipping()`, `open_sleep_confirmation()`, `open_morning_summary(summary)`
- HUD intention signals: action selection, seed selection, shop purchase, shipping deposit, sleep confirmation, summary acknowledgment, panel close
- `WorldShell` owns one `GameSession`, reads `PlayerController.current_target_cell()`, and refreshes `FarmView`/`GameHud` from fresh snapshots

- [ ] **Step 1: Extend the headless smoke with RED input-routing assertions**

Use real `world.tscn` and call production coordinator helpers directly rather than synthesizing OS key events. Pin:

- shop/bed/shipping target opens exactly the matching panel;
- a modal makes `GameHud.has_blocking_modal()` true;
- the same modal disables `PlayerController` movement;
- the same modal also prevents farming/action/interact routing and preserves the session snapshot;
- closing Shop/Shipping/Sleep restores world input when no summary exists;
- Morning Summary stays blocking until successful acknowledgment.

- [ ] **Step 2: Build one `GameHud` scene, not one scene/controller per panel**

Use one `CanvasLayer` root with one `Control` tree. Keep always-visible labels/buttons for day/time/weather/stamina/money, four action buttons, selected seed/seed counts, harvested counts, pending shipment total, and interaction hint.

Keep four mutually exclusive panel containers inside the same scene:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Shop and Shipping each use three crop rows, one `SpinBox`, one `Max` button, and one explicit Buy/Deposit button. Quantity, selected row, focus, panel enum, and feedback text stay local UI state. Escape closes only Shop/Shipping/Sleep; Morning Summary only closes after the session accepts acknowledgment.

- [ ] **Step 3: Make `WorldShell` the only production holder of `GameSession`**

On `_ready`, construct one session, connect HUD intentions, initialize collisions (including shipping), then call one refresh helper:

```gdscript
func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate(snapshot)
```

After every session command, show feedback from the returned `code` and refresh from a new snapshot. Do not keep mutable gameplay copies in `WorldShell`.

- [ ] **Step 4: Add direct production routing helpers used by input and smoke tests**

Keep the input surface explicit rather than generic dispatch:

```gdscript
func select_action_slot(slot: int) -> void
func use_selected_action() -> void
func interact() -> void
```

`_unhandled_input` maps `1/2/3/4` to the four action slots, Space to `use_selected_action`, and E to `interact`. UI action/seed buttons call the same direct session-selection methods through connected intentions.

`interact()` reads the player's current target each time: shop opens Shop, shipping opens Shipping, bed opens Sleep Confirmation, and every other cell shows `nothing-to-interact`. Buy/deposit/sleep confirmation handlers re-read the current target and pass it to `GameSession`, so UI opening is never treated as authorization.

- [ ] **Step 5: Implement one derived world-input gate**

Compute exactly:

```gdscript
var world_input_enabled := (
    not hud.has_blocking_modal()
    and snapshot["pending_morning_summary"] == null
)
```

Apply the same boolean to both input paths:

1. `player.set_input_enabled(world_input_enabled)`;
2. `WorldShell` ignores `1/2/3/4`, Space, and E when false.

Do not add independent movement/action/modal lock flags. Morning summary UI remains operable because its button signal bypasses world gameplay routing and calls `acknowledge_morning_summary()` directly.

- [ ] **Step 6: Wire snapshot presentation and morning-summary behavior**

`GameHud.render` derives all labels/counts from the snapshot and opens the summary when `pending_morning_summary` is non-null. `FarmView.refresh` is called from the same snapshot. UI maps stable session result codes to concise player-facing feedback; rules/session code never owns presentation strings.

- [ ] **Step 7: Run direct tests plus real-scene composition smoke**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Expected: direct rules/session suites and all modal/input/composition assertions pass.

- [ ] **Step 8: Perform one normal-control manual journey before final verification**

Run:

```bash
godot --path .
```

Using only normal controls and UI, complete `buy seed → hoe → plant → water → sleep → grow → harvest → ship → receive income → buy more seeds`. Confirm modal panels block both movement and world actions, morning summary blocks until Start Day, rainy-day watering does not consume resources, and Day 14 cannot advance to Day 15.

- [ ] **Step 9: Commit the runtime integration**

```bash
git add scripts/ui/game_hud.gd scenes/ui/game_hud.tscn scripts/world/world_shell.gd scenes/world/world.tscn tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: wire the Godot farming gameplay loop"
```

---

### Task 6: Extend the one clean verifier and update the Godot handoff

**Files:**
- Modify: `tools/verify-clean.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `.github/workflows/ci.yml` remains one Godot job

**Interfaces:**
- `./tools/verify-clean.sh` remains the only clean-checkout verification entry point
- README/CLAUDE describe the HPA-589 gameplay boundary and controls without creating a second source of balance truth

- [ ] **Step 1: Extend the archive verifier in one place**

Keep the current archive-first structure and append GUT plus gameplay smoke while retaining all existing commands:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Do not add a second shell script or a second Actions job.

- [ ] **Step 2: Update README controls and current feature boundary**

Document `1/2/3/4`, Space, E, Shop/Shipping/Sleep/Morning Summary behavior, and that HPA-589 now owns farming/day/economy while HPA-594 remains the next social slice. Keep exact stable balance values in the design/spec/tests; README should explain player behavior rather than duplicate every assertion.

- [ ] **Step 3: Update `CLAUDE.md` architecture and verifier handoff**

Add the new ownership boundaries:

- `GameRules` = closed pure rules/content;
- `GameSession` = only mutable gameplay-rules authority;
- `FarmView` = snapshot rendering only;
- `GameHud` = presentation/modal state only;
- `WorldShell` = only production session holder + runtime coordinator;
- `PlayerController` stays movement/facing/targeting only.

Replace the HPA-590-only verification command list with the six-command clean verifier sequence above. State explicitly that persistence/social/finale remain later work and no second runtime exists.

- [ ] **Step 4: Run the committed-state clean verifier**

Commit the verifier/docs changes first because `verify-clean.sh` tests archived committed `HEAD`:

```bash
git add tools/verify-clean.sh README.md CLAUDE.md
git commit -m "docs: document and verify the HPA-589 gameplay port"
./tools/verify-clean.sh
```

Expected: editor/import, all GUT tests, project smoke, world-math smoke, existing world-shell smoke, and gameplay-shell smoke all pass from the temporary archive.

- [ ] **Step 5: Run final repository checks**

```bash
git diff --check main...HEAD
git status --short
git diff --name-only main...HEAD
```

Expected:

- `git diff --check` is clean;
- `git status --short` is empty;
- changed files are limited to HPA-589 gameplay/test/docs/vendor scope;
- no JavaScript/Tauri runtime, persistence/social/finale implementation, generic framework, or unrelated cleanup has entered the PR.

- [ ] **Step 6: Verify CI shape rather than redesign it**

Inspect `.github/workflows/ci.yml` and confirm it still pins Godot `4.7.1`, `use-dotnet: false`, and invokes only `./tools/verify-clean.sh` after `godot --version`. No workflow edit is needed unless the existing job stops satisfying that contract.

- [ ] **Step 7: Keep the PR draft until the full HPA-589 matrix is green**

Update the existing PR description only if implementation facts differ from the planning summary. Keep the same branch/PR for implementation and mark it ready only after the clean verifier, manual normal-control journey, Day-14 boundary, and scope checks above pass.
