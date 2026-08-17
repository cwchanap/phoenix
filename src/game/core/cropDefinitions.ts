import type { CropCounts, CropKind, ShipmentLine } from './types';

export const CROP_KINDS = ['turnip', 'potato', 'pumpkin'] as const satisfies readonly CropKind[];

export interface CropDefinition {
  readonly displayName: string;
  readonly growthDays: number;
  readonly seedPrice: number;
  readonly saleValue: number;
}

export const CROP_DEFINITIONS = {
  turnip: { displayName: 'Turnip', growthDays: 3, seedPrice: 20, saleValue: 35 },
  potato: { displayName: 'Potato', growthDays: 5, seedPrice: 40, saleValue: 75 },
  pumpkin: { displayName: 'Pumpkin', growthDays: 7, seedPrice: 70, saleValue: 140 },
} as const satisfies Readonly<Record<CropKind, CropDefinition>>;

export type CropVisualStage = 0 | 1 | 2 | 3;

function assertProgress(kind: CropKind, progress: number): void {
  const growthDays = CROP_DEFINITIONS[kind].growthDays;
  if (!Number.isSafeInteger(progress) || progress < 0 || progress > growthDays) {
    throw new RangeError(`${kind} progress must be an integer from 0 through ${growthDays}`);
  }
}

export function visualStage(kind: CropKind, progress: number): CropVisualStage {
  assertProgress(kind, progress);
  return Math.min(
    3,
    Math.floor((progress * 3) / CROP_DEFINITIONS[kind].growthDays),
  ) as CropVisualStage;
}

export function isMature(kind: CropKind, progress: number): boolean {
  assertProgress(kind, progress);
  return progress === CROP_DEFINITIONS[kind].growthDays;
}

export function shipmentPayout(pending: CropCounts): { lines: ShipmentLine[]; total: number } {
  const lines: ShipmentLine[] = [];
  let total = 0;
  for (const crop of CROP_KINDS) {
    const quantity = pending[crop];
    if (!Number.isSafeInteger(quantity) || quantity < 0) {
      throw new RangeError(`${crop} shipment count must be a nonnegative safe integer`);
    }
    if (quantity === 0) continue;
    const unitValue = CROP_DEFINITIONS[crop].saleValue;
    const lineTotal = quantity * unitValue;
    const nextTotal = total + lineTotal;
    if (!Number.isSafeInteger(lineTotal) || !Number.isSafeInteger(nextTotal)) {
      throw new RangeError('shipment payout exceeds safe integer range');
    }
    lines.push({ crop, quantity, unitValue, lineTotal });
    total = nextTotal;
  }
  return { lines, total };
}
