import { intersects } from './collision';
import { CROP_DEFINITIONS, CROP_KINDS, isMature, shipmentPayout } from './cropDefinitions';
import {
  ACTION_CUTOFF_MINUTES,
  DAY_START_MINUTES,
  defaultNextWeather,
  evaluateActionBudget,
  MAX_DAY,
  MAX_STAMINA,
} from './dailyRhythm';
import { ProofWorld } from './ProofWorld';
import {
  closeFriendDialogueLines,
  dialogueLines,
  FAVOURITE_GIFT_BONUS,
  GIFT_POINTS,
  relationshipLevel,
  TALK_POINTS,
  VILLAGER_DEFINITIONS,
  VILLAGER_IDS,
} from './villagerDefinitions';
import type { ActionBudgetResult } from './dailyRhythm';
import type {
  CommandResult,
  CropCounts,
  CropKind,
  DaySummary,
  FarmTileSnapshot,
  FarmingAction,
  Footprint,
  GameSnapshot,
  GameState,
  GridCell,
  InventorySnapshot,
  MovementInput,
  ProjectionMetrics,
  ProofMap,
  GiftResult,
  RelationshipSnapshot,
  RelationshipState,
  TalkResult,
  VillagerId,
  Weather,
  WorldSnapshot,
} from './types';

export interface GameSessionConfig {
  world: ProofMap;
  metrics: ProjectionMetrics;
  farmCells: GridCell[];
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
  villagerCells: Record<VillagerId, GridCell>;
  nextWeather?: () => Weather;
  initialState?: GameState;
}

interface MutableCrop {
  kind: CropKind;
  growth: number;
  wateredToday: boolean;
}

interface MutableFarmTile {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: MutableCrop | null;
}

type LookupResult = MutableFarmTile | { ok: false; code: 'no-target' | 'not-farm-cell' };

const STARTING_MONEY = 150;
const STARTING_SEEDS: CropCounts = { turnip: 3, potato: 0, pumpkin: 0 };
const REQUIRED_FARM_TILE_COUNT = 9;

export class GameSession {
  private readonly world: ProofWorld;
  private readonly farmTiles: MutableFarmTile[];
  private readonly farmTilesByKey: Map<string, MutableFarmTile>;
  private readonly bedCell: GridCell;
  private readonly shopCell: GridCell;
  private readonly shippingCell: GridCell;
  private readonly villagerCells: Record<VillagerId, GridCell>;
  private readonly relationships: Record<VillagerId, RelationshipState>;
  private readonly nextWeather: () => Weather;
  private day = 1;
  private timeMinutes = DAY_START_MINUTES;
  private stamina = MAX_STAMINA;
  private readonly maxStamina = MAX_STAMINA;
  private weather: Weather = 'sunny';
  private pendingDaySummary: DaySummary | null = null;
  private selectedAction: FarmingAction = 'hoe';
  private selectedSeed: CropKind = 'turnip';
  private money = STARTING_MONEY;
  private inventory: InventorySnapshot = {
    seeds: cloneCounts(STARTING_SEEDS),
    crops: { turnip: 0, potato: 0, pumpkin: 0 },
  };
  private pendingShipment: CropCounts = { turnip: 0, potato: 0, pumpkin: 0 };

  constructor(config: GameSessionConfig) {
    this.nextWeather = config.nextWeather ?? defaultNextWeather;
    const world = cloneProofMap(config.world);
    const metrics = cloneProjectionMetrics(config.metrics);
    const farmCells = config.farmCells.map((cell) => ({ ...cell }));
    const bedCell = { ...config.bedCell };
    const shopCell = { ...config.shopCell };
    const shippingCell = { ...config.shippingCell };
    const villagerCells = cloneVillagerCells(config.villagerCells);

    if (farmCells.length !== REQUIRED_FARM_TILE_COUNT) {
      throw new Error(`GameSession: expected exactly ${REQUIRED_FARM_TILE_COUNT} farm cells`);
    }

    const keys = new Set<string>();
    for (const cell of farmCells) {
      const key = cellKey(cell);
      if (keys.has(key)) throw new Error(`GameSession: duplicate farm cell ${key}`);
      keys.add(key);
    }

    if (keys.has(cellKey(bedCell))) {
      throw new Error('GameSession: bed cell cannot also be a farm cell');
    }

    const interactionCells = [bedCell, shopCell, shippingCell];
    for (const cell of interactionCells) {
      if (
        !Number.isInteger(cell.x) ||
        !Number.isInteger(cell.y) ||
        cell.x < 0 ||
        cell.x >= world.width ||
        cell.y < 0 ||
        cell.y >= world.height
      ) {
        throw new Error('GameSession: interaction cells must be integer cells in bounds');
      }
    }
    if (new Set(interactionCells.map(cellKey)).size !== interactionCells.length) {
      throw new Error('GameSession: bed, shop, and shipping cells must be distinct');
    }

    const occupiedCells = new Set([...keys, ...interactionCells.map(cellKey)]);
    const villagerKeys = new Set<string>();
    for (const id of VILLAGER_IDS) {
      const cell = villagerCells[id];
      if (!isIntegerCellInBounds(cell, world)) {
        throw new Error('GameSession: villager cells must be integer cells in bounds');
      }
      const key = cellKey(cell);
      if (occupiedCells.has(key) || villagerKeys.has(key)) {
        throw new Error('GameSession: villager cells must be distinct from interactions');
      }
      villagerKeys.add(key);
    }

    const bedFootprint: Footprint = {
      id: 'bed-interaction',
      x: bedCell.x,
      y: bedCell.y,
      width: 1,
      height: 1,
    };
    if (world.footprints.some((footprint) => intersects(bedFootprint, footprint))) {
      throw new Error('GameSession: bed cell overlaps a collision footprint');
    }

    this.world = new ProofWorld(world, metrics);
    this.bedCell = bedCell;
    this.shopCell = shopCell;
    this.shippingCell = shippingCell;
    this.villagerCells = villagerCells;
    this.relationships = createRelationships();
    this.farmTiles = farmCells
      .sort((a, b) => a.y - b.y || a.x - b.x)
      .map((position) => ({ position, soil: 'untilled', crop: null }));
    this.farmTilesByKey = new Map(this.farmTiles.map((tile) => [cellKey(tile.position), tile]));
    if (config.initialState) this.restoreInitialState(config.initialState);
  }

  stepMovement(input: MovementInput, deltaMs: number): void {
    if (this.pendingDaySummary) return;
    this.world.step(input, deltaMs);
  }

  state(): GameState {
    return {
      day: this.day,
      timeMinutes: this.timeMinutes,
      stamina: this.stamina,
      weather: this.weather,
      pendingDaySummary: cloneDaySummary(this.pendingDaySummary),
      selectedAction: this.selectedAction,
      selectedSeed: this.selectedSeed,
      money: this.money,
      inventory: cloneInventory(this.inventory),
      pendingShipment: cloneCounts(this.pendingShipment),
      farmTiles: this.farmTiles.map(cloneFarmTile),
      relationships: cloneRelationshipState(this.relationships),
    };
  }

  snapshot(): GameSnapshot {
    const worldSnapshot: WorldSnapshot = this.world.snapshot();
    const state = this.state();
    return {
      ...worldSnapshot,
      ...state,
      maxStamina: this.maxStamina,
      relationships: cloneRelationships(this.relationships),
      villagerCells: cloneVillagerCells(this.villagerCells),
      bedCell: { ...this.bedCell },
      shopCell: { ...this.shopCell },
      shippingCell: { ...this.shippingCell },
    };
  }

  selectAction(action: FarmingAction): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    this.selectedAction = action;
    return { ok: true, code: 'action-selected' };
  }

  selectSeed(kind: CropKind): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    this.selectedSeed = kind;
    return { ok: true, code: 'seed-selected' };
  }

  buySeeds(kind: CropKind, quantity: number): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    if (!sameCell(this.world.snapshot().target, this.shopCell)) {
      return { ok: false, code: 'not-at-shop' };
    }
    const total = CROP_DEFINITIONS[kind].seedPrice * quantity;
    if (!Number.isSafeInteger(quantity) || quantity <= 0 || !Number.isSafeInteger(total)) {
      return { ok: false, code: 'invalid-quantity' };
    }
    if (this.money < total) return { ok: false, code: 'insufficient-funds' };
    this.money -= total;
    this.inventory.seeds[kind] += quantity;
    return { ok: true, code: 'seeds-purchased' };
  }

  depositCrop(kind: CropKind, quantity: number): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    if (!sameCell(this.world.snapshot().target, this.shippingCell)) {
      return { ok: false, code: 'not-at-shipping-bin' };
    }
    const pendingAfter = this.pendingShipment[kind] + quantity;
    if (!Number.isSafeInteger(quantity) || quantity <= 0 || !Number.isSafeInteger(pendingAfter)) {
      return { ok: false, code: 'invalid-quantity' };
    }
    if (this.inventory.crops[kind] < quantity) {
      return { ok: false, code: 'insufficient-crops' };
    }
    this.inventory.crops[kind] -= quantity;
    this.pendingShipment[kind] = pendingAfter;
    return { ok: true, code: 'crop-deposited' };
  }

  talkTo(id: VillagerId): TalkResult {
    if (this.pendingDaySummary) return { ok: false, code: 'day-summary-pending' };
    if (!sameCell(this.world.snapshot().target, this.villagerCells[id])) {
      return { ok: false, code: 'not-at-villager' };
    }

    const relationship = this.relationships[id];
    const pointsGained = relationship.talkedToday ? 0 : TALK_POINTS;
    if (!relationship.talkedToday) {
      relationship.talkedToday = true;
      relationship.points += TALK_POINTS;
    }

    const level = relationshipLevel(relationship.points);
    if (level === 'closeFriend' && !relationship.closeFriendDialogueSeen) {
      relationship.closeFriendDialogueSeen = true;
      return {
        ok: true,
        code: 'villager-talked',
        social: {
          lines: closeFriendDialogueLines(id),
          pointsGained,
          giftReaction: null,
          closeFriendSequence: true,
        },
      };
    }

    return {
      ok: true,
      code: 'villager-talked',
      social: {
        lines: dialogueLines(id, level),
        pointsGained,
        giftReaction: null,
        closeFriendSequence: false,
      },
    };
  }

  giftCrop(id: VillagerId, crop: CropKind): GiftResult {
    if (this.pendingDaySummary) return { ok: false, code: 'day-summary-pending' };
    if (!sameCell(this.world.snapshot().target, this.villagerCells[id])) {
      return { ok: false, code: 'not-at-villager' };
    }

    const relationship = this.relationships[id];
    if (relationship.giftedToday) return { ok: false, code: 'gift-already-given' };
    if (this.inventory.crops[crop] < 1) return { ok: false, code: 'insufficient-crops' };

    const favourite = VILLAGER_DEFINITIONS[id].favouriteCrop === crop;
    const pointsGained = GIFT_POINTS + (favourite ? FAVOURITE_GIFT_BONUS : 0);
    this.inventory.crops[crop] -= 1;
    relationship.giftedToday = true;
    relationship.points += pointsGained;

    return {
      ok: true,
      code: 'crop-gifted',
      social: {
        lines: [
          favourite ? VILLAGER_DEFINITIONS[id].favouriteGift : VILLAGER_DEFINITIONS[id].normalGift,
        ],
        pointsGained,
        giftReaction: favourite ? 'favourite' : 'normal',
        closeFriendSequence: false,
      },
    };
  }

  applySelectedAction(position: GridCell | null): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    switch (this.selectedAction) {
      case 'hoe':
        return this.hoe(position);
      case 'seeds':
        return this.plant(position);
      case 'wateringCan':
        return this.water(position);
      case 'hands':
        return this.harvest(position);
      default:
        return assertNever(this.selectedAction);
    }
  }

  hoe(position: GridCell | null): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (tile.crop) return { ok: false, code: 'crop-present' };
    if (tile.soil === 'tilled') return { ok: false, code: 'already-tilled' };

    const budget = this.evaluateBudget('hoe');
    if (!budget.ok) return budget;
    tile.soil = 'tilled';
    this.commitBudget(budget);
    return { ok: true, code: 'soil-tilled' };
  }

  plant(position: GridCell | null): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (tile.soil === 'untilled') return { ok: false, code: 'soil-untilled' };
    if (tile.crop) return { ok: false, code: 'crop-present' };
    if (this.inventory.seeds[this.selectedSeed] <= 0) {
      return { ok: false, code: 'no-selected-seeds' };
    }

    const budget = this.evaluateBudget('seeds');
    if (!budget.ok) return budget;
    tile.crop = { kind: this.selectedSeed, growth: 0, wateredToday: false };
    this.inventory.seeds[this.selectedSeed] -= 1;
    this.commitBudget(budget);
    return { ok: true, code: 'crop-planted' };
  }

  water(position: GridCell | null): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (!tile.crop) return { ok: false, code: 'no-crop' };
    if (isMature(tile.crop.kind, tile.crop.growth)) return { ok: false, code: 'crop-mature' };
    if (this.weather === 'rainy') return { ok: false, code: 'rain-waters-crops' };
    if (tile.crop.wateredToday) return { ok: false, code: 'already-watered' };

    const budget = this.evaluateBudget('wateringCan');
    if (!budget.ok) return budget;
    tile.crop.wateredToday = true;
    this.commitBudget(budget);
    return { ok: true, code: 'crop-watered' };
  }

  harvest(position: GridCell | null): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (!tile.crop) return { ok: false, code: 'no-crop' };
    if (!isMature(tile.crop.kind, tile.crop.growth)) return { ok: false, code: 'crop-immature' };

    const budget = this.evaluateBudget('hands');
    if (!budget.ok) return budget;
    const kind = tile.crop.kind;
    tile.crop = null;
    this.inventory.crops[kind] += 1;
    this.commitBudget(budget);
    return { ok: true, code: 'crop-harvested' };
  }

  sleep(): CommandResult {
    const activeFailure = this.activeDayFailure();
    if (activeFailure) return activeFailure;
    const target = this.world.snapshot().target;
    if (!sameCell(target, this.bedCell)) return { ok: false, code: 'not-at-bed' };
    if (this.day >= MAX_DAY) return { ok: false, code: 'day-limit-reached' };

    const completedDay = this.day;
    const completedWeather = this.weather;
    const staminaRestored = this.maxStamina - this.stamina;
    const nextWeather = this.nextWeather();
    if (nextWeather !== 'sunny' && nextWeather !== 'rainy') {
      throw new Error('GameSession: nextWeather returned an unsupported value');
    }
    const payout = shipmentPayout(this.pendingShipment);

    let cropsAdvanced = 0;
    for (const tile of this.farmTiles) {
      if (!tile.crop) continue;
      const watered = tile.crop.wateredToday || completedWeather === 'rainy';
      if (watered && !isMature(tile.crop.kind, tile.crop.growth)) {
        tile.crop.growth += 1;
        cropsAdvanced += 1;
      }
      tile.crop.wateredToday = false;
    }
    this.day += 1;
    this.timeMinutes = DAY_START_MINUTES;
    this.stamina = this.maxStamina;
    this.weather = nextWeather;
    this.money += payout.total;
    this.pendingShipment = { turnip: 0, potato: 0, pumpkin: 0 };
    this.pendingDaySummary = {
      completedDay,
      nextDay: this.day,
      cropsAdvanced,
      nextWeather,
      staminaRestored,
      shipments: payout.lines.map((line) => ({ ...line })),
      shippingIncome: payout.total,
      moneyAfterShipping: this.money,
    };
    for (const relationship of Object.values(this.relationships)) {
      relationship.talkedToday = false;
      relationship.giftedToday = false;
    }
    return { ok: true, code: 'day-advanced' };
  }

  acknowledgeDaySummary(): CommandResult {
    if (!this.pendingDaySummary) return { ok: false, code: 'no-day-summary' };
    this.pendingDaySummary = null;
    return { ok: true, code: 'day-started' };
  }

  private restoreInitialState(initialState: GameState): void {
    validateInitialStateInvariants(initialState);

    const savedKeys = new Set<string>();
    for (const tile of initialState.farmTiles) {
      const key = cellKey(tile.position);
      if (savedKeys.has(key)) invalidInitialState(`duplicate farm coordinate ${key}`);
      if (!this.farmTilesByKey.has(key)) invalidInitialState(`foreign farm coordinate ${key}`);
      savedKeys.add(key);
    }
    if (savedKeys.size !== this.farmTiles.length) {
      invalidInitialState('missing authored farm coordinate');
    }

    const restoredTiles = initialState.farmTiles.map(cloneFarmTile);
    this.farmTiles.splice(0, this.farmTiles.length, ...restoredTiles);
    this.farmTilesByKey.clear();
    for (const tile of this.farmTiles) {
      this.farmTilesByKey.set(cellKey(tile.position), tile);
    }

    this.day = initialState.day;
    this.timeMinutes = initialState.timeMinutes;
    this.stamina = initialState.stamina;
    this.weather = initialState.weather;
    this.pendingDaySummary = cloneDaySummary(initialState.pendingDaySummary);
    this.selectedAction = initialState.selectedAction;
    this.selectedSeed = initialState.selectedSeed;
    this.money = initialState.money;
    this.inventory = cloneInventory(initialState.inventory);
    this.pendingShipment = cloneCounts(initialState.pendingShipment);

    const restoredRelationships = cloneRelationshipState(initialState.relationships);
    for (const id of VILLAGER_IDS) {
      this.relationships[id] = restoredRelationships[id];
    }
  }

  private activeDayFailure(): CommandResult | null {
    return this.pendingDaySummary ? { ok: false, code: 'day-summary-pending' } : null;
  }

  private evaluateBudget(action: FarmingAction): ActionBudgetResult {
    return evaluateActionBudget({ timeMinutes: this.timeMinutes, stamina: this.stamina }, action);
  }

  private commitBudget(result: Extract<ActionBudgetResult, { ok: true }>): void {
    this.timeMinutes = result.timeMinutes;
    this.stamina = result.stamina;
  }

  private lookupTile(position: GridCell | null): LookupResult {
    if (position === null) return { ok: false, code: 'no-target' };
    return this.farmTilesByKey.get(cellKey(position)) ?? { ok: false, code: 'not-farm-cell' };
  }
}

function cloneProofMap(map: ProofMap): ProofMap {
  return {
    ...map,
    spawn: { ...map.spawn },
    footprints: map.footprints.map((footprint) => ({ ...footprint })),
  };
}

function cloneProjectionMetrics(metrics: ProjectionMetrics): ProjectionMetrics {
  return { ...metrics, origin: { ...metrics.origin } };
}

function cloneCounts(counts: CropCounts): CropCounts {
  return { turnip: counts.turnip, potato: counts.potato, pumpkin: counts.pumpkin };
}

function cloneFarmTile(tile: FarmTileSnapshot): MutableFarmTile {
  return {
    position: { ...tile.position },
    soil: tile.soil,
    crop: tile.crop ? { ...tile.crop } : null,
  };
}

function cloneDaySummary(summary: DaySummary | null): DaySummary | null {
  return summary ? { ...summary, shipments: summary.shipments.map((line) => ({ ...line })) } : null;
}

function cloneInventory(inventory: InventorySnapshot): InventorySnapshot {
  return {
    seeds: cloneCounts(inventory.seeds),
    crops: cloneCounts(inventory.crops),
  };
}

function cloneVillagerCells(cells: Record<VillagerId, GridCell>): Record<VillagerId, GridCell> {
  return Object.fromEntries(VILLAGER_IDS.map((id) => [id, { ...cells[id] }])) as Record<
    VillagerId,
    GridCell
  >;
}

function createRelationships(): Record<VillagerId, RelationshipState> {
  return Object.fromEntries(
    VILLAGER_IDS.map((id) => [
      id,
      { points: 0, talkedToday: false, giftedToday: false, closeFriendDialogueSeen: false },
    ]),
  ) as Record<VillagerId, RelationshipState>;
}

function cloneRelationshipState(
  relationships: Record<VillagerId, RelationshipState>,
): Record<VillagerId, RelationshipState> {
  return Object.fromEntries(VILLAGER_IDS.map((id) => [id, { ...relationships[id] }])) as Record<
    VillagerId,
    RelationshipState
  >;
}

function cloneRelationships(
  relationships: Record<VillagerId, RelationshipState>,
): Record<VillagerId, RelationshipSnapshot> {
  return Object.fromEntries(
    VILLAGER_IDS.map((id) => {
      const relationship = relationships[id];
      return [
        id,
        {
          points: relationship.points,
          level: relationshipLevel(relationship.points),
          talkedToday: relationship.talkedToday,
          giftedToday: relationship.giftedToday,
          closeFriendDialogueSeen: relationship.closeFriendDialogueSeen,
        },
      ];
    }),
  ) as Record<VillagerId, RelationshipSnapshot>;
}

function invalidInitialState(reason: string): never {
  throw new Error(`GameSession: invalid initial state ${reason}`);
}

function validateInitialStateInvariants(state: GameState): void {
  if (!Number.isSafeInteger(state.day) || state.day < 1 || state.day > MAX_DAY) {
    invalidInitialState('day is outside the current rule range');
  }
  if (
    !Number.isSafeInteger(state.timeMinutes) ||
    state.timeMinutes < DAY_START_MINUTES ||
    state.timeMinutes > ACTION_CUTOFF_MINUTES
  ) {
    invalidInitialState('time is outside the current rule range');
  }
  if (!Number.isSafeInteger(state.stamina) || state.stamina < 0 || state.stamina > MAX_STAMINA) {
    invalidInitialState('stamina is outside the current rule range');
  }
  assertNonnegativeSafeInteger(state.money, 'money must be a nonnegative safe integer');

  for (const kind of CROP_KINDS) {
    assertNonnegativeSafeInteger(
      state.inventory.seeds[kind],
      `${kind} seed count must be a nonnegative safe integer`,
    );
    assertNonnegativeSafeInteger(
      state.inventory.crops[kind],
      `${kind} crop count must be a nonnegative safe integer`,
    );
    assertNonnegativeSafeInteger(
      state.pendingShipment[kind],
      `${kind} shipment count must be a nonnegative safe integer`,
    );
  }

  for (const tile of state.farmTiles) {
    if (!tile.crop) continue;
    if (tile.soil !== 'tilled') invalidInitialState('crop on untilled soil');
    const growthDays = CROP_DEFINITIONS[tile.crop.kind].growthDays;
    if (
      !Number.isSafeInteger(tile.crop.growth) ||
      tile.crop.growth < 0 ||
      tile.crop.growth > growthDays
    ) {
      invalidInitialState(`crop growth for ${tile.crop.kind} is outside the current rule range`);
    }
  }

  for (const id of VILLAGER_IDS) {
    const relationship = state.relationships?.[id];
    if (!relationship) invalidInitialState(`missing relationship ${id}`);
    assertNonnegativeSafeInteger(
      relationship.points,
      `${id} relationship points must be a nonnegative safe integer`,
    );
  }

  if (state.pendingDaySummary) validatePendingDaySummary(state.pendingDaySummary, state);
}

function validatePendingDaySummary(summary: DaySummary, state: GameState): void {
  if (!Number.isSafeInteger(summary.completedDay) || summary.completedDay !== state.day - 1) {
    invalidInitialState('pending day summary completedDay does not precede restored day');
  }
  if (!Number.isSafeInteger(summary.nextDay) || summary.nextDay !== state.day) {
    invalidInitialState('pending day summary nextDay does not match restored day');
  }
  if (summary.nextWeather !== state.weather) {
    invalidInitialState('pending day summary nextWeather does not match restored weather');
  }
  if (
    !Number.isSafeInteger(summary.moneyAfterShipping) ||
    summary.moneyAfterShipping !== state.money
  ) {
    invalidInitialState('pending day summary moneyAfterShipping does not match restored money');
  }

  if (!Array.isArray(summary.shipments)) {
    invalidInitialState('pending day summary shipments must be an array');
  }
  let aggregate = 0;
  for (const line of summary.shipments) {
    if (!line || typeof line.crop !== 'string') {
      invalidInitialState('pending day summary shipment line is malformed');
    }
    if (!(CROP_KINDS as readonly string[]).includes(line.crop)) {
      invalidInitialState(`pending day summary shipment crop ${String(line.crop)} is unknown`);
    }
    const kind = line.crop as CropKind;
    if (!Number.isSafeInteger(line.quantity) || line.quantity <= 0) {
      invalidInitialState(
        `pending day summary ${kind} shipment quantity must be a positive safe integer`,
      );
    }
    if (line.unitValue !== CROP_DEFINITIONS[kind].saleValue) {
      invalidInitialState(
        `pending day summary ${kind} shipment unitValue does not match crop definition`,
      );
    }
    const expectedLineTotal = line.quantity * line.unitValue;
    if (!Number.isSafeInteger(expectedLineTotal) || line.lineTotal !== expectedLineTotal) {
      invalidInitialState(
        `pending day summary ${kind} shipment lineTotal does not match quantity * unitValue`,
      );
    }
    const nextAggregate = aggregate + line.lineTotal;
    if (!Number.isSafeInteger(nextAggregate)) {
      invalidInitialState('pending day summary shipping income exceeds safe integer range');
    }
    aggregate = nextAggregate;
  }
  if (!Number.isSafeInteger(summary.shippingIncome) || summary.shippingIncome !== aggregate) {
    invalidInitialState(
      'pending day summary shippingIncome does not match aggregate shipment line totals',
    );
  }

  for (const id of VILLAGER_IDS) {
    const relationship = state.relationships[id];
    if (relationship.talkedToday) {
      invalidInitialState(`pending day summary requires ${id} talkedToday to be reset`);
    }
    if (relationship.giftedToday) {
      invalidInitialState(`pending day summary requires ${id} giftedToday to be reset`);
    }
  }
}

function assertNonnegativeSafeInteger(value: number, reason: string): void {
  if (!Number.isSafeInteger(value) || value < 0) invalidInitialState(reason);
}

function isIntegerCellInBounds(cell: GridCell, world: ProofMap): boolean {
  return (
    Number.isInteger(cell?.x) &&
    Number.isInteger(cell?.y) &&
    cell.x >= 0 &&
    cell.x < world.width &&
    cell.y >= 0 &&
    cell.y < world.height
  );
}

function cellKey(cell: GridCell): string {
  return `${cell.x},${cell.y}`;
}

function sameCell(a: GridCell | null, b: GridCell): boolean {
  return a !== null && a.x === b.x && a.y === b.y;
}

function isLookupFailure(value: LookupResult): value is Exclude<LookupResult, MutableFarmTile> {
  return 'ok' in value;
}

function assertNever(value: never): never {
  throw new Error(`Unsupported farming action: ${String(value)}`);
}
