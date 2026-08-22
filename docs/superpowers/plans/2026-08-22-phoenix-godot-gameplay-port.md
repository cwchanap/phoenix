# Phoenix Godot Gameplay Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore farming, repeatable days, weather, the three-crop economy, shipping, and reinvestment on the Godot runtime in one HPA-589 PR.

**Architecture:** Keep one statically typed `GameSession` as the only mutable gameplay authority. Put closed tables/pure formulas in `GameRules`; let `WorldShell` coordinate Godot input/UI, `FarmView` render snapshots, and one consolidated `GameHud` own presentation-only panels.

**Tech Stack:** Godot 4.7.1 standard build, statically typed GDScript, GUT 9.7.1, existing headless smoke scripts and GitHub Actions verifier.

**Spec:** `docs/superpowers/specs/2026-08-22-phoenix-godot-gameplay-port-design.md`

## Global Constraints

- HPA-589 is delivered in **one PR**. Keep all task commits on the branch/PR that contains this plan; do not open a second implementation PR.
- Preserve HPA-590 map/projection/movement/camera contracts unless this plan names the exact interaction addition.
- Preserve the closed crop table: Turnip `3/20/35`, Potato `5/40/75`, Pumpkin `7/70/140` for growth nights / seed price / sale value.
- Preserve daily values: start `06:00`, cutoff `22:00`, stamina `20`; Hoe `30/3`, Seeds `20/1`, Water `20/2`, Hands `20/1` for minutes/stamina.
- Day 1 is sunny; later successful transitions use a 25% rain chance.
- Day 14 remains playable and cannot advance or settle shipping into Day 15.
- `GameSession` is the only mutable gameplay-rules authority. World position, rendering nodes, and presentation state remain outside its snapshot.
- Expected invalid gameplay commands return stable results and do not partially mutate state.
- Do not add managers/services/event buses/registries/generic item systems/persistence/social/finale behavior.
- Start every production change with focused RED evidence and end each task with its focused GREEN command before committing.

---

## File map

### Create

- `scripts/game/game_rules.gd` — closed enums, constants, pure crop/action/weather/payout helpers.
- `scripts/game/game_session.gd` — only mutable gameplay authority.
- `scripts/world/farm_view.gd` — snapshot-to-soil/crop rendering adapter.
- `scripts/ui/game_hud.gd` — HUD/panel presentation and intention signals.
- `scenes/ui/game_hud.tscn` — one consolidated gameplay HUD + four panels.
- `tests/unit/test_game_rules.gd` — direct GUT pure-rule coverage.
- `tests/unit/test_game_session.gd` — direct GUT state-machine/economy/day-transition coverage.
- `tests/headless/gameplay_shell_smoke.gd` — real-scene composition smoke.
- `addons/gut/**` — exact GUT 9.7.1 addon contents and MIT license from the upstream release.

### Modify

- `scripts/world/world_contract.gd` — bed/shop/shipping cells and shipping footprint.
- `scripts/world/world_shell.gd` — instantiate session; route input/UI; refresh views; gate movement.
- `scripts/player/player_controller.gd` — expose target cell and input enable/disable.
- `scenes/world/world.tscn` — compose FarmView, shipping bin/collision, and GameHud.
- `project.godot` — farming/action/interact input map.
- `tests/headless/world_shell_smoke.gd` — extend shell invariants for the shipping entity without weakening existing assertions.
- `tools/verify-clean.sh` — add direct GUT and gameplay composition smoke to the existing clean archive verifier.
- `CLAUDE.md` and `README.md` — replace the HPA-590 boundary text with the HPA-589 gameplay/runtime verification surface.

---

### Task 1: Pin GUT and freeze pure gameplay tables/formulas

**Files:**
- Create: `addons/gut/**`
- Create: `scripts/game/game_rules.gd`
- Create: `tests/unit/test_game_rules.gd`

**Interfaces:**
- Produces: `GameRules.CropKind`, `GameRules.FarmingAction`, `GameRules.Weather`.
- Produces: `crop_definition`, `crop_key`, `visual_stage`, `is_mature`, `action_cost`, `evaluate_action_budget`, `shipment_payout`, `weather_from_roll`, `format_time`.
- Consumed by: every later task.

- [ ] **Step 1: Vendor exactly GUT 9.7.1**

Copy the upstream v9.7.1 `addons/gut/` directory, including `addons/gut/LICENSE.md`, into the repository. Do not enable an editor-only test scene and do not add another test framework.

Verify the CLI loads under the pinned runtime:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gh
```

Expected: GUT help is printed with exit code `0`.

- [ ] **Step 2: Write RED tests for the closed crop/action tables**

Create `tests/unit/test_game_rules.gd` beginning with these exact expectations:

```gdscript
extends GutTest

func test_crop_values_are_frozen() -> void:
    assert_eq(GameRules.crop_definition(GameRules.CropKind.TURNIP), {
        "key": &"turnip", "display_name": "Turnip", "growth_nights": 3,
        "seed_price": 20, "sale_value": 35,
    })
    assert_eq(GameRules.crop_definition(GameRules.CropKind.POTATO)["growth_nights"], 5)
    assert_eq(GameRules.crop_definition(GameRules.CropKind.POTATO)["seed_price"], 40)
    assert_eq(GameRules.crop_definition(GameRules.CropKind.POTATO)["sale_value"], 75)
    assert_eq(GameRules.crop_definition(GameRules.CropKind.PUMPKIN)["growth_nights"], 7)
    assert_eq(GameRules.crop_definition(GameRules.CropKind.PUMPKIN)["seed_price"], 70)
    assert_eq(GameRules.crop_definition(GameRules.CropKind.PUMPKIN)["sale_value"], 140)

func test_action_costs_are_frozen() -> void:
    assert_eq(GameRules.action_cost(GameRules.FarmingAction.HOE), {"minutes": 30, "stamina": 3})
    assert_eq(GameRules.action_cost(GameRules.FarmingAction.SEEDS), {"minutes": 20, "stamina": 1})
    assert_eq(GameRules.action_cost(GameRules.FarmingAction.WATERING_CAN), {"minutes": 20, "stamina": 2})
    assert_eq(GameRules.action_cost(GameRules.FarmingAction.HANDS), {"minutes": 20, "stamina": 1})
```

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_rules.gd -gexit
```

Expected: FAIL because `GameRules` does not exist.

- [ ] **Step 3: Implement the closed enums/constants and table accessors**

Create `scripts/game/game_rules.gd` with this public shape:

```gdscript
class_name GameRules
extends RefCounted

enum CropKind { TURNIP, POTATO, PUMPKIN }
enum FarmingAction { HOE, SEEDS, WATERING_CAN, HANDS }
enum Weather { SUNNY, RAINY }

const DAY_START_MINUTES: int = 360
const ACTION_CUTOFF_MINUTES: int = 1320
const MAX_STAMINA: int = 20
const MAX_DAY: int = 14
const RAIN_CHANCE: float = 0.25

static func crop_definition(kind: CropKind) -> Dictionary:
    # Return a duplicate of the closed definition selected by kind.
    ...

static func crop_key(kind: CropKind) -> StringName:
    ...

static func action_cost(action: FarmingAction) -> Dictionary:
    ...
```

Replace the ellipses during implementation with exhaustive `match` branches returning the exact values in the spec. Do not use a fallback/default crop or action; an impossible value must assert as programmer error.

- [ ] **Step 4: Add RED boundary tests for visual stages, budgets, weather, and payout**

Add table-driven assertions covering:

```gdscript
assert_eq(GameRules.visual_stage(GameRules.CropKind.TURNIP, 0), 0)
assert_eq(GameRules.visual_stage(GameRules.CropKind.TURNIP, 3), 3)
assert_true(GameRules.is_mature(GameRules.CropKind.POTATO, 5))
assert_false(GameRules.is_mature(GameRules.CropKind.PUMPKIN, 6))

assert_eq(
    GameRules.evaluate_action_budget(1290, 3, GameRules.FarmingAction.HOE),
    {"ok": true, "time_minutes": 1320, "stamina": 0},
)
assert_eq(
    GameRules.evaluate_action_budget(1300, 0, GameRules.FarmingAction.HOE)["code"],
    &"action-too-late",
)
assert_eq(GameRules.weather_from_roll(0.0), GameRules.Weather.RAINY)
assert_eq(GameRules.weather_from_roll(0.249999), GameRules.Weather.RAINY)
assert_eq(GameRules.weather_from_roll(0.25), GameRules.Weather.SUNNY)
```

For payout, assert `{turnip: 2, potato: 1, pumpkin: 0}` produces ordered lines `2×35`, `1×75` and total `145`.

Run the focused file and confirm it fails on missing helpers.

- [ ] **Step 5: Implement the pure helpers minimally**

Use exactly:

```gdscript
static func visual_stage(kind: CropKind, progress: int) -> int:
    var growth_nights: int = crop_definition(kind)["growth_nights"]
    assert(progress >= 0 and progress <= growth_nights)
    return mini(3, floori(float(progress * 3) / float(growth_nights)))
```

`evaluate_action_budget` checks completion time first, stamina second, and returns a new dictionary. `shipment_payout` iterates Turnip → Potato → Pumpkin, skips zero counts, derives all values from the crop table, and returns `{ "lines": Array, "total": int }`. `format_time` returns zero-padded `HH:MM`.

- [ ] **Step 6: Run GREEN and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_rules.gd -gexit
git add addons/gut scripts/game/game_rules.gd tests/unit/test_game_rules.gd
git commit -m "test: pin HPA-589 gameplay rules"
```

Expected: the focused GUT file passes with zero test failures.

---

### Task 2: Build `GameSession` farming state and atomic action budgets

**Files:**
- Create: `scripts/game/game_session.gd`
- Create: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `GameRules` from Task 1 and `WorldContract.farm_cells()`.
- Produces: `snapshot`, action/seed selection, `apply_selected_action`, `hoe`, `plant`, `water`, `harvest`.
- Produces result shape: `{ "ok": bool, "code": StringName }`.

- [ ] **Step 1: Write the starter-state RED test**

```gdscript
extends GutTest

func test_new_session_has_exact_starter_state() -> void:
    var session := GameSession.new(Callable())
    var state := session.snapshot()
    assert_eq(state["day"], 1)
    assert_eq(state["time_minutes"], 360)
    assert_eq(state["stamina"], 20)
    assert_eq(state["money"], 150)
    assert_eq(state["selected_action"], &"hoe")
    assert_eq(state["selected_seed"], &"turnip")
    assert_eq(state["inventory"]["seeds"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["farm"].size(), 9)
```

Run the test file and confirm RED because `GameSession` does not exist.

- [ ] **Step 2: Implement construction and deep snapshotting**

`GameSession` stores row-major farm entries for `WorldContract.farm_cells()`, starter inventory/money, selected action/seed, day/time/stamina/sunny weather, empty pending shipment, and no pending summary.

Constructor signature:

```gdscript
func _init(weather_roll_source: Callable = Callable()) -> void:
```

If the callable is invalid, production weather rolls use a private callable around `randf()`. Keep that callable private and out of snapshots.

Make `snapshot()` duplicate every nested farm/inventory/shipment/summary collection so this assertion passes:

```gdscript
var first := session.snapshot()
var second := session.snapshot()
assert_ne(first, second)
assert_ne(first["inventory"], second["inventory"])
assert_ne(first["farm"], second["farm"])
```

- [ ] **Step 3: Add RED tests for ordered guards and full-snapshot atomicity**

Use the first farm cell from `WorldContract.farm_cells()` and prove:

- Plant on untilled → `soil-untilled` and exact snapshot equality.
- Hoe success → `soil-tilled`, time `390`, stamina `17`.
- Hoe again → `already-tilled`, no further budget change.
- Plant success → Turnip growth `0`, seeds decrement to `2`, time `410`, stamina `16`.
- Water success on sunny → `crop-watered`, time `430`, stamina `14`.
- Water again → `already-watered`, no budget change.
- Harvest immature → `crop-immature`, no budget change.

Use a helper local to the test file:

```gdscript
func assert_failure_is_atomic(session: GameSession, call: Callable, expected_code: StringName) -> void:
    var before := session.snapshot()
    var result: Dictionary = call.call()
    assert_false(result["ok"])
    assert_eq(result["code"], expected_code)
    assert_eq(session.snapshot(), before)
```

- [ ] **Step 4: Implement the four direct farming commands and selected-action dispatch**

Add the design signatures. Each method performs all target/farm/prerequisite validation before applying `GameRules.evaluate_action_budget` and mutates crop/inventory/time/stamina only after every check passes.

`apply_selected_action` is one exhaustive `match` over `selected_action`; do not add a command object or map of callbacks.

Use these result codes exactly: `action-selected`, `seed-selected`, `soil-tilled`, `crop-planted`, `crop-watered`, `crop-harvested`, `no-target`, `not-farm-cell`, `crop-present`, `already-tilled`, `soil-untilled`, `no-selected-seeds`, `no-crop`, `crop-mature`, `already-watered`, `crop-immature`, `action-too-late`, `insufficient-stamina`, `rain-waters-crops`, `day-summary-pending`.

- [ ] **Step 5: Add rainy-water and budget precedence tests**

Inject a deterministic weather roll for later tasks, directly set up the rainy state only through successful sleeps once sleep exists in Task 3, and keep the pure 22:00/time-before-stamina boundary in `test_game_rules.gd`. At this task boundary, prove GameSession applies successful budgets exactly once and reachable stamina exhaustion is atomic; do not add a test-only clock setter.

- [ ] **Step 6: Run GREEN and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add authoritative farming session"
```

---

### Task 3: Complete weather, sleeping, economy, shipping, and reinvestment

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `buy_seeds`, `deposit_crop`, `sleep`, `acknowledge_morning_summary`.
- Snapshot gains: money, complete seed/crop counts, pending shipment, current weather, fixed interaction cells, and pending morning summary.

- [ ] **Step 1: Add RED economy transaction tests**

At `WorldContract.SHOP_CELL`, assert buying `2` potatoes costs `80G`, money becomes `70G`, and potato seeds become `2`. Assert quantity `0`, a non-shop target, and an unaffordable purchase each preserve the complete pre-call snapshot.

At `WorldContract.SHIPPING_CELL`, use normal farming commands to obtain a mature crop, then assert depositing one removes it from carried crops immediately and increments pending shipment exactly once. Wrong target, zero quantity, and excessive quantity must be atomic failures.

- [ ] **Step 2: Implement `buy_seeds` and `deposit_crop`**

Follow this validation order exactly:

```text
buy: active-day → shop target → positive quantity → funds → mutate
ship: active-day → shipping target → positive quantity → carried count → mutate
```

Return only the codes from the design: `seeds-purchased`, `crop-deposited`, `not-at-shop`, `not-at-shipping-bin`, `invalid-quantity`, `insufficient-funds`, `insufficient-crops`.

- [ ] **Step 3: Add RED day-transition and rain tests**

Construct with deterministic rolls:

```gdscript
var rolls: Array[float] = [0.10, 0.80, 0.80]
var session := GameSession.new(func() -> float: return rolls.pop_front())
```

Prove the first successful sleep creates rainy Day 2; a manually unwatered crop on rainy Day 2 advances on the next sleep; manual Water on rainy returns `rain-waters-crops` with full snapshot equality; every surviving crop resets `watered_today` after sleep.

Prove morning summary blocks farming, buying, depositing, seed/action selection, and another sleep until `acknowledge_morning_summary()` returns `day-started`.

- [ ] **Step 4: Add RED shipping settlement tests**

With pending `{turnip: 2, potato: 1, pumpkin: 0}`, one successful sleep must:

```text
shipping lines: Turnip 2 × 35 = 70; Potato 1 × 75 = 75
shipping income: 145
pending shipment after sleep: all zero
money after shipping: previous money + 145
```

A second sleep while summary is pending must return `day-summary-pending` and not pay again. Summary acknowledgment changes only pending-summary state.

- [ ] **Step 5: Implement one direct sleep transaction**

Validate summary/bed/Day-14 before reading the weather source. Then validate `GameRules.weather_from_roll(weather_roll_source.call())` and `GameRules.shipment_payout(...)` before mutating.

Commit crop advancement, watering reset, payout, shipment clear, day increment, time/stamina reset, next weather, and summary creation in the exact order from the design. Do not introduce rollback objects: after all validation, the remaining operations are local plain-state assignments with no expected failure branch.

- [ ] **Step 6: Add the full player-loop and Day-14 regression tests**

One test must use only public commands to complete:

```text
buy Turnip seed → hoe → plant → water → sleep/ack
→ water → sleep/ack → water → sleep/ack
→ harvest → deposit → sleep → verify payout → ack → buy more seeds
```

Advance to Day 14 using successful `sleep` + `acknowledge_morning_summary`; deposit at least one crop before the Day-14 sleep attempt; assert `day-limit-reached`, no weather-roll consumption, unchanged pending shipment/money/crops/time/stamina/weather, and day remains 14.

- [ ] **Step 7: Run both unit files GREEN and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore daily rhythm and crop economy"
```

---

### Task 4: Add Godot interaction cells, input gating, farm rendering, and shipping-bin world composition

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/player/player_controller.gd`
- Create: `scripts/world/farm_view.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`

**Interfaces:**
- `WorldContract.BED_CELL = Vector2i(6, 8)`.
- `WorldContract.SHOP_CELL = Vector2i(6, 7)`.
- `WorldContract.SHIPPING_CELL = Vector2i(6, 10)`.
- `WorldContract.SHIPPING_FOOTPRINT = Rect2(6.2, 10.2, 0.6, 0.6)`.
- `PlayerController.current_target_cell() -> Variant`.
- `PlayerController.set_input_enabled(enabled: bool) -> void`.
- `FarmView.refresh(snapshot: Dictionary) -> void`.

- [ ] **Step 1: Extend shell smoke with RED world-contract assertions**

Add exact assertions for the three interaction cells, shipping footprint, projected shipping anchor, and no changes to map/farm/tree/building/camera constants. Run:

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: FAIL on the new missing constants/entity.

- [ ] **Step 2: Add the four world constants and shipping collision/entity**

Extend `WorldContract` only with the fixed values above.

In `world.tscn`, add a `ShippingBin` under `Entities`, using frame `2` of `proof-scenery.png`, anchored at `WorldMath.grid_to_world(Vector2(6.5, 10.5))`. Add one `ShippingCollision` polygon under `StaticCollision`; `WorldShell._ready()` derives its polygon through `WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)`.

Keep Player first under `Entities` so HPA-590 exact-Y ordering remains intact; place Tree, Building, and ShippingBin after Player.

- [ ] **Step 3: Add target exposure and movement gating to `PlayerController`**

Refactor `_update_target()` to use one stored `current_target` value and expose it:

```gdscript
var input_enabled: bool = true
var current_target: Variant = null

func set_input_enabled(enabled: bool) -> void:
    input_enabled = enabled
    if not enabled:
        velocity = Vector2.ZERO

func current_target_cell() -> Variant:
    return current_target
```

When disabled, `_physics_process` must not call `move_and_slide()` with user input. It may refresh target visuals from the unchanged position/facing.

- [ ] **Step 4: Create `FarmView` and RED-check its deterministic node mapping**

`FarmView` pre-creates exactly nine soil sprites and nine crop sprites keyed by the row-major `WorldContract.farm_cells()` list. `refresh(snapshot)` updates visibility/frame only; it never stores authoritative crop state.

Use existing assets:

```text
res://assets/sprites/proof-soil.png
res://assets/sprites/proof-crops.png
```

Crop frame formula is `int(kind) * 4 + GameRules.visual_stage(kind, growth)` using the stable enum order Turnip/Potato/Pumpkin. Wet soil is selected when `watered_today` or current weather is rainy.

Extend the shell smoke to assert nine aligned farm anchors and that the snapshot-facing renderer owns no `GameSession` reference.

- [ ] **Step 5: Run shell GREEN and commit**

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git add scripts/world scripts/player/player_controller.gd scenes/world/world.tscn tests/headless/world_shell_smoke.gd
git commit -m "feat: add farm and economy world adapters"
```

---

### Task 5: Add the consolidated HUD/panels and wire one runtime coordinator

**Files:**
- Create: `scripts/ui/game_hud.gd`
- Create: `scenes/ui/game_hud.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `project.godot`
- Create: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- `GameHud.refresh(snapshot: Dictionary, result: Dictionary, target_cell: Variant) -> void`.
- `GameHud.open_shop()`, `open_shipping()`, `open_sleep_confirmation()`, `show_morning_summary()`.
- Signals carry only intentions: action, seed, buy, deposit, sleep-confirm, summary-ack, close-panel.
- `WorldShell` is the only production owner of the `GameSession` object.

- [ ] **Step 1: Add project input actions**

Add keyboard mappings:

```text
farm_hoe    = 1
farm_seeds  = 2
farm_water  = 3
farm_hands  = 4
farm_apply  = Space
interact    = E
```

Keep existing WASD mappings unchanged.

- [ ] **Step 2: Create one HUD scene with exact presentation regions**

`game_hud.tscn` contains:

- always-visible status labels for Day/Time/Weather/Stamina/Money;
- four action Buttons;
- three seed Buttons and inventory/pending labels;
- one context-hint Label;
- one modal root with mutually exclusive Shop, Shipping, SleepConfirmation, MorningSummary containers.

Shop and Shipping each contain three crop-row buttons, a `SpinBox` with minimum `1`, a Buy/Deposit button, and Close. Keep quantity state in `GameHud` only. Do not create a reusable quantity component for two consumers.

- [ ] **Step 3: Implement `GameHud` as a view + intention emitter**

Define typed signals for action/seed kinds and transaction quantity. `refresh` maps snapshot values and stable result codes to labels. It may call `GameRules.format_time` and crop-definition display helpers but must not calculate action affordability, mutate inventory, calculate shipping payout, or advance a day.

`has_blocking_modal() -> bool` returns true for Shop/Shipping/SleepConfirmation/MorningSummary. The summary Close/Escape path is disabled; only Start Day emits summary acknowledgment.

- [ ] **Step 4: Write RED gameplay composition smoke**

Create `tests/headless/gameplay_shell_smoke.gd` that instantiates `world.tscn`, waits one process frame, and asserts:

- `WorldShell` created a session and initial HUD snapshot;
- FarmView has nine soil/crop slots;
- targeting shop/bed/shipping routes to the corresponding panel method;
- opening any panel disables `PlayerController.input_enabled`;
- closing shop/shipping/sleep confirmation re-enables movement when no summary exists;
- successful sleep leaves movement disabled while summary is pending;
- successful Start Day acknowledgment re-enables movement.

Use direct coordinator methods/signals in the smoke; do not synthesize OS keyboard events.

Run it and confirm RED before wiring `WorldShell`.

- [ ] **Step 5: Wire `WorldShell` as the thin coordinator**

On `_ready()`:

```text
create GameSession
connect GameHud signals
refresh FarmView + GameHud from initial snapshot
```

On input:

```text
1..4 → session.select_action
Space → session.apply_selected_action(player.current_target_cell())
E at shop → open shop
E at shipping → open shipping
E at bed → open sleep confirmation
E elsewhere → presentation-only nothing-to-interact feedback
```

HUD transactions call `buy_seeds` / `deposit_crop` with the current target again so the domain revalidates location. Sleep confirmation calls `session.sleep(current target)` exactly once. Every command path then obtains one fresh snapshot and refreshes both views.

Compute world-input enabled state from `not hud.has_blocking_modal()` and `snapshot["pending_morning_summary"] == null`; call `player.set_input_enabled` from that one function. Do not distribute independent lock flags across nodes.

- [ ] **Step 6: Run gameplay composition GREEN and commit**

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
git add project.godot scripts/ui scenes/ui scripts/world/world_shell.gd scenes/world/world.tscn tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: wire HPA-589 gameplay UI"
```

---

### Task 6: Close verification gaps and update the single clean-checkout contract

**Files:**
- Modify: `tools/verify-clean.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `tests/unit/test_game_rules.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- `./tools/verify-clean.sh` remains the only repository-wide verification entry point.

- [ ] **Step 1: Run a spec-coverage audit before broad verification**

Confirm the focused tests explicitly name all of these seams:

```text
crop growth boundaries: 3 / 5 / 7
sunny Water cost: 20 min / 2 stamina
rainy Water: rejected + zero mutation
22:00 evaluator boundary
invalid actions: complete snapshot unchanged
purchase + deposit atomicity
pending shipment clears on one successful sleep
income paid exactly once
morning summary blocks gameplay
Day 14 cannot become Day 15 or settle shipping
full buy→farm→ship→payout→reinvest journey
```

If any seam is missing, add the focused assertion to the existing two unit files; do not create another test abstraction.

- [ ] **Step 2: Append GUT and gameplay smoke to `verify-clean.sh`**

The archive-body command order becomes exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Do not create a second verification script or CI job.

- [ ] **Step 3: Update handoff documentation to the HPA-589 boundary**

Document:

- `GameSession` as the only mutable gameplay authority;
- `GameRules` as pure closed content/formulas;
- `FarmView` and `GameHud` as adapters only;
- the six gameplay inputs;
- the full `./tools/verify-clean.sh` command;
- HPA-594 as the next social port;
- persistence/social/finale remaining out of HPA-589.

Do not copy the historical TypeScript architecture back into current docs.

- [ ] **Step 4: Run focused and full committed-state verification**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
./tools/verify-clean.sh
git diff --check main...HEAD
```

Expected: all commands exit `0`; GUT reports zero failures; every headless smoke prints its success marker.

- [ ] **Step 5: Perform one bounded manual playthrough in the real scene**

Run:

```bash
godot --path . --editor project.godot
```

Play using normal controls and verify:

```text
shop opens only at shop target
buy changes money/seeds
1/2/3/4 + Space farm the highlighted diamond
rainy manual Water does not charge budget
sleep confirmation blocks movement
morning summary remains blocking until Start Day
harvest enters carried inventory
shipping deposit removes carried crop immediately
next successful sleep shows exact payout and clears pending
credited money buys another seed
```

Record only actual defects found; do not add visual polish outside the ticket.

- [ ] **Step 6: Commit the verification/documentation closeout**

```bash
git add tools/verify-clean.sh README.md CLAUDE.md tests
git commit -m "test: verify complete HPA-589 gameplay loop"
```

Run `./tools/verify-clean.sh` once more against committed `HEAD` after the commit.

---

## Final self-review checklist

Before marking the PR ready for review:

- [ ] `GameSession` is the only mutable rules owner and no UI/world node owns competing money/farm/day state.
- [ ] All three crop values and all four action costs match the design exactly.
- [ ] Failure ordering is explicit and failed commands preserve the complete snapshot.
- [ ] Rain and sunny watering semantics are both directly tested.
- [ ] Shipping is credited once during successful sleep, not during deposit or summary acknowledgment.
- [ ] Day 14 preserves pending shipment on rejected sleep.
- [ ] Morning summary blocks movement and gameplay until domain acknowledgment.
- [ ] Player position/facing/camera/render frames/panel state are absent from `GameSession.snapshot()`.
- [ ] GUT is pinned to 9.7.1 and runs inside `./tools/verify-clean.sh`.
- [ ] Existing HPA-590 world math/shell smokes still pass without weakened assertions.
- [ ] No social, persistence, finale, generic framework, or second runtime work entered the PR.
- [ ] `git diff --check main...HEAD` and committed-archive `./tools/verify-clean.sh` pass.