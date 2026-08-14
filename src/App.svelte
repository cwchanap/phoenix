<script lang="ts">
  import { onMount } from 'svelte';
  import GameHost from './components/GameHost.svelte';
  import Overlay from './components/Overlay.svelte';
  import StageFrame from './components/StageFrame.svelte';
  import { InputGate } from './game/core/InputGate';
  import type { CommandResult, GameSnapshot } from './game/core/types';
  import type { SceneCommands } from './game/phaser/ProofScene';

  type LifecycleStatus = 'loading' | 'ready' | 'error';

  const inputGate = new InputGate();
  let status = $state<LifecycleStatus>('loading');
  let error = $state<string | null>(null);
  let gameSnapshot = $state.raw<GameSnapshot | null>(null);
  let commandResult = $state.raw<CommandResult | null>(null);
  let commands = $state.raw<SceneCommands | null>(null);
  let sleepPromptVisible = $state(false);

  function closeSleepPrompt(): void {
    sleepPromptVisible = false;
    inputGate.set('sleep-confirmation', false);
  }

  function resetGamePresentation(): void {
    gameSnapshot = null;
    commandResult = null;
    commands = null;
    closeSleepPrompt();
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
  }

  function handleCommandResult(nextResult: CommandResult): void {
    commandResult = nextResult;
  }

  function handleSleepPrompt(): void {
    if (sleepPromptVisible) return;
    sleepPromptVisible = true;
    inputGate.set('sleep-confirmation', true);
  }

  function confirmSleep(): void {
    if (!sleepPromptVisible) return;

    const currentCommands = commands;
    if (!currentCommands) {
      closeSleepPrompt();
      return;
    }

    try {
      currentCommands.sleep();
    } finally {
      closeSleepPrompt();
    }
  }

  function cancelSleep(): void {
    closeSleepPrompt();
  }

  const handleBlur = () => inputGate.set('window-blur', true);
  const handleFocus = () => inputGate.set('window-blur', false);

  onMount(() => () => {
    closeSleepPrompt();
    handleFocus();
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
      onSleepPrompt={handleSleepPrompt}
    />
    <Overlay
      {inputGate}
      {status}
      {error}
      snapshot={gameSnapshot}
      result={commandResult}
      {commands}
      {sleepPromptVisible}
      onConfirmSleep={confirmSleep}
      onCancelSleep={cancelSleep}
    />
  </StageFrame>
</main>
