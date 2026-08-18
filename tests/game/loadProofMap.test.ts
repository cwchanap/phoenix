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
  const raw = (await Bun.file(mapPath).json()) as Record<string, unknown>;
  const tilesets = raw.tilesets as Array<Record<string, unknown>>;
  const ground = withLayer(raw, 'Ground');
  const scenery = withLayer(raw, 'Scenery') as unknown as {
    objects: Array<Record<string, unknown>>;
  };
  const collision = withLayer(raw, 'Collision') as unknown as {
    objects: Array<Record<string, unknown>>;
  };
  const markers = withLayer(raw, 'Markers') as unknown as {
    objects: Array<Record<string, unknown>>;
  };
  expect(raw.nextlayerid).toBe(5);
  expect(raw.nextobjectid).toBe(17);
  expect(tilesets[0]).toEqual(
    expect.objectContaining({
      columns: 3,
      imageheight: 32,
      imagewidth: 192,
      tilecount: 3,
      firstgid: 1,
    }),
  );
  expect(tilesets[1]).toEqual(expect.objectContaining({ firstgid: 4 }));
  const groundData = ground.data as number[];
  const pathCells = groundData.flatMap((gid, index) =>
    gid === 3 ? [{ x: index % 12, y: Math.floor(index / 12) }] : [],
  );
  expect(pathCells).toEqual([
    { x: 3, y: 6 },
    { x: 4, y: 6 },
    { x: 5, y: 6 },
    { x: 6, y: 6 },
    { x: 7, y: 6 },
    { x: 8, y: 6 },
    { x: 9, y: 6 },
  ]);
  for (let y = 2; y <= 3; y += 1) {
    for (let x = 8; x <= 10; x += 1) expect(groundData[y * 12 + x]).toBe(1);
  }
  const reserveCells = new Set(
    Array.from({ length: 2 }, (_, row) =>
      Array.from({ length: 3 }, (_, column) => `${8 + column},${2 + row}`),
    ).flat(),
  );
  for (const layerName of ['Scenery', 'Collision', 'Markers']) {
    const objects = (withLayer(raw, layerName).objects ?? []) as Array<Record<string, unknown>>;
    for (const object of objects) {
      if (typeof object.x !== 'number' || typeof object.y !== 'number') continue;
      const cell = projection.worldToGrid({ x: object.x, y: object.y });
      expect(reserveCells.has(`${Math.floor(cell.x)},${Math.floor(cell.y)}`)).toBeFalse();
    }
  }
  expect(scenery.objects.map(({ id, name, gid }) => [id, name, gid])).toEqual([
    [1, 'tree', 4],
    [2, 'building', 5],
    [7, 'shipping-bin', 6],
  ]);
  expect(collision.objects.map(({ id, name }) => [id, name])).toEqual([
    [3, 'tree'],
    [4, 'building'],
    [8, 'shipping-bin'],
    [11, 'villager-shopkeeper'],
    [12, 'villager-farmer'],
    [13, 'villager-resident'],
  ]);
  expect(markers.objects).toEqual(
    expect.arrayContaining([
      expect.objectContaining({ id: 5, name: 'player-spawn' }),
      expect.objectContaining({ id: 6, name: 'bed-interaction' }),
      expect.objectContaining({ id: 9, name: 'shop-counter' }),
      expect.objectContaining({ id: 10, name: 'shipping-bin' }),
      expect.objectContaining({ id: 14, name: 'villager-shopkeeper', x: 416, y: 192 }),
      expect.objectContaining({ id: 15, name: 'villager-farmer', x: 320, y: 144 }),
      expect.objectContaining({ id: 16, name: 'villager-resident', x: 512, y: 240 }),
    ]),
  );

  const parsed = parseProofMap(raw, projection);

  expect(parsed.world.spawn).toEqual({ x: 2.5, y: 9.5 });
  expect(parsed.world.footprints).toEqual([
    { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
    { id: 'building', x: 7, y: 7, width: 2, height: 2 },
    { id: 'shipping-bin', x: 6.2, y: 10.2, width: 0.6, height: 0.6 },
    { id: 'villager-shopkeeper', x: 6.2, y: 5.2, width: 0.6, height: 0.6 },
    { id: 'villager-farmer', x: 3.2, y: 5.2, width: 0.6, height: 0.6 },
    { id: 'villager-resident', x: 9.2, y: 5.2, width: 0.6, height: 0.6 },
  ]);
  expect(
    parsed.scenery.map(({ id, kind, frame, world, stableOrder }) => [
      id,
      kind,
      frame,
      world,
      stableOrder,
    ]),
  ).toEqual([
    ['tree', 'tree', 0, { x: 480, y: 192 }, 1],
    ['building', 'building', 1, { x: 384, y: 288 }, 2],
    ['shipping-bin', 'shipping-bin', 2, { x: 256, y: 272 }, 7],
  ]);
  expect(parsed.villagers).toEqual([
    { id: 'shopkeeper', frame: 0, world: { x: 416, y: 192 }, stableOrder: 14 },
    { id: 'farmer', frame: 1, world: { x: 320, y: 144 }, stableOrder: 15 },
    { id: 'resident', frame: 2, world: { x: 512, y: 240 }, stableOrder: 16 },
  ]);
  expect(parsed.villagerCells).toEqual({
    shopkeeper: { x: 6, y: 5 },
    farmer: { x: 3, y: 5 },
    resident: { x: 9, y: 5 },
  });
  expect(parsed.farmCells).toHaveLength(9);
  expect(parsed.farmCells).toEqual([
    { x: 2, y: 7 },
    { x: 3, y: 7 },
    { x: 4, y: 7 },
    { x: 2, y: 8 },
    { x: 3, y: 8 },
    { x: 4, y: 8 },
    { x: 2, y: 9 },
    { x: 3, y: 9 },
    { x: 4, y: 9 },
  ]);
  expect(parsed.bedCell).toEqual({ x: 6, y: 8 });
  expect(parsed.shopCell).toEqual({ x: 6, y: 7 });
  expect(parsed.shippingCell).toEqual({ x: 6, y: 10 });
  expect(parsed.groundTilesetName).toBe('proof-ground');
});

test.each([
  ['proof-tiles.png', 192, 32],
  ['proof-player.png', 128, 48],
  ['proof-scenery.png', 288, 96],
  ['proof-villagers.png', 96, 48],
  ['proof-soil.png', 128, 32],
  ['proof-crops.png', 128, 144],
])('writes %s with exact PNG dimensions', async (name, width, height) => {
  const bytes = new Uint8Array(await Bun.file(resolve(assetRoot, 'sprites', name)).arrayBuffer());

  expect([...bytes.subarray(0, 8)]).toEqual([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  expect(view.getUint32(16)).toBe(width);
  expect(view.getUint32(20)).toBe(height);
});

const clone = <T>(value: T): T => structuredClone(value);
const withLayer = (raw: Record<string, unknown>, name: string): Record<string, unknown> => {
  const layer = (raw.layers as Array<Record<string, unknown>>).find(
    (candidate) => candidate.name === name,
  );
  if (!layer) throw new Error(`missing test layer ${name}`);
  return layer;
};
const withObject = (
  raw: Record<string, unknown>,
  layerName: string,
  objectName: string,
): Record<string, unknown> => {
  const object = (withLayer(raw, layerName).objects as Array<Record<string, unknown>>).find(
    (candidate) => candidate.name === objectName,
  );
  if (!object) throw new Error(`missing test object ${objectName}`);
  return object;
};

describe('proof-map contract validation', () => {
  async function validRaw(): Promise<Record<string, unknown>> {
    return (await Bun.file(mapPath).json()) as Record<string, unknown>;
  }

  test.each([
    { label: 'null', value: null },
    { label: 'array', value: [] as unknown[] },
    { label: 'string', value: 'map' },
  ])('rejects non-record input $label', ({ value }) => {
    expect(() => parseProofMap(value, projection)).toThrow(/proof-map: map must be an object/);
  });

  type MetadataMutation = [string, (raw: Record<string, unknown>) => void, RegExp];
  const metadataMutation = (
    name: string,
    mutate: MetadataMutation[1],
    message: RegExp,
  ): MetadataMutation => [name, mutate, message];
  const metadataMutations: MetadataMutation[] = [
    metadataMutation(
      'compressionlevel',
      (raw) => {
        raw.compressionlevel = 0;
      },
      /proof-map: compressionlevel must be -1/,
    ),
    metadataMutation(
      'tiledversion',
      (raw) => {
        raw.tiledversion = '1.11.2';
      },
      /proof-map: tiledversion must be 1\.12\.2/,
    ),
    metadataMutation(
      'version',
      (raw) => {
        raw.version = '1.9';
      },
      /proof-map: version must be 1\.10/,
    ),
    metadataMutation(
      'proof-ground margin',
      (raw) => {
        (raw.tilesets as Array<Record<string, unknown>>)[0].margin = 1;
      },
      /proof-map: proof-ground margin must be 0/,
    ),
    metadataMutation(
      'proof-ground spacing',
      (raw) => {
        (raw.tilesets as Array<Record<string, unknown>>)[0].spacing = 1;
      },
      /proof-map: proof-ground spacing must be 0/,
    ),
    ...(['Ground', 'Scenery', 'Collision', 'Markers'] as const).flatMap((layerName) => [
      metadataMutation(
        `${layerName} opacity`,
        (raw) => {
          withLayer(raw, layerName).opacity = 0;
        },
        new RegExp(`proof-map: ${layerName} opacity must be 1`),
      ),
      metadataMutation(
        `${layerName} visibility`,
        (raw) => {
          withLayer(raw, layerName).visible = false;
        },
        new RegExp(`proof-map: ${layerName} visible must be true`),
      ),
    ]),
    ...(['Scenery', 'Collision', 'Markers'] as const).map((layerName) =>
      metadataMutation(
        `${layerName} draw order`,
        (raw) => {
          withLayer(raw, layerName).draworder = 'bottomup';
        },
        new RegExp(`proof-map: ${layerName} draworder must be topdown`),
      ),
    ),
  ];

  test.each(metadataMutations)('rejects invalid %s metadata', async (_name, mutate, message) => {
    const raw = clone(await validRaw());
    mutate(raw);
    expect(() => parseProofMap(raw, projection)).toThrow(message);
  });

  test.each([
    [
      'orthogonal orientation',
      (raw: Record<string, unknown>) => {
        raw.orientation = 'orthogonal';
      },
      /proof-map: orientation must be isometric/,
    ],
    [
      'missing Markers layer',
      (raw: Record<string, unknown>) => {
        raw.layers = (raw.layers as Array<{ name: string }>).filter(
          ({ name }) => name !== 'Markers',
        );
      },
      /proof-map: missing Markers layer/,
    ],
    [
      'duplicate player spawn',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        markers.objects.push({ ...markers.objects[0], id: 6 });
      },
      /proof-map: expected exactly one player-spawn marker/,
    ],
    [
      'missing bed marker',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        markers.objects = markers.objects.filter(({ name }) => name !== 'bed-interaction');
      },
      /proof-map: expected exactly one bed-interaction marker/,
    ],
    [
      'duplicate bed marker',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        const bed = markers.objects.find(({ name }) => name === 'bed-interaction');
        if (!bed) throw new Error('missing bed marker in test fixture');
        markers.objects.push({ ...bed, id: 7 });
      },
      /proof-map: expected exactly one bed-interaction marker/,
    ],
    [
      'renamed bed marker',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'bed-interaction').name = 'bed';
      },
      /proof-map: unknown marker name bed/,
    ],
    [
      'unknown marker name',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        markers.objects.push({
          id: 7,
          name: 'mystery',
          type: '',
          point: true,
          x: 320,
          y: 240,
          rotation: 0,
          visible: true,
        });
      },
      /proof-map: unknown marker name mystery/,
    ],
    [
      'wrong bed coordinates',
      (raw: Record<string, unknown>) => {
        const bed = withObject(raw, 'Markers', 'bed-interaction');
        bed.x = 288;
      },
      /proof-map: bed-interaction marker must be at logical cell 6,8/,
    ],
    [
      'stale nextobjectid',
      (raw: Record<string, unknown>) => {
        raw.nextobjectid = 10;
      },
      /proof-map: nextobjectid must be 17/,
    ],
    [
      'missing shipping scenery',
      (raw: Record<string, unknown>) => {
        const layer = withLayer(raw, 'Scenery') as unknown as { objects: Array<{ name: string }> };
        layer.objects = layer.objects.filter(({ name }) => name !== 'shipping-bin');
      },
      /proof-map: expected tree, building, and shipping-bin scenery objects/,
    ],
    [
      'wrong shipping scenery id',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Scenery', 'shipping-bin').id = 8;
      },
      /proof-map: scenery shipping-bin.id must be 7/,
    ],
    [
      'wrong shipping gid',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Scenery', 'shipping-bin').gid = 4;
      },
      /proof-map: scenery shipping-bin.gid must be 6/,
    ],
    [
      'wrong shipping footprint id',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Collision', 'shipping-bin').id = 7;
      },
      /proof-map: footprint shipping-bin.id must be 8/,
    ],
    [
      'wrong shipping footprint position',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Collision', 'shipping-bin').x = 0;
      },
      /proof-map: footprint shipping-bin is not at its authored logical position/,
    ],
    [
      'missing shop marker',
      (raw: Record<string, unknown>) => {
        const layer = withLayer(raw, 'Markers') as unknown as { objects: Array<{ name: string }> };
        layer.objects = layer.objects.filter(({ name }) => name !== 'shop-counter');
      },
      /proof-map: expected exactly one shop-counter marker/,
    ],
    [
      'wrong shop marker id',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'shop-counter').id = 10;
      },
      /proof-map: shop-counter.id must be 9/,
    ],
    [
      'wrong shipping marker cell',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'shipping-bin').x = 0;
      },
      /proof-map: shipping-bin marker must be at logical cell 6,10/,
    ],
    [
      'missing villager footprint',
      (raw: Record<string, unknown>) => {
        const collision = withLayer(raw, 'Collision') as unknown as {
          objects: Array<{ name: string }>;
        };
        collision.objects = collision.objects.filter(({ name }) => name !== 'villager-farmer');
      },
      /proof-map: Collision.objects must contain exactly six supported footprints/,
    ],
    [
      'extra collision footprint',
      (raw: Record<string, unknown>) => {
        const collision = withLayer(raw, 'Collision') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        collision.objects.push({ ...collision.objects[0], id: 17 });
      },
      /proof-map: Collision.objects must contain exactly six supported footprints/,
    ],
    [
      'malformed villager footprint',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Collision', 'villager-shopkeeper').polygon = [];
      },
      /proof-map: footprint villager-shopkeeper must have four polygon points/,
    ],
    [
      'wrong villager footprint id',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Collision', 'villager-shopkeeper').id = 18;
      },
      /proof-map: footprint villager-shopkeeper.id must be 11/,
    ],
    [
      'wrong villager footprint position',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Collision', 'villager-shopkeeper').x = 0;
      },
      /proof-map: footprint villager-shopkeeper is not at its authored logical position/,
    ],
    [
      'missing villager marker',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<{ name: string }>;
        };
        markers.objects = markers.objects.filter(({ name }) => name !== 'villager-farmer');
      },
      /proof-map: expected exactly one villager-farmer marker/,
    ],
    [
      'duplicate villager marker',
      (raw: Record<string, unknown>) => {
        const markers = withLayer(raw, 'Markers') as unknown as {
          objects: Array<Record<string, unknown>>;
        };
        const villager = markers.objects.find(({ name }) => name === 'villager-resident');
        if (!villager) throw new Error('missing villager marker in test fixture');
        markers.objects.push({ ...villager, id: 19 });
      },
      /proof-map: expected exactly one villager-resident marker/,
    ],
    [
      'malformed villager marker',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'villager-shopkeeper').point = false;
      },
      /proof-map: villager-shopkeeper marker must be a point/,
    ],
    [
      'wrong villager marker id',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'villager-shopkeeper').id = 19;
      },
      /proof-map: villager-shopkeeper.id must be 14/,
    ],
    [
      'wrong villager marker cell',
      (raw: Record<string, unknown>) => {
        withObject(raw, 'Markers', 'villager-shopkeeper').x = 384;
      },
      /proof-map: villager-shopkeeper marker must be at logical cell 6,5/,
    ],
    [
      'missing building footprint',
      (raw: Record<string, unknown>) => {
        const collision = withLayer(raw, 'Collision') as unknown as {
          objects: Array<{ name: string }>;
        };
        collision.objects = collision.objects.filter(({ name }) => name !== 'building');
      },
      /proof-map: Collision.objects must contain exactly six supported footprints/,
    ],
    [
      'wrong tree footprint dimensions',
      (raw: Record<string, unknown>) => {
        const tree = withObject(raw, 'Collision', 'tree') as unknown as {
          polygon: Array<{ x: number; y: number }>;
        };
        tree.polygon[1] = { x: tree.polygon[1].x + 6.4, y: tree.polygon[1].y + 3.2 };
        tree.polygon[2] = { x: tree.polygon[2].x + 6.4, y: tree.polygon[2].y + 3.2 };
      },
      /proof-map: footprint tree dimensions must be 0\.6x0\.6/,
    ],
    [
      'unknown scenery kind',
      (raw: Record<string, unknown>) => {
        const tree = withObject(raw, 'Scenery', 'tree') as unknown as { type: string };
        tree.type = 'rock';
      },
      /proof-map: unknown scenery kind rock/,
    ],
    [
      'non-bottom scenery alignment',
      (raw: Record<string, unknown>) => {
        const sceneryTileset = (raw.tilesets as Array<Record<string, unknown>>)[1];
        sceneryTileset.objectalignment = 'top';
      },
      /proof-map: proof-scenery objectalignment must be bottom/,
    ],
    [
      'non-parallelogram footprint',
      (raw: Record<string, unknown>) => {
        const tree = withObject(raw, 'Collision', 'tree') as unknown as {
          polygon: Array<{ x: number; y: number }>;
        };
        tree.polygon[2] = { x: tree.polygon[2].x + 5, y: tree.polygon[2].y };
      },
      /proof-map: footprint tree is not a logical rectangle/,
    ],
    [
      'out-of-bounds spawn',
      (raw: Record<string, unknown>) => {
        const spawn = withObject(raw, 'Markers', 'player-spawn') as unknown as { x: number };
        spawn.x = -512;
      },
      /proof-map: player spawn is out of bounds/,
    ],
  ])('rejects %s', async (_name, mutate, message) => {
    const raw = clone(await validRaw());
    mutate(raw);
    expect(() => parseProofMap(raw, projection)).toThrow(message);
  });
});
