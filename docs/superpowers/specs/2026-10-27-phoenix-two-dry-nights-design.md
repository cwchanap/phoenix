# HPA-352 — Two dry nights wither a growing crop: design

**Status:** Implemented on this same PR at `822fd25`; the text below remains the design of record.
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

`GameRules.DRY_NIGHTS_TO_WITHER := 2` is the one authoritative pacing threshold (beside the existing day/weather/growth rules). Each **living crop** stores `dry_nights: int`, initialized to 0 on planting:

| Situation when sleeping | Immature crop result | Dry count | Morning summary |
| --- | --- | --- | --- |
| Watered today, or completed day was rainy | Existing growth +1 | Reset to 0 | Advanced +1 |
| First unwatered sunny night | No growth | Increment to 1 | No wither |
| Second consecutive unwatered sunny night | Remove crop; leave `tilled = true` | Crop removed | Withered +1 |
| Already mature | Keep crop available for harvest | Stays 0 | No wither |

- Apply the existing `completed_weather`, **not next morning's forecast**, inside the current `sleep()` loop. Remove a still-immature crop when its incremented count is `>= GameRules.DRY_NIGHTS_TO_WITHER`; avoid duplicating the threshold literal. Increment `crops_advanced` only for actual growth and new `crops_withered` only for actual removals. Keep all shipment, relationship and payout behavior as-is.
- Successful `water()` resets `dry_nights` immediately to 0 (and sets `watered_today`); a rainy completed day also resets it during `sleep()`. Failed water actions are atomic and cannot erase a warning. No separate per-frame drought update.
- After each overnight transition, reset `watered_today` as today. Mature crops are exempt even after any number of dry nights. Sleeping on Day 14 still triggers the finale without overnight growth, withering, or settlement; no Day 15.
- The proposed threshold is **exactly 2** dry nights, not two unwatered calendar days irrespective of rain. A rainy night breaks the streak.

## State and persistence

- Add `dry_nights` to each non-null crop in `GameSession._farm`, `_farm_snapshot()` (used by both `state()` and `snapshot()`), and `_farm_array()` on restore. Keep no dry counter on an empty plot.
- Add `crops_withered` to the existing `_pending_morning_summary` created by `sleep()`, including when zero. Day-14 sleep already short-circuits to `_complete_finale()` before the overnight loop and summary construction; **do not add a new Day-14 branch**. The existing `state()` / `snapshot()` summary copy path needs no second mapping.
- In `SessionStateValidator` change crop shape from 3 to 4 and summary shape from 8 to 9; require integral `dry_nights` in `0 <= dry_nights < GameRules.DRY_NIGHTS_TO_WITHER` (currently 0..1) and integral `crops_withered` in 0..number of farm cells. Reject missing, negative, wrong-type, or out-of-range values. Retain existing tilled/crop, weather, summary-day and shipment checks. Beyond shape/range, also reject a positive `dry_nights` on a mature crop or on one already `watered_today` — neither is naturally produced, so the impossible state is unrestorable rather than tolerated downstream (matching the existing crop-on-untilled-soil consistency check).
- Bump `SaveFileCodec.SCHEMA_VERSION` **3 → 4** as a minimal explicit incompatibility marker. **No migration or legacy parser.** Existing v3 saves are rejected at the codec boundary; newly encoded v4 saves round-trip through the validator and `restore_state()`. Keep one hard-coded version pin in `test_save_file.gd:13` (the existing pin at `:55` is redundant), remove the other three literal `== 3` pins while retaining the schema-1/schema+1 rejection checks, and update the complete hand-built crop/summary fixture inventory, both README version references, and the CLAUDE architecture note. The [implementation plan](../plans/2026-10-27-phoenix-two-dry-nights-implementation.md) names the exact locations.
- Do not introduce independent drought state, rule registries, new file formats, or a second state owner.

## Presentation

**Farm warning:** In `FarmView.refresh()`, use a single named muted/dry color on the crop sprite's **`self_modulate`**, not `modulate`: `ReadinessSparkle` is its child and must retain its own color. The tint predicate is `dry_nights > 0 && !rainy && day < GameRules.MAX_DAY`: no night follows Day 14, so a dry streak can never wither and must not warn. Clear `self_modulate` to neutral on *every* refresh after water, in rain, at maturity, on replanting or disappearance. Successful watering resets the counter to 0, so no redundant `watered_today` predicate or impossible-state test is needed. Rain-day suppression is display-only; the stored streak resets during `sleep()`. Do not tint soil/shadow or change sprite art.

**Morning report:** Add a single `Frame/WitheredWarning` label, right-aligned alongside `Frame/SectionTitle` (rather than a fifth card or reflowing the panel). In `MorningSummaryPanel.present()` show `1 CROP WITHERED` or `N CROPS WITHERED` only for a positive count; otherwise hide it. Reuse `UiStyle.text(..., color = UiStyle.RED)` instead of introducing a second warning color; preserve the shipping rows, four cards, save badge and keyboard flow. Check the maximum-count wording fits 640×360 without overlap.

**Explain the consequence:** Append one short sentence to the existing `ContentRules.TUTORIALS` **water** card (`content_rules.gd`), such as `Two dry nights in a row and it withers.` It already appears on sunny days with an immature, unwatered crop. Add the same rule in the README's **Sleep** paragraph (near line 102), alongside the required schema 4 text changes. Check tutorial wrapping at native viewport; do not create a separate popup, warning system, or tutorial entry.

## Acceptance and regression risks

1. GUT unit tests: first dry night stores 1 and keeps growth unchanged; exactly the second removes one crop but leaves tilled soil; watering and rain independently break the streak; mature crop stays; multiple simultaneous withers are counted once each; Day-14 finale doesn't advance/wither.
2. State validator tests: missing/wrong-type/negative `dry_nights` and `crops_withered` are rejected; v4 encode → decode → restore preserves a one-night warning and a pending positive wither summary; v3 rejected explicitly.
3. FarmView integration test checks crop `self_modulate` warning and neutral reset after water/rain/replant/absence (and unchanged readiness sparkle), validator rejection of a mature crop carrying a dry streak, and Day-14 suppression, using reachable session states. MorningSummaryPanel test checks a single conditional warning for 0/1/multiple withers, without affecting existing rows. Inspect tutorial text layout and README rule wording.
4. Existing five-Turnip Promising route and Efficient Can throughput benchmark pass with no numerical changes; both water through maturity. Keep the merged HPA-351 economy and its tests as the baseline (Potato seed 30G; sale values unchanged); no further balance tuning or fixture re-pin is part of HPA-352.
5. Run **full** `./tools/verify-clean.sh` (GUT + smokes), GdUnit4 and E2E **after shape changes**; updated invalid-state fixtures must still reach their *intended* validator checks, not pass for the wrong missing-field reason. On native macOS, judge only the warning's legibility at 2× under weather tint, and the positive/hidden label's fit with zero, one and several shipment rows. Run `./tools/verify-visual.sh`; do not blindly re-bless unrelated goldens.

## Follow-up review decisions (2026-10-28)

[Follow-up design review](https://github.com/cwchanap/phoenix/pull/26#issuecomment-6488811859) identified cross-suite fixture coverage, a shared threshold, player explanation, and more focused native visual checks. All are accepted **except** dropping the immature guard from the sprite tint: a mature crop with `dry_nights = 1` is structurally accepted by the proposed range validator even though natural growth does not create it. Preserve the one-line guard to ensure mature crops never appear threatened after restoring a manually constructed state. No new gameplay system, schema migration, or separate PR is warranted.

A later implementation review revisited this: instead of tolerating the impossible state, the validator now rejects `dry_nights > 0` on a mature or `watered_today` crop outright (the same class of consistency check as crop-on-untilled-soil). The tint's maturity guard and the `sleep()` dry-streak normalization landed in `f63ee16` were then removed as redundant defense — the documented goal is unchanged, since such a crop can never be restored at all.

## Boundaries

No dead sprite, revival, cleanup command, fertilizer, sprinklers, extra animations, sound, crop price adjustments, autosave architecture changes, or compatibility layer. If bespoke withering art is ever wanted, scope it to a **separate image-generation ticket**; it is not needed for this feature.

**Delivery:** one HPA-352 ticket, one draft PR for design review and subsequent implementation. No follow-up implementation PR.
