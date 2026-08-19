import { describe, expect, test } from 'bun:test';
import { loadTitleState } from '../../src/persistence/loadTitleState';
import type { GameState } from '../../src/game/core/types';
import type { SaveFileV1 } from '../../src/persistence/saveFile';
import type { SaveRepository } from '../../src/persistence/saveRepository';

const validSave: SaveFileV1 = {
  schemaVersion: 1,
  state: {
    day: 1,
    timeMinutes: 360,
    stamina: 100,
    weather: 'sunny',
    pendingDaySummary: null,
    selectedAction: 'hoe',
    selectedSeed: 'turnip',
    money: 150,
    inventory: {
      seeds: { turnip: 3, potato: 0, pumpkin: 0 },
      crops: { turnip: 0, potato: 0, pumpkin: 0 },
    },
    pendingShipment: { turnip: 0, potato: 0, pumpkin: 0 },
    farmTiles: [],
    relationships: {
      shopkeeper: {
        points: 0,
        talkedToday: false,
        giftedToday: false,
        closeFriendDialogueSeen: false,
      },
      farmer: { points: 0, talkedToday: false, giftedToday: false, closeFriendDialogueSeen: false },
      resident: {
        points: 0,
        talkedToday: false,
        giftedToday: false,
        closeFriendDialogueSeen: false,
      },
    },
  } satisfies GameState,
};

function repository(load: () => Promise<unknown | null>): SaveRepository {
  return { load, save: async () => {} };
}

describe('loadTitleState', () => {
  test('repository factory rejects -> repository null, save null, error present', async () => {
    const result = await loadTitleState(async () => {
      throw new Error('repository unavailable');
    });

    expect(result).toEqual({
      repository: null,
      save: null,
      error: 'repository unavailable',
    });
  });

  test('repository loads null -> repository retained, save null, error null', async () => {
    const saveRepository = repository(async () => null);

    const result = await loadTitleState(async () => saveRepository);

    expect(result).toEqual({ repository: saveRepository, save: null, error: null });
  });

  test('repository load rejects -> repository retained, save null, error present', async () => {
    const saveRepository = repository(async () => {
      throw new Error('load failed');
    });

    const result = await loadTitleState(async () => saveRepository);

    expect(result).toEqual({
      repository: saveRepository,
      save: null,
      error: 'load failed',
    });
  });

  test('repository returns malformed/unsupported save -> repository retained, save null, Invalid save error', async () => {
    const saveRepository = repository(async () => ({ schemaVersion: 2 }));

    const result = await loadTitleState(async () => saveRepository);

    expect(result.repository).toBe(saveRepository);
    expect(result.save).toBeNull();
    expect(result.error).toMatch(/^Invalid save/);
  });

  test('repository returns valid V1 -> repository retained, parsed save returned, error null', async () => {
    const saveRepository = repository(async () => structuredClone(validSave));

    const result = await loadTitleState(async () => saveRepository);

    expect(result.repository).toBe(saveRepository);
    expect(result.save).toEqual(validSave);
    expect(result.save).not.toBe(validSave);
    expect(result.error).toBeNull();
  });
});
