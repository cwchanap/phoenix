# HPA-353 — Session State Validator Extraction Implementation Plan

**Issue:** [HPA-353](https://linear.app/cwchanap/issue/HPA-353/tech-debt-move-save-state-validation-out-of-gamesession)  
**Design:** [2026-10-23-phoenix-session-state-validator-design.md](../specs/2026-10-23-phoenix-session-state-validator-design.md)  
**Delivery:** **one PR** on `agent/hpa-353-session-state-validator-plan`, based on `main` @ `8fe134e2f372ce065ed6d8e935370050970efeeb`. Plan-only draft initially; commit code and tests to the **same PR**, not a second implementation PR.  
**Status:** design/planning only. All implementation and test tasks below are pending. Do not report tests as passing until executed.

## Task 0 — Verify current callers and protect behavior

**Read:** `scripts/game/game_session.gd`, `scripts/app/app_root.gd`, `scripts/persistence/save_file.gd`, `scripts/persistence/save_repository.gd`, current validation/persistence tests and `CLAUDE.md`.

- [ ] Before editing, use `rg -n 'GameSession\.state_error|state_error\(|_named_dictionary_value\(' scripts tests` and enumerate all callers, including GUT, GdUnit, E2E and headless code. The Linear ticket estimates about 49 test call sites; use the actual current search result, not that estimate, as the source of truth.
- [ ] Confirm `restore_state()` calls `_named_dictionary_value` outside the validator, and check for any other non-validator uses of the migrated helpers. Record any unexpected use before changing it.
- [ ] If the local Godot runtime is available, run the current clean verifier to establish a baseline; record the result. Do not conflate a missing local runtime with a passing test.

**Checkpoint:** exact callers and any pre-existing failures documented; scope is still a pure move.

## Task 1 — Extract the validator without rewriting rules

**Files:** `scripts/game/session_state_validator.gd` (new), `scripts/game/game_session.gd`.

- [ ] Add `class_name SessionStateValidator`, `extends RefCounted`, then move `state_error(candidate: Variant) -> String` **unchanged** from `GameSession` and all static validation helpers from the original blocks (around lines 95–284 and 831–1216 at base).
- [ ] Preserve every check's order, `Variant` acceptance (including String/StringName and whole-int handling), exact error message, `GameRules`/content/world dependencies and existing method signatures. No helper renames needed inside the new class.
- [ ] Delete the moved definitions from `GameSession`. Do not leave a `GameSession.state_error` forwarding facade, shadow copies, or a second validator.
- [ ] Keep `GameSession`'s static array-construction and snapshot helpers after the moved block: `_counts_array`, `_farm_array`, `_relationship_array`, `_counts_snapshot`, `_relationships_state`, `_farm_snapshot`.
- [ ] Let Godot generate the source-adjacent `session_state_validator.gd.uid` if required by the checked-in UID convention; do not fabricate the UID manually.

**Checkpoint:** GDScript parses; no gameplay commands, save fields, or codec code have changed.

## Task 2 — Repoint the two production callers

**Files:** `scripts/game/game_session.gd`, `scripts/app/app_root.gd`.

- [ ] In `GameSession.restore_state()`, replace the preflight call with `SessionStateValidator.state_error(candidate)`; retain the existing early `false` return and subsequent canonicalization in place.
- [ ] In the same restore method, replace the **single external** `_named_dictionary_value` use for `tutorial` with an inline read of `id` when the Dictionary has that StringName key, otherwise `String(id)`. The validator has already checked its existence and type; preserve both forms. Do not introduce a shared accessor or public validator helper.
- [ ] In `AppRoot._load_title_state()`, call `SessionStateValidator.state_error(result["state"])` directly. Keep the same messaging and Continue gating.

**Checkpoint:** both production entry points use the new owner; no runtime behavior beyond call routing changes.

## Task 3 — Mechanical test migration and regression checks

**Files:** only actual callers of `GameSession.state_error`, especially `tests/unit/test_game_session.gd`, `tests/unit/test_save_file.gd`, and `tests/integration/test_persistence_flow.gd`.

- [ ] Replace `GameSession.state_error(` with `SessionStateValidator.state_error(` at all call sites. Keep exact expected error strings, invalid data, test cases and fixtures unchanged.
- [ ] Preserve coverage for valid state, missing/wrong-typed fields, weather history, farm/crop shape, relationships, tutorial, finale, summary, upgraded watering can, JSON decoding and Continue. Existing tests are the safety net; avoid moving them wholesale to a new file.
- [ ] Add a *minimal* focused assertion only if existing tests fail to prove that restore accepts both StringName and String tutorial keys after the inline read. Add no generic validator test framework.
- [ ] `rg -n 'GameSession\.state_error|static func state_error|_named_dictionary_value\(' scripts tests`: only the new validator should define `state_error`; migrated helpers should live only there. `GameSession` may no longer call private moved helpers.

**Checkpoint:** targeted GUT validation, save codec and persistence tests pass without editing expected messages.

## Task 4 — Architecture documentation and verification

**Files:** `CLAUDE.md` (one architecture bullet), and generated `.gd.uid` only if needed.

- [ ] Change `CLAUDE.md`'s existing `GameSession.state()/state_error()/restore_state()` ownership bullet to state that `GameSession.state()/restore_state()` own mutable-state export/canonical restore; `SessionStateValidator.state_error()` owns all persisted-state validation; `snapshot()` remains the view read model.
- [ ] Run `./tools/verify-clean.sh` **against committed HEAD**, not an uncommitted working tree. This runs Godot import, GUT unit/integration tests and headless smoke checks. Record the actual output or a clear environmental blocker.
- [ ] Run existing GdUnit4 suites when available: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c`. No E2E step updates are expected.
- [ ] Run `git diff --check` and a final repository search for stale `GameSession.state_error`; review diff for any save schema, error-string, runtime command, or GUI change.
- [ ] Address valid review comments within this same draft PR. Mark ready for review only after implementation and verification evidence are committed.

**Expected implementation diff:** one new validator script (+ generated UID if Godot produces it), deletion of the two validator blocks from `game_session.gd`, small call/restore edits in `game_session.gd` and `app_root.gd`, mechanical test call renames where present, and the single `CLAUDE.md` architecture bullet. **No** `SaveFileCodec` or `SaveRepository` edits; no new persisted fields, save migration, gameplay tuning, visual golden changes, art or audio work.

**Acceptance:** the validated game state, errors, Continue decision, restore canonicalization, tests and shipped behavior are byte-for-byte/logically the same as before extraction, while the validation rules live in one stateless `SessionStateValidator`. Do not begin the downstream HPA-264 or HPA-352 scopes in this PR.
