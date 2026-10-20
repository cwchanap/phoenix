# HPA-402 — River and Rain Audio Implementation Plan

**Issue:** [HPA-402](https://linear.app/cwchanap/issue/HPA-402/homestead-polish-integrate-river-and-rain-ambience-audio-after-hpa-440)  
**Design:** [2026-10-19-phoenix-homestead-audio-integration-design.md](../specs/2026-10-19-phoenix-homestead-audio-integration-design.md)  
**Delivery:** **one PR #21**, branch `agent/hpa-402-homestead-audio-plan`: draft planning now; put all tests and implementation into this same PR.  
**Upstream:** HPA-440 PR #20 merged both audio loops; HPA-462 PR #19 finished the visual presenter. The earlier [HPA-462 Tasks 3–4](2026-09-20-phoenix-homestead-ambience.md) are **superseded**, not a parallel implementation checklist.

## Baseline and minimal reuse

- [ ] Confirm existing `GameHud._build_audio()`, `apply_settings()`, `render(snapshot)` and `_play_sfx()` behavior. The HUD builds/owns Sfx and Music players, applies both preferences, handles rainy tint and checks `is_inside_tree()` before SFX playback.
- [ ] Confirm exact HPA-440 assets exist and `tests/headless/project_smoke.gd` already enforces full-clip `AudioStreamWAV.LOOP_FORWARD`; don't add asset-loop tests or edit WAVs.
- [ ] Confirm existing helpers/tests: `_spawn_world`, `_settings_world`, `SETTINGS_PATH`, the app launch tests and the gameplay-shell HUD/audio/settings/rain tests.
- [ ] Record baseline verification if Godot is available; **this planning-only draft has not run GUT or native playback**.

## Task 1 — Add failing regression assertions first

**Files:** `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_app_launch.gd`

- [ ] Extend `test_hud_audio_players_and_representative_feedback_streams()` to find exactly one `RiverAmbience` and `RainAmbience` HUD child each. Assert streams at the exact resource paths, River playing and default Sound 7 -> **-24 dB**. Preserve SFX/music checks.
- [ ] In `test_new_game_propagates_settings_and_tutorial_toggle_to_world_hud()`, assert existing startup Sound 10 results in **-12 dB** on both ambience players. In `test_settings_environment_path_is_loaded_without_using_save_override()`, set startup Sound 0 and assert **-80 dB** on both. Do not invoke `apply_settings()` again to make either test pass.
- [ ] In `test_settings_adjustment_persists_in_isolated_path_and_applies_audio()`, assert Music-only change doesn't alter River/Rain volume, navigate once to Sound, adjust once and verify both players' new dB without replacement. Reuse the existing SettingsPanel action flow.
- [ ] Add **one** focused `test_game_hud_rain_playback_follows_world_refresh()` in gameplay-shell: rainy -> repeated rainy -> sunny -> rainy through `_refresh_from_session()` on a valid restored session state/history. Assert Rain starts/stops without replacing its node, River continues playing and session weather isn't mutated by the presenters. Include a detached-HUD rainy render playback guard only if it fits the same focused test without a new harness.
- [ ] Run these target tests and record the expected failures **before** runtime changes. Do not add new suites or duplicate smoke assertions.

**Checkpoint:** failures must be for missing ambience behavior, not unrelated fixture errors.

## Task 2 — Implement the existing HUD audio seam

**File:** `scripts/ui/game_hud.gd` (**the only runtime file**)

- [ ] Preload `RIVER_AMBIENCE` and `RAIN_AMBIENCE` from their exact `res://assets/audio/*-ambience.wav` paths. Add `AMBIENCE_HEADROOM_DB := -12.0` and typed River/Rain player fields.
- [ ] Extend `_build_audio()` to create `RiverAmbience` and `RainAmbience` as named ordinary `AudioStreamPlayer` children of HUD, assign streams, initialize both `volume_db = -80.0`, and play River once after adding it. Leave Music/SFX setup unchanged.
- [ ] Extend the existing `apply_settings()` with the current Sound dB applied to **both** ambience players as `maxf(sound_db + AMBIENCE_HEADROOM_DB, -80.0)`. Preserve Music and SFX assignments and the existing settings guard. Sound 0 stays -80, Sound 7 -> -24, Sound 10 -> -12.
- [ ] In `render(snapshot)` reuse the weather condition already used by `WeatherTint`: start Rain only if rainy, `is_inside_tree()`, and not playing; stop Rain on sunny only if playing. **Do not early-return the full HUD render** when detached. No restart for repeated rainy renders.
- [ ] Keep `HomesteadAmbience` as the existing visual-only World child; make **no changes** to `world.tscn`, `world_shell.gd`, `homestead_ambience.gd`, `UiSettings`, `SettingsPanel` or `test_persistence_flow.gd`. No new signal, setup method or audio manager.

**Checkpoint:** re-run Task 1 tests. Verify the old `HomesteadAmbience.new()` without-camera test still works because that class was untouched.

## Task 3 — Verify and review mix

- [ ] Run affected `test_gameplay_shell.gd` and `test_app_launch.gd` GUT tests, plus existing headless smokes, and `./tools/verify-clean.sh` on committed HEAD. Run `git diff --check`.
- [ ] Native play: Sunny -> Rainy -> Sunny, Sound 7 and 0, a single live Sound adjustment, and Music-only adjustment. At **Sound 7 on a rainy day**, farm/harvest feedback must stay clearly audible over both ambient streams; rain should not restart on a redundant snapshot. Record actual listening observations (do not infer from RMS).
- [ ] Keep a focused diff: one runtime file and two existing integration test files, plus design/plan docs and the historical supersession line. No lifecycle test, new WAVs, audio buses, smoke duplication or new PR.
- [ ] Update PR #21's checklist and attach verified evidence. Keep draft until implementation and verification are actually complete.

## Risk

The main uncertainty is perceptual mix balance when River + Rain + Music + farm SFX play simultaneously. The fixed -12 dB headroom is a starting value, not proven by the preexisting single-asset loudness measurements. Tune only if native evidence requires it.

## Expected final implementation diff

- `scripts/ui/game_hud.gd` — **only runtime change**
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`

Explicitly **unchanged**: `scripts/world/homestead_ambience.gd`, `scripts/world/world_shell.gd`, `scenes/world/world.tscn`, `tests/integration/test_persistence_flow.gd`, audio source/import files and unrelated game logic.
