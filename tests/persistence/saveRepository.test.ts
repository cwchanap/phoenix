import { describe, expect, test } from 'bun:test';
import {
  LocalStorageSaveRepository,
  TauriStoreSaveRepository,
  createSaveRepository,
  type SaveRepositoryEnvironment,
  type TauriStoreLike,
} from '../../src/persistence/saveRepository';
import type { SaveFileV1 } from '../../src/persistence/saveFile';

const file = { schemaVersion: 1, state: { day: 1 } } as SaveFileV1;

class MemoryStorage implements Storage {
  private readonly values = new Map<string, string>();

  get length(): number {
    return this.values.size;
  }

  clear(): void {
    this.values.clear();
  }

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }

  key(index: number): string | null {
    return [...this.values.keys()][index] ?? null;
  }

  removeItem(key: string): void {
    this.values.delete(key);
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }
}

class MemoryStore implements TauriStoreLike {
  readonly values = new Map<string, unknown>();
  setCalls = 0;
  saveCalls = 0;

  async get<T>(key: string): Promise<T | null> {
    return (this.values.get(key) as T | undefined) ?? null;
  }

  async set(key: string, value: unknown): Promise<void> {
    this.setCalls += 1;
    this.values.set(key, value);
  }

  async save(): Promise<void> {
    this.saveCalls += 1;
  }
}

function environment(
  overrides: Partial<SaveRepositoryEnvironment> = {},
): SaveRepositoryEnvironment {
  return {
    storage: new MemoryStorage(),
    loadTauriStore: async () => new MemoryStore(),
    ...overrides,
  };
}

describe('LocalStorageSaveRepository', () => {
  test('loads and saves the Phoenix save slot', async () => {
    const storage = new MemoryStorage();
    const repository = new LocalStorageSaveRepository(storage);

    expect(await repository.load()).toBeNull();
    await repository.save(file);
    expect(storage.getItem('phoenix.save.v1')).toBe(JSON.stringify(file));
    expect(await repository.load()).toEqual(file);
  });

  test('propagates malformed JSON', async () => {
    const storage = new MemoryStorage();
    storage.setItem('phoenix.save.v1', '{malformed');

    await expect(new LocalStorageSaveRepository(storage).load()).rejects.toThrow();
  });

  test('propagates storage exceptions', async () => {
    const error = new Error('storage unavailable');
    const storage = {
      getItem: () => {
        throw error;
      },
      setItem: () => {
        throw error;
      },
    } as unknown as Storage;
    const repository = new LocalStorageSaveRepository(storage);

    await expect(repository.load()).rejects.toThrow(error);
    await expect(repository.save(file)).rejects.toThrow(error);
  });
});

describe('createSaveRepository', () => {
  test('uses localStorage when the Tauri platform is missing', async () => {
    let loadCalls = 0;
    const repository = await createSaveRepository(
      environment({
        loadTauriStore: async () => {
          loadCalls += 1;
          return new MemoryStore();
        },
      }),
    );

    expect(repository).toBeInstanceOf(LocalStorageSaveRepository);
    expect(loadCalls).toBe(0);
  });

  test('loads the Tauri Store when a platform is present', async () => {
    let loadCalls = 0;
    const store = new MemoryStore();
    const repository = await createSaveRepository(
      environment({
        tauriPlatform: 'darwin',
        loadTauriStore: async () => {
          loadCalls += 1;
          return store;
        },
      }),
    );

    expect(repository).toBeInstanceOf(TauriStoreSaveRepository);
    expect(loadCalls).toBe(1);
  });

  test('propagates Tauri Store initialization failures without localStorage fallback', async () => {
    const error = new Error('store unavailable');

    await expect(
      createSaveRepository(
        environment({
          tauriPlatform: 'darwin',
          loadTauriStore: async () => {
            throw error;
          },
        }),
      ),
    ).rejects.toThrow(error);
  });

  test('saves a Tauri file once and flushes it once', async () => {
    const store = new MemoryStore();
    const repository = await createSaveRepository(
      environment({
        tauriPlatform: 'darwin',
        loadTauriStore: async () => store,
      }),
    );

    await repository.save(file);

    expect(store.values.get('save')).toEqual(file);
    expect(store.setCalls).toBe(1);
    expect(store.saveCalls).toBe(1);
  });

  test('returns null when the Tauri save slot is missing', async () => {
    const repository = new TauriStoreSaveRepository(new MemoryStore());

    expect(await repository.load()).toBeNull();
  });
});
