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
- [ ] Cover save incompatibility at the **existing codec boundary**: schema-v3 save round-trips and v2 (plus other wrong versions) returns Unsupported save schema. Re-pin tests/unit/test_save_file.gd and the SCHEMA_VERSION assertion in tests/integration/test_app_launch.gd. Keep SessionStateValidator tests for required selected_seed and failed restore's atomicity; no bespoke retired-field validator matrix.
- [ ] Confirm these new expectations fail appropriately before changing runtime.

### 2. GREEN: one resolver, no selected tool state

- [ ] In scripts/game/game_session.gd introduce _action_for_target() based solely on the authoritative tile. Refactor preview_selected_action() and apply_selected_action() through this resolver; retain per-action failures/mutations and _cost_for() unchanged.
- [ ] Remove _selected_action and select_action(), state()/snapshot()/restore_state() references, and the now-obsolete selection switch. Do not duplicate action choice between preview and mutation. Return a nonfarm preview with null action and existing error codes; preserve preview four-key shape.
- [ ] Delete the unreachable GameRules.CommandCode.ACTION_SELECTED enum member, GameHud feedback/SFX case, and affected references in tests/unit/test_game_session.gd, tests/unit/test_content_rules.gd, tests/integration/test_gameplay_shell.gd. Preserve SEED_SELECTED and its ACTION_SFX mapping.
- [ ] In scripts/game/session_state_validator.gd delete the selected_action required-field block only; do **not** add a retired-key rejection branch or a strict-key schema. Bump SaveFileCodec.SCHEMA_VERSION 2→3 in scripts/persistence/save_file.gd while keeping the envelope/codec behavior otherwise unchanged. The production loader must reject v2 envelopes before state validation; internal raw dictionaries are outside this codec-version gate.
- [ ] Re-run focused GUT session / validator tests, correct any mismatched success/failure precedence.

### 3. GREEN: WorldShell controls, hold and HUD

- [ ] In scripts/world/world_shell.gd remove old select-action signals and 1/3/4 dispatch; make select_action_slot(2) cycle the selected seed on **every** press. Keep the current select_seed(kind) pathway for seed buttons.
- [ ] Add nullable _action_hold_action; capture it before the first press's command; reset in _cancel_action_hold(); gate _advance_action_hold() on matching preview.action and existing dwell/success checks. Cancel on seed change, blocked UI and focus loss. Keep one-shot use_selected_action() available for test/E2E fixtures.
- [ ] In scripts/ui/game_hud.gd remove action selection requests, make Action_0..3 read-only indicators without the disabled/dimmed presentation of an unavailable button, add set_target_action(action: Variant) with change check, and keep seed buttons usable. Update highlight from WorldShell's already-computed preview; avoid per-frame whole-HUD renders. Render still owns seed count, active seed badge, Efficient Can texture and other state.
- [ ] Update scenes/ui/game_hud.tscn instructional/key legends **and** scenes/ui/pause_panel.tscn's obsolete 1/2/3/4 keycaps, "Hoe · Seeds · Water · Hands" legend and "Use the selected action" text. Remove select_hoe, select_water and select_hands from project.godot, retaining select_seeds physical key 2. Keep the four action icons for visual continuity.
- [ ] Update ContentRules.TUTORIALS text while keeping IDs/completion codes; remove the scripts/ui/onboarding_overlay.gd farm_basics hardcoded shorter-body override so the shared TUTORIALS body is authoritative. Update README.md, CLAUDE.md **and AGENTS.md** controls, the hold-to-work explanation, and schema-v2 mentions to v3.

### 4. Integration and real-input regression proof

- [ ] Update tests/integration/test_gameplay_shell.gd: action selection assertions become resolved-target indicator assertions; verify auto till→plant→water→harvest on one target, proper tool effects, truthful red hints for already watered/rain/no seeds, context E hints and 2 cycling.
- [ ] Replace old assumptions that 'after Hoe the tile is red until selecting Seeds': the preview should become green for planting. Mature-crop readiness test should still show sparkle and now report valid Harvest automatically. Keep modal gating and native controls tests.
- [ ] Add one deterministic hold-gesture integration test proving a three-cell Hoe hold **never** auto-plants on the same held press; verify seed change cancels a gesture and new gestures plant/water.
- [ ] Rewrite tests/e2e/gameplay_day_one_test.gd's button-click helper and held-row test to use target-driven Space, release between passes, and assert only 3 tills before the first release. Keep actual input movement, target values, stamina and save isolation.
- [ ] Update tests/headless/world_shell_smoke.gd physical-key mappings: 2 remains, 1/3/4 mappings no longer exist.
- [ ] Update tests/visual/ui_fixture_factory.gd and any tests/goldens that hardcode selected_action or the previous active icon. Check the Pause visual golden after changing keycaps/help text and check onboarding captures after removing the special body; avoid unrelated pixel changes.

### 5. Verification and review gate

- [ ] Run ./tools/verify-clean.sh from *committed HEAD* (archives HEAD, not the working tree); record GUT totals, headless smokes, audio check.
- [ ] Run ./addons/gdUnit4/runtest.sh -a tests/gdunit -c and -a tests/e2e -c (with local Godot configured), and any relevant specific shell/visual fixtures.
- [ ] Native macOS: run ./tools/verify-visual.sh against approved raw 640×360 production captures; inspect toolbar, Pause-help and tutorial visual diffs, and re-bless only genuinely changed captures. CI must not generate/re-bless goldens.
- [ ] Check clean imports; no persisted/active selected_action field or stale control instructions (historical docs may still refer to old controls); no ACTION_SELECTED code/branch; no pressed action-select controls; schema v3 rejects v2 at decode; no regressions to Day 1/14 and 22:00 cutoff.
- [ ] Run git diff --check, update PR body with exact evidence/limitations, address review comments, mark ready only when implementation and tests land on this same PR.

## Review checkpoints / avoid overengineering

Review resolver/failure-ordering, the **existing codec schema-version rejection**, and the hold lock before writing broad code changes. Keep GameSession the only gameplay state owner, SessionStateValidator the one gameplay-shape validation owner, SaveFileCodec the schema-envelope owner, WorldShell the sole input/hold owner, and GameHud pure presentation. No extra input service, tool selection model, generic action router, save migration, new images/audio, or separate implementation PR.

## Known review risk

Deleting the required selected_action field check permits extra selected_action keys in direct in-memory restore_state() calls, but production Continue first passes through SaveFileCodec.decode(), which rejects every schema-v2 save once v3 is current. No redundant validator branch is needed. Separately, the current _advance_action_hold() relies on a manually selected action becoming ineligible after success. Under automatic resolution the **next** action becomes eligible immediately, so the per-gesture action lock is essential to avoid till-and-plant on one hold.
