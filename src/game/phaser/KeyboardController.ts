import type Phaser from 'phaser';
import type { InputGate } from '../core/InputGate';
import type { MovementInput } from '../core/types';

export interface KeyboardKeys {
  w: Phaser.Input.Keyboard.Key;
  a: Phaser.Input.Keyboard.Key;
  s: Phaser.Input.Keyboard.Key;
  d: Phaser.Input.Keyboard.Key;
}

export class KeyboardController {
  private readonly unsubscribe: () => void;
  private destroyed = false;

  constructor(
    private readonly keys: KeyboardKeys,
    private readonly inputGate: InputGate,
  ) {
    this.unsubscribe = inputGate.subscribe((locked) => {
      if (locked) this.resetKeys();
    });
    if (inputGate.isLocked) this.resetKeys();
  }

  sample(): MovementInput {
    if (this.inputGate.isLocked) return { screenX: 0, screenY: 0 };
    return {
      screenX: Number(this.keys.d.isDown) - Number(this.keys.a.isDown),
      screenY: Number(this.keys.s.isDown) - Number(this.keys.w.isDown),
    };
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.unsubscribe();
    for (const key of Object.values(this.keys)) {
      const plugin = key.plugin;
      if (plugin) plugin.removeKey(key, true, true);
      else key.destroy?.();
    }
  }

  private resetKeys(): void {
    for (const key of Object.values(this.keys)) key.reset();
  }
}
