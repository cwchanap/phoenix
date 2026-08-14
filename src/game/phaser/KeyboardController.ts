import type Phaser from 'phaser';
import type { InputGate } from '../core/InputGate';
import type { MovementInput } from '../core/types';
import { GateBoundKeys } from './GateBoundKeys';

export interface KeyboardKeys {
  w: Phaser.Input.Keyboard.Key;
  a: Phaser.Input.Keyboard.Key;
  s: Phaser.Input.Keyboard.Key;
  d: Phaser.Input.Keyboard.Key;
}

export class KeyboardController {
  private readonly gateBoundKeys: GateBoundKeys;

  constructor(
    private readonly keys: KeyboardKeys,
    inputGate: InputGate,
  ) {
    this.gateBoundKeys = new GateBoundKeys(inputGate, Object.values(keys), () => {});
  }

  sample(): MovementInput {
    if (this.gateBoundKeys.isLocked()) return { screenX: 0, screenY: 0 };
    return {
      screenX: Number(this.keys.d.isDown) - Number(this.keys.a.isDown),
      screenY: Number(this.keys.s.isDown) - Number(this.keys.w.isDown),
    };
  }

  destroy(): void {
    this.gateBoundKeys.destroy();
  }
}
