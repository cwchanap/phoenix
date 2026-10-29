# HPA-352 — Two dry nights wither a growing crop: design

**Status:** Proposed, planning only; implementation continues in this same draft PR.
**Linear:** https://linear.app/cwchanap/issue/HPA-352/daily-pacing-wither-crops-left-dry-for-two-nights
**Prerequisites:** HPA-353 (validator extraction) and HPA-263 (passive day clock), both Done.

## Player outcome

Missing one sunny night of watering gives a visible warning and one chance to recover. Missing **two consecutive dry nights** removes an *immature* crop, but leaves its soil tilled. Harvest-ready crops never wither. Rain saves a crop; there is no dead-crop cleanup task or new asset.

This increases the stakes of daily watering without new farming commands, weather systems, or mechanics beyond the existing 14-day loop. The effective daily budget and the Efficient Can are unchanged.

## Current economy and test baseline (after HPA-351)

HPA-351 was merged as [PR #25](https://github.com/cwchanap/phoenix/pull/25), after this planning branch was created. The accepted change was **Potato seed 40G → 30G**, *not* the originally proposed Potato/Pumpkin sale-price increase. Current `GameRules.SEED_PRICES = [20, 30, 70]`, `SALE_VALUES = [35, 75, 140]` and `GROWTH_NIGHTS = [3, 5, 7]`; do not change any of these in HPA-352.

The merged behavior retains the exact existing payout / finale tests: two Turnips + Potato + Pumpkin pay **285G**, the five-Turnip Promising route ships **175G**, and Efficient Can Pumpkin throughput is **6 vs 10 harvested**, **840G vs 1,400G shipped**, and **1,040G vs 1,400G final money (+360G)**. Withering does not alter these continuously watered routes. The HPA-351 regression suite additionally checks the Potato seed price/UI and the Almanac, Bag and Shop data; retain all those assertions. Preserve `ContentRules` shipped-value thresholds (**150G Promising / 300G Heart**) and the new crop-niche tests.

Latest `main` also hardens `tests/visual/ui_capture_host.gd` against intermittently blank frames, and re-blesses production goldens `02-seed-shop`, `04-bag`, and `05-almanac`. Use those merged images and capture guard as the visual baseline. HPA-352 should only touch the morning-summary scene and its own crop warning visuals.

## Existing code seams (checked on `main`, 2026-10-28, commit `f3c059bc507de04a04730453ae6071fcb70c5ba0`)

- `scripts/game/game_session.gd` is the only mutable farm authority. `plant()` creates a crop with `kind`, `growth` and `watered_today`; `water()` updates it; `sleep()` processes the **completed day's** water/rain state and constructs the pending morning summary. `state()` / `snapshot()` expose copies, and `_farm_array()` reconstructs validated save state.
- `scripts/game/session_state_validator.gd` owns persisted validation. `_farm_state_error()` requires exactly three crop fields; `_morning_summary_state_error()` requires eight summary fields.
- `scripts/world/farm_view.gd` creates a sprite per plot and renders from snapshots in `refresh()`, including crop maturity. It has no rules ownership.
- `scripts/ui/morning_summary_panel.gd` presents the summary through the authored `scenes/ui/morning_summary_panel.tscn`. The existing top four cards and shipping rows fill nearly all vertical space; `Frame/SectionTitle` has unused right-side space on the same row.
- `scripts/persistence/save_file.gd` gates old saves with `SaveFileCodec.SCHEMA_VERSION = 3`. It serializes generic state, not farm-specific fields.

## Overnight policy

One `dry_nights: int` field per **living crop**, initialized to 0 on planting:

| Situation when sleeping | Immature crop result | Dry count | Morning summary |
| --- | --- | --- | --- |
| Watered today, or completed day was rainy | Existing growth +1 | Reset to 0 | Advanced +1 |
| First unwatered sunny night | No growth | Increment to 1 | No wither |
| Second consecutive unwatered sunny night | Remove crop; leave `tilled = true` | Crop removed | Withered +1 |
| Already mature | Keep crop available for harvest | Reset to 0 | No wither |

- Apply the existing `completed_weather`, **not next morning's forecast**, inside the current `sleep()` loop. Increment `crops_advanced` only for actual growth and new `crops_withered` only for actual removals. Keep all shipment, relationship, tutorial and payout behavior as-is.
- Successful `water()` resets `dry_nights` immediately to 0 (and sets `watered_today`); a rainy completed day also resets it during `sleep()`. Failed water actions are atomic and cannot erase a warning. No separate per-frame drought update.
- After each overnight transition, reset `watered_today` as today. Mature crops are exempt even after any number of dry nights. Sleeping on Day 14 still triggers the finale without overnight growth, withering, or settlement; no Day 15.
- The proposed threshold is **exactly 2** dry nights, not two unwatered calendar days irrespective of rain. A rainy night breaks the streak.

## State and persistence

- Add `dry_nights` to each non-null crop in `GameSession._farm`, `_farm_snapshot()` (used by both `state()` and `snapshot()`), and `_farm_array()` on restore. Keep no dry counter on an empty plot.
- Add `crops_withered` to the existing `_pending_morning_summary` created by `sleep()`, including when zero. Day-14 sleep already short-circuits to `_complete_finale()` before the overnight loop and summary construction; **do not add a new Day-14 branch**. The existing `state()` / `snapshot()` summary copy path needs no second mapping.
- In `SessionStateValidator` change crop shape from 3 to 4 and summary shape from 8 to 9; require present integral `dry_nights` in range 0..1 and integral `crops_withered` in range 0..number of farm cells. Reject missing, negative, wrong-type, or impossible values. Retain the existing tilled/crop, weather, summary-day and shipment checks.
- Bump `SaveFileCodec.SCHEMA_VERSION` **3 → 4** as a minimal explicit incompatibility marker. **No migration or legacy parser.** Existing v3 saves are rejected at the codec boundary; newly encoded v4 saves round-trip through the validator and `restore_state()`. Update the three pinned version assertions (`test_save_file.gd`, `test_game_session.gd`, `test_app_launch.gd`), the hand-built crop/summary fixtures, both explicit README schema-3 references, and the CLAUDE architecture note. The [implementation plan](../plans/2026-10-27-phoenix-two-dry-nights-implementation.md) names the exact locations.
- Do not introduce independent drought state, rule registries, new file formats, or a second state owner.

## Presentation

**Farm warning:** In `FarmView.refresh()` apply one muted/dry `Sprite2D.modulate` tint when `dry_nights == 1` for an immature crop on a **sunny** day. Restore neutral modulate on every refresh after watering, on rainy days, once mature, newly planted, or removed. Since successful `water()` immediately resets `dry_nights` to 0, a separate `not watered_today` condition (and test of the unreachable `dry_nights == 1 && watered_today` combination) is unnecessary. Showing a warning for a rainy day (when rain protects the crop) would be misleading, so hide it on rainy days without changing the persisted count prematurely. Do not tint soil/shadow or change sprite art. Use a single named color constant so tests and visual review agree.

**Morning report:** Add a single `Frame/WitheredWarning` label, right-aligned alongside `Frame/SectionTitle` (rather than a fifth card or reflowing the panel). In `MorningSummaryPanel.present()` show `1 CROP WITHERED` or `N CROPS WITHERED` only for a positive count; otherwise hide it. Follow existing `UiStyle` text styling, use a restrained warning color, preserve the shipping rows, four cards, save badge and keyboard flow. Check the maximum-count wording fits 640×360 without overlap.

## Acceptance and regression risks

1. GUT unit tests: first dry night stores 1 and keeps growth unchanged; exactly the second removes one crop but leaves tilled soil; watering and rain independently break the streak; mature crop stays; multiple simultaneous withers are counted once each; Day-14 finale doesn't advance/wither.
2. State validator tests: missing/wrong-type/negative `dry_nights` and `crops_withered` are rejected; v4 encode → decode → restore preserves a one-night warning and a pending positive wither summary; v3 rejected explicitly.
3. FarmView integration test checks tint and neutral reset after water/rain/maturity/absence, using reachable session states (no artificial `dry_nights == 1 && watered_today` case). MorningSummaryPanel test checks a single conditional warning for 0/1/multiple withers, without affecting existing rows.
4. Existing five-Turnip Promising route and Efficient Can throughput benchmark pass with no numerical changes; both water through maturity. Keep the merged HPA-351 economy and its tests as the baseline (Potato seed 30G; sale values unchanged); no further balance tuning or fixture re-pin is part of HPA-352.
5. Run `./tools/verify-clean.sh`, GdUnit4 and E2E; inspect a native screen capture with a wither count and normal summary, then `./tools/verify-visual.sh` on macOS. Do not blindly re-bless goldens; default normal-day captures should remain unchanged.

## Boundaries

No dead sprite, revival, cleanup command, fertilizer, sprinklers, extra animations, sound, crop price adjustments, autosave architecture changes, or compatibility layer. If bespoke withering art is ever wanted, scope it to a **separate image-generation ticket**; it is not needed for this feature.

**Delivery:** one HPA-352 ticket, one draft PR for design review and subsequent implementation. No follow-up implementation PR.
