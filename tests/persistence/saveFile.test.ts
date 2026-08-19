import { describe, expect, test } from 'bun:test';
import { GameSession, type GameSessionConfig } from '../../src/game/core/GameSession';
import { createSaveFile, parseSaveFile, type SaveFileV1 } from '../../src/persistence/saveFile';
import type { GameState } from '../../src/game/core/types';

const farmCells = [
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

function config(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 3.5, y: 8.5 },
      footprints: [],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells,
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

function validState(): GameState {
  return new GameSession(config()).state();
}

function validFile(): SaveFileV1 {
  return createSaveFile(validState());
}

function withSummary(state: GameState): void {
  state.pendingDaySummary = {
    completedDay: 1,
    nextDay: 2,
    cropsAdvanced: 1,
    nextWeather: 'rainy',
    staminaRestored: 3,
    shipments: [{ crop: 'turnip', quantity: 1, unitValue: 35, lineTotal: 35 }],
    shippingIncome: 35,
    moneyAfterShipping: 185,
  };
}

function deleteField(value: unknown, field: string): void {
  delete (value as Record<string, unknown>)[field];
}

describe('save file V1', () => {
  test('creates and parses the structural envelope', () => {
    const state = validState();
    const file = createSaveFile(state);

    expect(file).toEqual({ schemaVersion: 1, state });
    expect(parseSaveFile(structuredClone(file))).toEqual(file);
  });

  test('parses populated crops and pending-day-summary data', () => {
    const state = validState();
    state.farmTiles[0].crop = { kind: 'turnip', growth: 2, wateredToday: true };
    withSummary(state);
    const file = createSaveFile(state);

    expect(parseSaveFile(file)).toEqual(file);
  });

  test('does not alias source state when creating a save file', () => {
    const state = validState();
    const file = createSaveFile(state);
    const saved = structuredClone(file);

    state.inventory.seeds.turnip += 1;
    state.farmTiles[0].position.x = 11;
    state.relationships.shopkeeper.points = 4;

    expect(file).toEqual(saved);
  });

  test('returns a fresh deep clone when parsing', () => {
    const input = validFile();
    const parsed = parseSaveFile(input);

    expect(parsed).toEqual(input);
    expect(parsed).not.toBe(input);
    expect(parsed.state).not.toBe(input.state);
    expect(parsed.state.inventory).not.toBe(input.state.inventory);

    parsed.state.inventory.crops.turnip = 12;
    expect(input.state.inventory.crops.turnip).toBe(0);
  });

  test.each([
    ['null', null],
    ['array', []],
    ['string', 'save'],
  ])('rejects non-object top level %s', (_name, value) => {
    expect(() => parseSaveFile(value)).toThrow('Invalid save: save must be an object');
  });

  test('rejects a missing schema version', () => {
    const file = validFile();
    deleteField(file, 'schemaVersion');

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save: schemaVersion/);
  });

  test.each([
    ['wrong number', 2],
    ['wrong type', '1'],
  ])('rejects %s schema version', (_name, value) => {
    const file = validFile();
    file.schemaVersion = value as 1;

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save: schemaVersion/);
  });

  test.each([
    'day',
    'timeMinutes',
    'stamina',
    'weather',
    'pendingDaySummary',
    'selectedAction',
    'selectedSeed',
    'money',
    'inventory',
    'pendingShipment',
    'farmTiles',
    'relationships',
  ])('rejects missing current state field %s', (field) => {
    const file = validFile();
    deleteField(file.state, field);

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
  });

  test.each([
    ['weather', (state: GameState) => (state.weather = 'stormy' as GameState['weather'])],
    [
      'action',
      (state: GameState) => (state.selectedAction = 'plant' as GameState['selectedAction']),
    ],
    ['seed', (state: GameState) => (state.selectedSeed = 'carrot' as GameState['selectedSeed'])],
    [
      'crop ID',
      (state: GameState) => {
        state.farmTiles[0].crop = {
          kind: 'carrot' as GameState['selectedSeed'],
          growth: 0,
          wateredToday: false,
        };
      },
    ],
    [
      'villager ID',
      (state: GameState) => {
        (state.relationships as Record<string, unknown>).stranger = {
          points: 0,
          talkedToday: false,
          giftedToday: false,
          closeFriendDialogueSeen: false,
        };
      },
    ],
  ] as Array<[string, (state: GameState) => void]>)('rejects invalid %s', (_name, mutate) => {
    const file = validFile();
    mutate(file.state);

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
  });

  test.each([
    ['day', (state: GameState) => (state.day = Number.MAX_SAFE_INTEGER + 1)],
    ['time', (state: GameState) => (state.timeMinutes = Number.MAX_SAFE_INTEGER + 1)],
    ['stamina', (state: GameState) => (state.stamina = Number.MAX_SAFE_INTEGER + 1)],
    ['money', (state: GameState) => (state.money = Number.MAX_SAFE_INTEGER + 1)],
    ['count', (state: GameState) => (state.inventory.seeds.turnip = Number.MAX_SAFE_INTEGER + 1)],
    [
      'position',
      (state: GameState) => (state.farmTiles[0].position.x = Number.MAX_SAFE_INTEGER + 1),
    ],
    [
      'relationship points',
      (state: GameState) => (state.relationships.shopkeeper.points = Number.MAX_SAFE_INTEGER + 1),
    ],
  ] as Array<[string, (state: GameState) => void]>)(
    'rejects non-safe-integer %s fields',
    (_name, mutate) => {
      const file = validFile();
      mutate(file.state);

      expect(() => parseSaveFile(file)).toThrow(/must be a safe integer/);
    },
  );

  test.each([
    ['missing seed count', (state: GameState) => deleteField(state.inventory.seeds, 'potato')],
    ['missing crop count', (state: GameState) => deleteField(state.inventory.crops, 'pumpkin')],
    ['seed count record', (state: GameState) => (state.inventory.seeds = null as never)],
    ['crop count record', (state: GameState) => (state.inventory.crops = [] as never)],
    ['shipment count record', (state: GameState) => (state.pendingShipment = null as never)],
    [
      'unknown count crop ID',
      (state: GameState) => {
        (state.inventory.seeds as Record<string, unknown>).carrot = 1;
      },
    ],
  ] as Array<[string, (state: GameState) => void]>)('rejects malformed %s', (_name, mutate) => {
    const file = validFile();
    mutate(file.state);

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
  });

  test.each([
    ['farm tile array', (state: GameState) => (state.farmTiles = null as never)],
    ['farm tile object', (state: GameState) => (state.farmTiles[0] = null as never)],
    ['farm position', (state: GameState) => (state.farmTiles[0].position = null as never)],
    ['farm soil', (state: GameState) => (state.farmTiles[0].soil = 'mud' as never)],
    ['crop object', (state: GameState) => (state.farmTiles[0].crop = [] as never)],
    [
      'crop growth',
      (state: GameState) => {
        state.farmTiles[0].crop = { kind: 'turnip', growth: 'new' as never, wateredToday: false };
      },
    ],
    [
      'crop wateredToday',
      (state: GameState) => {
        state.farmTiles[0].crop = { kind: 'turnip', growth: 0, wateredToday: 1 as never };
      },
    ],
  ] as Array<[string, (state: GameState) => void]>)(
    'rejects malformed %s shape',
    (_name, mutate) => {
      const file = validFile();
      mutate(file.state);

      expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
    },
  );

  test.each([
    ['relationships record', (state: GameState) => (state.relationships = null as never)],
    ['relationship object', (state: GameState) => (state.relationships.shopkeeper = null as never)],
    [
      'relationship points',
      (state: GameState) => {
        deleteField(state.relationships.shopkeeper, 'points');
      },
    ],
    [
      'relationship boolean',
      (state: GameState) => {
        state.relationships.farmer.talkedToday = 'yes' as never;
      },
    ],
  ] as Array<[string, (state: GameState) => void]>)('rejects malformed %s', (_name, mutate) => {
    const file = validFile();
    mutate(file.state);

    expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
  });

  test.each([
    ['summary object', (state: GameState) => (state.pendingDaySummary = [] as never)],
    [
      'summary shipment array',
      (state: GameState) => {
        withSummary(state);
        state.pendingDaySummary!.shipments = null as never;
      },
    ],
    [
      'summary shipment line',
      (state: GameState) => {
        withSummary(state);
        state.pendingDaySummary!.shipments[0] = null as never;
      },
    ],
    [
      'summary shipment crop',
      (state: GameState) => {
        withSummary(state);
        state.pendingDaySummary!.shipments[0].crop = 'carrot' as never;
      },
    ],
    [
      'summary shipment quantity',
      (state: GameState) => {
        withSummary(state);
        state.pendingDaySummary!.shipments[0].quantity = 'one' as never;
      },
    ],
  ] as Array<[string, (state: GameState) => void]>)(
    'rejects malformed pending-day-summary %s',
    (_name, mutate) => {
      const file = validFile();
      mutate(file.state);

      expect(() => parseSaveFile(file)).toThrow(/^Invalid save:/);
    },
  );

  test('accepts structurally valid but impossible current state', () => {
    const file = validFile();
    file.state.day = 999;
    file.state.stamina = 500;
    file.state.inventory.seeds.turnip = -1;
    file.state.farmTiles[0].position = { x: 11, y: 11 };

    expect(() => parseSaveFile(file)).not.toThrow();
  });
});
