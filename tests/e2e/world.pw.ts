import { expect, test, type Page } from '@playwright/test';
import type { DebugDepths, DebugSnapshot } from '../../src/game/phaser/ProofScene';
import {
  acquireTarget,
  assertCameraWithinBounds,
  gameSnapshot,
  holdKey,
  moveUntil,
  moveUntilKeys,
  moveUntilPlayerAxis,
  snapshot,
  waitForWorld,
} from './helpers';

const SHOP_CELL = { x: 6, y: 7 } as const;
const BED_CELL = { x: 6, y: 8 } as const;
const SHIPPING_CELL = { x: 6, y: 10 } as const;
const SHIPPING_FOOTPRINT = { x: 6.2, y: 10.2, width: 0.6, height: 0.6 } as const;
const VILLAGER_CELLS = {
  shopkeeper: { x: 6, y: 5 },
  farmer: { x: 3, y: 5 },
  resident: { x: 9, y: 5 },
} as const;
const MIRA_FOOTPRINT = { x: 6.2, y: 5.2, width: 0.6, height: 0.6 } as const;

function outsideFootprint(
  position: { x: number; y: number },
  footprint: { x: number; y: number; width: number; height: number },
  halfExtent = 0.18,
): boolean {
  return (
    position.x + halfExtent <= footprint.x ||
    position.x - halfExtent >= footprint.x + footprint.width ||
    position.y + halfExtent <= footprint.y ||
    position.y - halfExtent >= footprint.y + footprint.height
  );
}

function shopkeeperDepth(state: DebugSnapshot): number {
  const depth = state.depths['villager:shopkeeper'];
  if (depth === undefined) throw new Error('Missing shopkeeper depth');
  return depth;
}

async function moveWorldToShop(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 4.5);
  await acquireTarget(page, 'd', SHOP_CELL);
}

async function moveShopToWorldFarmHub(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['a', 'w'], 'x', 'lte', 3.5);
  await moveUntilPlayerAxis(page, ['a'], 'y', 'gte', 8.3);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 3.2);
  const player = (await snapshot(page)).player.position;
  expect(Math.floor(player.x)).toBe(3);
  expect(Math.floor(player.y)).toBe(8);
}

async function moveWorldFarmHubToBed(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  let current = await snapshot(page);
  if (current.player.position.y < 9.2) {
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 9.2);
    current = await snapshot(page);
  }
  if (current.player.position.y >= 10) {
    await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
    await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  }
  await acquireTarget(page, 'd', BED_CELL);
}

async function moveWorldBedToFarmHub(page: Page): Promise<void> {
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

async function moveToVillagerStance(
  page: Page,
  villager: keyof typeof VILLAGER_CELLS,
): Promise<void> {
  const target = VILLAGER_CELLS[villager];
  const key = villager === 'farmer' ? 'w' : 'd';
  if (villager === 'resident') {
    await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 6.4);
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 6.7);
    await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 7.5);
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 6.7);
  } else {
    await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 5.2);
    await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 7);
  }
  await acquireTarget(page, key, target);
}

test('stops at the tree, then detours down and right', async ({ page }) => {
  await waitForWorld(page);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 4);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 5.8);
  await moveUntilPlayerAxis(page, ['w', 'd'], 'y', 'lte', 3.8);
  const approachKeys = ['d', 's'];
  for (const key of approachKeys) await page.keyboard.down(key);
  try {
    await page.evaluate(
      () =>
        new Promise<void>((resolve, reject) => {
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
        }),
    );
  } finally {
    for (const key of [...approachKeys].reverse()) await page.keyboard.up(key);
  }
  const blocked = await snapshot(page);
  assertCameraWithinBounds(blocked);
  expect(blocked.player.facing).toBe('right');
  expect(blocked.player.position.x).toBeLessThanOrEqual(7.021);
  expect(
    outsideFootprint(blocked.player.position, { x: 7.2, y: 4.2, width: 0.6, height: 0.6 }),
  ).toBe(true);

  await moveUntil(page, 's', (value) => value.player.position.y >= 5.3);
  const detour = await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.x >= 7.5);
  expect(detour.player.position.x).toBeGreaterThanOrEqual(7.45);
  expect(
    outsideFootprint(detour.player.position, { x: 7.2, y: 4.2, width: 0.6, height: 0.6 }),
  ).toBe(true);
});

test('slides along the building edge and routes around its corner', async ({ page }) => {
  await waitForWorld(page);
  await moveUntil(page, 'w', (value) => value.player.position.y <= 5.5);
  await moveUntilKeys(page, ['d', 's'], (value) => value.player.position.x >= 6.7);
  const edgeStart = await moveUntilKeys(
    page,
    ['d', 's'],
    (value) => value.player.position.y >= 8.7,
  );
  expect(edgeStart.player.position.x).toBeLessThanOrEqual(6.821);
  expect(edgeStart.player.position.y).toBeGreaterThan(7.4);
  expect(outsideFootprint(edgeStart.player.position, { x: 7, y: 7, width: 2, height: 2 })).toBe(
    true,
  );

  const bottomCorner = await moveUntilKeys(
    page,
    ['d', 's'],
    (value) => value.player.position.x >= 7.4,
  );
  expect(bottomCorner.player.position.x).toBeGreaterThanOrEqual(7.4);
  expect(outsideFootprint(bottomCorner.player.position, { x: 7, y: 7, width: 2, height: 2 })).toBe(
    true,
  );
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
  for (const [key] of [['a'], ['d'], ['w'], ['s']] as const) {
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
      await expect
        .poll(async () => (await snapshot(page)).player.facing, { timeout: 3_000 })
        .toBe(facing);
    } finally {
      await page.keyboard.up(key);
    }
    const result = await snapshot(page);
    expect(result.target).toEqual(target);
    expect(result.visibleTarget).toBe(true);
  }
});

test('keeps authored villager cells and acquires each documented path stance', async ({ page }) => {
  await waitForWorld(page);
  expect((await gameSnapshot(page)).villagerCells).toEqual(VILLAGER_CELLS);

  for (const villager of ['shopkeeper', 'farmer', 'resident'] as const) {
    await waitForWorld(page);
    await moveToVillagerStance(page, villager);
    expect((await snapshot(page)).target).toEqual(VILLAGER_CELLS[villager]);
    assertCameraWithinBounds(await snapshot(page));
  }
});

test('blocks entry to Mira and reverses player depth across her footpoint', async ({ page }) => {
  await waitForWorld(page);
  await moveToVillagerStance(page, 'shopkeeper');
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 6.3);
  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 6.4);
  const above = await snapshot(page);
  expect(above.player.world.y).toBeLessThan(192);
  expect(above.player.position.y).toBeLessThan(5.019);
  expect(above.depths.player).toBeLessThan(shopkeeperDepth(above));

  const approachKeys = ['a', 's'];
  for (const key of approachKeys) await page.keyboard.down(key);
  try {
    await page.evaluate(
      () =>
        new Promise<void>((resolve, reject) => {
          const deadline = performance.now() + 3_000;
          let blockedAt: number | null = null;
          const sample = () => {
            const position = window.__PHOENIX_TEST__!.snapshot().player.position;
            const now = performance.now();
            if (blockedAt === null) {
              if (position.y >= 5.019 && position.y <= 5.021) blockedAt = now;
            } else {
              if (position.y > 5.021) {
                reject(new Error(`Mira collision escaped: ${JSON.stringify(position)}`));
                return;
              }
              if (now - blockedAt >= 300) {
                resolve();
                return;
              }
            }
            if (now >= deadline) {
              reject(new Error(`Mira collision timeout: ${JSON.stringify(position)}`));
              return;
            }
            requestAnimationFrame(sample);
          };
          requestAnimationFrame(sample);
        }),
    );
  } finally {
    for (const key of [...approachKeys].reverse()) await page.keyboard.up(key);
  }
  const blocked = await snapshot(page);
  expect(outsideFootprint(blocked.player.position, MIRA_FOOTPRINT)).toBe(true);
  expect(blocked.player.position.y).toBeLessThanOrEqual(5.021);
  assertCameraWithinBounds(blocked);

  const below = await moveUntil(page, 's', (value) => value.player.world.y >= 195.2);
  expect(below.player.world.y).toBeGreaterThanOrEqual(195.2);
  expect(below.depths.player).toBeGreaterThan(shopkeeperDepth(below));
  assertCameraWithinBounds(below);
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

test('reverses building and player depth across the authored building footpoint', async ({
  page,
}) => {
  await waitForWorld(page);
  const below = await moveUntil(
    page,
    's',
    (value) => value.player.world.y >= 260 && value.player.world.y <= 284.8,
  );
  expect(below.player.world.y).toBeLessThanOrEqual(284.8);
  expect(below.depths.player).toBeLessThan(below.depths.building);
  const above = await moveUntil(page, 's', (value) => value.player.world.y >= 291.2);
  expect(above.player.world.y).toBeGreaterThanOrEqual(291.2);
  expect(above.depths.player).toBeGreaterThan(above.depths.building);
});

test('routes around the shipping bin footprint and reverses its depth ordering', async ({
  page,
}) => {
  await waitForWorld(page);
  await moveWorldToShop(page);
  await moveShopToWorldFarmHub(page);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await acquireTarget(page, 's', SHIPPING_CELL);
  const approachStart = await snapshot(page);
  expect(approachStart.target, JSON.stringify(approachStart)).toEqual(SHIPPING_CELL);

  const approachKeys = ['s'];
  for (const key of approachKeys) await page.keyboard.down(key);
  try {
    await page.evaluate(
      () =>
        new Promise<void>((resolve, reject) => {
          const deadline = performance.now() + 3_000;
          let blockedAt: number | null = null;
          const outside = (position: { x: number; y: number }): boolean =>
            position.x + 0.18 <= 6.2 ||
            position.x - 0.18 >= 6.8 ||
            position.y + 0.18 <= 10.2 ||
            position.y - 0.18 >= 10.8;
          const sample = () => {
            const current = window.__PHOENIX_TEST__!.snapshot();
            if (!outside(current.player.position)) {
              reject(
                new Error(
                  `shipping-bin collision escaped: ${JSON.stringify(current.player.position)}`,
                ),
              );
              return;
            }
            if (blockedAt === null) {
              if (current.player.position.x >= 6.019 && current.player.position.y >= 10.019) {
                blockedAt = performance.now();
              }
            } else if (performance.now() - blockedAt >= 300) {
              resolve();
              return;
            }
            if (performance.now() >= deadline) {
              reject(
                new Error(
                  `shipping-bin collision timeout: ${JSON.stringify(current.player.position)}`,
                ),
              );
              return;
            }
            requestAnimationFrame(sample);
          };
          requestAnimationFrame(sample);
        }),
    );
  } finally {
    for (const key of [...approachKeys].reverse()) await page.keyboard.up(key);
  }
  const blocked = await snapshot(page);
  assertCameraWithinBounds(blocked);
  expect(outsideFootprint(blocked.player.position, SHIPPING_FOOTPRINT)).toBe(true);

  await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 11.2);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 7.2);
  const above = await snapshot(page);
  expect(above.player.world.y).toBeGreaterThanOrEqual(275.2);
  const shippingAbove: DebugDepths['shipping-bin'] = above.depths['shipping-bin'];
  expect(above.depths.player).toBeGreaterThan(shippingAbove);

  await moveUntilPlayerAxis(page, ['d'], 'x', 'gte', 10.8);
  const below = await moveUntil(page, 'w', (value) => value.player.world.y <= 268.8);
  expect(below.player.world.y).toBeLessThanOrEqual(268.8);
  const shippingBelow: DebugDepths['shipping-bin'] = below.depths['shipping-bin'];
  expect(below.depths.player).toBeLessThan(shippingBelow);

  await moveUntilPlayerAxis(page, ['s'], 'x', 'gte', 11.5);
  await moveUntilPlayerAxis(page, ['a'], 'y', 'gte', 10.5);
  await moveShopToWorldFarmHub(page);
  await moveWorldFarmHubToBed(page);
  expect((await snapshot(page)).target).toEqual(BED_CELL);
  await moveWorldBedToFarmHub(page);
  await acquireTarget(page, 'w', { x: 2, y: 7 });
  await acquireTarget(page, 'd', { x: 4, y: 7 });
  await acquireTarget(page, 's', { x: 4, y: 9 });
});
