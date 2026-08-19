import { expect, test, type Locator, type Page } from '@playwright/test';
import type { CropKind, GameSnapshot, GridCell } from '../../src/game/core/types';
import { CROP_DEFINITIONS } from '../../src/game/core/cropDefinitions';
import {
  acquireTarget,
  confirmAndStartDay,
  gameSnapshot,
  moveUntilPlayerAxis,
  snapshot,
  useSelected,
  waitForWorld,
  waterForCurrentWeather,
  type ActionSelection,
} from './helpers';

const FARM_CELLS = [
  { key: 'w', cell: { x: 2, y: 7 } },
  { key: 'd', cell: { x: 4, y: 7 } },
  { key: 's', cell: { x: 4, y: 9 } },
] as const satisfies ReadonlyArray<{ key: string; cell: GridCell }>;
const BED_CELL: GridCell = { x: 6, y: 8 };
const SHOP_CELL: GridCell = { x: 6, y: 7 };
const JUNE_CELL: GridCell = { x: 9, y: 5 };

async function selectAction(page: Page, key: '1' | '2' | '3' | '4'): Promise<void> {
  await page.keyboard.down(key);
  try {
    await expect(page.locator('[data-feedback]')).toHaveText('Action selected');
  } finally {
    await page.keyboard.up(key);
  }
}

const SOCIAL_ACTION_SELECTION: Readonly<Record<string, ActionSelection>> = {
  'Soil tilled': { key: '1', action: 'hoe', resetKey: '2', resetAction: 'seeds' },
  'Crop planted': { key: '2', action: 'seeds', resetKey: '1', resetAction: 'hoe' },
};
const HARVEST_ACTION_SELECTION: ActionSelection = {
  key: '4',
  action: 'hands',
  resetKey: '1',
  resetAction: 'hoe',
};

async function socialUseSelected(
  page: Page,
  targetKey: string,
  targetCell: GridCell,
  feedback: string | RegExp,
  crop: CropKind = 'turnip',
): Promise<GameSnapshot> {
  const selectAction =
    typeof feedback === 'string' ? SOCIAL_ACTION_SELECTION[feedback] : HARVEST_ACTION_SELECTION;
  return useSelected(page, { key: targetKey, cell: targetCell }, feedback, crop, selectAction);
}

async function selectSeed(page: Page, crop: CropKind): Promise<void> {
  const label = CROP_DEFINITIONS[crop].displayName;
  await page.getByRole('button', { name: `Select ${label}` }).click();
  await expect.poll(async () => (await gameSnapshot(page)).selectedSeed).toBe(crop);
}

async function waterPotato(page: Page): Promise<void> {
  await waterForCurrentWeather(page, FARM_CELLS[0].key, FARM_CELLS[0].cell);
}

async function moveSpawnToFarmHub(page: Page): Promise<void> {
  await moveSocialAxis(page, ['d'], 'x', 'gte', 3.5);
}

async function moveSocialAxis(
  page: Page,
  keys: string[],
  axis: 'x' | 'y',
  comparison: 'gte' | 'lte',
  target: number,
) {
  return moveUntilPlayerAxis(page, keys, axis, comparison, target, 0.25);
}

async function moveBedToFarmHub(page: Page): Promise<void> {
  await moveSocialAxis(page, ['a', 'w'], 'x', 'lte', 3.5);
  const current = await snapshot(page);
  if (current.player.position.y < 8.2) {
    await moveSocialAxis(page, ['a'], 'y', 'gte', 8.3);
  }
  const settled = await moveSocialAxis(page, ['d', 's'], 'x', 'gte', 3.2);
  if (settled.player.position.y >= 8.9) {
    await moveSocialAxis(page, ['w'], 'y', 'lte', 8.7);
  }
}

async function moveFarmHubToShop(page: Page): Promise<void> {
  await moveFarmHubToBed(page);
  await moveUntilPlayerAxis(page, ['w'], 'x', 'lte', 5.1);
  await acquireTarget(page, 'd', SHOP_CELL);
}

async function moveFarmHubToBed(page: Page): Promise<void> {
  await moveSocialAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  let current = await snapshot(page);
  if (current.player.position.y < 9.2) {
    await moveSocialAxis(page, ['s'], 'y', 'gte', 9.2);
    current = await snapshot(page);
  }
  if (current.player.position.y >= 10) {
    await moveSocialAxis(page, ['w'], 'y', 'lte', 9.8);
    await moveSocialAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  }
  current = await snapshot(page);
  if (current.player.position.y < 9) {
    await moveSocialAxis(page, ['s'], 'y', 'gte', 9.1);
  }
  current = await snapshot(page);
  if (current.player.position.x < 5) {
    await moveSocialAxis(page, ['d', 's'], 'x', 'gte', 5.3);
  }
  await acquireTarget(page, 'd', BED_CELL);
}

async function moveFarmHubToJune(page: Page): Promise<void> {
  await moveSocialAxis(page, ['d'], 'x', 'gte', 6.4);
  await moveSocialAxis(page, ['s'], 'y', 'gte', 6.7);
  await moveSocialAxis(page, ['d'], 'x', 'gte', 7.5);
  await moveSocialAxis(page, ['s'], 'y', 'gte', 6.7);
  await acquireTarget(page, 'd', JUNE_CELL);
}

async function moveJuneToBed(page: Page): Promise<void> {
  await moveSocialAxis(page, ['w'], 'x', 'lte', 6.5);
  await moveSocialAxis(page, ['a'], 'x', 'lte', 3.5);
  await moveSocialAxis(page, ['s'], 'y', 'gte', 9.3);
  await acquireTarget(page, 'd', BED_CELL);
}

async function openSleepDialog(page: Page): Promise<Locator> {
  const dialog = page.getByRole('dialog', { name: 'Sleep until tomorrow?' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  return dialog;
}

async function sleepAndStart(page: Page, cropsAdvanced = 3): Promise<GameSnapshot> {
  const before = await gameSnapshot(page);
  await openSleepDialog(page);
  return confirmAndStartDay(page, {
    completedDay: before.day,
    cropsAdvanced,
    staminaRestored: before.maxStamina - before.stamina,
  });
}

async function openJuneDialogue(page: Page): Promise<Locator> {
  const dialog = page.getByRole('dialog', { name: 'June' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  await expect.poll(async () => (await snapshot(page)).locked).toBe(true);
  return dialog;
}

async function closeDialogue(page: Page, dialog: Locator): Promise<void> {
  await dialog.getByRole('button', { name: 'Close', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect.poll(async () => (await snapshot(page)).locked).toBe(false);
}

async function expectDialogueLockedHud(page: Page): Promise<void> {
  await expect(page.getByText('World input: Locked')).toBeVisible();
  await expect(page.locator('[data-farming-hud] button')).toHaveCount(7);
  for (const button of await page.locator('[data-farming-hud] button').all()) {
    await expect(button).toBeDisabled();
  }
  await expect(page.getByRole('button', { name: /world input/i })).toBeDisabled();
}

function cropAt(
  state: GameSnapshot,
  cell: GridCell,
): NonNullable<GameSnapshot['farmTiles'][number]['crop']> {
  const tile = state.farmTiles.find(
    ({ position }) => position.x === cell.x && position.y === cell.y,
  );
  if (!tile?.crop) throw new Error(`Missing crop at ${cell.x},${cell.y}`);
  return tile.crop;
}

test('completes the no-hook three-day village social loop', async ({ page }) => {
  // This real multi-day journey exceeds Playwright's default 30 s budget on CI.
  test.setTimeout(120_000);
  await waitForWorld(page);
  await moveSpawnToFarmHub(page);

  await selectAction(page, '1');
  for (const { key, cell } of FARM_CELLS) {
    await socialUseSelected(page, key, cell, 'Soil tilled');
  }

  await selectAction(page, '2');
  for (const { key, cell } of FARM_CELLS) {
    await socialUseSelected(page, key, cell, 'Crop planted');
  }

  await selectAction(page, '3');
  for (const { key, cell } of FARM_CELLS) {
    await waterForCurrentWeather(page, key, cell);
  }

  await moveFarmHubToBed(page);
  await sleepAndStart(page);

  for (let day = 2; day <= 3; day += 1) {
    await moveBedToFarmHub(page);
    await selectAction(page, '3');
    for (const { key, cell } of FARM_CELLS) {
      await waterForCurrentWeather(page, key, cell);
    }
    await moveFarmHubToBed(page);
    const state = await sleepAndStart(page);
    expect(state.day).toBe(day + 1);
  }

  const dayFour = await gameSnapshot(page);
  for (const { cell } of FARM_CELLS) {
    expect(cropAt(dayFour, cell)).toMatchObject({ kind: 'turnip', growth: 3 });
  }

  await moveBedToFarmHub(page);
  await selectAction(page, '4');
  for (const { key, cell } of FARM_CELLS) {
    await socialUseSelected(page, key, cell, /harvested/i);
  }
  expect((await gameSnapshot(page)).inventory.crops.turnip).toBe(3);

  await moveFarmHubToShop(page);
  const shop = page.getByRole('dialog', { name: 'Seed shop' });
  await page.keyboard.down('e');
  try {
    await expect(shop).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  await shop.getByRole('button', { name: 'Potato seeds' }).click();
  await shop.getByRole('button', { name: 'Buy 1 Potato seed' }).click();
  await expect.poll(async () => (await gameSnapshot(page)).inventory.seeds.potato).toBe(1);
  await shop.getByRole('button', { name: 'Close' }).click();
  await expect(shop).toBeHidden();
  await moveBedToFarmHub(page);

  await selectSeed(page, 'potato');
  await socialUseSelected(page, FARM_CELLS[0].key, FARM_CELLS[0].cell, 'Crop planted', 'potato');
  await waterPotato(page);

  await moveFarmHubToJune(page);
  const stance = await snapshot(page);
  expect(stance.player.facing).toBe('right');
  expect(Math.floor(stance.player.position.x)).toBe(8);
  expect(Math.floor(stance.player.position.y)).toBe(6);
  expect(stance.target).toEqual(JUNE_CELL);

  let dialog = await openJuneDialogue(page);
  await expectDialogueLockedHud(page);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Stranger · 1 relationship point',
  );
  await expect(dialog.locator('[data-dialogue-line]')).toHaveText(
    'It is quieter here than the road makes it look.',
  );
  await expect(dialog.locator('[data-dialogue-points]')).toHaveText('+1 relationship point');
  let social = await gameSnapshot(page);
  expect(social.relationships.resident).toMatchObject({
    points: 1,
    level: 'stranger',
    talkedToday: true,
    giftedToday: false,
  });

  await closeDialogue(page, dialog);
  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-points]')).toHaveCount(0);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Stranger · 1 relationship point',
  );

  await dialog.getByRole('button', { name: 'Give Turnip', exact: true }).click();
  await expect.poll(async () => (await gameSnapshot(page)).inventory.crops.turnip).toBe(2);
  social = await gameSnapshot(page);
  expect(social.relationships.resident).toMatchObject({ points: 6, level: 'stranger' });
  await expect(dialog.locator('[data-dialogue-points]')).toHaveText('+5 relationship points');
  await expect(dialog.locator('[data-dialogue-reaction]')).toHaveText('Favourite gift!');

  const afterFirstGift = await gameSnapshot(page);
  await dialog.getByRole('button', { name: 'Give Turnip', exact: true }).click();
  await expect(page.locator('[data-feedback]')).toHaveText('You already gave a gift today');
  expect(await gameSnapshot(page)).toEqual(afterFirstGift);
  await closeDialogue(page, dialog);

  await moveJuneToBed(page);
  const dayTwo = await sleepAndStart(page, 1);
  expect(dayTwo.relationships.resident).toMatchObject({ talkedToday: false, giftedToday: false });
  await moveBedToFarmHub(page);
  await waterPotato(page);
  await moveFarmHubToJune(page);

  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Stranger · 7 relationship points',
  );
  await dialog.getByRole('button', { name: 'Give Turnip', exact: true }).click();
  await expect.poll(async () => (await gameSnapshot(page)).relationships.resident.points).toBe(12);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Friend · 12 relationship points',
  );
  await closeDialogue(page, dialog);

  await moveJuneToBed(page);
  const dayThree = await sleepAndStart(page, 1);
  expect(dayThree.relationships.resident).toMatchObject({
    talkedToday: false,
    giftedToday: false,
  });
  await moveBedToFarmHub(page);
  await waterPotato(page);
  await moveFarmHubToJune(page);

  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Friend · 13 relationship points',
  );
  await dialog.getByRole('button', { name: 'Give Turnip', exact: true }).click();
  await expect.poll(async () => (await gameSnapshot(page)).relationships.resident.points).toBe(18);
  social = await gameSnapshot(page);
  expect(social.relationships.resident).toMatchObject({
    points: 18,
    level: 'closeFriend',
    closeFriendDialogueSeen: false,
  });
  await closeDialogue(page, dialog);

  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-line]')).toHaveText(
    'You came here as the new farmer, but that is not how I think of you now.',
  );
  await expect(dialog.getByRole('button', { name: 'Continue', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(dialog.locator('[data-dialogue-line]')).toHaveText('You are one of us.');
  await expect(dialog.getByRole('button', { name: 'Close', exact: true })).toBeVisible();
  await closeDialogue(page, dialog);

  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-line]')).toHaveText(
    'The village feels more like home with you here.',
  );
  await expect(dialog.getByRole('button', { name: 'Continue', exact: true })).toHaveCount(0);
  await closeDialogue(page, dialog);

  // Water the potato over two more nights to reach maturity.
  await moveJuneToBed(page);
  await sleepAndStart(page, 1);
  for (let extraDay = 0; extraDay < 2; extraDay += 1) {
    await moveBedToFarmHub(page);
    await waterPotato(page);
    await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1, 0.1);
    await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 9.5, 0.05);
    await acquireTarget(page, 'd', BED_CELL);
    await sleepAndStart(page, 1);
  }

  // Harvest the mature potato and give it as a non-favourite gift.
  await moveBedToFarmHub(page);
  await selectAction(page, '4');
  await socialUseSelected(page, FARM_CELLS[0].key, FARM_CELLS[0].cell, /harvested/i, 'potato');
  expect((await gameSnapshot(page)).inventory.crops.potato).toBe(1);

  await moveFarmHubToJune(page);
  dialog = await openJuneDialogue(page);
  await expect(dialog.locator('[data-dialogue-relationship]')).toHaveText(
    'Close Friend · 19 relationship points',
  );
  await dialog.getByRole('button', { name: 'Give Potato', exact: true }).click();
  await expect.poll(async () => (await gameSnapshot(page)).inventory.crops.potato).toBe(0);
  social = await gameSnapshot(page);
  expect(social.relationships.resident).toMatchObject({ points: 22, level: 'closeFriend' });
  await expect(dialog.locator('[data-dialogue-points]')).toHaveText('+3 relationship points');
  await expect(dialog.locator('[data-dialogue-reaction]')).toHaveText('Gift accepted.');
  await expect(dialog.locator('[data-dialogue-no-crops]')).toBeVisible();
  await expect(dialog.locator('[data-dialogue-gift]')).toHaveCount(0);
  await closeDialogue(page, dialog);

  const observed = await gameSnapshot(page);
  const roundTrip = JSON.parse(JSON.stringify(observed)) as GameSnapshot;
  expect(roundTrip.villagerCells).toEqual(observed.villagerCells);
  expect(roundTrip.relationships).toEqual(observed.relationships);
});
