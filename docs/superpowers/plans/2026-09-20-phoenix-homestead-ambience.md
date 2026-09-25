# Phoenix River and Rain Homestead Ambience Implementation Plan

**Linear:** HPA-462
**Audio dependency:** HPA-440 gates Task 3; Tasks 3-4 ship on the follow-up PR
**Branch:** `agent/hpa-462-homestead-ambience-plan`
**Spec:** `docs/superpowers/specs/2026-09-20-phoenix-homestead-ambience-design.md`

**Goal:** Add restrained river motion, readable rain, and world-owned environmental audio while leaving gameplay time, weather rules, save state, map/collision, and the existing HUD tint behavior unchanged.

**Architecture:** Add one direct World child, `HomesteadAmbience`, after `FarmActionEffects`. It owns three ripple sprites, deterministic `Line2D` rain, and—after HPA-440 lands—the two ambient audio players. `WorldShell._refresh_from_session()` keeps one snapshot and fans it to `FarmView`, `HomesteadAmbience`, and `GameHud`.

## Global constraints

- HPA-462 ships as two PRs. PR #19 (`agent/hpa-462-homestead-ambience-plan`) carries the visual slice — Tasks 1, 2, and 5 — and merges without waiting for HPA-440.
- Tasks 3-4 stay under HPA-462 but land on a separate follow-up PR branched from `main` after the HPA-440 WAVs exist. They do not land on PR #19.
- Evening/window-light work is deleted. Current gameplay tops out theoretically at 12:40, so 18:00 content is unreachable.
- Leave `GameHud.SUNNY_TINT`, `RAINY_TINT`, and the existing `GameHud.render(snapshot)` tint expression unchanged.
- Do not create a shared tint/time projection helper.
- HPA-458 supplies `river-ripple.png`; `house-window-light.png` is not consumed.
- HPA-440 gates only Task 3 audio integration. Tasks 1-2 and the capture harness proceed and merge on PR #19.
- No placeholder audio in HPA-462.
- No `GameSession`/save/schema/game-clock/weather-policy/balance changes.
- No autoload/global service, particles framework, shader/lighting system, settings row, audio bus, spatial audio, or new golden framework.
- Visual density/positions are tunable through native evidence rather than frozen in headless contracts.

## Task 1: Add the bounded world presenter and river ripples

**Files:**

- create `scripts/world/homestead_ambience.gd`
- generated script UID if Godot creates it
- `scenes/world/world.tscn`
- `tests/headless/world_shell_smoke.gd`

### 1.1 Add the scene seam

In `world.tscn`:

- [ ] add exactly one direct `HomesteadAmbience` node immediately after `FarmActionEffects` and before `StaticCollision`;
- [ ] attach `scripts/world/homestead_ambience.gd`;
- [ ] do not add `WindowLight` or touch House children;
- [ ] do not change map/collision nodes.

Update `world_shell_smoke.gd` exact World child order for this one new node.

### 1.2 Create exactly three ripple sprites

`HomesteadAmbience` creates three `Sprite2D` ripples using `river-ripple.png`.

Initial authored logical centers:

- `Vector2(1.0, 6.5)`;
- `Vector2(1.0, 13.0)`;
- `Vector2(6.5, 19.0)`.

For each:

- [ ] position via `WorldMath.grid_to_world()`;
- [ ] `hframes = 3`;
- [ ] `scale = Vector2(1, 1)`;
- [ ] `offset = Vector2.ZERO`;
- [ ] no flip/rotation;
- [ ] render above `FarmSoil` / `FarmActionEffects` and below `TargetHighlight` / `Entities`.

The logical centers are implementation candidates, not smoke-test constants.

### 1.3 Reuse the existing Tween animation idiom

Animate each strip with a bound looping Tween instead of hand-rolled frame math in `_process()`.

- [ ] advance frame 0→2 at roughly 2 fps;
- [ ] use small start delays, applied once before each looping Tween starts, to avoid perfect lockstep;
- [ ] let final native review tune rate/delay.

Do not introduce `AnimatedSprite2D`, SpriteFrames resources, or an animation manager for three strips.

### 1.4 Structural smoke assertions only

Pin:

- [ ] one `HomesteadAmbience` direct World child in the exact scene position;
- [ ] exactly three ripple children;
- [ ] correct ripple texture;
- [ ] `hframes = 3`;
- [ ] `scale = Vector2(1, 1)`;
- [ ] `offset = Vector2.ZERO`;
- [ ] ambience visual layering is above soil/effects and below target/entities.

Do **not** pin exact ripple positions, initial frames, tween delays, or speed.

**Checkpoint:** run `world_shell_smoke.gd` and `git diff --check`.

## Task 2: Add deterministic rain and snapshot wiring

**Files:**

- `scripts/world/homestead_ambience.gd`
- `scripts/world/world_shell.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/headless/world_shell_smoke.gd`

### 2.1 Setup only the world references needed

Add:

`setup(camera: Camera2D)`

for the visual-only stage. Store the existing player camera; no gameplay/session object is passed to the presenter.

`WorldShell._ready()` calls setup once.

### 2.2 Build deterministic Line2D rain

Create one set of reusable `Line2D` streaks.

Start `RAIN_STREAK_COUNT` around 72 as an implementation default, but keep it explicitly tunable after native review.

Each streak:

- [ ] one pixel wide;
- [ ] short, pale, low-alpha, consistently slanted;
- [ ] deterministic from its index;
- [ ] no RNG;
- [ ] rendered above soil/ripples and below target/entities.

Smoke pins only the z-order relationship, not count/alpha/geometry.

### 2.3 One layout function used by render and process

Add private:

`_layout_rain(phase: float)`

It positions/wraps streaks around `camera.get_screen_center_position()` across the 640x360 viewport.

`render(snapshot)`:

- [ ] derives `rainy` directly from `snapshot["weather"]`;
- [ ] shows/hides the rain lines;
- [ ] when rainy, calls `_layout_rain(_rain_phase)` immediately;
- [ ] does not change gameplay state.

`_process(delta)`:

- [ ] does nothing when sunny;
- [ ] advances only `_rain_phase` when rainy;
- [ ] calls `_layout_rain(_rain_phase)`.

Ripple animation stays on Tweens; `_process()` owns rain movement only.

### 2.4 Keep the existing snapshot fan-out

Add `@onready var _homestead_ambience` to `WorldShell`.

Keep `_refresh_from_session()` as:

```gdscript
var snapshot := _session.snapshot()
farm_view.refresh(snapshot)
_homestead_ambience.render(snapshot)
hud.render(snapshot)
_refresh_world_input_gate()
```

Do not touch `GameHud` tint code in this task.

### 2.5 Focused integration coverage

Add only behavior worth guarding:

- [ ] rainy snapshot -> rain lines visible;
- [ ] sunny snapshot -> rain lines hidden;
- [ ] refreshing rain presentation does not mutate the session snapshot/farm state;
- [ ] the same rain-line instances are reused across rainy/sunny/rainy refreshes.

Do not add the earlier "wait several frames and prove time does not advance" test; evening/passive-clock behavior no longer exists in this feature.

**Checkpoint:** run affected gameplay-shell integration + headless smoke and `git diff --check`.

## Task 3: Integrate HPA-440 audio when its assets land

This task and Task 4 ship on the follow-up PR, not on PR #19.

**Start gate:** HPA-440 merged with:

- `assets/audio/river-ambience.wav`
- `assets/audio/rain-ambience.wav`
- forward-loop Godot import sidecars.

Branch the follow-up PR from current `main` after the assets land. Do not continue on `agent/hpa-462-homestead-ambience-plan` and do not create placeholder WAVs.

**Files:**

- `scripts/world/homestead_ambience.gd`
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `tests/integration/test_gameplay_shell.gd`

### 3.1 Add exactly two world-owned players

Create:

- `RiverAmbience`
- `RainAmbience`

Both are children of `HomesteadAmbience`.

Preload only the two HPA-440 streams. No audio registry/service.

### 3.2 Make initial volume independent of HUD signal ordering

Evolve setup to:

`setup(camera: Camera2D, settings: UiSettings)`

During setup:

- [ ] resolve `settings.db_for_level(settings.sound)`;
- [ ] apply `AMBIENCE_HEADROOM_DB := -12.0`;
- [ ] keep incoming mute at -80 dB;
- [ ] apply the resolved volume to both players;
- [ ] start River immediately after volume is resolved.

A missed live-settings signal therefore cannot leave startup permanently silent.

### 3.3 Keep one narrow live-settings notification

Add to `GameHud`:

`signal sound_volume_changed(volume_db: float)`

`GameHud.apply_settings()` emits the current Sound dB after its existing SFX assignment.

`WorldShell` connects this signal to:

`HomesteadAmbience.set_sound_volume_db(volume_db)`

for live settings changes.

Initial correctness comes from `setup(..., _settings)`, not from catching the first signal emission.

Do not add a settings bus or access `_settings_panel`.

### 3.4 Weather controls only Rain playback

Extend `render(snapshot)`:

- [ ] rainy -> play Rain if not already playing;
- [ ] sunny -> stop Rain if playing;
- [ ] repeated rainy renders do not restart the stream;
- [ ] River stays playing for the World lifetime.

### 3.5 Audio integration tests

Pin:

- [ ] exactly one River and one Rain player;
- [ ] expected stream paths;
- [ ] streams import as forward loops;
- [ ] Sound=0 -> both players at -80 dB;
- [ ] normal Sound applies the -12 dB headroom;
- [ ] live Sound changes update the same player instances;
- [ ] Music-only adjustment does not change ambience volume;
- [ ] rainy/sunny toggles Rain playback without recreating the player.

No speaker-dependent test.

**Checkpoint:** run the affected GUT/integration suite, manually check Sound 7 -> 0 -> 7 in native play, and run `git diff --check`.

## Task 4: Extend the existing result teardown/new-game test after Task 3

Ships on the follow-up PR with Task 3.

**Files:**

- `tests/integration/test_persistence_flow.gd`
- production code only if this existing path exposes a real lifecycle defect

Extend only:

`test_result_return_to_title_reloads_save_and_new_game_keeps_slot()`

- [ ] retain old River/Rain player references before the finale;
- [ ] after the existing `_await_world_teardown(app)`, assert both old instances are invalid;
- [ ] keep the existing Continue/result behavior unchanged;
- [ ] after the existing same-frame New Game, assert the fresh World owns exactly one River and one Rain player.

Do not add a separate free-world test, another restore clone, or "players cannot be under AppRoot/Title/Result" assertions. Child ownership already makes reparenting outside World impossible unless new code explicitly does it.

**Checkpoint:** run the affected persistence integration test.

## Task 5: Add two fixed-phase native captures

The capture harness can be built before HPA-440; final evidence can be refreshed after audio integration without changing its visual contract.

**Files:**

- create `tests/visual/capture_homestead_ambience.gd`
- generated UID if Godot creates it
- no committed golden files

### 5.1 Capture only live visual states

Capture at a normal reachable daytime value such as 09:20:

- `sunny`
- `rainy`

No evening fixtures.

### 5.2 Freeze animation before it can advance

For each state:

- [ ] build a complete valid initial state with `intro_acknowledged = true`;
- [ ] instantiate `world.tscn` off-tree;
- [ ] call `world.configure(initial_state, null, UiSettings.new())` before `add_child()`;
- [ ] set `HomesteadAmbience.process_mode = Node.PROCESS_MODE_DISABLED` before adding the World so both `_process()` and bound ripple Tweens remain frozen;
- [ ] add the World;
- [ ] allow the minimum frame needed for camera/world setup;
- [ ] call `HomesteadAmbience.render(world._session.snapshot())` once after camera setup so rainy state executes `_layout_rain(0.0)` at the correct screen center;
- [ ] capture exactly 640x360 to `test_output/hpa-462/`.

Do not extend `capture_ui_states.gd`, `compare_ui_states.gd`, or the permanent golden set.

### 5.3 Manual review and tuning

Review the two images together.

Required:

- [ ] sunny state still looks like current Phoenix;
- [ ] rainy state clearly contains visible rain;
- [ ] HUD/target/crops remain readable;
- [ ] ripples remain visually inside water;
- [ ] specifically inspect west-bank overhang around the two west-river candidates.

Allowed tuning without changing architecture/tests:

- ripple logical centers;
- ripple tween rate/start delays;
- `RAIN_STREAK_COUNT`;
- rain alpha;
- line length/slant;
- rain fall speed.

The headless smoke should not need edits when these values are tuned.

### 5.4 Final verification

Before the final implementation commit:

- [ ] run the full existing worktree GUT suite;
- [ ] run project/world-math/world-shell headless smokes;
- [ ] generate and inspect both HPA-462 captures;
- [ ] run `git diff --check`.

After committing:

- [ ] run `./tools/verify-clean.sh` because it verifies committed HEAD;
- [ ] re-run `git diff --check`;
- [ ] attach/reference the two captures in PR #19;
- [ ] keep the PR draft until review findings are addressed.

## Expected final diff

Runtime:

- `scripts/world/homestead_ambience.gd`
- generated UID as needed
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd` — Sound signal only (follow-up PR)
- `scenes/world/world.tscn`

Tests/evidence:

- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd` (follow-up PR)
- `tests/headless/world_shell_smoke.gd`
- `tests/visual/capture_homestead_ambience.gd`
- generated UID as needed

Planning:

- `docs/superpowers/specs/2026-09-20-phoenix-homestead-ambience-design.md`
- `docs/superpowers/plans/2026-09-20-phoenix-homestead-ambience.md`

HPA-440, not this PR, owns the two WAV files, import sidecars, and audio provenance notes.

Explicitly absent:

- `GameSession` / `GameRules` changes;
- `WindowLight` / house scene changes;
- evening tint/time-of-day helpers;
- `UiSettings` / `SettingsPanel` changes;
- unit-test-only presentation abstractions;
- existing UI-golden changes;
- audio asset generation.
