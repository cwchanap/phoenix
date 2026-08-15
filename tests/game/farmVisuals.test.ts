import { expect, test } from 'bun:test';
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  visualStage,
} from '../../src/game/core/cropDefinitions';
import { farmStableOrder, farmVisuals } from '../../src/game/core/farmVisuals';

test('keeps untilled soil hidden in sunny weather', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'untilled', crop: null }, 'sunny'))
    .toEqual({ soilFrame: null, cropFrame: null });
});

test('renders rainy empty soil as wet', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'tilled', crop: null }, 'rainy'))
    .toEqual({ soilFrame: 1, cropFrame: null });
});

test('maps every crop progress to its row-major sheet frame', () => {
  for (const kind of CROP_KINDS) {
    const growthDays = CROP_DEFINITIONS[kind].growthDays;
    for (let growth = 0; growth <= growthDays; growth += 1) {
      expect(farmVisuals({
        position: { x: 2, y: 7 },
        soil: 'tilled',
        crop: { kind, growth, wateredToday: false },
      }, 'sunny')).toEqual({
        soilFrame: 0,
        cropFrame: CROP_KINDS.indexOf(kind) * 4 + visualStage(kind, growth),
      });
    }
  }
});

test('does not confuse slow-crop progress with a sheet frame', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'pumpkin', growth: 5, wateredToday: false },
  }, 'sunny')).toEqual({ soilFrame: 0, cropFrame: 10 });
});

test('maps a watered sunny tile to deterministic frames', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 0, wateredToday: true },
  }, 'sunny'))
    .toEqual({ soilFrame: 1, cropFrame: 0 });
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'tilled', crop: null }, 'sunny'))
    .toEqual({ soilFrame: 0, cropFrame: null });
});

test('maps farm tiles to stable row-major depth order', () => {
  expect(Array.from({ length: 9 }, (_, index) => farmStableOrder(index)))
    .toEqual([100, 101, 102, 103, 104, 105, 106, 107, 108]);
});
