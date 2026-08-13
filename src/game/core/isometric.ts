import type {
  DepthEntry,
  GridCell,
  GridPoint,
  MapSize,
  ProjectionMetrics,
  WorldPoint,
  WorldRect,
} from './types';

export function gridToWorld(point: GridPoint, m: ProjectionMetrics): WorldPoint {
  return {
    x: m.origin.x + (point.x - point.y) * (m.tileWidth / 2),
    y: m.origin.y + (point.x + point.y) * (m.tileHeight / 2),
  };
}

export function worldToGrid(point: WorldPoint, m: ProjectionMetrics): GridPoint {
  const x = point.x - m.origin.x;
  const y = point.y - m.origin.y;
  return {
    x: x / m.tileWidth + y / m.tileHeight,
    y: y / m.tileHeight - x / m.tileWidth,
  };
}

export function gridCellAtWorld(point: WorldPoint, m: ProjectionMetrics): GridCell {
  const logical = worldToGrid(point, m);
  return {
    x: Math.floor(logical.x + 1e-9),
    y: Math.floor(logical.y + 1e-9),
  };
}

export function cellDiamond(cell: GridCell, m: ProjectionMetrics): WorldPoint[] {
  return [
    gridToWorld({ x: cell.x, y: cell.y }, m),
    gridToWorld({ x: cell.x + 1, y: cell.y }, m),
    gridToWorld({ x: cell.x + 1, y: cell.y + 1 }, m),
    gridToWorld({ x: cell.x, y: cell.y + 1 }, m),
  ];
}

export function projectedMapBounds(
  size: MapSize,
  m: ProjectionMetrics,
  topPadding: number,
): WorldRect {
  const corners = [
    gridToWorld({ x: 0, y: 0 }, m),
    gridToWorld({ x: size.width, y: 0 }, m),
    gridToWorld({ x: size.width, y: size.height }, m),
    gridToWorld({ x: 0, y: size.height }, m),
  ];
  const minX = Math.min(...corners.map(({ x }) => x));
  const maxX = Math.max(...corners.map(({ x }) => x));
  const minY = Math.min(...corners.map(({ y }) => y));
  const maxY = Math.max(...corners.map(({ y }) => y));
  return {
    x: minX,
    y: minY - topPadding,
    width: maxX - minX,
    height: maxY - minY + topPadding,
  };
}

export function sortDepthEntries(entries: DepthEntry[]): DepthEntry[] {
  return [...entries].sort((a, b) => a.groundY - b.groundY || a.stableOrder - b.stableOrder);
}
