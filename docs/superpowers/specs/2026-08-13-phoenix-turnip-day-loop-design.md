# Phoenix Turnip Day Loop Design (HPA-591)

**Status:** Approved for implementation planning

**Date:** 2026-08-13

**Delivery target:** macOS-first browser and Tauri farming slice

## Source of truth

This design implements the second active slice under [HPA-587](https://linear.app/cwchanap/issue/HPA-587/tracking-deliver-the-phoenix-14-day-farming-mvp): [HPA-591](https://linear.app/cwchanap/issue/HPA-591/farming-slice-deliver-one-complete-turnip-day-loop). The Phoenix Linear project description remains authoritative for product scope, fixed technology choices, delivery order, and non-goals.

HPA-591 builds directly on the completed HPA-588 sprite-isometric foundation. It delivers one coherent farming loop and only the domain state, rendering, input, and Svelte presentation required by that loop.

## Outcome

A new game starts on Day 1 with three turnip seeds. The player can walk to the existing nine-cell farm patch, select tools or items, target a logical farm diamond, hoe it, plant a turnip seed, water the crop, sleep, and repeat watering and sleeping until the turnip matures after three watered nights. The player can then harvest exactly one turnip into inventory. The same loop runs in browser development and the Tauri macOS application.

The slice must be playable through normal controls. Developer hooks may observe state for tests, but they do not perform farming actions.

## Approved decisions

- Use one composed, framework-free `GameSession` as the authoritative gameplay boundary.
- Preserve `ProofWorld` as the owner of movement, facing, collision, and target selection; `GameSession` composes it instead of duplicating those rules.
- Start every new game on Day 1 with exactly three turnip seeds and zero harvested turnips.
- Default the selected farming action to `hoe`, the first action in the playable loop.
- A turnip matures after exactly three watered day transitions.
- Use keyboard-first controls with matching clickable Svelte selection buttons.
- Use a blocking Svelte confirmation panel before sleeping.
- Keep expected gameplay failures atomic and represent them with stable result codes rather than exceptions.
- Keep feedback visible until the next action replaces it; do not add timer-driven toast behavior.
- Generate clear temporary farming sprites with the existing deterministic asset workflow. Final art remains outside this slice.
- Continue the existing `bun:test` unit suite instead of adding a second test runner. The ticket's Vitest wording is implemented as equivalent framework-free unit coverage under Phoenix's established Bun-only script and dependency policy.

## Explicit non-goals

This slice does not add potatoes, pumpkins, money, a shop, shipping, action-time costs, stamina, weather, relationships, dialogue, tutorial sequencing, autosave, multiple save slots, final art, generic event buses, plugin systems, a generalized domain framework, or a speculative complete-MVP state schema.

It does not add distribution signing or notarization. The native acceptance target remains a locally built macOS application and DMG.

## Architecture and ownership

### Pure TypeScript domain

`GameSession` is the single authoritative application-domain object. It owns:

- one `ProofWorld` instance;
- the current day;
- the selected farming action;
- the turnip-seed and harvested-turnip inventory stacks;
- the farm state for the nine authored logical cells; and
- the authored logical bed-interaction cell.

`ParsedProofMap` gains `bedCell: GridCell` alongside its existing row-major `farmCells`. `ProofMap` remains unchanged and movement-only. `ProofScene` constructs the session through this exact framework-free boundary:

```ts
new GameSession({
  world: parsed.world,
  metrics: projection.metrics,
  farmCells: parsed.farmCells,
  bedCell: parsed.bedCell,
});
```

`metrics` is explicit because the composed `ProofWorld` requires `ProjectionMetrics` for movement conversion. Construction defensively clones its inputs and throws if there are not exactly nine farm cells, if a farm cell repeats, if the bed cell is a farm cell, or if the bed cell overlaps a `world.footprints` collision rectangle. For collision validation, the bed cell is a unit logical rectangle and reuses the foundation's strict edge-touching-is-clear intersection policy. These are configuration failures, not expected gameplay failures, and are directly testable without a Tiled fixture.

`GameSession` exposes direct commands for selection, applying the selected action, hoeing, planting, watering, harvesting, and sleeping. It returns fresh JSON-serializable snapshots and never imports Phaser or Svelte.

`ProofWorld` remains a focused movement unit. `GameSession.stepMovement()` delegates to it and includes the resulting player and target state in the complete game snapshot. Collision, projection, facing, and target-offset behavior therefore keep their existing tested contracts.

### Phaser

`ProofScene` parses the map, constructs the `GameSession`, samples movement and action keys, invokes session commands, and reconciles visible Phaser objects from session snapshots. Space passes the current `GridCell | null` to `GameSession.applySelectedAction()`; Phaser never switches from the selected action to a farming rule itself. Phaser owns asset loading, sprites, graphics, camera follow, keyboard integration, and render-object lifecycles. It does not implement farming rules.

The scene publishes snapshots, command results, and a narrow UI command facade through explicit dependencies. The existing `onReady()` becomes `onReady(commands: SceneCommands)`, eliminating a separate command-readiness callback and its ordering ambiguity. `ProofSceneDependencies` otherwise gains explicit `onGameSnapshot`, `onCommandResult`, and `onSleepPrompt` callbacks alongside the existing error and debug-snapshot callbacks. `SceneCommands` has exactly two methods, `selectAction(action: FarmingAction): CommandResult` and `sleep(): CommandResult`, for the Svelte-owned interactions that must enter the domain. It does not expose the session object or create a generic message bus.

The scene publishes the initial `onGameSnapshot` before calling `onReady(commands)`, then publishes once after every selection, farming, or sleep command, whether that command succeeds or fails. It does not publish fresh Svelte state on movement-only frames. Per-frame work remains player rendering, target rendering, camera/debug publication, and entity depth sorting. This keeps rejected-command snapshots stable and avoids driving the HUD at 60 frames per second.

### Svelte

Svelte owns the fitted stage, HUD, action-selection buttons, sleep-confirmation panel, feedback text, lifecycle status, and fatal-error presentation. It displays values from the latest immutable session snapshot and does not maintain a second inventory, day counter, farm model, or selected-action authority.

`App.svelte` owns presentation-only state: the latest immutable game-snapshot reference, the latest command result, whether the sleep panel is open, and the current two-method scene command facade received with readiness. `GameHost.svelte` continues to own Phaser creation and teardown, keeps the existing per-frame debug snapshot private for the development hook, and forwards change-driven game snapshots and command results through explicit callbacks.

### Tauri and Rust

Tauri continues to provide only the desktop window and local application shell. Rust gains no gameplay state or farming logic. Browser development and Tauri load the same frontend code and assets.

## Domain model

### Coordinates and farm identity

Every farming boundary reuses the foundation's existing integer `GridCell` type. This slice does not introduce or rename it to `GridPosition`. The continuous player position remains `GridPoint`.

Farm tiles are created only from the validated `farmCells` authored in the Tiled map. A position is a farm position only when it exactly matches one of those cells. Commands do not silently create tiles or clamp outside coordinates.

The bed interaction is one separately validated logical cell. It is not a farm tile and does not carry crop state.

### Farming action

The authoritative selected action is one of:

```ts
type FarmingAction = 'hoe' | 'turnipSeeds' | 'wateringCan' | 'hands';
```

User-facing labels are Hoe, Seeds, Water, and Hands. Hands is the harvest action for this slice.

### Farm tile and crop state

Each farm tile has the following serializable shape:

```ts
interface FarmTileSnapshot {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: null | {
    kind: 'turnip';
    growth: 0 | 1 | 2 | 3;
    wateredToday: boolean;
  };
}
```

Growth level 0 is newly planted. Levels 1 and 2 are growing. Level 3 is mature. Maturity is derived from `growth === 3`; it is not stored as a competing boolean.

All nine tiles start untilled with no crop. Harvesting removes the crop and preserves `soil: 'tilled'`.

### Inventory and day

The inventory contains two non-negative integer stacks:

```ts
interface InventorySnapshot {
  turnipSeeds: number;
  turnips: number;
}
```

A new game starts with `{ turnipSeeds: 3, turnips: 0 }`, `day: 1`, and `selectedAction: 'hoe'`.

### Complete snapshot

`GameSnapshot` extends the existing `WorldSnapshot` with farming fields. `GameSession.snapshot()` returns a fresh `GameSnapshot` containing:

- the `ProofWorld` player and target snapshot;
- `day`;
- `selectedAction`;
- inventory stacks;
- all nine farm tiles in deterministic row-major order; and
- the logical bed-interaction position.

The snapshot contains no Phaser objects, textures, screen coordinates, camera state, Svelte state, functions, `Map`, or `Set`. `JSON.stringify` followed by `JSON.parse` must preserve its complete value.

Screen-space debug information such as projected player position, render depths, and camera bounds remains the existing separate `DebugSnapshot` assembled by `ProofScene`; it is not part of authoritative save-shaped state and its current field shape remains backward-compatible.

## Command rules

Commands return a discriminated result with a stable code:

```ts
type CommandResult =
  | { ok: true; code: SuccessCode }
  | { ok: false; code: FailureCode };
```

The presentation layer maps codes to concise player-facing text. Expected invalid actions do not throw.

Success codes are `action-selected`, `soil-tilled`, `turnip-planted`, `crop-watered`, `turnip-harvested`, and `day-advanced`. Failure codes are `no-target`, `not-farm-cell`, `already-tilled`, `soil-untilled`, `crop-present`, `no-turnip-seeds`, `no-crop`, `already-watered`, `crop-mature`, `crop-immature`, and `not-at-bed`.

Every farming command accepts `GridCell | null` and applies the same validation prefix before command-specific rules:

1. `null` returns `no-target`.
2. A non-farm cell returns `not-farm-cell`.
3. The command then applies its ordered checks below.

This order is part of the public command contract and determines the exact code when more than one invalid condition is true.

### Select action

`selectAction(action)` stores the supplied valid `FarmingAction` and always returns `{ ok: true, code: 'action-selected' }`. Its `CommandResult` return type is intentionally uniform with the two-method scene facade even though the typed input leaves no reachable failure branch; no invalid-action failure code is added. Device-specific key mapping and button events remain outside the domain.

### Apply selected action

`applySelectedAction(position)` delegates inside `GameSession` according to the authoritative `selectedAction`: Hoe to `hoe`, Seeds to `plant`, Water to `water`, and Hands to `harvest`. It returns the delegated result unchanged. This is the only selected-action dispatch switch. The switch is exhaustive and routes its impossible default through a `never`-typed assertion that throws, so adding a fifth `FarmingAction` cannot silently no-op.

### Hoe

After the shared prefix, `hoe(position)` checks `crop-present` before `already-tilled`. It succeeds only when the tile has no crop and its soil is untilled, changing only that tile's soil to tilled.

Hoeing outside the farm, hoeing an already tilled cell, or hoeing a cell with a crop fails without mutation.

### Plant

After the shared prefix, `plant(position)` checks `soil-untilled`, then `crop-present`, then `no-turnip-seeds`. It succeeds only when the soil is tilled, the crop is null, and at least one turnip seed is available. It creates a level-0 unwatered turnip and consumes exactly one seed.

Every prerequisite is validated before either the tile or inventory changes. Failed planting never consumes a seed.

### Water

After the shared prefix, `water(position)` checks `no-crop`, then `crop-mature`, then `already-watered`. It succeeds only when the position contains a non-mature turnip that has not already been watered that day. It sets `wateredToday` to true.

Watering empty soil, a mature crop, an already-watered crop, or a non-farm position fails without mutation.

### Harvest

After the shared prefix, `harvest(position)` checks `no-crop`, then `crop-immature`. It succeeds only when the position contains a growth-level-3 turnip. It removes the crop, leaves the soil tilled, and adds exactly one harvested turnip to inventory.

Harvesting an empty, immature, or non-farm position fails without mutation.

### Sleep

The scene may request the Svelte sleep confirmation only when the current session target equals the authored bed-interaction cell. E at the bed calls `onSleepPrompt`; it does not advance the day. E away from the bed invokes `sleep()` only to obtain the domain-owned `not-at-bed` result and publishes that failure without opening the panel. Confirming invokes `sleep()` exactly once.

`sleep()` first re-reads the current `ProofWorld` target. If it does not equal the bed cell, it returns `not-at-bed` without mutation. If it matches, `sleep()` returns `day-advanced` and performs one direct day transition:

1. Increment the day by one.
2. Advance every turnip with `wateredToday === true` by exactly one level, capped at level 3.
3. Leave every unwatered turnip at its current level.
4. Reset `wateredToday` to false for every crop exactly once.

There is no time-of-day, stamina, weather, bedtime restriction, overnight economy, or autosave in this transition.

## Input and interaction flow

### Keyboard controls

The controls are:

| Input | Action |
| --- | --- |
| WASD | Move in screen-relative directions |
| 1 | Select Hoe |
| 2 | Select Seeds |
| 3 | Select Water |
| 4 | Select Hands |
| Space | Apply the selected action to the highlighted farm cell |
| E | Request sleep while the bed interaction is highlighted |

Action keys are edge-triggered. Holding Space or E cannot repeat a command across frames. Movement and action input use separate sampling controllers but share one small Phaser-layer `GateBoundKeys` lifecycle helper. That helper owns the `InputGate` subscription, initial-lock reset, reset-on-lock behavior, idempotent unsubscribe, and plugin-aware key destruction currently implemented by `KeyboardController`. `KeyboardController` keeps analog WASD sampling; its action sibling adds only edge sampling for 1–4, Space, and E. There is one teardown implementation for remount and HMR to exercise.

Space reads the target from the same session snapshot used to draw the diamond and passes it unchanged to `GameSession.applySelectedAction()`. If the target is null or not a farm cell, the domain returns the ordered failure code.

### HUD selection

The HUD provides four buttons matching keys 1 through 4. Clicking a button invokes the scene's narrow `selectAction` command facade. The subsequent session snapshot is the only source used to show which button is selected.

### Sleep confirmation and input locking

Pressing E while the bed interaction is targeted calls the explicit `onSleepPrompt` scene dependency. Svelte then opens a panel reading “Sleep until tomorrow?” with Confirm and Cancel buttons. Phaser does not mutate Svelte state.

Opening the panel sets `InputGate` reason `sleep-confirmation`. Both movement and action controllers clear held state and report no world input while the gate is locked. Confirm calls the scene's `sleep` command once, closes the panel, and releases the reason. Cancel closes the panel and releases the reason without changing session state. Component teardown also releases the reason.

Pressing E away from the bed does not open the panel. The scene publishes the `not-at-bed` result returned by the domain's guarded `sleep()` command.

The existing demonstration lock is retained with reason `overlay` and button names “Lock world input” and “Unlock world input,” because the foundation lifecycle acceptance test uses that exact player-facing contract. Its layout may be compacted inside the expanded overlay, but it is not optional.

## Map and asset contract

The map remains a `12×12`, `64×32`, one-elevation isometric proof map. Its existing nine farm cells remain the only actionable soil positions.

The Markers layer gains one point object with ID 6 and name `bed-interaction`. Its logical cell center `{ x: 6.5, y: 8.5 }` projects to the authored Tiled world position `{ x: 320, y: 240 }`; the parser converts that point with `ProjectionAdapter.gridCellAtWorld()` to logical `GridCell { x: 6, y: 8 }`. That cell sits immediately beside the existing farmhouse's left footprint edge and is targetable from the walkable cell `{ x: 5, y: 9 }`.

Adding object ID 6 changes `tools/generate-proof-assets.ts`, committed `proof-map.json`, `validateMapHeader`, and `tests/game/loadProofMap.test.ts` atomically from `nextobjectid: 6` to `nextobjectid: 7`. None of those four files lands independently. The parser accepts only the exact marker names `player-spawn` and `bed-interaction` and rejects unknown marker objects instead of ignoring them. It validates:

- exactly one bed-interaction marker;
- exact conversion to logical cell `{ x: 6, y: 8 }`; and
- continued presence and uniqueness of the player spawn.

Farm-count, duplicate-farm, bed/farm-overlap, and bed/collision-overlap invariants belong to the pure `GameSession` constructor rather than permanently unreachable parser branches around one exact generated cell.

The deterministic asset generator adds two regular-frame spritesheets:

- `proof-soil.png`, exactly `128×32`, with two `64×32` frames for dry tilled and wet tilled soil; and
- `proof-turnip.png`, exactly `128×48`, with four `32×48` frames for growth levels 0 through 3.

The map JSON and generated PNG assets remain committed. Re-running the generator twice must produce identical bytes and no git diff.

## Rendering and depth

The existing brown farm ground diamonds are the untilled appearance. Phaser adds a dynamic 64×32 soil sprite only for tilled cells. A watered crop uses the wet-soil frame beneath it; tilled empty soil and unwatered planted soil use the dry-tilled frame.

Each planted crop has one bottom-centered sprite positioned at the projected logical center `{ x: cell.x + 0.5, y: cell.y + 0.5 }`, which is the crop's ground-contact footpoint. Its texture frame is selected only from `growth` in the session snapshot. Soil sprites use the same projected logical center with a centered origin.

Soil overlays occupy a fixed band immediately above ground depth 0 and below target depth 10 and the entity band. Crops join the existing footpoint depth ordering with the player, tree, and building. Player, tree, and building retain stable-order keys 0, 1, and 2. Crop keys use the reserved non-overlapping band `100 + rowMajorIndex`, where the existing row-major farm order supplies indices 0 through 8. This guarantees that equal ground-Y entries never share a stable-order key.

A small pure core mapper converts one `FarmTileSnapshot` into `{ soilFrame: null | 0 | 1, cropFrame: null | 0 | 1 | 2 | 3 }`. Phaser uses that result to select frames instead of embedding dry/wet/growth branching only in `ProofScene`. Unit tests cover every tile-state mapping.

`ProofScene` keeps render objects in keyed maps and creates, updates, or removes farm objects after creation and each command to match the latest game snapshot. Movement-only frames update player/target rendering and all entity depths without republishing or rebuilding unchanged farm sprites. Clearing all farm render objects and reconciling a fresh snapshot must reproduce the same soil and crop visuals; no hidden Phaser-only farming state is allowed.

The target outline remains the existing projected `64×32` diamond. The exact `GridCell` used to render it is the position passed to the farming command.

## HUD and feedback

The fitted `640×360` stage gains a compact farming HUD without changing the shared stage scaling contract. It shows:

- Day number;
- selected action;
- turnip-seed count;
- harvested-turnip count;
- keys 1–4 and Space;
- the latest success or failure message; and
- the sleep confirmation panel when requested.

Command results map to clear messages such as “Soil tilled,” “Turnip planted,” “Crop watered,” “Turnip harvested,” “That soil is already tilled,” or “This turnip is not ready.” Feedback remains until another farming or sleep interaction replaces it. Feedback is presentation state and is excluded from the authoritative snapshot.

The HUD stays read-only except for explicit action-selection and sleep-confirmation controls. It never increments inventory, advances the day, or edits a farm tile itself.

## Failure behavior

Expected gameplay mistakes return `ok: false` and a stable failure code. Each command validates all prerequisites before mutation, so rejected transitions leave the complete authoritative snapshot unchanged.

Malformed map metadata, missing required map markers, invalid farm positions, or asset-load failures remain fatal scene-startup errors. The existing Svelte fatal-error state reports the descriptive error and offers a normal page reload.

Scene or Svelte teardown destroys Phaser objects, keyboard handlers, action handlers, and command facades and clears all `InputGate` reasons owned by the component. Remount and HMR must still result in one canvas and one set of input handlers.

## Verification strategy

### Pure TypeScript tests

The existing `bun test` suite provides the unit coverage. It must prove:

- the exact constructor boundary, defensive cloning, nine-cell count, duplicate-cell rejection, and bed overlap invariants;
- new-game day, `hoe` selection, farm, and inventory defaults;
- each successful command and its exact result code;
- selected-action dispatch for all four actions without a Phaser-side rule switch;
- shared `no-target` and `not-farm-cell` precedence plus every command-specific failure-order overlap;
- every invalid-state rejection with a snapshot-equality assertion;
- planting consumes exactly one seed;
- failed planting consumes no seed;
- harvesting adds exactly one turnip and preserves tilled soil;
- one, two, and three watered sleeps produce growth levels 1, 2, and 3;
- an unwatered sleep does not advance growth;
- sleeping away from the bed returns `not-at-bed` without mutation;
- sleep increments the day once and resets watering once;
- mature crops do not grow beyond level 3;
- returned snapshots are fresh values;
- deterministic farm-tile ordering; and
- JSON stringify/parse round-trip equality.

Existing `ProofWorld`, collision, projection, lifecycle, and input tests remain green.

### Map and render integration tests

Focused tests must prove:

- the parser returns the exact nine farm positions and one bed position through `ParsedProofMap` while leaving `ProofMap` unchanged;
- the marker header uses `nextobjectid: 7`, spawn ID 5, and bed ID 6;
- unknown marker names are rejected;
- missing, duplicate, wrong-cell, or unknown-name markers are rejected;
- generated farming PNG dimensions and frame count are exact;
- farming assets regenerate deterministically;
- every snapshot tile maps through the pure visual mapper to the expected soil and crop frame;
- crop stable ordering uses exact keys 100 through 108; and
- the rendered target position equals the command position.

### Browser acceptance

Playwright uses real movement, number keys, Space, E, and confirmation buttons to:

1. reach and target a farm cell;
2. observe a rejected action without partial state change;
3. hoe, plant, and water one turnip;
4. confirm sleep and observe one growth step and one day increment;
5. repeat watering and sleeping until the third growth step is mature;
6. harvest with Hands; and
7. observe seed and turnip inventory counts in the HUD.

Additional acceptance checks cover clickable action selection, sleep-panel input locking, target-to-command identity, visible dry/wet/growth frames, remount/HMR lifecycle behavior, and the unchanged foundation movement, collision, depth, map-edge, camera, and stage-scaling contracts.

One crop-depth acceptance test plants a turnip and moves the player across its projected footpoint, asserting that the player/crop depth relation reverses in both directions. It follows the existing tree/building depth-test pattern rather than asserting absolute Phaser depth values.

The development hook keeps `snapshot(): DebugSnapshot` unchanged so all foundation helpers and E2E field paths remain valid. It additively exposes `gameSnapshot(): GameSnapshot`, updated on creation and after each command, for stable immutable domain assertions. Movement routes continue to use the existing debug snapshot and helpers; farming assertions use `gameSnapshot()` after real keyboard or button actions. The hook must not expose hoe, plant, water, sleep, harvest, selection, or confirmation commands.

### Final macOS gate

The final verification matrix runs:

- deterministic asset generation;
- Svelte and TypeScript static checks;
- all unit tests;
- all browser acceptance tests;
- the production frontend build;
- Cargo check; and
- the Tauri macOS application and DMG build.

A focused native smoke launches the built Tauri application and confirms that the shared farming interaction path responds inside the native window. Browser acceptance remains the exhaustive deterministic proof for the identical frontend. Any native interactions that cannot be safely or reliably observed are reported as evidence gaps rather than overstated.

## Delivery boundary

HPA-591 is complete when the normal player controls can carry one turnip through untilled, tilled, planted, watered, three growth transitions, mature, and harvested states; `GameSession.snapshot()` returns a fresh, fully JSON-round-trippable value containing no live references; browser and macOS build verification is green; and the HPA-588 foundation behavior remains intact.

HPA-592, not this slice, will extend the direct sleep transition with action-driven time, stamina, weather, and the full repeatable daily rhythm.
