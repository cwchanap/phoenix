# HPA-264 — Target-Driven Farming Implementation Plan

**Linear:** https://linear.app/cwchanap/issue/HPA-264/gameplay-polish-make-space-pick-the-farming-action-from-the-target  
**Design:** [Target-driven farming design](../specs/2026-10-25-phoenix-target-driven-farming-design.md)  
**Delivery rule:** *one ticket, one PR*. Continue implementation and code review on agent/hpa-264-target-driven-farming-plan; never open a follow-up implementation PR.  
**Current state:** plan only; steps below are not checked off.

## Implementation sequence (in this same PR)

### 0. Verify baseline and references

- [ ] Reconfirm latest main/PR head and no new competing HPA-264 PR before touching runtime files.
- [ ] Run baseline ./tools/verify-clean.sh and relevant GdUnit4 suites on committed HEAD; note any pre-existing failures. Check current usages of `selected_action`, `ACTION_KEYS`/`action_key`, `ACTION_SELECTED`, `select_action_requested`, `select_action_slot`, `use_selected_action`, `preview_selected_action`, `apply_selected_action`, Action_*, controls, schema literals and state shape across source/tests/visual fixtures, **including string-based E2E call_method() sites**.
- [ ] Keep the finished HPA-353 SessionStateValidator ownership boundary; do not reintroduce GameSession.state_error().

### 1. RED: pin domain behavior and saved shape

- [ ] Extend tests/unit/test_game_session.gd with a four-row state-to-action table (untilled → Hoe, tilled empty → Seeds, immature → Water, mature → Hands) and actual command result matching preview on each.
- [ ] Cover missing/nonfarm target, empty selected seed, rain, already-watered, stamina/time cutoff and Efficient Can 1-stamina Water. Preserve early active-day/finale precedence and cost/crop preview assertions.
- [ ] Update the exact snapshot keys/count expectation (one key removed), no selected_action in state(), seed still persisted, and ensure preview cannot mutate state.
- [ ] Cover save incompatibility at the **existing codec boundary**: schema-v3 save round-trips and v2 (plus future/wrong versions) returns `Unsupported save schema`. Re-pin `tests/unit/test_save_file.gd`, `tests/integration/test_app_launch.gd:377` **and `tests/unit/test_game_session.gd:276`**. Rename the `test_schema_2_transport_...` test. Construct codec test envelopes with `SaveFileCodec.SCHEMA_VERSION` (current version for invalid state/vector/type-marker branches, -1 for legacy, +1 for future); assert branch-specific errors so wrong-schema rejection cannot falsely pass marker tests. Keep validator tests for required selected_seed and atomic failed restore; no bespoke retired-field matrix.
- [ ] Confirm these new expectations fail appropriately before changing runtime.

### 2. GREEN: one resolver, no selected tool state

- [ ] In `scripts/game/game_session.gd` introduce `_action_for_target()` based solely on the authoritative tile. Rename `preview_selected_action()` and `apply_selected_action()` to **`preview_target_action()` / `apply_target_action()`** and route both through the one resolver; retain per-action failures/mutations and `_cost_for()` unchanged. Rename all production/test call sites with no wrappers or compatibility shims.
- [ ] Remove _selected_action and select_action(), state()/snapshot()/restore_state() references, and the now-obsolete selection switch. Do not duplicate action choice between preview and mutation. Return a nonfarm preview with null action and existing error codes; preserve preview four-key shape.
- [ ] Delete unreachable `GameRules.CommandCode.ACTION_SELECTED`, `GameRules.ACTION_KEYS` and `GameRules.action_key()`, the dead HUD feedback/SFX arm, and all assertions/references including `tests/unit/test_game_rules.gd:14,47`, `tests/unit/test_content_rules.gd:55`, `tests/unit/test_game_session.gd`, and `tests/integration/test_gameplay_shell.gd`. Keep the FarmingAction enum, `SEED_SELECTED`, and its ACTION_SFX mapping.
- [ ] In scripts/game/session_state_validator.gd delete the selected_action required-field block only; do **not** add a retired-key rejection branch or a strict-key schema. Bump SaveFileCodec.SCHEMA_VERSION 2→3 in scripts/persistence/save_file.gd while keeping the envelope/codec behavior otherwise unchanged. The production loader must reject v2 envelopes before state validation; internal raw dictionaries are outside this codec-version gate.
- [ ] **Land steps 2 and 3 together in one coherent implementation commit** (the intermediate state would leave `WorldShell` / `GameHud` calling removed session fields/methods and fail the project parser). Then run focused GUT session/validator/shell tests; correct any mismatched success/failure precedence. The RED tests may be prepared separately, but do not commit a half-repointed production tree.

### 3. GREEN: WorldShell controls, hold and HUD

- [ ] In `scripts/world/world_shell.gd` remove old select-action signals and 1/3/4 dispatch, delete the one-arm `select_action_slot(slot: int)` API and replace with **`cycle_seed()`** (every key 2 press advances the selected seed). Keep `select_seed(kind)` for seed buttons; migrate every call site/test.
- [ ] Add nullable `_action_hold_action`: on a fresh Space press over a farm tile, bind its resolved action **before** the first dispatch (even if blocked); when a hold starts off-farm, leave it unbound until the **first farm tile targeted**, then bind that resolved action lazily (do not wait for a successful action). Require the existing dwell/success gate **and** matching `preview.action` for subsequent work. Preserve existing walk-in sweep, forbid Hoe→Plant crossover, reset in `_cancel_action_hold()` on release/seed changes/modal or focus gate. Rename `use_selected_action()` / `_attempt_selected_action()` to **`use_target_action()` / `_attempt_target_action()`**; update E2E `call_method(WORLD, "use_selected_action")` string literally to `use_target_action`.
- [ ] In `scripts/ui/game_hud.gd` remove action selection requests, make Action_0..3 read-only indicators without disabled/dimmed presentation, add `set_target_action(action: Variant)` with change check (compare enum ints directly; no `ACTION_KEYS` lookup), and keep seed buttons usable. Update highlight from WorldShell's already-computed preview; avoid per-frame whole-HUD renders. `render()` still owns seed count, active seed badge, Efficient Can texture and other state. Adjust styling loops currently calling `get_node("Key")` / `get_node("Keycap")` on **every** action button once obsolete keycap children are deleted.
- [ ] Update `scenes/ui/game_hud.tscn` nodes **Hotbar/TillLabel** (`TILL`→`WORK`) and **Hotbar/TillIcon** (remove stale Hoe icon or reuse existing neutral asset, no new art), plus `Action_0`, `Action_2`, `Action_3` child **Key/Keycap** (remove 1/3/4); retain the `Action_1` key 2 and `2 CYCLES SEED` hint. Update `scenes/ui/pause_panel.tscn`: leave only the 2 keycap, update "Hoe · Seeds · Water · Hands" to seed cycling, change "Use the selected action" to target-driven Space text, and use existing icons. Remove select_hoe, select_water, select_hands from `project.godot` (retain physical key 2). Keep four action icons for visual continuity.
- [ ] Update `ContentRules.TUTORIALS` text while keeping IDs/completion codes; use a **short `farm_basics` body** (e.g. `Face a farm diamond. Green means ready; red means blocked. Press Space to till.` — 79 characters) so the tutorial card layout still fits after removing the `scripts/ui/onboarding_overlay.gd` hardcoded override. Update `README.md` and `CLAUDE.md` controls, hold-to-work explanation and schema-v2 mentions to v3. `AGENTS.md` is a **symlink to CLAUDE.md**; do not edit or commit it as a separate file.

### 4. Integration and real-input regression proof

- [ ] Update tests/integration/test_gameplay_shell.gd: action selection assertions become resolved-target indicator assertions; verify auto till→plant→water→harvest on one target, proper tool effects, truthful red hints for already watered/rain/no seeds, context E hints and 2 cycling.
- [ ] Replace old assumptions that 'after Hoe the tile is red until selecting Seeds': the preview should become green for planting. Mature-crop readiness test should still show sparkle and now report valid Harvest automatically. Keep modal gating and native controls tests.
- [ ] Add deterministic hold-gesture integration coverage: a three-cell Hoe hold **never** auto-plants on the same held press; seed change cancels; subsequent fresh gestures plant/water. Also start Space on a **non-farm** tile, enter a farm tile while holding, and verify the lock binds the first encountered farm action without crossing to Plant; test an initially blocked farm tile locks its resolved action.
- [ ] Rewrite `tests/e2e/gameplay_day_one_test.gd`'s button-click helper and held-row test to use target-driven Space, release between passes, and assert only 3 tills before the first release. Update **string-based** `call_method(WORLD, "use_selected_action")` to `use_target_action`; keep actual input movement, target values, stamina and save isolation.
- [ ] Update tests/headless/world_shell_smoke.gd physical-key mappings: 2 remains, 1/3/4 mappings no longer exist.
- [ ] Remove `selected_action` from `tests/visual/ui_fixture_factory.gd`; after `_hud.render(_state)` add **`_hud.set_target_action(GameRules.FarmingAction.HOE)`** in `tests/visual/ui_capture_host.gd` near `set_interaction_hint("E SHOP")` so the single HUD golden exercises the transient indicator. Expect only `01-hud` (toolbar and tutorial) and `10-pause` (keycaps/help) to change; treat any other golden diff as a regression, not something to bless.

### 5. Verification and review gate

- [ ] Run ./tools/verify-clean.sh from *committed HEAD* (archives HEAD, not the working tree); record GUT totals, headless smokes, audio check.
- [ ] Run ./addons/gdUnit4/runtest.sh -a tests/gdunit -c and -a tests/e2e -c (with local Godot configured), and any relevant specific shell/visual fixtures.
- [ ] Native macOS: run `./tools/verify-visual.sh --report-only` across the 14 approved raw 640×360 production states, inspect all diffs. Only **`01-hud` and `10-pause`** are expected to change; if accurate and approved, use `./tools/verify-visual.sh --update-goldens 01-hud 10-pause` on macOS. Treat changes to any other golden (including `12-intro`) as regressions. CI must not re-bless goldens.
- [ ] Check clean imports; no persisted/active `selected_action` field, `ACTION_KEYS`/`action_key`, or obsolete `*_selected_action` APIs (historical docs may still use old terms); no `ACTION_SELECTED` branch or pressed action-select controls; no stale tool legends or keycaps; schema v3 rejects v2 at decode; no regressions to Day 1/14 and 22:00 cutoff.
- [ ] Run git diff --check, update PR body with exact evidence/limitations, address review comments, mark ready only when implementation and tests land on this same PR.

## Review checkpoints / avoid overengineering

Review resolver/failure-ordering, the **existing codec schema-version rejection**, lazy lock-on-first-farm-target behavior, and the visual fixture's transient indicator before writing broad code changes. Keep GameSession the only gameplay state owner, SessionStateValidator the one gameplay-shape validation owner, SaveFileCodec the schema-envelope owner, WorldShell the sole input/hold owner, and GameHud pure presentation. **Commit the session + shell/HUD production repoint atomically**, because standalone step-2 would not parse after removing selected-action APIs. No extra input service, tool selection model, generic action router, save migration, new images/audio, or separate implementation PR.

## Known review risk

Deleting the required selected_action field check permits extra selected_action keys in direct in-memory restore_state() calls, but production Continue first passes through SaveFileCodec.decode(), which rejects every schema-v2 save once v3 is current. No redundant validator branch is needed. Separately, the current _advance_action_hold() relies on a manually selected action becoming ineligible after success. Under automatic resolution the **next** action becomes eligible immediately, so the per-gesture action lock is essential to avoid till-and-plant on one hold.
