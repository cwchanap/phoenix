# Task 7 report

## Implementation

Task 7 adds the read-only Bag, Almanac, and Season Calendar surfaces to the
production `GameHud`. The panels are authored fixed-coordinate scenes using
the existing semantic crop/icon assets and `UiStyle` font, color, and panel
helpers. Bag navigation uses W/S for shelves and A/D for crop detail; Almanac
navigation uses A/D; Calendar is read-only. I/B/C are registered with the
existing primary-modal and Esc registries, and public open methods only set up
a panel after `_open_modal()` accepts the request. The Morning Summary guard
therefore remains authoritative and world input stays blocked while any one
surface is visible.

`GameRules.earliest_ready_day()` owns the remaining-growth calculation and
returns `-1` beyond Day 14. `VillagerRules.favourite_villager_for_crop()` is
the inverse favourite lookup used by Bag and Almanac. Calendar reads only the
persisted `weather_history` snapshot, marks truthful earliest readiness for
the fixture's Turnip Day 6 and Pumpkin Day 9, and leaves future weather cells
blank.

The visual fixture/capture/comparer accepts states 04–06 and restores each
fixture through a temporary `GameSession` before passing its `snapshot()` to
the real production HUD. Static panel geometry, badges, detail icons, payout
nodes, and footer keycaps are authored in the three scenes; scripts retain
data/style/selection updates and only reflow visible pending cards. Bag shelf
cards are square and compact, zero pending cards are omitted while positive
pending crops reflow, and the shipping shelf shows the snapshot-derived payout
plus tomorrow-morning copy (or truthful season-end copy on Day 14). The detail
pane uses a large bordered seed image and compact growth/coin/favourite icons.
Almanac art uses cover cropping with bordered favourite badges and three inset
stat cells per crop; growth bars use crop-specific gold, blue, and red accents.
Almanac and Calendar own solid dark backgrounds. Calendar fits both rows above
the footer, highlights Today and the Market badge, and shows Day 13 last night,
full Day 14 market copy, known weather through Day 3, and earliest readiness
help. Existing states 01–03 and their goldens were left unchanged.

## TDD evidence

### RED

The focused rule tests first failed at parse time because the two required
static helpers did not exist. The pre-panel integration lane then reported
46/48 tests passed; the two new Task 7 behavior cases exposed the missing
inventory surfaces and registry entries.

### GREEN

Focused rule lanes passed:

- `test_game_rules.gd`: 14/14 tests, 76 assertions
- `test_villager_rules.gd`: 4/4 tests, 77 assertions

The focused production shell lane passed 49/49 tests with 622 assertions,
including I/B/C same-key close behavior, one-surface exclusivity, world-input
gating, Esc behavior, the Morning Summary guard, rules-derived Bag/Almanac
values, pending Turnips to the snapshot-derived `140G` payout, sparse and
empty pending-shelf navigation, Day 6/Day 9 crop markers, and the known-only
weather history.

The editor import/quit probe completed successfully. Godot printed the
existing macOS certificate/editor-settings diagnostics while running from the
worktree; no parser or resource-import errors were reported.

## Capture evidence

Fresh native macOS candidates were captured with
`rtk ./tools/verify-visual.sh --report-only 04-bag 05-almanac 06-calendar`:

- Bag raw: `test_output/ui-visual/04-bag.png`
- Bag nearest-2x: `test_output/ui-visual/04-bag-2x.png`
- Almanac raw: `test_output/ui-visual/05-almanac.png`
- Almanac nearest-2x: `test_output/ui-visual/05-almanac-2x.png`
- Calendar raw: `test_output/ui-visual/06-calendar.png`
- Calendar nearest-2x: `test_output/ui-visual/06-calendar-2x.png`

The captures used the native Metal/OpenGL macOS path at the required
640x360 logical viewport. Coordinator approval was recorded for all three
states, after which only `04-bag.png`, `05-almanac.png`, and
`06-calendar.png` were created as production goldens. The normal native
01–06 verification then passed every state with `max_channel_delta=0`,
`differing_pixels=0`, and `mismatch_ratio=0.00000000`. The tracked 01–03
goldens retain their BASE hashes. The Calendar candidate shows
sunny/rainy/sunny through Day 3, no future weather, the Turnip Day 6 and
Pumpkin Day 9 earliest markers, and the Day 14 market marker.

## Files changed

- `scripts/game/game_rules.gd`
- `scripts/game/villager_rules.gd`
- `scripts/ui/game_hud.gd`
- `scripts/ui/bag_panel.gd`
- `scripts/ui/almanac_panel.gd`
- `scripts/ui/calendar_panel.gd`
- `scenes/ui/bag_panel.tscn`
- `scenes/ui/almanac_panel.tscn`
- `scenes/ui/calendar_panel.tscn`
- `scripts/ui/{bag_panel,almanac_panel,calendar_panel}.gd.uid`
- `tests/unit/test_game_rules.gd`
- `tests/unit/test_villager_rules.gd`
- `tests/integration/test_gameplay_shell.gd`
- `tests/visual/{ui_fixture_factory,ui_capture_host,capture_ui_states,compare_ui_states}.gd`
- `tools/verify-visual.sh`
- `tests/visual/goldens/04-bag.png`
- `tests/visual/goldens/05-almanac.png`
- `tests/visual/goldens/06-calendar.png`
- `.superpowers/sdd/2026-09-04-phoenix-ui-redesign-plan/task-7-report.md`

## Verification notes

The focused behavior lanes passed with the existing macOS certificate and
editor-settings diagnostics. Native visual captures emit the existing
ObjectDB/resource cleanup warning on some modal states; the visual comparer
still reports exact zero mismatches. No Linux visual claim is made.

## Status

`APPROVED_GOLDENS_READY_FOR_COMMIT`
