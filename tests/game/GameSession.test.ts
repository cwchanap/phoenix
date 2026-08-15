import { describe, expect, test } from 'bun:test';
import { GameSession, type GameSessionConfig } from '../../src/game/core/GameSession';
import type { FarmingAction, GridCell } from '../../src/game/core/types';

const farmCells = [
  { x: 2, y: 7 }, { x: 3, y: 7 }, { x: 4, y: 7 },
  { x: 2, y: 8 }, { x: 3, y: 8 }, { x: 4, y: 8 },
  { x: 2, y: 9 }, { x: 3, y: 9 }, { x: 4, y: 9 },
];

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
    bedCell: { x: 6, y: 8 },
    ...overrides,
  };
}

function sessionWithConfig(overrides: Partial<GameSessionConfig> = {}): GameSession {
  return new GameSession(config(overrides));
}

function faceBed(session: GameSession): void {
  session.stepMovement({ screenX: 1, screenY: 0 }, 0);
}

function preparePlanted(session: GameSession, cell: GridCell = farmCells[0]): void {
  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'turnip-planted' });
}

function sleepAtBed(session: GameSession): void {
  faceBed(session);
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
}

function growToMaturity(session: GameSession, cell: GridCell = farmCells[0]): void {
  for (let growth = 0; growth < 3; growth += 1) {
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    sleepAtBed(session);
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
    expect(first.inventory).toEqual({ turnipSeeds: 3, turnips: 0 });
    expect(first.farmTiles.map((tile) => tile.position)).toEqual(farmCells);
    expect(first.farmTiles.every((tile) => tile.soil === 'untilled' && tile.crop === null)).toBe(true);
    expect(first.bedCell).toEqual({ x: 6, y: 8 });
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

    expect(session.plant(farmCells[0])).toEqual({ ok: true, code: 'turnip-planted' });

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

    expect(session.harvest(farmCells[0])).toEqual({ ok: true, code: 'turnip-harvested' });

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

  test('resets time and stamina after the current direct sleep transition', () => {
    const session = new GameSession(config());
    expect(session.hoe(farmCells[0])).toEqual({ ok: true, code: 'soil-tilled' });
    faceBed(session);

    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
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
    expect(session.plant(cell)).toEqual({ ok: true, code: 'turnip-planted' });
    expect(session.snapshot().inventory.turnipSeeds).toBe(2);

    for (const growth of [1, 2, 3] as const) {
      expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
      session.stepMovement({ screenX: 1, screenY: 0 }, 0);
      expect(session.snapshot().target).toEqual({ x: 6, y: 8 });
      expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
      expect(session.snapshot().farmTiles[0].crop).toEqual({
        kind: 'turnip',
        growth,
        wateredToday: false,
      });
    }

    expect(session.snapshot().day).toBe(4);
    expect(session.harvest(cell)).toEqual({ ok: true, code: 'turnip-harvested' });
    expect(session.snapshot().farmTiles[0]).toEqual({
      position: cell,
      soil: 'tilled',
      crop: null,
    });
    expect(session.snapshot().inventory).toEqual({ turnipSeeds: 2, turnips: 1 });
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

        expect(command(session, { x: 99, y: 99 }), name).toEqual({ ok: false, code: 'not-farm-cell' });
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
      expect(noSeeds.plant(noSeedsCell)).toEqual({ ok: false, code: 'no-turnip-seeds' });
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

    sleepAtBed(session);
    expect(session.snapshot().day).toBe(2);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip', growth: 1, wateredToday: false,
    });
    expect(session.snapshot().farmTiles[1].crop).toEqual({
      kind: 'turnip', growth: 0, wateredToday: false,
    });

    expect(session.water(watered)).toEqual({ ok: true, code: 'crop-watered' });
    sleepAtBed(session);
    expect(session.snapshot().farmTiles[0].crop?.growth).toBe(2);

    expect(session.water(watered)).toEqual({ ok: true, code: 'crop-watered' });
    sleepAtBed(session);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip', growth: 3, wateredToday: false,
    });
    expect(session.snapshot().day).toBe(4);

    const beforeUnwateredSleep = session.snapshot();
    sleepAtBed(session);
    expect(session.snapshot().day).toBe(5);
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip', growth: 3, wateredToday: false,
    });
    expect(session.snapshot().farmTiles[1].crop).toEqual(beforeUnwateredSleep.farmTiles[1].crop);
  });

  describe('selected action dispatch', () => {
    test('selects every farming action', () => {
      const session = new GameSession(config());
      const actions: FarmingAction[] = ['hoe', 'turnipSeeds', 'wateringCan', 'hands'];

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
      expect(plant.selectAction('turnipSeeds')).toEqual({ ok: true, code: 'action-selected' });
      expect(plant.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'turnip-planted' });

      const water = new GameSession(config());
      preparePlanted(water);
      expect(water.selectAction('wateringCan')).toEqual({ ok: true, code: 'action-selected' });
      expect(water.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'crop-watered' });

      const harvest = new GameSession(config());
      preparePlanted(harvest);
      growToMaturity(harvest);
      expect(harvest.selectAction('hands')).toEqual({ ok: true, code: 'action-selected' });
      expect(harvest.applySelectedAction(farmCells[0])).toEqual({ ok: true, code: 'turnip-harvested' });
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
      expect(() => new GameSession(config({ farmCells: [...farmCells, { x: 5, y: 5 }] }))).toThrow();
    });

    test('rejects duplicate farm cells', () => {
      expect(() => new GameSession(config({
        farmCells: [...farmCells.slice(0, 8), farmCells[0]],
      }))).toThrow();
    });

    test('rejects a bed cell that is also a farm cell', () => {
      expect(() => new GameSession(config({ bedCell: farmCells[0] }))).toThrow();
    });

    test('rejects a bed unit rectangle overlapping a footprint', () => {
      expect(() => new GameSession(config({ bedCell: { x: 7, y: 7 } }))).toThrow();
    });

    test('allows a bed rectangle that only touches a footprint edge', () => {
      expect(() => new GameSession(config({
        world: {
          ...config().world,
          footprints: [{ id: 'edge', x: 5, y: 8, width: 1, height: 1 }],
        },
      }))).not.toThrow();
    });

    test('clones caller-owned configuration at construction', () => {
      const source = config({
        farmCells: farmCells.map((cell) => ({ ...cell })),
        bedCell: { x: 6, y: 8 },
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
      source.world.spawn.x = 99;
      source.world.footprints[0].x = 99;
      source.metrics.origin.x = 99;

      expect(session.snapshot()).toEqual(before);
    });
  });
});
