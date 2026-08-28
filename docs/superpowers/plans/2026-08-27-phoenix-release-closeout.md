# Phoenix HPA-599 Release Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phoenix’s 14-day MVP with truthful/readable farming feedback, a minimal HUD/help/audio polish pass, an unsigned macOS CI export, and one verified packaged playthrough without expanding the game.

**Architecture:** Keep the existing owners. `GameSession` remains the only gameplay authority; `WorldShell` coordinates; `PlayerController`, `FarmView`, and `GameHud` render; GUT remains the broad release oracle while GdUnit4/godot-e2e stay focused parallel lanes. Add no generic polish, feedback, audio, settings, pause, or rendering framework.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, GitHub Actions, Godot macOS export templates.

**Spec:** `docs/superpowers/specs/2026-08-27-phoenix-release-closeout-design.md`

## Global Constraints

- One Linear ticket, one branch, one PR. Continue implementation on `agent/hpa-599-release-closeout-plan`; do not open a second HPA-599 implementation PR.
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
- Reuses: `_active_day_failure()`, `_target_failure()`, `GameRules.evaluate_action_budget()`, existing command-code text, existing `InteractionHint`, and existing `TargetHighlight`.

### 1.1 RED — move the release-critical preview contract into GUT

- [ ] Add preview/atomicity tests beside the current hoe/plant/water/harvest guard tests in `tests/unit/test_game_session.gd`. Do **not** add a duplicate preview test to `tests/gdunit/`.

Use state equality so the persisted authority is proven unchanged:

```gdscript
func test_preview_selected_action_matches_hoe_guard_and_does_not_mutate() -> void:
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
```

Add equivalent focused cases for:

```gdscript
# Plant: tilled empty cell + Turnip selected -> CROP_PLANTED.
# Plant: Potato selected with zero Potato seeds -> NO_SELECTED_SEEDS.
# Water: planted sunny crop -> CROP_WATERED.
# Water: already-watered crop -> ALREADY_WATERED.
# Harvest: immature crop -> CROP_IMMATURE.
# Harvest: _mature_turnip(session) -> CROP_HARVESTED.
# Budget: hoe six fresh cells first; with stamina == 2, preview Hoe on cell 7 -> INSUFFICIENT_STAMINA.
```

For every preview assertion, capture `before := session.state()` immediately before preview and assert `session.state() == before` afterward.

- [ ] Run the broad release oracle:

```bash
./tools/verify-clean.sh
```

**Expected:** GUT fails because `preview_selected_action()` is missing.

### 1.2 GREEN — factor existing guards once

- [ ] Refactor `hoe`, `plant`, `water`, and `harvest` so each calls one private read-only failure helper before mutation.

Use the existing `-1` success sentinel:

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
```

Implement `_plant_failure`, `_water_failure`, and `_harvest_failure` in the same existing guard order. The public command calls its helper, returns the failure when non-`-1`, then performs the current mutation/budget commit unchanged.

- [ ] Add one dispatcher for preview:

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

`_selected_action_failure()` dispatches only to the four private failure helpers. Do not clone a session or execute/rollback a real command.

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** preview GUT cases pass and all existing command-order/atomicity tests remain green.

### 1.3 RED/GREEN — extract the existing feedback sentence table

- [ ] In `GameHud`, extract the current `show_feedback()` match into a pure text method and keep one table:

```gdscript
func feedback_text(code: GameRules.CommandCode) -> String:
    match code:
        GameRules.CommandCode.SOIL_TILLED:
            return "Soil tilled."
        GameRules.CommandCode.CROP_PLANTED:
            return "Crop planted."
        # Move every existing show_feedback mapping here unchanged.
        _:
            return ""

func show_feedback(code: GameRules.CommandCode) -> void:
    var text := feedback_text(code)
    if text != "":
        _feedback.text = text
```

Do not create a second pre-action error-text table.

### 1.4 RED/GREEN — green/red/gold plus pre-action reason

- [ ] Add target colors to `PlayerController`:

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

- [ ] In `WorldShell._process()`, preview only authored farm cells. Treat these four codes as valid:

```gdscript
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]
```

For a farm cell:

```gdscript
var preview := _session.preview_selected_action(target)
var valid := FARM_ACTION_SUCCESS_CODES.has(preview)
player.set_target_action_validity(valid)
hud.set_interaction_hint(
    "Space — use selected action" if valid else hud.feedback_text(preview)
)
```

For every non-farm target, call `player.set_target_action_validity(null)` first, then keep the current shop/bed/shipping/market/villager hint logic unchanged.

- [ ] Add one integration test to `tests/integration/test_gameplay_shell.gd` using the real WorldShell:

```gdscript
func test_farm_target_preview_uses_green_red_reason_and_non_farm_gold() -> void:
    var world := _world()
    var cell: Vector2i = WorldContract.farm_cells()[0]
    await _place_target(world, cell)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)
    assert_eq(
        (world.hud.get_node("HudRoot/InteractionHint") as Label).text,
        "Space — use selected action",
    )

    world.use_selected_action()
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_INVALID)
    assert_eq(
        (world.hud.get_node("HudRoot/InteractionHint") as Label).text,
        "Soil is already tilled.",
    )

    world.select_action_slot(2)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)

    await _place_target(world, WorldContract.SHOP_CELL)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq((world.hud.get_node("HudRoot/InteractionHint") as Label).text, "Shop — E")
```

Use the existing target helper/facing convention in the file rather than adding a new test hook.

### 1.5 Fix and pin the Day-1 tutorial copy

- [ ] Change only the `farm_basics` body in `ContentRules.TUTORIALS`:

```gdscript
"body": "Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.",
```

- [ ] Add a direct assertion in `tests/unit/test_content_rules.gd` so a future target-color change cannot leave stale onboarding copy:

```gdscript
func test_farm_basics_copy_matches_target_validity_contract() -> void:
    assert_eq(
        ContentRules.TUTORIALS[0]["body"],
        "Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.",
    )
```

The current README has no “gold outline” tutorial wording; no README edit is needed for this correction.

- [ ] Run:

```bash
./tools/verify-clean.sh
git diff --check
```

- [ ] Commit:

```bash
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

### 2.1 RED — pin Esc ordering before building help

- [ ] Add integration coverage for the exact modal order.

Create an input helper local to the test file if one does not already exist:

```gdscript
func _cancel_event() -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"ui_cancel"
    event.pressed = true
    return event
```

Add focused assertions:

1. Fresh locked world: intro is visible; call `world.hud._unhandled_input(_cancel_event())`; intro stays visible and `PauseHelp` stays hidden.
2. Normal world: Esc opens `PauseHelp`; `world._world_input_enabled` becomes false.
3. Press `PauseHelp/Resume`; help closes; world input becomes true.
4. Open shop/shipping/sleep one at a time; Esc closes the active panel and does not open help.
5. Open normal dialogue; call `world.hud._unhandled_input(_cancel_event())`; help remains hidden, then call the dialogue panel's `_unhandled_input()` with the event and verify dialogue closes.
6. Existing morning-summary test path: Esc leaves summary visible and does not open help.

Do not make GameHud close dialogue directly: `DialoguePanel._unhandled_input()` owns the close-friend unskippable sequence.

### 2.2 GREEN — code-build PauseHelp beside current modals

- [ ] Add `_pause_help_panel: Control` to `GameHud` and build it inside `_build_modals()`:

```gdscript
_pause_help_panel = _build_pause_help()
_pause_help_panel.visible = false
```

Use the existing helpers:

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
```

Add:

```gdscript
func _set_pause_help_visible(is_visible: bool) -> void:
    if _pause_help_panel.visible == is_visible:
        return
    _pause_help_panel.visible = is_visible
    modal_state_changed.emit()
```

Include `_pause_help_panel.visible` in `has_blocking_modal()`.

- [ ] Replace `GameHud._unhandled_input()` with the required ownership order:

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
        return # DialoguePanel owns Esc and its close-friend lock.
    elif _pause_help_panel.visible:
        _set_pause_help_visible(false)
    else:
        _set_pause_help_visible(true)
    get_viewport().set_input_as_handled()
```

Do not call `get_tree().paused` and do not create `pause_help.tscn`.

### 2.3 RED/GREEN — add subtle weather tint

- [ ] Add `WeatherTint` in `_build_always_visible_hud()` before ordinary HUD controls:

```gdscript
const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)

var _weather_tint: ColorRect

func _build_always_visible_hud() -> void:
    _weather_tint = ColorRect.new()
    _weather_tint.name = "WeatherTint"
    _weather_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _weather_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weather_tint.z_index = -1
    _root.add_child(_weather_tint)
    # existing HUD construction follows
```

In `render(snapshot)`, set `_weather_tint.color` from the existing weather key only.

- [ ] Add an integration assertion using a duplicated snapshot:

```gdscript
var snapshot := world._session.snapshot()
snapshot["weather"] = GameRules.weather_key(GameRules.Weather.RAINY)
world.hud.render(snapshot)
assert_eq(
    (world.hud.get_node("HudRoot/WeatherTint") as ColorRect).color,
    GameHud.RAINY_TINT,
)
```

Repeat for sunny.

### 2.4 RED/GREEN — one reused ground-shadow texture

- [ ] Generate `assets/sprites/proof-shadow.png` as a small translucent ellipse with a one-off Godot script; do not add a permanent generator dependency:

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
```

- [ ] Reuse it under the player, tree, building, shipping, harvest market, and three villagers. Every static entity root keeps the same position/Y-sort identity; its exact children become:

```text
Shadow
Sprite2D
```

- [ ] In `FarmView._ready()`, create `Shadow` under each `FarmCrop_x_y` root before `Sprite2D`, use the same texture at a smaller scale, and store it in `_crop_shadows`.

In `refresh(snapshot)`:

```gdscript
var visible := tilled and crop_data != null
shadow.visible = visible
crop.visible = visible
```

- [ ] Update the **existing exact child-name assertions** in `tests/headless/world_shell_smoke.gd`; do not merely append separate shadow checks:

```gdscript
if not _expect_names(entity, ["Shadow", "Sprite2D"], "%s entity" % entry.label):
    return
```

Do the same for villagers, player where its exact child list is pinned, and crop roots. Add assertions that `Shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png"` and that shadow nodes are children of the entity roots, not direct `Entities` children.

- [ ] Run the import to create the sidecar:

```bash
godot --headless --path . --editor --quit
```

Commit `assets/sprites/proof-shadow.png.import` with the PNG.

### 2.5 Document the art contract and verify

- [ ] Add `Sprite-isometric art contract` to `CLAUDE.md` with exactly these rules:

```text
- Ground diamonds are 64×32.
- Entity root positions are bottom-center ground contacts.
- Visible sprites offset upward from their root.
- Shadows are child sprites on the ground plane, never Y-sort roots.
- Entities remains the only Y-sort owner for foreground/occluding world objects.
- Nearest filtering and integer scaling are mandatory.
```

- [ ] Run:

```bash
./tools/verify-clean.sh
git diff --check
```

- [ ] Commit:

```bash
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

- [ ] Create eight mono PCM WAV files at 22,050 Hz. Keep SFX under 250 ms and the music loop under 8 seconds. Use a one-off Python standard-library command; do not add a project/runtime dependency.

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
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
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

- [ ] Add `assets/audio/README.md`:

```markdown
# Phoenix placeholder audio

These WAV files are project-generated placeholder tones created for the HPA-599 MVP closeout. They contain no externally sourced recording or composition and require no third-party attribution. They are intentionally disposable if authored audio replaces them later.
```

### 3.2 RED — pin wiring, not waveform bytes

- [ ] Add integration checks that the two players exist and representative feedback selects the intended resource:

```gdscript
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

Do not assert speaker output or waveform samples.

### 3.3 GREEN — keep all audio in GameHud

- [ ] Add only these nodes to `scenes/ui/game_hud.tscn`:

```text
GameHud/SfxPlayer
GameHud/MusicPlayer
```

Set conservative default volume levels (approximately `-8 dB` SFX and `-20 dB` music). Start the music loop from `GameHud._ready()`; configure the imported loop appropriately rather than adding a music controller.

- [ ] Add preloaded stream constants in `game_hud.gd` and one narrow selector:

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
        GameRules.CommandCode.NO_SELECTED_SEEDS, \
        GameRules.CommandCode.INSUFFICIENT_FUNDS, \
        GameRules.CommandCode.INSUFFICIENT_CROPS, \
        GameRules.CommandCode.ACTION_TOO_LATE, \
        GameRules.CommandCode.INSUFFICIENT_STAMINA:
            return CANCEL_SFX
        _:
            return null
```

`show_feedback(code)` sets text through `feedback_text(code)` and plays `_sfx_for_code(code)` when non-null. Reuse the same `SfxPlayer` for help/modal confirm/cancel and save status where required; do not create more players.

- [ ] Run:

```bash
./tools/verify-clean.sh
git diff --check
```

- [ ] Commit:

```bash
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
- Reuses the existing `macOS` export preset.
- Produces CI artifact `Phoenix-macOS` containing `build/Phoenix.zip`.
- Adopts the same checkout/setup action SHAs and credential policy as the GdUnit4/e2e workflows.

### 4.1 Update CI pins before adding export

- [ ] Replace the floating actions in `.github/workflows/ci.yml` with the exact existing repository convention:

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

Do not leave `actions/checkout@v7` or `setup-godot@v2.4.1` floating in the edited workflow.

### 4.2 Add the unsigned zip gate

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

### 4.3 Local/static verification

- [ ] Run:

```bash
./tools/verify-clean.sh
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
git diff --check
```

**Expected:** clean verifier passes; export exits 0; ZIP contains the app executable.

- [ ] Commit:

```bash
git add .github/workflows/ci.yml export_presets.cfg
git commit -m "ci: verify unsigned macOS export"
```

If `export_presets.cfg` was not changed, omit it from `git add`.

---

## Task 5: Run every release gate, perform one packaged 14-day run, and record only evidence-backed tuning

**Files:**
- Modify only if evidence requires it: `scripts/game/game_rules.gd`, `scripts/game/villager_rules.gd`, `scripts/game/content_rules.gd`, their exact-value GUT tests.
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Update: PR #12 description/checklist with final evidence.

**Interfaces:**
- Release gate = clean GUT/headless + focused GdUnit4 + bounded godot-e2e + unsigned macOS export + one real packaged playthrough.
- Balance bar for the representative run = `ContentRules` Promising shipped-value threshold (`>= 150G`); Heart is optional.

### 5.1 Run all four automated gates

- [ ] Clean GUT/headless oracle:

```bash
./tools/verify-clean.sh
```

- [ ] Focused GdUnit4 lane:

```bash
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

- [ ] Bounded godot-e2e lane:

```bash
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

- [ ] Unsigned macOS export:

```bash
rm -f /tmp/Phoenix-HPA-599.zip
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-599.zip
unzip -l /tmp/Phoenix-HPA-599.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record exact pass counts/output summary in PR #12. Do not add duplicate tests solely to make the four lanes look symmetrical.

### 5.2 Perform one normal packaged New Game → Day 14 run

- [ ] Launch the exported `.app` from the ZIP and play without debug mutation/test hooks.

Record this checklist in PR #12:

```markdown
### Packaged 14-day acceptance
- [ ] Fresh player path works from title + intro without README instructions.
- [ ] Farm target: green valid, red invalid with reason, gold non-farm/interactable.
- [ ] Hoe / plant / water / harvest have readable pre- and post-action feedback.
- [ ] Dry/wet soil and every crop stage are distinguishable at 1×.
- [ ] Purchase, shipping income, gift/relationship gain, sleep/wake/save, and finale cues are readable/audible.
- [ ] Tree, building, mature crop, and villager crossings preserve front/behind order.
- [ ] Default and smaller supported window keep required controls visible and pixel art crisp.
- [ ] Continue restores a representative saved morning without UI/state desynchronization.
- [ ] Day 14 pre-finale Continue reaches the same terminal result path.
- [ ] Repeated input does not duplicate purchase, shipment, gift, day transition, save, or finale processing.
- [ ] Representative farming/reinvestment reaches shipped_value >= 150G (Promising Farmer). Heart is optional.
```

The acceptance bar is observable: the representative run must reach `Promising Farmer` through shipped value. Do not use “satisfying” as a tuning criterion.

### 5.3 Tune only if the evidence crosses a defined defect bar

- [ ] Leave all release-candidate numbers unchanged unless one of these happens:

1. A reasonable farming/reinvestment route in the packaged run cannot reach `shipped_value >= ContentRules.PROMISING_SHIPPED_VALUE`.
2. The player enters a forced economy dead-end that prevents continuing the intended farming loop.
3. A specific timing/threshold value causes an observed readability/usability defect that cannot be fixed in presentation alone.

If a number changes, change the owning constant and its exact GUT assertion in the same commit. Do not create a tuning table, difficulty layer, configuration resource, or compatibility branch.

### 5.4 Final documentation

- [ ] Update `README.md` to describe only shipped player-facing release behavior: green/red/gold target meaning, Esc controls panel, audio presence, and unsigned macOS development export instructions if useful.

- [ ] Update `CLAUDE.md` verification section to state the four automated gates and retain the art contract from Task 2.

- [ ] Run final checks after documentation/tuning:

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

- [ ] Commit final release evidence/docs (and any evidence-backed balance correction):

```bash
git add README.md CLAUDE.md scripts/game tests/unit
# Omit unchanged paths from the actual commit.
git commit -m "docs: record Phoenix MVP release verification"
```

### 5.5 Final PR evidence

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

Keep PR #12 as the single HPA-599 delivery PR through implementation and closeout.
