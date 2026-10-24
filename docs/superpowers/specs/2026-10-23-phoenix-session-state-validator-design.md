# HPA-353 — Session State Validator Extraction Design

**Linear:** [HPA-353](https://linear.app/cwchanap/issue/HPA-353/tech-debt-move-save-state-validation-out-of-gamesession)  
**Delivery:** one draft-then-implementation PR on `agent/hpa-353-session-state-validator-plan`; design and plan first, runtime extraction and verification later **on the same PR**.  
**Base reviewed:** `main` @ `8fe134e2f372ce065ed6d8e935370050970efeeb` (2026-10-23).  
**Downstream:** [HPA-264](https://linear.app/cwchanap/issue/HPA-264/gameplay-polish-make-space-pick-the-farming-action-from-the-target) removes `selected_action`; [HPA-352](https://linear.app/cwchanap/issue/HPA-352/daily-pacing-wither-crops-left-dry-for-two-nights) adds crop/summary fields. Neither belongs in this PR.

## Problem and existing seams

`scripts/game/game_session.gd` is 1,328 lines at the reviewed base. Persisted-state validation occupies two disconnected blocks: `static func state_error(candidate: Variant) -> String` (lines 95–284) and its static validators (`_field` through `_morning_summary_state_error`, lines 831–1216). This makes changes to gameplay and state restoration harder to navigate.

- `GameSession.state()` exports the save model; `snapshot()` supplies the view read model; `restore_state(candidate: Dictionary) -> bool` validates before mutating and then canonicalizes restored dictionaries/keys.
- `AppRoot._load_title_state()` at `scripts/app/app_root.gd:41` calls `GameSession.state_error(result["state"])` to determine whether Continue is enabled.
- `SaveFileCodec` handles schema-2 JSON transport, **not gameplay schema validation**; `SaveRepository` owns storage.
- There are **49 `GameSession.state_error(...)` test calls across 10 files** at this base: `tests/unit/test_game_session.gd` (24), `tests/unit/test_save_file.gd` (2), `tests/integration/test_persistence_flow.gd` (3), `tests/visual/ui_fixture_factory.gd` (11), `tests/integration/test_app_launch.gd` (4), plus one each in `tests/e2e/gameplay_day_one_test.gd`, `tests/integration/test_save_repository.gd`, `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_finale_cue.gd`, and `tests/visual/capture_homestead_ambience.gd`. These cover malformed values, typed keys, canonical restore, Continue, finale, farm state, summary and saved fields.

## Decision: one stateless owner, no compatibility layer

Create `scripts/game/session_state_validator.gd`:

```gdscript
class_name SessionStateValidator
extends RefCounted

static func state_error(candidate: Variant) -> String:
    # Move the existing implementation verbatim.
    ...
```

Move the complete existing `state_error()` and only the static **validator** helpers `_field`, `_dictionary`, `_array`, `_whole_int`, `_named`, `named_dictionary_value` (renamed from `_named_dictionary_value`), `_counts_state_error`, `_tutorial_state_error`, `_finale_state_error`, `_farm_state_error`, `_relationship_state_error`, and `_morning_summary_state_error` into this class. Preserve method bodies except for the **single helper rename** (`_named_dictionary_value` → public static `named_dictionary_value`) and its call sites; preserve ordering, first-error-wins semantics, accepted Variant shapes, numeric boundaries, and **every existing error message verbatim**. Dependencies on existing `GameRules`, `ContentRules`, `VillagerRules`, and `WorldContract` stay as they are.

**No wrapper:** delete `GameSession.state_error()` and all migrated helpers from `GameSession`. Production callers use `SessionStateValidator.state_error(candidate)` directly:
- `GameSession.restore_state()`: validate before any mutation, return `false` on invalid input.
- `AppRoot._load_title_state()`: preserve the current incompatible-save message/Continue behavior.
- Tests: mechanically replace all `GameSession.state_error(...)` calls with `SessionStateValidator.state_error(...)` across the repository without rewriting their expected assertions.

**Three cross-boundary helper call sites:** In addition to its uses inside validation, `_named_dictionary_value` is called by `GameSession.restore_state()` for tutorial keys (original line 308), `_counts_array()` for crop keys (original line 1253), and `_relationship_array()` for villager keys (original line 1280). Move **one** implementation to `SessionStateValidator` as `static func named_dictionary_value(map: Dictionary, key: StringName, label: String) -> Dictionary` (remove only the leading underscore) and update its internal validator calls plus **all three** `GameSession` callers to `SessionStateValidator.named_dictionary_value(...)`. The helper stays byte-for-byte identical internally, including the StringName-first/String-fallback precedence and missing-key errors. Keep no local helper or duplicate lookup in `GameSession`; this public helper is the sole intentional exception to keeping other validator internals private.

Keep the **non-validator** state transformation helpers `_counts_array`, `_farm_array`, `_relationship_array`, `_counts_snapshot`, `_relationships_state`, and `_farm_snapshot` in `GameSession`. They construct runtime/snapshot state, not validate external input.

## Compatibility and behavioral invariants

This is a source-level refactor, not a change in saved data. The current schema-2 persisted state, field order/required fields, String/StringName acceptance, rejection behavior, and messages remain unchanged. Valid saves must still enable Continue and restore to identical canonical state. Invalid saves must still disable Continue and be rejected without partial mutation. No save migration, version increment, extra validation pass, or alternate state authority.

`GameSession` remains the **sole mutable gameplay authority**. The validator creates no instance state, nodes, service, repository, gameplay commands or schema DSL. `AppRoot` and `GameSession` share the single static validator, with no delegation through `GameSession`.

## Acceptance and scope guard

1. For all existing valid fixture states, `SessionStateValidator.state_error(state) == ""`. For every existing malformed-state fixture, preserve the exact returned message and error precedence.
2. `GameSession.restore_state()` returns `false` for invalid data without changing the active session; for valid data, its canonical `state()` and isolation behavior are unchanged, including tutorial, crop-count, and relationship dictionaries with String or StringName keys.
3. `AppRoot` displays the same incompatible-save/Continue state. Existing save codec and persistence round-trip tests still pass.
4. Repository search finds **no remaining** `GameSession.state_error` references or `GameSession` definitions of moved validator helpers; all three `GameSession` key-lookup sites use `SessionStateValidator.named_dictionary_value`. Mechanically update the 49 known test calls across 10 files. Existing unit/integration/headless/GdUnit/E2E gates run, with no expected visual golden changes.
5. Update the one obsolete `CLAUDE.md` architecture bullet: `GameSession.state()/restore_state()` own export and canonical restore; `SessionStateValidator.state_error()` owns persisted-state validation; `snapshot()` remains the view read model.

**Non-goals:** HPA-264 controls/save-field removal, HPA-352 withering/save-field additions, HPA-351 tuning, save-format updates, transport validation in `SaveFileCodec`, reorganizing other `GameSession` methods, new validation abstractions, test-suite rewrites, and any new art/SFX.

**Implementation details and checkpoints:** [HPA-353 implementation plan](../plans/2026-10-23-phoenix-session-state-validator-implementation.md).
