# HPA-351 — Crop-economy niches: design specification

**Status:** Proposed / planning only (no runtime changes in this PR)
**Linear:** https://linear.app/cwchanap/issue/HPA-351/economy-give-each-crop-a-distinct-niche
**Repository:** `cwchanap/phoenix`
**Prerequisite:** HPA-263 (Done); do not duplicate HPA-264's separate work.

## Problem and desired player decision

Current `GameRules` crop constants produce a dominated middle option. Turnip has the shortest growth cycle and quickest capital recovery; Pumpkin has the highest profit per unit of watering stamina. Potato wins neither. Keep the exact three-crop, 14-day game and make each choice distinct using *only sale-price tuning*:

- **Turnip:** fastest cash-back cycle and latest viable planting (3 growth nights, Day 11).
- **Potato:** highest profit relative to seed cost *per growth night*.
- **Pumpkin:** highest net profit per tending stamina in both base- and upgraded-watering scenarios.

This is a small economy decision, not a new progression system or a change to time/stamina rules.

## Existing code contracts (initially checked on main, 2026-10-25; rechecked 2026-10-27)

- `scripts/game/game_rules.gd` owns `GROWTH_NIGHTS=[3,5,7]`, `SEED_PRICES=[20,40,70]`, `SALE_VALUES=[35,75,140]`, and the effective action-cost seam. `shipment_payout()` derives settlement amounts from `sale_value()`.
- `scripts/game/content_rules.gd` derives finale shipped value from `GameRules.sale_value()`. Its `PROMISING_SHIPPED_VALUE=150` and `HEART_SHIPPED_VALUE=300` thresholds remain unchanged; Heart also requires a close friend.
- `scripts/ui/almanac_panel.gd` already derives crop prices, sale values and margins from `GameRules`; `scripts/ui/bag_panel.gd` likewise shows sale-derived payout.
- `tests/unit/test_game_rules.gd` pins exact sale values and an itemized mixed shipment. `tests/unit/test_game_session.gd` pins the Potato reinvestment example and Pumpkin-based Efficient Can benchmark. `tests/integration/test_gameplay_shell.gd` pins several displayed values.
- HPA-264 PR #24 has since landed on `main`: it changed farming-action selection and bumped the save format to schema v3. HPA-351 must not alter the resulting commands, saves, or UI action selection. Rebase this planning branch onto the updated `main` before implementing.

## Proposed constants

| Crop | Seed | Grow (watered nights) | Sale before → after | Net profit after | Latest planting for Day 14 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Turnip | 20G | 3 | 35G → **35G** | 15G | Day 11 |
| Potato | 40G | 5 | 75G → **95G** | 55G | Day 9 |
| Pumpkin | 70G | 7 | 140G → **150G** | 80G | Day 7 |

**Metric definitions:** `profit = sale - seed`; `cash_return_per_night = profit / (seed_cost * growth_nights)`; `tending_stamina = 1 plant + growth_nights * watering_stamina + 1 harvest`; `profit_per_stamina = profit / tending_stamina`. As in the Linear issue, the comparative stamina metric excludes the one-time cost of hoeing and transit; it compares the recurring crop cycle on prepared soil. The daily passive clock is an independent constraint, not part of these three headline metrics.

| Crop | Return on seed cash / night | Profit / stamina (base 2-stamina water) | Profit / stamina (Efficient Can 1-stamina water) |
| --- | ---: | ---: | ---: |
| Turnip | 0.250 | 1.875 | 3.000 |
| Potato | **0.275** | 4.583 | 7.857 |
| Pumpkin | 0.163 | **5.000** | **8.889** |

Thus each crop strictly wins a distinct *binding* axis: growth time, seed-cash return per growth night, and profit per tending stamina. Prices and progression stay straightforward.

## Player-facing behavior and implications

1. **No new mechanics:** retain all seeds, growth nights, seasons, watering stamina, rainy weather, shops, inventories and existing interaction input.
2. **Updated displayed prices:** Potato sale 95G, margin +55G; Pumpkin sale 150G, margin +80G. Shops' *seed purchase prices* stay unchanged. Derived Bag, shipping, morning-settlement, Almanac and finale displays update through existing code.
3. **Threshold side effect is intentional to review:** One shipped Pumpkin now reaches the 150G Promising value threshold by itself, whereas it formerly yielded 140G. A 300G Pumpkin pair reaches the Heart *value* bar only; a close friend remains mandatory. Keep current tiers unless a native playtest demonstrates a concrete issue.
4. **No save schema change:** `SaveFileCodec.SCHEMA_VERSION` is **3** on current `main` (HPA-264 intentionally rejects older v2 saves). Saves contain crop counts and balances, not a persisted copy of sale-price constants. Compatible schema-v3 saves remain readable; future shipment settlements and result calculations use the newly tuned values. Do not add migration, versioning, or compatibility code.
5. **No art or audio:** the existing Almanac asset and layout are reused. Update native production visual goldens *only for actually changed captured states* after inspecting diffs; likely Almanac and other screens showing prices, but do not auto-bless wholesale.

## Acceptance criteria

- One small pure-rules test computes each metric using `GameRules` and asserts strict winners: Turnip for shortest growth / latest planting, Potato for seed-cash return per night, Pumpkin for stamina efficiency both with and without Efficient Can.
- Existing exact-value assertions are reconciled without weakening guard tests. Mixed shipment `2 turnips + 1 potato + 1 pumpkin` now pays **315G** (70+95+150).
- Potato reinvestment settlement becomes 205G after one Potato (150−40+95), then 165G after buying another 40G seed.
- The Pumpkin throughput benchmark keeps **6 vs 10 crops**. Shipped value becomes **900G vs 1,500G**; final money **1,100G vs 1,500G** (200G initial balance, upgraded route spends 200G); uplift **+600G shipped, +400G final money**.
- The Turnip-only five-crop Promising route remains **175G / promising_farmer** unchanged.
- Explicitly pin the result of **one shipped Pumpkin, no friendships**: 150G shipped and `promising_farmer`. Keep the 150G Promising and 300G Heart thresholds unchanged; the Heart tier still requires a close friend.
- Update stale Potato fixture comments in `tests/unit/test_content_rules.gd`: two Potatoes become **190G** (not 150G), four become **380G** (not 300G); existing valid tier assertions stay in place. Check the displayed Almanac/Bag values; no change to their computation code is anticipated.
- Existing clean verifier, GdUnit4, E2E and macOS visual regression run after implementation. Record actual results and review any changed visual capture before blessing.

## Deliberately excluded

No new crops, regrowth, plot-balance mechanics, watering rules, price volatility, season systems, alternate scoring, art, or SFX. No refactor outside the files directly affected by changed constants/expectations. **One HPA-351 issue → one PR** (the current draft is the planning phase of that eventual implementation PR).
