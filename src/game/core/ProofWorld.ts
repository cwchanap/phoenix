import { moveWithCollisions } from './collision';
import type {
  Facing,
  GridCell,
  GridPoint,
  MovementInput,
  ProjectionMetrics,
  ProofMap,
  WorldSnapshot,
} from './types';

const MOVE_SPEED = 96;
const MAX_FRAME_MS = 50;
const MAX_SUBSTEP_MS = 8;
const PLAYER_HALF_EXTENT = 0.18;

const TARGET_OFFSETS: Record<Facing, GridPoint> = {
  up: { x: -1, y: -1 },
  right: { x: 1, y: -1 },
  down: { x: 1, y: 1 },
  left: { x: -1, y: 1 },
};

export class ProofWorld {
  private readonly map: ProofMap;
  private readonly metrics: ProjectionMetrics;
  private position: GridPoint;
  private facing: Facing;

  constructor(map: ProofMap, metrics: ProjectionMetrics, initialFacing: Facing = 'down') {
    this.map = {
      ...map,
      spawn: { ...map.spawn },
      footprints: map.footprints.map((footprint) => ({ ...footprint })),
    };
    this.metrics = { ...metrics, origin: { ...metrics.origin } };
    this.position = { ...this.map.spawn };
    this.facing = initialFacing;
  }

  step(input: MovementInput, deltaMs: number): void {
    const { screenX, screenY } = input;
    const magnitude = Math.hypot(screenX, screenY);
    if (magnitude > 0) {
      this.facing =
        Math.abs(screenX) >= Math.abs(screenY)
          ? screenX > 0
            ? 'right'
            : 'left'
          : screenY > 0
            ? 'down'
            : 'up';
    }

    const normalizedX = magnitude > 0 ? screenX / magnitude : 0;
    const normalizedY = magnitude > 0 ? screenY / magnitude : 0;
    let remainingMs = Math.min(Math.max(deltaMs, 0), MAX_FRAME_MS);

    while (remainingMs > 0) {
      const stepMs = Math.min(remainingMs, MAX_SUBSTEP_MS);
      const projectedX = (normalizedX * MOVE_SPEED * stepMs) / 1000;
      const projectedY = (normalizedY * MOVE_SPEED * stepMs) / 1000;
      const gridDelta = {
        x: projectedX / this.metrics.tileWidth + projectedY / this.metrics.tileHeight,
        y: projectedY / this.metrics.tileHeight - projectedX / this.metrics.tileWidth,
      };
      this.position = moveWithCollisions(this.position, gridDelta, this.map, PLAYER_HALF_EXTENT);
      remainingMs -= stepMs;
    }
  }

  snapshot(): WorldSnapshot {
    const target = this.targetCell();
    return {
      player: {
        position: { ...this.position },
        facing: this.facing,
      },
      target: target ? { ...target } : null,
    };
  }

  private targetCell(): GridCell | null {
    const offset = TARGET_OFFSETS[this.facing];
    const target = {
      x: Math.floor(this.position.x) + offset.x,
      y: Math.floor(this.position.y) + offset.y,
    };
    if (target.x < 0 || target.x >= this.map.width || target.y < 0 || target.y >= this.map.height) {
      return null;
    }
    return target;
  }
}
