# HPA-402 — Homestead River/Rain Audio Integration Design

**Issue:** [HPA-402](https://linear.app/cwchanap/issue/HPA-402/homestead-polish-integrate-river-and-rain-ambience-audio-after-hpa-440)  
**Repository:** `cwchanap/phoenix` · **Delivery:** one draft-then-implementation [PR #21](https://github.com/cwchanap/phoenix/pull/21) based on `main` after HPA-440 PR #20  
**Prior art:** [HPA-462 visual design](2026-09-20-phoenix-homestead-ambience-design.md); [HPA-462 plan Tasks 3–4 (superseded)](../plans/2026-09-20-phoenix-homestead-ambience.md)

## Outcome and status

Play quiet river ambience throughout the homestead World; play a separate rain bed only when the authoritative session snapshot says rainy. Both obey the existing Sound preference, including true mute, without affecting music, weather rules, saves, or visuals.

**Dependency complete:** HPA-440 PR #20 merged `assets/audio/river-ambience.wav` and `assets/audio/rain-ambience.wav` plus their forward-loop import sidecars and asset-level validation. Reuse them as-is; no asset generation/editing, importer changes or duplicate waveform tests.

**Review correction:** The earlier HPA-462 handoff proposed placing two players under `HomesteadAmbience`. Repository review identified a smaller existing integration seam: `GameHud` already builds all audio players, applies Music/Sound settings and reads rainy/sunny snapshots to render `WeatherTint`. This **HPA-402 design supersedes** the earlier proposed audio ownership and related lifecycle instructions. `HomesteadAmbience` remains visual-only and unchanged.

## Ownership: one existing HUD audio implementation

Modify **only `scripts/ui/game_hud.gd` in runtime**.

- Preload exactly `res://assets/audio/river-ambience.wav` and `res://assets/audio/rain-ambience.wav` alongside the existing SFX/music preloads.
- Add typed `_river_ambience_player` and `_rain_ambience_player` fields; create `RiverAmbience` and `RainAmbience` `AudioStreamPlayer` children directly in existing `_build_audio()`. Keep the existing `SfxPlayer` and `MusicPlayer` untouched. These are ordinary non-spatial players.
- Assign the exact preloaded streams, set each initial `volume_db = -80.0`, add them to HUD and start River once. `_ready()` calls `_build_audio()` before the World invokes `hud.configure(settings)`, so starting River muted avoids a loud first frame. `configure` calls existing `apply_settings()` to resolve the persisted Sound level.
- Since `GameHud` is a World child, all four players naturally die when the World is freed; no new lifecycle plumbing/test is necessary.

No scene-authored players, `WorldShell` change, `HomesteadAmbience.setup()`, `sound_volume_changed` signal, cross-node signal bridge, global audio service, custom bus, settings row, or AudioStreamPlayer2D.

## Existing Sound/Music settings path

Keep `UiSettings.db_for_level()` and `GameHud.apply_settings()` as the only dB translation path. After the existing SFX assignment, compute the local `sound_db` once (optionally reuse it for SFX) and set both ambience players to:

```gdscript
maxf(sound_db + AMBIENCE_HEADROOM_DB, -80.0)
```

with the one constant `AMBIENCE_HEADROOM_DB := -12.0`.

`db_for_level(0) == -80.0` remains -80.0; Sound 7 is -12.0 incoming, therefore **-24.0 dB** ambience; Sound 10 is 0.0 incoming, therefore **-12.0 dB** ambience. The clamp has the same result as a separate mute branch for all valid levels 0–10.

Settings changes already flow `SettingsPanel.settings_changed -> GameHud._on_settings_changed -> apply_settings()`. Music-only changes may replay the same Sound value; that is idempotent and does not change ambience volume.

## Weather playback and detached World

In existing `GameHud.render(snapshot)`, use the same rainy/sunny boolean already used by `WeatherTint`; avoid a second weather source. After tint selection:

- Rainy and `is_inside_tree()` and not `RainAmbience.playing` -> `play()`.
- Sunny and `RainAmbience.playing` -> `stop()`.
- Repeated rainy renders must not restart the stream. River stays running and does not react to weather.
- A detached World can still receive a snapshot/command before deferred deletion. **Guard the `play()` call**, reusing the existing `_play_sfx()` precedent. Do **not** return from the whole HUD `render()`: it must keep its other presentation behavior even off-tree. A later in-tree render reconciles Rain normally.

Do not modify `WorldShell._refresh_from_session()` (the existing one-snapshot fan-out already calls `hud.render(snapshot)`), `GameSession` weather policy, tint, visual rain, or ripple state.

## Focused acceptance tests

Reuse existing integration tests, not a new audio suite:

1. `tests/integration/test_gameplay_shell.gd::test_hud_audio_players_and_representative_feedback_streams`: assert one named HUD child per ambience player, expected stream paths, River playing, and **default Sound 7 -> -24 dB**; preserve existing music/SFX assertions.
2. `tests/integration/test_app_launch.gd::test_new_game_propagates_settings_and_tutorial_toggle_to_world_hud`: existing Sound 10 must set both ambience players to **-12 dB** at launch, without extra `apply_settings()`.
3. `tests/integration/test_app_launch.gd::test_settings_environment_path_is_loaded_without_using_save_override`: set startup Sound 0 and assert both players remain **-80 dB** through actual AppRoot launch.
4. `tests/integration/test_gameplay_shell.gd::test_settings_adjustment_persists_in_isolated_path_and_applies_audio`: extend the Music adjustment to assert both ambience levels stay unchanged, then navigate to Sound and adjust once to verify both update with the original player instances.
5. Add one narrow `test_game_hud_rain_playback_follows_world_refresh` in the existing gameplay-shell file. Exercise rainy -> repeated rainy -> sunny -> rainy through actual `WorldShell._refresh_from_session()` (valid weather history on restored state); assert Rain playing state, reused player identity, and River remains playing. Include a detached-HUD rainy render `play()` guard assertion without mutating session, if it can be exercised without building another world/test harness.

Asset-level full-clip `LOOP_FORWARD` has already been verified in `tests/headless/project_smoke.gd` under HPA-440; do not duplicate it here. The World-child ownership is sufficient: **do not modify** `tests/integration/test_persistence_flow.gd` or add a lifecycle test. Existing `MusicPlayer` uses the same ownership model.

## Validation and mix risk

Run focused GUT integration tests, existing headless smokes and `./tools/verify-clean.sh` against committed HEAD; run `git diff --check`. Perceptual mix acceptance is the measurement-based imported-stream subordination review recorded in `assets/audio/README.md`: at equal gain both beds measure strictly below the music bed and the farming one-shots under unweighted and A-weighted RMS, and the runtime adds a further -12 dB headroom, so farming action SFX stays clearly audible over rain and river. The human native-listening gate was removed at owner direction (2026-10-20), matching the HPA-440 assets decision; tune the single headroom constant only if measured evidence requires it.

## Exclusions

No new audio layer, audio registry, global settings bus, ambience slider, extra node lifecycle assertions, scene changes, changes to `HomesteadAmbience`, new weather rules, save migration, visual effects, soundtrack, asset regeneration or code for hypothetical future needs.
