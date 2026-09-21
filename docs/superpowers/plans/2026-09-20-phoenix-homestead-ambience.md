# Phoenix Homestead Ambience Implementation Plan

**Linear:** HPA-462
**Audio dependency:** HPA-440
**Branch:** `agent/hpa-462-homestead-ambience-plan`
**Spec:** `docs/superpowers/specs/2026-09-20-phoenix-homestead-ambience-design.md`

**Goal:** Add restrained river motion, rain, and evening presentation to the current Phoenix homestead while keeping `GameSession`, persisted state, map/collision, gameplay time, and weather rules unchanged.

**Architecture:** Add one world-local `HomesteadAmbience` presenter fed from the existing `WorldShell._refresh_from_session()` snapshot. It owns transient ripple/rain/audio presentation, while the existing `GameHud/WeatherTint` remains the only full-screen tint surface. Time-of-day is a pure `time_minutes >= 18:00` projection. HPA-440 supplies the two loop files; this PR only integrates them.

## Global constraints

- One HPA-462 branch and one HPA-462 PR. Implementation continues on this draft PR after planning review.
- HPA-440 is a hard implementation start gate because it owns the two new audio files. Rebase this branch onto `main` after HPA-440 merges; do not merge `main` into the branch.
- HPA-458 image assets are already complete; do not create/edit image assets.
- Do not create/edit audio assets in HPA-462.
- No `GameSession` field, save/schema change, weather roll change, clock mutation, passive time advancement, or `GameRules` balance change.
- No autoload/global service, event bus, day-night framework, particle framework, shader/post-processing framework, dynamic lighting, new audio bus/mixer, or extra settings row.
- Preserve current sunny/rainy daytime tint values exactly.
- The House mask inherits the existing House 2x transform; do not double-scale it.
- Use the current Sound preference; preserve Music behavior.
- Native evidence is four fixed-phase captures, not a new golden/capture framework.

## Task 0: Planning lands now; implementation waits for HPA-440

**Linear/GitHub only**

- [ ] Keep HPA-462 blocked by HPA-440 until the asset-only PR merges.
- [ ] Confirm HPA-440 lands exactly:
  - `assets/audio/river-ambience.wav`
  - `assets/audio/rain-ambience.wav`
  - loop-enabled Godot import sidecars.
- [ ] Rebase `agent/hpa-462-homestead-ambience-plan` onto the then-current `main`.
- [ ] Verify both streams load in Godot before adding runtime preloads.

Do not temporarily synthesize, copy, or commit placeholder ambience in this PR.

## Task 1: Add the pure ambience projection and static scene anchor

**Files:**

- create `scripts/world/homestead_ambience.gd`
- generated `scripts/world/homestead_ambience.gd.uid` if Godot creates it
- `scenes/world/world.tscn`
- create `tests/unit/test_homestead_ambience.gd`
- generated test UID if Godot creates it
- `tests/headless/world_shell_smoke.gd`

### 1.1 RED — pin the only weather/time projection

Add unit tests for `HomesteadAmbience.presentation_for(snapshot)`:

- [ ] sunny 17:59 -> `rainy=false`, `evening=false`;
- [ ] sunny 18:00 -> `rainy=false`, `evening=true`;
- [ ] rainy 17:59 -> `rainy=true`, `evening=false`;
- [ ] rainy 18:00 -> `rainy=true`, `evening=true`;
- [ ] sunny daytime tint is exactly `Color(1.0, 0.96, 0.86, 0.03)`;
- [ ] rainy daytime tint is exactly `Color(0.38, 0.52, 0.72, 0.12)`;
- [ ] each evening state returns one final `world_tint` value; there is no separate evening-overlay output.

Use minimal snapshot dictionaries containing only `weather` and `time_minutes`; this helper is presentation-only and must not demand a whole persisted state.

### 1.2 GREEN — create one helper, not a subsystem

Implement `HomesteadAmbience` with:

- [ ] `EVENING_START_MINUTES := 18 * 60`;
- [ ] the two existing exact daytime tints;
- [ ] one restrained sunny-evening constant;
- [ ] one restrained rainy-evening constant;
- [ ] `presentation_for(snapshot)` returning only `rainy`, `evening`, `world_tint`.

No enum/class/resource for time-of-day. No stored day/night state.

### 1.3 Add the world node and House mask

In `world.tscn`:

- [ ] add exactly one direct `HomesteadAmbience` node under World with the new script;
- [ ] add `Entities/House/WindowLight` after the base House sprite;
- [ ] use `assets/sprites/polish/house-window-light.png`;
- [ ] `offset = Vector2(0, -48)`;
- [ ] local scale remains 1 so the House parent supplies the existing 2x scale;
- [ ] hidden by default.

Update `world_shell_smoke.gd`:

- [ ] add `HomesteadAmbience` to the exact direct-child contract;
- [ ] assert `WindowLight` uses the approved texture;
- [ ] assert offset/alignment and hidden default;
- [ ] leave every collision/map footprint assertion unchanged.

**Checkpoint:** run the new unit coverage plus `world_shell_smoke.gd`. Run `git diff --check`.

## Task 2: Build the bounded visual presenter and wire the existing snapshot refresh

**Files:**

- `scripts/world/homestead_ambience.gd`
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `tests/unit/test_homestead_ambience.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/headless/world_shell_smoke.gd`

### 2.1 RED — pin snapshot-driven world behavior

Add integration coverage around normal `WorldShell` refresh:

- [ ] restored sunny 17:59 starts with `WindowLight.visible == false`;
- [ ] wait several process frames and assert session `time_minutes` is unchanged and the mask is still hidden;
- [ ] prepare a valid session/action at 17:30 whose existing action cost reaches 18:00, execute through the normal world command path, and assert the mask becomes visible;
- [ ] restored rainy state exposes the rain visuals; restored sunny state hides them;
- [ ] restoring equivalent `time_minutes` / `weather` reproduces the same presentation without a new save field.

Do not call a production “set evening” API; none should exist.

### 2.2 GREEN — three fixed river ripples

In `HomesteadAmbience`, create exactly three ripple sprites using `river-ripple.png`.

- [ ] logical centers:
  - `Vector2(1.0, 6.5)`;
  - `Vector2(1.0, 13.0)`;
  - `Vector2(6.5, 19.0)`;
- [ ] project through `WorldMath.grid_to_world()`;
- [ ] `hframes = 3`;
- [ ] use the HPA-458 2x display contract;
- [ ] low world z-index above water but below target/entities;
- [ ] advance at 0.5 seconds per frame;
- [ ] initial phase offsets 0/1/2.

Keep those presentation coordinates in `HomesteadAmbience`, not `WorldContract`.

Add a small unit/helper assertion that each logical center is inside either existing river footprint. Do not alter the footprints.

### 2.3 GREEN — deterministic camera-following rain

Create exactly 16 runtime `Line2D` streaks once.

- [ ] one-pixel width;
- [ ] short, pale, low-alpha slanted segments;
- [ ] fixed index-derived offsets; no RNG;
- [ ] z-index above ordinary world entities/target but still below CanvasLayer 10 HUD;
- [ ] in `_process(delta)`, advance only a visual phase;
- [ ] wrap positions around `Camera2D.get_screen_center_position()` across the 640x360 viewport;
- [ ] hide the lines when not rainy.

Do not use GPUParticles/CPUParticles, a rain texture, or a second script/class just for streaks.

### 2.4 GREEN — one House mask and one tint surface

Add a setup method receiving the existing `Camera2D` and `WindowLight` references.

`HomesteadAmbience.render(presentation)`:

- [ ] caches only current `rainy` / `evening` booleans needed by transient rendering;
- [ ] sets `WindowLight.visible`;
- [ ] shows/hides the rain line set;
- [ ] does not touch session data.

In `GameHud`:

- [ ] remove the independent sunny/rainy tint choice from `render(snapshot)`;
- [ ] add only `set_world_tint(color: Color)`;
- [ ] keep `WeatherTint` as the same existing ColorRect.

In `WorldShell._refresh_from_session()`:

- [ ] take one session snapshot;
- [ ] compute `HomesteadAmbience.presentation_for(snapshot)`;
- [ ] refresh `FarmView`;
- [ ] render `HomesteadAmbience`;
- [ ] render `GameHud`;
- [ ] apply the one composed tint;
- [ ] preserve the existing input/modal refresh.

Do not add a second snapshot call or passive refresh loop.

**Checkpoint:** run unit + gameplay-shell integration + headless smoke. Inspect sunny/rainy daytime to confirm the existing look has not changed. Run `git diff --check`.

## Task 3: Integrate the two HPA-440 loops with the existing Sound setting

**Files:**

- `scripts/world/homestead_ambience.gd`
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `tests/integration/test_gameplay_shell.gd`

### 3.1 RED — pin audio ownership and live settings behavior

Integration tests should assert:

- [ ] `HomesteadAmbience` owns exactly one `RiverAmbience` and one `RainAmbience` `AudioStreamPlayer`;
- [ ] River uses `res://assets/audio/river-ambience.wav`;
- [ ] Rain uses `res://assets/audio/rain-ambience.wav`;
- [ ] River is started once for the live world;
- [ ] Rain plays on rainy presentation and stops on sunny presentation;
- [ ] Sound=0 produces -80 dB on both ambience players;
- [ ] changing Sound while the world is open updates both players without recreating them;
- [ ] changing Music alone does not alter ambience policy.

Avoid tests that depend on speakers or wall-clock audibility; inspect player state/stream/volume.

### 3.2 GREEN — build the two world-owned players

Preload only the two HPA-440 streams.

Create the players once under `HomesteadAmbience`:

- `RiverAmbience`
- `RainAmbience`

Use one `AMBIENCE_HEADROOM_DB := -12.0`.

`set_sound_volume_db(sound_db)`:

- [ ] if incoming dB is at/below the existing mute value (-80), set ambience to -80;
- [ ] otherwise set both players to `sound_db + AMBIENCE_HEADROOM_DB`.

Do not add new `UiSettings` fields or buses.

### 3.3 GREEN — forward Sound volume through the HUD boundary

Add one signal:

`signal sound_volume_changed(volume_db: float)`

In `GameHud.apply_settings()`:

- [ ] keep assigning Music from `settings.music`;
- [ ] keep assigning the existing SFX player from `settings.sound`;
- [ ] emit the current Sound dB after the assignments.

In `WorldShell._ready()`:

- [ ] setup `HomesteadAmbience`;
- [ ] connect `hud.sound_volume_changed` to `ambience.set_sound_volume_db`;
- [ ] make that connection before the initial `hud.configure(_settings)` so initial and live values take the same path.

Do not reach through `GameHud._settings_panel` or poll Settings every frame.

### 3.4 GREEN — weather controls Rain audio only

`HomesteadAmbience.render(presentation)`:

- rainy -> ensure Rain player is playing;
- sunny -> stop Rain player;
- River remains one continuous world-lifetime loop.

Repeated `render()` calls must not restart an already playing loop.

**Checkpoint:** run the affected GUT suite. Manually adjust Sound 7 -> 0 -> 7 in a native run and verify ambience follows while Music keeps its existing behavior. Run `git diff --check`.

## Task 4: Pin world teardown and Continue/result lifecycle

**Files:**

- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`
- optionally `scripts/world/homestead_ambience.gd` only if the tests expose a real teardown defect

### 4.1 World-owned teardown

In gameplay-shell integration:

- [ ] retain references to both ambience players;
- [ ] remove/free the world;
- [ ] await one frame;
- [ ] assert the old player instances are no longer valid.

Child ownership should make this pass without a manager. Add an explicit `_exit_tree()` stop only if Godot playback survives detach long enough to fail the lifecycle assertion.

### 4.2 AppRoot concrete lifecycle

Extend the existing AppRoot integration path with one create -> result -> title/new world proof:

- [ ] launch one World and record its ambience players;
- [ ] route through the existing result teardown path;
- [ ] assert the old World/players are freed;
- [ ] launch a new/continued World;
- [ ] assert it owns exactly one River and one Rain player;
- [ ] no audio nodes exist under AppRoot/Title/Result.

Do not add an ambience registry to make this test pass.

### 4.3 Restore proof

Use an existing valid persisted/restored state with rainy/evening values:

- [ ] Continue launches directly into the matching mask/rain/tint state;
- [ ] no migration or new persisted key is expected.

Prefer extending an existing persistence/AppRoot test if its fixture already owns the Continue state; otherwise keep the assertion in `test_gameplay_shell.gd`. Do not duplicate the full persistence suite.

**Checkpoint:** run integration tests and `world_shell_smoke.gd`.

## Task 5: Add four fixed-phase native captures and complete verification

**Files:**

- create `tests/visual/capture_homestead_ambience.gd`
- generated UID if Godot creates it
- no new committed golden set

### 5.1 Bounded capture script

The script accepts an output directory, instantiates the real `world.tscn`, and builds valid restored session states for exactly:

- `sunny-day`: 12:00, sunny;
- `rainy-day`: 12:00, rainy;
- `sunny-evening`: 19:00, sunny;
- `rainy-evening`: 19:00, rainy.

For each state:

- [ ] acknowledge/seed the intro flag so normal HUD/world presentation is visible;
- [ ] use the real World/Camera/HUD;
- [ ] disable `HomesteadAmbience` processing before capture so ripple/rain phase stays fixed;
- [ ] capture exactly 640x360;
- [ ] write to `test_output/hpa-462/<state>.png`.

Do not teach `capture_ui_states.gd` about world states and do not add these four images as permanent golden tests.

### 5.2 Manual visual review

Review the four captures together:

- [ ] sunny daytime matches the current baseline tint;
- [ ] rainy daytime remains readable;
- [ ] evening is obvious but restrained;
- [ ] rainy evening is not double-darkened;
- [ ] WindowLight aligns with the House windows;
- [ ] ripples stay visibly over water;
- [ ] rain does not obscure crops, target highlight, interaction hint, or top/bottom HUD.

Only the two evening tint constants and rain line alpha/length/speed are presentation-tuning knobs. Do not change the 18:00 rule, add lighting, or broaden scope to solve taste issues.

### 5.3 Final verification

Before the implementation commit:

- [ ] run the full existing worktree GUT suite;
- [ ] run:
  - `godot --headless --path . --script res://tests/headless/project_smoke.gd`
  - `godot --headless --path . --script res://tests/headless/world_math_smoke.gd`
  - `godot --headless --path . --script res://tests/headless/world_shell_smoke.gd`
- [ ] run the HPA-462 native capture script and inspect all four images;
- [ ] run `git diff --check`.

After committing the intended implementation state:

- [ ] run `./tools/verify-clean.sh` because it verifies committed `HEAD`;
- [ ] re-run `git diff --check`;
- [ ] attach/reference the four native captures in the PR conversation;
- [ ] keep the PR draft until review findings are addressed.

## Expected final diff

Runtime:

- `scripts/world/homestead_ambience.gd`
- generated script UID as needed
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `scenes/world/world.tscn`

Tests/evidence:

- `tests/unit/test_homestead_ambience.gd`
- generated test UID as needed
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`
- `tests/headless/world_shell_smoke.gd`
- `tests/visual/capture_homestead_ambience.gd`
- generated capture-script UID as needed

Planning:

- `docs/superpowers/specs/2026-09-20-phoenix-homestead-ambience-design.md`
- `docs/superpowers/plans/2026-09-20-phoenix-homestead-ambience.md`

HPA-440, not this PR, owns:

- `assets/audio/river-ambience.wav`
- `assets/audio/river-ambience.wav.import`
- `assets/audio/rain-ambience.wav`
- `assets/audio/rain-ambience.wav.import`
- related provenance updates in `assets/audio/README.md`

Anything beyond the HPA-462 list needs a concrete implementation reason. In particular, do not proactively touch `GameSession`, `GameRules`, `UiSettings`, `SettingsPanel`, `FarmView`, save code, terrain/collision resources, generated image assets, audio files, existing UI goldens, or project architecture docs.
