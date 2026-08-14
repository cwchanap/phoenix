import { expect, test } from '@playwright/test';
import { holdKey, moveUntilPlayerAxis, snapshot, waitForWorld } from './helpers';

test('sleep confirmation focuses the dialog and blocks background action activation', async ({ page }) => {
  await waitForWorld(page);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await holdKey(page, 'd', 40);
  await expect.poll(async () => (await snapshot(page)).target).toEqual({ x: 6, y: 8 });

  const readGameSnapshot = () => page.evaluate(() => {
    const snapshot = window.__PHOENIX_TEST__?.gameSnapshot();
    if (!snapshot) throw new Error('Phoenix game snapshot is not ready');
    return snapshot;
  });

  const before = await readGameSnapshot();
  expect(before.selectedAction).toBe('hoe');

  const dialog = page.getByRole('dialog', { name: 'Sleep until tomorrow?' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  await expect(page.getByRole('button', { name: 'Confirm' })).toBeFocused();

  const seedsButton = page.getByRole('button', { name: '2 Seeds' });
  await expect(seedsButton).toBeDisabled();
  await page.keyboard.press('2');

  const after = await readGameSnapshot();
  expect(after.selectedAction).toBe(before.selectedAction);
  expect(after.day).toBe(before.day);

  await page.getByRole('button', { name: 'Cancel' }).click();
  await expect(dialog).toBeHidden();
});
