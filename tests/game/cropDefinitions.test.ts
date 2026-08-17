import { describe, expect, test } from 'bun:test';
import {
  CROP_DEFINITIONS,
  CROP_KINDS,
  isMature,
  shipmentPayout,
  visualStage,
} from '../../src/game/core/cropDefinitions';

describe('cropDefinitions', () => {
  test('keeps exact stable crop content and profitable return order', () => {
    expect(CROP_KINDS).toEqual(['turnip', 'potato', 'pumpkin']);
    expect(CROP_DEFINITIONS).toEqual({
      turnip: { displayName: 'Turnip', growthDays: 3, seedPrice: 20, saleValue: 35 },
      potato: { displayName: 'Potato', growthDays: 5, seedPrice: 40, saleValue: 75 },
      pumpkin: { displayName: 'Pumpkin', growthDays: 7, seedPrice: 70, saleValue: 140 },
    });
    const profits = CROP_KINDS.map(
      (kind) => CROP_DEFINITIONS[kind].saleValue - CROP_DEFINITIONS[kind].seedPrice,
    );
    const profitPerNight = CROP_KINDS.map(
      (kind) => profits[CROP_KINDS.indexOf(kind)] / CROP_DEFINITIONS[kind].growthDays,
    );
    expect(profits).toEqual([15, 35, 70]);
    expect(profitPerNight).toEqual([5, 7, 10]);
  });

  test.each([
    ['turnip', [0, 1, 2, 3]],
    ['potato', [0, 0, 1, 1, 2, 3]],
    ['pumpkin', [0, 0, 0, 1, 1, 2, 2, 3]],
  ] as const)('maps every valid %s progress to four visual stages', (kind, expected) => {
    expect(expected.map((_stage, progress) => visualStage(kind, progress))).toEqual([...expected]);
  });

  test.each([
    ['turnip', 3],
    ['potato', 5],
    ['pumpkin', 7],
  ] as const)('uses the configured maturity for %s', (kind, matureProgress) => {
    expect(isMature(kind, matureProgress - 1)).toBe(false);
    expect(isMature(kind, matureProgress)).toBe(true);
  });

  test.each([
    ['turnip', -1],
    ['potato', 1.5],
    ['pumpkin', 8],
  ] as const)('rejects invalid %s progress %p', (kind, progress) => {
    expect(() => visualStage(kind, progress)).toThrow();
    expect(() => isMature(kind, progress)).toThrow();
  });

  test('creates stable nonzero payout lines and total without mutating counts', () => {
    const pending = { turnip: 2, potato: 1, pumpkin: 3 };
    expect(shipmentPayout(pending)).toEqual({
      lines: [
        { crop: 'turnip', quantity: 2, unitValue: 35, lineTotal: 70 },
        { crop: 'potato', quantity: 1, unitValue: 75, lineTotal: 75 },
        { crop: 'pumpkin', quantity: 3, unitValue: 140, lineTotal: 420 },
      ],
      total: 565,
    });
    expect(pending).toEqual({ turnip: 2, potato: 1, pumpkin: 3 });
  });

  test('omits zero counts, returns fresh data, and handles an empty shipment', () => {
    const first = shipmentPayout({ turnip: 0, potato: 2, pumpkin: 0 });
    const second = shipmentPayout({ turnip: 0, potato: 2, pumpkin: 0 });
    expect(first).toEqual({
      lines: [{ crop: 'potato', quantity: 2, unitValue: 75, lineTotal: 150 }],
      total: 150,
    });
    expect(second).toEqual(first);
    expect(second).not.toBe(first);
    expect(second.lines).not.toBe(first.lines);
    expect(second.lines[0]).not.toBe(first.lines[0]);
    expect(shipmentPayout({ turnip: 0, potato: 0, pumpkin: 0 })).toEqual({ lines: [], total: 0 });
  });

  test.each([-1, 1.5, Number.NaN])('rejects invalid shipment count %p', (quantity) => {
    expect(() => shipmentPayout({ turnip: quantity, potato: 0, pumpkin: 0 })).toThrow();
  });

  test('rejects unsafe payout arithmetic', () => {
    expect(() =>
      shipmentPayout({
        turnip: Number.MAX_SAFE_INTEGER,
        potato: 0,
        pumpkin: 0,
      }),
    ).toThrow();
  });
});
