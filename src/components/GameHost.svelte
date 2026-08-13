<script lang="ts">
  import { onMount } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  import { GameLifecycle } from '../game/phaser/GameLifecycle';
  import { createGame } from '../game/phaser/createGame';
  import type { DebugSnapshot, ProofSceneDependencies } from '../game/phaser/ProofScene';

  interface Props {
    inputGate: InputGate;
    onStatus: (status: string) => void;
    onError: (error: Error) => void;
  }

  let { inputGate, onStatus, onError }: Props = $props();
  let host = $state<HTMLDivElement>();
  let latestSnapshot: DebugSnapshot | null = null;
  let dependencies: ProofSceneDependencies | null = null;

  const lifecycle = new GameLifecycle<ProofSceneDependencies>(createGame);
  const stop = () => lifecycle.stop();

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
      remount: () => {
        if (host && dependencies) lifecycle.start(host, dependencies);
      },
    };
  }

  const cleanup = () => {
    stop();
    removeDevelopmentHook();
  };

  if (import.meta.hot) {
    import.meta.hot.dispose(cleanup);
  }

  onMount(() => {
    if (!host) return cleanup;

    dependencies = {
      inputGate,
      onReady: () => onStatus('World ready'),
      onError: (error) => {
        queueMicrotask(stop);
        onError(error);
      },
      onSnapshot: (snapshot) => {
        latestSnapshot = cloneSnapshot(snapshot);
      },
    };

    try {
      lifecycle.start(host, dependencies);
      publishDevelopmentHook();
    } catch (error) {
      queueMicrotask(stop);
      onError(error instanceof Error ? error : new Error(String(error)));
    }

    return cleanup;
  });
</script>

<div data-game-host bind:this={host}></div>
