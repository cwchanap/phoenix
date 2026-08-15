import type { FarmTileSnapshot, GrowthLevel, Weather } from './types';

export interface FarmVisualFrames {
  soilFrame: 0 | 1 | null;
  cropFrame: GrowthLevel | null;
}

export function farmVisuals(tile: FarmTileSnapshot, weather: Weather): FarmVisualFrames {
  const wet = weather === 'rainy' || tile.crop?.wateredToday === true;
  return {
    soilFrame: tile.soil === 'untilled' ? null : wet ? 1 : 0,
    cropFrame: tile.crop?.growth ?? null,
  };
}

export function farmStableOrder(rowMajorIndex: number): number {
  return 100 + rowMajorIndex;
}
