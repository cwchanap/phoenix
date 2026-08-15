# Phoenix Three-Crop Economy Design (HPA-593)

**Status:** Approved for implementation planning

**Date:** 2026-08-15

**Delivery target:** macOS-first browser and Tauri economy slice

## Source of truth

This design implements the fourth active slice under [HPA-587](https://linear.app/cwchanap/issue/HPA-587/tracking-deliver-the-phoenix-14-day-farming-mvp): [HPA-593](https://linear.app/cwchanap/issue/HPA-593/economy-slice-add-three-crops-seed-shop-shipping-and-reinvestment). The live Linear issue and Phoenix project description remain authoritative for product scope, technical direction, delivery order, and non-goals.

HPA-593 builds directly on the completed foundation, turnip loop, and daily-rhythm slices. It adds the smallest complete economy needed for the 14-day MVP: three crops with recognizable growth and return profiles, a nearby seed shop, a shipping bin, overnight income, and a reinvestment loop.

## Outcome

A new game begins with 150G, three turnip seeds, and no harvested crops or pending shipment. The player can visit the existing building's seed counter, buy any of three seed types in chosen quantities, plant and tend those crops on the existing nine-cell farm, harvest them, deposit selected quantities in a nearby shipping bin, sleep, review an itemized payout, and reinvest the credited money.

Turnips retain their established three-watered-night lifecycle. Potatoes take five watered nights and offer a balanced return. Pumpkins take seven watered nights and offer the highest absolute and per-growing-day return. All three crops are profitable and usable within the 14-day arc. Shop and shipping interactions are free; the existing farming actions remain the only economy-slice actions that consume time and stamina.

The map remains a compact 12 by 12 isometric space. The existing building becomes the shop, and one shipping-bin prop is added beside the farm and bed path. The same frontend and authoritative state run in browser and Tauri.

## Approved decisions

- Keep `GameSession` as the only mutable gameplay authority.
- Add one small pure crop-definition module rather than a generic item or economy framework.
- Use exactly three crop kinds: `turnip`, `potato`, and `pumpkin`.
- Preserve the existing four farming actions and keys: `1` Hoe, `2` Seeds, `3` Water, and `4` Hands.
- Store the selected crop seed separately from the selected farming action. Turnip is the initial selected seed.
- Keep the existing three starter turnip seeds and add 150G starting money.
- Use these exact crop values:

| Crop | Watered nights to mature | Seed price | Sale value | Profit per crop |
| --- | ---: | ---: | ---: | ---: |
| Turnip | 3 | 20G | 35G | 15G |
| Potato | 5 | 40G | 75G | 35G |
| Pumpkin | 7 | 70G | 140G | 70G |

- Keep shop stock unlimited and available on every active day.
- Make buying, depositing, seed selection, and panel navigation consume no time or stamina.
- Make shipping deposits final. Deposited crops leave carried inventory immediately and cannot be reclaimed.
- Credit shipping only during one successful sleep transition.
- Use one shared quantity stepper pattern with minus, plus, Max, and an explicit transaction button.
- Reuse the existing building as the seed shop and keep the map dimensions, projection, camera, farm, bed, tree, and spawn unchanged.
- Use four visual stages for every crop and derive the visible stage from authoritative growth progress.
- Keep browser acceptance as the exhaustive real-control proof and use a bounded macOS native smoke for the identical frontend.

## Explicit non-goals

This slice does not add the full village, villager schedules, relationships, dialogue, gifting, limited or rotating stock, dynamic prices, bartering, loans, debt, taxes, inventory capacity, item quality, crop seasons, crop death, processed goods, crafting, tools for sale, tool upgrades, drag-and-drop inventory, multiple currencies, a generic item database, a generic economy service, an overnight registry, or persistence.

It does not add gameplay logic to Rust, create a second renderer, expand beyond one walkable elevation, or change the fixed camera and 2:1 isometric projection. Signing and notarization remain outside this feature.

## Architecture and ownership

### Pure crop definitions

A new framework-free `src/game/core/cropDefinitions.ts` module owns editable crop content. It exports:

- `CROP_KINDS` in stable turnip, potato, pumpkin order;
- `CROP_DEFINITIONS` as a readonly exhaustive record;
- the exact growth days, seed prices, and sale values above; and
- `visualStage(kind, progress)`, which maps authoritative growth progress to one of four visual stages;
- `isMature(kind, progress)`, which applies the selected crop's maturity rule; and
- `shipmentPayout(pending)`, which derives immutable payout lines and a total from pending counts.

The definition for a crop has only content fields required by this slice: display name, growth days, seed price, and sale value. It contains no callbacks, Phaser frame numbers, Svelte labels, transaction methods, or mutable stock.

`CropVisualStage` is exactly `0 | 1 | 2 | 3`. `visualStage` accepts a crop kind and integer progress from zero through that crop's growth-days value. It returns a `CropVisualStage` using:

```ts
Math.min(3, Math.floor((progress * 3) / growthDays))
```

Progress zero is planted, progress equal to growth days is mature, and slower crops may retain a visible stage across multiple mornings. Invalid progress is a programmer error and throws.

`isMature` validates the same integer range and returns whether progress equals `CROP_DEFINITIONS[kind].growthDays`. `shipmentPayout` validates nonnegative safe-integer counts, walks `CROP_KINDS` in stable order, omits zero-quantity crops, and returns fresh `{ lines, total }` data. Each line uses the definition's sale value; unsafe line or aggregate arithmetic is a programmer error and throws. These helpers are the only maturity, frame-stage, and payout formulas used by the slice.

```ts
isMature(kind: CropKind, progress: number): boolean;
shipmentPayout(pending: CropCounts): { lines: ShipmentLine[]; total: number };
```

### Shared domain types

`CropKind` is exactly:

```ts
type CropKind = 'turnip' | 'potato' | 'pumpkin';
```

`FarmingAction` becomes:

```ts
type FarmingAction = 'hoe' | 'seeds' | 'wateringCan' | 'hands';
```

The keyboard's `2` action selects `seeds`; it does not silently change the current crop kind. `ACTION_COSTS.turnipSeeds` is renamed to `ACTION_COSTS.seeds` with the existing 20-minute, one-stamina cost unchanged.

Carried inventory uses exhaustive plain records:

```ts
type CropCounts = Record<CropKind, number>;

interface InventorySnapshot {
  seeds: CropCounts;
  crops: CropCounts;
}
```

`GameSnapshot` retains all existing fields and adds:

- `money: number`;
- `selectedSeed: CropKind`;
- `pendingShipment: CropCounts`;
- `shopCell: GridCell`; and
- `shippingCell: GridCell`.

Farm crop snapshots generalize from turnip-only state to:

```ts
interface CropSnapshot {
  kind: CropKind;
  growth: number;
  wateredToday: boolean;
}
```

`growth` is an integer watered-night count from zero through the selected definition's growth days. Snapshots remain fresh, JSON-serializable plain data with no `Map`, `Set`, provider function, Phaser object, Svelte state, or Tauri value.

The domain no longer exports or uses `GrowthLevel`; its old fixed `0 | 1 | 2 | 3` range cannot represent potato or pumpkin progress. Only `CropVisualStage` is constrained to zero through three.

Every `GameSession.snapshot()` call deep-clones mutable nested data. At minimum, the top-level snapshot, `inventory`, `inventory.seeds`, `inventory.crops`, `pendingShipment`, every farm tile and crop, `bedCell`, `shopCell`, `shippingCell`, `pendingDaySummary`, its `shipments` array, and every shipment line have fresh identities. Caller-owned configuration cells are cloned on construction and never returned by reference.

### GameSession

`GameSession` retains `ProofWorld`, farm, daily rhythm, selected action, weather, and transition ownership. Its configuration gains cloned `shopCell` and `shippingCell` values parsed from the authored map. Construction validates that the shop interaction cell, shipping interaction cell, and bed cell are distinct and in bounds. The parser validates their authored marker and collision relationships; browser acceptance proves the actual player routes.

The session starts with:

- money 150;
- seeds `{ turnip: 3, potato: 0, pumpkin: 0 }`;
- crops `{ turnip: 0, potato: 0, pumpkin: 0 }`;
- pending shipment `{ turnip: 0, potato: 0, pumpkin: 0 }`; and
- selected seed `turnip`.

The session gains three direct economy commands:

```ts
selectSeed(kind: CropKind): CommandResult;
buySeeds(kind: CropKind, quantity: number): CommandResult;
depositCrop(kind: CropKind, quantity: number): CommandResult;
```

It does not gain a generic dispatch method, economy object, transaction class, item registry, command middleware, or overnight plugin.

### Phaser

`ProofScene` remains the adapter for map loading, rendering, keyboard sampling, target detection, and command publication. It does not own money, inventory, pricing, crop growth, shipping totals, or panel state.

The action controller treats `E` as a general interact edge rather than a sleep-only edge. `ProofScene` compares the authoritative target with the authored bed, shop, and shipping cells:

- bed: emit `sleep`;
- shop: emit `shop`;
- shipping bin: emit `shipping`; and
- anything else: publish stable `nothing-to-interact` feedback and a fresh snapshot directly through the existing publication callbacks, without invoking or mutating `GameSession`.

The new closed adapter contract is:

```ts
type InteractionIntent = 'sleep' | 'shop' | 'shipping';
onInteractIntent(intent: InteractionIntent): void;
```

This member replaces `ProofSceneDependencies.onSleepPrompt`; all unrelated dependency callbacks remain unchanged. `ActionSample.sleep` is renamed to `ActionSample.interact`. `GameHost.svelte` forwards the same `onInteractIntent` callback, and `App.svelte` alone decides which presentation state to open. This deliberately replaces the current normal-control behavior in which off-bed `E` calls `GameSession.sleep()` and returns `not-at-bed`. `GameSession.sleep()` retains `not-at-bed` as a defensive direct-call guard, but an off-target `E` now returns `nothing-to-interact` from the Phaser adapter.

`SceneCommands` gains only direct facades for `selectSeed`, `buySeeds`, and `depositCrop` alongside its existing domain commands. It does not gain `openShop`, `openShipping`, or another presentation command. Each economy facade delegates to `GameSession`, reconciles sprites when needed, and publishes one authoritative snapshot and result. The scene never exposes `GameSession`, crop mutation, money setters, stock setters, shipment setters, or test-only economy injection.

### Svelte

Svelte owns only HUD and panel presentation. `App.svelte` gains one optional economy-panel state with values `shop`, `shipping`, or null. An economy panel cannot coexist with sleep confirmation or a morning summary. Opening a panel adds an `economy-panel` reason to `InputGate`; closing it removes that reason. Lifecycle reset and component teardown clear the reason idempotently.

`Overlay.svelte` renders authoritative money, inventory, shipment counts, selected seed, shop content, shipping content, transaction feedback, and summary income. It imports the shared readonly crop definitions only for names, growth nights, and displayed prices. It does not change inventory or money locally and does not calculate a payout.

## Map and authored interactions

The map remains 12 by 12.

- The existing three-by-three farm remains at logical cells x 2 through 4 and y 7 through 9.
- The existing building footprint remains x 7 through 9 and y 7 through 9. Its sprite gains a seed-shop sign.
- `shop-counter` is authored at logical cell 6,7 on the building's farm-facing edge.
- `shipping-bin` is authored at logical cell 6,10 beside the farm and bed path.
- The shipping bin gains one visible scenery object and the exact authored collision footprint `{ id: 'shipping-bin', x: 6.2, y: 10.2, width: 0.6, height: 0.6 }` within cell 6,10.
- The existing bed remains at 6,8, the player spawn at 2.5,9.5, and the tree and building at their established positions.

The generated `proof-scenery.png` becomes exactly 288 by 96 pixels: three 96 by 96 tiles in one row. Its Tiled tileset remains `firstgid: 3` and becomes `columns: 3`, `tilecount: 3`, with global IDs `3` tree, `4` shop building, and `5` shipping bin.

The existing authored objects keep IDs 1 through 6. The generator adds these exact objects atomically with the tileset metadata:

- object 7: visible shipping-bin scenery using global tile ID 5;
- object 8: the `shipping-bin` collision rectangle with the exact footprint above;
- object 9: the `shop-counter` interaction marker at cell 6,7; and
- object 10: the `shipping-bin` interaction marker at cell 6,10.

The generated map sets `nextobjectid` to 11. The marker layer permits exactly `player-spawn`, `bed-interaction`, `shop-counter`, and `shipping-bin`. The parser requires one of each, the exact IDs above, zero rotation, visibility, valid isometric coordinates, and the exact authored logical cells. It rejects missing, duplicate, renamed, misplaced, out-of-bounds, footprint-conflicting, or unexpected markers. Generator, PNG, JSON fixture, parser, and fixture tests change as one task so no intermediate contract is accepted.

The shop marker must not overlap collision. The shipping marker must correspond to the authored shipping-bin footprint. Neither new footprint may block the existing route between spawn, farm, bed, shop, and shipping interaction edges.

`SceneryKind` becomes exactly `'tree' | 'building' | 'shipping-bin'`. `ProofScene` adds `shipping-bin` to its scenery sprite map, base depth IDs, debug depths, and footpoint-depth reconciliation. The shop stays the existing building plus its seed sign; it does not gain another scenery entity.

The shipping footprint is deliberately southeast of the current y 9.5 spawn corridor and east of the existing diagonal route toward the bed. Its scenery anchor is the footprint center at logical point 6.5,10.5, which projects to world point 256,272. Map and movement tests prove the footprint blocks entry into its own 0.6 by 0.6 rectangle while preserving reachable routes in both directions among spawn, all farm edges, bed, shop counter, and shipping interaction cell.

`ParsedProofMap` returns `shopCell` and `shippingCell` with the existing world, scenery, farm cells, and bed cell. These cells are the only map-owned economy configuration passed into `GameSession`.

## Crop and scenery visuals

The deterministic asset generator replaces the turnip-only crop sheet with one `proof-crops.png` spritesheet. It has four 32 by 48 frames per crop, with crop rows in `CROP_KINDS` order and visual stages zero through three across each row, for an exact image size of 128 by 144 pixels. Each crop has a distinct silhouette and palette at planted, sprout, growing, and mature stages.

`farmVisuals` first derives `visualStage(kind, growth)`, then maps the row-major sheet index exactly as:

```ts
const cropIndex = CROP_KINDS.indexOf(kind);
const cropFrame = cropIndex * 4 + visualStage(kind, growth);
```

`cropFrame` is therefore null for empty soil or an integer sheet index from 0 through 11; it is never the domain growth value. `ProofScene` loads `proof-crops.png` and passes that sheet index to Phaser. Soil wetness continues to depend on weather or `wateredToday`. Gameplay snapshots never store or publish a frame number.

The scenery sheet retains the tree and shop-building frames and adds a shipping-bin frame. The existing building frame is visually amended with a seed sign; no separate shop building or village expansion is introduced. The shipping bin participates in the existing footpoint depth ordering.

All generated PNG and Tiled JSON outputs remain deterministic. Repeated generator runs must produce byte-identical outputs and a clean Git diff.

## Farming semantics

Planting uses the currently selected seed kind.

The transaction order is:

1. Apply the existing active-day gate.
2. Validate target and farm state in the existing order.
3. Verify carried inventory has at least one selected seed.
4. Evaluate the existing Seeds action time and stamina budget.
5. Create the selected crop at growth zero, remove one matching seed, and commit the budget together.

Every crop uses the existing farming costs. Hoe, Seeds, Water, and Hands keep their HPA-592 time and stamina values. Failed planting does not change selected seed, inventory, farm state, time, or stamina.

Watering remains crop-agnostic, but its mature-crop guard calls `isMature(kind, growth)` rather than comparing against a fixed number. On sunny days it sets `wateredToday` after budget validation. On rainy days it returns the existing rain feedback without budget cost. At sleep, a crop advances by one integer progress point when it was watered manually or the completed day was rainy and `isMature` is false. It never casts progress to the removed `GrowthLevel` or advances past the selected definition's growth days. Every surviving crop then resets `wateredToday` to false.

Harvest succeeds only when `isMature(kind, growth)` returns true. It removes the crop, adds one matching harvested crop to carried inventory, and charges the existing Hands budget atomically.

## Economy command semantics

### Seed selection

`selectSeed` applies the active-day gate, stores the exhaustive crop kind, and returns `seed-selected`. It is free and can be used anywhere during active play. Selecting a seed does not select the Seeds farming action; keyboard `2` or the Seeds action button still owns that choice.

### Buying seeds

`buySeeds` applies checks in this order:

1. Active-day gate.
2. Current target equals `shopCell`.
3. Quantity and the resulting purchase total are positive safe integers.
4. Money is at least `seedPrice * quantity`.

On success it deducts the exact total and adds the exact seed quantity in one mutation, then returns `seeds-purchased`. Stock is unlimited. On failure it returns `not-at-shop`, `invalid-quantity`, or `insufficient-funds` and preserves the complete snapshot.

### Depositing crops

`depositCrop` applies checks in this order:

1. Active-day gate.
2. Current target equals `shippingCell`.
3. Quantity and the resulting pending-shipment count are positive safe integers.
4. Carried harvested inventory contains at least that quantity.

On success it removes the exact quantity from carried crops, adds it to the same pending-shipment crop count, and returns `crop-deposited`. Deposits are final. On failure it returns `not-at-shipping-bin`, `invalid-quantity`, or `insufficient-crops` and preserves the complete snapshot.

Buying, depositing, and seed selection do not change time, stamina, weather, farm state, or day.

## Day transition and payout

Before a valid sleep transition mutates state, `GameSession` validates the next weather and calls `shipmentPayout(pendingShipment)`. The pure helper returns the immutable line-item data and total used by the transition. Each nonzero line contains:

```ts
interface ShipmentLine {
  crop: CropKind;
  quantity: number;
  unitValue: number;
  lineTotal: number;
}
```

Lines use stable crop order, skip zero quantities, and take `unitValue` from `CROP_DEFINITIONS`. `lineTotal` is `quantity * unitValue`, and total income is the sum of all line totals. Empty shipments produce no lines and zero income. Neither `GameSession` nor Svelte duplicates this arithmetic.

The successful direct transition then:

1. Advances eligible crops and resets daily watering flags.
2. Credits total shipping income to money.
3. Clears all pending shipment quantities.
4. Increments the day.
5. Resets time to 06:00 and stamina to maximum.
6. Stores the validated next weather.
7. Creates one pending morning summary.

`DaySummary` retains all HPA-592 fields and adds:

- `shipments: ShipmentLine[]`;
- `shippingIncome: number`; and
- `moneyAfterShipping: number`.

The summary stores fresh copies of the helper's lines. Every later snapshot clones the summary object, shipment array, and each line again. `Overlay.svelte` renders these authoritative `DaySummary.shipments` values and may look up crop display names in `CROP_DEFINITIONS`; it never recomputes unit values, line totals, or aggregate income.

The existing pending-summary domain gate prevents a second sleep. Shipment quantities are already zero before the summary becomes visible. Acknowledgment only clears the summary; it never credits income. Duplicate sleep, duplicate acknowledgment, rejected sleep, invalid weather, and Day 14 sleep cannot pay twice.

Day 14 remains fully playable. Its rejected sleep preserves crops, watering flags, carried inventory, pending shipment, money, time, stamina, weather, day, and provider state. HPA-597 will own the eventual finale transition and treatment of final-day shipments.

## Panels, HUD, and focus

The HUD adds:

- money;
- selected seed;
- seed counts for each crop;
- harvested counts for each crop; and
- total pending shipment quantity.

The action area remains four controls. Its Seeds label includes the selected crop, such as `2 Seeds: Potato`. Three compact inventory buttons select Turnip, Potato, or Pumpkin. These buttons call the authoritative seed-selection command and reflect the published selected seed.

The shop and shipping panels consume one shared `src/components/QuantityStepper.svelte` component rather than duplicating quantity behavior. They use the same interaction pattern:

- three selectable crop rows in stable order;
- name, growth nights, unit price or sale value, and relevant owned count;
- one shared quantity value for the selected row;
- minus, plus, Max, and an explicit Buy or Deposit button;
- default quantity one;
- initial focus on the first usable crop row, or Close when no row is usable;
- an explicit Close button; and
- Escape to close.

The shop displays unlimited stock. Its Max value is `Math.floor(money / seedPrice)`. The Buy button is disabled for zero affordable quantity or when the authoritative command is being submitted.

The shipping panel enables only crop rows with a positive carried count. Its Max value is the selected crop's carried quantity. Pending shipment counts update immediately after a successful deposit.

Quantity, selected row, focus target, and submitting state are presentation-only. They reset when a panel closes. Panels remain open after a transaction so the player can process multiple crop kinds. Obvious disabled states improve usability, but domain validation remains definitive.

The panel layer uses an accessible modal dialog, blocks background controls, and keeps world input locked. Sleep confirmation and the morning summary retain their existing focus and continuous-lock behavior. Economy panels cannot open during either day-transition stage.

## Result codes and feedback

New success codes are:

- `seed-selected`;
- `seeds-purchased`;
- `crop-deposited`;
- `crop-planted`; and
- `crop-harvested`.

New failure codes are:

- `nothing-to-interact`;
- `no-selected-seeds`;
- `not-at-shop`;
- `not-at-shipping-bin`;
- `invalid-quantity`;
- `insufficient-funds`; and
- `insufficient-crops`.

The existing `turnip-planted` and `turnip-harvested` codes are replaced by `crop-planted` and `crop-harvested`. The UI may include the selected or harvested crop's display name from the authoritative snapshot and shared definitions, but it does not infer transaction totals or mutate state.

Every command returns one stable result and publishes one fresh authoritative snapshot. Failure paths preserve farm, inventory, shipment, money, time, stamina, weather, day, selection, and summary state.

## Testing strategy

### Pure and unit tests

`cropDefinitions` tests prove:

- exact stable crop order;
- exact 3, 5, and 7 growth days;
- exact prices and sale values;
- positive profitability and increasing return profile;
- exact four-stage mapping at every valid progress value;
- exact per-kind maturity at 3, 5, and 7 progress;
- rejection of invalid progress;
- stable nonzero shipment-line order, definition-derived unit values, line totals, and aggregate total; and
- empty payout behavior, zero-count omission, invalid counts, and unsafe arithmetic rejection.

`GameSession` tests prove:

- exact starter money and inventory;
- exhaustive seed selection;
- all three planting, watering, rainy growth, sunny dry non-growth, maturity, and harvest lifecycles;
- definition-driven mature guards in water, sleep advancement, and harvest for turnip, potato, and pumpkin;
- purchase totals, multi-quantity purchases, unlimited stock, insufficient funds, invalid quantities, wrong-location rejection, and atomic rollback;
- partial and full-stack deposits, immediate carried-inventory removal, invalid quantities, wrong-location rejection, insufficient crops, and double-deposit prevention;
- stable itemized payout order, line totals, total income, resulting money, shipment clearing, and empty-shipment behavior;
- duplicate sleep and summary acknowledgment cannot process income twice;
- invalid weather and Day 14 preserve shipment and money;
- all new state is cloned, fresh, and JSON round-trippable, including separate identity assertions for seed counts, crop counts, pending shipment, config cells, the summary shipment array, and every shipment line; and
- caller-owned configuration cells cannot mutate session state, and snapshots never alias the shared readonly definitions.

Mutation evidence must cover at least one affordability guard, one immediate inventory removal, and one payout-clearing rule.

### Map, assets, and rendering

Parser and generator tests prove:

- exact shop cell 6,7 and shipping cell 6,10;
- one marker of each permitted name;
- exact 288 by 96 scenery metadata, three tiles, global IDs 3 through 5, object IDs 7 through 10, and `nextobjectid: 11`;
- the exact `{ x: 6.2, y: 10.2, width: 0.6, height: 0.6 }` shipping footprint and valid marker relationship;
- unchanged farm, bed, building, tree, spawn, projection, and camera contracts;
- exact deterministic PNG dimensions;
- distinct four-stage frames for each crop;
- exact crop frame formula `CROP_KINDS.indexOf(kind) * 4 + visualStage` for every valid progress value;
- stable soil, crop, shipping-bin, player, and scenery depth behavior;
- collision at the shipping footprint plus clear spawn, farm, bed, shop, and shipping routes; and
- byte-identical regeneration across repeated runs.

### Phaser and Svelte integration

Focused tests prove:

- `ActionSample.interact` emits one rising edge and resets under `InputGate` locking;
- `onInteractIntent` routes exactly `sleep`, `shop`, and `shipping`, while an empty target publishes `nothing-to-interact` without a session mutation;
- normal off-target `E` no longer publishes `not-at-bed`, while direct defensive `GameSession.sleep()` still does;
- scene command facades publish authoritative snapshots and results once;
- economy panel locking resets held movement and action keys;
- lifecycle remount and teardown do not retain panels, locks, callbacks, or Phaser objects;
- HUD and panel labels exhaustively cover crop and result unions;
- quantity Max and disabled states derive from current snapshots;
- shop and shipping modes consume the same quantity-stepper component; and
- sleep and economy modal states remain mutually exclusive.

Svelte changes receive static checking and the available Svelte autofixer. If the external autofixer remains unavailable at the privacy or network boundary, the report records that limitation and uses local Svelte 5 review plus `svelte-check` as the required fallback.

### Browser acceptance

Playwright uses real movement, `E`, keyboard actions, and visible buttons with retries zero and existing route deadlines. It proves:

1. The player reaches the shop and opens the panel from the exact authored target.
2. Buying potato and pumpkin seeds changes money and inventory exactly.
3. An unaffordable purchase leaves the complete snapshot unchanged.
4. All three crop kinds can be selected, planted, and rendered distinctly.
5. Crops progress according to observed production sunny or rainy weather until turnip, potato, and pumpkin mature on their configured schedules.
6. Harvested crops enter the matching carried counts.
7. The player reaches the shipping bin, deposits selected quantities, and sees immediate carried-inventory removal and pending-shipment updates.
8. One sleep produces exact itemized lines, credits the exact total once, clears pending shipment, and retains the blocking summary until acknowledgment.
9. The credited balance buys a larger follow-up seed quantity, completing reinvestment.
10. Shop and shipping focus, Escape, world-input locking, camera bounds, crop frames, and relevant depth reversals remain correct.

All existing foundation, farming, sleep, daily-rhythm, lifecycle, HMR, map-edge, camera, and depth suites remain green.

### Implementation planning constraints

The implementation plan must preserve this dependency order:

1. Add `cropDefinitions`, generalized domain types, `GameSession` commands and payout behavior; rename the `FarmingAction` and `ACTION_COSTS` key from `turnipSeeds` to `seeds`; and replace the flat turnip inventory fields with exhaustive `inventory.seeds` and `inventory.crops` before touching adapters.
2. Change the deterministic generator, crop and scenery assets, Tiled JSON fixture, exact parser contract, and parser/generator tests atomically.
3. Update `farmVisuals`, crop-frame mapping, `ActionSample.interact`, the closed `onInteractIntent` bridge, `ProofScene` scenery/depth reconciliation, and direct scene command facades.
4. Add App/Overlay economy presentation and one shared `QuantityStepper.svelte` used by both shop and shipping modes.
5. Add Playwright journeys, documentation, production/native verification, and delivery evidence.

Each stage starts with focused RED evidence and reaches its focused GREEN checks before the next dependent stage begins. The first mutation proofs target one affordability guard, immediate carried-inventory removal on deposit, and pending-shipment clearing after payout. Broad full-suite, browser, and native verification follows only after the focused seams are green; the plan must not hide domain failures behind UI work or duplicate the quantity stepper across panels.

### macOS delivery

Final verification runs:

- deterministic asset generation and clean regeneration diff;
- full unit suite;
- Svelte/TypeScript check;
- full Playwright suite;
- production build and hook scan;
- Cargo check;
- Tauri app and DMG build at the required macOS host boundary;
- arm64, bundle identifier, version, and DMG verification audit; and
- the committed clean-checkout verifier.

A bounded native smoke launches only the task-created Phoenix process and attempts to observe the same shop, crop, shipping, and summary frontend. Browser E2E remains the exhaustive interaction proof. Native accessibility, focus, signing, or notarization limitations are reported without overclaiming. Unrelated processes are never terminated.

## Acceptance summary

The slice is complete when a player can, through normal controls:

1. Open the nearby shop.
2. Buy any seed type in an affordable quantity.
3. Grow and harvest recognizable quick, balanced, and slow crops.
4. Deposit harvested crops in the shipping bin.
5. Receive one exact itemized payout the next morning.
6. Reinvest that money in a larger planting plan.

Every mutation is authoritative, atomic, and reflected through fresh snapshots. The map remains compact, UI panels own no economy rules, the overnight flow remains direct, and no speculative economy framework enters the MVP.
