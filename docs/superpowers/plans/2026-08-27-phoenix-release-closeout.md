# Phoenix HPA-599 Release Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phoenix’s 14-day MVP with truthful farming feedback, minimal HUD/visual/audio polish, an automated Promising-reachability proof, an unsigned macOS CI export, and one qualitative packaged playthrough.

**Architecture:** Keep the current owners. `GameSession` remains the only gameplay authority; `WorldShell` coordinates; `PlayerController`, `FarmView`, and `GameHud` render. GUT remains the broad release oracle while GdUnit4/godot-e2e stay focused parallel lanes. Add no generic polish, feedback, audio, settings, pause, or rendering framework.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, GitHub Actions, Godot macOS export templates.

**Spec:** `docs/superpowers/specs/2026-08-27-phoenix-release-closeout-design.md`

## Global Constraints

- One Linear ticket, one branch, one PR. Continue implementation on `agent/hpa-599-release-closeout-plan`; do not open a second HPA-599 PR.
- No new crops, villagers, maps, tools, quests, endings, post-game, save schema, or migration layer.
- Keep current balance constants unless an automated/package acceptance check exposes a concrete defect.
- Do not migrate GUT to GdUnit4 and do not add a 14-day UI automation harness.
- No feedback/event bus, audio manager, settings screen, generic pause manager, renderer abstraction, shader/post-processing layer, or second gameplay state.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Farm target tint is a closed enum: neutral gold / valid green / invalid red.
- The authored world has no fence entity; do not create one for release verification.
- No signing, notarization, DMG, installer, updater, release publishing, or macOS runner solely for export.

---

## Task 1: Share farm guards, preview through the real authority, and make Day-1 targeting truthful

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
- Produces: `PlayerController.TargetTint { NEUTRAL, VALID, INVALID }`
- Produces: `PlayerController.set_target_tint(tint: TargetTint) -> void`
- Reuses: `_active_day_failure()`, `_target_failure()`, `GameRules.evaluate_action_budget()`, `_assert_unchanged()`, `_hud()`, `_place_target()`, `InteractionHint`, and `TargetHighlight`.

### 1.1 RED — put preview/atomicity in the GUT release oracle

- [ ] Add preview cases beside the existing farming guard tests in `tests/unit/test_game_session.gd`. Use the existing `_assert_unchanged(session, before)` helper and capture `before` with `session.snapshot()`.

```gdscript
func test_preview_selected_action_matches_hoe_and_plant_guards_without_mutation() -> void:
    var session := GameSession.new()

    var before := session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.SOIL_TILLED,
    )
    _assert_unchanged(session, before)

    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    before = session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.ALREADY_TILLED,
    )
    _assert_unchanged(session, before)

    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    before = session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_PLANTED,
    )
    _assert_unchanged(session, before)

    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    before = session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.NO_SELECTED_SEEDS,
    )
    _assert_unchanged(session, before)


func test_preview_selected_action_matches_water_guards_without_mutation() -> void:
    var session := GameSession.new()
    _plant_turnip(session)
    assert_eq(
        session.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )

    var before := session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_WATERED,
    )
    _assert_unchanged(session, before)

    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    before = session.snapshot()
    assert_eq(
        session.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.ALREADY_WATERED,
    )
    _assert_unchanged(session, before)


func test_preview_selected_action_matches_harvest_guards_without_mutation() -> void:
    var immature := GameSession.new()
    _plant_turnip(immature)
    assert_eq(
        immature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    var before := immature.snapshot()
    assert_eq(
        immature.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_IMMATURE,
    )
    _assert_unchanged(immature, before)

    var mature := GameSession.new(func() -> float: return 0.9)
    _mature_turnip(mature)
    assert_eq(
        mature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    before = mature.snapshot()
    assert_eq(
        mature.preview_selected_action(FARM_CELL),
        GameRules.CommandCode.CROP_HARVESTED,
    )
    _assert_unchanged(mature, before)


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

    var before := session.snapshot()
    assert_eq(
        session.preview_selected_action(cells[6]),
        GameRules.CommandCode.INSUFFICIENT_STAMINA,
    )
    _assert_unchanged(session, before)
```

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** GUT fails because `preview_selected_action()` does not exist.

### 1.2 GREEN — factor the existing four guard paths once

- [ ] Add private read-only failure helpers in `scripts/game/game_session.gd`, preserving the current guard order exactly:

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

- [ ] Replace the guard blocks at the top of `hoe`, `plant`, `water`, and `harvest` with the corresponding helper. Keep each existing mutation and `_commit(...)` block unchanged after validation.

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

- [ ] Run `./tools/verify-clean.sh`. **Expected:** preview tests and all existing guard-order/atomicity tests pass.

### 1.3 Extract the complete feedback table without breaking silent intro codes

- [ ] Replace the current `show_feedback()` match with `feedback_text()` plus a thin setter. Preserve every existing sentence and make the two currently silent intro codes explicit:

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
        GameRules.CommandCode.NOTHING_TO_INTERACT:
            return "Nothing to interact with."
        GameRules.CommandCode.VILLAGER_TALKED:
            return "Talked to villager."
        GameRules.CommandCode.CROP_GIFTED:
            return "Gift given."
        GameRules.CommandCode.NOT_AT_VILLAGER:
            return "Stand at the villager."
        GameRules.CommandCode.GIFT_ALREADY_GIVEN:
            return "Gift already given today."
        GameRules.CommandCode.INTRO_ACKNOWLEDGED, \
        GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED:
            return ""
        GameRules.CommandCode.FINALE_TRIGGERED:
            return "Harvest finale complete."
        GameRules.CommandCode.MARKET_NOT_READY:
            return "The Harvest Market opens on Day 14."
        GameRules.CommandCode.NOT_AT_MARKET:
            return "Stand at the Harvest Market."
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED:
            return "The harvest finale is already complete."
        _:
            assert(false, "unmapped command feedback: %s" % code)
            return ""


func show_feedback(code: GameRules.CommandCode) -> void:
    var text := feedback_text(code)
    if text != "":
        _feedback.text = text
```

This keeps intro acknowledgment silent while making future missing mappings fail loudly.

### 1.4 Use a closed target tint and let preview classify membership

- [ ] Add to `PlayerController`:

```gdscript
enum TargetTint { NEUTRAL, VALID, INVALID }

const TARGET_NEUTRAL := Color(1.0, 0.85, 0.2, 0.9)
const TARGET_VALID := Color(0.35, 1.0, 0.45, 0.9)
const TARGET_INVALID := Color(1.0, 0.35, 0.35, 0.9)

func set_target_tint(tint: TargetTint) -> void:
    if target_highlight == null:
        return
    match tint:
        TargetTint.NEUTRAL:
            target_highlight.default_color = TARGET_NEUTRAL
        TargetTint.VALID:
            target_highlight.default_color = TARGET_VALID
        TargetTint.INVALID:
            target_highlight.default_color = TARGET_INVALID
```

- [ ] Add the four selected-action success codes to `WorldShell`:

```gdscript
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]
```

- [ ] Replace the beginning of `WorldShell._process()` with this classification. Do not call `WorldContract.farm_cells().has(target)`:

```gdscript
func _process(_delta: float) -> void:
    var target: Variant = player.current_target_cell()

    if not _world_input_enabled:
        player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
        hud.set_interaction_hint("")
        return

    var preview := _session.preview_selected_action(target)
    if FARM_ACTION_SUCCESS_CODES.has(preview):
        player.set_target_tint(PlayerController.TargetTint.VALID)
        hud.set_interaction_hint("Space — use selected action")
        return
    if preview != GameRules.CommandCode.NO_TARGET and preview != GameRules.CommandCode.NOT_FARM_CELL:
        player.set_target_tint(PlayerController.TargetTint.INVALID)
        hud.set_interaction_hint(hud.feedback_text(preview))
        return

    player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
    # Continue into the existing villager/shop/bed/shipping/market/empty hint chain.
```

`GameSession._target_failure()` is now the only farm-membership decision used by both preview and command execution.

- [ ] Add/update integration coverage using `_hud(world)` and `_place_target()`:

```gdscript
func test_farm_preview_uses_green_red_reason_and_non_farm_gold() -> void:
    var world := _world()
    var hud := _hud(world)
    var hint := hud.get_node("HudRoot/InteractionHint") as Label
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

    await _place_target(world, WorldContract.SHOP_CELL)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq(hint.text, "Shop — E")
```

- [ ] Add the blocking-intro regression:

```gdscript
func test_blocking_intro_never_advertises_farm_action() -> void:
    var world := _locked_world()
    var hud := _hud(world)
    await _place_target(world, WorldContract.farm_cells()[0])
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq((hud.get_node("HudRoot/InteractionHint") as Label).text, "")
```

### 1.5 Fix and pin Day-1 tutorial copy

- [ ] Change only the first `ContentRules.TUTORIALS` body:

```gdscript
"body": "Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.",
```

- [ ] Add an exact assertion in `tests/unit/test_content_rules.gd` for that string.

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

## Task 2: Build help in the existing HUD and test real Esc propagation

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
- Produces code-built `HudRoot/PauseHelp`.
- Reuses `_add_panel`, `_add_label`, `_add_button`, `modal_state_changed`, `has_blocking_modal()`, `_hud()`, and `_panel()`.
- Leaves `DialoguePanel._unhandled_input()` as the dialogue Esc owner.

### 2.1 RED — inject Esc through Godot instead of calling private handlers

- [ ] Add this integration helper:

```gdscript
func _press_escape() -> void:
    var pressed := InputEventAction.new()
    pressed.action = &"ui_cancel"
    pressed.pressed = true
    Input.parse_input_event(pressed)
    await get_tree().process_frame

    var released := InputEventAction.new()
    released.action = &"ui_cancel"
    released.pressed = false
    Input.parse_input_event(released)
    await get_tree().process_frame
```

- [ ] Add real propagation coverage using `_hud()` / `_panel()`:

```gdscript
func test_escape_does_not_open_help_over_blocking_intro() -> void:
    var world := _locked_world()
    var hud := _hud(world)
    var overlay := hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay
    assert_true(overlay.is_opening_visible())

    await _press_escape()

    assert_true(overlay.is_opening_visible())
    assert_false(_panel(hud, "PauseHelp").visible)
    assert_false(world._world_input_enabled)


func test_escape_toggles_code_built_help_and_world_gate() -> void:
    var world := _world()
    var hud := _hud(world)
    var help := _panel(hud, "PauseHelp")

    await _press_escape()
    assert_true(help.visible)
    assert_false(world._world_input_enabled)

    await _press_escape()
    assert_false(help.visible)
    assert_true(world._world_input_enabled)


func test_escape_closes_shop_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    hud.open_shop()

    await _press_escape()

    assert_false(_panel(hud, "ShopPanel").visible)
    assert_false(_panel(hud, "PauseHelp").visible)
```

Add the same single-event assertion for Shipping and Sleep using their existing open methods.

- [ ] Prove descendant dialogue owns Esc under real propagation:

```gdscript
func test_dialogue_consumes_escape_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    var villager_id := VillagerRules.VillagerId.SHOPKEEPER
    var result := world._session.talk_to(
        villager_id,
        WorldContract.villager_cell(villager_id),
    )
    hud.open_dialogue(villager_id, result, world._session.snapshot())

    await _press_escape()

    assert_false(_panel(hud, "DialoguePanel").visible)
    assert_false(_panel(hud, "PauseHelp").visible)
```

- [ ] Add `PauseHelp`-hidden assertions to the existing morning-summary Esc lock. Do not directly call `hud._unhandled_input()` or `dialogue._unhandled_input()` in these routing tests.

### 2.2 GREEN — extend the existing GameHud Esc handler; no dialogue branch

- [ ] Add `_pause_help_panel: Control`, build it in `_build_modals()`, and include it in `has_blocking_modal()`.

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
    var resume := _add_button(panel, "Resume", "Resume", Vector2(236, 178), Vector2(78, 28))
    resume.pressed.connect(func() -> void: _set_pause_help_visible(false))
    return panel


func _set_pause_help_visible(is_visible: bool) -> void:
    if _pause_help_panel.visible == is_visible:
        return
    _pause_help_panel.visible = is_visible
    modal_state_changed.emit()
```

- [ ] Extend the **existing** `GameHud._unhandled_input()` to:

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
    elif _pause_help_panel.visible:
        _set_pause_help_visible(false)
    else:
        _set_pause_help_visible(true)
    get_viewport().set_input_as_handled()
```

There is deliberately no dialogue branch: `DialoguePanel` is a descendant and consumes its Esc before the event reaches `GameHud`.

Do not call `get_tree().paused` and do not create `pause_help.tscn`.

### 2.3 Add subtle snapshot-derived weather tint

- [ ] Add:

```gdscript
const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)

var _weather_tint: ColorRect
```

- [ ] Build `WeatherTint` before ordinary HUD controls and set it from `snapshot["weather"]` inside `render()`.

- [ ] Add an integration test that renders a rainy snapshot and a sunny snapshot and asserts the two exact tint constants.

### 2.4 Add one reused ground shadow and update existing exact smoke contracts

- [ ] Generate `assets/sprites/proof-shadow.png` with a one-off Godot script and run an import. Do not add a permanent generator dependency.

- [ ] Add a `Shadow` `Sprite2D` before the visible sprite under Player, Tree, Building, Shipping, HarvestMarket, and all three villager roots. Do not change root positions/z-order.

- [ ] In `FarmView`, preload the same texture, create `Shadow` before each dynamic crop `Sprite2D`, keep it hidden initially, and mirror crop visibility during `refresh()`.

- [ ] Replace the current exact `_expect_names` contracts in `tests/headless/world_shell_smoke.gd`:

```gdscript
_expect_names(entity, ["Shadow", "Sprite2D"], "%s entity" % entry.label)
_expect_names(villager, ["Shadow", "Sprite2D"], "villager %d entity" % id)
_expect_names(crop_root, ["Shadow", "Sprite2D"], "crop %s" % cell)
```

Add direct player/entity shadow resource checks and assert crop shadows start hidden. Do not add a fence or screenshot/golden harness.

### 2.5 Document art contract, verify, and commit

- [ ] Add to `CLAUDE.md`:

```text
Sprite-isometric art contract
- Ground diamonds are 64×32.
- Entity roots are bottom-center ground contacts.
- Visible sprites offset upward from the root.
- Shadows are child sprites on the ground plane, never Y-sort roots.
- Entities remains the sole Y-sort owner for foreground/occluding world objects.
- Nearest filtering and integer scaling remain mandatory.
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

## Task 3: Add minimal code-built audio with import-time looping

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
- Create/modify after import: `assets/audio/*.wav.import`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces code-built `GameHud/SfxPlayer` and `GameHud/MusicPlayer`.
- Reuses `show_feedback()` / `feedback_text()` for command categories.
- Assigns the imported `FARM_DAY_LOOP` directly; no duplicated runtime music resource.

### 3.1 Generate and import the placeholder assets

- [ ] Generate eight project-owned mono PCM WAV files at 22,050 Hz using Python's standard library. Keep SFX under 250 ms and music under 8 seconds. Use the existing tone-generation command from the planning branch or equivalent standard-library code; no project dependency is added.

- [ ] Add `assets/audio/README.md`:

```markdown
# Phoenix placeholder audio

These WAV files are project-generated placeholder tones created for the HPA-599 MVP closeout. They contain no externally sourced recording or composition and require no third-party attribution. They are intentionally disposable if authored audio replaces them later.
```

- [ ] Import once, set the music import loop mode to Forward, and reimport:

```bash
godot --headless --path . --import
python3 - <<'PY'
from pathlib import Path
p = Path("assets/audio/farm-day-loop.wav.import")
text = p.read_text()
assert "edit/loop_mode=0" in text
p.write_text(text.replace("edit/loop_mode=0", "edit/loop_mode=2", 1))
PY
godot --headless --path . --import
grep -F 'edit/loop_mode=2' assets/audio/farm-day-loop.wav.import
```

Commit all `.wav.import` sidecars with their WAV files.

### 3.2 RED — pin imported stream identity and representative SFX routing

- [ ] Add integration coverage:

```gdscript
func test_hud_audio_players_and_representative_feedback_streams() -> void:
    var world := _world()
    var sfx := world.hud.get_node("SfxPlayer") as AudioStreamPlayer
    var music := world.hud.get_node("MusicPlayer") as AudioStreamPlayer
    assert_not_null(sfx)
    assert_not_null(music)
    assert_eq(music.stream.resource_path, "res://assets/audio/farm-day-loop.wav")
    assert_eq((music.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)

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

Do not assert waveform samples or speaker output.

### 3.3 GREEN — code-build the two players in GameHud

- [ ] Preload the eight streams and add fields:

```gdscript
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
```

- [ ] Call `_build_audio()` during `_ready()`:

```gdscript
func _build_audio() -> void:
    _sfx_player = AudioStreamPlayer.new()
    _sfx_player.name = "SfxPlayer"
    _sfx_player.volume_db = -8.0
    add_child(_sfx_player)

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.volume_db = -20.0
    _music_player.stream = FARM_DAY_LOOP
    add_child(_music_player)
    _music_player.play()
```

Do not duplicate `FARM_DAY_LOOP` and do not edit `scenes/ui/game_hud.tscn`.

- [ ] Keep one `_sfx_for_code(code)` selector: farming success → action; purchase/shipping → commerce; talk/gift → social; day transition → day-transition; finale → finale; current farm/economy guards → cancel. Return `null` for deliberately silent codes.

- [ ] After `show_feedback()` sets text, play the selected stream on `_sfx_player`. Reuse that player for modal confirm/cancel and save status where no command code already covers the transition.

- [ ] Verify and commit:

```bash
./tools/verify-clean.sh
git diff --check
git add assets/audio scripts/ui/game_hud.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: add lightweight game audio feedback"
```

---

## Task 4: Add deterministic economy reachability and make CI the unsigned macOS release gate

**Files:**
- Modify: `tests/unit/test_game_session.gd`
- Modify: `.github/workflows/ci.yml`
- Modify: `export_presets.cfg` only if the real export command proves a missing release option is required.

**Interfaces:**
- Adds the arithmetic release gate to GUT/`verify-clean.sh`.
- Reuses existing `GameSession` public commands and injectable weather roll.
- Reuses existing `macOS` export preset.
- Produces CI artifact `Phoenix-macOS` containing `build/Phoenix.zip`.

### 4.1 RED/GREEN — prove a normal five-Turnip route reaches Promising

- [ ] Add a tiny helper near the existing test helpers:

```gdscript
func _sleep_and_ack(session: GameSession) -> void:
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(
        session.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
```

- [ ] Add the deterministic release route:

```gdscript
func test_representative_reinvestment_route_reaches_promising() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var cells := [
        WorldContract.farm_cells()[0],
        WorldContract.farm_cells()[1],
        WorldContract.farm_cells()[2],
    ]

    # Starter crop: three Turnips, watered through three sunny growth nights.
    for cell in cells:
        assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 2
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 3
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 4, mature

    for cell in cells:
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 3, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 5, first 105G shipment settled

    # Reinvest into two more Turnips on already-tilled cells.
    assert_eq(
        session.buy_seeds(GameRules.CropKind.TURNIP, 2, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    for cell in cells.slice(0, 2):
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 6
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 7
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 8, mature

    for cell in cells.slice(0, 2):
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 2, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 9, second 70G shipment settled

    while int(session.snapshot()["day"]) < GameRules.MAX_DAY:
        _sleep_and_ack(session)

    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var result := ContentRules.build_harvest_result(session.state())
    assert_eq(result["shipped_count"], 5)
    assert_eq(result["shipped_value"], 175)
    assert_true(int(result["shipped_value"]) >= ContentRules.PROMISING_SHIPPED_VALUE)
    assert_eq(result["tier"], &"promising_farmer")
```

- [ ] Run `./tools/verify-clean.sh`. The route must pass before any balance retuning is considered.

### 4.2 Adopt the repository's existing CI action pins

- [ ] Replace floating checkout/setup actions in `.github/workflows/ci.yml` with:

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

### 4.3 Import the checkout before exporting it

- [ ] Keep `./tools/verify-clean.sh`, then explicitly import the **checkout** before release export:

```yaml
- name: Import release checkout
  run: godot --headless --path . --import

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

`verify-clean.sh` imports only its temporary archive; it does not warm the checkout's `.godot` import cache.

### 4.4 Verify locally with the same import/export sequence

- [ ] Run:

```bash
./tools/verify-clean.sh
godot --headless --path . --import
rm -f /tmp/Phoenix-HPA-599.zip
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
git diff --check
```

- [ ] Commit:

```bash
git add tests/unit/test_game_session.gd .github/workflows/ci.yml
git diff --quiet -- export_presets.cfg || git add export_presets.cfg
git commit -m "ci: prove balance and unsigned macOS export"
```

Do not add signing, notarization, DMG, a macOS runner, GitHub Release publishing, or deployment logic.

---

## Task 5: Run release gates, perform one qualitative packaged playthrough, and record only evidence-backed tuning

**Files:**
- Modify conditionally on observed evidence: `scripts/game/game_rules.gd`, `scripts/game/villager_rules.gd`, `scripts/game/content_rules.gd`, and matching exact-value/reachability GUT tests.
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Update: PR #12 description/checklist with final evidence.

**Interfaces:**
- Automated release gate = clean GUT/headless (including Promising route) + focused GdUnit4 + bounded godot-e2e + imported unsigned macOS export.
- Manual acceptance = readability, audio, depth, window behavior, restore feel, and practical dead-end/soft-lock detection.

### 5.1 Run all four automated gates

- [ ] Clean GUT/headless oracle:

```bash
./tools/verify-clean.sh
```

- [ ] Focused GdUnit4:

```bash
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

- [ ] Bounded godot-e2e:

```bash
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

- [ ] Import + export release candidate:

```bash
godot --headless --path . --import
rm -f /tmp/Phoenix-HPA-599.zip
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record exact pass counts plus the deterministic route's `5 crops / 175G / promising_farmer` result in PR #12.

### 5.2 Perform one real packaged New Game → Day 14 run

- [ ] Unzip and launch the exported `.app`. Play without debug state/test hooks.

Record this qualitative checklist:

```markdown
### Packaged 14-day acceptance
- [ ] Fresh player path works from title + intro without README/developer instructions.
- [ ] Farm target is green when valid, red with a reason when invalid, and gold for non-farm/interactable targets.
- [ ] Blocking intro/modals never advertise an inert farm action.
- [ ] Hoe / plant / water / harvest have readable pre- and post-action feedback.
- [ ] Dry/wet soil and every crop stage are distinguishable at 1×.
- [ ] Purchase, shipping income, gift/relationship gain, sleep/wake/save, and finale cues are readable/audible.
- [ ] Tree, building, mature crop, and villager crossings preserve front/behind order.
- [ ] Default and smaller supported windows keep required controls visible and pixel art crisp.
- [ ] Continue restores representative saves without visible UI/state desynchronization.
- [ ] Repeated input does not visibly duplicate processing or soft-lock the run.
- [ ] No practical economy dead-end appears during normal play.
```

Record the human run's final shipped value/tier as evidence, but do not use it as the arithmetic proof of Promising reachability.

### 5.3 Retune only across a defined defect bar

- [ ] Leave release-candidate numbers unchanged unless:

1. `test_representative_reinvestment_route_reaches_promising()` fails because a legitimate rule change makes the normal scripted route miss the threshold;
2. the packaged run finds a forced economy dead-end not represented by that route; or
3. a specific rule value causes a concrete usability defect that presentation cannot fix.

If a number changes, change its owning constant, exact-value GUT assertion, and representative reachability test expectations in the same commit. Do not add a tuning table/difficulty/configuration layer.

### 5.4 Final docs

- [ ] Update `README.md` with shipped facts:

```text
- Green farm target = selected action can run.
- Red farm target = selected action is blocked; the hint explains why.
- Gold target = neutral/non-farm interaction targeting.
- Esc opens Controls when no blocking/closable UI owns the event.
- Phoenix includes lightweight placeholder music/SFX.
```

Document local clean export as:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```

- [ ] Update `CLAUDE.md` with the four automated gates, deterministic Promising route, and Task 2 sprite-isometric art contract.

### 5.5 Final verification and PR evidence

- [ ] Run after any final tuning/docs edit:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599-final.zip
unzip -l /tmp/Phoenix-HPA-599-final.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
git diff --check
```

- [ ] Commit final documentation plus only balance files actually changed:

```bash
git add README.md CLAUDE.md
# If balance changed, add only the owning rules/content file and changed GUT tests.
git commit -m "docs: record Phoenix MVP release verification"
```

- [ ] Update PR #12 with:

```text
- clean verifier result + GUT count
- deterministic Promising route result (5 crops / 175G / promising_farmer)
- GdUnit4 result
- godot-e2e result
- macOS checkout import + ZIP export result
- packaged 14-day qualitative checklist
- final manual shipped_value/tier for evidence
- any balance change + concrete defect, or “no balance changes required”
```

Keep PR #12 as the single HPA-599 delivery PR.

## Known Risks

1. Linux-to-macOS cross-export has no existing Phoenix CI proof. Task 4 makes it an explicit gate; do not silently add a macOS runner if it fails.
2. Regenerating `farm-day-loop.wav` can reset its import metadata. The committed `.wav.import` sidecar plus loop-mode integration assertion pins the contract.
3. Any accepted balance change may invalidate the deterministic route. Update the route and exact-value tests in the same review as the rule change.
