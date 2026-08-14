import { expect, test } from 'bun:test';
import { farmStableOrder, farmVisuals } from '../../src/game/core/farmVisuals';

test('maps authoritative farm state to deterministic frames', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'untilled', crop: null }))
    .toEqual({ soilFrame: null, cropFrame: null });
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'tilled', crop: null }))
    .toEqual({ soilFrame: 0, cropFrame: null });
  for (const growth of [0, 1, 2, 3] as const) {
    expect(farmVisuals({
      position: { x: 2, y: 7 },
      soil: 'tilled',
      crop: { kind: 'turnip', growth, wateredToday: true },
    })).toEqual({ soilFrame: 1, cropFrame: growth });
  }
});

test('maps farm tiles to stable row-major depth order', () => {
  expect(Array.from({ length: 9 }, (_, index) => farmStableOrder(index)))
    .toEqual([100, 101, 102, 103, 104, 105, 106, 107, 108]);
});
