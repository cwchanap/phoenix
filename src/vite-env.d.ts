/// <reference types="vite/client" />

import type { DebugSnapshot } from './game/phaser/ProofScene';

declare global {
  interface Window {
    __PHOENIX_TEST__?: {
      snapshot(): DebugSnapshot;
      remount(): void;
    };
    __PHOENIX_HMR_COUNT__?: number;
  }
}

export {};
