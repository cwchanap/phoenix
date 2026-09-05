# Task 3 report: Add persistent UI settings

## Implemented

- Added `UiSettings`, a small `ConfigFile`-backed `RefCounted` with `ui` keys for music, sound, window scale, and tutorial cards.
- Added exact defaults of `4 / 7 / 2x / true`, clamped 0–10 volume setters, valid window scales `[1, 2, 3, 4, 0]`, safe fallback loading, and `Error`-returning saves.
- Added dB mapping with true level-0 attenuation (`-80.0`) and monotonic audible levels 1–10.
- Added OS window application at `640x360 * scale` or fullscreen without changing the logical viewport.
- Threaded one settings instance from AppRoot through WorldShell to GameHud, applying existing Music/SFX players and onboarding presentation.
- Added `PHOENIX_SETTINGS_PATH` loading for AppRoot while preserving optional existing `configure()` call signatures.
- Tutorial Cards OFF hides only the presentation; intro blocking and `GameSession` tutorial progress remain authoritative and unchanged.
- Added isolated unit coverage and focused AppRoot propagation/environment coverage.

## TDD evidence

### RED

Command:

```text
rtk godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ui_settings.gd -gexit --log-file /private/tmp/phoenix-task3-red.log
```

Before implementation, GUT reported `Identifier "UiSettings" not declared in the current scope` and ran no tests. This was the expected failure for the newly added test against the missing implementation.

### GREEN

Focused commands and results:

```text
rtk godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ui_settings.gd -gexit --log-file /private/tmp/phoenix-task3-unit-final2.log
# 6/6 passed, 35 asserts

rtk godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_app_launch.gd -gexit --log-file /private/tmp/phoenix-task3-app-final.log
# 8/8 passed, 75 asserts

rtk godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_gameplay_shell.gd -gexit --log-file /private/tmp/phoenix-task3-gameplay-green.log
# 40/40 passed, 492 asserts

rtk godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit --log-file /private/tmp/phoenix-task3-full-gut-final.log
# 155/155 passed, 2005 asserts
```

The Godot commands that write `user://` test files required escalated access because the restricted process cannot write Godot's user-data directory; the same restriction reproduced `ERR_FILE_CANT_OPEN` in the existing save tests. Test settings and save paths are isolated and cleaned after each test.

Additional verification:

```text
rtk git diff --check
# passed
```

## Files changed

- `scripts/ui/ui_settings.gd`
- `scripts/ui/ui_settings.gd.uid`
- `scripts/app/app_root.gd`
- `scripts/world/world_shell.gd`
- `scripts/ui/game_hud.gd`
- `scripts/ui/onboarding_overlay.gd`
- `tests/unit/test_ui_settings.gd`
- `tests/unit/test_ui_settings.gd.uid`
- `tests/integration/test_app_launch.gd`

## Self-review

- Existing AppRoot and WorldShell configure callers remain valid because the settings parameter is optional.
- `GameSession` remains the only mutable gameplay authority; settings never enter `state()` or `snapshot()`.
- Direct WorldShell test fixtures use in-memory defaults, while AppRoot alone loads persisted user settings.
- Window application changes only OS mode/size; project viewport settings stay pinned at 640x360.
- No settings panel or new UI subsystem was added; that remains Task 9.

## Concerns

None. Godot's macOS certificate warning and the existing expected assertion traces remain known test-run noise; all tests passed.
