# Task 2 report: Persist weather history and bump save schema

## Implemented

- Added `GameSession._weather_history`, initialized to Day 1 `sunny`.
- Exposed ordered `weather_history` in both `state()` and `snapshot()` with independent deep-copy behavior.
- Added strict validation for one entry per day, valid `GameRules.WEATHER_KEYS` entries, and a final entry matching current `weather`.
- Canonicalized restored history entries through `GameRules.WEATHER_KEYS` and appended the next weather exactly once during successful overnight advancement.
- Bumped `SaveFileCodec.SCHEMA_VERSION` from 1 to 2; schema 1 remains unsupported with the existing `Unsupported save schema` error.
- Added unit and persistence coverage, including sunny-to-rainy save/load and updated Day-14 seed fixtures to satisfy the new invariant.

## TDD evidence

### RED

Command:

```text
rtk godot --headless --path . --log-file /private/tmp/phoenix-task2-red.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
```

Before implementation, the new history tests failed because `state()`/`snapshot()` had no `weather_history`; invariant checks returned an empty error; and the starter snapshot remained 18 fields instead of 19. Result: 46/53 passed, 7 failed.

### GREEN

Focused commands and results:

```text
rtk godot --headless --path . --log-file /private/tmp/phoenix-task2-session-final.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
# 53/53 passed, 919 asserts

rtk godot --headless --path . --log-file /private/tmp/phoenix-task2-save-green.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_file.gd -gexit
# 3/3 passed, 38 asserts

rtk godot --headless --path . --log-file /private/tmp/phoenix-task2-flow-green-escalated.log -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_persistence_flow.gd -gexit
# 9/9 passed, 133 asserts
```

The persistence command required escalated access because the sandbox denied Godot's `user://` save directory; the same suite reproduced `ERR_FILE_CANT_OPEN` without that access.

Full GUT verification before the final commit:

```text
rtk godot --headless --path . --log-file /private/tmp/phoenix-task2-full-gut.log -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
# 147/147 passed, 1945 asserts
```

`rtk git diff --check` passed.

## Files changed

- `scripts/game/game_session.gd`
- `scripts/persistence/save_file.gd`
- `tests/unit/test_game_session.gd`
- `tests/unit/test_save_file.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/integration/test_app_launch.gd`
- `tests/integration/test_finale_cue.gd`

The last two integration files and the persistence flow's existing Day-14 helper only received the required 14-entry history seed so strict restore validation remains valid.

## Self-review

- History mutation is confined to `GameSession`; no rules or second state holder were introduced.
- Failed sleep paths do not roll or append history because validation and pending-summary guards return before the overnight mutation block.
- Day 14 finale paths do not append history because they return before weather generation.
- Save JSON remains transport-only; canonical type restoration stays in `GameSession.restore_state()`.
- No unrelated production or UI files changed.

## Concerns

None. Godot's macOS certificate warning and expected assertion traces remain existing test-run noise; all assertions passed.
