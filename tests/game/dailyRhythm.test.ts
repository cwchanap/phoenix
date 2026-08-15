import { describe, expect, test } from 'bun:test';
import {
  ACTION_COSTS,
  evaluateActionBudget,
  formatTime,
  weatherFromRandom,
} from '../../src/game/core/dailyRhythm';

describe('dailyRhythm', () => {
  test('uses the exact exhaustive farming costs', () => {
    expect(ACTION_COSTS).toEqual({
      hoe: { minutes: 30, stamina: 3 },
      turnipSeeds: { minutes: 20, stamina: 1 },
      wateringCan: { minutes: 20, stamina: 2 },
      hands: { minutes: 20, stamina: 1 },
    });
  });

  test('allows exact cutoff and rejects a finish after cutoff', () => {
    const current = { timeMinutes: 1290, stamina: 20 };
    expect(evaluateActionBudget(current, 'hoe')).toEqual({
      ok: true,
      timeMinutes: 1320,
      stamina: 17,
    });
    expect(current).toEqual({ timeMinutes: 1290, stamina: 20 });
    expect(evaluateActionBudget({ timeMinutes: 1291, stamina: 20 }, 'hoe'))
      .toEqual({ ok: false, code: 'action-too-late' });
  });

  test('checks time before stamina', () => {
    expect(evaluateActionBudget({ timeMinutes: 1310, stamina: 0 }, 'hands'))
      .toEqual({ ok: false, code: 'action-too-late' });
    expect(evaluateActionBudget({ timeMinutes: 360, stamina: 0 }, 'hands'))
      .toEqual({ ok: false, code: 'insufficient-stamina' });
  });

  test.each([
    [0, '00:00'],
    [360, '06:00'],
    [1300, '21:40'],
    [1320, '22:00'],
    [1439, '23:59'],
  ] as const)('formats %i as %s', (minutes, expected) => {
    expect(formatTime(minutes)).toBe(expected);
  });

  test.each([-1, 1.5, Number.NaN])('rejects invalid time %p', (minutes) => {
    expect(() => formatTime(minutes)).toThrow();
  });

  test('uses an exact 25 percent rainy boundary', () => {
    expect(weatherFromRandom(0)).toBe('rainy');
    expect(weatherFromRandom(0.249999)).toBe('rainy');
    expect(weatherFromRandom(0.25)).toBe('sunny');
    expect(weatherFromRandom(0.999999)).toBe('sunny');
  });

  test.each([-0.001, 1, Number.NaN])('rejects invalid random value %p', (value) => {
    expect(() => weatherFromRandom(value)).toThrow();
  });
});
