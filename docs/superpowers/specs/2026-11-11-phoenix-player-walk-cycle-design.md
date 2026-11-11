# HPA-546 — Player walk-cycle animation: design specification

**Status:** Design updated after review on 2026-11-11; runtime implementation has not started.
**Linear:** https://linear.app/cwchanap/issue/HPA-546/game-feel-play-the-player-walk-cycle-while-moving
**Art prerequisite:** HPA-539 (Done; merged PR #27).
**Baseline:** Phoenix `main` after HPA-684 / PR #39.
**Delivery:** One HPA-546 issue → one PR. Implement on this same PR after design review.

## Player experience

The farmer visibly walks in each of four isometric directions instead of sliding a static sprite. A stopped or fully blocked character displays that direction's idle pose. Opening a blocking menu during a stride immediately displays idle, rather than freezing in mid-step. The persistent Player and camera work on both farm and town without changes to movement, collision, ground contact, Y-sorting, targeting, farming, or persistence.

## Verified baseline and accepted art change

- `scenes/player/player.tscn` currently uses `proof-player.png` (four horizontal idle frames), with DOWN at `frame = 2`. `PlayerController._update_visuals()` sets `frame = int(facing)`, while `_physics_process()` uses `move_and_slide()` for movement.
- HPA-539 delivered `assets/sprites/player-walk.png` and its import sidecar. The 128×192 RGBA sheet has four 32×48 columns in each of four facing rows: UP (0), RIGHT (1), DOWN (2), LEFT (3). Column 0 is idle; columns 1–3 are walk poses. Preserve `Sprite2D.offset = Vector2(0, -24)` and the unchanged shadow/collision shape.
- **HPA-539 superseded the old pixel-identical-idle requirement.** Its redesigned farmer has new idle frames. Accept the new appearance through in-game inspection, not a comparison with `proof-player.png`. Phoenix's screenshot-golden gate was removed.
- The active input-gate call is `WorldShell._refresh_from_session()` → `_refresh_world_input_gate()` → `player.set_input_enabled(...)`. Refresh happens repeatedly for passive game-time ticks (nominally every 0.5 seconds) and gameplay commands, **even when the gate remains enabled**. This is not an edge-triggered modal callback.
- `FarmActionEffects.TOOL_FACING` stores HPA-458 tool-overlay anchors composed against the **old** proof player. The redesign may require adjusting those anchor coordinates while keeping the existing tool textures and FX ownership.

## Animation contract

1. Retain the existing `Sprite2D`; switch its texture to `player-walk.png`, set `hframes = 4`, `vframes = 4` and authored DOWN idle `frame = 8`. No new animation nodes or state machine.
2. Compute `frame = int(facing) * player_sprite.hframes + column`. Walk sequence **1 → 2 → 3 → 2**, repeating at 8 poses/second (one pose per 0.125 seconds), with column 0 reserved for idle. The first moving update shows column 1.
3. Advance one `PlayerController` elapsed-time accumulator using physics `delta`. In `_physics_process(delta)`, after `move_and_slide()`, call `_update_visuals(delta, get_real_velocity().length() > 1.0)`. `get_real_velocity()` reports actual displacement, unlike the requested/slid `velocity`; the small 1 px/s threshold avoids spurious motion near blocked geometry. A fully stationary body must not walk in place; meaningful wall sliding may still animate.
4. Keep the test seam small: `_update_visuals(delta: float = 0.0, moving: bool = false)`. Use `[1, 2, 3, 2][floori(_walk_seconds * WALK_FPS) % 4]` **before** accumulating `delta`, so the first moving update is column 1 and cadence is deterministic at 0.125-second boundaries. A row/facing change reuses the current sequence phase rather than resetting it. When `moving == false`, set column 0 and clear elapsed time.
5. `set_input_enabled(false)` synchronously zeroes velocity and invokes the idle/reset visual update. **`set_input_enabled(true)` must not reset phase, repaint the sprite, or modify the timer**: level-triggered world/session refreshes routinely pass true. After a genuine disable, the next movement starts from column 1 because the disable already cleared the phase. The physics disabled branch remains a no-motion early return.
6. `enter_map()` already clears velocity and restores DOWN facing. It must also repaint/reset the animation to DOWN idle, because `WorldShell.load_map()` retains and reparents the same Player across farm/town. Initial `_ready()` paints idle too.
7. Animation is transient, presentation-only `PlayerController` state. Do not add to `GameSession`, save schema, `WorldShell` gating, `WorldMath`, or `WorldContract`.

## Files and boundaries

- **Runtime:** `scenes/player/player.tscn` and `scripts/player/player_controller.gd`. Only if visual inspection shows a concrete tool-alignment defect, retune the existing `scripts/world/farm_action_effects.gd::TOOL_FACING` anchor entries in this **same PR**, and update their existing test pins.
- **Behavior tests:** extend `tests/integration/test_gameplay_shell.gd` with four-direction cadence, idle/stop, synchronous disable, repeated `set_input_enabled(true)` preserving the phase/frame, an actual physics-input path, and reset-on-map-entry assertions. Test rendered frame changes, not the private accumulator.
- **Scene/asset contract:** `tests/headless/world_shell_smoke.gd` alone pins the walk sheet's 128×192 size, texture path, `hframes/vframes = 4`, DOWN idle index 8, and unchanged offset/geometry. Do **not** repeat those configuration assertions in GUT. Update the older map-reload GUT frame expectation (`DOWN` now indexes 8).
- **Cleanup:** replace live references and **delete** `assets/sprites/proof-player.png` with its `.import` sidecar as part of the implementation. Confirm no remaining production/test consumer before deletion; historical HPA-458/HPA-539 provenance docs may still mention old art. Update `CLAUDE.md` to reflect the active walk-sheet player texture.
- **Art/FX boundary:** Use existing HPA-539 and HPA-458 art, no new sprite/audio generation. Verify hoe/watering tool positions against the newly displayed silhouette in all facings and correct any introduced anchor mismatch **here**, updating the two existing `test_gameplay_shell.gd` anchor assertions. Separate **new art/SFX** requests remain outside this ticket.

## Acceptance criteria

1. On real movement in every direction, columns follow 1 → 2 → 3 → 2 at ~8 fps; idle and fully blocked motion show column 0 with the most recent facing.
2. Blocking input mid-stride resets sprite to idle synchronously. Repeated calls to `set_input_enabled(true)` during active walking do not restart animation; a subsequent genuine disable/enable starts fresh.
3. Entering either map resets to DOWN idle while retaining the existing Player/Camera2D; movement, Y-sort, ground contact, shadow and targeting remain unchanged.
4. Tests are written before the implementation cutover; focused GUT proves cadence, stop/gate/no-reset-on-true and map reload behavior. Headless smoke owns scene/texture pins; GdUnit4 and godot-e2e regressions pass.
5. Native 1080p farm-and-town visual inspection accepts the redesigned farmer, four directions, feet/shadow/occlusion and hoe/watering attachment. If anchors mismatch, they are retuned and existing anchor tests updated in **this PR**, not deferred.
6. The obsolete proof sprite and import sidecar are removed after live-reference replacement. No new art, audio, animation framework, persistence or screenshot-golden infrastructure.
7. One issue → one implementation PR (this draft PR).