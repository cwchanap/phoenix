import { VILLAGER_IDS } from '../core/villagerDefinitions';
import type { GridCell, VillagerId } from '../core/types';

export type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };

export interface InteractionCells {
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
  villagerCells: Record<VillagerId, GridCell>;
}

function sameCell(a: GridCell | null, b: GridCell): boolean {
  return a !== null && a.x === b.x && a.y === b.y;
}

export function interactionIntentForTarget(
  target: GridCell | null,
  cells: InteractionCells,
): InteractionIntent | null {
  if (sameCell(target, cells.bedCell)) return { kind: 'sleep' };
  if (sameCell(target, cells.shopCell)) return { kind: 'shop' };
  if (sameCell(target, cells.shippingCell)) return { kind: 'shipping' };
  for (const villagerId of VILLAGER_IDS) {
    if (sameCell(target, cells.villagerCells[villagerId])) {
      return { kind: 'villager', villagerId };
    }
  }
  return null;
}
