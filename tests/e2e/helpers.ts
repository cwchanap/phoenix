import { expect, type Page } from '@playwright/test';
import { Buffer } from 'node:buffer';
import { gridToWorld } from '../../src/game/core/isometric';
import type { DebugSnapshot } from '../../src/game/phaser/ProofScene';
import type {
  CropKind,
  FarmingAction,
  GameSnapshot,
  GridCell,
  ShipmentLine,
} from '../../src/game/core/types';
import { CROP_DEFINITIONS } from '../../src/game/core/cropDefinitions';

interface ExpectedDayTransition {
  completedDay: number;
  cropsAdvanced: number;
  staminaRestored: number;
  shipments?: ShipmentLine[];
  shippingIncome?: number;
  moneyAfterShipping?: number;
}

export async function waitForWorld(page: Page): Promise<void> {
  await page.goto('/');
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  const newGame = page.locator('[data-new-game]');
  await expect(newGame).toBeEnabled();
  await newGame.click();
  await expect(page.getByText('World ready')).toBeVisible();
  await page.waitForFunction(() => Boolean(window.__PHOENIX_TEST__?.snapshot()));
}

export const snapshot = (page: Page): Promise<DebugSnapshot> =>
  page.evaluate(() => window.__PHOENIX_TEST__!.snapshot());

export async function acquireTarget(page: Page, key: string, target: GridCell): Promise<void> {
  const initial = await snapshot(page);
  if (initial.visibleTarget && initial.target?.x === target.x && initial.target?.y === target.y) {
    assertCameraWithinBounds(initial);
    return;
  }

  const deadline = Date.now() + 3_000;
  const waitForSettledFrame = async (timeout: number): Promise<void> => {
    await page.evaluate(
      (timeoutMs) =>
        new Promise<void>((resolve, reject) => {
          const deadlineAt = performance.now() + timeoutMs;
          let previous: {
            x: number;
            y: number;
            facing: string;
            target: GridCell | null;
            visibleTarget: boolean;
          } | null = null;
          const timer = window.setTimeout(() => {
            reject(new Error('Target did not settle after key release'));
          }, timeoutMs);
          const sample = () => {
            const current = window.__PHOENIX_TEST__!.snapshot();
            const state = {
              x: current.player.position.x,
              y: current.player.position.y,
              facing: current.player.facing,
              target: current.target ? { ...current.target } : null,
              visibleTarget: current.visibleTarget,
            };
            const positionSettled =
              previous !== null &&
              Math.abs(state.x - previous.x) < 0.0001 &&
              Math.abs(state.y - previous.y) < 0.0001;
            const targetSettled =
              previous !== null &&
              state.facing === previous.facing &&
              state.visibleTarget === previous.visibleTarget &&
              state.target?.x === previous.target?.x &&
              state.target?.y === previous.target?.y;
            if (positionSettled && targetSettled) {
              window.clearTimeout(timer);
              resolve();
              return;
            }
            previous = state;
            if (performance.now() >= deadlineAt) {
              window.clearTimeout(timer);
              reject(new Error('Target did not settle after key release'));
              return;
            }
            requestAnimationFrame(sample);
          };
          requestAnimationFrame(sample);
        }),
      timeout,
    );
  };

  let waitError: unknown;
  let released = initial;
  try {
    while (Date.now() < deadline) {
      await page.keyboard.press(key, { delay: 8 });

      const settleTimeout = deadline - Date.now();
      if (settleTimeout <= 0) break;
      try {
        await waitForSettledFrame(settleTimeout);
      } catch (error) {
        waitError = error;
        released = await snapshot(page).catch(() => released);
        break;
      }
      released = await snapshot(page);
      if (released.target?.x === target.x && released.target?.y === target.y) {
        expect(released.target, JSON.stringify({ initial, released })).toEqual(target);
        expect(released.visibleTarget).toBe(true);
        assertCameraWithinBounds(released);
        return;
      }
    }
  } catch (error) {
    waitError = error;
    released = await snapshot(page).catch(() => released);
  }

  const timeoutError =
    waitError instanceof Error
      ? waitError.message
      : `Target ${JSON.stringify(target)} was not acquired before the 3-second deadline`;
  throw new Error(`${timeoutError}; snapshots: ${JSON.stringify({ initial, released })}`);
}

export async function gameSnapshot(page: Page): Promise<GameSnapshot> {
  return page.evaluate(() => {
    const snapshot = window.__PHOENIX_TEST__?.gameSnapshot();
    if (!snapshot) throw new Error('Phoenix game snapshot is not ready');
    return snapshot;
  });
}

export async function waterForCurrentWeather(
  page: Page,
  targetKey: string,
  targetCell: GridCell,
): Promise<GameSnapshot> {
  await acquireTarget(page, targetKey, targetCell);
  await page.keyboard.down('1');
  try {
    await expect.poll(async () => (await gameSnapshot(page)).selectedAction).toBe('hoe');
  } finally {
    await page.keyboard.up('1');
  }
  await page.keyboard.down('3');
  try {
    await expect.poll(async () => (await gameSnapshot(page)).selectedAction).toBe('wateringCan');
  } finally {
    await page.keyboard.up('3');
  }
  // Movement is published through the observation-only snapshot; the game
  // snapshot is refreshed on commands. Merge the live world coordinates so a
  // rainy no-op compares domain state without retaining the prior waypoint.
  const observed = await snapshot(page);
  const before = {
    ...(await gameSnapshot(page)),
    player: {
      position: observed.player.position,
      facing: observed.player.facing,
    },
    target: observed.target,
  } satisfies GameSnapshot;
  const feedback = before.weather === 'sunny' ? 'Crop watered' : 'Rain is watering the crops';

  await page.keyboard.down('Space');
  try {
    if (before.weather === 'sunny') {
      await expect
        .poll(async () => (await gameSnapshot(page)).timeMinutes)
        .toBe(before.timeMinutes + 20);
    }
    await expect(page.locator('[data-feedback]')).toHaveText(feedback);
  } finally {
    await page.keyboard.up('Space');
  }

  const after = await gameSnapshot(page);
  if (before.weather === 'sunny') {
    expect(after.timeMinutes).toBe(before.timeMinutes + 20);
    expect(after.stamina).toBe(before.stamina - 2);
  } else {
    expect(after).toEqual(before);
  }
  return after;
}

export async function confirmAndStartDay(
  page: Page,
  expected: ExpectedDayTransition,
): Promise<GameSnapshot> {
  await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Morning summary' });
  await expect(dialog).toBeVisible();

  const pending = await gameSnapshot(page);
  const nextDay = expected.completedDay + 1;
  expect(pending.day).toBe(nextDay);
  expect(pending.pendingDaySummary).toEqual({
    completedDay: expected.completedDay,
    nextDay,
    cropsAdvanced: expected.cropsAdvanced,
    nextWeather: pending.weather,
    staminaRestored: expected.staminaRestored,
    shipments: expected.shipments ?? [],
    shippingIncome: expected.shippingIncome ?? 0,
    moneyAfterShipping: expected.moneyAfterShipping ?? pending.money,
  });
  await expect(dialog).toContainText('Day ' + expected.completedDay + ' complete');
  await expect(dialog).toContainText('Crops advanced: ' + expected.cropsAdvanced);
  await expect(dialog).toContainText('Next day: Day ' + nextDay);
  await expect(dialog).toContainText(
    'Weather: ' + (pending.weather === 'sunny' ? 'Sunny' : 'Rainy'),
  );
  await expect(dialog).toContainText('Stamina restored: ' + expected.staminaRestored);
  const shipments = expected.shipments ?? [];
  await expect(dialog.locator('[data-shipment-row]')).toHaveCount(shipments.length);
  for (const shipment of shipments) {
    const line = `${CROP_DEFINITIONS[shipment.crop].displayName}: ${shipment.quantity} × ${shipment.unitValue} = ${shipment.lineTotal}`;
    await expect(dialog.locator('[data-shipment-row]').filter({ hasText: line })).toHaveCount(1);
  }
  const shippingIncome = expected.shippingIncome ?? 0;
  const moneyAfterShipping = expected.moneyAfterShipping ?? pending.money;
  await expect(dialog).toContainText('Shipping income: ' + shippingIncome);
  await expect(dialog).toContainText('Money after shipping: ' + moneyAfterShipping);
  expect((await snapshot(page)).locked).toBe(true);

  const start = page.getByRole('button', { name: 'Start Day ' + nextDay });
  await expect(page.locator('[data-save-status]')).toHaveText('Saved');
  await expect(start).toBeEnabled();
  await expect(start).toBeFocused();
  await start.click();
  await expect(dialog).toBeHidden();
  await expect(page.locator('[data-save-status]')).toHaveCount(0);
  await expect.poll(async () => (await gameSnapshot(page)).pendingDaySummary).toBeNull();
  expect((await snapshot(page)).locked).toBe(false);
  return gameSnapshot(page);
}

export async function waitForCameraToSettle(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve, reject) => {
        const deadline = performance.now() + 3_000;
        let previous: { scrollX: number; scrollY: number } | null = null;
        const sample = () => {
          const current = window.__PHOENIX_TEST__?.snapshot().camera;
          if (!current) {
            reject(new Error('Phoenix camera snapshot is not ready'));
            return;
          }
          if (
            previous &&
            Math.abs(current.scrollX - previous.scrollX) < 0.01 &&
            Math.abs(current.scrollY - previous.scrollY) < 0.01
          ) {
            resolve();
            return;
          }
          previous = { scrollX: current.scrollX, scrollY: current.scrollY };
          if (performance.now() >= deadline) {
            reject(new Error(`Phoenix camera did not settle: ${JSON.stringify(current)}`));
            return;
          }
          requestAnimationFrame(sample);
        };
        requestAnimationFrame(sample);
      }),
  );
}

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

  const footpoint = gridToWorld({ x: cell.x + 0.5, y: cell.y + 0.5 }, E2E_PROJECTION);
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

export async function holdKey(page: Page, key: string, ms: number): Promise<void> {
  return holdKeys(page, [key], ms);
}

export async function holdKeys(page: Page, keys: string[], ms: number): Promise<void> {
  for (const key of keys) await page.keyboard.down(key);
  try {
    await page.waitForTimeout(ms);
  } finally {
    for (const key of [...keys].reverse()) await page.keyboard.up(key);
  }
}

export function assertCameraWithinBounds(value: DebugSnapshot): void {
  const { bounds, scrollX, scrollY } = value.camera;
  const maxX = Math.max(bounds.x, bounds.x + bounds.width - 640);
  const maxY = Math.max(bounds.y, bounds.y + bounds.height - 360);
  expect(scrollX).toBeGreaterThanOrEqual(bounds.x - 0.5);
  expect(scrollX).toBeLessThanOrEqual(maxX + 0.5);
  expect(scrollY).toBeGreaterThanOrEqual(bounds.y - 0.5);
  expect(scrollY).toBeLessThanOrEqual(maxY + 0.5);
}

export async function moveUntil(
  page: Page,
  key: string,
  predicate: (value: DebugSnapshot) => boolean,
): Promise<DebugSnapshot> {
  return moveUntilKeys(page, [key], predicate);
}

export async function moveUntilPlayerAxis(
  page: Page,
  keys: string[],
  axis: 'x' | 'y',
  comparison: 'gte' | 'lte',
  target: number,
  pollingMargin = 0,
): Promise<DebugSnapshot> {
  // Some route waypoints must release before a fractional floor boundary so
  // acquireTarget can turn without crossing into the next cell. Callers that
  // assert the reached coordinate keep the default exact polling target.
  const pollingTarget = comparison === 'gte' ? target - pollingMargin : target + pollingMargin;
  for (const key of keys) await page.keyboard.down(key);
  let waitError: unknown;
  try {
    try {
      await page.waitForFunction(
        ({ axis: positionAxis, comparison: positionComparison, target: positionTarget }) => {
          const position = window.__PHOENIX_TEST__!.snapshot().player.position;
          const value = position[positionAxis];
          return positionComparison === 'gte' ? value >= positionTarget : value <= positionTarget;
        },
        { axis, comparison, target: pollingTarget },
        { timeout: 3_000, polling: 'raf' },
      );
    } catch (error) {
      waitError = error;
    }
  } finally {
    for (const key of [...keys].reverse()) await page.keyboard.up(key);
    await page.evaluate(
      () => new Promise<void>((resolve) => requestAnimationFrame(() => resolve())),
    );
  }
  if (waitError) {
    const latest = await snapshot(page).catch(() => null);
    if (latest) {
      throw new Error(
        `${waitError instanceof Error ? waitError.message : String(waitError)}; last snapshot after release: ${JSON.stringify(latest)}`,
      );
    }
    throw waitError;
  }
  const latest = await snapshot(page);
  assertCameraWithinBounds(latest);
  return latest;
}

export async function moveUntilKeys(
  page: Page,
  keys: string[],
  predicate: (value: DebugSnapshot) => boolean,
): Promise<DebugSnapshot> {
  for (const key of keys) await page.keyboard.down(key);
  let latest: DebugSnapshot | null = null;
  let waitError: unknown;
  try {
    try {
      await expect
        .poll(
          async () => {
            latest = await snapshot(page);
            return predicate(latest);
          },
          { timeout: 3_000, intervals: [50] },
        )
        .toBe(true);
    } catch (error) {
      waitError = error;
    }
  } finally {
    for (const key of [...keys].reverse()) await page.keyboard.up(key);
  }
  if (waitError) {
    latest = await snapshot(page).catch(() => latest);
    if (latest) {
      throw new Error(
        `${waitError instanceof Error ? waitError.message : String(waitError)}; last snapshot after release: ${JSON.stringify(latest)}`,
      );
    }
    throw waitError;
  }
  latest = await snapshot(page);
  assertCameraWithinBounds(latest);
  return latest;
}

const SHOP_CELL: GridCell = { x: 6, y: 7 };

export async function moveToShop(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 4.5);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 5.1);
  const player = (await snapshot(page)).player.position;
  expect(Math.floor(player.x)).toBe(5);
  expect(Math.floor(player.y)).toBe(8);
  await acquireTarget(page, 'd', SHOP_CELL);
}

const JUNE_CELL: GridCell = { x: 9, y: 5 };

export async function moveToJune(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 3.5, 0.25);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 6.4, 0.25);
  await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 6.7, 0.25);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 7.5, 0.25);
  await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 6.7, 0.25);
  await acquireTarget(page, 'd', JUNE_CELL);
}

export type ListenerCensus = { keydown: number; keyup: number };
type ListenerCensusWindow = Window & {
  __PHOENIX_LISTENER_CENSUS__: () => ListenerCensus;
};

export async function installListenerCensus(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const active = new Map<
      string,
      Array<{ listener: EventListenerOrEventListenerObject; capture: boolean }>
    >();
    type ListenerOptions = boolean | AddEventListenerOptions;
    const originalAdd = window.addEventListener.bind(window) as (
      type: string,
      listener: EventListenerOrEventListenerObject | null,
      options?: ListenerOptions,
    ) => void;
    const originalRemove = window.removeEventListener.bind(window) as (
      type: string,
      listener: EventListenerOrEventListenerObject | null,
      options?: ListenerOptions,
    ) => void;
    const captureOf = (options?: ListenerOptions) =>
      typeof options === 'boolean' ? options : Boolean(options?.capture);
    const tracked = (type: string) => type === 'keydown' || type === 'keyup';
    window.addEventListener = ((
      type: string,
      listener: EventListenerOrEventListenerObject | null,
      options?: boolean | AddEventListenerOptions,
    ) => {
      if (listener && tracked(type)) {
        const records = active.get(type) ?? [];
        const capture = captureOf(options);
        if (!records.some((record) => record.listener === listener && record.capture === capture))
          records.push({ listener, capture });
        active.set(type, records);
      }
      return originalAdd(type, listener, options);
    }) as typeof window.addEventListener;
    window.removeEventListener = ((
      type: string,
      listener: EventListenerOrEventListenerObject | null,
      options?: ListenerOptions,
    ) => {
      if (listener && tracked(type)) {
        const records = active.get(type) ?? [];
        const capture = captureOf(options);
        const index = records.findIndex(
          (record) => record.listener === listener && record.capture === capture,
        );
        if (index >= 0) records.splice(index, 1);
      }
      return originalRemove(type, listener, options);
    }) as typeof window.removeEventListener;
    (window as unknown as ListenerCensusWindow).__PHOENIX_LISTENER_CENSUS__ = () => ({
      keydown: active.get('keydown')?.length ?? 0,
      keyup: active.get('keyup')?.length ?? 0,
    });
  });
}

export async function listenerCensus(page: Page): Promise<ListenerCensus> {
  return page.evaluate(() =>
    (window as unknown as ListenerCensusWindow).__PHOENIX_LISTENER_CENSUS__(),
  );
}

export interface ActionSelection {
  key: '1' | '2' | '3' | '4';
  action: FarmingAction;
  resetKey: '1' | '2';
  resetAction: FarmingAction;
}

export async function useSelected(
  page: Page,
  target: { key: string; cell: GridCell },
  feedback: string | RegExp,
  crop: CropKind,
  selectAction?: ActionSelection,
): Promise<GameSnapshot> {
  await acquireTarget(page, target.key, target.cell);
  if (selectAction) {
    await page.keyboard.down(selectAction.resetKey);
    try {
      await expect
        .poll(async () => (await gameSnapshot(page)).selectedAction)
        .toBe(selectAction.resetAction);
    } finally {
      await page.keyboard.up(selectAction.resetKey);
    }
    await page.keyboard.down(selectAction.key);
    try {
      await expect
        .poll(async () => (await gameSnapshot(page)).selectedAction)
        .toBe(selectAction.action);
    } finally {
      await page.keyboard.up(selectAction.key);
    }
  }
  const before = await gameSnapshot(page);
  await page.keyboard.down('Space');
  try {
    if (feedback === 'Soil tilled') {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) => position.x === target.cell.x && position.y === target.cell.y,
            )?.soil,
        )
        .toBe('tilled');
    } else if (typeof feedback === 'string' && feedback.endsWith(' planted')) {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) => position.x === target.cell.x && position.y === target.cell.y,
            )?.crop?.kind,
        )
        .toBe(crop);
    } else if (feedback === 'Crop watered') {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) => position.x === target.cell.x && position.y === target.cell.y,
            )?.crop?.wateredToday,
        )
        .toBe(true);
    } else if (feedback instanceof RegExp) {
      await expect
        .poll(async () => (await gameSnapshot(page)).inventory.crops[crop])
        .toBe(before.inventory.crops[crop] + 1);
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) => position.x === target.cell.x && position.y === target.cell.y,
            )?.crop,
        )
        .toBeNull();
    }
    await expect(page.locator('[data-feedback]')).toHaveText(feedback);
  } finally {
    await page.keyboard.up('Space');
  }
  return gameSnapshot(page);
}
