import type { ProjectionAdapter } from './ProjectionAdapter';
import type {
  Footprint,
  GridCell,
  ProofMap,
  SceneryKind,
  SceneryPlacement,
} from '../core/types';

export interface ParsedProofMap {
  world: ProofMap;
  scenery: SceneryPlacement[];
  farmCells: GridCell[];
  groundTilesetName: 'proof-ground';
}

type RecordValue = Record<string, unknown>;

const snap = (value: number) => Math.round(value * 1_000_000_000) / 1_000_000_000;

function fail(reason: string): never {
  throw new Error(`proof-map: ${reason}`);
}

function record(value: unknown, context: string): RecordValue {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    fail(`${context} must be an object`);
  }
  return value as RecordValue;
}

function array(value: unknown, context: string): unknown[] {
  if (!Array.isArray(value)) fail(`${context} must be an array`);
  return value;
}

function string(value: unknown, context: string): string {
  if (typeof value !== 'string') fail(`${context} must be a string`);
  return value;
}

function number(value: unknown, context: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) fail(`${context} must be a finite number`);
  return value;
}

function integer(value: unknown, context: string): number {
  const result = number(value, context);
  if (!Number.isInteger(result)) fail(`${context} must be an integer`);
  return result;
}

function boolean(value: unknown, context: string): boolean {
  if (typeof value !== 'boolean') fail(`${context} must be a boolean`);
  return value;
}

function validateLayerMetadata(layer: RecordValue, name: string, objectLayer: boolean): void {
  if (number(layer.opacity, `${name}.opacity`) !== 1) fail(`${name} opacity must be 1`);
  if (!boolean(layer.visible, `${name}.visible`)) fail(`${name} visible must be true`);
  if (objectLayer && string(layer.draworder, `${name}.draworder`) !== 'topdown') {
    fail(`${name} draworder must be topdown`);
  }
}

function validateTilesetSpacing(tileset: RecordValue, name: string): void {
  if (integer(tileset.margin, `${name}.margin`) !== 0) fail(`${name} margin must be 0`);
  if (integer(tileset.spacing, `${name}.spacing`) !== 0) fail(`${name} spacing must be 0`);
}

function findLayer(raw: RecordValue, name: string): RecordValue {
  const layers = array(raw.layers, 'layers').map((value, index) => record(value, `layers[${index}]`));
  const layer = layers.find((candidate) => candidate.name === name);
  if (!layer) fail(`missing ${name} layer`);
  return layer;
}

function validateTileset(value: unknown, expected: {
  name: string;
  firstgid: number;
  columns: number;
  image: string;
  imageheight: number;
  imagewidth: number;
  tilecount: number;
  tileheight: number;
  tilewidth: number;
}): RecordValue {
  const tileset = record(value, `tileset ${expected.name}`);
  if (string(tileset.name, `tileset ${expected.name}.name`) !== expected.name) {
    fail(`expected tileset ${expected.name}`);
  }
  if (integer(tileset.firstgid, `tileset ${expected.name}.firstgid`) !== expected.firstgid) {
    fail(`tileset ${expected.name}.firstgid must be ${expected.firstgid}`);
  }
  for (const [field, expectedValue] of Object.entries(expected)) {
    if (field === 'name' || field === 'firstgid') continue;
    const actual = tileset[field];
    if (typeof expectedValue === 'number') {
      if (integer(actual, `tileset ${expected.name}.${field}`) !== expectedValue) {
        fail(`tileset ${expected.name}.${field} must be ${expectedValue}`);
      }
    } else if (string(actual, `tileset ${expected.name}.${field}`) !== expectedValue) {
      fail(`tileset ${expected.name}.${field} must be ${expectedValue}`);
    }
  }
  return tileset;
}

function validateMapHeader(raw: RecordValue, projection: ProjectionAdapter): void {
  if (string(raw.type, 'type') !== 'map') fail('type must be map');
  if (integer(raw.compressionlevel, 'compressionlevel') !== -1) {
    fail('compressionlevel must be -1');
  }
  if (string(raw.tiledversion, 'tiledversion') !== '1.12.2') {
    fail('tiledversion must be 1.12.2');
  }
  if (string(raw.version, 'version') !== '1.10') fail('version must be 1.10');
  if (string(raw.orientation, 'orientation') !== 'isometric') {
    fail('orientation must be isometric');
  }
  if (string(raw.renderorder, 'renderorder') !== 'right-down') {
    fail('renderorder must be right-down');
  }
  if (raw.infinite !== false) fail('infinite must be false');
  if (integer(raw.width, 'width') !== projection.mapSize.width) {
    fail(`width must be ${projection.mapSize.width}`);
  }
  if (integer(raw.height, 'height') !== projection.mapSize.height) {
    fail(`height must be ${projection.mapSize.height}`);
  }
  if (integer(raw.tilewidth, 'tilewidth') !== projection.metrics.tileWidth) {
    fail(`tilewidth must be ${projection.metrics.tileWidth}`);
  }
  if (integer(raw.tileheight, 'tileheight') !== projection.metrics.tileHeight) {
    fail(`tileheight must be ${projection.metrics.tileHeight}`);
  }
  if (integer(raw.nextlayerid, 'nextlayerid') !== 5) fail('nextlayerid must be 5');
  if (integer(raw.nextobjectid, 'nextobjectid') !== 6) fail('nextobjectid must be 6');
  const layers = array(raw.layers, 'layers').map((value, index) => record(value, `layers[${index}]`));
  const layerNames = new Set(layers.map((layer) => string(layer.name, 'layer.name')));
  for (const name of ['Ground', 'Scenery', 'Collision', 'Markers']) {
    if (!layerNames.has(name)) fail(`missing ${name} layer`);
  }
  if (layers.length !== 4) fail('expected exactly four map layers');
  const expectedLayers = [
    [1, 'Ground'],
    [2, 'Scenery'],
    [3, 'Collision'],
    [4, 'Markers'],
  ] as const;
  for (const [id, name] of expectedLayers) {
    const layer = layers.find((candidate) => candidate.name === name) as RecordValue;
    if (integer(layer.id, `${name}.id`) !== id) {
      fail(`${name} layer id must be ${id}`);
    }
    validateLayerMetadata(layer, name, name !== 'Ground');
  }
}

function validateTilesets(raw: RecordValue): void {
  const tilesets = array(raw.tilesets, 'tilesets');
  if (tilesets.length !== 2) fail('expected proof-ground and proof-scenery tilesets');
  const ground = validateTileset(tilesets[0], {
    name: 'proof-ground',
    firstgid: 1,
    columns: 2,
    image: '../sprites/proof-tiles.png',
    imageheight: 32,
    imagewidth: 128,
    tilecount: 2,
    tileheight: 32,
    tilewidth: 64,
  });
  validateTilesetSpacing(ground, 'proof-ground');
  const scenery = validateTileset(tilesets[1], {
    name: 'proof-scenery',
    firstgid: 3,
    columns: 2,
    image: '../sprites/proof-scenery.png',
    imageheight: 96,
    imagewidth: 192,
    tilecount: 2,
    tileheight: 96,
    tilewidth: 96,
  });
  validateTilesetSpacing(scenery, 'proof-scenery');
  if (string(scenery.objectalignment, 'proof-scenery.objectalignment') !== 'bottom') {
    fail('proof-scenery objectalignment must be bottom');
  }
  const grid = record(scenery.grid, 'proof-scenery.grid');
  if (string(grid.orientation, 'proof-scenery.grid.orientation') !== 'isometric') {
    fail('proof-scenery.grid.orientation must be isometric');
  }
  if (integer(grid.width, 'proof-scenery.grid.width') !== 64) {
    fail('proof-scenery.grid.width must be 64');
  }
  if (integer(grid.height, 'proof-scenery.grid.height') !== 32) {
    fail('proof-scenery.grid.height must be 32');
  }
}

function parseGroundLayer(raw: RecordValue, projection: ProjectionAdapter): GridCell[] {
  const layer = findLayer(raw, 'Ground');
  if (integer(layer.id, 'Ground.id') !== 1) fail('Ground layer id must be 1');
  if (string(layer.type, 'Ground.type') !== 'tilelayer') fail('Ground must be a tile layer');
  if (number(layer.x, 'Ground.x') !== 0 || number(layer.y, 'Ground.y') !== 0) {
    fail('Ground layer position must be 0,0');
  }
  if (integer(layer.width, 'Ground.width') !== projection.mapSize.width) {
    fail(`Ground.width must be ${projection.mapSize.width}`);
  }
  if (integer(layer.height, 'Ground.height') !== projection.mapSize.height) {
    fail(`Ground.height must be ${projection.mapSize.height}`);
  }
  const data = array(layer.data, 'Ground.data');
  const expectedLength = projection.mapSize.width * projection.mapSize.height;
  if (data.length !== expectedLength) fail(`Ground.data must contain ${expectedLength} cells`);
  const farmCells: GridCell[] = [];
  data.forEach((value, index) => {
    const gid = integer(value, `Ground.data[${index}]`);
    const x = index % projection.mapSize.width;
    const y = Math.floor(index / projection.mapSize.width);
    const expectedGid = x >= 2 && x <= 4 && y >= 7 && y <= 9 ? 2 : 1;
    if (gid !== expectedGid) {
      fail(`Ground.data[${index}] must be GID ${expectedGid}`);
    }
    if (gid === 2) {
      farmCells.push({ x, y });
    }
  });
  return farmCells;
}

function parseScenery(raw: RecordValue, projection: ProjectionAdapter): {
  scenery: SceneryPlacement[];
} {
  const layer = findLayer(raw, 'Scenery');
  if (integer(layer.id, 'Scenery.id') !== 2) fail('Scenery layer id must be 2');
  if (string(layer.type, 'Scenery.type') !== 'objectgroup') fail('Scenery must be an object layer');
  const objects = array(layer.objects, 'Scenery.objects').map((value, index) => record(value, `Scenery.objects[${index}]`));
  if (objects.length !== 2) fail('expected exactly tree and building scenery objects');
  const seen = new Set<string>();
  const scenery: SceneryPlacement[] = [];
  for (const object of objects) {
    const id = string(object.name, 'Scenery object.name');
    if (id !== 'tree' && id !== 'building') fail(`unknown scenery name ${id}`);
    if (seen.has(id)) fail(`duplicate scenery object ${id}`);
    seen.add(id);
    const kindValue = string(object.type, `scenery ${id}.type`);
    if (kindValue !== 'tree' && kindValue !== 'building') {
      fail(`unknown scenery kind ${kindValue}`);
    }
    if (kindValue !== id) fail(`scenery ${id} kind must match its name`);
    const gid = integer(object.gid, `scenery ${id}.gid`);
    const expectedGid = id === 'tree' ? 3 : 4;
    if (gid !== expectedGid) fail(`scenery ${id}.gid must be ${expectedGid}`);
    const expectedId = id === 'tree' ? 1 : 2;
    if (integer(object.id, `scenery ${id}.id`) !== expectedId) {
      fail(`scenery ${id}.id must be ${expectedId}`);
    }
    if (number(object.width, `scenery ${id}.width`) !== 96 || number(object.height, `scenery ${id}.height`) !== 96) {
      fail(`scenery ${id} dimensions must be 96x96`);
    }
    if (number(object.rotation, `scenery ${id}.rotation`) !== 0 || !boolean(object.visible, `scenery ${id}.visible`)) {
      fail(`scenery ${id} must be visible with zero rotation`);
    }
    const expectedWorld = projection.gridToWorld(id === 'tree' ? { x: 7.5, y: 4.5 } : { x: 9, y: 9 });
    const worldX = number(object.x, `scenery ${id}.x`);
    const worldY = number(object.y, `scenery ${id}.y`);
    if (worldX !== expectedWorld.x || worldY !== expectedWorld.y) {
      fail(`scenery ${id} must be at its authored ground position`);
    }
    scenery.push({
      id,
      kind: kindValue as SceneryKind,
      frame: gid - 3,
      world: { x: worldX, y: worldY },
      stableOrder: integer(object.id, `scenery ${id}.id`),
    });
  }
  scenery.sort((a, b) => a.stableOrder - b.stableOrder);
  if (!seen.has('tree') || !seen.has('building')) fail('expected tree and building scenery objects');
  return { scenery };
}

function parseFootprint(object: RecordValue, projection: ProjectionAdapter): Footprint {
  const name = string(object.name, 'Collision object.name');
  const x = number(object.x, `footprint ${name}.x`);
  const y = number(object.y, `footprint ${name}.y`);
  const polygon = array(object.polygon, `footprint ${name}.polygon`);
  if (polygon.length !== 4) fail(`footprint ${name} must have four polygon points`);
  const gridPoints = polygon.map((point, index) => {
    const relative = record(point, `footprint ${name}.polygon[${index}]`);
    return projection.worldToGrid({
      x: x + number(relative.x, `footprint ${name}.polygon[${index}].x`),
      y: y + number(relative.y, `footprint ${name}.polygon[${index}].y`),
    });
  }).map(({ x: gridX, y: gridY }) => ({ x: snap(gridX), y: snap(gridY) }));
  const uniquePoints = new Set(gridPoints.map(({ x: gridX, y: gridY }) => `${gridX},${gridY}`));
  const xs = [...new Set(gridPoints.map(({ x: gridX }) => gridX))].sort((a, b) => a - b);
  const ys = [...new Set(gridPoints.map(({ y: gridY }) => gridY))].sort((a, b) => a - b);
  if (uniquePoints.size !== 4 || xs.length !== 2 || ys.length !== 2) {
    fail(`footprint ${name} is not a logical rectangle`);
  }
  const expectedCorners = xs.flatMap((gridX) => ys.map((gridY) => `${gridX},${gridY}`));
  if (expectedCorners.some((corner) => !uniquePoints.has(corner))) {
    fail(`footprint ${name} is not a logical rectangle`);
  }
  const width = snap(xs[1] - xs[0]);
  const height = snap(ys[1] - ys[0]);
  if (width <= 0 || height <= 0) fail(`footprint ${name} must have positive dimensions`);
  return { id: name, x: xs[0], y: ys[0], width, height };
}

function parseCollision(raw: RecordValue, projection: ProjectionAdapter, scenery: SceneryPlacement[]): Footprint[] {
  const layer = findLayer(raw, 'Collision');
  if (integer(layer.id, 'Collision.id') !== 3) fail('Collision layer id must be 3');
  if (string(layer.type, 'Collision.type') !== 'objectgroup') fail('Collision must be an object layer');
  const objects = array(layer.objects, 'Collision.objects').map((value, index) => record(value, `Collision.objects[${index}]`));
  const footprints = objects.map((object) => {
    const name = string(object.name, 'Collision object.name');
    const expectedId = name === 'tree' ? 3 : name === 'building' ? 4 : -1;
    if (expectedId < 0) fail(`unknown collision footprint ${name}`);
    if (integer(object.id, `footprint ${name}.id`) !== expectedId) {
      fail(`footprint ${name}.id must be ${expectedId}`);
    }
    if (string(object.type, `footprint ${name}.type`) !== '') fail(`footprint ${name}.type must be empty`);
    if (number(object.rotation, `footprint ${name}.rotation`) !== 0 || !boolean(object.visible, `footprint ${name}.visible`)) {
      fail(`footprint ${name} must be visible with zero rotation`);
    }
    return parseFootprint(object, projection);
  });
  const byId = new Map(footprints.map((footprint) => [footprint.id, footprint]));
  for (const placement of scenery) {
    const footprint = byId.get(placement.id);
    if (!footprint) fail(`missing footprint for scenery ${placement.id}`);
    const expected = placement.id === 'tree' ? { width: 0.6, height: 0.6 } : { width: 2, height: 2 };
    if (footprint.width !== expected.width || footprint.height !== expected.height) {
      fail(`footprint ${placement.id} dimensions must be ${expected.width}x${expected.height}`);
    }
    const expectedPosition = placement.id === 'tree'
      ? { x: 7.2, y: 4.2 }
      : { x: 7, y: 7 };
    if (footprint.x !== expectedPosition.x || footprint.y !== expectedPosition.y) {
      fail(`footprint ${placement.id} is not at its authored logical position`);
    }
  }
  if (footprints.length !== scenery.length) fail('expected one collision footprint per scenery object');
  return scenery.map(({ id }) => byId.get(id) as Footprint);
}

function parseSpawn(raw: RecordValue, projection: ProjectionAdapter): { x: number; y: number } {
  const layer = findLayer(raw, 'Markers');
  if (integer(layer.id, 'Markers.id') !== 4) fail('Markers layer id must be 4');
  if (string(layer.type, 'Markers.type') !== 'objectgroup') fail('Markers must be an object layer');
  const objects = array(layer.objects, 'Markers.objects').map((value, index) => record(value, `Markers.objects[${index}]`));
  const spawns = objects.filter((object) => object.name === 'player-spawn');
  if (spawns.length !== 1) fail('expected exactly one player-spawn marker');
  const marker = spawns[0];
  if (integer(marker.id, 'player-spawn.id') !== 5) fail('player-spawn id must be 5');
  if (marker.point !== true) fail('player-spawn marker must be a point');
  if (string(marker.type, 'player-spawn.type') !== ''
    || number(marker.rotation, 'player-spawn.rotation') !== 0
    || !boolean(marker.visible, 'player-spawn.visible')) {
    fail('player-spawn marker must be visible with zero rotation and empty type');
  }
  const world = { x: number(marker.x, 'player-spawn.x'), y: number(marker.y, 'player-spawn.y') };
  const spawn = projection.worldToGrid(world);
  if (!Number.isFinite(spawn.x) || !Number.isFinite(spawn.y)
    || spawn.x < 0 || spawn.y < 0
    || spawn.x > projection.mapSize.width || spawn.y > projection.mapSize.height) {
    fail('player spawn is out of bounds');
  }
  const snapped = { x: snap(spawn.x), y: snap(spawn.y) };
  if (snapped.x !== 2.5 || snapped.y !== 9.5) fail('player spawn is not at its authored position');
  return snapped;
}

export function parseProofMap(raw: unknown, projection: ProjectionAdapter): ParsedProofMap {
  const map = record(raw, 'map');
  validateMapHeader(map, projection);
  validateTilesets(map);
  const farmCells = parseGroundLayer(map, projection);
  const { scenery } = parseScenery(map, projection);
  const footprints = parseCollision(map, projection, scenery);
  const spawn = parseSpawn(map, projection);
  return {
    world: {
      width: projection.mapSize.width,
      height: projection.mapSize.height,
      spawn,
      footprints,
    },
    scenery,
    farmCells,
    groundTilesetName: 'proof-ground',
  };
}
