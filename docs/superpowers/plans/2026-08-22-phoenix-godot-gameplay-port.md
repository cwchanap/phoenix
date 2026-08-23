# Phoenix Godot Gameplay Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's complete farming, daily-rhythm, and three-crop economy loop in Godot while preserving one mutable gameplay authority and the explicit HPA-590 scene contracts.

**Architecture:** Add one pure `GameRules` helper and one mutable `GameSession`. Keep `FarmSoil` below target/entity rendering, keep crop/scenery roots as direct children of the existing one-Y-sort `Entities`, and attach `FarmView` to `Entities`. `WorldShell` remains a thin coordinator, `PlayerController` keeps movement/targeting, and one `GameHud` owns presentation/modal state. Wire every new test into the existing archive verifier in the same task that introduces it.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-22-phoenix-godot-gameplay-port-design.md`

## Global Constraints

- Deliver HPA-589 in this same draft PR; do not open a second implementation PR.
- Preserve all HPA-590 map/projection/spawn/movement/camera/tree/building values.
- `Entities` stays the only Y-sort-enabled `CanvasItem`; crop roots and shipping are direct `Entities` children.
- Soil lives under one non-Y-sorted root `FarmSoil` at z-index `5`, between Ground `0` and TargetHighlight `10`.
- Integer farm-cell anchors use `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`, never `grid_to_world(cell)`.
- Farm stays `x=2..4,y=7..9`; shop `(6,7)`; bed `(6,8)`; shipping `(6,10)`; shipping footprint `Rect2(6.2,10.2,0.6,0.6)`.
- Crops stay Turnip `3 / 20G / 35G`, Potato `5 / 40G / 75G`, Pumpkin `7 / 70G / 140G` for watered nights / seed price / sale value.
- Day starts at `06:00` (`360`), stamina `20`, cutoff `22:00` (`1320`), max day `14`, starting money `150G`, starter Turnip seeds `3`.
- Costs stay Hoe `30m/3`, Seeds `20m/1`, Water `20m/2`, Hands `20m/1`.
- Day 1 is sunny; later successful transitions use a 25% rain chance.
- Rain advances planted non-mature crops overnight; manual rainy-day watering returns `RAIN_WATERS_CROPS` without mutation.
- Shipping removes carried crops immediately; one successful sleep settles pending shipment exactly once before the blocking summary.
- Sleeping on Day 14 cannot consume RNG, settle shipping, or advance to Day 15.
- Public `GameSession` commands return `GameRules.CommandCode` directly. Do not add `ok`, `command_code_key`, generic result objects, or an unused `is_success()` classifier to that public command boundary.
- `GameSession.snapshot()` is a current read model for FarmView/HUD, not a save-schema design exercise.
- Player-facing controls use `InputMap`; no raw keycode switch in `WorldShell`.
- HUD modal state is the only input-gate source; Morning Summary modal state is derived from the session snapshot inside `GameHud.render`.
- Keep one `./tools/verify-clean.sh` entry point and one existing GitHub Actions Godot job.
- No C#, GDExtension, JavaScript/Tauri runtime, compatibility layer, persistence/schema work, villagers/social behavior, finale behavior, generic manager/service/event-bus/item-registry/command framework, GUT mocks/doubles, or unrelated shell refactor.

---

### Task 1: Fetch GUT via the verifier, freeze `GameRules`, and make CI run the unit suite immediately

(Amended 2026-08-23: GUT is verifier-fetched, not vendored; the addon left the git tree by owner decision.)

**Files:**
- Modify: `tools/verify-clean.sh` (pinned GUT fetch into its temp archive; `addons/gut/**` is never committed)
- Create: `scripts/game/game_rules.gd`
- Create: `tests/unit/test_game_rules.gd`
- Modify: `tools/verify-clean.sh`

**Interfaces:**
- Produces: `GameRules.CropKind`, `FarmingAction`, `Weather`, `CommandCode`
- Produces constants: `DAY_START_MINUTES`, `ACTION_CUTOFF_MINUTES`, `MAX_STAMINA`, `MAX_DAY`, `RAIN_CHANCE`, `STARTING_MONEY`
- Produces pure helpers: `starting_seed_counts`, `crop_key`, `crop_display_name`, `growth_nights`, `seed_price`, `sale_value`, `action_cost`, `visual_stage`, `is_mature`, `evaluate_action_budget`, `shipment_payout`, `weather_from_roll`, `format_time`
- Consumes no mutable game/world state

- [ ] **Step 1: Fetch exactly GUT 9.7.1 in the verifier**

Do not vendor `addons/gut/` into the git tree. Do not enable mocks/doubles or add another dependency manager. Instead, extend `tools/verify-clean.sh` so that, inside its temp archive, it downloads the tagged upstream tarball, validates the pinned sha256 checksum, and extracts only `addons/gut`:

```bash
mkdir -p addons/gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o gut.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  gut.tgz" \
  | shasum -a 256 -c -
tar -xzf gut.tgz --strip-components=3 -C addons/gut "Gut-9.7.1/addons/gut"
```

Run the existing clean verifier before adding tests:

```bash
./tools/verify-clean.sh
```

Expected: archive editor import and all three existing shell smokes pass with the fetched addon present. This proves the pinned fetch works from a clean archive; clean runs need network access.

- [ ] **Step 2: Keep the addon out of the git tree**

There is no standalone vendor commit: `addons/gut/**` stays untracked and the pinned verifier fetch above is the single GUT distribution path.

- [ ] **Step 3: Write RED frozen-rule tests**

Create `tests/unit/test_game_rules.gd`:

```gdscript
extends GutTest

func test_starter_and_day_constants_are_exact() -> void:
    assert_eq(GameRules.DAY_START_MINUTES, 360)
    assert_eq(GameRules.ACTION_CUTOFF_MINUTES, 1320)
    assert_eq(GameRules.MAX_STAMINA, 20)
    assert_eq(GameRules.MAX_DAY, 14)
    assert_eq(GameRules.STARTING_MONEY, 150)
    assert_eq(GameRules.starting_seed_counts(), [3, 0, 0])

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

Also assert any parallel crop arrays all have size `GameRules.CropKind.size()` so table-growth mistakes fail as a size contract rather than an accessor crash.

- [ ] **Step 4: Add RED budget/weather/payout tests**

`evaluate_action_budget` is a pure helper with a small internal discriminated shape because success must carry the next time/stamina while failure carries a `CommandCode`. This `ok` field is **not** the public `GameSession` command contract.

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

Also table-drive:

- all 3/5/7 maturity boundaries;
- all visual-stage boundaries;
- exact four action costs;
- `format_time(360) == "06:00"`;
- invalid weather rolls outside `[0.0,1.0)` assert;
- itemized payout order and exact total.

- [ ] **Step 5: Run the focused test and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_rules.gd -gexit
```

Expected: failure because `GameRules` is absent.

- [ ] **Step 6: Implement minimal `GameRules`**

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

static func starting_seed_counts() -> Array[int]:
    return [3, 0, 0]
```

Keep the crop definition data closed and immutable. Do not add `command_code_key` or `is_success`.

- [ ] **Step 7: Run rules tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 8: Put the GUT unit suite into the archive verifier now**

Modify `tools/verify-clean.sh` so the archive block becomes:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Run:

```bash
./tools/verify-clean.sh
```

Expected: GUT unit suite and all existing smokes pass from committed-tree content.

- [ ] **Step 9: Commit authored rules + verifier wiring**

```bash
git add scripts/game/game_rules.gd tests/unit/test_game_rules.gd tools/verify-clean.sh
git commit -m "test: freeze HPA-589 gameplay rules"
```

---

### Task 2: Add authoritative farm state and direct farming command codes

**Files:**
- Create: `scripts/game/game_session.gd`
- Create: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `GameRules`, `WorldContract.farm_cells()`
- Produces: `snapshot`, `select_action`, `select_seed`, `apply_selected_action`, `hoe`, `plant`, `water`, `harvest`
- Every public command returns `GameRules.CommandCode` directly

- [ ] **Step 1: Write RED starter-state/read-model tests**

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
    assert_eq(fresh["seeds"][&"turnip"], 3)
```

Also assert the nine farm entries are in `WorldContract.farm_cells()` row-major order and the snapshot contains no interaction cells, player/world position, node, focus, or panel fields.

- [ ] **Step 2: Write RED ordered guard/atomicity tests**

For every failure, capture `before := session.snapshot()` and assert the complete snapshot remains equal afterward.

Pin farming order:

`target → farm membership → command-specific state → time → stamina`.

Use direct enum assertions:

```gdscript
func test_turnip_actions_commit_atomically() -> void:
    var session := GameSession.new()
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    var snapshot := session.snapshot()
    assert_eq(snapshot["time_minutes"], 430)
    assert_eq(snapshot["stamina"], 14)
    assert_eq(snapshot["seeds"][&"turnip"], 2)
```

Cover `NO_TARGET`, `NOT_FARM_CELL`, `ALREADY_TILLED`, `SOIL_UNTILLED`, `CROP_PRESENT`, `NO_SELECTED_SEEDS`, `NO_CROP`, `CROP_MATURE`, `CROP_IMMATURE`, `ALREADY_WATERED`, `ACTION_TOO_LATE`, `INSUFFICIENT_STAMINA`, and `RAIN_WATERS_CROPS`.

Also prove:

- `select_action` returns `ACTION_SELECTED`;
- `select_seed` returns `SEED_SELECTED`;
- `apply_selected_action` routes only the four closed actions;
- harvest leaves tilled soil and increments carried crop.

- [ ] **Step 3: Run session tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

- [ ] **Step 4: Implement one mutable `GameSession`**

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
```

Initialize `_farm` from `WorldContract.farm_cells()` only. Validate a command fully before mutation; apply budget only after command-specific guards pass. Public commands return only the enum code.

- [ ] **Step 5: Run the archive verifier**

```bash
./tools/verify-clean.sh
```

Expected: rules + session GUT tests and all existing smokes pass.

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

- [ ] **Step 1: Add public-command-only test helper**

```gdscript
func _grow_and_harvest_turnip(session: GameSession, cell := Vector2i(2, 7)) -> void:
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    for _night in 3:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )
    assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
```

Use a deterministic sunny callable (`func() -> float: return 0.9`). Do not add production setters/test hooks.

- [ ] **Step 2: Write RED economy tests**

Pin:

- `buy_seeds`: active-day → shop target → positive quantity → funds;
- `deposit_crop`: active-day → shipping target → positive quantity → carried crop;
- exact success codes `SEEDS_PURCHASED` / `CROP_DEPOSITED`;
- `NOT_AT_SHOP`, `NOT_AT_SHIPPING_BIN`, `INVALID_QUANTITY`, `INSUFFICIENT_FUNDS`, `INSUFFICIENT_CROPS` rollback;
- immediate carried-crop removal on deposit.

- [ ] **Step 3: Write RED overnight/summary tests**

Prove independently:

- watered sunny crop advances once;
- unwatered sunny crop does not advance;
- rainy completed day advances each planted non-mature crop;
- surviving `watered_today` resets;
- next weather uses `<0.25` rainy / `>=0.25` sunny;
- shipping credits exact itemized payout once and clears pending before summary;
- pending summary makes selection, farming, buy, deposit, and sleep return `DAY_SUMMARY_PENDING` with no mutation;
- acknowledgment returns `DAY_STARTED`; duplicate acknowledgment returns `NO_DAY_SUMMARY` and cannot pay/advance.

- [ ] **Step 4: Pin Day-14 no-RNG/no-settlement behavior**

Using public commands only:

1. Grow/harvest one Turnip early and keep it carried.
2. Sleep/acknowledge until Day 14 using a counting weather callable.
3. Deposit the carried Turnip on Day 14.
4. Capture snapshot + callable invocation count.
5. Call `sleep(WorldContract.BED_CELL)`.
6. Assert `DAY_LIMIT_REACHED`, exact snapshot equality, pending shipment still contains the Turnip, and callable count is unchanged.

- [ ] **Step 5: Add one public-command-only full loop**

Prove:

`buy Potato seed → hoe → plant → water/sleep until mature → harvest → deposit → sleep/payout → acknowledge → buy Potato again from increased money`.

Do not set money, growth, day, inventory, or shipment directly.

- [ ] **Step 6: Implement exactly three expected sleep gates**

The command validation path is only:

```text
active-day
bed target
_day < GameRules.MAX_DAY
```

After those pass, call `weather_from_roll` and `shipment_payout`. Invalid random values or impossible internal payout data are programmer/invariant errors and assert; do not invent command codes for them.

Then commit atomically:

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

- [ ] **Step 7: Run the archive verifier**

```bash
./tools/verify-clean.sh
```

- [ ] **Step 8: Commit**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore Godot day and crop economy rules"
```

---

### Task 4: Add soil/crop/shipping presentation without breaking the shell contracts

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/player/player_controller.gd`
- Create: `scripts/world/farm_view.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_math_smoke.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Create: `tests/integration/test_gameplay_shell.gd`
- Modify: `tools/verify-clean.sh`

**Interfaces:**
- Produces: `WorldContract.SHOP_CELL`, `BED_CELL`, `SHIPPING_CELL`, `SHIPPING_FOOTPRINT`
- Produces: `PlayerController.set_input_enabled(enabled: bool)`, `current_target_cell() -> Variant`
- Produces: `FarmView.refresh(snapshot: Dictionary)` on the existing `Entities` node
- Adds: root `FarmSoil` below TargetHighlight and nine crop roots directly under `Entities`
- Preserves exactly one Y-sort-enabled `CanvasItem`

- [ ] **Step 1: Extend `world_math_smoke.gd` RED contract assertions**

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

Run and verify RED:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
```

- [ ] **Step 2: Add only the four interaction constants**

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Run `world_math_smoke.gd` again and verify GREEN.

- [ ] **Step 3: Write RED GUT composition tests using the real scene**

Create `tests/integration/test_gameplay_shell.gd` extending `GutTest`.

Use the real `world.tscn`:

```gdscript
extends GutTest

func _world() -> WorldShell:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    assert_not_null(packed)
    var world := packed.instantiate() as WorldShell
    add_child_autoqfree(world)
    return world
```

Add separate tests rather than one giant first-failure script. Pin:

- `FarmSoil` exists, `y_sort_enabled == false`, `z_index == 5`;
- nine soil sprites are centered at `grid_to_world(cell + 0.5)`;
- `Entities` is `FarmView`, remains Y-sort enabled, and no second CanvasItem enables Y-sort;
- nine crop roots are direct `Entities` children at the same cell centers;
- `set_input_enabled(false)` zeros/stops player movement;
- `current_target_cell()` matches `WorldMath.target_cell`.

- [ ] **Step 4: Add `FarmSoil` as ground presentation**

Add root sibling:

```text
World
├─ Ground                 z=0
├─ FarmSoil               z=5, y_sort=false
├─ StaticCollision
├─ Entities               z=20, y_sort=true
└─ TargetHighlight        z=10
```

`FarmSoil` owns nine soil Sprite2Ds. Each uses `proof-soil.png`, `hframes = 2`, at:

```gdscript
WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

Do not put soil under crop/Y-sort roots.

- [ ] **Step 5: Attach `FarmView` to `Entities` and create crop roots only**

Attach `scripts/world/farm_view.gd` directly to `Entities`.

On `_ready()`, keep a reference to sibling `../FarmSoil` and create one direct crop root per farm cell:

```gdscript
func _crop_name(cell: Vector2i) -> StringName:
    return StringName("FarmCrop_%d_%d" % [cell.x, cell.y])

func _ready() -> void:
    _farm_soil = get_node("../FarmSoil") as Node2D
    for cell in WorldContract.farm_cells():
        var crop_root := Node2D.new()
        crop_root.name = _crop_name(cell)
        crop_root.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
        add_child(crop_root)
```

Each crop root owns one crop Sprite2D: `proof-crops.png`, `hframes = 4`, `vframes = 3`, `offset = Vector2(0, -24)`.

`refresh(snapshot)` drives both sibling soil sprites and crop sprites. Do not store gameplay state in node metadata.

- [ ] **Step 6: Add Shipping as an `Entities` sibling and collision sibling**

In `world.tscn`:

- `Shipping` follows Building as a direct `Entities` child;
- position = cell center of `SHIPPING_CELL`;
- sprite = `proof-scenery.png`, `hframes = 3`, `frame = 2`, `offset = Vector2(0, -48)`;
- `ShippingCollision` is a direct `StaticCollision` child.

Extend `WorldShell._ready()`:

```gdscript
var shipping_collision := static_collision.get_node("ShippingCollision") as CollisionPolygon2D
shipping_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)
```

- [ ] **Step 7: Update both exact-name and exact-order shell assertions in the same change**

Update the world root expectation from:

```gdscript
["Ground", "StaticCollision", "Entities", "TargetHighlight"]
```

to:

```gdscript
["Ground", "FarmSoil", "StaticCollision", "Entities", "TargetHighlight"]
```

`StaticCollision` expected names/order become:

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

Build one exact `Entities` list and use it for **both** `_expect_names` and `_expect_child_order`:

```gdscript
var entity_names := ["Player", "Tree", "Building", "Shipping"]
for cell in WorldContract.farm_cells():
    entity_names.append("FarmCrop_%d_%d" % [cell.x, cell.y])
```

Keep and extend:

- exactly one enabled Y-sort node and it is `Entities`;
- Player/Tree/Building/Shipping/crop roots share entity z-index;
- `Ground.z_index < FarmSoil.z_index < TargetHighlight.z_index < Entities.z_index`;
- shipping frame/offset/center anchor exact;
- each soil/crop root uses the cell-center helper;
- existing tree/building exact-Y ordering tests unchanged.

- [ ] **Step 8: Put the new GUT integration suite into CI now**

Change the GUT line in `tools/verify-clean.sh` to:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Leave the three existing SceneTree smoke commands after it.

- [ ] **Step 9: Run the complete archive verifier**

```bash
./tools/verify-clean.sh
```

Expected: unit GUT, integration GUT, project smoke, world-math smoke, and world-shell smoke all pass.

- [ ] **Step 10: Commit**

```bash
git add scripts/world/world_contract.gd scripts/player/player_controller.gd \
  scripts/world/farm_view.gd scripts/world/world_shell.gd scenes/world/world.tscn \
  tests/headless/world_math_smoke.gd tests/headless/world_shell_smoke.gd \
  tests/integration/test_gameplay_shell.gd tools/verify-clean.sh
git commit -m "feat: add Godot farm and economy world adapters"
```

---

### Task 5: Add InputMap controls, contextual HUD, and one immediate modal gate

**Files:**
- Modify: `project.godot`
- Create: `scripts/ui/game_hud.gd`
- Create: `scenes/ui/game_hud.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- InputMap actions: `select_hoe`, `select_seeds`, `select_water`, `select_hands`, `use_action`, `interact`
- `GameHud`: `render(snapshot)`, `has_blocking_modal`, `set_interaction_hint`, panel open methods, `show_feedback(code)`
- HUD signals: action/seed selection, buy, deposit, sleep confirm, summary acknowledge, modal-state change
- `WorldShell` is the only production holder of `GameSession`

- [ ] **Step 1: Add RED InputMap assertions to `world_shell_smoke.gd`**

Extend the existing key table with physical keys 49/50/51/52, Space 32, E 69 for:

```text
select_hoe
select_seeds
select_water
select_hands
use_action
interact
```

Run `world_shell_smoke.gd`; expected RED until `project.godot` changes.

- [ ] **Step 2: Add the six InputMap actions**

Map the physical keys above. Keep WASD untouched. Run `world_shell_smoke.gd` again before HUD work.

- [ ] **Step 3: Extend the GUT integration suite with RED modal/routing tests**

Add separate tests proving:

- shop/bed/shipping target opens only its panel;
- off-target interact shows `NOTHING_TO_INTERACT` without session mutation;
- opening Shop immediately disables movement + world command routing **before any buy command**;
- closing Shop restores input without requiring a session refresh;
- same immediate gate behavior for Shipping/Sleep;
- successful sleep causes `GameHud.render(snapshot)` to open Morning Summary;
- acknowledgment clears summary and restores input;
- blocked routing leaves the session snapshot unchanged;
- Day-14 Shipping/Sleep boundary copy is visible.

- [ ] **Step 4: Build one consolidated `GameHud`**

Always visible:

- day/time/weather/stamina/money;
- four farming actions;
- selected seed + three seed counts;
- three harvested counts;
- pending shipment total;
- contextual target hint;
- concise feedback.

Mutually exclusive panels:

- Seed Shop;
- Shipping;
- Sleep Confirmation;
- Morning Summary.

Expose:

```gdscript
signal select_action_requested(action: int)
signal select_seed_requested(kind: int)
signal buy_requested(kind: int, quantity: int)
signal deposit_requested(kind: int, quantity: int)
signal sleep_requested
signal morning_summary_acknowledged
signal modal_state_changed
```

`show_feedback(code: GameRules.CommandCode)` is one exhaustive enum match. There is no string-code mapper.

`render(snapshot)` derives Morning Summary modal visibility directly:

```gdscript
var summary: Variant = snapshot["pending_morning_summary"]
_set_morning_summary_visible(summary != null)
```

Do not maintain a competing summary-open flag.

On Day 14:

- Shipping panel shows that pending crops will not settle at the current boundary;
- Sleep panel shows that sleeping cannot advance/pay shipping;
- `DAY_LIMIT_REACHED` is rendered inline in the Sleep panel when returned.

- [ ] **Step 5: Add contextual interaction hint without new art**

`WorldShell` updates one cheap hint from the current target:

```gdscript
func _process(_delta: float) -> void:
    var target: Variant = player.current_target_cell()
    if target == WorldContract.SHOP_CELL:
        hud.set_interaction_hint("Shop — E")
    elif target == WorldContract.BED_CELL:
        hud.set_interaction_hint("Bed — E")
    elif target == WorldContract.SHIPPING_CELL:
        hud.set_interaction_hint("Shipping — E")
    else:
        hud.set_interaction_hint("")
```

This is presentation only. Do not write the target cell into `GameSession.snapshot()`.

- [ ] **Step 6: Add `GameHud` as a root sibling and update exact root order**

Instance `GameHud` under `World` after TargetHighlight.

Root expectation becomes:

```gdscript
[
    "Ground",
    "FarmSoil",
    "StaticCollision",
    "Entities",
    "TargetHighlight",
    "GameHud",
]
```

Keep the one-Y-sort assertion unchanged.

- [ ] **Step 7: Construct one session and refresh one snapshot**

```gdscript
var _session := GameSession.new()
var _world_input_enabled := true

@onready var player := $Entities/Player as PlayerController
@onready var farm_view := $Entities as FarmView
@onready var hud := $GameHud as GameHud

func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate()

func _refresh_world_input_gate() -> void:
    _world_input_enabled = not hud.has_blocking_modal()
    player.set_input_enabled(_world_input_enabled)
```

After every session command, pass its direct `CommandCode` to `hud.show_feedback(code)` and refresh from one fresh snapshot. Do not call `snapshot()` merely to recalculate the gate.

- [ ] **Step 8: Connect modal-state changes directly to the no-argument gate refresh**

In `_ready()`:

```gdscript
hud.modal_state_changed.connect(_refresh_world_input_gate)
```

Opening/closing Shop/Shipping/Sleep must emit `modal_state_changed`. `GameHud.render` must emit it only when derived Morning Summary visibility actually changes.

This connection is what prevents walking behind a just-opened Shop before the first purchase.

- [ ] **Step 9: Add production routing helpers and sample InputMap names**

Expose helpers shared by `_unhandled_input` and integration tests:

```gdscript
func select_action_slot(slot: int) -> void
func use_selected_action() -> void
func interact() -> void
```

All return immediately when `_world_input_enabled` is false.

`_unhandled_input(event)` samples only named actions. `interact()` re-reads `player.current_target_cell()` each time:

- Shop → open Shop;
- Shipping → open Shipping;
- Bed → open Sleep;
- else → show `NOTHING_TO_INTERACT`.

Buy/deposit/sleep-confirm handlers re-read target and call `GameSession`; an open panel is never authorization.

- [ ] **Step 10: Run the archive verifier**

```bash
./tools/verify-clean.sh
```

Expected: all rules/session/integration tests and existing smokes pass.

- [ ] **Step 11: Perform one bounded normal-control proof**

```bash
godot --path .
```

Using only normal controls/UI:

1. complete `buy → hoe → plant → water → sleep/grow → harvest → ship → payout → buy again`;
2. confirm target hints identify Shop/Bed/Shipping;
3. open a modal and confirm movement + Space/E/1–4 stop immediately;
4. close it and confirm input resumes.

Do **not** manually play fourteen days; Task 3 owns Day-14 proof.

- [ ] **Step 12: Commit**

```bash
git add project.godot scripts/ui/game_hud.gd scenes/ui/game_hud.tscn \
  scripts/world/world_shell.gd scenes/world/world.tscn \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: wire the Godot farming gameplay loop"
```

---

### Task 6: Update handoff docs and run final verification

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `AGENTS.md` symlink
- Verify only: `tools/verify-clean.sh`
- Verify only: `.github/workflows/ci.yml`

**Interfaces:**
- `./tools/verify-clean.sh` is already complete before this task; Task 6 does not add delayed test commands
- `AGENTS.md` remains a symlink to `CLAUDE.md`; do not write duplicate handoff content

- [ ] **Step 1: Update README behavior/controls**

Document:

- `1/2/3/4`, Space, E;
- Shop/Shipping/Sleep/Morning Summary behavior;
- target hints;
- complete farming/economy loop;
- Day-14 temporary boundary;
- HPA-589 as gameplay authority;
- HPA-594 as next social slice.

Keep exhaustive balance/code tables in tests/spec instead of duplicating them all in README.

- [ ] **Step 2: Update `CLAUDE.md` ownership/handoff**

Record:

- `GameRules`: closed rules/content/enum codes;
- `GameSession`: only mutable gameplay authority;
- `FarmSoil`: non-Y-sorted ground decals;
- `Entities`/`FarmView`: one Y-sort owner + crop snapshot rendering;
- `GameHud`: presentation/modal state only;
- `WorldShell`: only production session holder + coordinator;
- `PlayerController`: movement/facing/targeting only.

Document final verifier order:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Do not edit `AGENTS.md` separately; it is the symlink to `CLAUDE.md`.

- [ ] **Step 3: Commit docs**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document the HPA-589 gameplay port"
```

- [ ] **Step 4: Run fresh final committed-state verification**

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
git diff --name-only main...HEAD
test "$(readlink AGENTS.md)" = "CLAUDE.md"
```

Expected:

- archive editor import exits 0;
- all GUT unit/integration tests pass;
- project/world-math/world-shell smokes pass;
- no whitespace errors;
- clean status;
- symlink intact;
- only HPA-589 gameplay/test/docs/vendor files.

- [ ] **Step 5: Verify CI shape without redesigning it**

Inspect `.github/workflows/ci.yml`. It must still pin Godot `4.7.1`, `use-dotnet: false`, and call only `./tools/verify-clean.sh` after `godot --version`.

- [ ] **Step 6: Keep PR #7 draft until implementation verification is green**

Continue implementation on this same branch/PR. Mark it ready only after the fresh clean verifier and bounded normal-control proof pass.