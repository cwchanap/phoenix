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

`GameSession` exposes direct commands for selection, hoeing, planting, watering, harvesting, and sleeping. It returns fresh JSON-serializable snapshots and never imports Phaser or Svelte.

`ProofWorld` remains a focused movement unit. `GameSession.stepMovement()` delegates to it and includes the resulting player and target state in the complete game snapshot. Collision, projection, facing, and target-offset behavior therefore keep their existing tested contracts.

### Phaser

`ProofScene` parses the map, constructs the `GameSession`, samples movement and action keys, invokes session commands, and reconciles visible Phaser objects from session snapshots. Phaser owns asset loading, sprites, graphics, camera follow, keyboard integration, and render-object lifecycles. It does not implement farming rules.

The scene publishes snapshots, command results, and a narrow UI command facade through explicit dependencies. The facade supports only the Svelte-owned interactions that must enter the domain: selecting an action and confirming sleep. It does not expose the session object or create a generic message bus.

### Svelte

Svelte owns the fitted stage, HUD, action-selection buttons, sleep-confirmation panel, feedback text, lifecycle status, and fatal-error presentation. It displays values from the latest immutable session snapshot and does not maintain a second inventory, day counter, farm model, or selected-action authority.

`App.svelte` owns presentation-only state: the latest snapshot reference, the latest command result, whether the sleep panel is open, and the current scene command facade. `GameHost.svelte` continues to own Phaser creation and teardown and forwards those values through explicit callbacks.

### Tauri and Rust

Tauri continues to provide only the desktop window and local application shell. Rust gains no gameplay state or farming logic. Browser development and Tauri load the same frontend code and assets.

## Domain model

### Coordinates and farm identity

`GridPosition` is an integer logical coordinate with `x` and `y`. It is structurally compatible with the foundation's `GridCell`; implementation may consolidate the names if one exported type can serve both contracts without ambiguity.

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
  position: GridPosition;
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

A new game starts with `{ turnipSeeds: 3, turnips: 0 }` and `day: 1`.

### Complete snapshot

`GameSession.snapshot()` returns fresh plain objects containing:

- the `ProofWorld` player and target snapshot;
- `day`;
- `selectedAction`;
- inventory stacks;
- all nine farm tiles in deterministic row-major order; and
- the logical bed-interaction position.

The snapshot contains no Phaser objects, textures, screen coordinates, camera state, Svelte state, functions, `Map`, or `Set`. `JSON.stringify` followed by `JSON.parse` must preserve its complete value.

Screen-space debug information such as projected player position, render depths, and camera bounds remains a separate development snapshot assembled by `ProofScene`; it is not part of authoritative save-shaped state.

## Command rules

Commands return a discriminated result with a stable code:

```ts
type CommandResult =
  | { ok: true; code: SuccessCode }
  | { ok: false; code: FailureCode };
```

The presentation layer maps codes to concise player-facing text. Expected invalid actions do not throw.

Success codes are `action-selected`, `soil-tilled`, `turnip-planted`, `crop-watered`, `turnip-harvested`, and `day-advanced`. Failure codes are `no-target`, `not-farm-cell`, `already-tilled`, `soil-untilled`, `crop-present`, `no-turnip-seeds`, `no-crop`, `already-watered`, `crop-mature`, `crop-immature`, and `not-at-bed`.

### Select action

`selectAction(action)` stores the supplied valid `FarmingAction` and succeeds. Device-specific key mapping and button events remain outside the domain.

### Hoe

`hoe(position)` succeeds only when `position` is an authored farm cell whose soil is untilled and whose crop is null. It changes only that tile's soil to tilled.

Hoeing outside the farm, hoeing an already tilled cell, or hoeing a cell with a crop fails without mutation.

### Plant

`plant(position)` succeeds only when the position is an authored farm cell, the soil is tilled, the crop is null, and at least one turnip seed is available. It creates a level-0 unwatered turnip and consumes exactly one seed.

Every prerequisite is validated before either the tile or inventory changes. Failed planting never consumes a seed.

### Water

`water(position)` succeeds only when the position contains a non-mature turnip that has not already been watered that day. It sets `wateredToday` to true.

Watering empty soil, a mature crop, an already-watered crop, or a non-farm position fails without mutation.

### Harvest

`harvest(position)` succeeds only when the position contains a growth-level-3 turnip. It removes the crop, leaves the soil tilled, and adds exactly one harvested turnip to inventory.

Harvesting an empty, immature, or non-farm position fails without mutation.

### Sleep

The presentation may open sleep confirmation only when the current target equals the authored bed-interaction position. Confirming invokes `sleep()` exactly once.

`sleep()` performs one direct day transition:

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

Action keys are edge-triggered. Holding Space or E cannot repeat a command across frames. A Phaser-specific action controller owns these keys and resets their held state whenever `InputGate` becomes locked.

Space reads the target from the same session snapshot used to draw the diamond, then dispatches to `hoe`, `plant`, `water`, or `harvest` according to `selectedAction`. If the target is null or not a farm cell, the command returns the appropriate failure code.

### HUD selection

The HUD provides four buttons matching keys 1 through 4. Clicking a button invokes the scene's narrow `selectAction` command facade. The subsequent session snapshot is the only source used to show which button is selected.

### Sleep confirmation and input locking

Pressing E while the bed interaction is targeted asks Svelte to open a panel reading “Sleep until tomorrow?” The panel has Confirm and Cancel buttons.

Opening the panel sets `InputGate` reason `sleep-confirmation`. Both movement and action controllers clear held state and report no world input while the gate is locked. Confirm calls the scene's `sleep` command once, closes the panel, and releases the reason. Cancel closes the panel and releases the reason without changing session state. Component teardown also releases the reason.

Pressing E away from the bed does not open the panel and produces failure feedback.

The existing demonstration lock remains available only if it still serves foundation acceptance without crowding the farming HUD. It may be relabeled or moved, but aggregate lock behavior and its browser coverage must remain intact.

## Map and asset contract

The map remains a `12×12`, `64×32`, one-elevation isometric proof map. Its existing nine farm cells remain the only actionable soil positions.

The Markers layer gains exactly one named bed-interaction marker at logical cell `{ x: 6, y: 8 }`, immediately beside the existing farmhouse's left footprint edge and reachable from the walkable cell `{ x: 5, y: 9 }`. The parser validates:

- exactly one bed-interaction marker;
- integer logical coordinates;
- in-bounds placement;
- placement outside collision footprints;
- placement outside the nine farm cells; and
- continued presence and uniqueness of the player spawn.

The deterministic asset generator adds two regular-frame spritesheets:

- `proof-soil.png`, exactly `128×32`, with two `64×32` frames for dry tilled and wet tilled soil; and
- `proof-turnip.png`, exactly `128×48`, with four `32×48` frames for growth levels 0 through 3.

The map JSON and generated PNG assets remain committed. Re-running the generator twice must produce identical bytes and no git diff.

## Rendering and depth

The existing brown farm ground diamonds are the untilled appearance. Phaser adds a dynamic 64×32 soil sprite only for tilled cells. A watered crop uses the wet-soil frame beneath it; tilled empty soil and unwatered planted soil use the dry-tilled frame.

Each planted crop has one bottom-centered sprite positioned at the projected logical center `{ x: cell.x + 0.5, y: cell.y + 0.5 }`, which is the crop's ground-contact footpoint. Its texture frame is selected only from `growth` in the session snapshot. Soil sprites use the same projected logical center with a centered origin.

Soil overlays occupy a fixed band immediately above the ground layer and below the target diamond and entities. Crops join the existing footpoint depth ordering with the player, tree, and building. Crop stable-order keys derive deterministically from row-major farm position, so exact depth ties cannot flicker.

`ProofScene` keeps render objects in keyed maps, creates or removes them to match the latest snapshot, and updates every frame and depth from snapshot data. Clearing all farm render objects and reconciling a fresh snapshot must reproduce the same soil and crop visuals; no hidden Phaser-only farming state is allowed.

The target outline remains the existing projected `64×32` diamond. The exact `GridPosition` used to render it is the position passed to the farming command.

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

- new-game day, selection, farm, and inventory defaults;
- each successful command and its exact result code;
- every invalid-state rejection with a snapshot-equality assertion;
- planting consumes exactly one seed;
- failed planting consumes no seed;
- harvesting adds exactly one turnip and preserves tilled soil;
- one, two, and three watered sleeps produce growth levels 1, 2, and 3;
- an unwatered sleep does not advance growth;
- sleep increments the day once and resets watering once;
- mature crops do not grow beyond level 3;
- returned snapshots are fresh values;
- deterministic farm-tile ordering; and
- JSON stringify/parse round-trip equality.

Existing `ProofWorld`, collision, projection, lifecycle, and input tests remain green.

### Map and render integration tests

Focused tests must prove:

- the parser returns the exact nine farm positions and one bed position;
- malformed, duplicate, colliding, out-of-bounds, or farm-overlapping bed markers are rejected;
- generated farming PNG dimensions and frame count are exact;
- farming assets regenerate deterministically;
- every snapshot tile maps to the expected soil and crop frame;
- crop stable ordering follows row-major position; and
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

The test hook may return immutable snapshots for assertions. It must not expose hoe, plant, water, sleep, or harvest commands.

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

HPA-591 is complete when the normal player controls can carry one turnip through untilled, tilled, planted, watered, three growth transitions, mature, and harvested states; all authoritative state is rebuildable from a serializable snapshot; browser and macOS build verification is green; and the HPA-588 foundation behavior remains intact.

HPA-592, not this slice, will extend the direct sleep transition with action-driven time, stamina, weather, and the full repeatable daily rhythm.
