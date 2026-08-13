# Phoenix

Phoenix is the HPA-588 foundation slice: a browser and Tauri proof world for
the macOS-first farming MVP. This slice is verified on macOS only; it does not
claim acceptance for Windows or Linux.

## Prerequisites

- macOS
- Bun 1.3.1
- Rust/Cargo 1.96
- Xcode command-line tools

## Setup

```bash
bun install
bun run test:e2e:install
```

## Run

Start the browser at the strict development URL with:

```bash
bun run dev
```

Run the desktop shell with:

```bash
bun run tauri:dev
```

Use WASD for screen-relative movement. The overlay input lock prevents
keyboard movement while it is enabled; unlock it to resume movement.

## Verification and builds

```bash
bun run check
bun test
bun run test:e2e
bun run build
bun run tauri:build
bun run verify:clean
```

`verify:clean` archives the committed `HEAD` into a temporary checkout and
runs the complete frozen-install, browser, static-check, unit-test, frontend,
and macOS Tauri build matrix there.

## Architecture and authored map contract

- Framework-free TypeScript owns projection, movement, collision, facing, and
  targeting rules.
- Phaser owns the world/render adapter, camera, assets, and keyboard sampling.
- Svelte owns the fitted stage and screen-space overlay, including the input
  lock.
- Tauri owns the macOS desktop shell only; gameplay authority stays in the
  frontend rules layer.

The authored proof map is a finite 12×12 (12x12) logical grid using 64×32
(64x32) 2:1 isometric tiles and embedded Tiled tilesets.
