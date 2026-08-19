<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { CROP_DEFINITIONS, CROP_KINDS } from '../game/core/cropDefinitions';
  import { VILLAGER_DEFINITIONS } from '../game/core/villagerDefinitions';
  import type {
    CropKind,
    GameSnapshot,
    RelationshipLevel,
    SocialFeedback,
    VillagerId,
  } from '../game/core/types';

  interface Props {
    villagerId: VillagerId;
    social: SocialFeedback;
    snapshot: GameSnapshot;
    onGift: (crop: CropKind) => void;
    onClose: () => void;
  }

  const roleLabels: Readonly<Record<VillagerId, string>> = {
    shopkeeper: 'Seed-shop keeper',
    farmer: 'Neighbouring farmer',
    resident: 'Village resident',
  };

  let { villagerId, social, snapshot, onGift, onClose }: Props = $props();
  let lineIndex = $state(0);
  let continueButton = $state<HTMLButtonElement | null>(null);
  let closeButton = $state<HTMLButtonElement | null>(null);
  let dialog = $state<HTMLDivElement | null>(null);

  const villager = $derived(VILLAGER_DEFINITIONS[villagerId]);
  const relationship = $derived(snapshot.relationships[villagerId]);
  const currentLine = $derived(social.lines[lineIndex] ?? '');
  const hasMoreLines = $derived(lineIndex < social.lines.length - 1);
  const carriedCrops = $derived(CROP_KINDS.filter((kind) => snapshot.inventory.crops[kind] > 0));

  function relationshipLabel(level: RelationshipLevel): string {
    switch (level) {
      case 'stranger':
        return 'Stranger';
      case 'friend':
        return 'Friend';
      case 'closeFriend':
        return 'Close Friend';
      default:
        return assertNever(level);
    }
  }

  function assertNever(value: never): never {
    throw new Error(`Unsupported relationship level: ${String(value)}`);
  }

  function focusPrimary(): void {
    void tick().then(() =>
      requestAnimationFrame(() => {
        if (hasMoreLines) continueButton?.focus();
        else
          (
            dialog?.querySelector<HTMLButtonElement>('[data-dialogue-gift]') ?? closeButton
          )?.focus();
      }),
    );
  }

  function continueDialogue(): void {
    if (!hasMoreLines) return;
    lineIndex += 1;
    focusPrimary();
  }

  function handleKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Escape') return;
    event.preventDefault();
    onClose();
  }

  onMount(() => {
    focusPrimary();
  });
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="sleep-modal-layer dialogue-modal-layer" data-dialogue-layer>
  <div
    class="sleep-dialog dialogue-dialog"
    data-dialogue-panel
    role="dialog"
    tabindex="-1"
    aria-modal="true"
    aria-labelledby="dialogue-panel-title"
    bind:this={dialog}
  >
    <div class="dialogue-header">
      <div class="dialogue-portrait" data-dialogue-portrait aria-hidden="true">?</div>
      <div>
        <h2 id="dialogue-panel-title">{villager.displayName}</h2>
        <p class="dialogue-role" data-dialogue-role>{roleLabels[villagerId]}</p>
      </div>
    </div>

    <p class="dialogue-relationship" data-dialogue-relationship>
      {relationshipLabel(relationship.level)} · {relationship.points} relationship
      {relationship.points === 1 ? 'point' : 'points'}
    </p>

    <p class="dialogue-line" data-dialogue-line>{currentLine}</p>

    {#if social.pointsGained > 0}
      <p class="dialogue-points" data-dialogue-points>
        +{social.pointsGained} relationship {social.pointsGained === 1 ? 'point' : 'points'}
      </p>
    {/if}
    {#if social.giftReaction}
      <p class="dialogue-reaction" data-dialogue-reaction>
        {social.giftReaction === 'favourite' ? 'Favourite gift!' : 'Gift accepted.'}
      </p>
    {/if}

    {#if hasMoreLines}
      <div class="dialogue-actions">
        <button bind:this={continueButton} type="button" onclick={continueDialogue}>Continue</button
        >
      </div>
    {:else}
      <section class="dialogue-gifts" aria-label="Give a harvested crop">
        <h3>Give a gift</h3>
        {#if carriedCrops.length > 0}
          <div class="dialogue-gift-list">
            {#each carriedCrops as kind (kind)}
              <button type="button" data-dialogue-gift onclick={() => onGift(kind)}>
                Give {CROP_DEFINITIONS[kind].displayName}
              </button>
            {/each}
          </div>
        {:else}
          <p data-dialogue-no-crops>No harvested crops to give</p>
        {/if}
      </section>
      <div class="dialogue-actions">
        <button bind:this={closeButton} type="button" onclick={onClose}>Close</button>
      </div>
    {/if}
  </div>
</div>
