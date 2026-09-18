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

`FarmView` creates the 30 soil and crop presentations from `WorldContract.farm_cells()` and refreshes them from snapshots. It owns no mutable game rules.

### Audio

`GameHud` has one SFX player controlled by `UiSettings.sound`. Farming successes currently share `action.wav`; failures use the existing restrained blocked cue. HPA-459 extends this mapping rather than adding another audio service/player.

## Design

### 1. Structured authoritative farming preview

Evolve `GameSession.preview_selected_action(target_cell)` in place from returning only a `CommandCode` to returning one small transient Dictionary:

```gdscript
{
    "code": GameRules.CommandCode,
    "action": StringName,
    "crop": StringName | null,
    "cost": {
        "minutes": int,
        "stamina": int,
    },
    "available_seeds": int,
}
```

The preview is not persisted and is not a second state model.

- `code` is produced by the existing `_selected_action_failure()` path, or the same success code used today when eligible.
- `action` is the selected action key.
- `crop` is:
  - selected seed kind for Plant;
  - target crop kind for Water/Harvest when present;
  - `null` for Hoe or where no crop can be truthfully named.
- `cost` comes directly from `GameRules.action_cost(_selected_action)`.
- `available_seeds` is the selected seed count; it is presentation context only.

This intentionally changes the internal preview return shape rather than creating `preview_selected_action_v2()` or a second helper. Phoenix has no compatibility requirement for this private application seam.

The real command still performs its own validation and mutation. Preview never authorizes an animation by itself.

### 2. Truthful target hint

`WorldShell` continues to decide whether the target is valid/invalid/neutral, but delegates successful preview wording to one `GameHud.farming_preview_text(preview)` presenter.

Initial copy:

- Hoe: `Till soil · 3 stamina`
- Plant: `Plant Turnip · 3 seeds` (pluralized from the selected seed count)
- Water: `Water Turnip · 2 stamina`
- Harvest: `Harvest Turnip`

The exact values are derived from the structured preview, never hardcoded beside the copy. HPA-460 can therefore change the watering cost in the rules/session policy and see the new value in the hint automatically.

Invalid farming targets keep the current red target tint and `feedback_text(code)`. Non-farm/interactable targets continue into the existing E-interaction hint chain.

### 3. One targeted mature-crop cue

Keep the normal crop stage sprites and soil wet/dry presentation unchanged.

`FarmView` gains one reusable mature-target cue using the approved `harvest-sparkle.png` peak frame:

- cache which farm cells are currently mature while refreshing the snapshot;
- expose `set_target_cell(target_cell)`;
- when the targeted cell contains a mature crop, reparent/show one reusable sparkle under that crop sprite at the HPA-458 handoff offset `(0, -44)`;
- hide it for non-mature/non-farm/no-target cells.

The cue is independent of selected tool so a mature crop is discoverable while Hoe/Seeds/Water is selected. It never changes the selected action or dispatches Harvest.

Use one cue object, not 30 labels/sparkles and not another readiness state in `GameSession`.

When world input is blocked, `WorldShell` clears the targeted cue together with the hint/tint.

### 4. Successful action capture and dispatch

Add one internal `WorldShell._attempt_selected_action(target_cell)` path used by both a normal Space press and held continuation.

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

Create `scripts/world/farm_action_effects.gd` and add one `FarmActionEffects` Node under the existing World scene. Do not create a reusable animation subsystem or separate PackedScenes for six tiny effects.

The helper receives production nodes/references it needs from `WorldShell` (Player, FarmSoil, FarmView/Entities) and a captured success context. It creates transient child sprites/tweens and frees them when finished.

Initial duration target is about 180–220 ms. Tweens never block movement or world input.

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
- attach/play `harvest-sparkle.png` using HPA-458's `(0, -44)` crop-sprite-space offset;
- free the transient nodes at completion.

The authoritative inventory/crop removal still comes only from `GameSession`.

#### Layering and cleanup

- Ground effects are children of the existing non-Y-sorted `FarmSoil` layer.
- Tool overlays are children of the existing Player root.
- Harvest pop presentation stays under the existing `Entities` Y-sort owner.
- Do not introduce a second Y-sort root.
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
var _action_hold_success_cells: Dictionary = {}
```

No part of this is saved.

#### Start

A non-echo `use_action` press while world input is enabled:

1. cancels/resets any previous hold;
2. marks the gesture active;
3. immediately calls `_attempt_selected_action(current_target)` exactly once;
4. records the target in `_action_hold_success_cells` only if the operation succeeds.

The initial press therefore keeps today's immediate Space behavior.

#### Continue

Each `_process(delta)` pass uses the current faced target:

- when the target changes, reset dwell to zero;
- after the target is stable for 150 ms:
  - if the cell already succeeded during this continuous hold, do nothing;
  - otherwise inspect the current authoritative preview;
  - dispatch through `_attempt_selected_action()` only when the preview code is a farming success code;
  - if blocked/non-farm, do not dispatch and do not emit failure feedback/SFX;
  - when a later eligible target becomes stable, continuation can proceed.

Only successful cells enter the per-hold set. Returning to a previously successful cell cannot charge resources again.

No neighbouring scan, route, queue, reach extension, or hidden tool switching is performed.

#### Cancel

Use one `_cancel_action_hold()` helper. Cancel on:

- Space release;
- tool selection;
- seed change/cycle;
- world input gate becoming blocked (any blocking modal);
- application/window focus loss;
- successful day transition/sleep;
- finale start.

A new World created by New Game/Continue naturally starts with no gesture state.

Closing a modal or regaining focus never reconstructs the hold from `Input.is_action_pressed()`. If Space is still physically down, the player must release and press it again, satisfying the fresh-press requirement.

Key-repeat/echo events are ignored as action sources.

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
- effects only on confirmed success using captured cell/crop/facing;
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

Add one critical held-row flow using three adjacent starter Turnip cells:

1. select Hoe and start a fresh Space hold;
2. move/reposition across the three cells with stable-target dwell and verify exactly three tills;
3. release, select Seeds, repeat with a fresh hold;
4. release, select Water, repeat with a fresh hold;
5. verify the three cells, seed count, and final stamina reflect exactly one operation per cell.

Tool changes intentionally require a new Space press, proving cancellation and avoiding a separate automation mechanic.

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

1. **Initial press double-dispatches due to key repeat/hold processing**  
   Ignore echo as a source and make held continuation wait for a target change/stable dwell after the immediate dispatch.

2. **A harvest effect loses crop identity after mutation**  
   Capture structured preview/crop kind before calling the mutating command.

3. **Modal/focus transitions resume stale Space**  
   Cancel on the existing world-input gate and focus notification; never infer a new hold from current key state.

4. **HPA-460 must duplicate cost rules**  
   Preview cost comes from `GameRules.action_cost()`, the same policy consumed by command budgets.

5. **FX break world depth or collision**  
   Tool motion is child presentation only; ground FX stay in FarmSoil and harvest pop stays under the one Entities Y-sort root.

6. **Water tool art conflicts with ticket “tilt” wording**  
   The completed HPA-458 consumer contract is final: no texture rotation. Use a short positional dip around its approved facing anchor.

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