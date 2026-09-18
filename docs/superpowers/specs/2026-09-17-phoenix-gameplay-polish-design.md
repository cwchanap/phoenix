# Phoenix Responsive Farming Polish Design

**Linear:** HPA-459  
**Repository:** `cwchanap/phoenix`

## Summary

HPA-459 makes the existing farming loop easier to read and faster to execute without changing its rules. The slice keeps Phoenix's current 24×20 homestead, 30 authored farm cells, three crops, explicit tool selection, adjacent-cell targeting, action costs, clock, save format, and finale scoring.

The implementation extends the seams already present on `main`:

- `GameSession.preview_selected_action()` remains the authoritative non-mutating farming preview, but returns enough structured context for truthful hints and presentation.
- `WorldShell` remains the coordinator for target preview, command dispatch, transient hold state, and successful-action presentation.
- `PlayerController` remains responsible only for movement, facing, and target-cell ownership.
- `FarmView` remains snapshot-driven presentation and gains one targeted mature-crop cue.
- `GameHud` remains the UI/audio presenter and keeps the one existing SFX player and Sound preference.
- A single `FarmActionEffects` world-local helper owns the short-lived farming sprites/tweens. It owns no gameplay state and introduces no action/event framework.

HPA-458 is complete and its committed assets/consumer handoff are inputs to this ticket. No image generation belongs in HPA-459.

## Goals

1. Replace the generic successful farming hint with compact action-specific information derived from the same preview/rules path that validates the command.
2. Make mature crops obvious only when the player targets them, without covering the farm in permanent markers.
3. Give Hoe, Plant, Water, and Harvest distinct short visual/audio feedback only after a successful command.
4. Let a held Space gesture work deliberately across a row while preserving the same single-cell rules and resource checks.
5. Keep the result small enough that HPA-460 can add its watering-cost modifier without undoing duplicated UI policy.

## Non-goals

No new crops, map changes, farming balance changes, tool upgrades, area-of-effect tools, auto-pathing, nearby-cell scans, queues, mouse farming, controller remapping, player animation rig, event bus, action framework, animation-driven gameplay, save/schema change, new image assets, shader system, new music, or additional visual/E2E framework.

## Current seams to preserve

### Rules and session

`GameRules.action_cost()` is the current action-cost source and `evaluate_action_budget()` consumes it. `GameSession` owns the selected action/seed and all farm/resource mutation. Its current `preview_selected_action()` already runs the same action-specific guard path as the real command without mutation.

Do not duplicate a cost table in `WorldShell` or `GameHud`.

### World and input

`WorldShell._process()` currently resolves `player.current_target_cell()`, calls the session preview, chooses target tint, and renders the hint. `use_selected_action()` dispatches the real command. `GameHud.has_blocking_modal()` is already the single world-input gate.

`PlayerController` owns the `CharacterBody2D`, movement/facing, and target diamond. HPA-459 must not move its root/collision as part of tool feedback.

### Farming presentation

`FarmView` creates the 30 soil and crop presentations from `WorldContract.farm_cells()` and refreshes them from snapshots. It owns no mutable game rules. The current headless/integration contracts also pin `FarmSoil` to exactly those 30 soil children and pin the direct `World`/`Entities` child lists, so transient HPA-459 effects must not be hidden inside those rest-state collections.

### Audio

`GameHud` has one SFX player controlled by `UiSettings.sound`. Farming successes currently share `action.wav`; failures use the existing restrained blocked cue. HPA-459 extends this mapping rather than adding another audio service/player.

## Design

### 1. Structured authoritative farming preview

Evolve `GameSession.preview_selected_action(target_cell)` in place from returning only a `CommandCode` to returning one small transient Dictionary:

```gdscript
{
    "code": GameRules.CommandCode,
    "action": GameRules.FarmingAction,
    "crop": GameRules.CropKind | null,
    "cost": {
        "minutes": int,
        "stamina": int,
    },
}
```

The preview is not persisted and is not a second state model.

- `code` is produced by the existing `_selected_action_failure()` path, or the same success code used today when eligible.
- `action` is the selected `GameRules.FarmingAction` enum; transient in-process preview data does not use save/snapshot StringName encoding.
- `crop` is:
  - selected seed kind for Plant;
  - target crop kind for Water/Harvest when present;
  - `null` for Hoe or where no crop can be truthfully named.
- Add one private `GameSession._cost_for(action)` seam. In HPA-459 it forwards to `GameRules.action_cost(action)`.
- Change `GameRules.evaluate_action_budget()` to consume an explicit cost Dictionary; every farming guard and successful command supplies `_cost_for(action)`, and preview uses that same cost.
- HPA-460 can then add its rules-owned effective watering cost and change only `_cost_for()` to include session upgrade state; preview and command budgets remain aligned.

This intentionally changes the internal preview return shape rather than creating `preview_selected_action_v2()` or a second helper. Phoenix has no compatibility requirement for this private application seam.

The real command still performs its own validation and mutation. Preview never authorizes an animation by itself.

### 2. Truthful target hint

`WorldShell` continues to decide whether the target is valid/invalid/neutral, but delegates successful preview wording to one `GameHud.farming_preview_text(preview)` presenter.

Initial copy:

- Hoe: `Space — Till soil · 3 stamina`
- Plant: `Space — Plant Turnip · 1 stamina`
- Water: `Space — Water Turnip · 2 stamina`
- Harvest: `Space — Harvest Turnip · 1 stamina`

Seed inventory remains visible in the existing HUD rather than appearing after `·` where it could be mistaken for action cost.

The exact values are derived from the structured preview, never hardcoded beside the copy. HPA-460 can therefore change the watering cost in the rules/session policy and see the new value in the hint automatically.

Invalid farming targets keep the current red target tint and `feedback_text(code)`. Non-farm/interactable targets continue into the existing E-interaction hint chain.

### 3. One targeted mature-crop cue

Keep the normal crop stage sprites and soil wet/dry presentation unchanged.

`FarmView` adds target-only mature readiness using the approved `harvest-sparkle.png` peak frame:

- During the existing `refresh(snapshot)` crop loop, compute one derived maturity bool per cell with `GameRules.is_mature(kind, growth)`; do not infer readiness back from `Sprite2D.frame`.
- Define `SPARKLE_CROP_OFFSET := Vector2(0, -44)` once on `FarmView`; Harvest FX reuse the same constant.
- In `_ready()`, add one hidden peak-frame readiness sparkle as a child of each crop `Sprite2D`. The headless contract pins crop-root children, not children of the crop sprite, so this avoids runtime reparenting or allowlist churn.
- `set_target_cell(target_cell)` hides the previous cue and shows only the targeted crop child when its rules-derived maturity bool is true.

The cue is independent of selected tool so a mature crop is discoverable while Hoe/Seeds/Water is selected. It never changes the selected action or dispatches Harvest.

Use one cue object, not 30 labels/sparkles and not another readiness state in `GameSession`.

On every enabled `_process()` pass, `WorldShell` calls `FarmView.set_target_cell(target)` before branching on the selected-action preview, so invalid Hoe/Seeds/Water previews on a mature crop still show readiness. When world input is blocked, the existing early return clears the targeted cue together with the hint/tint.

### 4. Successful action capture and dispatch

Add one internal `WorldShell._attempt_selected_action(target_cell)` dispatch primitive. `use_selected_action()` remains a one-shot public wrapper around that primitive for existing integration/E2E callers; it never starts or advances hold state. Only real Space press/release handling plus `_process()` continuation own the hold gesture.

Before the mutating command, it captures the presentation facts that could disappear/change after the command:

```text
target cell
player facing
player world position
structured preview (including crop kind)
```

Then it calls `GameSession.apply_selected_action(target_cell)`.

Afterward:

1. `_finish_command(code)` remains the common feedback/session refresh path.
2. Only when `code` is one of the four farming success codes does `WorldShell` ask `FarmActionEffects` to play the captured visual feedback.
3. Invalid commands never get success effects.

This keeps rules authoritative and avoids an animation-driven command or event bus.

### 5. One narrow `FarmActionEffects` helper

Create `scripts/world/farm_action_effects.gd` and add exactly one non-Y-sorted `FarmActionEffects` Node directly under the existing World scene, immediately after `FarmSoil`, with `z_index = 5`. Update the existing headless World child allowlist/order in the same change. Do not create a reusable animation subsystem or separate PackedScenes for six tiny effects.

The helper receives the production references it needs from `WorldShell` (Player and Entities) plus a captured success context. Ground FX are children of this helper, not extra `FarmSoil` children, preserving the existing exact 30-soil rest-state contract. It creates transient child sprites/tweens and frees them when finished.

Use one helper-local tool-facing table for the HPA-458 frame/flip/Player-local anchor contract. Harvest sparkle placement reuses `FarmView.SPARKLE_CROP_OFFSET`; do not encode `(0, -44)` a second time.

Keep HPA-458's authored strip timing recommendations for `soil-impact`, `water-splash`, and `harvest-sparkle`; cell-local effects may overlap across different row cells. Cap only the shared Player-local tool-overlay motion at at most 150 ms so the next held action can replace/restart it cleanly. Plant's single seed drop stays in the ticket's short 150–250 ms range. Tweens never block movement or world input.

#### Hoe

- Use `hoe-overlay.png`.
- Select the HPA-458 frame/flip/Player-local anchor for the captured facing.
- Show it as a child of the Player root and apply only a small positional swing/dip around that anchor.
- Spawn `soil-impact.png` at the captured cell center, frames 0→1→2, then clear.

#### Plant

- Spawn `planting-seed.png` over the captured cell.
- Use a short downward drop/fade into the soil.
- The authoritative crop can already be visible after the session refresh; this is just a transient confirmation.

#### Water

- Use `watering-can-overlay.png` with the exact HPA-458 facing frame/flip/anchor.
- HPA-458's final consumer contract forbids texture rotation. Interpret the ticket's “tilt” intent as a short forward/down positional dip; do not rotate the texture or invent another frame.
- Spawn `water-splash.png` at the captured cell center, frames 0→1→2.
- The wet-soil state continues to come exclusively from the authoritative session snapshot.

#### Harvest

The real command removes the crop immediately, so capture its crop kind before dispatch.

On success:

- create a temporary duplicate of the mature crop presentation at the captured cell;
- tween it a short distance toward the captured player position while fading;
- show a brief `+1` label;
- attach/play `harvest-sparkle.png` using the shared `FarmView.SPARKLE_CROP_OFFSET` crop-sprite-space offset;
- free the transient nodes at completion.

The authoritative inventory/crop removal still comes only from `GameSession`.

#### Layering and cleanup

- Ground effects are children of the new direct-World `FarmActionEffects` node at `z_index = 5`; `FarmSoil` remains exactly its 30 soil Sprite2D children.
- Tool overlays are children of the existing Player root.
- Harvest pop presentation stays under the existing `Entities` Y-sort owner and is freed after playback, so the pinned rest-state entity list returns unchanged.
- `Entities` remains the only enabled Y-sort CanvasItem; `FarmActionEffects` must not enable y-sort.
- One tool overlay instance may restart/replace the previous tool tween; cell effects may overlap naturally when moving through a row.
- `_exit_tree()` clears transient tweens/nodes so Continue/result teardown cannot leave orphaned presentation.

### 6. Four distinct farming SFX through the existing HUD path

Add four short project-generated/minimally synthesized WAVs:

- `assets/audio/farm-hoe.wav`
- `assets/audio/farm-plant.wav`
- `assets/audio/farm-water.wav`
- `assets/audio/farm-harvest.wav`

Document their project-generated provenance in `assets/audio/README.md`.

Update only `GameHud._sfx_for_code()`:

- four farming success codes map one-to-one to the new cues;
- Action/Seed selection can keep the existing generic `ACTION_SFX`;
- failures keep the current blocked/cancel cue;
- no second audio player, bus, mixer, or setting is added.

Because all cues still use `_sfx_player`, the existing Sound=0 behavior applies automatically.

Held continuation checks eligibility before dispatch; it does not repeatedly call `show_feedback()` for blocked cells, so it also does not spam failure audio.

### 7. Hold-to-work as transient `WorldShell` state

Keep the gesture local to the coordinator:

```gdscript
const ACTION_HOLD_DWELL_SECONDS := 0.15

var _action_hold_active := false
var _action_hold_target: Variant = null
var _action_hold_dwell := 0.0
```

No part of this is saved. No per-hold success-cell set is needed: with tool/seed fixed for the hold, each successful command makes that same cell rules-ineligible (`ALREADY_TILLED`, `CROP_PRESENT`, `ALREADY_WATERED`, or `NO_CROP`).

#### Start

A `use_action` press handled by `WorldShell._unhandled_input()`:

1. returns immediately if `_world_input_enabled` is false, before touching any hold field;
2. cancels/resets any previous hold;
3. marks the gesture active;
4. immediately calls `_attempt_selected_action(current_target)` exactly once.

The existing `InputEvent.is_action_pressed("use_action")` call already uses Godot's default `allow_echo = false`, so no separate `event.is_echo()` guard is needed.

The initial press therefore keeps today's immediate Space behavior.

#### Continue

`_process(delta)` computes the target and structured preview once, then calls `_advance_action_hold(delta, target, preview)` before any success/invalid/neutral hint return. The updater:

- resets dwell when the target changes;
- dispatches only after the target stays stable for 150 ms and `preview["code"]` is a farming success code;
- skips blocked/non-farm targets without dispatch or error-SFX spam; moving later to another target resets dwell and can continue;
- relies on the existing action rules to make a previously successful cell ineligible, rather than tracking a second success-cell set;
- returns whether it dispatched; `_process()` returns immediately after a continuation dispatch so it never paints stale pre-mutation preview text.

No neighbouring scan, route, queue, reach extension, or hidden tool switching is performed.

#### Cancel

Use one `_cancel_action_hold()` helper. Cancel on:

- Space release;
- tool selection;
- seed change/cycle;
- the exact `_refresh_world_input_gate()` transition to disabled, rather than waiting for the next `_process()`; this covers blocking modals and the terminal finale lock;
- `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`;
- successful day transition/sleep;
- finale start.

Tutorial cards are intentionally not cancellation points because they are not part of `GameHud.has_blocking_modal()`.

A new World created by New Game/Continue naturally starts with no gesture state.

Closing a modal or regaining focus never reconstructs the hold from `Input.is_action_pressed()`. If Space is still physically down, the player must release and press it again, satisfying the fresh-press requirement.

No explicit echo branch is added: `InputEvent.is_action_pressed("use_action")` already defaults `allow_echo` to false for key events.

### 8. Testing strategy

Use the existing suites. No new harness.

#### Unit: `tests/unit/test_game_session.gd`

Revise the existing preview tests to prove:

- the structured preview is non-mutating;
- its `code` matches each real action guard;
- crop/seed context is truthful;
- `cost` equals `GameRules.action_cost()`;
- budget failures remain preview failures.

These tests are the policy guard that HPA-460 will extend later.

#### Integration: `tests/integration/test_gameplay_shell.gd`

Add focused checks for:

- exact successful hint composition and unchanged invalid hint/tint behavior;
- mature cue visible while targeting a mature crop even with a non-Hands tool, and absent elsewhere;
- effects only on confirmed success using captured cell/crop/facing; observe the transient nodes by their real parent/name/frame immediately after dispatch rather than adding a production `last_played`/debug API;
- each success code selects a distinct SFX stream through the existing HUD player;
- deterministic held-row state by driving the hold updater with explicit delta rather than sleeping on wall-clock timers:
  - immediate initial operation;
  - stable dwell before continuation;
  - one success per cell per hold;
  - standing/re-entering does not repeat;
  - blocked target is skipped without feedback/SFX spam;
  - a later eligible cell works;
  - tool/seed/modal/focus/day cancellation leaves no stale resume.

Do not make tests depend on tween completion timing where a direct state/node assertion is sufficient.

#### Existing E2E: `tests/e2e/gameplay_day_one_test.gd`

Add a **new** critical held-row test in the same file; do not splice it into or replace the existing one-cell `test_day_one_farming_loop_and_sleep()` and its `14`-stamina assertion.

Use three adjacent starter Turnip cells and the real input seam:

1. select Hoe, call `input_action("use_action", true)`, and verify the first target applies immediately;
2. use the existing `_stand_at_target()` helper to retarget the next cells and wait `WorldShell.ACTION_HOLD_DWELL_SECONDS * 4.0` after each move; verify exactly three tills without calling `use_selected_action()` remotely;
3. while Space is still down, change to Seeds and retarget/wait once to prove tool change canceled the gesture and no plant occurs until a fresh press;
4. call `input_action("use_action", false)`, then start a fresh held press for Seeds and repeat across the row;
5. release, select Water, start another fresh held press, and repeat;
6. verify the three cells, seed count, and final stamina reflect exactly one operation per cell.

Keep harvest-hold proof in deterministic integration/session fixtures rather than turning E2E into a weather-sensitive multi-day route.

Keep multi-day/mature-harvest hold proof in deterministic integration/session fixtures rather than turning E2E into a weather-sensitive multi-day route.

#### Visual/manual

- Run the existing native visual regression; do not add a second visual harness.
- Inspect the real world at native 640×360 and integer 2×:
  - all four player facings for the tool overlays;
  - hoe/seed/water/harvest effects;
  - mature target cue;
  - farm cells near foreground crops/props.
- Update only genuinely affected production goldens. CI must never bless them automatically.
- Record short row-play observations in this PR rather than opening another QA/release ticket.

## File map

### Create

- `scripts/world/farm_action_effects.gd`
- `assets/audio/farm-hoe.wav`
- `assets/audio/farm-plant.wav`
- `assets/audio/farm-water.wav`
- `assets/audio/farm-harvest.wav`

### Modify

- `scripts/game/game_session.gd`
- `scripts/world/world_shell.gd`
- `scripts/world/farm_view.gd`
- `scenes/world/world.tscn`
- `scripts/ui/game_hud.gd`
- `assets/audio/README.md`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/headless/world_shell_smoke.gd`
- `tests/e2e/gameplay_day_one_test.gd`
- `CLAUDE.md` only for durable handoff changes

`PlayerController` should remain unchanged unless implementation exposes a concrete targeting/input defect.

## Rejected alternatives

### Generic farming-action/event framework

Rejected. Four existing commands already share a stable session/coordinator seam. An event bus, command object hierarchy, animation scheduler, or reusable effect registry adds more ownership than this slice needs.

### Put hold logic in `PlayerController`

Rejected. The player owns movement/facing/targeting, while eligibility and command dispatch already belong to the session/WorldShell flow. Putting farming gesture state in PlayerController would mix rules coordination into movement code.

### Duplicate preview/cost formatter in UI

Rejected. HPA-460 explicitly needs one policy path. The session preview carries rule-derived cost/context; HUD only formats it.

### Animate gameplay by waiting for effects

Rejected. Presentation is intentionally non-blocking. Gameplay state changes immediately after authoritative validation; tweens visualize the result.

### Add 30 permanent mature markers

Rejected. One target-local cue is enough and preserves visual restraint.

## Risks and closures

1. **Space is pressed while the world-input gate is already closed**  
   Return before arming any hold field. Integration proves press-while-blocked → unblock causes no dispatch and still requires a fresh press.

2. **A harvest effect loses crop identity after mutation**  
   Capture structured preview/crop kind before calling the mutating command.

3. **Modal/focus transitions resume stale Space**  
   Cancel on the existing world-input gate and focus notification; never infer a new hold from current key state.

4. **HPA-460 must duplicate cost rules**  
   Preview cost comes from `GameRules.action_cost()`, the same policy consumed by command budgets.

5. **FX break pinned world-tree/depth contracts**  
   Add exactly one non-Y-sorted direct-World `FarmActionEffects` child and update the headless allowlist in the same task. Ground FX live there at z=5, `FarmSoil` stays at exactly 30 soils, tool motion is child presentation only, and harvest pop is transient under the one Entities Y-sort root.

6. **Water tool art conflicts with ticket “tilt” wording**  
   The completed HPA-458 consumer contract is final: no texture rotation. Use a short positional dip around its approved facing anchor.

7. **Held-row E2E is timing-sensitive under xvfb/CI**  
   Integration drives `_advance_action_hold()` with explicit delta. The one real-input E2E waits `WorldShell.ACTION_HOLD_DWELL_SECONDS * 4.0` after retargeting so scheduler jitter does not sit on the 150 ms threshold.

## Acceptance

HPA-459 is complete when:

1. Successful farming targets show truthful action-specific hints from structured session preview data.
2. Invalid targets retain current reason text and red tint.
3. One target-local mature cue works regardless of selected tool without changing selection.
4. Each successful farming action has distinct short visual feedback at the captured target/facing and one distinct SFX.
5. Failed commands mutate nothing and produce no success effect.
6. A normal Space press still attempts exactly one action immediately.
7. Held Space can deliberately traverse a short row, with at most one successful operation per cell per continuous hold.
8. Blocked/non-farm targets do not trigger repeated commands/error SFX; later eligible cells may continue.
9. release/tool/seed/modal/focus/day/finale cancellation requires a fresh Space press.
10. Existing farming budgets, weather, save state, finale score, and Day 14 behavior are unchanged.
11. Focused unit/integration coverage and one held-row existing E2E flow pass.
12. Native 640×360 and integer-2× manual checks pass using the approved HPA-458 assets.
13. Existing clean verifier, GdUnit lanes, affected E2E, import/export, and visual regression pass.
14. No new image generation, save migration, action framework, or second gameplay state is introduced.

## Delivery rule

One Linear issue, one branch, one PR. This planning change opens the HPA-459 draft PR; implementation, the four small audio cues, tests, visual evidence, and final verification continue on that same branch and PR.