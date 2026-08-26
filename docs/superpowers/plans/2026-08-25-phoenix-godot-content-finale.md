# Phoenix Godot Content and Harvest Finale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Godot farming/economy/social/persistence shell into a self-explanatory 14-day MVP with contextual onboarding, one authored harvest-market finale, deterministic result tiers, and completed-save Continue.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the direct world/save coordinator. Add one pure `ContentRules` sibling for tutorial copy/eligibility and terminal result derivation; persist four content facts directly in `GameSession.state()` and `snapshot()`; share one shipment-settlement helper between normal sleep and finale; add one focused onboarding `Control`; author one market entity in the existing world; and add one presentation-only `ResultScreen` sibling under `AppRoot`. The Day 14 bed return-code flip lands only in the same task that teaches the live shell/application to consume it. `SaveFileCodec` remains semantic-field-blind schema-v1 transport.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, Godot `Control` UI, existing sprite-isometric `TileMapLayer`/Y-sort world, GUT 9.7.1, existing headless SceneTree smokes, FileAccess JSON autosave.

**Spec:** `docs/superpowers/specs/2026-08-25-phoenix-godot-content-finale-design.md`

**Behavior oracle:** Linear HPA-597 plus product decisions retained from the superseded Phaser/Svelte HPA-597 plan. The old implementation shape is not authoritative.

## Global Constraints

- Deliver implementation on this same HPA-597 branch/PR after plan review. Do not open a second implementation PR.
- Keep one runtime, one `GameSession`, one `SaveRepository`, one authored world, and one save file.
- Keep `SaveFileCodec.SCHEMA_VERSION == 1`; older development saves missing HPA-597 fields are intentionally incompatible. No migration.
- Preserve current starter money/seeds, crop growth/sale values, weather, action costs, and relationship thresholds. HPA-599 owns balance tuning.
- Add one pure `ContentRules` module only. No tutorial/quest/cutscene/event/scoring framework.
- Persist exactly `intro_acknowledged`, exact tutorial flags, lifetime shipped crop counts, and `finale_triggered`.
- Copy those four keys explicitly in both `GameSession.state()` and the current hand-built `snapshot()` dictionary.
- `ContentRules.build_harvest_result()` consumes canonical `state()` and derives relationship levels from raw persisted `points`; do not depend on snapshot-only `level`.
- Complete tutorial steps only after successful authoritative commands. Dismissal is transient UI state.
- Normal sleep and finale share one shipment-settlement helper. Market and Day 14 sleep ultimately share one `_complete_finale()` helper.
- **Do not change Day 14 `sleep()` from `DAY_LIMIT_REACHED` to `FINALE_TRIGGERED` until Task 4**, when `WorldShell`, final save, `AppRoot`, and `ResultScreen` consume it in the same vertical slice.
- `GameHud.has_blocking_modal()` remains the one gameplay input gate. Opening blocks; contextual cards do not.
- Full-rect onboarding root uses `MOUSE_FILTER_IGNORE`; opening panel uses `STOP`; the small tutorial card uses `STOP` only within its own bounds and must not cover the action/seed controls.
- Fresh-world tests that expect movement/world commands press the real opening Start button first. Keep one test proving input is locked before Start. No production `skip_intro` flag.
- Completed Continue routes directly to `ResultScreen`; there is no post-game world.
- Final save failure never rolls back the ending. Show it; do not add retry/queue machinery.
- New Game does not proactively delete the slot, matching HPA-598.
- Extend existing GUT/headless seams; no browser hooks, second E2E harness, or production test API.
- `AGENTS.md` stays a symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` stays unchanged and is a post-commit gate because it verifies archived `HEAD`.
- HPA-599 owns packaging/export verification; HPA-597 does not add a macOS export-release gate.

---

### Task 0: Provision worktree GUT and freeze the baseline

**Files:** no committed files; local gitignored `addons/gut/` only.

**Produces:** a worktree-visible RED/GREEN runner matching `tools/verify-clean.sh`.

- [ ] **Step 1: Confirm Godot and reuse the verifier's pinned GUT version/checksum**

```bash
godot --version
sed -n '1,220p' tools/verify-clean.sh
```

Expected: standard non-.NET Godot `4.7.1`. Provision exactly the GUT archive/checksum used by the verifier into gitignored `addons/gut/`; do not commit it.

- [ ] **Step 2: Run the current baseline**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: current `main` behavior passes before production edits.

---

### Task 1: Add the pure content and finale policy

**Files:**
- Create: `scripts/game/content_rules.gd`
- Create: `tests/unit/test_content_rules.gd`
- Modify: `scripts/game/villager_rules.gd`
- Modify: `tests/unit/test_villager_rules.gd`

**Interfaces:**
- Produces `ContentRules.TUTORIAL_KEYS`, `initial_tutorial_progress()`, `next_tutorial_prompt(snapshot, excluded)`, and `build_harvest_result(state)`.
- Produces `VillagerRules.finale_line(id, level)`.
- Consumes only existing `GameRules`/`VillagerRules` static policy; no mutable session dependency.

- [ ] **Step 1: Write RED tests for exact tutorial identity/default state**

```gdscript
extends GutTest

func test_initial_tutorial_progress_has_exact_false_keys() -> void:
    assert_eq(ContentRules.TUTORIAL_KEYS, [
        &"farm_basics", &"plant", &"water", &"sleep", &"talk",
        &"buy_seeds", &"harvest", &"shipping", &"gift",
    ])
    var progress := ContentRules.initial_tutorial_progress()
    assert_eq(progress.size(), ContentRules.TUTORIAL_KEYS.size())
    for key in ContentRules.TUTORIAL_KEYS:
        assert_true(progress.has(key))
        assert_false(progress[key])
```

Run GUT; expected RED because `ContentRules` does not exist.

- [ ] **Step 2: Implement the smallest static contract**

```gdscript
class_name ContentRules
extends RefCounted

const TUTORIAL_KEYS: Array[StringName] = [
    &"farm_basics", &"plant", &"water", &"sleep", &"talk",
    &"buy_seeds", &"harvest", &"shipping", &"gift",
]
const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

static func initial_tutorial_progress() -> Dictionary:
    var result: Dictionary = {}
    for key in TUTORIAL_KEYS:
        result[key] = false
    return result
```

Keep opening/tutorial copy in direct constants/tables in this file. Do not add Resources/registries for nine prompts.

- [ ] **Step 3: Write RED prompt-relevance tests using state-shaped snapshots**

Use a small test helper that starts from `GameSession.new().snapshot()` and enriches only the state needed for each predicate. Cover:

- first eligible prompt is `farm_basics` after intro;
- `plant` requires tilled empty soil plus a seed;
- `water` requires Sunny + immature unwatered crop and is suppressed by Rain;
- `sleep` follows a watered crop or Rainy planted crop;
- `talk`/`buy_seeds` are Day 2+ (buy also requires at least Turnip affordability);
- `harvest` requires mature crop;
- `shipping`/`gift` require harvested inventory;
- excluded/dismissed IDs are skipped without changing completion flags;
- `{}` when no incomplete relevant prompt exists.

Example:

```gdscript
var prompt := ContentRules.next_tutorial_prompt(snapshot, [&"talk"])
assert_ne(prompt.get("id", &""), &"talk")
assert_false(snapshot["tutorial"][&"talk"])
```

- [ ] **Step 4: Implement one ordered explicit selector**

`next_tutorial_prompt(snapshot, excluded)` scans `TUTORIAL_KEYS`, checks one concrete predicate per step, and returns only `{id,title,body}` or `{}`. No predicate objects/DSL/state machine.

- [ ] **Step 5: Write RED tier-boundary tests from canonical state-shaped relationships**

The fixture contains `shipped`, `money`, and `relationships`; each relationship uses persisted raw `points` and the existing daily flags shape. Do **not** add snapshot-only `level` to the fixture.

Pin:

```gdscript
# 2 potatoes = exactly 150G
assert_eq(_result_for([0, 2, 0], [0, 0, 0])["tier"], &"promising_farmer")

# 4 potatoes = 300G but no Close Friend -> still Promising
assert_eq(_result_for([0, 4, 0], [0, 0, 0])["tier"], &"promising_farmer")

# 300G + one Close Friend -> Heart
assert_eq(
    _result_for([0, 4, 0], [0, 0, VillagerRules.CLOSE_FRIEND_POINTS])["tier"],
    &"heart_of_harvest",
)
```

Also prove Friend alone yields Promising and below both boundaries yields New Beginning.

- [ ] **Step 6: Add finale lines and pure result derivation**

Add one `FINALE_LINES[villager][relationship_level]` table and:

```gdscript
static func finale_line(id: VillagerId, level: RelationshipLevel) -> String:
    return FINALE_LINES[id][level]
```

`ContentRules.build_harvest_result(state)`:

1. reads `state["shipped"]`;
2. derives count/value through `GameRules.sale_value()`;
3. reads each `state["relationships"][key]["points"]`;
4. derives `RelationshipLevel` through `VillagerRules.relationship_level(points)`;
5. chooses `VillagerRules.finale_line()`;
6. returns tier key/title, shipped count/value, final money, relationship display data, and villager lines.

Persist no score/result object.

- [ ] **Step 7: GREEN + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
git add scripts/game/content_rules.gd scripts/game/villager_rules.gd \
  tests/unit/test_content_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: add Phoenix content and finale rules"
```

---

### Task 2: Make onboarding, lifetime shipping, and market finalization authoritative

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/world/world_contract.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd` only if existing generic transport coverage needs one canonical nested-state case

**Interfaces:**
- Produces `WorldContract.MARKET_*`.
- Produces four canonical persisted facts and their total validation/restore.
- Produces `GameSession.acknowledge_intro()`, `trigger_harvest_finale(target)`, `_settle_pending_shipment()`, and `_complete_finale()`.
- **Keeps Day 14 `sleep()` returning `DAY_LIMIT_REACHED` in this task.** No live application path can finish the run yet.

- [ ] **Step 1: Add the market contract before domain tests need it**

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

Pin:

```gdscript
assert_eq(
    WorldContract.MARKET_ANCHOR,
    WorldMath.grid_to_world(Vector2(WorldContract.MARKET_CELL) + Vector2(0.5, 0.5)),
)
```

Scene consumption waits until Task 3.

- [ ] **Step 2: Write RED starter-state/isolation/validation tests**

Extend the exact `state()` and `snapshot()` shape assertions. Both projections must contain:

```gdscript
assert_false(snapshot["intro_acknowledged"])
assert_eq(snapshot["tutorial"], ContentRules.initial_tutorial_progress())
assert_eq(snapshot["shipped"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
assert_false(snapshot["finale_triggered"])
```

Mutate returned `tutorial`/`shipped` dictionaries and prove a fresh `state()` and `snapshot()` are isolated.

Add invalid candidates for:

- each missing new field;
- wrong intro/finale boolean types;
- tutorial missing/extra key or non-boolean value;
- negative shipped count;
- finale before Day 14;
- finale with pending morning summary;
- finale with non-empty pending shipment.

Old pre-HPA-597 state without the fields must fail loudly.

- [ ] **Step 3: Add exact session fields and copy them into both projections**

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

In `state()` add exactly:

```gdscript
"intro_acknowledged": _intro_acknowledged,
"tutorial": _tutorial_progress.duplicate(true),
"shipped": _counts_snapshot(_shipped_counts),
"finale_triggered": _finale_triggered,
```

Then add the same four keys explicitly to the hand-built `snapshot()` dictionary. Do not assume snapshot automatically includes new state fields.

Extend `state_error()` in the existing `_field()` / `_counts_state_error()` style and canonicalize JSON String keys in `restore_state()`. Do not edit `SaveFileCodec` semantics or schema version.

- [ ] **Step 4: Write RED success-vs-failure tutorial completion tests**

Pin failed commands as non-completing and successful commands as completing. Example:

```gdscript
var session := GameSession.new()
assert_eq(session.hoe(Vector2i(0, 0)), GameRules.CommandCode.NOT_FARM_CELL)
assert_false(session.state()["tutorial"][&"farm_basics"])

var cell := WorldContract.farm_cells()[0]
assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
assert_true(session.state()["tutorial"][&"farm_basics"])
```

Cover Plant, Water, **normal Day 1–13** `DAY_ADVANCED`, Buy Seeds, Talk, Harvest, Deposit, Gift. Selecting action/seed does not count.

- [ ] **Step 5: Add intro/finale command codes and direct completion mapping**

Add while retaining `DAY_LIMIT_REACHED`:

```gdscript
INTRO_ACKNOWLEDGED,
INTRO_ALREADY_ACKNOWLEDGED,
FINALE_TRIGGERED,
MARKET_NOT_READY,
NOT_AT_MARKET,
FINALE_ALREADY_TRIGGERED,
```

`acknowledge_intro()` flips once; duplicate acknowledgment is a no-op failure code. Add one private success-code -> tutorial-ID mapping invoked only after real command mutations. Keep social completion inside successful `talk_to()`/`gift_crop()` paths.

- [ ] **Step 6: Write RED cumulative-shipping tests, then extract one settlement helper**

Through existing public crop/deposit/sleep commands prove normal sleep clears pending shipment, pays money, records lifetime `shipped`, and later nights accumulate lifetime counts while morning summaries remain per-night.

Extract only:

```gdscript
func _settle_pending_shipment() -> Dictionary:
    var payout := GameRules.shipment_payout(_counts_snapshot(_pending_shipment_counts))
    for kind in range(GameRules.CropKind.size()):
        _shipped_counts[kind] += _pending_shipment_counts[kind]
    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    return payout
```

Use it from normal Day 1–13 sleep; preserve crop/weather/stamina/summary/social-reset behavior.

- [ ] **Step 7: Write RED market-finalization tests and preserve the bed characterization**

A narrow fixture may seed `_day`, pending counts, and relationship points; immediately assert the seeded state before exercising public commands.

Cover market finalization:

- market before Day 14 -> `MARKET_NOT_READY`;
- Day 14 wrong target -> `NOT_AT_MARKET`;
- Day 14 market -> `FINALE_TRIGGERED`;
- final pending shipment paid and added to lifetime counts once;
- day remains 14; no morning summary; no weather roll/crop growth/time/stamina/social reset;
- duplicate finale -> `FINALE_ALREADY_TRIGGERED` with no mutation;
- all later gameplay commands are terminal-blocked.

Also keep one explicit characterization of the not-yet-routed bed path:

```gdscript
var before := session.state()
assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_LIMIT_REACHED)
assert_eq(session.state(), before)
```

This test is intentionally replaced in Task 4.

- [ ] **Step 8: Implement market `_complete_finale()` only; do not flip sleep yet**

`trigger_harvest_finale(target)` validates active state/day/target then delegates:

```gdscript
func _complete_finale() -> GameRules.CommandCode:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
    _settle_pending_shipment()
    _finale_triggered = true
    return GameRules.CommandCode.FINALE_TRIGGERED
```

Update `_active_day_failure()` to terminal-block a directly finalized session. Leave the existing Day 14 branch in `sleep()` returning `DAY_LIMIT_REACHED`. Do not remove the enum/HUD copy in Task 2.

- [ ] **Step 9: Verify generic save transport + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
git grep -n "DAY_LIMIT_REACHED" -- scripts tests
```

Expected: GUT green. `DAY_LIMIT_REACHED` is **still present** in the current Day 14 sleep/HUD/test contract and is removed only in Task 4.

If existing `test_save_file.gd` already proves recursive dictionaries, do not add redundant field-aware tests. Otherwise add one encode/decode -> `GameSession.restore_state()` case; keep `SaveFileCodec` ignorant of HPA-597 field names.

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd scripts/world/world_contract.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd
git commit -m "feat: add authoritative Phoenix content state"
```

Omit `tests/unit/test_save_file.gd` from `git add` if unchanged.

---

### Task 3: Author the market and contextual onboarding UI

**Files:**
- Modify: `scenes/world/world.tscn`
- Modify: `assets/sprites/proof-scenery.png`
- Modify: `assets/sprites/proof-scenery.png.import` only if normal Godot import changes it
- Create: `scenes/ui/onboarding_overlay.tscn`
- Create: `scripts/ui/onboarding_overlay.gd`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`

**Interfaces:**
- Produces authored market geometry/visual and the opening/tutorial/objective UI.
- Opening reuses the existing modal input gate.
- The market is visible but **not yet a live terminal interaction**; Day 14 sleep still has the old temporary boundary until Task 4.

- [ ] **Step 1: Write RED market scene/smoke contracts including every hard-coded offset**

Update `tests/headless/world_shell_smoke.gd` expectations together:

```gdscript
EXPECTED_ASSETS["proof-scenery"] = Vector2i(384, 96)
```

Pin collision order exactly:

```gdscript
var collision_names := [
    "TreeCollision",
    "BuildingCollision",
    "ShippingCollision",
    "HarvestMarketCollision",
] + WorldContract.VILLAGER_COLLISION_NAMES + [
    "PerimeterTop",
    "PerimeterRight",
    "PerimeterBottom",
    "PerimeterLeft",
]
```

Perimeters now use:

```gdscript
collision_names[index + 7]
```

Pin entity order exactly:

```gdscript
[
    "Player", "Tree", "Building", "Shipping", "HarvestMarket",
    "VillagerShopkeeper", "VillagerFarmer", "VillagerResident",
]
```

then dynamic crops. In GUT scene tests change `7 + cells.size()` / `7 + index` to `8 + cells.size()` / `8 + index`.

Also assert:

- Tree/Building/Shipping/HarvestMarket use `proof-scenery.png`, `hframes == 4`, frames `0/1/2/3`;
- HarvestMarket anchor equals `WorldContract.MARKET_ANCHOR`;
- HarvestMarket collision equals `WorldMath.footprint_to_polygon(WorldContract.MARKET_FOOTPRINT)`;
- HarvestMarket `z_index` equals the current shared entity z-index.

- [ ] **Step 2: Author the market using existing world conventions**

Extend `proof-scenery.png` from `288x96` to `384x96` with one proof-quality 96x96 market-stall frame. Keep bottom-center ground contact and transparent background. No asset generator/framework for one frame.

In `world.tscn`:

- change existing Tree/Building/Shipping scenery sprites to `hframes = 4`, preserving frames 0/1/2;
- insert `HarvestMarketCollision` **after ShippingCollision and before villager collisions**;
- insert `Entities/HarvestMarket` **after Shipping and before villagers** at `MARKET_ANCHOR`, frame 3, `offset = Vector2(0, -48)`.

In `WorldShell._ready()`, derive the market polygon through `WorldMath.footprint_to_polygon()` like Shipping.

`FarmView` remains unchanged because it resolves crop roots by name.

- [ ] **Step 3: Write RED opening/prompt tests and add the test-only caller helpers**

Keep one test that intentionally does **not** acknowledge:

```gdscript
func test_fresh_opening_blocks_world_input() -> void:
    var world := _world()
    var hud := _hud(world)
    var opening := hud.get_node("HudRoot/OnboardingOverlay/OpeningPanel") as Control
    assert_true(opening.visible)
    assert_false(world._world_input_enabled)
    assert_false(world._session.state()["intro_acknowledged"])
```

Add one integration helper that uses the real UI path:

```gdscript
func _acknowledge_intro(world: WorldShell) -> void:
    var start := world.hud.get_node(
        "HudRoot/OnboardingOverlay/OpeningPanel/Start"
    ) as Button
    start.pressed.emit()
    await get_tree().process_frame
```

Use `await _acknowledge_intro(world)` at the top of every **existing** gameplay-shell test that expects movement enabled, calls `select_action_slot()`, `use_selected_action()`, `interact()`, or opens a gameplay modal through world interaction. Structural render-only tests do not need it.

Add the analogous button helper to `world_shell_smoke.gd` and call it once before the existing section that first presses movement/actions. Do not mutate `_intro_acknowledged` directly and do not add a production bypass.

- [ ] **Step 4: Implement `OnboardingOverlay` with explicit mouse filters**

The scene contract is:

```text
OnboardingOverlay (full rect): mouse_filter = IGNORE
OpeningPanel:                 mouse_filter = STOP
TutorialCard:                 mouse_filter = STOP
```

`TutorialCard` is a small panel placed away from the existing action/seed bar; its own Dismiss button remains clickable, but the full overlay does not cover/consume the rest of the HUD.

```gdscript
class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

var _dismissed: Array[StringName] = []

func render(snapshot: Dictionary) -> void:
    _render_opening(not bool(snapshot["intro_acknowledged"]))
    _render_tutorial(ContentRules.next_tutorial_prompt(snapshot, _dismissed))
```

Dismiss stores only transient IDs.

- [ ] **Step 5: Reuse the current HUD/world modal gate**

`GameHud` forwards `intro_acknowledged` and includes only the opening panel in `has_blocking_modal()`. When opening becomes visible, close other gameplay modals and emit the existing `modal_state_changed` signal. No second lock boolean.

`WorldShell` handler:

```gdscript
func _on_intro_acknowledged() -> void:
    _finish_command(_session.acknowledge_intro())
```

This mirrors morning-summary acknowledgement; do not reject it merely because `_world_input_enabled` is false.

- [ ] **Step 6: Prove tutorial-card hit testing does not break existing HUD buttons**

After Start and while a tutorial card is visible, connect to the production HUD signal and press an existing action button:

```gdscript
var selected: Array[int] = []
world.hud.select_action_requested.connect(func(action: int) -> void:
    selected.append(action)
)

var hoe_button := world.hud.get_node("HudRoot/Action_0") as Button
hoe_button.pressed.emit()
assert_eq(selected, [GameRules.FarmingAction.HOE])
assert_true(world._world_input_enabled)
```

Also prove Dismiss hides the current card without mutating `world._session.state()["tutorial"]`, and successful Hoe refresh completes/removes `farm_basics`.

- [ ] **Step 7: Add the persistent objective but keep the temporary Day 14 boundary truthful**

Always-visible HUD objective:

```text
Harvest Market: Day 14 · 13 days left
```

through Day 13 and:

```text
Harvest Market today — village path stall
```

on Day 14.

Do **not** remove `DAY_LIMIT_REACHED`, do not change the current Day 14 sleep warning to claim completion, and do not add `Harvest Market — E` yet. Those player-action contracts land atomically with terminal routing in Task 4.

- [ ] **Step 8: GREEN + commit**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

```bash
git add assets/sprites/proof-scenery.png assets/sprites/proof-scenery.png.import \
  scenes/world/world.tscn scenes/ui/game_hud.tscn scenes/ui/onboarding_overlay.tscn \
  scripts/world/world_shell.gd scripts/ui/game_hud.gd scripts/ui/onboarding_overlay.gd \
  tests/integration/test_gameplay_shell.gd tests/headless/world_shell_smoke.gd
git commit -m "feat: add harvest market and contextual onboarding"
```

Omit `.import` if Godot leaves it unchanged.

---

### Task 4: Flip Day 14 and route both finale triggers through one final save to `ResultScreen`

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/unit/test_game_session.gd`
- Create: `scenes/ui/result_screen.tscn`
- Create: `scripts/ui/result_screen.gd`
- Modify: `scenes/app/app.tscn`
- Modify: `scripts/app/app_root.gd`
- Modify: `tests/integration/test_app_launch.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`

**Interfaces:**
- Consumes Task 2's `_complete_finale()` and market command.
- Produces the one live terminal route for market **and** Day 14 bed, one final save attempt, `finale_completed`, `ResultScreen`, and completed-Continue routing.
- Removes the temporary `DAY_LIMIT_REACHED` domain/UI contract in this same task.

- [ ] **Step 1: Replace the temporary Day 14 bed characterization with RED market == bed domain tests**

From the same seeded pre-final state:

```gdscript
var by_market := _day14_session_from(pre_final_state)
var by_bed := _day14_session_from(pre_final_state)

assert_eq(
    by_market.trigger_harvest_finale(WorldContract.MARKET_CELL),
    GameRules.CommandCode.FINALE_TRIGGERED,
)
assert_eq(
    by_bed.sleep(WorldContract.BED_CELL),
    GameRules.CommandCode.FINALE_TRIGGERED,
)
assert_eq(by_bed.state(), by_market.state())
```

Also assert no weather roll/crop growth/day advance and final shipment settled once.

Expected RED: Day 14 bed still returns `DAY_LIMIT_REACHED` from Task 2.

- [ ] **Step 2: Write RED completed-Continue AppRoot test**

Create a terminal state through `trigger_harvest_finale()` (or after Step 1 through bed), save it through real `SaveRepository`, spawn AppRoot, emit Continue, then assert:

```gdscript
assert_null(app.get_node_or_null("World"))
var result := app.get_node("ResultScreen") as ResultScreen
assert_true(result.visible)
```

Pin displayed result against `ContentRules.build_harvest_result(completed_state)` rather than duplicating scoring in the test.

- [ ] **Step 3: Add a presentation-only static `ResultScreen` sibling**

`result_screen.tscn` has result title, shipped count/value, final money, relationship summary, three villager lines, save-status text, New Game, Return to Title. Hidden by default.

```gdscript
class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

func present(result: Dictionary, save_error: int = OK) -> void:
    # assign labels and button state only
    visible = true
```

Instance it beside `TitleScreen` in `app.tscn`.

- [ ] **Step 4: Extend AppRoot routing with validated direct indexing**

In `_launch(initial_state)`:

```gdscript
if initial_state != null and bool(initial_state["finale_triggered"]):
    _show_result(initial_state, OK)
    return
```

Do **not** use `.get("finale_triggered", false)`. `_load_title_state()` already calls `GameSession.state_error()`, and missing HPA-597 keys are incompatible, so a silent default would weaken the validated boundary.

`_show_result(state, save_error)` derives through `ContentRules.build_harvest_result(state)`, frees any live World, hides title, and presents result.

Result New Game hides result then launches fresh world without deleting the slot. Return to Title hides result, shows title, calls `_load_title_state()` so Continue reflects the latest successful save.

- [ ] **Step 5: Write RED one-save/equivalent-trigger integration tests using the existing repository fake**

Reuse `CountingSaveRepository` from `tests/integration/test_persistence_flow.gd`; do not create another save fake.

For the same pre-final state prove:

1. Day 14 market interaction saves exactly once and opens result;
2. Day 14 sleep saves exactly once and opens result;
3. canonical terminal state and `ContentRules.build_harvest_result()` are equal for both routes;
4. duplicate finalization cannot add another save;
5. pending final shipment is paid/recorded once.

For market interaction, target `WorldContract.MARKET_CELL` and use the live `world.interact()` path. For bed, use the existing sleep-panel signal path.

- [ ] **Step 6: Flip the Day 14 domain boundary and remove the temporary code/copy**

Change `GameSession.sleep()` only now:

```gdscript
if _day == GameRules.MAX_DAY:
    return _complete_finale()
```

preserving the existing bed-target and pending-summary checks before it.

Remove `GameRules.CommandCode.DAY_LIMIT_REACHED` and replace/remove all live HUD/integration copy that describes the old hard stop.

New truthful Day 14 copy:

```text
Day 14 shipment settles when the finale starts.
Day 14: sleeping ends the run and settles the final shipment.
```

Add the live target hint now:

```text
Harvest Market — E
```

- [ ] **Step 7: Add one WorldShell terminal handoff and market routing in the same change**

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

Route `MARKET_CELL` in `interact()` to the session command:

```gdscript
elif target == WorldContract.MARKET_CELL:
    _finish_finale(_session.trigger_harvest_finale(target))
```

Change `_on_sleep_requested()` so terminal success is consumed before the current normal-day branch:

```gdscript
func _on_sleep_requested() -> void:
    var target: Variant = player.current_target_cell()
    var code := _session.sleep(target)
    if code == GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_finale(code)
        return
    if code != GameRules.CommandCode.DAY_ADVANCED or _save_repository == null:
        _finish_command(code)
        return

    hud.show_feedback(code)
    _refresh_from_session()
    var save_error := _save_repository.save(_session.state())
    if save_error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(&"error", "Save failed — this morning is not persisted.")
```

One shared terminal helper:

```gdscript
func _finish_finale(code: GameRules.CommandCode) -> void:
    if code != GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_command(code)
        return
    hud.show_feedback(code)
    _refresh_from_session()
    var state := _session.state()
    var save_error := ERR_UNAVAILABLE
    if _save_repository != null:
        save_error = _save_repository.save(state)
    finale_completed.emit(state, save_error)
```

No await/save queue/reentrancy machinery.

- [ ] **Step 8: Connect the terminal handoff before the world enters the tree**

In `AppRoot._launch()` after instantiate/configure and before `add_child(world)`:

```gdscript
world.finale_completed.connect(_on_finale_completed)
```

`_on_finale_completed(final_state, save_error)` calls `_show_result(final_state, save_error)`.

Direct `world.tscn` tests have no repository, so successful terminal handoff uses `ERR_UNAVAILABLE`; do not create a fallback repository.

- [ ] **Step 9: Prove failure semantics and result actions**

Using the existing unwritable-directory repository style, assert final save failure still yields terminal result/no rollback and the result screen reports the unsaved ending.

Test Result -> New Game and Result -> Return to Title, including title reload behavior. New Game does not delete the previous slot.

- [ ] **Step 10: GREEN, prove old boundary is gone, and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git grep -n "DAY_LIMIT_REACHED" -- . ':!docs/superpowers/**'
git diff --check
```

Expected: GUT green and the grep has no live production/test matches.

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd scripts/ui/game_hud.gd \
  scripts/world/world_shell.gd tests/unit/test_game_session.gd \
  scenes/app/app.tscn scenes/ui/result_screen.tscn scripts/app/app_root.gd \
  scripts/ui/result_screen.gd tests/integration/test_app_launch.gd \
  tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd
git commit -m "feat: add terminal harvest result flow"
```

---

### Task 5: Close the acceptance loop and document the shipped slice

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify existing tests only if the acceptance pass exposes an actual missing contract

**Interfaces:**
- Verifies the complete HPA-597 behavior through current Godot/GUT/headless/save seams.
- Leaves packaging/export verification to HPA-599.

- [ ] **Step 1: Extend the existing persistence-flow acceptance path, not a new harness**

Use real UI/session/save seams to prove:

1. fresh opening is visible and world input is blocked;
2. press the real Start button;
3. Hoe/Plant/Water complete tutorial flags;
4. normal sleep saves;
5. reopen/Continue restores intro/tutorial state without reopening the introduction;
6. existing command-driven crop/social path completes Harvest/Talk/Gift/Shipping;
7. later normal sleep records/restores lifetime shipped counts.

Do not play thirteen literal UI days just to reach the already-focused Day 14 boundary tests.

- [ ] **Step 2: Add the completed-save reopen no-post-game assertion**

From a terminal state saved through real `WorldShell` final handoff:

```gdscript
var restored_app := APP_SCENE.instantiate() as AppRoot
restored_app.configure(repository)
add_child_autoqfree(restored_app)
var title := restored_app.get_node("TitleScreen") as TitleScreen
title.continue_requested.emit()
await get_tree().process_frame
assert_null(restored_app.get_node_or_null("World"))
assert_true((restored_app.get_node("ResultScreen") as ResultScreen).visible)
```

- [ ] **Step 3: Update README and CLAUDE.md**

README: opening/context help, Day 14 market goal, market `E`/sleep fallback, three encouraging endings, completed Continue -> result, no post-game.

CLAUDE.md: `ContentRules` pure policy, four persisted fields/no migration, explicit `state()` + `snapshot()` copies, `MARKET_*` ownership, overlay mouse/input contract, fresh-world Start test contract, shared settlement/finalization paths, WorldShell final-save handoff, AppRoot validated direct result routing, HPA-599 next for balance/polish/export.

Keep `AGENTS.md` untouched.

- [ ] **Step 4: Full worktree verification**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

- [ ] **Step 5: Commit closeout docs/tests**

```bash
git add README.md CLAUDE.md tests
git commit -m "docs: finish HPA-597 content slice handoff"
```

If Task 5 did not require a test change, omit `tests` rather than touching it needlessly.

- [ ] **Step 6: Run the committed clean-archive gate**

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected: green, clean diff/worktree, only HPA-597 files, no JavaScript/Tauri/browser runtime return. Keep `tools/verify-clean.sh` unchanged.

Do **not** add a macOS export-release step here. HPA-599 owns packaging/export verification.

---

## Done definition

HPA-597 is done in this one PR when:

- fresh play has a short blocking introduction followed by relevant dismissible non-blocking help;
- existing movement/world-interaction tests acknowledge the opening through the real Start button, while one test proves the pre-Start lock;
- the onboarding overlay does not intercept existing action/seed button clicks outside its small tutorial card;
- tutorial completion comes only from successful `GameSession` commands and survives save/continue;
- lifetime shipped counts survive multiple nights/save round trips;
- an authored harvest market exists on the current isometric/Y-sort world seam with all smoke offsets/assets/hframes updated;
- Day 14 market and Day 14 sleep switch to one terminal transaction only when the live shell/result route exists;
- final shipping settles exactly once and no route reaches Day 15;
- New Beginning, Promising Farmer, and Heart of the Harvest exact thresholds have direct tests from canonical state/raw relationship points;
- poor play always gets New Beginning, never game over;
- final save is attempted once through the current repository path and failure does not undo the ending;
- completed Continue uses validated `finale_triggered` directly and opens `ResultScreen` with no post-game world;
- README/CLAUDE handoff is current;
- `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass;
- packaging/export verification remains in HPA-599.
