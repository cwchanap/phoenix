export interface GridPoint { x: number; y: number }
export interface GridCell { x: number; y: number }
export interface WorldPoint { x: number; y: number }
export interface WorldRect { x: number; y: number; width: number; height: number }
export interface MapSize { width: number; height: number }
export interface ProjectionMetrics {
  tileWidth: number;
  tileHeight: number;
  origin: WorldPoint;
}
export interface DepthEntry {
  id: string;
  groundY: number;
  stableOrder: number;
}

export type Facing = 'up' | 'right' | 'down' | 'left';

export interface Footprint {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ProofMap {
  width: number;
  height: number;
  spawn: GridPoint;
  footprints: Footprint[];
}

export interface MovementInput {
  screenX: number;
  screenY: number;
}

export interface WorldSnapshot {
  player: { position: GridPoint; facing: Facing };
  target: GridCell | null;
}
