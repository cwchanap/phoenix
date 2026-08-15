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

export type SceneryKind = 'tree' | 'building';

export interface SceneryPlacement {
  id: string;
  kind: SceneryKind;
  frame: number;
  world: WorldPoint;
  stableOrder: number;
}

export interface MovementInput {
  screenX: number;
  screenY: number;
}

export interface WorldSnapshot {
  player: { position: GridPoint; facing: Facing };
  target: GridCell | null;
}

export type FarmingAction = 'hoe' | 'turnipSeeds' | 'wateringCan' | 'hands';
export type GrowthLevel = 0 | 1 | 2 | 3;

export type Weather = 'sunny' | 'rainy';

export interface DaySummary {
  completedDay: number;
  nextDay: number;
  cropsAdvanced: number;
  nextWeather: Weather;
  staminaRestored: number;
}

export interface TurnipCropSnapshot {
  kind: 'turnip';
  growth: GrowthLevel;
  wateredToday: boolean;
}

export interface FarmTileSnapshot {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: TurnipCropSnapshot | null;
}

export interface InventorySnapshot {
  turnipSeeds: number;
  turnips: number;
}

export interface GameSnapshot extends WorldSnapshot {
  day: number;
  timeMinutes: number;
  stamina: number;
  maxStamina: number;
  weather: Weather;
  pendingDaySummary: DaySummary | null;
  selectedAction: FarmingAction;
  inventory: InventorySnapshot;
  farmTiles: FarmTileSnapshot[];
  bedCell: GridCell;
}

export type SuccessCode =
  | 'action-selected'
  | 'soil-tilled'
  | 'turnip-planted'
  | 'crop-watered'
  | 'turnip-harvested'
  | 'day-advanced'
  | 'day-started';

export type FailureCode =
  | 'no-target'
  | 'not-farm-cell'
  | 'already-tilled'
  | 'soil-untilled'
  | 'crop-present'
  | 'no-turnip-seeds'
  | 'no-crop'
  | 'already-watered'
  | 'crop-mature'
  | 'crop-immature'
  | 'not-at-bed'
  | 'action-too-late'
  | 'insufficient-stamina'
  | 'day-summary-pending'
  | 'rain-waters-crops'
  | 'day-limit-reached'
  | 'no-day-summary';

export type CommandResult =
  | { ok: true; code: SuccessCode }
  | { ok: false; code: FailureCode };
