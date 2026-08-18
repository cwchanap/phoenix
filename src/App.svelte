<script lang="ts">
  import { onMount } from 'svelte';
  import GameHost from './components/GameHost.svelte';
  import Overlay from './components/Overlay.svelte';
  import StageFrame from './components/StageFrame.svelte';
  import { InputGate } from './game/core/InputGate';
  import type {
    CommandResult,
    CropKind,
    GameSnapshot,
    SocialFeedback,
    VillagerId,
  } from './game/core/types';
  import type { SceneCommands } from './game/phaser/ProofScene';
  import type { InteractionIntent } from './game/phaser/interactionIntent';
  import DialoguePanel from './components/DialoguePanel.svelte';

  type LifecycleStatus = 'loading' | 'ready' | 'error';

  const inputGate = new InputGate();
  let status = $state<LifecycleStatus>('loading');
  let error = $state<string | null>(null);
  let gameSnapshot = $state.raw<GameSnapshot | null>(null);
  let commandResult = $state.raw<CommandResult | null>(null);
  let commands = $state.raw<SceneCommands | null>(null);
  let sleepPromptVisible = $state(false);
  let sleepSubmitting = $state(false);
  let summarySubmitting = $state(false);
  let dayTransitionActive = $state(false);
  type EconomyPanel = Exclude<InteractionIntent['kind'], 'sleep' | 'villager'> | null;
  let economyPanel = $state<EconomyPanel>(null);
  type DialoguePanelState = { villagerId: VillagerId; social: SocialFeedback };
  let dialoguePanel = $state<DialoguePanelState | null>(null);

  function syncDayTransition(): void {
    dayTransitionActive =
      sleepPromptVisible ||
      sleepSubmitting ||
      summarySubmitting ||
      (gameSnapshot?.pendingDaySummary ?? null) !== null;
    inputGate.set('day-transition', dayTransitionActive);
  }

  function syncEconomyPanel(): void {
    inputGate.set('economy-panel', economyPanel !== null);
  }

  function resetGamePresentation(): void {
    gameSnapshot = null;
    commandResult = null;
    commands = null;
    sleepPromptVisible = false;
    sleepSubmitting = false;
    summarySubmitting = false;
    economyPanel = null;
    dialoguePanel = null;
    syncDayTransition();
    syncEconomyPanel();
    inputGate.set('dialogue-panel', false);
  }

  function handleStatus(nextStatus: string): void {
    if (nextStatus === 'World ready') {
      status = 'ready';
    } else if (nextStatus === 'World failed') {
      status = 'error';
    } else {
      status = 'loading';
    }
    if (status !== 'error') error = null;
    if (status !== 'ready') resetGamePresentation();
  }

  function handleError(nextError: Error): void {
    error = nextError.message;
    status = 'error';
    resetGamePresentation();
  }

  function handleReady(nextCommands: SceneCommands): void {
    commands = nextCommands;
    status = 'ready';
    error = null;
  }

  function handleGameSnapshot(nextSnapshot: GameSnapshot): void {
    gameSnapshot = nextSnapshot;
    syncDayTransition();
  }

  function handleCommandResult(nextResult: CommandResult): void {
    commandResult = nextResult;
  }

  function handleInteractIntent(intent: InteractionIntent): void {
    if (dayTransitionActive || economyPanel !== null || dialoguePanel !== null) return;
    switch (intent.kind) {
      case 'sleep':
        sleepPromptVisible = true;
        syncDayTransition();
        break;
      case 'shop':
      case 'shipping':
        economyPanel = intent.kind;
        syncEconomyPanel();
        break;
      case 'villager': {
        const currentCommands = commands;
        if (!currentCommands) return;
        const result = currentCommands.talkTo(intent.villagerId);
        if (result.ok) {
          dialoguePanel = { villagerId: intent.villagerId, social: result.social };
          inputGate.set('dialogue-panel', true);
        }
        break;
      }
    }
  }

  function closeEconomyPanel(): void {
    economyPanel = null;
    syncEconomyPanel();
  }

  function closeDialoguePanel(): void {
    dialoguePanel = null;
    inputGate.set('dialogue-panel', false);
  }

  function giftDialogueCrop(crop: CropKind): void {
    const currentPanel = dialoguePanel;
    const currentCommands = commands;
    if (!currentPanel || !currentCommands) return;

    const result = currentCommands.giftCrop(currentPanel.villagerId, crop);
    if (result.ok) {
      dialoguePanel = { ...currentPanel, social: result.social };
    }
  }

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

  const handleBlur = () => inputGate.set('window-blur', true);
  const handleFocus = () => inputGate.set('window-blur', false);

  onMount(() => () => {
    resetGamePresentation();
    handleFocus();
    inputGate.set('day-transition', false);
    inputGate.set('economy-panel', false);
  });
</script>

<svelte:window onblur={handleBlur} onfocus={handleFocus} />

<main data-app-shell>
  <StageFrame>
    <GameHost
      {inputGate}
      onStatus={handleStatus}
      onError={handleError}
      onReady={handleReady}
      onGameSnapshot={handleGameSnapshot}
      onCommandResult={handleCommandResult}
      onInteractIntent={handleInteractIntent}
    />
    <Overlay
      {inputGate}
      {status}
      {error}
      snapshot={gameSnapshot}
      result={commandResult}
      {commands}
      {sleepPromptVisible}
      {sleepSubmitting}
      {summarySubmitting}
      {dayTransitionActive}
      {economyPanel}
      dialogueOpen={dialoguePanel !== null}
      onConfirmSleep={confirmSleep}
      onCancelSleep={cancelSleep}
      onStartDay={startDay}
      onCloseEconomyPanel={closeEconomyPanel}
    />
    {#if dialoguePanel && gameSnapshot}
      {#key dialoguePanel.social}
        <DialoguePanel
          villagerId={dialoguePanel.villagerId}
          social={dialoguePanel.social}
          snapshot={gameSnapshot}
          onGift={giftDialogueCrop}
          onClose={closeDialoguePanel}
        />
      {/key}
    {/if}
  </StageFrame>
</main>
