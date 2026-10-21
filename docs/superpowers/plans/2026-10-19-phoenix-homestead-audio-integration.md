# HPA-402 — River and Rain Audio Implementation Plan

**Issue:** [HPA-402](https://linear.app/cwchanap/issue/HPA-402/homestead-polish-integrate-river-and-rain-ambience-audio-after-hpa-440)  
**Design:** [2026-10-19-phoenix-homestead-audio-integration-design.md](../specs/2026-10-19-phoenix-homestead-audio-integration-design.md)  
**Delivery:** **one PR #21**, branch `agent/hpa-402-homestead-audio-plan`: draft planning now; put all tests and implementation into this same PR.  
**Upstream:** HPA-440 PR #20 merged both audio loops; HPA-462 PR #19 finished the visual presenter. The earlier [HPA-462 Tasks 3–4](2026-09-20-phoenix-homestead-ambience.md) are **superseded**, not a parallel implementation checklist.

## Baseline and minimal reuse

- [x] Confirm existing `GameHud._build_audio()`, `apply_settings()`, `render(snapshot)` and `_play_sfx()` behavior. The HUD builds/owns Sfx and Music players, applies both preferences, handles rainy tint and checks `is_inside_tree()` before SFX playback.
- [x] Confirm exact HPA-440 assets exist and `tests/headless/project_smoke.gd` already enforces full-clip `AudioStreamWAV.LOOP_FORWARD`; don't add asset-loop tests or edit WAVs.
- [x] Confirm existing helpers/tests: `_spawn_world`, `_settings_world`, `SETTINGS_PATH`, the app launch tests and the gameplay-shell HUD/audio/settings/rain tests.
- [x] Baseline verification recorded: focused GUT runs of `test_gameplay_shell.gd` and `test_app_launch.gd` are green on this branch. The human native-listening gate was removed at owner direction (2026-10-20) — see Task 3.

## Task 1 — Add failing regression assertions first

**Files:** `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_app_launch.gd`

- [x] Extend `test_hud_audio_players_and_representative_feedback_streams()` to find exactly one `RiverAmbience` and `RainAmbience` HUD child each. Assert streams at the exact resource paths, River playing and default Sound 7 -> **-24 dB**. Preserve SFX/music checks.
- [x] In `test_new_game_propagates_settings_and_tutorial_toggle_to_world_hud()`, assert existing startup Sound 10 results in **-12 dB** on both ambience players. In `test_settings_environment_path_is_loaded_without_using_save_override()`, set startup Sound 0 and assert **-80 dB** on both. Do not invoke `apply_settings()` again to make either test pass.
- [x] In `test_settings_adjustment_persists_in_isolated_path_and_applies_audio()`, assert Music-only change doesn't alter River/Rain volume, navigate once to Sound, adjust once and verify both players' new dB without replacement. Reuse the existing SettingsPanel action flow.
- [x] Add **one** focused `test_game_hud_rain_playback_follows_world_refresh()` in gameplay-shell: rainy -> repeated rainy -> sunny -> rainy through `_refresh_from_session()` on a valid restored session state/history. Assert Rain starts/stops without replacing its node, River continues playing and session weather isn't mutated by the presenters. Include a detached-HUD rainy render playback guard only if it fits the same focused test without a new harness.
- [x] Run these target tests and record the expected failures **before** runtime changes. Do not add new suites or duplicate smoke assertions.

**Checkpoint:** failures must be for missing ambience behavior, not unrelated fixture errors. — Met: the Task 1 RED commit `8736be4` recorded the expected failures before runtime code landed.

## Task 2 — Implement the existing HUD audio seam

**File:** `scripts/ui/game_hud.gd` (**the only runtime file**)

- [x] Preload `RIVER_AMBIENCE` and `RAIN_AMBIENCE` from their exact `res://assets/audio/*-ambience.wav` paths. Add `AMBIENCE_HEADROOM_DB := -12.0` and typed River/Rain player fields.
- [x] Extend `_build_audio()` to create `RiverAmbience` and `RainAmbience` as named ordinary `AudioStreamPlayer` children of HUD, assign streams, initialize both `volume_db = -80.0`, and play River once after adding it. Leave Music/SFX setup unchanged.
- [x] Extend the existing `apply_settings()` with the current Sound dB applied to **both** ambience players as `maxf(sound_db + AMBIENCE_HEADROOM_DB, -80.0)`. Preserve Music and SFX assignments and the existing settings guard. Sound 0 stays -80, Sound 7 -> -24, Sound 10 -> -12.
- [x] In `render(snapshot)` reuse the weather condition already used by `WeatherTint`: start Rain only if rainy, `is_inside_tree()`, and not playing; stop Rain on sunny only if playing. **Do not early-return the full HUD render** when detached. No restart for repeated rainy renders.
- [x] Keep `HomesteadAmbience` as the existing visual-only World child; make **no changes** to `world.tscn`, `world_shell.gd`, `homestead_ambience.gd`, `UiSettings`, `SettingsPanel` or `test_persistence_flow.gd`. No new signal, setup method or audio manager.

**Checkpoint:** re-run Task 1 tests. Verify the old `HomesteadAmbience.new()` without-camera test still works because that class was untouched.

## Task 3 — Verify and review mix

- [x] Run affected `test_gameplay_shell.gd` and `test_app_launch.gd` GUT tests, plus existing headless smokes, and `./tools/verify-clean.sh` on committed HEAD. Run `git diff --check`.
- [x] ~~Native play~~ (superseded — the human listening gate was removed at owner direction 2026-10-20, matching the HPA-440 assets decision. Perceptual mix acceptance is the measurement-based imported-stream subordination review recorded in `assets/audio/README.md`: both beds measure strictly below the music bed and the farming one-shots under unweighted and A-weighted RMS, before the additional -12 dB runtime headroom. Playback behavior — sunny/rainy transitions, mute, live Sound and Music-only adjustment, no redundant-snapshot restart — is covered by the gameplay-shell rain/settings tests.)
- [x] Keep a focused diff: one runtime file and two existing integration test files, plus design/plan docs and the historical supersession line. No lifecycle test, new WAVs, audio buses, smoke duplication or new PR.
- [x] Update PR #21's checklist and attach verified evidence.

## Risk

Perceptual mix balance when River + Rain + Music + farm SFX play simultaneously is accepted by the measurement-based imported-stream subordination review in `assets/audio/README.md`, not by a native listening session. The fixed -12 dB headroom is a starting value; tune only if measured evidence requires it.

## Review follow-up (post-implementation)

Reviewer pass over the merged-test surface produced these adjustments, all kept inside the same two test files plus small helpers:

- **Restart coverage:** `test_game_hud_rain_playback_follows_world_refresh` now asserts `assert_same(rain.get_stream_playback(), ...)` — a repeated rainy render creating a new `AudioStreamPlayback` fails, which node identity alone could not catch.
- **Duplicate coverage:** the single-player check counts `AudioStreamPlayer` children by their stream `resource_path` because Godot renames a duplicate sibling (e.g. `@AudioStreamPlayer@4`) and name matching silently misses it.
- **Mute coverage:** the Sound 0 launch test perturbs player volumes before re-applying settings, so `apply_settings()` must drive the -80 dB floor from a different value; it also asserts `stream_paused` so deleting the pause/volume lines fails.
- **Detached-HUD guard:** the vacuous `assert_false(playing)` became `assert_engine_error_count(0)` — off-tree `play()` logs `Playback can only happen inside the scene tree` and `playing` alone can never fail there.
- **Sound 0 = real mute:** `apply_settings()` sets `stream_paused` on both ambience players (River decodes nothing at level 0), and `render()` skips `play()` while muted since `play()` clears `stream_paused` and a paused stream reports `playing == false`. The sunny branch stops a muted-but-active rain via `or stream_paused`. Muting mid-rain pauses the live stream; unmuting resumes the same playback.
- **Deduplication:** `sound_db` is computed once in `apply_settings()`; `_build_audio()` funnels all four players through `_add_audio_player()`; tests share `_restore_weather()` and `_players_with_stream()`; ambience assertions derive expected dB from `db_for_level(...) + GameHud.AMBIENCE_HEADROOM_DB` instead of literals.
- ~~**`GameRules.is_rainy()`**~~ **reverted:** the shared helper and its `HomesteadAmbience`/`FarmView`/`MorningSummaryPanel`/`_display_weather` call-site migrations were cross-cutting cleanup outside this slice — the same resolution as HPA-462 PR #19 (`e3bead7`). The rainy-key comparison stays local in `GameHud`, preserving the one-runtime-file promise.
- **No rain fade-in:** `rain-ambience.wav` opens at ≈-45 dBFS (first 10 ms peak -32.6 dBFS) — the soft onset is baked into the asset, so a code fade is unnecessary.
- **Unmute starts idle Rain:** a muted rainy render leaves Rain never-started, and clearing `stream_paused` on an idle player starts nothing, so `apply_settings()` now plays it when Sound becomes positive over a rainy snapshot, in-tree and not already playing. The check runs after `stream_paused = false` so a mid-rain paused stream still resumes in place; covered by `test_hud_unmute_starts_rain_when_last_render_was_muted`.

## Expected final implementation diff

- `scripts/ui/game_hud.gd` — primary runtime change (**the only runtime file**)
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`

Explicitly **unchanged**: `scripts/world/world_shell.gd`, `scenes/world/world.tscn`, `tests/integration/test_persistence_flow.gd`, audio source/import files and unrelated game logic.
