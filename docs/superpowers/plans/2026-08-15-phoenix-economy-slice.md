# Phoenix Economy Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver HPA-593 as a complete three-crop economy loop in which the player buys seeds, grows and harvests turnips, potatoes, and pumpkins, deposits crops in a shipping bin, receives one overnight payout, and reinvests the proceeds in the browser and macOS Tauri application.

**Architecture:** One framework-free `cropDefinitions` table owns crop content plus pure maturity, visual-stage, and payout helpers. `GameSession` remains the only mutable gameplay authority and gains direct location-gated economy commands; the exact authored map owns shop and shipping interaction cells; Phaser remains the movement/render/input adapter; Svelte owns one economy-panel state and a shared quantity stepper without duplicating economy math.

**Tech Stack:** Bun 1.3.1 and bun:test, TypeScript 7.0.2 through @typescript/native with TypeScript 6.0.3 for svelte-check --tsgo, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1 with retries disabled, Vite 8.2.1, Tauri 2.11.4, and Rust/Cargo 1.96 on macOS.

## Global Constraints

- Implement only HPA-593. Do not add an item registry, economy service, transaction framework, stock system, capacity, crop quality, seasons, persistence, dialogue, relationships, a village, another building, a generalized overnight hook, or the HPA-597 finale.
- Preserve ownership: `cropDefinitions` owns content and pure formulas; `GameSession` owns money, inventory, crops, pending shipment, payout application, and command validation; the authored map owns interaction cells; Phaser owns rendering/input/target routing; Svelte owns presentation and focus; Tauri remains a shell.
- Use exact crop content in stable order: Turnip 3 watered nights, 20G seed, 35G sale; Potato 5 nights, 40G seed, 75G sale; Pumpkin 7 nights, 70G seed, 140G sale.
- Start every new session with 150G, seeds `{ turnip: 3, potato: 0, pumpkin: 0 }`, zero carried crops, zero pending shipment, and selected seed `turnip`.
- Keep the four farming actions exactly `hoe`, `seeds`, `wateringCan`, and `hands`. Key `2` selects Seeds and never changes `selectedSeed`. Preserve all HPA-592 time/stamina costs and validation order.
- Buying, depositing, seed selection, opening/closing panels, and summary acknowledgment are free. Deposits are final and remove carried inventory immediately. Payout occurs only inside one successful sleep, before pending shipment is cleared.
- Use `isMature(kind, growth)` for water, sleep advancement, and harvest. Domain growth is an integer from zero through the definition's `growthDays`; it is not the old fixed `GrowthLevel`.
- `shipmentPayout` is the only payout formula. `farmVisuals` is the only crop-sheet-index mapper. Svelte may read definitions for labels and prices but must not calculate totals or mutate authoritative state.
- Use the exact map contract: shop cell 6,7; shipping cell 6,10; shipping footprint `{ id: 'shipping-bin', x: 6.2, y: 10.2, width: 0.6, height: 0.6 }`; scenery anchor logical 6.5,10.5/world 256,272; scenery PNG 288×96 with global IDs 3 tree, 4 building, 5 shipping bin; object IDs 7–10; `nextobjectid: 11`.
- Keep `window.__PHOENIX_TEST__` observation-only. Do not add command invocation, setters, weather injection, inventory injection, teleportation, or economy mutation hooks.
- Use one `onInteractIntent('sleep' | 'shop' | 'shipping')` presentation callback. Off-target `E` publishes `nothing-to-interact` without calling `GameSession.sleep()` or mutating the session. `GameSession.sleep()` retains `not-at-bed` for direct defensive calls.
- Use one `QuantityStepper.svelte` for shop and shipping. Economy panels are accessible modals, mutually exclusive with sleep confirmation and morning summary, and hold one continuous `economy-panel` InputGate reason until close.
- Use Bun as the only JavaScript package manager and bun:test as the unit runner. Add no dependency and do not change package versions.
- Run genuine RED before production edits, focused GREEN, task-level regression checks, self-review, and a focused commit. Record the affordability, deposit-removal, and payout-clearing mutations in Task 2.
- Tasks 1 and 2 complete the domain stage before map or adapter work. Tasks 2 through 4 may expose only the explicitly expected static consumer errors from the domain-first rename; do not add compatibility aliases or hard-coded map defaults to make an intermediate global check green. Task 5 must close every migration error and restore `rtk bun run check` to zero errors and zero warnings.
- For Svelte edits, load `svelte:svelte-code-writer` and `svelte:svelte-core-bestpractices` at execution time. Use only local analysis that does not send private source externally, and always finish the Svelte task with `rtk bun run check`.
- Browser actions enter through real keys and visible controls. Keep Playwright retries at 0 and existing 3-second route/readiness deadlines; do not hide flakes with retries, arbitrary sleeps, broad timeouts, direct session calls, or setters.
- macOS is the only native boundary. Report ad-hoc/unsigned signing, accessibility/focus limits, and any unproven native interaction accurately. Never terminate unrelated processes.

## File Map

### Pure crop policy and authoritative session

- Create: `src/game/core/cropDefinitions.ts`
- Create: `tests/game/cropDefinitions.test.ts`
- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/dailyRhythm.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `tests/game/dailyRhythm.test.ts`
- Modify: `tests/game/GameSession.test.ts`

### Deterministic assets and exact authored map

- Modify: `tools/generate-proof-assets.ts`
- Create (generated): `src/assets/sprites/proof-crops.png`
- Modify (generated): `src/assets/sprites/proof-scenery.png`
- Modify (generated): `src/assets/maps/proof-map.json`
- Delete: `src/assets/sprites/proof-turnip.png`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `tests/game/loadProofMap.test.ts`
- Modify: `tests/game/ProofWorld.test.ts`

### Rendering and interaction bridge

- Modify: `src/game/core/farmVisuals.ts`
- Modify: `tests/game/farmVisuals.test.ts`
- Create: `src/game/phaser/interactionIntent.ts`
- Create: `tests/game/interactionIntent.test.ts`
- Modify: `src/game/phaser/ActionController.ts`
- Modify: `tests/game/ActionController.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`

### Svelte economy presentation

- Create: `src/components/QuantityStepper.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/GameHost.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

### Browser acceptance and delivery

- Create: `tests/e2e/economy.pw.ts`
- Modify: `tests/e2e/helpers.ts`
- Modify: `tests/e2e/farming.pw.ts`
- Modify: `tests/e2e/sleep-confirmation.pw.ts`
- Modify: `tests/e2e/world.pw.ts`
- Modify: `tests/e2e/lifecycle.pw.ts`
- Modify: `tests/config/handoff.test.ts`
- Modify: `README.md`

No change is planned for `package.json`, `bun.lock`, `playwright.config.ts`, the development-hook shape in `src/vite-env.d.ts`, Tauri configuration, Rust source, or `tools/verify-clean-checkout.ts`.

---

### Task 1: Pure Crop Definitions and Formula Policy

**Files:**

- Create: `src/game/core/cropDefinitions.ts`
- Create: `tests/game/cropDefinitions.test.ts`
- Modify: `src/game/core/types.ts`

**Interfaces:**

- Consumes: no mutable game state; only the additive `CropKind`, `CropCounts`, and `ShipmentLine` types introduced in this task.
- Produces: `CROP_KINDS`, `CROP_DEFINITIONS`, `CropVisualStage`, `visualStage(kind, progress)`, `isMature(kind, progress)`, and `shipmentPayout(pending)`.
- Preserves: current turnip-only `FarmTileSnapshot`, `InventorySnapshot`, `GameSnapshot`, and `GrowthLevel` until Task 2 performs the authoritative migration.

- [ ] **Step 1: Write the failing pure-policy tests**

Create `tests/game/cropDefinitions.test.ts`:

~~~ts
import { describe, expect, test } from 'bun:test';
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  isMature,
  shipmentPayout,
  visualStage,
} from '../../src/game/core/cropDefinitions';

describe('cropDefinitions', () => {
  test('keeps exact stable crop content and profitable return order', () => {
    expect(CROP_KINDS).toEqual(['turnip', 'potato', 'pumpkin']);
    expect(CROP_DEFINITIONS).toEqual({
      turnip: { displayName: 'Turnip', growthDays: 3, seedPrice: 20, saleValue: 35 },
      potato: { displayName: 'Potato', growthDays: 5, seedPrice: 40, saleValue: 75 },
      pumpkin: { displayName: 'Pumpkin', growthDays: 7, seedPrice: 70, saleValue: 140 },
    });
    const profits = CROP_KINDS.map((kind) => (
      CROP_DEFINITIONS[kind].saleValue - CROP_DEFINITIONS[kind].seedPrice
    ));
    const profitPerNight = CROP_KINDS.map((kind) => (
      profits[CROP_KINDS.indexOf(kind)] / CROP_DEFINITIONS[kind].growthDays
    ));
    expect(profits).toEqual([15, 35, 70]);
    expect(profitPerNight).toEqual([5, 7, 10]);
  });

  test.each([
    ['turnip', [0, 1, 2, 3]],
    ['potato', [0, 0, 1, 1, 2, 3]],
    ['pumpkin', [0, 0, 0, 1, 1, 2, 2, 3]],
  ] as const)('maps every valid %s progress to four visual stages', (kind, expected) => {
    expect(expected.map((_stage, progress) => visualStage(kind, progress))).toEqual(expected);
  });

  test.each([
    ['turnip', 3],
    ['potato', 5],
    ['pumpkin', 7],
  ] as const)('uses the configured maturity for %s', (kind, matureProgress) => {
    expect(isMature(kind, matureProgress - 1)).toBe(false);
    expect(isMature(kind, matureProgress)).toBe(true);
  });

  test.each([
    ['turnip', -1],
    ['potato', 1.5],
    ['pumpkin', 8],
  ] as const)('rejects invalid %s progress %p', (kind, progress) => {
    expect(() => visualStage(kind, progress)).toThrow();
    expect(() => isMature(kind, progress)).toThrow();
  });

  test('creates stable nonzero payout lines and total without mutating counts', () => {
    const pending = { turnip: 2, potato: 1, pumpkin: 3 };
    expect(shipmentPayout(pending)).toEqual({
      lines: [
        { crop: 'turnip', quantity: 2, unitValue: 35, lineTotal: 70 },
        { crop: 'potato', quantity: 1, unitValue: 75, lineTotal: 75 },
        { crop: 'pumpkin', quantity: 3, unitValue: 140, lineTotal: 420 },
      ],
      total: 565,
    });
    expect(pending).toEqual({ turnip: 2, potato: 1, pumpkin: 3 });
  });

  test('omits zero counts, returns fresh data, and handles an empty shipment', () => {
    const first = shipmentPayout({ turnip: 0, potato: 2, pumpkin: 0 });
    const second = shipmentPayout({ turnip: 0, potato: 2, pumpkin: 0 });
    expect(first).toEqual({
      lines: [{ crop: 'potato', quantity: 2, unitValue: 75, lineTotal: 150 }],
      total: 150,
    });
    expect(second).toEqual(first);
    expect(second).not.toBe(first);
    expect(second.lines).not.toBe(first.lines);
    expect(second.lines[0]).not.toBe(first.lines[0]);
    expect(shipmentPayout({ turnip: 0, potato: 0, pumpkin: 0 }))
      .toEqual({ lines: [], total: 0 });
  });

  test.each([-1, 1.5, Number.NaN])('rejects invalid shipment count %p', (quantity) => {
    expect(() => shipmentPayout({ turnip: quantity, potato: 0, pumpkin: 0 })).toThrow();
  });

  test('rejects unsafe payout arithmetic', () => {
    expect(() => shipmentPayout({
      turnip: Number.MAX_SAFE_INTEGER,
      potato: 0,
      pumpkin: 0,
    })).toThrow();
  });
});
~~~

- [ ] **Step 2: Run the focused test and observe RED**

Run: `rtk bun test tests/game/cropDefinitions.test.ts`

Expected: FAIL because `src/game/core/cropDefinitions.ts` does not exist.

- [ ] **Step 3: Add the shared additive crop and shipment types**

Add these exports beside the existing farming types in `src/game/core/types.ts`; do not replace the old turnip snapshot types yet:

~~~ts
export type CropKind = 'turnip' | 'potato' | 'pumpkin';
export type CropCounts = Record<CropKind, number>;

export interface ShipmentLine {
  crop: CropKind;
  quantity: number;
  unitValue: number;
  lineTotal: number;
}
~~~

- [ ] **Step 4: Implement the complete pure crop-definition module**

Create `src/game/core/cropDefinitions.ts`:

~~~ts
import type { CropCounts, CropKind, ShipmentLine } from './types';

export const CROP_KINDS = ['turnip', 'potato', 'pumpkin'] as const
  satisfies readonly CropKind[];

export interface CropDefinition {
  readonly displayName: string;
  readonly growthDays: number;
  readonly seedPrice: number;
  readonly saleValue: number;
}

export const CROP_DEFINITIONS = {
  turnip: { displayName: 'Turnip', growthDays: 3, seedPrice: 20, saleValue: 35 },
  potato: { displayName: 'Potato', growthDays: 5, seedPrice: 40, saleValue: 75 },
  pumpkin: { displayName: 'Pumpkin', growthDays: 7, seedPrice: 70, saleValue: 140 },
} as const satisfies Readonly<Record<CropKind, CropDefinition>>;

export type CropVisualStage = 0 | 1 | 2 | 3;

function assertProgress(kind: CropKind, progress: number): void {
  const growthDays = CROP_DEFINITIONS[kind].growthDays;
  if (!Number.isSafeInteger(progress) || progress < 0 || progress > growthDays) {
    throw new RangeError(`${kind} progress must be an integer from 0 through ${growthDays}`);
  }
}

export function visualStage(kind: CropKind, progress: number): CropVisualStage {
  assertProgress(kind, progress);
  return Math.min(
    3,
    Math.floor((progress * 3) / CROP_DEFINITIONS[kind].growthDays),
  ) as CropVisualStage;
}

export function isMature(kind: CropKind, progress: number): boolean {
  assertProgress(kind, progress);
  return progress === CROP_DEFINITIONS[kind].growthDays;
}

export function shipmentPayout(
  pending: CropCounts,
): { lines: ShipmentLine[]; total: number } {
  const lines: ShipmentLine[] = [];
  let total = 0;
  for (const crop of CROP_KINDS) {
    const quantity = pending[crop];
    if (!Number.isSafeInteger(quantity) || quantity < 0) {
      throw new RangeError(`${crop} shipment count must be a nonnegative safe integer`);
    }
    if (quantity === 0) continue;
    const unitValue = CROP_DEFINITIONS[crop].saleValue;
    const lineTotal = quantity * unitValue;
    const nextTotal = total + lineTotal;
    if (!Number.isSafeInteger(lineTotal) || !Number.isSafeInteger(nextTotal)) {
      throw new RangeError('shipment payout exceeds safe integer range');
    }
    lines.push({ crop, quantity, unitValue, lineTotal });
    total = nextTotal;
  }
  return { lines, total };
}
~~~

- [ ] **Step 5: Run focused GREEN and the current static check**

Run: `rtk bun test tests/game/cropDefinitions.test.ts`

Expected: PASS.

Run: `rtk bun run check`

Expected: zero errors and zero warnings because Task 1 is additive only.

- [ ] **Step 6: Self-review and commit the pure policy**

Run: `rtk git diff --check`

Verify with `rtk rg -n "Phaser|Svelte|stock|callback" src/game/core/cropDefinitions.ts` that the file contains none of those dependencies or concepts.

Commit:

~~~bash
rtk git add src/game/core/types.ts src/game/core/cropDefinitions.ts tests/game/cropDefinitions.test.ts
rtk git commit -m "feat: add crop economy definitions"
~~~

### Task 2: Generalized Farming Session, Economy Commands, and Overnight Payout

**Files:**

- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/dailyRhythm.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `tests/game/dailyRhythm.test.ts`
- Modify: `tests/game/GameSession.test.ts`

**Interfaces:**

- Consumes: `CROP_KINDS`, `CROP_DEFINITIONS`, `isMature`, and `shipmentPayout` from Task 1.
- Produces: generalized `CropSnapshot`, nested `InventorySnapshot`, widened `GameSnapshot` and `DaySummary`, exact economy result codes, required `shopCell`/`shippingCell` config, and `selectSeed`, `buySeeds`, and `depositCrop` commands.
- Preserves: `GameSession` direct methods, action validation order, HPA-592 costs, weather provider behavior, Day 14 rejection, pending-summary gate, and observation-only snapshot publication.

- [ ] **Step 1: Rewrite the test fixture around exhaustive crops and authored interaction cells**

In `tests/game/GameSession.test.ts`, add the definitions import and change the shared config to use three distinct unit-test interaction targets around the existing spawn:

~~~ts
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  isMature,
} from '../../src/game/core/cropDefinitions';
import type { CropKind, FarmingAction, GridCell, Weather } from '../../src/game/core/types';

const bedCell = { x: 6, y: 8 };
const shopCell = { x: 6, y: 10 };
const shippingCell = { x: 4, y: 10 };

function config(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 5.5, y: 9.5 },
      footprints: [
        { id: 'tree', x: 7, y: 4, width: 1, height: 1 },
        { id: 'building', x: 7, y: 7, width: 3, height: 2 },
      ],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells,
    bedCell,
    shopCell,
    shippingCell,
    nextWeather: () => 'sunny',
    ...overrides,
  };
}

function faceBed(session: GameSession): void {
  session.stepMovement({ screenX: 1, screenY: 0 }, 0);
  expect(session.snapshot().target).toEqual(bedCell);
}

function faceShop(session: GameSession): void {
  session.stepMovement({ screenX: 0, screenY: 1 }, 0);
  expect(session.snapshot().target).toEqual(shopCell);
}

function faceShipping(session: GameSession): void {
  session.stepMovement({ screenX: -1, screenY: 0 }, 0);
  expect(session.snapshot().target).toEqual(shippingCell);
}
~~~

Apply these exact migration replacements throughout the existing tests:

| Old contract | New contract |
| --- | --- |
| action `'turnipSeeds'` | action `'seeds'` |
| `turnip-planted` | `crop-planted` |
| `turnip-harvested` | `crop-harvested` |
| `no-turnip-seeds` | `no-selected-seeds` |
| `{ turnipSeeds: N, turnips: M }` | `{ seeds: { turnip: N, potato: 0, pumpkin: 0 }, crops: { turnip: M, potato: 0, pumpkin: 0 } }` |
| fixed three-iteration maturity helper | `CROP_DEFINITIONS[kind].growthDays` |

- [ ] **Step 2: Add RED tests for generalized lifecycles, commands, payout, and nested ownership**

Add these focused cases to `tests/game/GameSession.test.ts`:

~~~ts
function prepareCrop(session: GameSession, kind: CropKind, cell: GridCell): void {
  if (kind !== 'turnip') {
    faceShop(session);
    expect(session.buySeeds(kind, 1)).toEqual({ ok: true, code: 'seeds-purchased' });
  }
  expect(session.selectSeed(kind)).toEqual({ ok: true, code: 'seed-selected' });
  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
}

test('starts with the exact forgiving economy', () => {
  expect(sessionWithConfig().snapshot()).toMatchObject({
    money: 150,
    selectedSeed: 'turnip',
    inventory: {
      seeds: { turnip: 3, potato: 0, pumpkin: 0 },
      crops: { turnip: 0, potato: 0, pumpkin: 0 },
    },
    pendingShipment: { turnip: 0, potato: 0, pumpkin: 0 },
    shopCell,
    shippingCell,
  });
});

test.each(CROP_KINDS)('grows and harvests %s only at configured maturity', (kind) => {
  const session = sessionWithConfig();
  const cell = farmCells[0];
  prepareCrop(session, kind, cell);

  for (let progress = 0; progress < CROP_DEFINITIONS[kind].growthDays; progress += 1) {
    expect(session.harvest(cell)).toEqual({ ok: false, code: 'crop-immature' });
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    faceBed(session);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind,
      growth: progress + 1,
      wateredToday: false,
    });
    expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  }

  expect(session.water(cell)).toEqual({ ok: false, code: 'crop-mature' });
  expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
  expect(session.snapshot().inventory.crops[kind]).toBe(1);
});

test('buys exact quantities atomically and preserves failures', () => {
  const session = sessionWithConfig();
  faceShop(session);
  expect(session.buySeeds('potato', 2)).toEqual({ ok: true, code: 'seeds-purchased' });
  expect(session.snapshot()).toMatchObject({
    money: 70,
    inventory: { seeds: { turnip: 3, potato: 2, pumpkin: 0 } },
  });

  const beforeUnaffordable = session.snapshot();
  expect(session.buySeeds('pumpkin', 2)).toEqual({ ok: false, code: 'insufficient-funds' });
  expect(session.snapshot()).toEqual(beforeUnaffordable);

  for (const quantity of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    const beforeInvalid = session.snapshot();
    expect(session.buySeeds('turnip', quantity)).toEqual({ ok: false, code: 'invalid-quantity' });
    expect(session.snapshot()).toEqual(beforeInvalid);
  }
});

test('deposits immediately, pays once at sleep, and clears shipment before summary', () => {
  const session = sessionWithConfig();
  const cell = farmCells[0];
  prepareCrop(session, 'turnip', cell);
  for (let night = 0; night < 3; night += 1) {
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    faceBed(session);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  }
  expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });

  faceShipping(session);
  expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
  expect(session.snapshot().inventory.crops.turnip).toBe(0);
  expect(session.snapshot().pendingShipment.turnip).toBe(1);

  faceBed(session);
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
  const paid = session.snapshot();
  expect(paid.money).toBe(185);
  expect(paid.pendingShipment).toEqual({ turnip: 0, potato: 0, pumpkin: 0 });
  expect(paid.pendingDaySummary).toMatchObject({
    shipments: [{ crop: 'turnip', quantity: 1, unitValue: 35, lineTotal: 35 }],
    shippingIncome: 35,
    moneyAfterShipping: 185,
  });
  const beforeDuplicate = session.snapshot();
  expect(session.sleep()).toEqual({ ok: false, code: 'day-summary-pending' });
  expect(session.snapshot()).toEqual(beforeDuplicate);
});

test('deep-clones nested economy and summary snapshots', () => {
  const session = sessionWithConfig();
  const first = session.snapshot();
  const second = session.snapshot();
  expect(second.inventory).not.toBe(first.inventory);
  expect(second.inventory.seeds).not.toBe(first.inventory.seeds);
  expect(second.inventory.crops).not.toBe(first.inventory.crops);
  expect(second.pendingShipment).not.toBe(first.pendingShipment);
  expect(second.bedCell).not.toBe(first.bedCell);
  expect(second.shopCell).not.toBe(first.shopCell);
  expect(second.shippingCell).not.toBe(first.shippingCell);

  prepareCrop(session, 'turnip', farmCells[0]);
  for (let night = 0; night < 3; night += 1) {
    session.water(farmCells[0]);
    faceBed(session);
    session.sleep();
    session.acknowledgeDaySummary();
  }
  session.harvest(farmCells[0]);
  faceShipping(session);
  session.depositCrop('turnip', 1);
  faceBed(session);
  session.sleep();
  const summaryA = session.snapshot().pendingDaySummary!;
  const summaryB = session.snapshot().pendingDaySummary!;
  expect(summaryB).not.toBe(summaryA);
  expect(summaryB.shipments).not.toBe(summaryA.shipments);
  expect(summaryB.shipments[0]).not.toBe(summaryA.shipments[0]);
  summaryA.shipments[0].quantity = 999;
  expect(session.snapshot().pendingDaySummary?.shipments[0].quantity).toBe(1);
});
~~~

Add these exact rejection and gate assertions as well:

~~~ts
test('location and deposit failures preserve the complete snapshot', () => {
  const session = sessionWithConfig();
  faceBed(session);
  const awayFromShop = session.snapshot();
  expect(session.buySeeds('turnip', 1)).toEqual({ ok: false, code: 'not-at-shop' });
  expect(session.snapshot()).toEqual(awayFromShop);

  faceShipping(session);
  for (const quantity of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    const before = session.snapshot();
    expect(session.depositCrop('turnip', quantity)).toEqual({ ok: false, code: 'invalid-quantity' });
    expect(session.snapshot()).toEqual(before);
  }
  const beforeMissing = session.snapshot();
  expect(session.depositCrop('turnip', 1)).toEqual({ ok: false, code: 'insufficient-crops' });
  expect(session.snapshot()).toEqual(beforeMissing);
});

test('empty shipment produces a zero-income summary', () => {
  const session = sessionWithConfig();
  faceBed(session);
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
  expect(session.snapshot()).toMatchObject({
    money: 150,
    pendingShipment: { turnip: 0, potato: 0, pumpkin: 0 },
    pendingDaySummary: {
      shipments: [],
      shippingIncome: 0,
      moneyAfterShipping: 150,
    },
  });
});

test('supports partial then full deposit and rejects a double deposit', () => {
  const session = sessionWithConfig();
  const cells = farmCells.slice(0, 2);
  for (const cell of cells) prepareCrop(session, 'turnip', cell);
  for (let night = 0; night < 3; night += 1) {
    for (const cell of cells) expect(session.water(cell).ok).toBe(true);
    faceBed(session);
    expect(session.sleep().ok).toBe(true);
    expect(session.acknowledgeDaySummary().ok).toBe(true);
  }
  for (const cell of cells) expect(session.harvest(cell).ok).toBe(true);
  faceShipping(session);
  expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
  expect(session.snapshot().inventory.crops.turnip).toBe(1);
  expect(session.snapshot().pendingShipment.turnip).toBe(1);
  expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
  expect(session.snapshot().inventory.crops.turnip).toBe(0);
  expect(session.snapshot().pendingShipment.turnip).toBe(2);
  const beforeDouble = session.snapshot();
  expect(session.depositCrop('turnip', 1)).toEqual({ ok: false, code: 'insufficient-crops' });
  expect(session.snapshot()).toEqual(beforeDouble);
});
~~~

In the existing invalid-weather and Day 14 tests, include `money`, `pendingShipment`, and nested inventory in the before/after full-snapshot equality. Extend the existing blocked-command table with these exact entries:

~~~ts
['selectSeed', () => session.selectSeed('potato')],
['buySeeds', () => session.buySeeds('turnip', 1)],
['depositCrop', () => session.depositCrop('turnip', 1)],
~~~

- [ ] **Step 3: Run the focused domain tests and observe RED**

Run:

~~~bash
rtk bun test tests/game/cropDefinitions.test.ts tests/game/dailyRhythm.test.ts tests/game/GameSession.test.ts
~~~

Expected: FAIL because the generalized snapshot fields and the three economy commands do not exist, and current maturity is still fixed at three.

- [ ] **Step 4: Replace fixed turnip domain types and action cost key**

In `src/game/core/types.ts`, remove `GrowthLevel` and `TurnipCropSnapshot`, then use these exact shapes:

~~~ts
export type FarmingAction = 'hoe' | 'seeds' | 'wateringCan' | 'hands';

export interface CropSnapshot {
  kind: CropKind;
  growth: number;
  wateredToday: boolean;
}

export interface FarmTileSnapshot {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: CropSnapshot | null;
}

export interface InventorySnapshot {
  seeds: CropCounts;
  crops: CropCounts;
}

export interface DaySummary {
  completedDay: number;
  nextDay: number;
  cropsAdvanced: number;
  nextWeather: Weather;
  staminaRestored: number;
  shipments: ShipmentLine[];
  shippingIncome: number;
  moneyAfterShipping: number;
}

export interface GameSnapshot extends WorldSnapshot {
  day: number;
  timeMinutes: number;
  stamina: number;
  maxStamina: number;
  weather: Weather;
  pendingDaySummary: DaySummary | null;
  selectedAction: FarmingAction;
  selectedSeed: CropKind;
  money: number;
  inventory: InventorySnapshot;
  pendingShipment: CropCounts;
  farmTiles: FarmTileSnapshot[];
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
}
~~~

Replace the result unions with all existing general results plus these exact migrations/additions:

~~~ts
export type SuccessCode =
  | 'action-selected'
  | 'seed-selected'
  | 'soil-tilled'
  | 'crop-planted'
  | 'crop-watered'
  | 'crop-harvested'
  | 'seeds-purchased'
  | 'crop-deposited'
  | 'day-advanced'
  | 'day-started';

export type FailureCode =
  | 'no-target'
  | 'not-farm-cell'
  | 'already-tilled'
  | 'soil-untilled'
  | 'crop-present'
  | 'no-selected-seeds'
  | 'no-crop'
  | 'already-watered'
  | 'crop-mature'
  | 'crop-immature'
  | 'nothing-to-interact'
  | 'not-at-bed'
  | 'not-at-shop'
  | 'not-at-shipping-bin'
  | 'invalid-quantity'
  | 'insufficient-funds'
  | 'insufficient-crops'
  | 'action-too-late'
  | 'insufficient-stamina'
  | 'day-summary-pending'
  | 'rain-waters-crops'
  | 'day-limit-reached'
  | 'no-day-summary';
~~~

In `src/game/core/dailyRhythm.ts`, rename only the cost key and keep its values:

~~~ts
export const ACTION_COSTS = {
  hoe: { minutes: 30, stamina: 3 },
  seeds: { minutes: 20, stamina: 1 },
  wateringCan: { minutes: 20, stamina: 2 },
  hands: { minutes: 20, stamina: 1 },
} as const satisfies Readonly<Record<FarmingAction, ActionCost>>;
~~~

Update the exact expectation in `tests/game/dailyRhythm.test.ts` from `turnipSeeds` to `seeds`.

- [ ] **Step 5: Generalize GameSession state, construction, and deep snapshots**

In `src/game/core/GameSession.ts`, import the Task 1 helpers and use these state primitives:

~~~ts
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  isMature,
  shipmentPayout,
} from './cropDefinitions';

const STARTING_MONEY = 150;
const STARTING_SEEDS: CropCounts = { turnip: 3, potato: 0, pumpkin: 0 };

interface MutableCrop {
  kind: CropKind;
  growth: number;
  wateredToday: boolean;
}

function cloneCounts(counts: CropCounts): CropCounts {
  return { turnip: counts.turnip, potato: counts.potato, pumpkin: counts.pumpkin };
}
~~~

Make `shopCell` and `shippingCell` required in `GameSessionConfig`. Clone all three interaction cells, require integer in-bounds coordinates, require three distinct cell keys, preserve the existing bed/farm/collision checks, and store the clones. Initialize money, selected seed, nested inventory, and pending shipment from fresh records.

Use these exact ownership fields and constructor validation:

~~~ts
private readonly bedCell: GridCell;
private readonly shopCell: GridCell;
private readonly shippingCell: GridCell;
private selectedSeed: CropKind = 'turnip';
private money = STARTING_MONEY;
private inventory: InventorySnapshot = {
  seeds: cloneCounts(STARTING_SEEDS),
  crops: { turnip: 0, potato: 0, pumpkin: 0 },
};
private pendingShipment: CropCounts = { turnip: 0, potato: 0, pumpkin: 0 };

const bedCell = { ...config.bedCell };
const shopCell = { ...config.shopCell };
const shippingCell = { ...config.shippingCell };
const interactionCells = [bedCell, shopCell, shippingCell];
for (const cell of interactionCells) {
  if (!Number.isInteger(cell.x) || !Number.isInteger(cell.y)
    || cell.x < 0 || cell.x >= world.width
    || cell.y < 0 || cell.y >= world.height) {
    throw new Error('GameSession: interaction cells must be integer cells in bounds');
  }
}
if (new Set(interactionCells.map(cellKey)).size !== interactionCells.length) {
  throw new Error('GameSession: bed, shop, and shipping cells must be distinct');
}
~~~

Implement the snapshot clone exactly at every nested economy boundary:

~~~ts
pendingDaySummary: this.pendingDaySummary ? {
  ...this.pendingDaySummary,
  shipments: this.pendingDaySummary.shipments.map((line) => ({ ...line })),
} : null,
selectedAction: this.selectedAction,
selectedSeed: this.selectedSeed,
money: this.money,
inventory: {
  seeds: cloneCounts(this.inventory.seeds),
  crops: cloneCounts(this.inventory.crops),
},
pendingShipment: cloneCounts(this.pendingShipment),
farmTiles: this.farmTiles.map((tile): FarmTileSnapshot => ({
  position: { ...tile.position },
  soil: tile.soil,
  crop: tile.crop ? { ...tile.crop } : null,
})),
bedCell: { ...this.bedCell },
shopCell: { ...this.shopCell },
shippingCell: { ...this.shippingCell },
~~~

- [ ] **Step 6: Generalize farming and implement direct economy commands**

Use `seeds` in selected-action dispatch. Plant `selectedSeed`, decrement its matching seed count, and return `crop-planted`. Water and sleep use `isMature`; harvest requires `isMature`, remembers the crop kind before clearing the tile, increments `inventory.crops[kind]`, and returns `crop-harvested`.

Add these direct commands with the exact validation order:

~~~ts
selectSeed(kind: CropKind): CommandResult {
  const activeFailure = this.activeDayFailure();
  if (activeFailure) return activeFailure;
  this.selectedSeed = kind;
  return { ok: true, code: 'seed-selected' };
}

buySeeds(kind: CropKind, quantity: number): CommandResult {
  const activeFailure = this.activeDayFailure();
  if (activeFailure) return activeFailure;
  if (!sameCell(this.world.snapshot().target, this.shopCell)) {
    return { ok: false, code: 'not-at-shop' };
  }
  const total = CROP_DEFINITIONS[kind].seedPrice * quantity;
  if (!Number.isSafeInteger(quantity) || quantity <= 0 || !Number.isSafeInteger(total)) {
    return { ok: false, code: 'invalid-quantity' };
  }
  if (this.money < total) return { ok: false, code: 'insufficient-funds' };
  this.money -= total;
  this.inventory.seeds[kind] += quantity;
  return { ok: true, code: 'seeds-purchased' };
}

depositCrop(kind: CropKind, quantity: number): CommandResult {
  const activeFailure = this.activeDayFailure();
  if (activeFailure) return activeFailure;
  if (!sameCell(this.world.snapshot().target, this.shippingCell)) {
    return { ok: false, code: 'not-at-shipping-bin' };
  }
  const pendingAfter = this.pendingShipment[kind] + quantity;
  if (!Number.isSafeInteger(quantity) || quantity <= 0 || !Number.isSafeInteger(pendingAfter)) {
    return { ok: false, code: 'invalid-quantity' };
  }
  if (this.inventory.crops[kind] < quantity) {
    return { ok: false, code: 'insufficient-crops' };
  }
  this.inventory.crops[kind] -= quantity;
  this.pendingShipment[kind] = pendingAfter;
  return { ok: true, code: 'crop-deposited' };
}
~~~

- [ ] **Step 7: Integrate one payout into the existing sleep transaction**

After location/day checks and next-weather validation, call the pure helper before any mutation:

~~~ts
const payout = shipmentPayout(this.pendingShipment);
~~~

Advance only watered/rainy crops for which `isMature(kind, growth)` is false. Then credit `payout.total`, clear all three pending counts, and create the summary with cloned lines:

~~~ts
this.money += payout.total;
this.pendingShipment = { turnip: 0, potato: 0, pumpkin: 0 };
this.pendingDaySummary = {
  completedDay,
  nextDay: this.day,
  cropsAdvanced,
  nextWeather,
  staminaRestored,
  shipments: payout.lines.map((line) => ({ ...line })),
  shippingIncome: payout.total,
  moneyAfterShipping: this.money,
};
~~~

Keep rejected sleep, invalid weather, Day 14, duplicate sleep, and summary acknowledgment free of payout side effects.

- [ ] **Step 8: Run focused GREEN and the complete unit suite**

Run:

~~~bash
rtk bun test tests/game/cropDefinitions.test.ts tests/game/dailyRhythm.test.ts tests/game/GameSession.test.ts
rtk bun test
~~~

Expected: all focused and full Bun tests pass. Do not run or claim a global Svelte check yet; the approved domain-first rename leaves only stale adapter consumers in `farmVisuals.ts`, `ActionController.ts`, `ProofScene.ts`, and `Overlay.svelte`, which Tasks 4 and 5 remove.

- [ ] **Step 9: Record the three required mutation proofs**

Perform each mutation one at a time, run the named focused test, observe failure, then restore the production line before the next mutation:

1. Replace the affordability guard with `if (false)`; the atomic insufficient-funds test must fail because money/seeds change.
2. Temporarily omit `this.inventory.crops[kind] -= quantity`; the deposit test must fail because carried inventory remains present.
3. Temporarily omit the pending-shipment reset in sleep; the payout test must fail because shipment is not cleared.

After restoring all three lines, rerun:

~~~bash
rtk bun test tests/game/cropDefinitions.test.ts tests/game/dailyRhythm.test.ts tests/game/GameSession.test.ts
rtk git diff --check
~~~

Expected: PASS and no whitespace errors.

- [ ] **Step 10: Self-review and commit the authoritative domain stage**

Confirm `rtk rg -n "growth === 3|growth < 3|as GrowthLevel|turnipSeeds|turnip-planted|turnip-harvested" src/game/core tests/game` returns no stale domain contract. Confirm failed commands compare equal to their before snapshot and no command accepts a provider, callback, generic item, or generic dispatch object.

Commit:

~~~bash
rtk git add src/game/core/types.ts src/game/core/dailyRhythm.ts src/game/core/GameSession.ts tests/game/dailyRhythm.test.ts tests/game/GameSession.test.ts
rtk git commit -m "feat: add authoritative crop economy"
~~~

### Task 3: Deterministic Crop/Scenery Assets and Closed Map Fixture

**Files:**

- Modify: `tools/generate-proof-assets.ts`
- Create (generated): `src/assets/sprites/proof-crops.png`
- Modify (generated): `src/assets/sprites/proof-scenery.png`
- Modify (generated): `src/assets/maps/proof-map.json`
- Delete: `src/assets/sprites/proof-turnip.png`
- Modify: `src/game/core/types.ts`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `tests/game/loadProofMap.test.ts`
- Modify: `tests/game/ProofWorld.test.ts`

**Interfaces:**

- Consumes: exact map cells and crop order from the approved design; required `shopCell` and `shippingCell` in `GameSessionConfig` from Task 2.
- Produces: `proof-crops.png` 128×144, `proof-scenery.png` 288×96, exact object IDs 7–10, `SceneryKind` including `shipping-bin`, and `ParsedProofMap.shopCell`/`shippingCell`.
- Preserves: 12×12 map, farm cells, spawn 2.5,9.5, bed 6,8, tree/building positions and footprints, layer IDs, projection metadata, and existing generated asset determinism.

- [ ] **Step 1: Change fixture expectations first and observe RED**

Update the primary contract test in `tests/game/loadProofMap.test.ts` to these exact values:

~~~ts
expect(raw.nextobjectid).toBe(11);
expect(markers.objects).toEqual(expect.arrayContaining([
  expect.objectContaining({ id: 5, name: 'player-spawn' }),
  expect.objectContaining({ id: 6, name: 'bed-interaction' }),
  expect.objectContaining({ id: 9, name: 'shop-counter' }),
  expect.objectContaining({ id: 10, name: 'shipping-bin' }),
]));

const parsed = parseProofMap(raw, projection);
expect(parsed.world.footprints).toEqual([
  { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
  { id: 'building', x: 7, y: 7, width: 2, height: 2 },
  { id: 'shipping-bin', x: 6.2, y: 10.2, width: 0.6, height: 0.6 },
]);
expect(parsed.scenery.map(({ id, kind, frame, world, stableOrder }) => (
  [id, kind, frame, world, stableOrder]
))).toEqual([
  ['tree', 'tree', 0, { x: 480, y: 192 }, 1],
  ['building', 'building', 1, { x: 384, y: 288 }, 2],
  ['shipping-bin', 'shipping-bin', 2, { x: 256, y: 272 }, 7],
]);
expect(parsed.bedCell).toEqual({ x: 6, y: 8 });
expect(parsed.shopCell).toEqual({ x: 6, y: 7 });
expect(parsed.shippingCell).toEqual({ x: 6, y: 10 });
~~~

Replace the PNG dimension table entries with:

~~~ts
['proof-scenery.png', 288, 96],
['proof-soil.png', 128, 32],
['proof-crops.png', 128, 144],
~~~

Remove the `proof-turnip.png` expectation. Run:

~~~bash
rtk bun test tests/game/loadProofMap.test.ts
~~~

Expected: FAIL on current `nextobjectid: 7`, missing markers/scenery/footprint, old scenery dimensions, and missing `proof-crops.png`.

- [ ] **Step 2: Add exact malformed-fixture rows before parser changes**

Extend the existing table-driven mutation tests with these exact mutations and messages:

~~~ts
['stale nextobjectid', (raw) => { raw.nextobjectid = 10; }, /nextobjectid must be 11/],
['missing shipping scenery', (raw) => {
  const layer = withLayer(raw, 'Scenery') as unknown as { objects: Array<{ name: string }> };
  layer.objects = layer.objects.filter(({ name }) => name !== 'shipping-bin');
}, /expected tree, building, and shipping-bin scenery objects/],
['wrong shipping scenery id', (raw) => {
  withObject(raw, 'Scenery', 'shipping-bin').id = 8;
}, /scenery shipping-bin.id must be 7/],
['wrong shipping gid', (raw) => {
  withObject(raw, 'Scenery', 'shipping-bin').gid = 4;
}, /scenery shipping-bin.gid must be 5/],
['wrong shipping footprint id', (raw) => {
  withObject(raw, 'Collision', 'shipping-bin').id = 7;
}, /footprint shipping-bin.id must be 8/],
['wrong shipping footprint position', (raw) => {
  withObject(raw, 'Collision', 'shipping-bin').x = 0;
}, /footprint shipping-bin is not at its authored logical position/],
['missing shop marker', (raw) => {
  const layer = withLayer(raw, 'Markers') as unknown as { objects: Array<{ name: string }> };
  layer.objects = layer.objects.filter(({ name }) => name !== 'shop-counter');
}, /expected exactly one shop-counter marker/],
['wrong shop marker id', (raw) => {
  withObject(raw, 'Markers', 'shop-counter').id = 10;
}, /shop-counter.id must be 9/],
['wrong shipping marker cell', (raw) => {
  withObject(raw, 'Markers', 'shipping-bin').x = 0;
}, /shipping-bin marker must be at logical cell 6,10/],
~~~

Run the focused parser test again and retain the RED output.

- [ ] **Step 3: Expand the deterministic pixel assets**

In `tools/generate-proof-assets.ts`, make the scenery surface 288×96. Preserve the first two frames, add a small seed sign to the building frame, and draw the third frame as the shipping bin. Use the existing pixel helpers and these exact frame bounds/colors:

~~~ts
const scenery = createSurface(288, 96);
// Existing tree remains in x 0..95 and building remains in x 96..191.
fillRect(scenery, 128, 50, 32, 12, '#f6d365');
fillRect(scenery, 134, 53, 20, 3, '#3f7847');
fillRect(scenery, 208, 58, 64, 30, '#8f5f3d');
fillRect(scenery, 204, 52, 72, 8, '#5d3d2b');
fillRect(scenery, 214, 64, 52, 8, '#b98552');
fillRect(scenery, 220, 88, 8, 8, '#4a352d');
fillRect(scenery, 252, 88, 8, 8, '#4a352d');
~~~

Replace the turnip surface with one 128×144 crop surface. Four stages run across each row and crop rows follow `turnip`, `potato`, `pumpkin`. Use one palette per crop and the exact row/frame placement below so every frame is visibly distinct without storing a Phaser frame in gameplay:

~~~ts
const crops = createSurface(128, 144);
const cropPalettes = [
  { leaf: '#4f9c47', leafLight: '#68b454', root: '#e5b86b', outline: '#855531' },
  { leaf: '#4b8e43', leafLight: '#7ab45b', root: '#c99a58', outline: '#79502f' },
  { leaf: '#3f8041', leafLight: '#66a94c', root: '#e88738', outline: '#8a4c24' },
] as const;

cropPalettes.forEach((palette, cropIndex) => {
  const rowY = cropIndex * 48;
  for (let stage = 0; stage < 4; stage += 1) {
    const x = stage * 32;
    if (stage === 0) {
      fillRect(crops, x + 14, rowY + 34, 4 + cropIndex, 4, palette.root);
      continue;
    }
    fillRect(crops, x + 14, rowY + 25 - stage * 4, 4, 11 + stage * 4, palette.leaf);
    fillRect(crops, x + 7 - stage, rowY + 26 - stage * 3, 9 + stage * 2, 4 + stage, palette.leafLight);
    fillRect(crops, x + 17, rowY + 22 - stage * 4, 7 + stage * 2, 4 + stage, palette.leaf);
    fillDiamond(
      crops,
      x + 16,
      rowY + 38,
      3 + stage * 2 + cropIndex,
      4 + stage * 2,
      palette.root,
      palette.outline,
    );
  }
});
~~~

Write `proof-crops.png` instead of `proof-turnip.png`. Remove the tracked old binary with `rtk git rm src/assets/sprites/proof-turnip.png` only after the new generator output exists.

- [ ] **Step 4: Generate the exact Tiled fixture atomically**

Use these exact generator constants and objects:

~~~ts
const shippingBin = project({ x: 6.5, y: 10.5 });
const shopCounter = project({ x: 6.5, y: 7.5 });
const shippingMarker = project({ x: 6.5, y: 10.5 });
const shippingRect = logicalPolygon(8, 'shipping-bin', 6.2, 10.2, 6.8, 10.8);

const sceneryTileset = {
  firstgid: 3,
  columns: 3,
  image: '../sprites/proof-scenery.png',
  imageheight: 96,
  imagewidth: 288,
  margin: 0,
  name: 'proof-scenery',
  objectalignment: 'bottom',
  spacing: 0,
  tilecount: 3,
  tileheight: 96,
  tilewidth: 96,
  grid: { height: 32, orientation: 'isometric', width: 64 },
};
~~~

Append object 7 to `sceneryLayer.objects` with name/type `shipping-bin`, gid 5, x/y from `shippingBin`, dimensions 96×96, rotation 0, and visible true. Append `shippingRect` after the existing collision objects. Append these points after spawn and bed:

~~~ts
{
  id: 9,
  name: 'shop-counter',
  type: '',
  point: true,
  x: shopCounter.x,
  y: shopCounter.y,
  rotation: 0,
  visible: true,
},
{
  id: 10,
  name: 'shipping-bin',
  type: '',
  point: true,
  x: shippingMarker.x,
  y: shippingMarker.y,
  rotation: 0,
  visible: true,
},
~~~

Set `nextobjectid: 11`, then run `rtk bun run assets:generate` once to regenerate both PNGs and the JSON fixture.

- [ ] **Step 5: Close the parser around the new exact fixture**

In `src/game/core/types.ts`, change:

~~~ts
export type SceneryKind = 'tree' | 'building' | 'shipping-bin';
~~~

In `src/game/phaser/loadProofMap.ts`:

- add `shopCell` and `shippingCell` to both `ParsedProofMap` and `ParsedMarkers`;
- permit exactly four marker names;
- require `nextobjectid === 11`;
- require scenery columns/tilecount 3 and image width 288;
- require exactly tree/building/shipping-bin scenery with IDs 1/2/7, gids 3/4/5, frames 0/1/2, and world points 480,192 / 384,288 / 256,272;
- require collision IDs 3/4/8 and exact footprint positions/dimensions;
- require marker IDs 5/6/9/10 and cells spawn 2.5,9.5 / bed 6,8 / shop 6,7 / shipping 6,10; and
- return cloned shop/shipping cells with the parsed map.

Use closed records rather than condition chains that silently accept new kinds:

~~~ts
const sceneryContract = {
  tree: { objectId: 1, gid: 3, frame: 0, world: { x: 480, y: 192 } },
  building: { objectId: 2, gid: 4, frame: 1, world: { x: 384, y: 288 } },
  'shipping-bin': { objectId: 7, gid: 5, frame: 2, world: { x: 256, y: 272 } },
} as const satisfies Record<SceneryKind, {
  objectId: number;
  gid: number;
  frame: number;
  world: { x: number; y: number };
}>;

const footprintContract = {
  tree: { objectId: 3, x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
  building: { objectId: 4, x: 7, y: 7, width: 2, height: 2 },
  'shipping-bin': { objectId: 8, x: 6.2, y: 10.2, width: 0.6, height: 0.6 },
} as const;
~~~

- [ ] **Step 6: Add a real movement/collision route regression**

In `tests/game/ProofWorld.test.ts`, load the generated map through `parseProofMap` and add this bounded route helper and test. It uses production movement only and checks the existing diagonal bed route no longer intersects the bin:

~~~ts
function stepUntil(
  world: ProofWorld,
  input: MovementInput,
  predicate: (snapshot: WorldSnapshot) => boolean,
): WorldSnapshot {
  for (let frame = 0; frame < 300; frame += 1) {
    world.step(input, 16);
    const current = world.snapshot();
    if (predicate(current)) return current;
  }
  throw new Error(`route did not settle: ${JSON.stringify(world.snapshot())}`);
}

test('keeps farm, bed, shop, and shipping routes clear around the authored bin', async () => {
  const raw = await Bun.file(resolve(import.meta.dir, '../../src/assets/maps/proof-map.json')).json();
  const projection = new ProjectionAdapter(
    { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    { width: 12, height: 12 },
  );
  const parsed = parseProofMap(raw, projection);
  const world = new ProofWorld(parsed.world, projection.metrics);

  world.step({ screenX: 1, screenY: 0 }, 0);
  expect(world.snapshot().target).toEqual({ x: 3, y: 8 });
  stepUntil(world, { screenX: 1, screenY: 1 }, ({ player }) => player.position.x >= 5.1);
  stepUntil(world, { screenX: 0, screenY: -1 }, ({ player }) => player.position.y <= 9.8);
  stepUntil(world, { screenX: 1, screenY: 1 }, ({ player }) => player.position.x >= 5.1);
  world.step({ screenX: 1, screenY: 0 }, 0);
  expect(world.snapshot().target).toEqual(parsed.bedCell);

  stepUntil(world, { screenX: 0, screenY: -1 }, ({ player }) => player.position.x <= 4.5);
  expect(stepUntil(world, { screenX: 1, screenY: 0 }, ({ target }) => (
    target?.x === 6 && target.y === 7
  )).target).toEqual(parsed.shopCell);
  expect(stepUntil(world, { screenX: 0, screenY: 1 }, ({ target }) => (
    target?.x === 6 && target.y === 10
  )).target).toEqual(parsed.shippingCell);

  const atShipping = world.snapshot().player.position;
  expect(atShipping.x + 0.18).toBeLessThan(6.2);
  let pushed = atShipping;
  for (let step = 0; step < 50; step += 1) {
    pushed = moveWithCollisions(pushed, { x: 0.02, y: 0.02 }, parsed.world, 0.18);
  }
  expect(pushed.y).toBeLessThanOrEqual(10.02 + 1e-9);
  expect(intersects(
    { id: 'player', x: pushed.x - 0.18, y: pushed.y - 0.18, width: 0.36, height: 0.36 },
    parsed.world.footprints.find(({ id }) => id === 'shipping-bin')!,
  )).toBe(false);
  world.step({ screenX: 1, screenY: 0 }, 0);
  expect(world.snapshot().target).toEqual(parsed.bedCell);
  stepUntil(world, { screenX: 0, screenY: -1 }, ({ player }) => player.position.x <= 4.8);
  expect(stepUntil(world, { screenX: 1, screenY: 0 }, ({ target }) => (
    target?.x === 6 && target.y === 7
  )).target).toEqual(parsed.shopCell);
});
~~~

Add the required imports for `resolve`, `intersects`, `moveWithCollisions`, `ProjectionAdapter`, `parseProofMap`, `MovementInput`, and `WorldSnapshot`.

- [ ] **Step 7: Run focused GREEN and deterministic regeneration proof**

Run:

~~~bash
rtk bun test tests/game/loadProofMap.test.ts tests/game/ProofWorld.test.ts
rtk bun run assets:generate
shasum src/assets/maps/proof-map.json src/assets/sprites/proof-crops.png src/assets/sprites/proof-scenery.png > /tmp/phoenix-economy-assets-first.sha
rtk bun run assets:generate
shasum src/assets/maps/proof-map.json src/assets/sprites/proof-crops.png src/assets/sprites/proof-scenery.png > /tmp/phoenix-economy-assets-second.sha
diff /tmp/phoenix-economy-assets-first.sha /tmp/phoenix-economy-assets-second.sha
~~~

Expected: focused tests PASS and `diff` exits 0.

- [ ] **Step 8: Self-review and commit the atomic authored-map task**

Run `rtk git diff --check`. Verify only `proof-crops.png` exists for crop art and `proof-turnip.png` is deleted. Verify `rtk rg -n "nextobjectid.*7|columns: 2|imagewidth: 192|tilecount: 2" src/game/phaser/loadProofMap.ts tools/generate-proof-assets.ts` finds no stale scenery contract.

Commit all generator, parser, fixture, and generated outputs together:

~~~bash
rtk git add tools/generate-proof-assets.ts src/assets/maps/proof-map.json src/assets/sprites/proof-crops.png src/assets/sprites/proof-scenery.png src/game/core/types.ts src/game/phaser/loadProofMap.ts tests/game/loadProofMap.test.ts tests/game/ProofWorld.test.ts
rtk git add -u src/assets/sprites/proof-turnip.png
rtk git commit -m "feat: author shop and shipping map"
~~~

### Task 4: Crop Frame Mapping and Closed Phaser Interaction Adapter

**Files:**

- Modify: `src/game/core/farmVisuals.ts`
- Modify: `tests/game/farmVisuals.test.ts`
- Create: `src/game/phaser/interactionIntent.ts`
- Create: `tests/game/interactionIntent.test.ts`
- Modify: `src/game/phaser/ActionController.ts`
- Modify: `tests/game/ActionController.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`

**Interfaces:**

- Consumes: generalized snapshots/commands from Task 2 and exact map/scenery/parser output from Task 3.
- Produces: row-major crop sheet indices, `ActionSample.interact`, `InteractionIntent`, direct economy `SceneCommands`, `ProofSceneDependencies.onInteractIntent`, and shipping-bin depth/debug state.
- Preserves: one GateBoundKeys owner, rising-edge semantics, command publication, movement/camera behavior, target rendering, farm sprite reconciliation, and idempotent scene teardown.

- [ ] **Step 1: Replace fixed crop-frame expectations with exhaustive RED cases**

In `tests/game/farmVisuals.test.ts`, retain soil wetness and stable-order cases, then replace all crop-frame-equals-growth assertions with this table:

~~~ts
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  visualStage,
} from '../../src/game/core/cropDefinitions';

test('maps every crop progress to its row-major sheet frame', () => {
  for (const kind of CROP_KINDS) {
    const growthDays = CROP_DEFINITIONS[kind].growthDays;
    for (let growth = 0; growth <= growthDays; growth += 1) {
      expect(farmVisuals({
        position: { x: 2, y: 7 },
        soil: 'tilled',
        crop: { kind, growth, wateredToday: false },
      }, 'sunny')).toEqual({
        soilFrame: 0,
        cropFrame: CROP_KINDS.indexOf(kind) * 4 + visualStage(kind, growth),
      });
    }
  }
});

test('does not confuse slow-crop progress with a sheet frame', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'pumpkin', growth: 5, wateredToday: false },
  }, 'sunny')).toEqual({ soilFrame: 0, cropFrame: 10 });
});
~~~

Run `rtk bun test tests/game/farmVisuals.test.ts`.

Expected: FAIL because `cropFrame` still equals growth and still uses `GrowthLevel`.

- [ ] **Step 2: Add RED tests for the closed interaction resolver and renamed edge**

Create `tests/game/interactionIntent.test.ts`:

~~~ts
import { expect, test } from 'bun:test';
import { interactionIntentForTarget } from '../../src/game/phaser/interactionIntent';

const cells = {
  bedCell: { x: 6, y: 8 },
  shopCell: { x: 6, y: 7 },
  shippingCell: { x: 6, y: 10 },
};

test.each([
  [{ x: 6, y: 8 }, 'sleep'],
  [{ x: 6, y: 7 }, 'shop'],
  [{ x: 6, y: 10 }, 'shipping'],
  [{ x: 3, y: 8 }, null],
  [null, null],
] as const)('resolves target %p to %p', (target, expected) => {
  expect(interactionIntentForTarget(target, cells)).toBe(expected);
});
~~~

In `tests/game/ActionController.test.ts`, replace action `turnipSeeds` with `seeds`, replace every `sleep` sample field with `interact`, and rename the held-key test to assert E emits `interact` only once until release and again after repress.

Run:

~~~bash
rtk bun test tests/game/interactionIntent.test.ts tests/game/ActionController.test.ts
~~~

Expected: FAIL because the resolver does not exist and `ActionSample` still exposes `sleep`.

- [ ] **Step 3: Implement exact crop-sheet frame mapping**

Replace `src/game/core/farmVisuals.ts` with the same soil logic and this crop mapping:

~~~ts
import { CROP_KINDS, visualStage } from './cropDefinitions';
import type { FarmTileSnapshot, Weather } from './types';

export interface FarmVisualFrames {
  soilFrame: number | null;
  cropFrame: number | null;
}

export function farmVisuals(
  tile: FarmTileSnapshot,
  weather: Weather,
): FarmVisualFrames {
  const wet = weather === 'rainy' || tile.crop?.wateredToday === true;
  const cropFrame = tile.crop === null
    ? null
    : CROP_KINDS.indexOf(tile.crop.kind) * 4
      + visualStage(tile.crop.kind, tile.crop.growth);
  return {
    soilFrame: tile.soil === 'untilled' ? null : wet ? 1 : 0,
    cropFrame,
  };
}
~~~

Keep `farmStableOrder` unchanged.

- [ ] **Step 4: Implement the closed pure intent resolver**

Create `src/game/phaser/interactionIntent.ts`:

~~~ts
import type { GridCell } from '../core/types';

export type InteractionIntent = 'sleep' | 'shop' | 'shipping';

export interface InteractionCells {
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
}

function sameCell(a: GridCell | null, b: GridCell): boolean {
  return a !== null && a.x === b.x && a.y === b.y;
}

export function interactionIntentForTarget(
  target: GridCell | null,
  cells: InteractionCells,
): InteractionIntent | null {
  if (sameCell(target, cells.bedCell)) return 'sleep';
  if (sameCell(target, cells.shopCell)) return 'shop';
  if (sameCell(target, cells.shippingCell)) return 'shipping';
  return null;
}
~~~

- [ ] **Step 5: Rename the controller output without changing key ownership**

In `src/game/phaser/ActionController.ts`:

- map key `2` to `seeds`;
- rename `ActionSample.sleep` to `ActionSample.interact`;
- rename the remembered E flag accordingly; and
- keep numeric, Space, and E rising-edge/reset/destroy behavior identical.

The returned shape is exactly:

~~~ts
export interface ActionSample {
  selectedAction: FarmingAction | null;
  useSelected: boolean;
  interact: boolean;
}
~~~

- [ ] **Step 6: Wire the exact map, crops, commands, and intent callback into ProofScene**

In `src/game/phaser/ProofScene.ts`:

1. Replace `TURNIP_KEY`/`proof-turnip.png` with `CROPS_KEY`/`proof-crops.png`, still using 32×48 frames.
2. Use `Map<SceneryKind, Phaser.GameObjects.Sprite>` and add `shipping-bin` to `BaseEntityId`, initial `DebugDepths`, sorted depth entries, and the required-sprite guard.
3. Pass parsed `shopCell` and `shippingCell` into `GameSession`.
4. Remove the narrowing cast when inserting parsed scenery.
5. Add the economy facades to `SceneCommands`:

~~~ts
selectSeed(kind: CropKind): CommandResult;
buySeeds(kind: CropKind, quantity: number): CommandResult;
depositCrop(kind: CropKind, quantity: number): CommandResult;
~~~

6. Replace `onSleepPrompt()` in `ProofSceneDependencies` with:

~~~ts
onInteractIntent(intent: InteractionIntent): void;
~~~

7. Route one `action.interact` edge with the pure resolver:

~~~ts
if (action.interact) {
  const snapshot = this.session.snapshot();
  const intent = interactionIntentForTarget(snapshot.target, snapshot);
  if (intent === null) {
    this.publishCommand({ ok: false, code: 'nothing-to-interact' });
  } else {
    this.dependencies.onInteractIntent(intent);
  }
}
~~~

8. Implement each new scene command as a direct `GameSession` call passed through `publishCommand`; do not add `openShop`, `openShipping`, a generic dispatch method, or a panel result code.
9. Use `CROPS_KEY` plus the 0–11 `farmVisuals` frame when creating/reconciling crop sprites.
10. Add the shipping sprite to the same footpoint sort as player/tree/building/crops with stable order 3; keep farm crop stable orders unchanged and return a fresh complete debug-depth object.

- [ ] **Step 7: Run focused GREEN and adapter regressions**

Run:

~~~bash
rtk bun test tests/game/farmVisuals.test.ts tests/game/interactionIntent.test.ts tests/game/ActionController.test.ts tests/game/GameLifecycle.test.ts tests/game/KeyboardController.test.ts
rtk bun test
~~~

Expected: focused tests and the Bun suite PASS. `rtk bun run check` is still intentionally deferred: `GameHost.svelte`, `App.svelte`, and `Overlay.svelte` still consume the old callback and turnip-only presentation contract until Task 5.

- [ ] **Step 8: Self-review and commit the Phaser adapter stage**

Run:

~~~bash
rtk rg -n "proof-turnip|TURNIP_KEY|ActionSample\.sleep|action\.sleep|onSleepPrompt|Map<'tree'" src/game src/game/phaser tests/game
rtk git diff --check
~~~

Expected: no stale matches and no whitespace errors. Confirm an empty-target E calls only `publishCommand` with `nothing-to-interact`, while sleep/shop/shipping emit only the closed intent callback.

Commit:

~~~bash
rtk git add src/game/core/farmVisuals.ts tests/game/farmVisuals.test.ts src/game/phaser/interactionIntent.ts tests/game/interactionIntent.test.ts src/game/phaser/ActionController.ts tests/game/ActionController.test.ts src/game/phaser/ProofScene.ts
rtk git commit -m "feat: render economy world interactions"
~~~

### Task 5: App-Owned Economy Panels and Shared Quantity Stepper

**Files:**

- Create: `src/components/QuantityStepper.svelte`
- Modify: `src/components/GameHost.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`
- Modify: `tests/e2e/helpers.ts`
- Create: `tests/e2e/economy.pw.ts`

**Interfaces:**

- Consumes: `InteractionIntent`, direct `SceneCommands`, authoritative `GameSnapshot`, and shared crop definitions.
- Produces: one App-owned `'shop' | 'shipping' | null` state, one continuous `economy-panel` InputGate reason, one controlled `QuantityStepper`, accessible panels, and authoritative HUD/feedback rendering.
- Preserves: sleep confirmation/summary ownership, continuous day-transition lock, overlay lock, lifecycle cleanup, HMR cleanup, observation-only development hook, and all four farming action controls.

- [ ] **Step 1: Move the reusable target-acquisition helper into the shared E2E module**

Move the existing production-key `acquireTarget` implementation from `tests/e2e/farming.pw.ts` to `tests/e2e/helpers.ts` and export it with the same 3-second RAF deadline. Update `farming.pw.ts` to import it. The shared signature is:

~~~ts
export async function acquireTarget(
  page: Page,
  key: string,
  target: GridCell,
): Promise<void>;
~~~

Do not change its key-down/finally-key-up behavior, camera assertion, or error context.

- [ ] **Step 2: Write focused browser RED for interaction routing, shop purchase, and empty shipping**

Create `tests/e2e/economy.pw.ts` with these helpers and first test:

~~~ts
import { expect, test, type Locator, type Page } from '@playwright/test';
import type { GridCell } from '../../src/game/core/types';
import {
  acquireTarget,
  gameSnapshot,
  moveUntilPlayerAxis,
  snapshot,
  waitForWorld,
} from './helpers';

const SHOP_CELL: GridCell = { x: 6, y: 7 };
const SHIPPING_CELL: GridCell = { x: 6, y: 10 };

async function moveToShop(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 4.5);
  await acquireTarget(page, 'd', SHOP_CELL);
}

async function openInteraction(page: Page, name: string): Promise<Locator> {
  const dialog = page.getByRole('dialog', { name });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  return dialog;
}

test('routes E to authoritative shop and shipping presentation', async ({ page }) => {
  await waitForWorld(page);
  const initial = await gameSnapshot(page);
  await page.keyboard.down('e');
  try {
    await expect(page.locator('[data-feedback]')).toHaveText('Nothing to interact with');
  } finally {
    await page.keyboard.up('e');
  }
  expect(await gameSnapshot(page)).toEqual(initial);

  await moveToShop(page);
  const shop = await openInteraction(page, 'Seed shop');
  await expect(page.getByRole('button', { name: 'Turnip seeds' })).toBeFocused();
  expect((await snapshot(page)).locked).toBe(true);

  await page.getByRole('button', { name: 'Potato seeds' }).click();
  await page.getByRole('button', { name: 'Buy 1 Potato seed' }).click();
  await expect.poll(async () => (await gameSnapshot(page)).money).toBe(110);
  await expect.poll(async () => (await gameSnapshot(page)).inventory.seeds.potato).toBe(1);
  await page.keyboard.press('Escape');
  await expect(shop).toBeHidden();
  expect((await snapshot(page)).locked).toBe(false);

  await acquireTarget(page, 's', SHIPPING_CELL);
  const shipping = await openInteraction(page, 'Shipping bin');
  await expect(shipping.getByRole('button', { name: /Deposit/ })).toBeDisabled();
  await expect(shipping.getByRole('button', { name: 'Close' })).toBeFocused();
  await shipping.getByRole('button', { name: 'Close' }).click();
  await expect(shipping).toBeHidden();
  expect((await snapshot(page)).locked).toBe(false);
});
~~~

Run: `rtk bun run test:e2e -- tests/e2e/economy.pw.ts`

Expected: FAIL because App/GameHost still expose `onSleepPrompt`, economy dialogs do not exist, and off-target E still has old presentation behavior.

- [ ] **Step 3: Implement one controlled quantity-stepper component**

Create `src/components/QuantityStepper.svelte`:

~~~svelte
<script lang="ts">
  interface Props {
    quantity: number;
    max: number;
    disabled: boolean;
    itemName: string;
    actionLabel: 'Buy' | 'Deposit';
    onQuantityChange: (quantity: number) => void;
    onSubmit: () => void;
  }

  let {
    quantity,
    max,
    disabled,
    itemName,
    actionLabel,
    onQuantityChange,
    onSubmit,
  }: Props = $props();

  const transactionDisabled = $derived(disabled || max < 1 || quantity < 1 || quantity > max);
  const setQuantity = (value: number) => {
    if (disabled || max < 1) return;
    onQuantityChange(Math.min(max, Math.max(1, value)));
  };
</script>

<div class="quantity-stepper" aria-label={`${actionLabel} quantity`}>
  <button
    type="button"
    aria-label="Decrease quantity"
    disabled={disabled || max < 1 || quantity <= 1}
    onclick={() => setQuantity(quantity - 1)}
  >−</button>
  <output aria-live="polite">{quantity}</output>
  <button
    type="button"
    aria-label="Increase quantity"
    disabled={disabled || max < 1 || quantity >= max}
    onclick={() => setQuantity(quantity + 1)}
  >+</button>
  <button
    type="button"
    disabled={disabled || max < 1 || quantity === max}
    onclick={() => setQuantity(max)}
  >Max</button>
  <button
    type="button"
    disabled={transactionDisabled}
    onclick={onSubmit}
  >{actionLabel} {quantity} {itemName}{quantity === 1 ? '' : 's'}</button>
</div>
~~~

The component owns no quantity state, crop table, price, inventory, money, panel mode, or command call.

- [ ] **Step 4: Replace the sleep-only host callback with the closed intent callback**

In `src/components/GameHost.svelte`, import `InteractionIntent`, replace the `onSleepPrompt` prop with `onInteractIntent`, forward it into `ProofSceneDependencies`, and leave snapshot cloning/development hooks unchanged:

~~~ts
onInteractIntent: (intent: InteractionIntent) => void;
~~~

- [ ] **Step 5: Make App the sole panel/lock owner**

In `src/App.svelte`, import `InteractionIntent`, add:

~~~ts
type EconomyPanel = Exclude<InteractionIntent, 'sleep'> | null;
let economyPanel = $state<EconomyPanel>(null);

function syncEconomyPanel(): void {
  inputGate.set('economy-panel', economyPanel !== null);
}

function handleInteractIntent(intent: InteractionIntent): void {
  if (dayTransitionActive || economyPanel !== null) return;
  if (intent === 'sleep') {
    sleepPromptVisible = true;
    syncDayTransition();
    return;
  }
  economyPanel = intent;
  syncEconomyPanel();
}

function closeEconomyPanel(): void {
  economyPanel = null;
  syncEconomyPanel();
}
~~~

Update `resetGamePresentation` and `onMount` teardown to clear `economyPanel` and set `economy-panel` false idempotently. Pass `onInteractIntent={handleInteractIntent}` to GameHost and pass `economyPanel`/`onCloseEconomyPanel={closeEconomyPanel}` to Overlay. Never let a sleep prompt or morning summary coexist with an economy panel.

- [ ] **Step 6: Generalize the HUD, feedback, seed selection, and one modal implementation**

In `src/components/Overlay.svelte`:

- import `CROP_DEFINITIONS`, `CROP_KINDS`, `QuantityStepper`, `CropKind`, and `untrack`;
- replace `turnipSeeds` action/labels with `seeds` and `2 Seeds: ${definition.displayName}`;
- render money, selected seed, all three seed counts, all three carried crop counts, and total pending quantity from the authoritative snapshot;
- add three compact seed-selection buttons calling `commands.selectSeed(kind)` and reflecting `snapshot.selectedSeed`;
- make `actionsReady` require `economyPanel === null` as well as the existing day-transition guards;
- add exhaustive messages for every new success/failure result, including `Nothing to interact with`, without a local price/total calculation; and
- render summary shipment rows directly from `summary.shipments`, followed by `shippingIncome` and `moneyAfterShipping`.

Pin accessible names so browser and keyboard users see one unambiguous control per role:

- inventory seed selectors: `Select Turnip`, `Select Potato`, `Select Pumpkin`;
- shop crop rows: `Turnip seeds`, `Potato seeds`, `Pumpkin seeds`;
- shipping crop rows: `Turnip crop`, `Potato crop`, `Pumpkin crop`;
- action button: `2 Seeds: <DisplayName>`; and
- shared transaction buttons: `Buy <N> <DisplayName> seed(s)` or `Deposit <N> <DisplayName>(s)`.

Use one local presentation state for both panel modes:

~~~ts
let selectedPanelCrop = $state<CropKind>('turnip');
let quantity = $state(1);
let transactionSubmitting = $state(false);
let previousEconomyPanel = $state<'shop' | 'shipping' | null>(null);
let economyDialog = $state<HTMLElement | null>(null);
let economyCloseButton = $state<HTMLButtonElement | null>(null);

const panelMaximum = $derived.by(() => {
  if (!snapshot || !economyPanel) return 0;
  if (economyPanel === 'shop') {
    return Math.floor(snapshot.money / CROP_DEFINITIONS[selectedPanelCrop].seedPrice);
  }
  return snapshot.inventory.crops[selectedPanelCrop];
});

$effect(() => {
  const panel = economyPanel;
  if (panel === previousEconomyPanel) return;
  previousEconomyPanel = panel;
  transactionSubmitting = false;
  quantity = 1;
  if (panel === null) return;
  selectedPanelCrop = untrack(() => (
    CROP_KINDS.find((kind) => panel === 'shop'
      ? Boolean(snapshot && snapshot.money >= CROP_DEFINITIONS[kind].seedPrice)
      : Boolean(snapshot && snapshot.inventory.crops[kind] > 0)) ?? 'turnip'
  ));
  void tick().then(() => requestAnimationFrame(() => {
    if (economyPanel !== panel) return;
    const firstUsableRow = economyDialog
      ?.querySelector<HTMLButtonElement>('[data-economy-row]:not(:disabled)');
    (firstUsableRow ?? economyCloseButton)?.focus();
  }));
});

function selectPanelCrop(kind: CropKind): void {
  selectedPanelCrop = kind;
  quantity = 1;
}

function submitEconomyTransaction(): void {
  if (!snapshot || !commands || !economyPanel || transactionSubmitting) return;
  transactionSubmitting = true;
  try {
    if (economyPanel === 'shop') commands.buySeeds(selectedPanelCrop, quantity);
    else commands.depositCrop(selectedPanelCrop, quantity);
  } finally {
    transactionSubmitting = false;
  }
}
~~~

Render one `role="dialog"`, `aria-modal="true"` branch named `Seed shop` or `Shipping bin` and bind the dialog element to `economyDialog`. Its three keyed crop-row buttons carry `data-economy-row`, use stable `CROP_KINDS` order, call `selectPanelCrop(kind)`, and display definition name, growth nights, seed price or sale value, and the relevant owned count. The focus effect queries the first enabled row after render; when none are enabled, it focuses Close. Pass `quantity`, `panelMaximum`, submitting state, definition display name, mode label, and the two callbacks into the shared stepper.

Add a `<svelte:window onkeydown={...}>` handler that closes only an open economy panel on Escape. Background farming, seed-selection, and overlay-lock controls are disabled while any modal is active.

- [ ] **Step 7: Add focused accessible panel styling**

In `src/app.css`, reuse the existing modal layer colors and add only bounded economy styles:

~~~css
.economy-dialog {
  width: min(430px, calc(100% - 32px));
  max-height: calc(100% - 32px);
  overflow: auto;
}

.economy-crop-rows,
.seed-selection,
.quantity-stepper {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.economy-crop-rows button[aria-pressed="true"],
.seed-selection button[aria-pressed="true"] {
  background: #365f4d;
}

.quantity-stepper {
  align-items: center;
  margin-top: 10px;
}

.quantity-stepper output {
  min-width: 2.5ch;
  text-align: center;
  font-weight: 700;
}
~~~

Keep the 640×360 stage, pixel scaling, and existing visual tokens unchanged.

- [ ] **Step 8: Run Svelte local review, static GREEN, and focused browser GREEN**

At execution time, read the two required Svelte skills completely. Run the available local Svelte autofixer for `QuantityStepper.svelte`, `GameHost.svelte`, `App.svelte`, and `Overlay.svelte`. If it attempts an unavailable network fetch or external source upload, stop that command, record the boundary, and perform manual Svelte 5 review instead.

Run:

~~~bash
rtk bun run check
rtk bun test
rtk bun run test:e2e -- tests/e2e/economy.pw.ts
rtk bun run build
rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
~~~

Expected: static check reports zero errors/zero warnings; Bun suite passes; focused economy E2E passes; build succeeds with only the accepted Phaser chunk advisory; production hook scan exits 1 with no matches.

- [ ] **Step 9: Self-review lock symmetry and commit the presentation stage**

Manually trace open, Escape, Close, lifecycle reset, HMR dispose, error, sleep transition, and component teardown. Each path must clear `economy-panel` exactly once and leave no panel state. Confirm `rtk rg -n "seedPrice.*\*|saleValue.*\*|shippingIncome.*=" src/App.svelte src/components` finds no Svelte payout arithmetic.

Run `rtk git diff --check`, then commit:

~~~bash
rtk git add src/components/QuantityStepper.svelte src/components/GameHost.svelte src/App.svelte src/components/Overlay.svelte src/app.css tests/e2e/helpers.ts tests/e2e/economy.pw.ts tests/e2e/farming.pw.ts
rtk git commit -m "feat: add seed shop and shipping panels"
~~~

### Task 6: Complete Three-Crop Reinvestment Browser Acceptance

**Files:**

- Modify: `tests/e2e/helpers.ts`
- Modify: `tests/e2e/economy.pw.ts`
- Modify: `tests/e2e/farming.pw.ts`
- Modify: `tests/e2e/sleep-confirmation.pw.ts`
- Modify: `tests/e2e/world.pw.ts`
- Modify: `tests/e2e/lifecycle.pw.ts`

**Interfaces:**

- Consumes: only real keyboard input, visible Svelte controls, rendered pixels, and the existing observation-only snapshots.
- Produces: browser proof for exact purchases, all three growth schedules/frames, harvesting, final deposits, one itemized payout, reinvestment, focus/lock symmetry, collision routes, HMR/remount cleanup, and existing regression coverage.
- Preserves: Playwright retries 0, 3-second readiness/route deadlines, release-first key helpers, camera assertions, no test setters or command hooks, and all foundation/HPA-591/HPA-592 journeys.

- [ ] **Step 1: Generalize existing browser assertions to the new domain contract**

In `tests/e2e/farming.pw.ts` make these exact replacements:

| Old browser contract | New browser contract |
| --- | --- |
| action `turnipSeeds` | action `seeds` |
| `Turnip planted` | `Turnip planted` from generic `crop-planted` presentation |
| `Turnip harvested` | `Crop harvested` unless the authoritative UI can name the removed crop without inference |
| off-target E `You must be at the bed` | `Nothing to interact with` |
| `inventory.turnipSeeds` | `inventory.seeds.turnip` |
| `inventory.turnips` | `inventory.crops.turnip` |
| action label `Seeds` | `Seeds: Turnip` |

Keep the original three-night real-control turnip journey, crop screenshots, time/stamina assertions, weather branching, sleep cancel/confirm behavior, and depth/camera checks.

Update `tests/e2e/helpers.ts::confirmAndStartDay` so its summary assertion also accepts optional exact shipment expectations:

~~~ts
interface ExpectedDayTransition {
  completedDay: number;
  cropsAdvanced: number;
  staminaRestored: number;
  shipments?: ShipmentLine[];
  shippingIncome?: number;
  moneyAfterShipping?: number;
}
~~~

When provided, assert every visible line, shipping income, money after shipping, and matching authoritative summary before clicking Start Day. When omitted, assert zero income and no shipment rows.

- [ ] **Step 2: Add reusable real-key farm-hub and interaction routes**

In `tests/e2e/economy.pw.ts`, use these three farm cells, all reachable from one standing cell without teleportation:

~~~ts
const FARM_CELLS = {
  turnip: { x: 2, y: 7 },
  potato: { x: 4, y: 7 },
  pumpkin: { x: 4, y: 9 },
} as const satisfies Record<CropKind, GridCell>;

const FARM_TARGET_KEY = {
  turnip: 'w',
  potato: 'd',
  pumpkin: 's',
} as const satisfies Record<CropKind, string>;
~~~

Add these exact bounded routes:

~~~ts
async function moveShopToFarmHub(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['a', 'w'], 'x', 'lte', 3.5);
  await moveUntilPlayerAxis(page, ['a'], 'y', 'gte', 8.3);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 3.2);
  const player = (await snapshot(page)).player.position;
  expect(Math.floor(player.x)).toBe(3);
  expect(Math.floor(player.y)).toBe(8);
}

async function moveFarmHubToBed(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  const current = await snapshot(page);
  if (current.player.position.y >= 10) {
    await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
    await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  }
  await acquireTarget(page, 'd', { x: 6, y: 8 });
}

async function moveBedToFarmHub(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['a', 'w'], 'x', 'lte', 3.5);
  const current = await snapshot(page);
  if (current.player.position.y < 8.2) {
    await moveUntilPlayerAxis(page, ['a'], 'y', 'gte', 8.3);
  }
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 3.2);
  const player = (await snapshot(page)).player.position;
  expect(Math.floor(player.x)).toBe(3);
  expect(Math.floor(player.y)).toBe(8);
}

async function moveBedToShop(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 4.5);
  await acquireTarget(page, 'd', SHOP_CELL);
}

async function moveFarmHubToShipping(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await acquireTarget(page, 's', SHIPPING_CELL);
}
~~~

All helpers must retain key release in `finally` through the existing shared helpers and assert camera bounds after each settled leg.

- [ ] **Step 3: Add real-control action helpers without widening the hook**

Add local helpers that wait on visible feedback while keys remain down:

~~~ts
async function selectAction(page: Page, key: '1' | '2' | '3' | '4'): Promise<void> {
  await page.keyboard.down(key);
  try {
    await expect(page.locator('[data-feedback]')).toHaveText('Action selected');
  } finally {
    await page.keyboard.up(key);
  }
}

async function useSelected(
  page: Page,
  crop: CropKind,
  feedback: string | RegExp,
): Promise<GameSnapshot> {
  await acquireTarget(page, FARM_TARGET_KEY[crop], FARM_CELLS[crop]);
  await page.keyboard.down('Space');
  try {
    await expect(page.locator('[data-feedback]')).toHaveText(feedback);
  } finally {
    await page.keyboard.up('Space');
  }
  return gameSnapshot(page);
}

async function selectSeed(page: Page, crop: CropKind): Promise<void> {
  const label = CROP_DEFINITIONS[crop].displayName;
  await page.getByRole('button', { name: `Select ${label}` }).click();
  await expect.poll(async () => (await gameSnapshot(page)).selectedSeed).toBe(crop);
  await expect(page.getByRole('button', { name: `2 Seeds: ${label}` }))
    .toHaveAttribute('aria-pressed', 'true');
}
~~~

These helpers may observe `gameSnapshot`; they must never invoke `SceneCommands` or mutate the window hook.

- [ ] **Step 4: Write the complete exact reinvestment journey**

Add one serial production journey to `tests/e2e/economy.pw.ts`:

~~~ts
test('buys, grows, ships, pays, and reinvests across all three crops', async ({ page }) => {
  await waitForWorld(page);
  await moveToShop(page);
  const shop = await openInteraction(page, 'Seed shop');

  await shop.getByRole('button', { name: 'Potato seeds' }).click();
  await shop.getByRole('button', { name: 'Buy 1 Potato seed' }).click();
  await shop.getByRole('button', { name: 'Pumpkin seeds' }).click();
  await shop.getByRole('button', { name: 'Buy 1 Pumpkin seed' }).click();
  await expect.poll(async () => (await gameSnapshot(page)).money).toBe(40);
  expect((await gameSnapshot(page)).inventory.seeds).toEqual({
    turnip: 3, potato: 1, pumpkin: 1,
  });
  await shop.getByRole('button', { name: 'Close' }).click();

  await moveShopToFarmHub(page);
  await selectAction(page, '1');
  for (const crop of CROP_KINDS) {
    await useSelected(page, crop, 'Soil tilled');
  }
  await selectAction(page, '2');
  for (const crop of CROP_KINDS) {
    await selectSeed(page, crop);
    await useSelected(page, crop, `${CROP_DEFINITIONS[crop].displayName} planted`);
  }

  for (let night = 1; night <= 7; night += 1) {
    await selectAction(page, '3');
    const beforeWater = await gameSnapshot(page);
    for (const crop of CROP_KINDS) {
      const tile = beforeWater.farmTiles.find(({ position }) => (
        position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y
      ));
      if (!tile?.crop || isMature(crop, tile.crop.growth)) continue;
      const feedback = beforeWater.weather === 'sunny'
        ? 'Crop watered'
        : 'Rain is watering the crops';
      await useSelected(page, crop, feedback);
    }
    await moveFarmHubToBed(page);
    const beforeSleep = await gameSnapshot(page);
    await openInteraction(page, 'Sleep until tomorrow?');
    await confirmAndStartDay(page, {
      completedDay: beforeSleep.day,
      cropsAdvanced: CROP_KINDS.filter((crop) => night <= CROP_DEFINITIONS[crop].growthDays).length,
      staminaRestored: beforeSleep.maxStamina - beforeSleep.stamina,
      shipments: [],
      shippingIncome: 0,
      moneyAfterShipping: 40,
    });
    const afterSleep = await gameSnapshot(page);
    for (const crop of CROP_KINDS) {
      const tile = afterSleep.farmTiles.find(({ position }) => (
        position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y
      ));
      expect(tile?.crop?.growth).toBe(Math.min(night, CROP_DEFINITIONS[crop].growthDays));
    }
    if (night < 7) await moveBedToFarmHub(page);
  }

  await moveBedToFarmHub(page);
  await selectAction(page, '4');
  for (const crop of CROP_KINDS) await useSelected(page, crop, /harvested/i);
  expect((await gameSnapshot(page)).inventory.crops).toEqual({
    turnip: 1, potato: 1, pumpkin: 1,
  });

  await moveFarmHubToShipping(page);
  const shipping = await openInteraction(page, 'Shipping bin');
  for (const crop of CROP_KINDS) {
    const name = CROP_DEFINITIONS[crop].displayName;
    await shipping.getByRole('button', { name: `${name} crop` }).click();
    await shipping.getByRole('button', { name: `Deposit 1 ${name}` }).click();
    await expect.poll(async () => (await gameSnapshot(page)).inventory.crops[crop]).toBe(0);
    await expect.poll(async () => (await gameSnapshot(page)).pendingShipment[crop]).toBe(1);
  }
  await shipping.getByRole('button', { name: 'Close' }).click();

  await acquireTarget(page, 'd', { x: 6, y: 8 });
  const beforePayout = await gameSnapshot(page);
  await openInteraction(page, 'Sleep until tomorrow?');
  const lines = [
    { crop: 'turnip', quantity: 1, unitValue: 35, lineTotal: 35 },
    { crop: 'potato', quantity: 1, unitValue: 75, lineTotal: 75 },
    { crop: 'pumpkin', quantity: 1, unitValue: 140, lineTotal: 140 },
  ] as const;
  await confirmAndStartDay(page, {
    completedDay: beforePayout.day,
    cropsAdvanced: 0,
    staminaRestored: beforePayout.maxStamina - beforePayout.stamina,
    shipments: [...lines],
    shippingIncome: 250,
    moneyAfterShipping: 290,
  });
  expect((await gameSnapshot(page)).pendingShipment).toEqual({
    turnip: 0, potato: 0, pumpkin: 0,
  });

  await moveBedToShop(page);
  const reinvest = await openInteraction(page, 'Seed shop');
  await reinvest.getByRole('button', { name: 'Turnip seeds' }).click();
  await reinvest.getByRole('button', { name: 'Increase quantity' }).click();
  await reinvest.getByRole('button', { name: 'Increase quantity' }).click();
  await reinvest.getByRole('button', { name: 'Increase quantity' }).click();
  await reinvest.getByRole('button', { name: 'Buy 4 Turnip seeds' }).click();
  const final = await gameSnapshot(page);
  expect(final.money).toBe(210);
  expect(final.inventory.seeds.turnip).toBe(6);
});
~~~

Import `CROP_DEFINITIONS`, `CROP_KINDS`, `isMature`, `CropKind`, and `GameSnapshot`. The test starts with three turnip seeds, spends 110G, receives exactly 250G, and buys four more turnip seeds for 80G; those arithmetic assertions are fixed acceptance values, not alternate production formulas.

- [ ] **Step 5: Prove distinct rendered crops and shipping depth/collision**

Move the existing `waitForCameraToSettle` and `captureCropSprite` helpers from `tests/e2e/farming.pw.ts` into `tests/e2e/helpers.ts`. Import `Buffer` from `node:buffer`, `gridToWorld` from `src/game/core/isometric`, and `GridCell` from `src/game/core/types`. Replace the hard-coded turnip footpoint with this generalized implementation:

~~~ts
const E2E_PROJECTION = {
  tileWidth: 64,
  tileHeight: 32,
  origin: { x: 384, y: 0 },
} as const;

export async function captureCropSprite(page: Page, cell: GridCell): Promise<Buffer> {
  await waitForCameraToSettle(page);
  const debug = await snapshot(page);
  const canvas = page.locator('canvas');
  const box = await canvas.boundingBox();
  if (!box) throw new Error('Phoenix canvas is not measurable');

  const scaleX = box.width / 640;
  const scaleY = box.height / 360;
  expect(scaleX).toBeGreaterThan(0);
  expect(Number.isInteger(scaleX)).toBe(true);
  expect(scaleY).toBe(scaleX);

  const footpoint = gridToWorld(
    { x: cell.x + 0.5, y: cell.y + 0.5 },
    E2E_PROJECTION,
  );
  const clip = {
    x: box.x + (footpoint.x - 16 - debug.camera.scrollX) * scaleX,
    y: box.y + (footpoint.y - 48 - debug.camera.scrollY) * scaleY,
    width: 32 * scaleX,
    height: 48 * scaleY,
  };
  expect(clip.x).toBeGreaterThanOrEqual(box.x);
  expect(clip.y).toBeGreaterThanOrEqual(box.y);
  expect(clip.x + clip.width).toBeLessThanOrEqual(box.x + box.width);
  expect(clip.y + clip.height).toBeLessThanOrEqual(box.y + box.height);
  return page.screenshot({ clip, animations: 'disabled' });
}
~~~

Update the existing turnip frame test to call `captureCropSprite(page, CROP_CELL)`. Before harvesting in the full journey, add:

~~~ts
const matureSprites = await Promise.all(
  CROP_KINDS.map((crop) => captureCropSprite(page, FARM_CELLS[crop])),
);
for (let left = 0; left < matureSprites.length; left += 1) {
  for (let right = left + 1; right < matureSprites.length; right += 1) {
    expect(Buffer.compare(matureSprites[left], matureSprites[right])).not.toBe(0);
  }
}
~~~

In `tests/e2e/world.pw.ts`, extend the authored-footprint test with the exact shipping rectangle and a real route that:

1. reaches the shop target;
2. reaches shipping target 6,10;
3. holds movement toward the bin and remains outside `{ x: 6.2, y: 10.2, width: 0.6, height: 0.6 }` using player half extent 0.18;
4. returns to bed and farm targets; and
5. observes player/shipping-bin depth ordering reverse when passing its footpoint.

Use `DebugDepths['shipping-bin']`; do not add a new test hook.

- [ ] **Step 6: Cover panel focus/lock cleanup through lifecycle and HMR**

In `tests/e2e/lifecycle.pw.ts`, import `acquireTarget`, `gameSnapshot`, and `moveUntilPlayerAxis`, then add this real route locally so the lifecycle file does not import another Playwright test module:

~~~ts
async function moveLifecycleToShop(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 4.5);
  await acquireTarget(page, 'd', { x: 6, y: 7 });
}

async function openShop(page: Page): Promise<Locator> {
  const dialog = page.getByRole('dialog', { name: 'Seed shop' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  return dialog;
}
~~~

Add the lifecycle case with exact locked-state assertions:

~~~ts
test('economy panel owns focus and clears its lock on Escape and remount', async ({ page }) => {
  await waitForWorld(page);
  await moveLifecycleToShop(page);
  const dialog = await openShop(page);
  await expect(dialog.getByRole('button', { name: 'Turnip seeds' })).toBeFocused();
  expect((await snapshot(page)).locked).toBe(true);

  const beforeWorld = await snapshot(page);
  const beforeGame = await gameSnapshot(page);
  for (const key of ['w', 'a', 's', 'd', 'Space', '1', '2', '3', '4', 'e']) {
    await holdKey(page, key, 100);
  }
  const afterWorld = await snapshot(page);
  const afterGame = await gameSnapshot(page);
  expect(afterWorld.player.position).toEqual(beforeWorld.player.position);
  expect(afterGame.selectedAction).toBe(beforeGame.selectedAction);
  await expect(dialog).toBeVisible();

  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
  expect((await snapshot(page)).locked).toBe(false);

  const reopened = await openShop(page);
  await page.evaluate(() => window.__PHOENIX_TEST__!.remount());
  await expect(reopened).toBeHidden();
  await expect(page.getByText('World ready')).toBeVisible();
  expect((await snapshot(page)).locked).toBe(false);
});
~~~

In the existing real-Vite-HMR test, after measuring pre-HMR movement and before writing the probe, run `moveLifecycleToShop`, open the shop, close it with Escape, and assert `listenerCensus(page)` is still exactly `{ keydown: 1, keyup: 1 }`. Retain the existing identical assertion after HMR; do not add a second listener hook.

In `tests/e2e/sleep-confirmation.pw.ts`, extend the existing real bed journey. While `Sleep until tomorrow?` is visible, assert the `Seed shop` and `Shipping bin` dialogs have count zero, every background farming/seed/lock control is disabled, and another held E does not add a dialog. Repeat the zero-economy-dialog and disabled-background assertions while `Morning summary` is visible. Use the existing readiness-safe held-E pattern and release it in `finally`.

- [ ] **Step 7: Run focused route stability and the full browser suite**

Run the risky focused journeys three consecutive times without retries:

~~~bash
rtk bun run test:e2e -- tests/e2e/economy.pw.ts --grep "buys, grows, ships, pays, and reinvests"
rtk bun run test:e2e -- tests/e2e/economy.pw.ts --grep "buys, grows, ships, pays, and reinvests"
rtk bun run test:e2e -- tests/e2e/economy.pw.ts --grep "buys, grows, ships, pays, and reinvests"
rtk bun run test:e2e -- tests/e2e/world.pw.ts --grep "shipping"
rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts --grep "economy"
rtk bun run test:e2e
~~~

Expected: every focused run and the complete suite pass with retries 0. If a route fails, use `superpowers:systematic-debugging`, inspect the last released snapshot, fix the owning readiness/route predicate, and stop after the first failed proposed fix rather than stacking timeouts or retries.

- [ ] **Step 8: Run non-browser regressions and commit acceptance**

Run:

~~~bash
rtk bun test
rtk bun run check
rtk bun run build
rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
rtk git diff --check
~~~

Expected: Bun and static checks pass; build succeeds with only the accepted Phaser chunk advisory; production scan exits 1/no matches; diff check is clean.

Commit:

~~~bash
rtk git add tests/e2e/helpers.ts tests/e2e/economy.pw.ts tests/e2e/farming.pw.ts tests/e2e/sleep-confirmation.pw.ts tests/e2e/world.pw.ts tests/e2e/lifecycle.pw.ts
rtk git commit -m "test: cover the crop reinvestment loop"
~~~

### Task 7: Handoff Documentation, Whole-Branch Review, and macOS Delivery

**Files:**

- Modify: `tests/config/handoff.test.ts`
- Modify: `README.md`
- Create locally (ignored evidence): `.superpowers/sdd/2026-08-15-phoenix-economy-slice/task-7-report.md`

**Interfaces:**

- Consumes: the complete HPA-593 branch and existing seven-command clean-checkout verifier.
- Produces: current controls/economy/map documentation, a reviewed branch, browser/native evidence, verified macOS app/DMG artifacts, and an auditable final report.
- Preserves: verifier command order, package pins, Tauri configuration, Rust shell, macOS-only claim, and accurate signing/accessibility limitations.

- [ ] **Step 1: Write the failing documentation contract**

Extend the first test in `tests/config/handoff.test.ts` with these exact HPA-593 strings:

~~~ts
for (const economyText of [
  'HPA-593',
  '150G',
  'Turnip',
  'Potato',
  'Pumpkin',
  '3 watered nights',
  '5 watered nights',
  '7 watered nights',
  'Seed shop',
  'Shipping bin',
  '20G',
  '35G',
  '40G',
  '75G',
  '70G',
  '140G',
  'Select Turnip',
  'Select Potato',
  'Select Pumpkin',
  'minus, plus, Max',
  'Deposit',
  'Shipping income',
  'reinvest',
  'shop cell 6,7',
  'shipping cell 6,10',
]) {
  expect(readme.toLowerCase()).toContain(economyText.toLowerCase());
}
~~~

Run: `rtk bun test tests/config/handoff.test.ts`

Expected: FAIL because README still describes only HPA-588/HPA-591/HPA-592 and turnips.

- [ ] **Step 2: Update README with exact player and maintainer handoff**

Update the opening to include HPA-593 and describe the full three-crop economy loop. Preserve all prerequisite/setup/build commands. Replace the controls/farming section with exact behavior:

- 1 Hoe, 2 Seeds using selected crop, 3 Water, 4 Hands;
- Select Turnip/Potato/Pumpkin buttons change the seed kind without changing the farming action;
- E opens sleep, Seed shop, or Shipping bin from its highlighted authored target;
- shop and shipping use minus, plus, Max, explicit Buy/Deposit, Escape/Close, and world-input lock;
- session starts with 150G and three turnip seeds;
- exact crop growth/price/sale table;
- deposits are final and free;
- one successful sleep credits itemized shipping income once and clears pending shipment before the Morning summary; and
- the 290G/210G acceptance example demonstrates reinvestment without making it a guaranteed general session outcome.

Add the exact map contract in prose: shop cell 6,7 on the existing building, shipping cell 6,10, three-frame 288×96 scenery sheet, and the existing compact 12×12 world.

- [ ] **Step 3: Run docs GREEN and request whole-branch code review**

Run:

~~~bash
rtk bun test tests/config/handoff.test.ts
rtk bun test
rtk bun run check
rtk git diff --check
~~~

Expected: all pass with zero static diagnostics.

At execution time load `superpowers:requesting-code-review` and perform a whole-branch review against base `7e4f453`, the approved design, and this plan. Review especially:

- all three maturity call sites;
- snapshot nested identities;
- payout order/clearing/duplicate protection;
- map IDs/coordinates/collision routes;
- crop sheet frame formula;
- `onInteractIntent` versus presentation commands;
- modal/input-lock symmetry;
- Svelte arithmetic duplication;
- Playwright real-control and hook boundaries; and
- accidental frameworks or speculative abstractions.

Fix only confirmed findings with focused RED/GREEN evidence, rerun the owning task checks, and request a focused re-review of any changed seam.

- [ ] **Step 4: Commit the completed source and documentation before clean-checkout verification**

Commit the documentation after review fixes are committed and the worktree is otherwise clean:

~~~bash
rtk git add README.md tests/config/handoff.test.ts
rtk git commit -m "docs: document Phoenix crop economy"
~~~

Record the exact final source HEAD and commit range in the ignored task report. `verify:clean` archives committed `HEAD`, so do not run it against uncommitted source.

- [ ] **Step 5: Run the complete committed-head verification matrix**

Run in this order:

~~~bash
rtk bun run assets:generate
rtk git diff --exit-code -- src/assets tools/generate-proof-assets.ts
rtk bun run check
rtk bun test
rtk bun run test:e2e
rtk bun run build
rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
rtk cargo check --manifest-path src-tauri/Cargo.toml
rtk bun run tauri:build
~~~

Expected:

- deterministic regeneration leaves no diff;
- static check reports zero errors and zero warnings;
- unit and Playwright suites pass with retries 0;
- Vite build passes with only the accepted Phaser chunk-size advisory;
- production hook scan exits 1 with no matches;
- Cargo check passes; and
- Tauri produces `src-tauri/target/release/bundle/macos/Phoenix.app` and `src-tauri/target/release/bundle/dmg/Phoenix_0.1.0_aarch64.dmg`.

If sandboxed DMG creation fails with `hdiutil: create failed - Device not configured`, prove that boundary with a minimal `hdiutil create` probe, then rerun the exact Tauri command once at the approved macOS host boundary. Do not change source to mask a host-device failure.

- [ ] **Step 6: Audit artifacts and perform bounded native smoke**

Audit and record:

- app and DMG sizes/paths;
- arm64 Mach-O architecture matching the host;
- bundle identifier `com.hapadona.phoenix`;
- version `0.1.0`;
- `hdiutil verify` result;
- `codesign -dv --verbose=4` metadata;
- strict `codesign --verify --deep --strict` result; and
- Gatekeeper `spctl` result.

Do not claim Developer ID signing or notarization when the build is ad hoc/linker-signed.

Launch only the task-created Phoenix app. Capture the exact Phoenix window if available and attempt a bounded smoke of: active HUD with 150G/three crops, real movement, opening the shop, and observing the shipping/morning-summary frontend. Stop if focus/accessibility targeting becomes ambiguous; browser E2E remains authoritative for transactions and the complete loop. Terminate only the exact Phoenix PID created by this task, then verify no Phoenix process or task-created port listener remains.

- [ ] **Step 7: Run the committed clean-checkout verifier once**

At the macOS host boundary run:

~~~bash
rtk bun run verify:clean
~~~

Expected: frozen install, Chromium install, static check, unit suite, full Playwright suite, production build, and Tauri app/DMG build all pass from the archived committed HEAD. Stop on the first failure, preserve exact evidence, and do not add retries or widen timeouts.

- [ ] **Step 8: Final audit and report**

Run:

~~~bash
rtk git diff --check
rtk git status --short --branch
rtk rg -n "GrowthLevel|turnipSeeds|proof-turnip|onSleepPrompt|openShop|openShipping" src tests README.md
~~~

Expected: clean worktree, clean diff check, and no stale contract matches. The task report must separate unit, browser, build, native visual, native interaction, signing, and clean-checkout evidence; list any unproven native behavior explicitly; and include the final commit SHAs without modifying verified source afterward.
