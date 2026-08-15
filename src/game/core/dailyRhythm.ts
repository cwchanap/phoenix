import type { FarmingAction, Weather } from './types';

export const DAY_START_MINUTES = 360;
export const ACTION_CUTOFF_MINUTES = 1320;
export const MAX_STAMINA = 20;
export const MAX_DAY = 14;
export const RAIN_CHANCE = 0.25;

export interface ActionCost {
  readonly minutes: number;
  readonly stamina: number;
}

export interface ActionBudget {
  readonly timeMinutes: number;
  readonly stamina: number;
}

export type ActionBudgetResult =
  | { ok: true; timeMinutes: number; stamina: number }
  | { ok: false; code: 'action-too-late' | 'insufficient-stamina' };

export const ACTION_COSTS = {
  hoe: { minutes: 30, stamina: 3 },
  turnipSeeds: { minutes: 20, stamina: 1 },
  wateringCan: { minutes: 20, stamina: 2 },
  hands: { minutes: 20, stamina: 1 },
} as const satisfies Readonly<Record<FarmingAction, ActionCost>>;

export function evaluateActionBudget(
  current: ActionBudget,
  action: FarmingAction,
): ActionBudgetResult {
  const cost = ACTION_COSTS[action];
  const timeMinutes = current.timeMinutes + cost.minutes;
  if (timeMinutes > ACTION_CUTOFF_MINUTES) {
    return { ok: false, code: 'action-too-late' };
  }
  if (current.stamina < cost.stamina) {
    return { ok: false, code: 'insufficient-stamina' };
  }
  return {
    ok: true,
    timeMinutes,
    stamina: current.stamina - cost.stamina,
  };
}

export function formatTime(minutes: number): string {
  if (!Number.isInteger(minutes) || minutes < 0 || minutes > 1439) {
    throw new RangeError('minutes must be an integer from 0 through 1439');
  }
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return String(hours).padStart(2, '0') + ':' + String(remainder).padStart(2, '0');
}

export function weatherFromRandom(value: number): Weather {
  if (!Number.isFinite(value) || value < 0 || value >= 1) {
    throw new RangeError('random value must be in the interval [0, 1)');
  }
  return value < RAIN_CHANCE ? 'rainy' : 'sunny';
}

export function defaultNextWeather(): Weather {
  return weatherFromRandom(Math.random());
}
