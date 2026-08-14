import { expect, test } from 'bun:test';
import type Phaser from 'phaser';
import { InputGate } from '../../src/game/core/InputGate';
import { GateBoundKeys } from '../../src/game/phaser/GateBoundKeys';

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

function asPhaserKey(key: FakeKey): Phaser.Input.Keyboard.Key {
  return key as unknown as Phaser.Input.Keyboard.Key;
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

function makeKeys(plugin: FakePlugin | null = null): FakeKey[] {
  return [makeKey(plugin), makeKey(plugin), makeKey(plugin), makeKey(plugin)];
}

test('does not reset keys when constructed while the gate is unlocked', () => {
  const gate = new InputGate();
  const raw = makeKeys();
  let controllerResetCalls = 0;

  const bound = new GateBoundKeys(
    gate,
    raw.map(asPhaserKey),
    () => {
      controllerResetCalls += 1;
    },
  );

  expect(bound.isLocked()).toBe(false);
  expect(raw.map((key) => key.resetCalls)).toEqual([0, 0, 0, 0]);
  expect(controllerResetCalls).toBe(0);
  bound.destroy();
});

test('resets keys exactly once when constructed while the gate is locked', () => {
  const gate = new InputGate();
  gate.set('modal', true);
  const raw = makeKeys();
  let controllerResetCalls = 0;

  const bound = new GateBoundKeys(
    gate,
    raw.map(asPhaserKey),
    () => {
      controllerResetCalls += 1;
    },
  );

  expect(bound.isLocked()).toBe(true);
  expect(raw.map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);
  expect(controllerResetCalls).toBe(1);
  bound.destroy();
});

test('resets only on transitions into a locked state', () => {
  const gate = new InputGate();
  const raw = makeKeys();
  let controllerResetCalls = 0;
  const bound = new GateBoundKeys(
    gate,
    raw.map(asPhaserKey),
    () => {
      controllerResetCalls += 1;
    },
  );

  gate.set('modal', true);
  expect(raw.map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);
  expect(controllerResetCalls).toBe(1);

  gate.set('another-modal', true);
  gate.set('modal', false);
  expect(raw.map((key) => key.resetCalls)).toEqual([1, 1, 1, 1]);
  expect(controllerResetCalls).toBe(1);
  expect(bound.isLocked()).toBe(true);

  gate.set('another-modal', false);
  expect(bound.isLocked()).toBe(false);
  gate.set('modal', true);
  expect(raw.map((key) => key.resetCalls)).toEqual([2, 2, 2, 2]);
  expect(controllerResetCalls).toBe(2);
  bound.destroy();
});

test('destroy unsubscribes and is idempotent', () => {
  const gate = new InputGate();
  const raw = makeKeys();
  let controllerResetCalls = 0;
  const bound = new GateBoundKeys(
    gate,
    raw.map(asPhaserKey),
    () => {
      controllerResetCalls += 1;
    },
  );

  bound.destroy();
  bound.destroy();
  gate.set('modal', true);

  expect(raw.map((key) => key.resetCalls)).toEqual([0, 0, 0, 0]);
  expect(controllerResetCalls).toBe(0);
});

test('removes keys through their plugins with destruction and capture flags', () => {
  const gate = new InputGate();
  const plugin = makePlugin();
  const raw = makeKeys(plugin);
  const bound = new GateBoundKeys(gate, raw.map(asPhaserKey), () => undefined);

  bound.destroy();
  bound.destroy();

  expect(plugin.removeCalls).toHaveLength(4);
  expect(plugin.removeCalls.map(({ key }) => key)).toEqual(raw);
  expect(plugin.removeCalls.every(({ destroy, removeCapture }) => destroy && removeCapture)).toBe(true);
  expect(raw.map((key) => key.destroyCalls)).toEqual([0, 0, 0, 0]);
});

test('falls back to key.destroy when a plugin is unavailable', () => {
  const gate = new InputGate();
  const raw = makeKeys();
  const bound = new GateBoundKeys(gate, raw.map(asPhaserKey), () => undefined);

  bound.destroy();
  bound.destroy();

  expect(raw.map((key) => key.destroyCalls)).toEqual([1, 1, 1, 1]);
});
