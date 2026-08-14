import { expect, test } from 'bun:test';
import type Phaser from 'phaser';
import { InputGate } from '../../src/game/core/InputGate';
import type { FarmingAction } from '../../src/game/core/types';
import {
  ActionController,
  type ActionKeys,
} from '../../src/game/phaser/ActionController';

interface FakeKey {
  isDown: boolean;
  resetCalls: number;
  destroyCalls: number;
  plugin: null;
  reset(): void;
  destroy(): void;
}

function makeKey(): FakeKey {
  const key: FakeKey = {
    isDown: false,
    resetCalls: 0,
    destroyCalls: 0,
    plugin: null,
    reset() {
      key.resetCalls += 1;
      key.isDown = false;
    },
    destroy() {
      key.destroyCalls += 1;
    },
  };
  return key;
}

function makeKeys(): {
  keys: ActionKeys;
  raw: Record<keyof ActionKeys, FakeKey>;
} {
  const raw = {
    one: makeKey(),
    two: makeKey(),
    three: makeKey(),
    four: makeKey(),
    space: makeKey(),
    e: makeKey(),
  };
  return {
    keys: raw as unknown as ActionKeys,
    raw,
  };
}

function keyFor(raw: Record<keyof ActionKeys, FakeKey>, action: FarmingAction): FakeKey {
  switch (action) {
    case 'hoe':
      return raw.one;
    case 'turnipSeeds':
      return raw.two;
    case 'wateringCan':
      return raw.three;
    case 'hands':
      return raw.four;
  }
}

test('returns no action edges when all action keys are up', () => {
  const gate = new InputGate();
  const { keys } = makeKeys();
  const controller = new ActionController(keys, gate);

  expect(controller.sample()).toEqual({
    selectedAction: null,
    useSelected: false,
    sleep: false,
  });
  controller.destroy();
});

test('emits each numeric action only on press edges', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new ActionController(keys, gate);
  const actions: FarmingAction[] = ['hoe', 'turnipSeeds', 'wateringCan', 'hands'];

  actions.forEach((action) => {
    const key = keyFor(raw, action);
    key.isDown = true;
    expect(controller.sample()).toEqual({
      selectedAction: action,
      useSelected: false,
      sleep: false,
    });
    expect(controller.sample()).toEqual({
      selectedAction: null,
      useSelected: false,
      sleep: false,
    });
    key.isDown = false;
    expect(controller.sample()).toEqual({
      selectedAction: null,
      useSelected: false,
      sleep: false,
    });
    key.isDown = true;
    expect(controller.sample()).toEqual({
      selectedAction: action,
      useSelected: false,
      sleep: false,
    });
    key.isDown = false;
    expect(controller.sample()).toEqual({
      selectedAction: null,
      useSelected: false,
      sleep: false,
    });
  });
  controller.destroy();
});

test('selects the first numeric rising edge when multiple keys press together', () => {
  const gate = new InputGate();
  const { keys } = makeKeys();
  const controller = new ActionController(keys, gate);

  (keys.one as unknown as FakeKey).isDown = true;
  (keys.two as unknown as FakeKey).isDown = true;
  expect(controller.sample().selectedAction).toBe('hoe');
  controller.destroy();
});

test('emits held Space and E keys only once until released', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new ActionController(keys, gate);

  raw.space.isDown = true;
  expect(controller.sample().useSelected).toBe(true);
  expect(controller.sample().useSelected).toBe(false);
  raw.space.isDown = false;
  expect(controller.sample().useSelected).toBe(false);
  raw.space.isDown = true;
  expect(controller.sample().useSelected).toBe(true);

  raw.space.isDown = false;
  raw.e.isDown = true;
  expect(controller.sample().sleep).toBe(true);
  expect(controller.sample().sleep).toBe(false);
  controller.destroy();
});

test('locking resets held key state and remembered edges before unlock', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new ActionController(keys, gate);

  raw.space.isDown = true;
  raw.e.isDown = true;
  expect(controller.sample()).toEqual({ selectedAction: null, useSelected: true, sleep: true });

  gate.set('modal', true);
  expect(Object.values(raw).map((key) => key.resetCalls)).toEqual([1, 1, 1, 1, 1, 1]);
  expect(Object.values(raw).every((key) => !key.isDown)).toBe(true);
  expect(controller.sample()).toEqual({ selectedAction: null, useSelected: false, sleep: false });

  gate.set('modal', false);
  expect(controller.sample()).toEqual({ selectedAction: null, useSelected: false, sleep: false });
  controller.destroy();
});

test('destroys all action keys idempotently', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new ActionController(keys, gate);

  controller.destroy();
  controller.destroy();

  expect(Object.values(raw).map((key) => key.destroyCalls)).toEqual([1, 1, 1, 1, 1, 1]);
});
