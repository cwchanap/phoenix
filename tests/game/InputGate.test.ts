import { expect, test } from 'bun:test';
import { InputGate } from '../../src/game/core/InputGate';

test('notifies only aggregate lock transitions', () => {
  const gate = new InputGate();
  const transitions: boolean[] = [];
  gate.subscribe((locked) => transitions.push(locked));

  gate.set('overlay', true);
  gate.set('window-blur', true);
  gate.set('overlay', false);
  gate.set('window-blur', false);

  expect(transitions).toEqual([true, false]);
  expect(gate.isLocked).toBe(false);
});

test('ignores empty reasons and removes unsubscribed listeners', () => {
  const gate = new InputGate();
  const transitions: boolean[] = [];
  const unsubscribe = gate.subscribe((locked) => transitions.push(locked));

  gate.set('', true);
  expect(gate.isLocked).toBe(false);
  expect(transitions).toEqual([]);

  unsubscribe();
  gate.set('overlay', true);
  gate.set('overlay', false);

  expect(gate.isLocked).toBe(false);
  expect(transitions).toEqual([]);
});
