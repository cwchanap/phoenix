import type Phaser from 'phaser';
import type { InputGate } from '../core/InputGate';
import type { FarmingAction } from '../core/types';
import { GateBoundKeys } from './GateBoundKeys';

export interface ActionKeys {
  one: Phaser.Input.Keyboard.Key;
  two: Phaser.Input.Keyboard.Key;
  three: Phaser.Input.Keyboard.Key;
  four: Phaser.Input.Keyboard.Key;
  space: Phaser.Input.Keyboard.Key;
  e: Phaser.Input.Keyboard.Key;
}

export interface ActionSample {
  selectedAction: FarmingAction | null;
  useSelected: boolean;
  interact: boolean;
}

export class ActionController {
  private readonly gateBoundKeys: GateBoundKeys;
  private previousOneDown = false;
  private previousTwoDown = false;
  private previousThreeDown = false;
  private previousFourDown = false;
  private previousSpaceDown = false;
  private previousInteractDown = false;

  constructor(
    private readonly keys: ActionKeys,
    inputGate: InputGate,
  ) {
    this.gateBoundKeys = new GateBoundKeys(
      inputGate,
      Object.values(keys),
      () => this.resetPreviousDown(),
    );
  }

  sample(): ActionSample {
    if (this.gateBoundKeys.isLocked()) {
      return { selectedAction: null, useSelected: false, interact: false };
    }

    const oneDown = this.keys.one.isDown;
    const twoDown = this.keys.two.isDown;
    const threeDown = this.keys.three.isDown;
    const fourDown = this.keys.four.isDown;
    const spaceDown = this.keys.space.isDown;
    const eDown = this.keys.e.isDown;

    const onePressed = oneDown && !this.previousOneDown;
    const twoPressed = twoDown && !this.previousTwoDown;
    const threePressed = threeDown && !this.previousThreeDown;
    const fourPressed = fourDown && !this.previousFourDown;
    const spacePressed = spaceDown && !this.previousSpaceDown;
    const ePressed = eDown && !this.previousInteractDown;

    this.previousOneDown = oneDown;
    this.previousTwoDown = twoDown;
    this.previousThreeDown = threeDown;
    this.previousFourDown = fourDown;
    this.previousSpaceDown = spaceDown;
    this.previousInteractDown = eDown;

    let selectedAction: FarmingAction | null = null;
    if (onePressed) selectedAction = 'hoe';
    else if (twoPressed) selectedAction = 'seeds';
    else if (threePressed) selectedAction = 'wateringCan';
    else if (fourPressed) selectedAction = 'hands';

    return {
      selectedAction,
      useSelected: spacePressed,
      interact: ePressed,
    };
  }

  destroy(): void {
    this.gateBoundKeys.destroy();
  }

  private resetPreviousDown(): void {
    this.previousOneDown = false;
    this.previousTwoDown = false;
    this.previousThreeDown = false;
    this.previousFourDown = false;
    this.previousSpaceDown = false;
    this.previousInteractDown = false;
  }
}
