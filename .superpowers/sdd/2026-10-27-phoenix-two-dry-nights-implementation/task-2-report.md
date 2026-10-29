# HPA-352 Task 2 — Farm warning presentation report

## Implementation

- `FarmView.refresh()` now applies `DRY_CROP_TINT` through the crop sprite's `self_modulate` only when its crop has a positive dry-night counter, the day is sunny, and the crop is immature. Every other refresh restores white, including rain, watering, maturity, replanting, removal, and un-tilled soil. The parent sprite's `modulate`, shadows, soil, and readiness sparkle remain unchanged.
- `MorningSummaryPanel` now renders a hidden, right-aligned `WitheredWarning` label beside the section title. Positive counts show singular or plural copy in `UiStyle.RED`; zero hides the line on every call, including after a previous positive count.
- The existing water tutorial body now adds: “Two dry nights in a row and it withers.”
- README's Sleep rules already described withering after two consecutive dry nights in the task-1 base, so no README change was needed.

## Test-first evidence

- Before implementation, `test_dry_crop_tint_tracks_weather_and_crop_state` failed its sunny dry-crop assertions because the sprite stayed white. The pre-implementation summary assertion also found no `Frame/WitheredWarning` node.
- After implementation, the focused crop-view test passed: 1/1 test, 23 assertions. It checks sunny tint, neutral tint during rain while `dry_nights` remains 1, water clearing the counter, the mature-crop guard, unchanged readiness sparkle, and removal/replant reset.
- The focused morning-summary test passed: 1/1 test, 39 assertions. It checks zero, singular, plural, and repeated presentation returning to zero.
- The full affected gameplay-shell integration script passed: 100/100 tests, 1,951 assertions.

## Verification

- `godot --headless --path . --editor --quit` — passed; changed GDScript and scene imported.
- `git diff --check` — passed.
- `./tools/verify-clean.sh` against committed HEAD `1503fc37a5f26151ac29cdab2a01eb72ebf880c0` — passed. The pinned GUT v9.7.1 archive matched the expected SHA-256; all 272 tests and 4,508 assertions passed across 12 scripts. Project smoke, world-math smoke, world-shell smoke, and audio-source checks also passed.
- Native Godot capture at the authored 640×360 viewport was inspected for the water tutorial and a two-crop warning. The tutorial body rendered in two visible lines within its card; the warning stayed in the title row and clear of the shipment row.

## Files and commit

- `scripts/world/farm_view.gd`
- `scripts/ui/morning_summary_panel.gd`
- `scenes/ui/morning_summary_panel.tscn`
- `scripts/game/content_rules.gd`
- `tests/integration/test_gameplay_shell.gd`
- Implementation commit: `1503fc37a5f26151ac29cdab2a01eb72ebf880c0` (`HPA-352 add wither presentation warnings`).

## Remaining checks

- No known behavior limitation. GdUnit4, godot-e2e, release export, and the full visual-golden comparison were not run; the required native layout check used temporary captures, and no goldens were changed.
