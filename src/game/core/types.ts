export interface GridPoint {
  x: number;
  y: number;
}
export interface GridCell {
  x: number;
  y: number;
}
export interface WorldPoint {
  x: number;
  y: number;
}
export interface WorldRect {
  x: number;
  y: number;
  width: number;
  height: number;
}
export interface MapSize {
  width: number;
  height: number;
}
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

export type SceneryKind = 'tree' | 'building' | 'shipping-bin';

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

export type FarmingAction = 'hoe' | 'seeds' | 'wateringCan' | 'hands';

export type CropKind = 'turnip' | 'potato' | 'pumpkin';
export type CropCounts = Record<CropKind, number>;

export type VillagerId = 'shopkeeper' | 'farmer' | 'resident';
export type RelationshipLevel = 'stranger' | 'friend' | 'closeFriend';

export interface RelationshipSnapshot {
  points: number;
  level: RelationshipLevel;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}

export interface SocialFeedback {
  lines: string[];
  pointsGained: number;
  giftReaction: 'normal' | 'favourite' | null;
  closeFriendSequence: boolean;
}

export type TalkResult =
  | { ok: true; code: 'villager-talked'; social: SocialFeedback }
  | { ok: false; code: 'day-summary-pending' | 'not-at-villager' };

export type GiftResult =
  | { ok: true; code: 'crop-gifted'; social: SocialFeedback }
  | {
      ok: false;
      code: 'day-summary-pending' | 'not-at-villager' | 'gift-already-given' | 'insufficient-crops';
    };

export interface ShipmentLine {
  crop: CropKind;
  quantity: number;
  unitValue: number;
  lineTotal: number;
}

export type Weather = 'sunny' | 'rainy';

export interface DaySummary {
  completedDay: number;
  nextDay: number;
  cropsAdvanced: number;
  nextWeather: Weather;
  staminaRestored: number;
  shipments: ShipmentLine[];
  shippingIncome: number;
  moneyAfterShipping: number;
}

export interface CropSnapshot {
  kind: CropKind;
  growth: number;
  wateredToday: boolean;
}

export interface FarmTileSnapshot {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: CropSnapshot | null;
}

export interface InventorySnapshot {
  seeds: CropCounts;
  crops: CropCounts;
}

export interface GameSnapshot extends WorldSnapshot {
  day: number;
  timeMinutes: number;
  stamina: number;
  maxStamina: number;
  weather: Weather;
  pendingDaySummary: DaySummary | null;
  selectedAction: FarmingAction;
  selectedSeed: CropKind;
  money: number;
  inventory: InventorySnapshot;
  pendingShipment: CropCounts;
  farmTiles: FarmTileSnapshot[];
  relationships: Record<VillagerId, RelationshipSnapshot>;
  villagerCells: Record<VillagerId, GridCell>;
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
}

export type SuccessCode =
  | 'action-selected'
  | 'seed-selected'
  | 'soil-tilled'
  | 'crop-planted'
  | 'crop-watered'
  | 'crop-harvested'
  | 'seeds-purchased'
  | 'crop-deposited'
  | 'villager-talked'
  | 'crop-gifted'
  | 'day-advanced'
  | 'day-started';

export type FailureCode =
  | 'no-target'
  | 'not-farm-cell'
  | 'already-tilled'
  | 'soil-untilled'
  | 'crop-present'
  | 'no-selected-seeds'
  | 'no-crop'
  | 'already-watered'
  | 'crop-mature'
  | 'crop-immature'
  | 'nothing-to-interact'
  | 'not-at-bed'
  | 'not-at-shop'
  | 'not-at-shipping-bin'
  | 'not-at-villager'
  | 'gift-already-given'
  | 'invalid-quantity'
  | 'insufficient-funds'
  | 'insufficient-crops'
  | 'action-too-late'
  | 'insufficient-stamina'
  | 'day-summary-pending'
  | 'rain-waters-crops'
  | 'day-limit-reached'
  | 'no-day-summary';

export type CommandResult = { ok: true; code: SuccessCode } | { ok: false; code: FailureCode };
