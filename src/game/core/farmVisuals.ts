import type { FarmTileSnapshot, GrowthLevel } from './types';

export interface FarmVisualFrames {
  soilFrame: 0 | 1 | null;
  cropFrame: GrowthLevel | null;
}

export function farmVisuals(tile: FarmTileSnapshot): FarmVisualFrames {
  return {
    soilFrame: tile.soil === 'untilled' ? null : tile.crop?.wateredToday ? 1 : 0,
    cropFrame: tile.crop?.growth ?? null,
  };
}

export function farmStableOrder(rowMajorIndex: number): number {
  return 100 + rowMajorIndex;
}
