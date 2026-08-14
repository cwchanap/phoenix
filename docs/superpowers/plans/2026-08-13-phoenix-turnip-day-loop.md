# Phoenix Turnip Day Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver HPA-591 as one complete, playable turnip loop: start Day 1 with three seeds, hoe and plant an authored farm cell, water and sleep through three day transitions, harvest one mature turnip, and observe the same behavior in browser development and the macOS Tauri app.

**Architecture:** A framework-free `GameSession` composes the existing `ProofWorld` and owns all farming, inventory, selected-action, and day-transition state. Phaser adapts keyboard input and reconciles sprites from immutable snapshots; Svelte owns the HUD, feedback, and sleep-confirmation presentation; Tauri remains an unchanged desktop shell.

**Tech Stack:** Bun 1.3.1 and `bun:test`, TypeScript 7.0.2 through `@typescript/native` with TypeScript 6.0.3 for `svelte-check --tsgo`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11, Rust/Cargo 1.96, deterministic PNG generation, and Tiled 1.12-compatible JSON.

## Global Constraints

- Implement only HPA-591. Do not add other crops, money, shops, shipping, stamina, weather, relationships, dialogue, tutorial state, saves, generic event buses, plugin systems, or a generalized domain framework.
- Preserve the HPA-588 ownership split: pure TypeScript owns gameplay, `ProofWorld` owns movement/facing/collision/targeting, Phaser owns rendering and device adaptation, Svelte owns presentation, and Rust/Tauri remains a shell.
- Reuse `GridCell`, `GridPoint`, `ProjectionMetrics`, `ProofMap`, `WorldSnapshot`, `InputGate`, `intersects`, projection/depth helpers, the existing asset generator, and the current Playwright movement helpers.
- Keep `ProofMap` unchanged. Add `bedCell` only to `ParsedProofMap` and `GameSnapshot`.
- Use Bun as the only JavaScript package manager and `bun:test` as the only unit runner. Do not add Vitest or any dependency.
- Treat expected gameplay failures as immutable `CommandResult` values. Reserve thrown errors for invalid construction/configuration and impossible exhaustive-switch states.
- Preserve the existing `window.__PHOENIX_TEST__.snapshot()` debug contract and its existing player, target, camera, and `player`/`tree`/`building` depth keys. Add `gameSnapshot()` for authoritative state and only additive crop keys inside the existing debug `depths` record.
- Preserve the exact foundation buttons “Lock world input” and “Unlock world input” and the `overlay` gate reason.
- Use gate reason `sleep-confirmation` for the new modal. Every close, error, remount, and component teardown path must release it.
- Publish a game snapshot after every selection, farming, and sleep result, including failures; do not publish it every movement frame.
- Keep all farm arrays in the authored row-major order. Return fresh, JSON-serializable snapshots with no `Map`, `Set`, class instance, function, Phaser object, or Svelte state.
- Make the map header, bed marker, parser assertions, generated JSON, generated PNGs, and tests one atomic task and commit.
- Run tests RED before production edits, then focused GREEN, full unit/static checks, and a task-scoped review before each commit.
- For Svelte edits, load `svelte:svelte-code-writer` and `svelte:svelte-core-bestpractices`, run the available local Svelte analysis/autofix workflow if it can execute without external source egress, and always finish with `rtk bun run check`.
- Browser acceptance must use real keys and buttons. Test hooks may observe state but must not invoke farming commands.
- macOS is the only native verification boundary. Do not claim Windows/Linux, signing, notarization, or unobserved native interactions.

## File Map

### Framework-free domain

- Modify: `src/game/core/types.ts`
- Create: `src/game/core/GameSession.ts`
- Create: `src/game/core/farmVisuals.ts`
- Test: `tests/game/GameSession.test.ts`
- Test: `tests/game/farmVisuals.test.ts`

### Authored map and deterministic assets

- Modify: `tools/generate-proof-assets.ts`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `src/assets/maps/proof-map.json`
- Create: `src/assets/sprites/proof-soil.png`
- Create: `src/assets/sprites/proof-turnip.png`
- Modify: `tests/game/loadProofMap.test.ts`

### Phaser input and rendering

- Create: `src/game/phaser/GateBoundKeys.ts`
- Create: `src/game/phaser/ActionController.ts`
- Modify: `src/game/phaser/KeyboardController.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `tests/game/KeyboardController.test.ts`
- Create: `tests/game/GateBoundKeys.test.ts`
- Create: `tests/game/ActionController.test.ts`

### Svelte bridge and presentation

- Modify: `src/components/GameHost.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/App.svelte`
- Modify: `src/app.css`
- Modify: `src/vite-env.d.ts`
- Modify: `README.md`

### Browser and delivery verification

- Modify: `tests/e2e/helpers.ts`
- Create: `tests/e2e/farming.pw.ts`
- Preserve and rerun: `tests/e2e/lifecycle.pw.ts`
- Preserve and rerun: `tests/e2e/world.pw.ts`

---

### Task 1: Authoritative `GameSession` Farming Rules

**Files:**

- Modify: `src/game/core/types.ts`
- Create: `src/game/core/GameSession.ts`
- Create: `tests/game/GameSession.test.ts`

**Interfaces:**

- Consumes: `ProofWorld`, `GridCell`, `ProjectionMetrics`, `ProofMap`, `WorldSnapshot`, and `intersects`.
- Produces: `FarmingAction`, farm/crop/inventory snapshots, `GameSnapshot`, stable success/failure codes, `CommandResult`, `GameSessionConfig`, and `GameSession`.
- Preserves: `ProofWorld` public behavior and `ProofMap` shape.

- [ ] **Step 1: Add failing type-and-default-state tests**

Create a fixture whose bed is reachable but does not overlap a collision footprint. Assert a fresh session starts on Day 1, defaults to Hoe, owns exactly three seeds, has zero turnips, and exposes nine fresh row-major tiles.

```ts
// tests/game/GameSession.test.ts
import { describe, expect, test } from 'bun:test';
import { GameSession, type GameSessionConfig } from '../../src/game/core/GameSession';

const farmCells = [
  { x: 2, y: 7 }, { x: 3, y: 7 }, { x: 4, y: 7 },
  { x: 2, y: 8 }, { x: 3, y: 8 }, { x: 4, y: 8 },
  { x: 2, y: 9 }, { x: 3, y: 9 }, { x: 4, y: 9 },
];

function config(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 5.5, y: 9.5 },
      footprints: [
        { id: 'tree', x: 7, y: 4, width: 1, height: 1 },
        { id: 'building', x: 7, y: 7, width: 3, height: 2 },
      ],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells,
    bedCell: { x: 6, y: 8 },
    ...overrides,
  };
}

test('starts a fresh Day 1 turnip session', () => {
  const session = new GameSession(config());
  const first = session.snapshot();
  const second = session.snapshot();

  expect(first.day).toBe(1);
  expect(first.selectedAction).toBe('hoe');
  expect(first.inventory).toEqual({ turnipSeeds: 3, turnips: 0 });
  expect(first.farmTiles.map((tile) => tile.position)).toEqual(farmCells);
  expect(first.farmTiles.every((tile) => tile.soil === 'untilled' && tile.crop === null)).toBe(true);
  expect(first.bedCell).toEqual({ x: 6, y: 8 });
  expect(second).toEqual(first);
  expect(second).not.toBe(first);
  expect(second.farmTiles).not.toBe(first.farmTiles);
  expect(second.inventory).not.toBe(first.inventory);
});
```

- [ ] **Step 2: Add the full three-watered-night lifecycle test before implementation**

Use one farm cell and assert every mutation boundary, including the fact that planting starts at growth 0, sleep advances only watered crops, watering resets once per day, the third watered sleep produces growth 3, and harvest preserves tilled soil.

```ts
test('grows and harvests one turnip after three watered nights', () => {
  const session = new GameSession(config());
  const cell = farmCells[0];

  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'turnip-planted' });
  expect(session.snapshot().inventory.turnipSeeds).toBe(2);

  for (const growth of [1, 2, 3] as const) {
    expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    session.stepMovement({ screenX: 1, screenY: 0 }, 0);
    expect(session.snapshot().target).toEqual({ x: 6, y: 8 });
    expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
    expect(session.snapshot().farmTiles[0].crop).toEqual({
      kind: 'turnip',
      growth,
      wateredToday: false,
    });
  }

  expect(session.snapshot().day).toBe(4);
  expect(session.harvest(cell)).toEqual({ ok: true, code: 'turnip-harvested' });
  expect(session.snapshot().farmTiles[0]).toEqual({
    position: cell,
    soil: 'tilled',
    crop: null,
  });
  expect(session.snapshot().inventory).toEqual({ turnipSeeds: 2, turnips: 1 });
});
```

- [ ] **Step 3: Add table-driven rejection, precedence, and no-mutation tests**

Cover the shared `null -> no-target` and non-farm -> `not-farm-cell` prefix for Hoe, Plant, Water, and Harvest. Then cover exact command order:

- Hoe: `crop-present` before `already-tilled`.
- Plant: `soil-untilled`, then `crop-present`, then `no-turnip-seeds`.
- Water: `no-crop`, then `crop-mature`, then `already-watered`.
- Harvest: `no-crop`, then `crop-immature`.
- Sleep: `not-at-bed` before any day/crop mutation.

Capture `before = session.snapshot()`, run each rejected command, and assert `session.snapshot()` deeply equals `before`. Consume all three seeds on three different prepared cells to reach `no-turnip-seeds` without a test-only setter. Grow a crop normally to reach `crop-mature`.

Add a separate day-transition test with one watered and one unwatered crop. Prove one sleep grows only the watered crop, resets both watering flags, and increments the day exactly once. After reaching growth 3, sleep once more without watering and prove growth remains capped at 3 while the day still increments once.

- [ ] **Step 4: Add selection-dispatch and JSON round-trip tests**

Assert all four `selectAction` values return `action-selected`. For each selected action, call only `applySelectedAction(cell)` and prove it delegates to the matching rule. Serialize a nontrivial snapshot and assert `JSON.parse(JSON.stringify(snapshot))` equals the original snapshot.

- [ ] **Step 5: Add constructor invariant tests**

Assert construction throws for eight or ten farm cells, duplicate farm cells, a bed cell equal to a farm cell, and a bed unit rectangle that overlaps a footprint. Also prove edge-touching does not throw, matching the existing `intersects` contract. Mutate the caller-owned `farmCells`, `bedCell`, and nested world values after construction and prove the session snapshot is unchanged.

- [ ] **Step 6: Run the focused test and observe RED**

Run: `rtk bun test tests/game/GameSession.test.ts`

Expected: FAIL because `GameSession` and the new farming types do not exist.

- [ ] **Step 7: Add the serializable domain types**

Add these exact exported contracts to `src/game/core/types.ts`:

```ts
export type FarmingAction = 'hoe' | 'turnipSeeds' | 'wateringCan' | 'hands';
export type GrowthLevel = 0 | 1 | 2 | 3;

export interface TurnipCropSnapshot {
  kind: 'turnip';
  growth: GrowthLevel;
  wateredToday: boolean;
}

export interface FarmTileSnapshot {
  position: GridCell;
  soil: 'untilled' | 'tilled';
  crop: TurnipCropSnapshot | null;
}

export interface InventorySnapshot {
  turnipSeeds: number;
  turnips: number;
}

export interface GameSnapshot extends WorldSnapshot {
  day: number;
  selectedAction: FarmingAction;
  inventory: InventorySnapshot;
  farmTiles: FarmTileSnapshot[];
  bedCell: GridCell;
}

export type SuccessCode =
  | 'action-selected'
  | 'soil-tilled'
  | 'turnip-planted'
  | 'crop-watered'
  | 'turnip-harvested'
  | 'day-advanced';

export type FailureCode =
  | 'no-target'
  | 'not-farm-cell'
  | 'already-tilled'
  | 'soil-untilled'
  | 'crop-present'
  | 'no-turnip-seeds'
  | 'no-crop'
  | 'already-watered'
  | 'crop-mature'
  | 'crop-immature'
  | 'not-at-bed';

export type CommandResult =
  | { ok: true; code: SuccessCode }
  | { ok: false; code: FailureCode };
```

- [ ] **Step 8: Implement `GameSession` with one selected-action switch**

Use a private mutable tile shape internally, indexed by the stable `"x,y"` key, while keeping the row-major array as the only snapshot order. Clone `world`, `metrics`, `farmCells`, and `bedCell` before constructing `ProofWorld` or storing values.

Keep all mutable state private and expose exactly these public members: `constructor(config: GameSessionConfig)`, `stepMovement(input, deltaMs)`, `snapshot()`, `selectAction(action)`, `applySelectedAction(position)`, `hoe(position)`, `plant(position)`, `water(position)`, `harvest(position)`, and `sleep()`.

```ts
export interface GameSessionConfig {
  world: ProofMap;
  metrics: ProjectionMetrics;
  farmCells: GridCell[];
  bedCell: GridCell;
}
```

Use this complete dispatch method inside `GameSession`; it is the only selected-action switch:

```ts
applySelectedAction(position: GridCell | null): CommandResult {
  switch (this.selectedAction) {
    case 'hoe': return this.hoe(position);
    case 'turnipSeeds': return this.plant(position);
    case 'wateringCan': return this.water(position);
    case 'hands': return this.harvest(position);
    default: return assertNever(this.selectedAction);
  }
}

function assertNever(value: never): never {
  throw new Error(`Unsupported farming action: ${String(value)}`);
}
```

Implement the shared target lookup once so every command gets identical prefix behavior. Validate all prerequisites before mutating tile or inventory. `sleep()` must re-read `this.world.snapshot().target`, increment the day, grow only watered crops by one with a cap of 3, then clear every crop's `wateredToday` exactly once.

Validate footprint overlap through the existing geometry function, including an ID because `intersects` consumes `Footprint` values:

```ts
const bedFootprint: Footprint = {
  id: 'bed-interaction',
  x: bedCell.x,
  y: bedCell.y,
  width: 1,
  height: 1,
};
if (world.footprints.some((footprint) => intersects(bedFootprint, footprint))) {
  throw new Error('GameSession: bed cell overlaps a collision footprint');
}
```

- [ ] **Step 9: Run focused and full framework-free verification**

Run:

- `rtk bun test tests/game/GameSession.test.ts`
- `rtk bun test tests/game/ProofWorld.test.ts tests/game/GameSession.test.ts`
- `rtk bun run check`

Expected: all pass with zero static diagnostics.

- [ ] **Step 10: Review and commit Task 1**

Review for command precedence, accidental shared references, framework imports, unreachable failure codes, and any second selected-action switch. Run `rtk rg -n "switch.*selectedAction|case 'turnipSeeds'" src` and confirm the only domain dispatch switch is in `GameSession`.

Commit:

```bash
rtk git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts
rtk git commit -m "feat: add authoritative farming session"
```

---

### Task 2: Atomic Bed Marker, Parser Contract, and Farming Assets

**Files:**

- Modify: `tools/generate-proof-assets.ts`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `src/assets/maps/proof-map.json`
- Create: `src/assets/sprites/proof-soil.png`
- Create: `src/assets/sprites/proof-turnip.png`
- Modify: `tests/game/loadProofMap.test.ts`

**Interfaces:**

- Consumes: `gridCellAtWorld`, existing deterministic PNG helpers, current Tiled marker layer, and current `ParsedProofMap`.
- Produces: exactly one `bed-interaction` point marker at logical cell `{ x: 6, y: 8 }`, `ParsedProofMap.bedCell`, a two-frame soil sheet, and a four-frame turnip sheet.
- Preserves: the nine farm cells, player spawn, scenery footprints, embedded Tiled tilesets, and `ProofMap`.

- [ ] **Step 1: Extend parser tests first**

Add assertions that the committed map has `nextobjectid: 7`, marker ID 5 named `player-spawn`, marker ID 6 named `bed-interaction`, and that `loadProofMap()` returns `bedCell: { x: 6, y: 8 }`. Add malformed-map rows for missing bed, duplicate bed, renamed bed, unknown marker name, wrong bed coordinates, and stale `nextobjectid`.

Extend the existing PNG dimension table with these deterministic asset assertions:

```ts
test.each([
  ['proof-tiles.png', 128, 32],
  ['proof-player.png', 128, 48],
  ['proof-scenery.png', 192, 96],
  ['proof-soil.png', 128, 32],
  ['proof-turnip.png', 128, 48],
])('writes %s with exact PNG dimensions', async (name, width, height) => {
  const bytes = new Uint8Array(
    await Bun.file(resolve(assetRoot, 'sprites', name)).arrayBuffer(),
  );
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  expect(view.getUint32(16)).toBe(width);
  expect(view.getUint32(20)).toBe(height);
});
```

- [ ] **Step 2: Run the parser test and observe RED**

Run: `rtk bun test tests/game/loadProofMap.test.ts`

Expected: FAIL because `ParsedProofMap` lacks `bedCell`, the header remains 6, and the new images do not exist.

- [ ] **Step 3: Change parser/header/marker validation together**

Change `ParsedProofMap` to include `bedCell: GridCell`. Replace the spawn-only marker parser with one exact marker parser that:

- accepts only `player-spawn` and `bed-interaction` names;
- requires exactly one point object of each name;
- requires player ID 5 and bed ID 6, both visible with zero rotation and empty type;
- preserves the existing unique spawn parsing;
- converts the bed marker through `gridCellAtWorld` and requires `{ x: 6, y: 8 }`; and
- requires `nextobjectid === 7`.

Do not duplicate the nine-cell, duplicate-cell, bed-vs-farm, or bed-vs-footprint invariants here; those belong to `GameSession` and are already covered in Task 1.

```ts
interface ParsedMarkers {
  spawn: GridPoint;
  bedCell: GridCell;
}

const allowedMarkerNames = new Set(['player-spawn', 'bed-interaction']);
```

- [ ] **Step 4: Update the deterministic generator and committed outputs atomically**

Generate marker ID 6 with this exact Tiled representation:

```ts
{
  id: 6,
  name: 'bed-interaction',
  type: '',
  point: true,
  x: 320,
  y: 240,
  rotation: 0,
  visible: true,
}
```

Set `nextobjectid: 7`. Generate:

- `proof-soil.png`: `128×32`, two `64×32` frames in dry then wet order;
- `proof-turnip.png`: `128×48`, four `32×48` frames in growth 0, 1, 2, 3 order.

Use only the existing pixel writer/drawing utilities. Give every frame a visibly distinct silhouette or color while keeping transparent backgrounds and crisp integer pixels.

Run: `rtk bun run assets:generate`

- [ ] **Step 5: Prove deterministic regeneration**

Run the generator twice and compare both tracked output and SHA-256 values:

```bash
rtk bun run assets:generate
rtk shasum -a 256 src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png
rtk git diff -- src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png
rtk bun run assets:generate
rtk shasum -a 256 src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png
rtk git diff -- src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png
```

Expected: the two SHA-256 result sets are identical, both diffs show the same intended change, and the second run introduces no additional byte changes.

- [ ] **Step 6: Run focused and full verification**

Run:

- `rtk bun test tests/game/loadProofMap.test.ts tests/game/GameSession.test.ts`
- `rtk bun test`
- `rtk bun run check`

Expected: all pass; map parsing and construction agree on the authored bed/farm boundary.

- [ ] **Step 7: Review and commit Task 2**

Review the staged JSON and PNG dimensions, confirm IDs 5 and 6 are unique, confirm `nextobjectid` is 7 in generator/parser/fixture, and run `rtk git diff --check`.

Commit:

```bash
rtk git add tools/generate-proof-assets.ts src/game/phaser/loadProofMap.ts src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png tests/game/loadProofMap.test.ts
rtk git commit -m "feat: author farm sleep marker and sprites"
```

---

### Task 3: Shared Gate-Bound Keys and Edge-Triggered Actions

**Files:**

- Create: `src/game/phaser/GateBoundKeys.ts`
- Create: `src/game/phaser/ActionController.ts`
- Modify: `src/game/phaser/KeyboardController.ts`
- Create: `tests/game/GateBoundKeys.test.ts`
- Create: `tests/game/ActionController.test.ts`
- Modify: `tests/game/KeyboardController.test.ts`

**Interfaces:**

- Consumes: `InputGate`, Phaser key objects, and the existing plugin-aware key teardown behavior.
- Produces: one shared gate subscription/reset/destroy owner, analog WASD sampling, and edge samples for 1–4, Space, and E.
- Preserves: `KeyboardController.sample()` axes and idempotent teardown behavior.

- [ ] **Step 1: Write failing helper lifecycle tests**

Test initial unlocked and locked construction, reset exactly once on a transition into locked state, no repeated reset while still locked, unsubscribe on destroy, idempotent destroy, `plugin.removeKey(key)` when the plugin exists, and `key.destroy()` fallback when it does not.

- [ ] **Step 2: Write failing action edge tests**

Define the public sample shape:

```ts
export interface ActionSample {
  selectedAction: FarmingAction | null;
  useSelected: boolean;
  sleep: boolean;
}
```

Assert keys map as follows: 1 Hoe, 2 Seeds, 3 Water, 4 Hands, Space use, E sleep. A held key must emit once, then remain false/null until release and a new press. Locking must clear both held Phaser key state and the controller's remembered previous-down state so unlock cannot synthesize an edge.

- [ ] **Step 3: Run focused tests and observe RED**

Run:

- `rtk bun test tests/game/GateBoundKeys.test.ts`
- `rtk bun test tests/game/ActionController.test.ts`

Expected: FAIL because the helper and action controller do not exist.

- [ ] **Step 4: Extract `GateBoundKeys` from `KeyboardController`**

Give the helper only lifecycle responsibility. It receives the gate, owned keys, and a controller reset callback. It reports `isLocked()`, subscribes exactly once, resets on initial locked construction and unlocked-to-locked transitions, and destroys keys/subscription idempotently. Use the real Phaser key type in production and cast structural fakes only in tests.

```ts
import type Phaser from 'phaser';

export class GateBoundKeys {
  private destroyed = false;
  private locked: boolean;
  private readonly unsubscribe: () => void;

  constructor(
    gate: InputGate,
    private readonly keys: Phaser.Input.Keyboard.Key[],
    private readonly resetController: () => void,
  ) {
    this.locked = gate.isLocked;
    this.unsubscribe = gate.subscribe((locked) => {
      const enteredLock = locked && !this.locked;
      this.locked = locked;
      if (enteredLock) this.reset();
    });
    if (this.locked) this.reset();
  }

  isLocked(): boolean {
    return this.locked;
  }

  reset(): void {
    for (const key of this.keys) key.reset();
    this.resetController();
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.unsubscribe();
    for (const key of this.keys) {
      const plugin = key.plugin;
      if (plugin) plugin.removeKey(key, true, true);
      else key.destroy?.();
    }
  }
}
```

Move all plugin-aware destruction into this helper. Do not duplicate it in either controller.

- [ ] **Step 5: Refactor `KeyboardController` without changing its public sample**

Create the four movement keys as before, construct one `GateBoundKeys`, return zero axes while locked, and delegate `destroy()` to the helper. Keep the current aggregate direction normalization and reset semantics. Run existing mutation-sensitive keyboard tests unchanged before updating only fakes/imports required by the extraction.

- [ ] **Step 6: Implement `ActionController` edge sampling**

Store the six prior-down flags. On each unlocked sample, compute rising edges from `key.isDown && !previous`, update all previous flags, select the first numeric edge in 1-to-4 order, and return Space/E edges. On reset, clear Phaser key state through the shared helper and clear every previous flag.

- [ ] **Step 7: Run focused, full, and static verification**

Run:

- `rtk bun test tests/game/GateBoundKeys.test.ts tests/game/ActionController.test.ts tests/game/KeyboardController.test.ts`
- `rtk bun test`
- `rtk bun run check`

Expected: all pass with no duplicated gate subscriptions or teardown branches.

- [ ] **Step 8: Review and commit Task 3**

Mutate one rising-edge comparison to level-triggered behavior and prove the held-key test fails, then restore it. Review remount/HMR idempotence and run `rtk rg -n "removeKey|\.destroy\(\)" src/game/phaser` to confirm key teardown has one owner.

Commit:

```bash
rtk git add src/game/phaser/GateBoundKeys.ts src/game/phaser/ActionController.ts src/game/phaser/KeyboardController.ts tests/game/GateBoundKeys.test.ts tests/game/ActionController.test.ts tests/game/KeyboardController.test.ts
rtk git commit -m "feat: add gated farming input controls"
```

---

### Task 4: Phaser Session Integration, Farm Rendering, and Depth

**Files:**

- Create: `src/game/core/farmVisuals.ts`
- Create: `tests/game/farmVisuals.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`

**Interfaces:**

- Consumes: `GameSession`, `ActionController`, `ParsedProofMap.bedCell`, new sprite sheets, current projection adapter, and current stable depth sorter.
- Produces: pure frame mapping, `SceneCommands`, change-driven game snapshots/results/sleep prompts, reconciled soil/crop sprites, and additive `crop:x,y` debug-depth entries.
- Preserves: current movement, target diamond, camera, scenery, player rendering, debug snapshot fields, and player/tree/building depth keys.

- [ ] **Step 1: Write the pure visual mapping test first**

```ts
// tests/game/farmVisuals.test.ts
import { expect, test } from 'bun:test';
import { farmVisuals } from '../../src/game/core/farmVisuals';

test('maps authoritative farm state to deterministic frames', () => {
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'untilled', crop: null }))
    .toEqual({ soilFrame: null, cropFrame: null });
  expect(farmVisuals({ position: { x: 2, y: 7 }, soil: 'tilled', crop: null }))
    .toEqual({ soilFrame: 0, cropFrame: null });
  for (const growth of [0, 1, 2, 3] as const) {
    expect(farmVisuals({
      position: { x: 2, y: 7 },
      soil: 'tilled',
      crop: { kind: 'turnip', growth, wateredToday: true },
    })).toEqual({ soilFrame: 1, cropFrame: growth });
  }
});
```

The mapper returns soil frame 0 for dry tilled soil, 1 for watered tilled soil, and null for untilled soil. Crop frame equals growth and is independent of watering.

- [ ] **Step 2: Run the mapper test and observe RED**

Run: `rtk bun test tests/game/farmVisuals.test.ts`

Expected: FAIL because `farmVisuals` does not exist.

- [ ] **Step 3: Implement the pure mapper and run GREEN**

```ts
export interface FarmVisualFrames {
  soilFrame: 0 | 1 | null;
  cropFrame: GrowthLevel | null;
}

export function farmVisuals(tile: FarmTileSnapshot): FarmVisualFrames {
  return {
    soilFrame: tile.soil === 'untilled' ? null : tile.crop?.wateredToday ? 1 : 0,
    cropFrame: tile.crop?.growth ?? null,
  };
}

export function farmStableOrder(rowMajorIndex: number): number {
  return 100 + rowMajorIndex;
}
```

Extend the focused test to assert `farmCells.map((_, index) => farmStableOrder(index))` equals `[100, 101, 102, 103, 104, 105, 106, 107, 108]`. `ProofScene` must call this helper rather than repeating the offset.

Run: `rtk bun test tests/game/farmVisuals.test.ts`

- [ ] **Step 4: Define the exact Phaser-to-Svelte bridge**

In `ProofScene.ts`, add:

```ts
export interface SceneCommands {
  selectAction(action: FarmingAction): CommandResult;
  sleep(): CommandResult;
}

export interface ProofSceneDependencies {
  inputGate: InputGate;
  onReady(commands: SceneCommands): void;
  onError(error: Error): void;
  onSnapshot(snapshot: DebugSnapshot): void;
  onGameSnapshot(snapshot: GameSnapshot): void;
  onCommandResult(result: CommandResult): void;
  onSleepPrompt(): void;
}
```

Keep the current debug callback name and existing fields. Widen only `depths` to permit additive crop keys while always retaining `player`, `tree`, and `building`.

- [ ] **Step 5: Replace the scene's direct `ProofWorld` ownership with `GameSession`**

Construct the session exactly as approved:

```ts
this.session = new GameSession({
  world: parsed.world,
  metrics: this.projection.metrics,
  farmCells: parsed.farmCells,
  bedCell: parsed.bedCell,
});
```

In `create()`, publish `this.session.snapshot()` before calling `onReady(this.commands)`. In `update()`, call `session.stepMovement(keyboard.sample(), delta)`, then sample `ActionController`. Keep movement/render/debug/depth work per frame; do not call `onGameSnapshot` for movement alone.

- [ ] **Step 6: Centralize command publication inside the scene**

Use one method for both success and failure:

```ts
private publishCommand(result: CommandResult): CommandResult {
  const snapshot = this.session.snapshot();
  this.reconcileFarmSprites(snapshot);
  this.dependencies.onCommandResult(result);
  this.dependencies.onGameSnapshot(snapshot);
  return result;
}
```

Numeric edges call `publishCommand(session.selectAction(action))`. Space calls `publishCommand(session.applySelectedAction(session.snapshot().target))`. E compares the current target to `snapshot.bedCell`: at the bed it calls only `onSleepPrompt`; away from bed it calls `publishCommand(session.sleep())`. The `SceneCommands.sleep()` facade calls `session.sleep()` exactly once and routes the result through `publishCommand`.

- [ ] **Step 7: Preload and reconcile farm sprites only on creation/commands**

Load `proof-soil.png` as `64×32` frames and `proof-turnip.png` as `32×48` frames. Maintain sprite maps keyed by `"x,y"`. For each snapshot tile:

- create/update/destroy soil according to `soilFrame`;
- create/update/destroy crop according to `cropFrame`;
- center soil on the projected cell diamond;
- bottom-center crop at projected `{ x: cell.x + 0.5, y: cell.y + 0.5 }`;
- assign soil the fixed `SOIL_DEPTH = 1`, strictly between ground depth 0 and target depth 10.

Do not rebuild farm sprites on movement-only frames. Do update crop depth every frame.

- [ ] **Step 8: Join crops to stable entity depth sorting**

Add every visible crop to the same depth input as player/tree/building, using footpoint `{ x: cell.x + 0.5, y: cell.y + 0.5 }` and `stableOrder: 100 + rowMajorIndex`. Preserve player/tree/building stable orders 0/1/2. Store the resolved crop depth under debug key `crop:${cell.x},${cell.y}` without removing existing keys.

- [ ] **Step 9: Teardown both input controllers and all farm objects idempotently**

Destroy `ActionController` alongside `KeyboardController` on scene shutdown. Clear farm maps, session references, and command facade references so remount/HMR cannot retain listeners or sprites.

- [ ] **Step 10: Run focused and integration verification**

Run:

- `rtk bun test tests/game/farmVisuals.test.ts tests/game/GameSession.test.ts tests/game/ActionController.test.ts`
- `rtk bun test tests/game/GameLifecycle.test.ts tests/game/KeyboardController.test.ts`
- `rtk bun test`
- `rtk bun run check`
- `rtk bun run build`

Expected: all pass; the only expected build note is the existing Phaser chunk-size advisory.

- [ ] **Step 11: Review and commit Task 4**

Review callback order, command publication on failures, no snapshot publication during movement-only frames, no Phaser import in `src/game/core`, one sleep call per confirm facade invocation, and stable crop keys/depth order.

Commit:

```bash
rtk git add src/game/core/farmVisuals.ts tests/game/farmVisuals.test.ts src/game/phaser/ProofScene.ts
rtk git commit -m "feat: render interactive turnip farming"
```

---

### Task 5: Svelte HUD, Feedback, Sleep Confirmation, and Test Observation

**Files:**

- Modify: `src/components/GameHost.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/App.svelte`
- Modify: `src/app.css`
- Modify: `src/vite-env.d.ts`
- Modify: `README.md`

**Interfaces:**

- Consumes: `SceneCommands`, `GameSnapshot`, `CommandResult`, and the existing `InputGate`.
- Produces: Day/action/inventory HUD, clickable action selection, persistent feedback, blocking sleep confirmation, and read-only `gameSnapshot()` test observation.
- Preserves: fitted `640×360` stage, lifecycle/error handling, existing lock control labels/reason, and `snapshot()`/`remount()` development hooks.

- [ ] **Step 1: Extend the development hook type before implementation**

Add only the read-only game observation method:

```ts
interface PhoenixTestHook {
  snapshot(): DebugSnapshot;
  gameSnapshot(): GameSnapshot;
  remount(): void;
}
```

Do not expose select, farm, sleep, inventory, or day mutation methods.

- [ ] **Step 2: Thread change-driven callbacks through `GameHost`**

Change its props to forward `onReady(commands)`, `onGameSnapshot(snapshot)`, `onCommandResult(result)`, and `onSleepPrompt()`. Store the latest game snapshot only for the dev hook, and return a fresh deep value from `gameSnapshot()` using `structuredClone`. On restart/remount, clear both latest snapshots before creating the new lifecycle.

- [ ] **Step 3: Make `App.svelte` own presentation-only state**

Store:

- `GameSnapshot | null` latest snapshot;
- `CommandResult | null` latest feedback;
- `SceneCommands | null` current facade; and
- `boolean` sleep confirmation visibility.

Do not copy day, inventory, selection, or farm fields into separate writable state. On scene loading/error/remount, close the sleep panel and release `sleep-confirmation`.

- [ ] **Step 4: Implement exactly-once sleep confirmation and gate cleanup**

When the prompt opens, call `inputGate.set('sleep-confirmation', true)`. Confirm must capture the current command facade, invoke `commands.sleep()` exactly once while movement remains locked, then close the panel and call `inputGate.set('sleep-confirmation', false)` in a `finally` path. Cancel closes and clears the reason without a command. Component teardown always calls `inputGate.set('sleep-confirmation', false)`; clearing an absent reason must remain harmless.

- [ ] **Step 5: Expand `Overlay.svelte` without replacing the foundation control**

Render:

- `Day {snapshot.day}`;
- selected action label;
- `Seeds: {snapshot.inventory.turnipSeeds}`;
- `Turnips: {snapshot.inventory.turnips}`;
- four buttons labeled `1 Hoe`, `2 Seeds`, `3 Water`, `4 Hands`;
- the current persistent result message;
- existing `Lock world input` / `Unlock world input` button;
- the blocking text `Sleep until tomorrow?` with `Confirm` and `Cancel`.

Use `aria-pressed` on action buttons and a dialog with `role="dialog"`, `aria-modal="true"`, and an accessible label. Disable farming buttons until commands and a snapshot are ready.

Map every result code exhaustively to concise text in one presentation function. The function's impossible default must use a `never` assertion so new result codes cannot silently render blank feedback.

- [ ] **Step 6: Style the HUD and modal inside the shared stage**

Keep the overlay legible at both 1× and 2× integer scale, preserve pointer-events behavior, avoid covering the farm/bed route, and give the sleep panel an opaque-enough backing. Do not change logical stage dimensions or native window configuration.

- [ ] **Step 7: Update the README controls and architecture**

Document WASD, 1–4, Space, E, three watered nights, three starter seeds, the Svelte confirmation behavior, `GameSession` authority, and the unchanged macOS-only native boundary.

- [ ] **Step 8: Run Svelte/static/build verification**

Run the local Svelte analysis workflow required by the loaded Svelte skills for `GameHost.svelte`, `Overlay.svelte`, and `App.svelte`, then run:

- `rtk bun run check`
- `rtk bun test`
- `rtk bun run build`
- `rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist`

Expected: zero Svelte diagnostics; unit/build green; production scan exits 1 with no test-hook match.

- [ ] **Step 9: Review and commit Task 5**

Review gate symmetry for Confirm, Cancel, error, remount, and destroy; verify no duplicate farming authority in Svelte; verify exact old lock labels; verify feedback does not self-clear.

Commit:

```bash
rtk git add src/components/GameHost.svelte src/components/Overlay.svelte src/App.svelte src/app.css src/vite-env.d.ts README.md
rtk git commit -m "feat: add farming HUD and sleep confirmation"
```

---

### Task 6: Real-Control Browser Acceptance for the Complete Loop

**Files:**

- Modify: `tests/e2e/helpers.ts`
- Create: `tests/e2e/farming.pw.ts`
- Preserve and rerun: `tests/e2e/lifecycle.pw.ts`
- Preserve and rerun: `tests/e2e/world.pw.ts`

**Interfaces:**

- Consumes: real keyboard/button input, `window.__PHOENIX_TEST__.snapshot()`, new read-only `gameSnapshot()`, and existing movement helpers.
- Produces: browser proof of rules, HUD, gating, targeting, deterministic day growth, harvest, rejection stability, clickable selection, and crop/player depth reversal.
- Preserves: all 14 foundation browser tests and their current timing/readiness helpers.

- [ ] **Step 1: Add a read-only game snapshot helper**

```ts
export async function gameSnapshot(page: Page): Promise<GameSnapshot> {
  return page.evaluate(() => {
    const snapshot = window.__PHOENIX_TEST__?.gameSnapshot();
    if (!snapshot) throw new Error('Phoenix game snapshot is not ready');
    return snapshot;
  });
}
```

Do not add a command helper. All actions below enter through `page.keyboard` or visible buttons.

- [ ] **Step 2: Write the failing selection/rejection acceptance test**

At initial spawn, tap `d` just enough to face right while remaining in the same logical floor cell; assert the debug target and authoritative target are both `{ x: 3, y: 8 }`. Select Hands with key 4, wait for the selection snapshot, then capture it as `beforeRejected`. Press Space on the empty farm tile. Assert feedback is the mapped `no-crop` message and the complete authoritative snapshot deeply equals `beforeRejected`. Click `1 Hoe`, assert `aria-pressed`, and prove the authoritative selection returns to Hoe.

- [ ] **Step 3: Write the failing complete three-night loop test**

Use these real-control route helpers, always with release-first settled snapshots:

- Crop approach: return near `{ x: 2.5, y: 9.5 }`, then tap `d` so target is `{ x: 3, y: 8 }`.
- Bed approach: hold `d+s` until player `x >= 5.1` while y remains in the spawn row, release, then tap `d`; assert target is `{ x: 6, y: 8 }` before pressing E.
- Crop return: hold `a+w` until player `x <= 2.8`, release, then tap `d`; assert target returns to `{ x: 3, y: 8 }`.

Perform only real inputs:

1. Key 1 + Space: Hoe.
2. Key 2 + Space: plant; seeds become 2.
3. Key 3 + Space: water.
4. Walk to bed, press E, assert dialog opens and world debug state reports locked.
5. While the dialog is open, press movement, selection, and Space keys and prove player/session state is unchanged.
6. Confirm once, assert Day 2, growth 1, watering false, dialog closed, world unlocked.
7. Return, water, sleep, assert Day 3/growth 2.
8. Return, water, sleep, assert Day 4/growth 3.
9. Return, key 4 + Space, assert crop null, soil tilled, seeds 2, turnips 1.

Assert the HUD values and persistent feedback after every command boundary rather than relying only on the hook.

Capture the Phaser canvas—not the Svelte overlay—around the projected crop sprite after planting, watering, and each growth transition. Compute the clip from the known crop footpoint `{ x: 3.5, y: 8.5 }`, the current debug camera scroll, and the canvas bounding box/scale. Clip the sprite's logical `32×48` area at the active integer stage scale, poll until the camera/clip is settled, and assert consecutive image buffers differ. This proves the generated dry/wet/growth frames produce visible output without adding render-state mutation methods or brittle full-screen golden files.

- [ ] **Step 4: Add Cancel and away-from-bed sleep coverage**

Press E while a farm tile is targeted and assert no dialog, `not-at-bed` feedback, and unchanged day. At the bed, open the dialog and Cancel; assert unchanged day/crops and released input. Reopen and Confirm in the lifecycle test to prove no stale gate reason or duplicated command.

- [ ] **Step 5: Add crop/player depth reversal coverage**

Hoe and plant `{ x: 3, y: 8 }`. Move the player to the projected far side of the crop footpoint and assert `snapshot.depths.player < snapshot.depths['crop:3,8']`. Move through to the near side and assert the relation reverses. Also assert tree/building depth keys remain present, proving the additive debug seam did not replace foundation data.

- [ ] **Step 6: Run RED before adjusting production code**

Run: `rtk bun run test:e2e -- tests/e2e/farming.pw.ts`

Expected: FAIL until the hook, HUD, scene inputs, and farm rendering from Tasks 4–5 are wired correctly. If it unexpectedly passes before all requested assertions exist, strengthen the test rather than changing production code.

- [ ] **Step 7: Stabilize only readiness and route predicates**

Use `expect.poll`, `page.waitForFunction({ polling: 'raf' })`, the existing 3-second movement deadline, exact authoritative target checks, and release-first snapshots. Do not add arbitrary sleeps, retries, broad timeouts, direct domain calls, teleportation, or test-only action commands. Run the risky full-loop test three consecutive times before accepting it.

- [ ] **Step 8: Run focused and complete browser verification**

Run:

- `rtk bun run test:e2e -- tests/e2e/farming.pw.ts`
- `rtk bun run test:e2e -- tests/e2e/farming.pw.ts`
- `rtk bun run test:e2e -- tests/e2e/farming.pw.ts`
- `rtk bun run test:e2e -- tests/e2e/lifecycle.pw.ts`
- `rtk bun run test:e2e -- tests/e2e/world.pw.ts`
- `rtk bun run test:e2e`

Expected: three focused farming passes, all foundation suites green, then the full suite green in one combined run.

- [ ] **Step 9: Run unit/static/build regression verification**

Run:

- `rtk bun test`
- `rtk bun run check`
- `rtk bun run build`
- `rtk rg -n "__PHOENIX_TEST__|__PHOENIX_HMR_COUNT__" dist`
- `rtk git diff --check`

Expected: all tests/check/build pass, production hook scan exits 1 with no matches, and diff check is clean.

- [ ] **Step 10: Review and commit Task 6**

Review that tests use observation-only hooks, every action comes from normal controls, sleep confirm is exactly once, target identity is asserted before commands, the test covers all three water/sleep transitions, and crop depth reverses around the player.

Commit:

```bash
rtk git add tests/e2e/helpers.ts tests/e2e/farming.pw.ts
rtk git commit -m "test: cover the complete turnip loop"
```

---

### Task 7: Whole-Branch Review and macOS Delivery Verification

**Files:**

- Review: every file changed since the HPA-591 branch base.
- Update only if evidence requires it: `README.md`
- Do not commit generated build directories, Playwright traces, screenshots, temporary Tauri configs, or clean-checkout archives.

**Interfaces:**

- Consumes: the committed Task 1–6 branch, `verify:clean`, deterministic asset generator, browser acceptance, Cargo/Tauri build, and a real local macOS application window.
- Produces: reviewed branch evidence and a truthful handoff for HPA-591.

- [ ] **Step 1: Perform a whole-branch implementation review**

Compare the branch against its base and the approved design. Check especially:

- one authoritative `GameSession` and one selected-action switch;
- exact rejection precedence and no mutation on failures;
- fresh/serializable snapshots and defensive construction;
- atomic marker/header/parser/generator agreement;
- one gate-bound key lifecycle implementation;
- change-driven Svelte publication rather than frame-driven HUD updates;
- sleep gate release on every exit path;
- no new dependencies or gameplay in Rust;
- observation-only browser hooks; and
- no regression to the 14 foundation browser cases.

Address every valid Critical, Important, or Minor finding with a focused RED/GREEN cycle and separate fix commit. Re-review the changed scope after each fix round.

- [ ] **Step 2: Verify deterministic authored outputs and the complete local matrix**

Run:

- `rtk bun run assets:generate`
- `rtk git diff --exit-code -- src/assets/maps/proof-map.json src/assets/sprites/proof-soil.png src/assets/sprites/proof-turnip.png`
- `rtk bun run check`
- `rtk bun test`
- `rtk bun run test:e2e`
- `rtk bun run build`
- `rtk cargo check --manifest-path src-tauri/Cargo.toml`
- `rtk bun run tauri:build`
- `rtk bun run verify:clean`

Expected: generated assets are already committed byte-for-byte; checks/unit/E2E/build/Cargo/Tauri/clean-checkout all pass. The existing Vite chunk advisory is acceptable. If sandboxed DMG creation fails at `hdiutil` with a device error, rerun the exact Tauri or clean-verifier command at the approved macOS host boundary and report both outcomes.

- [ ] **Step 3: Audit the macOS artifacts**

Confirm the `.app` and `.dmg` exist under `src-tauri/target/release/bundle`, the Mach-O architecture matches the current Mac, the bundle identifier remains `com.hapadona.phoenix`, and `hdiutil verify` accepts the DMG. Report ad hoc signing truthfully; do not present it as Developer ID signing or notarization.

- [ ] **Step 4: Perform a bounded native smoke**

Launch only the just-built Phoenix app. Verify a real Phoenix window shows the HUD and farm visuals and accepts WASD plus at least one farming selection/action. When reliable PID-targeted interaction is available, also verify the sleep panel blocks world input and releases it after Cancel. Keep browser E2E as the authoritative proof for the complete three-night loop if native automation is ambiguous. Stop only the Phoenix process created by this task and leave unrelated applications/processes untouched.

- [ ] **Step 5: Confirm final repository hygiene**

Run:

- `rtk git status --short --branch`
- `rtk git diff --check`
- `rtk git log --oneline --decorate -12`

Expected: clean worktree, clean committed diffs, no generated artifacts staged, and a linear sequence of reviewed HPA-591 commits.

- [ ] **Step 6: Prepare the HPA-591 handoff**

Report the exact reviewed head, commit list, unit/E2E/static/build/native results, artifact paths, any accepted warnings, and any native interaction not directly proven. Do not mark HPA-587 complete. Move HPA-591 to review/done or integrate the branch only after the user chooses the finishing workflow.
