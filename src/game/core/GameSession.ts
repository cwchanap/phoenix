import { intersects } from './collision';
import { ProofWorld } from './ProofWorld';
import type {
  CommandResult,
  FarmTileSnapshot,
  FarmingAction,
  Footprint,
  GameSnapshot,
  GridCell,
  GrowthLevel,
  InventorySnapshot,
  MovementInput,
  ProjectionMetrics,
  ProofMap,
  WorldSnapshot,
} from './types';

export interface GameSessionConfig {
  world: ProofMap;
  metrics: ProjectionMetrics;
  farmCells: GridCell[];
  bedCell: GridCell;
}

interface MutableTurnipCrop {
  kind: 'turnip';
  growth: GrowthLevel;
  wateredToday: boolean;
}

interface MutableFarmTile {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: MutableTurnipCrop | null;
}

type LookupResult = MutableFarmTile | { ok: false; code: 'no-target' | 'not-farm-cell' };

const STARTING_SEEDS = 3;
const REQUIRED_FARM_TILE_COUNT = 9;

export class GameSession {
  private readonly world: ProofWorld;
  private readonly farmTiles: MutableFarmTile[];
  private readonly farmTilesByKey: Map<string, MutableFarmTile>;
  private readonly bedCell: GridCell;
  private day = 1;
  private selectedAction: FarmingAction = 'hoe';
  private inventory: InventorySnapshot = { turnipSeeds: STARTING_SEEDS, turnips: 0 };

  constructor(config: GameSessionConfig) {
    const world = cloneProofMap(config.world);
    const metrics = cloneProjectionMetrics(config.metrics);
    const farmCells = config.farmCells.map((cell) => ({ ...cell }));
    const bedCell = { ...config.bedCell };

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
    this.farmTiles = farmCells
      .sort((a, b) => a.y - b.y || a.x - b.x)
      .map((position) => ({ position, soil: 'untilled', crop: null }));
    this.farmTilesByKey = new Map(this.farmTiles.map((tile) => [cellKey(tile.position), tile]));
  }

  stepMovement(input: MovementInput, deltaMs: number): void {
    this.world.step(input, deltaMs);
  }

  snapshot(): GameSnapshot {
    const worldSnapshot: WorldSnapshot = this.world.snapshot();
    return {
      ...worldSnapshot,
      day: this.day,
      selectedAction: this.selectedAction,
      inventory: { ...this.inventory },
      farmTiles: this.farmTiles.map((tile): FarmTileSnapshot => ({
        position: { ...tile.position },
        soil: tile.soil,
        crop: tile.crop ? { ...tile.crop } : null,
      })),
      bedCell: { ...this.bedCell },
    };
  }

  selectAction(action: FarmingAction): CommandResult {
    this.selectedAction = action;
    return { ok: true, code: 'action-selected' };
  }

  applySelectedAction(position: GridCell | null): CommandResult {
    switch (this.selectedAction) {
      case 'hoe': return this.hoe(position);
      case 'turnipSeeds': return this.plant(position);
      case 'wateringCan': return this.water(position);
      case 'hands': return this.harvest(position);
      default: return assertNever(this.selectedAction);
    }
  }

  hoe(position: GridCell | null): CommandResult {
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (tile.crop) return { ok: false, code: 'crop-present' };
    if (tile.soil === 'tilled') return { ok: false, code: 'already-tilled' };

    tile.soil = 'tilled';
    return { ok: true, code: 'soil-tilled' };
  }

  plant(position: GridCell | null): CommandResult {
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (tile.soil === 'untilled') return { ok: false, code: 'soil-untilled' };
    if (tile.crop) return { ok: false, code: 'crop-present' };
    if (this.inventory.turnipSeeds <= 0) return { ok: false, code: 'no-turnip-seeds' };

    tile.crop = { kind: 'turnip', growth: 0, wateredToday: false };
    this.inventory.turnipSeeds -= 1;
    return { ok: true, code: 'turnip-planted' };
  }

  water(position: GridCell | null): CommandResult {
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (!tile.crop) return { ok: false, code: 'no-crop' };
    if (tile.crop.growth === 3) return { ok: false, code: 'crop-mature' };
    if (tile.crop.wateredToday) return { ok: false, code: 'already-watered' };

    tile.crop.wateredToday = true;
    return { ok: true, code: 'crop-watered' };
  }

  harvest(position: GridCell | null): CommandResult {
    const tile = this.lookupTile(position);
    if (isLookupFailure(tile)) return tile;
    if (!tile.crop) return { ok: false, code: 'no-crop' };
    if (tile.crop.growth < 3) return { ok: false, code: 'crop-immature' };

    tile.crop = null;
    this.inventory.turnips += 1;
    return { ok: true, code: 'turnip-harvested' };
  }

  sleep(): CommandResult {
    const target = this.world.snapshot().target;
    if (!sameCell(target, this.bedCell)) return { ok: false, code: 'not-at-bed' };

    this.day += 1;
    for (const tile of this.farmTiles) {
      if (!tile.crop) continue;
      if (tile.crop.wateredToday && tile.crop.growth < 3) {
        tile.crop.growth = (tile.crop.growth + 1) as GrowthLevel;
      }
      tile.crop.wateredToday = false;
    }
    return { ok: true, code: 'day-advanced' };
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
