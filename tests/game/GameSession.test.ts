import { describe, expect, test } from 'bun:test';
import { GameSession, type GameSessionConfig } from '../../src/game/core/GameSession';
import { CROP_DEFINITIONS, CROP_KINDS, isMature } from '../../src/game/core/cropDefinitions';
import {
  ACTION_CUTOFF_MINUTES,
  DAY_START_MINUTES,
  MAX_DAY,
  MAX_STAMINA,
} from '../../src/game/core/dailyRhythm';
import type {
  CropKind,
  FarmingAction,
  GameSnapshot,
  GameState,
  GridCell,
  VillagerId,
  Weather,
} from '../../src/game/core/types';

const farmCells = [
  { x: 2, y: 7 },
  { x: 3, y: 7 },
  { x: 4, y: 7 },
  { x: 2, y: 8 },
  { x: 3, y: 8 },
  { x: 4, y: 8 },
  { x: 2, y: 9 },
  { x: 3, y: 9 },
  { x: 4, y: 9 },
];

const roundTripFarmCells = [
  { x: 6, y: 2 },
  { x: 7, y: 2 },
  { x: 8, y: 2 },
  { x: 6, y: 3 },
  { x: 7, y: 3 },
  { x: 8, y: 3 },
  { x: 6, y: 4 },
  { x: 7, y: 4 },
  { x: 8, y: 4 },
];

const bedCell = { x: 6, y: 8 };
const shopCell = { x: 6, y: 10 };
const shippingCell = { x: 4, y: 10 };
const villagerCells = {
  shopkeeper: { x: 6, y: 5 },
  farmer: { x: 3, y: 5 },
  resident: { x: 9, y: 5 },
} as const;

const villagerStances = {
  shopkeeper: {
    spawn: { x: 5.5, y: 6.5 },
    input: { screenX: 1, screenY: 0 },
    bedCell: { x: 6, y: 7 },
    bedInput: { screenX: 0, screenY: 1 },
  },
  farmer: {
    spawn: { x: 4.5, y: 6.5 },
    input: { screenX: 0, screenY: -1 },
    bedCell: { x: 5, y: 7 },
    bedInput: { screenX: 0, screenY: 1 },
  },
  resident: {
    spawn: { x: 8.5, y: 6.5 },
    input: { screenX: 1, screenY: 0 },
    bedCell: { x: 7, y: 5 },
    bedInput: { screenX: 0, screenY: -1 },
  },
} as const;

function config(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 5.5, y: 9.5 },
      footprints: [
        { id: 'tree', x: 7, y: 4, width: 1, height: 1 },
        { id: 'building', x: 7, y: 7, width: 3, height: 2 },
      ],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells,
    bedCell,
    shopCell,
    shippingCell,
    villagerCells,
    nextWeather: () => 'sunny',
    ...overrides,
  };
}

function roundTripConfig(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 3.5, y: 8.5 },
      footprints: [],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells: roundTripFarmCells,
    bedCell: { x: 4, y: 9 },
    shopCell: { x: 4, y: 7 },
    shippingCell: { x: 2, y: 9 },
    villagerCells: {
      shopkeeper: { x: 2, y: 7 },
      farmer: { x: 9, y: 5 },
      resident: { x: 10, y: 5 },
    },
    nextWeather: () => 'sunny',
    ...overrides,
  };
}

function face(session: GameSession, screenX: number, screenY: number): void {
  session.stepMovement({ screenX, screenY }, 0);
}

function withoutWorld(snapshot: GameSnapshot) {
  const { player: _player, target: _target, ...rest } = snapshot;
  void _player;
  void _target;
  return rest;
}

function sessionWithConfig(overrides: Partial<GameSessionConfig> = {}): GameSession {
  return new GameSession(config(overrides));
}

function faceBed(session: GameSession): void {
  session.stepMovement({ screenX: 1, screenY: 0 }, 0);
  expect(session.snapshot().target).toEqual(bedCell);
}

function faceShop(session: GameSession): void {
  session.stepMovement({ screenX: 0, screenY: 1 }, 0);
  expect(session.snapshot().target).toEqual(shopCell);
}

function faceShipping(session: GameSession): void {
  session.stepMovement({ screenX: -1, screenY: 0 }, 0);
  expect(session.snapshot().target).toEqual(shippingCell);
}

function faceVillager(session: GameSession, id: VillagerId): void {
  session.stepMovement(villagerStances[id].input, 0);
  expect(session.snapshot().target).toEqual(villagerCells[id]);
}

function sessionAtVillager(
  id: VillagerId,
  overrides: Partial<GameSessionConfig> = {},
): GameSession {
  const base = config(overrides);
  return new GameSession({
    ...base,
    world: { ...base.world, spawn: { ...villagerStances[id].spawn } },
    bedCell: { ...villagerStances[id].bedCell },
  });
}

function faceSocialBed(session: GameSession, id: VillagerId): void {
  session.stepMovement(villagerStances[id].bedInput, 0);
  expect(session.snapshot().target).toEqual(villagerStances[id].bedCell);
}

function harvestTurnipAtVillager(session: GameSession, id: VillagerId): void {
  preparePlanted(session);
  for (let night = 0; night < 3; night += 1) {
    expect(session.water(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });
    faceSocialBed(session, id);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  }
  expect(session.harvest(farmCells[0])).toEqual({ ok: true, code: 'crop-harvested' });
}

function harvestThreeTurnipsAtVillager(session: GameSession, id: VillagerId): void {
  for (const cell of farmCells.slice(0, 3)) preparePlanted(session, cell);
  for (let night = 0; night < 3; night += 1) {
    for (const cell of farmCells.slice(0, 3)) {
      expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    }
    faceSocialBed(session, id);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  }
  for (const cell of farmCells.slice(0, 3)) {
    expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
  }
}

function preparePlanted(session: GameSession, cell: GridCell = farmCells[0]): void {
  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
}

function prepareCrop(session: GameSession, kind: CropKind, cell: GridCell): void {
  if (kind !== 'turnip') {
    faceShop(session);
    expect(session.buySeeds(kind, 1)).toEqual({ ok: true, code: 'seeds-purchased' });
  }
  expect(session.selectSeed(kind)).toEqual({ ok: true, code: 'seed-selected' });
  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
}

function advanceDayAtBed(session: GameSession): void {
  faceBed(session);
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
  expect(session.snapshot().pendingDaySummary).not.toBeNull();
  expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  expect(session.snapshot().pendingDaySummary).toBeNull();
}

function growToMaturity(session: GameSession, cell: GridCell = farmCells[0]): void {
  const kind = session
    .snapshot()
    .farmTiles.find((tile) => tile.position.x === cell.x && tile.position.y === cell.y)?.crop?.kind;
  if (!kind) throw new Error('test crop is missing');
  for (let growth = 0; growth < CROP_DEFINITIONS[kind].growthDays; growth += 1) {
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    advanceDayAtBed(session);
  }
}

describe('GameSession', () => {
  test('starts a fresh Day 1 turnip session', () => {
    const session = new GameSession(config());
    const first = session.snapshot();
    const second = session.snapshot();

    expect(first.day).toBe(1);
    expect(first).toMatchObject({
      day: 1,
      timeMinutes: 360,
      stamina: 20,
      maxStamina: 20,
      weather: 'sunny',
      pendingDaySummary: null,
    });
    expect(first.selectedAction).toBe('hoe');
    expect(first.inventory).toEqual({
      seeds: { turnip: 3, potato: 0, pumpkin: 0 },
      crops: { turnip: 0, potato: 0, pumpkin: 0 },
    });
    expect(first.farmTiles.map((tile) => tile.position)).toEqual(farmCells);
    expect(first.farmTiles.every((tile) => tile.soil === 'untilled' && tile.crop === null)).toBe(
      true,
    );
    expect(first.bedCell).toEqual(bedCell);
    expect(first.shopCell).toEqual(shopCell);
    expect(first.shippingCell).toEqual(shippingCell);
    expect(second).toEqual(first);
    expect(second).not.toBe(first);
    expect(second.farmTiles).not.toBe(first.farmTiles);
    expect(second.inventory).not.toBe(first.inventory);
  });

  test('charges 30 minutes and 3 stamina for a successful hoe', () => {
    const session = new GameSession(config());
    const before = session.snapshot();

    expect(session.hoe(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });

    const after = session.snapshot();
    expect(after.timeMinutes).toBe(before.timeMinutes + 30);
    expect(after.stamina).toBe(before.stamina - 3);
  });

  test('charges 20 minutes and 1 stamina for a successful plant', () => {
    const session = new GameSession(config());
    expect(session.hoe(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });
    const before = session.snapshot();

    expect(session.plant(farmCells[0])).toEqual({ ok: true, code: 'crop-planted' });

    const after = session.snapshot();
    expect(after.timeMinutes).toBe(before.timeMinutes + 20);
    expect(after.stamina).toBe(before.stamina - 1);
  });

  test('charges 20 minutes and 2 stamina for a successful water', () => {
    const session = new GameSession(config());
    preparePlanted(session);
    const before = session.snapshot();

    expect(session.water(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });

    const after = session.snapshot();
    expect(after.timeMinutes).toBe(before.timeMinutes + 20);
    expect(after.stamina).toBe(before.stamina - 2);
  });

  test('charges 20 minutes and 1 stamina for a successful harvest', () => {
    const session = new GameSession(config());
    preparePlanted(session);
    growToMaturity(session);
    const before = session.snapshot();

    expect(session.harvest(farmCells[0])).toEqual({ ok: true, code: 'crop-harvested' });

    const after = session.snapshot();
    expect(after.timeMinutes).toBe(before.timeMinutes + 20);
    expect(after.stamina).toBe(before.stamina - 1);
  });

  test('rejects a seventh valid hoe when stamina is exhausted without mutation', () => {
    const session = new GameSession(config());
    for (const cell of farmCells.slice(0, 6)) {
      expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
    }
    expect(session.snapshot()).toMatchObject({ timeMinutes: 540, stamina: 2 });
    const beforeSeventhHoe = session.snapshot();

    expect(session.hoe(farmCells[6])).toEqual({ ok: false, code: 'insufficient-stamina' });
    expect(session.snapshot()).toEqual(beforeSeventhHoe);
  });

  test('does not charge action selection or movement', () => {
    const session = new GameSession(config());
    const beforeSelection = session.snapshot();

    expect(session.selectAction('wateringCan')).toEqual({ ok: true, code: 'action-selected' });

    const afterSelection = session.snapshot();
    expect(afterSelection.timeMinutes).toBe(beforeSelection.timeMinutes);
    expect(afterSelection.stamina).toBe(beforeSelection.stamina);

    session.stepMovement({ screenX: 1, screenY: 0 }, 16);

    const afterMovement = session.snapshot();
    expect(afterMovement.timeMinutes).toBe(afterSelection.timeMinutes);
    expect(afterMovement.stamina).toBe(afterSelection.stamina);
  });

  test('resets time and stamina after a completed day transition', () => {
    const session = new GameSession(config());
    expect(session.hoe(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });
    advanceDayAtBed(session);
    expect(session.snapshot()).toMatchObject({
      day: 2,
      timeMinutes: 360,
      stamina: 20,
      maxStamina: 20,
    });
  });

  test('grows and harvests one turnip after three watered nights', () => {
    const session = new GameSession(config());
    const cell = farmCells[0];

    expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
    expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
    expect(session.snapshot().inventory.seeds.turnip).toBe(2);

    for (const growth of [1, 2, 3] as const) {
      expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
      session.stepMovement({ screenX: 1, screenY: 0 }, 0);
      expect(session.snapshot().target).toEqual({ x: 6, y: 8 });
      advanceDayAtBed(session);
      expect(session.snapshot().farmTiles[0].crop).toEqual({
        kind: 'turnip',
        growth,
        wateredToday: false,
      });
    }

    expect(session.snapshot().day).toBe(4);
    expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
    expect(session.snapshot().farmTiles[0]).toEqual({
      position: cell,
      soil: 'tilled',
      crop: null,
    });
    expect(session.snapshot().inventory).toEqual({
      seeds: { turnip: 2, potato: 0, pumpkin: 0 },
      crops: { turnip: 1, potato: 0, pumpkin: 0 },
    });
  });

  test('starts with the exact forgiving economy', () => {
    expect(sessionWithConfig().snapshot()).toMatchObject({
      money: 150,
      selectedSeed: 'turnip',
      inventory: {
        seeds: { turnip: 3, potato: 0, pumpkin: 0 },
        crops: { turnip: 0, potato: 0, pumpkin: 0 },
      },
      pendingShipment: { turnip: 0, potato: 0, pumpkin: 0 },
      shopCell,
      shippingCell,
    });
  });

  test.each([...CROP_KINDS] as CropKind[])(
    'grows and harvests %s only at configured maturity',
    (kind) => {
      const session = sessionWithConfig();
      const cell = farmCells[0];
      prepareCrop(session, kind, cell);

      for (let progress = 0; progress < CROP_DEFINITIONS[kind].growthDays; progress += 1) {
        expect(session.harvest(cell)).toEqual({ ok: false, code: 'crop-immature' });
        expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
        faceBed(session);
        expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
        expect(session.snapshot().farmTiles[0].crop).toEqual({
          kind,
          growth: progress + 1,
          wateredToday: false,
        });
        expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
      }

      expect(isMature(kind, CROP_DEFINITIONS[kind].growthDays)).toBe(true);
      expect(session.water(cell)).toEqual({ ok: false, code: 'crop-mature' });
      expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
      expect(session.snapshot().inventory.crops[kind]).toBe(1);
    },
  );

  test('buys exact quantities atomically and preserves failures', () => {
    const session = sessionWithConfig();
    faceShop(session);
    expect(session.buySeeds('potato', 2)).toEqual({ ok: true, code: 'seeds-purchased' });
    expect(session.snapshot()).toMatchObject({
      money: 70,
      inventory: { seeds: { turnip: 3, potato: 2, pumpkin: 0 } },
    });

    const beforeUnaffordable = session.snapshot();
    expect(session.buySeeds('pumpkin', 2)).toEqual({ ok: false, code: 'insufficient-funds' });
    expect(session.snapshot()).toEqual(beforeUnaffordable);

    for (const quantity of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
      const beforeInvalid = session.snapshot();
      expect(session.buySeeds('turnip', quantity)).toEqual({ ok: false, code: 'invalid-quantity' });
      expect(session.snapshot()).toEqual(beforeInvalid);
    }
  });

  test('deposits immediately, pays once at sleep, and clears shipment before summary', () => {
    const session = sessionWithConfig();
    const cell = farmCells[0];
    prepareCrop(session, 'turnip', cell);
    for (let night = 0; night < 3; night += 1) {
      expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
      faceBed(session);
      expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
    }
    expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });

    faceShipping(session);
    expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
    expect(session.snapshot().inventory.crops.turnip).toBe(0);
    expect(session.snapshot().pendingShipment.turnip).toBe(1);

    faceBed(session);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    const paid = session.snapshot();
    expect(paid.money).toBe(185);
    expect(paid.pendingShipment).toEqual({ turnip: 0, potato: 0, pumpkin: 0 });
    expect(paid.pendingDaySummary).toMatchObject({
      shipments: [{ crop: 'turnip', quantity: 1, unitValue: 35, lineTotal: 35 }],
      shippingIncome: 35,
      moneyAfterShipping: 185,
    });
    const beforeDuplicate = session.snapshot();
    expect(session.sleep()).toEqual({ ok: false, code: 'day-summary-pending' });
    expect(session.snapshot()).toEqual(beforeDuplicate);
  });

  test('deep-clones nested economy and summary snapshots', () => {
    const session = sessionWithConfig();
    const first = session.snapshot();
    const second = session.snapshot();
    expect(second.inventory).not.toBe(first.inventory);
    expect(second.inventory.seeds).not.toBe(first.inventory.seeds);
    expect(second.inventory.crops).not.toBe(first.inventory.crops);
    expect(second.pendingShipment).not.toBe(first.pendingShipment);
    expect(second.bedCell).not.toBe(first.bedCell);
    expect(second.shopCell).not.toBe(first.shopCell);
    expect(second.shippingCell).not.toBe(first.shippingCell);

    prepareCrop(session, 'turnip', farmCells[0]);
    for (let night = 0; night < 3; night += 1) {
      session.water(farmCells[0]);
      faceBed(session);
      session.sleep();
      session.acknowledgeDaySummary();
    }
    session.harvest(farmCells[0]);
    faceShipping(session);
    session.depositCrop('turnip', 1);
    faceBed(session);
    session.sleep();
    const summaryA = session.snapshot().pendingDaySummary!;
    const summaryB = session.snapshot().pendingDaySummary!;
    expect(summaryB).not.toBe(summaryA);
    expect(summaryB.shipments).not.toBe(summaryA.shipments);
    expect(summaryB.shipments[0]).not.toBe(summaryA.shipments[0]);
    summaryA.shipments[0].quantity = 999;
    expect(session.snapshot().pendingDaySummary?.shipments[0].quantity).toBe(1);
  });

  test('location and deposit failures preserve the complete snapshot', () => {
    const session = sessionWithConfig();
    faceBed(session);
    const awayFromShop = session.snapshot();
    expect(session.buySeeds('turnip', 1)).toEqual({ ok: false, code: 'not-at-shop' });
    expect(session.snapshot()).toEqual(awayFromShop);

    faceShipping(session);
    for (const quantity of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
      const before = session.snapshot();
      expect(session.depositCrop('turnip', quantity)).toEqual({
        ok: false,
        code: 'invalid-quantity',
      });
      expect(session.snapshot()).toEqual(before);
    }
    const beforeMissing = session.snapshot();
    expect(session.depositCrop('turnip', 1)).toEqual({ ok: false, code: 'insufficient-crops' });
    expect(session.snapshot()).toEqual(beforeMissing);
  });

  test('empty shipment produces a zero-income summary', () => {
    const session = sessionWithConfig();
    faceBed(session);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.snapshot()).toMatchObject({
      money: 150,
      pendingShipment: { turnip: 0, potato: 0, pumpkin: 0 },
      pendingDaySummary: {
        shipments: [],
        shippingIncome: 0,
        moneyAfterShipping: 150,
      },
    });
  });

  test('supports partial then full deposit and rejects a double deposit', () => {
    const session = sessionWithConfig();
    const cells = farmCells.slice(0, 2);
    for (const cell of cells) prepareCrop(session, 'turnip', cell);
    for (let night = 0; night < 3; night += 1) {
      for (const cell of cells) expect(session.water(cell).ok).toBe(true);
      faceBed(session);
      expect(session.sleep().ok).toBe(true);
      expect(session.acknowledgeDaySummary().ok).toBe(true);
    }
    for (const cell of cells) expect(session.harvest(cell).ok).toBe(true);
    faceShipping(session);
    expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
    expect(session.snapshot().inventory.crops.turnip).toBe(1);
    expect(session.snapshot().pendingShipment.turnip).toBe(1);
    expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
    expect(session.snapshot().inventory.crops.turnip).toBe(0);
    expect(session.snapshot().pendingShipment.turnip).toBe(2);
    const beforeDouble = session.snapshot();
    expect(session.depositCrop('turnip', 1)).toEqual({ ok: false, code: 'insufficient-crops' });
    expect(session.snapshot()).toEqual(beforeDouble);
  });

  test('rejects hoeing an already-tilled empty tile without mutation', () => {
    const session = new GameSession(config());
    const cell = farmCells[0];

    expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
    const before = session.snapshot();

    expect(session.hoe(cell)).toEqual({ ok: false, code: 'already-tilled' });
    expect(session.snapshot()).toEqual(before);
  });

  describe('rejection prefixes and precedence', () => {
    const commands = [
      ['hoe', (session: GameSession, position: GridCell | null) => session.hoe(position)],
      ['plant', (session: GameSession, position: GridCell | null) => session.plant(position)],
      ['water', (session: GameSession, position: GridCell | null) => session.water(position)],
      ['harvest', (session: GameSession, position: GridCell | null) => session.harvest(position)],
    ] as const;

    test('returns no-target for null across all farming commands without mutation', () => {
      for (const [name, command] of commands) {
        const session = new GameSession(config());
        const before = session.snapshot();

        expect(command(session, null), name).toEqual({ ok: false, code: 'no-target' });
        expect(session.snapshot()).toEqual(before);
      }
    });

    test('returns not-farm-cell for non-farm positions across all farming commands without mutation', () => {
      for (const [name, command] of commands) {
        const session = new GameSession(config());
        const before = session.snapshot();

        expect(command(session, { x: 99, y: 99 }), name).toEqual({
          ok: false,
          code: 'not-farm-cell',
        });
        expect(session.snapshot()).toEqual(before);
      }
    });

    test('checks crop-present before already-tilled for hoe', () => {
      const session = new GameSession(config());
      const cell = farmCells[0];
      preparePlanted(session, cell);
      const before = session.snapshot();

      expect(session.hoe(cell)).toEqual({ ok: false, code: 'crop-present' });
      expect(session.snapshot()).toEqual(before);
    });

    test('checks soil-untilled, crop-present, then seeds for plant', () => {
      const untilled = new GameSession(config());
      const untilledBefore = untilled.snapshot();
      expect(untilled.plant(farmCells[0])).toEqual({ ok: false, code: 'soil-untilled' });
      expect(untilled.snapshot()).toEqual(untilledBefore);

      const planted = new GameSession(config());
      preparePlanted(planted, farmCells[0]);
      const plantedBefore = planted.snapshot();
      expect(planted.plant(farmCells[0])).toEqual({ ok: false, code: 'crop-present' });
      expect(planted.snapshot()).toEqual(plantedBefore);

      const noSeeds = new GameSession(config());
      for (const cell of farmCells.slice(0, 3)) preparePlanted(noSeeds, cell);
      const noSeedsCell = farmCells[3];
      expect(noSeeds.hoe(noSeedsCell)).toEqual({ ok: true, code: 'soil-tilled' });
      const noSeedsBefore = noSeeds.snapshot();
      expect(noSeeds.plant(noSeedsCell)).toEqual({ ok: false, code: 'no-selected-seeds' });
      expect(noSeeds.snapshot()).toEqual(noSeedsBefore);
    });

    test('checks no-crop, crop-mature, then already-watered for water', () => {
      const noCrop = new GameSession(config());
      const noCropBefore = noCrop.snapshot();
      expect(noCrop.water(farmCells[0])).toEqual({ ok: false, code: 'no-crop' });
      expect(noCrop.snapshot()).toEqual(noCropBefore);

      const mature = new GameSession(config());
      preparePlanted(mature);
      growToMaturity(mature);
      const matureBefore = mature.snapshot();
      expect(mature.water(farmCells[0])).toEqual({ ok: false, code: 'crop-mature' });
      expect(mature.snapshot()).toEqual(matureBefore);

      const watered = new GameSession(config());
      preparePlanted(watered);
      expect(watered.water(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });
      const wateredBefore = watered.snapshot();
      expect(watered.water(farmCells[0])).toEqual({ ok: false, code: 'already-watered' });
      expect(watered.snapshot()).toEqual(wateredBefore);
    });

    test('checks no-crop then crop-immature for harvest', () => {
      const noCrop = new GameSession(config());
      const noCropBefore = noCrop.snapshot();
      expect(noCrop.harvest(farmCells[0])).toEqual({ ok: false, code: 'no-crop' });
      expect(noCrop.snapshot()).toEqual(noCropBefore);

      const immature = new GameSession(config());
      preparePlanted(immature);
      const before = immature.snapshot();
      expect(immature.harvest(farmCells[0])).toEqual({ ok: false, code: 'crop-immature' });
      expect(immature.snapshot()).toEqual(before);
    });

    test('rejects sleep away from the bed before mutating day or crops', () => {
      const session = new GameSession(config());
      preparePlanted(session);
      expect(session.water(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });
      const before = session.snapshot();

      expect(session.sleep()).toEqual({ ok: false, code: 'not-at-bed' });
      expect(session.snapshot()).toEqual(before);
    });
  });

  test('grows only watered crops, clears watering flags, and advances one day', () => {
    const session = new GameSession(config());
    const watered = farmCells[0];
    const dry = farmCells[1];
    preparePlanted(session, watered);
    preparePlanted(session, dry);
    expect(session.water(watered)).toEqual({ ok: true, code: 'crop-watered' });

    advanceDayAtBed(session);
    expect(session.snapshot().day).toBe(2);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth: 1,
      wateredToday: false,
    });
    expect(session.snapshot().farmTiles[1].crop).toEqual({
      kind: 'turnip',
      growth: 0,
      wateredToday: false,
    });

    expect(session.water(watered)).toEqual({ ok: true, code: 'crop-watered' });
    advanceDayAtBed(session);
    expect(session.snapshot().farmTiles[0].crop?.growth).toBe(2);

    expect(session.water(watered)).toEqual({ ok: true, code: 'crop-watered' });
    advanceDayAtBed(session);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth: 3,
      wateredToday: false,
    });
    expect(session.snapshot().day).toBe(4);

    const beforeUnwateredSleep = session.snapshot();
    advanceDayAtBed(session);
    expect(session.snapshot().day).toBe(5);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth: 3,
      wateredToday: false,
    });
    expect(session.snapshot().farmTiles[1].crop).toEqual(beforeUnwateredSleep.farmTiles[1].crop);
  });

  test('uses the provider once and leaves a complete morning summary pending', () => {
    let weatherCalls = 0;
    const session = sessionWithConfig({
      nextWeather: () => {
        weatherCalls += 1;
        return 'rainy';
      },
    });
    const cell = farmCells[0];
    preparePlanted(session, cell);
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    faceBed(session);

    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(weatherCalls).toBe(1);
    expect(session.snapshot()).toMatchObject({
      day: 2,
      timeMinutes: 360,
      stamina: 20,
      weather: 'rainy',
      pendingDaySummary: {
        completedDay: 1,
        nextDay: 2,
        cropsAdvanced: 1,
        nextWeather: 'rainy',
        staminaRestored: 6,
      },
    });

    const beforeDuplicateSleep = session.snapshot();
    expect(session.sleep()).toEqual({ ok: false, code: 'day-summary-pending' });
    expect(session.snapshot()).toEqual(beforeDuplicateSleep);
    expect(weatherCalls).toBe(1);

    expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
    const afterAcknowledgment = session.snapshot();
    expect(afterAcknowledgment.pendingDaySummary).toBeNull();
    expect(session.acknowledgeDaySummary()).toEqual({ ok: false, code: 'no-day-summary' });
    expect(session.snapshot()).toEqual(afterAcknowledgment);
  });

  test('lets rainy days grow crops without manual watering', () => {
    let weatherCalls = 0;
    const session = sessionWithConfig({
      nextWeather: () => {
        weatherCalls += 1;
        return weatherCalls === 1 ? 'rainy' : 'sunny';
      },
    });
    const cell = farmCells[0];
    preparePlanted(session, cell);

    advanceDayAtBed(session);
    const afterFirstRainyNight = session.snapshot();
    expect(afterFirstRainyNight.day).toBe(2);
    expect(afterFirstRainyNight.weather).toBe('rainy');
    expect(afterFirstRainyNight.farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth: 0,
      wateredToday: false,
    });

    const beforeRainWater = session.snapshot();
    expect(session.water(cell)).toEqual({ ok: false, code: 'rain-waters-crops' });
    expect(session.snapshot()).toEqual(beforeRainWater);

    advanceDayAtBed(session);
    const afterSecondRainyNight = session.snapshot();
    expect(afterSecondRainyNight.day).toBe(3);
    expect(afterSecondRainyNight.weather).toBe('sunny');
    expect(afterSecondRainyNight.farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth: 1,
      wateredToday: false,
    });
  });

  test('blocks every active-day command and movement while a summary is pending', () => {
    const session = new GameSession(config());
    faceBed(session);
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    const beforeBlockedCommands = session.snapshot();

    const blockedCommands = [
      ['selectAction', () => session.selectAction('wateringCan')],
      ['selectSeed', () => session.selectSeed('potato')],
      ['buySeeds', () => session.buySeeds('turnip', 1)],
      ['depositCrop', () => session.depositCrop('turnip', 1)],
      ['applySelectedAction', () => session.applySelectedAction(farmCells[0])],
      ['hoe', () => session.hoe(farmCells[0])],
      ['plant', () => session.plant(farmCells[0])],
      ['water', () => session.water(farmCells[0])],
      ['harvest', () => session.harvest(farmCells[0])],
      ['sleep', () => session.sleep()],
    ] as const;

    for (const [name, command] of blockedCommands) {
      expect(command(), name).toEqual({ ok: false, code: 'day-summary-pending' });
      expect(session.snapshot(), name).toEqual(beforeBlockedCommands);
    }

    const beforeBlockedMovement = session.snapshot();
    session.stepMovement({ screenX: -1, screenY: 1 }, 16);
    const afterBlockedMovement = session.snapshot();
    expect(afterBlockedMovement.player).toEqual(beforeBlockedMovement.player);
    expect(afterBlockedMovement.target).toEqual(beforeBlockedMovement.target);
    expect(afterBlockedMovement).toEqual(beforeBlockedMovement);
  });

  test('rejects Day 14 sleep without consuming weather or mutating state', () => {
    let weatherCalls = 0;
    const session = sessionWithConfig({
      nextWeather: () => {
        weatherCalls += 1;
        return 'sunny';
      },
    });

    for (let transition = 0; transition < 13; transition += 1) {
      advanceDayAtBed(session);
    }
    expect(session.snapshot().day).toBe(14);
    expect(session.selectAction('hands')).toEqual({ ok: true, code: 'action-selected' });

    faceBed(session);
    const beforeFinalSleep = session.snapshot();
    expect(session.sleep()).toEqual({ ok: false, code: 'day-limit-reached' });
    expect(session.snapshot()).toEqual(beforeFinalSleep);
    expect(weatherCalls).toBe(13);
  });

  test('does not consume weather for sleep away from the bed', () => {
    let weatherCalls = 0;
    const session = sessionWithConfig({
      nextWeather: () => {
        weatherCalls += 1;
        return 'sunny';
      },
    });
    const before = session.snapshot();

    expect(session.sleep()).toEqual({ ok: false, code: 'not-at-bed' });
    expect(session.snapshot()).toEqual(before);
    expect(weatherCalls).toBe(0);
  });

  test('validates provider weather before mutating a transition', () => {
    const session = sessionWithConfig({
      nextWeather: () => 'stormy' as Weather,
    });
    faceBed(session);
    const before = session.snapshot();

    expect(() => session.sleep()).toThrow('GameSession: nextWeather returned an unsupported value');
    expect(session.snapshot()).toEqual(before);
  });

  describe('restorable state', () => {
    test('round-trips command-driven state without moving the restored world', () => {
      const session = new GameSession(roundTripConfig());

      face(session, 1, 0); // right -> shop {4,7}
      expect(session.buySeeds('potato', 1)).toEqual({ ok: true, code: 'seeds-purchased' });

      for (const cell of roundTripFarmCells.slice(0, 2)) {
        expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
        expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
        expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
      }
      expect(session.hoe(roundTripFarmCells[2])).toEqual({ ok: true, code: 'soil-tilled' });

      for (let night = 0; night < 3; night += 1) {
        face(session, 0, 1); // down -> bed {4,9}
        expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
        expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
        if (night < 2) {
          for (const cell of roundTripFarmCells.slice(0, 2)) {
            expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
          }
        }
      }

      for (const cell of roundTripFarmCells.slice(0, 2)) {
        expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
      }

      face(session, -1, 0); // left -> shipping {2,9}
      expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });

      face(session, 0, -1); // up -> shopkeeper {2,7}
      expect(session.talkTo('shopkeeper').ok).toBe(true);
      expect(session.giftCrop('shopkeeper', 'turnip').ok).toBe(true);
      expect(session.selectAction('hands')).toEqual({ ok: true, code: 'action-selected' });
      expect(session.selectSeed('potato')).toEqual({ ok: true, code: 'seed-selected' });

      const beforeSleepState = session.state();
      const restoredBeforeSleep = new GameSession(
        roundTripConfig({ initialState: structuredClone(beforeSleepState) }),
      );
      expect(withoutWorld(restoredBeforeSleep.snapshot())).toEqual(
        withoutWorld(session.snapshot()),
      );
      expect(restoredBeforeSleep.snapshot().player.position).toEqual({ x: 3.5, y: 8.5 });

      expect(restoredBeforeSleep.selectSeed('potato')).toEqual({ ok: true, code: 'seed-selected' });
      expect(restoredBeforeSleep.plant(roundTripFarmCells[2])).toEqual({
        ok: true,
        code: 'crop-planted',
      });

      face(session, 0, 1);
      expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      const morningState = session.state();
      const restoredMorning = new GameSession(
        roundTripConfig({ initialState: structuredClone(morningState) }),
      );
      expect(withoutWorld(restoredMorning.snapshot())).toEqual(withoutWorld(session.snapshot()));
      expect(restoredMorning.snapshot().pendingDaySummary?.shippingIncome).toBeGreaterThan(0);

      const first = session.state();
      const second = session.state();
      expect(first).toEqual(second);
      expect(first).not.toBe(second);
      first.inventory.seeds.turnip += 999;
      expect(session.state()).toEqual(second);
    });

    test('rejects initial state outside current rules or authored identity', () => {
      const validState = new GameSession(roundTripConfig()).state();
      const invalidCases: Array<[string, (state: GameState) => void]> = [
        ['day below range', (state) => (state.day = 0)],
        ['day above range', (state) => (state.day = MAX_DAY + 1)],
        ['time before day start', (state) => (state.timeMinutes = DAY_START_MINUTES - 1)],
        ['time after cutoff', (state) => (state.timeMinutes = ACTION_CUTOFF_MINUTES + 1)],
        ['negative stamina', (state) => (state.stamina = -1)],
        ['stamina over max', (state) => (state.stamina = MAX_STAMINA + 1)],
        ['negative money', (state) => (state.money = -1)],
        ['negative seed count', (state) => (state.inventory.seeds.turnip = -1)],
        ['negative crop count', (state) => (state.inventory.crops.turnip = -1)],
        ['negative shipment count', (state) => (state.pendingShipment.turnip = -1)],
        ['negative relationship points', (state) => (state.relationships.shopkeeper.points = -1)],
        [
          'closeFriendDialogueSeen below threshold',
          (state) => {
            state.relationships.shopkeeper.closeFriendDialogueSeen = true;
          },
        ],
        [
          'growth past maturity',
          (state) => {
            state.farmTiles[0].soil = 'tilled';
            state.farmTiles[0].crop = {
              kind: 'turnip',
              growth: CROP_DEFINITIONS.turnip.growthDays + 1,
              wateredToday: false,
            };
          },
        ],
        [
          'crop on untilled soil',
          (state) => {
            state.farmTiles[0].soil = 'untilled';
            state.farmTiles[0].crop = { kind: 'turnip', growth: 0, wateredToday: false };
          },
        ],
        [
          'duplicate saved farm coordinate',
          (state) => (state.farmTiles[1].position = { ...state.farmTiles[0].position }),
        ],
        [
          'foreign saved farm coordinate',
          (state) => (state.farmTiles[0].position = { x: 0, y: 0 }),
        ],
        [
          'missing villager relationship',
          (state) => {
            delete (state.relationships as Partial<GameState['relationships']>).shopkeeper;
          },
        ],
      ];

      for (const [name, mutate] of invalidCases) {
        const state = structuredClone(validState);
        mutate(state);
        expect(() => new GameSession(roundTripConfig({ initialState: state })), name).toThrow(
          /^GameSession: invalid initial state/,
        );
      }
    });

    test('rejects pending day summary that contradicts restored state', () => {
      const session = new GameSession(roundTripConfig());
      preparePlanted(session, roundTripFarmCells[0]);
      for (let night = 0; night < CROP_DEFINITIONS.turnip.growthDays; night += 1) {
        expect(session.water(roundTripFarmCells[0])).toEqual({ ok: true, code: 'crop-watered' });
        face(session, 0, 1); // down -> bed {4,9}
        expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
        expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
      }
      expect(session.harvest(roundTripFarmCells[0])).toEqual({ ok: true, code: 'crop-harvested' });
      face(session, -1, 0); // left -> shipping {2,9}
      expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });
      face(session, 0, 1); // down -> bed {4,9}
      expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });

      const baseState = session.state();
      expect(baseState.pendingDaySummary).not.toBeNull();
      expect(baseState.pendingDaySummary!.shipments.length).toBeGreaterThan(0);
      expect(
        () => new GameSession(roundTripConfig({ initialState: structuredClone(baseState) })),
      ).not.toThrow();

      const summaryCases: Array<[string, (state: GameState) => void]> = [
        ['pending completedDay mismatch', (state) => (state.pendingDaySummary!.completedDay += 1)],
        ['pending nextDay mismatch', (state) => (state.pendingDaySummary!.nextDay += 1)],
        [
          'pending restored day still at day 1',
          (state) => {
            state.day = 1;
            state.pendingDaySummary!.completedDay = 0;
            state.pendingDaySummary!.nextDay = 1;
          },
        ],
        [
          'pending nextWeather mismatch',
          (state) => {
            state.pendingDaySummary!.nextWeather = state.weather === 'sunny' ? 'rainy' : 'sunny';
          },
        ],
        [
          'pending moneyAfterShipping mismatch',
          (state) => (state.pendingDaySummary!.moneyAfterShipping += 1),
        ],
        [
          'pending shippingIncome mismatch',
          (state) => (state.pendingDaySummary!.shippingIncome += 1),
        ],
        [
          'pending shipment quantity zero',
          (state) => (state.pendingDaySummary!.shipments[0].quantity = 0),
        ],
        [
          'pending shipment unitValue wrong',
          (state) => (state.pendingDaySummary!.shipments[0].unitValue = 0),
        ],
        [
          'pending shipment lineTotal wrong',
          (state) => (state.pendingDaySummary!.shipments[0].lineTotal = 0),
        ],
        [
          'pending shippingIncome exceeds moneyAfterShipping',
          (state) => {
            state.money = state.pendingDaySummary!.shippingIncome - 1;
            state.pendingDaySummary!.moneyAfterShipping = state.money;
          },
        ],
        [
          'pending staminaRestored negative',
          (state) => (state.pendingDaySummary!.staminaRestored = -1),
        ],
        [
          'pending staminaRestored exceeds max',
          (state) => (state.pendingDaySummary!.staminaRestored = MAX_STAMINA + 1),
        ],
        [
          'pending cropsAdvanced negative',
          (state) => (state.pendingDaySummary!.cropsAdvanced = -1),
        ],
        [
          'pending cropsAdvanced exceeds planted count',
          (state) => {
            let planted = 0;
            for (const tile of state.farmTiles) if (tile.crop) planted += 1;
            state.pendingDaySummary!.cropsAdvanced = planted + 1;
          },
        ],
        [
          'pending duplicate shipment crop',
          (state) => {
            state.pendingDaySummary!.shipments.push({ ...state.pendingDaySummary!.shipments[0] });
          },
        ],
        [
          'pending shipments not an array',
          (state) => {
            (state.pendingDaySummary as unknown as { shipments: unknown }).shipments = {
              crop: 'turnip',
              quantity: 1,
            };
          },
        ],
        [
          'pending shipment crop unknown',
          (state) => {
            state.pendingDaySummary!.shipments[0].crop = 'kale' as CropKind;
          },
        ],
        [
          'pending talkedToday not reset',
          (state) => (state.relationships.shopkeeper.talkedToday = true),
        ],
        [
          'pending giftedToday not reset',
          (state) => (state.relationships.farmer.giftedToday = true),
        ],
        ['pending time not at day start', (state) => (state.timeMinutes = DAY_START_MINUTES + 10)],
        ['pending stamina not at max', (state) => (state.stamina = MAX_STAMINA - 1)],
        ['pending shipment not cleared', (state) => (state.pendingShipment.turnip = 1)],
        [
          'pending crop still watered',
          (state) => {
            state.farmTiles[0].soil = 'tilled';
            state.farmTiles[0].crop = { kind: 'turnip', growth: 0, wateredToday: true };
          },
        ],
      ];

      for (const [name, mutate] of summaryCases) {
        const state = structuredClone(baseState);
        mutate(state);
        expect(() => new GameSession(roundTripConfig({ initialState: state })), name).toThrow(
          /^GameSession: invalid initial state/,
        );
      }
    });
  });

  describe('selected action dispatch', () => {
    test('selects every farming action', () => {
      const session = new GameSession(config());
      const actions: FarmingAction[] = ['hoe', 'seeds', 'wateringCan', 'hands'];

      for (const action of actions) {
        expect(session.selectAction(action)).toEqual({ ok: true, code: 'action-selected' });
        expect(session.snapshot().selectedAction).toBe(action);
      }
    });

    test('delegates each selected action to its matching rule', () => {
      const hoe = new GameSession(config());
      expect(hoe.selectAction('hoe')).toEqual({ ok: true, code: 'action-selected' });
      expect(hoe.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });

      const plant = new GameSession(config());
      expect(plant.hoe(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });
      expect(plant.selectAction('seeds')).toEqual({ ok: true, code: 'action-selected' });
      expect(plant.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'crop-planted' });

      const water = new GameSession(config());
      preparePlanted(water);
      expect(water.selectAction('wateringCan')).toEqual({ ok: true, code: 'action-selected' });
      expect(water.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });

      const harvest = new GameSession(config());
      preparePlanted(harvest);
      growToMaturity(harvest);
      expect(harvest.selectAction('hands')).toEqual({ ok: true, code: 'action-selected' });
      expect(harvest.applySelectedAction(farmCells[0])).toEqual({
        ok: true,
        code: 'crop-harvested',
      });
    });

    test('round-trips a nontrivial snapshot through JSON', () => {
      const session = new GameSession(config());
      preparePlanted(session);
      expect(session.water(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });
      expect(session.selectAction('wateringCan')).toEqual({ ok: true, code: 'action-selected' });
      session.stepMovement({ screenX: 1, screenY: 0 }, 16);
      const snapshot = session.snapshot();

      expect(JSON.parse(JSON.stringify(snapshot))).toEqual(snapshot);
    });
  });

  describe('constructor invariants and ownership', () => {
    test('requires exactly nine farm cells', () => {
      expect(() => new GameSession(config({ farmCells: farmCells.slice(0, 8) }))).toThrow();
      expect(
        () => new GameSession(config({ farmCells: [...farmCells, { x: 5, y: 5 }] })),
      ).toThrow();
    });

    test('rejects duplicate farm cells', () => {
      expect(
        () =>
          new GameSession(
            config({
              farmCells: [...farmCells.slice(0, 8), farmCells[0]],
            }),
          ),
      ).toThrow();
    });

    test('rejects a bed cell that is also a farm cell', () => {
      expect(() => new GameSession(config({ bedCell: farmCells[0] }))).toThrow();
    });

    test('requires distinct in-bounds integer interaction cells', () => {
      expect(() => new GameSession(config({ shopCell: bedCell }))).toThrow();
      expect(() => new GameSession(config({ shippingCell: { x: 12, y: 10 } }))).toThrow();
      expect(() => new GameSession(config({ shippingCell: { x: 4.5, y: 10 } }))).toThrow();
    });

    test('rejects a bed unit rectangle overlapping a footprint', () => {
      expect(() => new GameSession(config({ bedCell: { x: 7, y: 7 } }))).toThrow();
    });

    test('allows a bed rectangle that only touches a footprint edge', () => {
      expect(
        () =>
          new GameSession(
            config({
              world: {
                ...config().world,
                footprints: [{ id: 'edge', x: 5, y: 8, width: 1, height: 1 }],
              },
            }),
          ),
      ).not.toThrow();
    });

    test('clones caller-owned configuration at construction', () => {
      const source = config({
        farmCells: farmCells.map((cell) => ({ ...cell })),
        bedCell: { x: 6, y: 8 },
        shopCell: { ...shopCell },
        shippingCell: { ...shippingCell },
        villagerCells: {
          shopkeeper: { ...villagerCells.shopkeeper },
          farmer: { ...villagerCells.farmer },
          resident: { ...villagerCells.resident },
        },
        world: {
          width: 12,
          height: 12,
          spawn: { x: 5.5, y: 9.5 },
          footprints: [
            { id: 'tree', x: 7, y: 4, width: 1, height: 1 },
            { id: 'building', x: 7, y: 7, width: 3, height: 2 },
          ],
        },
        metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
      });
      const session = new GameSession(source);
      const before = session.snapshot();

      source.farmCells[0].x = 99;
      source.bedCell.x = 99;
      source.shopCell.x = 99;
      source.shippingCell.x = 99;
      source.villagerCells.shopkeeper.x = 99;
      source.world.spawn.x = 99;
      source.world.footprints[0].x = 99;
      source.metrics.origin.x = 99;

      expect(session.snapshot()).toEqual(before);
    });
  });

  describe('social progression', () => {
    test('starts with fresh deep-cloned relationships and villager cells', () => {
      const session = new GameSession(config());
      const first = session.snapshot();
      const second = session.snapshot();

      expect(first.relationships).toEqual({
        shopkeeper: {
          points: 0,
          level: 'stranger',
          talkedToday: false,
          giftedToday: false,
          closeFriendDialogueSeen: false,
        },
        farmer: {
          points: 0,
          level: 'stranger',
          talkedToday: false,
          giftedToday: false,
          closeFriendDialogueSeen: false,
        },
        resident: {
          points: 0,
          level: 'stranger',
          talkedToday: false,
          giftedToday: false,
          closeFriendDialogueSeen: false,
        },
      });
      expect(first.villagerCells).toEqual(villagerCells);
      expect(second.relationships).not.toBe(first.relationships);
      expect(second.relationships.shopkeeper).not.toBe(first.relationships.shopkeeper);
      expect(second.villagerCells).not.toBe(first.villagerCells);
      first.relationships.shopkeeper.points = 99;
      first.villagerCells.shopkeeper.x = 99;
      expect(session.snapshot().relationships.shopkeeper.points).toBe(0);
      expect(session.snapshot().villagerCells.shopkeeper).toEqual(villagerCells.shopkeeper);
    });

    test('rejects social commands away from the requested villager without mutation', () => {
      const session = new GameSession(config());
      const before = session.snapshot();

      expect(session.talkTo('shopkeeper')).toEqual({ ok: false, code: 'not-at-villager' });
      expect(session.giftCrop('shopkeeper', 'turnip')).toEqual({
        ok: false,
        code: 'not-at-villager',
      });
      expect(session.snapshot()).toEqual(before);
    });

    test('talks once per day, then repeats without extra points or costs', () => {
      const session = sessionAtVillager('resident');
      faceVillager(session, 'resident');
      const before = session.snapshot();

      expect(session.talkTo('resident')).toEqual({
        ok: true,
        code: 'villager-talked',
        social: {
          lines: ['It is quieter here than the road makes it look.'],
          pointsGained: 1,
          giftReaction: null,
          closeFriendSequence: false,
        },
      });
      const afterFirstTalk = session.snapshot();
      expect(afterFirstTalk.timeMinutes).toBe(before.timeMinutes);
      expect(afterFirstTalk.stamina).toBe(before.stamina);
      expect(afterFirstTalk.relationships.resident).toMatchObject({
        points: 1,
        level: 'stranger',
        talkedToday: true,
      });

      expect(session.talkTo('resident')).toEqual({
        ok: true,
        code: 'villager-talked',
        social: {
          lines: ['It is quieter here than the road makes it look.'],
          pointsGained: 0,
          giftReaction: null,
          closeFriendSequence: false,
        },
      });
      expect(session.snapshot().relationships.resident.points).toBe(1);
    });

    test('gives one normal crop and one favourite crop, then rejects repeat and no-crop gifts', () => {
      const normal = sessionAtVillager('shopkeeper');
      harvestTurnipAtVillager(normal, 'shopkeeper');
      faceVillager(normal, 'shopkeeper');
      expect(normal.giftCrop('shopkeeper', 'turnip')).toEqual({
        ok: true,
        code: 'crop-gifted',
        social: {
          lines: ['A useful harvest. Thank you.'],
          pointsGained: 3,
          giftReaction: 'normal',
          closeFriendSequence: false,
        },
      });
      expect(normal.snapshot().inventory.crops.turnip).toBe(0);
      const afterGift = normal.snapshot();
      expect(normal.giftCrop('shopkeeper', 'turnip')).toEqual({
        ok: false,
        code: 'gift-already-given',
      });
      expect(normal.snapshot()).toEqual(afterGift);

      const favourite = sessionAtVillager('resident');
      harvestTurnipAtVillager(favourite, 'resident');
      faceVillager(favourite, 'resident');
      expect(favourite.giftCrop('resident', 'turnip')).toEqual({
        ok: true,
        code: 'crop-gifted',
        social: {
          lines: ['Turnips are my favourite. Perfect choice.'],
          pointsGained: 5,
          giftReaction: 'favourite',
          closeFriendSequence: false,
        },
      });

      const noCrop = sessionAtVillager('resident');
      faceVillager(noCrop, 'resident');
      expect(noCrop.giftCrop('resident', 'turnip')).toEqual({
        ok: false,
        code: 'insufficient-crops',
      });
    });

    test('reaches Friend at 12 and Close Friend at 18 with the one-time sequence', () => {
      const session = sessionAtVillager('resident');
      harvestThreeTurnipsAtVillager(session, 'resident');

      for (let day = 0; day < 2; day += 1) {
        faceVillager(session, 'resident');
        expect(session.talkTo('resident').ok).toBe(true);
        expect(session.giftCrop('resident', 'turnip').ok).toBe(true);
        expect(session.snapshot().relationships.resident.points).toBe((day + 1) * 6);
        if (day === 1) expect(session.snapshot().relationships.resident.level).toBe('friend');
        faceSocialBed(session, 'resident');
        expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
        expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
      }

      faceVillager(session, 'resident');
      expect(session.talkTo('resident')).toEqual({
        ok: true,
        code: 'villager-talked',
        social: {
          lines: ['I keep seeing you around. I like that.'],
          pointsGained: 1,
          giftReaction: null,
          closeFriendSequence: false,
        },
      });
      expect(session.giftCrop('resident', 'turnip')).toEqual({
        ok: true,
        code: 'crop-gifted',
        social: {
          lines: ['Turnips are my favourite. Perfect choice.'],
          pointsGained: 5,
          giftReaction: 'favourite',
          closeFriendSequence: false,
        },
      });
      expect(session.snapshot().relationships.resident).toMatchObject({
        points: 18,
        level: 'closeFriend',
        closeFriendDialogueSeen: false,
      });

      expect(session.talkTo('resident')).toEqual({
        ok: true,
        code: 'villager-talked',
        social: {
          lines: [
            'You came here as the new farmer, but that is not how I think of you now.',
            'You are one of us.',
          ],
          pointsGained: 0,
          giftReaction: null,
          closeFriendSequence: true,
        },
      });
      expect(session.snapshot().relationships.resident.closeFriendDialogueSeen).toBe(true);
      expect(session.talkTo('resident')).toEqual({
        ok: true,
        code: 'villager-talked',
        social: {
          lines: ['The village feels more like home with you here.'],
          pointsGained: 0,
          giftReaction: null,
          closeFriendSequence: false,
        },
      });
    });

    test('resets daily social flags only after successful sleep', () => {
      const failed = sessionAtVillager('shopkeeper');
      harvestTurnipAtVillager(failed, 'shopkeeper');
      faceVillager(failed, 'shopkeeper');
      expect(failed.talkTo('shopkeeper').ok).toBe(true);
      expect(failed.giftCrop('shopkeeper', 'turnip').ok).toBe(true);
      expect(failed.sleep()).toEqual({ ok: false, code: 'not-at-bed' });
      expect(failed.snapshot().relationships.shopkeeper).toMatchObject({
        talkedToday: true,
        giftedToday: true,
      });

      faceSocialBed(failed, 'shopkeeper');
      expect(failed.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      expect(failed.snapshot().relationships.shopkeeper).toMatchObject({
        points: 4,
        talkedToday: false,
        giftedToday: false,
      });
    });

    test('does not reset social flags for Day 14 rejection or summary-pending sleep', () => {
      const finalDay = sessionAtVillager('resident');
      for (let transition = 0; transition < 13; transition += 1) {
        faceSocialBed(finalDay, 'resident');
        expect(finalDay.sleep()).toEqual({ ok: true, code: 'day-advanced' });
        expect(finalDay.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
      }
      faceVillager(finalDay, 'resident');
      expect(finalDay.talkTo('resident').ok).toBe(true);
      faceSocialBed(finalDay, 'resident');
      const beforeDayLimit = finalDay.snapshot();
      expect(finalDay.sleep()).toEqual({ ok: false, code: 'day-limit-reached' });
      expect(finalDay.snapshot()).toEqual(beforeDayLimit);

      const pending = sessionAtVillager('resident');
      faceVillager(pending, 'resident');
      expect(pending.talkTo('resident').ok).toBe(true);
      faceSocialBed(pending, 'resident');
      expect(pending.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      const beforeDuplicate = pending.snapshot();
      expect(pending.sleep()).toEqual({ ok: false, code: 'day-summary-pending' });
      expect(pending.snapshot()).toEqual(beforeDuplicate);
    });

    test('blocks talk and gift while a morning summary is pending', () => {
      const session = sessionAtVillager('resident');
      faceSocialBed(session, 'resident');
      expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      const before = session.snapshot();

      expect(session.talkTo('resident')).toEqual({
        ok: false,
        code: 'day-summary-pending',
      });
      expect(session.giftCrop('resident', 'turnip')).toEqual({
        ok: false,
        code: 'day-summary-pending',
      });
      expect(session.snapshot()).toMatchObject(before);
    });

    test('requires distinct in-bounds integer villager cells away from farm interactions', () => {
      expect(
        () =>
          new GameSession(config({ villagerCells: { ...villagerCells, farmer: { x: 12, y: 5 } } })),
      ).toThrow();
      expect(
        () =>
          new GameSession(
            config({ villagerCells: { ...villagerCells, farmer: { x: 3.5, y: 5 } } }),
          ),
      ).toThrow();
      expect(
        () =>
          new GameSession(
            config({
              villagerCells: { ...villagerCells, farmer: { ...villagerCells.shopkeeper } },
            }),
          ),
      ).toThrow();
      expect(
        () =>
          new GameSession(
            config({ villagerCells: { ...villagerCells, farmer: { ...farmCells[0] } } }),
          ),
      ).toThrow();
      expect(
        () =>
          new GameSession(config({ villagerCells: { ...villagerCells, farmer: { ...bedCell } } })),
      ).toThrow();
      expect(
        () =>
          new GameSession(config({ villagerCells: { ...villagerCells, farmer: { ...shopCell } } })),
      ).toThrow();
      expect(
        () =>
          new GameSession(
            config({ villagerCells: { ...villagerCells, farmer: { ...shippingCell } } }),
          ),
      ).toThrow();
    });

    test('round-trips social state through JSON', () => {
      const session = sessionAtVillager('resident');
      faceVillager(session, 'resident');
      expect(session.talkTo('resident').ok).toBe(true);
      const snapshot = session.snapshot();

      expect(JSON.parse(JSON.stringify(snapshot))).toEqual(snapshot);
    });
  });
});
