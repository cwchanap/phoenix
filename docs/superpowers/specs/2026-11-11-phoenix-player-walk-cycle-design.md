# HPA-546 — Player walk-cycle animation: design specification

**Status:** Proposed for review; runtime implementation has not started.
**Linear:** https://linear.app/cwchanap/issue/HPA-546/game-feel-play-the-player-walk-cycle-while-moving
**Art prerequisite:** HPA-539 (Done; merged PR #27).
**Baseline:** Phoenix `main` after HPA-684 / PR #39.
**Delivery:** One HPA-546 issue → one PR. Implement on this same PR after design review.

## Player experience

The farmer visibly walks in each of four isometric directions instead of sliding a static sprite. A stopped character displays that direction's idle pose. Opening a blocking menu during a stride immediately displays idle, rather than freezing in mid-step. The same Player instance and its animation state work on both the farm and town maps without changing movement, collisions, camera follow, ground contact, depth sorting, farming, or persistence.

## Ground truth and accepted art change

- `scenes/player/player.tscn` currently uses `proof-player.png` (four horizontal idle frames) and `frame = 2` for DOWN. `PlayerController._update_visuals()` currently sets `frame = int(facing)`. `_physics_process()` samples input, sets `velocity`, runs `move_and_slide()`, then updates visuals.
- HPA-539 already committed `assets/sprites/player-walk.png` and its Godot import sidecar. The sheet is **128×192 RGBA**: four 32×48 columns per row, four rows ordered `WorldMath.Facing`: UP (0), RIGHT (1), DOWN (2), LEFT (3). Column 0 is idle; 1, 2, 3 are walking poses. Keep the existing `Sprite2D` offset `(0, -24)` and bottom-center anchor. The existing shadow and collision shape do not change.
- **HPA-539 explicitly superseded the old requirement for pixel-identical idle frames.** The art ticket redesigned the farmer and delivered new idle poses. The new appearance requires an in-game visual review; do not gate HPA-546 on pixel equality with `proof-player.png`.
- Phoenix removed its screenshot-golden gate in November 2026. Acceptance is behavior tests plus manual in-game inspection, not golden image recapture.

## Animation contract

1. Retain the existing `Sprite2D`; change its texture to `player-walk.png`, set `hframes = 4`, `vframes = 4`, and initial DOWN idle `frame = 8`. Do not create `AnimatedSprite2D`, `AnimationPlayer`, `AnimationTree`, or another player/animation owner.
2. Compute the linear frame index as `int(facing) * 4 + column`. Column 0 is idle. Walk columns follow HPA-539's recommended repeating **1 → 2 → 3 → 2** sequence at **8 poses/second** (125 ms per pose). Show column 1 on the first moving update. Keep a tiny elapsed-time accumulator in `PlayerController`; advance it using the physics `delta` so speed is frame-rate independent.
3. Animate when the resolved `velocity` after `move_and_slide()` is non-zero. On zero velocity, display the current facing's column-0 idle and clear animation elapsed time. A direction change while moving switches rows without creating an independent directional animation clock. No walking loop for a fully blocked, stationary character; sliding along a wall can still animate.
4. `set_input_enabled(false)` synchronously zeroes velocity **and updates the sprite to idle**, so the frame resets immediately on pause, dialogue, shop, or other blocking HUD modal—even if the next physics tick is gated. The physics disabled branch remains a no-motion early return. Re-enabling input starts a fresh walk at column 1 on the next move.
5. `enter_map()` already zeros velocity and restores DOWN facing. Reset walk phase and idle there too, because `WorldShell.load_map()` retains and reparents the same Player instance across farm/town. Initial `_ready()` also paints a correct idle frame.
6. Animation is **presentation-only transient state** owned by `PlayerController`. Do not add anything to `GameSession`, the save schema, `WorldShell`'s input gate, `WorldMath`, or `WorldContract`.

## Files and boundaries

- **Runtime:** `scenes/player/player.tscn` and `scripts/player/player_controller.gd` only.
- **Focused tests:** extend `tests/integration/test_gameplay_shell.gd` to cover the art configuration, moving poses, stop, mid-stride input gate, and map reload. Update its current map-reload assertion, which expects `int(WorldMath.Facing.DOWN)` instead of the new frame index 8.
- **Headless contract:** update `tests/headless/world_shell_smoke.gd`'s `EXPECTED_ASSETS` manifest from the old 128×48 proof player to the new 128×192 walk sheet; assert the live player sprite's path, `hframes = 4`, `vframes = 4`, DOWN idle index, and unchanged offset/ground anchor. Preserve existing player collision, speed, targeting, camera, and Y-sort checks.
- **Cleanup:** replace `CLAUDE.md`'s statement that the proof player remains a live texture. Search production/test asset references before optionally deleting `assets/sprites/proof-player.png` and its `.import` sidecar. Historical HPA-539 provenance text and reference images may continue to mention the old proof art; do not rewrite history or regenerate either sheet.
- **Art and FX:** use the existing HPA-539 sheet; do not generate new art or audio. Visually review HPA-459 hoe/watering tool overlays against the redesigned hands/body, and report a concrete positioning defect if found. Scope any new SFX or new art to a separate ticket.

## Non-goals

Tool-use and carry animations; villager walking; footsteps; animation blending, easing, or a global animation service; player movement retuning; new locations or map contracts; save migrations; generated sprite revisions; screenshot-golden infrastructure.

## Acceptance criteria

1. In each facing direction, movement visibly cycles through the four walk-sequence poses at about 8 fps; stopping restores column 0 of the retained facing without a stale pose.
2. A modal can disable input in mid-stride and immediately restore idle; re-enabling and walking restarts the loop.
3. Crossing between farm and town retains the same player/camera object, with the animation reset on arrival and no changes to movement, collision, ground-contact offset, Y-sort, or targeting.
4. GUT coverage demonstrates frame progression, idle/disable/reset, and spawn/reload behavior; headless smoke validates sprite asset dimensions and live scene configuration. Existing GdUnit4 and godot-e2e regressions continue to pass.
5. A real 1080p farm-and-town visual pass accepts the **new** idle character and checks all four directions, occlusion/feet alignment, and hoe/watering overlay attachment. There is no pixel-identical-old-idle requirement and no screenshot-golden gate.
6. Changes stay limited to this one ticket and this same PR, using the existing art.