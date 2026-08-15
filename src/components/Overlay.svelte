<script lang="ts">
  import { onMount, tick, untrack } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  import {
    CROP_DEFINITIONS,
    CROP_KINDS,
  } from '../game/core/cropDefinitions';
  import { formatTime } from '../game/core/dailyRhythm';
  import type {
    CommandResult,
    CropKind,
    FarmingAction,
    GameSnapshot,
    Weather,
  } from '../game/core/types';
  import QuantityStepper from './QuantityStepper.svelte';
  import type { SceneCommands } from '../game/phaser/ProofScene';

  type LifecycleStatus = 'loading' | 'ready' | 'error';
  type EconomyPanel = 'shop' | 'shipping' | null;

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
    economyPanel: EconomyPanel;
    onConfirmSleep: () => void;
    onCancelSleep: () => void;
    onStartDay: () => void;
    onCloseEconomyPanel: () => void;
  }

  const actions: ReadonlyArray<{
    key: string;
    label: string;
    action: FarmingAction;
  }> = [
    { key: '1', label: 'Hoe', action: 'hoe' },
    { key: '2', label: 'Seeds', action: 'seeds' },
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
    economyPanel,
    onConfirmSleep,
    onCancelSleep,
    onStartDay,
    onCloseEconomyPanel,
  }: Props = $props();
  let overlayLocked = $state(false);
  let locked = $state(false);
  let confirmButton = $state<HTMLButtonElement | null>(null);
  let startDayButton = $state<HTMLButtonElement | null>(null);
  let selectedPanelCrop = $state<CropKind>('turnip');
  let quantity = $state(1);
  let transactionSubmitting = $state(false);
  let previousEconomyPanel = $state<EconomyPanel>(null);
  let economyDialog = $state<HTMLElement | null>(null);
  let economyCloseButton = $state<HTMLButtonElement | null>(null);
  const summary = $derived(snapshot?.pendingDaySummary ?? null);
  const totalPendingQuantity = $derived.by(() => {
    if (!snapshot) return 0;
    return CROP_KINDS.reduce((total, kind) => total + snapshot.pendingShipment[kind], 0);
  });
  const actionsReady = $derived(
    status === 'ready'
      && commands !== null
      && snapshot !== null
      && !dayTransitionActive
      && economyPanel === null,
  );
  const panelMaximum = $derived.by(() => {
    if (!snapshot || !economyPanel) return 0;
    if (economyPanel === 'shop') {
      return Math.floor(snapshot.money / CROP_DEFINITIONS[selectedPanelCrop].seedPrice);
    }
    return snapshot.inventory.crops[selectedPanelCrop];
  });
  const selectedPanelDefinition = $derived(CROP_DEFINITIONS[selectedPanelCrop]);

  $effect(() => {
    if (sleepPromptVisible) {
      void tick().then(() => requestAnimationFrame(() => confirmButton?.focus()));
    } else if (summary) {
      void tick().then(() => requestAnimationFrame(() => startDayButton?.focus()));
    }
  });

  $effect(() => {
    const panel = economyPanel;
    if (panel === previousEconomyPanel) return;
    previousEconomyPanel = panel;
    transactionSubmitting = false;
    quantity = 1;
    if (panel === null) return;
    selectedPanelCrop = untrack(() => (
      CROP_KINDS.find((kind) => panel === 'shop'
        ? Boolean(snapshot && snapshot.money >= CROP_DEFINITIONS[kind].seedPrice)
        : Boolean(snapshot && snapshot.inventory.crops[kind] > 0)) ?? 'turnip'
    ));
    void tick().then(() => requestAnimationFrame(() => {
      if (economyPanel !== panel) return;
      const firstUsableRow = economyDialog
        ?.querySelector<HTMLButtonElement>('[data-economy-row]:not(:disabled)');
      (firstUsableRow ?? economyCloseButton)?.focus();
    }));
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
      case 'seeds': {
        const definition = snapshot ? CROP_DEFINITIONS[snapshot.selectedSeed] : null;
        return definition ? `Seeds: ${definition.displayName}` : 'Seeds';
      }
      case 'wateringCan': return 'Water';
      case 'hands': return 'Hands';
      default: return assertNever(action);
    }
  }

  function commandResultMessage(commandResult: CommandResult): string {
    switch (commandResult.code) {
      case 'action-selected': return 'Action selected';
      case 'seed-selected': return 'Seed selected';
      case 'soil-tilled': return 'Soil tilled';
      case 'crop-planted': return 'Turnip planted';
      case 'crop-watered': return 'Crop watered';
      case 'crop-harvested': return 'Crop harvested';
      case 'seeds-purchased': return 'Seeds purchased';
      case 'crop-deposited': return 'Crop deposited';
      case 'day-advanced': return 'Day advanced';
      case 'day-started': return 'Day started';
      case 'no-target': return 'No target highlighted';
      case 'not-farm-cell': return 'That is not a farm cell';
      case 'already-tilled': return 'That soil is already tilled';
      case 'soil-untilled': return 'Till the soil first';
      case 'crop-present': return 'That cell already has a crop';
      case 'no-selected-seeds': return 'No selected seeds';
      case 'no-crop': return 'No crop here';
      case 'already-watered': return 'This crop is already watered';
      case 'crop-mature': return 'This crop is already mature';
      case 'crop-immature': return 'This crop is not ready';
      case 'nothing-to-interact': return 'Nothing to interact with';
      case 'not-at-bed': return 'You must be at the bed';
      case 'not-at-shop': return 'You must be at the shop';
      case 'not-at-shipping-bin': return 'You must be at the shipping bin';
      case 'invalid-quantity': return 'Invalid quantity';
      case 'insufficient-funds': return 'Not enough money';
      case 'insufficient-crops': return 'Not enough crops';
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
    throw new Error(`Unsupported value: ${String(value)}`);
  }

  function selectPanelCrop(kind: CropKind): void {
    selectedPanelCrop = kind;
    quantity = 1;
  }

  function submitEconomyTransaction(): void {
    if (!snapshot || !commands || !economyPanel || transactionSubmitting) return;
    transactionSubmitting = true;
    try {
      if (economyPanel === 'shop') commands.buySeeds(selectedPanelCrop, quantity);
      else commands.depositCrop(selectedPanelCrop, quantity);
    } finally {
      transactionSubmitting = false;
    }
  }

  function handleEconomyKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Escape' || economyPanel === null) return;
    event.preventDefault();
    onCloseEconomyPanel();
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
    if (dayTransitionActive || economyPanel !== null) return;
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
        <p>Selected seed: {snapshot ? CROP_DEFINITIONS[snapshot.selectedSeed].displayName : '—'}</p>
        <p>Money: {snapshot?.money ?? '—'}</p>
        {#each CROP_KINDS as kind (kind)}
          <p>{CROP_DEFINITIONS[kind].displayName} seeds: {snapshot?.inventory.seeds[kind] ?? '—'}</p>
        {/each}
        {#each CROP_KINDS as kind (kind)}
          <p>{CROP_DEFINITIONS[kind].displayName} crops: {snapshot?.inventory.crops[kind] ?? '—'}</p>
        {/each}
        <p>Pending shipment: {snapshot ? totalPendingQuantity : '—'}</p>
      </div>

      <div class="seed-selection" aria-label="Seed selection">
        {#each CROP_KINDS as kind (kind)}
          <button
            type="button"
            aria-label={`Select ${CROP_DEFINITIONS[kind].displayName}`}
            aria-pressed={Boolean(snapshot && snapshot.selectedSeed === kind)}
            disabled={!actionsReady}
            onclick={() => {
              if (actionsReady) commands?.selectSeed(kind);
            }}
          >Select {CROP_DEFINITIONS[kind].displayName}</button>
        {/each}
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
            {action.key} {actionLabel(action.action)}
          </button>
        {/each}
      </div>

      <p data-feedback>{result ? commandResultMessage(result) : 'No command yet'}</p>
    </section>

    <p>Move: WASD</p>
    <p>Use selected: Space · Interact: E</p>
    <p>World input: {locked ? 'Locked' : 'Active'}</p>
    <button
      type="button"
      aria-pressed={overlayLocked}
      disabled={dayTransitionActive || economyPanel !== null}
      onclick={toggle}
    >
      {overlayLocked ? 'Unlock world input' : 'Lock world input'}
    </button>
  {/if}

  {#if economyPanel}
    <div class="sleep-modal-layer" data-economy-modal>
      <div
        class="sleep-dialog economy-dialog"
        role="dialog"
        tabindex="-1"
        aria-modal="true"
        aria-labelledby="economy-dialog-title"
        onkeydown={handleEconomyKeydown}
        bind:this={economyDialog}
      >
        <h2 id="economy-dialog-title">{economyPanel === 'shop' ? 'Seed shop' : 'Shipping bin'}</h2>
        <div class="economy-crop-rows">
          {#each CROP_KINDS as kind (kind)}
            {@const definition = CROP_DEFINITIONS[kind]}
            <button
              type="button"
              data-economy-row
              aria-label={`${definition.displayName} ${economyPanel === 'shop' ? 'seeds' : 'crop'}`}
              aria-pressed={selectedPanelCrop === kind}
              disabled={snapshot === null || (economyPanel === 'shop'
                ? snapshot.money < definition.seedPrice
                : snapshot.inventory.crops[kind] < 1)}
              onclick={() => selectPanelCrop(kind)}
            >
              <span>{definition.displayName} {economyPanel === 'shop' ? 'seeds' : 'crop'}</span>
              <span>{definition.growthDays} nights</span>
              <span>{economyPanel === 'shop' ? 'Seed price' : 'Sale value'}: {economyPanel === 'shop' ? definition.seedPrice : definition.saleValue}</span>
              <span>{economyPanel === 'shop' ? 'Seeds owned' : 'Crops carried'}: {economyPanel === 'shop' ? snapshot?.inventory.seeds[kind] ?? '—' : snapshot?.inventory.crops[kind] ?? '—'}</span>
            </button>
          {/each}
        </div>

        <QuantityStepper
          quantity={quantity}
          max={panelMaximum}
          disabled={transactionSubmitting || commands === null || snapshot === null}
          itemName={economyPanel === 'shop' ? `${selectedPanelDefinition.displayName} seed` : selectedPanelDefinition.displayName}
          actionLabel={economyPanel === 'shop' ? 'Buy' : 'Deposit'}
          onQuantityChange={(nextQuantity) => quantity = nextQuantity}
          onSubmit={submitEconomyTransaction}
        />
        <button bind:this={economyCloseButton} type="button" onclick={onCloseEconomyPanel}>Close</button>
      </div>
    </div>
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
        {#each summary.shipments as shipment (shipment.crop)}
          <p data-shipment-row>{CROP_DEFINITIONS[shipment.crop].displayName}: {shipment.quantity} × {shipment.unitValue} = {shipment.lineTotal}</p>
        {/each}
        <p>Shipping income: {summary.shippingIncome}</p>
        <p>Money after shipping: {summary.moneyAfterShipping}</p>
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
