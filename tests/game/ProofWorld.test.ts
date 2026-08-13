import { expect, test } from 'bun:test';
import { gridToWorld } from '../../src/game/core/isometric';
import { intersects, moveWithCollisions, playerRect } from '../../src/game/core/collision';
import { ProofWorld } from '../../src/game/core/ProofWorld';
import type { ProofMap, WorldPoint } from '../../src/game/core/types';

const map: ProofMap = {
  width: 12,
  height: 12,
  spawn: { x: 2.5, y: 9.5 },
  footprints: [
    { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
    { id: 'building', x: 7, y: 7, width: 2, height: 2 },
  ],
};
const metrics = { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } };

test('normalizes diagonal screen input', () => {
  const cardinal = new ProofWorld(map, metrics);
  const diagonal = new ProofWorld(map, metrics);
  cardinal.step({ screenX: 1, screenY: 0 }, 50);
  diagonal.step({ screenX: 1, screenY: 1 }, 50);

  const start = gridToWorld(map.spawn, metrics);
  const cardinalEnd = gridToWorld(cardinal.snapshot().player.position, metrics);
  const diagonalEnd = gridToWorld(diagonal.snapshot().player.position, metrics);
  const distance = (point: WorldPoint) => Math.hypot(point.x - start.x, point.y - start.y);

  expect(distance(diagonalEnd)).toBeCloseTo(distance(cardinalEnd), 6);
});

test('cancels opposing screen components without moving', () => {
  const world = new ProofWorld(map, metrics);
  world.step({ screenX: 0, screenY: 0 }, 50);

  expect(world.snapshot().player.position).toEqual(map.spawn);
});

test('chooses each facing direction and horizontal wins ties', () => {
  const directions = [
    [{ screenX: 0, screenY: -1 }, 'up'],
    [{ screenX: 1, screenY: 1 }, 'right'],
    [{ screenX: 0, screenY: 1 }, 'down'],
    [{ screenX: -1, screenY: 0 }, 'left'],
  ] as const;

  for (const [input, facing] of directions) {
    const world = new ProofWorld(map, metrics);
    world.step(input, 1);
    expect(world.snapshot().player.facing).toBe(facing);
  }
});

test('retains facing while idle', () => {
  const world = new ProofWorld(map, metrics, 'up');
  world.step({ screenX: 0, screenY: 0 }, 50);

  expect(world.snapshot().player.facing).toBe('up');
});

test('normalizes the player to map bounds', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 0.25, y: 0.25 } }, metrics);
  world.step({ screenX: -1, screenY: -1 }, 500);
  const player = world.snapshot().player.position;

  expect(player.x).toBeGreaterThanOrEqual(0.18);
  expect(player.y).toBeGreaterThanOrEqual(0.18);
  expect(player.x).toBeLessThanOrEqual(11.82);
  expect(player.y).toBeLessThanOrEqual(11.82);
});

test('caps a large delta before it can tunnel through the tree', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 6.5, y: 4.5 } }, metrics);
  world.step({ screenX: 1, screenY: 0.5 }, 500);
  const player = world.snapshot().player.position;

  expect(player.x).toBeLessThan(6.7);
  expect(player.y).toBeGreaterThan(4.4);
});

test('subdivides a capped frame before resolving a corner collision', () => {
  const world = new ProofWorld({
    width: 12,
    height: 12,
    spawn: { x: 0.7, y: 0.8 },
    footprints: [{ id: 'post', x: 1, y: 1, width: 0.1, height: 0.1 }],
  }, metrics);
  world.step({ screenX: 0.2, screenY: 0.2 }, 50);

  expect(world.snapshot().player.position.x).toBeCloseTo(0.82, 10);
});

test('slides along the building footprint instead of entering it', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 6.5, y: 7.5 } }, metrics);
  for (let i = 0; i < 30; i++) world.step({ screenX: 1, screenY: 0.3 }, 16);
  const player = world.snapshot().player.position;

  expect(player.x).toBeLessThanOrEqual(6.82);
  expect(player.y).not.toBeCloseTo(7.5, 2);
});

test('treats touching footprint edges as clear but overlap as collision', () => {
  const edge = { id: 'edge', x: 1, y: 1, width: 1, height: 1 };
  expect(intersects(edge, { id: 'player', x: 2, y: 1, width: 1, height: 1 })).toBe(false);
  expect(intersects(edge, { id: 'player', x: 1.999, y: 1, width: 1, height: 1 })).toBe(true);
  expect(playerRect({ x: 2, y: 3 })).toEqual({
    id: 'player', x: 1.82, y: 2.82, width: 0.36, height: 0.36,
  });
});

test('resolves direct motion against a footprint and both map edges', () => {
  const fromLeft = moveWithCollisions({ x: 6.5, y: 7.5 }, { x: 1, y: 0 }, map);
  const fromRight = moveWithCollisions({ x: 9.5, y: 7.5 }, { x: -1, y: 0 }, map);
  const fromAbove = moveWithCollisions({ x: 7.5, y: 6.5 }, { x: 0, y: 1 }, map);
  const fromBelow = moveWithCollisions({ x: 7.5, y: 9.5 }, { x: 0, y: -1 }, map);
  const bounds = moveWithCollisions({ x: 0.5, y: 0.5 }, { x: -3, y: -3 }, map);

  expect(fromLeft.x).toBeCloseTo(6.82, 10);
  expect(fromRight.x).toBeCloseTo(9.18, 10);
  expect(fromAbove.y).toBeCloseTo(6.82, 10);
  expect(fromBelow.y).toBeCloseTo(9.18, 10);
  expect(bounds).toEqual({ x: 0.18, y: 0.18 });
});

test('returns null instead of clamping a target beyond the map', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 0.25, y: 0.25 } }, metrics, 'up');

  expect(world.snapshot().target).toBeNull();
});

test('applies all four target offsets from a fractional player position', () => {
  const cases = [
    [{ screenX: 0, screenY: -1 }, { x: 4, y: 4 }],
    [{ screenX: 1, screenY: 0 }, { x: 6, y: 4 }],
    [{ screenX: 0, screenY: 1 }, { x: 6, y: 6 }],
    [{ screenX: -1, screenY: 0 }, { x: 4, y: 6 }],
  ] as const;

  for (const [input, target] of cases) {
    const world = new ProofWorld({ ...map, spawn: { x: 5.5, y: 5.5 } }, metrics);
    world.step(input, 1);
    expect(world.snapshot().target).toEqual(target);
  }
});

test('returns fresh snapshots', () => {
  const world = new ProofWorld(map, metrics);
  const first = world.snapshot();
  first.player.position.x = 99;

  expect(world.snapshot().player.position.x).toBe(map.spawn.x);
});
