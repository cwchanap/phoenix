# HPA-351 — Crop-economy niches: single-PR implementation plan

**Status:** Implemented on this PR; all tasks below ran — see the execution ledger for commands and results  
**Design:** [2026-10-25-phoenix-crop-economy-design.md](../specs/2026-10-25-phoenix-crop-economy-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-351/economy-give-each-crop-a-distinct-niche  
**Delivery model:** Implement on **this same draft PR**. No extra Linear ticket, PR, runtime abstraction, asset-production task or migration.

## Decision after design review #2

**Replace the earlier two-sale-value proposal with one seed-price change:**

```gdscript
# scripts/game/game_rules.gd
const SEED_PRICES: Array[int] = [20, 30, 70] # was [20, 40, 70]
# SALE_VALUES stays [35, 75, 140]
```

This is less work and preserves existing shipped-value behavior. In particular **do not** change the 285G mixed shipment, 840G/1400G Pumpkin benchmark, 645G Heart fixture, 150G/300G tier boundary tests, Bag payout displays, or result visual goldens merely because they appeared in the previous plan.

Turnip's niche is **fastest maturity / last safe planting (Day 11)**, not highest seed-money return. Potato now leads the cash-efficiency metric at 0.300 per seed-G per night; Pumpkin leads net profit per tending stamina. The extra buying power at 150G (five rather than three Potato seeds) is an intentional trade-off to playtest.

## Reuse survey: existing owners

| Need | Owner / existing contract | Work |
| --- | --- | --- |
| Crop economics | `GameRules.SEED_PRICES` and `seed_price()` | One price literal (40 → 30) |
| Sale and settlement | `GameRules.SALE_VALUES`, `sale_value()`, `shipment_payout()` | No changes |
| Effective action stamina | `GameRules.effective_action_cost()` | Reuse to calculate all three farming-action costs in niche test |
| Seed purchasing | `GameSession.buy_seeds()` | No logic changes; update exact money assertions |
| Shop / Almanac | `ShopPanel` / `AlmanacPanel` render from `GameRules` | No logic changes; inspect changed prices/margins |
| Finale scoring | `ContentRules.build_harvest_result()` | No code or boundary-test changes |
| Test harness | Existing GUT, GdUnit4, E2E, native visual verifier | Reuse without new harness |

## Task 0 — Base verification

- [x] Rebase the PR's existing planning branch onto current `main` (HPA-264 is already merged and this branch diverged before it). Confirm `SaveFileCodec.SCHEMA_VERSION = 3`, target-driven farming, HPA-263 clock and `SessionStateValidator` survive unchanged.
- [x] Record the starting base commit SHA. Run `./tools/verify-clean.sh` *before implementation* and write the true baseline result (or explicit environment blocker) into the PR.
- [x] Inspect exact-price and purchased-money assertions, searching by contexts (`seed_price(POTATO)`, `buy_seeds(POTATO`, `"money"`, `"30G"`, `"40G"`, `"+35"`) as well as raw `40`, `70`, `145`, `185`. Do not blanket-replace unrelated prices or numeric fixtures.
- [x] Keep the PR at **one HPA-351 ticket → one PR**; do not revive the already completed HPA-264 work.

## Task 1 — Write one red metric test

- [x] Add one focused `test_crop_niches_have_distinct_leaders()` to `tests/unit/test_game_rules.gd`.
- [x] Compute `seed = GameRules.seed_price(kind)`, `sale = GameRules.sale_value(kind)`, `nights = GameRules.growth_nights(kind)`, and `profit = sale - seed` for each of the three crops. Check `TURNIP` has strictly shortest nights / latest safe planting.
- [x] Assert `POTATO` uniquely maximizes `profit / (seed * nights)`. Compare exact cross-products or floats; avoid any duplicated production metric API.
- [x] For **both** `upgraded=false` and `true`, compute
  `tending_stamina = int(GameRules.effective_action_cost(GameRules.FarmingAction.SEEDS, upgraded)["stamina"]) + nights * int(GameRules.effective_action_cost(GameRules.FarmingAction.WATERING_CAN, upgraded)["stamina"]) + int(GameRules.effective_action_cost(GameRules.FarmingAction.HANDS, upgraded)["stamina"])`.
  Assert `PUMPKIN` strictly maximizes `profit/tending_stamina`. **Do not hardcode planting + harvest as 2**: those costs are rules-owned and may change.
- [x] Verify the test fails against current prices (`SEED_PRICES=[20,40,70]`), then passes after the planned constant change.

## Task 2 — Make the single runtime change

- [x] Change `scripts/game/game_rules.gd` `SEED_PRICES` from `[20, 40, 70]` to `[20, 30, 70]`. **Do not change `SALE_VALUES`, growth nights, watering/stamina, clock, save format, or finale thresholds.**
- [x] Update `tests/unit/test_game_rules.gd` Potato seed-price assertion from **40** to **30**. Keep payout assertions unchanged at 75G Potato, 140G Pumpkin and 285G mixed shipment.

## Task 3 — Re-pin purchasing money and protect unchanged results

- [x] `tests/unit/test_game_session.gd` — `test_buy_seeds_validates_target_quantity_and_funds_atomically()`: two Potato seeds now leave **90G** from 150G, not 70G.
- [x] `tests/unit/test_game_session.gd` — `test_public_potato_loop_reinvests_shipping_income()`: after buying one Potato (30G) and shipping it for 75G, money becomes **195G** (previously 185G); after buying another Potato, **165G** (previously 145G).
- [x] Run the red suite and audit additional exact purchase totals that a literal grep may miss. Adjust only expectations whose derivation uses the **seed price**. Do not update results whose derivation uses unchanged **sale values**.
- [x] Preserve `tests/unit/test_content_rules.gd`'s **2 Potatoes = 150G** Promising and **4 Potatoes = 300G** Heart boundary vehicles; these continue to pin inclusive `>=` behavior. Do **not** add the previously proposed one-Pumpkin-at-150G assertion (one Pumpkin is still 140G).
- [x] Preserve the six-vs-ten-Pumpkin Efficient Can benchmark (**840G / 1400G shipped; 1040G / 1400G final cash; +360G** after upgrade), the five-Turnip `promising_farmer` route (**175G**), `test_gameplay_shell.gd` Bag total (**325G**), app/visual result totals (**645G**), and mixed shipment total (**285G**). Failures there are regressions, not new targets.
- [x] Confirm Shop Potato price **30G** and Almanac seed **30G** / margin **+45G** are rendered using existing `GameRules` code. Update any directly asserted UI purchase-value literals if the test suite reveals them; avoid editing unrelated panel logic.

## Task 4 — Verify on the same PR and record evidence

- [x] Run `./tools/verify-clean.sh`, then the existing GdUnit4 and real-input E2E suites (bootstrap test addons if needed). Record exact commands, run environment, and counts; don't claim unrun checks.
- [x] On native macOS, run `./tools/verify-visual.sh`. Inspect `02-seed-shop` and `05-almanac` before manually re-blessing only their changed **production** goldens with documented `--update-goldens`. Re-run compare afterward. If a different captured state genuinely changes, inspect and explicitly justify it rather than assuming the review's list is exhaustive.
- [x] Keep `04-bag` and `14-result-heart-of-harvest` goldens unchanged unless an independently grounded regression says otherwise. Do not auto-bless all 14 captures or use Linux CI to update macOS goldens. **Review round 3 update:** `04-bag` was legitimately re-blessed after the Bag detail copy was updated to name each crop's niche (see ledger).
- [x] Update this PR description with final price table, actual test results, specific changed golden names, and unresolved subjective playtest observations. Move from Draft to Ready only after implementation and native acceptance are complete.

## Acceptance / stop condition

Exactly one runtime constant edit gives Turnip the shortest time-to-harvest and latest Day 14 planting, Potato the best `(sale - seed)/(seed * nights)`, and Pumpkin the best `(sale - seed)/tending_stamina` for *both* watering-can modes. No payout, finale, farming input, save or UI architecture changes. Existing baseline numeric contracts stay fixed except three seed-related money assertions and one seed-price assertion.

## Remaining small risks

- **Cash availability:** Five Potato seeds are purchasable with the initial 150G. Native playtest should assess whether that makes Potato too attractive despite a five-night delay; do not add dynamic pricing, inventory caps or new mechanics speculatively.
- **Golden drift:** Only Shop and Almanac are expected to change, but use actual capture diffs before updating.
- **Base drift:** The planning branch was created before HPA-264 merged; rebase to latest `main` before implementation. Re-run tests after rebase rather than assuming old checks apply.

## Execution ledger

- **Base:** branch rebased onto `main` @ `05f9383`; pre-implementation `./tools/verify-clean.sh` green (263 tests / 4334 asserts, macOS, Godot 4.7.1).
- **Landing:** `SEED_PRICES [20,40,70] → [20,30,70]` plus the niche test (`c5c97f4`), the session-money re-pins (`73d70ff`), and the Shop/Almanac golden re-bless (`8bdd43a`). A later review flagged that these land as three commits rather than one, so `c5c97f4`/`73d70ff` each fail a release gate standalone; the split was kept to avoid rewriting pushed history.
- **Post-implementation gates:** `./tools/verify-clean.sh` green (264 tests / 4346+ asserts); `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` 12/12; `-a tests/e2e -c` 7/7; `./tools/verify-visual.sh` all 14 states pass.
- **Goldens:** `02-seed-shop` (price digit) and `05-almanac` (seed + margin digits) re-blessed; the first `02` `--update-goldens` run blessed an intermittent black first frame and was re-blessed from a verified true capture. Review round 3 added `04-bag` (Bag detail now names each crop's niche) and hardened `capture_root()` in `tests/visual/ui_capture_host.gd` to retry until a non-uniform frame and fail the capture on a persistent blank, so no blank frame can reach `--update-goldens` again.
- **Review round 3 fixes:** niche test rewritten (direct shortest-nights and positive-profit asserts, `range(CropKind.size())` indexing, hoisted action costs, failure messages naming the mode); `buy_seeds` prompt now reads `SEED_PRICES.min()` instead of assuming Turnip is cheapest; Bag descriptions name Turnip's late-planting and Potato's capital-return niches; Shop/Almanac scene placeholders updated to 30G/+45; the Linux-CI integration test now asserts rendered Shop row prices and Almanac Card_1 seed/margin; the frozen UI-contract fixture row and the stamina-lead wording in the design doc were corrected.
