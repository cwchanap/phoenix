<script lang="ts">
  import GameHost from './components/GameHost.svelte';
  import { InputGate } from './game/core/InputGate';

  const inputGate = new InputGate();
  let status = $state('World loading…');
  let error = $state<string | null>(null);

  function handleStatus(nextStatus: string): void {
    status = nextStatus;
    error = null;
  }

  function handleError(nextError: Error): void {
    error = nextError.message;
    status = 'World failed';
  }
</script>

<main data-app-shell>
  <h1>Phoenix</h1>
  <p>{error ? `${status}: ${error}` : status}</p>
  <GameHost {inputGate} onStatus={handleStatus} onError={handleError} />
</main>
