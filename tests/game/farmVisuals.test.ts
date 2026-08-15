import { expect, test } from 'bun:test';
import { farmStableOrder, farmVisuals } from '../../src/game/core/farmVisuals';

test('keeps untilled soil hidden in sunny weather', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'untilled', crop: null }, 'sunny'))
    .toEqual({ soilFrame: null, cropFrame: null });
});

test('renders rainy empty soil as wet', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'tilled', crop: null }, 'rainy'))
    .toEqual({ soilFrame: 1, cropFrame: null });
});

test('renders rainy dry crops on wet soil', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 1, wateredToday: false },
  }, 'rainy')).toEqual({ soilFrame: 1, cropFrame: 1 });
});

test('renders sunny dry crops on dry soil', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 2, wateredToday: false },
  }, 'sunny')).toEqual({ soilFrame: 0, cropFrame: 2 });
});

test('renders sunny watered crops on wet soil', () => {
  expect(farmVisuals({
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 3, wateredToday: true },
  }, 'sunny')).toEqual({ soilFrame: 1, cropFrame: 3 });
});

test('preserves every crop-growth frame', () => {
  for (const growth of [0, 1, 2, 3] as const) {
    expect(farmVisuals({
      position: { x: 2, y: 7 },
      soil: 'tilled',
      crop: { kind: 'turnip', growth, wateredToday: false },
    }, 'sunny')).toEqual({ soilFrame: 0, cropFrame: growth });
  }
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
