# Task 9 report — Phoenix pause and nested settings

Date: 2026-09-06
Worktree: `/Users/chanwaichan/workspace/phoenix/.worktrees/ui-redesign-visual-parity`
Branch: `docs/ui-redesign-visual-parity`

## Implemented

- Replaced the code-built `PauseHelp` surface with authored `PausePanel` scene/script.
- Added authored `SettingsPanel` scene/script at the fixed 640×360 layout from references 10–11.
- Registered both surfaces in `GameHud`'s primary modal and Esc registries.
- Added `open_pause`, `close_pause`, `open_settings`, and `close_settings` to `GameHud`.
- Kept Settings→Pause as one modal transaction so `modal_state_changed` never exposes an unblocked world between nested surfaces.
- Kept `O` handling on Pause only; Settings consumes only W/S/A/D and updates the existing `UiSettings` object.
- Applied audio, tutorial presentation, and window choices through the existing `GameHud.apply_settings()` helpers.
- Rendered the Settings save label from `SaveRepository.DEFAULT_PATH`, independent of environment overrides.
- Added isolated preference mutation/nesting/canonical-label integration tests and a physical-key GdUnit E2E test.
- Registered visual fixture/capture support for states 10–11 without creating or updating goldens.

## Verification

- `rtk git diff --check` — PASS.
- `rtk godot --headless --rendering-method gl_compatibility --path . --editor --quit` — PASS for project/script import; Godot emitted only the existing local editor-settings save warning.
- `rtk godot --headless --rendering-method gl_compatibility --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_gameplay_shell.gd -gexit` — 60/60 passing, 783 assertions.
- `rtk godot --headless --rendering-method gl_compatibility --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_app_launch.gd -gexit` — 9/9 passing, 78 assertions.
- `rtk godot --headless --rendering-method gl_compatibility --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_persistence_flow.gd -gexit` — 9/9 passing, 133 assertions.
- `rtk godot --headless --rendering-method gl_compatibility --path . --check-only --script res://tests/e2e/ui_navigation_test.gd` — PASS.

## TDD evidence

The task brief required focused nesting/canonical-label tests but did not require a separate RED/GREEN transcript. The new tests were added alongside the implementation and pass through the focused integration lanes above.

## Files changed

- `scripts/ui/game_hud.gd`
- `scripts/ui/pause_panel.gd`
- `scripts/ui/settings_panel.gd`
- `scripts/ui/pause_panel.gd.uid`
- `scripts/ui/settings_panel.gd.uid`
- `scenes/ui/pause_panel.tscn`
- `scenes/ui/settings_panel.tscn`
- `tests/integration/test_gameplay_shell.gd`
- `tests/integration/test_app_launch.gd`
- `tests/integration/test_persistence_flow.gd`
- `tests/e2e/ui_navigation_test.gd`
- `tests/e2e/ui_navigation_test.gd.uid`
- `tests/visual/capture_ui_states.gd`
- `tests/visual/compare_ui_states.gd`
- `tests/visual/ui_capture_host.gd`
- `tests/visual/ui_fixture_factory.gd`
- `tools/verify-visual.sh`

## Self-review and concerns

- Existing `PauseHelp` assertions were updated to the authored `PausePanel` node; no gameplay state or second settings authority was introduced.
- Settings tests use a dedicated `user://phoenix-task9-gameplay-settings.cfg` and clean it before/after each test. The AppRoot canonical-label test uses isolated environment paths.
- The real-key E2E test and native visual captures/golden approval were not executed because the coordinator marked the Mac unlock/native gates pending. No fake/headless capture or unapproved golden was created.
- `./tools/verify-clean.sh` remains the final committed-HEAD gate and is run after the implementation commit.
