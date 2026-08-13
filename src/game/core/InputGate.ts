export type InputLockListener = (locked: boolean) => void;

export class InputGate {
  private readonly reasons = new Set<string>();
  private readonly listeners = new Set<InputLockListener>();

  get isLocked(): boolean {
    return this.reasons.size > 0;
  }

  set(reason: string, locked: boolean): void {
    if (!reason) return;

    const wasLocked = this.isLocked;
    if (locked) this.reasons.add(reason);
    else this.reasons.delete(reason);

    if (wasLocked === this.isLocked) return;
    for (const listener of this.listeners) listener(this.isLocked);
  }

  subscribe(listener: InputLockListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }
}
