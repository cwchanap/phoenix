# HPA-264 — Target-Driven Farming Implementation Plan

**Linear:** https://linear.app/cwchanap/issue/HPA-264/gameplay-polish-make-space-pick-the-farming-action-from-the-target  
**Design:** [Target-driven farming design](../specs/2026-10-25-phoenix-target-driven-farming-design.md)  
**Delivery rule:** *one ticket, one PR*. Continue implementation and code review on agent/hpa-264-target-driven-farming-plan; never open a follow-up implementation PR.  
**Current state:** plan only; steps below are not checked off.

## Implementation sequence (in this same PR)

### 0. Verify baseline and references

- [ ] Reconfirm latest main/PR head and no new competing HPA-264 PR before touching runtime files.
- [ ] Run baseline ./tools/verify-clean.sh and relevant GdUnit4 suites on committed HEAD; note any pre-existing failures. Check current usages of selected_action, select_action_requested, select_action_slot, Action_*, 1/3/4 controls and state shape across source/tests/visual fixtures.
- [ ] Keep the finished HPA-353 SessionStateValidator ownership boundary; do not reintroduce GameSession.state_error().

### 1. RED: pin domain behavior and saved shape

- [ ] Extend tests/unit/test_game_session.gd with a four-row state-to-action table (untilled → Hoe, tilled empty → Seeds, immature → Water, mature → Hands) and actual command result matching preview on each.
- [ ] Cover missing/nonfarm target, empty selected seed, rain, already-watered, stamina/time cutoff and Efficient Can 1-stamina Water. Preserve early active-day/finale precedence and cost/crop preview assertions.
- [ ] Update the exact snapshot keys/count expectation (one key removed), no selected_action in state(), seed still persisted, and ensure preview cannot mutate state.
- [ ] Extend SessionStateValidator tests: new-format state passes; state with legacy selected_action fails; missing/invalid selected_seed still fails; failed restore leaves GameSession unchanged.
- [ ] Confirm these new expectations fail appropriately before changing runtime.

### 2. GREEN: one resolver, no selected tool state

- [ ] In scripts/game/game_session.gd introduce _action_for_target() based solely on the authoritative tile. Refactor preview_selected_action() and apply_selected_action() through this resolver; retain per-action failures/mutations and _cost_for() unchanged.
- [ ] Remove _selected_action and select_action(), state()/snapshot()/restore_state() references, and the now-obsolete selection switch. Do not duplicate action choice between preview and mutation. Return a nonfarm preview with null action and existing error codes; preserve preview four-key shape.
- [ ] In scripts/game/session_state_validator.gd remove the selected_action *required* check, add a direct retired-field rejection (including ordinary JSON string key), and keep unrelated validator behavior untouched. Do not alter SaveFileCodec envelope or add migration.
- [ ] Re-run focused GUT session / validator tests, correct any mismatched success/failure precedence.

### 3. GREEN: WorldShell controls, hold and HUD

- [ ] In scripts/world/world_shell.gd remove old select-action signals and 1/3/4 dispatch; make select_action_slot(2) cycle the selected seed on **every** press. Keep the current select_seed(kind) pathway for seed buttons.
- [ ] Add nullable _action_hold_action; capture it before the first press's command; reset in _cancel_action_hold(); gate _advance_action_hold() on matching preview.action and existing dwell/success checks. Cancel on seed change, blocked UI and focus loss. Keep one-shot use_selected_action() available for test/E2E fixtures.
- [ ] In scripts/ui/game_hud.gd remove action selection requests, make Action_0..3 read-only indicators without the disabled/dimmed presentation of an unavailable button, add set_target_action(action: Variant) with change check, and keep seed buttons usable. Update highlight from WorldShell's already-computed preview; avoid per-frame whole-HUD renders. Render still owns seed count, active seed badge, Efficient Can texture and other state.
- [ ] Update scenes/ui/game_hud.tscn instructional/key legends; remove select_hoe, select_water and select_hands from project.godot, retaining select_seeds physical key 2. Decide whether to keep the action index layout for visual continuity (default: keep it).
- [ ] Update ContentRules.TUTORIALS text while keeping IDs/completion codes; README.md and CLAUDE.md document Space-to-resolve and seed cycling.

### 4. Integration and real-input regression proof

- [ ] Update tests/integration/test_gameplay_shell.gd: action selection assertions become resolved-target indicator assertions; verify auto till→plant→water→harvest on one target, proper tool effects, truthful red hints for already watered/rain/no seeds, context E hints and 2 cycling.
- [ ] Replace old assumptions that 'after Hoe the tile is red until selecting Seeds': the preview should become green for planting. Mature-crop readiness test should still show sparkle and now report valid Harvest automatically. Keep modal gating and native controls tests.
- [ ] Add one deterministic hold-gesture integration test proving a three-cell Hoe hold **never** auto-plants on the same held press; verify seed change cancels a gesture and new gestures plant/water.
- [ ] Rewrite tests/e2e/gameplay_day_one_test.gd's button-click helper and held-row test to use target-driven Space, release between passes, and assert only 3 tills before the first release. Keep actual input movement, target values, stamina and save isolation.
- [ ] Update tests/headless/world_shell_smoke.gd physical-key mappings: 2 remains, 1/3/4 mappings no longer exist.
- [ ] Update tests/visual/ui_fixture_factory.gd and any tests/goldens that hardcode selected_action or the previous active icon. Avoid unrelated pixel changes.

### 5. Verification and review gate

- [ ] Run ./tools/verify-clean.sh from *committed HEAD* (archives HEAD, not the working tree); record GUT totals, headless smokes, audio check.
- [ ] Run ./addons/gdUnit4/runtest.sh -a tests/gdunit -c and -a tests/e2e -c (with local Godot configured), and any relevant specific shell/visual fixtures.
- [ ] Native macOS: run ./tools/verify-visual.sh against approved raw 640×360 production captures; re-bless only the genuine changed toolbar scenes, inspect screenshot diffs. CI must not generate/re-bless goldens.
- [ ] Check clean imports, no stale selected_action references except the deliberate legacy-save rejection test, no pressed action-select controls, no regressions to Day 1/14 and 22:00 action cutoff.
- [ ] Run git diff --check, update PR body with exact evidence/limitations, address review comments, mark ready only when implementation and tests land on this same PR.

## Review checkpoints / avoid overengineering

Review the resolver/failure-ordering contract, the retired-field save rejection, and the hold lock before writing broad code changes. Keep GameSession the only gameplay state owner, SessionStateValidator the one validation owner, WorldShell the sole input/hold owner, and GameHud pure presentation. No extra input service, tool selection model, generic action router, save schema migration, new images/audio, or separate implementation PR.

## Known review risk

The validator intentionally accepts unrelated extra top-level keys. Merely deleting its selected_action required-field check would accidentally accept old saves; explicitly reject that retired key. Separately, the current _advance_action_hold() relies on a manually selected action becoming ineligible after success. Under automatic resolution the **next** action becomes eligible immediately, so the per-gesture action lock is essential to avoid till-and-plant on one hold.
