# HPA-353 — Session State Validator Extraction Implementation Plan

**Issue:** [HPA-353](https://linear.app/cwchanap/issue/HPA-353/tech-debt-move-save-state-validation-out-of-gamesession)  
**Design:** [2026-10-23-phoenix-session-state-validator-design.md](../specs/2026-10-23-phoenix-session-state-validator-design.md)  
**Delivery:** **one PR** on `agent/hpa-353-session-state-validator-plan`, based on `main` @ `8fe134e2f372ce065ed6d8e935370050970efeeb`. Plan-only draft initially; commit code and tests to the **same PR**, not a second implementation PR.  
**Status:** design/planning only. All implementation and test tasks below are pending. Do not report tests as passing until executed.

## Task 0 — Verify current callers and protect behavior

**Read:** `scripts/game/game_session.gd`, `scripts/app/app_root.gd`, `scripts/persistence/save_file.gd`, `scripts/persistence/save_repository.gd`, current validation/persistence tests and `CLAUDE.md`.

- [ ] Before editing, use `rg -n 'GameSession\.state_error|state_error\(|_named_dictionary_value\(' scripts tests` and confirm the current census: **49 test calls in 10 files**, plus the two production calls to `GameSession.state_error` in `GameSession.restore_state()` and `AppRoot._load_title_state()`. Re-enumerate if main changed; never rely solely on the ticket's estimate.
- [ ] Check all three non-validator uses of `_named_dictionary_value` in `GameSession`: `restore_state()` tutorial loop (line 308), `_counts_array()` (line 1253), and `_relationship_array()` (line 1280) at the reviewed base. The existing validation helpers also call it. Record unexpected references before editing.
- [ ] If the local Godot runtime is available, run the current clean verifier to establish a baseline; record the result. Do not conflate a missing local runtime with a passing test.

**Checkpoint:** exact callers and any pre-existing failures documented; scope is still a pure move.

## Task 1 — Atomic validator extraction and production caller migration

**Files:** `scripts/game/session_state_validator.gd` (new), `scripts/game/game_session.gd`, `scripts/app/app_root.gd`.

Complete **all edits in this task together**, before claiming a parser-clean checkpoint. Deleting the old helpers first would leave both `restore_state()` and the kept array helpers with unresolved references.

- [ ] Add `class_name SessionStateValidator` and `extends RefCounted`; move `state_error(candidate: Variant) -> String` and the existing static validation helper implementations into this single stateless script (original blocks around lines 95–284 and 831–1216). Preserve check order, Variant acceptance, exact error messages, and rule/content/world dependencies.
- [ ] Make the **one intentional naming change**: move `_named_dictionary_value(map, key, label)` as **public static** `SessionStateValidator.named_dictionary_value(map, key, label)`; preserve its body unchanged and rename all its **internal** validator call sites. No other helper needs renaming.
- [ ] In `GameSession.restore_state()`, replace preflight validation with `SessionStateValidator.state_error(candidate)` and its tutorial-key lookup with `SessionStateValidator.named_dictionary_value(candidate["tutorial"], id, ...)`. Keep the existing `{"ok", "value"}` response handling and canonicalization. Do **not** add an inline StringName/String fallback or duplicate helper.
- [ ] In `GameSession._counts_array()` and `_relationship_array()`, replace their existing `_named_dictionary_value(...)` uses with `SessionStateValidator.named_dictionary_value(...)`. Preserve current conversion logic and key-selection/error behavior.
- [ ] In `AppRoot._load_title_state()`, call `SessionStateValidator.state_error(result["state"])` directly, with the same Continue gate and messages.
- [ ] Delete the migrated definitions from `GameSession` entirely. No `GameSession.state_error` forwarding facade, private shadow lookup helper, alternate validator, or save-format change.
- [ ] Leave `_counts_array`, `_farm_array`, `_relationship_array`, `_counts_snapshot`, `_relationships_state`, and `_farm_snapshot` in `GameSession`. Generate a source-adjacent `session_state_validator.gd.uid` using Godot if needed, never by fabricating one.

**Checkpoint:** production callers and all three key lookups have been repointed together; the production sources have no unresolved references to removed helpers. The **full project/test parse** and CI check happen **after Task 2's mechanical test migration**—not at an intermediate broken state.

## Task 2 — Mechanical test migration and regression checks

**Files:** all 10 existing test callers of `GameSession.state_error`: `tests/unit/test_game_session.gd` (24), `tests/unit/test_save_file.gd` (2), `tests/integration/test_persistence_flow.gd` (3), `tests/visual/ui_fixture_factory.gd` (11), `tests/integration/test_app_launch.gd` (4), and one each in `tests/e2e/gameplay_day_one_test.gd`, `tests/integration/test_save_repository.gd`, `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_finale_cue.gd`, and `tests/visual/capture_homestead_ambience.gd`.

- [ ] Mechanically replace the **49 known** `GameSession.state_error(` test calls with `SessionStateValidator.state_error(` (recount if the branch or base changed). Keep invalid fixture inputs and expected strings as-is; do not relocate tests.
- [ ] Preserve coverage for missing/wrong-typed fields, weather history, farm/crop shape, relationships, tutorial, finale, morning summary, watering-can ownership, decoding, canonical restore, Continue, and error priority. The existing suites are the safety net.
- [ ] Add a single focused test only if existing tests do not prove that canonical restore still accepts both StringName and String dictionary keys for tutorial, crop counts and relationships. Do not build a generic validator test framework.
- [ ] Run `rg -n 'GameSession\.state_error|static func state_error|_named_dictionary_value\(|named_dictionary_value\(' scripts tests`. There must be no stale `GameSession.state_error` usage, no `GameSession` copy of the moved lookup helper, and exactly one `SessionStateValidator.named_dictionary_value` implementation.

**Checkpoint:** **now** run the parser/import and targeted GUT validation/save-codec/persistence tests. All test and production call-site renames are complete, and the original error strings remain asserted.

## Task 3 — Architecture documentation and verification

**Files:** `CLAUDE.md` (one architecture bullet), and generated `.gd.uid` only if needed.

- [ ] Change `CLAUDE.md`'s existing `GameSession.state()/state_error()/restore_state()` ownership bullet to state that `GameSession.state()/restore_state()` own mutable-state export/canonical restore; `SessionStateValidator.state_error()` owns all persisted-state validation; `snapshot()` remains the view read model.
- [ ] Run `./tools/verify-clean.sh` **against committed HEAD**, not an uncommitted working tree. This runs Godot import, GUT unit/integration tests and headless smoke checks. Record the actual output or a clear environmental blocker.
- [ ] Run existing GdUnit4 suites when available: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c`. No E2E step updates are expected.
- [ ] Run `git diff --check` and a final repository search for stale `GameSession.state_error`; review diff for any save schema, error-string, runtime command, or GUI change.
- [ ] Address valid review comments within this same draft PR. Mark ready for review only after implementation and verification evidence are committed.

**Expected implementation diff:** one new validator script (+ generated UID if Godot produces it), deletion of the two validator blocks from `game_session.gd`, direct calls to the shared public key helper at all three `GameSession` sites, state validation calls in `game_session.gd`/`app_root.gd`, **49** mechanical test call renames across **10** files, and the single `CLAUDE.md` architecture bullet. **No** `SaveFileCodec` or `SaveRepository` edits; no new persisted fields, save migration, gameplay tuning, visual golden changes, art or audio work.

**Acceptance:** the validated game state, errors, Continue decision, restore canonicalization, tests and shipped behavior are byte-for-byte/logically the same as before extraction, while the validation rules live in one stateless `SessionStateValidator`. Do not begin the downstream HPA-264 or HPA-352 scopes in this PR.
