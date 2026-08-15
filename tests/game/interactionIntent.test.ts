import { expect, test } from 'bun:test';
import { interactionIntentForTarget } from '../../src/game/phaser/interactionIntent';

const cells = {
  bedCell: { x: 6, y: 8 },
  shopCell: { x: 6, y: 7 },
  shippingCell: { x: 6, y: 10 },
};

test.each([
  [{ x: 6, y: 8 }, 'sleep'],
  [{ x: 6, y: 7 }, 'shop'],
  [{ x: 6, y: 10 }, 'shipping'],
  [{ x: 3, y: 8 }, null],
  [null, null],
] as const)('resolves target %p to %p', (target, expected) => {
  expect(interactionIntentForTarget(target, cells)).toBe(expected);
});
