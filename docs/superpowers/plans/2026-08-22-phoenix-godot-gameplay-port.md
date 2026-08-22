# Phoenix Godot Gameplay Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's complete farming, daily-rhythm, and three-crop economy loop in Godot while preserving one mutable gameplay authority and the explicit HPA-590 scene contracts.

**Architecture:** Add one pure `GameRules` helper and one mutable `GameSession`. Keep the existing `Entities` node as the only Y-sort owner and attach `FarmView` to it so farm/scenery roots stay direct Y-sort children. `WorldShell` remains a thin coordinator, `PlayerController` keeps movement/targeting, and one `GameHud` owns presentation-only HUD/modal state. Extend the existing smokes and `verify-clean.sh` at the same seams the feature changes rather than deferring contract fixes to cleanup.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-22-phoenix-godot-gameplay-port-design.md`

## Global Constraints

- Deliver HPA-589 in this same draft PR; do not open a second implementation PR.
- Preserve all HPA-590 map/projection/spawn/movement/camera/tree/building values.
- `Entities` stays the only Y-sort-enabled `CanvasItem`; farm plots and shipping are direct `Entities` children.
- Integer farm-cell presentation anchors use `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`, never `grid_to_world(cell)`.
- Farm stays `x=2..4,y=7..9`; shop `(6,7)`; bed `(6,8)`; shipping `(6,10)`; shipping footprint `Rect2(6.2,10.2,0.6,0.6)`.
- Crops stay Turnip `3 / 20G / 35G`, Potato `5 / 40G / 75G`, Pumpkin `7 / 70G / 140G` for watered nights / seed price / sale value.
- Day starts at `06:00` (`360`), stamina `20`, cutoff `22:00` (`1320`), max day `14`, starting money `150G`, starter Turnip seeds `3`.
- Costs stay Hoe `30m/3`, Seeds `20m/1`, Water `20m/2`, Hands `20m/1`.
- Day 1 is sunny; later successful transitions use a 25% rain chance.
- Rain advances planted non-mature crops overnight; manual rainy-day watering returns `rain-waters-crops` without mutation.
- Shipping removes carried crops immediately; one successful sleep settles pending shipment exactly once before the blocking summary.
- Sleeping on Day 14 cannot consume RNG, settle shipping, or advance to Day 15.
- Command results use the closed `GameRules.CommandCode` enum; `command_code_key` preserves established spellings such as `action-too-late` and `insufficient-stamina`.
- `GameSession.snapshot()` is a current read model for FarmView/HUD, not a save-schema design exercise.
- Player-facing controls use `InputMap`; no raw keycode switch in `WorldShell`.
- Keep one `./tools/verify-clean.sh` entry point and one existing GitHub Actions Godot job.
- No C#, GDExtension, JavaScript/Tauri runtime, compatibility layer, persistence/schema work, villagers/social behavior, finale behavior, generic manager/service/event-bus/item-registry/command framework, GUT mocks/doubles, or unrelated shell refactor.

---

### Task 1: Pin GUT and freeze closed gameplay rules/codes

**Files:**
- Vendor: `addons/gut/**` from GUT `v9.7.1`
- Create: `scripts/game/game_rules.gd`
- Create: `tests/unit/test_game_rules.gd`

**Interfaces:**
- Produces: `GameRules.CropKind`, `FarmingAction`, `Weather`, `CommandCode`
- Produces constants: `DAY_START_MINUTES`, `ACTION_CUTOFF_MINUTES`, `MAX_STAMINA`, `MAX_DAY`, `RAIN_CHANCE`, `STARTING_MONEY`, `STARTING_TURNIP_SEEDS`
- Produces: `starting_seed_counts`, `command_code_key`, `crop_key`, `crop_display_name`, `growth_nights`, `seed_price`, `sale_value`, `action_cost`, `visual_stage`, `is_mature`, `evaluate_action_budget`, `shipment_payout`, `weather_from_roll`, `format_time`
- Consumes: no mutable game/world state

- [ ] **Step 1: Vendor exactly GUT 9.7.1 and prove Godot can import the clean addon**

Keep the upstream addon layout under `addons/gut/`. Do not add a package/download step to CI.

Run:

```bash
godot --headless --path . --editor --quit
```

Expected: editor import exits 0 with the vendored addon present.

- [ ] **Step 2: Write RED tests for frozen constants, crop rules, and command-code keys**

Create `tests/unit/test_game_rules.gd` extending `GutTest`:

```gdscript
extends GutTest

func test_starter_and_day_constants_are_exact() -> void:
    assert_eq(GameRules.DAY_START_MINUTES, 360)
    assert_eq(GameRules.ACTION_CUTOFF_MINUTES, 1320)
    assert_eq(GameRules.MAX_STAMINA, 20)
    assert_eq(GameRules.MAX_DAY, 14)
    assert_eq(GameRules.STARTING_MONEY, 150)
    assert_eq(GameRules.STARTING_TURNIP_SEEDS, 3)
    assert_eq(GameRules.starting_seed_counts(), [3, 0, 0])

func test_historical_budget_code_keys_are_preserved() -> void:
    assert_eq(
        GameRules.command_code_key(GameRules.CommandCode.ACTION_TOO_LATE),
        &"action-too-late",
    )
    assert_eq(
        GameRules.command_code_key(GameRules.CommandCode.INSUFFICIENT_STAMINA),
        &"insufficient-stamina",
    )

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
```

Table-drive `command_code_key` over the complete code set from the spec so every enum value has one stable key and there is no arbitrary StringName fallback.

Also table-drive all 3/5/7 maturity/visual-stage boundaries, exact four action costs, `format_time(360) == "06:00"`, invalid weather rolls outside `[0.0,1.0)`, and itemized payout order/total.

- [ ] **Step 3: Write RED budget/weather tests with exact precedence**

```gdscript
func test_action_budget_accepts_exact_2200_boundary() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1290, 3, GameRules.FarmingAction.HOE),
        {"ok": true, "time_minutes": 1320, "stamina": 0},
    )

func test_action_budget_checks_time_before_stamina() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1310, 0, GameRules.FarmingAction.HOE),
        {"ok": false, "code": GameRules.CommandCode.ACTION_TOO_LATE},
    )

func test_weather_threshold_is_exact() -> void:
    assert_eq(GameRules.weather_from_roll(0.249999), GameRules.Weather.RAINY)
    assert_eq(GameRules.weather_from_roll(0.25), GameRules.Weather.SUNNY)
```

- [ ] **Step 4: Run focused tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

Expected: failure because `GameRules` is absent.

- [ ] **Step 5: Implement the minimal `GameRules` helper**

Use one `RefCounted` matching `WorldMath`'s static-helper style:

```gdscript
class_name GameRules
extends RefCounted

enum CropKind { TURNIP, POTATO, PUMPKIN }
enum FarmingAction { HOE, SEEDS, WATERING_CAN, HANDS }
enum Weather { SUNNY, RAINY }
enum CommandCode {
    ACTION_SELECTED,
    SEED_SELECTED,
    SOIL_TILLED,
    CROP_PLANTED,
    CROP_WATERED,
    CROP_HARVESTED,
    SEEDS_PURCHASED,
    CROP_DEPOSITED,
    DAY_ADVANCED,
    DAY_STARTED,
    NO_TARGET,
    NOT_FARM_CELL,
    ALREADY_TILLED,
    SOIL_UNTILLED,
    CROP_PRESENT,
    NO_SELECTED_SEEDS,
    NO_CROP,
    ALREADY_WATERED,
    CROP_MATURE,
    CROP_IMMATURE,
    NOT_AT_BED,
    NOT_AT_SHOP,
    NOT_AT_SHIPPING_BIN,
    INVALID_QUANTITY,
    INSUFFICIENT_FUNDS,
    INSUFFICIENT_CROPS,
    ACTION_TOO_LATE,
    INSUFFICIENT_STAMINA,
    RAIN_WATERS_CROPS,
    DAY_SUMMARY_PENDING,
    NO_DAY_SUMMARY,
    DAY_LIMIT_REACHED,
    NOTHING_TO_INTERACT,
}

const DAY_START_MINUTES := 360
const ACTION_CUTOFF_MINUTES := 1320
const MAX_STAMINA := 20
const MAX_DAY := 14
const RAIN_CHANCE := 0.25
const STARTING_MONEY := 150
const STARTING_TURNIP_SEEDS := 3
const CROP_KEYS: Array[StringName] = [&"turnip", &"potato", &"pumpkin"]
const GROWTH_NIGHTS: Array[int] = [3, 5, 7]
const SEED_PRICES: Array[int] = [20, 40, 70]
const SALE_VALUES: Array[int] = [35, 75, 140]
const ACTION_MINUTES: Array[int] = [30, 20, 20, 20]
const ACTION_STAMINA: Array[int] = [3, 1, 2, 1]

static func starting_seed_counts() -> Array[int]:
    return [STARTING_TURNIP_SEEDS, 0, 0]
```

Implement `command_code_key` as one exhaustive `match` with the exact strings from the spec. Do not derive spellings from enum names or accept unknown values.

`evaluate_action_budget` checks time before stamina and returns enum codes. `shipment_payout` iterates crop enum order. Invalid enum indices/weather rolls are programmer errors and may assert.

- [ ] **Step 6: Run rules tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

- [ ] **Step 7: Commit**

```bash
git add addons/gut scripts/game/game_rules.gd tests/unit/test_game_rules.gd
git commit -m "test: freeze HPA-589 gameplay rules"
```

---

### Task 2: Add authoritative farm state and atomic farming commands

**Files:**
- Create: `scripts/game/game_session.gd`
- Create: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `GameRules`, `WorldContract.farm_cells()`
- Produces: `snapshot`, `select_action`, `select_seed`, `apply_selected_action`, `hoe`, `plant`, `water`, `harvest`
- Produces results exactly `{"ok": bool, "code": GameRules.CommandCode}`

- [ ] **Step 1: Write RED starter-state and deep-copy tests**

```gdscript
extends GutTest

func test_new_session_has_exact_starter_state() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var snapshot := session.snapshot()
    assert_eq(snapshot["day"], 1)
    assert_eq(snapshot["time_minutes"], GameRules.DAY_START_MINUTES)
    assert_eq(snapshot["stamina"], GameRules.MAX_STAMINA)
    assert_eq(snapshot["weather"], &"sunny")
    assert_eq(snapshot["money"], GameRules.STARTING_MONEY)
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
    assert_eq(fresh["seeds"][&"turnip"], GameRules.STARTING_TURNIP_SEEDS)
```

Also assert the nine farm entries are in `WorldContract.farm_cells()` row-major order and the snapshot contains no interaction cells/world position/node/UI fields.

- [ ] **Step 2: Write RED ordered-guard/atomicity tests**

For every failure capture `before := session.snapshot()` and assert the complete snapshot is unchanged.

Pin farming order:

`target -> farm membership -> command-specific state -> time -> stamina`.

Use established codes: `NO_TARGET`, `NOT_FARM_CELL`, `ALREADY_TILLED`, `SOIL_UNTILLED`, `CROP_PRESENT`, `NO_SELECTED_SEEDS`, `NO_CROP`, `CROP_MATURE`, `CROP_IMMATURE`, `ALREADY_WATERED`, `ACTION_TOO_LATE`, `INSUFFICIENT_STAMINA`, `RAIN_WATERS_CROPS`.

Pin one exact success chain:

```gdscript
func test_turnip_actions_commit_atomically() -> void:
    var session := GameSession.new()
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), {"ok": true, "code": GameRules.CommandCode.SOIL_TILLED})
    assert_eq(session.plant(cell), {"ok": true, "code": GameRules.CommandCode.CROP_PLANTED})
    assert_eq(session.water(cell), {"ok": true, "code": GameRules.CommandCode.CROP_WATERED})
    var snapshot := session.snapshot()
    assert_eq(snapshot["time_minutes"], 430)
    assert_eq(snapshot["stamina"], 14)
    assert_eq(snapshot["seeds"][&"turnip"], 2)
```

Also prove `select_action` returns `ACTION_SELECTED`, `select_seed` returns `SEED_SELECTED`, `apply_selected_action` dispatches only the four closed farming actions, and harvest leaves tilled soil while incrementing carried inventory.

- [ ] **Step 3: Run and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

- [ ] **Step 4: Implement one mutable `GameSession`**

Use closed arrays/dictionaries; do not add domain entity classes:

```gdscript
class_name GameSession
extends RefCounted

var _day: int = 1
var _time_minutes: int = GameRules.DAY_START_MINUTES
var _stamina: int = GameRules.MAX_STAMINA
var _weather: GameRules.Weather = GameRules.Weather.SUNNY
var _selected_action: GameRules.FarmingAction = GameRules.FarmingAction.HOE
var _selected_seed: GameRules.CropKind = GameRules.CropKind.TURNIP
var _money: int = GameRules.STARTING_MONEY
var _seed_counts: Array[int] = GameRules.starting_seed_counts()
var _harvested_counts: Array[int] = [0, 0, 0]
var _pending_shipment_counts: Array[int] = [0, 0, 0]
var _farm: Array[Dictionary] = []
var _pending_morning_summary: Variant = null
var _weather_roll: Callable

func _init(weather_roll: Callable = Callable()) -> void:
    _weather_roll = weather_roll if weather_roll.is_valid() else func() -> float: return randf()
    for cell in WorldContract.farm_cells():
        _farm.append({"cell": cell, "tilled": false, "crop": null})
```

Validate an entire command before mutation; apply budget only after command-specific guards pass. `snapshot()` returns fresh stable-key dictionaries and deep-copies all nested arrays/dictionaries for current presentation safety.

- [ ] **Step 5: Run all unit tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add authoritative Godot farming session"
```

---

### Task 3: Add weather, sleep, economy, shipping, and morning blocking

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `buy_seeds`, `deposit_crop`, `sleep`, `acknowledge_morning_summary`
- Adds one shared active-day gate used by selection, farming, buying, depositing, and sleep

- [ ] **Step 1: Add public-command-only test helpers, then write RED economy tests**

Do not add production setters/test hooks. Build a harvested Turnip through public commands:

```gdscript
func _grow_and_harvest_turnip(session: GameSession, cell := Vector2i(2, 7)) -> void:
    assert_true(session.hoe(cell)["ok"])
    assert_true(session.plant(cell)["ok"])
    for _night in 3:
        assert_true(session.water(cell)["ok"])
        assert_true(session.sleep(WorldContract.BED_CELL)["ok"])
        assert_true(session.acknowledge_morning_summary()["ok"])
    assert_true(session.harvest(cell)["ok"])
```

Use a deterministic sunny weather callable (`func() -> float: return 0.9`). Pin:

- `buy_seeds`: active-day → shop target → positive quantity → funds;
- `deposit_crop`: active-day → shipping target → positive quantity → carried crop;
- exact success codes `SEEDS_PURCHASED` / `CROP_DEPOSITED`;
- `NOT_AT_SHOP`, `NOT_AT_SHIPPING_BIN`, `INVALID_QUANTITY`, `INSUFFICIENT_FUNDS`, `INSUFFICIENT_CROPS` rollback;
- immediate carried-crop removal on deposit.

- [ ] **Step 2: Write RED overnight transaction and summary-gate tests**

Prove independently:

- watered sunny crop advances once;
- unwatered sunny crop does not advance;
- rainy completed day advances each planted non-mature crop;
- surviving `watered_today` resets;
- next weather uses `<0.25` rainy / `>=0.25` sunny;
- shipping credits exact itemized payout once and clears pending before summary;
- pending summary makes `select_action`, `select_seed`, farming, buy, deposit, and sleep return `DAY_SUMMARY_PENDING` with no mutation;
- acknowledgment returns `DAY_STARTED`; duplicate acknowledgment returns `NO_DAY_SUMMARY` and cannot pay/advance.

- [ ] **Step 3: Pin Day-14 no-RNG/no-settlement behavior without a test hook**

Use public commands only:

1. Grow/harvest one Turnip early and keep it carried.
2. Sleep/acknowledge until Day 14 using a counting weather callable.
3. Deposit the carried Turnip on Day 14.
4. Capture snapshot + callable invocation count.
5. Call `sleep(WorldContract.BED_CELL)`.
6. Assert `DAY_LIMIT_REACHED`, exact snapshot equality, pending shipment still contains the Turnip, and callable count is unchanged.

- [ ] **Step 4: Add one public-command-only full-loop test**

Using only public methods prove:

`buy Potato seed -> hoe -> plant -> water/sleep until mature -> harvest -> deposit -> sleep/payout -> acknowledge -> buy Potato again from increased money`.

Do not set money, growth, day, inventory, or shipment directly.

- [ ] **Step 5: Run and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

- [ ] **Step 6: Implement the active-day gate and atomic day transition**

Add one private helper returning `DAY_SUMMARY_PENDING`. Call it first from selection, all farming commands, buying, depositing, and sleep.

`sleep` checks:

```text
active-day
bed target
_day < GameRules.MAX_DAY
next weather valid
shipment payout valid
```

Only then commit:

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

The summary contains completed/next day, crops advanced, next weather, restored stamina, deterministic shipping lines, shipping income, and money after shipping. Acknowledgment only clears the summary.

- [ ] **Step 7: Run all GUT tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 8: Commit**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore Godot day and crop economy rules"
```

---

### Task 4: Extend the authored world contract without breaking one-Y-sort ownership

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/player/player_controller.gd`
- Create: `scripts/world/farm_view.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_math_smoke.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Create: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- Produces: `WorldContract.SHOP_CELL`, `BED_CELL`, `SHIPPING_CELL`, `SHIPPING_FOOTPRINT`
- Produces: `PlayerController.set_input_enabled(enabled: bool)`, `current_target_cell() -> Variant`
- Produces: `FarmView.refresh(snapshot: Dictionary)` on the existing `Entities` node
- Preserves: exactly one Y-sort-enabled `CanvasItem`

- [ ] **Step 1: Extend `world_math_smoke.gd` RED contract assertions first**

Add exact assertions:

```gdscript
if not _expect(WorldContract.SHOP_CELL == Vector2i(6, 7), "shop cell contract"):
    return
if not _expect(WorldContract.BED_CELL == Vector2i(6, 8), "bed cell contract"):
    return
if not _expect(WorldContract.SHIPPING_CELL == Vector2i(6, 10), "shipping cell contract"):
    return
if not _expect(
    WorldContract.SHIPPING_FOOTPRINT == Rect2(6.2, 10.2, 0.6, 0.6),
    "shipping footprint contract",
):
    return
```

Run:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
```

Expected: parse/member failures until constants exist.

- [ ] **Step 2: Add only the four interaction constants**

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Run `world_math_smoke.gd` again and verify GREEN before scene changes.

- [ ] **Step 3: Add RED player/FarmView assertions to `gameplay_shell_smoke.gd`**

Load the real `world.tscn` and assert:

- `Entities` is a `FarmView` and remains Y-sort enabled;
- no other world `CanvasItem` enables Y-sort;
- exactly nine farm roots exist directly under `Entities`;
- each root position equals `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`;
- each plot contains Soil/Crop presentation children;
- `set_input_enabled(false)` zeros/stops player movement and re-enable restores it;
- `current_target_cell()` matches `WorldMath.target_cell(WorldMath.world_to_grid(player.global_position), player.facing)`.

- [ ] **Step 4: Add `FarmView` to the existing `Entities` node**

Attach `scripts/world/farm_view.gd` directly to `Entities`; do not add `FarmView` as a nested node.

On `_ready()`, append plot roots in `WorldContract.farm_cells()` order:

```gdscript
func _plot_name(cell: Vector2i) -> StringName:
    return StringName("FarmPlot_%d_%d" % [cell.x, cell.y])

func _ready() -> void:
    for cell in WorldContract.farm_cells():
        var plot := Node2D.new()
        plot.name = _plot_name(cell)
        plot.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
        add_child(plot)
```

Each plot gets:

- Soil sprite: `proof-soil.png`, `hframes = 2`, centered on the root;
- Crop sprite: `proof-crops.png`, `hframes = 4`, `vframes = 3`, `offset = Vector2(0, -24)`.

`refresh(snapshot)` only sets visibility/frames from snapshot data. Do not copy gameplay state into node metadata.

- [ ] **Step 5: Add Shipping as an `Entities` sibling and collision as a `StaticCollision` sibling**

In `world.tscn`:

- `Shipping` is after `Building`, direct child of `Entities`;
- position = `WorldMath.grid_to_world(Vector2(WorldContract.SHIPPING_CELL) + Vector2(0.5, 0.5))` (store the resolved projected value in the authored scene and assert it from the helper);
- sprite = `proof-scenery.png`, `hframes = 3`, `frame = 2`, `offset = Vector2(0, -48)`;
- `ShippingCollision` is a direct `StaticCollision` child.

Extend `WorldShell._ready()`:

```gdscript
var shipping_collision := static_collision.get_node("ShippingCollision") as CollisionPolygon2D
shipping_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)
```

- [ ] **Step 6: Update the existing exact-tree shell smoke in the same change**

Modify `tests/headless/world_shell_smoke.gd`; this is required, not cleanup.

`StaticCollision` expected names become:

```gdscript
[
    "TreeCollision",
    "BuildingCollision",
    "ShippingCollision",
    "PerimeterTop",
    "PerimeterRight",
    "PerimeterBottom",
    "PerimeterLeft",
]
```

Build exact `Entities` expected names from the authored cells:

```gdscript
var entity_names := ["Player", "Tree", "Building", "Shipping"]
for cell in WorldContract.farm_cells():
    entity_names.append("FarmPlot_%d_%d" % [cell.x, cell.y])
if not _expect_names(entities, entity_names, "Entities"):
    return
```

Keep and extend these assertions:

- exactly one enabled Y-sort node and it is `Entities`;
- Player/Tree/Building/Shipping/plots share entity z-index;
- shipping frame/offset/center anchor are exact;
- each farm root uses the cell-center helper;
- existing tree/building exact-Y ordering tests remain unchanged.

- [ ] **Step 7: Run all affected headless smokes**

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Expected: all pass with exactly one Y-sort owner.

- [ ] **Step 8: Commit**

```bash
git add scripts/world/world_contract.gd scripts/player/player_controller.gd scripts/world/farm_view.gd scripts/world/world_shell.gd scenes/world/world.tscn tests/headless/world_math_smoke.gd tests/headless/world_shell_smoke.gd tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: add Godot farm and economy world adapters"
```

---

### Task 5: Add InputMap controls, one HUD, and `WorldShell` coordination

**Files:**
- Modify: `project.godot`
- Create: `scripts/ui/game_hud.gd`
- Create: `scenes/ui/game_hud.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- InputMap actions: `select_hoe`, `select_seeds`, `select_water`, `select_hands`, `use_action`, `interact`
- `GameHud`: `render(snapshot)`, `has_blocking_modal`, panel open methods, `show_feedback(code)`
- HUD signals: action/seed selection, buy, deposit, sleep confirm, summary acknowledge, modal-state change
- `WorldShell` is the only production holder of `GameSession`

- [ ] **Step 1: Add RED InputMap assertions to `world_shell_smoke.gd`**

Extend the existing key table with:

```gdscript
for entry in [
    {"action": "select_hoe", "physical": 49},
    {"action": "select_seeds", "physical": 50},
    {"action": "select_water", "physical": 51},
    {"action": "select_hands", "physical": 52},
    {"action": "use_action", "physical": 32},
    {"action": "interact", "physical": 69},
]:
    if not _expect(InputMap.has_action(entry.action), "%s gameplay action" % entry.action):
        return
    var has_key := false
    for event in InputMap.action_get_events(entry.action):
        if event is InputEventKey and event.physical_keycode == entry.physical:
            has_key = true
    if not _expect(has_key, "%s physical key" % entry.action):
        return
```

Run `world_shell_smoke.gd`; expected RED until `project.godot` changes.

- [ ] **Step 2: Add the six InputMap actions to `project.godot`**

Map physical 1/2/3/4, Space, E to the exact action names above. Keep WASD actions untouched.

Run `world_shell_smoke.gd`; new InputMap assertions should pass before HUD integration.

- [ ] **Step 3: Extend `gameplay_shell_smoke.gd` with RED routing/gate assertions**

Call production coordinator methods directly, not synthetic OS events. Prove:

- shop/bed/shipping target opens only its panel;
- off-target interact emits `NOTHING_TO_INTERACT` feedback without calling a session mutation;
- any modal disables player movement plus action selection/use/interact routing;
- blocked routing leaves the session snapshot unchanged;
- closing Shop/Shipping/Sleep restores world input when no summary exists;
- successful sleep presents Morning Summary and it remains blocking until acknowledgment.

- [ ] **Step 4: Build one consolidated `GameHud`**

Create one `CanvasLayer` + `Control` scene. Always visible:

- day/time/weather/stamina/money;
- four farming actions;
- selected seed + three seed counts;
- three harvested counts;
- pending shipment total;
- interaction/command feedback.

Mutually exclusive modal containers:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Shop/Shipping each use three crop rows, one `SpinBox`, one `Max` button, and one explicit Buy/Deposit button. Quantity/row/focus/panel state remains UI-only.

Expose these signals (integer arguments carry the closed enum values):

```gdscript
signal select_action_requested(action: int)
signal select_seed_requested(kind: int)
signal buy_requested(kind: int, quantity: int)
signal deposit_requested(kind: int, quantity: int)
signal sleep_requested
signal morning_summary_acknowledged
signal modal_state_changed
```

`show_feedback(code: GameRules.CommandCode)` uses one exhaustive `match` over every `CommandCode`; do not map arbitrary StringNames.

Escape closes Shop/Shipping/Sleep and emits `modal_state_changed`. Morning Summary closes only after successful acknowledgment.

- [ ] **Step 5: Add `GameHud` as a root sibling and update the exact root smoke immediately**

Instance `scenes/ui/game_hud.tscn` as `GameHud` under `World`, not under `Entities`.

Update the exact root list in `world_shell_smoke.gd` from:

```gdscript
["Ground", "StaticCollision", "Entities", "TargetHighlight"]
```

to:

```gdscript
["Ground", "StaticCollision", "Entities", "TargetHighlight", "GameHud"]
```

Keep the one-Y-sort assertion unchanged; `GameHud` must not participate in world Y-sort.

- [ ] **Step 6: Construct one session and refresh one snapshot**

In `WorldShell`:

```gdscript
var _session := GameSession.new()

@onready var player := $Entities/Player as PlayerController
@onready var farm_view := $Entities as FarmView
@onready var hud := $GameHud as GameHud

func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate(snapshot)
```

After every session command, call `hud.show_feedback(result["code"])` and refresh from a fresh snapshot. Do not keep gameplay copies in `WorldShell` or `GameHud`.

- [ ] **Step 7: Add production routing helpers and sample InputMap names**

Expose helpers shared by `_unhandled_input` and the composition smoke:

```gdscript
func select_action_slot(slot: int) -> void
func use_selected_action() -> void
func interact() -> void
```

`_unhandled_input(event)` uses action names only:

```gdscript
if event.is_action_pressed("select_hoe"):
    select_action_slot(1)
elif event.is_action_pressed("select_seeds"):
    select_action_slot(2)
elif event.is_action_pressed("select_water"):
    select_action_slot(3)
elif event.is_action_pressed("select_hands"):
    select_action_slot(4)
elif event.is_action_pressed("use_action"):
    use_selected_action()
elif event.is_action_pressed("interact"):
    interact()
```

`interact()` reads `player.current_target_cell()` each time. Shop/shipping/bed open the corresponding panel; elsewhere call `hud.show_feedback(GameRules.CommandCode.NOTHING_TO_INTERACT)`.

Buy/deposit/sleep-confirm handlers re-read the target and pass it to `GameSession`; an already-open panel never acts as authorization.

- [ ] **Step 8: Apply one derived gate to both movement and world commands**

```gdscript
func _refresh_world_input_gate(snapshot: Dictionary) -> void:
    var enabled := (
        not hud.has_blocking_modal()
        and snapshot["pending_morning_summary"] == null
    )
    player.set_input_enabled(enabled)
    _world_input_enabled = enabled
```

`select_action_slot`, `use_selected_action`, and `interact` return immediately when `_world_input_enabled` is false. Do not create a second lock graph.

HUD command signals (buy/deposit/sleep/summary acknowledgment) remain available while their modal is intentionally open; the domain revalidates target/summary state.

- [ ] **Step 9: Run unit and headless composition suites**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

- [ ] **Step 10: Perform one bounded normal-control proof**

```bash
godot --path .
```

Using only normal controls/UI:

1. complete `buy -> hoe -> plant -> water -> sleep/grow -> harvest -> ship -> payout -> buy again`;
2. open one modal and confirm movement plus Space/E/1-4 are blocked;
3. close it and confirm input resumes.

Do **not** manually play fourteen days to prove the Day-14 boundary; Task 3's deterministic GUT test owns that contract.

- [ ] **Step 11: Commit**

```bash
git add project.godot scripts/ui/game_hud.gd scenes/ui/game_hud.tscn scripts/world/world_shell.gd scenes/world/world.tscn tests/headless/world_shell_smoke.gd tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: wire the Godot farming gameplay loop"
```

---

### Task 6: Extend the one clean verifier and handoff docs

**Files:**
- Modify: `tools/verify-clean.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `AGENTS.md` symlink
- Verify only: `.github/workflows/ci.yml`

**Interfaces:**
- `./tools/verify-clean.sh` remains the only clean-checkout verification entry point
- `AGENTS.md` remains a symlink to `CLAUDE.md`; do not write duplicate handoff content

- [ ] **Step 1: Extend the archive verifier in place**

Keep archive-first behavior and run exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Do not add another verification script or Actions job.

- [ ] **Step 2: Update README behavior/controls**

Document:

- `1/2/3/4`, Space, E;
- Shop/Shipping/Sleep/Morning Summary behavior;
- the complete farming/economy loop;
- HPA-589 as gameplay authority;
- HPA-594 as the next social slice.

Keep exact exhaustive balance/code tables in tests/spec rather than duplicating them all in README.

- [ ] **Step 3: Update `CLAUDE.md` architecture and verification handoff**

Record ownership:

- `GameRules`: closed rules/content/command codes;
- `GameSession`: only mutable gameplay-rules authority;
- `Entities`/`FarmView`: the one Y-sort owner + snapshot rendering;
- `GameHud`: presentation/modal state only;
- `WorldShell`: only production session holder + coordinator;
- `PlayerController`: movement/facing/targeting only.

Replace the HPA-590-only verifier list with the six commands above. Keep persistence/social/finale explicitly outside current scope.

Do not edit `AGENTS.md` separately; it is the symlink to `CLAUDE.md`.

- [ ] **Step 4: Commit docs/verifier, then run fresh committed-state verification**

```bash
git add tools/verify-clean.sh README.md CLAUDE.md
git commit -m "docs: document and verify the HPA-589 gameplay port"
./tools/verify-clean.sh
```

Expected: archive import, GUT suite, project smoke, world-math smoke, world-shell smoke, and gameplay-shell smoke all exit 0.

- [ ] **Step 5: Run final repository/symlink checks**

```bash
git diff --check main...HEAD
git status --short
git diff --name-only main...HEAD
test "$(readlink AGENTS.md)" = "CLAUDE.md"
```

Expected: no whitespace errors, clean status, symlink intact, and only HPA-589 gameplay/test/docs/vendor files. Confirm no persistence/social/finale implementation, JavaScript/Tauri runtime, generic framework, or unrelated cleanup entered the PR.

- [ ] **Step 6: Verify CI shape without redesigning it**

Inspect `.github/workflows/ci.yml`. It must still pin Godot `4.7.1`, `use-dotnet: false`, and call only `./tools/verify-clean.sh` after `godot --version`. Leave it unchanged unless that existing contract has actually broken.

- [ ] **Step 7: Keep PR #7 draft until the implementation verification matrix is green**

Continue implementation on this branch/PR. Mark it ready only after the fresh clean verifier and bounded normal-control proof pass.