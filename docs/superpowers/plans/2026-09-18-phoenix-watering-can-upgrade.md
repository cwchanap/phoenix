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
- The final upgrade price starts at 200G. Only this one number may move if the required short play check disproves the intended reinvestment pacing.
- Purchase spending never contributes to shipped/finale score.

## Task 1: Add the rules-owned effective watering cost and one state bit

**Files:**  
`scripts/game/game_rules.gd`  
`scripts/game/game_session.gd`  
`tests/unit/test_game_rules.gd`  
`tests/unit/test_game_session.gd`

### 1.1 RED — pin the cost policy

Add focused `GameRules` tests:

- [ ] `WATERING_CAN_UPGRADE_PRICE == 200`.
- [ ] Base watering remains `{"minutes": 20, "stamina": 2}`.
- [ ] Upgraded watering is `{"minutes": 20, "stamina": 1}`.
- [ ] Hoe, Seeds, and Hands effective costs are byte-for-byte the same for false/true ownership.
- [ ] Six base waterings and twelve upgraded waterings both consume 12 stamina from a 20-stamina budget.

Do not rewrite `ACTION_STAMINA`; it remains the base rule table.

### 1.2 GREEN — add one pure effective-cost helper

- [ ] Add `GameRules.WATERING_CAN_UPGRADE_PRICE := 200`.
- [ ] Add `GameRules.effective_action_cost(action, watering_can_upgraded)`.
- [ ] Start from `action_cost(action)`; only override watering stamina to 1 when upgraded.
- [ ] Return a fresh Dictionary and do not mutate shared/base data.

### 1.3 RED/GREEN — add ownership to `GameSession`

- [ ] Add `_watering_can_upgraded := false`.
- [ ] Add `watering_can_upgraded` to `state()` and `snapshot()`.
- [ ] Update exact starter snapshot/state assertions.
- [ ] Change only `GameSession._cost_for(action)` to call `GameRules.effective_action_cost(action, _watering_can_upgraded)`.
- [ ] Prove HPA-459 `preview_selected_action()` reports 2 stamina before ownership and 1 after ownership.
- [ ] Prove real watering consumes the same cost at exact stamina boundaries.
- [ ] Keep rainy-day watering rejected before any time/stamina spend in both states.
- [ ] During Task 1 only, set `session._watering_can_upgraded = true` directly in focused unit tests to exercise the effective-cost seam before the purchase command exists. Do not add a production setter/test hook; Task 2 replaces this as the real state-transition proof.

**Checkpoint:** focused unit tests green. No shop or persistence changes yet.

---

## Task 2: Add one purchase command and one fourth shop row

**Files:**  
`scripts/game/game_rules.gd`  
`scripts/game/game_session.gd`  
`scripts/ui/shop_panel.gd`  
`scenes/ui/shop_panel.tscn`  
`scripts/ui/game_hud.gd`  
`scripts/world/world_shell.gd`  
`tests/unit/test_game_session.gd`  
`tests/unit/test_content_rules.gd`  
`tests/integration/test_gameplay_shell.gd`

### 2.1 RED — pin atomic purchase behavior

Add session tests for `buy_watering_can_upgrade(target_cell)`:

- [ ] 150G fresh state → insufficient funds and no mutation.
- [ ] Exactly 200G → success, money 0, ownership true.
- [ ] 255G → success leaves 55G.
- [ ] Duplicate purchase → dedicated already-owned failure and no money change.
- [ ] Wrong target → `NOT_AT_SHOP` and no mutation.
- [ ] Inactive/pending day state still uses the existing active-day guard.
- [ ] Successful purchase does not change stamina, time, seeds, harvested, pending shipment, shipped counts, relationships, tutorial progress, or finale fields.

### 2.2 GREEN — implement the narrow command

- [ ] Add `WATERING_CAN_UPGRADED` and `WATERING_CAN_ALREADY_UPGRADED` command codes.
- [ ] Implement validation in the same order as the design.
- [ ] Subtract `WATERING_CAN_UPGRADE_PRICE` and set the boolean only on success.
- [ ] Route success through the existing `_commit()`.
- [ ] Add `ContentRules` assertions that both new upgrade codes map to `&""`; do **not** add either code to `TUTORIALS`, so buying the can cannot complete Reinvest / seed purchase.
- [ ] Add truthful `GameHud.feedback_text()` strings.
- [ ] Map `WATERING_CAN_UPGRADED` to `COMMERCE_SFX` in the same match arm as `SEEDS_PURCHASED`; the current default is cancel feedback, so this mapping is required. No new stream.

### 2.3 RED — extend current shop keyboard behavior

Update integration coverage around the existing shop panel:

- [ ] Selected row is 0..3; S wraps row 3 → row 0 and W wraps row 0 → row 3. Navigation modulus is 4, not `CropKind.size()`.
- [ ] Rows 0–2 keep current A/D/M quantity behavior and Enter emits `buy_requested(kind, quantity)`; existing `selected_kind()` remains crop-only for these rows so `test_shop_keyboard_rows_update_quantity_max_and_enter_request` keeps its contract.
- [ ] Row 3 hides Minus/Plus/Quantity/Max; A/D/M are no-ops.
- [ ] At 150G, row 3 remains visible and footer still says **BUY · 200G**; Enter emits exactly one `upgrade_requested`, then the session returns `INSUFFICIENT_FUNDS`.
- [ ] With enough money, the same request succeeds.
- [ ] Owned row renders footer **OWNED** and panel Enter emits nothing; a direct duplicate session call remains covered separately.
- [ ] Existing crop-row tests keep their behavior; do not replace them with broad UI snapshots.

### 2.4 GREEN — add the row without a shop framework

- [ ] Use one panel-local selected row index; derive crop kind only for rows < `GameRules.CropKind.size()`. Keep `selected_kind()` crop-only and expose row selection separately if tests need it.
- [ ] Add `UPGRADE_ROW := GameRules.CropKind.size()`; no SKU/product enum outside this panel.
- [ ] Add `ShopPanel.upgrade_requested`.
- [ ] Forward as `GameHud.upgrade_requested`.
- [ ] Connect in `WorldShell` to `_on_upgrade_requested()`, using current target cell and `_finish_command()`.
- [ ] Add one fourth row to `shop_panel.tscn` using `assets/ui/icons/watering-can-efficient.png`.
- [ ] Price comes from `WATERING_CAN_UPGRADE_PRICE`; benefit copy formats base/upgraded watering stamina from two `effective_action_cost()` calls instead of hardcoding `2→1`.
- [ ] Footer is **BUY · 200G** whenever unowned (including 150G) and **OWNED** when owned.
- [ ] Pin the fixed 640×360 geometry: Frame `x=128..512, y=24..336`; Header local `y=2..40`; Body `y=40..275`; rows at Body `8..58`, `64..114`, `120..170`, `176..226`; Footer local `y=275..310`.
- [ ] Keep seed quantity controls hidden on row 3 rather than inventing fake ×1 semantics. No scrolling.

### 2.5 GREEN — update the immediate read surfaces

- [ ] When `watering_can_upgraded` is true, `GameHud.render()` swaps only Action_2's icon to `watering-can-efficient.png`; world FX stays on `watering-can-overlay.png`.
- [ ] Keep the same action slot and same `WATERING_CAN` action.
- [ ] While ShopPanel is open, HUD chrome is hidden: only shop money + **OWNED** are immediately visible through the existing `_finish_command() → render() → present()` path.
- [ ] After Esc, the already-rendered Action_2 icon is visible and the next valid watering target automatically shows **1 stamina** through HPA-459 preview. Do not special-case hint text or add another refresh.
- [ ] Leave Almanac untouched.

**Checkpoint:** unit + gameplay-shell integration green; inspect the shop once at native 640×360.

---

## Task 3: Persist ownership as a required schema-2 state field

**Files:**  
`scripts/game/game_session.gd`  
`tests/unit/test_game_session.gd`  
`tests/integration/test_app_launch.gd`  
`tests/integration/test_gameplay_shell.gd`

### 3.1 RED — pin state validation and restore

- [ ] `GameSession.state_error()` rejects missing `watering_can_upgraded`.
- [ ] It rejects non-boolean values.
- [ ] `restore_state()` restores both false and true.
- [ ] A restored true state immediately returns 1-stamina watering preview/cost.
- [ ] New `GameSession` still starts false.
- [ ] `SaveFileCodec.SCHEMA_VERSION` remains exactly 2; no codec test or codec implementation change is needed.

### 3.2 GREEN — add the required field

- [ ] Validate `watering_can_upgraded` next to the existing simple boolean/scalar fields.
- [ ] Restore it into `_watering_can_upgraded`.
- [ ] Do not infer ownership from money, icon, shop state, or past actions.
- [ ] Never default a missing field to false.

### 3.3 RED/GREEN — pin the existing Continue incompatibility path

- [ ] In `test_app_launch.gd`, create/save a schema-2 current state with `watering_can_upgraded` removed.
- [ ] Prove `SaveRepository.load()` still returns `loaded` (codec accepted schema 2).
- [ ] Prove AppRoot disables Continue with **“Save is incompatible; start a New Game.”** through `GameSession.state_error()`.
- [ ] Bypass the disabled Continue signal as the existing test does and prove no World launches.
- [ ] Keep **“Save unavailable”** reserved for codec/I/O invalid states; do not manufacture an Unsupported-schema path.

### 3.4 Integration — overnight ownership contract

- [ ] Buy the upgrade.
- [ ] Sleep through the existing overnight save path.
- [ ] Restore/Continue from the resulting state.
- [ ] Assert ownership, Action_2 icon, and 1-stamina watering behavior remain true after leaving any blocking modal.
- [ ] Do not add a mid-day save after purchase.

**Checkpoint:** state-validation/app-launch/gameplay-shell suites green.

---

## Task 4: Prove reinvestment, optionality, and the shipped UI path

**Files:**  
`tests/unit/test_game_session.gd`  
`tests/integration/test_gameplay_shell.gd`  
`tests/e2e/gameplay_day_one_test.gd`  
`README.md` / `CLAUDE.md` only if behavior/ownership docs need updating

### 4.1 Keep the existing no-upgrade route

- [ ] Do not change existing crop values, starter resources, stamina cap, finale thresholds, or no-upgrade Day-14 expectations.
- [ ] Run the existing five-Turnip/175G Promising route unchanged.
- [ ] If a test needs edits only because the snapshot gained one boolean, keep its behavior assertions otherwise identical.

### 4.2 Add one deterministic upgrade/reinvestment route

At session level, pin the reference economy:

- [ ] Start 150G.
- [ ] Ship/settle the three starter Turnips → 255G.
- [ ] Buy efficient can → 55G.
- [ ] Buy two Turnip seeds → 15G.
- [ ] Clone `test_representative_reinvestment_route_reaches_promising()` and insert the upgrade after the first shipment settlement, before buying the two new Turnip seeds.
- [ ] Pin money **255 → 55 → 15** and `watering_can_upgraded == true`.
- [ ] Continue the same two-Turnip second crop and settlement.
- [ ] Pin result **shipped_count = 5**, **shipped_value = 175**, **tier = promising_farmer**, and **final_money = 85**.
- [ ] Assert upgrade spending never increments shipped counts or finale score inputs.
- [ ] Assert finale is on Day 14 and no Day 15 exists.

Do not duplicate the whole finale as a second end-to-end UI test.

### 4.3 One focused real-input E2E

Extend the existing gameplay E2E seam without simulating the four-day starter economy:

- [ ] Add/reuse a helper that writes a valid schema-2 save to the isolated `PHOENIX_SAVE_PATH` before launch.
- [ ] Seed that save at 255G with `watering_can_upgraded = false`, intro acknowledged, and one tilled/planted/unwatered crop; use current state shape rather than a special production test hook.
- [ ] Launch via Continue, target the real shop, and use real W/S keyboard navigation to the can row.
- [ ] Press Enter and assert open-shop money becomes **55** and the row becomes **OWNED**.
- [ ] Esc the shop; then assert Action_2 uses the efficient icon and a valid watering target hint reports **1 stamina**.
- [ ] Water once through the real action path.
- [ ] Sleep and wait for the normal save confirmation.
- [ ] Relaunch against the same isolated save and Continue.
- [ ] Assert ownership/icon/1-stamina behavior persists.

Reuse existing shop/sleep/positioning helpers and save isolation. No new E2E harness and no in-E2E crop-growth loop.

### 4.4 Native visual/pacing check

- [ ] Inspect the shop at 640×360 and integer 2×: four rows fit, footer is readable, upgrade row is keyboard-visible, Owned is legible.
- [ ] Inspect base vs upgraded watering hint/toolbar icon.
- [ ] Run the existing visual workflow and update **only `02-seed-shop`**; the fourth row/frame necessarily changes that production state.
- [ ] Do not add a 15th visual state for **OWNED**; pin Owned in gameplay-shell integration.
- [ ] Do not update `05-almanac` or unrelated goldens.
- [ ] Record the short before/after pacing observation in the PR.
- [ ] Keep 200G unless this check demonstrates the required route is not a useful early reinvestment; if changed, update the one rules constant and its tests/evidence only.

### 4.5 Documentation and final gates

Record the final ownership/cost seam in `CLAUDE.md` and player-facing upgrade behavior in `README.md` only if those documents currently cover the corresponding area.

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
