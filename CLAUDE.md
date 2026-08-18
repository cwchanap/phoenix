# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Phoenix is a macOS-first isometric farming MVP delivered as a browser app (Vite + Svelte 5 + Phaser 4) wrapped in a Tauri 2 desktop shell. Runtime is Bun; there is no npm/yarn lockfile.

## Commands

```bash
bun install                     # deps (bun.lock is the only JS lockfile)
bun run test:e2e:install        # one-time: Playwright Chromium
bun run dev                     # vite on localhost:1420, strictPort
bun run tauri:dev               # desktop shell

bun run check                   # svelte-check --tsgo (type gate)
bun run lint                    # eslint .
bun run format:check            # prettier --check .
bun test                        # bun unit tests (tests/**/*.test.ts)
bun run test:coverage           # writes coverage/lcov.info
bun run coverage:check          # fails under 90% line AND function coverage
bun run test:e2e                # Playwright; own dev server on port 1422
bun run build                   # vite build
bun run tauri:build -- --no-sign
bun run verify:clean            # full 11-command matrix on a git-archive of HEAD
bun run assets:generate         # regenerate src/assets/sprites/*.png procedurally
```

Single tests:

```bash
bun test tests/game/GameSession.test.ts
bun test -t "harvest"                    # filter by test name
bun run test:e2e tests/e2e/economy.pw.ts
bun run test:e2e --grep "shipping"
```

E2E runs `fullyParallel: false`, `workers: 1`, and spawns its own `bun run dev -- --port 1422`; do not have `bun run dev` occupying 1422 while running them. Traces land in `test-results/` on failure.

## Architecture

Strict layering, enforced by where the logic lives — keep it that way:

- **`src/game/core/` — framework-free TypeScript, the rules authority.** No Phaser, no Svelte, no DOM. `GameSession` owns day/clock/stamina/weather, farm tiles, crop growth, inventory, money, and shipments; every mutation goes through a method returning `CommandResult` (`{ok:true, code}` / `{ok:false, code}`) from the closed `SuccessCode`/`FailureCode` unions in `core/types.ts`. `ProofWorld` owns position, facing, and the facing-derived target cell. `isometric.ts`/`collision.ts` own projection and movement math. Snapshots are always deep-cloned on the way out.
- **`src/game/phaser/` — render/input adapter.** `ProofScene` samples keyboard, calls into `GameSession`, and mirrors the snapshot onto sprites; it must not encode rules. `loadProofMap.ts` parses the authored Tiled map and _hard-fails_ on any deviation from the committed contract (object ids, gids, world coordinates, footprints, marker cells). `createGame` fixes the canvas at 640×360, `Phaser.Scale.NONE`, pixel-art.
- **`src/components/` + `src/App.svelte` — screen-space UI.** `StageFrame` scales the 640×360 stage by integer factors only. `Overlay` renders the HUD, action buttons, feedback, sleep confirmation, morning summary, and shop/shipping panels. `App.svelte` owns modal state and drives the input lock.
- **`src-tauri/` — unchanged desktop shell.** No gameplay logic belongs here.

### Cross-cutting mechanisms

- **`InputGate`** is a reason-keyed lock (`'day-transition'`, `'economy-panel'`, `'window-blur'`). Any reason set locks world keyboard input. `GateBoundKeys` resets held Phaser keys on entering the lock so a key held across a modal does not resume movement. New modals must set and clear their own reason.
- **`GameSession.pendingDaySummary`** blocks every command with `day-summary-pending` until `acknowledgeDaySummary()`. Sleep is two-stage: `sleep()` advances the day and stores the summary; the summary is blocking and keyboard-locked until "Start Day N".
- **Dev-only test hook.** `GameHost.svelte` publishes `window.__PHOENIX_TEST__` (`snapshot()`, `gameSnapshot()`, `remount()`) under `import.meta.env.DEV` only. E2E reads state exclusively through it plus `data-*` attributes (`data-farming-hud`, `data-economy-modal`, `data-shipment-row`, …) — no CSS-class selectors.
- **E2E timing.** Movement/targeting is frame-based; use `tests/e2e/helpers.ts` (`acquireTarget`, `moveUntil*`, `waitForCameraToSettle`, `confirmAndStartDay`) rather than fixed waits.

## Contract tests that will fail on "unrelated" edits

`tests/config/` asserts on repo metadata, so these edits require matching test updates:

- `scaffold.test.ts` pins **exact** dependency versions and script strings in `package.json`. Bumping any dep or renaming a script fails the suite.
- `handoff.test.ts` asserts that `README.md` contains specific phrases (prerequisites, every verification command, control names, crop prices, the map-contract wording), that `tools/verify-clean-checkout.ts` contains its exact 11 commands, and that `.github/workflows/ci.yml` keeps its four jobs (Build, Unit test, E2E, Tauri build) with specific steps. Change gameplay numbers, CI structure, or the verifier and update README + this test together.

## Conventions

- Prettier: 100 cols, single quotes, trailing commas. Husky + lint-staged run eslint --fix and prettier on commit.
- Commits are conventional and small: `feat:`, `fix:`, `test:`, `docs:`, `ci:`, `chore:`.
- Design specs and implementation plans live in `docs/superpowers/specs/` and `docs/superpowers/plans/`, dated and named per slice (HPA-5xx). Work is delivered slice by slice; the README documents the current slice's state including temporary boundaries (e.g. Day 14 returns `day-limit-reached` instead of advancing).
- New rules logic goes in `core/` with a `bun test` unit test; only the visible behaviour of that rule belongs in an e2e test. Coverage gate is 90% lines and functions over `src/` (tests, tools, and `src-tauri` are excluded via `bunfig.toml`).
