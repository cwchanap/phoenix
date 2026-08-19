import { describe, expect, mock, test } from 'bun:test';
import type { GameState } from '../../src/game/core/types';
import { createSaveFile, type SaveFileV1 } from '../../src/persistence/saveFile';
import { persistOvernightSave } from '../../src/persistence/persistOvernightSave';
import type { SaveRepository } from '../../src/persistence/saveRepository';

const state = {
  day: 2,
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
} satisfies GameState;

describe('persistOvernightSave', () => {
  test('saves a day-advanced result exactly once', async () => {
    const save = mock<(file: SaveFileV1) => Promise<void>>(() => Promise.resolve());
    const repository = { load: async () => null, save } satisfies SaveRepository;
    const wrote = await persistOvernightSave({
      result: { ok: true, code: 'day-advanced' },
      state,
      repository,
    });

    expect(wrote).toBe(true);
    expect(save).toHaveBeenCalledTimes(1);
    expect(save.mock.calls[0][0]).toEqual(createSaveFile(state));
  });

  test('skips failures and non-day-advanced successes', async () => {
    const save = mock<(file: SaveFileV1) => Promise<void>>(() => Promise.resolve());
    const repository = { load: async () => null, save } satisfies SaveRepository;

    for (const result of [
      { ok: false, code: 'not-at-bed' } as const,
      { ok: true, code: 'action-selected' } as const,
    ]) {
      expect(await persistOvernightSave({ result, state, repository })).toBe(false);
    }
    expect(save).not.toHaveBeenCalled();
  });

  test('rejects a day-advanced result without save storage', async () => {
    await expect(
      persistOvernightSave({
        result: { ok: true, code: 'day-advanced' },
        state,
        repository: null,
      }),
    ).rejects.toThrow('Save storage is unavailable');
  });

  test('propagates a repository rejection', async () => {
    const error = new Error('storage failed');
    const save = mock<(file: SaveFileV1) => Promise<void>>(() => Promise.reject(error));
    const repository = { load: async () => null, save } satisfies SaveRepository;

    await expect(
      persistOvernightSave({
        result: { ok: true, code: 'day-advanced' },
        state,
        repository,
      }),
    ).rejects.toThrow(error);
    expect(save).toHaveBeenCalledTimes(1);
  });
});
