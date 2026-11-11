# HPA-546 — Single-PR implementation and verification plan

**Status:** Review findings incorporated on 2026-11-11; implementation remains pending.
**Linear:** https://linear.app/cwchanap/issue/HPA-546/game-feel-play-the-player-walk-cycle-while-moving
**Companion design:** [2026-11-11-phoenix-player-walk-cycle-design.md](../specs/2026-11-11-phoenix-player-walk-cycle-design.md)
**Dependency:** HPA-539 already delivered the redesigned art; no new asset generation.
**Delivery:** Review, implement, test and verify on **this same HPA-546 draft PR**, not a second PR.

## Current main baseline

- `scenes/player/player.tscn` still displays the 128×48 `proof-player.png` with `hframes=4`, DOWN default `frame=2` and offset `(0,-24)`.
- `scripts/player/player_controller.gd` sets requested `velocity`, calls `move_and_slide()` and sets the static facing frame. `set_input_enabled(false)` only zeroes velocity; `enter_map()` resets DOWN facing and zero velocity.
- **The existing gate is level-triggered:** `WorldShell._refresh_from_session()` calls `_refresh_world_input_gate()` (`scripts/world/world_shell.gd:218-236`), which calls `player.set_input_enabled(_world_input_enabled)` on every session refresh. The passive clock can cause refreshes roughly every 0.5s during gameplay. Calls with `true` must **not** reset the walk timer or pose.
- GUT `tests/integration/test_gameplay_shell.gd` checks disabled movement (around line 496) and map reload (around 4058, with the old facing-only index); headless `tests/headless/world_shell_smoke.gd` owns all scene/texture/asset-dimension pins (manifest around line 12 and player around 669). Do not duplicate sprite-config tests in GUT.
- `scripts/world/farm_action_effects.gd::TOOL_FACING` has player-local hoe/watering anchors fitted to the old proof art, pinned in `tests/integration/test_gameplay_shell.gd` (around lines 2195 and 2232-2237). Visual acceptance must verify and, if misaligned, retune those anchors on **this PR**.
- HPA-539 `tests/visual/hpa-539/README.md` documents the 128×192, 4×4 sheet and **1 → 2 → 3 → 2** at 8 fps. It explicitly replaces the old idle pose with new art. Phoenix no longer has a screenshot-golden gate.

## Step 1 — Write red GUT behavior tests first

**File:** `tests/integration/test_gameplay_shell.gd`.

1. Reuse the existing world/player GUT fixture. Add deterministic cadence tests calling the existing `PlayerController._update_visuals(delta: float = 0.0, moving: bool = false)` seam **once implementation exists**, with `facing` set explicitly and `delta = 0.125`. First moving call displays walk column 1; subsequent calls show 2, 3, 2 and wrap. Verify each row via `int(facing) * 4 + column` and preserve phase when changing direction. The seam is intentionally trivial; do not create a new animator/test harness.
2. Exercise stop: `_update_visuals(0.0, false)` immediately paints column 0 in the retained facing; the next moving call restarts column 1. Test the pose, not `_walk_seconds`.
3. Extend `test_set_input_enabled_false_zeros_and_stops_player_movement`: establish a non-idle pose, call `set_input_enabled(false)` and immediately assert zero velocity and idle frame; re-enable and assert that the next movement starts column 1. Retain the existing real-physics no-motion assertion.
4. **New regression:** while moving and at a non-idle pose, call `player.set_input_enabled(true)` (or `world._refresh_from_session()`) repeatedly. Assert current sprite frame and subsequent walk step continue unchanged. This protects against the recurring level-triggered passive-clock and action refresh path.
5. Extend the map-reload regression: change its old DOWN frame expectation from `int(WorldMath.Facing.DOWN)` to `int(WorldMath.Facing.DOWN) * 4`; after `world.load_map()` call `_update_visuals(0.125, true)` and assert DOWN column 1. Do not inspect the internal timer.
6. Preserve one real `_physics_process`-driven movement/blocked-input integration path in addition to the deterministic seam tests. The seam should not replace an assertion that actual player input drives walking.

**Red checkpoint:** Land/commit the tests **before** changing the scene or controller. The new tests should fail against old frame mapping/missing behavior. Existing static syntax and unchanged regression tests remain runnable; no need for a separate PR.

## Step 2 — Minimal scene and controller changes to green

**Files:** `scenes/player/player.tscn`, `scripts/player/player_controller.gd`, `tests/headless/world_shell_smoke.gd`.

1. Point `Sprite2D` to the committed `player-walk.png`. Set `hframes=4`, `vframes=4` and authored DOWN idle `frame=8`; preserve `offset=(0,-24)`, shadow and collider. Update the headless asset manifest to `player-walk.png` at `128×192` and the existing live sprite checks for texture path, columns, rows, idle frame and offset.
2. Add only `WALK_FPS := 8.0`, the sequence `[1,2,3,2]`, and one elapsed-seconds member to `PlayerController`. Use `int(facing) * player_sprite.hframes + column`; obtain column using the elapsed index **before** adding the current physics delta, so the initial moving pose is 1.
3. After `move_and_slide()` call `_update_visuals(delta, get_real_velocity().length() > 1.0)`. Godot's real velocity checks actual movement rather than residual requested `velocity` at blockers. Keep the updater signature `_update_visuals(delta: float = 0.0, moving: bool = false)` so GUT can test exact `0.125`-second boundaries without waiting for physics frames.
4. Reset phase and repaint idle only in the disabled `if not enabled:` branch of `set_input_enabled`, plus normal stop and `enter_map()`. On **every** `set_input_enabled(true)` call, preserve the current phase and frame. Preserve the early return in disabled physics frames; do not edit the world input gate.
5. Keep changes inside the existing scene/controller plus test assertions; no `AnimatedSprite2D`, Tween loop, state machine, new owner, global service, save field, movement/camera/physics retuning, or localization.

**Green checkpoint:** GUT behavior, headless sprite checks and existing world/input regressions pass against the newly displayed sprite.

## Step 3 — Delete obsolete proof art and update the handoff

**Files:** `assets/sprites/proof-player.png`, `assets/sprites/proof-player.png.import`, `CLAUDE.md`.

1. On the implementation checkout, run `rg -n 'proof-player\.png|player_sprite\.frame|frame = int\(facing\)' .`. Replace all live references in code/tests; do not change old HPA-458/HPA-539 provenance docs.
2. **Delete** the old player PNG **and** its `.import` sidecar on this PR once live references are gone. This is not optional cleanup; report any unexpected live dependency and update it before removal.
3. Update `CLAUDE.md`'s current-assets statement to describe `player-walk.png` as the active player sprite, while retaining accurate descriptions for other `proof-*` textures.

## Step 4 — Verify visual regression and tool overlay alignment on this PR

1. Run the game at native 1920×1080 and inspect UP/RIGHT/DOWN/LEFT walk and idle, stop/start, modal opened mid-stride, farm↔town travel, feet/shadow/occlusion.
2. **Explicit acceptance for HPA-459 hoe and watering-can overlays:** inspect their attachment against the new farmer in all facings. If one or more anchors are misaligned, adjust only `FarmActionEffects.TOOL_FACING` (existing position table) on this branch and update its existing `test_gameplay_shell.gd` anchor assertions at the same time. Rerun the focused test. Do **not** ship a known misalignment or defer its fix to a second ticket/PR.
3. No new overlay art, sprite generation, tool-animation framework or footstep SFX. Any **new art or SFX** request gets its own ticket.

## Verification on committed HEAD

`./tools/verify-clean.sh` archives committed `HEAD`, not the uncommitted worktree. Commit the red-test and green-implementation checkpoints before claiming a clean pass. Execute:

```bash
./tools/verify-clean.sh
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Document which gates actually passed; do not claim a manual native inspection without performing it. There is **no screenshot-golden** gate.

## Done when

- [ ] Existing GUT tests prove 1→2→3→2 cadence at 8 fps for each facing, stop-to-idle, disable-to-idle, **no reset on repeated true**, and a fresh start after map reload.
- [ ] Existing headless smoke pins the redesigned walk sheet's dimensions, configuration, DOWN idle index, ground-contact geometry.
- [ ] GUT/headless, GdUnit4, godot-e2e, import and unsigned macOS export regressions are green.
- [ ] Farm/town visual review accepts redesigned farmer and hoe/watering overlay alignment; any required `TOOL_FACING` retuning and its existing tests land on **this same PR**.
- [ ] Obsolete `proof-player.png` and `.import` are removed; current `CLAUDE.md` handoff is correct.
- [ ] Implementation remains on PR #40; no additional PR tied to HPA-546.

**Out of scope:** New art, new audio/SFX, villager animation, game balance, save migrations, generic animation framework, screenshot-golden infrastructure.