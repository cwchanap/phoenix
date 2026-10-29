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

**Files:** `scripts/game/game_session.gd`; `scripts/game/session_state_validator.gd`; `scripts/persistence/save_file.gd`.

- [ ] Write a few targeted GUT tests in `tests/unit/test_game_session.gd`:
  - Plant a Turnip and sleep in sunny weather without watering: day-2 crop remains, growth 0, `dry_nights == 1`, `crops_withered == 0`. After acknowledging the summary and sleeping sunny again: crop is null, soil remains tilled, `crops_withered == 1`, `crops_advanced == 0`.
  - Plant / dry once / water on the following day: `dry_nights` becomes 0 **at successful water()**, and growth resumes overnight; a subsequent missed night gives only the first warning.
  - Plant / dry once / next day rainy / sleep: rain resets the streak and advances growth even without manual watering; next sunny missed night counts as first, not second. Use deterministic weather rolls; distinguish completed-day weather from next-day weather.
  - Mature a crop through watering, then skip at least two sunny nights; it remains harvestable. Wither two cells in one transition and verify count 2. Verify Day-14 `sleep()` takes the existing finale route without a wither transition.
- [ ] Initialize `dry_nights = 0` in `plant()` and reset it to 0 on successful `water()` only. In `sleep()`, test maturity first; for immature crops use the existing water/rain decision: advance and reset on wet nights, increment on dry, set `tile["crop"] = null` at exactly 2; retain the tilled soil. Reset `watered_today` on remaining crops. Count withers independently of growth.
- [ ] Persist/read the field in `_farm_snapshot()` and `_farm_array()`. Add `crops_withered` (including 0) in the same existing summary dictionary; `state()` and `snapshot()` already carry that summary.
- [ ] Update `_farm_state_error()` crop shape 3 → 4 and validate integer `dry_nights` within 0..1. Update `_morning_summary_state_error()` shape 8 → 9 and validate `crops_withered` within 0..farm-cell count. Use existing field helpers, preserve error ordering and all unrelated validation.
- [ ] Add direct missing, noninteger, negative and too-large cases to `tests/unit/test_session_state_validator.gd` for both new fields. Repair the existing hand-built crop/summary fixtures listed in **Known fixture and documentation repairs** below.
- [ ] Increase `SaveFileCodec.SCHEMA_VERSION` from 3 to 4, with **no migration**. Update the three exact v3 pins and the test name/comment listed below; keep the field-blind codec and its existing unsupported-schema behavior. Add/adjust codec round-trip assertions: warning count and pending summary survive encode/decode/restore; old schema 3 returns "Unsupported save schema". Verify malformed states are rejected atomically.

### Known fixture and documentation repairs (verified against `main` at `f3c059b`)

Repair these specific existing expectations while implementing the schema/shape changes; do not relax their behavioral assertions:

- `tests/integration/test_gameplay_shell.gd:1320-1335`: the manually constructed eight-field `pending_morning_summary` used by `hud.render()` must include `crops_withered: 0`; reuse this UI fixture to assert that positive wither counts display and zero counts hide the label.
- `tests/unit/test_game_session.gd:780-784`: the exact expected crop dictionary in `test_turnip_actions_commit_atomically` must include `dry_nights: 0`.
- `tests/unit/test_save_file.gd:13`: update the hardcoded `SaveFileCodec.SCHEMA_VERSION == 3` assertion to **4**.
- `tests/unit/test_game_session.gd:278`: update the **3 → 4** version assertion and rename `test_schema_3_transport_stays_field_blind_and_session_rejects_sabotaged_ownership` to schema 4; keep the field-blind, rejected-legacy-schema, and invalid-ownership assertions.
- `tests/integration/test_app_launch.gd:410`: update the hardcoded version assertion to **4** and the adjacent `schema-3 slot` comment to schema 4; preserve the distinction between codec rejection and invalid session-state rejection.
- `README.md:26,33`: both user-facing `schema 3` statements must be changed to **schema 4** during implementation, alongside the `CLAUDE.md` architecture/version note. Do not leave README conditional.
- If further shape/version literals fail, update only genuinely affected fixtures while preserving their assertions and documenting the reason.

**Checkpoint:** targeted unit suite passes, with no changes to crop price, tool costs, daily time, rain probability, or save architecture.

## 2. Farm warning and report line

**Files:** `scripts/world/farm_view.gd`; `scripts/ui/morning_summary_panel.gd`; `scenes/ui/morning_summary_panel.tscn`.

- [ ] Add one named muted/dry tint constant in `FarmView`. On every `refresh(snapshot)` set the crop sprite's `modulate` based on snapshot data; tint an **immature** crop with `dry_nights == 1` only on a **sunny** day. A successful `water()` resets the count to 0 already, so no extra `watered_today` predicate or test for the impossible combination (`dry_nights == 1` and `watered_today == true`) is necessary. Return to neutral on water, rain, maturity, and absence. Avoid modifying shadow, soil, or readiness-sparkle rendering.
- [ ] Add one hidden, right-aligned `Frame/WitheredWarning` Label in the existing horizontal row of `Frame/SectionTitle`; reuse `UiStyle.text` with warning color. No fifth summary card, modal, or scroll area.
- [ ] In `MorningSummaryPanel.present()`, compute the summary count and only show the line when positive; support singular/plural text. Repeated `present()` calls must hide a stale warning when the next summary has zero withers.
- [ ] Extend `tests/integration/test_gameplay_shell.gd` or an existing focused view/panel test to assert tint/neutral state and zero/one/many warning text and visibility. Ensure a rain day doesn't misleadingly display the crop tint; the persisted counter still resets only in the overnight rule.

**Checkpoint:** one dry-night warning is visible, a following sunny dry night removes the crop, and the morning warning is readable without overlapping shipping rows at the 640×360 authored viewport.

## 3. Regression and native visual checks

- [ ] Run `./tools/verify-clean.sh` (import, GUT, headless smokes, audio checks), and record exact totals and commit SHA.
- [ ] Run `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and the same command with `tests/e2e`. Investigate failing existing tests rather than deleting or loosening them.
- [ ] Retain merged HPA-351's exact economic regression numbers: mixed shipment **285G**; canonical five-Turnip / **175G** Promising route; Efficient Can Pumpkin throughput **6 vs 10 crops**, **840G vs 1,400G shipped**, and **1,040G vs 1,400G cash (+360G)**. Both water through maturity and should still pass without changes. Preserve the crop-niche test and inclusive shipped-value thresholds (150G/300G).
- [ ] On native macOS, manually observe a sun-dry → watered recovery, a sun-dry → sun-dry wither, rainy recovery and a mature harvest wait. Capture a positive-wither summary at the 640×360 viewport, inspect width/alignment and both single/multi-shipment variants. Run `./tools/verify-visual.sh` using the merged HPA-351 golden baseline (`02-seed-shop`, `04-bag`, `05-almanac`) and the newer `ui_capture_host.gd` nonblank-frame guard; inspect any diffs and re-bless only genuinely intended production goldens. Do not touch design-reference images.
- [ ] Verify a freshly saved v4 run can Continue after one dry night and after a wither summary, and that a v3 save is refused cleanly. **Update both explicit schema-3 references in `README.md`** and the schema-v3 architecture note in `CLAUDE.md` to v4.
- [ ] Check `git diff --check` and confirm no art/SFX, pricing, legacy migration, or framework files were introduced. Document actual verification outcomes and remaining limits in this PR before marking it ready for review.

## Reviewable file scope

| File(s) | Minimal expected change |
| --- | --- |
| `game_session.gd` | Crop field, overnight rules and wither count, restore/snapshot |
| `session_state_validator.gd` | Two field validations and shape sizes |
| `save_file.gd` | Schema number 3 → 4 only |
| `farm_view.gd` | Snapshot-driven tint and neutral reset |
| `morning_summary_panel.gd` / `morning_summary_panel.tscn` | One conditional warning line |
| `tests/unit`, `tests/integration`, relevant codec/GdUnit/E2E fixtures | Focused scenarios and exact changed state/version expectations, as enumerated above |
| `README.md`, `CLAUDE.md` | Update both README schema-3 references and the CLAUDE schema-version contract |

## Not part of this PR

No new crop mechanics, fertilizer/sprinkler systems, deceased-crop assets, art/SFX generation, save migrations, unrelated refactors or multiple PRs for HPA-352. HPA-539 (walk-cycle art) and HPA-546 (walk-cycle integration) stay separate; HPA-351 crop balance has already merged and must not be reverted.

**Latest review disposition:** Review [#5692806467](https://github.com/cwchanap/phoenix/pull/26#pullrequestreview-5692806467) confirmed missing fixture and README references (added above) and a redundant tint condition (removed). The Day-14 finale already returns before overnight summary creation, so no special summary handling is needed. No additional mechanism is introduced.

**Implementation has not started in this planning commit.** Checkboxes are intentionally unchecked until verified against an implementation commit.
