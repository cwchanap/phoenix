import {
  cellDiamond,
  gridCellAtWorld,
  gridToWorld,
  projectedMapBounds,
  worldToGrid,
} from '../core/isometric';
import type { GridCell, GridPoint, MapSize, ProjectionMetrics, WorldPoint } from '../core/types';

export class ProjectionAdapter {
  constructor(
    readonly metrics: ProjectionMetrics,
    readonly mapSize: MapSize,
  ) {}

  gridToWorld(point: GridPoint) {
    return gridToWorld(point, this.metrics);
  }
  worldToGrid(point: WorldPoint) {
    return worldToGrid(point, this.metrics);
  }
  gridCellAtWorld(point: WorldPoint) {
    return gridCellAtWorld(point, this.metrics);
  }
  cellDiamond(cell: GridCell) {
    return cellDiamond(cell, this.metrics);
  }
  projectedBounds(topPadding = 0) {
    return projectedMapBounds(this.mapSize, this.metrics, topPadding);
  }
}
