<script lang="ts">
  import { onMount } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  import type { CommandResult, GameSnapshot, GameState } from '../game/core/types';
  import { GameLifecycle } from '../game/phaser/GameLifecycle';
  import { createGame } from '../game/phaser/createGame';
  import type {
    DebugSnapshot,
    ProofSceneDependencies,
    SceneCommands,
  } from '../game/phaser/ProofScene';
  import type { InteractionIntent } from '../game/phaser/interactionIntent';

  interface Props {
    inputGate: InputGate;
    initialState: GameState | null;
    onStatus: (status: string) => void;
    onError: (error: Error) => void;
    onReady: (commands: SceneCommands) => void;
    onGameSnapshot: (snapshot: GameSnapshot) => void;
    onCommandResult: (result: CommandResult) => void;
    onInteractIntent: (intent: InteractionIntent) => void;
  }

  let {
    inputGate,
    initialState,
    onStatus,
    onError,
    onReady,
    onGameSnapshot,
    onCommandResult,
    onInteractIntent,
  }: Props = $props();
  let host = $state<HTMLDivElement>();
  let latestSnapshot: DebugSnapshot | null = null;
  let latestGameSnapshot: GameSnapshot | null = null;
  let dependencies: ProofSceneDependencies | null = null;

  const lifecycle = new GameLifecycle<ProofSceneDependencies>(createGame);
  const stop = () => lifecycle.stop();
  const restart = () => {
    if (!host || !dependencies) return;
    latestSnapshot = null;
    latestGameSnapshot = null;
    onStatus('World loading…');
    lifecycle.start(host, dependencies);
  };

  function cloneSnapshot(snapshot: DebugSnapshot): DebugSnapshot {
    return {
      player: {
        position: { ...snapshot.player.position },
        facing: snapshot.player.facing,
        world: { ...snapshot.player.world },
      },
      target: snapshot.target ? { ...snapshot.target } : null,
      visibleTarget: snapshot.visibleTarget,
      locked: snapshot.locked,
      depths: { ...snapshot.depths },
      camera: {
        scrollX: snapshot.camera.scrollX,
        scrollY: snapshot.camera.scrollY,
        bounds: { ...snapshot.camera.bounds },
      },
    };
  }

  function removeDevelopmentHook(): void {
    if (import.meta.env.DEV) delete window.__PHOENIX_TEST__;
  }

  function publishDevelopmentHook(): void {
    if (!import.meta.env.DEV || !host || !dependencies) return;
    window.__PHOENIX_TEST__ = {
      snapshot: () => {
        if (!latestSnapshot) throw new Error('world is not ready');
        return cloneSnapshot(latestSnapshot);
      },
      gameSnapshot: () => {
        if (!latestGameSnapshot) throw new Error('game world is not ready');
        return structuredClone(latestGameSnapshot);
      },
      remount: () => {
        restart();
      },
    };
  }

  const cleanup = () => {
    stop();
    latestSnapshot = null;
    latestGameSnapshot = null;
    removeDevelopmentHook();
  };

  if (import.meta.hot) {
    import.meta.hot.dispose(cleanup);
  }

  onMount(() => {
    if (!host) return cleanup;

    dependencies = {
      inputGate,
      initialState,
      onReady: (commands) => {
        onStatus('World ready');
        onReady(commands);
      },
      onError: (error) => {
        latestSnapshot = null;
        latestGameSnapshot = null;
        queueMicrotask(stop);
        onError(error);
      },
      onSnapshot: (snapshot) => {
        latestSnapshot = cloneSnapshot(snapshot);
      },
      onGameSnapshot: (snapshot) => {
        latestGameSnapshot = structuredClone(snapshot);
        onGameSnapshot(snapshot);
      },
      onCommandResult,
      onInteractIntent,
    };

    try {
      restart();
      publishDevelopmentHook();
    } catch (error) {
      queueMicrotask(stop);
      onError(error instanceof Error ? error : new Error(String(error)));
    }

    return cleanup;
  });
</script>

<div data-game-host bind:this={host}></div>
