# Task 6 report

## Implementation

Task 6 adds authored Shop and Shipping panels under `GameHud` while keeping
the existing request signals and `GameSession` snapshot ownership intact.
Each panel owns its row selection and quantity presentation plus W/S/A/D/M/
Enter input. `GameHud` remains responsible for Esc routing, modal registration,
HUD chrome visibility, and forwarding buy/deposit requests. Opening a primary
modal hides the onboarding tutorial card and restores it with the HUD chrome
when the modal closes; the real dialogue close path also restores the chrome.

The visual host now restores every validated fixture through a short-lived
`GameSession` and passes the resulting `snapshot()` to the real HUD. State 02
and State 03 use the existing capture path, farm/shipping plates, raw 640x360
captures, nearest 1280x720 evidence, and full-frame comparison scope. The
state-01 HUD golden remains unchanged.

The State 03 browser reference was re-rendered from the supplied DOM after
changing only the stale header datum from `PENDING 245G` to `PENDING 0G`.
Selected `VALUE 245` and `DEPOSIT ×7` remain unchanged. The correction is
recorded in `docs/superpowers/specs/2026-09-04-phoenix-ui-reference-contract.md`;
the source HTML and PNG pixels were not edited directly.

## TDD evidence

### RED

The new focused integration tests first ran against the pre-panel surface and
reported 42/44 tests passed. The two expected failures were the missing
`selected_kind()` / `selected_quantity()` panel contracts for Shop and
Shipping.

### GREEN

After adding both authored panels, the focused integration suite passed 44/44.
The modal layering test was then added and the final integration lane passed:

- 66/66 integration tests passed
- 778 assertions passed
- Shop quantity max and `ui_accept` request coverage passed
- Shipping quantity max and `ui_accept` request coverage passed
- real `GameHud` tutorial/modal visibility coverage passed

The e2e lane passed with the existing isolated 1x window settings fixture:

- 4/4 cases passed
- 0 errors, failures, flaky cases, skipped cases, or orphans
- `test_shop_purchase_updates_money` uses keyboard Enter and Esc through the
  production panel path

## Capture evidence

Fresh native macOS candidates are retained under `test_output/ui-visual/`:

- Shop raw: `test_output/ui-visual/02-seed-shop.png`
- Shop nearest-2x: `test_output/ui-visual/02-seed-shop-2x.png`
- Shipping raw: `test_output/ui-visual/03-shipping-day14.png`
- Shipping nearest-2x: `test_output/ui-visual/03-shipping-day14-2x.png`

The candidates include the modal dim layer, flat inset rows with gold selected
accents, authored font weights, keyboard keycaps, Shop's normal-opacity
unselected vendor rows with dim `×0` boxes, Shipping's dim zero-stock rows
without quantity boxes, the single-line `M ALL` control, and the tinted Day 14
warning.

The approved state-01 comparison remains exact:

```text
golden_missing=false
max_channel_delta=0
differing_pixels=0
pixels_over_tolerance=0
pixels_over_contract_channel_ceiling=0
compared_pixels=65280
mismatch_ratio=0.00000000
```

State 02 and State 03 report-only comparisons correctly report
`golden_missing=true`; no Task 6 golden was created or updated. Native capture
processes retain the existing shutdown diagnostics of two leaked ObjectDB
instances and one resource still in use; capture files were written
successfully and the focused tests pass.

After committing the implementation, `rtk ./tools/verify-clean.sh` passed
against committed `HEAD`, including editor import/quit, the full GUT lane
(160/160 tests and 2,060 assertions), `project_smoke.gd`,
`world_math_smoke.gd`, and `world_shell_smoke.gd`. The world-shell smoke
retained the same two ObjectDB and one resource shutdown diagnostics; its
smoke result was successful.

## Files changed

- `scenes/ui/shop_panel.tscn`
- `scenes/ui/shipping_panel.tscn`
- `scripts/ui/shop_panel.gd`
- `scripts/ui/shipping_panel.gd`
- `scripts/ui/game_hud.gd`
- `scripts/ui/ui_style.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/e2e/gameplay_day_one_test.gd`
- `tests/visual/capture_ui_states.gd`
- `tests/visual/compare_ui_states.gd`
- `tests/visual/ui_capture_host.gd`
- `tests/visual/ui_fixture_factory.gd`
- `tests/visual/design-reference/03-shipping-day14.png`
- `tools/verify-visual.sh`
- `docs/superpowers/specs/2026-09-04-phoenix-ui-reference-contract.md`

## Remaining concerns and gates

The coordinator must approve the fresh Shop and Shipping candidates before any
explicit State 02/03 golden update. The visual comparison gate is intentionally
macOS-local with the existing measured one-channel / `0.0005` ratio tolerance;
Linux parity and calibration remain outside this task. The shutdown diagnostics
listed above are unchanged from the native capture path and did not cause test
failures.

## Status

`DONE_WITH_CONCERNS` pending coordinator visual approval and the later explicit
golden-update decision.
