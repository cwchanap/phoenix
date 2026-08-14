/// <reference types="vite/client" />

import type { DebugSnapshot } from './game/phaser/ProofScene';
import type { GameSnapshot } from './game/core/types';

interface PhoenixTestHook {
  snapshot(): DebugSnapshot;
  gameSnapshot(): GameSnapshot;
  remount(): void;
}

declare global {
  interface Window {
    __PHOENIX_TEST__?: PhoenixTestHook;
    __PHOENIX_HMR_COUNT__?: number;
  }
}

export {};
