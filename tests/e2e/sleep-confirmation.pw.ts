import { expect, test, type Locator, type Page } from '@playwright/test';
import { holdKey, moveUntilPlayerAxis, snapshot, waitForWorld } from './helpers';

async function expectEconomyDialogsAbsent(page: Page): Promise<void> {
  await expect(page.getByRole('dialog', { name: 'Seed shop' })).toHaveCount(0);
  await expect(page.getByRole('dialog', { name: 'Shipping bin' })).toHaveCount(0);
}

async function expectBackgroundControlsDisabled(page: Page): Promise<void> {
  for (const name of ['1 Hoe', '2 Seeds: Turnip', '3 Water', '4 Hands']) {
    await expect(page.getByRole('button', { name, exact: true })).toBeDisabled();
  }
  for (const name of ['Select Turnip', 'Select Potato', 'Select Pumpkin']) {
    await expect(page.getByRole('button', { name, exact: true })).toBeDisabled();
  }
  await expect(page.getByRole('button', { name: 'Lock world input', exact: true })).toBeDisabled();
}

async function assertHeldELeavesModalOpen(page: Page, modal: Locator): Promise<void> {
  await page.keyboard.down('e');
  try {
    await expect(modal).toBeVisible();
    await expectEconomyDialogsAbsent(page);
  } finally {
    await page.keyboard.up('e');
  }
  await expect(modal).toBeVisible();
}

test('sleep confirmation focuses the dialog and blocks background action activation', async ({
  page,
}) => {
  await waitForWorld(page);
  await expect(page.locator('[data-time]')).toHaveText('06:00');
  await expect(page.locator('[data-stamina]')).toHaveText('20 / 20');
  await expect(page.locator('[data-weather]')).toHaveText('Sunny');
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await holdKey(page, 'd', 40);
  await expect.poll(async () => (await snapshot(page)).target).toEqual({ x: 6, y: 8 });

  const readGameSnapshot = () =>
    page.evaluate(() => {
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
  await expectEconomyDialogsAbsent(page);
  await expectBackgroundControlsDisabled(page);
  await assertHeldELeavesModalOpen(page, dialog);

  const seedsButton = page.getByRole('button', { name: '2 Seeds: Turnip' });
  await expect(seedsButton).toBeDisabled();
  await page.keyboard.press('2');

  const after = await readGameSnapshot();
  expect(after.selectedAction).toBe(before.selectedAction);
  expect(after.day).toBe(before.day);

  await page.getByRole('button', { name: 'Cancel' }).click();
  await expect(dialog).toBeHidden();

  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  await expect(page.getByRole('button', { name: 'Confirm', exact: true })).toBeFocused();
  await page.getByRole('button', { name: 'Confirm', exact: true }).click({ clickCount: 2 });

  const summary = page.getByRole('dialog', { name: 'Morning summary' });
  await expect(summary).toBeVisible();
  await expect(dialog).toBeHidden();

  const morning = await readGameSnapshot();
  expect(morning.day).toBe(2);
  expect(morning.pendingDaySummary).toMatchObject({
    completedDay: 1,
    nextDay: 2,
    cropsAdvanced: 0,
    staminaRestored: 0,
  });
  expect(morning.pendingDaySummary).not.toBeNull();
  expect((await snapshot(page)).locked).toBe(true);

  await expectEconomyDialogsAbsent(page);
  await expectBackgroundControlsDisabled(page);
  await assertHeldELeavesModalOpen(page, summary);
  await page.keyboard.press('2');
  expect((await readGameSnapshot()).selectedAction).toBe(before.selectedAction);

  await expect(page.getByRole('button', { name: 'Start Day 2', exact: true })).toBeFocused();
  await page.getByRole('button', { name: 'Start Day 2', exact: true }).click();
  await expect(summary).toBeHidden();
  const started = await readGameSnapshot();
  expect(started.pendingDaySummary).toBeNull();
  expect(started.day).toBe(2);
  expect((await snapshot(page)).locked).toBe(false);
});
