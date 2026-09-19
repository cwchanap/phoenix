# Phoenix Efficient Watering Can Implementation Plan

**Linear:** HPA-460  
**Branch:** `agent/hpa-460-watering-can-upgrade-plan`  
**Spec:** `docs/superpowers/specs/2026-09-18-phoenix-watering-can-upgrade-design.md`

**Goal:** Add one optional 200G efficient watering-can purchase that changes only successful single-tile watering stamina from 2 to 1, survives Continue, and proves that farming income can be reinvested without making the upgrade mandatory.

**Architecture:** Extend current owners only. `GameRules` owns the price and pure effective-cost policy; `GameSession` owns one boolean plus the purchase command; the existing HPA-459 `_cost_for()` seam feeds preview and real farming budgets; the current fixed `ShopPanel` gets one special fourth row; persistence keeps schema 2 and lets required-field validation reject older state with the existing incompatible-save path.

## Global constraints

- One ticket / one branch / one PR. Implementation continues on this draft PR after planning review.
- HPA-458 and HPA-459 are complete dependencies. Reuse `assets/ui/icons/watering-can-efficient.png` and HPA-459's structured preview/`_cost_for()` path.
- Keep `GameSession` as the only mutable gameplay authority.
- Keep manual tool selection, one-cell range, and hold-to-work behavior unchanged.
- Change only watering stamina after ownership; keep watering time and every other action cost unchanged.
- Do not add an upgrade framework, equipment inventory, catalog/SKU abstraction, migration adapter, second save slot, or new image/audio work.
- The final upgrade price starts at 200G. Only this one number may move, and only if Task 1's deterministic same-day-count throughput benchmark fails to show both higher shipped value and higher final money after paying for the can.
- Purchase spending never contributes to shipped/finale score.

## Task 1: Add rules, ownership, purchase command, and the balance gate

**Files:**  
`scripts/game/game_rules.gd`  
`scripts/game/game_session.gd`  
`tests/unit/test_game_rules.gd`  
`tests/unit/test_game_session.gd`  
`tests/unit/test_content_rules.gd`

### 1.1 RED/GREEN — add one rules-owned effective-cost policy

- [ ] Pin `WATERING_CAN_UPGRADE_PRICE == 200`.
- [ ] Base watering remains `{"minutes": 20, "stamina": 2}`; upgraded watering is `{"minutes": 20, "stamina": 1}`.
- [ ] Hoe, Seeds, and Hands effective costs are identical for false/true ownership.
- [ ] Add `GameRules.effective_action_cost(action, watering_can_upgraded)` by copying `action_cost(action)` and overriding only upgraded watering stamina.
- [ ] Return a fresh Dictionary; keep `ACTION_MINUTES`, `ACTION_STAMINA`, and `action_cost()` as the unchanged base table.

### 1.2 RED/GREEN — add the state bit and real purchase transition together

- [ ] Add `_watering_can_upgraded := false`.
- [ ] Add required `watering_can_upgraded` to `state()` / `snapshot()`, validate it as boolean in `state_error()`, and restore it in `restore_state()`.
- [ ] Change only `GameSession._cost_for(action)` to call `GameRules.effective_action_cost(action, _watering_can_upgraded)`.
- [ ] Add `WATERING_CAN_UPGRADED` / `WATERING_CAN_ALREADY_UPGRADED`.
- [ ] Implement `buy_watering_can_upgrade(target_cell)` with the existing `buy_seeds()` guard order: active day → exact shop cell → not already owned → sufficient funds.
- [ ] Success subtracts the rules-owned price, sets the boolean, and returns `_commit(WATERING_CAN_UPGRADED)`.
- [ ] Pin 150G insufficient, exact 200G success, 255G → 55G, duplicate no-op, wrong-location no-op, and inactive-day rejection.
- [ ] Pin that purchase changes only money + ownership; no stamina/time/seeds/harvest/shipment/social/finale/tutorial mutation.
- [ ] Assert `ContentRules.tutorial_for_code()` returns `&""` for both new codes; do not add them to `TUTORIALS`.

No test-only setter/private-field poke is needed: the real purchase command is the state transition from the first ownership-aware session test onward.

### 1.3 RED/GREEN — prove preview/command agreement and HPA-459 continuation

- [ ] Before purchase, HPA-459 preview reports watering cost 2; after purchase it reports 1.
- [ ] Real watering consumes the same cost at exact stamina boundaries.
- [ ] Rain still rejects watering before time/stamina spend in both ownership states.
- [ ] Keep the small arithmetic examples: six base waterings and twelve upgraded waterings each consume 12 stamina.
- [ ] Unit-level cost tests remain pure; session tests acquire ownership through `buy_watering_can_upgrade()`.

### 1.4 Balance gate — prove 200G buys real throughput before UI work

Create one prepared, deterministic larger-farm comparison. Use two otherwise identical sunny sessions restored from the same valid state:

- [ ] Day 1; **200G**; first **10** authored farm cells already tilled/empty; **10 Pumpkin seeds**; no relationship shortcut.
- [ ] Baseline keeps 200G and the base can.
- [ ] Upgrade route buys the can through `buy_watering_can_upgrade()`, leaving 0G.
- [ ] Day 1 complete Plant + Water costs 3 stamina base vs 2 upgraded, so pin **6** established Pumpkins baseline vs **10** upgraded.
- [ ] Maintain exactly those established crops for the same seven sunny watered nights, harvest/deposit, and settle. Both routes finish on **Day 9**.
- [ ] Baseline result: **6 crops / 840G shipped / 1040G final money**.
- [ ] Upgraded result: **10 crops / 1400G shipped / 1400G final money**.
- [ ] Pin the advantage: **+4 crops / +560G shipped / +360G final money after paying 200G**.
- [ ] Treat the supplied seed inventory as a balance fixture that isolates stamina throughput; do not turn this into a seed-acquisition simulation.

If this exact benchmark does not hold after implementation/tuning, stop before Task 2 and adjust only `WATERING_CAN_UPGRADE_PRICE`. Do not rebalance crops or stamina to rescue the upgrade.

**Checkpoint:** all focused rules/session/content unit tests green, including the throughput benchmark. The 200G price is mechanically defended before any shop UI work starts.

---

## Task 2A: Wire the upgrade through existing HUD/world seams

**Files:**  
`scripts/ui/shop_panel.gd` (signal only; no row/geometry yet)  
`scripts/ui/game_hud.gd`  
`scripts/world/world_shell.gd`  
`tests/integration/test_gameplay_shell.gd`

### 2A.1 RED/GREEN — add the explicit request chain

- [ ] Add `ShopPanel.upgrade_requested`.
- [ ] Forward it as `GameHud.upgrade_requested`.
- [ ] Connect `WorldShell._on_upgrade_requested()` to current target cell → `GameSession.buy_watering_can_upgrade()` → existing `_finish_command()`.
- [ ] Integration-drive the signal directly before the fourth scene row exists: wrong target stays `NOT_AT_SHOP`; valid target refreshes the session/HUD.
- [ ] Keep `buy_requested(kind, quantity)` untouched; never encode the upgrade as a fake crop kind.

### 2A.2 RED/GREEN — feedback, icon, SFX, and hold-to-work

- [ ] Add truthful feedback text for the two new command codes.
- [ ] Map `WATERING_CAN_UPGRADED` to `COMMERCE_SFX` beside `SEEDS_PURCHASED`; leave failures on the existing cancel/default path.
- [ ] In `GameHud.render()`, swap only Action_2's icon from `watering-can.png` to `watering-can-efficient.png` when the snapshot flag is true. World FX remains `watering-can-overlay.png`.
- [ ] Keep HPA-459 hint formatting untouched; after purchase a valid water preview must naturally read **1 stamina**.
- [ ] Prepare three eligible unwatered crops, acquire the upgrade through the real session command, then drive the existing hold seam across all three. Assert **20 → 17 stamina**: N=3 successful held waterings cost exactly N stamina.
- [ ] No new hold state, gesture rule, or E2E is introduced for this assertion.

**Checkpoint:** gameplay-shell integration green for request wiring, SFX/icon/hint, and upgraded hold-to-work. No shop scene geometry has changed yet.

---

## Task 2B: Add the fourth fixed shop row and prove its chrome immediately

**Files:**  
`scripts/ui/shop_panel.gd`  
`scenes/ui/shop_panel.tscn`  
`tests/integration/test_gameplay_shell.gd`  
existing visual state/golden `02-seed-shop`

### 2B.1 RED/GREEN — split navigation row from crop quantity state

- [ ] Add `_selected_row: int = 0` for navigation over 0..3.
- [ ] Keep `_selected_kind` permanently valid in 0..2; selecting crop rows updates it, selecting row 3 does not.
- [ ] Keep `selected_kind()` returning the last real crop even while row 3 is selected; add `selected_row()` for navigation assertions.
- [ ] `present()`, `_clamped_quantity()`, `_max_quantity()`, and every `seed_price()` call use only `_selected_kind`; they never receive `_selected_row`.
- [ ] Existing crop loop updates rows 0–2. Add one focused `_update_upgrade_row()` for row 3/footer instead of branching generic item logic through the crop loop.
- [ ] S/W navigation modulus is 4: S row3→Turnip, W Turnip→row3.
- [ ] Row 3 hides Minus/Plus/Quantity/Max; A/D/M do nothing.
- [ ] At 150G, footer remains **BUY · 200G** and Enter still emits one upgrade request so the session returns `INSUFFICIENT_FUNDS`.
- [ ] Owned footer is **OWNED** and Enter emits nothing; direct duplicate session command remains separately authoritative.

This shape prevents `GameRules.seed_price(3)` / `SEED_PRICES[3]` by construction, including during `present()` after a successful purchase refresh.

### 2B.2 GREEN — add the authored row and fixed geometry

- [ ] Add row 3 using `assets/ui/icons/watering-can-efficient.png`.
- [ ] Price comes from `WATERING_CAN_UPGRADE_PRICE`.
- [ ] Benefit copy formats the two effective watering costs, yielding **Water 2→1 STA** at current values; no hardcoded cost table.
- [ ] Pin Frame `x=128..512, y=24..336`; Header local `2..40`; Body `40..275`; rows `8..58`, `64..114`, `120..170`, `176..226`; Footer `275..310`.
- [ ] No scrolling/responsive shop framework.

### 2B.3 Checkpoint — native proof belongs here, not final cleanup

- [ ] Extend gameplay-shell integration for four-row wrap, crop-only `selected_kind()`, row-3 quantity no-ops, unaffordable Enter, successful purchase, immediate open-shop **55G + OWNED**, and Owned no-emit.
- [ ] Inspect the frame at native 640×360 and shipped integer 2× immediately after the scene move.
- [ ] Regolden **only `02-seed-shop`** now.
- [ ] Do not add a 15th **OWNED** visual state; integration pins it.
- [ ] Do not touch `05-almanac`.

**Checkpoint:** shop integration + native layout + `02-seed-shop` visual gate green before persistence work.

---

## Task 3: Prove required-field persistence and Continue compatibility

**Files:**  
`scripts/game/game_session.gd` (already owns field validation/restore from Task 1)  
`tests/unit/test_game_session.gd`  
`tests/integration/test_app_launch.gd`  
`tests/integration/test_gameplay_shell.gd`

### 3.1 Keep schema 2 and pin the loaded-but-incompatible path

- [ ] `SaveFileCodec.SCHEMA_VERSION` remains exactly 2; no codec implementation/test change.
- [ ] Save a current schema-2 state with `watering_can_upgraded` removed.
- [ ] Prove `SaveRepository.load()` returns `loaded`, then `GameSession.state_error()` rejects the missing field.
- [ ] AppRoot disables Continue with **“Save is incompatible; start a New Game.”**.
- [ ] Bypass the disabled Continue signal as the existing integration test does and prove no World launches.
- [ ] Non-boolean ownership follows the same required-field/state-validation path.
- [ ] Never default missing ownership to false; **“Save unavailable”** remains reserved for codec/I/O invalidity.

### 3.2 Overnight ownership contract at integration level

- [ ] Acquire the upgrade through the real session command.
- [ ] Sleep through the existing overnight save path; no mid-day save is added.
- [ ] Load the saved schema-2 state and restore a new `GameSession`.
- [ ] Assert ownership remains true and a valid watering preview/command still costs 1 stamina.
- [ ] At gameplay-shell level, render the restored snapshot and assert the efficient Action_2 icon; no second process launch is needed.

**Checkpoint:** app-launch + save/restore/gameplay-shell integration green. Persistence coverage ends here; E2E does not repeat it.

---

## Task 4: Keep economy safety, prove one real UI purchase, and close out

**Files:**  
`tests/unit/test_game_session.gd`  
`tests/e2e/gameplay_day_one_test.gd`  
`README.md` / `CLAUDE.md` only if current documentation covers the affected behavior

### 4.1 Keep the old route and add one economy-safety clone

- [ ] Keep `test_representative_reinvestment_route_reaches_promising()` behavior unchanged: five Turnips / 175G / `promising_farmer`.
- [ ] Clone it only to prove purchase accounting does not corrupt the existing route.
- [ ] After first settlement pin **255G → buy upgrade → 55G → buy two Turnip seeds → 15G**.
- [ ] Pin ownership true, final shipped **5 / 175G**, tier **`promising_farmer`**, **final_money = 85**, finale on Day 14, and no Day 15.
- [ ] Label this as economy-safety evidence, not the price justification; Task 1's larger-farm benchmark owns the 200G value proof.

### 4.2 One seeded, single-launch real-input E2E

Do not grow three starter Turnips and do not relaunch the child process.

- [ ] Add/reuse one helper that writes a valid schema-2 save before launch to the isolated `PHOENIX_SAVE_PATH`.
- [ ] Seed 255G, ownership false, intro acknowledged, and one tilled/planted/unwatered crop.
- [ ] Launch once and Continue.
- [ ] Target the real shop and navigate with real W/S input to row 3.
- [ ] Enter once; assert open-shop money **55** and **OWNED**.
- [ ] Esc; assert the primary signal — valid Water hint reads **1 stamina**.
- [ ] Also assert Action_2 uses `watering-can-efficient.png` as the secondary ownership accent.
- [ ] Water the prepared crop once through the real action path and assert success.
- [ ] Stop there. Task 3 already owns sleep/save/restore persistence; do not build a same-save relaunch harness.

### 4.3 Final native UX check — not a balance gate

- [ ] Reconfirm the shop at native 640×360 and shipped integer 2×; the actual golden update already happened in Task 2B.
- [ ] After Esc, verify the **1 stamina** preview is immediately obvious; this is the primary feedback.
- [ ] Explicitly check the three-pixel efficient-can glint still reads at the shipped integer 2× default; treat it as secondary feedback only.
- [ ] Record a short subjective before/after pacing note in the PR if useful, but do not use that note to defend or retune 200G. The deterministic Task 1 throughput benchmark owns that decision.

### 4.4 Documentation and final gates

Record the final ownership/cost seam in `CLAUDE.md` and player-facing upgrade behavior in `README.md` only if those documents already cover the corresponding area.

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit

./tools/bootstrap-gdunit.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c

./tools/verify-clean.sh
./tools/verify-visual.sh

godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"

git diff --check main...HEAD
```

## Scope guard

Do not add:

- more upgrades or tiers;
- equipment inventory / generic unlock state;
- shop catalogs, SKU types, registries, or data-driven commerce architecture;
- charged/AOE watering, range increase, can capacity/refill, durability, or passive stamina systems;
- global stamina/crop/economy rebalance;
- new art or SFX;
- save migrations, compatibility adapters, extra save slots, or mid-day autosave;
- a second PR for implementation.
