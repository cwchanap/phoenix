# Phoenix Godot Content and Harvest Finale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Godot farming/economy/social/persistence shell into a self-explanatory 14-day MVP with contextual onboarding, one authored harvest-market finale, deterministic result tiers, and completed-save Continue.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the direct world/save coordinator. Add one pure `ContentRules` sibling for tutorial copy/eligibility and terminal result derivation; persist four content facts directly in `GameSession.state()`; share one shipment-settlement helper between normal sleep and finale; add one focused onboarding `Control`; author one market entity in the existing world; and add one presentation-only `ResultScreen` sibling under `AppRoot`. `SaveFileCodec` remains semantic-field-blind schema-v1 transport.

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
- Complete tutorial steps only after successful authoritative commands. Dismissal is transient UI state.
- Normal sleep and finale share one shipment-settlement helper. Market and Day 14 sleep share one finale helper.
- `GameHud.has_blocking_modal()` remains the one gameplay input gate. Opening blocks; contextual cards do not.
- Completed Continue routes directly to `ResultScreen`; there is no post-game world.
- Final save failure never rolls back the ending. Show it; do not add retry/queue machinery.
- New Game does not proactively delete the slot, matching HPA-598.
- Extend existing GUT/headless seams; no browser hooks, second E2E harness, or production test API.
- `AGENTS.md` stays a symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` stays unchanged and is a post-commit gate because it verifies archived `HEAD`.

---

### Task 0: Provision worktree GUT and freeze the baseline

**Files:** no committed files; local gitignored `addons/gut/` only.

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

**Produces:** tutorial IDs/defaults/copy/relevance; 150G/300G tier policy; three villager finale-line tables; no mutable state.

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

- [ ] **Step 3: Write RED prompt-relevance tests using enriched real snapshots**

Take `GameSession.new().snapshot()`, inject `intro_acknowledged`/`tutorial` in test-local helpers, then cover:

- first eligible prompt is `farm_basics` after intro;
- `plant` requires tilled empty soil plus a seed;
- `water` requires Sunny + immature unwatered crop and is suppressed by Rain;
- `sleep` follows a watered crop or Rainy planted crop;
- `talk`/`buy_seeds` are Day 2+ (buy also requires at least Turnip affordability);
- `harvest` requires mature crop;
- `shipping`/`gift` require harvested inventory;
- excluded/dismissed prompt IDs are skipped without changing completion flags;
- `{}` when no incomplete relevant prompt exists.

Example:

```gdscript
var prompt := ContentRules.next_tutorial_prompt(snapshot, [&"talk"])
assert_ne(prompt.get("id", &""), &"talk")
assert_false(snapshot["tutorial"][&"talk"])
```

- [ ] **Step 4: Implement one ordered explicit selector**

`next_tutorial_prompt(snapshot, excluded)` scans `TUTORIAL_KEYS`, checks one concrete predicate per step, and returns only `{id,title,body}` or `{}`. No predicate objects/DSL/state machine.

- [ ] **Step 5: Write RED tier-boundary tests from small terminal dictionaries**

Use a test-local result-state dictionary containing only fields consumed by `build_harvest_result`: `shipped`, `money`, `relationships`.

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

`ContentRules.build_harvest_result(state)` derives shipped count/value from `GameRules.sale_value()`, final money, relationship levels, one line/villager, tier key/title. Final money is display-only; persist no score/result object.

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

### Task 2: Make onboarding, lifetime shipping, and Day 14 completion authoritative

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/world/world_contract.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd` only if existing generic transport coverage needs one canonical nested-state case

**Produces:** market world contract, four persisted content facts, authoritative tutorial completion, shared shipment settlement, one terminal domain boundary.

- [ ] **Step 1: Add the market contract before domain tests need it**

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

Add a small unit/headless assertion if the current world-contract tests have a natural home. Scene consumption waits until Task 3.

- [ ] **Step 2: Write RED starter-state/isolation/validation tests**

Extend pinned state/snapshot shape with:

```gdscript
assert_false(snapshot["intro_acknowledged"])
assert_eq(snapshot["tutorial"], ContentRules.initial_tutorial_progress())
assert_eq(snapshot["shipped"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
assert_false(snapshot["finale_triggered"])
```

Add invalid candidates for missing new fields, wrong boolean types, missing/extra/non-boolean tutorial keys, negative shipped counts, finale before Day 14, finale with pending summary, and finale with non-empty pending shipment.

- [ ] **Step 3: Add exact state fields and canonical restore**

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

Expose them directly through `state()`/`snapshot()`. `state_error()` remains total current-rule validation; `restore_state()` canonicalizes JSON String keys back to runtime keys. Do not change `SaveFileCodec` semantics or schema version.

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

Cover Plant, Water, normal `DAY_ADVANCED`, Buy Seeds, Talk, Harvest, Deposit, Gift. Selecting action/seed does not count.

- [ ] **Step 5: Add intro command and direct completion mapping**

Add command codes:

```gdscript
INTRO_ACKNOWLEDGED,
INTRO_ALREADY_ACKNOWLEDGED,
FINALE_TRIGGERED,
MARKET_NOT_READY,
NOT_AT_MARKET,
FINALE_ALREADY_TRIGGERED,
```

`acknowledge_intro()` flips once; duplicate acknowledgment is a no-op failure code. Add one private success-code -> tutorial-ID mapping and invoke it only after real command mutations. Keep social completion inside successful `talk_to()`/`gift_crop()` paths.

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

Use it from normal Day 1–13 sleep; preserve all crop/weather/stamina/summary/social-reset behavior.

- [ ] **Step 7: Replace the temporary Day 14 test with RED finale boundary tests**

A narrow fixture may seed `_day`/pending counts/relationship points, immediately assert the seeded state, then exercise public commands.

Cover:

- market before Day 14 -> `MARKET_NOT_READY`;
- Day 14 wrong target -> `NOT_AT_MARKET`;
- Day 14 market -> `FINALE_TRIGGERED`;
- Day 14 bed -> same `FINALE_TRIGGERED` terminal state from the same pre-final state;
- final pending shipment paid and added to lifetime counts once;
- day remains 14; no morning summary; no weather roll/crop growth/time/stamina/social-daily reset;
- duplicate finale -> `FINALE_ALREADY_TRIGGERED` with no mutation;
- all later gameplay commands are terminal-blocked.

- [ ] **Step 8: Implement one `_complete_finale()` and remove `DAY_LIMIT_REACHED`**

`trigger_harvest_finale(target)` validates active state/day/target then delegates. Day 14 `sleep()` validates bed target then delegates to the same helper.

```gdscript
func _complete_finale() -> GameRules.CommandCode:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
    _settle_pending_shipment()
    _finale_triggered = true
    return GameRules.CommandCode.FINALE_TRIGGERED
```

Update `_active_day_failure()` to block terminal sessions. Remove `DAY_LIMIT_REACHED` when no live path references it.

- [ ] **Step 9: Verify generic save transport + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git grep -n "DAY_LIMIT_REACHED" -- . ':!docs/superpowers/**'
git diff --check
```

Expected: green; no live `DAY_LIMIT_REACHED` reference.

If existing `test_save_file.gd` already proves recursive dictionaries, do not add redundant field-aware tests. Otherwise add one encode/decode -> `GameSession.restore_state()` case; keep `SaveFileCodec` ignorant of HPA-597 field names.

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd scripts/world/world_contract.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd
git commit -m "feat: add authoritative onboarding and finale state"
```

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

**Produces:** authored market geometry/visual, blocking opening, non-blocking contextual card, persistent Day 14 HUD objective. Successful terminal routing waits for Task 4 so no intermediate commit can finish a run without a result screen.

- [ ] **Step 1: Write RED scene-contract tests**

Pin that:

- `HarvestMarketCollision` derives from `WorldContract.MARKET_FOOTPRINT`;
- direct `Entities/HarvestMarket` is at `MARKET_ANCHOR`, uses the fourth scenery frame, and participates in the existing single Y-sort node;
- entity count/crop offset changes from `7 + cells` / `7 + index` to `8 + cells` / `8 + index`.

`FarmView` itself should need no production change because it resolves crop nodes by name.

- [ ] **Step 2: Author the market using existing world conventions**

Extend `proof-scenery.png` with one fourth 96×96 proof-quality market-stall frame. Keep bottom-center ground contact and transparent background. Do not add a generator/framework for one frame.

In `world.tscn`:

- existing Tree/Building/Shipping use `hframes = 4`, preserving frames 0/1/2;
- add `HarvestMarketCollision` under `StaticCollision`;
- add `Entities/HarvestMarket` at `MARKET_ANCHOR`, frame 3, existing `offset = Vector2(0, -48)` convention.

In `WorldShell._ready()`, derive the collision polygon through `WorldMath.footprint_to_polygon()` like current authored scenery.

- [ ] **Step 3: Write RED opening/prompt tests**

Pin the behavioral contract rather than pixel positions:

```gdscript
var world := _world()
var hud := _hud(world)
var opening := hud.get_node("HudRoot/OnboardingOverlay/OpeningPanel") as Control
assert_true(opening.visible)
assert_false(world._world_input_enabled)
assert_false(world._session.state()["intro_acknowledged"])

(opening.get_node("Start") as Button).pressed.emit()
assert_true(world._session.state()["intro_acknowledged"])
assert_false(opening.visible)
assert_true(world._world_input_enabled)
```

Also prove tutorial card appears after intro, Dismiss does not mutate session flags, contextual card does not block gameplay, successful Hoe refresh completes/removes `farm_basics`, and restored acknowledged state does not reopen the intro.

- [ ] **Step 4: Implement one focused `OnboardingOverlay` Control**

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

Opening panel is mouse-blocking; tutorial card is not. Dismiss stores only transient IDs. Instance the scene once under `GameHud/HudRoot`.

- [ ] **Step 5: Reuse the current HUD/world modal gate**

`GameHud` forwards `intro_acknowledged` and includes only the opening panel in `has_blocking_modal()`. When opening becomes visible it closes other gameplay modals and emits the existing modal-state change. No second lock boolean.

`WorldShell` handler:

```gdscript
func _on_intro_acknowledged() -> void:
    _finish_command(_session.acknowledge_intro())
```

The existing refresh releases input once authoritative state changes.

- [ ] **Step 6: Add objective, Day 14 copy, and market target hint**

Always-visible HUD:

```text
Harvest Market: Day 14 · 13 days left
```

through Day 13 and:

```text
Harvest Market today — village path stall
```

on Day 14.

Replace temporary Day 14 warnings with:

```text
Day 14 shipment settles when the finale starts.
Day 14: sleeping ends the run and settles the final shipment.
```

Targeting `MARKET_CELL` shows `Harvest Market — E` in `WorldShell._process()`.

Add feedback copy for new intro/market/finale command codes, but do **not** route successful market interaction yet; Task 4 adds the market command and terminal save/result handoff atomically.

- [ ] **Step 7: GREEN + commit**

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

### Task 4: Route both finale triggers through one final save to `ResultScreen`

**Files:**
- Create: `scenes/ui/result_screen.tscn`
- Create: `scripts/ui/result_screen.gd`
- Modify: `scenes/app/app.tscn`
- Modify: `scripts/app/app_root.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_app_launch.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`

**Produces:** market interaction, Day 14 sleep fallback, one terminal save handoff, completed-save Continue, terminal New Game/Return Title.

- [ ] **Step 1: Write RED completed-Continue AppRoot test**

Create terminal state via a narrow fixture followed by public `sleep()`/`trigger_harvest_finale()`, save it through real `SaveRepository`, spawn AppRoot, emit Continue, then assert:

```gdscript
assert_null(app.get_node_or_null("World"))
var result := app.get_node("ResultScreen") as ResultScreen
assert_true(result.visible)
```

Pin displayed result against `ContentRules.build_harvest_result(completed)` rather than duplicated UI scoring.

- [ ] **Step 2: Add a presentation-only static `ResultScreen` sibling**

`result_screen.tscn` has result title, shipped count/value, final money, relationship summary, three villager lines, save-status text, New Game, Return to Title. Hidden by default.

```gdscript
class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

func present(result: Dictionary, save_error: int = OK) -> void:
    # labels/buttons only; no file or GameSession access
    visible = true
```

Instance it beside `TitleScreen` in `app.tscn`.

- [ ] **Step 3: Extend AppRoot routing without changing title responsibilities**

In `_launch(initial_state)`:

```gdscript
if initial_state != null and bool(initial_state.get("finale_triggered", false)):
    _show_result(initial_state, OK)
    return
```

`_show_result(state, save_error)` derives through `ContentRules`, frees any live World, hides title, presents result.

Result New Game hides result then launches fresh world without deleting slot. Return to Title hides result, shows title, calls `_load_title_state()` so Continue reflects the latest successful save.

- [ ] **Step 4: Write RED one-save/equivalent-trigger integration tests**

Using `CountingSaveRepository`, prove for the same pre-final state:

1. Day 14 market interaction saves exactly once and opens result;
2. Day 14 sleep saves exactly once and opens result;
3. canonical terminal state and `ContentRules.build_harvest_result()` are equal for both routes;
4. duplicate finalization cannot add another save;
5. pending final shipment is paid/recorded once.

- [ ] **Step 5: Add one WorldShell terminal handoff and market routing**

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

Route `MARKET_CELL` in `interact()` to `GameSession.trigger_harvest_finale(target)`.

Both market success and Day 14 `_on_sleep_requested()` success call:

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

Connect `world.finale_completed` in `AppRoot` before `add_child(world)` and route to `_show_result()`. Keep normal `DAY_ADVANCED` morning-summary save/status behavior unchanged. No `await`, save queue, or reentrancy machinery.

- [ ] **Step 6: Prove failure semantics and result actions**

With the existing unwritable-directory repository style assert final save failure still yields terminal result/no rollback. Test Result -> New Game and Result -> Return to Title, including title reload behavior.

- [ ] **Step 7: GREEN + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
```

```bash
git add scenes/app/app.tscn scenes/ui/result_screen.tscn \
  scripts/app/app_root.gd scripts/ui/result_screen.gd scripts/world/world_shell.gd \
  tests/integration/test_app_launch.gd tests/integration/test_gameplay_shell.gd \
  tests/integration/test_persistence_flow.gd
git commit -m "feat: add terminal harvest result flow"
```

---

### Task 5: Close the acceptance loop and document the shipped slice

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify existing tests only if the acceptance pass exposes an actual missing contract

- [ ] **Step 1: Extend the existing persistence-flow acceptance path, not a new harness**

Use real UI/session/save seams to prove:

1. fresh opening -> Start;
2. Hoe/Plant/Water complete tutorial flags;
3. normal sleep saves;
4. reopen/Continue restores intro/tutorial state;
5. existing command-driven crop/social path completes Harvest/Talk/Gift/Shipping;
6. later normal sleep records/restores lifetime shipped counts.

Do not play thirteen literal UI days just to reach the already-unit-tested Day 14 boundary.

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

CLAUDE.md: `ContentRules` pure policy, four persisted fields/no migration, `MARKET_*` ownership, opening uses existing input gate while prompt card is non-blocking, shared settlement/finalization paths, WorldShell final save handoff, AppRoot completed-result routing, HPA-599 next for balance/polish/export.

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

Expected: green, clean diff/worktree, only HPA-597 files, no JavaScript/Tauri/browser runtime return.

- [ ] **Step 7: Bounded exported-app sanity check**

```bash
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-597.app
```

Manually verify title -> New Game -> opening -> non-blocking prompt; Day 14 market/sleep -> result; completed reopen/Continue -> result; Result New Game; Result Return to Title. Packaging/signing/polish beyond this sanity pass belongs to HPA-599.

---

## Done definition

HPA-597 is done in this one PR when:

- fresh play has a short blocking introduction followed by relevant dismissible non-blocking help;
- tutorial completion comes only from successful `GameSession` commands and survives save/continue;
- lifetime shipped counts survive multiple nights/save round trips;
- an authored harvest market exists on the current isometric/Y-sort world seam;
- Day 14 market and Day 14 sleep use one terminal transaction;
- final shipping settles exactly once and no route reaches Day 15;
- New Beginning, Promising Farmer, and Heart of the Harvest exact thresholds have direct tests;
- poor play always gets New Beginning, never game over;
- final save is attempted once through the current repository path and failure does not undo the ending;
- completed Continue opens `ResultScreen` directly with no post-game world;
- README/CLAUDE handoff is current;
- `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass.
