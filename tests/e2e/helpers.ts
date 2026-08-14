import { expect, type Page } from '@playwright/test';
import type { DebugSnapshot } from '../../src/game/phaser/ProofScene';
import type { GameSnapshot } from '../../src/game/core/types';

export async function waitForWorld(page: Page): Promise<void> {
  await page.goto('/');
  await expect(page.getByText('World ready')).toBeVisible();
  await page.waitForFunction(() => Boolean(window.__PHOENIX_TEST__?.snapshot()));
}

export const snapshot = (page: Page): Promise<DebugSnapshot> =>
  page.evaluate(() => window.__PHOENIX_TEST__!.snapshot());

export async function gameSnapshot(page: Page): Promise<GameSnapshot> {
  return page.evaluate(() => {
    const snapshot = window.__PHOENIX_TEST__?.gameSnapshot();
    if (!snapshot) throw new Error('Phoenix game snapshot is not ready');
    return snapshot;
  });
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
): Promise<DebugSnapshot> {
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
        { axis, comparison, target },
        { timeout: 3_000, polling: 'raf' },
      );
    } catch (error) {
      waitError = error;
    }
  } finally {
    for (const key of [...keys].reverse()) await page.keyboard.up(key);
  }
  if (waitError) {
    const latest = await snapshot(page).catch(() => null);
    if (latest) {
      throw new Error(`${waitError instanceof Error ? waitError.message : String(waitError)}; last snapshot after release: ${JSON.stringify(latest)}`);
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
      await expect.poll(async () => {
        latest = await snapshot(page);
        return predicate(latest);
      }, { timeout: 3_000, intervals: [50] }).toBe(true);
    } catch (error) {
      waitError = error;
    }
  } finally {
    for (const key of [...keys].reverse()) await page.keyboard.up(key);
  }
  if (waitError) {
    latest = await snapshot(page).catch(() => latest);
    if (latest) {
      throw new Error(`${waitError instanceof Error ? waitError.message : String(waitError)}; last snapshot after release: ${JSON.stringify(latest)}`);
    }
    throw waitError;
  }
  latest = await snapshot(page);
  assertCameraWithinBounds(latest);
  return latest;
}
