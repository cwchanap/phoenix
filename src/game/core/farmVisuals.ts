import { CROP_KINDS, visualStage } from './cropDefinitions';
import type { FarmTileSnapshot, Weather } from './types';

export interface FarmVisualFrames {
  soilFrame: number | null;
  cropFrame: number | null;
}

export function farmVisuals(tile: FarmTileSnapshot, weather: Weather): FarmVisualFrames {
  const wet = weather === 'rainy' || tile.crop?.wateredToday === true;
  const cropFrame =
    tile.crop === null
      ? null
      : CROP_KINDS.indexOf(tile.crop.kind) * 4 + visualStage(tile.crop.kind, tile.crop.growth);
  return {
    soilFrame: tile.soil === 'untilled' ? null : wet ? 1 : 0,
    cropFrame,
  };
}

export function farmStableOrder(rowMajorIndex: number): number {
  return 100 + rowMajorIndex;
}
