# Phoenix Godot Gameplay Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's complete farming, daily-rhythm, and three-crop economy loop in Godot while keeping one authoritative gameplay state and the HPA-590 world shell intact.

**Architecture:** Add one pure `GameRules` helper and one mutable `GameSession` authority. Keep `WorldShell` as the thin runtime coordinator, `PlayerController` as movement/facing/targeting only, `FarmView` as snapshot rendering only, and one consolidated `GameHud` for presentation and modal state. Extend the current scene and clean verifier rather than adding managers, services, a second runtime, or another CI path.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing headless smoke scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-22-phoenix-godot-gameplay-port-design.md`

## Global Constraints

- Deliver HPA-589 in this same PR; do not open a second implementation PR.
- Preserve every HPA-590 map/projection/spawn/movement/camera/tree/building value.
- Farm stays `x=2..4,y=7..9`; shop `(6,7)`; bed `(6,8)`; shipping `(6,10)`; shipping footprint `Rect2(6.2,10.2,0.6,0.6)`.
- Crops stay Turnip `3 / 20G / 35G`, Potato `5 / 40G / 75G`, Pumpkin `7 / 70G / 140G` for watered nights / seed price / sale value.
- Day starts at `06:00` (`360`), stamina `20`, cutoff `22:00` (`1320`); an action ending exactly at 22:00 succeeds.
- Costs stay Hoe `30m/3`, Seeds `20m/1`, Water `20m/2`, Hands `20m/1`.
- Day 1 is sunny; later successful transitions use a 25% rain chance.
- Rain advances planted crops overnight; manual rainy-day watering is rejected without mutation.
- Shipping removes carried crops immediately; one successful sleep settles the pending shipment exactly once before the blocking morning summary.
- Day 14 remains playable; sleeping on Day 14 cannot consume RNG, settle shipping, or advance to Day 15.
- Gameplay snapshots exclude player/world position, camera/rendering nodes, fixed interaction coordinates, UI state, and the weather callable.
- Keep one `./tools/verify-clean.sh` entry point and the existing single GitHub Actions Godot job.
- No C#, GDExtension, JavaScript/Tauri runtime, compatibility layer, persistence, villagers/social behavior, finale behavior, generic manager/service/event-bus/item-registry/command framework, or unrelated shell refactor.

---

### Task 1: Pin GUT and freeze the closed gameplay rules

**Files:**
- Vendor: `addons/gut/**` from GUT `v9.7.1`
- Create: `scripts/game/game_rules.gd`
- Create: `tests/unit/test_game_rules.gd`

**Interfaces:**
- Produces closed enums: `CropKind`, `FarmingAction`, `Weather`
- Produces stable crop/action/weather keys and exact constants
- Produces pure helpers: `crop_key`, `crop_display_name`, `growth_nights`, `seed_price`, `sale_value`, `action_cost`, `visual_stage`, `is_mature`, `evaluate_action_budget`, `shipment_payout`, `weather_from_roll`, `format_time`

- [ ] **Step 1: Vendor exactly GUT 9.7.1 under `addons/gut/`**

Keep upstream addon files committed so clean verification downloads nothing. Verify the runner itself:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected before tests exist: GUT starts successfully and reports no tests, not a missing runner/plugin error.

- [ ] **Step 2: Write RED rules tests with exact tables and boundaries**

Create `tests/unit/test_game_rules.gd` extending `GutTest`. Include these exact assertions:

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
    assert_eq(GameRules.weather_from_roll(0.249999), GameRules.Weather.RAINY)
    assert_eq(GameRules.weather_from_roll(0.25), GameRules.Weather.SUNNY)
```

Also table-drive all 3/5/7 maturity and visual-stage boundaries, exact four action costs, `format_time(360) == "06:00"`, invalid weather rolls outside `[0.0,1.0)`, and itemized payout order/total for `2 Turnip + 1 Potato + 1 Pumpkin == 285G`.

- [ ] **Step 3: Run focused tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

Expected: failures because `GameRules` does not exist.

- [ ] **Step 4: Implement the minimal pure helper**

Use one `RefCounted` with closed arrays, not Resources or registries:

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

static func visual_stage(kind: int, progress: int) -> int:
    return mini(3, int(floor(float(progress * 3) / float(growth_nights(kind)))))

static func is_mature(kind: int, progress: int) -> bool:
    return progress >= growth_nights(kind)
```

`evaluate_action_budget` checks time before stamina. `shipment_payout` iterates enum order for deterministic summary lines. Invalid enum indices/rolls are programmer errors and may assert.

- [ ] **Step 5: Run rules tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_rules.gd -gexit
```

- [ ] **Step 6: Commit**

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
- Every command returns a fresh `{"ok": bool, "code": StringName}`

- [ ] **Step 1: Write RED starter-state and deep-copy tests**

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

- [ ] **Step 2: Write RED farming guard/atomicity tests**

For every failure, compare the complete snapshot before/after. Pin validation order:

`target -> farm membership -> command-specific state -> time -> stamina`.

Cover null/outside targets, already-tilled, crop-present, soil-untilled, no-selected-seeds, no-crop, crop-mature, crop-immature, already-watered, rainy watering, too-late, and too-tired. Pin one exact success chain:

```gdscript
func test_turnip_actions_commit_atomically() -> void:
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

Also prove selected action/seed changes, `apply_selected_action`, and harvest leaves tilled soil while incrementing harvested inventory.

- [ ] **Step 3: Run and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

- [ ] **Step 4: Implement one mutable `GameSession`**

Use closed arrays/dictionaries; do not introduce farm/entity classes or a generic state framework:

```gdscript
class_name GameSession
extends RefCounted

var _day: int = 1
var _time_minutes: int = GameRules.DAY_START_MINUTES
var _stamina: int = GameRules.MAX_STAMINA
var _weather: int = GameRules.Weather.SUNNY
var _selected_action: int = GameRules.FarmingAction.HOE
var _selected_seed: int = GameRules.CropKind.TURNIP
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
        _farm.append({"cell": cell, "tilled": false, "crop": null})
```

Validate an entire command before mutation; apply budget only after command-specific guards pass. `snapshot()` converts closed counts to stable-key dictionaries and deep-copies all nested arrays/dictionaries.

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

- [ ] **Step 1: Add public-command test helpers, then write RED economy tests**

Do not add production test hooks. Build harvested crops through public commands only:

```gdscript
func _grow_and_harvest_turnip(session: GameSession, cell := Vector2i(2, 7)) -> void:
    assert_true(session.hoe(cell)["ok"])
    assert_true(session.plant(cell)["ok"])
    for night in 3:
        assert_true(session.water(cell)["ok"])
        assert_true(session.sleep(WorldContract.BED_CELL)["ok"])
        assert_true(session.acknowledge_morning_summary()["ok"])
    assert_true(session.harvest(cell)["ok"])
```

Use a sunny callable (`func() -> float: return 0.9`) so this helper is deterministic. Then pin shop/shipping validation order, quantity `<=0`, insufficient funds/crop rollback, exact-cost purchases, and immediate carried-crop removal on deposit.

- [ ] **Step 2: Write RED overnight transaction tests**

Pin all of these independently:

- watered sunny crop advances once;
- unwatered sunny crop does not advance;
- rainy completed day advances every planted crop;
- surviving `watered_today` resets;
- next weather uses `<0.25` rainy / `>=0.25` sunny;
- pending shipping credits exact itemized payout once and clears before summary;
- summary blocks `select_action`, `select_seed`, farming, buy, deposit, and sleep with `day-summary-pending` and no mutation;
- duplicate acknowledgment cannot pay or advance;
- Day 14 sleep returns `day-limit-reached`, preserves pending shipment, and does not invoke the weather callable.

For RNG consumption, inject a counting callable and assert the count does not change on the rejected Day-14 sleep.

- [ ] **Step 3: Add one public-command-only full loop test**

Using only public methods, prove:

`buy non-starter seed -> hoe -> plant -> water -> sleep/grow -> harvest -> deposit -> sleep/payout -> acknowledge -> buy again from increased money`.

This is the direct acceptance journey; do not shortcut state.

- [ ] **Step 4: Run and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_session.gd -gexit
```

- [ ] **Step 5: Implement the shared active-day gate and atomic day transition**

Add one helper that returns `day-summary-pending` when the summary exists. Call it first from selection, farming, buying, depositing, and sleep.

`buy_seeds` validates `active-day -> shop target -> positive quantity -> funds`.

`deposit_crop` validates `active-day -> shipping target -> positive quantity -> carried count`.

`sleep` validates `active-day -> bed target -> day < 14` before calling RNG. Build next weather/payout before mutation, then commit exactly:

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

Summary data contains completed/next day, crops advanced, next weather key, restored stamina, deterministic shipping lines, shipping income, and money after shipping. `acknowledge_morning_summary` only clears that value.

- [ ] **Step 6: Run all GUT tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 7: Commit**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore Godot day and crop economy rules"
```

---

### Task 4: Add authored interaction cells, player gating, farm rendering, and shipping composition

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scripts/player/player_controller.gd`
- Create: `scripts/world/farm_view.gd`
- Modify: `scenes/world/world.tscn`
- Create: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- Produces: `WorldContract.SHOP_CELL`, `BED_CELL`, `SHIPPING_CELL`, `SHIPPING_FOOTPRINT`
- Produces: `PlayerController.set_input_enabled(enabled: bool)`, `current_target_cell() -> Variant`
- Produces: `FarmView.refresh(snapshot: Dictionary)`

- [ ] **Step 1: Write RED real-scene geometry/composition assertions**

Load `res://scenes/world/world.tscn`. Assert exact interaction cells, nine farm roots at `WorldMath.grid_to_world(cell)`, shipping collision derived from `WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)`, and a shipping sprite using frame 2 of `proof-scenery.png`. Reuse production projection helpers in assertions.

- [ ] **Step 2: Write RED player-gate assertions**

Call `set_input_enabled(false)` on the real player and prove velocity becomes zero immediately and movement stays disabled until re-enabled. Assert `current_target_cell()` matches the existing highlight calculation, including `null` at map edges.

- [ ] **Step 3: Add only the four HPA-589 world constants**

```gdscript
const SHOP_CELL := Vector2i(6, 7)
const BED_CELL := Vector2i(6, 8)
const SHIPPING_CELL := Vector2i(6, 10)
const SHIPPING_FOOTPRINT := Rect2(6.2, 10.2, 0.6, 0.6)
```

Do not alter existing HPA-590 constants.

- [ ] **Step 4: Add the player input flag without duplicating target state**

`set_input_enabled(false)` sets `velocity = Vector2.ZERO`; `_physics_process` skips movement sampling while disabled. `current_target_cell()` recomputes from current position/facing through `WorldMath.target_cell`; `_update_target()` calls the same method.

- [ ] **Step 5: Implement `FarmView` as presentation only**

Reconcile exactly nine authored plot roots. Use committed soil/crop sheets and `WorldMath.grid_to_world`:

```text
untilled -> no soil/crop sprite
tilled + sunny dry -> dry soil frame
tilled + watered or rainy -> wet soil frame
crop frame -> int(kind) * 4 + GameRules.visual_stage(kind, growth)
```

Use bottom-center logical contact within the existing Y-sorted presentation hierarchy; do not store frame indices or gameplay state in nodes.

- [ ] **Step 6: Add shipping sprite/collision to the existing scene**

Reuse frame 2 of `assets/sprites/proof-scenery.png`, anchor at logical center `(6.5,10.5)`, and add `ShippingCollision` under the existing `StaticCollision`. Extend `WorldShell` collision setup to derive the shipping polygon; do not move tree/building/player nodes.

- [ ] **Step 7: Run smokes and verify GREEN**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

The existing shell smoke must stay green.

- [ ] **Step 8: Commit**

```bash
git add scripts/world/world_contract.gd scripts/player/player_controller.gd scripts/world/farm_view.gd scenes/world/world.tscn tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: add Godot farm and economy world adapters"
```

---

### Task 5: Add one HUD and wire `WorldShell` as the runtime coordinator

**Files:**
- Create: `scripts/ui/game_hud.gd`
- Create: `scenes/ui/game_hud.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/gameplay_shell_smoke.gd`

**Interfaces:**
- Produces: `GameHud.render(snapshot)`, `has_blocking_modal`, `show_feedback`, and open/close methods for Shop, Shipping, Sleep, Morning Summary
- HUD emits explicit intentions for action/seed selection, buy, deposit, sleep confirmation, summary acknowledgment, and panel close
- `WorldShell` is the only production holder of `GameSession`

- [ ] **Step 1: Extend the real-scene smoke with RED routing/input-lock assertions**

Call production coordinator helpers directly, not synthetic OS events. Prove:

- shop/bed/shipping target opens only its panel;
- any modal makes `has_blocking_modal()` true;
- that same state disables player movement and `WorldShell` action/interact routing;
- blocked routing leaves the session snapshot unchanged;
- closing Shop/Shipping/Sleep restores input when no summary exists;
- Morning Summary stays blocking until successful acknowledgment.

- [ ] **Step 2: Build one consolidated `GameHud` scene**

Use one `CanvasLayer` + `Control` tree. Always-visible presentation: day/time/weather/stamina/money, four action controls, selected seed + three seed counts, three harvested counts, pending shipment total, and interaction hint.

Use four mutually exclusive panel containers: Seed Shop, Shipping, Sleep Confirmation, Morning Summary. Shop/Shipping each expose three crop rows, one `SpinBox`, one `Max` control, and one explicit Buy/Deposit action. Quantity/row/focus/panel state stays UI-only. Escape closes Shop/Shipping/Sleep; Morning Summary closes only after accepted Start Day.

- [ ] **Step 3: Construct one session and refresh from snapshots**

`WorldShell._ready()` constructs the session, connects HUD intentions, completes collision setup, then refreshes:

```gdscript
func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate(snapshot)
```

After every session command, map its stable `code` to HUD feedback and refresh from a fresh snapshot. Keep no gameplay copy in `WorldShell`.

- [ ] **Step 4: Add explicit production routing helpers**

Use three direct helpers shared by `_unhandled_input` and smoke tests:

```gdscript
func select_action_slot(slot: int) -> void
func use_selected_action() -> void
func interact() -> void
```

Map `1/2/3/4` to action slots, Space to selected farm action, E to interaction. `interact()` reads the player's current target each time: shop opens Shop, shipping opens Shipping, bed opens Sleep, otherwise `nothing-to-interact` feedback. Buy/deposit/sleep confirmation handlers re-read the target and pass it to `GameSession`; opening a panel is not authorization.

- [ ] **Step 5: Use one derived world-input gate for both movement and commands**

```gdscript
var world_input_enabled := (
    not hud.has_blocking_modal()
    and snapshot["pending_morning_summary"] == null
)
```

Apply the same boolean to `player.set_input_enabled(...)` and to `WorldShell`'s `1/2/3/4`, Space, E routing. Do not add separate movement/action/modal lock flags. Summary acknowledgment comes through its HUD signal, not world input.

- [ ] **Step 6: Run unit and composition suites**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

- [ ] **Step 7: Perform one normal-control journey**

```bash
godot --path .
```

Using only normal controls/UI, complete `buy -> hoe -> plant -> water -> sleep/grow -> harvest -> ship -> payout -> buy again`. Confirm modals block both movement and world actions, rainy watering is free/rejected, Morning Summary blocks until Start Day, and Day 14 cannot advance.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/game_hud.gd scenes/ui/game_hud.tscn scripts/world/world_shell.gd scenes/world/world.tscn tests/headless/gameplay_shell_smoke.gd
git commit -m "feat: wire the Godot farming gameplay loop"
```

---

### Task 6: Extend the one verifier and update the handoff docs

**Files:**
- Modify: `tools/verify-clean.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `.github/workflows/ci.yml`

**Interfaces:**
- `./tools/verify-clean.sh` remains the only clean-checkout verification entry point
- README/CLAUDE describe HPA-589 ownership and controls without becoming a second balance table

- [ ] **Step 1: Extend the current archive verifier in place**

Keep archive-first behavior and run exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . --script res://tests/headless/gameplay_shell_smoke.gd
```

Do not add a second verification script or Actions job.

- [ ] **Step 2: Update README behavior/controls**

Document `1/2/3/4`, Space, E, Shop/Shipping/Sleep/Morning Summary, and the complete farming/economy loop. State that HPA-589 now owns gameplay authority and HPA-594 is the next social slice. Keep exhaustive exact values in tests/spec rather than duplicating every table in README.

- [ ] **Step 3: Update `CLAUDE.md` architecture and verification handoff**

Record these ownership rules:

- `GameRules`: closed pure rules/content;
- `GameSession`: only mutable gameplay-rules authority;
- `FarmView`: snapshot rendering only;
- `GameHud`: presentation/modal state only;
- `WorldShell`: only production session holder + coordinator;
- `PlayerController`: movement/facing/targeting only.

Replace the HPA-590-only verifier list with the six commands above. Keep persistence/social/finale explicitly outside current scope.

- [ ] **Step 4: Commit docs/verifier, then run committed-state verification**

```bash
git add tools/verify-clean.sh README.md CLAUDE.md
git commit -m "docs: document and verify the HPA-589 gameplay port"
./tools/verify-clean.sh
```

Expected: archive import, all GUT tests, project smoke, world-math smoke, existing world-shell smoke, and gameplay-shell smoke pass.

- [ ] **Step 5: Run final repository checks**

```bash
git diff --check main...HEAD
git status --short
git diff --name-only main...HEAD
```

Expected: no whitespace errors, clean status, and only HPA-589 gameplay/test/docs/vendor files. Confirm no persistence/social/finale implementation, JavaScript/Tauri runtime, generic framework, or unrelated cleanup entered the PR.

- [ ] **Step 6: Verify CI shape without redesigning it**

Inspect `.github/workflows/ci.yml`: it must still pin Godot `4.7.1`, `use-dotnet: false`, and call only `./tools/verify-clean.sh` after `godot --version`. Leave it unchanged unless that existing contract has broken.

- [ ] **Step 7: Keep PR #7 draft until the full matrix is green**

Continue implementation on this branch/PR. Mark it ready only after the clean verifier, manual normal-control journey, Day-14 boundary, and scope checks all pass.
