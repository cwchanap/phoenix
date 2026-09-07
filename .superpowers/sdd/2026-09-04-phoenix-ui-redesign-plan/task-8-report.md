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
registered in the visual fixture/capture/comparer scripts, manually approved on
native macOS, and now have production goldens.

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
- Normal native visual verification was completed in bounded groups:
  `./tools/verify-visual.sh 01-hud 02-seed-shop 03-shipping-day14`,
  `./tools/verify-visual.sh 04-bag 05-almanac 06-calendar`, and
  `./tools/verify-visual.sh 07-dialogue 08-morning-summary 09-sleep`.
  All nine states exited 0 with `golden_missing=false`,
  `max_channel_delta=0`, `differing_pixels=0`, and
  `mismatch_ratio=0.00000000` (01 compared 65,280 pixels; 02–09 each
  compared 230,400 pixels). State 05 emitted the existing ObjectDB/resource
  cleanup warning but still completed with an exact comparison pass.
- Post-approval focused command:
  `godot --headless --path . -s addons/gut/gut_cmdln.gd
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit`.
  Output: `60/60 passed`, `Tests 60`, `Passing Tests 60`, `Asserts 786`,
  `---- All tests passed! ----`; exit 0 in 24.762 seconds. The test-only
  follow-up aligns stale Dialogue expectations with the approved curly quotes
  and uppercase role labels.

## Candidate evidence and gates

The approved native candidate paths are `test_output/ui-visual/07-dialogue.png`,
`08-morning-summary.png`, and `09-sleep.png`, with corresponding `-2x.png`
evidence files. Manual review approved all three after the final authored
spacing correction (including the 07 relationship and quantity bounds). The
approved captures were promoted only to `tests/visual/goldens/07-dialogue.png`,
`08-morning-summary.png`, and `09-sleep.png`; states 01–06 were unchanged.

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

`GOLDENS_07_09_APPROVED_NORMAL_01_09_PASS_FOCUSED_SHELL_60_60_786; NATIVE_E2E_DEFERRED_TO_COMBINED_TASK8_TASK9_RUN`
