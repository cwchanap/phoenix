# Phoenix Homestead Ambience Design

**Linear:** HPA-462
**Audio dependency:** HPA-440
**Repository:** `cwchanap/phoenix`
**Branch:** `agent/hpa-462-homestead-ambience-plan`
**Base reviewed:** `main` at `0c8ec8f55cbc38087488976c6dca75021dfe5b0f`

## Goal

Make the existing homestead feel more alive through restrained river movement, readable rain, and warm evening windows without changing gameplay weather, game time, persistence, map geometry, or the current farming loop.

This is a presentation slice. The session snapshot remains the only source of truth for weather and clock time. Real-time animation may move pixels and audio playback, but it never advances or derives new gameplay state.

## Dependency split

HPA-458 is complete and already supplies the two image assets HPA-462 needs:

- `assets/sprites/polish/river-ripple.png`
- `assets/sprites/polish/house-window-light.png`

New ambient audio is deliberately outside this runtime ticket. HPA-440, repurposed from Graveyard, owns exactly:

- `assets/audio/river-ambience.wav`
- `assets/audio/rain-ambience.wav`

HPA-462 implementation begins after HPA-440 merges. This PR consumes those fixed paths but does not generate or edit audio.

## Existing seams to preserve

### Snapshot refresh

`WorldShell._refresh_from_session()` already obtains one `GameSession.snapshot()` and fans it into `FarmView` and `GameHud`. Every farming command, sleep transition, morning acknowledgement, restore, and social/shop refresh already passes through this seam.

HPA-462 adds ambience presentation to that same fan-out. It does not add another observer, timer-driven session refresh, event bus, or background state model.

### Clock and weather

`GameSession` already owns:

- `time_minutes`, advanced only by gameplay actions;
- `weather`, rolled only by the existing day transition;
- persisted/restored time and weather.

`GameRules` currently defines the action-driven clock bounds and weather keys. HPA-462 does not add a gameplay time-of-day enum or save field. The 18:00 boundary is presentation policy owned by the ambience helper.

### World layering

The world currently has ordinary canvas content, `FarmSoil` / `FarmActionEffects` at low world z-index, `TargetHighlight` at z 10, and y-sorted `Entities` at z 20.

`GameHud` is CanvasLayer 10. Its first child, `WeatherTint`, already covers the 640x360 viewport and is drawn before the HUD chrome. That makes it the correct single full-screen tint target: it can color the world while text, target hints, controls, and modal content remain readable above it.

Do not add a second full-screen weather/evening overlay.

### House transform

The existing House is positioned/scaled as one `Node2D` at 2x. Its sprite uses `offset = Vector2(0, -48)`.

The HPA-458 window mask was authored against that exact source frame. Add `WindowLight` as a child of `Entities/House`, after the base sprite, with the same offset and local scale 1. It therefore inherits the House's existing 2x transform. It starts hidden.

### Settings and audio

`UiSettings.sound` is already the one 0..10 sound preference and maps level 0 to -80 dB. `GameHud.apply_settings()` is the existing live settings application point.

World ambience uses Sound, not Music. Music behavior and `farm-day-loop.wav` remain unchanged.

## Chosen architecture

### One world-local presenter

Add one `HomesteadAmbience` `Node2D` under `World`:

`scripts/world/homestead_ambience.gd`

It owns only transient presentation:

- three river ripple sprites;
- a small fixed set of rain `Line2D` streaks;
- references to the existing camera and House `WindowLight`;
- one River and one Rain `AudioStreamPlayer`;
- visual animation phase.

It owns no gameplay mutation, save data, weather roll, game-time timer, collision, or crop state.

This is intentionally one helper rather than separate river/rain/day-night/audio managers.

### Pure weather/time projection

Expose one pure static projection:

`presentation_for(snapshot: Dictionary) -> Dictionary`

The returned shape is deliberately tiny:

```gdscript
{
    "rainy": bool,
    "evening": bool,
    "world_tint": Color,
}
```

Rules:

- `rainy` iff `snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)`;
- `evening` iff `snapshot["time_minutes"] >= 18 * 60`;
- before 18:00 is daytime;
- exactly 18:00 is evening.

There is no dawn state, night state, interpolation state, season, real-time clock, or persisted presentation state.

### Four composed tint states

Move the current day tint constants out of `GameHud` and into `HomesteadAmbience` so one owner composes weather plus time.

Preserve the current daytime values exactly:

- sunny day: `Color(1.0, 0.96, 0.86, 0.03)`;
- rainy day: `Color(0.38, 0.52, 0.72, 0.12)`.

Add one restrained sunny-evening tint and one restrained rainy-evening tint. They are presentation constants, not game rules. Native 640x360 evidence may tune those two values for readability, but the state mapping and single-overlay rule are fixed.

`GameHud` gains only:

`set_world_tint(color: Color) -> void`

`GameHud.render(snapshot)` stops independently deriving a weather tint. `WorldShell` computes one presentation result and applies its `world_tint` to the existing HUD surface.

This prevents a rainy evening from becoming two stacked alpha overlays.

## River presentation

Create exactly three ripple `Sprite2D` children under `HomesteadAmbience`, all using the approved HPA-458 strip.

Use fixed logical centers projected through `WorldMath.grid_to_world()`:

- west river: `Vector2(1.0, 6.5)`;
- west river: `Vector2(1.0, 13.0)`;
- south river: `Vector2(6.5, 19.0)`.

These points sit inside the existing `RIVER_WEST_FOOTPRINT` / `RIVER_SOUTH_FOOTPRINT`; they are presentation coordinates and do not belong in `WorldContract`.

Runtime contract:

- `hframes = 3`;
- respect HPA-458's 2x display contract;
- world z-index below `TargetHighlight` and `Entities`;
- advance one frame every 0.5 seconds (~2 fps);
- fixed initial phase offsets 0, 1, 2 so all ripples do not blink in sync.

Do not animate the water TileMap itself or create one ripple per tile.

## Rain presentation

Use deterministic runtime-created `Line2D` streaks rather than a particle subsystem or generated texture.

Bound it to a small constant count (16). Each line is:

- roughly 10-14 px long;
- 1 px wide;
- pale/low-alpha;
- slanted consistently;
- world-canvas z-index 9: above ground/ripples but below `TargetHighlight` (10) and `Entities` (20).

`HomesteadAmbience._process(delta)` may advance only a visual rain phase. On each rainy frame, position the fixed line set around `Camera2D.get_screen_center_position()` using deterministic index-based offsets and wrap them across the 640x360 viewport.

No RNG is needed. The line set is hidden when `rainy == false`.

Because the streak positions follow the camera center, moving the camera does not leave rain behind. Because they remain ordinary world-canvas nodes, the HUD CanvasLayer stays above them.

## Evening window light

`WindowLight.visible = presentation["evening"]`.

Keep it static. Do not add a light node, shader, bloom, shadow system, pulse timer, or another time-state object. The world tint is enough to establish dusk; the mask gives the house one warm focal cue.

## Snapshot wiring

`WorldShell._refresh_from_session()` becomes conceptually:

```gdscript
var snapshot := _session.snapshot()
var ambience := HomesteadAmbience.presentation_for(snapshot)
farm_view.refresh(snapshot)
_homestead_ambience.render(ambience)
hud.render(snapshot)
hud.set_world_tint(ambience["world_tint"])
_refresh_world_input_gate()
```

Exact call order may vary only to keep existing modal/HUD behavior intact. There is still one session snapshot and no duplicate policy.

A successful action that moves `time_minutes` across 18:00 naturally changes the next refresh. Merely waiting in `_process()` changes animation phase only.

## Sound preference wiring

Add one narrow public signal to `GameHud`:

`sound_volume_changed(volume_db: float)`

`apply_settings()` emits the current Sound dB after applying settings. `WorldShell` connects the signal to `HomesteadAmbience` before the initial `hud.configure(_settings)` call so the world gets both the initial volume and later Settings changes.

`HomesteadAmbience` applies fixed ambience headroom (initially -12 dB) relative to the incoming Sound dB:

- incoming -80 dB remains -80 dB;
- otherwise ambience uses `sound_db - 12 dB`.

Both players use the same preference and headroom. Do not add buses, sliders, mixers, or separate ambience settings.

Playback:

- Both players start at the muted -80 dB default so no frame can play at full volume before settings arrive.
- River loop starts once after the initial Sound volume is delivered for the lifetime of the world.
- Rain loop plays only while the presentation is rainy.
- Switching sunny/rainy starts/stops only the Rain player.
- Sound=0 silences both via the existing -80 dB convention.
- Both players are children of `HomesteadAmbience`, so removing the World owns their teardown. An explicit `_exit_tree()` stop is fine but no global cleanup registry is needed.

## Restore and lifecycle

No new persistence is required. `time_minutes` and `weather` are already saved and restored.

On New Game / Continue:

1. `WorldShell` creates/restores the existing `GameSession`;
2. it obtains the current snapshot;
3. the same ambience projection reproduces the right daytime/evening/rain state.

On finale:

`AppRoot._show_result()` removes and queues the World for deletion. Because all ambience nodes/players are beneath World, no audio or effect survives into Result/Title.

Do not add AppRoot ambience ownership.

## Deterministic native evidence

Do not extend the current UI-golden framework with a second generalized world-capture system.

Add one narrow script:

`tests/visual/capture_homestead_ambience.gd`

It instantiates `world.tscn` with valid restored snapshots for exactly four cases:

1. sunny daytime;
2. rainy daytime;
3. sunny evening;
4. rainy evening.

Before capture, disable `HomesteadAmbience` processing so ripple/rain phase stays at its initial deterministic state. Capture the native 640x360 viewport into `test_output/hpa-462/` for PR evidence. No new committed golden matrix is required.

## Testing boundaries

### Pure mapping

Add `tests/unit/test_homestead_ambience.gd` to pin:

- 17:50 -> daytime;
- 18:00 -> evening;
- sunny/rainy detection;
- daytime tints remain the existing exact values;
- rainy evening is one composed result, not an additive overlay API.

### World integration

Extend `tests/integration/test_gameplay_shell.gd` to pin:

- an unchanged pre-18:00 session remains pre-evening after real process frames;
- a successful action crossing 18:00 turns on the window mask through normal refresh;
- rainy snapshots show rain and run the Rain loop; sunny snapshots hide/stop it;
- Sound=0 and live Sound adjustment reach both ambience players;
- restore starts in the correct presentation state.

### Lifecycle

Use the existing AppRoot integration surface in `tests/integration/test_app_launch.gd` for one concrete create -> result teardown -> create path. Assert old ambience players are freed and the next world owns one River and one Rain player, not accumulated globals.

### Scene/headless contract

Update `tests/headless/world_shell_smoke.gd` for:

- the new direct `HomesteadAmbience` World child;
- the House `WindowLight` asset/alignment/hidden default;
- no map/collision contract changes.

## Alternatives rejected

### Put everything in GameHud

Rejected. The existing tint belongs there as a rendering surface, but ripples, camera-following rain, house presentation, and ambience audio should die with the world. Moving all of that into the HUD would broaden an already large UI presenter.

### Add day/night state to GameSession

Rejected. Day/evening is fully derivable from persisted `time_minutes`; storing another field creates synchronization and migration work with no product benefit.

### Add a global ambience/day-night service

Rejected. Phoenix has one world at a time. Child ownership already gives correct lifecycle and is cheaper to maintain.

### Use GPUParticles/CPUParticles

Rejected for this slice. Sixteen deterministic `Line2D` streaks are enough, require no texture, behave in headless/native evidence consistently, and avoid particle tuning/lifecycle machinery.

### Generate audio in HPA-462

Rejected by project workflow. New audio assets are isolated in HPA-440 so this runtime PR remains code/presentation integration only.

## Non-goals

No new weather types, passive game clock, new save fields, village scene, house interior, new map geometry, collision change, NPC schedules, foliage animation pass, wildlife, dynamic shadows, dynamic lights, shader/post-processing framework, audio bus architecture, spatial audio, new soundtrack, or gameplay balance changes.
