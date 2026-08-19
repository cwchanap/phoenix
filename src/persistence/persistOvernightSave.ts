import type { CommandResult, GameState } from '../game/core/types';
import { createSaveFile } from './saveFile';
import type { SaveRepository } from './saveRepository';

export async function persistOvernightSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<boolean> {
  if (!input.result.ok || input.result.code !== 'day-advanced') return false;
  if (!input.repository) throw new Error('Save storage is unavailable');
  await input.repository.save(createSaveFile(input.state));
  return true;
}
