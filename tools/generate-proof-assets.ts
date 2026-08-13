import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { deflateSync } from 'node:zlib';
import type { GridPoint, WorldPoint } from '../src/game/core/types';

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

const rgb = (hex: string) => [
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
      const distance = Math.abs(x + 0.5 - centerX) / halfWidth
        + Math.abs(y + 0.5 - centerY) / halfHeight;
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
  await Bun.write(path, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(scanlines)),
    chunk('IEND', new Uint8Array()),
  ]));
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

const tiles = createSurface(128, 32);
fillDiamond(tiles, 32, 16, 32, 16, '#76a85b', '#36563a');
fillDiamond(tiles, 96, 16, 32, 16, '#9a6a43', '#5d3d2b');

const player = createSurface(128, 48);
for (const [frame, marker] of ['#9fd8ff', '#ffd36b', '#f49c83', '#b7e48f'].entries()) {
  const x = frame * 32;
  fillRect(player, x + 12, 8, 8, 8, '#f0c7a5');
  fillRect(player, x + 10, 16, 12, 18, '#426c8d');
  fillRect(player, x + 8, 20, 4, 12, marker);
  fillRect(player, x + 12, 34, 3, 10, '#4a352d');
  fillRect(player, x + 18, 34, 3, 10, '#4a352d');
}

const scenery = createSurface(192, 96);
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

const ground = Array.from({ length: 144 }, (_, index) => {
  const x = index % 12;
  const y = Math.floor(index / 12);
  return x >= 2 && x <= 4 && y >= 7 && y <= 9 ? 2 : 1;
});

const tree = project({ x: 7.5, y: 4.5 });
const building = project({ x: 9, y: 9 });
const spawn = project({ x: 2.5, y: 9.5 });
const treeRect = logicalPolygon(3, 'tree', 7.2, 4.2, 7.8, 4.8);
const buildingRect = logicalPolygon(4, 'building', 7, 7, 9, 9);

const groundTileset = {
  firstgid: 1,
  columns: 2,
  image: '../sprites/proof-tiles.png',
  imageheight: 32,
  imagewidth: 128,
  margin: 0,
  name: 'proof-ground',
  spacing: 0,
  tilecount: 2,
  tileheight: 32,
  tilewidth: 64,
};
const sceneryTileset = {
  firstgid: 3,
  columns: 2,
  image: '../sprites/proof-scenery.png',
  imageheight: 96,
  imagewidth: 192,
  margin: 0,
  name: 'proof-scenery',
  objectalignment: 'bottom',
  spacing: 0,
  tilecount: 2,
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
      gid: 3,
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
      gid: 4,
      x: building.x,
      y: building.y,
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
  objects: [treeRect, buildingRect],
};
const markerLayer = {
  id: 4,
  name: 'Markers',
  type: 'objectgroup',
  draworder: 'topdown',
  opacity: 1,
  visible: true,
  objects: [{
    id: 5,
    name: 'player-spawn',
    type: '',
    point: true,
    x: spawn.x,
    y: spawn.y,
    rotation: 0,
    visible: true,
  }],
};

const map = {
  compressionlevel: -1,
  height: 12,
  infinite: false,
  nextlayerid: 5,
  nextobjectid: 6,
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
await Bun.write('src/assets/maps/proof-map.json', `${JSON.stringify(map, null, 2)}\n`);
