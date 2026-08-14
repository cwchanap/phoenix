<script lang="ts">
  import { onMount } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  import type {
    CommandResult,
    FarmingAction,
    GameSnapshot,
  } from '../game/core/types';
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
    onConfirmSleep: () => void;
    onCancelSleep: () => void;
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
    onConfirmSleep,
    onCancelSleep,
  }: Props = $props();
  let overlayLocked = $state(false);
  let locked = $state(false);
  let confirmButton = $state<HTMLButtonElement | null>(null);
  const actionsReady = $derived(
    status === 'ready' && commands !== null && snapshot !== null && !sleepPromptVisible,
  );

  $effect(() => {
    if (sleepPromptVisible) confirmButton?.focus();
  });

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
    if (sleepPromptVisible) return;
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
    <button type="button" aria-pressed={overlayLocked} disabled={sleepPromptVisible} onclick={toggle}>
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
          <button bind:this={confirmButton} type="button" onclick={onConfirmSleep} disabled={commands === null}>Confirm</button>
          <button type="button" onclick={onCancelSleep}>Cancel</button>
        </div>
      </div>
    </div>
  {/if}
</aside>
