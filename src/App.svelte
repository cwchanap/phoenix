<script lang="ts">
  import { onMount } from 'svelte';
  import GameHost from './components/GameHost.svelte';
  import Overlay from './components/Overlay.svelte';
  import TitleScreen from './components/TitleScreen.svelte';
  import StageFrame from './components/StageFrame.svelte';
  import { InputGate } from './game/core/InputGate';
  import { loadTitleState } from './persistence/loadTitleState';
  import { persistOvernightSave } from './persistence/persistOvernightSave';
  import type { SaveFileV1 } from './persistence/saveFile';
  import type { SaveRepository } from './persistence/saveRepository';
  import type {
    CommandResult,
    CropKind,
    GameSnapshot,
    GameState,
    SocialFeedback,
    VillagerId,
  } from './game/core/types';
  import type { SceneCommands } from './game/phaser/ProofScene';
  import type { InteractionIntent } from './game/phaser/interactionIntent';
  import DialoguePanel from './components/DialoguePanel.svelte';

  type LifecycleStatus = 'loading' | 'ready' | 'error';
  type AppPhase = 'loading-save' | 'title' | 'playing';
  type LaunchSource = 'new' | 'continue' | null;
  type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
  type AppHmrData = { appPhase?: AppPhase; saveRepository?: SaveRepository | null };

  const inputGate = new InputGate();
  const hmrData = import.meta.hot?.data as AppHmrData | undefined;
  const restorePlayingFromHmr = hmrData?.appPhase === 'playing';
  let appPhase = $state<AppPhase>('loading-save');
  if (restorePlayingFromHmr) appPhase = 'playing';
  let launchSource = $state<LaunchSource>(null);
  let saveRepository = $state.raw<SaveRepository | null>(null);
  if (restorePlayingFromHmr) saveRepository = hmrData?.saveRepository ?? null;
  let loadedSave = $state.raw<SaveFileV1 | null>(null);
  let initialState = $state.raw<GameState | null>(null);
  let titleError = $state<string | null>(null);
  let status = $state<LifecycleStatus>('loading');
  let error = $state<string | null>(null);
  let gameSnapshot = $state.raw<GameSnapshot | null>(null);
  let commandResult = $state.raw<CommandResult | null>(null);
  let commands = $state.raw<SceneCommands | null>(null);
  let sleepPromptVisible = $state(false);
  let sleepSubmitting = $state(false);
  let summarySubmitting = $state(false);
  let saveStatus = $state<SaveStatus>('idle');
  let saveError = $state<string | null>(null);
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
    saveStatus = 'idle';
    saveError = null;
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
    if (launchSource !== null) {
      const failedLaunch = launchSource;
      resetGamePresentation();
      appPhase = 'title';
      titleError = nextError.message;
      if (failedLaunch === 'continue') {
        loadedSave = null;
        initialState = null;
      }
      launchSource = null;
      return;
    }

    error = nextError.message;
    status = 'error';
    resetGamePresentation();
  }

  function handleReady(nextCommands: SceneCommands): void {
    commands = nextCommands;
    status = 'ready';
    error = null;
    launchSource = null;
  }

  function startNewGame(): void {
    launchSource = 'new';
    initialState = null;
    titleError = null;
    appPhase = 'playing';
  }

  function continueGame(): void {
    if (!loadedSave) return;
    launchSource = 'continue';
    initialState = structuredClone(loadedSave.state);
    titleError = null;
    appPhase = 'playing';
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

  async function confirmSleep(): Promise<void> {
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
      const result = currentCommands.sleep();
      sleepPromptVisible = false;
      syncDayTransition();
      if (!result.ok || result.code !== 'day-advanced') return;

      saveStatus = 'saving';
      saveError = null;
      try {
        await persistOvernightSave({
          result,
          state: currentCommands.state(),
          repository: saveRepository,
        });
        saveStatus = 'saved';
      } catch (error) {
        saveStatus = 'error';
        saveError = error instanceof Error ? error.message : String(error);
      }
    } finally {
      sleepSubmitting = false;
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
      const result = commands.acknowledgeDaySummary();
      if (result.ok && result.code === 'day-started') {
        saveStatus = 'idle';
        saveError = null;
      }
    } finally {
      summarySubmitting = false;
      syncDayTransition();
    }
  }

  const handleBlur = () => inputGate.set('window-blur', true);
  const handleFocus = () => inputGate.set('window-blur', false);

  $effect(() => {
    if (import.meta.hot) {
      import.meta.hot.data.appPhase = appPhase;
      import.meta.hot.data.saveRepository = saveRepository;
    }
  });

  onMount(() => {
    let disposed = false;

    if (!restorePlayingFromHmr) {
      void loadTitleState().then((titleState) => {
        if (disposed) return;
        saveRepository = titleState.repository;
        loadedSave = titleState.save;
        titleError = titleState.error;
        appPhase = 'title';
      });
    }

    return () => {
      disposed = true;
      resetGamePresentation();
      handleFocus();
      inputGate.set('day-transition', false);
      inputGate.set('economy-panel', false);
    };
  });
</script>

<svelte:window onblur={handleBlur} onfocus={handleFocus} />

<main data-app-shell>
  <StageFrame>
    {#if appPhase === 'playing'}
      <GameHost
        {inputGate}
        {initialState}
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
        {saveStatus}
        {saveError}
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
    {:else}
      <TitleScreen
        loading={appPhase === 'loading-save'}
        canContinue={loadedSave !== null}
        error={titleError}
        onNewGame={startNewGame}
        onContinue={continueGame}
      />
    {/if}
  </StageFrame>
</main>
