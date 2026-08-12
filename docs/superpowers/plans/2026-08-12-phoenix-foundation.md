# Phoenix Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver HPA-588 as a macOS-first browser and Tauri application where a player moves through a crisp `12×12` sprite-isometric proof world, collides with authored footprints, sorts correctly around tall scenery, and targets the logical tile ahead.

**Architecture:** Svelte owns one fitted `640×360` stage and its screen-space overlay; Phaser owns rendering, camera, asset loading, and keyboard sampling. Framework-free TypeScript owns projection, movement, collision, facing, and targeting, while the Tauri Rust crate remains a shell with no gameplay logic.

**Tech Stack:** Bun 1.3.1 with `@types/bun` 1.3.14, TypeScript 7.0.2, Vite 8.2.1, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Tauri CLI 2.11.4, Tauri crate 2.11.5, Rust/Cargo 1.96, Xcode 26.6, and Tiled 1.12-compatible JSON.

## Global Constraints

- Implement only HPA-588; HPA-591 farming rules and all later roadmap slices remain out of scope.
- Use Bun as the sole JavaScript package manager and script entry point.
- Commit `bun.lock` as the only JavaScript package-manager lockfile and commit the Tauri crate's `Cargo.lock`.
- Pin every direct JavaScript dependency exactly; pin Phaser to `4.2.1`.
- Verify desktop behavior on macOS only; keep ordinary Tauri configuration portable without claiming Windows or Linux verification.
- Use one fixed `640×360` logical stage, integer-fit scaling, letterboxing, and an initial Tauri window of `1280×720` with a `640×360` minimum.
- Use a finite `12×12`, `64×32`, 2:1 isometric Tiled map with embedded tileset definitions because Phaser does not support external Tiled tilesets.
- Keep authoritative movement, collision, facing, targeting, and projection rules in framework-free TypeScript.
- Keep gameplay rules out of Rust, Phaser scene fields, and Svelte stores.
- Use explicit logical ground footprints and footpoint depth sorting; never collide against transparent sprite bounds.
- Keep one walkable elevation plane, fixed camera projection/rotation/zoom, and no second renderer.
- Use `com.hapadona.phoenix` as the Tauri bundle identifier and `Phoenix` as the application and window title.
- Do not add a backend, database, final art, multiple maps, pathfinding, crop rules, inventory, save data, NPCs, shaders, 3D geometry, or 3D physics.

## File Map

### Application and configuration

- `package.json` — exact dependencies and all Bun entry points.
- `bun.lock` — the only JavaScript dependency lockfile.
- `index.html`, `vite.config.ts`, `svelte.config.js`, `tsconfig.json` — Vite/Svelte application configuration.
- `src/main.ts`, `src/app.css`, `src/App.svelte` — browser entry, global presentation, and composition root.
- `src/vite-env.d.ts` — Vite types plus the development-only browser test contract.
- `src-tauri/tauri.conf.json` — window, build, bundle, and frontend settings.
- `src-tauri/Cargo.toml`, `src-tauri/Cargo.lock`, `src-tauri/build.rs`, `src-tauri/src/main.rs`, `src-tauri/src/lib.rs` — minimal Tauri shell.
- `src-tauri/capabilities/default.json` — least-privilege main-window capability.
- `src-tauri/icons/*` — Tauri-generated desktop icons from one committed SVG source.

### Framework-free world rules

- `src/game/core/types.ts` — shared structural types only.
- `src/game/core/isometric.ts` — reversible projection, cell diamonds, projected bounds, and stable depth ordering.
- `src/game/core/collision.ts` — logical rectangle intersection and axis-separated motion.
- `src/game/core/InputGate.ts` — nested input locks and lock-state notifications.
- `src/game/core/ProofWorld.ts` — authoritative player position, movement, facing, collision, and target selection.

### Phaser integration and map data

- `src/game/phaser/ProjectionAdapter.ts` — Phaser-facing wrapper around pure projection functions.
- `src/game/phaser/loadProofMap.ts` — fail-fast Tiled JSON validation and conversion to `ProofMap`.
- `src/game/phaser/KeyboardController.ts` — Phaser key sampling and reset behavior.
- `src/game/phaser/ProofScene.ts` — asset loading, visual synchronization, depth assignment, target rendering, and camera follow.
- `src/game/phaser/GameLifecycle.ts` — idempotent create/destroy ownership.
- `src/game/phaser/createGame.ts` — the one Phaser configuration factory.
- `src/assets/maps/proof-map.json` — finite Tiled map with embedded ground/scenery tilesets.
- `src/assets/sprites/proof-tiles.png` — two `64×32` ground frames.
- `src/assets/sprites/proof-player.png` — four `32×48` facing frames.
- `src/assets/sprites/proof-scenery.png` — two `96×96` scenery frames.
- `tools/generate-proof-assets.ts` — deterministic PNG and Tiled JSON authoring script.

### Svelte presentation

- `src/components/GameHost.svelte` — Phaser host and lifecycle bridge.
- `src/components/Overlay.svelte` — controls, status, error panel, and input-lock toggle.
- `src/components/StageFrame.svelte` — integer-fit shared canvas/overlay transform.
- `src/ui/stageScale.ts` — pure scale and letterbox calculation.

### Tests and documentation

- `tests/config/scaffold.test.ts` — dependency, script, lockfile, and Tauri contract.
- `tests/game/isometric.test.ts` — projection, edge, diamond, bounds, and depth tests.
- `tests/game/ProofWorld.test.ts` — movement, collision, facing, and targeting tests.
- `tests/game/InputGate.test.ts` — nested lock transition tests.
- `tests/game/loadProofMap.test.ts` — authored map and malformed-map validation tests.
- `tests/game/GameLifecycle.test.ts` — duplicate-instance and idempotent cleanup tests.
- `tests/game/stageScale.test.ts` — integer scaling and letterbox tests.
- `tests/e2e/lifecycle.pw.ts` — canvas lifecycle, overlay lock, blur, resize, remount, and HMR checks; the `.pw.ts` suffix prevents Bun's unit-test discovery from loading it.
- `tests/e2e/world.pw.ts` — keyboard navigation, collision, targeting, depth, and camera checks; Playwright selects it explicitly.
- `playwright.config.ts` — single pinned Chromium project and Vite web server.
- `tools/verify-clean-checkout.ts` — archive-based clean-checkout verification.
- `README.md` — setup, commands, controls, architecture, and macOS verification boundary.

---

### Task 1: Bun, Svelte, Vite, and Tauri Application Shell

**Files:**

- Create: `.gitignore`
- Create: `package.json`
- Create: `index.html`
- Create: `tsconfig.json`
- Create: `svelte.config.js`
- Create: `vite.config.ts`
- Create: `src/vite-env.d.ts`
- Create: `src/main.ts`
- Create: `src/app.css`
- Create: `src/App.svelte`
- Create: `src-tauri/Cargo.toml`
- Create: `src-tauri/build.rs`
- Create: `src-tauri/src/main.rs`
- Create: `src-tauri/src/lib.rs`
- Create: `src-tauri/capabilities/default.json`
- Create: `src-tauri/tauri.conf.json`
- Create: `src-tauri/icons/app-icon.svg`
- Generate: `bun.lock`
- Generate: `src-tauri/Cargo.lock`
- Generate: `src-tauri/icons/*`
- Test: `tests/config/scaffold.test.ts`

**Interfaces:**

- Consumes: none; this is the first executable repository task.
- Produces: Bun scripts `dev`, `check`, `test`, `test:e2e:install`, `test:e2e`, `build`, `tauri`, `tauri:dev`, `tauri:build`, `assets:generate`, and `verify:clean`.
- Produces: Vite at strict URL `http://localhost:1420`, frontend output `dist/`, and a minimal Tauri `run()` entry point.

- [ ] **Step 1: Write the failing scaffold contract test**

```ts
// tests/config/scaffold.test.ts
import { describe, expect, test } from 'bun:test';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');

describe('Phoenix scaffold', () => {
  test('pins the approved direct JavaScript dependencies', async () => {
    const pkg = await Bun.file(resolve(root, 'package.json')).json();
    expect(pkg.packageManager).toBe('bun@1.3.1');
    expect(pkg.dependencies).toEqual({ phaser: '4.2.1', svelte: '5.56.8' });
    expect(pkg.devDependencies).toEqual({
      '@playwright/test': '1.62.1',
      '@sveltejs/vite-plugin-svelte': '7.3.0',
      '@tauri-apps/cli': '2.11.4',
      '@types/bun': '1.3.14',
      'svelte-check': '4.7.5',
      typescript: '7.0.2',
      vite: '8.2.1',
    });
  });

  test('uses only Bun and Cargo lockfiles', () => {
    expect(existsSync(resolve(root, 'bun.lock'))).toBe(true);
    expect(existsSync(resolve(root, 'src-tauri/Cargo.lock'))).toBe(true);
    for (const forbidden of ['package-lock.json', 'pnpm-lock.yaml', 'yarn.lock']) {
      expect(existsSync(resolve(root, forbidden))).toBe(false);
    }
  });

  test('configures the macOS-first Tauri window and Bun hooks', async () => {
    const config = await Bun.file(resolve(root, 'src-tauri/tauri.conf.json')).json();
    expect(config.identifier).toBe('com.hapadona.phoenix');
    expect(config.build).toEqual({
      beforeDevCommand: 'bun run dev',
      beforeBuildCommand: 'bun run build',
      devUrl: 'http://localhost:1420',
      frontendDist: '../dist',
    });
    expect(config.app.windows[0]).toMatchObject({
      label: 'main', title: 'Phoenix', width: 1280, height: 720,
      minWidth: 640, minHeight: 360,
    });
  });
});
```

- [ ] **Step 2: Run the scaffold test to observe RED**

Run: `rtk bun test tests/config/scaffold.test.ts`

Expected: FAIL because `package.json`, lockfiles, and Tauri configuration do not exist.

- [ ] **Step 3: Create the exact Bun package and frontend configuration**

```json
{
  "name": "phoenix",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "packageManager": "bun@1.3.1",
  "scripts": {
    "dev": "vite --host localhost --port 1420 --strictPort",
    "check": "svelte-check --tsconfig ./tsconfig.json",
    "test": "bun test",
    "test:e2e:install": "playwright install chromium",
    "test:e2e": "playwright test",
    "build": "vite build",
    "tauri": "tauri",
    "tauri:dev": "tauri dev",
    "tauri:build": "tauri build",
    "assets:generate": "bun run tools/generate-proof-assets.ts",
    "verify:clean": "bun run tools/verify-clean-checkout.ts"
  },
  "dependencies": {
    "phaser": "4.2.1",
    "svelte": "5.56.8"
  },
  "devDependencies": {
    "@playwright/test": "1.62.1",
    "@sveltejs/vite-plugin-svelte": "7.3.0",
    "@tauri-apps/cli": "2.11.4",
    "@types/bun": "1.3.14",
    "svelte-check": "4.7.5",
    "typescript": "7.0.2",
    "vite": "8.2.1"
  }
}
```

Create `.gitignore` with exactly these generated outputs (the authored map, proof sprites, and desktop icons remain tracked):

```gitignore
.DS_Store
node_modules/
dist/
playwright-report/
test-results/
src-tauri/target/
```

Create `vite.config.ts` with the Svelte plugin, strict port `1420`, host `localhost`, and `server.watch.ignored: ['**/src-tauri/**']`. Create a strict bundler-mode `tsconfig.json` that includes `src`, `tests`, `tools`, `vite.config.ts`, and `playwright.config.ts`. Create `svelte.config.js` with `vitePreprocess()`.

```ts
// vite.config.ts
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: 'localhost',
    port: 1420,
    strictPort: true,
    watch: { ignored: ['**/src-tauri/**'] },
  },
});
```

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "allowJs": true,
    "checkJs": true,
    "isolatedModules": true,
    "strict": true,
    "skipLibCheck": true,
    "types": ["bun", "vite/client"]
  },
  "include": ["src/**/*.d.ts", "src/**/*.ts", "src/**/*.svelte", "tests/**/*.ts", "tools/**/*.ts", "vite.config.ts", "playwright.config.ts"]
}
```

Use this browser entry contract:

```ts
// src/main.ts
import { mount } from 'svelte';
import App from './App.svelte';
import './app.css';

mount(App, { target: document.getElementById('app')! });
```

Use a minimal `App.svelte` that renders `<main data-app-shell><h1>Phoenix</h1><p>Foundation loading…</p></main>`, and reset `html`, `body`, and `#app` to a full-size, margin-free dark viewport in `src/app.css`.

- [ ] **Step 4: Create the minimal Tauri 2 shell**

```toml
# src-tauri/Cargo.toml
[package]
name = "phoenix"
version = "0.1.0"
description = "Phoenix farming-life MVP"
edition = "2021"

[lib]
name = "phoenix_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "=2.6.3", features = [] }

[dependencies]
tauri = { version = "=2.11.5", features = [] }
```

```rust
// src-tauri/src/lib.rs
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running Phoenix");
}
```

Set `tauri.conf.json` to the exact identifier, build hooks, URL, dimensions, and title asserted above. Configure `bundle.active: true`, macOS targets `['app', 'dmg']`, and the standard generated desktop icon paths. Keep the Rust crate command-free and plugin-free.

```json
{
  "$schema": "../node_modules/@tauri-apps/cli/config.schema.json",
  "productName": "Phoenix",
  "version": "0.1.0",
  "identifier": "com.hapadona.phoenix",
  "build": {
    "beforeDevCommand": "bun run dev",
    "beforeBuildCommand": "bun run build",
    "devUrl": "http://localhost:1420",
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [{
      "label": "main", "title": "Phoenix",
      "width": 1280, "height": 720,
      "minWidth": 640, "minHeight": 360,
      "resizable": true, "fullscreen": false
    }],
    "security": { "csp": null }
  },
  "bundle": {
    "active": true,
    "targets": ["app", "dmg"],
    "icon": ["icons/32x32.png", "icons/128x128.png", "icons/128x128@2x.png", "icons/icon.icns", "icons/icon.ico"]
  }
}
```

`build.rs` contains `fn main() { tauri_build::build() }`. Use these exact remaining shell files; the Windows attribute is inert on macOS and keeps the ordinary Tauri shell portable without expanding the verification claim:

```rust
// src-tauri/src/main.rs
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    phoenix_lib::run();
}
```

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default capability for the Phoenix main window",
  "windows": ["main"],
  "permissions": ["core:default"]
}
```

- [ ] **Step 5: Install dependencies and generate desktop icons**

Create the icon source exactly, then let Tauri derive every platform size from it:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect x="32" y="32" width="448" height="448" rx="96" fill="#173e32"/>
  <circle cx="256" cy="192" r="72" fill="#f2b84b"/>
  <path d="M244 392V264h24v128z" fill="#d8e7a2"/>
  <path d="M256 304c-64 0-96-32-96-80 56 0 96 24 96 80z" fill="#6fa85b"/>
  <path d="M256 344c64 0 96-32 96-80-56 0-96 24-96 80z" fill="#8fc96a"/>
  <path d="M256 376c-48 0-72-24-72-60 42 0 72 18 72 60z" fill="#4f8249"/>
</svg>
```

Then run:

```bash
rtk bun install
rtk bun tauri icon src-tauri/icons/app-icon.svg --output src-tauri/icons
rtk cargo generate-lockfile --manifest-path src-tauri/Cargo.toml
```

Expected: `bun.lock`, `src-tauri/Cargo.lock`, `src-tauri/icons/icon.icns`, `icon.ico`, and standard PNG sizes are generated; no npm, pnpm, or Yarn lockfile appears.

- [ ] **Step 6: Run the scaffold GREEN checks**

Run:

```bash
rtk bun test tests/config/scaffold.test.ts
rtk bun run check
rtk bun run build
rtk cargo check --manifest-path src-tauri/Cargo.toml
```

Expected: all commands exit 0; `dist/index.html` exists; Cargo generates and locks the minimal shell.

- [ ] **Step 7: Commit the application shell**

```bash
rtk git add .gitignore package.json bun.lock index.html tsconfig.json svelte.config.js vite.config.ts src src-tauri tests/config/scaffold.test.ts
rtk git commit -m "feat: bootstrap Phoenix application shell"
```

### Task 2: Isometric Projection and Stable Depth Ordering

**Files:**

- Create: `src/game/core/types.ts`
- Create: `src/game/core/isometric.ts`
- Create: `src/game/phaser/ProjectionAdapter.ts`
- Test: `tests/game/isometric.test.ts`

**Interfaces:**

- Consumes: TypeScript/Bun test setup from Task 1.
- Produces: `GridPoint`, `GridCell`, `WorldPoint`, `WorldRect`, `ProjectionMetrics`, `DepthEntry`.
- Produces: `gridToWorld(point, metrics)`, `worldToGrid(point, metrics)`, `gridCellAtWorld(point, metrics)`, `cellDiamond(cell, metrics)`, `projectedMapBounds(size, metrics, topPadding)`, and `sortDepthEntries(entries)`.
- Produces: `new ProjectionAdapter(metrics, mapSize)` with matching methods and no duplicated arithmetic.

- [ ] **Step 1: Write projection and depth tests**

```ts
// tests/game/isometric.test.ts
import { describe, expect, test } from 'bun:test';
import {
  cellDiamond, gridCellAtWorld, gridToWorld, projectedMapBounds,
  sortDepthEntries, worldToGrid,
} from '../../src/game/core/isometric';
import { ProjectionAdapter } from '../../src/game/phaser/ProjectionAdapter';

const metrics = { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } } as const;

test('round-trips fractional logical coordinates', () => {
  for (const point of [{ x: 0, y: 0 }, { x: 2.5, y: 9.5 }, { x: 12, y: 12 }]) {
    const result = worldToGrid(gridToWorld(point, metrics), metrics);
    expect(result.x).toBeCloseTo(point.x, 10);
    expect(result.y).toBeCloseTo(point.y, 10);
  }
});

test('selects cells consistently at the proof-map edges', () => {
  expect(gridCellAtWorld(gridToWorld({ x: 0.5, y: 0.5 }, metrics), metrics)).toEqual({ x: 0, y: 0 });
  expect(gridCellAtWorld(gridToWorld({ x: 11.999999, y: 11.999999 }, metrics), metrics)).toEqual({ x: 11, y: 11 });
  expect(gridCellAtWorld(gridToWorld({ x: 0.5, y: 6.5 }, metrics), metrics)).toEqual({ x: 0, y: 6 });
  expect(gridCellAtWorld(gridToWorld({ x: 11.5, y: 6.5 }, metrics), metrics)).toEqual({ x: 11, y: 6 });
  expect(gridCellAtWorld(gridToWorld({ x: 6.5, y: 0.5 }, metrics), metrics)).toEqual({ x: 6, y: 0 });
  expect(gridCellAtWorld(gridToWorld({ x: 6.5, y: 11.5 }, metrics), metrics)).toEqual({ x: 6, y: 11 });
});

test('uses a one-nanounit epsilon only at cell lookup boundaries', () => {
  expect(gridCellAtWorld(gridToWorld({ x: 0.999999, y: 4.5 }, metrics), metrics)).toEqual({ x: 0, y: 4 });
  expect(gridCellAtWorld(gridToWorld({ x: 0.9999999995, y: 4.5 }, metrics), metrics)).toEqual({ x: 1, y: 4 });
});

test('returns clockwise diamond vertices', () => {
  expect(cellDiamond({ x: 0, y: 0 }, metrics)).toEqual([
    { x: 384, y: 0 }, { x: 416, y: 16 },
    { x: 384, y: 32 }, { x: 352, y: 16 },
  ]);
});

test('uses stable order only when ground Y ties', () => {
  const sorted = sortDepthEntries([
    { id: 'tree', groundY: 160, stableOrder: 1 },
    { id: 'player', groundY: 159, stableOrder: 9 },
    { id: 'building', groundY: 160, stableOrder: 0 },
  ]);
  expect(sorted.map(({ id }) => id)).toEqual(['player', 'building', 'tree']);
});

test('the Phaser adapter delegates every projection operation', () => {
  const adapter = new ProjectionAdapter(metrics, { width: 12, height: 12 });
  expect(adapter.gridToWorld({ x: 2.5, y: 9.5 })).toEqual(gridToWorld({ x: 2.5, y: 9.5 }, metrics));
  expect(adapter.projectedBounds(96)).toEqual(projectedMapBounds({ width: 12, height: 12 }, metrics, 96));
  expect(adapter.projectedBounds(96)).toEqual({ x: 0, y: -96, width: 768, height: 480 });
});
```

- [ ] **Step 2: Run the focused test to observe RED**

Run: `rtk bun test tests/game/isometric.test.ts`

Expected: FAIL with missing core modules and `ProjectionAdapter`.

- [ ] **Step 3: Define shared structural types**

```ts
// src/game/core/types.ts
export interface GridPoint { x: number; y: number }
export interface GridCell { x: number; y: number }
export interface WorldPoint { x: number; y: number }
export interface WorldRect { x: number; y: number; width: number; height: number }
export interface MapSize { width: number; height: number }
export interface ProjectionMetrics {
  tileWidth: number;
  tileHeight: number;
  origin: WorldPoint;
}
export interface DepthEntry {
  id: string;
  groundY: number;
  stableOrder: number;
}
```

- [ ] **Step 4: Implement the reversible projection and depth helpers**

Use exactly these equations:

```ts
export function gridToWorld(point: GridPoint, m: ProjectionMetrics): WorldPoint {
  return {
    x: m.origin.x + (point.x - point.y) * (m.tileWidth / 2),
    y: m.origin.y + (point.x + point.y) * (m.tileHeight / 2),
  };
}

export function worldToGrid(point: WorldPoint, m: ProjectionMetrics): GridPoint {
  const x = point.x - m.origin.x;
  const y = point.y - m.origin.y;
  return {
    x: x / m.tileWidth + y / m.tileHeight,
    y: y / m.tileHeight - x / m.tileWidth,
  };
}
```

`gridCellAtWorld` floors each inverse-projected component after adding `1e-9`. `cellDiamond` projects the four logical corners `(x,y)`, `(x+1,y)`, `(x+1,y+1)`, and `(x,y+1)`. `projectedMapBounds` projects the four boundary corners, subtracts `topPadding` from the minimum Y, and returns the enclosing rectangle. `sortDepthEntries` returns a copy sorted by `groundY`, then `stableOrder`, without mutating its input.

- [ ] **Step 5: Implement `ProjectionAdapter` as a thin wrapper**

```ts
export class ProjectionAdapter {
  constructor(
    readonly metrics: ProjectionMetrics,
    readonly mapSize: MapSize,
  ) {}

  gridToWorld(point: GridPoint) { return gridToWorld(point, this.metrics); }
  worldToGrid(point: WorldPoint) { return worldToGrid(point, this.metrics); }
  gridCellAtWorld(point: WorldPoint) { return gridCellAtWorld(point, this.metrics); }
  cellDiamond(cell: GridCell) { return cellDiamond(cell, this.metrics); }
  projectedBounds(topPadding = 0) {
    return projectedMapBounds(this.mapSize, this.metrics, topPadding);
  }
}
```

- [ ] **Step 6: Run projection GREEN checks**

Run:

```bash
rtk bun test tests/game/isometric.test.ts
rtk bun run check
```

Expected: all projection, edge, diamond, bounds, adapter, and stable-depth tests pass.

- [ ] **Step 7: Commit projection primitives**

```bash
rtk git add src/game/core/types.ts src/game/core/isometric.ts src/game/phaser/ProjectionAdapter.ts tests/game/isometric.test.ts
rtk git commit -m "feat: add isometric projection primitives"
```

### Task 3: Pure World Movement, Collision, Facing, Targeting, and Input Locks

**Files:**

- Modify: `src/game/core/types.ts`
- Create: `src/game/core/collision.ts`
- Create: `src/game/core/InputGate.ts`
- Create: `src/game/core/ProofWorld.ts`
- Test: `tests/game/InputGate.test.ts`
- Test: `tests/game/ProofWorld.test.ts`

**Interfaces:**

- Consumes: `GridPoint`, `GridCell`, `ProjectionMetrics`, and projection functions from Task 2.
- Produces: `Facing = 'up' | 'right' | 'down' | 'left'`, `Footprint`, `ProofMap`, `MovementInput`, and `WorldSnapshot`.
- Produces: `InputGate.set(reason, locked)`, `InputGate.isLocked`, and `InputGate.subscribe(listener)`.
- Produces: `new ProofWorld(map, metrics, initialFacing = 'down')`, `ProofWorld.step(input, deltaMs)`, and `ProofWorld.snapshot()`.

- [ ] **Step 1: Write InputGate tests**

```ts
import { expect, test } from 'bun:test';
import { InputGate } from '../../src/game/core/InputGate';

test('notifies only aggregate lock transitions', () => {
  const gate = new InputGate();
  const transitions: boolean[] = [];
  gate.subscribe((locked) => transitions.push(locked));
  gate.set('overlay', true);
  gate.set('window-blur', true);
  gate.set('overlay', false);
  gate.set('window-blur', false);
  expect(transitions).toEqual([true, false]);
  expect(gate.isLocked).toBe(false);
});
```

- [ ] **Step 2: Write ProofWorld movement and targeting tests**

Use this canonical fixture:

```ts
import { gridToWorld } from '../../src/game/core/isometric';
import type { ProofMap, WorldPoint } from '../../src/game/core/types';

const map: ProofMap = {
  width: 12,
  height: 12,
  spawn: { x: 2.5, y: 9.5 },
  footprints: [
    { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
    { id: 'building', x: 7, y: 7, width: 2, height: 2 },
  ],
};
const metrics = { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } };
```

Test these exact behaviors:

```ts
test('normalizes diagonal screen input', () => {
  const cardinal = new ProofWorld(map, metrics);
  const diagonal = new ProofWorld(map, metrics);
  cardinal.step({ screenX: 1, screenY: 0 }, 50);
  diagonal.step({ screenX: 1, screenY: 1 }, 50);
  const start = gridToWorld(map.spawn, metrics);
  const cardinalEnd = gridToWorld(cardinal.snapshot().player.position, metrics);
  const diagonalEnd = gridToWorld(diagonal.snapshot().player.position, metrics);
  const distance = (point: WorldPoint) => Math.hypot(point.x - start.x, point.y - start.y);
  expect(distance(diagonalEnd)).toBeCloseTo(distance(cardinalEnd), 6);
});

test('slides along the building footprint instead of entering it', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 6.5, y: 7.5 } }, metrics);
  for (let i = 0; i < 30; i++) world.step({ screenX: 1, screenY: 0.3 }, 16);
  const player = world.snapshot().player.position;
  expect(player.x).toBeLessThanOrEqual(6.82);
  expect(player.y).not.toBeCloseTo(7.5, 2);
});

test('returns null instead of clamping a target beyond the map', () => {
  const world = new ProofWorld({ ...map, spawn: { x: 0.25, y: 0.25 } }, metrics, 'up');
  expect(world.snapshot().target).toBeNull();
});
```

Also cover opposing-key cancellation, four facing directions, idle facing retention, map bounds, a `500 ms` delta that cannot tunnel through the tree, and all four target offsets.

- [ ] **Step 3: Run the world tests to observe RED**

Run: `rtk bun test tests/game/InputGate.test.ts tests/game/ProofWorld.test.ts`

Expected: FAIL because the input gate, collision helpers, and world model are absent.

- [ ] **Step 4: Implement nested input locking**

`InputGate` stores a `Set<string>` of lock reasons and a `Set<(locked: boolean) => void>` of listeners. `set` ignores an empty reason, computes aggregate lock state before and after mutation, and notifies only when that state changes. `subscribe` returns an unsubscribe function.

```ts
get isLocked(): boolean { return this.reasons.size > 0; }
```

- [ ] **Step 5: Implement logical rectangle collision**

Expose `intersects(a, b)`, `playerRect(position, halfExtent = 0.18)`, and `moveWithCollisions(position, delta, map, halfExtent)`.

`moveWithCollisions` must:

1. test X motion while preserving Y;
2. clamp X to map bounds and the nearest colliding rectangle edge;
3. test Y motion using the resolved X;
4. clamp Y the same way; and
5. return the resolved center point.

Touching rectangle edges is non-intersection; any positive overlap is collision.

```ts
export function intersects(a: Footprint, b: Footprint): boolean {
  return a.x < b.x + b.width && a.x + a.width > b.x
    && a.y < b.y + b.height && a.y + a.height > b.y;
}

export function moveWithCollisions(
  position: GridPoint,
  delta: GridPoint,
  map: ProofMap,
  halfExtent = 0.18,
): GridPoint {
  let next = resolveAxis(position, delta.x, 'x', map, halfExtent);
  next = resolveAxis(next, delta.y, 'y', map, halfExtent);
  return next;
}
```

`resolveAxis` builds the proposed player rectangle, clamps its center to `[halfExtent, size-halfExtent]`, and, for each overlapping footprint, places the center at `footprint.x-halfExtent` / `footprint.x+width+halfExtent` (or the equivalent Y edge) according to motion sign.

- [ ] **Step 6: Implement `ProofWorld`**

Use `96` projected pixels per second, clamp a frame to `50 ms`, and split it into steps no larger than `8 ms`. Normalize non-zero screen input before multiplying by speed. Convert each projected delta with the linear inverse projection:

```ts
const gridDelta = {
  x: projectedX / metrics.tileWidth + projectedY / metrics.tileHeight,
  y: projectedY / metrics.tileHeight - projectedX / metrics.tileWidth,
};
```

Choose facing by dominant screen component; horizontal wins exact ties. Target offsets are `up (-1,-1)`, `right (+1,-1)`, `down (+1,+1)`, and `left (-1,+1)`. Compute the target from `floor(player position)`, and return `null` if either coordinate is outside `[0,width)` or `[0,height)`.

`snapshot()` returns a fresh object:

```ts
export type Facing = 'up' | 'right' | 'down' | 'left';
export interface Footprint { id: string; x: number; y: number; width: number; height: number }
export interface ProofMap {
  width: number;
  height: number;
  spawn: GridPoint;
  footprints: Footprint[];
}
export interface MovementInput { screenX: number; screenY: number }
interface WorldSnapshot {
  player: { position: GridPoint; facing: Facing };
  target: GridCell | null;
}
```

- [ ] **Step 7: Run world GREEN checks**

Run:

```bash
rtk bun test tests/game/InputGate.test.ts tests/game/ProofWorld.test.ts
rtk bun test
rtk bun run check
```

Expected: all tests pass with no Phaser or Svelte imports under `src/game/core`.

- [ ] **Step 8: Commit the pure world model**

```bash
rtk git add src/game/core tests/game/InputGate.test.ts tests/game/ProofWorld.test.ts
rtk git commit -m "feat: add pure proof-world movement rules"
```

### Task 4: Tiled Proof Map, Deterministic Pixel Assets, and Validation

**Files:**

- Create: `tools/generate-proof-assets.ts`
- Create: `src/assets/maps/proof-map.json`
- Create: `src/assets/sprites/proof-tiles.png`
- Create: `src/assets/sprites/proof-player.png`
- Create: `src/assets/sprites/proof-scenery.png`
- Create: `src/game/phaser/loadProofMap.ts`
- Modify: `src/game/core/types.ts`
- Test: `tests/game/loadProofMap.test.ts`

**Interfaces:**

- Consumes: `ProjectionAdapter`, `GridPoint`, `Footprint`, and `ProofMap` from Tasks 2-3.
- Produces: `parseProofMap(raw, projection): ParsedProofMap`.
- Produces: `ParsedProofMap = { world: ProofMap; scenery: SceneryPlacement[]; farmCells: GridCell[]; groundTilesetName: 'proof-ground' }`.
- Produces: exact scene placements `tree` and `building`, matched to logical footprints by name.

Add these shared structures to `src/game/core/types.ts`:

```ts
export type SceneryKind = 'tree' | 'building';
export interface SceneryPlacement {
  id: string;
  kind: SceneryKind;
  frame: number;
  world: WorldPoint;
  stableOrder: number;
}
```

- [ ] **Step 1: Write map-contract tests before generating assets**

```ts
import { describe, expect, test } from 'bun:test';
import { resolve } from 'node:path';
import { ProjectionAdapter } from '../../src/game/phaser/ProjectionAdapter';
import { parseProofMap } from '../../src/game/phaser/loadProofMap';

const assetRoot = resolve(import.meta.dir, '../../src/assets');
const path = resolve(assetRoot, 'maps/proof-map.json');
const projection = new ProjectionAdapter(
  { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
  { width: 12, height: 12 },
);

test('loads the authored proof-map contract', async () => {
  const parsed = parseProofMap(await Bun.file(path).json(), projection);
  expect(parsed.world.spawn).toEqual({ x: 2.5, y: 9.5 });
  expect(parsed.world.footprints).toEqual([
    { id: 'tree', x: 7.2, y: 4.2, width: 0.6, height: 0.6 },
    { id: 'building', x: 7, y: 7, width: 2, height: 2 },
  ]);
  expect(parsed.scenery.map(({ id, kind }) => [id, kind])).toEqual([
    ['tree', 'tree'], ['building', 'building'],
  ]);
  expect(parsed.farmCells).toHaveLength(9);
});

test.each([
  ['proof-tiles.png', 128, 32],
  ['proof-player.png', 128, 48],
  ['proof-scenery.png', 192, 96],
])('writes %s with exact PNG dimensions', async (name, width, height) => {
  const bytes = new Uint8Array(await Bun.file(resolve(assetRoot, 'sprites', name)).arrayBuffer());
  expect([...bytes.subarray(0, 8)]).toEqual([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  expect(view.getUint32(16)).toBe(width);
  expect(view.getUint32(20)).toBe(height);
});
```

Clone the valid raw object and assert descriptive throws for orientation `orthogonal`, missing `Markers`, duplicate spawn, missing `building` footprint, wrong tree footprint dimensions, an unknown scenery kind, scenery tileset alignment other than `bottom`, a non-parallelogram footprint, and an out-of-bounds spawn.

- [ ] **Step 2: Run the map tests to observe RED**

Run: `rtk bun test tests/game/loadProofMap.test.ts`

Expected: FAIL because the map, generated assets, and parser do not exist.

- [ ] **Step 3: Implement deterministic PNG encoding and pixel drawing**

In `tools/generate-proof-assets.ts`, use `node:zlib`'s `deflateSync`, PNG filter byte `0` per scanline, and CRC32 chunks `IHDR`, `IDAT`, and `IEND`. Implement the local encoder and drawing primitives directly so asset generation has no additional package:

```ts
import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { deflateSync } from 'node:zlib';
import type { GridPoint, WorldPoint } from '../src/game/core/types';

interface Surface { width: number; height: number; pixels: Uint8Array }

const createSurface = (width: number, height: number): Surface => ({
  width, height, pixels: new Uint8Array(width * height * 4),
});
const rgb = (hex: string) => [
  Number.parseInt(hex.slice(1, 3), 16),
  Number.parseInt(hex.slice(3, 5), 16),
  Number.parseInt(hex.slice(5, 7), 16),
] as const;
function setPixel(surface: Surface, x: number, y: number, color: string): void {
  if (x < 0 || y < 0 || x >= surface.width || y >= surface.height) return;
  const offset = (y * surface.width + x) * 4;
  const [r, g, b] = rgb(color);
  surface.pixels.set([r, g, b, 255], offset);
}
function fillRect(surface: Surface, x: number, y: number, width: number, height: number, color: string): void {
  for (let py = y; py < y + height; py++) {
    for (let px = x; px < x + width; px++) setPixel(surface, px, py, color);
  }
}
function fillDiamond(
  surface: Surface, centerX: number, centerY: number, halfWidth: number, halfHeight: number,
  fill: string, outline: string,
): void {
  const borderStart = 1 - 1 / Math.min(halfWidth, halfHeight);
  for (let y = centerY - halfHeight; y < centerY + halfHeight; y++) {
    for (let x = centerX - halfWidth; x < centerX + halfWidth; x++) {
      const distance = Math.abs(x + 0.5 - centerX) / halfWidth
        + Math.abs(y + 0.5 - centerY) / halfHeight;
      if (distance <= 1) setPixel(surface, x, y, distance >= borderStart ? outline : fill);
    }
  }
}
function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type: string, data: Uint8Array): Uint8Array {
  const output = Buffer.alloc(12 + data.length);
  output.writeUInt32BE(data.length, 0);
  output.write(type, 4, 4, 'ascii');
  output.set(data, 8);
  output.writeUInt32BE(crc32(output.subarray(4, 8 + data.length)), 8 + data.length);
  return output;
}
async function writePng(path: string, surface: Surface): Promise<void> {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(surface.width, 0);
  ihdr.writeUInt32BE(surface.height, 4);
  ihdr.set([8, 6, 0, 0, 0], 8);
  const rowLength = surface.width * 4;
  const scanlines = Buffer.alloc((rowLength + 1) * surface.height);
  for (let y = 0; y < surface.height; y++) {
    scanlines[y * (rowLength + 1)] = 0;
    scanlines.set(surface.pixels.subarray(y * rowLength, (y + 1) * rowLength), y * (rowLength + 1) + 1);
  }
  await mkdir(dirname(path), { recursive: true });
  await Bun.write(path, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', deflateSync(scanlines)), chunk('IEND', new Uint8Array()),
  ]));
}
```

Generate these exact sheets:

```ts
const tiles = createSurface(128, 32);
fillDiamond(tiles, 32, 16, 32, 16, '#76a85b', '#36563a');
fillDiamond(tiles, 96, 16, 32, 16, '#9a6a43', '#5d3d2b');

const player = createSurface(128, 48);
for (const [frame, marker] of ['#9fd8ff', '#ffd36b', '#f49c83', '#b7e48f'].entries()) {
  const x = frame * 32;
  fillRect(player, x + 12, 8, 8, 8, '#f0c7a5');
  fillRect(player, x + 10, 16, 12, 18, '#426c8d');
  fillRect(player, x + 8, 20, 4, 12, marker);
  fillRect(player, x + 12, 34, 3, 10, '#4a352d');
  fillRect(player, x + 18, 34, 3, 10, '#4a352d');
}

const scenery = createSurface(192, 96);
fillRect(scenery, 43, 60, 10, 36, '#6d432b');
fillRect(scenery, 24, 24, 48, 36, '#315f3b');
fillRect(scenery, 32, 12, 32, 20, '#3f7847');
fillRect(scenery, 16, 34, 64, 14, '#3f7847');
fillRect(scenery, 108, 50, 72, 46, '#d8b56d');
fillRect(scenery, 102, 42, 84, 10, '#704638');
fillRect(scenery, 110, 32, 68, 10, '#704638');
fillRect(scenery, 118, 22, 52, 10, '#704638');
fillRect(scenery, 138, 66, 14, 30, '#624331');
fillRect(scenery, 118, 62, 12, 12, '#8bc0cf');
fillRect(scenery, 160, 62, 12, 12, '#8bc0cf');

await writePng('src/assets/sprites/proof-tiles.png', tiles);
await writePng('src/assets/sprites/proof-player.png', player);
await writePng('src/assets/sprites/proof-scenery.png', scenery);
```

Use integer rectangles only, with transparent pixels outside the drawn shapes. The tree and building both use frame size `96×96` and bottom-center ground contact.

- [ ] **Step 4: Generate the finite embedded-tileset Tiled JSON**

The same script writes `proof-map.json` with:

- `orientation: 'isometric'`, `renderorder: 'right-down'`, `width: 12`, `height: 12`, `tilewidth: 64`, `tileheight: 32`, `infinite: false`;
- embedded `proof-ground` tileset at `firstgid: 1`, image `../sprites/proof-tiles.png`, `2` columns, and `2` tiles;
- embedded `proof-scenery` tileset at `firstgid: 3`, image `../sprites/proof-scenery.png`, `2` columns, `2` tiles, grid `{ orientation: 'isometric', width: 64, height: 32 }`, and `objectalignment: 'bottom'`;
- `Ground` tile data containing dirt GID `2` only at cells `x=2..4`, `y=7..9`, and grass GID `1` elsewhere;
- `Scenery` tile objects `tree` (`gid: 3`, type `tree`) at projected grid point `(7.5,4.5)` and `building` (`gid: 4`, type `building`) at `(9,9)`;
- `Collision` polygons made by projecting the logical rectangles `tree [7.2,4.2]-[7.8,4.8]` and `building [7,7]-[9,9]` and storing polygon points relative to the first vertex; and
- one named point object `player-spawn` at projected grid point `(2.5,9.5)` in `Markers`.

Build the map from these concrete values rather than hand-copying 144 cells. Give layers IDs `1..4`, objects IDs `1..5`, `nextlayerid: 5`, and `nextobjectid: 6`:

```ts
const ground = Array.from({ length: 144 }, (_, index) => {
  const x = index % 12;
  const y = Math.floor(index / 12);
  return x >= 2 && x <= 4 && y >= 7 && y <= 9 ? 2 : 1;
});
const project = ({ x, y }: GridPoint): WorldPoint => ({
  x: 384 + (x - y) * 32,
  y: (x + y) * 16,
});
const logicalPolygon = (
  id: number, name: string, minX: number, minY: number, maxX: number, maxY: number,
) => {
  const points = [
    project({ x: minX, y: minY }), project({ x: maxX, y: minY }),
    project({ x: maxX, y: maxY }), project({ x: minX, y: maxY }),
  ];
  return {
    id, name, type: '', x: points[0].x, y: points[0].y,
    polygon: points.map((point) => ({ x: point.x - points[0].x, y: point.y - points[0].y })),
    rotation: 0, visible: true,
  };
};
const treeRect = logicalPolygon(3, 'tree', 7.2, 4.2, 7.8, 4.8);
const buildingRect = logicalPolygon(4, 'building', 7, 7, 9, 9);
const tree = project({ x: 7.5, y: 4.5 });
const building = project({ x: 9, y: 9 });
const spawn = project({ x: 2.5, y: 9.5 });

const groundTileset = {
  firstgid: 1, columns: 2, image: '../sprites/proof-tiles.png', imageheight: 32, imagewidth: 128,
  margin: 0, name: 'proof-ground', spacing: 0, tilecount: 2, tileheight: 32, tilewidth: 64,
};
const sceneryTileset = {
  firstgid: 3, columns: 2, image: '../sprites/proof-scenery.png', imageheight: 96, imagewidth: 192,
  margin: 0, name: 'proof-scenery', objectalignment: 'bottom', spacing: 0,
  tilecount: 2, tileheight: 96, tilewidth: 96,
  grid: { height: 32, orientation: 'isometric', width: 64 },
};
const groundLayer = {
  id: 1, name: 'Ground', type: 'tilelayer', x: 0, y: 0,
  width: 12, height: 12, opacity: 1, visible: true, data: ground,
};
const sceneryLayer = {
  id: 2, name: 'Scenery', type: 'objectgroup', draworder: 'topdown', opacity: 1, visible: true,
  objects: [
    { id: 1, name: 'tree', type: 'tree', gid: 3, x: tree.x, y: tree.y, width: 96, height: 96, rotation: 0, visible: true },
    { id: 2, name: 'building', type: 'building', gid: 4, x: building.x, y: building.y, width: 96, height: 96, rotation: 0, visible: true },
  ],
};
const collisionLayer = {
  id: 3, name: 'Collision', type: 'objectgroup', draworder: 'topdown', opacity: 1, visible: true,
  objects: [treeRect, buildingRect],
};
const markerLayer = {
  id: 4, name: 'Markers', type: 'objectgroup', draworder: 'topdown', opacity: 1, visible: true,
  objects: [{ id: 5, name: 'player-spawn', type: '', point: true, x: spawn.x, y: spawn.y, rotation: 0, visible: true }],
};

const map = {
  compressionlevel: -1,
  height: 12,
  infinite: false,
  nextlayerid: 5,
  nextobjectid: 6,
  orientation: 'isometric',
  renderorder: 'right-down',
  tiledversion: '1.12.2',
  tileheight: 32,
  tilewidth: 64,
  type: 'map',
  version: '1.10',
  width: 12,
  tilesets: [groundTileset, sceneryTileset],
  layers: [groundLayer, sceneryLayer, collisionLayer, markerLayer],
};
await Bun.write('src/assets/maps/proof-map.json', `${JSON.stringify(map, null, 2)}\n`);
```

Run: `rtk bun run assets:generate`

Expected: all four generated data files exist and PNG header dimensions are `128×32`, `128×48`, and `192×96`.

- [ ] **Step 5: Implement fail-fast map parsing**

`parseProofMap` must reject non-record inputs and validate every contract listed in Step 4. Use named helper functions that throw `Error('proof-map: <specific reason>')`.

For each collision polygon:

1. add the object's `x/y` to its relative points;
2. inverse-project all four world points;
3. round values within `1e-9` of an exact authored decimal;
4. require exactly four unique points, two unique logical X values, two unique logical Y values, and all four Cartesian corner pairs; and
5. require positive width/height and derive `{ id, x: minX, y: minY, width: maxX-minX, height: maxY-minY }`.

Pair scenery and footprints by the exact object name. Derive scenery frame as `gid - 3`, stable order by object ID, and bottom-center world position directly from the tile object's `x/y`. Derive farm cells by locating GID `2` in the `Ground` layer.

Use a deterministic snap before extracting the rectangle:

```ts
const snap = (value: number) => Math.round(value * 1_000_000_000) / 1_000_000_000;
const gridPoints = object.polygon.map((point) => projection.worldToGrid({
  x: object.x + point.x,
  y: object.y + point.y,
})).map(({ x, y }) => ({ x: snap(x), y: snap(y) }));
const xs = [...new Set(gridPoints.map(({ x }) => x))].sort((a, b) => a - b);
const ys = [...new Set(gridPoints.map(({ y }) => y))].sort((a, b) => a - b);
if (xs.length !== 2 || ys.length !== 2) {
  throw new Error(`proof-map: footprint ${object.name} is not a logical rectangle`);
}
const actualCorners = new Set(gridPoints.map(({ x, y }) => `${x},${y}`));
const expectedCorners = xs.flatMap((x) => ys.map((y) => `${x},${y}`));
if (actualCorners.size !== 4 || expectedCorners.some((corner) => !actualCorners.has(corner))) {
  throw new Error(`proof-map: footprint ${object.name} is not a logical rectangle`);
}
```

- [ ] **Step 6: Run map GREEN checks**

Run:

```bash
rtk bun run assets:generate
rtk bun test tests/game/loadProofMap.test.ts
rtk bun test
rtk bun run check
```

Expected: the valid map parses to the canonical fixture; every malformed clone reports its named contract violation.

- [ ] **Step 7: Commit authored map data and validation**

```bash
rtk git add tools/generate-proof-assets.ts src/assets src/game/core/types.ts src/game/phaser/loadProofMap.ts tests/game/loadProofMap.test.ts
rtk git commit -m "feat: add isometric proof map and assets"
```

### Task 5: Phaser Proof Scene and Single-Instance Lifecycle

**Files:**

- Create: `src/game/phaser/KeyboardController.ts`
- Create: `src/game/phaser/GameLifecycle.ts`
- Create: `src/game/phaser/ProofScene.ts`
- Create: `src/game/phaser/createGame.ts`
- Create: `src/components/GameHost.svelte`
- Modify: `src/vite-env.d.ts`
- Modify: `src/App.svelte`
- Test: `tests/game/GameLifecycle.test.ts`

**Interfaces:**

- Consumes: `InputGate`, `ProofWorld`, `ProjectionAdapter`, and `parseProofMap`.
- Produces: `DebugSnapshot`, `ProofSceneDependencies`, `createGame(parent, dependencies): Phaser.Game`, and `GameLifecycle.start(parent, dependencies) / stop()`.
- Produces: development-only `window.__PHOENIX_TEST__.snapshot()` and `window.__PHOENIX_TEST__.remount()`; neither exists in production.

- [ ] **Step 1: Write lifecycle tests with an injected fake game factory**

```ts
import { expect, test } from 'bun:test';
import { GameLifecycle } from '../../src/game/phaser/GameLifecycle';

test('starting twice destroys the first game and owns only the second', () => {
  const destroyed: number[] = [];
  let nextId = 0;
  const lifecycle = new GameLifecycle(() => {
    const id = ++nextId;
    return { destroy: (removeCanvas: boolean) => { if (removeCanvas) destroyed.push(id); } };
  });
  const parent = {} as HTMLElement;
  lifecycle.start(parent, {} as never);
  lifecycle.start(parent, {} as never);
  expect(destroyed).toEqual([1]);
  lifecycle.stop();
  lifecycle.stop();
  expect(destroyed).toEqual([1, 2]);
});
```

Add a second test where the factory throws; assert `start` rethrows, leaves no owned game, and a following successful `start` works.

- [ ] **Step 2: Run lifecycle tests to observe RED**

Run: `rtk bun test tests/game/GameLifecycle.test.ts`

Expected: FAIL because `GameLifecycle` does not exist.

- [ ] **Step 3: Implement lifecycle and keyboard ownership**

`GameLifecycle` accepts a factory returning `{ destroy(removeCanvas: boolean): void }`, calls `stop()` before each `start()`, stores only a successfully returned game, and makes `stop()` idempotent by nulling its field before `destroy(true)`.

```ts
type GameLike = { destroy(removeCanvas: boolean): void };
type GameFactory<T> = (parent: HTMLElement, dependencies: T) => GameLike;

export class GameLifecycle<T> {
  private game: GameLike | null = null;
  constructor(private readonly factory: GameFactory<T>) {}
  start(parent: HTMLElement, dependencies: T): void {
    this.stop();
    this.game = this.factory(parent, dependencies);
  }
  stop(): void {
    const game = this.game;
    this.game = null;
    game?.destroy(true);
  }
}
```

`KeyboardController` receives Phaser `Key` objects and an `InputGate`. It returns screen input from WASD, subscribes to aggregate gate transitions, calls `reset()` on all four keys whenever locking becomes true, and unsubscribes/removes keys on `destroy()`.

```ts
sample(): MovementInput {
  if (this.inputGate.isLocked) return { screenX: 0, screenY: 0 };
  return {
    screenX: Number(this.keys.d.isDown) - Number(this.keys.a.isDown),
    screenY: Number(this.keys.s.isDown) - Number(this.keys.w.isDown),
  };
}
```

- [ ] **Step 4: Implement `ProofScene` as an adapter, not an authority**

Define dependencies:

```ts
export interface DebugSnapshot {
  player: { position: GridPoint; facing: Facing; world: WorldPoint };
  target: GridCell | null;
  visibleTarget: boolean;
  locked: boolean;
  depths: Record<'player' | 'tree' | 'building', number>;
  camera: { scrollX: number; scrollY: number; bounds: WorldRect };
}

export interface ProofSceneDependencies {
  inputGate: InputGate;
  onReady(): void;
  onError(error: Error): void;
  onSnapshot(snapshot: DebugSnapshot): void;
}
```

In `preload`, load the Tiled JSON URL, ground sheet (`64×32`), player sheet (`32×48`), and scenery sheet (`96×96`) through Vite-resolved URLs. Import the JSON once more as typed raw data for `parseProofMap`; the URL-backed copy supplies Phaser's tilemap cache. Register one loader error callback, retain the first failed file key, and make `create` throw `Error('asset load failed: <key>')` before constructing the world when that field is set.

In `create`:

1. parse the imported raw map with `parseProofMap`;
2. create the isometric `TilemapLayer` with `map.addTilesetImage('proof-ground', 'proof-tiles')` and `map.createLayer('Ground', tileset, 384, 0, false)`; use the CPU `TilemapLayer`, not the GPU layer whose Phaser 4 contract excludes isometric maps;
3. create tree/building sprites at parsed bottom-center points with origin `(0.5,1)`;
4. create the player sprite at projected `ProofWorld` position with origin `(0.5,1)`;
5. create a four-segment target diamond `Graphics` object below entity depths;
6. set camera bounds from `projection.projectedBounds(96)` and follow the player at lerp `0.12` without changing zoom or rotation;
7. create `KeyboardController`; and
8. report ready.

In `update`, sample input, call `ProofWorld.step`, and then synchronize only render state: player position/frame, target geometry/visibility, stable entity depth ranks, camera target, and `DebugSnapshot`. Sort `DepthEntry` values and assign consecutive entity depths beginning at `100`; use stable order `0` for the player and the parsed Tiled object IDs `1` and `2` for tree/building. Keep ground at `0` and target at `10`.

Wrap map/scene creation in `try/catch`; on failure call `dependencies.onError(error instanceof Error ? error : new Error(String(error)))` and schedule the owning lifecycle's cleanup through the Svelte callback. Register scene `SHUTDOWN` and `DESTROY` handlers that destroy `KeyboardController` and detach loader callbacks.

- [ ] **Step 5: Implement the single Phaser factory**

```ts
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
```

The pinned Phaser 4.2.1 `Phaser.Types.Core.GameConfig` declares `pixelArt`, `antialias`, `roundPixels`, and `smoothPixelArt` as the top-level properties shown above; do not move them under a nested render object.

- [ ] **Step 6: Mount the game through `GameHost.svelte`**

`GameHost` receives `inputGate`, `onStatus`, and `onError` props. On mount it starts one lifecycle in the bound host node. Its cleanup and `import.meta.hot.dispose` both call the same `stop()`. On scene error, queue lifecycle cleanup before forwarding the error to Svelte.

In development only, publish:

```ts
window.__PHOENIX_TEST__ = {
  snapshot: () => latestSnapshot,
  remount: () => lifecycle.start(host, dependencies),
};
```

Declare the hook without widening production APIs:

```ts
// src/vite-env.d.ts
/// <reference types="vite/client" />
import type { DebugSnapshot } from './game/phaser/ProofScene';

declare global {
  interface Window {
    __PHOENIX_TEST__?: { snapshot(): DebugSnapshot; remount(): void };
  }
}

export {};
```

Delete that property during component cleanup. Update `App.svelte` to construct one `InputGate` and render `GameHost`.

- [ ] **Step 7: Run lifecycle and browser-build GREEN checks**

Run:

```bash
rtk bun test tests/game/GameLifecycle.test.ts
rtk bun test
rtk bun run check
rtk bun run build
```

Then run `rtk rg -n "__PHOENIX_TEST__" dist` and require exit code `1` with no matches. Expected: unit/static/build checks pass and production output contains no literal development-test property.

- [ ] **Step 8: Commit the Phaser runtime**

```bash
rtk git add src/game/phaser src/components/GameHost.svelte src/App.svelte src/vite-env.d.ts tests/game/GameLifecycle.test.ts
rtk git commit -m "feat: render the Phaser proof world"
```

### Task 6: Shared Stage Scaling, Overlay, and World-Input Locking

**Files:**

- Create: `src/ui/stageScale.ts`
- Create: `src/components/StageFrame.svelte`
- Create: `src/components/Overlay.svelte`
- Modify: `src/App.svelte`
- Modify: `src/app.css`
- Test: `tests/game/stageScale.test.ts`

**Interfaces:**

- Consumes: `GameHost`, `InputGate`, and scene lifecycle status from Task 5.
- Produces: `fitStage(viewportWidth, viewportHeight): StageFit`.
- Produces: a shared transformed stage where Phaser canvas and Svelte overlay have identical client rectangles.
- Produces: overlay lock reason `overlay` and focus lock reason `window-blur`.

- [ ] **Step 1: Write exact stage-fit tests**

```ts
import { expect, test } from 'bun:test';
import { fitStage } from '../../src/ui/stageScale';

test.each([
  [640, 360, { scale: 1, width: 640, height: 360, left: 0, top: 0 }],
  [1024, 768, { scale: 1, width: 640, height: 360, left: 192, top: 204 }],
  [1280, 720, { scale: 2, width: 1280, height: 720, left: 0, top: 0 }],
])('fits %ix%i with an integer scale', (width, height, expected) => {
  expect(fitStage(width, height)).toEqual(expected);
});
```

- [ ] **Step 2: Run stage tests to observe RED**

Run: `rtk bun test tests/game/stageScale.test.ts`

Expected: FAIL because `fitStage` does not exist.

- [ ] **Step 3: Implement integer-fit scaling**

```ts
export interface StageFit {
  scale: number;
  width: number;
  height: number;
  left: number;
  top: number;
}

export function fitStage(viewportWidth: number, viewportHeight: number): StageFit {
  const scale = Math.max(1, Math.floor(Math.min(viewportWidth / 640, viewportHeight / 360)));
  const width = 640 * scale;
  const height = 360 * scale;
  return {
    scale, width, height,
    left: Math.floor((viewportWidth - width) / 2),
    top: Math.floor((viewportHeight - height) / 2),
  };
}
```

The supported viewport floor is `640×360`; smaller browser windows may overflow rather than use a blurry fractional scale.

- [ ] **Step 4: Implement `StageFrame.svelte`**

Listen to `window.resize`, calculate `fitStage(window.innerWidth, window.innerHeight)`, and render:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  import { fitStage } from '../ui/stageScale';

  let { children }: { children: Snippet } = $props();
  let fit = $state(fitStage(640, 360));
  onMount(() => {
    const resize = () => { fit = fitStage(window.innerWidth, window.innerHeight); };
    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  });
</script>

<div class="stage-frame" data-stage-frame style:left={`${fit.left}px`} style:top={`${fit.top}px`}
  style:width={`${fit.width}px`} style:height={`${fit.height}px`} data-stage-scale={fit.scale}>
  <div class="logical-stage" data-logical-stage style:transform={`scale(${fit.scale})`}>
    {@render children()}
  </div>
</div>
```

Set `.logical-stage` to absolute `640×360`, `transform-origin: top left`, and isolate overflow. Put both the canvas host and overlay at `inset: 0` inside this element. Set canvas `image-rendering: pixelated` and exact `640×360` CSS size.

- [ ] **Step 5: Implement `Overlay.svelte` and composition state**

The overlay displays:

- title `Phoenix — Isometric Proof`;
- controls `Move: WASD`;
- lifecycle status `Loading world…`, `World ready`, or fatal error text;
- current input state `World input: Active/Locked`; and
- a button with `aria-pressed` and text `Lock world input` / `Unlock world input`.

The button calls `inputGate.set('overlay', nextLocked)`. `App.svelte` handles `window.blur` with `inputGate.set('window-blur', true)` and `window.focus` with `false`. Fatal errors replace controls with the exact error and a `Reload` button calling `window.location.reload()`.

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import type { InputGate } from '../game/core/InputGate';
  let { inputGate, status, error }: {
    inputGate: InputGate;
    status: 'loading' | 'ready' | 'error';
    error: string | null;
  } = $props();
  let overlayLocked = $state(false);
  let locked = $state(inputGate.isLocked);
  onMount(() => inputGate.subscribe((value) => { locked = value; }));
  const toggle = () => {
    overlayLocked = !overlayLocked;
    inputGate.set('overlay', overlayLocked);
  };
</script>

<aside data-overlay aria-live="polite">
  <h1>Phoenix — Isometric Proof</h1>
  {#if status === 'error'}
    <p role="alert">{error}</p><button onclick={() => location.reload()}>Reload</button>
  {:else}
    <p>{status === 'ready' ? 'World ready' : 'Loading world…'}</p>
    <p>Move: WASD</p>
    <p>World input: {locked ? 'Locked' : 'Active'}</p>
    <button aria-pressed={overlayLocked} onclick={toggle}>
      {overlayLocked ? 'Unlock world input' : 'Lock world input'}
    </button>
  {/if}
</aside>
```

- [ ] **Step 6: Run presentation GREEN checks**

Run:

```bash
rtk bun test tests/game/stageScale.test.ts
rtk bun test
rtk bun run check
rtk bun run build
```

Expected: unit/static/build checks pass and canvas/overlay share one transformed parent.

- [ ] **Step 7: Commit the fitted overlay stage**

```bash
rtk git add src/App.svelte src/app.css src/components src/ui/stageScale.ts tests/game/stageScale.test.ts
rtk git commit -m "feat: add fitted Svelte overlay stage"
```

### Task 7: Browser Acceptance and Real HMR Verification

**Files:**

- Create: `playwright.config.ts`
- Create: `tests/e2e/helpers.ts`
- Create: `tests/e2e/lifecycle.pw.ts`
- Create: `tests/e2e/world.pw.ts`
- Modify: `src/game/phaser/ProofScene.ts` only if a read-only snapshot field required below is absent.
- Modify: `src/main.ts` to expose a development-only Vite HMR event counter.
- Modify: `src/vite-env.d.ts` only to keep the declared test contract synchronized.

**Interfaces:**

- Consumes: `window.__PHOENIX_TEST__.snapshot()` and `.remount()` from Task 5.
- Produces: deterministic browser evidence for lifecycle, scaling, input locks, navigation, target edges, depth transitions, and camera bounds.
- Produces: `DebugSnapshot` fields `player.position`, `player.facing`, `target`, `locked`, `visibleTarget`, `depths`, and `camera`.
- Produces: development-only `window.__PHOENIX_HMR_COUNT__`, incremented by Vite's `vite:afterUpdate` event and removed from production builds.

- [ ] **Step 1: Configure one pinned Chromium project**

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.pw.ts',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: 'line',
  use: {
    baseURL: 'http://localhost:1420',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'bun run dev',
    url: 'http://localhost:1420',
    reuseExistingServer: false,
  },
});
```

- [ ] **Step 2: Write lifecycle and resize acceptance tests**

Implement helpers `waitForWorld(page)`, `snapshot(page)`, and `holdKey(page, key, ms)`. Tests must assert:

```ts
// tests/e2e/helpers.ts
import { expect, type Page } from '@playwright/test';
import type { DebugSnapshot } from '../../src/game/phaser/ProofScene';

export async function waitForWorld(page: Page) {
  await page.goto('/');
  await expect(page.getByText('World ready')).toBeVisible();
  await page.waitForFunction(() => Boolean(window.__PHOENIX_TEST__?.snapshot()));
}

export const snapshot = (page: Page) => page.evaluate(() => window.__PHOENIX_TEST__!.snapshot());

export async function holdKey(page: Page, key: string, ms: number) {
  await page.keyboard.down(key);
  try { await page.waitForTimeout(ms); }
  finally { await page.keyboard.up(key); }
}
```

```ts
test('remounts without duplicating the canvas', async ({ page }) => {
  await waitForWorld(page);
  await page.evaluate(() => window.__PHOENIX_TEST__!.remount());
  await expect(page.locator('canvas')).toHaveCount(1);
  await expect(page.getByText('World ready')).toBeVisible();
});

test('keeps overlay and canvas aligned at supported sizes', async ({ page }) => {
  await waitForWorld(page);
  for (const [width, height, scale] of [[640, 360, 1], [1024, 768, 1], [1280, 720, 2]]) {
    await page.setViewportSize({ width, height });
    const boxes = await page.locator('[data-game-host], [data-overlay]').evaluateAll((nodes) =>
      nodes.map((node) => node.getBoundingClientRect().toJSON()));
    expect(boxes[0]).toEqual(boxes[1]);
    await expect(page.locator('[data-stage-frame]')).toHaveAttribute('data-stage-scale', String(scale));
  }
});
```

1. initial load has one canvas and status `World ready`;
2. `window.__PHOENIX_TEST__.remount()` settles back to one canvas;
3. locked overlay and synthetic `window.blur` both prevent displacement during a `250 ms` key hold;
4. unlocking restores displacement;
5. canvas host and `[data-overlay]` rectangles match at `640×360`, `1024×768`, and `1280×720`; and
6. reported stage scales are `1`, `1`, and `2` with expected letterboxing.

Run: `rtk bun run test:e2e:install` once before executing Playwright on a fresh machine.

- [ ] **Step 3: Run lifecycle E2E tests to observe RED**

Run: `rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts`

Expected: at least one assertion fails until every required debug field, data attribute, lock path, and remount cleanup is wired correctly.

- [ ] **Step 4: Complete the minimal lifecycle/debug wiring and reach GREEN**

Keep the debug object inside an `import.meta.env.DEV` branch. Its `snapshot()` must return cloned serializable data; tests may not mutate authoritative world state. In `src/main.ts`, register a development-only Vite event counter:

```ts
if (import.meta.env.DEV && import.meta.hot) {
  window.__PHOENIX_HMR_COUNT__ = 0;
  const recordUpdate = () => { window.__PHOENIX_HMR_COUNT__ = (window.__PHOENIX_HMR_COUNT__ ?? 0) + 1; };
  import.meta.hot.on('vite:afterUpdate', recordUpdate);
  import.meta.hot.dispose(() => {
    import.meta.hot?.off('vite:afterUpdate', recordUpdate);
    delete window.__PHOENIX_HMR_COUNT__;
  });
}
```

Add `__PHOENIX_HMR_COUNT__?: number` beside `__PHOENIX_TEST__` in the global `Window` declaration. Delete the HMR counter only if `src/main.ts` itself disposes. This hook is observation-only and never mutates world state.

Run: `rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts`

Expected: all lifecycle, lock, blur, and resize tests pass.

- [ ] **Step 5: Write keyboard world-acceptance tests**

Use actual Playwright keyboard events. `moveUntil(page, key, predicate)` holds one WASD key, polls cloned snapshots, releases the key in `finally`, and fails after `3 seconds` with the last snapshot.

```ts
export async function moveUntil(
  page: Page,
  key: string,
  predicate: (value: DebugSnapshot) => boolean,
): Promise<DebugSnapshot> {
  await page.keyboard.down(key);
  try {
    await expect.poll(async () => predicate(await snapshot(page)), { timeout: 3_000 }).toBe(true);
    return await snapshot(page);
  } finally {
    await page.keyboard.up(key);
  }
}
```

Use fresh page state per test. For the tree route, hold `d` until `player.position.x >= 6.95`, hold it another `300 ms`, and assert `x <= 7.021` (the exact collision center is `7.02`); then hold `s` until `y >= 5.35`, hold `d` until `x >= 7.45`, and assert movement resumed without overlap. For edge targeting, hold `a` until `x <= 0.2`, then assert facing `left`, `target === null`, and `visibleTarget === false`.

Cover these paths:

- move into the tree until collision stops further right-facing progress, then detour down/right and confirm progress resumes;
- approach the building, slide along one footprint edge, then route around its corner without entering `[7,9)×[7,9)`;
- cross and leave the nine-cell farm patch without collision;
- move to each reachable map edge and assert the player rectangle remains in bounds;
- face outward at the top-left or bottom-right perimeter and assert `target === null` plus `visibleTarget === false`;
- face each direction away from edges and assert the target offset table exactly;
- cross designated tree and building footpoint Y values and assert player/scenery depth ranks reverse; and
- assert every camera scroll value remains within the reported projected camera bounds.

Use the exact depth thresholds implied by the authored footpoints: tree ground Y is `(7.5 + 4.5) × 16 = 192`, and building ground Y is `(9 + 9) × 16 = 288`. Route the player through clear positions where `16 × (player.x + player.y)` is at least `3.2` pixels below and above each threshold; assert `depths.player < depths.<object>` before and `>` after. For camera checks, allow `0.5` pixel tolerance and constrain scroll X to `[bounds.x, max(bounds.x, bounds.x + bounds.width - 640)]` and scroll Y to `[bounds.y, max(bounds.y, bounds.y + bounds.height - 360)]`.

- [ ] **Step 6: Add a real Vite HMR lifecycle test**

In `lifecycle.pw.ts`, record displacement from a `250 ms` key hold, append one valid Svelte comment to `src/App.svelte`, wait until the Vite HMR event counter increases, assert `World ready` and one canvas, then repeat the same key hold. Require the second displacement to remain between `0.6×` and `1.4×` the first, proving no doubled input handler. Restore the exact original bytes and timestamps, then wait for the restoration HMR event before the test returns.

```ts
const appPath = fileURLToPath(new URL('../../src/App.svelte', import.meta.url));
const original = statSync(appPath);
const originalSource = readFileSync(appPath, 'utf8');
const measure = async () => {
  const before = await snapshot(page);
  await holdKey(page, 'w', 250);
  const after = await snapshot(page);
  return Math.hypot(
    after.player.world.x - before.player.world.x,
    after.player.world.y - before.player.world.y,
  );
};
const beforeHmr = await measure();
try {
  const updateCount = await page.evaluate(() => window.__PHOENIX_HMR_COUNT__ ?? 0);
  writeFileSync(appPath, `${originalSource}\n<!-- playwright-hmr-probe -->\n`);
  await page.waitForFunction((count) => (window.__PHOENIX_HMR_COUNT__ ?? 0) > count, updateCount);
  await expect(page.locator('canvas')).toHaveCount(1);
  await expect(page.getByText('World ready')).toBeVisible();
  const afterHmr = await measure();
  expect(afterHmr).toBeGreaterThan(beforeHmr * 0.6);
  expect(afterHmr).toBeLessThan(beforeHmr * 1.4);
} finally {
  const restoreCount = await page.evaluate(() => window.__PHOENIX_HMR_COUNT__ ?? 0);
  writeFileSync(appPath, originalSource);
  utimesSync(appPath, original.atime, original.mtime);
  await page.waitForFunction((count) => (window.__PHOENIX_HMR_COUNT__ ?? 0) > count, restoreCount);
}
```

Import `readFileSync`, `writeFileSync`, `statSync`, and `utimesSync` from `node:fs`, plus `fileURLToPath` from `node:url`. The `finally` block must leave `git status --short` empty even when an assertion fails.

- [ ] **Step 7: Run all browser acceptance tests GREEN**

Run:

```bash
rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts
rtk bun run test:e2e -- tests/e2e/world.pw.ts
rtk bun run test:e2e
rtk bun run build
rtk git status --short
```

Then run `rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist` and require exit code `1` with no matches. Expected: all Chromium tests pass, HMR leaves exactly one game, neither test hook survives the production build, and Git reports no test-created content changes.

- [ ] **Step 8: Commit browser acceptance coverage**

```bash
rtk git add playwright.config.ts tests/e2e src/main.ts src/game/phaser/ProofScene.ts src/vite-env.d.ts
rtk git commit -m "test: cover Phoenix browser acceptance"
```

### Task 8: macOS Tauri Acceptance, Clean-Checkout Proof, and Handoff Documentation

**Files:**

- Create: `tools/verify-clean-checkout.ts`
- Create: `README.md`
- Modify: `package.json` only if verification commands need a corrected script spelling.
- Modify: implementation files only for defects reproduced by the verification commands below.

**Interfaces:**

- Consumes: all Bun scripts, tests, builds, and runtime surfaces from Tasks 1-7.
- Produces: `bun run verify:clean` as reproducible clean-checkout evidence.
- Produces: macOS `.app` and `.dmg` artifacts under `src-tauri/target/release/bundle/`.
- Produces: contributor documentation and final HPA-588 evidence.

- [ ] **Step 1: Write the clean-checkout verifier**

Use `mkdtemp` from `node:fs/promises` under `tmpdir()`. Run `git archive --format=tar HEAD`, save its stdout to a temporary tar file, extract it into the temporary checkout, then run each command with `Bun.spawn` and inherited output:

```ts
import { mkdtemp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const commands = [
  ['bun', 'install', '--frozen-lockfile'],
  ['bun', 'run', 'test:e2e:install'],
  ['bun', 'run', 'check'],
  ['bun', 'test'],
  ['bun', 'run', 'test:e2e'],
  ['bun', 'run', 'build'],
  ['bun', 'run', 'tauri:build'],
] as const;

async function run(command: readonly string[], cwd: string): Promise<void> {
  const child = Bun.spawn(command, { cwd, stdin: 'inherit', stdout: 'inherit', stderr: 'inherit' });
  const code = await child.exited;
  if (code !== 0) throw new Error(`clean verification failed (${code}): ${command.join(' ')}`);
}

const checkout = await mkdtemp(join(tmpdir(), 'phoenix-clean-'));
const archive = `${checkout}.tar`;
try {
  const git = Bun.spawn(['git', 'archive', '--format=tar', 'HEAD'], { stdout: 'pipe', stderr: 'inherit' });
  const archiveBytes = await new Response(git.stdout).arrayBuffer();
  if (await git.exited !== 0) throw new Error('git archive failed');
  await Bun.write(archive, archiveBytes);
  await run(['tar', '-xf', archive, '-C', checkout], process.cwd());
  for (const command of commands) await run(command, checkout);
} finally {
  await rm(archive, { force: true });
  await rm(checkout, { recursive: true, force: true });
}
```

Abort on the first non-zero exit and include the command in the error. In `finally`, remove only the exact `mkdtemp` directory and tar path with `node:fs/promises.rm`. Never accept a user-supplied deletion target.

- [ ] **Step 2: Write concise contributor documentation**

`README.md` must include:

- prerequisites: macOS, Bun 1.3.1, Rust/Cargo 1.96, Xcode command-line tools;
- clean setup: `bun install` and `bun run test:e2e:install`;
- browser: `bun run dev`;
- desktop: `bun run tauri:dev`;
- controls: WASD and overlay input lock;
- verification commands: check, test, E2E, frontend build, Tauri build, clean verification;
- ownership: pure TypeScript rules, Phaser world adapter, Svelte overlay, Tauri shell;
- map contract: `12×12`, `64×32`, embedded Tiled tilesets; and
- explicit statement that this slice is verified on macOS and does not claim Windows/Linux acceptance.

- [ ] **Step 3: Run the complete local automated verification matrix**

Run fresh, without relying on previous task output:

```bash
rtk bun run assets:generate
rtk bun run check
rtk bun test
rtk bun run test:e2e
rtk bun run build
rtk bun run tauri:build
```

Expected: every command exits 0; unit and browser output report zero failures; frontend and macOS Tauri production artifacts exist.

If a command exposes a defect, use `superpowers:systematic-debugging`, add the narrowest regression test at the owning layer, make the minimal fix, rerun that focused test and this entire matrix, and commit the fix before continuing. Do not let `verify:clean` archive an older `HEAD` while relying on an uncommitted correction.

- [ ] **Step 4: Run browser visual smoke at 1× and 2×**

Start `bun run dev`, open `http://localhost:1420`, and capture `640×360` and `1280×720` screenshots. Inspect both images for:

- crisp diamond edges and sprite pixels;
- identical canvas/overlay alignment;
- visible farm patch, tree, building, player, and target diamond;
- correct letterboxing; and
- no clipping at camera bounds.

Store temporary evidence outside the repository unless the user asks to preserve it.

- [ ] **Step 5: Run the macOS Tauri visual smoke**

Run `bun run tauri:dev`. In the Phoenix window, verify the same proof world, WASD movement, overlay lock, edge targeting, and player passage behind/in front of both tall objects. Resize between `640×360`, `1024×768`, and `1280×720`; confirm integer scaling and aligned overlay. Trigger one development HMR update and verify a single movement response.

Capture the Phoenix window and inspect it; do not infer desktop parity from the browser build alone.

- [ ] **Step 6: Commit documentation and clean-verification tooling**

First run `rtk git status --short` and require that every modified path is either the documentation/verifier from this task or an already-tested defect fix found in Steps 3-5. Commit any defect fix separately with its regression test, then commit the handoff files:

```bash
rtk git add README.md package.json tools/verify-clean-checkout.ts
rtk git commit -m "docs: add Phoenix foundation verification guide"
```

- [ ] **Step 7: Prove a clean committed checkout**

Run:

```bash
rtk bun run verify:clean
rtk git status --short --branch
```

Expected: archive-based install/check/test/E2E/frontend/Tauri verification exits 0 and the working tree remains clean.

- [ ] **Step 8: Perform final source-boundary and acceptance audit**

Run:

```bash
rtk rg -n "ProofWorld|collision|target|facing" src-tauri src/components
rtk rg -n "Phaser|svelte" src/game/core
rtk find . -maxdepth 2 -type f \( -name 'package-lock.json' -o -name 'pnpm-lock.yaml' -o -name 'yarn.lock' \)
rtk git log --oneline --decorate -8
```

Expected: no gameplay implementation appears in Rust or Svelte, no framework import appears in the core, no forbidden JavaScript lockfile exists, and every task has its dedicated commit.

- [ ] **Step 9: Update roadmap evidence after the implementation review passes**

Post the exact verification commands, macOS smoke result, build artifact paths, and final commit SHA to HPA-588. Mark HPA-588 complete only after task review, whole-branch review, and any resulting fix/re-review loop pass. Do not change HPA-587 directly; it remains open until HPA-599 completes.

## Plan Self-Review

| Approved requirement | Planned evidence |
| --- | --- |
| Bun-only clean setup and pinned stack | Task 1 scaffold contract; Task 8 archive-based frozen install |
| Same proof world in browser and macOS Tauri | Tasks 5-7 browser runtime/tests; Task 8 native smoke and build |
| `12×12`, `64×32`, embedded Tiled data | Task 4 generated map, PNG header tests, and fail-fast parser tests |
| Reversible projection and explicit edge policy | Task 2 round-trip, boundary epsilon, all-edge, diamond, and bounds tests |
| Screen-relative WASD without diagonal speedup | Task 3 pure-rule tests; Task 7 real keyboard paths |
| Map-bound and footprint collision with sliding | Task 3 tree/building/unit cases; Task 7 navigation routes |
| Four-direction facing and ahead-tile targeting | Tasks 3 and 7, including outside-map `null` behavior |
| Stable front/behind rendering | Task 2 stable-sort test; Tasks 5 and 7 authored footpoint thresholds |
| One Phaser instance through remount and HMR | Task 5 lifecycle tests; Task 7 remount and actual Vite-update checks |
| Crisp integer scale with aligned overlay | Task 6 pure fit tests; Tasks 7-8 browser and native resize evidence |
| Failure cleanup and visible fatal errors | Tasks 4-6 parser, asset-error, lifecycle, and reload contracts |
| No gameplay authority in Svelte, Phaser, or Rust | File ownership in Tasks 2-5; final source-boundary audit in Task 8 |
| macOS-only desktop acceptance claim | Global constraint, README boundary, Tauri build, and native smoke in Task 8 |

Self-review found and resolved five plan-level hazards: external Tiled tilesets unsupported by the pinned Phaser parser; ambiguous Phaser render-option placement; Bun accidentally discovering Playwright's default test suffix; nondeterministic fixed-delay HMR observation; and a clean-checkout archive that could ignore uncommitted fixes. Every function referenced by a code excerpt is either defined in that task or explicitly consumed from an earlier task, direct dependencies are exact pins, command examples use the repository's RTK convention, and Markdown fences are balanced.

No approved behavior is left without a unit, browser, build, source-audit, or macOS visual-smoke evidence path. Runtime results and screenshots remain execution evidence to collect in Task 8; this planning review does not claim that the unimplemented application already passes them.
