import Phaser from 'phaser';
import proofMapRaw from '../../assets/maps/proof-map.json';
import { farmStableOrder, farmVisuals } from '../core/farmVisuals';
import { GameSession } from '../core/GameSession';
import type { InputGate } from '../core/InputGate';
import type {
  CommandResult,
  DepthEntry,
  Facing,
  FarmingAction,
  GameSnapshot,
  GridCell,
  GridPoint,
  WorldPoint,
  WorldRect,
} from '../core/types';
import { sortDepthEntries } from '../core/isometric';
import { ActionController, type ActionKeys } from './ActionController';
import { KeyboardController, type KeyboardKeys } from './KeyboardController';
import { ProjectionAdapter } from './ProjectionAdapter';
import { parseProofMap, type ParsedProofMap } from './loadProofMap';

const MAP_KEY = 'proof-map';
const GROUND_KEY = 'proof-tiles';
const PLAYER_KEY = 'proof-player';
const SCENERY_KEY = 'proof-scenery';
const SOIL_KEY = 'proof-soil';
const TURNIP_KEY = 'proof-turnip';
const PLAYER_DEPTH = 100;
const TARGET_DEPTH = 10;
const GROUND_DEPTH = 0;
const SOIL_DEPTH = 1;

const projection = new ProjectionAdapter(
  { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
  { width: 12, height: 12 },
);

const PLAYER_FRAMES: Record<Facing, number> = {
  up: 0,
  right: 1,
  down: 2,
  left: 3,
};

type BaseEntityId = 'player' | 'tree' | 'building';
type CropEntityId = `crop:${number},${number}`;
type EntityId = BaseEntityId | CropEntityId;

export type DebugDepths = Record<BaseEntityId, number> & Partial<Record<CropEntityId, number>>;

const debugDepthsCropMayBeMissing: DebugDepths['crop:3,8'] = undefined;

export interface DebugSnapshot {
  player: { position: GridPoint; facing: Facing; world: WorldPoint };
  target: GridCell | null;
  visibleTarget: boolean;
  locked: boolean;
  depths: DebugDepths;
  camera: { scrollX: number; scrollY: number; bounds: WorldRect };
}

export interface SceneCommands {
  selectAction(action: FarmingAction): CommandResult;
  sleep(): CommandResult;
}

export interface ProofSceneDependencies {
  inputGate: InputGate;
  onReady(commands: SceneCommands): void;
  onError(error: Error): void;
  onSnapshot(snapshot: DebugSnapshot): void;
  onGameSnapshot(snapshot: GameSnapshot): void;
  onCommandResult(result: CommandResult): void;
  onSleepPrompt(): void;
}

function cellKey(cell: GridCell): string {
  return `${cell.x},${cell.y}`;
}

function sameCell(a: GridCell | null, b: GridCell): boolean {
  return a !== null && a.x === b.x && a.y === b.y;
}

export class ProofScene extends Phaser.Scene {
  private readonly dependencies: ProofSceneDependencies;
  private failedAssetKey: string | null = null;
  private loaderErrorHandler: ((file: Phaser.Loader.File) => void) | null = null;
  private session: GameSession | null = null;
  private parsedMap: ParsedProofMap | null = null;
  private player: Phaser.GameObjects.Sprite | null = null;
  private target: Phaser.GameObjects.Graphics | null = null;
  private groundLayer: Phaser.Tilemaps.TilemapLayer | null = null;
  private keyboard: KeyboardController | null = null;
  private actionController: ActionController | null = null;
  private commands: SceneCommands | null = null;
  private readonly scenery = new Map<'tree' | 'building', Phaser.GameObjects.Sprite>();
  private readonly soilSprites = new Map<string, Phaser.GameObjects.Sprite>();
  private readonly cropSprites = new Map<string, Phaser.GameObjects.Sprite>();
  private readonly cameraBounds = projection.projectedBounds(96);
  private depths: DebugDepths = {
    player: PLAYER_DEPTH,
    tree: PLAYER_DEPTH + 1,
    building: PLAYER_DEPTH + 2,
  };

  constructor(dependencies: ProofSceneDependencies) {
    super({ key: 'ProofScene' });
    this.dependencies = dependencies;
  }

  preload(): void {
    this.failedAssetKey = null;
    this.loaderErrorHandler = (file) => {
      if (this.failedAssetKey === null) this.failedAssetKey = file.key;
    };
    this.load.on(Phaser.Loader.Events.FILE_LOAD_ERROR, this.loaderErrorHandler);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.cleanupResources());
    this.events.once(Phaser.Scenes.Events.DESTROY, () => this.cleanupResources());

    this.load.tilemapTiledJSON(
      MAP_KEY,
      new URL('../../assets/maps/proof-map.json', import.meta.url).href,
    );
    this.load.image(
      GROUND_KEY,
      new URL('../../assets/sprites/proof-tiles.png', import.meta.url).href,
    );
    this.load.spritesheet(
      PLAYER_KEY,
      new URL('../../assets/sprites/proof-player.png', import.meta.url).href,
      { frameWidth: 32, frameHeight: 48 },
    );
    this.load.spritesheet(
      SCENERY_KEY,
      new URL('../../assets/sprites/proof-scenery.png', import.meta.url).href,
      { frameWidth: 96, frameHeight: 96 },
    );
    this.load.spritesheet(
      SOIL_KEY,
      new URL('../../assets/sprites/proof-soil.png', import.meta.url).href,
      { frameWidth: 64, frameHeight: 32 },
    );
    this.load.spritesheet(
      TURNIP_KEY,
      new URL('../../assets/sprites/proof-turnip.png', import.meta.url).href,
      { frameWidth: 32, frameHeight: 48 },
    );
  }

  create(): void {
    try {
      if (this.failedAssetKey !== null) {
        throw new Error(`asset load failed: ${this.failedAssetKey}`);
      }

      const parsed = parseProofMap(proofMapRaw, projection);
      const map = this.make.tilemap({ key: MAP_KEY });
      const tileset = map.addTilesetImage(parsed.groundTilesetName, GROUND_KEY);
      if (!tileset) throw new Error('proof-map: failed to add ground tileset');
      const layer = map.createLayer('Ground', tileset, 384, 0, false);
      if (!layer) throw new Error('proof-map: failed to create ground layer');
      this.groundLayer = layer as Phaser.Tilemaps.TilemapLayer;
      this.groundLayer.setDepth(GROUND_DEPTH);

      this.parsedMap = parsed;
      this.session = new GameSession({
        world: parsed.world,
        metrics: projection.metrics,
        farmCells: parsed.farmCells,
        bedCell: parsed.bedCell,
      });
      for (const placement of parsed.scenery) {
        const sprite = this.add
          .sprite(placement.world.x, placement.world.y, SCENERY_KEY, placement.frame)
          .setOrigin(0.5, 1);
        this.scenery.set(placement.id as 'tree' | 'building', sprite);
      }

      const initial = this.session.snapshot();
      const initialWorld = projection.gridToWorld(initial.player.position);
      this.player = this.add
        .sprite(initialWorld.x, initialWorld.y, PLAYER_KEY, PLAYER_FRAMES[initial.player.facing])
        .setOrigin(0.5, 1);
      this.target = this.add.graphics().setDepth(TARGET_DEPTH).setVisible(false);

      this.cameras.main.setBounds(
        this.cameraBounds.x,
        this.cameraBounds.y,
        this.cameraBounds.width,
        this.cameraBounds.height,
      );
      this.cameras.main.startFollow(this.player, true, 0.12, 0.12);

      const keyboard = this.input.keyboard;
      if (!keyboard) throw new Error('keyboard input unavailable');
      const movementKeys: KeyboardKeys = {
        w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
        a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
        s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
        d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
      };
      const actionKeys: ActionKeys = {
        one: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ONE),
        two: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.TWO),
        three: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.THREE),
        four: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.FOUR),
        space: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE),
        e: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.E),
      };
      this.keyboard = new KeyboardController(movementKeys, this.dependencies.inputGate);
      this.actionController = new ActionController(actionKeys, this.dependencies.inputGate);
      const commands: SceneCommands = {
        selectAction: (action) => this.selectAction(action),
        sleep: () => this.sleep(),
      };
      this.commands = commands;

      this.reconcileFarmSprites(initial);
      this.dependencies.onGameSnapshot(initial);
      this.syncRenderState();
      this.dependencies.onReady(commands);
    } catch (error) {
      this.dependencies.onError(error instanceof Error ? error : new Error(String(error)));
    }
  }

  update(_time: number, delta: number): void {
    if (!this.session || !this.keyboard || !this.actionController || !this.player || !this.target) return;
    this.session.stepMovement(this.keyboard.sample(), delta);

    const action = this.actionController.sample();
    if (action.selectedAction !== null) {
      this.publishCommand(this.session.selectAction(action.selectedAction));
    }
    if (action.useSelected) {
      this.publishCommand(this.session.applySelectedAction(this.session.snapshot().target));
    }
    if (action.sleep) {
      const snapshot = this.session.snapshot();
      if (sameCell(snapshot.target, snapshot.bedCell)) {
        this.dependencies.onSleepPrompt();
      } else {
        this.publishCommand(this.session.sleep());
      }
    }

    this.syncRenderState();
  }

  private selectAction(action: FarmingAction): CommandResult {
    const session = this.requireSession();
    return this.publishCommand(session.selectAction(action));
  }

  private sleep(): CommandResult {
    const session = this.requireSession();
    return this.publishCommand(session.sleep());
  }

  private requireSession(): GameSession {
    if (!this.session) throw new Error('ProofScene session is not active');
    return this.session;
  }

  private publishCommand(result: CommandResult): CommandResult {
    const snapshot = this.requireSession().snapshot();
    this.reconcileFarmSprites(snapshot);
    this.dependencies.onCommandResult(result);
    this.dependencies.onGameSnapshot(snapshot);
    return result;
  }

  private reconcileFarmSprites(snapshot: GameSnapshot): void {
    const visibleSoil = new Set<string>();
    const visibleCrops = new Set<string>();
    for (const tile of snapshot.farmTiles) {
      const key = cellKey(tile.position);
      const frames = farmVisuals(tile);
      const center = projection.gridToWorld({
        x: tile.position.x + 0.5,
        y: tile.position.y + 0.5,
      });

      if (frames.soilFrame === null) {
        this.destroyFarmSprite(this.soilSprites, key);
      } else {
        visibleSoil.add(key);
        const existing = this.soilSprites.get(key);
        const sprite = existing ?? this.add.sprite(center.x, center.y, SOIL_KEY, frames.soilFrame)
          .setOrigin(0.5, 0.5);
        sprite.setPosition(center.x, center.y).setFrame(frames.soilFrame).setDepth(SOIL_DEPTH);
        if (!existing) this.soilSprites.set(key, sprite);
      }

      if (frames.cropFrame === null) {
        this.destroyFarmSprite(this.cropSprites, key);
      } else {
        visibleCrops.add(key);
        const existing = this.cropSprites.get(key);
        const sprite = existing ?? this.add.sprite(center.x, center.y, TURNIP_KEY, frames.cropFrame)
          .setOrigin(0.5, 1);
        sprite.setPosition(center.x, center.y).setFrame(frames.cropFrame);
        if (!existing) this.cropSprites.set(key, sprite);
      }
    }

    for (const key of this.soilSprites.keys()) {
      if (!visibleSoil.has(key)) this.destroyFarmSprite(this.soilSprites, key);
    }
    for (const key of this.cropSprites.keys()) {
      if (!visibleCrops.has(key)) this.destroyFarmSprite(this.cropSprites, key);
    }
  }

  private destroyFarmSprite(
    sprites: Map<string, Phaser.GameObjects.Sprite>,
    key: string,
  ): void {
    const sprite = sprites.get(key);
    if (!sprite) return;
    sprite.destroy();
    sprites.delete(key);
  }

  private syncRenderState(): void {
    if (!this.session || !this.player || !this.target) return;
    const snapshot = this.session.snapshot();
    const playerWorld = projection.gridToWorld(snapshot.player.position);
    this.player.setPosition(playerWorld.x, playerWorld.y);
    this.player.setFrame(PLAYER_FRAMES[snapshot.player.facing]);

    const targetCell = snapshot.target;
    this.target.clear();
    if (targetCell) {
      const points = projection.cellDiamond(targetCell);
      this.target
        .lineStyle(2, 0xf6d365, 1)
        .beginPath()
        .moveTo(points[0].x, points[0].y)
        .lineTo(points[1].x, points[1].y)
        .lineTo(points[2].x, points[2].y)
        .lineTo(points[3].x, points[3].y)
        .closePath()
        .strokePath()
        .setVisible(true);
    } else {
      this.target.setVisible(false);
    }

    this.depths = this.updateDepths(playerWorld.y, snapshot);
    this.dependencies.onSnapshot({
      player: {
        position: { ...snapshot.player.position },
        facing: snapshot.player.facing,
        world: { ...playerWorld },
      },
      target: targetCell ? { ...targetCell } : null,
      visibleTarget: targetCell !== null,
      locked: this.dependencies.inputGate.isLocked,
      depths: { ...this.depths },
      camera: {
        scrollX: this.cameras.main.scrollX,
        scrollY: this.cameras.main.scrollY,
        bounds: { ...this.cameraBounds },
      },
    });
  }

  private updateDepths(playerGroundY: number, snapshot: GameSnapshot): DebugDepths {
    const player = this.player;
    const tree = this.scenery.get('tree');
    const building = this.scenery.get('building');
    if (!player || !tree || !building) return this.depths;

    const entries: Array<DepthEntry & { sprite: Phaser.GameObjects.Sprite }> = [
      { id: 'player', groundY: playerGroundY, stableOrder: 0, sprite: player },
      { id: 'tree', groundY: tree.y, stableOrder: 1, sprite: tree },
      { id: 'building', groundY: building.y, stableOrder: 2, sprite: building },
    ];
    snapshot.farmTiles.forEach((tile, index) => {
      const crop = this.cropSprites.get(cellKey(tile.position));
      if (!crop) return;
      const footpoint = projection.gridToWorld({
        x: tile.position.x + 0.5,
        y: tile.position.y + 0.5,
      });
      entries.push({
        id: `crop:${tile.position.x},${tile.position.y}`,
        groundY: footpoint.y,
        stableOrder: farmStableOrder(index),
        sprite: crop,
      });
    });

    const result: DebugDepths = {
      player: this.depths.player,
      tree: this.depths.tree,
      building: this.depths.building,
    };
    const sortedEntries = sortDepthEntries(entries) as Array<DepthEntry & { sprite: Phaser.GameObjects.Sprite }>;
    sortedEntries.forEach((entry, index) => {
      const depth = PLAYER_DEPTH + index;
      entry.sprite.setDepth(depth);
      result[entry.id as EntityId] = depth;
    });
    return result;
  }

  private cleanupResources(): void {
    const keyboard = this.keyboard;
    this.keyboard = null;
    keyboard?.destroy();

    const actionController = this.actionController;
    this.actionController = null;
    actionController?.destroy();

    for (const sprite of this.soilSprites.values()) sprite.destroy();
    for (const sprite of this.cropSprites.values()) sprite.destroy();
    this.soilSprites.clear();
    this.cropSprites.clear();

    this.session = null;
    this.parsedMap = null;
    this.commands = null;
    this.detachLoaderErrorHandler();
  }

  private detachLoaderErrorHandler(): void {
    const handler = this.loaderErrorHandler;
    if (!handler) return;
    this.load.off(Phaser.Loader.Events.FILE_LOAD_ERROR, handler);
    this.loaderErrorHandler = null;
  }
}
