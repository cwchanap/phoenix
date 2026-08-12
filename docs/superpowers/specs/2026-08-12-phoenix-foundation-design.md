# Phoenix Foundation Design (HPA-588)

**Status:** Approved for implementation planning

**Date:** 2026-08-12

**Delivery target:** macOS-first browser and Tauri foundation slice

## Source of truth

This design implements the first active slice under [HPA-587](https://linear.app/cwchanap/issue/HPA-587/tracking-deliver-the-phoenix-14-day-farming-mvp): [HPA-588](https://linear.app/cwchanap/issue/HPA-588/foundation-bootstrap-phoenix-and-prove-the-sprite-isometric-world). The Phoenix Linear project description remains authoritative for product scope, fixed technology choices, delivery order, and non-goals.

HPA-588 must prove the real stack and the riskiest rendering behavior before farming rules begin. It is not an empty application scaffold.

## Outcome

From a clean checkout, a developer can use Bun to run Phoenix in a browser or in a Tauri 2 macOS shell. Both display the same tiny sprite-isometric proof world. The player can move with screen-relative WASD controls around explicit collision footprints, pass correctly in front of and behind tall scenery, and see the logical tile immediately ahead highlighted.

The completed slice is the foundation for HPA-591. It contains no crop, inventory, economy, social, persistence, tutorial, or finale rules.

## Decisions

- Use a thin custom vertical slice instead of adapting a larger game template.
- Initialize a Vite, Svelte 5, and TypeScript frontend with a minimal Tauri 2 shell.
- Use Bun as the sole JavaScript package manager and script entry point.
- Pin Phaser exactly to `4.2.1` and commit only `bun.lock`.
- Verify the desktop path on macOS. Keep ordinary Tauri configuration portable, but make no Windows or Linux verification claim in this slice.
- Use a fixed `640×360` logical presentation with integer scaling and letterboxing. The initial Tauri window is `1280×720`, with a minimum size of `640×360`.
- Use a `12×12` Tiled isometric proof map with `64×32` ground diamonds.
- Keep authoritative movement, collision, facing, targeting, and projection behavior in framework-free TypeScript.
- Use temporary proof assets designed for clarity at integer scale. Final art direction is outside HPA-588.

## Architecture and ownership

### Svelte

Svelte owns the application shell, fitted stage, screen-space overlay, lifecycle status, and fatal-error presentation. It does not own authoritative gameplay state.

`App.svelte` composes two layers inside one fitted logical stage:

1. `GameHost.svelte`, which owns the Phaser lifecycle.
2. `Overlay.svelte`, which displays controls, status, and a small world-input lock toggle.

The overlay uses the same `640×360` logical coordinate space as the Phaser canvas, so both layers receive one shared scale and letterbox offset.

### Phaser

Phaser owns rendering, camera follow, asset loading, and keyboard sampling. `ProofScene` translates device input into a framework-free input value, advances the pure TypeScript world model, and synchronizes visible objects from the resulting render snapshot.

Phaser scene fields may hold references to the world model and render objects, but the scene does not implement or duplicate gameplay rules.

### Pure TypeScript

`ProofWorld` owns the authoritative foundation state:

- continuous logical-grid player position;
- four-direction facing;
- static collision footprints;
- map bounds;
- movement and collision resolution; and
- the current target tile or `null`.

Small framework-free functions own coordinate conversion and depth calculation. They import neither Phaser nor Svelte and are directly unit tested.

### Tauri and Rust

Tauri supplies only the desktop window and local application shell. Rust contains generated/minimal Tauri setup and no gameplay rules, map logic, or state.

## Proposed source layout

```text
src/
  App.svelte
  components/
    GameHost.svelte
    Overlay.svelte
  game/
    core/
      InputGate.ts
      ProofWorld.ts
      collision.ts
      isometric.ts
      types.ts
    phaser/
      createGame.ts
      ProofScene.ts
      loadProofMap.ts
  assets/
    maps/
      proof-map.json
      proof-tileset.json
    sprites/
      proof-tiles.png
      proof-player.png
      proof-scenery.png
tests/
  e2e/
src-tauri/
```

Files may be combined when implementation shows that a boundary would otherwise contain only trivial forwarding code. The ownership boundaries above must remain intact.

## Lifecycle and input locking

`GameHost.svelte` constructs a lifecycle controller during `onMount`. The controller creates one Phaser game for the supplied host element and returns a cleanup function that destroys the game, canvas, scene resources, and registered handlers.

Before creating a game, the controller disposes any instance it already owns. Svelte unmount and Vite hot-module disposal both invoke the same idempotent cleanup path. This prevents duplicate canvases and keyboard handlers during development reloads.

`InputGate` is a small injected object with explicit lock reasons. `Overlay.svelte` uses one reason for its demonstration toggle, while window blur uses another. Phaser reads the aggregate locked state before passing input to `ProofWorld`. Locking also clears sampled held-key state so focus restoration cannot apply stale movement.

This is a direct dependency passed at game creation, not a global event bus or Svelte store.

## Proof map and assets

The Tiled JSON map uses:

- orientation `isometric`;
- render order `right-down`;
- width and height `12×12`;
- tile size `64×32`;
- one ground tile layer;
- one scenery object layer;
- one collision-footprint object layer; and
- one marker object layer.

The proof map contains a visible farm patch, one tree, one small building, blocked perimeter cells, and one player spawn. It deliberately omits the full farm and village.

Ground remains on a fixed low depth. Tall scenery is represented by independent sprites or image objects with explicit ground-contact points. Collision uses logical-grid footprints authored alongside those objects; transparent image bounds never determine collision.

The loader validates the map orientation, dimensions, tile size, required layers, unique spawn, known scenery kinds, footprint dimensions, and in-bounds coordinates. It converts validated map data into a framework-free `ProofMap` consumed by `ProofWorld` and the scene renderer.

## Isometric coordinate contract

Logical grid coordinates are continuous floats. With projected-world origin `(originX, originY)`, a logical point `(gridX, gridY)` projects to:

```text
worldX = originX + (gridX - gridY) × 32
worldY = originY + (gridX + gridY) × 16
```

The inverse is:

```text
gridX = (worldX - originX) / 64 + (worldY - originY) / 32
gridY = (worldY - originY) / 32 - (worldX - originX) / 64
```

Grid-cell lookup applies `floor` only at the boundary where a continuous point becomes a tile index. Conversion helpers otherwise preserve fractional coordinates. Tests cover tile centers, boundaries with an explicit epsilon policy, and every map edge.

Four screen-facing directions map to logical tile offsets as follows:

| Facing | Grid offset |
| --- | ---: |
| Up | `(-1, -1)` |
| Right | `(+1, -1)` |
| Down | `(+1, +1)` |
| Left | `(-1, +1)` |

## Movement and collision

WASD produces a screen-space vector. Opposing keys cancel. Non-zero diagonal input is normalized before speed is applied, ensuring diagonal movement is not faster.

The desired projected displacement is inverse-projected into a logical-grid displacement. `ProofWorld` resolves that displacement against map bounds and explicit static footprints. The player uses a small ground-contact footprint centered beneath the visible sprite. Resolution treats logical axes separately so the player slides along obstacles instead of sticking at corners. Large frame deltas are capped and subdivided to prevent tunneling.

Facing follows the dominant non-zero screen-space component and retains the last direction while idle. The temporary player sprite has four visually distinct facing frames.

## Depth sorting

Each movable or tall object exposes one projected ground-contact point. Its primary depth key is that point's projected Y coordinate. A stable object-order key breaks exact ties, preventing frame-to-frame flicker.

The player depth is recalculated after movement. Tree and building depth keys remain anchored to their authored footpoints. The visible result must place the player behind each object when the player's footpoint is above it and in front when below it.

Ground and the target diamond use fixed depth bands below entities. The screen-space Svelte overlay remains above the Phaser canvas and is not part of world depth sorting.

## Targeting

The targeting adapter converts the player's continuous position to its logical tile, applies the current facing offset, and checks map bounds. It returns either a valid integer grid coordinate or `null`; it never silently clamps an outside coordinate.

`ProofScene` projects a returned coordinate and renders a diamond outline matching the `64×32` tile. A `null` target hides the highlight. Unit and browser tests cover all four directions, fractional player positions, and perimeter cells.

## Camera and presentation scaling

The Phaser camera follows the player's projected footpoint with restrained interpolation and is constrained to bounds derived from all four projected corners of the isometric map plus the visible height of scenery. The player can reach all permitted proof-map areas without exposing unrendered space where the camera can avoid it.

The stage's internal size is always `640×360`. For supported viewports of at least that size, Svelte selects the largest whole-number scale that fits both dimensions and centers the result. Extra space becomes letterboxing. The Phaser canvas and overlay are children of the same transformed stage, preventing independent rounding drift.

Phaser uses a pixel-art configuration with texture smoothing disabled and a render resolution of one. Canvas CSS uses pixelated image rendering. The Tauri window starts at `1280×720` for a 2× scale and cannot resize below `640×360`.

## Failure behavior

- Map or asset validation failure aborts scene startup and reports a descriptive fatal error to Svelte.
- Partial Phaser startup is destroyed before the error is exposed.
- The error overlay names the failed asset or invalid map contract and offers a normal page reload, not an in-process retry system.
- An outside target is represented explicitly as `null`.
- Unknown map objects and malformed footprints fail validation instead of being ignored or guessed.
- Window blur locks input and clears held keys.

There is no telemetry, backend reporting, recovery registry, or plugin framework in this slice.

## Scripts and dependency policy

The root package exposes Bun entry points for:

- `bun run dev` — browser development;
- `bun run check` — TypeScript and Svelte static checks;
- `bun test` — framework-free and lifecycle unit tests;
- `bun run test:e2e` — browser acceptance tests;
- `bun run build` — frontend production build;
- `bun run tauri:dev` — Tauri development; and
- `bun run tauri:build` — macOS Tauri production build.

Direct dependencies are installed as exact versions. Phaser is fixed at `4.2.1`. The implementation plan will record the exact versions resolved for the remaining current stable dependencies when the scaffold is created. Bun generates the only JavaScript lockfile.

## Verification strategy

### Unit tests

Bun tests cover:

- grid-to-world and world-to-grid round trips;
- cell selection at centers, boundaries, and all proof-map edges;
- normalized diagonal movement and opposing-key cancellation;
- movement subdivision and map-bound collision;
- tree and building footprint collision with sliding;
- four-direction facing;
- target offsets and outside-map `null` behavior;
- footpoint depth ordering and stable ties;
- nested input-lock reasons and held-input clearing; and
- idempotent Phaser lifecycle cleanup using an injected fake factory.

### Browser acceptance tests

Playwright runs against the Vite application and verifies:

- exactly one canvas exists after load and reload;
- deterministic key input changes the player snapshot;
- the player cannot enter static footprints or leave bounds;
- the overlay and window blur lock movement;
- the visible target matches the adapter's logical target;
- outside-map targets hide the diamond;
- canvas and overlay rectangles remain aligned at supported viewport sizes; and
- the stage selects the expected integer scale and letterbox offset.

A read-only debug snapshot is available only in development/test builds for deterministic browser assertions. Production builds do not expose it.

### Build and visual smoke evidence

Completion requires fresh successful output from static checks, unit tests, browser tests, the frontend production build, and the Tauri macOS build.

Browser and `tauri dev` smoke checks additionally confirm:

- the same proof world appears in both hosts;
- proof assets remain crisp at 1× and 2×;
- camera follow respects projected bounds;
- movement does not become stuck around the tree, building, or farm patch;
- the player passes visibly behind and in front of the tree and building without depth flicker; and
- development reload does not duplicate the game or input response.

## Acceptance mapping

| HPA-588 requirement | Primary evidence |
| --- | --- |
| Bun-only clean checkout | lockfile inspection plus documented clean install and scripts |
| Same browser and Tauri world | browser and macOS Tauri smoke checks |
| Navigable proof map | browser tests plus visual smoke |
| Explicit ground footprints | map validation and collision unit/browser tests |
| Correct depth behavior | depth unit tests plus visual smoke |
| Correct target diamond at edges | projection/target unit tests plus browser assertions |
| Crisp aligned resize behavior | browser viewport tests plus visual smoke |
| No duplicate Phaser instances | lifecycle unit tests plus reload browser test |
| Frontend and Tauri builds | fresh build command output |
| No misplaced gameplay rules | source review against ownership boundaries |

## Non-goals

This slice does not implement the complete farm or village, crops, tools, time, stamina, weather, sleep, inventory, economy, villagers, relationships, saving, tutorial content, the Day 14 finale, final art, pathfinding, multiple maps, mobile packaging, auto-update, a backend, a database, real 3D geometry, 3D physics, camera rotation, dynamic lighting, shaders, or a second renderer.
