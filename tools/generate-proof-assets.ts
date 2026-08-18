import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { deflateSync } from 'node:zlib';
import type { GridPoint, WorldPoint } from '../src/game/core/types';
import { VILLAGER_IDS } from '../src/game/core/villagerDefinitions';

interface Surface {
  width: number;
  height: number;
  pixels: Uint8Array;
}

const createSurface = (width: number, height: number): Surface => ({
  width,
  height,
  pixels: new Uint8Array(width * height * 4),
});

const rgb = (hex: string) =>
  [
    Number.parseInt(hex.slice(1, 3), 16),
    Number.parseInt(hex.slice(3, 5), 16),
    Number.parseInt(hex.slice(5, 7), 16),
  ] as const;

function setPixel(surface: Surface, x: number, y: number, color: string): void {
  if (x < 0 || y < 0 || x >= surface.width || y >= surface.height) return;
  const offset = (y * surface.width + x) * 4;
  const [r, g, b] = rgb(color);
  surface.pixels.set([r, g, b, 255], offset);
}

function fillRect(
  surface: Surface,
  x: number,
  y: number,
  width: number,
  height: number,
  color: string,
): void {
  for (let py = y; py < y + height; py++) {
    for (let px = x; px < x + width; px++) setPixel(surface, px, py, color);
  }
}

function fillDiamond(
  surface: Surface,
  centerX: number,
  centerY: number,
  halfWidth: number,
  halfHeight: number,
  fill: string,
  outline: string,
): void {
  const borderStart = 1 - 1 / Math.min(halfWidth, halfHeight);
  for (let y = centerY - halfHeight; y < centerY + halfHeight; y++) {
    for (let x = centerX - halfWidth; x < centerX + halfWidth; x++) {
      const distance =
        Math.abs(x + 0.5 - centerX) / halfWidth + Math.abs(y + 0.5 - centerY) / halfHeight;
      if (distance <= 1) setPixel(surface, x, y, distance >= borderStart ? outline : fill);
    }
  }
}

function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const output = Buffer.alloc(12 + data.length);
  output.writeUInt32BE(data.length, 0);
  output.write(type, 4, 4, 'ascii');
  output.set(data, 8);
  output.writeUInt32BE(crc32(output.subarray(4, 8 + data.length)), 8 + data.length);
  return output;
}

async function writePng(path: string, surface: Surface): Promise<void> {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(surface.width, 0);
  ihdr.writeUInt32BE(surface.height, 4);
  ihdr.set([8, 6, 0, 0, 0], 8);
  const rowLength = surface.width * 4;
  const scanlines = Buffer.alloc((rowLength + 1) * surface.height);
  for (let y = 0; y < surface.height; y++) {
    scanlines[y * (rowLength + 1)] = 0;
    scanlines.set(
      surface.pixels.subarray(y * rowLength, (y + 1) * rowLength),
      y * (rowLength + 1) + 1,
    );
  }
  await mkdir(dirname(path), { recursive: true });
  await Bun.write(
    path,
    Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      chunk('IHDR', ihdr),
      chunk('IDAT', deflateSync(scanlines)),
      chunk('IEND', new Uint8Array()),
    ]),
  );
}

const project = ({ x, y }: GridPoint): WorldPoint => ({
  x: 384 + (x - y) * 32,
  y: (x + y) * 16,
});

const logicalPolygon = (
  id: number,
  name: string,
  minX: number,
  minY: number,
  maxX: number,
  maxY: number,
) => {
  const points = [
    project({ x: minX, y: minY }),
    project({ x: maxX, y: minY }),
    project({ x: maxX, y: maxY }),
    project({ x: minX, y: maxY }),
  ];
  return {
    id,
    name,
    type: '',
    x: points[0].x,
    y: points[0].y,
    polygon: points.map((point) => ({ x: point.x - points[0].x, y: point.y - points[0].y })),
    rotation: 0,
    visible: true,
  };
};

const tiles = createSurface(192, 32);
fillDiamond(tiles, 32, 16, 32, 16, '#76a85b', '#36563a');
fillDiamond(tiles, 96, 16, 32, 16, '#9a6a43', '#5d3d2b');
fillDiamond(tiles, 160, 16, 32, 16, '#c5a15d', '#755a35');

const player = createSurface(128, 48);
for (const [frame, marker] of ['#9fd8ff', '#ffd36b', '#f49c83', '#b7e48f'].entries()) {
  const x = frame * 32;
  fillRect(player, x + 12, 8, 8, 8, '#f0c7a5');
  fillRect(player, x + 10, 16, 12, 18, '#426c8d');
  fillRect(player, x + 8, 20, 4, 12, marker);
  fillRect(player, x + 12, 34, 3, 10, '#4a352d');
  fillRect(player, x + 18, 34, 3, 10, '#4a352d');
}

const scenery = createSurface(288, 96);
fillRect(scenery, 43, 60, 10, 36, '#6d432b');
fillRect(scenery, 24, 24, 48, 36, '#315f3b');
fillRect(scenery, 32, 12, 32, 20, '#3f7847');
fillRect(scenery, 16, 34, 64, 14, '#3f7847');
fillRect(scenery, 108, 50, 72, 46, '#d8b56d');
fillRect(scenery, 102, 42, 84, 10, '#704638');
fillRect(scenery, 110, 32, 68, 10, '#704638');
fillRect(scenery, 118, 22, 52, 10, '#704638');
fillRect(scenery, 138, 66, 14, 30, '#624331');
fillRect(scenery, 118, 62, 12, 12, '#8bc0cf');
fillRect(scenery, 160, 62, 12, 12, '#8bc0cf');
fillRect(scenery, 128, 50, 32, 12, '#f6d365');
fillRect(scenery, 134, 53, 20, 3, '#3f7847');
fillRect(scenery, 208, 58, 64, 30, '#8f5f3d');
fillRect(scenery, 204, 52, 72, 8, '#5d3d2b');
fillRect(scenery, 214, 64, 52, 8, '#b98552');
fillRect(scenery, 220, 88, 8, 8, '#4a352d');
fillRect(scenery, 252, 88, 8, 8, '#4a352d');

const villagerPalette = {
  shopkeeper: { accent: '#c96b5e', shirt: '#6b4e85' },
  farmer: { accent: '#d7a34a', shirt: '#537b58' },
  resident: { accent: '#7ab8c9', shirt: '#7d5d48' },
} as const;
const villagers = createSurface(VILLAGER_IDS.length * 32, 48);
for (const [frame, id] of VILLAGER_IDS.entries()) {
  const x = frame * 32;
  const palette = villagerPalette[id];
  fillRect(villagers, x + 12, 8, 8, 8, '#f0c7a5');
  fillRect(villagers, x + 10, 16, 12, 18, palette.shirt);
  fillRect(villagers, x + 8, 20, 4, 12, palette.accent);
  fillRect(villagers, x + 12, 34, 3, 10, '#4a352d');
  fillRect(villagers, x + 18, 34, 3, 10, '#4a352d');
}

const soil = createSurface(128, 32);
fillDiamond(soil, 32, 16, 32, 16, '#8a5a3b', '#5a3828');
fillDiamond(soil, 96, 16, 32, 16, '#526f54', '#334936');
fillRect(soil, 74, 12, 4, 2, '#7c9a77');
fillRect(soil, 106, 19, 5, 2, '#405c45');

const crops = createSurface(128, 144);
const cropPalettes = [
  { leaf: '#4f9c47', leafLight: '#68b454', root: '#e5b86b', outline: '#855531' },
  { leaf: '#4b8e43', leafLight: '#7ab45b', root: '#c99a58', outline: '#79502f' },
  { leaf: '#3f8041', leafLight: '#66a94c', root: '#e88738', outline: '#8a4c24' },
] as const;

cropPalettes.forEach((palette, cropIndex) => {
  const rowY = cropIndex * 48;
  for (let stage = 0; stage < 4; stage += 1) {
    const x = stage * 32;
    if (stage === 0) {
      fillRect(crops, x + 14, rowY + 34, 4 + cropIndex, 4, palette.root);
      continue;
    }
    fillRect(crops, x + 14, rowY + 25 - stage * 4, 4, 11 + stage * 4, palette.leaf);
    fillRect(
      crops,
      x + 7 - stage,
      rowY + 26 - stage * 3,
      9 + stage * 2,
      4 + stage,
      palette.leafLight,
    );
    fillRect(crops, x + 17, rowY + 22 - stage * 4, 7 + stage * 2, 4 + stage, palette.leaf);
    fillDiamond(
      crops,
      x + 16,
      rowY + 38,
      3 + stage * 2 + cropIndex,
      4 + stage * 2,
      palette.root,
      palette.outline,
    );
  }
});

const ground = Array.from({ length: 144 }, (_, index) => {
  const x = index % 12;
  const y = Math.floor(index / 12);
  return x >= 3 && x <= 9 && y === 6 ? 3 : x >= 2 && x <= 4 && y >= 7 && y <= 9 ? 2 : 1;
});

const tree = project({ x: 7.5, y: 4.5 });
const building = project({ x: 9, y: 9 });
const spawn = project({ x: 2.5, y: 9.5 });
const shippingBin = project({ x: 6.5, y: 10.5 });
const shopCounter = project({ x: 6.5, y: 7.5 });
const shippingMarker = project({ x: 6.5, y: 10.5 });
const treeRect = logicalPolygon(3, 'tree', 7.2, 4.2, 7.8, 4.8);
const buildingRect = logicalPolygon(4, 'building', 7, 7, 9, 9);
const shippingRect = logicalPolygon(8, 'shipping-bin', 6.2, 10.2, 6.8, 10.8);
const villagerAuthoring = {
  shopkeeper: {
    collision: logicalPolygon(11, 'villager-shopkeeper', 6.2, 5.2, 6.8, 5.8),
    marker: project({ x: 6.5, y: 5.5 }),
  },
  farmer: {
    collision: logicalPolygon(12, 'villager-farmer', 3.2, 5.2, 3.8, 5.8),
    marker: project({ x: 3.5, y: 5.5 }),
  },
  resident: {
    collision: logicalPolygon(13, 'villager-resident', 9.2, 5.2, 9.8, 5.8),
    marker: project({ x: 9.5, y: 5.5 }),
  },
} as const;
const villagerFootprints = VILLAGER_IDS.map((id) => villagerAuthoring[id].collision);

const groundTileset = {
  firstgid: 1,
  columns: 3,
  image: '../sprites/proof-tiles.png',
  imageheight: 32,
  imagewidth: 192,
  margin: 0,
  name: 'proof-ground',
  spacing: 0,
  tilecount: 3,
  tileheight: 32,
  tilewidth: 64,
};
const sceneryTileset = {
  firstgid: 4,
  columns: 3,
  image: '../sprites/proof-scenery.png',
  imageheight: 96,
  imagewidth: 288,
  margin: 0,
  name: 'proof-scenery',
  objectalignment: 'bottom',
  spacing: 0,
  tilecount: 3,
  tileheight: 96,
  tilewidth: 96,
  grid: { height: 32, orientation: 'isometric', width: 64 },
};

const groundLayer = {
  id: 1,
  name: 'Ground',
  type: 'tilelayer',
  x: 0,
  y: 0,
  width: 12,
  height: 12,
  opacity: 1,
  visible: true,
  data: ground,
};
const sceneryLayer = {
  id: 2,
  name: 'Scenery',
  type: 'objectgroup',
  draworder: 'topdown',
  opacity: 1,
  visible: true,
  objects: [
    {
      id: 1,
      name: 'tree',
      type: 'tree',
      gid: 4,
      x: tree.x,
      y: tree.y,
      width: 96,
      height: 96,
      rotation: 0,
      visible: true,
    },
    {
      id: 2,
      name: 'building',
      type: 'building',
      gid: 5,
      x: building.x,
      y: building.y,
      width: 96,
      height: 96,
      rotation: 0,
      visible: true,
    },
    {
      id: 7,
      name: 'shipping-bin',
      type: 'shipping-bin',
      gid: 6,
      x: shippingBin.x,
      y: shippingBin.y,
      width: 96,
      height: 96,
      rotation: 0,
      visible: true,
    },
  ],
};
const collisionLayer = {
  id: 3,
  name: 'Collision',
  type: 'objectgroup',
  draworder: 'topdown',
  opacity: 1,
  visible: true,
  objects: [treeRect, buildingRect, shippingRect, ...villagerFootprints],
};
const markerLayer = {
  id: 4,
  name: 'Markers',
  type: 'objectgroup',
  draworder: 'topdown',
  opacity: 1,
  visible: true,
  objects: [
    {
      id: 5,
      name: 'player-spawn',
      type: '',
      point: true,
      x: spawn.x,
      y: spawn.y,
      rotation: 0,
      visible: true,
    },
    {
      id: 6,
      name: 'bed-interaction',
      type: '',
      point: true,
      x: 320,
      y: 240,
      rotation: 0,
      visible: true,
    },
    {
      id: 9,
      name: 'shop-counter',
      type: '',
      point: true,
      x: shopCounter.x,
      y: shopCounter.y,
      rotation: 0,
      visible: true,
    },
    {
      id: 10,
      name: 'shipping-bin',
      type: '',
      point: true,
      x: shippingMarker.x,
      y: shippingMarker.y,
      rotation: 0,
      visible: true,
    },
    ...VILLAGER_IDS.map((id, frame) => {
      const marker = villagerAuthoring[id].marker;
      return {
        id: 14 + frame,
        name: `villager-${id}`,
        type: '',
        point: true,
        x: marker.x,
        y: marker.y,
        rotation: 0,
        visible: true,
      };
    }),
  ],
};

const map = {
  compressionlevel: -1,
  height: 12,
  infinite: false,
  nextlayerid: 5,
  nextobjectid: 17,
  orientation: 'isometric',
  renderorder: 'right-down',
  tiledversion: '1.12.2',
  tileheight: 32,
  tilewidth: 64,
  type: 'map',
  version: '1.10',
  width: 12,
  tilesets: [groundTileset, sceneryTileset],
  layers: [groundLayer, sceneryLayer, collisionLayer, markerLayer],
};

await writePng('src/assets/sprites/proof-tiles.png', tiles);
await writePng('src/assets/sprites/proof-player.png', player);
await writePng('src/assets/sprites/proof-scenery.png', scenery);
await writePng('src/assets/sprites/proof-villagers.png', villagers);
await writePng('src/assets/sprites/proof-soil.png', soil);
await writePng('src/assets/sprites/proof-crops.png', crops);
await Bun.write('src/assets/maps/proof-map.json', `${JSON.stringify(map, null, 2)}\n`);
