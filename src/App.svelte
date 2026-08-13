<script lang="ts">
  import { onMount } from 'svelte';
  import GameHost from './components/GameHost.svelte';
  import Overlay from './components/Overlay.svelte';
  import StageFrame from './components/StageFrame.svelte';
  import { InputGate } from './game/core/InputGate';

  type LifecycleStatus = 'loading' | 'ready' | 'error';

  const inputGate = new InputGate();
  let status = $state<LifecycleStatus>('loading');
  let error = $state<string | null>(null);

  function handleStatus(nextStatus: string): void {
    if (nextStatus === 'World ready') {
      status = 'ready';
    } else if (nextStatus === 'World failed') {
      status = 'error';
    } else {
      status = 'loading';
    }
    if (status !== 'error') error = null;
  }

  function handleError(nextError: Error): void {
    error = nextError.message;
    status = 'error';
  }

  const handleBlur = () => inputGate.set('window-blur', true);
  const handleFocus = () => inputGate.set('window-blur', false);

  onMount(() => () => {
    handleFocus();
  });
</script>

<svelte:window onblur={handleBlur} onfocus={handleFocus} />

<main data-app-shell>
  <StageFrame>
    <GameHost {inputGate} onStatus={handleStatus} onError={handleError} />
    <Overlay {inputGate} {status} {error} />
  </StageFrame>
</main>
