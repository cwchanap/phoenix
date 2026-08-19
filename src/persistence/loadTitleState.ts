import type { SaveFileV1 } from './saveFile';
import { parseSaveFile } from './saveFile';
import { createSaveRepository, type SaveRepository } from './saveRepository';

export interface TitleLoadState {
  repository: SaveRepository | null;
  save: SaveFileV1 | null;
  error: string | null;
}

export async function loadTitleState(
  createRepository: () => Promise<SaveRepository> = createSaveRepository,
): Promise<TitleLoadState> {
  try {
    const repository = await createRepository();
    try {
      const value = await repository.load();
      if (value === null) return { repository, save: null, error: null };
      return { repository, save: parseSaveFile(value), error: null };
    } catch (error) {
      return { repository, save: null, error: errorMessage(error) };
    }
  } catch (error) {
    return { repository: null, save: null, error: errorMessage(error) };
  }
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
