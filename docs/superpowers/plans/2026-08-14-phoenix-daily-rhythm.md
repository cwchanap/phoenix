# Phoenix Daily Rhythm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver HPA-592 as a repeatable 14-day farming rhythm with exact action time and stamina costs, sunny and rainy weather, one guarded sleep transition, and a blocking morning summary in the browser and macOS Tauri application.

**Architecture:** The existing framework-free GameSession remains the only mutable gameplay authority. A small dailyRhythm policy module owns fixed costs, budget evaluation, formatting, and weather selection; Phaser remains a rendering/input adapter; Svelte renders authoritative snapshots and owns one continuous day-transition input lock; Tauri remains an unchanged shell.

**Tech Stack:** Bun 1.3.1 and bun:test, TypeScript 7.0.2 through @typescript/native with TypeScript 6.0.3 for svelte-check --tsgo, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1 with retries disabled, Vite 8.2.1, Tauri 2.11.4, and Rust/Cargo 1.96 on macOS.

## Global Constraints

- Implement only HPA-592. Do not add money, shipping, shops, persistence, relationships, dialogue, new crops, seasons, forecasts, rain particles, a finale, or a generalized scheduler/stat/event framework.
- Preserve the ownership split: GameSession and pure TypeScript own gameplay; ProofWorld owns movement, collision, facing, and targeting; Phaser owns rendering and device input; Svelte owns presentation; Rust/Tauri remains a shell.
- Day 1 starts at 06:00 with timeMinutes 360, stamina 20, maxStamina 20, weather sunny, and pendingDaySummary null.
- Use exact action costs: hoe 30 minutes/3 stamina, turnipSeeds 20/1, wateringCan 20/2, and hands 20/1.
- A valid action ending exactly at 22:00 succeeds. A valid action ending after 22:00 returns action-too-late. Time failure precedes insufficient-stamina.
- Preserve every HPA-591 target/state validation prefix before budget evaluation. On Water, rain-waters-crops comes after no-crop and crop-mature but before already-watered.
- Walking and selection remain free. Expected failures preserve the complete GameSnapshot.
- Day 1 is sunny. Later days use the GameSession default 25 percent provider in production. ProofScene must omit nextWeather.
- Unit test config() injects nextWeather: () => 'sunny' unless a test explicitly exercises weather.
- Rain does not set wateredToday. It makes all tilled soil wet and every planted crop eligible to grow at sleep.
- Use one day-transition InputGate reason from confirmation open through summary acknowledgment. Remove sleep-confirmation rather than keeping two reasons.
- Day 14 is playable. Sleep at its bed returns day-limit-reached and does not consume weather or mutate state.
- Keep window.__PHOENIX_TEST__ observation-only. Do not add weather, clock, stamina, summary, or command mutation hooks.
- Use Bun as the only JavaScript package manager and bun:test as the only unit runner. Add no dependency.
- Run a genuine RED before production edits in each feature task, then focused GREEN, task-level regression checks, self-review, and a focused commit.
- For Svelte edits, load svelte:svelte-code-writer and svelte:svelte-core-bestpractices at execution time. Use only local analysis that does not send private source externally, and always finish with rtk bun run check.
- Browser actions enter through real keys and visible buttons. Playwright retries remain 0; do not hide flakes with retries, arbitrary sleeps, broad timeouts, direct session calls, or setters.
- macOS is the only native boundary. Report unsigned/ad-hoc packaging and any unproven native interaction accurately.

## File Map

### Pure policy and authoritative state

- Create: src/game/core/dailyRhythm.ts
- Modify: src/game/core/types.ts
- Modify: src/game/core/GameSession.ts
- Create: tests/game/dailyRhythm.test.ts
- Modify: tests/game/GameSession.test.ts

### Rendering and Phaser bridge

- Modify: src/game/core/farmVisuals.ts
- Modify: tests/game/farmVisuals.test.ts
- Modify: src/game/phaser/ProofScene.ts

### Svelte presentation

- Modify: src/App.svelte
- Modify: src/components/Overlay.svelte
- Modify: src/app.css

### Browser and handoff

- Modify: tests/e2e/helpers.ts
- Modify: tests/e2e/farming.pw.ts
- Modify: tests/e2e/sleep-confirmation.pw.ts
- Modify: tests/config/handoff.test.ts
- Modify: README.md

No change is planned for GameHost.svelte, vite-env.d.ts, the observation-hook shape, authored map JSON, generated sprites, Tauri configuration, Rust source, package.json, or bun.lock.

---

### Task 1: Pure Daily-Rhythm Policy

**Files:**

- Create: src/game/core/dailyRhythm.ts
- Modify: src/game/core/types.ts
- Create: tests/game/dailyRhythm.test.ts

**Interfaces:**

- Consumes: the existing FarmingAction type.
- Produces: Weather, DaySummary, ActionCost, ActionBudget, ActionBudgetResult, ACTION_COSTS, DAY_START_MINUTES, ACTION_CUTOFF_MINUTES, MAX_STAMINA, MAX_DAY, RAIN_CHANCE, evaluateActionBudget(), formatTime(), weatherFromRandom(), and defaultNextWeather().
- Preserves: all current GameSnapshot fields and CommandResult unions until Task 2 or Task 3 explicitly widens them.

- [ ] **Step 1: Write the failing policy tests**

Create tests/game/dailyRhythm.test.ts with these exact cases:

~~~ts
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
~~~

- [ ] **Step 2: Run the focused test and observe RED**

Run: rtk bun test tests/game/dailyRhythm.test.ts

Expected: FAIL because src/game/core/dailyRhythm.ts does not exist.

- [ ] **Step 3: Add shared weather and summary types**

Add these exact exports to src/game/core/types.ts beside GameSnapshot-related types:

~~~ts
export type Weather = 'sunny' | 'rainy';

export interface DaySummary {
  completedDay: number;
  nextDay: number;
  cropsAdvanced: number;
  nextWeather: Weather;
  staminaRestored: number;
}
~~~

Do not add the fields to GameSnapshot or widen CommandResult in this task.

- [ ] **Step 4: Implement the complete pure policy module**

Create src/game/core/dailyRhythm.ts:

~~~ts
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
~~~

- [ ] **Step 5: Run focused GREEN and mutation checks**

Run: rtk bun test tests/game/dailyRhythm.test.ts

Temporarily change the cutoff comparison from greater-than to greater-than-or-equal and rerun the focused test. Expected: the exact-22:00 case fails. Restore it.

Temporarily check stamina before time and rerun. Expected: the time-precedence case fails. Restore it.

- [ ] **Step 6: Run task-level regression checks**

Run:

- rtk bun test tests/game/dailyRhythm.test.ts tests/game/GameSession.test.ts
- rtk bun run check
- rtk git diff --check

Expected: all pass with zero static diagnostics.

- [ ] **Step 7: Self-review and commit Task 1**

Review for a parallel action enum, mutable policy object, default cost, framework import, invalid half-open boundary, or evaluator input mutation.

~~~bash
rtk git add src/game/core/types.ts src/game/core/dailyRhythm.ts tests/game/dailyRhythm.test.ts
rtk git commit -m "feat: add daily rhythm policy"
~~~

---

### Task 2: Authoritative Action Time and Stamina

**Files:**

- Modify: src/game/core/types.ts
- Modify: src/game/core/GameSession.ts
- Modify: tests/game/GameSession.test.ts
- Modify: src/components/Overlay.svelte

**Interfaces:**

- Consumes: evaluateActionBudget(), DAY_START_MINUTES, MAX_STAMINA, Weather, and DaySummary from Task 1.
- Produces: GameSnapshot.timeMinutes, stamina, maxStamina, weather, pendingDaySummary; action-too-late and insufficient-stamina failures; exact successful farming charges; sleep budget reset.
- Preserves: HPA-591 target/state validation ordering, selected-action dispatch, crop/inventory mutation, and direct pre-summary sleep behavior until Task 3.

- [ ] **Step 1: Add failing initial-budget and cost tests**

Extend tests/game/GameSession.test.ts. Assert:

~~~ts
expect(session.snapshot()).toMatchObject({
  day: 1,
  timeMinutes: 360,
  stamina: 20,
  maxStamina: 20,
  weather: 'sunny',
  pendingDaySummary: null,
});
~~~

Add one fresh-session path per action and capture before/after only that command:

- Hoe consumes 30 minutes and 3 stamina on a valid untilled cell.
- Plant consumes 20 minutes and 1 stamina after preparing tilled empty soil.
- Water consumes 20 minutes and 2 stamina after preparing a planted crop.
- Harvest consumes 20 minutes and 1 stamina after growing a crop with the current sleep helper.

Keep complete snapshot equality in every existing rejected farming test so the new budget fields prove no charge.

- [ ] **Step 2: Add reachable exhaustion and free-operation tests**

Hoe six distinct cells and assert timeMinutes 540 and stamina 2. Capture the snapshot, attempt a seventh valid Hoe, and assert:

~~~ts
expect(session.hoe(farmCells[6])).toEqual({
  ok: false,
  code: 'insufficient-stamina',
});
expect(session.snapshot()).toEqual(beforeSeventhHoe);
~~~

Capture budgets around selectAction and stepMovement and prove both are free. Spend stamina, use the current direct sleep transition, and prove the next day resets to 360 and 20.

- [ ] **Step 3: Run focused RED**

Run: rtk bun test tests/game/GameSession.test.ts

Expected: FAIL because snapshots lack budget fields and actions neither charge nor reject exhaustion.

- [ ] **Step 4: Widen snapshot and result types**

Add to GameSnapshot:

~~~ts
timeMinutes: number;
stamina: number;
maxStamina: number;
weather: Weather;
pendingDaySummary: DaySummary | null;
~~~

Add action-too-late and insufficient-stamina to FailureCode. Add exhaustive Overlay messages immediately:

~~~ts
case 'action-too-late': return 'Not enough time before 22:00';
case 'insufficient-stamina': return 'Not enough stamina';
~~~

- [ ] **Step 5: Add budget state and snapshot fields**

In GameSession:

~~~ts
private timeMinutes = DAY_START_MINUTES;
private stamina = MAX_STAMINA;
private readonly maxStamina = MAX_STAMINA;
private weather: Weather = 'sunny';
private pendingDaySummary: DaySummary | null = null;
~~~

Return all five fields from snapshot(), cloning pendingDaySummary when non-null.

- [ ] **Step 6: Apply the evaluator after each established state prefix**

Add:

~~~ts
private evaluateBudget(action: FarmingAction): ActionBudgetResult {
  return evaluateActionBudget({
    timeMinutes: this.timeMinutes,
    stamina: this.stamina,
  }, action);
}

private commitBudget(result: Extract<ActionBudgetResult, { ok: true }>): void {
  this.timeMinutes = result.timeMinutes;
  this.stamina = result.stamina;
}
~~~

Use exact mapping after current state checks:

- hoe() evaluates hoe, mutates soil, commits budget.
- plant() evaluates turnipSeeds, creates crop and consumes one seed, commits.
- water() evaluates wateringCan, sets wateredToday, commits.
- harvest() evaluates hands, removes crop and adds one turnip, commits.

Return failed evaluator results unchanged. Do not duplicate cutoff logic or add setters.

- [ ] **Step 7: Reset budget in the current sleep transition**

After the existing growth/reset loop and day increment:

~~~ts
this.timeMinutes = DAY_START_MINUTES;
this.stamina = this.maxStamina;
~~~

Do not choose weather or create/acknowledge summaries yet.

- [ ] **Step 8: Run focused GREEN and mutations**

Run: rtk bun test tests/game/GameSession.test.ts tests/game/dailyRhythm.test.ts

Temporarily evaluate one action before its state checks; an existing no-mutation rejection must fail. Restore it. Temporarily omit one commitBudget call; the exact-cost test must fail. Restore it.

- [ ] **Step 9: Run task-level verification**

Run:

- rtk bun test
- rtk bun run check
- rtk bun run build
- rtk git diff --check

Expected: all pass, with only the existing Phaser chunk advisory.

- [ ] **Step 10: Self-review and commit Task 2**

Review all four commands for exact mapping, established precedence, one charge, failure equality, free walking/selection, and absence of a clock setter.

~~~bash
rtk git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts src/components/Overlay.svelte
rtk git commit -m "feat: add farming time and stamina"
~~~

---

### Task 3: Weather, Guarded Sleep, and Morning-Summary Authority

**Files:**

- Modify: src/game/core/types.ts
- Modify: src/game/core/GameSession.ts
- Modify: tests/game/GameSession.test.ts
- Modify: src/components/Overlay.svelte

**Interfaces:**

- Consumes: Weather, DaySummary, defaultNextWeather(), DAY_START_MINUTES, MAX_STAMINA, and MAX_DAY.
- Produces: GameSessionConfig.nextWeather, rain-aware Water, activeDayFailure(), provider-first sleep, pendingDaySummary, acknowledgeDaySummary(), day-started, day-summary-pending, rain-waters-crops, day-limit-reached, and no-day-summary.
- Preserves: direct GameSession construction, ProofWorld target authority, in-place crop storage, and snapshot equality on expected failures.

- [ ] **Step 1: Make unit weather deterministic and add the complete day helper**

Change config() in tests/game/GameSession.test.ts so ordinary tests contain:

~~~ts
nextWeather: () => 'sunny',
~~~

Replace ordinary sleepAtBed calls with:

~~~ts
function advanceDayAtBed(session: GameSession): void {
  faceBed(session);
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
  expect(session.snapshot().pendingDaySummary).not.toBeNull();
  expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  expect(session.snapshot().pendingDaySummary).toBeNull();
}
~~~

Growth, maturity, and normal day tests use advanceDayAtBed. Pending-gate and duplicate-sleep tests call sleep() directly.

- [ ] **Step 2: Add failing summary and provider tests**

Use a counting provider that returns rainy. Hoe, plant, and water one crop, leaving stamina 14, then sleep at the bed. Assert:

~~~ts
expect(weatherCalls).toBe(1);
expect(session.snapshot()).toMatchObject({
  day: 2,
  timeMinutes: 360,
  stamina: 20,
  weather: 'rainy',
  pendingDaySummary: {
    completedDay: 1,
    nextDay: 2,
    cropsAdvanced: 1,
    nextWeather: 'rainy',
    staminaRestored: 6,
  },
});
~~~

Before acknowledgment, call sleep again and expect day-summary-pending, unchanged snapshot, and one provider call. Acknowledge once for day-started; a second acknowledgment returns no-day-summary without mutation.

- [ ] **Step 3: Add failing rain and active-gate tests**

Use provider results rainy then sunny:

1. Plant without watering on sunny Day 1.
2. Sleep; growth stays 0 and Day 2 weather becomes rainy.
3. Acknowledge.
4. Call Water; expect rain-waters-crops and complete snapshot equality.
5. Sleep; the rainy completed day advances growth to 1.

After a successful sleep but before acknowledgment, prove selectAction, applySelectedAction, hoe, plant, water, harvest, and sleep all return day-summary-pending without mutation. Call stepMovement with nonzero input and prove player position, facing, and target remain unchanged.

- [ ] **Step 4: Add failing Day 14 and provider-error tests**

Advance and acknowledge 13 times. On active Day 14, prove selection still works. At the bed capture state/call count, then assert:

~~~ts
expect(session.sleep()).toEqual({ ok: false, code: 'day-limit-reached' });
expect(session.snapshot()).toEqual(beforeFinalSleep);
expect(weatherCalls).toBe(13);
~~~

Prove not-at-bed sleep consumes no weather. With nextWeather returning 'stormy' as Weather, expect bed sleep to throw and preserve the complete snapshot.

- [ ] **Step 5: Run focused RED**

Run: rtk bun test tests/game/GameSession.test.ts

Expected: FAIL because nextWeather, summaries, acknowledgment, rain behavior, active gating, and the Day 14 boundary are absent.

- [ ] **Step 6: Add the stable result codes**

Add day-started to SuccessCode. Add day-summary-pending, rain-waters-crops, day-limit-reached, and no-day-summary to FailureCode.

Keep Overlay's switch exhaustive by adding:

~~~ts
case 'day-started': return 'Day started';
case 'day-summary-pending': return 'Start the new day first';
case 'rain-waters-crops': return 'Rain is watering the crops';
case 'day-limit-reached': return 'Day 14 is the final playable day for now';
case 'no-day-summary': return 'No morning summary to close';
~~~

- [ ] **Step 7: Add provider ownership and one shared command prefix**

Extend GameSessionConfig:

~~~ts
nextWeather?: () => Weather;
~~~

Store config.nextWeather ?? defaultNextWeather privately. Add:

~~~ts
private activeDayFailure(): CommandResult | null {
  return this.pendingDaySummary
    ? { ok: false, code: 'day-summary-pending' }
    : null;
}
~~~

Call it first in selectAction, applySelectedAction, hoe, plant, water, harvest, and sleep. stepMovement returns before ProofWorld.step when a summary exists. acknowledgeDaySummary is exempt.

- [ ] **Step 8: Insert rain at the exact Water precedence**

Water must use:

~~~ts
const tile = this.lookupTile(position);
if (isLookupFailure(tile)) return tile;
if (!tile.crop) return { ok: false, code: 'no-crop' };
if (tile.crop.growth === 3) return { ok: false, code: 'crop-mature' };
if (this.weather === 'rainy') return { ok: false, code: 'rain-waters-crops' };
if (tile.crop.wateredToday) return { ok: false, code: 'already-watered' };
~~~

Only then evaluate wateringCan and mutate.

- [ ] **Step 9: Implement the provider-first in-place transition**

Use the exact sleep guard order: activeDayFailure first, not-at-bed second, then day greater than or equal to MAX_DAY. Only after those pass:

~~~ts
const completedDay = this.day;
const completedWeather = this.weather;
const staminaRestored = this.maxStamina - this.stamina;
const nextWeather = this.nextWeather();
if (nextWeather !== 'sunny' && nextWeather !== 'rainy') {
  throw new Error('GameSession: nextWeather returned an unsupported value');
}

let cropsAdvanced = 0;
for (const tile of this.farmTiles) {
  if (!tile.crop) continue;
  const watered = tile.crop.wateredToday || completedWeather === 'rainy';
  if (watered && tile.crop.growth < 3) {
    tile.crop.growth = (tile.crop.growth + 1) as GrowthLevel;
    cropsAdvanced += 1;
  }
  tile.crop.wateredToday = false;
}

this.day += 1;
this.timeMinutes = DAY_START_MINUTES;
this.stamina = this.maxStamina;
this.weather = nextWeather;
this.pendingDaySummary = {
  completedDay,
  nextDay: this.day,
  cropsAdvanced,
  nextWeather,
  staminaRestored,
};
return { ok: true, code: 'day-advanced' };
~~~

Provider validation happens before mutation. Do not copy the farm array.

- [ ] **Step 10: Implement one-shot acknowledgment**

~~~ts
acknowledgeDaySummary(): CommandResult {
  if (!this.pendingDaySummary) {
    return { ok: false, code: 'no-day-summary' };
  }
  this.pendingDaySummary = null;
  return { ok: true, code: 'day-started' };
}
~~~

snapshot() returns a fresh summary object.

- [ ] **Step 11: Run focused GREEN and mutation evidence**

Run: rtk bun test tests/game/GameSession.test.ts tests/game/dailyRhythm.test.ts

Mutate and restore one at a time:

- Remove the selection active-day gate; its pending test fails.
- Call nextWeather twice; provider-count test fails.
- Remove rainy eligibility; rain-growth test fails.
- Remove MAX_DAY guard; Day 14 state/call count fails.

- [ ] **Step 12: Run task verification and record the staged E2E boundary**

Run:

- rtk bun test
- rtk bun run check
- rtk bun run build
- rtk git diff --check

Expected: unit/static/build green. Do not claim full Playwright yet: HPA-591 browser helpers do not acknowledge the new summary. Tasks 4–6 close this intentional integration gap; do not weaken the domain.

- [ ] **Step 13: Self-review and commit Task 3**

Review provider order/count, snapshot freshness, all command entries, movement no-op, Day 14, rain precedence, helper migration, and lack of a copied transition.

~~~bash
rtk git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts src/components/Overlay.svelte
rtk git commit -m "feat: add guarded daily transitions"
~~~

---

### Task 4: Rain Visuals and Phaser Summary Bridge

**Files:**

- Modify: src/game/core/farmVisuals.ts
- Modify: tests/game/farmVisuals.test.ts
- Modify: src/game/phaser/ProofScene.ts

**Interfaces:**

- Consumes: Weather, GameSnapshot.weather, GameSession.acknowledgeDaySummary(), and publishCommand().
- Produces: farmVisuals(tile, weather), rainy wet soil, SceneCommands.acknowledgeDaySummary(), and snapshot/result publication for acknowledgment.
- Preserves: sprite keys, crop frames/depths, lifecycle, observation-hook shape, and default weather ownership inside GameSession.

- [ ] **Step 1: Write failing required-weather visual tests**

Add exact rainy empty-soil, rainy dry-crop, sunny dry-crop, sunny watered-crop, untilled, every crop-growth, and stable-order cases. Representative required cases:

~~~ts
expect(farmVisuals(
  { position: { x: 2, y: 7 }, soil: 'tilled', crop: null },
  'rainy',
)).toEqual({ soilFrame: 1, cropFrame: null });

expect(farmVisuals(
  {
    position: { x: 2, y: 7 },
    soil: 'tilled',
    crop: { kind: 'turnip', growth: 2, wateredToday: false },
  },
  'sunny',
)).toEqual({ soilFrame: 0, cropFrame: 2 });
~~~

No Weather default is permitted.

- [ ] **Step 2: Run focused RED**

Run: rtk bun test tests/game/farmVisuals.test.ts

Expected: FAIL because farmVisuals accepts one argument and rainy empty soil is dry.

- [ ] **Step 3: Implement the mapper**

~~~ts
export function farmVisuals(
  tile: FarmTileSnapshot,
  weather: Weather,
): FarmVisualFrames {
  const wet = weather === 'rainy' || tile.crop?.wateredToday === true;
  return {
    soilFrame: tile.soil === 'untilled' ? null : wet ? 1 : 0,
    cropFrame: tile.crop?.growth ?? null,
  };
}
~~~

Run the focused test and require PASS.

- [ ] **Step 4: Widen the concrete SceneCommands facade**

Add:

~~~ts
acknowledgeDaySummary(): CommandResult;
~~~

Construct:

~~~ts
const commands: SceneCommands = {
  selectAction: (action) => this.selectAction(action),
  sleep: () => this.sleep(),
  acknowledgeDaySummary: () => this.acknowledgeDaySummary(),
};
~~~

Implement:

~~~ts
private acknowledgeDaySummary(): CommandResult {
  return this.publishCommand(this.requireSession().acknowledgeDaySummary());
}
~~~

Do not pass nextWeather to GameSession and do not expose the session/provider.

- [ ] **Step 5: Reconcile with snapshot weather**

In reconcileFarmSprites():

~~~ts
const frames = farmVisuals(tile, snapshot.weather);
~~~

Keep reconciliation on initial creation and publishCommand, not frame-driven.

- [ ] **Step 6: Run task verification**

Run:

- rtk bun test tests/game/farmVisuals.test.ts tests/game/GameSession.test.ts
- rtk bun test
- rtk bun run check
- rtk bun run build
- rtk git diff --check

Expected: all pass with only the existing chunk advisory. Add no Phaser Bun-test harness; Task 5/6 Playwright proves the bridge.

- [ ] **Step 7: Self-review and commit Task 4**

Review required Weather, rainy empty soil, unchanged crop frames, publishCommand reuse, no provider exposure, and one acknowledgment method.

~~~bash
rtk git add src/game/core/farmVisuals.ts tests/game/farmVisuals.test.ts src/game/phaser/ProofScene.ts
rtk git commit -m "feat: render rainy farm days"
~~~

---

### Task 5: Svelte Daily HUD and Continuous Two-Stage Modal

**Files:**

- Modify: src/App.svelte
- Modify: src/components/Overlay.svelte
- Modify: src/app.css
- Modify: tests/e2e/sleep-confirmation.pw.ts

**Interfaces:**

- Consumes: expanded GameSnapshot, formatTime(), widened SceneCommands, CommandResult, and InputGate.
- Produces: Day/Time/Stamina/Weather HUD, one dayTransitionActive presentation value, one day-transition gate reason, guarded sleep submission, authoritative morning summary, guarded acknowledgment, accessible focus, and exhaustive feedback.
- Preserves: HPA-591 action buttons, demonstration lock labels/reason, stage dimensions, fatal lifecycle handling, and observation-only hooks.

- [ ] **Step 1: Extend the sleep acceptance test before Svelte edits**

In tests/e2e/sleep-confirmation.pw.ts, retain the existing route, Cancel proof, and Confirm focus. Add initial assertions:

~~~ts
await expect(page.locator('[data-time]')).toHaveText('06:00');
await expect(page.locator('[data-stamina]')).toHaveText('20 / 20');
await expect(page.locator('[data-weather]')).toHaveText('Sunny');
~~~

Reopen the sleep dialog and issue a real double click:

~~~ts
await page.getByRole('button', { name: 'Confirm', exact: true })
  .click({ clickCount: 2 });
~~~

Then require one visible dialog named Morning summary. Read gameSnapshot() and assert day 2 plus non-null pendingDaySummary with completedDay 1, nextDay 2, cropsAdvanced 0, and staminaRestored 0. Assert debug snapshot locked is true; all four action buttons and the demonstration lock button are disabled; key 2 cannot change selection.

Assert Start Day 2 is focused. Click it once, then require the summary hidden, pendingDaySummary null, day still 2, and debug locked false.

- [ ] **Step 2: Run focused RED**

Run: rtk bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts

Expected: FAIL because the new HUD fields and morning summary are absent and the current finally path releases input immediately.

- [ ] **Step 3: Replace prompt-only gate state with one synchronized value**

In App.svelte add:

~~~ts
let sleepSubmitting = $state(false);
let summarySubmitting = $state(false);
let dayTransitionActive = $state(false);

function syncDayTransition(): void {
  dayTransitionActive = (
    sleepPromptVisible
    || sleepSubmitting
    || summarySubmitting
    || (gameSnapshot?.pendingDaySummary ?? null) !== null
  );
  inputGate.set('day-transition', dayTransitionActive);
}
~~~

Call syncDayTransition after every change to the four inputs. handleGameSnapshot assigns the snapshot then synchronizes. handleSleepPrompt returns when dayTransitionActive is true; otherwise it opens the prompt and synchronizes before returning.

Delete every sleep-confirmation InputGate call. resetGamePresentation and component teardown clear prompt/submission state, clear snapshots/commands as today, synchronize once, and explicitly set day-transition false as an idempotent final cleanup.

- [ ] **Step 4: Guard Confirm, Cancel, and Start Day**

Implement:

~~~ts
function confirmSleep(): void {
  if (!sleepPromptVisible || sleepSubmitting) return;
  const currentCommands = commands;
  if (!currentCommands) {
    sleepPromptVisible = false;
    syncDayTransition();
    return;
  }

  sleepSubmitting = true;
  syncDayTransition();
  try {
    currentCommands.sleep();
  } finally {
    sleepSubmitting = false;
    sleepPromptVisible = false;
    syncDayTransition();
  }
}

function cancelSleep(): void {
  if (sleepSubmitting) return;
  sleepPromptVisible = false;
  syncDayTransition();
}

function startDay(): void {
  if (!gameSnapshot?.pendingDaySummary || summarySubmitting || !commands) return;
  summarySubmitting = true;
  syncDayTransition();
  try {
    commands.acknowledgeDaySummary();
  } finally {
    summarySubmitting = false;
    syncDayTransition();
  }
}
~~~

The command callbacks publish snapshots synchronously, so the prompt closes only after pendingDaySummary has been observed. The same reason remains locked without a false transition.

- [ ] **Step 5: Expand Overlay's exact props and readiness**

Add props:

~~~ts
dayTransitionActive: boolean;
sleepSubmitting: boolean;
summarySubmitting: boolean;
onStartDay: () => void;
~~~

Set actionsReady only when ready and dayTransitionActive is false. The demonstration toggle returns immediately when dayTransitionActive and its button is disabled by the same value. Confirm/Cancel use submission guards. Derive:

~~~ts
const summary = $derived(snapshot?.pendingDaySummary ?? null);
~~~

Maintain confirmButton and add startDayButton. A Svelte effect focuses Confirm for the sleep dialog, otherwise Start Day N for the summary.

- [ ] **Step 6: Render authoritative HUD and summary**

Import formatTime from dailyRhythm. Add data-time, data-stamina, and data-weather elements:

~~~svelte
<p>Day {snapshot?.day ?? '—'}</p>
<p>Time: <span data-time>{snapshot ? formatTime(snapshot.timeMinutes) : '—'}</span></p>
<p>Stamina: <span data-stamina>{snapshot ? snapshot.stamina + ' / ' + snapshot.maxStamina : '—'}</span></p>
<p>Weather: <span data-weather>{snapshot ? weatherLabel(snapshot.weather) : '—'}</span></p>
~~~

When summary is non-null, render one aria-modal dialog named Morning summary containing:

- Day {completedDay} complete
- Crops advanced: {cropsAdvanced}
- Next day: Day {nextDay}
- Weather: Sunny or Rainy from nextWeather
- Stamina restored: {staminaRestored} ({snapshot.stamina} / {snapshot.maxStamina})
- a button named Start Day {nextDay}, bound for focus and disabled while summarySubmitting

The summary has no Cancel path. Keep the sleep confirmation as the first dialog and never render both after a successful command.

- [ ] **Step 7: Finish exhaustive feedback and styling**

Keep all messages added in Tasks 2–3. Add an exhaustive Weather label switch with a never default. Style the HUD for six compact stats and style the summary layer using the existing modal backing/border/focus conventions. Keep the 640 by 360 logical stage and farm/bed route visible.

- [ ] **Step 8: Run Svelte analysis and focused GREEN**

At execution time load the required Svelte skills. Run any installed local Svelte analyzer/autofixer only if it does not egress source. Then run:

- rtk bun run check
- rtk bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts
- rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts
- rtk bun run test:e2e -- tests/e2e/world.pw.ts

Expected: check zero diagnostics; sleep two-stage flow, lifecycle, and world suites green.

- [ ] **Step 9: Run unit/build/hook verification and record the remaining staged test**

Run:

- rtk bun test
- rtk bun run build
- rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
- rtk git diff --check

Expected: unit/build green, production scan exits 1 with no matches, diff clean. The existing farming.pw.ts still assumes always-sunny watering and no summary acknowledgment; Task 6 must observe that RED and adapt it rather than weakening production.

- [ ] **Step 10: Self-review and commit Task 5**

Review one gate reason, every synchronized state path, double-submit guards, handleSleepPrompt guard, background buttons, focus, teardown, no second day authority, and no hook changes.

~~~bash
rtk git add src/App.svelte src/components/Overlay.svelte src/app.css tests/e2e/sleep-confirmation.pw.ts
rtk git commit -m "feat: add daily rhythm HUD and summary"
~~~

---

### Task 6: Weather-Aware Complete-Loop Browser Acceptance

**Files:**

- Modify: tests/e2e/helpers.ts
- Modify: tests/e2e/farming.pw.ts
- Modify: tests/e2e/sleep-confirmation.pw.ts only if focused readiness evidence requires a test-only correction

**Interfaces:**

- Consumes: real keyboard/buttons, DebugSnapshot, GameSnapshot, morning-summary DOM, production Math.random, and existing movement routes.
- Produces: a reusable confirmAndStartDay() helper, budget-aware HUD assertions, weather-branching watering, exact summary checks, and a complete nonflaky turnip loop.
- Preserves: retries 0, 3-second movement deadlines, observation-only hooks, target identity, visual frame/depth proof, and all foundation E2E.

- [ ] **Step 1: Run the old farming suite and observe the expected RED**

Run: rtk bun run test:e2e -- tests/e2e/farming.pw.ts

Expected: FAIL after the first successful sleep because pendingDaySummary blocks the old immediate watering path, or on a rainy day because the old test always expects crop-watered.

- [ ] **Step 2: Add a shared confirm-and-start helper**

In tests/e2e/helpers.ts add:

~~~ts
interface ExpectedDayTransition {
  completedDay: number;
  cropsAdvanced: number;
  staminaRestored: number;
}

export async function confirmAndStartDay(
  page: Page,
  expected: ExpectedDayTransition,
): Promise<GameSnapshot> {
  await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Morning summary' });
  await expect(dialog).toBeVisible();

  const pending = await gameSnapshot(page);
  const nextDay = expected.completedDay + 1;
  expect(pending.day).toBe(nextDay);
  expect(pending.pendingDaySummary).toEqual({
    completedDay: expected.completedDay,
    nextDay,
    cropsAdvanced: expected.cropsAdvanced,
    nextWeather: pending.weather,
    staminaRestored: expected.staminaRestored,
  });
  await expect(dialog).toContainText('Day ' + expected.completedDay + ' complete');
  await expect(dialog).toContainText('Crops advanced: ' + expected.cropsAdvanced);
  await expect(dialog).toContainText('Next day: Day ' + nextDay);
  await expect(dialog).toContainText(
    'Weather: ' + (pending.weather === 'sunny' ? 'Sunny' : 'Rainy'),
  );
  await expect(dialog).toContainText(
    'Stamina restored: ' + expected.staminaRestored,
  );
  expect((await snapshot(page)).locked).toBe(true);

  const start = page.getByRole('button', { name: 'Start Day ' + nextDay });
  await expect(start).toBeFocused();
  await start.click();
  await expect(dialog).toBeHidden();
  await expect.poll(async () => (await gameSnapshot(page)).pendingDaySummary).toBeNull();
  expect((await snapshot(page)).locked).toBe(false);
  return gameSnapshot(page);
}
~~~

Each caller supplies the completed day, actual crops advanced, and exact stamina restored. The helper always asserts nextWeather equals resulting weather, visible summary content, Start focus, pending clear, and lock release.

- [ ] **Step 3: Expand HUD assertions to authoritative budgets and weather**

Update expectHud() to check Day, formatted Time, Stamina current/max, Weather, Selected, Seeds, and Turnips. Use formatTime() for integration formatting because its boundary behavior is independently tested in Task 1. Capitalize Weather through an exhaustive test-local label map.

After initial Hoe, Plant, and Water on sunny Day 1, assert exact snapshots:

- after Hoe: time 390, stamina 17;
- after Plant: time 410, stamina 16;
- after Water: time 430, stamina 14.

Retain the rejected Hands-on-empty snapshot equality and explicitly confirm its time/stamina are unchanged.

- [ ] **Step 4: Replace direct Confirm calls with complete transitions**

Every farming sleep does:

1. Move to and assert BED_CELL.
2. Open sleep confirmation.
3. Confirm.
4. Assert the authoritative Morning summary.
5. Click Start Day N.
6. Wait for pendingDaySummary null and input unlocked.

Day 1 completion supplies cropsAdvanced 1 and staminaRestored 6. Each later growth night supplies cropsAdvanced 1 and staminaRestored 2 after successful sunny watering or 0 after rainy watering rejection. The returned active snapshot must show time 360 and stamina 20.

- [ ] **Step 5: Branch watering on observed production weather**

Add:

~~~ts
async function waterForCurrentWeather(page: Page): Promise<GameSnapshot> {
  const before = await gameSnapshot(page);
  if (before.weather === 'sunny') {
    const watered = await useSelected(page, CROP_CELL, FEEDBACK.cropWatered);
    expect(watered.timeMinutes).toBe(before.timeMinutes + 20);
    expect(watered.stamina).toBe(before.stamina - 2);
    return watered;
  }

  const rejected = await useSelected(page, CROP_CELL, FEEDBACK.rainWatersCrops);
  expect(rejected).toEqual(before);
  return rejected;
}
~~~

Add FEEDBACK.rainWatersCrops with the exact Overlay text. On rainy days, the following sleep must still advance the crop. Do not inject or set weather.

- [ ] **Step 6: Preserve visual and depth proof under either branch**

On sunny days, the soil frame changes when manual watering succeeds. On rainy days, soil is already wet at day start, so do not require a second wet-frame change after the rejected Water command. Continue requiring distinct crop frames after each growth level and retain the existing player/crop depth reversal assertions.

- [ ] **Step 7: Run focused GREEN and a helper mutation**

Run the farming suite three consecutive times:

- rtk bun run test:e2e -- tests/e2e/farming.pw.ts
- rtk bun run test:e2e -- tests/e2e/farming.pw.ts
- rtk bun run test:e2e -- tests/e2e/farming.pw.ts

Temporarily remove the Start Day click from confirmAndStartDay and run the focused suite. Expected: the next farming command fails behind pendingDaySummary. Restore the click and require another focused pass.

- [ ] **Step 8: Run the complete browser matrix**

Run:

- rtk bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts
- rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts
- rtk bun run test:e2e -- tests/e2e/world.pw.ts
- rtk bun run test:e2e

Expected: all suites pass in one combined run with retries 0. If a route fails, use release-first snapshots and the existing RAF/50 ms polling helpers; do not broaden deadlines or add arbitrary waits.

- [ ] **Step 9: Run regression verification**

Run:

- rtk bun test
- rtk bun run check
- rtk bun run build
- rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
- rtk git diff --check

Expected: unit/check/build pass, scan exits 1 with no hooks, and diff is clean.

- [ ] **Step 10: Self-review and commit Task 6**

Review normal controls, weather branching, summary content, lock continuity, no setter/hook, exact cost assertions, cropsAdvanced, frame behavior, and unchanged route deadlines.

~~~bash
rtk git add tests/e2e/helpers.ts tests/e2e/farming.pw.ts tests/e2e/sleep-confirmation.pw.ts
rtk git commit -m "test: cover the complete daily rhythm"
~~~

---

### Task 7: Documentation, Whole-Branch Review, and macOS Delivery

**Files:**

- Modify: tests/config/handoff.test.ts
- Modify: README.md
- Review: every file changed from the HPA-592 branch base through Task 6
- Do not commit: target, dist, test-results, screenshots, temporary native helpers/configs, or clean-checkout archives

**Interfaces:**

- Consumes: the committed Task 1–6 branch, asset generator, unit/browser/static matrix, Cargo/Tauri build, verify:clean, and a real Phoenix macOS window.
- Produces: updated player/developer handoff, whole-branch review fixes when evidence requires them, clean-checkout proof, artifact audit, bounded native evidence, and a truthful finishing handoff.

- [ ] **Step 1: Write a failing handoff contract**

Extend the existing README test to require all of:

~~~ts
for (const dailyRhythmText of [
  'HPA-592',
  '06:00',
  '22:00',
  '20 stamina',
  'Sunny',
  'Rainy',
  'Morning summary',
  'Start Day',
  'Day 14',
]) {
  expect(readme.toLowerCase()).toContain(dailyRhythmText.toLowerCase());
}
~~~

Run: rtk bun test tests/config/handoff.test.ts

Expected: FAIL because README still describes only HPA-588/HPA-591 and direct sleep unlock.

- [ ] **Step 2: Update README without expanding platform claims**

Describe HPA-592, the exact four costs, action-driven clock/stamina, rain behavior, two-stage sleep/summary flow, Start Day N, and the temporary Day 14 boundary. Correct the old sentence that Confirm immediately releases input. Keep setup commands, macOS-only statement, ownership split, authored map contract, and verification matrix intact.

- [ ] **Step 3: Run documentation GREEN and commit**

Run:

- rtk bun test tests/config/handoff.test.ts
- rtk bun test
- rtk bun run check
- rtk git diff --check

Commit:

~~~bash
rtk git add README.md tests/config/handoff.test.ts
rtk git commit -m "docs: document the daily rhythm"
~~~

- [ ] **Step 4: Perform whole-branch review against the approved design**

At execution time use superpowers:requesting-code-review for the final review. Compare the full branch to its base and verify:

- one GameSession authority and no gameplay in Rust/Svelte/Phaser;
- exact action costs and failure precedence;
- evaluator-only cutoff ownership with no setter;
- provider omission from ProofScene and deterministic unit fixtures;
- provider-first in-place sleep and one provider call;
- complete active-day command coverage and movement no-op;
- fresh summary/snapshot values and Day 14 immutability;
- required Weather farm visuals;
- one dayTransitionActive value and one day-transition reason;
- background control/focus/teardown symmetry;
- weather-aware E2E without mutation hooks;
- unchanged HPA-588/HPA-591 movement, collision, camera, depth, HMR, map, and stage contracts.

Fix every valid Critical, Important, or Minor finding with a focused RED/GREEN cycle and separate commit, then re-review the changed scope.

- [ ] **Step 5: Verify deterministic assets and the complete committed matrix**

Require a clean worktree, then run:

- rtk bun run assets:generate
- rtk git diff --exit-code -- src/assets/maps/proof-map.json src/assets/sprites
- rtk bun run check
- rtk bun test
- rtk bun run test:e2e
- rtk bun run build
- rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist
- rtk cargo check --manifest-path src-tauri/Cargo.toml
- rtk bun run tauri:build
- rtk bun run verify:clean

Expected: no asset diff; zero static diagnostics; all unit/E2E pass; frontend/Cargo/Tauri/clean verification pass; hook scan exits 1 with no matches. The existing Phaser chunk advisory is accepted.

If sandboxed DMG creation fails with hdiutil Device not configured, classify it with one minimal hdiutil probe and rerun the exact Tauri or verifier command at the approved macOS host boundary. Record both outcomes; do not change application code for a sandbox device failure.

- [ ] **Step 6: Audit macOS artifacts**

Confirm Phoenix.app and Phoenix_0.1.0_aarch64.dmg under src-tauri/target/release/bundle. Verify:

- Mach-O is arm64 and matches the host;
- bundle identifier remains com.hapadona.phoenix;
- version remains 0.1.0;
- hdiutil verify reports VALID;
- size and paths are recorded;
- codesign/spctl results are reported as ad hoc/unsigned truth, not Developer ID or notarization.

- [ ] **Step 7: Perform a bounded native smoke**

Launch only the just-built Phoenix app. Confirm a real Phoenix window visibly shows Time, Stamina, Weather, farming HUD, farm sprites, and world. When PID-targeted interaction is reliable, prove one WASD movement and one modal lock path. If summary interaction, resize, or native input is ambiguous, stop and report the gap; browser E2E remains authoritative for the identical frontend.

Terminate only the Phoenix process created by this task. Verify no Phoenix process and no task-created Vite/Playwright listener remains. Do not touch unrelated applications or old global browser processes.

- [ ] **Step 8: Confirm repository hygiene and prepare handoff**

Run:

- rtk git status --short --branch
- rtk git diff --check
- rtk git log --oneline --decorate -15

Expected: clean worktree and a linear reviewed Task 1–7 history. Report exact head, commits, unit/E2E/check/build/Cargo/Tauri/verify results, artifact paths, accepted advisories, signing truth, native evidence, and any unproven interaction.

Do not mark HPA-587 complete. Use superpowers:finishing-a-development-branch only after the user chooses integration/cleanup.
