# Phoenix HPA-599 Release Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phoenix’s 14-day MVP with readable action/presentation feedback, a minimal help/audio pass, an unsigned macOS export gate, and one verified packaged playthrough without expanding the game.

**Architecture:** Keep the existing ownership model. `GameSession` remains the only gameplay authority; `WorldShell` coordinates; `PlayerController`/`FarmView`/`GameHud` render; existing GUT/GdUnit4/godot-e2e lanes stay separate. Add no generic polish, audio, settings, pause, or rendering framework.

**Tech Stack:** Godot 4.7.1 standard edition, statically typed GDScript, GUT 9.7.1, GdUnit4 6.2.1, godot-e2e, GitHub Actions, macOS Godot export templates.

**Spec:** `docs/superpowers/specs/2026-08-27-phoenix-release-closeout-design.md`

## Global Constraints

- One Linear ticket, one branch, one PR: implementation continues on `agent/hpa-599-release-closeout-plan`; do not open a second implementation PR.
- No new crops, villagers, map areas, tools, quests, endings, post-game, or save schema.
- Keep the current release-candidate balance values unless an automated or packaged playthrough exposes a specific defect.
- Do not migrate the existing GUT suite to GdUnit4.
- Do not introduce a feedback/event bus, audio manager, settings screen, generic pause manager, renderer abstraction, shader/post-processing layer, or new state-management system.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Use the existing snapshot/command-code contracts instead of letting views infer hidden gameplay state.
- The current map has no authored fence entity; do not add one for a checklist-only depth test.
- No signing, notarization, DMG, installer, updater, or release publishing.

---

## Task 1: Add exact read-only farming action preview and target validity feedback

**Files:**
- Modify: `tests/gdunit/test_game_session_flows.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

### 1.1 RED — pin preview behavior without mutation

- [ ] Add focused GdUnit4 cases to `tests/gdunit/test_game_session_flows.gd` for all four selected actions.

The tests must prove:

```gdscript
func test_selected_action_preview_matches_guards_without_mutation() -> void:
    var session := _sunny()
    var cell := _cell(0)

    var before := session.state()
    assert_int(session.preview_selected_action(cell)).is_equal(
        GameRules.CommandCode.SOIL_TILLED
    )
    assert_dict(session.state()).is_equal(before)

    assert_int(session.hoe(cell)).is_equal(GameRules.CommandCode.SOIL_TILLED)
    before = session.state()
    assert_int(session.preview_selected_action(cell)).is_equal(
        GameRules.CommandCode.ALREADY_TILLED
    )
    assert_dict(session.state()).is_equal(before)

    assert_int(session.select_action(GameRules.FarmingAction.SEEDS)).is_equal(
        GameRules.CommandCode.ACTION_SELECTED
    )
    assert_int(session.preview_selected_action(cell)).is_equal(
        GameRules.CommandCode.CROP_PLANTED
    )
```

Add equivalent valid/invalid coverage for watering and harvesting, plus one budget failure (`INSUFFICIENT_STAMINA` or `ACTION_TOO_LATE`). Do not duplicate unrelated lifecycle tests.

- [ ] Bootstrap and run only the focused GdUnit directory:

```bash
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

**Expected:** new preview tests fail because `preview_selected_action()` does not exist.

### 1.2 GREEN — share command validation with preview

- [ ] Refactor the existing `hoe`, `plant`, `water`, and `harvest` guards into private read-only helpers in `scripts/game/game_session.gd`.

Use the existing `-1` success sentinel already used by `_active_day_failure()`:

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

`_selected_action_failure()` dispatches to `_hoe_failure()`, `_plant_failure()`, `_water_failure()`, or `_harvest_failure()`. Each helper performs the same active-day/target/tile/inventory/weather/budget checks currently embedded in the mutating method. The public command calls its helper first and mutates only when it returns `-1`.

Do not implement preview by cloning a session, applying a command, or recreating guards in UI/world code.

- [ ] Run the focused GdUnit suite again. **Expected: PASS.**

### 1.3 RED/GREEN — render neutral/valid/invalid target state

- [ ] Add presentation constants and a narrow setter in `scripts/player/player_controller.gd`:

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

- [ ] In `WorldShell._process`, after resolving `target`, ask for preview **only** when `target` is an authored farm cell. Map the four success command codes to `true`; every other preview code maps to `false`. Non-farm targets pass `null` so shop/bed/shipping/market/villager targeting stays gold.

- [ ] Add a scene integration test in `tests/integration/test_gameplay_shell.gd` that targets one fresh farm cell, selects Hoe, verifies green; hoes it, verifies red; selects Seeds, verifies green; then targets the shop and verifies neutral gold. The test should call `_process(0.0)` explicitly after changing the target/action so it does not depend on frame timing.

- [ ] Run the clean verifier after committing the test + implementation:

```bash
./tools/verify-clean.sh
```

**Expected:** full GUT/headless lane passes.

- [ ] Commit:

```bash
git add scripts/game/game_session.gd scripts/player/player_controller.gd \
  scripts/world/world_shell.gd tests/gdunit/test_game_session_flows.gd \
  tests/integration/test_gameplay_shell.gd
git commit -m "feat: preview farming action validity"
```

---

## Task 2: Close visual/readability gaps and add the small controls panel

**Files:**
- Modify: `scripts/world/farm_view.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scenes/world/world.tscn`
- Modify: `scenes/ui/game_hud.tscn`
- Create: `scenes/ui/pause_help.tscn`
- Create: `assets/sprites/proof-shadow.png`
- Create after import: `assets/sprites/proof-shadow.png.import`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `CLAUDE.md`

### 2.1 RED — pin the help/input/weather presentation contract

- [ ] Extend `tests/integration/test_gameplay_shell.gd` with focused assertions that:

  - `GameHud.has_blocking_modal()` is false during normal play;
  - Esc with no modal opens `PauseHelp` and blocks world input;
  - Resume closes it and re-enables world input;
  - Esc still closes shop/shipping/sleep/dialogue before it can open `PauseHelp`;
  - a rainy snapshot gives the weather tint its rainy color and a sunny snapshot restores the sunny color.

- [ ] Extend `tests/headless/world_shell_smoke.gd` to pin only structural depth invariants that matter to HPA-599:

  - `Entities.y_sort_enabled == true`;
  - player/tree/building/villagers/crop roots remain children of `Entities`;
  - added shadow nodes are children of their entity roots, not new Y-sort roots;
  - crop shadow visibility follows crop visibility.

Do not add pixel screenshot/golden-image tests.

### 2.2 GREEN — add one standalone help scene without pausing the tree

- [ ] Create `scenes/ui/pause_help.tscn` as a simple `Control` with a single panel, static control text, and a `Resume` button. Use these exact player-facing bindings:

```text
Phoenix — Controls
WASD — Move
1 / 2 / 3 / 4 — Hoe / Seeds / Water / Hands
Space — Use selected action
E — Interact
Esc — Close / controls
```

No separate script is needed.

- [ ] Instance the scene under `HudRoot` in `scenes/ui/game_hud.tscn`, hidden by default.

- [ ] In `scripts/ui/game_hud.gd`:

  - cache `_pause_help`;
  - connect `PauseHelp/Panel/Resume` to close it;
  - include it in `has_blocking_modal()`;
  - preserve the current morning-summary Esc lock;
  - preserve “Esc closes the open modal” for shop/shipping/sleep/dialogue;
  - when no existing modal is open, Esc toggles `PauseHelp`;
  - emit the existing `modal_state_changed` signal when its visibility changes.

Do **not** set `get_tree().paused`; Phoenix’s gameplay clock advances through commands, so the existing world-input gate is enough.

### 2.3 GREEN — add a tiny weather tint

- [ ] In `_build_always_visible_hud()`, create one full-screen `ColorRect` named `WeatherTint` before the ordinary labels/buttons. Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` and a negative z-index so it overlays the world but stays behind HUD content.

Use two constants in `game_hud.gd`:

```gdscript
const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)
```

`render(snapshot)` selects one from the existing `weather` key. Do not add animation, particles, shaders, or another weather state.

### 2.4 GREEN — add one reusable ground shadow texture

- [ ] Create `assets/sprites/proof-shadow.png` as a small soft/translucent ellipse on a transparent background. Keep it nearest-filter friendly and neutral; no projected light direction.

- [ ] Reuse that one texture under the player, tree, building, shipping bin, harvest market, and three villagers. Put each shadow under the existing entity root before the visible sprite so Y-sort still operates on the entity root’s bottom-center ground contact.

- [ ] In `FarmView._ready()`, create a shadow `Sprite2D` under each dynamic crop root before the crop sprite, reuse the same texture, scale it smaller, and keep `shadow.visible == crop.visible` in `refresh()`.

- [ ] Run a headless import to generate/refresh the `.import` sidecar and commit the source-adjacent import file:

```bash
godot --headless --path . --editor --quit
```

- [ ] Do not add fence sprites. There is no fence entity in the authored HPA-590/HPA-597 world.

### 2.5 Document the art contract

- [ ] Add a concise `Sprite-isometric art contract` section to `CLAUDE.md` with exactly these ownership rules:

  - 64×32 ground diamonds;
  - entity root = bottom-center ground contact;
  - sprite art offsets upward from that root;
  - shadows stay as children on the ground plane;
  - `Entities` remains the only Y-sort owner;
  - nearest texture filtering + integer scaling remain mandatory.

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** all GUT/headless checks pass.

- [ ] Commit:

```bash
git add assets/sprites/proof-shadow.png assets/sprites/proof-shadow.png.import \
  scenes/player/player.tscn scenes/world/world.tscn scenes/ui/game_hud.tscn \
  scenes/ui/pause_help.tscn scripts/world/farm_view.gd scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd tests/headless/world_shell_smoke.gd CLAUDE.md
git commit -m "feat: polish world readability and controls"
```

---

## Task 3: Add the minimal placeholder audio pass

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

### 3.1 Generate a deliberately small project-owned placeholder set

- [ ] Generate eight mono PCM WAV files at 22,050 Hz. They are placeholders, not a music-production task. Keep SFX under 250 ms and the loop under 8 seconds.

Use Python’s standard library (`wave`, `math`, `struct`) in a one-off local command or temporary script; do not add a runtime dependency. Use simple sine/triangle envelopes with conservative amplitudes. The intended identities are:

| File | Use |
| --- | --- |
| `action.wav` | till/plant/water/harvest |
| `commerce.wav` | purchase/shipping |
| `social.wav` | talk/gift/relationship gain |
| `confirm.wav` | modal confirm/open/save success |
| `cancel.wav` | cancel/guard/error feedback |
| `day-transition.wav` | sleep/wake/morning |
| `finale.wav` | terminal result transition |
| `farm-day-loop.wav` | quiet background loop |

- [ ] Add `assets/audio/README.md` stating that these are project-generated placeholder tones with no external attribution dependency and are intentionally disposable if real audio replaces them later.

- [ ] Import them:

```bash
godot --headless --path . --editor --quit
```

Commit the generated `.wav.import` sidecars with the source WAV files.

### 3.2 RED — pin wiring, not audio output bytes

- [ ] Add integration assertions that `GameHud/SfxPlayer` and `GameHud/MusicPlayer` exist; music has `farm-day-loop.wav`; and representative calls switch the SFX stream to the expected resource path:

  - `SOIL_TILLED` → `action.wav`;
  - `SEEDS_PURCHASED` → `commerce.wav`;
  - `CROP_GIFTED` → `social.wav`;
  - `DAY_ADVANCED` → `day-transition.wav`;
  - `FINALE_TRIGGERED` → `finale.wav`;
  - a guard such as `INSUFFICIENT_STAMINA` → `cancel.wav`.

Do not assert waveform samples or speaker output in CI.

### 3.3 GREEN — keep audio inside GameHud

- [ ] Add only two `AudioStreamPlayer` children to `scenes/ui/game_hud.tscn`:

```text
GameHud/SfxPlayer
GameHud/MusicPlayer
```

Use conservative defaults (roughly `-8 dB` SFX, `-20 dB` music). Assign the music stream in the scene. Restart it from the player’s `finished` signal to loop; no audio bus or manager is needed.

- [ ] In `game_hud.gd`, preload the seven SFX resources and add one private `_play_sfx(stream)` helper. Call it from the existing `show_feedback()` command-code mapping and from modal open/close paths where there is no command code.

Keep the semantic mapping narrow:

```text
farming successes -> action
purchase/deposit -> commerce
talk/gift -> social
DAY_ADVANCED -> day-transition
FINALE_TRIGGERED -> finale
invalid/guard command -> cancel
modal open / save success -> confirm
modal close -> cancel
```

Do not add volume sliders/settings. If the manual package pass finds the mix too loud/quiet, adjust the two player `volume_db` values or source amplitudes.

- [ ] Run:

```bash
./tools/verify-clean.sh
```

**Expected:** PASS.

- [ ] Commit:

```bash
git add assets/audio scenes/ui/game_hud.tscn scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd
git commit -m "feat: add lightweight release audio feedback"
```

---

## Task 4: Turn the existing macOS preset into a CI release gate and refresh release docs

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify only if export exposes a concrete preset problem: `export_presets.cfg`
- Modify: `README.md`
- Modify: `CLAUDE.md`

### 4.1 RED — verify the current CI environment cannot export yet

- [ ] Before changing CI, run locally (or reproduce in a clean environment without templates):

```bash
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```

**Expected in a template-less environment:** export fails because Godot export templates are not installed. This proves the CI change is necessary; do not change the preset merely to manufacture a diff.

### 4.2 GREEN — extend the existing main CI job

- [ ] In `.github/workflows/ci.yml`, keep Godot pinned to `4.7.1` and change the setup step to install export templates:

```yaml
with:
  version: 4.7.1
  use-dotnet: false
  include-templates: true
```

- [ ] Keep `./tools/verify-clean.sh` as the first release gate, then add:

```yaml
- name: Export unsigned macOS build
  run: |
    mkdir -p build
    godot --headless --path . --export-release "macOS" build/Phoenix.zip
    unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"

- name: Upload macOS build
  uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
  with:
    name: phoenix-macos
    if-no-files-found: error
    path: build/Phoenix.zip
```

Use the already-pinned upload-artifact revision from the GdUnit/e2e workflows; do not introduce an unpinned action.

- [ ] Do not add a macOS runner solely for export. Godot’s macOS preset supports `.zip` output with the standard export templates, and the CI gate only needs an unsigned package for manual MVP verification.

- [ ] Leave `export_presets.cfg` unchanged if the command succeeds. If Godot reports a concrete missing preset option, make only that required edit and keep bundle id/version `com.hapadona.phoenix` / `0.1.0` unless the error is specifically about them.

### 4.3 Refresh player/handoff instructions

- [ ] Update `README.md` with a short **Export macOS** section:

```bash
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```

State that HPA-599 produces an unsigned test build only; signing/notarization are out of scope.

- [ ] Update `README.md` controls with `Esc — close modal / open controls`.

- [ ] Update `CLAUDE.md` so the handoff no longer describes `verify-clean.sh` as the only CI lane: name the existing GUT/headless verifier, GdUnit4 unit flow, godot-e2e flow, and macOS export gate separately. Keep the architecture section unchanged except for the art/audio/help presentation ownership added by HPA-599.

- [ ] Run local export with templates installed:

```bash
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

**Expected:** both commands exit 0 and the ZIP contains the app executable.

- [ ] Commit:

```bash
git add .github/workflows/ci.yml README.md CLAUDE.md export_presets.cfg
git commit -m "ci: verify unsigned macOS release export"
```

If `export_presets.cfg` did not change, omit it from `git add`.

---

## Task 5: Run the release gates, perform one exported 14-day playthrough, and tune only observed defects

**Files:**
- Modify only when a concrete release defect is found: existing rule/presentation/test files from Tasks 1–4
- No new report file; record the manual result in the existing HPA-599 PR description/checklist

### 5.1 Run every automated gate from the final branch

- [ ] Broad clean checkout/GUT/headless:

```bash
./tools/verify-clean.sh
```

- [ ] GdUnit4:

```bash
./tools/bootstrap-gdunit.sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
```

- [ ] godot-e2e:

```bash
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

- [ ] macOS export:

```bash
rm -rf build
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

All four gates must pass before the manual release run.

### 5.2 Confirm the already-existing balance/persistence acceptance tests still cover the release contract

- [ ] Verify that the final GUT run still includes and passes:

  - `tests/unit/test_game_rules.gd` exact starter/crop/action/weather values;
  - `tests/unit/test_content_rules.gd` all three result tiers, 150G Promising boundary, 300G + Close Friend Heart boundary, and a reachable value below each boundary;
  - `tests/integration/test_persistence_flow.gd` representative complete-morning save/Continue equivalence;
  - `tests/integration/test_persistence_flow.gd` Day 14 pre-finale market/bed equivalence and save-once behavior.

Do not add duplicate tests if those contracts remain covered.

### 5.3 Run one normal exported macOS playthrough

- [ ] Unpack `build/Phoenix.zip` on macOS and launch the exported `Phoenix.app`.

- [ ] Start from **New Game** and play normally through the Day 14 result. Do not use debug state injection for this pass.

Record pass/fail for this compact checklist in the PR description:

```text
[ ] Onboarding + Esc controls are enough without README/dev instructions
[ ] Hoe / Seeds / Water / Hands show correct green/red target state and clear result text
[ ] Dry/wet soil and crop growth stages are readable at 1×
[ ] Purchase, shipping income, gift/relationship change, sleep/wake/save, finale are readable/audible
[ ] Tree/building/mature-crop/villager crossings keep correct front/behind order
[ ] 640×360 and one smaller host-window check remain crisp and usable
[ ] Continue from a representative midgame morning restores the same playable state
[ ] Continue immediately before finale restores the same playable state
[ ] No purchase/shipping/gift/finale action processes twice
[ ] Representative economy reaches a satisfying result without a hidden strategy
[ ] Day 14 reaches exactly one terminal result and no post-game/free-play state
```

### 5.4 Apply only evidence-backed tuning

- [ ] If every balance item passes, **leave `GameRules`, `VillagerRules`, and `ContentRules` numeric values unchanged**.

- [ ] If the playthrough exposes a concrete economy/social/prompt problem, change the smallest existing constant/table entry that fixes it, update its exact-value test in the same commit, and rerun Tasks 5.1–5.3 for the affected path. Do not add difficulty levels, dynamic scaling, simulation/solver code, or a second tuning data layer.

- [ ] If the playthrough exposes an audio/readability problem, adjust the existing asset/player/color value in place. Do not create a settings framework.

### 5.5 Final branch/PR self-review

- [ ] Confirm `git diff main...HEAD` contains only HPA-599 design/plan + closeout implementation.
- [ ] Confirm no second runtime, save migration, generic manager, or new gameplay feature slipped in.
- [ ] Confirm CI pins remain explicit and `persist-credentials: false` remains intact in the GdUnit/e2e workflows.
- [ ] Confirm the PR remains one HPA-599 PR and the manual checklist is recorded in its description.

- [ ] Final commit only if the manual pass required fixes:

```bash
git add <only-files-changed-by-observed-fix>
git commit -m "fix: address HPA-599 release playthrough findings"
```

When all automated gates, the exported 14-day pass, and the PR checklist are green, mark the PR ready for review and move HPA-599 to In Review.
