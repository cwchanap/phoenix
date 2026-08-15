<script lang="ts">
  import { onMount, tick } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  import type {
    CommandResult,
    FarmingAction,
    GameSnapshot,
    Weather,
  } from '../game/core/types';
  import { formatTime } from '../game/core/dailyRhythm';
  import type { SceneCommands } from '../game/phaser/ProofScene';

  type LifecycleStatus = 'loading' | 'ready' | 'error';

  interface Props {
    inputGate: InputGate;
    status: LifecycleStatus;
    error: string | null;
    snapshot: GameSnapshot | null;
    result: CommandResult | null;
    commands: SceneCommands | null;
    sleepPromptVisible: boolean;
    sleepSubmitting: boolean;
    summarySubmitting: boolean;
    dayTransitionActive: boolean;
    onConfirmSleep: () => void;
    onCancelSleep: () => void;
    onStartDay: () => void;
  }

  const actions: ReadonlyArray<{
    key: string;
    label: string;
    action: FarmingAction;
  }> = [
    { key: '1', label: 'Hoe', action: 'hoe' },
    { key: '2', label: 'Seeds', action: 'turnipSeeds' },
    { key: '3', label: 'Water', action: 'wateringCan' },
    { key: '4', label: 'Hands', action: 'hands' },
  ];

  let {
    inputGate,
    status,
    error,
    snapshot,
    result,
    commands,
    sleepPromptVisible,
    sleepSubmitting,
    summarySubmitting,
    dayTransitionActive,
    onConfirmSleep,
    onCancelSleep,
    onStartDay,
  }: Props = $props();
  let overlayLocked = $state(false);
  let locked = $state(false);
  let confirmButton = $state<HTMLButtonElement | null>(null);
  let startDayButton = $state<HTMLButtonElement | null>(null);
  const summary = $derived(snapshot?.pendingDaySummary ?? null);
  const actionsReady = $derived(
    status === 'ready'
      && commands !== null
      && snapshot !== null
      && !dayTransitionActive,
  );

  $effect(() => {
    if (sleepPromptVisible) {
      void tick().then(() => requestAnimationFrame(() => confirmButton?.focus()));
    } else if (summary) {
      void tick().then(() => requestAnimationFrame(() => startDayButton?.focus()));
    }
  });

  function weatherLabel(weather: Weather): string {
    switch (weather) {
      case 'sunny': return 'Sunny';
      case 'rainy': return 'Rainy';
      default: return assertNever(weather);
    }
  }

  function actionLabel(action: FarmingAction): string {
    switch (action) {
      case 'hoe': return 'Hoe';
      case 'turnipSeeds': return 'Seeds';
      case 'wateringCan': return 'Water';
      case 'hands': return 'Hands';
      default: return assertNever(action);
    }
  }

  function commandResultMessage(commandResult: CommandResult): string {
    switch (commandResult.code) {
      case 'action-selected': return 'Action selected';
      case 'soil-tilled': return 'Soil tilled';
      case 'turnip-planted': return 'Turnip planted';
      case 'crop-watered': return 'Crop watered';
      case 'turnip-harvested': return 'Turnip harvested';
      case 'day-advanced': return 'Day advanced';
      case 'day-started': return 'Day started';
      case 'no-target': return 'No target highlighted';
      case 'not-farm-cell': return 'That is not a farm cell';
      case 'already-tilled': return 'That soil is already tilled';
      case 'soil-untilled': return 'Till the soil first';
      case 'crop-present': return 'That cell already has a turnip';
      case 'no-turnip-seeds': return 'No turnip seeds';
      case 'no-crop': return 'No crop here';
      case 'already-watered': return 'This crop is already watered';
      case 'crop-mature': return 'This turnip is already mature';
      case 'crop-immature': return 'This turnip is not ready';
      case 'not-at-bed': return 'You must be at the bed';
      case 'action-too-late': return 'Not enough time before 22:00';
      case 'insufficient-stamina': return 'Not enough stamina';
      case 'day-summary-pending': return 'Start the new day first';
      case 'rain-waters-crops': return 'Rain is watering the crops';
      case 'day-limit-reached': return 'Day 14 is the final playable day for now';
      case 'no-day-summary': return 'No morning summary to close';
      default: return assertNever(commandResult);
    }
  }

  function assertNever(value: never): never {
    throw new Error(`Unsupported command result: ${String(value)}`);
  }

  onMount(() => {
    locked = inputGate.isLocked;
    const unsubscribe = inputGate.subscribe((value) => {
      locked = value;
    });

    return () => {
      unsubscribe();
      inputGate.set('overlay', false);
    };
  });

  const toggle = () => {
    if (dayTransitionActive) return;
    const nextLocked = !overlayLocked;
    overlayLocked = nextLocked;
    inputGate.set('overlay', nextLocked);
  };
</script>

<aside data-overlay aria-live="polite">
  <h1>Phoenix — Isometric Proof</h1>
  {#if status === 'error'}
    <p role="alert">{error ?? 'World failed'}</p>
    <button type="button" onclick={() => window.location.reload()}>Reload</button>
  {:else}
    <p data-world-status>{status === 'ready' ? 'World ready' : 'Loading world…'}</p>

    <section data-farming-hud aria-label="Farming status">
      <div class="hud-stats">
        <p>Day {snapshot?.day ?? '—'}</p>
        <p>Time: <span data-time>{snapshot ? formatTime(snapshot.timeMinutes) : '—'}</span></p>
        <p>Stamina: <span data-stamina>{snapshot ? snapshot.stamina + ' / ' + snapshot.maxStamina : '—'}</span></p>
        <p>Weather: <span data-weather>{snapshot ? weatherLabel(snapshot.weather) : '—'}</span></p>
        <p>Selected: {snapshot ? actionLabel(snapshot.selectedAction) : '—'}</p>
        <p>Seeds: {snapshot?.inventory.turnipSeeds ?? '—'}</p>
        <p>Turnips: {snapshot?.inventory.turnips ?? '—'}</p>
      </div>

      <div class="action-buttons" aria-label="Farming actions">
        {#each actions as action (action.key)}
          <button
            type="button"
            aria-pressed={Boolean(snapshot && snapshot.selectedAction === action.action)}
            disabled={!actionsReady}
            onclick={() => {
              if (actionsReady) commands?.selectAction(action.action);
            }}
          >
            {action.key} {action.label}
          </button>
        {/each}
      </div>

      <p data-feedback>{result ? commandResultMessage(result) : 'No command yet'}</p>
    </section>

    <p>Move: WASD</p>
    <p>Use selected: Space · Sleep at bed: E</p>
    <p>World input: {locked ? 'Locked' : 'Active'}</p>
    <button type="button" aria-pressed={overlayLocked} disabled={dayTransitionActive} onclick={toggle}>
      {overlayLocked ? 'Unlock world input' : 'Lock world input'}
    </button>
  {/if}

  {#if sleepPromptVisible}
    <div class="sleep-modal-layer" data-sleep-modal>
      <div
        class="sleep-dialog"
        role="dialog"
        tabindex="-1"
        aria-modal="true"
        aria-labelledby="sleep-dialog-title"
      >
        <h2 id="sleep-dialog-title">Sleep until tomorrow?</h2>
        <p>Watered crops grow overnight.</p>
        <div class="sleep-dialog-actions">
          <button
            bind:this={confirmButton}
            type="button"
            onclick={onConfirmSleep}
            disabled={commands === null || sleepSubmitting}
          >Confirm</button>
          <button type="button" onclick={onCancelSleep} disabled={sleepSubmitting}>Cancel</button>
        </div>
      </div>
    </div>
  {/if}

  {#if summary}
    <div class="sleep-modal-layer" data-day-summary-modal>
      <div
        class="sleep-dialog summary-dialog"
        role="dialog"
        tabindex="-1"
        aria-modal="true"
        aria-labelledby="morning-summary-title"
      >
        <h2 id="morning-summary-title">Morning summary</h2>
        <p>Day {summary.completedDay} complete</p>
        <p>Crops advanced: {summary.cropsAdvanced}</p>
        <p>Next day: Day {summary.nextDay}</p>
        <p>Weather: {weatherLabel(summary.nextWeather)}</p>
        <p>Stamina restored: {summary.staminaRestored} ({snapshot?.stamina ?? '—'} / {snapshot?.maxStamina ?? '—'})</p>
        <div class="sleep-dialog-actions">
          <button
            bind:this={startDayButton}
            type="button"
            onclick={onStartDay}
            disabled={summarySubmitting || commands === null}
          >
            Start Day {summary.nextDay}
          </button>
        </div>
      </div>
    </div>
  {/if}
</aside>
