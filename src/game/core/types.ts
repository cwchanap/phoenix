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
