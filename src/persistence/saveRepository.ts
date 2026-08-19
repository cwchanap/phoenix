import type { SaveFileV1 } from './saveFile';

const LOCAL_STORAGE_KEY = 'phoenix.save.v1';
const TAURI_SAVE_KEY = 'save';

export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}

export interface TauriStoreLike {
  get<T>(key: string): Promise<T | null | undefined>;
  set(key: string, value: unknown): Promise<void>;
  save(): Promise<void>;
}

export interface SaveRepositoryEnvironment {
  tauriPlatform?: string;
  storage: Storage;
  loadTauriStore: () => Promise<TauriStoreLike>;
}

export class LocalStorageSaveRepository implements SaveRepository {
  constructor(private readonly storage: Storage) {}

  async load(): Promise<unknown | null> {
    const value = this.storage.getItem(LOCAL_STORAGE_KEY);
    return value === null ? null : JSON.parse(value);
  }

  async save(file: SaveFileV1): Promise<void> {
    this.storage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(file));
  }
}

export class TauriStoreSaveRepository implements SaveRepository {
  constructor(private readonly store: TauriStoreLike) {}

  async load(): Promise<unknown | null> {
    return (await this.store.get<unknown>(TAURI_SAVE_KEY)) ?? null;
  }

  async save(file: SaveFileV1): Promise<void> {
    await this.store.set(TAURI_SAVE_KEY, file);
    await this.store.save();
  }
}

export async function createSaveRepository(
  environment?: SaveRepositoryEnvironment,
): Promise<SaveRepository> {
  const tauriPlatform = environment?.tauriPlatform ?? import.meta.env.TAURI_ENV_PLATFORM;
  if (!tauriPlatform) {
    return new LocalStorageSaveRepository(environment?.storage ?? window.localStorage);
  }

  if (environment?.loadTauriStore) {
    return new TauriStoreSaveRepository(await environment.loadTauriStore());
  }

  const { load } = await import('@tauri-apps/plugin-store');
  const store = await load('phoenix-save.json', {
    defaults: {},
    autoSave: false,
  });
  return new TauriStoreSaveRepository(store);
}
