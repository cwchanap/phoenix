import { expect, test } from 'bun:test';
import { InputGate } from '../../src/game/core/InputGate';
import { KeyboardController, type KeyboardKeys } from '../../src/game/phaser/KeyboardController';

interface FakeKey {
  isDown: boolean;
  resetCalls: number;
  destroyCalls: number;
  plugin: FakePlugin | null;
  reset(): void;
  destroy(): void;
}

interface FakePlugin {
  removeCalls: Array<{ key: FakeKey; destroy: boolean; removeCapture: boolean }>;
  removeKey(key: FakeKey, destroy: boolean, removeCapture: boolean): void;
}

function makeKey(plugin: FakePlugin | null = null): FakeKey {
  const key: FakeKey = {
    isDown: false,
    resetCalls: 0,
    destroyCalls: 0,
    plugin,
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

function makePlugin(): FakePlugin {
  return {
    removeCalls: [],
    removeKey(key, destroy, removeCapture) {
      this.removeCalls.push({ key, destroy, removeCapture });
    },
  };
}

function makeKeys(plugin: FakePlugin | null = null): {
  keys: KeyboardKeys;
  raw: Record<keyof KeyboardKeys, FakeKey>;
} {
  const raw = {
    w: makeKey(plugin),
    a: makeKey(plugin),
    s: makeKey(plugin),
    d: makeKey(plugin),
  };
  return { keys: raw as unknown as KeyboardKeys, raw };
}

test('samples unlocked WASD input', () => {
  const gate = new InputGate();
  const { keys } = makeKeys();
  const controller = new KeyboardController(keys, gate);

  keys.w.isDown = true;
  keys.d.isDown = true;

  expect(controller.sample()).toEqual({ screenX: 1, screenY: -1 });
  controller.destroy();
});

test('aggregate locking resets all keys and returns zero input', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new KeyboardController(keys, gate);

  for (const key of Object.values(raw)) key.isDown = true;
  gate.set('modal', true);

  expect(controller.sample()).toEqual({ screenX: 0, screenY: 0 });
  expect(Object.values(raw).map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);

  gate.set('another-modal', true);
  expect(Object.values(raw).map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);
  controller.destroy();
});

test('locked construction resets held WASD keys before the first sample', () => {
  const gate = new InputGate();
  gate.set('modal', true);
  const { keys, raw } = makeKeys();
  for (const key of Object.values(raw)) key.isDown = true;

  const controller = new KeyboardController(keys, gate);

  expect(controller.sample()).toEqual({ screenX: 0, screenY: 0 });
  expect(Object.values(raw).map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);
  controller.destroy();
});

test('destroy unsubscribes from future gate transitions', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys();
  const controller = new KeyboardController(keys, gate);

  controller.destroy();
  gate.set('modal', true);

  expect(Object.values(raw).map((key) => key.resetCalls)).toEqual([0, 0, 0, 0]);
});

test('destroy is idempotent and removes keys through their plugins', () => {
  const gate = new InputGate();
  const plugin = makePlugin();
  const { keys, raw } = makeKeys(plugin);
  const controller = new KeyboardController(keys, gate);

  controller.destroy();
  controller.destroy();

  expect(plugin.removeCalls).toHaveLength(4);
  expect(plugin.removeCalls.map(({ key }) => key)).toEqual(Object.values(raw));
  expect(plugin.removeCalls.every(({ destroy, removeCapture }) => destroy && removeCapture)).toBe(true);
  expect(Object.values(raw).map((key) => key.destroyCalls)).toEqual([0, 0, 0, 0]);
});

test('destroy falls back to key.destroy when a plugin is unavailable', () => {
  const gate = new InputGate();
  const { keys, raw } = makeKeys(null);
  const controller = new KeyboardController(keys, gate);

  expect(() => controller.destroy()).not.toThrow();
  controller.destroy();

  expect(Object.values(raw).map((key) => key.destroyCalls)).toEqual([1, 1, 1, 1]);
});
