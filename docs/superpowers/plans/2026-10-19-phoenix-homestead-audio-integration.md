# HPA-402 — River and Rain Audio Implementation Plan

**Issue:** [HPA-402](https://linear.app/cwchanap/issue/HPA-402/homestead-polish-integrate-river-and-rain-ambience-audio-after-hpa-440)  
**Design:** [2026-10-19-phoenix-homestead-audio-integration-design.md](../specs/2026-10-19-phoenix-homestead-audio-integration-design.md)  
**Delivery:** one PR `agent/hpa-402-homestead-audio-plan`, opened draft with docs; complete production/test changes on **this branch and PR**, never a second PR for HPA-402.  
**Dependency:** HPA-440 PR #20 **merged** into `main` on 2026-10-18. HPA-462 PR #19 already owns the visuals. This plan is the still-unimplemented Tasks 3–4 of the original [homestead ambience plan](2026-09-20-phoenix-homestead-ambience.md). That original document remains historical and is not another implementation assignment.

## 0. Baseline / reuse checks

- [ ] Confirm both WAVs and `.import` sidecars load from `main`, and the existing `tests/headless/project_smoke.gd` covers their forward-loop import properties (HPA-440 owns these).
- [ ] Inspect `scripts/world/homestead_ambience.gd`, `scripts/world/world_shell.gd`, `scripts/ui/game_hud.gd`, `scenes/world/world.tscn`, `scripts/ui/ui_settings.gd`, and existing tests. Do not replace the existing world/presenter/settings path.
- [ ] Run/record clean baseline verification if Godot is available. The **planning-only commit has not run the Godot suite**.

## 1. Add two World-owned players + volume setup

**Files:** `scenes/world/world.tscn`, `scripts/world/homestead_ambience.gd`

- [ ] Add two external `AudioStream` resources for `res://assets/audio/river-ambience.wav` and `res://assets/audio/rain-ambience.wav`; add child `AudioStreamPlayer` nodes `HomesteadAmbience/RiverAmbience` and `HomesteadAmbience/RainAmbience` with those streams. No replacement/clone streams, buses or looping scripts.
- [ ] Bind both children with typed `@onready` refs. Add `AMBIENCE_HEADROOM_DB := -12.0`.
- [ ] Add `set_sound_volume_db(sound_db: float)`: if input is mute (`<= -80.0`), set both to `-80.0`; otherwise set both to `sound_db - 12.0`.
- [ ] Add `setup(settings: UiSettings)`: call `set_sound_volume_db(settings.db_for_level(settings.sound))` then `play()` River once. Do not store `settings` or camera.
- [ ] Extend existing `render(snapshot)` with conditional Rain play/stop and no restart while already playing. Preserve `_rain_falling`, `set_process`, `queue_redraw` and all ripple behavior.

**Checkpoint:** verify scene parses; at first World creation both streams are attached, River plays and Rain reflects first snapshot.

## 2. Wire live Sound settings at existing seam

**Files:** `scripts/ui/game_hud.gd`, `scripts/world/world_shell.gd`

- [ ] Declare `signal sound_volume_changed(volume_db: float)` on `GameHud`.
- [ ] Emit the current sound dB from `GameHud.apply_settings()` after `_sfx_player.volume_db = ...` (respect existing early return). Do not alter Music logic or change SettingsPanel.
- [ ] In `WorldShell._ready()`, after HUD configuration, call `_homestead_ambience.setup(_settings)` and connect `hud.sound_volume_changed` to `_homestead_ambience.set_sound_volume_db` before the existing `_refresh_from_session()`. Initial setup is direct, not signal-dependent.
- [ ] Check that the current one-snapshot fanout `farm_view.refresh -> ambience.render -> hud.render` is unchanged.

**Checkpoint:** Sound adjustments update the same River/Rain players; changing Music alone leaves their dB unchanged; Sound 0 stays -80 rather than -92.

## 3. Focused gameplay-shell integration coverage

**File:** `tests/integration/test_gameplay_shell.gd`

Reuse `_spawn_world(..., UiSettings)` / `_settings_world()` and their isolated `SETTINGS_PATH`. Extend the existing Sound/Settings and rain test area, rather than adding a new audio test suite.

- [ ] Verify `HomesteadAmbience` has **exactly** one `RiverAmbience` and one `RainAmbience`, with the HPA-440 stream paths and `AudioStreamWAV.LOOP_FORWARD`; runtime ripple children stay unchanged.
- [ ] Verify startup default Sound 7 -> `-24.0` dB; startup Sound 0 -> `-80.0` dB **without** needing to invoke `apply_settings()` after World creation.
- [ ] Change Sound 7 -> 0 -> 7 through existing settings flow, asserting both dB values and original player instance identities. Change Music only and assert the two audio volume values do not change.
- [ ] Verify initial rainy/sunny snapshot state and rainy -> rainy -> sunny -> rainy behavior, using `WorldShell._refresh_from_session()` for at least one real rainy session; Rain toggles without replacing instances, River stays playing.
- [ ] Do not add frame-count, RMS, audio waveform, loop-seam or repeated no-op-render tests beyond needed behavior; HPA-440 has asset validation.

**Checkpoint:** run targeted GUT checks and record result.

## 4. Extend existing lifecycle test only

**File:** `tests/integration/test_persistence_flow.gd`

In `test_result_return_to_title_reloads_save_and_new_game_keeps_slot()`:

- [ ] Before `world.interact()`, retain references to both World-owned players.
- [ ] After `_await_world_teardown(app)`, ensure queued deletion has actually flushed (if needed, await one process frame) before asserting `not is_instance_valid(old_river)` and `not is_instance_valid(old_rain)`.
- [ ] Keep Continue/result/save-slot logic and all current assertions.
- [ ] After the existing same-frame New Game, assert the **fresh World** owns exactly one River player and one Rain player, both different from the freed refs. No separate free-world test or reparenting assertions.

**Checkpoint:** run the existing persistence-flow suite.

## 5. Final verification and PR follow-through

- [ ] Run the affected gameplay-shell and persistence-flow GUT tests and the existing headless smoke(s), then `./tools/verify-clean.sh` on **committed HEAD**.
- [ ] Run `git diff --check` and review the focused runtime/test diff for YAGNI/KISS compliance.
- [ ] In native Godot play, exercise Sound 7 -> 0 -> 7 during sunny/rainy World and Music-only adjustment; verify quiet ambience and no harsh restart. Record actual observations, not inferred results.
- [ ] Update this PR description with verification evidence; address review in the same PR, then mark ready when implementation is complete.

## Expected implementation diff (after this documentation-only draft)

- `scenes/world/world.tscn`
- `scripts/world/homestead_ambience.gd`
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_persistence_flow.gd`

Not expected: audio asset/sidecar changes, `UiSettings`, `SettingsPanel`, `GameSession`, `GameRules`, saves, the visual-capture framework, or new services.
