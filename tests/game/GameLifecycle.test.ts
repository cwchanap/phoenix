import { expect, test } from 'bun:test';
import { GameLifecycle } from '../../src/game/phaser/GameLifecycle';

test('starting twice destroys the first game and owns only the second', () => {
  const destroyed: number[] = [];
  let nextId = 0;
  const lifecycle = new GameLifecycle(() => {
    const id = ++nextId;
    return {
      destroy: (removeCanvas: boolean) => {
        if (removeCanvas) destroyed.push(id);
      },
    };
  });
  const parent = {} as HTMLElement;

  lifecycle.start(parent, {} as never);
  lifecycle.start(parent, {} as never);

  expect(destroyed).toEqual([1]);
  lifecycle.stop();
  lifecycle.stop();
  expect(destroyed).toEqual([1, 2]);
});

test('a failed start rethrows without owning a game and allows a later start', () => {
  const destroyed: number[] = [];
  let nextId = 0;
  let shouldThrow = true;
  const lifecycle = new GameLifecycle(() => {
    const id = ++nextId;
    if (shouldThrow) {
      shouldThrow = false;
      throw new Error('factory failed');
    }
    return {
      destroy: (removeCanvas: boolean) => {
        if (removeCanvas) destroyed.push(id);
      },
    };
  });
  const parent = {} as HTMLElement;

  expect(() => lifecycle.start(parent, {} as never)).toThrow('factory failed');
  expect(destroyed).toEqual([]);

  lifecycle.start(parent, {} as never);
  lifecycle.stop();
  expect(destroyed).toEqual([2]);
});
