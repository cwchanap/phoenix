import Phaser from 'phaser';
import proofMapRaw from '../../assets/maps/proof-map.json';
import type { InputGate } from '../core/InputGate';
import { ProofWorld } from '../core/ProofWorld';
import type {
  DepthEntry,
  Facing,
  GridCell,
  GridPoint,
  WorldPoint,
  WorldRect,
} from '../core/types';
import { sortDepthEntries } from '../core/isometric';
import { KeyboardController, type KeyboardKeys } from './KeyboardController';
import { ProjectionAdapter } from './ProjectionAdapter';
import { parseProofMap, type ParsedProofMap } from './loadProofMap';

const MAP_KEY = 'proof-map';
const GROUND_KEY = 'proof-tiles';
const PLAYER_KEY = 'proof-player';
const SCENERY_KEY = 'proof-scenery';
const PLAYER_DEPTH = 100;
const TARGET_DEPTH = 10;
const GROUND_DEPTH = 0;

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

export interface DebugSnapshot {
  player: { position: GridPoint; facing: Facing; world: WorldPoint };
  target: GridCell | null;
  visibleTarget: boolean;
  locked: boolean;
  depths: Record<'player' | 'tree' | 'building', number>;
  camera: { scrollX: number; scrollY: number; bounds: WorldRect };
}

export interface ProofSceneDependencies {
  inputGate: InputGate;
  onReady(): void;
  onError(error: Error): void;
  onSnapshot(snapshot: DebugSnapshot): void;
}

type EntityId = 'player' | 'tree' | 'building';

export class ProofScene extends Phaser.Scene {
  private readonly dependencies: ProofSceneDependencies;
  private failedAssetKey: string | null = null;
  private loaderErrorHandler: ((file: Phaser.Loader.File) => void) | null = null;
  private world: ProofWorld | null = null;
  private parsedMap: ParsedProofMap | null = null;
  private player: Phaser.GameObjects.Sprite | null = null;
  private target: Phaser.GameObjects.Graphics | null = null;
  private groundLayer: Phaser.Tilemaps.TilemapLayer | null = null;
  private keyboard: KeyboardController | null = null;
  private readonly scenery = new Map<'tree' | 'building', Phaser.GameObjects.Sprite>();
  private readonly cameraBounds = projection.projectedBounds(96);
  private depths: Record<EntityId, number> = {
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
      this.world = new ProofWorld(parsed.world, projection.metrics);
      for (const placement of parsed.scenery) {
        const sprite = this.add
          .sprite(placement.world.x, placement.world.y, SCENERY_KEY, placement.frame)
          .setOrigin(0.5, 1);
        this.scenery.set(placement.id as 'tree' | 'building', sprite);
      }

      const initial = this.world.snapshot();
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
      const keys: KeyboardKeys = {
        w: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W),
        a: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A),
        s: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S),
        d: keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D),
      };
      this.keyboard = new KeyboardController(keys, this.dependencies.inputGate);
      this.syncRenderState();
      this.dependencies.onReady();
    } catch (error) {
      this.dependencies.onError(error instanceof Error ? error : new Error(String(error)));
    }
  }

  update(_time: number, delta: number): void {
    if (!this.world || !this.keyboard || !this.player || !this.target) return;
    this.world.step(this.keyboard.sample(), delta);
    this.syncRenderState();
  }

  private syncRenderState(): void {
    if (!this.world || !this.player || !this.target) return;
    const worldSnapshot = this.world.snapshot();
    const playerWorld = projection.gridToWorld(worldSnapshot.player.position);
    this.player.setPosition(playerWorld.x, playerWorld.y);
    this.player.setFrame(PLAYER_FRAMES[worldSnapshot.player.facing]);

    const targetCell = worldSnapshot.target;
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

    this.depths = this.updateDepths(playerWorld.y);
    this.dependencies.onSnapshot({
      player: {
        position: { ...worldSnapshot.player.position },
        facing: worldSnapshot.player.facing,
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

  private updateDepths(playerGroundY: number): Record<EntityId, number> {
    const player = this.player;
    const tree = this.scenery.get('tree');
    const building = this.scenery.get('building');
    if (!player || !tree || !building) {
      return this.depths;
    }

    const entries: Array<DepthEntry & { sprite: Phaser.GameObjects.Sprite }> = [
      { id: 'player', groundY: playerGroundY, stableOrder: 0, sprite: player },
      { id: 'tree', groundY: tree.y, stableOrder: 1, sprite: tree },
      { id: 'building', groundY: building.y, stableOrder: 2, sprite: building },
    ];
    const result = {} as Record<EntityId, number>;
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
    this.detachLoaderErrorHandler();
  }

  private detachLoaderErrorHandler(): void {
    const handler = this.loaderErrorHandler;
    if (!handler) return;
    this.load.off(Phaser.Loader.Events.FILE_LOAD_ERROR, handler);
    this.loaderErrorHandler = null;
  }
}
