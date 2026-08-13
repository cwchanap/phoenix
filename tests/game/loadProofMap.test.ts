import { describe, expect, test } from 'bun:test';
import { resolve } from 'node:path';
import { ProjectionAdapter } from '../../src/game/phaser/ProjectionAdapter';
import { parseProofMap } from '../../src/game/phaser/loadProofMap';

const assetRoot = resolve(import.meta.dir, '../../src/assets');
const mapPath = resolve(assetRoot, 'maps/proof-map.json');
const projection = new ProjectionAdapter(
  { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
  { width: 12, height: 12 },
);

test('loads the authored proof-map contract', async () => {
  const parsed = parseProofMap(await Bun.file(mapPath).json(), projection);

  expect(parsed.world.spawn).toEqual({ x: 2.5, y: 9.5 });
  expect(parsed.world.footprints).toEqual([
    { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
    { id: 'building', x: 7, y: 7, width: 2, height: 2 },
  ]);
  expect(parsed.scenery.map(({ id, kind }) => [id, kind])).toEqual([
    ['tree', 'tree'],
    ['building', 'building'],
  ]);
  expect(parsed.scenery.map(({ id, frame, world, stableOrder }) => [id, frame, world, stableOrder])).toEqual([
    ['tree', 0, { x: 480, y: 192 }, 1],
    ['building', 1, { x: 384, y: 288 }, 2],
  ]);
  expect(parsed.farmCells).toHaveLength(9);
  expect(parsed.farmCells).toEqual([
    { x: 2, y: 7 }, { x: 3, y: 7 }, { x: 4, y: 7 },
    { x: 2, y: 8 }, { x: 3, y: 8 }, { x: 4, y: 8 },
    { x: 2, y: 9 }, { x: 3, y: 9 }, { x: 4, y: 9 },
  ]);
  expect(parsed.groundTilesetName).toBe('proof-ground');
});

test.each([
  ['proof-tiles.png', 128, 32],
  ['proof-player.png', 128, 48],
  ['proof-scenery.png', 192, 96],
])('writes %s with exact PNG dimensions', async (name, width, height) => {
  const bytes = new Uint8Array(await Bun.file(resolve(assetRoot, 'sprites', name)).arrayBuffer());

  expect([...bytes.subarray(0, 8)]).toEqual([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  expect(view.getUint32(16)).toBe(width);
  expect(view.getUint32(20)).toBe(height);
});

const clone = <T>(value: T): T => structuredClone(value);
const withLayer = (raw: Record<string, unknown>, name: string): Record<string, unknown> => {
  const layer = (raw.layers as Array<Record<string, unknown>>).find((candidate) => candidate.name === name);
  if (!layer) throw new Error(`missing test layer ${name}`);
  return layer;
};
const withObject = (raw: Record<string, unknown>, layerName: string, objectName: string): Record<string, unknown> => {
  const object = (withLayer(raw, layerName).objects as Array<Record<string, unknown>>)
    .find((candidate) => candidate.name === objectName);
  if (!object) throw new Error(`missing test object ${objectName}`);
  return object;
};

describe('proof-map contract validation', () => {
  async function validRaw(): Promise<Record<string, unknown>> {
    return await Bun.file(mapPath).json() as Record<string, unknown>;
  }

  test.each([
    { label: 'null', value: null },
    { label: 'array', value: [] as unknown[] },
    { label: 'string', value: 'map' },
  ])('rejects non-record input $label', ({ value }) => {
    expect(() => parseProofMap(value, projection)).toThrow(/proof-map: map must be an object/);
  });

  test.each([
    ['orthogonal orientation', (raw: Record<string, unknown>) => { raw.orientation = 'orthogonal'; }, /proof-map: orientation must be isometric/],
    ['missing Markers layer', (raw: Record<string, unknown>) => { raw.layers = (raw.layers as Array<{ name: string }>).filter(({ name }) => name !== 'Markers'); }, /proof-map: missing Markers layer/],
    ['duplicate player spawn', (raw: Record<string, unknown>) => {
      const markers = withLayer(raw, 'Markers') as unknown as { objects: Array<Record<string, unknown>> };
      markers.objects.push({ ...markers.objects[0], id: 6 });
    }, /proof-map: expected exactly one player-spawn marker/],
    ['missing building footprint', (raw: Record<string, unknown>) => {
      const collision = withLayer(raw, 'Collision') as unknown as { objects: Array<{ name: string }> };
      collision.objects = collision.objects.filter(({ name }) => name !== 'building');
    }, /proof-map: missing footprint for scenery building/],
    ['wrong tree footprint dimensions', (raw: Record<string, unknown>) => {
      const tree = withObject(raw, 'Collision', 'tree') as unknown as { polygon: Array<{ x: number; y: number }> };
      tree.polygon[1] = { x: tree.polygon[1].x + 6.4, y: tree.polygon[1].y + 3.2 };
      tree.polygon[2] = { x: tree.polygon[2].x + 6.4, y: tree.polygon[2].y + 3.2 };
    }, /proof-map: footprint tree dimensions must be 0\.6x0\.6/],
    ['unknown scenery kind', (raw: Record<string, unknown>) => {
      const tree = withObject(raw, 'Scenery', 'tree') as unknown as { type: string };
      tree.type = 'rock';
    }, /proof-map: unknown scenery kind rock/],
    ['non-bottom scenery alignment', (raw: Record<string, unknown>) => {
      const sceneryTileset = (raw.tilesets as Array<Record<string, unknown>>)[1];
      sceneryTileset.objectalignment = 'top';
    }, /proof-map: proof-scenery objectalignment must be bottom/],
    ['non-parallelogram footprint', (raw: Record<string, unknown>) => {
      const tree = withObject(raw, 'Collision', 'tree') as unknown as { polygon: Array<{ x: number; y: number }> };
      tree.polygon[2] = { x: tree.polygon[2].x + 5, y: tree.polygon[2].y };
    }, /proof-map: footprint tree is not a logical rectangle/],
    ['out-of-bounds spawn', (raw: Record<string, unknown>) => {
      const spawn = withObject(raw, 'Markers', 'player-spawn') as unknown as { x: number };
      spawn.x = -512;
    }, /proof-map: player spawn is out of bounds/],
  ])('rejects %s', async (_name, mutate, message) => {
    const raw = clone(await validRaw());
    mutate(raw);
    expect(() => parseProofMap(raw, projection)).toThrow(message);
  });
});
