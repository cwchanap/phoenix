import Phaser from 'phaser';
import { ProofScene, type ProofSceneDependencies } from './ProofScene';

export function createGame(parent: HTMLElement, deps: ProofSceneDependencies): Phaser.Game {
  return new Phaser.Game({
    type: Phaser.WEBGL,
    parent,
    width: 640,
    height: 360,
    backgroundColor: '#17251f',
    pixelArt: true,
    antialias: false,
    roundPixels: true,
    smoothPixelArt: false,
    scale: { mode: Phaser.Scale.NONE, width: 640, height: 360 },
    scene: [new ProofScene(deps)],
  });
}
