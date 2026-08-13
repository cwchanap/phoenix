import { expect, test } from '@playwright/test';
import { readFileSync, statSync, utimesSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { holdKey, snapshot, waitForWorld } from './helpers';

const appPath = fileURLToPath(new URL('../../src/App.svelte', import.meta.url));

type ListenerCensus = { keydown: number; keyup: number };
type ListenerCensusWindow = Window & { __PHOENIX_LISTENER_CENSUS__: () => ListenerCensus };

async function listenerCensus(page: Parameters<typeof waitForWorld>[0]): Promise<ListenerCensus> {
  return page.evaluate(() => (window as unknown as ListenerCensusWindow).__PHOENIX_LISTENER_CENSUS__());
}

function displacement(before: Awaited<ReturnType<typeof snapshot>>, after: Awaited<ReturnType<typeof snapshot>>): number {
  return Math.hypot(
    after.player.world.x - before.player.world.x,
    after.player.world.y - before.player.world.y,
  );
}

test('loads one canvas and exposes a ready world', async ({ page }) => {
  await waitForWorld(page);
  await expect(page.locator('canvas')).toHaveCount(1);
  await expect(page.getByText('World ready')).toBeVisible();
});

test('remounts without duplicating the canvas', async ({ page }) => {
  await waitForWorld(page);
  await page.evaluate(() => window.__PHOENIX_TEST__!.remount());
  await expect(page.locator('canvas')).toHaveCount(1);
  await expect(page.getByText('World ready')).toBeVisible();
});

test('locked overlay prevents movement and unlocking restores it', async ({ page }) => {
  await waitForWorld(page);
  const lockButton = page.getByRole('button', { name: 'Lock world input' });
  await lockButton.click();
  await expect(page.getByText('World input: Locked')).toBeVisible();

  const lockedBefore = await snapshot(page);
  await holdKey(page, 'd', 250);
  const lockedAfter = await snapshot(page);
  expect(displacement(lockedBefore, lockedAfter)).toBeLessThan(0.05);

  await page.getByRole('button', { name: 'Unlock world input' }).click();
  await expect(page.getByText('World input: Active')).toBeVisible();
  const unlockedBefore = await snapshot(page);
  await holdKey(page, 'd', 250);
  const unlockedAfter = await snapshot(page);
  expect(displacement(unlockedBefore, unlockedAfter)).toBeGreaterThan(0.1);
});

test('synthetic window blur prevents movement until focus returns', async ({ page }) => {
  await waitForWorld(page);
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect(page.getByText('World input: Locked')).toBeVisible();
  const blurredBefore = await snapshot(page);
  await holdKey(page, 'd', 250);
  const blurredAfter = await snapshot(page);
  expect(displacement(blurredBefore, blurredAfter)).toBeLessThan(0.05);

  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.getByText('World input: Active')).toBeVisible();
  const focusedBefore = await snapshot(page);
  await holdKey(page, 'd', 250);
  const focusedAfter = await snapshot(page);
  expect(displacement(focusedBefore, focusedAfter)).toBeGreaterThan(0.1);
});

test('keeps the overlay and canvas aligned at supported sizes', async ({ page }) => {
  await waitForWorld(page);
  for (const [width, height, scale, left, top] of [
    [640, 360, 1, 0, 0],
    [1024, 768, 1, 192, 204],
    [1280, 720, 2, 0, 0],
  ] as const) {
    await page.setViewportSize({ width, height });
    await expect(page.locator('[data-stage-frame]')).toHaveAttribute('data-stage-scale', String(scale));
    await expect.poll(
      () => page.locator('[data-stage-frame]').evaluate((node) => {
        const rect = node.getBoundingClientRect();
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
      }),
      { timeout: 3_000, intervals: [16] },
    ).toEqual({ x: left, y: top, width: 640 * scale, height: 360 * scale });
    const [host, overlay, frame] = await page.locator('[data-game-host], [data-overlay], [data-stage-frame]')
      .evaluateAll((nodes) => nodes.map((node) => node.getBoundingClientRect().toJSON()));
    expect(host).toEqual(overlay);
    expect(frame).toMatchObject({ x: left, y: top, width: 640 * scale, height: 360 * scale });
  }
});

test('keeps one input handler across a real Vite HMR update', async ({ page }) => {
  test.setTimeout(60_000);
  await page.addInitScript(() => {
    const active = new Map<string, Array<{ listener: EventListenerOrEventListenerObject; capture: boolean }>>();
    type ListenerOptions = boolean | AddEventListenerOptions;
    const originalAdd = window.addEventListener.bind(window) as (type: string, listener: EventListenerOrEventListenerObject | null, options?: ListenerOptions) => void;
    const originalRemove = window.removeEventListener.bind(window) as (type: string, listener: EventListenerOrEventListenerObject | null, options?: ListenerOptions) => void;
    const captureOf = (options?: ListenerOptions) => typeof options === 'boolean' ? options : Boolean(options?.capture);
    const tracked = (type: string) => type === 'keydown' || type === 'keyup';
    window.addEventListener = ((type: string, listener: EventListenerOrEventListenerObject | null, options?: boolean | AddEventListenerOptions) => {
      if (listener && tracked(type)) {
        const records = active.get(type) ?? [];
        const capture = captureOf(options);
        if (!records.some((record) => record.listener === listener && record.capture === capture)) records.push({ listener, capture });
        active.set(type, records);
      }
      return originalAdd(type, listener, options);
    }) as typeof window.addEventListener;
    window.removeEventListener = ((type: string, listener: EventListenerOrEventListenerObject | null, options?: ListenerOptions) => {
      if (listener && tracked(type)) {
        const records = active.get(type) ?? [];
        const capture = captureOf(options);
        const index = records.findIndex((record) => record.listener === listener && record.capture === capture);
        if (index >= 0) records.splice(index, 1);
      }
      return originalRemove(type, listener, options);
    }) as typeof window.removeEventListener;
    (window as unknown as ListenerCensusWindow).__PHOENIX_LISTENER_CENSUS__ = () => ({
      keydown: active.get('keydown')?.length ?? 0,
      keyup: active.get('keyup')?.length ?? 0,
    });
  });
  await waitForWorld(page);
  const original = statSync(appPath);
  const originalSource = readFileSync(appPath, 'utf8');
  const measure = async (): Promise<number> => {
    const before = await snapshot(page);
    await holdKey(page, 'w', 250);
    const after = await snapshot(page);
    return displacement(before, after);
  };

  const beforeListeners = await listenerCensus(page);
  expect(beforeListeners).toEqual({ keydown: 1, keyup: 1 });
  const beforeHmr = await measure();
  expect(beforeHmr).toBeGreaterThan(0.1);
  let primaryFailure: unknown;
  try {
    const updateCount = await page.evaluate(() => window.__PHOENIX_HMR_COUNT__ ?? 0);
    writeFileSync(appPath, `${originalSource}\n{@html '<!-- playwright-hmr-probe -->'}\n`);
    await page.waitForFunction(
      (count) => (window.__PHOENIX_HMR_COUNT__ ?? 0) > count,
      updateCount,
      { timeout: 10_000 },
    );
    await expect(page.locator('canvas')).toHaveCount(1);
    await expect(page.getByText('World ready')).toBeVisible();
    const afterListeners = await listenerCensus(page);
    expect(afterListeners).toEqual({ keydown: 1, keyup: 1 });
    const afterHmr = await measure();
    expect(afterHmr).toBeGreaterThan(0.1);
  } catch (error) {
    primaryFailure = error;
    throw error;
  } finally {
    let restorationFailure: unknown;
    try {
      let restoreCount: number | null = null;
      try {
        if (!page.isClosed()) {
          restoreCount = await page.evaluate(() => window.__PHOENIX_HMR_COUNT__ ?? 0);
        }
      } catch (error) {
        restorationFailure = error;
      }
      writeFileSync(appPath, originalSource);
      if (!restorationFailure && restoreCount !== null && !page.isClosed()) {
        await page.waitForFunction(
          (count) => (window.__PHOENIX_HMR_COUNT__ ?? 0) > count,
          restoreCount,
          { timeout: 10_000 },
        );
      }
    } catch (error) {
      restorationFailure = error;
    } finally {
      utimesSync(appPath, original.atime, original.mtime);
    }
    if (!primaryFailure && restorationFailure && !page.isClosed()) {
      throw restorationFailure;
    }
  }
});
