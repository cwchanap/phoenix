# Phoenix River and Rain Homestead Ambience Design

**Linear:** HPA-462
**Audio dependency:** HPA-440 (audio task only)
**Repository:** `cwchanap/phoenix`
**Branch:** `agent/hpa-462-homestead-ambience-plan`
**Base reviewed:** `main` at `0c8ec8f55cbc38087488976c6dca75021dfe5b0f`

## Goal

Make the existing homestead feel more alive through restrained river movement, readable rain, and quiet environmental audio without changing gameplay weather, game time, persistence, map geometry, or the farming loop.

This is a presentation-only slice. `GameSession.weather` remains the only gameplay weather state. Real-time animation may move pixels and audio playback, but it never waters crops, rolls weather, spends stamina/time, or mutates the session.

## Evening scope removed after reachability review

The earlier draft included an 18:00 evening tint and HPA-458's `house-window-light.png`. That work is removed.

Current gameplay cannot reach 18:00:

- each day starts at 06:00 (`360` minutes) with 20 stamina;
- every time-advancing farming action spends at least 1 stamina;
- the best minutes-per-stamina rate is 20 minutes, including the upgraded watering can;
- therefore even the theoretical maximum is `360 + 20 * 20 = 760`, or 12:40.

Sleeping resets the next day to 06:00, and the normal save path writes the next-morning state. An 18:00 integration fixture would therefore prove only that manually injected state renders, not that a player can reach the feature.

HPA-462 consequently ships no evening state, no evening tint constants, no `WindowLight`, and no time-of-day helper. `assets/sprites/polish/house-window-light.png` remains an unused HPA-458 asset until a future gameplay change makes a real time-of-day cue reachable.

Changing action/stamina/time rules just to expose evening is explicitly outside this ticket.

## Dependencies and asset ownership

HPA-458 is complete and supplies the image HPA-462 consumes:

- `assets/sprites/polish/river-ripple.png`

HPA-440 owns exactly the two new audio assets:

- `assets/audio/river-ambience.wav`
- `assets/audio/rain-ambience.wav`

HPA-440 gates only audio integration. River/rain visual implementation can proceed before those WAV files merge. No placeholder or duplicate audio belongs in HPA-462.

## Existing seams to preserve

### Snapshot refresh

`WorldShell._refresh_from_session()` already obtains one `GameSession.snapshot()` and fans it into the world/HUD presenters. HPA-462 adds one more world presenter to the same fan-out.

There is no observer, event bus, weather service, or second state model.

### Weather tint

`GameHud.render(snapshot)` already owns the single full-screen sunny/rainy tint through `HudRoot/WeatherTint`.

Leave that code untouched. HPA-462's world presenter only needs to derive:

`snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)`

There is no shared tint helper and no dependency from UI code to a world `Node2D` script.

### World layering

The existing contract is:

- ground;
- `FarmSoil` / `FarmActionEffects` at low world z;
- `TargetHighlight` at z 10;
- y-sorted `Entities` at z 20;
- `GameHud` on CanvasLayer 10.

Add `HomesteadAmbience` as a direct non-Y-sorted World child immediately after `FarmActionEffects`. Its ripple/rain presentation stays above soil/effects and below `TargetHighlight` / `Entities`, so gameplay targeting and actors remain readable.

### Settings and audio

`UiSettings.sound` remains the only environmental/SFX volume preference. `UiSettings.db_for_level(0)` already maps mute to -80 dB.

World ambience uses Sound, not Music. `farm-day-loop.wav` and the Music preference remain unchanged.

## One world-local presenter

Add:

`scripts/world/homestead_ambience.gd`

`HomesteadAmbience` owns only transient world presentation:

- three ripple `Sprite2D` children;
- deterministic runtime `Line2D` rain streaks;
- the existing `Camera2D` reference;
- one River and one Rain `AudioStreamPlayer` after HPA-440 lands;
- visual rain phase.

It owns no gameplay state, save data, collision, crop state, or game clock.

Do not split this into river/rain/audio managers.

## River presentation

Create exactly three ripple `Sprite2D` children using `river-ripple.png`.

Start with these authored logical centers:

- west river: `Vector2(1.0, 6.5)`;
- west river: `Vector2(1.0, 13.0)`;
- south river: `Vector2(6.5, 19.0)`.

Project them with `WorldMath.grid_to_world()`. These are presentation constants, not `WorldContract` state.

Sprite contract:

- `hframes = 3`;
- `scale = Vector2(1, 1)`;
- `offset = Vector2.ZERO`;
- no rotation/flip;
- render between farm effects and the target highlight/entities.

Reuse the repository's tween idiom for frame animation: one looping bound Tween per ripple advances frame 0→2 at roughly 2 fps, with small start delays applied once before each loop starts so they do not recur every cycle. `_process()` should not manage ripple frames.

The exact ripple centers, start delays, and playback rate remain visual-tuning values. The frame stays at 1x: review confirmed a 64x32 frame rendered at 2x spans 128x64 and its opaque corner pixels overhang both banks of the two-cell-wide rivers on every candidate cell.

Do not animate the whole water TileMap or create one ripple per tile.

## Rain presentation

Use deterministic runtime-created `Line2D` streaks rather than particles or a generated rain texture.

Keep one `RAIN_STREAK_COUNT` constant, but treat its value as a visual tuning knob. Start with a moderate native-screen density rather than freezing the original 16-streak guess.

Each streak is:

- one pixel wide;
- short and consistently slanted;
- pale/low-alpha;
- placed deterministically from its index;
- rendered above soil/ripples but below `TargetHighlight` and `Entities`.

No RNG is required.

### One reusable layout function

Implement:

`_layout_rain(phase: float)`

It positions/wraps every streak around `Camera2D.get_screen_center_position()` across the 640x360 viewport.

Call it from both:

- `render(snapshot)` when rain becomes/currently is visible, using the current phase (initially 0);
- `_process(delta)` while rainy after advancing the transient phase.

This keeps fixed-phase captures truthful even when processing is disabled.

`render(snapshot)` derives rain directly from the snapshot, shows/hides the streaks, and never mutates session state.

## Audio integration

Audio is Task 3 and waits for HPA-440 only.

After the two WAV files land, `HomesteadAmbience` owns:

- `RiverAmbience`
- `RainAmbience`

Both are ordinary non-spatial `AudioStreamPlayer` children of the World-owned presenter.

### Initial settings are not signal-dependent

`setup(camera: Camera2D, settings: UiSettings)` receives the current settings directly from `WorldShell`.

It:

1. stores the camera;
2. computes the current Sound dB with `settings.db_for_level(settings.sound)`;
3. applies the fixed ambience headroom;
4. starts the River loop immediately at that resolved volume.

This means a missed signal cannot leave River permanently silent.

Use one `AMBIENCE_HEADROOM_DB := -12.0`:

- Sound mute (-80 dB) stays -80 dB;
- otherwise ambience uses `sound_db - 12 dB`.

### Live setting changes

Add one narrow `GameHud` signal:

`sound_volume_changed(volume_db: float)`

`GameHud.apply_settings()` emits it after applying the existing Sound level.

`WorldShell` connects that signal to `HomesteadAmbience.set_sound_volume_db()` for live settings changes. The signal is not needed for initial setup correctness.

Do not add a settings bus, audio bus, ambience slider, or reach into `_settings_panel`.

### Weather controls Rain audio only

- River plays for the World lifetime.
- Rain plays only while the snapshot reports rainy weather.
- Repeated `render(snapshot)` calls do not restart a loop already playing.
- Sound=0 silences both through the existing -80 dB convention.

All players are children of `HomesteadAmbience`, so World teardown owns their lifetime.

## Snapshot wiring

Keep `WorldShell._refresh_from_session()` as one-snapshot fan-out:

```gdscript
var snapshot := _session.snapshot()
farm_view.refresh(snapshot)
_homestead_ambience.render(snapshot)
hud.render(snapshot)
_refresh_world_input_gate()
```

`GameHud.render(snapshot)` keeps its current sunny/rainy tint logic unchanged.

No second snapshot call, no time-of-day projection, and no imperative HUD tint API are added.

## Lifecycle

`AppRoot._show_result()` already removes and queues the World for deletion.

Extend the existing `test_result_return_to_title_reloads_save_and_new_game_keeps_slot()` flow only:

- retain old River/Rain player references before result teardown;
- assert they become invalid after the existing teardown wait;
- after the existing New Game path, assert the new World owns exactly one River and one Rain player.

Do not add a duplicate world-free test or assertions that players are not reparented into unrelated UI nodes.

## Native evidence

Add one narrow capture script:

`tests/visual/capture_homestead_ambience.gd`

Capture exactly two states at a normal reachable daytime value such as 09:20:

1. sunny;
2. rainy.

No new committed goldens and no changes to `capture_ui_states.gd` / `compare_ui_states.gd`.

### Fixed phase

For each capture:

1. build a valid initial session state with `intro_acknowledged = true`;
2. instantiate `world.tscn` off-tree;
3. call `world.configure(initial_state, ...)` before adding it;
4. set `HomesteadAmbience.process_mode = Node.PROCESS_MODE_DISABLED` before `add_child()` so bound ripple Tweens and rain processing stay frozen;
5. add the World;
6. let the camera/world settle minimally;
7. call `HomesteadAmbience.render(world._session.snapshot())` once more so `_layout_rain(0.0)` uses the settled camera center;
8. capture the native 640x360 viewport.

This guarantees rainy evidence actually contains rain while keeping a deterministic phase.

## Smoke-test contract vs tuning knobs

Extend `world_shell_smoke.gd` only for structural facts:

- `HomesteadAmbience` exists in the exact World child position immediately after `FarmActionEffects`;
- exactly three ripple sprites exist;
- every ripple uses `river-ripple.png`, `hframes = 3`, `scale = Vector2(2, 2)`, and `offset = Vector2.ZERO`;
- ripple/rain rendering is strictly above farm soil/effects and below `TargetHighlight` / `Entities`.

Do not pin:

- exact ripple positions;
- ripple start frames/delays;
- rain streak count;
- rain alpha/length/speed;
- fixed pixel positions.

Those values are reviewed/tuned through the two native captures, not treated as architecture.

## Testing boundaries

### Gameplay-shell integration

Pin only behavior with a real ownership failure mode:

- rainy snapshot -> rain lines visible;
- sunny snapshot -> rain lines hidden;
- rainy/sunny refresh never changes gameplay weather or farm state;
- after HPA-440: River/Rain players use the two expected streams;
- Sound=0 -> both players at -80 dB;
- live Sound adjustment updates both existing players;
- changing Music alone does not alter ambience volume;
- rainy -> Rain player runs, sunny -> it stops, without recreating the player.

Do not add a "waiting frames does not advance time" test; no timer-driven gameplay path exists in this feature after evening is removed.

### Lifecycle

Use only the existing persistence-flow result teardown/new-game test described above.

### Visual review

The two captures verify:

- ripples remain visibly inside water, especially at the west bank;
- rain is actually visible at native 640x360;
- rain stays restrained enough that crops, target highlight, interaction hint, and HUD remain readable;
- sunny/rainy existing HUD tint behavior remains unchanged.

Explicit tuning knobs are:

- ripple logical centers;
- ripple tween rate/start delays;
- `RAIN_STREAK_COUNT`;
- rain alpha;
- rain line length/slant;
- rain fall speed.

## Alternatives rejected

### Keep the 18:00 evening slice

Rejected because the current stamina/time economy cannot reach it. Manually restored evening state would be dead-content verification, not player-visible acceptance.

### Move dusk into the reachable morning band

Rejected because a lit-house/window cue around late morning reads incorrectly and solves no current gameplay problem.

### Change time/stamina rules

Rejected as a balance change outside this presentation ticket.

### Share a presentation helper with GameHud

Rejected after evening removal. The HUD already has the correct two-way weather-tint owner; adding a dependency on a world Node2D class would make the architecture worse for no benefit.

### Put environmental audio in GameHud

Rejected. River/rain lifetime belongs to the World. The one Sound-volume signal is the smallest live-settings bridge.

### Use GPUParticles/CPUParticles

Rejected. Deterministic `Line2D` rain is enough and easier to review/capture.

## Non-goals

No evening/day-night presentation, WindowLight integration, gameplay time change, new weather types, passive game clock, new save fields, map/collision changes, house interior, NPC schedules, foliage/wildlife systems, shaders/post-processing, dynamic lights/shadows, audio bus architecture, spatial audio, new soundtrack, or gameplay balance changes.
