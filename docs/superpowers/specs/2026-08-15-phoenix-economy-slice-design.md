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
- a pure function that maps authoritative growth progress to one of four visual stages.

The definition for a crop has only content fields required by this slice: display name, growth days, seed price, and sale value. It contains no callbacks, Phaser frame numbers, Svelte labels, transaction methods, or mutable stock.

The visual-stage function accepts a crop kind and integer progress from zero through that crop's growth-days value. It returns stage 0 through 3 using:

```ts
Math.min(3, Math.floor((progress * 3) / growthDays))
```

Progress zero is planted, progress equal to growth days is mature, and slower crops may retain a visible stage across multiple mornings. Invalid progress is a programmer error and throws.

### Shared domain types

`CropKind` is exactly:

```ts
type CropKind = 'turnip' | 'potato' | 'pumpkin';
```

`FarmingAction` becomes:

```ts
type FarmingAction = 'hoe' | 'seeds' | 'wateringCan' | 'hands';
```

The keyboard's `2` action selects `seeds`; it does not silently change the current crop kind.

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

### GameSession

`GameSession` retains `ProofWorld`, farm, daily rhythm, selected action, weather, and transition ownership. Its configuration gains cloned `shopCell` and `shippingCell` values parsed from the authored map. Construction validates that the shop interaction cell, shipping interaction cell, and bed cell are distinct, in bounds, and consistent with the configured collision footprints. The parser fixes their authored positions; browser acceptance proves the actual player routes.

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

- bed: emit the existing sleep-prompt intent;
- shop: emit a shop-panel intent;
- shipping bin: emit a shipping-panel intent; and
- anything else: publish stable `nothing-to-interact` feedback without mutation.

Scene commands gain direct facades for `selectSeed`, `buySeeds`, and `depositCrop`. Each delegates to `GameSession`, reconciles sprites when needed, and publishes one authoritative snapshot and result. The scene never exposes `GameSession`, crop mutation, money setters, stock setters, shipment setters, or test-only economy injection.

### Svelte

Svelte owns only HUD and panel presentation. `App.svelte` gains one optional economy-panel state with values `shop`, `shipping`, or null. An economy panel cannot coexist with sleep confirmation or a morning summary. Opening a panel adds an `economy-panel` reason to `InputGate`; closing it removes that reason. Lifecycle reset and component teardown clear the reason idempotently.

`Overlay.svelte` renders authoritative money, inventory, shipment counts, selected seed, shop content, shipping content, transaction feedback, and summary income. It does not change inventory or money locally and does not calculate a payout.

## Map and authored interactions

The map remains 12 by 12.

- The existing three-by-three farm remains at logical cells x 2 through 4 and y 7 through 9.
- The existing building footprint remains x 7 through 9 and y 7 through 9. Its sprite gains a seed-shop sign.
- `shop-counter` is authored at logical cell 6,7 on the building's farm-facing edge.
- `shipping-bin` is authored at logical cell 5,9 beside the farm and bed path.
- The shipping bin gains one visible scenery object, a small authored collision footprint within cell 5,9, and footpoint depth sorting.
- The existing bed remains at 6,8, the player spawn at 2.5,9.5, and the tree and building at their established positions.

The marker layer permits exactly `player-spawn`, `bed-interaction`, `shop-counter`, and `shipping-bin`. The parser requires one of each, explicit stable object IDs, zero rotation, visibility, valid isometric coordinates, and the exact authored logical cells. It rejects missing, duplicate, renamed, misplaced, out-of-bounds, footprint-conflicting, or unexpected markers.

The shop marker must not overlap collision. The shipping marker must correspond to the authored shipping-bin footprint. Neither new footprint may block the existing route between spawn, farm, bed, shop, and shipping interaction edges.

`ParsedProofMap` returns `shopCell` and `shippingCell` with the existing world, scenery, farm cells, and bed cell. These cells are the only map-owned economy configuration passed into `GameSession`.

## Crop and scenery visuals

The deterministic asset generator replaces the turnip-only crop sheet with one `proof-crops.png` spritesheet. It has four 32 by 48 frames per crop in stable row-major crop order, for an exact image size of 128 by 144 pixels. Each crop has a distinct silhouette and palette at planted, sprout, growing, and mature stages.

`farmVisuals` derives the crop frame from crop kind and authoritative progress through the pure crop-definition mapper. Soil wetness continues to depend on weather or `wateredToday`. Gameplay never stores or publishes a frame number.

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

Watering remains crop-agnostic. On sunny days it sets `wateredToday` after budget validation. On rainy days it returns the existing rain feedback without budget cost. At sleep, a crop advances by one progress point when it was watered manually or the completed day was rainy, up to its definition's growth days. Every surviving crop then resets `wateredToday` to false.

Harvest succeeds only when progress equals the crop's growth days. It removes the crop, adds one matching harvested crop to carried inventory, and charges the existing Hands budget atomically.

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

Before a valid sleep transition mutates state, `GameSession` validates the next weather and builds immutable shipment line items from the current pending shipment and shared crop definitions. Each nonzero line contains:

```ts
interface ShipmentLine {
  crop: CropKind;
  quantity: number;
  unitValue: number;
  lineTotal: number;
}
```

Lines use stable crop order. `lineTotal` is `quantity * unitValue`, and total income is the sum of all line totals. Empty shipments produce no lines and zero income.

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

The shop and shipping panels use the same interaction pattern:

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
- `seeds-purchased`; and
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
- exact four-stage mapping at every valid progress value; and
- rejection of invalid progress.

`GameSession` tests prove:

- exact starter money and inventory;
- exhaustive seed selection;
- all three planting, watering, rainy growth, sunny dry non-growth, maturity, and harvest lifecycles;
- purchase totals, multi-quantity purchases, unlimited stock, insufficient funds, invalid quantities, wrong-location rejection, and atomic rollback;
- partial and full-stack deposits, immediate carried-inventory removal, invalid quantities, wrong-location rejection, insufficient crops, and double-deposit prevention;
- stable itemized payout order, line totals, total income, resulting money, shipment clearing, and empty-shipment behavior;
- duplicate sleep and summary acknowledgment cannot process income twice;
- invalid weather and Day 14 preserve shipment and money;
- all new state is cloned, fresh, and JSON round-trippable; and
- caller-owned configuration cells cannot mutate session state, and snapshots never alias the shared readonly definitions.

Mutation evidence must cover at least one affordability guard, one immediate inventory removal, and one payout-clearing rule.

### Map, assets, and rendering

Parser and generator tests prove:

- exact shop and shipping cells;
- one marker of each permitted name;
- explicit metadata and object IDs;
- valid marker and footprint relationships;
- unchanged farm, bed, building, tree, spawn, projection, and camera contracts;
- exact deterministic PNG dimensions;
- distinct four-stage frames for each crop;
- stable soil, crop, shipping-bin, player, and scenery depth behavior; and
- byte-identical regeneration across repeated runs.

### Phaser and Svelte integration

Focused tests prove:

- `E` routes bed, shop, shipping, and empty targets correctly;
- scene command facades publish authoritative snapshots and results once;
- economy panel locking resets held movement and action keys;
- lifecycle remount and teardown do not retain panels, locks, callbacks, or Phaser objects;
- HUD and panel labels exhaustively cover crop and result unions;
- quantity Max and disabled states derive from current snapshots; and
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
