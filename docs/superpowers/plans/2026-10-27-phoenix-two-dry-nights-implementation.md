# HPA-352 — Two-night crop withering: implementation plan

**Status:** Planning only; follow this checklist by extending the **same** draft PR.
**Design:** [2026-10-27-phoenix-two-dry-nights-design.md](../specs/2026-10-27-phoenix-two-dry-nights-design.md)
**Issue:** https://linear.app/cwchanap/issue/HPA-352/daily-pacing-wither-crops-left-dry-for-two-nights
**Working branch:** `agent/hpa-352-two-dry-nights-plan`

## 0. Baseline and integration boundary

- [ ] Base implementation on latest `main` at `f3c059bc507de04a04730453ae6071fcb70c5ba0` (the merged HPA-351 tip observed 2026-10-28) or its current descendant. After syncing this branch, pin the actual implementation-base SHA and run `./tools/verify-clean.sh` before changing gameplay code. Record actual results in this PR; no baseline was executed during this planning update.
- [ ] Confirm the base includes HPA-353's `SessionStateValidator` extraction, HPA-263's passive clock and HPA-264's target-driven Space input (present on `main` when designed).
- [ ] HPA-351 PR #25 **has merged into `main`**. Preserve `GameRules.SEED_PRICES = [20, 30, 70]`, `SALE_VALUES = [35, 75, 140]`, `GROWTH_NIGHTS = [3, 5, 7]`, and its new crop-niche/UI tests. Never revert the merged 30G Potato price or restore superseded 95G/150G sale prices. No new balance change in HPA-352.
- [ ] Reuse the current `GameSession` overnight loop, `_farm_snapshot()`/`_farm_array()` restore path, `SessionStateValidator`, `FarmView.refresh()`, and authored `MorningSummaryPanel`. No new service or abstraction.

### Merge verification note (2026-10-28)

The prior planning branch base was `05f938352a4314019cc9be8247a932d89d358eb5`. The latest main tip is `f3c059bc507de04a04730453ae6071fcb70c5ba0`, thirteen commits ahead (HPA-351). This review checked remote source and PR metadata but **did not run code or tests**. HPA-351's merged PR reports a green baseline of 264 GUT tests, 12 GdUnit4 tests, 7 E2E tests and 14 visual states. Treat those as prior evidence, not as new HPA-352 verification.

## 1. Rules and persistence — small, test-first change

**Files:** `scripts/game/game_rules.gd`; `scripts/game/game_session.gd`; `scripts/game/session_state_validator.gd`; `scripts/persistence/save_file.gd`.

- [ ] Extend existing GUT tests in `tests/unit/test_game_session.gd` (start with `test_unwatered_sunny_crop_does_not_advance` and `test_rainy_completed_day_advances_each_planted_crop`); add only the new cases those tests cannot cleanly express:
  - Plant a Turnip and sleep in sunny weather without watering: day-2 crop remains, growth 0, `dry_nights == 1`, `crops_withered == 0`. After acknowledging the summary and sleeping sunny again: crop is null, soil remains tilled, `crops_withered == 1`, `crops_advanced == 0`.
  - Plant / dry once / water on the following day: `dry_nights` becomes 0 **at successful water()**, and growth resumes overnight; a subsequent missed night gives only the first warning.
  - Plant / dry once / next day rainy / sleep: rain resets the streak and advances growth even without manual watering; next sunny missed night counts as first, not second. Use deterministic weather rolls; distinguish completed-day weather from next-day weather.
  - Mature a crop through watering, then skip at least two sunny nights; it remains harvestable. Wither two cells in one transition and verify count 2. Verify Day-14 `sleep()` takes the existing finale route without a wither transition.
- [ ] Add **one** shared pacing constant `GameRules.DRY_NIGHTS_TO_WITHER := 2` beside the existing day/weather/growth constants. Initialize `dry_nights = 0` in `plant()` and reset it to 0 on successful `water()` only. In `sleep()`, test maturity first; for immature crops reuse the existing water/rain decision: advance and reset on wet nights, increment on dry, remove the crop with `tile["crop"] = null` at `dry_nights >= GameRules.DRY_NIGHTS_TO_WITHER`; retain the tilled soil. Reset `watered_today` on remaining crops. Count withers independently of growth. Keep the overnight rule inline; no new helper/service.
- [ ] Persist/read the field in `_farm_snapshot()` and `_farm_array()`. Add `crops_withered` (including 0) in the same existing summary dictionary; `state()` and `snapshot()` already carry that summary.
- [ ] Update `_farm_state_error()` crop shape 3 → 4 and validate integer `dry_nights` in `0 <= dry_nights < GameRules.DRY_NIGHTS_TO_WITHER` (currently 0..1). Update `_morning_summary_state_error()` shape 8 → 9 and validate `crops_withered` within 0..farm-cell count, using the existing `crops_advanced` range-check pattern. Use existing field helpers and preserve unrelated validation.
- [ ] Add direct missing, noninteger, negative and too-large cases to `tests/unit/test_session_state_validator.gd` for both new fields. Repair the existing hand-built crop/summary fixtures listed in **Known fixture and documentation repairs** below.
- [ ] Increase `SaveFileCodec.SCHEMA_VERSION` from 3 to 4, with **no migration**. Retain **one** hardcoded version pin in `test_save_file.gd:13` (update it to 4); remove the three redundant `== 3` asserts listed below rather than repinning. Keep the field-blind codec and its existing `SCHEMA_VERSION ± 1` unsupported-schema checks. Add/adjust codec round-trip assertions: dry streak and pending positive wither summary survive encode/decode/restore; an explicit old schema 3 returns `Unsupported save schema`. Verify malformed states are rejected atomically.

### Measured fixture and documentation repair inventory (against `main` at `f3c059b`)

The [follow-up review](https://github.com/cwchanap/phoenix/pull/26#issuecomment-6488811859) prototyped the rules and then the new state shapes in a **throwaway archive**, reporting **264/264 GUT** with behavior only and **259/264** after crop/summary shapes changed; those were reviewer tests, *not* HPA-352 branch test runs. Repair all affected fixtures before concluding the state change is green:

| Existing file / location | Required targeted repair |
| --- | --- |
| `tests/unit/test_game_session.gd:780-784` | Add `dry_nights: 0` to the exact crop-dictionary expectation. |
| `tests/unit/test_game_session.gd:1549` | Add `dry_nights: 0` to the Day-14 crop literal used before `restore_state()`. |
| `tests/integration/test_gameplay_shell.gd:769-785, 816-826, 887-897` | Add `dry_nights: 0` to *every* hand-built crop for the calendar/read-only panel restore cases. |
| `tests/visual/ui_fixture_factory.gd:63-82, 111-135` | Update the calendar crop literals and the 8-field morning-summary fixture; their `assert(state_error == "")` gates fail only in native visual captures. |
| `tests/e2e/gameplay_day_one_test.gd:288-293` | Add `dry_nights: 0` to seeded Continue save; update the adjacent `schema-3` comment to schema 4. This is an E2E-only fixture. |
| `tests/unit/test_session_state_validator.gd:98-110` | Add `dry_nights: 0` to **both** deliberately invalid crop candidates (untilled soil and growth beyond range). Otherwise they quietly pass `assert_ne(state_error, "")` on *wrong shape*, losing the original test coverage. Prefer asserting the intended error text for each. |
| `tests/integration/test_gameplay_shell.gd:1320-1335` | Add `crops_withered: 0` to the hand-built summary for realism and exercise 0→positive→0 warning UI. The existing `present()` uses `.get()` and might not fail without this, so do not count it as an observed GUT failure. |
| `tests/unit/test_save_file.gd:13, 55` | Update the **first** literal `SCHEMA_VERSION == 3` to `4`; **remove** the redundant second hardcoded assertion at line 55 while preserving legacy/future schema rejection tests. |
| `tests/unit/test_game_session.gd:278` | Remove redundant `SCHEMA_VERSION == 3` assertion; rename the `test_schema_3_transport_...` function to a version-agnostic transport name and keep malformed/ownership rejection coverage. |
| `tests/integration/test_app_launch.gd:410` | Remove redundant `SCHEMA_VERSION == 3` assertion; change the adjacent `schema-3 slot` comment to schema 4 and keep the rejection-classification assertions. |
| `README.md:26, 33, ~102` | Update both schema-3 references to **4** and explain that an immature crop withers after two consecutive nights without watering or rain in the Sleep gameplay paragraph. |
| `CLAUDE.md` | Update the schema-version handoff; retain the existing ownership boundaries and place the new threshold with other `GameRules` pacing constants. |

Do **not** rely only on red GUT tests: invalid-state candidates can silently pass for the wrong reason, and visual/E2E fixtures live in separate lanes.

**Checkpoint:** run the **entire** `./tools/verify-clean.sh` GUT/smoke gate plus both `GdUnit4 tests/gdunit` and `tests/e2e` suites after rules, validator, and fixture changes. Record actual totals, and do not suppress existing assertions. No crop price, tool cost, weather probability, or save architecture changes.

## 2. Farm warning and report line

**Files:** `scripts/world/farm_view.gd`; `scripts/ui/morning_summary_panel.gd`; `scenes/ui/morning_summary_panel.tscn`; `scripts/game/content_rules.gd`.

- [ ] Add one named muted/dry tint constant in `FarmView`. On **every** `refresh(snapshot)` set the crop sprite's **`self_modulate`** (not inherited `modulate`, which would tint its child `ReadinessSparkle`). Tint when `dry_nights > 0` and `!rainy` and crop is **immature**; successful water already clears the counter, so no extra `watered_today` predicate/test. Keep the cheap maturity guard: the range-only validator permits a hand-built/restored *mature* crop with `dry_nights == 1`, even though real overnight growth cannot create it. Reset tint to neutral on water/rain/maturity/replant/removal; do not modify shadow, soil, or readiness-sparkle rendering.
- [ ] Add one hidden, right-aligned `Frame/WitheredWarning` Label in the existing horizontal row of `Frame/SectionTitle`; reuse `UiStyle.text(..., color = UiStyle.RED)` instead of introducing another warning color. No fifth summary card, modal, or scroll area.
- [ ] In `MorningSummaryPanel.present()`, compute the summary count and only show the line when positive; support singular/plural text. Repeated `present()` calls must hide a stale warning when the next summary has zero withers.
- [ ] Extend `tests/integration/test_gameplay_shell.gd` or a focused view/panel test to assert `self_modulate` tint/neutral state, unchanged mature `ReadinessSparkle`, and zero/one/many warning text and visibility. Ensure a rain day hides crop tint; the persisted counter still resets only overnight.
- [ ] Append **one short sentence** to the existing `water` tutorial's `ContentRules.TUTORIALS` body, e.g. `Two dry nights in a row and it withers.` Do not add a new tutorial/modal. Update the README Sleep rules text as listed above. Check added tutorial text fits the authored viewport during native verification.

**Checkpoint:** one dry-night warning is visible, a following sunny dry night removes the crop, and the morning warning is readable without overlapping shipping rows at the 640×360 authored viewport.

## 3. Regression and native visual checks

- [ ] Run `./tools/verify-clean.sh` (import, GUT, headless smokes, audio checks), and record exact totals and commit SHA.
- [ ] Run `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and the same command with `tests/e2e`. Investigate failing existing tests rather than deleting or loosening them.
- [ ] Retain merged HPA-351's exact economic regression numbers: mixed shipment **285G**; canonical five-Turnip / **175G** Promising route; Efficient Can Pumpkin throughput **6 vs 10 crops**, **840G vs 1,400G shipped**, and **1,040G vs 1,400G cash (+360G)**. Both water through maturity and should still pass without changes. Preserve the crop-niche test and inclusive shipped-value thresholds (150G/300G).
- [ ] On native macOS, focus manual inspection on the **two things automated tests cannot establish**: (1) muted crop tint is legible at 2× under the weather overlay, without altering sparkle appearance; (2) the morning wither warning fits and resets correctly with **zero, one, and several shipment rows**, with no overlap at 640×360. Also check the updated water-tutorial copy wraps cleanly. The sunny/rain/water/mature/Continue state transitions are covered by deterministic tests; do not duplicate them as a manual playtest checklist. Run `./tools/verify-visual.sh` against the merged HPA-351 goldens and newer nonblank-frame guard, inspect real diffs, and re-bless only genuinely intended changes; do not touch reference images.
- [ ] Cover freshly saved v4 Continue after one dry night and a wither summary, plus clean v3 refusal, with existing and focused **automated** save/launch tests. Confirm **both** README schema-3 references and the schema-v3 architecture note in `CLAUDE.md` are updated to v4 and README explains two-night withering.
- [ ] Check `git diff --check` and confirm no art/SFX, pricing, legacy migration, or framework files were introduced. Document actual verification outcomes and remaining limits in this PR before marking it ready for review.

## Reviewable file scope

| File(s) | Minimal expected change |
| --- | --- |
| `game_rules.gd` / `game_session.gd` | One shared threshold, crop field, overnight rules and wither count, restore/snapshot |
| `session_state_validator.gd` | Two field validations and shape sizes |
| `save_file.gd` | Schema number 3 → 4 only |
| `farm_view.gd` / `content_rules.gd` | Crop `self_modulate` warning and short addition to existing water tutorial |
| `morning_summary_panel.gd` / `morning_summary_panel.tscn` | One conditional warning line |
| `tests/unit`, `tests/integration`, relevant codec/GdUnit/E2E fixtures | Focused scenarios and exact changed state/version expectations, as enumerated above |
| `README.md`, `CLAUDE.md` | Update both README schema references, Sleep rules explanation and CLAUDE handoff |

## Not part of this PR

No new crop mechanics, fertilizer/sprinkler systems, deceased-crop assets, art/SFX generation, save migrations, unrelated refactors or multiple PRs for HPA-352. HPA-539 (walk-cycle art) and HPA-546 (walk-cycle integration) stay separate; HPA-351 crop balance has already merged and must not be reverted.

**Latest review disposition:** Review [#5692806467](https://github.com/cwchanap/phoenix/pull/26#pullrequestreview-5692806467) confirmed missing fixture and README references (added above) and a redundant tint condition (removed). The Day-14 finale already returns before overnight summary creation, so no special summary handling is needed. No additional mechanism is introduced.

**Follow-up review disposition:** [Review comment #6488811859](https://github.com/cwchanap/phoenix/pull/26#issuecomment-6488811859) identifies additional fixture consumers (including silent validator coverage loss), one shared threshold, player-facing explanation, and targeted visual verification; these are incorporated above. `self_modulate` and `UiStyle.RED` are reused. **Declined only** removing the immature tint check: the proposed range validator accepts a structurally valid, manually constructed mature crop with a nonzero dry counter, so leaving one guard ensures mature crops never appear warned after restore. No added framework or new standalone UI.

**Implementation has not started in this planning commit.** Checkboxes are intentionally unchecked until verified against an implementation commit.
