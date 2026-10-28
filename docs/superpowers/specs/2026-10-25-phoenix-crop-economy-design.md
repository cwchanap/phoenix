# HPA-351 — Crop economy: distinct crop niches (design specification)

**Status:** Revised proposal / planning only; no runtime implementation in this draft PR  
**Linear:** https://linear.app/cwchanap/issue/HPA-351/economy-give-each-crop-a-distinct-niche  
**Repository:** `cwchanap/phoenix`  
**Prerequisites:** HPA-263 and HPA-353 completed; HPA-264 merged. Rebase the planning branch onto current `main` before implementation.  
**Decision:** Accept PR #25 design review #2: discount Potato seed **40G → 30G** instead of changing Potato/Pumpkin sale values. This supersedes the earlier 95G/150G sale-price proposal.

## Player problem and intended decision

Currently Turnip yields a quick return and can be grown late in the 14-day season; Pumpkin returns the most net profit per tending stamina. Potato leads neither useful economic measure. Fix the dominated middle choice by adjusting **one existing seed-price constant**, not by adding another system.

Each crop should win one distinct primary axis:

- **Turnip:** fastest harvest (3 nights), earliest cash-back **in time**, and latest viable planting on Day 11. It is the only crop newly plantable on Days 10–11 that can mature for the Day 14 market. **Do not claim that Turnip has the best normalized return on seed money**: Potato owns that axis under the new price.
- **Potato:** best net return relative to seed capital *per growth night* (0.300) and a practical cash-tight seed purchase (30G). Longer growing time is the trade-off.
- **Pumpkin:** best net profit per tending stamina, both with a normal watering can and the Efficient Can. Seven nights of care and 70G of upfront seed capital remain its trade-offs.

## Verified current ownership (main, review #2)

- `scripts/game/game_rules.gd` owns `GROWTH_NIGHTS=[3,5,7]`, `SEED_PRICES=[20,40,70]`, `SALE_VALUES=[35,75,140]`, and all effective action-cost calculations. Purchase code calls `seed_price()`; shipment settlement calls `sale_value()`.
- `scripts/ui/shop_panel.gd` and `scripts/ui/almanac_panel.gd` render seed prices from `GameRules`; Almanac margin is also derived from `sale_value() - seed_price()`. No new rendering logic is needed.
- `scripts/game/content_rules.gd` scores shipped crops using sale values and the existing 150G Promising / 300G Heart thresholds. No scoring change is needed. `tests/unit/test_content_rules.gd` uses **two Potatoes = exactly 150G** and **four Potatoes = exactly 300G** to pin inclusive tier boundaries; preserve these exact boundary fixtures.
- HPA-264 landed on `main`, replacing manual farming-tool selection and introducing **save schema v3**. This economy ticket does not modify controls, persistence or save schema. Compatible v3 saves remain valid; older v2 saves remain unsupported.

## Proposed constants

| Crop | Seed before → after | Sale unchanged | Grow (watered nights) | Net profit after | Latest planting for Day 14 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Turnip | 20G → 20G | 35G | 3 | 15G | Day 11 |
| Potato | **40G → 30G** | 75G | 5 | 45G | Day 9 |
| Pumpkin | 70G → 70G | 140G | 7 | 70G | Day 7 |

Metric formulas (evaluate using actual `GameRules` costs, not duplicated constants):

- `profit = sale_value - seed_price`
- `return_on_seed_per_night = profit / (seed_price * growth_nights)`
- `tending_stamina = effective_action_cost(SEEDS, upgraded).stamina + growth_nights * effective_action_cost(WATERING_CAN, upgraded).stamina + effective_action_cost(HANDS, upgraded).stamina`
- `profit_per_stamina = profit / tending_stamina`

The comparison deliberately excludes one-time hoeing on an already prepared tile; harvested tiles stay tilled. Walking and the passive day clock are separate constraints, not part of the defined *tending-stamina* metric.

| Crop | Return / seed-G / night | Profit / stamina, normal can | Profit / stamina, Efficient Can |
| --- | ---: | ---: | ---: |
| Turnip | 0.250 | 1.875 | 3.000 |
| Potato | **0.300** | 3.750 | 6.429 |
| Pumpkin | 0.143 | **4.375** | **7.778** |

Each lead is strict. The discounted Potato seed increases separation between Potato and Turnip on seed-capital return without crowding Pumpkin on stamina efficiency.

## Player impact and constraints

1. **Purchasing:** Potato seeds cost 30G. At 150G, five Potato seeds are affordable instead of three; the trade-off is that they take five nights and cannot be started as late as Turnips. Include this in the native playtest.
2. **Display:** The Shop row shows 30G instead of 40G; the Almanac shows 30G seed and **+45G** margin instead of +35G. Everything renders from existing `GameRules` calls. Inspect native captures `02-seed-shop` and `05-almanac`; other goldens should stay byte-identical unless evidence shows otherwise.
3. **Unchanged payouts:** Mixed shipment of 2 Turnips + Potato + Pumpkin is still **285G**. Bag/Shipping values, shipment settlement, morning summaries, Result/Heart fixtures (including **645G**), and both finale thresholds remain unchanged. A single Pumpkin still sells for 140G and **does not** reach the 150G Promising value threshold without a friendship.
4. **Unchanged benchmark:** Efficient Can test still proves six vs ten Pumpkins, **840G vs 1400G shipped**, **1040G vs 1400G final cash**, **+560G shipped / +360G final cash**. Five Turnips still produce **175G** and `promising_farmer`.
5. **Persistence:** No state or `SaveFileCodec` changes; existing supported schema-v3 saves remain valid and future seed purchases use the new price. No backward-compatibility work.
6. **Assets:** No new sprites, audio, UI widgets or systems. Re-bless only native visual goldens actually changed after visual inspection.

## Acceptance

- Add **one** pure `test_game_rules.gd` niche-ranking test deriving every action cost via `effective_action_cost()`. Assert Turnip has the shortest growth and latest safe planting, Potato uniquely leads seed-money return per night, and Pumpkin uniquely leads net profit per tending stamina for upgraded and regular watering.
- The test fails against `SEED_PRICES=[20,40,70]` and passes after **only** `SEED_PRICES=[20,30,70]` is changed.
- Update affected exact tests: Potato seed constant 30; two-Potato purchase leaves **90G**; Potato shipment/reinvestment money becomes **195G**, then **165G**. Preserve the exact 150G/300G tier boundary fixtures.
- Re-run existing shipment, Can, Turnip-only finale and UI regression suites without modifying their payout expectations. Native visual acceptance evaluates the changed Shop and Almanac screenshots; no blanket re-blessing.

## Non-goals

No sale-value changes, price volatility, new crops, plot mechanics, stamina/time/season retuning, result threshold adjustment, extra testing framework, save migration, input changes, new art or sound. **One ticket, one PR**: implement on this same draft PR after the design is reviewed.
