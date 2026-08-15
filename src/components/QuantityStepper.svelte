<script lang="ts">
  interface Props {
    quantity: number;
    max: number;
    disabled: boolean;
    itemName: string;
    actionLabel: 'Buy' | 'Deposit';
    onQuantityChange: (quantity: number) => void;
    onSubmit: () => void;
  }

  let {
    quantity,
    max,
    disabled,
    itemName,
    actionLabel,
    onQuantityChange,
    onSubmit,
  }: Props = $props();

  const transactionDisabled = $derived(disabled || max < 1 || quantity < 1 || quantity > max);
  const setQuantity = (value: number) => {
    if (disabled || max < 1) return;
    onQuantityChange(Math.min(max, Math.max(1, value)));
  };
</script>

<div class="quantity-stepper" aria-label={`${actionLabel} quantity`}>
  <button
    type="button"
    aria-label="Decrease quantity"
    disabled={disabled || max < 1 || quantity <= 1}
    onclick={() => setQuantity(quantity - 1)}
  >−</button>
  <output aria-live="polite">{quantity}</output>
  <button
    type="button"
    aria-label="Increase quantity"
    disabled={disabled || max < 1 || quantity >= max}
    onclick={() => setQuantity(quantity + 1)}
  >+</button>
  <button
    type="button"
    disabled={disabled || max < 1 || quantity === max}
    onclick={() => setQuantity(max)}
  >Max</button>
  <button
    type="button"
    disabled={transactionDisabled}
    onclick={onSubmit}
  >{actionLabel} {quantity} {itemName}{quantity === 1 ? '' : 's'}</button>
</div>
