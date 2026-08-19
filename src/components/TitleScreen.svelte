<script lang="ts">
  interface Props {
    loading: boolean;
    canContinue: boolean;
    error: string | null;
    onNewGame: () => void;
    onContinue: () => void;
  }

  let { loading, canContinue, error, onNewGame, onContinue }: Props = $props();
</script>

<section data-title-screen class="title-screen" aria-labelledby="title-heading">
  <div class="title-panel">
    <h1 id="title-heading">Phoenix</h1>
    <p>Isometric farming proof</p>
    {#if loading}
      <p>Loading save…</p>
    {:else if error}
      <p data-title-error role="alert">{error}</p>
    {/if}
    <div class="title-actions">
      <button data-new-game type="button" disabled={loading} onclick={onNewGame}>New Game</button>
      <button data-continue type="button" disabled={loading || !canContinue} onclick={onContinue}>
        Continue
      </button>
    </div>
  </div>
</section>
