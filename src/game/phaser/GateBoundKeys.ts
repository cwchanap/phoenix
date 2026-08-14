import type Phaser from 'phaser';
import type { InputGate } from '../core/InputGate';

export class GateBoundKeys {
  private destroyed = false;
  private locked: boolean;
  private readonly unsubscribe: () => void;

  constructor(
    gate: InputGate,
    private readonly keys: Phaser.Input.Keyboard.Key[],
    private readonly resetController: () => void,
  ) {
    this.locked = gate.isLocked;
    this.unsubscribe = gate.subscribe((locked) => {
      const enteredLock = locked && !this.locked;
      this.locked = locked;
      if (enteredLock) this.reset();
    });
    if (this.locked) this.reset();
  }

  isLocked(): boolean {
    return this.locked;
  }

  reset(): void {
    for (const key of this.keys) key.reset();
    this.resetController();
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.unsubscribe();
    for (const key of this.keys) {
      const plugin = key.plugin;
      if (plugin) plugin.removeKey(key, true, true);
      else key.destroy?.();
    }
  }
}
