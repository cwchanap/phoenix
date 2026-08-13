import { expect, test } from '@playwright/test';
import { assertCameraWithinBounds, holdKey, moveUntil, moveUntilKeys, moveUntilPlayerAxis, snapshot, waitForWorld } from './helpers';

function outsideFootprint(position: { x: number; y: number }, footprint: { x: number; y: number; width: number; height: number }, halfExtent = 0.18): boolean {
  return position.x + halfExtent <= footprint.x
    || position.x - halfExtent >= footprint.x + footprint.width
    || position.y + halfExtent <= footprint.y
    || position.y - halfExtent >= footprint.y + footprint.height;
}

test('stops at the tree, then detours down and right', async ({ page }) => {
  await waitForWorld(page);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 4);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 5.8);
  await moveUntilPlayerAxis(page, ['w', 'd'], 'y', 'lte', 3.8);
  const approachKeys = ['d', 's'];
  for (const key of approachKeys) await page.keyboard.down(key);
  try {
    await page.evaluate(() => new Promise<void>((resolve, reject) => {
      const deadline = performance.now() + 3_000;
      let blockedAt: number | null = null;
      const sample = () => {
        const position = window.__PHOENIX_TEST__!.snapshot().player.position;
        const now = performance.now();
        if (blockedAt === null) {
          if (position.x >= 7.019 && position.x <= 7.021 && position.y < 4.65) {
            blockedAt = now;
          }
        } else {
          if (position.x > 7.021) {
            reject(new Error(`tree collision escaped: ${JSON.stringify(position)}`));
            return;
          }
          if (now - blockedAt >= 300) {
            resolve();
            return;
          }
        }
        if (now >= deadline) {
          reject(new Error(`tree collision timeout: ${JSON.stringify(position)}`));
          return;
        }
        requestAnimationFrame(sample);
      };
      requestAnimationFrame(sample);
    }));
  } finally {
    for (const key of [...approachKeys].reverse()) await page.keyboard.up(key);
  }
  const blocked = await snapshot(page);
  assertCameraWithinBounds(blocked);
  expect(blocked.player.facing).toBe('right');
  expect(blocked.player.position.x).toBeLessThanOrEqual(7.021);
  expect(outsideFootprint(blocked.player.position, { x: 7.2, y: 4.2, width: 0.6, height: 0.6 })).toBe(true);

  await moveUntil(page, 's', (value) => value.player.position.y >= 5.3);
  const detour = await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.x >= 7.5);
  expect(detour.player.position.x).toBeGreaterThanOrEqual(7.45);
  expect(outsideFootprint(detour.player.position, { x: 7.2, y: 4.2, width: 0.6, height: 0.6 })).toBe(true);
});

test('slides along the building edge and routes around its corner', async ({ page }) => {
  await waitForWorld(page);
  await moveUntil(page, 'w', (value) => value.player.position.y <= 5.5);
  await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.x >= 6.7);
  const edgeStart = await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.y >= 8.7);
  expect(edgeStart.player.position.x).toBeLessThanOrEqual(6.821);
  expect(edgeStart.player.position.y).toBeGreaterThan(7.4);
  expect(outsideFootprint(edgeStart.player.position, { x: 7, y: 7, width: 2, height: 2 })).toBe(true);

  const bottomCorner = await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.x >= 7.4);
  expect(bottomCorner.player.position.x).toBeGreaterThanOrEqual(7.4);
  expect(outsideFootprint(bottomCorner.player.position, { x: 7, y: 7, width: 2, height: 2 })).toBe(true);
});

test('crosses and leaves the nine-cell farm patch', async ({ page }) => {
  await waitForWorld(page);
  const entered = await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 2.8);
  expect(entered.player.position.x).toBeGreaterThanOrEqual(2.8);
  expect(entered.player.position.x).toBeLessThanOrEqual(4);
  expect(entered.player.position.y).toBeGreaterThanOrEqual(8);
  expect(entered.player.position.y).toBeLessThanOrEqual(9.2);
  const left = await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 5.2);
  expect(left.player.position.x).toBeGreaterThan(4);
  expect(left.player.position.y).toBeLessThan(8);
});

test('keeps the player rectangle within each reachable map edge', async ({ page }) => {
  for (const [key] of [
    ['a'],
    ['d'],
    ['w'],
    ['s'],
  ] as const) {
    await waitForWorld(page);
    let result: Awaited<ReturnType<typeof moveUntilPlayerAxis>>;
    if (key === 'd') {
      await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 11.8);
      await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 7);
      await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 9.4);
      result = await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 11.8);
    } else if (key === 'w') {
      await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 7);
      result = await moveUntilPlayerAxis(page, ['w', 'd'], 'y', 'lte', 0.2);
    } else if (key === 'a') {
      result = await moveUntilPlayerAxis(page, ['a'], 'x', 'lte', 0.2);
    } else {
      result = await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 11.8);
    }
    expect(result.player.position.x).toBeGreaterThanOrEqual(0.18);
    expect(result.player.position.y).toBeGreaterThanOrEqual(0.18);
    expect(result.player.position.x).toBeLessThanOrEqual(11.82);
    expect(result.player.position.y).toBeLessThanOrEqual(11.82);
  }
});

test('hides targets when facing outward at both perimeter corners', async ({ page }) => {
  await waitForWorld(page);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 7);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 4.5);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 2);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 0.2);
  await holdKey(page, 'w', 50);
  const topLeft = await snapshot(page);
  expect(topLeft.player.position.x).toBeGreaterThanOrEqual(0.18);
  expect(topLeft.player.position.y).toBeGreaterThanOrEqual(0.18);
  expect(topLeft.player.facing).toBe('up');
  expect(topLeft.target).toBeNull();
  expect(topLeft.visibleTarget).toBe(false);

  await waitForWorld(page);
  await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 11.2);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 11.8);
  await holdKey(page, 's', 50);
  const bottomRight = await snapshot(page);
  expect(bottomRight.player.position.x).toBeLessThanOrEqual(11.82);
  expect(bottomRight.player.position.y).toBeLessThanOrEqual(11.82);
  expect(bottomRight.player.facing).toBe('down');
  expect(bottomRight.target).toBeNull();
  expect(bottomRight.visibleTarget).toBe(false);
});

test('reports the exact target offset for each facing direction', async ({ page }) => {
  const cases = [
    ['w', 'up', { x: 1, y: 8 }],
    ['d', 'right', { x: 3, y: 8 }],
    ['s', 'down', { x: 3, y: 10 }],
    ['a', 'left', { x: 1, y: 10 }],
  ] as const;
  for (const [key, facing, target] of cases) {
    await waitForWorld(page);
    await page.keyboard.down(key);
    try {
      await expect.poll(async () => (await snapshot(page)).player.facing, { timeout: 3_000 }).toBe(facing);
    } finally {
      await page.keyboard.up(key);
    }
    const result = await snapshot(page);
    expect(result.target).toEqual(target);
    expect(result.visibleTarget).toBe(true);
  }
});

test('reverses tree and player depth across the authored tree footpoint', async ({ page }) => {
  await waitForWorld(page);
  const below = await moveUntil(page, 'w', (value) => value.player.world.y <= 188.8);
  expect(below.player.world.y).toBeLessThanOrEqual(188.8);
  expect(below.depths.player).toBeLessThan(below.depths.tree);
  const above = await moveUntil(page, 's', (value) => value.player.world.y >= 195.2);
  expect(above.player.world.y).toBeGreaterThanOrEqual(195.2);
  expect(above.depths.player).toBeGreaterThan(above.depths.tree);
});

test('reverses building and player depth across the authored building footpoint', async ({ page }) => {
  await waitForWorld(page);
  const below = await moveUntil(page, 's', (value) => value.player.world.y >= 260 && value.player.world.y <= 284.8);
  expect(below.player.world.y).toBeLessThanOrEqual(284.8);
  expect(below.depths.player).toBeLessThan(below.depths.building);
  const above = await moveUntil(page, 's', (value) => value.player.world.y >= 291.2);
  expect(above.player.world.y).toBeGreaterThanOrEqual(291.2);
  expect(above.depths.player).toBeGreaterThan(above.depths.building);
});
