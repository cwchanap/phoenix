import { expect, test, type Locator, type Page } from '@playwright/test';
import { Buffer } from 'node:buffer';
import type { CropKind, GameSnapshot, GridCell } from '../../src/game/core/types';
import { CROP_DEFINITIONS, CROP_KINDS, isMature } from '../../src/game/core/cropDefinitions';
import {
  acquireTarget,
  captureCropSprite,
  confirmAndStartDay,
  gameSnapshot,
  moveUntilPlayerAxis,
  snapshot,
  waitForWorld,
  waterForCurrentWeather,
} from './helpers';

const SHOP_CELL: GridCell = { x: 6, y: 7 };
const SHIPPING_CELL: GridCell = { x: 6, y: 10 };
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

async function moveToShop(page: Page): Promise<void> {
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
  let current = await snapshot(page);
  if (current.player.position.y < 9.2) {
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 9.2);
    current = await snapshot(page);
  }
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
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 5.1);
  await acquireTarget(page, 'd', SHOP_CELL);
}

async function moveFarmHubToShipping(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await acquireTarget(page, 's', SHIPPING_CELL);
}

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
    if (feedback === 'Soil tilled') {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) =>
                position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y,
            )?.soil,
        )
        .toBe('tilled');
    } else if (typeof feedback === 'string' && feedback.endsWith(' planted')) {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) =>
                position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y,
            )?.crop?.kind,
        )
        .toBe(crop);
    } else if (feedback === 'Crop watered') {
      await expect
        .poll(
          async () =>
            (await gameSnapshot(page)).farmTiles.find(
              ({ position }) =>
                position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y,
            )?.crop?.wateredToday,
        )
        .toBe(true);
    } else if (feedback instanceof RegExp) {
      await expect.poll(async () => (await gameSnapshot(page)).inventory.crops[crop]).toBe(1);
    }
  } finally {
    await page.keyboard.up('Space');
  }
  return gameSnapshot(page);
}

async function selectSeed(page: Page, crop: CropKind): Promise<void> {
  const label = CROP_DEFINITIONS[crop].displayName;
  await page.getByRole('button', { name: `Select ${label}` }).click();
  await expect.poll(async () => (await gameSnapshot(page)).selectedSeed).toBe(crop);
  await expect(page.getByRole('button', { name: `2 Seeds: ${label}` })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
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
  await expect.poll(async () => (await snapshot(page)).locked).toBe(false);

  await acquireTarget(page, 's', SHIPPING_CELL);
  const shipping = await openInteraction(page, 'Shipping bin');
  await expect(shipping.getByRole('button', { name: /Deposit/ })).toBeDisabled();
  await expect(shipping.getByRole('button', { name: 'Close' })).toBeFocused();
  await shipping.getByRole('button', { name: 'Close' }).click();
  await expect(shipping).toBeHidden();
  await expect.poll(async () => (await snapshot(page)).locked).toBe(false);
});

test('buys, grows, ships, pays, and reinvests across all three crops', async ({ page }) => {
  // The seven-day economy loop can exceed Playwright's default 30 s budget on CI.
  test.setTimeout(60_000);

  await waitForWorld(page);
  await moveToShop(page);
  const shop = await openInteraction(page, 'Seed shop');

  await shop.getByRole('button', { name: 'Potato seeds' }).click();
  await shop.getByRole('button', { name: 'Buy 1 Potato seed' }).click();
  await shop.getByRole('button', { name: 'Pumpkin seeds' }).click();
  await shop.getByRole('button', { name: 'Buy 1 Pumpkin seed' }).click();
  await expect.poll(async () => (await gameSnapshot(page)).money).toBe(40);
  expect((await gameSnapshot(page)).inventory.seeds).toEqual({
    turnip: 3,
    potato: 1,
    pumpkin: 1,
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
    await useSelected(page, crop, 'Crop planted');
  }

  for (let night = 1; night <= 7; night += 1) {
    await selectAction(page, '3');
    const beforeWater = await gameSnapshot(page);
    for (const crop of CROP_KINDS) {
      const tile = beforeWater.farmTiles.find(
        ({ position }) => position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y,
      );
      if (!tile?.crop || isMature(crop, tile.crop.growth)) continue;
      await waterForCurrentWeather(page, FARM_TARGET_KEY[crop], FARM_CELLS[crop]);
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
      const tile = afterSleep.farmTiles.find(
        ({ position }) => position.x === FARM_CELLS[crop].x && position.y === FARM_CELLS[crop].y,
      );
      expect(tile?.crop?.growth).toBe(Math.min(night, CROP_DEFINITIONS[crop].growthDays));
    }
    if (night < 7) await moveBedToFarmHub(page);
  }

  await moveBedToFarmHub(page);
  const matureSprites = await Promise.all(
    CROP_KINDS.map((crop) => captureCropSprite(page, FARM_CELLS[crop])),
  );
  for (let left = 0; left < matureSprites.length; left += 1) {
    for (let right = left + 1; right < matureSprites.length; right += 1) {
      expect(Buffer.compare(matureSprites[left], matureSprites[right])).not.toBe(0);
    }
  }
  await selectAction(page, '4');
  for (const crop of CROP_KINDS) await useSelected(page, crop, /harvested/i);
  expect((await gameSnapshot(page)).inventory.crops).toEqual({
    turnip: 1,
    potato: 1,
    pumpkin: 1,
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

  await moveFarmHubToBed(page);
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
    turnip: 0,
    potato: 0,
    pumpkin: 0,
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
