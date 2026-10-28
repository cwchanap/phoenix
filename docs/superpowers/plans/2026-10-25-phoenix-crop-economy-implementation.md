# HPA-351 — Crop-economy niches: single-PR implementation plan

**Status:** Planned; not implemented; no test/visual results claimed
**Design:** [2026-10-25-phoenix-crop-economy-design.md](../specs/2026-10-25-phoenix-crop-economy-design.md)
**Linear:** https://linear.app/cwchanap/issue/HPA-351/economy-give-each-crop-a-distinct-niche
**Base:** planned from `main` after HPA-263 on 2026-10-25. **Rebase onto current `main` before implementation**: HPA-264 landed after this draft branch fork and raised the save schema to v3.
**Delivery model:** Extend this **same draft PR** with the implementation; do not create a second PR or split into additional tickets.

## Reuse survey / simplest architecture

| Need | Existing owner | Reuse or change? |
| --- | --- | --- |
| Crop growth/price/sale table | `GameRules.GROWTH_NIGHTS`, `SEED_PRICES`, `SALE_VALUES` | **Change only two sale constants** |
| Crop stamina | `GameRules.action_cost()` and `effective_action_cost()` | Reuse without modification |
| Shipping settlement | `GameRules.shipment_payout()` / `GameSession` | Reuse; revise pinned test totals only |
| Almanac and inventory value | `AlmanacPanel`, Bag and Shipping panels | Reuse derived values; revise exact display expectations |
| Finale scoring | `ContentRules.build_harvest_result()` and existing tiers | Reuse, review one-Pumpkin threshold implication |
| Balance checks | Existing `GutTest` unit/integration suites | Add one rules-level niche test; update impacted literals |
| Visual verification | `./tools/verify-visual.sh`, `tests/visual/goldens` | Run native macOS check; re-bless changed captures only |

No service, registry, metric helper in production code, game-state field, screen, save migration, or extra test harness is justified.

## Task 0 — Check the base and old assumptions

- [ ] Rebase this PR branch onto latest `main` (it predates HPA-264's merged changes). Confirm HPA-263's passive clock, HPA-353's `SessionStateValidator`, HPA-264's target-driven farming and `SaveFileCodec.SCHEMA_VERSION = 3` are present. Do not alter the save schema or reintroduce selected-tool state.
- [ ] Run `./tools/verify-clean.sh` before editing; record baseline pass/fail and commit SHA in PR description. If local Godot 4.7.1/macOS verification is unavailable, say so instead of claiming a pass.
- [ ] Confirm no HPA-351 PR/branch has independently landed since the plan; keep changes here, never duplicate the ticket.
- [ ] Before updating expectations, grep the project tests/fixtures for literal `75`, `140`, `+70`, `840`, `1400`, `185`, `145` where they represent these prices or derived payouts (not unrelated times/coordinates/test fixtures). Review diffs rather than blanket-replacing numbers.

## Task 1 — Pin intended niches before implementation

- [ ] Add **one** focused `test_crop_niches_have_distinct_leaders()` (name illustrative) to `tests/unit/test_game_rules.gd`. Derive the metrics directly from `GameRules.seed_price()`, `sale_value()`, `growth_nights()` and `effective_action_cost()`.
- [ ] Check Turnip's growth nights are strictly shorter than both others (and thus latest safe Day-14 planting is Day 11).
- [ ] Check Potato's `(sale - seed) / (seed * nights)` strictly exceeds both others (use exact integer cross-products or uncomplicated float comparisons; no new runtime utility).
- [ ] Check Pumpkin's `(sale - seed) / (2 + nights * water_stamina)` strictly exceeds both others for **both** `watering_can_upgraded=false` and `true`. Confirm the crop results do not depend on changing `effective_action_cost()`.
- [ ] Verify the new test fails on current constants and passes with proposed constants. Keep existing `test_crop_table_is_closed_and_exact()` to pin actual values.

## Task 2 — Make the two-number runtime change

- [ ] In `scripts/game/game_rules.gd`, change **only** `SALE_VALUES` from `[35, 75, 140]` to `[35, 95, 150]`. Leave prices, nights, watering, world, saving, UI rendering and finale tier thresholds alone.
- [ ] Confirm all settlement callers still use `GameRules.sale_value()`; avoid copying price tables into HUD/Almanac or inventing a new state owner.
- [ ] Update exact constants in `tests/unit/test_game_rules.gd`: Potato 95, Pumpkin 150, mixed shipment payout line items 70/95/150 and total **315**.

## Task 3 — Re-pin consequential examples and visible values

- [ ] `tests/unit/test_game_session.gd` `test_public_potato_loop_reinvests_shipping_income()`: after shipping **205G**; after another seed **165G**.
- [ ] `tests/unit/test_game_session.gd` `test_balance_gate_two_hundred_gold_buys_real_throughput_by_day_nine()`:
  - Base remains six Pumpkins and **900G** shipped; starting 200G retained so final cash **1,100G**.
  - Efficient Can remains ten Pumpkins and **1,500G** shipped; 200G upgrade spent so final cash **1,500G**.
  - Keep **+4 crops**; uplift becomes **+600G shipped** and **+400G net final cash**.
  - Keep weather, travel, day 9 and stamina assertions; *do not* loosen throughput gates to fit the new prices.
- [ ] Preserve `test_representative_reinvestment_route_reaches_promising()` and `test_upgrade_purchase_keeps_reinvestment_route_intact()` unchanged at five Turnips, **175G**, `promising_farmer`. Investigate if either fails.
- [ ] `tests/integration/test_gameplay_shell.gd`: adjust the Bag Pumpkin payout display from `140G` to `150G`, Almanac Potato sale from `75G` to `95G`, and Pumpkin margin from `+70` to `+80`. Keep unrelated synthetic summary line amounts untouched when they are explicitly fixture values rather than game-rule payouts.
- [ ] In `tests/unit/test_content_rules.gd`, keep the current finale tier assertions and correct stale comments in `test_harvest_result_tier_boundaries()`: **2 Potatoes = 190G** (not 150G), **4 Potatoes = 380G** (not 300G). Rewrite the generic `300G + Close Friend` comment as `At least 300G + Close Friend` because this case now totals 380G. Avoid changing unrelated fixtures.
- [ ] Audit other literal payout/settlement expectations, including tests and snapshot fixtures. Change only ones derived from these crop prices.
- [ ] In `test_harvest_result_tier_boundaries()` **add an explicit one-Pumpkin boundary case**: `_result_for([0, 0, 1], [0, 0, 0])` yields `shipped_value == 150` and `tier == &"promising_farmer"`. Existing tests cover Potato tiers, **not** this new one-Pumpkin consequence. Keep `ContentRules.PROMISING_SHIPPED_VALUE == 150`, `HEART_SHIPPED_VALUE == 300` and the close-friend gate unchanged; do not retune tiers as part of HPA-351.

## Task 4 — Run evidence-based verification on the same PR

- [ ] Run `./tools/verify-clean.sh` (headless import, GUT unit/integration, project/world smokes).
- [ ] Run `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c` after the normal bootstrap if required.
- [ ] Inspect the Almanac, Bag/Shipping, and relevant morning/finale panels in native play or current visual capture. No art or layout redesign.
- [ ] On native macOS run `./tools/verify-visual.sh`. If specific production golden images change solely because displayed price values changed, inspect then manually update **only those files** with the documented `--update-goldens` workflow; re-run comparison. Do not regenerate the whole baseline or bless goldens on Linux/CI.
- [ ] If CI or local verification fails, separate pre-existing failures from regressions and record the exact command/output. Do not mark a checkbox complete without evidence.
- [ ] Update the draft PR's description with before/after balance table, actual test results, affected golden filenames, evidence, and any accepted deviation. Move it to Ready for Review only once implementation and native visual acceptance are complete.

## Acceptance / stop condition

Exactly one underlying balance change, `GameRules.SALE_VALUES = [35,95,150]`, demonstrates strict Turnip/Potato/Pumpkin niches under both watering tools. The Pumpkin upgrade benchmark, money totals, almanac displays, and finale gates remain internally consistent; unchanged five-Turnip completion is still viable. No new features, persisted fields, art, sound, or second PR.

## Risks and intentionally deferred work

- **Player outcome:** One Pumpkin at 150G crosses Promising's shipped-value threshold; record this in review and validate it subjectively, but change thresholds only in a separate ticket if playtest feedback calls for it.
- **Test data:** Synthetic UI fixtures can contain values like 80G or 300G unrelated to the new sale table. Preserve them unless they claim to represent `GameRules` payouts.
- **Visual goldens:** A 10G/20G label change alters pixels. Review actual diff and modify specific approved macOS screenshots, not reference artwork.
- **Completed HPA-264:** PR #24 is now integrated on `main` (including schema-v3 saves and target-driven farming). This branch forked before that integration; rebase it before implementing and avoid any input- or save-related diff. The numeric balance changes are independent.
