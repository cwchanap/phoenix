import { expect, test } from 'bun:test';
import { interactionIntentForTarget } from '../../src/game/phaser/interactionIntent';

const cells = {
  bedCell: { x: 6, y: 8 },
  shopCell: { x: 6, y: 7 },
  shippingCell: { x: 6, y: 10 },
  villagerCells: {
    shopkeeper: { x: 6, y: 5 },
    farmer: { x: 3, y: 5 },
    resident: { x: 9, y: 5 },
  },
};

test.each([
  [{ x: 6, y: 8 }, { kind: 'sleep' }],
  [{ x: 6, y: 7 }, { kind: 'shop' }],
  [{ x: 6, y: 10 }, { kind: 'shipping' }],
  [
    { x: 6, y: 5 },
    { kind: 'villager', villagerId: 'shopkeeper' },
  ],
  [
    { x: 3, y: 5 },
    { kind: 'villager', villagerId: 'farmer' },
  ],
  [
    { x: 9, y: 5 },
    { kind: 'villager', villagerId: 'resident' },
  ],
  [{ x: 3, y: 8 }, null],
  [null, null],
] as const)('resolves target %p to %p', (target, expected) => {
  expect(interactionIntentForTarget(target, cells)).toEqual(expected);
});
