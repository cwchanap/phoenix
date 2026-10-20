# HPA-402 — Homestead River/Rain Audio Integration Design

**Linear:** [HPA-402](https://linear.app/cwchanap/issue/HPA-402/homestead-polish-integrate-river-and-rain-ambience-audio-after-hpa-440)  
**Repository:** `cwchanap/phoenix` · **Base:** current `main` after PR #20 · **Delivery:** one draft-then-implementation PR  
**Upstream contracts:** [HPA-462 design](2026-09-20-phoenix-homestead-ambience-design.md), [HPA-462 plan Tasks 3–4](../plans/2026-09-20-phoenix-homestead-ambience.md), merged [HPA-440 assets](https://github.com/cwchanap/phoenix/pull/20).

## Outcome and readiness

Finish the deferred audio-only part of the existing homestead ambience presenter: a continuously looping quiet river bed, weather-driven rain bed, live Sound-level control, and World-scoped lifecycle. No changes to gameplay or visual ambience.

**Dependency satisfied:** PR #20 merged on 2026-10-18. `assets/audio/river-ambience.wav` and `assets/audio/rain-ambience.wav` exist on `main`; their `.import` sidecars already enforce full-clip forward looping. The source-container verifier and imported-stream smoke also landed. Do not recreate or alter these assets/sidecars, duplicate import tests, or change their provenance.

**Verified current seams:**

- `HomesteadAmbience` is already a direct World child at z=6. Its `render(snapshot)` already derives rainy/sunny for drawing and `WorldShell._refresh_from_session()` already calls it before `hud.render(snapshot)`.
- `WorldShell.configure(..., settings)` supplies `UiSettings`; `WorldShell._ready()` resolves missing settings and calls `hud.configure(_settings)`.
- `GameHud.apply_settings()` currently computes Music and SFX player volumes independently using `UiSettings.db_for_level(...)`. Settings changes flow through `SettingsPanel.settings_changed -> GameHud._on_settings_changed -> apply_settings()`. No existing cross-world audio notification.
- `UiSettings.db_for_level(0) == -80.0`; at Sound 7 the incoming dB is -12.0.

## Minimal ownership and scene contract

In `scenes/world/world.tscn`, add exactly two ordinary **non-spatial** `AudioStreamPlayer` children under the existing `HomesteadAmbience` node, named **RiverAmbience** and **RainAmbience**. Assign their streams to the two exact HPA-440 paths via direct scene external resources. Keep the existing three runtime ripple children and rain canvas rendering unchanged. No player under HUD, AppRoot, global autoload, audio bus, or new manager.

In `scripts/world/homestead_ambience.gd`, use two `@onready` player references and a single constant `AMBIENCE_HEADROOM_DB := -12.0`. The existing instance owns playback for its entire World lifetime; freeing the World frees both players.

## Initial Sound volume and live changes

Add `setup(settings: UiSettings)` to `HomesteadAmbience` (the visual slice intentionally has no `setup` or camera parameter). It resolves `settings.db_for_level(settings.sound)`, passes it to `set_sound_volume_db(sound_db: float)`, and starts River only after both players have the correct volume. Thus first-frame correctness never relies on a previously emitted HUD signal.

`set_sound_volume_db` writes the **same** output to both players: `-80.0` when incoming `sound_db` is mute (`<= -80.0`), otherwise `sound_db + AMBIENCE_HEADROOM_DB`. Do not subtract headroom from mute or derive volume from Music. At Sound 7, both should be at -24 dB; at Sound 0, both stay at -80 dB.

Add one `GameHud` signal `sound_volume_changed(volume_db: float)`. `apply_settings()` emits the current Sound dB immediately after its existing SFX-volume assignment (and after its existing early-return guard). `WorldShell._ready()` passes `_settings` directly to `_homestead_ambience.setup(_settings)` and connects the signal to `_homestead_ambience.set_sound_volume_db`. It is safe if HUD's child `_ready` or `hud.configure()` applied settings before the connection: `setup` is authoritative for startup. `apply_settings` may also run after Music-only changes; replaying an unchanged dB is idempotent and must leave ambience volume unchanged. Avoid signal caching, a settings bus, reading `_settings_panel`, or changing `UiSettings`.

## Weather and lifecycle

Extend the **existing** `HomesteadAmbience.render(snapshot)` without changing the rain-visual logic:

- Rainy: `RainAmbience.play()` only when it is not already playing.
- Sunny: `RainAmbience.stop()` only when it is playing.
- Repeated rainy renders must not restart audio; sunny/rainy changes reuse one player instance.
- River is started once in `setup`, not on every snapshot; it remains running as long as the World exists (including on sunny days).

The World is already removed/queued for deletion at finale. Do not add teardown hooks, reparent players, or implement cross-scene persistence. The existing same-frame New Game path must receive a **new** pair of World-owned players.

## Verification / acceptance

1. In existing gameplay-shell GUT tests, assert exact child names/count and stream resource paths, river playing, player-level forward-loop stream type (without duplicating HPA-440's frame-count/import assertions), startup Sound 7 = -24 dB, startup Sound 0 = -80 dB, live Sound 7 -> 0 -> 7 reusing nodes, Music-only change leaves ambience volume, rainy -> repeated rainy -> sunny -> rainy changes only Rain playback and doesn't replace nodes.
2. Exercise real `WorldShell._refresh_from_session()` for rainy state, preserving existing visual assertions and session data. Do not test rendering or mixing quality via speaker-dependent GUT assertions.
3. Extend **only** `test_result_return_to_title_reloads_save_and_new_game_keeps_slot()` in the persistence-flow suite: capture old River/Rain refs before finale; after World deletion completes, assert both invalid; retain current Continue/result/save assertions; after same-frame New Game assert exactly one fresh pair.
4. Run affected GUT/integration tests, `./tools/verify-clean.sh`, `git diff --check`, and manually check Sound 7 -> 0 -> 7 and rain/sun in native play. Do not claim audio listening evidence without performing it.

## Deliberate exclusions

No audio asset generation/editing, new SFX or music, visual rain/ripple changes, evening tint, weather/gameplay/save/schema changes, UI settings row, sound mixer/bus, spatial falloff, event bus, autoload, tests for pre-existing import internals, extra lifecycle test, or backwards-compatibility work. If a real failing test reveals a lifecycle bug, fix it narrowly within this same PR.
