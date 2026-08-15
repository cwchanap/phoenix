import type { GridCell } from '../core/types';

export type InteractionIntent = 'sleep' | 'shop' | 'shipping';

export interface InteractionCells {
  bedCell: GridCell;
  shopCell: GridCell;
  shippingCell: GridCell;
}

function sameCell(a: GridCell | null, b: GridCell): boolean {
  return a !== null && a.x === b.x && a.y === b.y;
}

export function interactionIntentForTarget(
  target: GridCell | null,
  cells: InteractionCells,
): InteractionIntent | null {
  if (sameCell(target, cells.bedCell)) return 'sleep';
  if (sameCell(target, cells.shopCell)) return 'shop';
  if (sameCell(target, cells.shippingCell)) return 'shipping';
  return null;
}
