# Phoenix Godot Content and Harvest Finale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Godot farming/economy/social/persistence shell into a self-explanatory 14-day MVP with contextual onboarding, one authored harvest-market finale, deterministic result tiers, and completed-save Continue.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the direct command/save coordinator. Add one pure `ContentRules` sibling for tutorial eligibility/copy and terminal result derivation, persist four content facts directly in `GameSession.state()`, reuse one shipment-settlement helper for normal sleep and finale, add one focused onboarding `Control`, author one market entity in the existing world, and add one presentation-only `ResultScreen` sibling under `AppRoot`. `SaveFileCodec` remains semantic-field-blind schema-v1 transport.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, Godot `Control` UI, existing sprite-isometric `TileMapLayer`/Y-sort world, GUT 9.7.1, current headless SceneTree smokes, FileAccess JSON autosave.

**Spec:** `docs/superpowers/specs/2026-08-25-phoenix-godot-content-finale-design.md`

**Behavior oracle:** Linear HPA-597 plus the product decisions retained from the superseded Phaser/Svelte HPA-597 plan; implementation details in that old plan are not authoritative.

## Global Constraints

- Deliver HPA-597 implementation on this same branch and PR after plan review. Do not create a second implementation PR.
- Keep one runtime, one `GameSession`, one `SaveRepository`, one authored world, and one save file.
- Keep `SaveFileCodec.SCHEMA_VERSION == 1` and semantic-field-blind. Old development saves missing HPA-597 fields are intentionally incompatible; add no migration.
- Preserve current starter money/seeds, crop growth/sale values, weather, action costs, and 12/18 relationship thresholds. HPA-599 owns balance tuning.
- Add only one new pure policy module: `ContentRules`. No tutorial engine, quest system, cutscene runner, event bus, result/scoring framework, or registry.
- Persist exactly: `intro_acknowledged`, exact `tutorial` flags, lifetime `shipped` crop counts, and `finale_triggered`.
- Tutorial completion happens only in successful authoritative `GameSession` command paths. Dismissal stays presentation-only.
- Normal sleep and terminal finalization share exactly one shipment-settlement helper.
- Market interaction and Day 14 sleep share exactly one finale-completion helper.
- `GameHud.has_blocking_modal()` remains the sole gameplay input gate. The opening blocks; contextual prompt cards do not.
- Completed saves route to `ResultScreen` in `AppRoot`; never instantiate a post-game `WorldShell`.
- Final save failure does not roll back the terminal session. Show the failure on the result screen; add no retry queue.
- New Game never proactively deletes the slot, matching HPA-598.
- Keep direct tests on existing seams. No browser hooks, second E2E harness, debug mutation API, or production test service.
- `AGENTS.md` remains the symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` remains unchanged and is a post-commit verification gate because it archives `HEAD`.

---

### Task 0: Provision worktree-visible GUT and freeze the baseline

**Files:**
- No committed files.
- Local only: gitignored `addons/gut/`.

- [ ] **Step 1: Confirm the pinned Godot runtime**

```bash
godot --version
```

Expected: standard non-.NET Godot `4.7.1`.

- [ ] **Step 2: Provision the exact GUT version/checksum already used by `tools/verify-clean.sh`**

Read the current verifier first and copy its version/checksum rather than inventing new tooling:

```bash
sed -n '1,220p' tools/verify-clean.sh
```

Provision the matching archive into gitignored `addons/gut/`. Do not commit the addon.

- [ ] **Step 3: Run the current baseline before changing production code**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: current `main` behavior passes. Use these direct worktree commands for RED/GREEN. Use `./tools/verify-clean.sh` after commits.

---

### Task 1: Add the pure content policy and finale copy

**Files:**
- Create: `scripts/game/content_rules.gd`
- Create: `tests/unit/test_content_rules.gd`
- Modify: `scripts/game/villager_rules.gd`
- Modify: `tests/unit/test_villager_rules.gd`

**Interfaces:**
- `ContentRules.TUTORIAL_KEYS`
- `ContentRules.initial_tutorial_progress()`
- `ContentRules.next_tutorial_prompt(snapshot, excluded)`
- `ContentRules.build_harvest_result(state)`
- `VillagerRules.finale_line(id, level)`

- [ ] **Step 1: Write RED tests for the exact tutorial progress shape**

Start `tests/unit/test_content_rules.gd` with the persisted contract:

```gdscript
extends GutTest

func test_initial_tutorial_progress_has_exact_false_keys() -> void:
    assert_eq(ContentRules.TUTORIAL_KEYS, [
        &"farm_basics",
        &"plant",
        &"water",
        &"sleep",
        &"talk",
        &"buy_seeds",
        &"harvest",
        &"shipping",
        &"gift",
    ])
    var progress := ContentRules.initial_tutorial_progress()
    assert_eq(progress.size(), ContentRules.TUTORIAL_KEYS.size())
    for key in ContentRules.TUTORIAL_KEYS:
        assert_true(progress.has(key))
        assert_false(progress[key])
```

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: RED because `ContentRules` does not exist.

- [ ] **Step 2: Implement the smallest static tutorial contract**

Create `scripts/game/content_rules.gd` with only constants/pure helpers. Start with:

```gdscript
class_name ContentRules
extends RefCounted

const TUTORIAL_KEYS: Array[StringName] = [
    &"farm_basics",
    &"plant",
    &"water",
    &"sleep",
    &"talk",
    &"buy_seeds",
    &"harvest",
    &"shipping",
    &"gift",
]

const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

static func initial_tutorial_progress() -> Dictionary:
    var result: Dictionary = {}
    for key in TUTORIAL_KEYS:
        result[key] = false
    return result
```

Keep the opening/tutorial strings as direct constants/tables in this file. Do not create resource files or a generic content registry for nine prompts.

- [ ] **Step 3: Write RED prompt-eligibility tests from real snapshot shapes**

Cover, at minimum:

```gdscript
func test_first_prompt_is_farm_basics_after_intro() -> void:
    var snapshot := GameSession.new().snapshot()
    snapshot["intro_acknowledged"] = true
    snapshot["tutorial"] = ContentRules.initial_tutorial_progress()
    assert_eq(
        ContentRules.next_tutorial_prompt(snapshot)["id"],
        &"farm_basics",
    )

func test_dismissed_prompt_is_skipped_without_becoming_complete() -> void:
    var snapshot := _tutorial_snapshot_for_day_two()
    var prompt := ContentRules.next_tutorial_prompt(snapshot, [&"talk"])
    assert_ne(prompt.get("id", &""), &"talk")
    assert_false(snapshot["tutorial"][&"talk"])

func test_rain_never_offers_manual_water_prompt() -> void:
    var snapshot := _snapshot_with_immature_unwatered_crop()
    snapshot["weather"] = &"rainy"
    assert_ne(
        ContentRules.next_tutorial_prompt(snapshot).get("id", &""),
        &"water",
    )
```

Use small test-local snapshot builders. Do not add production fixture APIs.

Also cover mature crop -> `harvest`, harvested inventory -> `shipping`/`gift`, Day 2 affordability -> `buy_seeds`, and `{}` when no incomplete relevant prompt exists.

- [ ] **Step 4: Implement explicit relevance predicates and one ordered selector**

Implement `next_tutorial_prompt()` as a straight scan of `TUTORIAL_KEYS` with concrete helper predicates. Keep state inspection readable; do not build predicate objects or a DSL.

Return only:

```gdscript
{
    "id": &"farm_basics",
    "title": "Prepare the soil",
    "body": "Face a farm diamond until the gold outline appears. Press 1 for Hoe, then Space.",
}
```

for an eligible prompt, otherwise `{}`.

- [ ] **Step 5: Write RED result-tier boundary tests**

Build terminal dictionaries from `GameSession.new().state()` and override only the facts consumed by the pure evaluator. Pin exact boundaries:

```gdscript
func test_new_beginning_below_promising_boundaries() -> void:
    var state := _terminal_state_with_shipped_value_below(150)
    assert_eq(ContentRules.build_harvest_result(state)["tier"], &"new_beginning")

func test_promising_at_exact_150g() -> void:
    var state := _terminal_state_for_counts([0, 2, 0]) # 150G
    assert_eq(ContentRules.build_harvest_result(state)["tier"], &"promising_farmer")

func test_heart_requires_300g_and_close_friend() -> void:
    var farming_only := _terminal_state_for_counts([0, 4, 0]) # 300G
    assert_eq(ContentRules.build_harvest_result(farming_only)["tier"], &"promising_farmer")
    farming_only["relationships"][&"resident"]["points"] = VillagerRules.CLOSE_FRIEND_POINTS
    assert_eq(ContentRules.build_harvest_result(farming_only)["tier"], &"heart_of_harvest")
```

Also pin Promising via `Friend` with farming below 150G and New Beginning as the fallback.

- [ ] **Step 6: Add the three-by-three villager finale table and result derivation**

Extend `VillagerRules` beside existing dialogue/gift tables:

```gdscript
const FINALE_LINES: Array = [
    [
        "You gave the farm a real beginning.",
        "You found your rhythm here. Keep it.",
        "The market feels right with you standing here.",
    ],
    [
        "A first harvest is still a harvest.",
        "Your fields are becoming dependable.",
        "I knew you would make this place yours.",
    ],
    [
        "You made it to market. That matters.",
        "The village noticed how much you changed.",
        "I told you: you are one of us now.",
    ],
]

static func finale_line(id: VillagerId, level: RelationshipLevel) -> String:
    return FINALE_LINES[id][level]
```

Implement `ContentRules.build_harvest_result(state)` by deriving:

- shipped count/value from `state["shipped"]` and `GameRules.sale_value()`;
- relationship levels from persisted points;
- three villager lines through `VillagerRules.finale_line()`;
- final money directly from state;
- tier/title from the exact 150/300G rules.

Do not persist a score or derived result object.

- [ ] **Step 7: Run GREEN and commit Task 1**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
git add scripts/game/content_rules.gd scripts/game/villager_rules.gd \
  tests/unit/test_content_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: add Phoenix content and finale rules"
```

---

### Task 2: Make onboarding progress, lifetime shipping, and the finale authoritative

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd` only if the current canonical round-trip does not already cover the nested tutorial dictionary after state changes

**Interfaces:**
- Four new persisted `GameSession.state()` fields
- `GameSession.acknowledge_intro()`
- `GameSession.trigger_harvest_finale(target_cell)`
- One private tutorial completion helper
- One private `_settle_pending_shipment()`
- One private `_complete_finale()`

- [ ] **Step 1: Write RED starter-state/isolation/validation tests**

Extend the exact state/snapshot tests first. New-session assertions include:

```gdscript
assert_false(snapshot["intro_acknowledged"])
assert_eq(snapshot["tutorial"], ContentRules.initial_tutorial_progress())
assert_eq(snapshot["shipped"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
assert_false(snapshot["finale_triggered"])
```

Update the pinned snapshot size/key order once, not through loose `has()` assertions.

Add invalid candidates for:

- missing each new field;
- non-boolean intro/finale flags;
- missing/extra tutorial key;
- non-boolean tutorial value;
- negative shipped count;
- `finale_triggered == true` before Day 14;
- triggered finale with a morning summary;
- triggered finale with a non-empty pending shipment.

Run GUT and confirm RED.

- [ ] **Step 2: Add exact state fields and canonical restore**

Add to `GameSession`:

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

Extend `state()`/`snapshot()` directly. Add narrow validator helpers for the tutorial dictionary, reuse `_counts_state_error()` for `shipped`, and canonicalize JSON String keys during restore. Do not change `SaveFileCodec` gameplay semantics.

Run GREEN for starter/validation/restore tests before continuing.

- [ ] **Step 3: Write RED tests proving completion only follows successful commands**

Use public commands and pin both success and failure:

```gdscript
func test_failed_farm_command_does_not_complete_tutorial() -> void:
    var session := GameSession.new()
    assert_eq(session.hoe(Vector2i(0, 0)), GameRules.CommandCode.NOT_FARM_CELL)
    assert_false(session.state()["tutorial"][&"farm_basics"])

func test_successful_farm_commands_complete_their_steps() -> void:
    var session := GameSession.new()
    var cell := WorldContract.farm_cells()[0]
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_true(session.state()["tutorial"][&"farm_basics"])
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_true(session.state()["tutorial"][&"plant"])
```

Cover Water, normal Day 1 sleep, Talk, Buy Seeds, Harvest, Deposit, and Gift through their existing public methods. Selecting an action/seed must not complete anything.

- [ ] **Step 4: Add intro acknowledgement and direct success mapping**

Add command codes:

```gdscript
INTRO_ACKNOWLEDGED,
INTRO_ALREADY_ACKNOWLEDGED,
FINALE_TRIGGERED,
MARKET_NOT_READY,
NOT_AT_MARKET,
FINALE_ALREADY_TRIGGERED,
```

Add:

```gdscript
func acknowledge_intro() -> GameRules.CommandCode:
    if _intro_acknowledged:
        return GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED
    _intro_acknowledged = true
    return GameRules.CommandCode.INTRO_ACKNOWLEDGED
```

Implement one private `GameSession` mapping helper and invoke it only after successful mutations. Do not route normal command results through a new dispatcher solely for tutorial bookkeeping.

- [ ] **Step 5: Write RED tests for cumulative settlement across normal sleeps**

Seed/grow/ship through public commands where practical and prove:

```gdscript
assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
assert_eq(session.state()["pending_shipment"][&"turnip"], 0)
assert_eq(session.state()["shipped"][&"turnip"], 1)
```

Run another shipment/night and assert lifetime `shipped` accumulates while the morning summary still contains only that night's settlement.

- [ ] **Step 6: Extract one settlement helper without changing Day 1–13 behavior**

Refactor current `sleep()` payment code into:

```gdscript
func _settle_pending_shipment() -> Dictionary:
    var pending := _counts_snapshot(_pending_shipment_counts)
    var payout := GameRules.shipment_payout(pending)
    for kind in range(GameRules.CropKind.size()):
        _shipped_counts[kind] += _pending_shipment_counts[kind]
    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    return payout
```

Use this exact helper from normal sleep. Preserve current crop growth, next-weather, stamina/time reset, morning-summary shape, and daily relationship reset.

- [ ] **Step 7: Write RED tests for the Day 14 terminal boundary**

Replace the existing `DAY_LIMIT_REACHED` characterization with terminal assertions. A narrow test helper may seed `_day`, `_pending_shipment_counts`, and relationship points, but immediately assert the seeded state before calling public commands.

Cover:

```gdscript
func test_market_cannot_finish_before_day_fourteen() -> void:
    var session := GameSession.new()
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.MARKET_NOT_READY,
    )

func test_day_fourteen_sleep_settles_once_without_day_fifteen() -> void:
    var session := _day_fourteen_session_with_pending_turnip()
    var weather_calls := 0
    session.set("_weather_roll", func() -> float:
        weather_calls += 1
        return 0.1
    )

    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.FINALE_TRIGGERED)
    var state := session.state()
    assert_eq(state["day"], GameRules.MAX_DAY)
    assert_true(state["finale_triggered"])
    assert_eq(state["pending_shipment"][&"turnip"], 0)
    assert_eq(state["shipped"][&"turnip"], 1)
    assert_eq(weather_calls, 0)
    assert_null(state["pending_morning_summary"])
```

Add equivalent market-trigger assertions, off-target failure, duplicate calls, unchanged crop growth/time/stamina/social daily flags on finalization, and terminal `_active_day_failure()` behavior.

- [ ] **Step 8: Implement one shared terminal transaction and remove the temporary Day 14 code**

Add `trigger_harvest_finale(target_cell)` and `_complete_finale()` exactly as specified. In `sleep()`, after validating the bed target:

```gdscript
if _day == GameRules.MAX_DAY:
    return _complete_finale()
```

`_complete_finale()` calls `_settle_pending_shipment()`, flips `_finale_triggered`, and does nothing else.

Update `_active_day_failure()` so a completed session returns `FINALE_ALREADY_TRIGGERED` before normal commands mutate anything.

Remove `DAY_LIMIT_REACHED` from `GameRules.CommandCode` and tests once no production path references it.

- [ ] **Step 9: Prove save transport remains generic and commit Task 2**

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git grep -n "DAY_LIMIT_REACHED" -- . ':!docs/superpowers/**'
git diff --check
```

Expected: GUT green; no live `DAY_LIMIT_REACHED` reference.

If `test_save_file.gd` already round-trips arbitrary nested dictionaries, do not add redundant codec tests. If not, add one encode/decode -> `GameSession.restore_state()` test with a completed tutorial flag and nonzero `shipped` count; do not teach `SaveFileCodec` field names.

Commit:

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd \
  tests/unit/test_game_session.gd tests/unit/test_save_file.gd
git commit -m "feat: add authoritative onboarding and finale state"
```

---

### Task 3: Author the market and contextual onboarding UI on existing world seams

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `assets/sprites/proof-scenery.png`
- Modify: `assets/sprites/proof-scenery.png.import` only through normal Godot import metadata if Godot changes it
- Create: `scenes/ui/onboarding_overlay.tscn`
- Create: `scripts/ui/onboarding_overlay.gd`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`

**Interfaces:**
- `WorldContract.MARKET_CELL`, `MARKET_FOOTPRINT`, `MARKET_ANCHOR`
- `OnboardingOverlay.intro_acknowledged`
- `OnboardingOverlay.blocking_state_changed`
- `GameHud.intro_acknowledged`
- existing `GameHud.has_blocking_modal()` remains the input gate

- [ ] **Step 1: Write RED world-contract tests before editing the scene**

In `test_gameplay_shell.gd` and the headless smoke pin:

```gdscript
assert_eq(WorldContract.MARKET_CELL, Vector2i(8, 6))
assert_eq(WorldContract.MARKET_FOOTPRINT, Rect2(8.2, 6.2, 0.6, 0.6))
assert_eq(WorldContract.MARKET_ANCHOR, Vector2(448.0, 240.0))
```

Update the entity arithmetic expectation to `8 + WorldContract.farm_cells().size()` and crop root offset to `8 + index` only in the RED test first.

Also assert the market root is a direct `Entities` child at `MARKET_ANCHOR`, uses the scenery sheet fourth frame, and has one collision polygon derived from `MARKET_FOOTPRINT`.

Run scene/integration tests and confirm RED.

- [ ] **Step 2: Add the authored market with no world abstraction changes**

Add the three constants to `WorldContract`.

Extend `proof-scenery.png` horizontally with one simple fourth 96×96 proof-quality market-stall frame. Keep transparent background, bottom-center ground contact, and the existing pixel-art visual language. Do not add an asset generator or generic scenery definition system for this one frame.

In `world.tscn`:

- change Tree/Building/Shipping scenery sprites to `hframes = 4` while preserving their existing frame indices 0/1/2;
- add `HarvestMarketCollision` under `StaticCollision`;
- add direct `Entities/HarvestMarket` at `Vector2(448, 240)` with frame 3 and the same `offset = Vector2(0, -48)` convention;
- leave `Entities` as the only Y-sort-enabled node.

In `WorldShell._ready()`, derive the market collision polygon with the same `WorldMath.footprint_to_polygon()` path used by current authored scenery.

Do not modify `FarmView`; it already resolves crops by name.

- [ ] **Step 3: Write RED tests for opening and contextual card behavior**

Pin the important UI contract, not pixel positions:

```gdscript
func test_fresh_world_opening_blocks_until_authoritative_acknowledgement() -> void:
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

Also test:

- tutorial card appears after intro;
- dismissing the card does not mutate session tutorial flags;
- tutorial card visibility does not block movement/tools/interact;
- successful `SOIL_TILLED` refresh removes/completes `farm_basics` and exposes the next relevant prompt;
- a restored state with `intro_acknowledged == true` never reopens the introduction.

- [ ] **Step 4: Implement one focused `OnboardingOverlay` Control scene**

`onboarding_overlay.gd` owns only UI/transient dismissal state:

```gdscript
class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

var _dismissed: Array[StringName] = []
var _last_snapshot: Dictionary = {}

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    _render_opening(not bool(snapshot["intro_acknowledged"]))
    _render_tutorial(ContentRules.next_tutorial_prompt(snapshot, _dismissed))
```

The opening panel is mouse-blocking and the tutorial card is non-blocking. `Dismiss` appends only the current prompt ID to `_dismissed` and rerenders; it never touches `GameSession`.

Instance this scene once under `GameHud/HudRoot`. Do not build a tutorial manager.

- [ ] **Step 5: Wire opening into the existing HUD/world input gate**

Add `signal intro_acknowledged` to `GameHud`. Forward `OnboardingOverlay.intro_acknowledged`; include the opening panel in `has_blocking_modal()`; keep the tutorial card out.

In `WorldShell._ready()` connect the signal. Handler:

```gdscript
func _on_intro_acknowledged() -> void:
    _finish_command(_session.acknowledge_intro())
```

The normal refresh path rerenders the overlay and releases the existing input gate. Do not add a second boolean lock for tutorial state.

- [ ] **Step 6: Add the persistent objective and market hint/routing boundary**

Add one HUD objective label and render:

```text
Harvest Market: Day 14 · 13 days left
```

through Day 13, and:

```text
Harvest Market today — village path stall
```

on Day 14.

Replace the old Day 14 warnings with:

```text
Day 14 shipment settles when the finale starts.
Day 14: sleeping ends the run and settles the final shipment.
```

In `WorldShell._process()`, targeting `MARKET_CELL` shows `Harvest Market — E`.

In `interact()`, route the market cell to `GameSession.trigger_harvest_finale(target)` before the generic `NOTHING_TO_INTERACT` fallback. For Task 3, nonterminal failure feedback is enough; terminal handoff is completed in Task 4.

Add `GameHud.show_feedback()` copy for the new intro/finale/market command codes and remove old Day 14 limit copy.

- [ ] **Step 7: Run GREEN world/UI verification and commit Task 3**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

Commit the authored asset/resource/scene/script/test changes together:

```bash
git add assets/sprites/proof-scenery.png assets/sprites/proof-scenery.png.import \
  scenes/world/world.tscn scenes/ui/game_hud.tscn scenes/ui/onboarding_overlay.tscn \
  scripts/world/world_contract.gd scripts/world/world_shell.gd \
  scripts/ui/game_hud.gd scripts/ui/onboarding_overlay.gd \
  tests/integration/test_gameplay_shell.gd tests/headless/world_shell_smoke.gd
git commit -m "feat: add harvest market and contextual onboarding"
```

If Godot does not change `proof-scenery.png.import`, do not touch it merely to satisfy the file list.

---

### Task 4: Route terminal completion through one final save to `ResultScreen`

**Files:**
- Create: `scenes/ui/result_screen.tscn`
- Create: `scripts/ui/result_screen.gd`
- Modify: `scenes/app/app.tscn`
- Modify: `scripts/app/app_root.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_app_launch.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`

**Interfaces:**
- `WorldShell.finale_completed(final_state, save_error)`
- `ResultScreen.present(result, save_error)`
- `ResultScreen.new_game_requested`
- `ResultScreen.return_to_title_requested`
- completed Continue route in `AppRoot`

- [ ] **Step 1: Write RED AppRoot tests for completed Continue**

Create a valid terminal state through the narrow test fixture: seed Day 14/pending shipment, call public `sleep()` or `trigger_harvest_finale()`, save the resulting `GameSession.state()`, then spawn the real app.

Pin:

```gdscript
func test_completed_continue_opens_result_without_world() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var completed := _completed_state()
    assert_eq(repository.save(completed), OK)

    var app := _spawn_app(repository)
    var title := app.get_node("TitleScreen") as TitleScreen
    title.continue_requested.emit()
    await get_tree().process_frame

    assert_null(app.get_node_or_null("World"))
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_true(result.visible)
```

Also assert tier title/summary uses `ContentRules.build_harvest_result(completed)` rather than duplicated UI scoring.

- [ ] **Step 2: Add presentation-only `ResultScreen`**

Author `result_screen.tscn` like the current `TitleScreen`: fixed labels, two buttons, hidden by default.

`result_screen.gd` exposes:

```gdscript
class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

func present(result: Dictionary, save_error: int = OK) -> void:
    # Fill labels only; no file/session access.
    visible = true
```

Render tier/title, shipped count/value, final money, relationship summary, exactly one line each from Mira/Rowan/June, and a short final-save failure message when `save_error != OK`.

- [ ] **Step 3: Add ResultScreen as a static AppRoot sibling**

Instance `ResultScreen` in `scenes/app/app.tscn` beside `TitleScreen` and keep it hidden initially.

Update `AppRoot._launch(initial_state)`:

```gdscript
if initial_state != null and bool(initial_state.get("finale_triggered", false)):
    _show_result(initial_state, OK)
    return
```

`_show_result(state, save_error)` derives once through `ContentRules.build_harvest_result(state)`, removes any live `World`, hides title, and presents result.

Connect result buttons:

- New Game -> hide result -> `_launch(null)`; do not delete slot;
- Return to Title -> hide result -> show title -> `_load_title_state()` again.

Keep `TitleScreen` presentation-only.

- [ ] **Step 4: Write RED tests for one final save and duplicate protection**

Extend `CountingSaveRepository` coverage. Prove both terminal routes independently:

1. Day 14 market interaction -> exactly one repository save -> `finale_completed` -> result;
2. Day 14 sleep fallback -> exactly one repository save -> same terminal state/result for the same seeded pre-final state;
3. a second terminal signal/call cannot increment `save_calls` because `GameSession` returns `FINALE_ALREADY_TRIGGERED`.

Compare canonical terminal state, not scene timing:

```gdscript
assert_eq(market_terminal["day"], GameRules.MAX_DAY)
assert_eq(market_terminal["pending_shipment"], sleep_terminal["pending_shipment"])
assert_eq(market_terminal["shipped"], sleep_terminal["shipped"])
assert_eq(market_terminal["money"], sleep_terminal["money"])
assert_eq(
    ContentRules.build_harvest_result(market_terminal),
    ContentRules.build_harvest_result(sleep_terminal),
)
```

- [ ] **Step 5: Implement exactly one `WorldShell` terminal handoff**

Add:

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

Add `_finish_finale(code)` and call it from both:

- market interaction when `trigger_harvest_finale()` returns `FINALE_TRIGGERED`;
- `_on_sleep_requested()` when `sleep()` returns `FINALE_TRIGGERED`.

Implementation shape:

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

Do not add `await`, a save queue, reentrancy flag, or second final-state object.

Connect `world.finale_completed` in `AppRoot` immediately after instantiation and route to `_show_result()`.

Normal `DAY_ADVANCED` path keeps its existing `Saved.`/morning-summary status behavior.

- [ ] **Step 6: Prove final-save failure keeps the ending and commit Task 4**

Use the existing unwritable/missing-directory repository style. Assert:

- session is terminal;
- result screen is visible;
- result screen reports final save failure;
- there is no world rollback;
- returning to title reloads whatever prior valid slot actually exists.

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
```

Commit:

```bash
git add scenes/app/app.tscn scenes/ui/result_screen.tscn \
  scripts/app/app_root.gd scripts/ui/result_screen.gd scripts/world/world_shell.gd \
  tests/integration/test_app_launch.gd tests/integration/test_gameplay_shell.gd \
  tests/integration/test_persistence_flow.gd
git commit -m "feat: add terminal harvest result flow"
```

---

### Task 5: Prove save/continue, the full slice, and repository handoff

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: existing tests only if the acceptance pass reveals a missing contract; do not create a new framework

**Acceptance:** one normal command-driven path plus focused terminal boundary tests demonstrate the complete HPA-597 behavior.

- [ ] **Step 1: Add one command-driven onboarding/persistence acceptance path**

Extend the existing persistence-flow fixture rather than making a new E2E harness. The path should:

1. start a fresh session/world;
2. acknowledge the opening through the real UI signal/button;
3. hoe/plant/water successfully and observe those tutorial flags complete;
4. sleep and save;
5. close/reopen/Continue;
6. prove intro/tutorial/shipped state restored canonically;
7. continue enough existing command-driven crop/social setup to harvest, talk, gift, and ship;
8. save again through normal sleep;
9. prove lifetime shipped counts survive another Continue.

Do not require thirteen literal UI-played sleeps just to reach the Day 14 boundary; focused Task 2/4 tests already prove that boundary.

- [ ] **Step 2: Add the final completed-save reopen assertion**

From a validated terminal state saved through the real `WorldShell` final handoff:

```gdscript
var restored_app := APP_SCENE.instantiate() as AppRoot
restored_app.configure(repository)
add_child_autoqfree(restored_app)
var restored_title := restored_app.get_node("TitleScreen") as TitleScreen
restored_title.continue_requested.emit()
await get_tree().process_frame

assert_null(restored_app.get_node_or_null("World"))
assert_true((restored_app.get_node("ResultScreen") as ResultScreen).visible)
```

This is the required no-post-game contract.

- [ ] **Step 3: Update player-facing README**

Document only behavior players/operators need:

- short opening and dismissible contextual help;
- Day 14 market objective;
- market `E` interaction and Day 14 sleep fallback;
- three encouraging result tiers;
- completed Continue returns to result;
- no post-game/free-play.

Do not document internal thresholds as player promises unless the existing README already exposes balance internals.

- [ ] **Step 4: Update `CLAUDE.md` architecture/handoff**

Record:

- `ContentRules` is pure content/policy; `GameSession` remains the only mutable authority;
- exact persisted content fields and no-migration policy;
- `WorldContract.MARKET_*` ownership and Y-sort scene convention;
- opening uses the existing `GameHud.has_blocking_modal()` gate; tutorial card is non-blocking;
- normal sleep/finale share shipment settlement;
- market/sleep share finalization;
- `WorldShell` owns final synchronous save handoff;
- `AppRoot` owns terminal ResultScreen routing, including completed Continue;
- HPA-599 is next and owns deliberate balance/polish/export verification.

Keep `AGENTS.md` untouched as a symlink.

- [ ] **Step 5: Run the full worktree suite before the final commit**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

Expected: all green.

- [ ] **Step 6: Commit documentation/acceptance changes**

```bash
git add README.md CLAUDE.md tests
git commit -m "docs: finish HPA-597 content slice handoff"
```

If no test file changed in Task 5, omit `tests` from the commit rather than touching tests needlessly.

- [ ] **Step 7: Run the committed clean-archive gate**

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected:

- verifier succeeds from committed `HEAD`;
- diff check is clean;
- worktree is clean apart from intentionally gitignored local GUT;
- `git diff --name-only main...HEAD` contains only HPA-597 planning/implementation/docs/assets/tests;
- no JavaScript/Tauri/browser runtime files return.

- [ ] **Step 8: Manual macOS release sanity check only after automated gates**

Use the existing HPA-598 export preset/templates; do not add new release automation in HPA-597:

```bash
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-597.app
```

Open the exported app and verify the bounded human checklist:

1. title -> New Game;
2. opening appears and blocks movement until Start;
3. first contextual card appears and can be dismissed without blocking play;
4. Day 14 objective copy is visible in a seeded/manual acceptance run;
5. market interaction or Day 14 sleep reaches a result screen;
6. quit/reopen -> Continue on completed slot returns directly to result;
7. Result -> New Game starts a fresh run;
8. Result -> Return to Title shows the title and current Continue state.

Packaging/signing/polish beyond this sanity check belongs to HPA-599.

---

## Done definition

HPA-597 is done only when all of the following are true in this one PR:

- fresh play has a short authoritative opening and contextual, dismissible, non-blocking help;
- tutorial flags complete only from successful gameplay commands and survive save/continue;
- lifetime shipped counts are authoritative and survive multiple nights/save round trips;
- the harvest market is an authored world interaction on the existing isometric/Y-sort seam;
- Day 14 market and Day 14 sleep share one deterministic finalization transaction;
- pending final shipping settles exactly once and no path reaches Day 15;
- all three result tiers and exact thresholds have direct pure tests;
- poor play always yields New Beginning, never game over;
- final state is saved once through the existing repository path;
- final save failure does not undo the ending;
- completed Continue opens `ResultScreen` directly with no gameplay world/post-game mode;
- `README.md`/`CLAUDE.md` describe the shipped flow;
- `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass.
