# HPA-353 — Session State Validator Extraction Implementation Plan

**Issue:** [HPA-353](https://linear.app/cwchanap/issue/HPA-353/tech-debt-move-save-state-validation-out-of-gamesession)  
**Design:** [2026-10-23-phoenix-session-state-validator-design.md](../specs/2026-10-23-phoenix-session-state-validator-design.md)  
**Delivery:** **one PR** on `agent/hpa-353-session-state-validator-plan`, based on `main` @ `8fe134e2f372ce065ed6d8e935370050970efeeb`. Plan-only draft initially; commit code and tests to the **same PR**, not a second implementation PR.  
**Status:** implemented and verified on this PR — the `SessionStateValidator` extraction, all production/test caller migration, and the generated `.gd.uid` (`94ceb35`), plus the `CLAUDE.md` ownership bullet (`6b4282b`), are committed; every task box below is complete. Review commits `01e50b3`/`af36917` then deliberately reworked the moved code and tests (see **Post-extraction divergence** below), so the pinned-source diff is a historical proof of the `94ceb35` move, not a description of head; current-head correctness is carried by the suites. Verification record: the pinned-source extraction diff was empty at `d54e619`; at head, `./tools/verify-clean.sh` passed (255/255 GUT, all headless smokes, audio check), GdUnit4 `tests/gdunit` passed 12/12, `tests/e2e` passed (`test_day_one_held_row_works_three_cells` flaked once on dwell timing and passed on re-run; CI lanes are green through `af36917`), and `git diff --check` is clean.

## Task 0 — Verify current callers and protect behavior

**Read:** `scripts/game/game_session.gd`, `scripts/app/app_root.gd`, `scripts/persistence/save_file.gd`, `scripts/persistence/save_repository.gd`, current validation/persistence tests and `CLAUDE.md`.

- [x] Before editing, use `rg -n 'GameSession\.state_error|state_error\(|_named_dictionary_value\(' scripts tests` and confirm the current census: **49 test calls in 10 files**, plus the two production calls to `GameSession.state_error` in `GameSession.restore_state()` and `AppRoot._load_title_state()`. Re-enumerate if main changed; never rely solely on the ticket's estimate.
- [x] Check all three non-validator uses of `_named_dictionary_value` in `GameSession`: `restore_state()` tutorial loop (line 308), `_counts_array()` (line 1253), and `_relationship_array()` (line 1280) at the reviewed base. The existing validation helpers also call it. Record unexpected references before editing.
- [x] If the local Godot runtime is available, run the current clean verifier to establish a baseline; record the result. Do not conflate a missing local runtime with a passing test.

**Checkpoint:** exact callers and any pre-existing failures documented; scope is still a pure move.

## Task 1 — Atomic validator extraction and production caller migration

**Files:** `scripts/game/session_state_validator.gd` (new), `scripts/game/game_session.gd`, `scripts/app/app_root.gd`.

Complete **all edits in this task together**, before claiming a parser-clean checkpoint. Deleting the old helpers first would leave both `restore_state()` and the kept array helpers with unresolved references.

- [x] Add `class_name SessionStateValidator` and `extends RefCounted`; move `state_error(candidate: Variant) -> String` and the existing static validation helper implementations into this single stateless script (original blocks around lines 95–284 and 831–1215). Preserve check order, Variant acceptance, exact error messages, and rule/content/world dependencies.
- [x] Make the **one intentional naming change**: move `_named_dictionary_value(map, key, label)` as **public static** `SessionStateValidator.named_dictionary_value(map, key, label)`; preserve its body unchanged and rename all its **internal** validator call sites. No other helper needs renaming.
- [x] In `GameSession.restore_state()`, replace preflight validation with `SessionStateValidator.state_error(candidate)` and its tutorial-key lookup with `SessionStateValidator.named_dictionary_value(candidate["tutorial"], id, ...)`. Keep the existing `{"ok", "value"}` response handling and canonicalization. Do **not** add an inline StringName/String fallback or duplicate helper.
- [x] In `GameSession._counts_array()` and `_relationship_array()`, replace their existing `_named_dictionary_value(...)` uses with `SessionStateValidator.named_dictionary_value(...)`. Preserve current conversion logic and key-selection/error behavior.
- [x] In `AppRoot._load_title_state()`, call `SessionStateValidator.state_error(result["state"])` directly, with the same Continue gate and messages.
- [x] Delete the migrated definitions from `GameSession` entirely. No `GameSession.state_error` forwarding facade, private shadow lookup helper, alternate validator, or save-format change.
- [x] Leave `_counts_array`, `_farm_array`, `_relationship_array`, `_counts_snapshot`, `_relationships_state`, and `_farm_snapshot` in `GameSession`. The new script **must** have a tracked `scripts/game/session_state_validator.gd.uid` sidecar, generated by Godot during Task 2, not invented manually; all 54 existing `.gd` files have checked-in `.gd.uid` files.

**Checkpoint: prove verbatim extraction from the pinned base.** With the validator file ordered as its three-line header (`class_name`, `extends`, blank line), followed by the original `state_error` block (base lines 95–285 — base line 285 is the blank separator after `state_error` and is deliberately carried over as the new file's single blank line between the two moved blocks) then the original static-helper block (base lines 831–1215; base line 1216 is the blank separator after the block and is deliberately not moved, so the new file has no blank line at EOF), run this **Bash/Zsh** process-substitution diff from the repository root:

```bash
diff <(git show 8fe134e2f372ce065ed6d8e935370050970efeeb:scripts/game/game_session.gd |
    sed -n '95,285p;831,1215p' |
    sed 's/_named_dictionary_value(/named_dictionary_value(/g') \
  <(tail -n +4 scripts/game/session_state_validator.gd)
```

It must have **no output and exit 0**: only the approved helper rename and its call sites may differ from the original moved text. This source comparison protects error strings and validation order that the existing fixtures do not assert exhaustively. Do not rewrite an unexpected diff away or expand accepted changes; inspect and preserve original logic. The **full project/test parse** follows Task 2's mechanical test migration, not an intermediate broken state.

This checkpoint held at `d54e619` and is a historical record of the mechanical move only. Review commits `01e50b3`/`af36917` intentionally changed the moved code afterward (see **Post-extraction divergence**), so re-running this diff at head produces output by design — current-head behavior is pinned by the test suites, not by this comparison.

## Task 2 — Mechanical test migration and regression checks

**Files:** all 10 existing test callers of `GameSession.state_error`: `tests/unit/test_game_session.gd` (24), `tests/unit/test_save_file.gd` (2), `tests/integration/test_persistence_flow.gd` (3), `tests/visual/ui_fixture_factory.gd` (11), `tests/integration/test_app_launch.gd` (4), and one each in `tests/e2e/gameplay_day_one_test.gd`, `tests/integration/test_save_repository.gd`, `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_finale_cue.gd`, and `tests/visual/capture_homestead_ambience.gd`.

- [x] Mechanically replace the **49 known** `GameSession.state_error(` test calls with `SessionStateValidator.state_error(` (recount if the branch or base changed). Keep invalid fixture inputs and expected strings as-is; do not relocate tests.
- [x] Preserve coverage for missing/wrong-typed fields, weather history, farm/crop shape, relationships, tutorial, finale, morning summary, watering-can ownership, decoding, canonical restore, Continue, and error priority. Existing suites prove save integration and round-trip behavior; the **Task 1 source diff** proved exact validator text and error precedence at the extraction head `d54e619` — after the review follow-ups, `tests/unit/test_session_state_validator.gd` carries that proof instead.
- [x] Reuse existing key-compatibility coverage **without a new test**: `tests/unit/test_save_file.gd::test_codec_round_trip_restores_canonical_state()` decodes JSON to String-keyed dictionaries and asserts restored canonical state matches the original, exercising tutorial/crop/relationship fallback; direct `state()` → `restore_state()` tests exercise the StringName-keyed path.
- [x] Run `rg -n 'GameSession\.state_error|static func state_error|_named_dictionary_value\(|named_dictionary_value\(' scripts tests`. There must be no stale `GameSession.state_error` usage, no `GameSession` copy of the moved lookup helper, and exactly one `SessionStateValidator.named_dictionary_value` implementation.
- [x] Run `godot --headless --path . --editor --quit` from the checkout **after** all call sites are fixed, then stage the real Godot-generated `scripts/game/session_state_validator.gd.uid` alongside the `.gd` and test changes. The sidecar is mandatory, not conditional; the clean verifier's temporary archive would otherwise hide its absence.
- [x] **Commit Tasks 1 and 2 together in one implementation commit.** Do not commit the validator move alone with 49 unresolved test references. The source diff, generated `.uid`, caller updates and test renames must all be staged before this commit.

**Checkpoint:** after the combined implementation commit, run parser/import and targeted GUT validation/save-codec/persistence tests. All caller renames and the committed `.uid` are present. The source diff proves unchanged error strings; the existing fixtures prove working save/restore flows.

## Task 3 — Architecture documentation and verification

**Files:** `CLAUDE.md` (one architecture bullet). The mandatory `.gd.uid` sidecar was already generated and committed with Tasks 1 and 2.

- [x] Change `CLAUDE.md`'s existing `GameSession.state()/state_error()/restore_state()` ownership bullet to state that `GameSession.state()/restore_state()` own mutable-state export/canonical restore; `SessionStateValidator.state_error()` owns all persisted-state validation; `snapshot()` remains the view read model.
- [x] Run `./tools/verify-clean.sh` **against committed HEAD**, not an uncommitted working tree. This runs Godot import, GUT unit/integration tests and headless smoke checks. Record the actual output or a clear environmental blocker.
- [x] Run existing GdUnit4 suites when available: `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c`. No E2E step updates are expected.
- [x] Run `git diff --check` and a final repository search for stale `GameSession.state_error`; review diff for any save schema, error-string, runtime command, or GUI change.
- [x] Address valid review comments within this same draft PR. Mark ready for review only after implementation and verification evidence are committed.

**Expected implementation diff:** one new validator script **and its committed Godot-generated UID**, deletion of the two validator blocks from `game_session.gd`, direct calls to the shared public key helper at all three `GameSession` sites, state validation calls in `game_session.gd`/`app_root.gd`, **49** mechanical test call renames across **10** files, and the single `CLAUDE.md` architecture bullet. **No** `SaveFileCodec` or `SaveRepository` edits; no new persisted fields, save migration, gameplay tuning, visual golden changes, art or audio work. This describes the `94ceb35` extraction commit; `01e50b3`/`af36917` additionally relocated the validator assertions into `tests/unit/test_session_state_validator.gd` (+`.gd.uid`), rewrote `restore_state()` derive-then-commit, and consolidated the validator helpers — see below.

## Post-extraction divergence (review commits `01e50b3`, `af36917`)

The verbatim-move guarantee above describes the `94ceb35` extraction, proven by the empty pinned-source diff recorded through `d54e619`. Review then drove two commits that deliberately changed the moved code, so the validator at head is **not** byte-identical to the base blocks:

- `01e50b3` consolidated the repeated `_field` + check sequences into shared helpers (`_int_field`, `_named_field`, `_bool_field`, `_dict_field`, `_array_field`, `_non_negative_int_result`/`_non_negative_int_field`/`_non_negative_named_int`), folded the three crop-count dictionaries into one loop, dropped the redundant re-validation of `state["day"]`/`state["money"]` inside `_morning_summary_state_error`, rewrote `GameSession.restore_state()` to build derived state before commit, and relocated the validator assertions from `tests/unit/test_game_session.gd` into the new `tests/unit/test_session_state_validator.gd`.
- `01e50b3` also narrowed acceptance beyond the pure-move spec — `MAX_PERSISTED_VALUE` field caps, an exact top-level key count, and a `shipping_income` vs shipment-lines reconciliation. `af36917` **reverted** all three: base non-negative/integer checks, tolerated unknown top-level fields, and original first-error order (`shipped` after `tutorial`, `finale_triggered` specificity) are restored and pinned by tests.
- **Kept intentional acceptance change — the `_whole_int` int64 bound.** A finite whole float outside `[-2^63, 2^63)` is rejected with `"<label> is out of range"` instead of reaching `int()`, whose out-of-range result is platform-divergent (ARM saturates to `INT64_MAX`, x86 yields `INT64_MIN`). Base accepted such values and stored the divergent cast; head rejects them uniformly on every platform. This is the single deliberate accepted-shape change versus `8fe134e`; `test_state_error_rejects_out_of_int64_range_floats_on_every_platform` pins it.
- Also kept: the `restore_state()` derive-then-commit structure and the validator-test relocation. Neither alters acceptance; restore remains fail-closed after the `state_error` gate, and the redundant farm/relationship shape re-checks added in `01e50b3` were removed again so the helpers stay conversion-only (`state_error` owns all persisted-shape rules).

**Acceptance:** the pinned-source comparison proved the `94ceb35` extraction verbatim at `d54e619` (approved helper rename only); at head, the GUT/GdUnit4/E2E suites prove accepted shapes, check order, and error messages match base, with the `_whole_int` int64-float bound above as the single documented acceptance change. Existing and relocated tests prove valid/invalid saves, Continue behavior, and restore canonicalization still work. The single combined implementation commit includes all migrated callers/tests and the new `.gd.uid`, with the rules living in one stateless `SessionStateValidator`. Do not begin the downstream HPA-264 or HPA-352 scopes in this PR.
