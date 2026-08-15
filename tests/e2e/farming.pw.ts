import { expect, test, type Locator, type Page } from '@playwright/test';
import { Buffer } from 'node:buffer';
import type { DebugSnapshot } from '../../src/game/phaser/ProofScene';
import type {
  FarmingAction,
  FarmTileSnapshot,
  GameSnapshot,
  GridCell,
  Weather,
} from '../../src/game/core/types';
import { formatTime } from '../../src/game/core/dailyRhythm';
import {
  confirmAndStartDay,
  gameSnapshot,
  moveUntil,
  moveUntilPlayerAxis,
  snapshot,
  waitForWorld,
} from './helpers';

const CROP_CELL: GridCell = { x: 3, y: 8 };
const BED_CELL: GridCell = { x: 6, y: 8 };
const CROP_FOOTPOINT = { x: 3.5, y: 8.5 };
const CROP_WORLD_FOOTPOINT = {
  x: 384 + (CROP_FOOTPOINT.x - CROP_FOOTPOINT.y) * 32,
  y: (CROP_FOOTPOINT.x + CROP_FOOTPOINT.y) * 16,
};

const ACTION_BY_KEY = {
  '1': 'hoe',
  '2': 'turnipSeeds',
  '3': 'wateringCan',
  '4': 'hands',
} as const satisfies Record<string, FarmingAction>;

const ACTION_LABEL: Record<FarmingAction, string> = {
  hoe: 'Hoe',
  turnipSeeds: 'Seeds',
  wateringCan: 'Water',
  hands: 'Hands',
};

const FEEDBACK = {
  actionSelected: 'Action selected',
  soilTilled: 'Soil tilled',
  turnipPlanted: 'Turnip planted',
  cropWatered: 'Crop watered',
  rainWatersCrops: 'Rain is watering the crops',
  dayStarted: 'Day started',
  turnipHarvested: 'Turnip harvested',
  noCrop: 'No crop here',
  notAtBed: 'You must be at the bed',
} as const;

const WEATHER_LABEL: Record<Weather, string> = {
  sunny: 'Sunny',
  rainy: 'Rainy',
};

function cropTile(state: GameSnapshot): FarmTileSnapshot {
  const tile = state.farmTiles.find(({ position }) => (
    position.x === CROP_CELL.x && position.y === CROP_CELL.y
  ));
  if (!tile) throw new Error(`Missing farm tile ${CROP_CELL.x},${CROP_CELL.y}`);
  return tile;
}

function cropDepth(state: DebugSnapshot): number {
  const depth = state.depths['crop:3,8'];
  if (depth === undefined) throw new Error('Missing crop depth for 3,8');
  return depth;
}

async function expectFeedback(page: Page, text: string): Promise<void> {
  await expect(page.locator('[data-feedback]')).toHaveText(text);
}

async function expectHud(page: Page, state: GameSnapshot): Promise<void> {
  await expect(page.locator('.hud-stats p')).toHaveText([
    `Day ${state.day}`,
    `Time: ${formatTime(state.timeMinutes)}`,
    `Stamina: ${state.stamina} / ${state.maxStamina}`,
    `Weather: ${WEATHER_LABEL[state.weather]}`,
    `Selected: ${ACTION_LABEL[state.selectedAction]}`,
    `Seeds: ${state.inventory.turnipSeeds}`,
    `Turnips: ${state.inventory.turnips}`,
  ]);
}

async function expectDebugTarget(page: Page, target: GridCell): Promise<void> {
  expect((await snapshot(page)).target).toEqual(target);
}

async function expectPublishedTarget(page: Page, target: GridCell): Promise<GameSnapshot> {
  const state = await gameSnapshot(page);
  expect(state.target).toEqual(target);
  return state;
}

async function tapDirection(page: Page, key: string, target: GridCell): Promise<void> {
  const facing = key === 'w'
    ? 'up'
    : key === 'd'
      ? 'right'
      : key === 's'
        ? 'down'
        : 'left';
  await page.keyboard.down(key);
  try {
    await expect.poll(async () => (await snapshot(page)).player.facing, { timeout: 3_000 }).toBe(facing);
  } finally {
    await page.keyboard.up(key);
  }
  await expectDebugTarget(page, target);
}

async function selectWithKey(
  page: Page,
  key: keyof typeof ACTION_BY_KEY,
  target: GridCell,
): Promise<GameSnapshot> {
  const action = ACTION_BY_KEY[key];
  await expectDebugTarget(page, target);
  await page.keyboard.down(key);
  try {
    await expectFeedback(page, FEEDBACK.actionSelected);
    await expect.poll(async () => (await gameSnapshot(page)).selectedAction, { timeout: 3_000 }).toBe(action);
  } finally {
    await page.keyboard.up(key);
  }
  const state = await expectPublishedTarget(page, target);
  expect(state.selectedAction).toBe(action);
  return state;
}

async function useSelected(page: Page, target: GridCell, feedback: string): Promise<GameSnapshot> {
  await expectDebugTarget(page, target);
  await page.keyboard.down('Space');
  try {
    await expectFeedback(page, feedback);
  } finally {
    await page.keyboard.up('Space');
  }
  return expectPublishedTarget(page, target);
}

async function waterForCurrentWeather(page: Page): Promise<GameSnapshot> {
  const before = await gameSnapshot(page);
  if (before.weather === 'sunny') {
    const watered = await useSelected(page, CROP_CELL, FEEDBACK.cropWatered);
    expect(watered.timeMinutes).toBe(before.timeMinutes + 20);
    expect(watered.stamina).toBe(before.stamina - 2);
    return watered;
  }

  const rejected = await useSelected(page, CROP_CELL, FEEDBACK.rainWatersCrops);
  expect(rejected).toEqual(before);
  return rejected;
}

async function moveToBed(page: Page): Promise<void> {
  await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  await moveUntilPlayerAxis(page, ['w'], 'y', 'lte', 9.8);
  let settled = await moveUntilPlayerAxis(page, ['d', 's'], 'x', 'gte', 5.1);
  if (settled.player.position.y < 9.8) {
    settled = await moveUntilPlayerAxis(page, ['s'], 'y', 'gte', 9.8);
  }
  expect(Math.floor(settled.player.position.y)).toBe(9);
  await tapDirection(page, 'd', BED_CELL);
}

async function moveToCrop(page: Page): Promise<void> {
  let settled = await moveUntilPlayerAxis(page, ['a', 'w'], 'x', 'lte', 2.8);
  if (settled.player.position.y < 9.3) {
    settled = await moveUntilPlayerAxis(page, ['a'], 'y', 'gte', 9.3);
  }
  expect(Math.floor(settled.player.position.x), JSON.stringify(settled.player.position)).toBe(2);
  expect(Math.floor(settled.player.position.y), JSON.stringify(settled.player.position)).toBe(9);
  await tapDirection(page, 'd', CROP_CELL);
}

async function waitForCameraToSettle(page: Page): Promise<void> {
  await page.evaluate(() => new Promise<void>((resolve, reject) => {
    const deadline = performance.now() + 3_000;
    let previous: { scrollX: number; scrollY: number } | null = null;
    const sample = () => {
      const current = window.__PHOENIX_TEST__?.snapshot().camera;
      if (!current) {
        reject(new Error('Phoenix camera snapshot is not ready'));
        return;
      }
      if (previous
        && Math.abs(current.scrollX - previous.scrollX) < 0.01
        && Math.abs(current.scrollY - previous.scrollY) < 0.01) {
        resolve();
        return;
      }
      previous = { scrollX: current.scrollX, scrollY: current.scrollY };
      if (performance.now() >= deadline) {
        reject(new Error(`Phoenix camera did not settle: ${JSON.stringify(current)}`));
        return;
      }
      requestAnimationFrame(sample);
    };
    requestAnimationFrame(sample);
  }));
}

async function captureCropSprite(page: Page): Promise<Buffer> {
  await waitForCameraToSettle(page);
  const debug = await snapshot(page);
  const canvas = page.locator('canvas');
  const box = await canvas.boundingBox();
  if (!box) throw new Error('Phoenix canvas is not measurable');

  const scaleX = box.width / 640;
  const scaleY = box.height / 360;
  expect(scaleX).toBeGreaterThan(0);
  expect(Number.isInteger(scaleX)).toBe(true);
  expect(scaleY).toBe(scaleX);

  const clip = {
    x: box.x + (CROP_WORLD_FOOTPOINT.x - 16 - debug.camera.scrollX) * scaleX,
    y: box.y + (CROP_WORLD_FOOTPOINT.y - 48 - debug.camera.scrollY) * scaleY,
    width: 32 * scaleX,
    height: 48 * scaleY,
  };
  expect(clip.x).toBeGreaterThanOrEqual(box.x);
  expect(clip.y).toBeGreaterThanOrEqual(box.y);
  expect(clip.x + clip.width).toBeLessThanOrEqual(box.x + box.width);
  expect(clip.y + clip.height).toBeLessThanOrEqual(box.y + box.height);
  return page.screenshot({ clip, animations: 'disabled' });
}

function expectDistinctFrame(previous: Buffer, current: Buffer): void {
  expect(Buffer.compare(previous, current)).not.toBe(0);
}

async function openSleepDialog(page: Page): Promise<Locator> {
  await expectDebugTarget(page, BED_CELL);
  const dialog = page.getByRole('dialog', { name: 'Sleep until tomorrow?' });
  await page.keyboard.down('e');
  try {
    await expect(dialog).toBeVisible();
  } finally {
    await page.keyboard.up('e');
  }
  expect((await snapshot(page)).locked).toBe(true);
  return dialog;
}

test('selects hands, keeps a rejected empty-crop command stable, and supports clickable selection', async ({ page }) => {
  await waitForWorld(page);
  await tapDirection(page, 'd', CROP_CELL);

  const hands = await selectWithKey(page, '4', CROP_CELL);
  expect(hands.inventory).toEqual({ turnipSeeds: 3, turnips: 0 });
  await expectHud(page, hands);

  const beforeRejected = await gameSnapshot(page);
  const rejected = await useSelected(page, CROP_CELL, FEEDBACK.noCrop);
  expect(rejected).toEqual(beforeRejected);
  expect(rejected.timeMinutes).toBe(beforeRejected.timeMinutes);
  expect(rejected.stamina).toBe(beforeRejected.stamina);
  await expectHud(page, beforeRejected);

  await expectDebugTarget(page, CROP_CELL);
  await page.keyboard.down('e');
  try {
    await expectFeedback(page, FEEDBACK.notAtBed);
  } finally {
    await page.keyboard.up('e');
  }
  await expect(page.getByRole('dialog', { name: 'Sleep until tomorrow?' })).toBeHidden();
  const afterAwaySleep = await gameSnapshot(page);
  expect(afterAwaySleep).toEqual(beforeRejected);
  await expectHud(page, beforeRejected);

  const hoeButton = page.getByRole('button', { name: '1 Hoe', exact: true });
  await expectDebugTarget(page, CROP_CELL);
  await hoeButton.click();
  await expect(hoeButton).toHaveAttribute('aria-pressed', 'true');
  await expectFeedback(page, FEEDBACK.actionSelected);
  const hoe = await expectPublishedTarget(page, CROP_CELL);
  expect(hoe.selectedAction).toBe('hoe');
  await expectHud(page, hoe);
});

test('completes three real-control nights from tilling through turnip harvest', async ({ page }) => {
  await waitForWorld(page);
  await tapDirection(page, 'd', CROP_CELL);

  let state = await selectWithKey(page, '1', CROP_CELL);
  await expectHud(page, state);
  state = await useSelected(page, CROP_CELL, FEEDBACK.soilTilled);
  expect(cropTile(state)).toMatchObject({ soil: 'tilled', crop: null });
  expect(state.timeMinutes).toBe(390);
  expect(state.stamina).toBe(17);
  await expectHud(page, state);

  state = await selectWithKey(page, '2', CROP_CELL);
  await expectHud(page, state);
  state = await useSelected(page, CROP_CELL, FEEDBACK.turnipPlanted);
  expect(cropTile(state)).toMatchObject({
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 0, wateredToday: false },
  });
  expect(state.timeMinutes).toBe(410);
  expect(state.stamina).toBe(16);
  await expectHud(page, state);
  let previousFrame = await captureCropSprite(page);

  state = await selectWithKey(page, '3', CROP_CELL);
  await expectHud(page, state);
  expect(state.weather).toBe('sunny');
  state = await waterForCurrentWeather(page);
  expect(cropTile(state)).toMatchObject({
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 0, wateredToday: true },
  });
  expect(state.timeMinutes).toBe(430);
  expect(state.stamina).toBe(14);
  await expectHud(page, state);
  let currentFrame = await captureCropSprite(page);
  expectDistinctFrame(previousFrame, currentFrame);
  previousFrame = currentFrame;

  await moveToBed(page);
  const firstDialog = await openSleepDialog(page);
  const beforeCancel = await gameSnapshot(page);
  const beforeCancelDebug = await snapshot(page);
  await page.keyboard.press('d');
  await page.keyboard.press('2');
  await page.keyboard.press('Space');
  expect(await gameSnapshot(page)).toEqual(beforeCancel);
  const afterBlockedInput = await snapshot(page);
  expect(afterBlockedInput.player).toEqual(beforeCancelDebug.player);
  expect(afterBlockedInput.locked).toBe(true);

  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(firstDialog).toBeHidden();
  expect((await snapshot(page)).locked).toBe(false);
  expect(await gameSnapshot(page)).toEqual(beforeCancel);
  await expectFeedback(page, FEEDBACK.cropWatered);

  await openSleepDialog(page);
  state = await confirmAndStartDay(page, {
    completedDay: 1,
    cropsAdvanced: 1,
    staminaRestored: 6,
  });
  await expectFeedback(page, FEEDBACK.dayStarted);
  await expectPublishedTarget(page, BED_CELL);
  expect(state.day).toBe(2);
  expect(state.timeMinutes).toBe(360);
  expect(state.stamina).toBe(20);
  expect(state.pendingDaySummary).toBeNull();
  expect(cropTile(state)).toMatchObject({ crop: { growth: 1, wateredToday: false } });
  await expectHud(page, state);

  await moveToCrop(page);
  currentFrame = await captureCropSprite(page);
  expectDistinctFrame(previousFrame, currentFrame);
  previousFrame = currentFrame;

  state = await selectWithKey(page, '3', CROP_CELL);
  await expectHud(page, state);
  const day2Weather = state.weather;
  state = await waterForCurrentWeather(page);
  if (day2Weather === 'sunny') {
    expect(cropTile(state)).toMatchObject({ crop: { growth: 1, wateredToday: true } });
    expect(state.timeMinutes).toBe(380);
    expect(state.stamina).toBe(18);
  } else {
    expect(cropTile(state)).toMatchObject({ crop: { growth: 1, wateredToday: false } });
    expect(state.timeMinutes).toBe(360);
    expect(state.stamina).toBe(20);
  }
  await expectHud(page, state);
  if (day2Weather === 'sunny') {
    currentFrame = await captureCropSprite(page);
    expectDistinctFrame(previousFrame, currentFrame);
    previousFrame = currentFrame;
  }

  await moveToBed(page);
  await openSleepDialog(page);
  state = await confirmAndStartDay(page, {
    completedDay: 2,
    cropsAdvanced: 1,
    staminaRestored: day2Weather === 'sunny' ? 2 : 0,
  });
  await expectFeedback(page, FEEDBACK.dayStarted);
  await expectPublishedTarget(page, BED_CELL);
  expect(state.day).toBe(3);
  expect(state.timeMinutes).toBe(360);
  expect(state.stamina).toBe(20);
  expect(state.pendingDaySummary).toBeNull();
  expect(cropTile(state)).toMatchObject({ crop: { growth: 2, wateredToday: false } });
  await expectHud(page, state);

  await moveToCrop(page);
  currentFrame = await captureCropSprite(page);
  expectDistinctFrame(previousFrame, currentFrame);
  previousFrame = currentFrame;

  state = await selectWithKey(page, '3', CROP_CELL);
  await expectHud(page, state);
  const day3Weather = state.weather;
  state = await waterForCurrentWeather(page);
  if (day3Weather === 'sunny') {
    expect(cropTile(state)).toMatchObject({ crop: { growth: 2, wateredToday: true } });
    expect(state.timeMinutes).toBe(380);
    expect(state.stamina).toBe(18);
  } else {
    expect(cropTile(state)).toMatchObject({ crop: { growth: 2, wateredToday: false } });
    expect(state.timeMinutes).toBe(360);
    expect(state.stamina).toBe(20);
  }
  await expectHud(page, state);
  if (day3Weather === 'sunny') {
    currentFrame = await captureCropSprite(page);
    expectDistinctFrame(previousFrame, currentFrame);
    previousFrame = currentFrame;
  }

  await moveToBed(page);
  await openSleepDialog(page);
  state = await confirmAndStartDay(page, {
    completedDay: 3,
    cropsAdvanced: 1,
    staminaRestored: day3Weather === 'sunny' ? 2 : 0,
  });
  await expectFeedback(page, FEEDBACK.dayStarted);
  await expectPublishedTarget(page, BED_CELL);
  expect(state.day).toBe(4);
  expect(state.timeMinutes).toBe(360);
  expect(state.stamina).toBe(20);
  expect(state.pendingDaySummary).toBeNull();
  expect(cropTile(state)).toMatchObject({ crop: { growth: 3, wateredToday: false } });
  await expectHud(page, state);

  await moveToCrop(page);
  currentFrame = await captureCropSprite(page);
  expectDistinctFrame(previousFrame, currentFrame);

  state = await selectWithKey(page, '4', CROP_CELL);
  await expectHud(page, state);
  state = await useSelected(page, CROP_CELL, FEEDBACK.turnipHarvested);
  expect(cropTile(state)).toEqual({ position: CROP_CELL, soil: 'tilled', crop: null });
  expect(state.inventory).toEqual({ turnipSeeds: 2, turnips: 1 });
  await expectPublishedTarget(page, CROP_CELL);
  await expectHud(page, state);
});

test('reverses crop and player depth while retaining foundation scenery depth keys', async ({ page }) => {
  await waitForWorld(page);
  await tapDirection(page, 'd', CROP_CELL);
  await selectWithKey(page, '1', CROP_CELL);
  await useSelected(page, CROP_CELL, FEEDBACK.soilTilled);
  await selectWithKey(page, '2', CROP_CELL);
  await useSelected(page, CROP_CELL, FEEDBACK.turnipPlanted);

  const farSide = await moveUntil(page, 'w', (value) => value.player.world.y <= 188.8);
  expect(farSide.depths.player).toBeLessThan(cropDepth(farSide));
  expect(farSide.depths).toHaveProperty('tree');
  expect(farSide.depths).toHaveProperty('building');
  expect(farSide.depths).toHaveProperty('crop:3,8');

  const nearSide = await moveUntil(page, 's', (value) => value.player.world.y >= 195.2);
  expect(nearSide.depths.player).toBeGreaterThan(cropDepth(nearSide));
  expect(nearSide.depths).toHaveProperty('tree');
  expect(nearSide.depths).toHaveProperty('building');
  expect(nearSide.depths).toHaveProperty('crop:3,8');
});
