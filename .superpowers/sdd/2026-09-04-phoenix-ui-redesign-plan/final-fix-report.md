# Final fix report

Base review commit: `30107c0`

Implementation commit: `4d5703c` (`Fix HUD modal refresh ownership`)

## Findings addressed

- Important modal refresh defect: `GameHud` now reconciles presentation against
  the existing `_primary_modals` registry after `render()` updates the morning
  summary state. An open Shop, Shipping, or Dialogue surface keeps the HUD
  chrome hidden and suppresses the tutorial card until that surface closes.
  Morning-summary acknowledgement still restores the chrome through the same
  ownership check.
- Minor legacy presentation cleanup: removed the invisible `Day`, `Time`,
  `Weather`, `Stamina`, `Money`, `SelectedSeed`, `PendingShipment`, harvested
  shadow, and seed shadow nodes plus their bindings and writes. The tested
  invisible `Objective` seam remains.
- Added
  `test_successful_shop_refresh_preserves_modal_mask_until_close`, which opens
  the Shop, completes a successful Turnip purchase through the existing
  `buy_requested` route, verifies the modal remains visually exclusive after
  the session-backed refresh, and verifies chrome/tutorial restoration on close.

## Verification

Focused regression:

```text
rtk /private/tmp/phoenix-task11-godot-wrapper.sh --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gameplay_shell.gd -gunit_test_name=test_successful_shop_refresh_preserves_modal_mask_until_close -gexit
```

```text
1/1 passed.
Tests                1
Passing Tests        1
Asserts              18
---- All tests passed! ----
```

Focused modal ownership regression set:

```text
rtk /private/tmp/phoenix-task11-godot-wrapper.sh --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gameplay_shell.gd -gunit_test_name=modal -gexit
```

```text
7/7 passed.
Tests                7
Passing Tests        7
Asserts             103
---- All tests passed! ----
```

Committed clean verifier, first sandbox attempt:

```text
rtk env PATH=/private/tmp/phoenix-task11-bin:$PATH ./tools/verify-clean.sh
```

```text
curl: (6) Could not resolve host: github.com
exit 6
```

The same committed-HEAD command was rerun with the authorized network
escalation. The pinned archive checksum passed and the verifier completed:

```text
rtk env PATH=/private/tmp/phoenix-task11-bin:$PATH ./tools/verify-clean.sh
```

```text
gut.tgz: OK
180/180 passed.
Tests               180
Passing Tests       180
Asserts            2341
---- All tests passed! ----
world math smoke passed
world shell smoke passed: 144 cells, alignment, player, camera, collisions, reachability, assets
exit 0
```

The verifier emitted the existing expected-error traces from invariant tests
and the existing ObjectDB/resource cleanup warning at process exit; no test
failed.

The editor/import check also exited 0. This host still logs its existing
certificate and editor-settings write warnings:

```text
ERROR: Condition "ret != noErr" is true. Returning: ""
ERROR: Cannot save file '/Users/chanwaichan/Library/Application Support/Godot/editor_settings-4.7.tres'.
```

## External gates

- Native macOS all-14 visual verification remains pending because current and
  baseline native captures hang in the available display environment.
- Native GdUnit4 and `godot-e2e` remain pending for the same display gate.
- Hosted macOS CI remains pending because this branch was not pushed.
- No golden updates, GUI retry, push, or merge was performed.

## Files changed

- `scripts/ui/game_hud.gd`
- `scenes/ui/game_hud.tscn`
- `tests/integration/test_gameplay_shell.gd`
- `.superpowers/sdd/2026-09-04-phoenix-ui-redesign-plan/final-fix-report.md`
