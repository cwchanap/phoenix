# Phoenix

Phoenix combines the HPA-588 foundation slice with the HPA-591 turnip day-loop
slice: a browser and Tauri proof world where you can move through the authored
map, hoe and plant a turnip, water it through three nights, and harvest it.
This macOS-first farming MVP is verified on macOS only; it does not claim
acceptance for Windows or Linux.

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

Controls are keyboard-first: WASD moves in screen-relative directions; keys
1–4 select Hoe, Seeds, Water, and Hands respectively. Press Space to apply the
selected action to the highlighted farm cell. Press E when the bed is
highlighted to request sleep. The overlay input lock prevents keyboard
movement while it is enabled; unlock it to resume movement.

The new session starts with three starter seeds for turnips. A planted turnip
advances one growth stage after each of three watered nights; harvest it with
Hands after the third night. Pressing E at the bed opens a Svelte confirmation
panel that locks world input. Confirm advances the authoritative session once
and releases the lock; Cancel releases the lock without changing the farm.

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
  targeting rules. `GameSession` is the authority for the day, selected
  action, farm tiles, crop growth, and inventory.
- Phaser owns the world/render adapter, camera, assets, and keyboard sampling.
- Svelte owns the fitted stage and screen-space overlay, including the HUD,
  action buttons, feedback, sleep confirmation, and input lock presentation.
- Tauri remains the unchanged macOS-only desktop shell; gameplay authority
  stays in the frontend rules layer.

The authored proof map is a finite 12×12 (12x12) logical grid using 64×32
(64x32) 2:1 isometric tiles and embedded Tiled tilesets.
