# HPA-546 — Single-PR implementation and verification plan

**Status:** Planning only. Continue implementation on the same draft PR after review; do not create a second implementation PR.
**Linear:** https://linear.app/cwchanap/issue/HPA-546/game-feel-play-the-player-walk-cycle-while-moving
**Companion design:** [2026-11-11-phoenix-player-walk-cycle-design.md](../specs/2026-11-11-phoenix-player-walk-cycle-design.md)
**Dependency:** HPA-539 art is complete and committed. No new asset production is needed.

## Current main baseline

- `player.tscn`: old `proof-player.png`, `hframes = 4`, DOWN default `frame = 2`, offset `(0, -24)`; `Shadow` and `CollisionPolygon2D` are existing siblings.
- `player_controller.gd`: `_physics_process(_delta)` sets velocity, calls `move_and_slide()` and `_update_visuals()`; the latter sets `frame = int(facing)`. `set_input_enabled(false)` only zeroes velocity; `enter_map()` zeroes velocity/resets facing and then repaints.
- `tests/integration/test_gameplay_shell.gd` already checks `set_input_enabled(false)` stops the body (around line 496), and map reload currently pins the old DOWN frame index (around line 4058).
- `tests/headless/world_shell_smoke.gd` expects the **old** proof-player dimensions in `EXPECTED_ASSETS` and checks the player's four horizontal frames/offset (around line 669).
- `WorldShell._update_input_enabled()` already calls `player.set_input_enabled(...)` whenever HUD modal state changes; map travel calls `player.enter_map(...)` on the persistent Player. No new signal or world-shell integration is required.
- HPA-539's `tests/visual/hpa-539/README.md` is authoritative for the redesigned sheet and recommended `1 → 2 → 3 → 2` cadence. Ignore the stale pixel-identical-idle sentence in HPA-546: it predates the accepted redesign. The screenshot-golden gate has been retired.

## Step 1 — Wire the delivered sheet and implement the minimal playback

**Files:** `scenes/player/player.tscn`, `scripts/player/player_controller.gd`.

1. Switch the sprite's resource to `res://assets/sprites/player-walk.png`. Set `hframes = 4` and `vframes = 4`, preserve `offset = Vector2(0, -24)`, and start at DOWN idle (`frame = 8`). No added scene nodes.
2. Add a fixed `WALK_FPS = 8.0` constant, a four-entry sequence `[1, 2, 3, 2]`, and one elapsed-seconds member to `PlayerController`. Inside `_physics_process(delta)`, after `move_and_slide()` call the existing visual updater with `delta`. Map sprite row by `int(facing) * 4`; use the sequence index from elapsed time and reset elapsed time when velocity reaches zero. Make the first moving pose column 1. Do not tie playback to rendered frames or elapsed real-world wall time.
3. Extend the existing visual updater (optionally `delta: float = 0.0` for its call sites) rather than adding a second animation component. On `set_input_enabled(false)` zero velocity, repaint idle, and reset phase **synchronously**. `enter_map()` similarly resets phase via its zero-velocity visual update. Keep the disabled physics branch gated as-is.
4. Avoid touching `WorldShell`, camera, session, input mappings, save fields, movement speed, collider, shadow, or tool FX code unless a concrete regression is demonstrated.

**Checkpoint:** Open the existing scene, move one direction, stop, open a modal mid-stride, and change maps. Confirm the correct row/column and no frame is frozen by a modal.

## Step 2 — Update existing deterministic regression tests

**Files:** `tests/integration/test_gameplay_shell.gd` and `tests/headless/world_shell_smoke.gd`.

1. Add focused GUT coverage to `test_gameplay_shell.gd`. Instantiate the existing world/player fixture and check the actual scene texture resource path, `hframes/vframes`, and initial DOWN idle index 8.
2. Exercise visual advancement with controlled `delta` and movement velocity (or the smallest test seam already exposed by `PlayerController`): at time zero show column 1, then 2, 3, 2, then loop. Check rows for all four `WorldMath.Facing` values. Check a stop leaves the last facing unchanged at column 0 and resets phase for the next walk.
3. Extend `test_set_input_enabled_false_zeros_and_stops_player_movement` to first advance into a non-idle pose; invoke `set_input_enabled(false)` and immediately assert velocity zero, idle index, and no stale walk phase. After enable, the next walk begins at column 1. Existing modal tests should still pass without special HUD wiring.
4. Change the existing map-reload frame assertion from `int(WorldMath.Facing.DOWN)` to `int(WorldMath.Facing.DOWN) * 4`; assert phase is cleared on `enter_map()` / travel, not merely that the old facing was restored.
5. In `world_shell_smoke.gd` replace the proof-player asset in `EXPECTED_ASSETS` with `player-walk.png` (128×192). Pin sprite texture path, `hframes = 4`, `vframes = 4`, initial DOWN idle `frame = 8`, and unchanged offset. Keep old speed, projection, geometry, collision, and Y-sort assertions intact. Search the other GUT/GdUnit/e2e tests for assumptions that frame equals facing and change only affected assertions.

**Checkpoint:** Movement/idle/gate/map-reload tests fail against the old frame mapping and pass against the updated scene/controller. No new animation framework or separate test suite.

## Step 3 — Cleanup and handoff

**Files:** `CLAUDE.md` and, **only if unreferenced**, `assets/sprites/proof-player.png` and `assets/sprites/proof-player.png.import`.

1. Run `rg -n 'proof-player\.png|player_sprite\.frame|frame = int\(facing\)' .` on the updated implementation checkout. Distinguish live runtime/test references from historical docs. Remove the old proof sprite plus import sidecar only when every live reference has been replaced.
2. Update the current-assets sentence in `CLAUDE.md` so the walk sheet is listed as the live player texture and the remaining proof sprites are described accurately. Do not alter the historical HPA-539 visual handoff, which documents art production at the time of delivery.
3. Record the selected pacing (8 fps) and any visual limitations on this PR. No generated art or audio and no new Linear issue are needed unless the manual review exposes a **separate** art/SFX request.

## Verification on committed HEAD

`./tools/verify-clean.sh` archives the committed `HEAD`, **not** an uncommitted worktree; commit implementation/test checkpoints before invoking it. Execute:

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

Then manually run `scenes/app/app.tscn` at native 1920×1080 (and optionally 960×540) and inspect: UP/RIGHT/DOWN/LEFT while walking and still; repeated starts/stops; a modal opened while moving; farm↔town truck travel; feet/shadow aligned with ground and Y-sorted props; hoe and watering-can overlays against the redesigned silhouette. These are visual acceptance checks, **not** screenshot-golden updates.

## Done when

- [ ] The new 4×4 sheet drives every directional idle/walk frame at 8 fps.
- [ ] Zero velocity, blocking input, and map entry all reset to correct idle without stale movement.
- [ ] Focused GUT and updated headless sprite assertions pass; existing GdUnit4/e2e behavior passes.
- [ ] Native farm/town manual inspection accepts the redesigned character, contact/occlusion, and tool overlays.
- [ ] Current handoff/asset references are accurate; unused proof-player is removed only if safe.
- [ ] Implementation is committed to **this same HPA-546 PR**, reviewed, and then made ready; no follow-up implementation PR.

**Out of scope:** New sprites, animation state machines, audio, villager motion, gameplay balance, persistence migration, and screenshot-golden infrastructure.