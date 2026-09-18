# Phoenix Responsive Farming Polish Implementation Plan

**Linear:** HPA-459  
**Branch:** `agent/hpa-459-gameplay-polish-plan`  
**Spec:** `docs/superpowers/specs/2026-09-17-phoenix-gameplay-polish-design.md`

**Goal:** Make Phoenix's repeated farming interaction truthful, responsive, and row-friendly while preserving the current single-cell rules, economy, save state, and 14-day loop.

**Architecture:** Extend existing owners only. `GameSession` remains the rules/mutation authority; `WorldShell` remains the preview/dispatch coordinator and owns the tiny transient hold gesture; `FarmView` remains snapshot presentation; `GameHud` owns copy/audio; one `FarmActionEffects` helper owns short-lived presentation. No generic action/event framework.

## Global constraints

- One ticket / one branch / one PR. Implementation continues on this same draft PR.
- HPA-458 is done. Consume its committed runtime PNGs and `tests/visual/hpa-458/README.md`; do not generate/modify replacement image art here.
- Keep `GameSession` as the only mutable gameplay authority.
- Keep `GameRules.action_cost()` / budget policy as the source used by preview and real commands.
- Keep `PlayerController` focused on movement/facing/targeting; do not move its root/collision for tool animation.
- Keep `Entities` as the only world Y-sort root. `FarmSoil` remains the pinned non-Y-sorted container with exactly 30 soil Sprite2D children; transient ground effects go on one new non-Y-sorted direct-World `FarmActionEffects` child at `z_index = 5`.
- Keep the current save schema/state unchanged.
- No new crop/economy/balance rules, new map, tool upgrade, auto-pathing, scan, queue, event bus, effect registry, animation state machine, or player animation rig.
- Held input never bypasses the same session validation/cost path.
- HPA-458 tool textures never rotate. Water uses a short positional dip around the approved anchor.
- Four short project-generated farming SFX belong to this PR; no separate audio task/framework is needed.

## Verification workflow

`./tools/verify-clean.sh` archives committed HEAD, so use focused worktree suites during RED/GREEN and run the clean verifier after checkpoint commits.

Existing local/release gates remain:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
./tools/verify-clean.sh
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
./tools/verify-visual.sh
git diff --check main...HEAD
```

Run the smallest relevant suite after each RED/GREEN step; the full gates are Task 4.

---

## Task 1: Make preview the single truthful farming read model

**Files:**  
`scripts/game/game_session.gd`  
`scripts/ui/game_hud.gd`  
`scripts/world/world_shell.gd`  
`scripts/world/farm_view.gd`  
`tests/unit/test_game_session.gd`  
`tests/integration/test_gameplay_shell.gd`

### 1.1 RED — revise the existing preview contract tests

- [ ] Update existing `preview_selected_action()` tests to expect the structured Dictionary described by the spec.
- [ ] Pin `code`, `action`, `crop`, `cost`, and `available_seeds` for representative Hoe/Plant/Water/Harvest states.
- [ ] Keep the existing no-mutation assertions.
- [ ] Assert preview `cost` equals `GameRules.action_cost(selected_action)`; do not duplicate numeric cost fixtures except where a rule test already pins them.
- [ ] Keep budget-failure parity: preview failure code must match the real command guard.

### 1.2 GREEN — evolve `preview_selected_action()` in place

- [ ] Keep `_selected_action_failure()` and the four action guard helpers as the validation path.
- [ ] Return one structured transient Dictionary; no second preview method and no persisted field.
- [ ] Resolve crop context narrowly:
  - Plant → selected seed;
  - Water/Harvest → target crop when present;
  - Hoe → null.
- [ ] Fill cost from `GameRules.action_cost()`.
- [ ] Fill selected-seed availability from the current session count.

### 1.3 RED/GREEN — action-specific hint formatting

- [ ] Add focused integration assertions for valid target copy:
  - Till soil + stamina;
  - Plant selected crop + available seed count;
  - Water target crop + stamina;
  - Harvest target crop.
- [ ] Add `GameHud.farming_preview_text(preview)` as presentation-only formatting.
- [ ] Change `WorldShell._process()` to use `preview["code"]` for tint/eligibility and the HUD formatter for successful farm hints.
- [ ] Leave invalid reason copy on `feedback_text(code)`.
- [ ] Leave neutral E-interaction hint routing unchanged.

### 1.4 RED/GREEN — one mature-target cue

- [ ] Add an integration fixture with a mature crop and a non-Hands selected action.
- [ ] Do **not** cache a parallel mature-cell set. `FarmView.set_target_cell()` inspects the existing `_crop_sprites[cell]` directly: visible + mature visual frame is the readiness source.
- [ ] Define `FarmView.SPARKLE_CROP_OFFSET := Vector2(0, -44)` once and create one reusable sparkle cue reparented under the targeted crop sprite at that offset. Task 2's harvest effect reads the same constant.
- [ ] Call `FarmView.set_target_cell(target)` on every enabled target before `WorldShell` branches on preview validity, including invalid Hoe/Seeds/Water previews on a mature crop.
- [ ] Clear it in the existing `_process()` early return whenever world input is blocked.
- [ ] Do not add 30 cue nodes, new snapshot fields, or readiness state to `GameSession`.

**Checkpoint:** focused unit + integration tests green; commit before using `verify-clean.sh`.

---

## Task 2: Add successful farming presentation and distinct SFX

**Files:**  
`scripts/world/farm_action_effects.gd` (new)  
`scenes/world/world.tscn`  
`scripts/world/world_shell.gd`  
`scripts/ui/game_hud.gd`  
`assets/audio/farm-hoe.wav` (new)  
`assets/audio/farm-plant.wav` (new)  
`assets/audio/farm-water.wav` (new)  
`assets/audio/farm-harvest.wav` (new)  
`assets/audio/README.md`  
`tests/integration/test_gameplay_shell.gd`  
`tests/headless/world_shell_smoke.gd`

### 2.1 RED — pin capture-before-mutation and success-only effects

- [ ] Add a focused integration seam around a successful farming attempt and an invalid attempt.
- [ ] Assert the success path can observe the target cell, facing, player position, and pre-mutation preview crop.
- [ ] Assert invalid commands create no farming success effect.
- [ ] For Harvest, prove the captured crop kind survives even though session refresh removes the authoritative crop.

Observe the real transient effect nodes by parent/name/frame immediately after dispatch (and their absence after cleanup) rather than adding a production `last_played`, counter, or debug API. Keep the existing rest-state child-count tests intact.

### 2.2 GREEN — centralize manual/held dispatch

- [ ] Add `WorldShell._attempt_selected_action(target_cell)`.
- [ ] Capture preview + target + facing + player world position immediately before dispatch.
- [ ] Call `GameSession.apply_selected_action()`.
- [ ] Route every result through existing `_finish_command()`.
- [ ] Invoke the effect helper only for the four success codes.
- [ ] Keep current `use_selected_action()` as a one-shot wrapper that delegates to this path and returns; it never starts/advances hold state. Only `_unhandled_input` Space press/release plus `_process()` continuation own the hold fields.

### 2.3 GREEN — one `FarmActionEffects` helper, no framework

- [ ] Add exactly one non-Y-sorted `FarmActionEffects` helper directly under World, immediately after `FarmSoil`, with `z_index = 5`; no per-effect PackedScenes or registry.
- [ ] In the same change, update `tests/headless/world_shell_smoke.gd`'s exact World child allowlist/order to include `FarmActionEffects`; keep `Entities` as the only enabled y-sort node.
- [ ] Keep `FarmSoil` at exactly its 30 soil children and preserve the pinned rest-state `Entities` list once transient harvest nodes are freed.
- [ ] Preload the six approved HPA-458 farming textures.
- [ ] Encode the final HPA-458 tool frame/flip/anchor table exactly once in this helper:
  - UP → frame 1 at `(0,-22)`;
  - RIGHT → frame 2 at `(10,-21)`;
  - DOWN → frame 0 at `(4,-16)`;
  - LEFT → frame 2, flipped, at `(-10,-21)`.
- [ ] Never rotate or scale the tool textures.
- [ ] Hoe: short tool positional motion + cell-centered `soil-impact` 0→1→2.
- [ ] Plant: cell-centered seed drop/fade.
- [ ] Water: short can positional dip + cell-centered `water-splash` 0→1→2.
- [ ] Harvest: temporary mature crop pop toward the captured player position + `+1` + sparkle using `FarmView.SPARKLE_CROP_OFFSET`; do not duplicate `(0,-44)`.
- [ ] Use one fixed ~200 ms playback window and document that this intentionally overrides HPA-458's slower strip-fps recommendations so the 150 ms held-row cadence remains readable.
- [ ] Position cell FX with the existing `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`; do not add a second projection helper.
- [ ] Ground effects go under direct-World `FarmActionEffects` at z=5; harvest pop stays under Entities; tool overlays stay under Player.
- [ ] Replacing/restarting a current tool tween is fine; never move Player/Collision/Y-sort root.
- [ ] Free transient nodes/tweens on completion and world teardown.

### 2.4 RED/GREEN — replace generic farming success SFX

- [ ] Produce four very short project-generated/minimally synthesized WAVs with clearly different timbres.
- [ ] Extend `assets/audio/README.md` provenance; no external asset dependency if synthesis is used.
- [ ] Add integration assertions that the four farming success codes resolve to four distinct streams.
- [ ] Change `GameHud._sfx_for_code()` so only these four successes use the new files.
- [ ] Keep Action/Seed selection on `ACTION_SFX`.
- [ ] Keep failures on the existing blocked/cancel feedback.
- [ ] Keep the same `_sfx_player`; Sound setting automatically controls all new cues.

**Checkpoint:** focused integration tests green; manually smoke all four effects once at native scale; commit then run `verify-clean.sh`.

---

## Task 3: Add deliberate hold-to-work without new gameplay machinery

**Files:**  
`scripts/world/world_shell.gd`  
`tests/integration/test_gameplay_shell.gd`  
`tests/e2e/gameplay_day_one_test.gd`

### 3.1 RED — deterministic hold-state contract

Add integration tests that drive the hold updater with explicit delta values instead of wall-clock sleeps.

- [ ] A fresh non-echo press immediately attempts one action.
- [ ] Staying on the same successful cell never repeats.
- [ ] Changing target resets dwell; no continuation before 150 ms.
- [ ] An eligible new target dispatches once after stable dwell.
- [ ] Returning to a previously successful cell in the same hold does not repeat.
- [ ] An invalid/non-farm target is previewed but not dispatched repeatedly; feedback/SFX text/stream is not restarted by hold polling.
- [ ] Moving later to an eligible target continues successfully.
- [ ] Space release clears the gesture.
- [ ] Tool selection clears the gesture.
- [ ] Seed selection/cycle clears the gesture.
- [ ] Opening a blocking modal clears the gesture and closing it does not resume while Space remains down.
- [ ] Focus loss clears the gesture.
- [ ] Day transition/finale clears the gesture.

### 3.2 GREEN — four local transient fields only

- [ ] Add `ACTION_HOLD_DWELL_SECONDS := 0.15`.
- [ ] Add active/current-target/dwell/success-cell-set fields from the spec.
- [ ] Add one `_cancel_action_hold()`.
- [ ] On non-echo `use_action` press:
  - reset/start;
  - immediately call `_attempt_selected_action()`;
  - record the target only when that attempt succeeds.
- [ ] On release, cancel.
- [ ] In `_process(delta)`, after target resolution, advance the hold only for stable targets.
- [ ] Use the current structured session preview before any automatic dispatch.
- [ ] Automatic invalid/non-farm targets do not call `_finish_command()` and do not play error feedback.
- [ ] Never call `Input.is_action_pressed("use_action")` to reconstruct a canceled hold.
- [ ] Ignore key echo/repeat as a dispatch source.
- [ ] Cancel from the existing action/seed selection entry points.
- [ ] Inside `_refresh_world_input_gate()`, cancel immediately when the recomputed gate becomes false; do not wait for the next `_process()` tick. Tutorial cards do not cancel because they are not blocking modals.
- [ ] Handle both `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`; no global input manager.
- [ ] Filter `event.is_echo()` on the existing `use_action` press branch before the initial dispatch, not only during continuation.

### 3.3 E2E — one three-cell held Day-1 row

Add a new held-row test in the existing Day-1 E2E file; do not modify the existing one-cell `test_day_one_farming_loop_and_sleep()` budget flow or its `14`-stamina assertion. Do not create another harness.

- [ ] Derive three adjacent cells from `WorldContract.FARM_PATCH`.
- [ ] Select Hoe, then drive the real gesture with `game.input_action("use_action", true)`; verify the first target applies immediately.
- [ ] Retarget with the existing `_stand_at_target()` helper and `wait_seconds()` just beyond 150 ms for each next cell; do **not** call `use_selected_action()` remotely for this test.
- [ ] While Space is still down, select Seeds, retarget, and wait beyond dwell; verify no plant occurs, pinning that tool change canceled hold and requires a fresh press.
- [ ] Release with `game.input_action("use_action", false)`, then start a fresh held gesture and plant all three; release.
- [ ] Select Water, start another fresh held gesture, water all three, release.
- [ ] Verify three cells reached the expected state.
- [ ] Verify exactly three starter seeds were consumed.
- [ ] Verify exactly the expected stamina was consumed: 3×(3+1+2)=18, leaving 2 from this separate fresh Day-1 run's 20-stamina budget.
- [ ] Keep mature/harvest hold proof in deterministic integration/session setup rather than making E2E depend on several weather rolls.

**Checkpoint:** affected integration + existing E2E green; commit then run the relevant clean/GdUnit lanes.

---

## Task 4: Closeout, native visual review, docs, and full gates

**Files:**  
`CLAUDE.md` only if durable architecture/handoff text changes  
affected tests/assets from Tasks 1–3  
PR description/evidence

### 4.1 Regression and scope review

- [ ] Confirm no save/state/schema field was added.
- [ ] Confirm `PlayerController` still owns only movement/facing/targeting unless a concrete defect required a narrow fix.
- [ ] Confirm one direct-World, non-Y-sorted `FarmActionEffects` helper exists; the headless World allowlist is updated, `FarmSoil` still has exactly 30 soil children, and no event/action/effect framework appeared.
- [ ] Confirm hold state lives only in `WorldShell`.
- [ ] Confirm HPA-458 images are consumed as-is and no new image generation/art cleanup happened.
- [ ] Confirm no farming budget/crop/economy/finale values changed.
- [ ] Confirm HPA-460 can alter watering cost by changing the existing rules/session policy without editing hint constants.

### 4.2 Native visual acceptance

Run `./tools/verify-visual.sh` unchanged first.

Then inspect the actual world at:

- native 640×360;
- integer 2×;
- all four player facings with Hoe and Water overlays;
- Hoe/Plant/Water/Harvest effects;
- mature target cue;
- at least one row near foreground crops/props.

Review affected production goldens only if the live capture surface genuinely changes. CI never blesses.

Record one short observation in the PR: whether held row traversal feels deliberate at the initial 150 ms dwell. If tuning is necessary, adjust only this dwell within the same PR and pin the final value in tests; do not open a tuning ticket.

### 4.3 Full verification

Run:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
./tools/verify-visual.sh
git diff --check main...HEAD
```

- [ ] Inspect `git status --short` after import; no unrelated sidecars/cache.
- [ ] Keep new WAV `.import` sidecars if Godot generates them as required by the repository convention.
- [ ] Update PR description with test results, visual evidence, and row-play note.
- [ ] Keep this PR draft until implementation and evidence are complete.

---

## Self-review

Before implementation starts, confirm the plan still satisfies all of these:

- one PR for HPA-459 from plan through implementation;
- HPA-458 is consumed, not reopened or regenerated;
- one enriched preview replaces the old shape rather than adding a parallel preview API;
- preview and commands share validation/cost policy;
- one mature target cue derived from existing crop sprites, with no parallel mature-cell cache;
- one direct-World effects helper at z=5, with FarmSoil/Entities rest-state counts preserved, not an action/event framework;
- no tool texture rotation despite the ticket's “tilt” wording;
- no Player root/collision motion;
- held input never scans, paths, queues, switches tools, or extends range;
- only successful cells are remembered within a continuous hold;
- blocking-gate/focus/day/tool/seed cancellation is immediate and requires a fresh press; non-blocking tutorial cards do not cancel;
- blocked hold targets do not spam commands or error SFX;
- audio uses the existing SFX player and Sound preference;
- no save changes or compatibility work;
- existing verification/visual/E2E infrastructure is reused.