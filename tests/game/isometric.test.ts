import { describe, expect, test } from 'bun:test';
import {
  cellDiamond, gridCellAtWorld, gridToWorld, projectedMapBounds,
  sortDepthEntries, worldToGrid,
} from '../../src/game/core/isometric';
import { ProjectionAdapter } from '../../src/game/phaser/ProjectionAdapter';

const metrics = { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } } as const;

test('round-trips fractional logical coordinates', () => {
  for (const point of [{ x: 0, y: 0 }, { x: 2.5, y: 9.5 }, { x: 12, y: 12 }]) {
    const result = worldToGrid(gridToWorld(point, metrics), metrics);
    expect(result.x).toBeCloseTo(point.x, 10);
    expect(result.y).toBeCloseTo(point.y, 10);
  }
});

test('selects cells consistently at the proof-map edges', () => {
  expect(gridCellAtWorld(gridToWorld({ x: 0.5, y: 0.5 }, metrics), metrics)).toEqual({ x: 0, y: 0 });
  expect(gridCellAtWorld(gridToWorld({ x: 11.999999, y: 11.999999 }, metrics), metrics)).toEqual({ x: 11, y: 11 });
  expect(gridCellAtWorld(gridToWorld({ x: 0.5, y: 6.5 }, metrics), metrics)).toEqual({ x: 0, y: 6 });
  expect(gridCellAtWorld(gridToWorld({ x: 11.5, y: 6.5 }, metrics), metrics)).toEqual({ x: 11, y: 6 });
  expect(gridCellAtWorld(gridToWorld({ x: 6.5, y: 0.5 }, metrics), metrics)).toEqual({ x: 6, y: 0 });
  expect(gridCellAtWorld(gridToWorld({ x: 6.5, y: 11.5 }, metrics), metrics)).toEqual({ x: 6, y: 11 });
});

test('uses a one-nanounit epsilon only at cell lookup boundaries', () => {
  expect(gridCellAtWorld(gridToWorld({ x: 0.999999, y: 4.5 }, metrics), metrics)).toEqual({ x: 0, y: 4 });
  expect(gridCellAtWorld(gridToWorld({ x: 0.9999999995, y: 4.5 }, metrics), metrics)).toEqual({ x: 1, y: 4 });
});

test('returns clockwise diamond vertices', () => {
  expect(cellDiamond({ x: 0, y: 0 }, metrics)).toEqual([
    { x: 384, y: 0 }, { x: 416, y: 16 },
    { x: 384, y: 32 }, { x: 352, y: 16 },
  ]);
});

test('uses stable order only when ground Y ties', () => {
  const sorted = sortDepthEntries([
    { id: 'tree', groundY: 160, stableOrder: 1 },
    { id: 'player', groundY: 159, stableOrder: 9 },
    { id: 'building', groundY: 160, stableOrder: 0 },
  ]);
  expect(sorted.map(({ id }) => id)).toEqual(['player', 'building', 'tree']);
});

test('the Phaser adapter delegates every projection operation', () => {
  const adapter = new ProjectionAdapter(metrics, { width: 12, height: 12 });
  expect(adapter.gridToWorld({ x: 2.5, y: 9.5 })).toEqual(gridToWorld({ x: 2.5, y: 9.5 }, metrics));
  expect(adapter.projectedBounds(96)).toEqual(projectedMapBounds({ width: 12, height: 12 }, metrics, 96));
  expect(adapter.projectedBounds(96)).toEqual({ x: 0, y: -96, width: 768, height: 480 });
});
