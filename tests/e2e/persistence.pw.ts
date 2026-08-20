import { expect, test, type Page } from '@playwright/test';
import type { GameSnapshot, GridCell } from '../../src/game/core/types';
import {
  acquireTarget,
  gameSnapshot,
  moveUntilPlayerAxis,
  useSelected,
  waitForWorld,
} from './helpers';

const CROP_CELL: GridCell = { x: 3, y: 8 };
const BED_CELL: GridCell = { x: 6, y: 8 };

function withoutPlayerAndTarget(value: GameSnapshot) {
  const { player: _player, target: _target, ...rest } = value;
  void _player;
  void _target;
  return rest;
}

async function moveToBed(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  const settled = await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  if (settled.player.position.y < 9) {
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 9);
  } else if (settled.player.position.y >= 10) {
    await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  }
  await acquireTarget(page, 'd', BED_CELL);
}

async function sleepAndWaitForSave(page: Page): Promise<void> {
  const dialog = page.getByRole('dialog', { name: 'Sleep until tomorrow?' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect(page.locator('[data-save-status]')).toHaveText('Saved');
}

test('starts a fresh game from the title screen', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await expect(page.locator('[data-new-game]')).toBeEnabled();
  await expect(page.locator('[data-continue]')).toBeDisabled();
  await page.locator('[data-new-game]').click();
  await expect(page.getByText('World ready')).toBeVisible();
});

test('restores the saved morning through Continue after reload', async ({ page }) => {
  await waitForWorld(page);
  const freshTitleSnapshot = await gameSnapshot(page);
  const authoredSpawn = freshTitleSnapshot.player.position;

  const changed = await useSelected(page, { key: 'd', cell: CROP_CELL }, 'Soil tilled', 'turnip');
  expect(changed.farmTiles).toContainEqual({ position: CROP_CELL, soil: 'tilled', crop: null });

  await moveToBed(page);
  await sleepAndWaitForSave(page);
  const savedMorning = await gameSnapshot(page);
  expect(savedMorning.pendingDaySummary).not.toBeNull();
  const savedReadModel = withoutPlayerAndTarget(savedMorning);

  await page.reload();
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await expect(page.locator('[data-continue]')).toBeEnabled();
  await page.locator('[data-continue]').click();
  await expect(page.getByText('World ready')).toBeVisible();

  const restored = await gameSnapshot(page);
  expect(withoutPlayerAndTarget(restored)).toEqual(savedReadModel);
  expect(restored.player.position).toEqual(authoredSpawn);

  const summary = page.getByRole('dialog', { name: 'Morning summary' });
  await expect(summary).toBeVisible();
  const startDay = page.getByRole('button', { name: 'Start Day 2', exact: true });
  await expect(startDay).toBeEnabled();
  await startDay.click();
  await expect(summary).toBeHidden();
  await expect.poll(async () => (await gameSnapshot(page)).pendingDaySummary).toBeNull();
});

test('recovers from malformed browser storage with New Game', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('phoenix.save.v1', '{broken json');
  });
  await page.goto('/');
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await expect(page.locator('[data-continue]')).toBeDisabled();
  await expect(page.locator('[data-title-error]')).toBeVisible();
  await expect(page.locator('[data-new-game]')).toBeEnabled();
  await page.locator('[data-new-game]').click();
  await expect(page.getByText('World ready')).toBeVisible();
});

test('returns to the title when Continue rejects an incompatible saved day', async ({ page }) => {
  await waitForWorld(page);
  await useSelected(page, { key: 'd', cell: CROP_CELL }, 'Soil tilled', 'turnip');
  await moveToBed(page);
  await sleepAndWaitForSave(page);

  await page.evaluate(() => {
    const raw = localStorage.getItem('phoenix.save.v1');
    if (raw === null) throw new Error('Phoenix save was not created');
    const save = JSON.parse(raw) as { state: { day: number } };
    save.state.day = 999;
    localStorage.setItem('phoenix.save.v1', JSON.stringify(save));
  });

  await page.reload();
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await expect(page.locator('[data-continue]')).toBeEnabled();
  await page.locator('[data-continue]').click();
  await expect(page.getByText('World ready')).toHaveCount(0);
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await expect(page.locator('[data-title-error]')).toBeVisible();
  await expect(page.locator('[data-title-error]')).toContainText(
    'GameSession: invalid initial state',
  );
  await expect(page.locator('[data-continue]')).toBeDisabled();
  await expect(page.locator('[data-new-game]')).toBeEnabled();
  await page.locator('[data-new-game]').click();
  await expect(page.getByText('World ready')).toBeVisible();
});
