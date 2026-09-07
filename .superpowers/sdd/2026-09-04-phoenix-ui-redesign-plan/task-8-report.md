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

Fix round 1 keeps the single-crop morning layout and adds two authored compact
shipment rows for mixed payouts, binds dialogue portraits to Mira, Rowan, and
June, and hides the complete sleep warning box until Day 14. Fix round 2
replaces the mixed-payout runtime geometry rewrite with three authored compact
rows, preserving the original single-crop, money, and footer coordinates while
keeping the compact rows and footer inside the frame. Existing E2E node paths
remain valid; the Day 1 flow does not reach mixed payouts or villager portraits.

## Verification

- Focused command `godot --headless --path . -s addons/gut/gut_cmdln.gd
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit` after fix round
  2: 57/57 tests, 753 assertions. Coverage includes all three mixed shipment
  lines and an authored frame-containment/coordinate assertion.
- Committed-HEAD `./tools/verify-clean.sh` before this fix round: GUT 172/172,
  2,246 assertions, editor/import probe, and all three headless smokes passed.
- The existing gdUnit4 addon was present; no bootstrap was needed for this fix.
- E2E selectors were audited and require no changes. A bounded native E2E run
  produced only macOS LaunchServices/XPC errors while the Mac was locked and
  was stopped after 60 seconds; no E2E pass is claimed.

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

`FIX_ROUND_2_IMPLEMENTED_WITH_NATIVE_REVIEW_AND_E2E_PENDING`
