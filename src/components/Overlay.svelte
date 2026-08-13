<script lang="ts">
  import { onMount } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';

  type LifecycleStatus = 'loading' | 'ready' | 'error';

  interface Props {
    inputGate: InputGate;
    status: LifecycleStatus;
    error: string | null;
  }

  let { inputGate, status, error }: Props = $props();
  let overlayLocked = $state(false);
  let locked = $state(false);

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
    <p>{status === 'ready' ? 'World ready' : 'Loading world…'}</p>
    <p>Move: WASD</p>
    <p>World input: {locked ? 'Locked' : 'Active'}</p>
    <button type="button" aria-pressed={overlayLocked} onclick={toggle}>
      {overlayLocked ? 'Unlock world input' : 'Lock world input'}
    </button>
  {/if}
</aside>
