import { expect, test } from 'bun:test';
import { fitStage } from '../../src/ui/stageScale';

test.each([
  [640, 360, { scale: 1, width: 640, height: 360, left: 0, top: 0 }],
  [1024, 768, { scale: 1, width: 640, height: 360, left: 192, top: 204 }],
  [1280, 720, { scale: 2, width: 1280, height: 720, left: 0, top: 0 }],
])('fits %ix%i with an integer scale', (width, height, expected) => {
  expect(fitStage(width, height)).toEqual(expected);
});

test('keeps the supported floor when the viewport is smaller than the stage', () => {
  expect(fitStage(639, 359)).toEqual({
    scale: 1,
    width: 640,
    height: 360,
    left: -1,
    top: -1,
  });
});

test('uses the next integer scale only when both dimensions fit', () => {
  expect(fitStage(1280, 719)).toEqual({
    scale: 1,
    width: 640,
    height: 360,
    left: 320,
    top: 179,
  });
  expect(fitStage(1280, 720)).toEqual({
    scale: 2,
    width: 1280,
    height: 720,
    left: 0,
    top: 0,
  });
});
