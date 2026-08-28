# Phoenix HPA-599 Release Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phoenix’s 14-day MVP with truthful/readable farming feedback, a minimal HUD/help/audio polish pass, an unsigned macOS CI export, and one verified packaged playthrough without expanding the game.

**Architecture:** Keep the current ownership model. `GameSession` remains the only gameplay authority; `WorldShell` coordinates; `PlayerController`, `FarmView`, and `GameHud` render. GUT remains the broad release oracle while GdUnit4/godot-e2e stay focused parallel lanes. Add no generic polish, feedback, audio, settings, pause, or rendering framework.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, GitHub Actions, Godot macOS export templates.

**Spec:** `docs/superpowers/specs/2026-08-27-phoenix-release-closeout-design.md`

## Global Constraints

- One Linear ticket, one branch, one PR. Continue implementation on `agent/hpa-599-release-closeout-plan`; do not open a second HPA-599 PR.
- No new crops, villagers, maps, tools, quests, endings, post-game, save schema, or migration layer.
- Keep current balance constants unless an automated/package acceptance check exposes a concrete defect.
- Do not migrate GUT to GdUnit4 and do not add a 14-day UI automation harness.
- No feedback/event bus, audio manager, settings screen, generic pause manager, renderer abstraction, shader/post-processing layer, or second gameplay state.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Farm targets use green/red preview; non-farm targets stay gold.
- The authored world has no fence entity; do not create one for a checklist-only depth test.
- No signing, notarization, DMG, installer, updater, release publishing, or macOS runner solely for export.

---

## Task 1: Share farm-action guards, preview them, and make Day-1 targeting truthful

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/game/content_rules.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_content_rules.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces: `GameSession.preview_selected_action(target_cell: Variant) -> GameRules.CommandCode`
- Produces: `GameHud.feedback_text(code: GameRules.CommandCode) -> String`
- Produces: `PlayerController.set_target_action_validity(validity: Variant) -> void`, where `null = gold`, `true = green`, `false = red`.
- Reuses: `_active_day_failure()`, `_target_failure()`, `GameRules.evaluate_action_budget()`, `InteractionHint`, and `TargetHighlight`.

### 1.1 RED — put preview/atomicity in the GUT release oracle

- [ ] Add these tests beside the current farming guard tests in `tests/unit/test_game_session.gd`. Do not add a preview duplicate under `tests/gdunit/`.

```gdscript
func test_preview_selected_action_matches_hoe_and_plant_guards_without_mutation() -> void:
    var session := GameSession.new()

    var before := session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.SOIL_TILLED,
    )
    assert_eq(session.state(), before)

    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    before = session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.ALREADY_TILLED,
    )
    assert_eq(session.state(), before)

    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    before = session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_PLANTED,
    )
    assert_eq(session.state(), before)

    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    before = session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.NO_SELECTED_SEEDS,
    )
    assert_eq(session.state(), before)


func test_preview_selected_action_matches_water_guards_without_mutation() -> void:
    var session := GameSession.new()
    _plant_turnip(session)
    assert_eq(
        session.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )

    var before := session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_WATERED,
    )
    assert_eq(session.state(), before)

    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    before = session.state()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.ALREADY_WATERED,
    )
    assert_eq(session.state(), before)


func test_preview_selected_action_matches_harvest_guards_without_mutation() -> void:
    var immature := GameSession.new()
    _plant_turnip(immature)
    assert_eq(
        immature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    var before := immature.state()
    assert_eq(
        immature.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_IMMATURE,
    )
    assert_eq(immature.state(), before)

    var mature := GameSession.new(func() -> float: return 0.9)
    _mature_turnip(mature)
    assert_eq(
        mature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    before = mature.state()
    assert_eq(
        mature.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_HARVESTED,
    )
    assert_eq(mature.state(), before)


func test_preview_selected_action_matches_budget_failure_without_mutation() -> void:
    var session := GameSession.new()
    var cells := WorldContract.farm_cells()
    for index in 6:
        assert_eq(session.hoe(cells[index]), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.snapshot()["stamina"], 2)
    assert_eq(
        session.select_action(GameRules.FarmingAction.HOE),
        GameRules.CommandCode.ACTION_SELECTED,
    )

    var before := session.state()
    assert_eq(
        session.preview_selected_action(cells[6]),
        GameRules.CommandCode.INSUFFICIENT_STAMINA,
    )
    assert_eq(session.state(), before)
```

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** GUT fails because `preview_selected_action()` does not exist.

### 1.2 GREEN — factor the existing four command guard paths once

- [ ] Add these private read-only helpers in `scripts/game/game_session.gd`. Preserve the existing guard order exactly.

```gdscript
func _hoe_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if bool(tile["tilled"]):
        return GameRules.CommandCode.ALREADY_TILLED
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.HOE,
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])


func _plant_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if not bool(tile["tilled"]):
        return GameRules.CommandCode.SOIL_UNTILLED
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if _seed_counts[_selected_seed] == 0:
        return GameRules.CommandCode.NO_SELECTED_SEEDS
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.SEEDS,
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])


func _water_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if tile["crop"] == null:
        return GameRules.CommandCode.NO_CROP
    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    if GameRules.is_mature(kind, int(crop["growth"])):
        return GameRules.CommandCode.CROP_MATURE
    if _weather == GameRules.Weather.RAINY:
        return GameRules.CommandCode.RAIN_WATERS_CROPS
    if bool(crop["watered_today"]):
        return GameRules.CommandCode.ALREADY_WATERED
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.WATERING_CAN,
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])


func _harvest_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if tile["crop"] == null:
        return GameRules.CommandCode.NO_CROP
    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    if not GameRules.is_mature(kind, int(crop["growth"])):
        return GameRules.CommandCode.CROP_IMMATURE
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.HANDS,
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])


func _selected_action_failure(target_cell: Variant) -> int:
    match _selected_action:
        GameRules.FarmingAction.HOE:
            return _hoe_failure(target_cell)
        GameRules.FarmingAction.SEEDS:
            return _plant_failure(target_cell)
        GameRules.FarmingAction.WATERING_CAN:
            return _water_failure(target_cell)
        GameRules.FarmingAction.HANDS:
            return _harvest_failure(target_cell)
    assert(false, "unsupported farming action")
    return GameRules.CommandCode.NO_TARGET
```

- [ ] At the top of each public mutating command, replace its existing guard block with the corresponding helper:

```gdscript
func hoe(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _hoe_failure(target_cell)
    if failure != -1:
        return failure
    # Keep the existing tile mutation, budget commit, and _commit(SOIL_TILLED).
```

```gdscript
func plant(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _plant_failure(target_cell)
    if failure != -1:
        return failure
    # Keep the existing crop creation, seed decrement, budget commit, and _commit(CROP_PLANTED).
```

```gdscript
func water(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _water_failure(target_cell)
    if failure != -1:
        return failure
    # Keep the existing watered_today mutation, budget commit, and _commit(CROP_WATERED).
```

```gdscript
func harvest(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _harvest_failure(target_cell)
    if failure != -1:
        return failure
    # Keep the existing crop removal, harvested-count increment, budget commit, and _commit(CROP_HARVESTED).
```

The comments above identify the exact existing mutation blocks to retain; do not change mutation order or command codes during this refactor.

- [ ] Add the read-only dispatcher:

```gdscript
func preview_selected_action(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _selected_action_failure(target_cell)
    if failure != -1:
        return failure
    match _selected_action:
        GameRules.FarmingAction.HOE:
            return GameRules.CommandCode.SOIL_TILLED
        GameRules.FarmingAction.SEEDS:
            return GameRules.CommandCode.CROP_PLANTED
        GameRules.FarmingAction.WATERING_CAN:
            return GameRules.CommandCode.CROP_WATERED
        GameRules.FarmingAction.HANDS:
            return GameRules.CommandCode.CROP_HARVESTED
    assert(false, "unsupported farming action")
    return GameRules.CommandCode.NO_TARGET
```

Do not clone a session and do not execute/rollback a real command.

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** all new preview cases plus existing farming guard/atomicity cases pass.

### 1.3 Extract the existing command-code sentence table for reuse

- [ ] Replace the current `show_feedback()` match in `scripts/ui/game_hud.gd` with this complete text function, preserving every existing sentence:

```gdscript
func feedback_text(code: GameRules.CommandCode) -> String:
    match code:
        GameRules.CommandCode.ACTION_SELECTED:
            return "Action selected."
        GameRules.CommandCode.SEED_SELECTED:
            return "Seed selected."
        GameRules.CommandCode.SOIL_TILLED:
            return "Soil tilled."
        GameRules.CommandCode.CROP_PLANTED:
            return "Crop planted."
        GameRules.CommandCode.CROP_WATERED:
            return "Crop watered."
        GameRules.CommandCode.CROP_HARVESTED:
            return "Crop harvested."
        GameRules.CommandCode.SEEDS_PURCHASED:
            return "Seeds purchased."
        GameRules.CommandCode.CROP_DEPOSITED:
            return "Crop deposited."
        GameRules.CommandCode.DAY_ADVANCED:
            return "Day advanced."
        GameRules.CommandCode.DAY_STARTED:
            return "Morning acknowledged."
        GameRules.CommandCode.NO_TARGET:
            return "No target."
        GameRules.CommandCode.NOT_FARM_CELL:
            return "That is not a farm cell."
        GameRules.CommandCode.ALREADY_TILLED:
            return "Soil is already tilled."
        GameRules.CommandCode.SOIL_UNTILLED:
            return "Till the soil first."
        GameRules.CommandCode.CROP_PRESENT:
            return "A crop is already there."
        GameRules.CommandCode.NO_SELECTED_SEEDS:
            return "No selected seeds."
        GameRules.CommandCode.NO_CROP:
            return "There is no crop there."
        GameRules.CommandCode.ALREADY_WATERED:
            return "Crop is already watered."
        GameRules.CommandCode.CROP_MATURE:
            return "Crop is mature."
        GameRules.CommandCode.CROP_IMMATURE:
            return "Crop is not mature."
        GameRules.CommandCode.NOT_AT_BED:
            return "Stand at the bed."
        GameRules.CommandCode.NOT_AT_SHOP:
            return "Stand at the shop."
        GameRules.CommandCode.NOT_AT_SHIPPING_BIN:
            return "Stand at the shipping bin."
        GameRules.CommandCode.INVALID_QUANTITY:
            return "Choose a positive quantity."
        GameRules.CommandCode.INSUFFICIENT_FUNDS:
            return "Not enough money."
        GameRules.CommandCode.INSUFFICIENT_CROPS:
            return "Not enough harvested crops."
        GameRules.CommandCode.ACTION_TOO_LATE:
            return "It is too late for that action."
        GameRules.CommandCode.INSUFFICIENT_STAMINA:
            return "Not enough stamina."
        GameRules.CommandCode.RAIN_WATERS_CROPS:
            return "Rain is watering the crops."
        GameRules.CommandCode.DAY_SUMMARY_PENDING:
            return "Acknowledge the morning summary first."
        GameRules.CommandCode.NO_DAY_SUMMARY:
            return "No morning summary."
        GameRules.CommandCode.FINALE_TRIGGERED:
            return "Harvest finale complete."
        GameRules.CommandCode.MARKET_NOT_READY:
            return "The Harvest Market opens on Day 14."
        GameRules.CommandCode.NOT_AT_MARKET:
            return "Stand at the Harvest Market."
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED:
            return "The harvest finale is already complete."
        GameRules.CommandCode.VILLAGER_TALKED:
            return "Talked to villager."
        GameRules.CommandCode.CROP_GIFTED:
            return "Gift given."
        GameRules.CommandCode.NOT_AT_VILLAGER:
            return "Stand at the villager."
        GameRules.CommandCode.GIFT_ALREADY_GIVEN:
            return "Gift already given today."
        GameRules.CommandCode.NOTHING_TO_INTERACT:
            return "Nothing to interact with."
        _:
            return ""


func show_feedback(code: GameRules.CommandCode) -> void:
    var text := feedback_text(code)
    if text != "":
        _feedback.text = text
```

Do not add a second pre-action error-message table.

### 1.4 RED/GREEN — green/red/gold target plus pre-action reason

- [ ] Add these presentation constants/setter to `PlayerController`:

```gdscript
const TARGET_NEUTRAL := Color(1.0, 0.85, 0.2, 0.9)
const TARGET_VALID := Color(0.35, 1.0, 0.45, 0.9)
const TARGET_INVALID := Color(1.0, 0.35, 0.35, 0.9)

func set_target_action_validity(validity: Variant) -> void:
    if target_highlight == null:
        return
    if validity == null:
        target_highlight.default_color = TARGET_NEUTRAL
    elif bool(validity):
        target_highlight.default_color = TARGET_VALID
    else:
        target_highlight.default_color = TARGET_INVALID
```

- [ ] Add this constant to `WorldShell`:

```gdscript
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]
```

- [ ] At the start of `WorldShell._process()` after resolving `target`, render farm preview before the existing non-farm interaction-hint chain:

```gdscript
if target is Vector2i and WorldContract.farm_cells().has(target):
    var preview := _session.preview_selected_action(target)
    var valid := FARM_ACTION_SUCCESS_CODES.has(preview)
    player.set_target_action_validity(valid)
    hud.set_interaction_hint(
        "Space — use selected action" if valid else hud.feedback_text(preview)
    )
    return

player.set_target_action_validity(null)
```

Then leave the current villager/shop/bed/shipping/market/empty hint chain unchanged so all non-farm targets remain gold.

- [ ] Add this integration path in `tests/integration/test_gameplay_shell.gd` using the existing `_place_target` helper:

```gdscript
func test_farm_target_preview_uses_green_red_reason_and_non_farm_gold() -> void:
    var world := _world()
    var hint := world.hud.get_node("HudRoot/InteractionHint") as Label
    var cell: Vector2i = WorldContract.farm_cells()[0]

    await _place_target(world, cell)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)
    assert_eq(hint.text, "Space — use selected action")

    world.use_selected_action()
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_INVALID)
    assert_eq(hint.text, "Soil is already tilled.")

    world.select_action_slot(2)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)
    assert_eq(hint.text, "Space — use selected action")

    await _place_target(world, WorldContract.SHOP_CELL)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq(hint.text, "Shop — E")
```

### 1.5 Fix and pin the Day-1 tutorial copy in the same task

- [ ] Change only the first `ContentRules.TUTORIALS` body:

```gdscript
"body": "Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.",
```

- [ ] Add this direct GUT assertion to `tests/unit/test_content_rules.gd`:

```gdscript
func test_farm_basics_copy_matches_target_validity_contract() -> void:
    assert_eq(
        ContentRules.TUTORIALS[0]["body"],
        "Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.",
    )
```

The current README has no “gold outline” tutorial sentence, so Task 1 does not need a README edit.

- [ ] Verify and commit:

```bash
./tools/verify-clean.sh
git diff --check
git add scripts/game/game_session.gd scripts/game/content_rules.gd \
  scripts/player/player_controller.gd scripts/world/world_shell.gd \
  scripts/ui/game_hud.gd tests/unit/test_game_session.gd \
  tests/unit/test_content_rules.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: preview farming action validity"
```

---

## Task 2: Build help in the existing HUD and close visual/depth readability gaps

**Files:**
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/farm_view.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scenes/world/world.tscn`
- Create: `assets/sprites/proof-shadow.png`
- Create after import: `assets/sprites/proof-shadow.png.import`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces: code-built `HudRoot/PauseHelp` with `Resume` child.
- Reuses: `_add_panel`, `_add_label`, `_add_button`, `modal_state_changed`, `has_blocking_modal()`, and `DialoguePanel`'s existing Esc ownership.
- Produces: one reused `proof-shadow.png` presentation asset.

### 2.1 RED — pin Esc ordering including intro and dialogue ownership

- [ ] Add this helper to `tests/integration/test_gameplay_shell.gd`:

```gdscript
func _cancel_event() -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"ui_cancel"
    event.pressed = true
    return event
```

- [ ] Add intro/help coverage:

```gdscript
func test_escape_does_not_open_help_over_blocking_intro() -> void:
    var world := _locked_world()
    var overlay := world.hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay
    assert_true(overlay.is_opening_visible())

    world.hud._unhandled_input(_cancel_event())

    assert_true(overlay.is_opening_visible())
    assert_false((world.hud.get_node("HudRoot/PauseHelp") as Control).visible)
    assert_false(world._world_input_enabled)


func test_escape_toggles_code_built_help_and_world_gate() -> void:
    var world := _world()
    var help := world.hud.get_node("HudRoot/PauseHelp") as Control
    assert_false(help.visible)
    assert_true(world._world_input_enabled)

    world.hud._unhandled_input(_cancel_event())
    assert_true(help.visible)
    assert_false(world._world_input_enabled)

    (help.get_node("Resume") as Button).pressed.emit()
    assert_false(help.visible)
    assert_true(world._world_input_enabled)
```

- [ ] Add one shop close assertion, one sleep close assertion, and one dialogue ownership assertion using the existing real modal open methods:

```gdscript
func test_escape_closes_existing_modal_before_help() -> void:
    var world := _world()
    var help := world.hud.get_node("HudRoot/PauseHelp") as Control

    world.hud.open_shop()
    world.hud._unhandled_input(_cancel_event())
    assert_false((world.hud.get_node("HudRoot/ShopPanel") as Control).visible)
    assert_false(help.visible)

    world.hud.open_sleep_confirmation()
    world.hud._unhandled_input(_cancel_event())
    assert_false((world.hud.get_node("HudRoot/SleepPanel") as Control).visible)
    assert_false(help.visible)
```

```gdscript
func test_game_hud_does_not_steal_escape_from_dialogue() -> void:
    var world := _world()
    var villager_id := VillagerRules.VillagerId.SHOPKEEPER
    var result := world._session.talk_to(
        villager_id,
        WorldContract.villager_cell(villager_id),
    )
    world.hud.open_dialogue(villager_id, result, world._session.snapshot())
    var dialogue := world.hud.get_node("HudRoot/DialoguePanel") as DialoguePanel
    var help := world.hud.get_node("HudRoot/PauseHelp") as Control

    world.hud._unhandled_input(_cancel_event())
    assert_true(dialogue.visible)
    assert_false(help.visible)

    dialogue._unhandled_input(_cancel_event())
    assert_false(dialogue.visible)
    assert_false(help.visible)
```

Keep the existing morning-summary Esc-lock coverage; add `assert_false(PauseHelp.visible)` there when the help node exists.

### 2.2 GREEN — code-build PauseHelp beside the current modal builders

- [ ] Add `_pause_help_panel: Control` to `GameHud`; build it in `_build_modals()` and hide it initially:

```gdscript
_pause_help_panel = _build_pause_help()
_pause_help_panel.visible = false
```

- [ ] Add the builder using only existing helpers:

```gdscript
func _build_pause_help() -> Control:
    var panel := _add_panel(
        _root,
        "PauseHelp",
        "Phoenix — Controls",
        Vector2(300, 62),
        Vector2(332, 220),
    )
    var body := _add_label(
        panel,
        "Body",
        "WASD — Move\n1 / 2 / 3 / 4 — Hoe / Seeds / Water / Hands\nSpace — Use selected action\nE — Interact\nEsc — Close / controls",
        Vector2(12, 34),
        Vector2(308, 132),
    )
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var resume := _add_button(
        panel,
        "Resume",
        "Resume",
        Vector2(236, 178),
        Vector2(78, 28),
    )
    resume.pressed.connect(func() -> void: _set_pause_help_visible(false))
    return panel


func _set_pause_help_visible(is_visible: bool) -> void:
    if _pause_help_panel.visible == is_visible:
        return
    _pause_help_panel.visible = is_visible
    modal_state_changed.emit()
```

- [ ] Include `_pause_help_panel.visible` in `has_blocking_modal()`.

- [ ] Replace `GameHud._unhandled_input()` with this exact ownership order:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    if _morning_summary_panel.visible or _onboarding_overlay.is_opening_visible():
        get_viewport().set_input_as_handled()
        return
    if _shop_panel.visible:
        close_shop()
    elif _shipping_panel.visible:
        close_shipping()
    elif _sleep_panel.visible:
        close_sleep_confirmation()
    elif _dialogue_panel.visible:
        return
    elif _pause_help_panel.visible:
        _set_pause_help_visible(false)
    else:
        _set_pause_help_visible(true)
    get_viewport().set_input_as_handled()
```

The dialogue branch intentionally returns unhandled so `DialoguePanel._unhandled_input()` keeps ownership of normal close and its existing unskippable close-friend sequence. Do not call `close_dialogue()` from this branch.

Do not call `get_tree().paused` and do not create `pause_help.tscn`.

### 2.3 RED/GREEN — add a subtle snapshot-derived weather tint

- [ ] Add these constants/field to `GameHud`:

```gdscript
const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)

var _weather_tint: ColorRect
```

- [ ] At the start of `_build_always_visible_hud()` create one full-screen non-interactive tint before ordinary HUD controls:

```gdscript
_weather_tint = ColorRect.new()
_weather_tint.name = "WeatherTint"
_weather_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
_weather_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
_weather_tint.z_index = -1
_root.add_child(_weather_tint)
```

- [ ] In `render(snapshot)` set exactly one of the two colors:

```gdscript
_weather_tint.color = (
    RAINY_TINT
    if snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
    else SUNNY_TINT
)
```

- [ ] Add one integration test covering both values:

```gdscript
func test_weather_tint_follows_snapshot_weather() -> void:
    var world := _world()
    var tint := world.hud.get_node("HudRoot/WeatherTint") as ColorRect
    var snapshot := world._session.snapshot()

    snapshot["weather"] = GameRules.weather_key(GameRules.Weather.RAINY)
    world.hud.render(snapshot)
    assert_eq(tint.color, GameHud.RAINY_TINT)

    snapshot["weather"] = GameRules.weather_key(GameRules.Weather.SUNNY)
    world.hud.render(snapshot)
    assert_eq(tint.color, GameHud.SUNNY_TINT)
```

### 2.4 RED/GREEN — one reused ground-shadow texture and exact smoke edits

- [ ] Generate `assets/sprites/proof-shadow.png` with a one-off Godot script; do not add a permanent generator dependency:

```bash
cat > /tmp/phoenix-shadow.gd <<'GDSCRIPT'
extends SceneTree

func _init() -> void:
    var image := Image.create_empty(32, 12, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    for y in range(12):
        for x in range(32):
            var dx := (float(x) - 15.5) / 15.5
            var dy := (float(y) - 5.5) / 5.5
            var radius := dx * dx + dy * dy
            if radius <= 1.0:
                image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.28 * (1.0 - radius)))
    assert(image.save_png("res://assets/sprites/proof-shadow.png") == OK)
    quit()
GDSCRIPT
godot --headless --path . --script /tmp/phoenix-shadow.gd
rm /tmp/phoenix-shadow.gd
godot --headless --path . --editor --quit
```

- [ ] Add a `Shadow` `Sprite2D` child using `proof-shadow.png` before the visible `Sprite2D` under:

```text
Entities/Tree
Entities/Building
Entities/Shipping
Entities/HarvestMarket
Entities/VillagerShopkeeper
Entities/VillagerFarmer
Entities/VillagerResident
Player
```

Do not change the root positions or shared z-index values.

- [ ] In `FarmView`, preload the same shadow texture, add `_crop_shadows: Dictionary`, and create each crop root with exact child order `Shadow`, then `Sprite2D`:

```gdscript
var shadow := Sprite2D.new()
shadow.name = "Shadow"
shadow.texture = SHADOW_TEXTURE
shadow.scale = Vector2(0.65, 0.65)
shadow.visible = false
crop_root.add_child(shadow)
_crop_shadows[cell] = shadow

var crop_sprite := Sprite2D.new()
crop_sprite.name = "Sprite2D"
# keep the existing crop texture/frame/offset configuration
crop_root.add_child(crop_sprite)
```

In `refresh(snapshot)`:

```gdscript
var crop_visible := tilled and crop_data != null
var shadow: Sprite2D = _crop_shadows[cell]
shadow.visible = crop_visible
crop.visible = crop_visible
```

- [ ] Update the existing **exact** `_expect_names` assertions in `tests/headless/world_shell_smoke.gd`:

```gdscript
# Tree/building/shipping/market loop:
_expect_names(entity, ["Shadow", "Sprite2D"], "%s entity" % entry.label)

# Villagers:
_expect_names(villager, ["Shadow", "Sprite2D"], "villager %d entity" % id)

# Dynamic crop roots:
_expect_names(crop_root, ["Shadow", "Sprite2D"], "crop %s" % cell)
```

Add direct `get_node_or_null("Shadow")` checks for the player and each entity category and assert every shadow texture path is `res://assets/sprites/proof-shadow.png`. Assert crop shadows start hidden. There is no current exact player child-name list to replace.

- [ ] Do not add a fence entity or screenshot/golden-image harness.

### 2.5 Document the art contract, verify, and commit

- [ ] Add this concise contract to `CLAUDE.md`:

```text
Sprite-isometric art contract
- Ground diamonds are 64×32.
- Entity root positions are bottom-center ground contacts.
- Visible sprites offset upward from their root.
- Shadows are child sprites on the ground plane, never Y-sort roots.
- Entities remains the only Y-sort owner for foreground/occluding world objects.
- Nearest filtering and integer scaling are mandatory.
```

- [ ] Run and commit:

```bash
./tools/verify-clean.sh
git diff --check
git add scripts/ui/game_hud.gd scripts/world/farm_view.gd \
  scenes/player/player.tscn scenes/world/world.tscn \
  assets/sprites/proof-shadow.png assets/sprites/proof-shadow.png.import \
  tests/integration/test_gameplay_shell.gd tests/headless/world_shell_smoke.gd \
  CLAUDE.md
git commit -m "feat: polish world readability and controls"
```

---

## Task 3: Add the minimal GameHud-owned placeholder audio pass

**Files:**
- Create: `assets/audio/action.wav`
- Create: `assets/audio/commerce.wav`
- Create: `assets/audio/social.wav`
- Create: `assets/audio/confirm.wav`
- Create: `assets/audio/cancel.wav`
- Create: `assets/audio/day-transition.wav`
- Create: `assets/audio/finale.wav`
- Create: `assets/audio/farm-day-loop.wav`
- Create: `assets/audio/README.md`
- Create after import: `assets/audio/*.wav.import`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces exactly two players: `GameHud/SfxPlayer`, `GameHud/MusicPlayer`.
- Reuses `GameHud.show_feedback()`/`feedback_text()` for command categories.
- No audio manager, bus abstraction, settings UI, or persisted volume state.

### 3.1 Generate project-owned placeholder WAVs

- [ ] Create eight mono PCM WAV files at 22,050 Hz using Python's standard library. Keep SFX under 250 ms and the music loop under 8 seconds:

```bash
python3 - <<'PY'
from pathlib import Path
import math, struct, wave

RATE = 22_050
OUT = Path("assets/audio")
OUT.mkdir(parents=True, exist_ok=True)

def tone(name, freqs, seconds, amp):
    count = int(RATE * seconds)
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = bytearray()
        for i in range(count):
            t = i / RATE
            edge = max(0.0, min(1.0, t / 0.015, (seconds - t) / 0.035))
            sample = sum(math.sin(2 * math.pi * hz * t) for hz in freqs) / len(freqs)
            value = int(max(-1.0, min(1.0, sample * amp * edge)) * 32767)
            frames.extend(struct.pack("<h", value))
        f.writeframes(frames)

tone("action.wav", (440, 660), 0.12, 0.18)
tone("commerce.wav", (660, 880), 0.16, 0.16)
tone("social.wav", (523.25, 659.25), 0.18, 0.14)
tone("confirm.wav", (784,), 0.09, 0.14)
tone("cancel.wav", (220,), 0.12, 0.14)
tone("day-transition.wav", (330, 440), 0.22, 0.12)
tone("finale.wav", (523.25, 659.25, 783.99), 0.24, 0.13)
tone("farm-day-loop.wav", (130.81, 164.81, 196.0), 6.0, 0.035)
PY
godot --headless --path . --editor --quit
```

- [ ] Add `assets/audio/README.md` exactly documenting project ownership:

```markdown
# Phoenix placeholder audio

These WAV files are project-generated placeholder tones created for the HPA-599 MVP closeout. They contain no externally sourced recording or composition and require no third-party attribution. They are intentionally disposable if authored audio replaces them later.
```

### 3.2 RED — pin player/stream wiring, not waveform bytes

- [ ] Add this integration coverage:

```gdscript
func test_hud_audio_players_and_representative_feedback_streams() -> void:
    var world := _world()
    var sfx := world.hud.get_node("SfxPlayer") as AudioStreamPlayer
    var music := world.hud.get_node("MusicPlayer") as AudioStreamPlayer
    assert_not_null(sfx)
    assert_not_null(music)
    assert_eq(music.stream.resource_path, "res://assets/audio/farm-day-loop.wav")

    world.hud.show_feedback(GameRules.CommandCode.SOIL_TILLED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/action.wav")
    world.hud.show_feedback(GameRules.CommandCode.SEEDS_PURCHASED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/commerce.wav")
    world.hud.show_feedback(GameRules.CommandCode.CROP_GIFTED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/social.wav")
    world.hud.show_feedback(GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/day-transition.wav")
    world.hud.show_feedback(GameRules.CommandCode.FINALE_TRIGGERED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/finale.wav")
    world.hud.show_feedback(GameRules.CommandCode.INSUFFICIENT_STAMINA)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/cancel.wav")
```

Do not assert speaker output, exact samples, or timing in CI.

### 3.3 GREEN — keep audio inside GameHud

- [ ] Add only `SfxPlayer` and `MusicPlayer` under `GameHud` in `scenes/ui/game_hud.tscn`. Set approximately `-8 dB` SFX and `-20 dB` music.

- [ ] Preload the eight streams in `game_hud.gd`. In `_ready()`, make a duplicated `AudioStreamWAV` for music, enable forward looping, assign it to `MusicPlayer`, and start it:

```gdscript
var music_stream := FARM_DAY_LOOP.duplicate() as AudioStreamWAV
music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
($MusicPlayer as AudioStreamPlayer).stream = music_stream
($MusicPlayer as AudioStreamPlayer).play()
```

- [ ] Add one selector. Map every farm/economy/social success to its category and every current farm/economy guard to `cancel.wav`:

```gdscript
func _sfx_for_code(code: GameRules.CommandCode) -> AudioStream:
    match code:
        GameRules.CommandCode.SOIL_TILLED, \
        GameRules.CommandCode.CROP_PLANTED, \
        GameRules.CommandCode.CROP_WATERED, \
        GameRules.CommandCode.CROP_HARVESTED:
            return ACTION_SFX
        GameRules.CommandCode.SEEDS_PURCHASED, GameRules.CommandCode.CROP_DEPOSITED:
            return COMMERCE_SFX
        GameRules.CommandCode.VILLAGER_TALKED, GameRules.CommandCode.CROP_GIFTED:
            return SOCIAL_SFX
        GameRules.CommandCode.DAY_ADVANCED, GameRules.CommandCode.DAY_STARTED:
            return DAY_TRANSITION_SFX
        GameRules.CommandCode.FINALE_TRIGGERED:
            return FINALE_SFX
        GameRules.CommandCode.NO_TARGET, \
        GameRules.CommandCode.NOT_FARM_CELL, \
        GameRules.CommandCode.ALREADY_TILLED, \
        GameRules.CommandCode.SOIL_UNTILLED, \
        GameRules.CommandCode.CROP_PRESENT, \
        GameRules.CommandCode.NO_SELECTED_SEEDS, \
        GameRules.CommandCode.NO_CROP, \
        GameRules.CommandCode.ALREADY_WATERED, \
        GameRules.CommandCode.CROP_MATURE, \
        GameRules.CommandCode.CROP_IMMATURE, \
        GameRules.CommandCode.INVALID_QUANTITY, \
        GameRules.CommandCode.INSUFFICIENT_FUNDS, \
        GameRules.CommandCode.INSUFFICIENT_CROPS, \
        GameRules.CommandCode.ACTION_TOO_LATE, \
        GameRules.CommandCode.INSUFFICIENT_STAMINA, \
        GameRules.CommandCode.RAIN_WATERS_CROPS:
            return CANCEL_SFX
        _:
            return null
```

- [ ] Extend `show_feedback(code)` after setting text:

```gdscript
var stream := _sfx_for_code(code)
if stream != null:
    _sfx_player.stream = stream
    _sfx_player.play()
```

Use the same `_sfx_player` for help/modal confirm/cancel and save status where a command code does not already cover the transition. Do not create more players or persistent volume state.

- [ ] Verify and commit:

```bash
./tools/verify-clean.sh
git diff --check
git add assets/audio scenes/ui/game_hud.tscn scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd
git commit -m "feat: add lightweight game audio feedback"
```

---

## Task 4: Make the existing CI job the unsigned macOS release gate

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `export_presets.cfg` only if the actual export command proves a missing release option is required.

**Interfaces:**
- Reuses existing `macOS` export preset.
- Produces CI artifact `Phoenix-macOS` containing `build/Phoenix.zip`.
- Uses the same checkout/setup SHAs and credential policy as the GdUnit4/e2e workflows.

### 4.1 Adopt the repository's existing action-pin convention

- [ ] Replace the two floating actions in `.github/workflows/ci.yml` with:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
  with:
    persist-credentials: false
- uses: chickensoft-games/setup-godot@f166999204a4f2722c6fe042fbaa3b3ea0d9c789 # v2.4.1
  with:
    version: 4.7.1
    use-dotnet: false
    include-templates: true
```

### 4.2 Add the existing preset as an unsigned ZIP release gate

- [ ] Keep `./tools/verify-clean.sh`, then add:

```yaml
- name: Export unsigned macOS build
  run: |
    mkdir -p build
    godot --headless --path . --export-release "macOS" build/Phoenix.zip
    unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"

- name: Upload macOS build
  uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
  with:
    name: Phoenix-macOS
    path: build/Phoenix.zip
    if-no-files-found: error
```

Do not add signing, notarization, DMG, a macOS runner, GitHub Release publishing, or deployment logic.

### 4.3 Verify and commit

- [ ] Run:

```bash
./tools/verify-clean.sh
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
git diff --check
```

**Expected:** clean verifier exits 0; export exits 0; ZIP contains the app executable.

- [ ] Commit:

```bash
git add .github/workflows/ci.yml
git diff --quiet -- export_presets.cfg || git add export_presets.cfg
git commit -m "ci: verify unsigned macOS export"
```

---

## Task 5: Run every release gate, perform one packaged 14-day run, and record only evidence-backed tuning

**Files:**
- Modify conditionally on observed evidence: `scripts/game/game_rules.gd`, `scripts/game/villager_rules.gd`, `scripts/game/content_rules.gd`, and their exact-value GUT tests.
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Update: PR #12 description/checklist with final evidence.

**Interfaces:**
- Release gate = clean GUT/headless + focused GdUnit4 + bounded godot-e2e + unsigned macOS export + one real packaged playthrough.
- Representative balance bar = `ContentRules.PROMISING_SHIPPED_VALUE` (`150G` shipped value); Heart is optional.

### 5.1 Run all four automated gates

- [ ] Run the clean GUT/headless oracle:

```bash
./tools/verify-clean.sh
```

- [ ] Run focused GdUnit4:

```bash
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

- [ ] Run bounded godot-e2e:

```bash
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

- [ ] Export the release candidate:

```bash
rm -f /tmp/Phoenix-HPA-599.zip
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record the exact pass counts/output summary in PR #12. Do not add duplicate tests merely to make the lanes symmetrical.

### 5.2 Perform one real packaged New Game → Day 14 run

- [ ] Unzip and launch the exported `.app`. Play without debug state/test hooks.

Record this checklist in PR #12:

```markdown
### Packaged 14-day acceptance
- [ ] Fresh player path works from title + intro without README instructions.
- [ ] Farm target is green when valid, red with a reason when invalid, and gold for non-farm/interactable targets.
- [ ] Hoe / plant / water / harvest have readable pre- and post-action feedback.
- [ ] Dry/wet soil and every crop stage are distinguishable at 1×.
- [ ] Purchase, shipping income, gift/relationship gain, sleep/wake/save, and finale cues are readable/audible.
- [ ] Tree, building, mature crop, and villager crossings preserve front/behind order.
- [ ] Default and smaller supported windows keep required controls visible and pixel art crisp.
- [ ] Continue restores a representative saved morning without UI/state desynchronization.
- [ ] Day 14 pre-finale Continue reaches the same terminal result path.
- [ ] Repeated input does not duplicate purchase, shipment, gift, day transition, save, or finale processing.
- [ ] Representative farming/reinvestment reaches shipped_value >= 150G (Promising Farmer). Heart is optional.
```

The acceptance bar is the observable `Promising Farmer` shipped-value threshold, not a subjective “satisfying” result.

### 5.3 Retune only across a defined defect bar

- [ ] Leave all release-candidate numbers unchanged unless at least one of these is observed in the packaged run:

1. A reasonable farming/reinvestment route cannot reach `shipped_value >= ContentRules.PROMISING_SHIPPED_VALUE`.
2. The player enters a forced economy dead-end that prevents continuing the intended farming loop.
3. A specific timing/threshold value causes a concrete usability defect that presentation alone cannot fix.

If a number changes, modify the owning constant and its exact GUT assertion in the same commit. Do not add a tuning table, difficulty layer, configuration resource, or compatibility branch.

### 5.4 Final player/developer documentation

- [ ] Update `README.md` with these shipped facts only:

```text
- Green farm target = selected action can run.
- Red farm target = selected action is blocked; the hint explains why.
- Gold target = neutral/non-farm interaction targeting.
- Esc opens the Controls panel when no blocking/closable modal owns Esc.
- Phoenix includes lightweight placeholder music/SFX.
```

Add the local unsigned export command exactly:

```bash
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```

- [ ] Update the `CLAUDE.md` verification section to list the four automated gates and retain the Task 2 sprite-isometric art contract.

### 5.5 Final verification and PR evidence

- [ ] Run the final suite after any documentation/tuning edit:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599-final.zip
unzip -l /tmp/Phoenix-HPA-599-final.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
git diff --check
```

- [ ] Commit final documentation plus only the balance files actually changed:

```bash
git add README.md CLAUDE.md
# If balance changed, add only the owning rules/content file and its changed GUT test.
git commit -m "docs: record Phoenix MVP release verification"
```

- [ ] Update PR #12 with:

```text
- clean verifier result + GUT count
- GdUnit4 result
- godot-e2e result
- macOS ZIP export result
- packaged 14-day checklist
- final shipped_value/tier reached by the representative run
- any balance change and the concrete defect that justified it, or “no balance changes required”
```

Keep PR #12 as the single HPA-599 delivery PR through implementation and release closeout.
