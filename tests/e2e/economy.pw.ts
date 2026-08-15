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
