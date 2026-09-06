# Task 8 report

## Implementation

Task 8 moves Dialogue, Morning Summary, and Sleep presentation into authored
fixed-coordinate scenes registered by `GameHud`. The existing request signals,
snapshot flow, primary-modal exclusivity, close-friend sequence lock, gift
round-trip behavior, empty incoming gift lines, and authoritative `_open_modal`
guard remain intact. `DialoguePanel` now uses authored portrait/header/gift
cards/footer nodes; `MorningSummaryPanel` renders the existing summary payload;
`SleepPanel` owns only the existing sleep request and Day 14 warning.

The presentation pass uses the semantic growth and money-bag icons, a compact
relationship badge, bordered gift/key controls, selected-gift tinting, authored
footer keycaps, the approved Day 14 warning copy, and the reference spacing.
Existing states 01–06 and their goldens were left untouched. States 07–09 are
registered in the visual fixture/capture/comparer scripts but no new golden was
created before native review approval.

## Verification

- Focused `test_gameplay_shell.gd`: 55/55 tests, 728 assertions.
- Godot editor import/quit probe passed; existing macOS certificate and editor
  settings diagnostics remain.
- `./tools/bootstrap-gdunit.sh` could not download its addon because the
  sandbox could not resolve `github.com`.
- The gdUnit E2E lane was attempted but the native Mac was locked; the process
  stalled before launch and was stopped. The native visual capture runner was
  also blocked: headless mode has no viewport texture and native display waits
  for `frame_post_draw` while the Mac is locked.

## Candidate evidence and gates

The pre-existing candidate paths are `test_output/ui-visual/07-dialogue.png`,
`08-morning-summary.png`, and `09-sleep.png`, with corresponding `-2x.png`
evidence files. They predate the final authored-spacing corrections and must
be recaptured and manually approved on an unlocked native macOS session before
the three production goldens are created. No existing golden changed.

## Files changed

- `scenes/ui/dialogue_panel.tscn`
- `scenes/ui/morning_summary_panel.tscn`
- `scenes/ui/sleep_panel.tscn`
- `scripts/ui/dialogue_panel.gd`
- `scripts/ui/morning_summary_panel.gd`
- `scripts/ui/sleep_panel.gd`
- `scripts/ui/game_hud.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/visual/{ui_fixture_factory,ui_capture_host,capture_ui_states,compare_ui_states}.gd`
- `tools/verify-visual.sh`

## Status

`IMPLEMENTED_WITH_NATIVE_REVIEW_AND_E2E_PENDING`
