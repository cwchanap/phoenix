# Phoenix Persistence Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use TDD for core state/parser/repository/orchestration work, keep each task type-green before moving on, and deliver HPA-596 in this single PR.

**Goal:** Deliver HPA-596 with one versioned autosave slot, New Game/Continue title flow, browser `localStorage`, Tauri Store persistence, current-rule-safe restores, fixed-spawn resume, and visible save failures.

**Architecture:** `GameSession` remains the only mutable gameplay authority and gains the canonical `state(): GameState` projection. `GameSnapshot` derives from that state plus transient world/derived read-model data. `src/persistence/` owns the V1 envelope, two storage adapters, title bootstrap, and the one-write overnight transaction; it depends on `game/core`, never the reverse. Svelte owns phase/status presentation, Phaser forwards optional initial state and exposes one read-only state accessor, and Tauri only supplies Store.

**Tech Stack:** Bun 1.3.1 and `bun:test`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.x, `@tauri-apps/plugin-store` 2.4.4, current Rust/Cargo toolchain.

**Spec:** `docs/superpowers/specs/2026-08-18-phoenix-persistence-slice-design.md`

## Global Constraints

- Implement only HPA-596. Do not start HPA-597 finale/content or HPA-599 release polish.
- Keep HPA-596 as one PR; continue implementation on this planning PR after approval.
- Keep `GameSession` as the only mutable gameplay authority.
- Persist `GameState`, never `GameSnapshot`.
- Never persist player position/facing/target, camera, projected/world coordinates, authored interaction cells, Tiled objects, Phaser objects, or Svelte state.
- Continue always reconstructs `ProofWorld` from the current authored map and therefore resumes at the authored spawn.
- Persist `pendingDaySummary`, selected action/seed, farming/economy/shipment state, relationship daily flags, and one-time dialogue flags.
- Derive `maxStamina` and relationship level; do not save them redundantly.
- Save only after successful `sleep()` returns `day-advanced`.
- One successful overnight transition performs exactly one repository `save()` call.
- Tauri Store uses `autoSave: false` plus explicit `store.save()`.
- Do not roll back a successful day transition when persistence fails.
- Continue is enabled only for a structurally parsed V1; current-rule/map incompatibility is rejected by `GameSession` and returns to title.
- Malformed/unsupported/incompatible saves must never strand the player away from New Game.
- No migrations, backwards compatibility, backups, save rotation, slots, manual save, cloud sync, compression, encryption, repair/coercion, or custom Rust save command.
- Do not add a state-management library, schema library, JSDOM, service locator, registry, or desktop WebDriver harness.
- Keep `window.__PHOENIX_TEST__` observation-only.
- Keep existing Playwright retries/timeouts; fix shared helpers rather than adding sleeps or per-spec workarounds.
- Use exact Vite `envPrefix: ['VITE_', 'TAURI_ENV_']`; `*` is not a glob in Vite prefix matching.
- Give save status the explicit lifecycle `idle -> saving -> saved|error -> idle` when the morning summary is dismissed/reset.
- Preserve the current Start Day focus contract after the temporary save gate settles.
- Reuse extracted value-parser primitives from `game/core`; do not maintain a second private parser implementation in persistence.

## File Map

### Core state and shared parsing

- Create: `src/game/core/parse.ts`
- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `src/game/phaser/loadProofMap.ts`
- Test: `tests/game/GameSession.test.ts`
- Test: `tests/game/loadProofMap.test.ts` only where imports/error assertions require adjustment

### Persistence layer

- Create: `src/persistence/saveFile.ts`
- Create: `src/persistence/saveRepository.ts`
- Create: `src/persistence/loadTitleState.ts`
- Create: `src/persistence/persistOvernightSave.ts`
- Create: `tests/persistence/saveFile.test.ts`
- Create: `tests/persistence/saveRepository.test.ts`
- Create: `tests/persistence/loadTitleState.test.ts`
- Create: `tests/persistence/persistOvernightSave.test.ts`

### Tauri/Vite integration

- Modify: `vite.config.ts`
- Modify: `src/vite-env.d.ts`
- Modify: `package.json`
- Modify: `bun.lock`
- Modify: `src-tauri/Cargo.toml`
- Modify: `src-tauri/Cargo.lock`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/capabilities/default.json`
- Modify: `tests/config/scaffold.test.ts`

### Title/game/save UI bridge

- Create: `src/components/TitleScreen.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/GameHost.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `src/app.css`
- Modify: `tests/e2e/helpers.ts`
- Create: `tests/e2e/persistence.pw.ts`

### Architecture and handoff

- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `tests/config/handoff.test.ts`

No planned changes: `src/assets/**`, `tools/generate-proof-assets.ts`, `src/game/core/ProofWorld.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`, crop/villager content values, `.github/workflows/ci.yml`, `playwright.config.ts`, or a new desktop E2E framework.

## Risks

### Store environment/capability wiring

The Store adapter can compile and pass fake-backed unit tests while the real webview takes the wrong backend or is denied by Tauri permissions. Task 3 therefore includes a real `tauri:dev` Store initialization/write/read smoke when the plugin is introduced; Task 7 keeps the full product close/reopen acceptance.

### Shared E2E helper coupling

`waitForWorld` is used by every existing Playwright spec, and `confirmAndStartDay` is used by multi-night farming/economy/social flows. Tasks 4 and 5 update those helpers with the feature behavior and run the full E2E suite immediately rather than deferring breakage discovery.

---

## Task 1: Make `GameSession.state()` canonical and restore only valid current-rule state

**Files:**
- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Test: `tests/game/GameSession.test.ts`

**Interfaces:**
- Produces: `RelationshipState`, `GameState`, `GameSession.state(): GameState`, `GameSessionConfig.initialState?: GameState`
- Preserves: existing `GameSnapshot` consumer shape, existing commands, existing `ProofWorld` spawn behavior

- [ ] **Step 1: Write RED tests for canonical state, current-rule invariants, and real round trips**

Use this compact test-only authored arrangement for the command-driven round trip so all non-farm interaction targets are reachable from one spawn by changing facing:

```ts
const roundTripFarmCells = [
  { x: 6, y: 2 }, { x: 7, y: 2 }, { x: 8, y: 2 },
  { x: 6, y: 3 }, { x: 7, y: 3 }, { x: 8, y: 3 },
  { x: 6, y: 4 }, { x: 7, y: 4 }, { x: 8, y: 4 },
];

function roundTripConfig(overrides: Partial<GameSessionConfig> = {}): GameSessionConfig {
  return {
    world: {
      width: 12,
      height: 12,
      spawn: { x: 3.5, y: 8.5 },
      footprints: [],
    },
    metrics: { tileWidth: 64, tileHeight: 32, origin: { x: 384, y: 0 } },
    farmCells: roundTripFarmCells,
    bedCell: { x: 4, y: 9 },
    shopCell: { x: 4, y: 7 },
    shippingCell: { x: 2, y: 9 },
    villagerCells: {
      shopkeeper: { x: 2, y: 7 },
      farmer: { x: 9, y: 5 },
      resident: { x: 10, y: 5 },
    },
    nextWeather: () => 'sunny',
    ...overrides,
  };
}

function face(session: GameSession, screenX: number, screenY: number): void {
  session.stepMovement({ screenX, screenY }, 0);
}

function withoutWorld(snapshot: GameSnapshot) {
  const { player: _player, target: _target, ...rest } = snapshot;
  return rest;
}
```

Drive the real commands instead of constructing one giant expected-state literal:

```ts
const session = new GameSession(roundTripConfig());

face(session, 1, 0); // right -> shop {4,7}
expect(session.buySeeds('potato', 1)).toEqual({ ok: true, code: 'seeds-purchased' });

for (const cell of roundTripFarmCells.slice(0, 2)) {
  expect(session.hoe(cell)).toEqual({ ok: true, code: 'soil-tilled' });
  expect(session.plant(cell)).toEqual({ ok: true, code: 'crop-planted' });
  expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
}
expect(session.hoe(roundTripFarmCells[2])).toEqual({ ok: true, code: 'soil-tilled' });

for (let night = 0; night < 3; night += 1) {
  face(session, 0, 1); // down -> bed {4,9}
  expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
  expect(session.acknowledgeDaySummary()).toEqual({ ok: true, code: 'day-started' });
  if (night < 2) {
    for (const cell of roundTripFarmCells.slice(0, 2)) {
      expect(session.water(cell)).toEqual({ ok: true, code: 'crop-watered' });
    }
  }
}

for (const cell of roundTripFarmCells.slice(0, 2)) {
  expect(session.harvest(cell)).toEqual({ ok: true, code: 'crop-harvested' });
}

face(session, -1, 0); // left -> shipping {2,9}
expect(session.depositCrop('turnip', 1)).toEqual({ ok: true, code: 'crop-deposited' });

face(session, 0, -1); // up -> shopkeeper {2,7}
expect(session.talkTo('shopkeeper').ok).toBe(true);
expect(session.giftCrop('shopkeeper', 'turnip').ok).toBe(true);
expect(session.selectAction('hands')).toEqual({ ok: true, code: 'action-selected' });
expect(session.selectSeed('potato')).toEqual({ ok: true, code: 'seed-selected' });
```

At the pre-sleep checkpoint, export and restore. This preserves non-zero pending shipment and same-day social flags:

```ts
const beforeSleepState = session.state();
const restoredBeforeSleep = new GameSession(
  roundTripConfig({ initialState: structuredClone(beforeSleepState) }),
);
expect(withoutWorld(restoredBeforeSleep.snapshot())).toEqual(withoutWorld(session.snapshot()));
expect(restoredBeforeSleep.snapshot().player.position).toEqual({ x: 3.5, y: 8.5 });
```

Then prove the rebuilt farm lookup references restored tile objects by planting into the saved tilled-empty third tile:

```ts
expect(restoredBeforeSleep.selectSeed('potato')).toEqual({ ok: true, code: 'seed-selected' });
expect(restoredBeforeSleep.plant(roundTripFarmCells[2])).toEqual({
  ok: true,
  code: 'crop-planted',
});
```

Advance the original session once more so shipping becomes a pending morning summary, then round-trip again:

```ts
face(session, 0, 1);
expect(session.sleep()).toEqual({ ok: true, code: 'day-advanced' });
const morningState = session.state();
const restoredMorning = new GameSession(
  roundTripConfig({ initialState: structuredClone(morningState) }),
);
expect(withoutWorld(restoredMorning.snapshot())).toEqual(withoutWorld(session.snapshot()));
expect(restoredMorning.snapshot().pendingDaySummary?.shippingIncome).toBeGreaterThan(0);
```

Add deep-clone coverage:

```ts
const first = session.state();
const second = session.state();
expect(first).toEqual(second);
expect(first).not.toBe(second);
first.inventory.seeds.turnip += 999;
expect(session.state()).toEqual(second);
```

Add table-driven invalid restore cases starting from one valid exported state:

```ts
const invalidCases: Array<[string, (state: GameState) => void]> = [
  ['day below range', (state) => (state.day = 0)],
  ['day above range', (state) => (state.day = MAX_DAY + 1)],
  ['time before day start', (state) => (state.timeMinutes = DAY_START_MINUTES - 1)],
  ['time after cutoff', (state) => (state.timeMinutes = ACTION_CUTOFF_MINUTES + 1)],
  ['negative stamina', (state) => (state.stamina = -1)],
  ['stamina over max', (state) => (state.stamina = MAX_STAMINA + 1)],
  ['negative money', (state) => (state.money = -1)],
  ['negative seed count', (state) => (state.inventory.seeds.turnip = -1)],
  ['negative crop count', (state) => (state.inventory.crops.turnip = -1)],
  ['negative shipment count', (state) => (state.pendingShipment.turnip = -1)],
  ['negative relationship points', (state) => (state.relationships.shopkeeper.points = -1)],
  [
    'growth past maturity',
    (state) => {
      state.farmTiles[0].crop = {
        kind: 'turnip',
        growth: CROP_DEFINITIONS.turnip.growthDays + 1,
        wateredToday: false,
      };
    },
  ],
];
```

Every invalid state throws with prefix `GameSession: invalid initial state`.

Keep/add map-identity invalid cases: duplicate saved farm coordinate, foreign saved farm coordinate, and missing villager relationship.

Run:

```bash
bun test tests/game/GameSession.test.ts
```

Expected RED: `GameState`, `RelationshipState`, `state()`, and `initialState` do not exist.

- [ ] **Step 2: Promote relationship state and type `GameSnapshot` from `GameState`**

In `src/game/core/types.ts` add:

```ts
export interface RelationshipState {
  points: number;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}

export interface RelationshipSnapshot extends RelationshipState {
  level: RelationshipLevel;
}

export interface GameState {
  day: number;
  timeMinutes: number;
  stamina: number;
  weather: Weather;
  pendingDaySummary: DaySummary | null;
  selectedAction: FarmingAction;
  selectedSeed: CropKind;
  money: number;
  inventory: InventorySnapshot;
  pendingShipment: CropCounts;
  farmTiles: FarmTileSnapshot[];
  relationships: Record<VillagerId, RelationshipState>;
}

export type GameSnapshot = WorldSnapshot &
  Omit<GameState, 'relationships'> & {
    maxStamina: number;
    relationships: Record<VillagerId, RelationshipSnapshot>;
    villagerCells: Record<VillagerId, GridCell>;
    bedCell: GridCell;
    shopCell: GridCell;
    shippingCell: GridCell;
  };
```

Delete the private `MutableRelationship` interface from `GameSession.ts`; use `RelationshipState` for the mutable record.

- [ ] **Step 3: Add `GameSession.state()` by reusing/extending existing clone helpers**

Do not create persistence-only clones. Keep/extend the existing `cloneCounts`, farm-tile, day-summary, inventory, and relationship clone helpers near the bottom of `GameSession.ts`.

Implement:

```ts
state(): GameState {
  return {
    day: this.day,
    timeMinutes: this.timeMinutes,
    stamina: this.stamina,
    weather: this.weather,
    pendingDaySummary: cloneDaySummary(this.pendingDaySummary),
    selectedAction: this.selectedAction,
    selectedSeed: this.selectedSeed,
    money: this.money,
    inventory: cloneInventory(this.inventory),
    pendingShipment: cloneCounts(this.pendingShipment),
    farmTiles: this.farmTiles.map(cloneFarmTile),
    relationships: cloneRelationshipState(this.relationships),
  };
}
```

Change `snapshot()` to call `const state = this.state()` and spread `...state`, overriding only relationships with derived `level` plus existing world/maxStamina/interaction-cell fields.

- [ ] **Step 4: Validate current-rule invariants and restore into existing containers**

Add `ACTION_CUTOFF_MINUTES` to the existing `dailyRhythm` imports. Reuse the already imported `CROP_DEFINITIONS`.

Add a local failure helper:

```ts
function invalidInitialState(reason: string): never {
  throw new Error(`GameSession: invalid initial state ${reason}`);
}
```

Before applying `initialState`, assert:

```text
1 <= day <= MAX_DAY
DAY_START_MINUTES <= timeMinutes <= ACTION_CUTOFF_MINUTES
0 <= stamina <= MAX_STAMINA
money >= 0 and safe integer
all inventory/shipment counts >= 0 and safe integers
all relationship points >= 0 and safe integers
0 <= crop.growth <= CROP_DEFINITIONS[crop.kind].growthDays
```

The save parser handles shape/unions; this code handles current-rule ranges only.

Preserve exact current farm identity. After validating/cloning restored tiles, replace the array contents and rebuild the lookup map:

```ts
const restoredTiles = initialState.farmTiles.map(cloneFarmTile);
this.farmTiles.splice(0, this.farmTiles.length, ...restoredTiles);
this.farmTilesByKey.clear();
for (const tile of this.farmTiles) {
  this.farmTilesByKey.set(cellKey(tile.position), tile);
}
```

Clone scalar/count/day-summary/relationship fields into the current session. Never replace or hydrate `ProofWorld`.

- [ ] **Step 5: Verify Task 1**

Run:

```bash
bun test tests/game/GameSession.test.ts
bun run check
```

Expected: GREEN, including both command-driven checkpoints, invariant rejection, fixed spawn, and post-restore plant command.

- [ ] **Step 6: Commit Task 1**

```bash
git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts
git commit -m "feat: add restorable Phoenix game state"
```

---

## Task 2: Share plain-value parsing and add the structural V1 save envelope

**Files:**
- Create: `src/game/core/parse.ts`
- Modify: `src/game/phaser/loadProofMap.ts`
- Create: `src/persistence/saveFile.ts`
- Create: `tests/persistence/saveFile.test.ts`
- Modify: `tests/game/loadProofMap.test.ts` only if imports/error assertions require adjustment
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces: `createValueParser(prefix)` with `fail/record/array/string/number/integer/safeInteger/boolean/oneOf`
- Produces: `SaveFileV1`, `createSaveFile(state)`, `parseSaveFile(value)`
- Dependency rule: persistence may import core; core never imports persistence

- [ ] **Step 1: Record the existing map-parser baseline**

Run before refactoring:

```bash
bun test tests/game/loadProofMap.test.ts
```

Expected: GREEN. Preserve exact existing `proof-map: ...` error behavior.

- [ ] **Step 2: Extract the existing parser primitives without changing map behavior**

Create `src/game/core/parse.ts`:

```ts
export function createValueParser(prefix: string) {
  const fail = (reason: string): never => {
    throw new Error(`${prefix}: ${reason}`);
  };

  const record = (value: unknown, context: string): Record<string, unknown> => {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      fail(`${context} must be an object`);
    }
    return value as Record<string, unknown>;
  };

  const array = (value: unknown, context: string): unknown[] => {
    if (!Array.isArray(value)) fail(`${context} must be an array`);
    return value;
  };

  const string = (value: unknown, context: string): string => {
    if (typeof value !== 'string') fail(`${context} must be a string`);
    return value;
  };

  const number = (value: unknown, context: string): number => {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      fail(`${context} must be a finite number`);
    }
    return value;
  };

  const integer = (value: unknown, context: string): number => {
    const result = number(value, context);
    if (!Number.isInteger(result)) fail(`${context} must be an integer`);
    return result;
  };

  const safeInteger = (value: unknown, context: string): number => {
    const result = number(value, context);
    if (!Number.isSafeInteger(result)) fail(`${context} must be a safe integer`);
    return result;
  };

  const boolean = (value: unknown, context: string): boolean => {
    if (typeof value !== 'boolean') fail(`${context} must be a boolean`);
    return value;
  };

  const oneOf = <T extends string>(
    value: unknown,
    allowed: readonly T[],
    context: string,
  ): T => {
    const result = string(value, context);
    if (!allowed.includes(result as T)) {
      fail(`${context} must be one of ${allowed.join(', ')}`);
    }
    return result as T;
  };

  return { fail, record, array, string, number, integer, safeInteger, boolean, oneOf };
}
```

In `loadProofMap.ts`, replace only private primitive definitions with:

```ts
const { fail, record, array, string, number, integer, boolean } =
  createValueParser('proof-map');
```

Do not refactor the map contract or parser structure beyond this extraction.

Run:

```bash
bun test tests/game/loadProofMap.test.ts
```

Expected: GREEN with unchanged map contract/error prefixes.

- [ ] **Step 3: Write RED save-envelope/parser tests**

Create `tests/persistence/saveFile.test.ts`.

Use a valid `GameState` from `GameSession.state()` rather than repeating the whole state shape by hand where possible.

Cover:

```ts
const file = createSaveFile(state);
expect(file).toEqual({ schemaVersion: 1, state });
expect(parseSaveFile(structuredClone(file))).toEqual(file);
```

Mutate nested source state after `createSaveFile()` and prove the file is unchanged.

Reject structural defects:

- non-object top level;
- missing/wrong `schemaVersion`;
- missing current state fields;
- invalid weather/action/seed/crop/villager IDs;
- non-safe-integer numeric fields;
- malformed count records;
- malformed farm tile/crop object shape;
- malformed relationship records;
- malformed pending-day-summary shipment lines.

Structural parsing must **not** own current rule/map invariants. Add a passing case:

```ts
const structurallyValidButImpossible = structuredClone(file);
structurallyValidButImpossible.state.day = 999;
structurallyValidButImpossible.state.stamina = 500;
structurallyValidButImpossible.state.inventory.seeds.turnip = -1;
structurallyValidButImpossible.state.farmTiles[0].position = { x: 11, y: 11 };
expect(() => parseSaveFile(structurallyValidButImpossible)).not.toThrow();
```

`GameSession` rejects those values later using current rule/authored-map knowledge.

Run:

```bash
bun test tests/persistence/saveFile.test.ts
```

Expected RED: persistence module missing.

- [ ] **Step 4: Implement `SaveFileV1` using the shared parser**

Create:

```ts
export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

export function createSaveFile(state: GameState): SaveFileV1;
export function parseSaveFile(value: unknown): SaveFileV1;
```

Initialize the parser with:

```ts
const { record, array, safeInteger, boolean, oneOf } =
  createValueParser('Invalid save');
```

Use current closed runtime value lists for farming actions, weather, crop IDs, and villager IDs. Parse integers structurally as safe integers but do not apply domain ranges/minimums here.

`createSaveFile()` and `parseSaveFile()` return fresh nested data. Do not add version registries, schemas, migrations, coercion, or map-cell checks.

- [ ] **Step 5: Document the new layer immediately**

In `CLAUDE.md` Architecture add after core:

```markdown
- **`src/persistence/` — save/application boundary.** Owns the V1 save envelope, browser/Tauri storage adapters, title-load orchestration, and overnight save transaction. It may depend on framework-free `game/core` types/helpers; `game/core` never imports persistence. `App.svelte` is the only production runtime coordinator between persistence and the game scene.
```

Update the core bullet to mention `parse.ts` as a framework-free shared plain-value validation helper used by map/save parsing.

- [ ] **Step 6: Verify Task 2**

Run:

```bash
bun test tests/game/loadProofMap.test.ts tests/persistence/saveFile.test.ts
bun run check
bun run test:coverage
bun run coverage:check
```

Expected: GREEN; `loadProofMap` behavior unchanged, V1 parsing structural-only, shared parser lines covered through both consumers.

- [ ] **Step 7: Commit Task 2**

```bash
git add src/game/core/parse.ts src/game/phaser/loadProofMap.ts src/persistence/saveFile.ts tests/persistence/saveFile.test.ts tests/game/loadProofMap.test.ts CLAUDE.md
git commit -m "feat: add Phoenix V1 save envelope"
```

---

## Task 3: Add browser/Tauri repositories and verify real Store wiring immediately

**Files:**
- Create: `src/persistence/saveRepository.ts`
- Create: `tests/persistence/saveRepository.test.ts`
- Modify: `vite.config.ts`
- Modify: `src/vite-env.d.ts`
- Modify: `package.json`
- Modify: `bun.lock`
- Modify: `src-tauri/Cargo.toml`
- Modify: `src-tauri/Cargo.lock`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/capabilities/default.json`
- Modify: `tests/config/scaffold.test.ts`

**Interfaces:**
- Produces: `SaveRepository.load(): Promise<unknown | null>`
- Produces: `SaveRepository.save(file: SaveFileV1): Promise<void>`
- Produces: `createSaveRepository(): Promise<SaveRepository>`
- Selector: only `import.meta.env.TAURI_ENV_PLATFORM`

- [ ] **Step 1: Write RED repository and factory tests**

Create `tests/persistence/saveRepository.test.ts` with a tiny in-memory `Storage` fake; do not add JSDOM.

Test browser behavior:

```ts
const repository = new LocalStorageSaveRepository(storage);
expect(await repository.load()).toBeNull();
await repository.save(file);
expect(storage.getItem('phoenix.save.v1')).toBe(JSON.stringify(file));
expect(await repository.load()).toEqual(file);
```

Test malformed JSON and storage exceptions propagate.

Use one narrow factory seam for tests:

```ts
interface SaveRepositoryEnvironment {
  tauriPlatform?: string;
  storage: Storage;
  loadTauriStore: () => Promise<TauriStoreLike>;
}
```

Assert:

```text
missing tauriPlatform -> localStorage adapter; Store loader call count 0
present tauriPlatform -> Store loader call count 1
Store loader rejection -> rejects; no localStorage fallback
Tauri save -> set('save', file) exactly once + save() exactly once
Tauri load missing 'save' -> null
```

Run:

```bash
bun test tests/persistence/saveRepository.test.ts
```

Expected RED: repository module missing.

- [ ] **Step 2: Configure the exact Vite Tauri environment prefix and typing**

Update `vite.config.ts`:

```ts
export default defineConfig({
  plugins: [svelte()],
  envPrefix: ['VITE_', 'TAURI_ENV_'],
  server: {
    // preserve current server config exactly
  },
});
```

In `src/vite-env.d.ts` add:

```ts
interface ImportMetaEnv {
  readonly TAURI_ENV_PLATFORM?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

Keep current test-hook declarations unchanged.

- [ ] **Step 3: Add the Store JS/Rust dependencies and adapters**

Add exactly to runtime dependencies:

```json
"@tauri-apps/plugin-store": "2.4.4"
```

Do not add a direct `@tauri-apps/api` dependency solely for environment detection.

Regenerate with:

```bash
bun install
```

In production repository creation:

```ts
const tauriPlatform = import.meta.env.TAURI_ENV_PLATFORM;
if (!tauriPlatform) {
  return new LocalStorageSaveRepository(window.localStorage);
}
const { load } = await import('@tauri-apps/plugin-store');
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});
return new TauriStoreSaveRepository(store);
```

Tauri adapter:

```ts
async load(): Promise<unknown | null> {
  return (await this.store.get<unknown>('save')) ?? null;
}

async save(file: SaveFileV1): Promise<void> {
  await this.store.set('save', file);
  await this.store.save();
}
```

- [ ] **Step 4: Register Store and grant the default Store capability**

Add to `src-tauri/Cargo.toml`:

```toml
tauri-plugin-store = "=2.4.4"
```

Register in `src-tauri/src/lib.rs`:

```rs
tauri::Builder::default()
    .plugin(tauri_plugin_store::Builder::default().build())
    .run(tauri::generate_context!())
    .expect("error while running Phoenix");
```

Add `"store:default"` beside `"core:default"` in `src-tauri/capabilities/default.json`.

Regenerate Cargo lockfile through Cargo:

```bash
cargo check --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 5: Update exact scaffold contract tests**

`tests/config/scaffold.test.ts` currently pins direct JS dependencies exactly. Add Store and these assertions:

```ts
expect(viteConfigText).toContain("envPrefix: ['VITE_', 'TAURI_ENV_']");
expect(viteConfigText).not.toContain('TAURI_ENV_*');
expect(viteEnvText).toContain('readonly TAURI_ENV_PLATFORM?: string');
expect(cargoTomlText).toContain('tauri-plugin-store = "=2.4.4"');
expect(libRsText).toContain('.plugin(tauri_plugin_store::Builder::default().build())');
expect(capability.permissions).toEqual(expect.arrayContaining(['core:default', 'store:default']));
```

Run:

```bash
bun test tests/persistence/saveRepository.test.ts tests/config/scaffold.test.ts
bun run check
cargo check --manifest-path src-tauri/Cargo.toml
```

Expected: GREEN.

- [ ] **Step 6: Perform the early real Tauri Store smoke before leaving Task 3**

Run:

```bash
bun run tauri:dev
```

Open webview devtools. Make the real Phoenix factory execute inside the Tauri webview:

```js
const { createSaveRepository } = await import('/src/persistence/saveRepository.ts');
const repository = await createSaveRepository();
await repository.load();
```

Expected: resolves without Store initialization/permission error. Run this in the Tauri webview, not normal browser development.

Then verify actual Store write/read/delete on a separate smoke store so the Phoenix slot is untouched:

```js
const { Store } = await import('@tauri-apps/plugin-store');
const smoke = await Store.load('phoenix-store-smoke.json', { autoSave: false });
await smoke.set('probe', 'ok');
await smoke.save();
console.log(await smoke.get('probe'));
await smoke.delete('probe');
await smoke.save();
```

Expected console value:

```text
ok
```

If this fails, do not proceed. Fix environment selection, plugin registration, or capability wiring in Task 3.

- [ ] **Step 7: Commit Task 3**

```bash
git add vite.config.ts src/vite-env.d.ts package.json bun.lock src/persistence/saveRepository.ts tests/persistence/saveRepository.test.ts src-tauri tests/config/scaffold.test.ts
git commit -m "feat: add Phoenix save repositories"
```

---

## Task 4: Add unit-tested title bootstrap, title UI, and the loaded-state scene bridge

**Files:**
- Create: `src/persistence/loadTitleState.ts`
- Create: `tests/persistence/loadTitleState.test.ts`
- Create: `src/components/TitleScreen.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/GameHost.svelte`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `src/app.css`
- Modify: `tests/e2e/helpers.ts`

**Interfaces:**
- Produces: `TitleLoadState { repository, save, error }`
- Produces: `loadTitleState(createRepository?)`
- Produces: `SceneCommands.state(): GameState`
- Carries: `initialState: GameState | null` App -> GameHost -> ProofScene -> GameSession

- [ ] **Step 1: Write RED title-bootstrap unit tests for all startup branches**

Create `tests/persistence/loadTitleState.test.ts`.

Test exactly:

```text
repository factory rejects -> repository null, save null, error present
repository loads null -> repository retained, save null, error null
repository load rejects -> repository retained, save null, error present
repository returns malformed/unsupported save -> repository retained, save null, Invalid save error
repository returns valid V1 -> repository retained, parsed save returned, error null
```

Repository stays available after load/parse failure so New Game can overwrite the slot on its next successful sleep.

Run:

```bash
bun test tests/persistence/loadTitleState.test.ts
```

Expected RED: helper missing.

- [ ] **Step 2: Implement the small bootstrap helper**

Create:

```ts
export interface TitleLoadState {
  repository: SaveRepository | null;
  save: SaveFileV1 | null;
  error: string | null;
}

export async function loadTitleState(
  createRepository: () => Promise<SaveRepository> = createSaveRepository,
): Promise<TitleLoadState> {
  try {
    const repository = await createRepository();
    try {
      const value = await repository.load();
      if (value === null) return { repository, save: null, error: null };
      return { repository, save: parseSaveFile(value), error: null };
    } catch (error) {
      return { repository, save: null, error: errorMessage(error) };
    }
  } catch (error) {
    return { repository: null, save: null, error: errorMessage(error) };
  }
}
```

Use one private `errorMessage()` helper that returns `error.message` for `Error` and `String(error)` otherwise. Do not add retries, deletion, or repair.

Run:

```bash
bun test tests/persistence/loadTitleState.test.ts
bun run check
```

Expected: GREEN.

- [ ] **Step 3: Add the minimal title component**

Create `TitleScreen.svelte` with props:

```ts
interface Props {
  loading: boolean;
  canContinue: boolean;
  error: string | null;
  onNewGame: () => void;
  onContinue: () => void;
}
```

Render stable selectors:

```text
data-title-screen
data-new-game
data-continue
data-title-error
```

Continue is disabled while loading or when no parsed save is available. New Game is disabled only while bootstrap is still loading and becomes available even when `error` is present.

Render this component for both `loading-save` and `title`; only `playing` mounts the game.

- [ ] **Step 4: Add App phases while keeping Svelte `onMount` synchronous**

In `App.svelte` add:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
type LaunchSource = 'new' | 'continue' | null;
```

State:

```ts
let appPhase = $state<AppPhase>('loading-save');
let launchSource = $state<LaunchSource>(null);
let saveRepository = $state.raw<SaveRepository | null>(null);
let loadedSave = $state.raw<SaveFileV1 | null>(null);
let initialState = $state.raw<GameState | null>(null);
let titleError = $state<string | null>(null);
```

Do **not** make the Svelte `onMount` callback async; Svelte lifecycle cleanup must remain synchronous. Extend the current `onMount` pattern:

```ts
onMount(() => {
  let disposed = false;

  void loadTitleState().then((titleState) => {
    if (disposed) return;
    saveRepository = titleState.repository;
    loadedSave = titleState.save;
    titleError = titleState.error;
    appPhase = 'title';
  });

  return () => {
    disposed = true;
    resetGamePresentation();
    handleFocus();
    inputGate.set('day-transition', false);
    inputGate.set('economy-panel', false);
  };
});
```

New Game:

```ts
launchSource = 'new';
initialState = null;
titleError = null;
appPhase = 'playing';
```

Continue:

```ts
if (!loadedSave) return;
launchSource = 'continue';
initialState = structuredClone(loadedSave.state);
titleError = null;
appPhase = 'playing';
```

- [ ] **Step 5: Carry initial state through Phaser without adding persistence imports there**

Add `initialState: GameState | null` to `GameHost` props/dependencies. Add to `ProofSceneDependencies` and construct:

```ts
this.session = new GameSession({
  // existing parsed authored config
  initialState: this.dependencies.initialState ?? undefined,
});
```

Add one read-only command:

```ts
export interface SceneCommands {
  state(): GameState;
  // existing commands unchanged
}
```

Implement as direct delegation to `GameSession.state()`.

No save repository/import belongs in Phaser.

- [ ] **Step 6: Distinguish launch failures from later runtime errors**

When a world becomes ready, clear launch intent immediately:

```ts
function handleReady(nextCommands: SceneCommands): void {
  commands = nextCommands;
  status = 'ready';
  error = null;
  launchSource = null;
}
```

In `handleError`, use `launchSource !== null` to identify a pre-ready New Game/Continue failure. For that branch:

```ts
const failedLaunch = launchSource;
resetGamePresentation();
appPhase = 'title';
titleError = nextError.message;
if (failedLaunch === 'continue') {
  loadedSave = null;
  initialState = null;
}
launchSource = null;
```

New Game remains available. Continue becomes disabled after an incompatible Continue attempt. If `launchSource` is already null, preserve the existing post-ready gameplay error behavior instead of sending unrelated runtime errors to title.

- [ ] **Step 7: Update the shared `waitForWorld` helper in the same task**

Change `tests/e2e/helpers.ts`:

```ts
export async function waitForWorld(page: Page): Promise<void> {
  await page.goto('/');
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  const newGame = page.locator('[data-new-game]');
  await expect(newGame).toBeEnabled();
  await newGame.click();
  await expect(page.getByText('World ready')).toBeVisible();
  await page.waitForFunction(() => Boolean(window.__PHOENIX_TEST__?.snapshot()));
}
```

Do not patch each existing spec.

- [ ] **Step 8: Run the full E2E suite immediately because every spec uses `waitForWorld`**

Run:

```bash
bun test tests/persistence/loadTitleState.test.ts
bun run check
bun run test:e2e
```

Expected: all existing Playwright specs enter through New Game and remain green. Do not use a grep subset here.

- [ ] **Step 9: Commit Task 4**

```bash
git add src/persistence/loadTitleState.ts tests/persistence/loadTitleState.test.ts src/components/TitleScreen.svelte src/App.svelte src/components/GameHost.svelte src/game/phaser/ProofScene.ts src/app.css tests/e2e/helpers.ts
git commit -m "feat: add Phoenix title and continue bootstrap"
```

---

## Task 5: Add unit-tested overnight save orchestration and a non-stale save-status/focus lifecycle

**Files:**
- Create: `src/persistence/persistOvernightSave.ts`
- Create: `tests/persistence/persistOvernightSave.test.ts`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `tests/e2e/helpers.ts`

**Interfaces:**
- Produces: `persistOvernightSave({ result, state, repository }): Promise<boolean>`
- Produces UI state: `SaveStatus = 'idle' | 'saving' | 'saved' | 'error'`
- Preserves: existing pending morning summary as the only day-transition lock surface and existing Start Day focus behavior

- [ ] **Step 1: Write RED transaction tests before touching App async behavior**

Create `tests/persistence/persistOvernightSave.test.ts`.

Test successful `day-advanced`:

```ts
const save = mock(() => Promise.resolve());
const repository = { load: async () => null, save } satisfies SaveRepository;
const wrote = await persistOvernightSave({
  result: { ok: true, code: 'day-advanced' },
  state,
  repository,
});
expect(wrote).toBe(true);
expect(save).toHaveBeenCalledTimes(1);
expect(save.mock.calls[0][0]).toEqual(createSaveFile(state));
```

Test skip behavior for both a failure and another success code:

```ts
for (const result of [
  { ok: false, code: 'not-at-bed' } as const,
  { ok: true, code: 'action-selected' } as const,
]) {
  expect(await persistOvernightSave({ result, state, repository })).toBe(false);
}
expect(save).not.toHaveBeenCalled();
```

Test `day-advanced` with `repository: null` rejects and repository rejection propagates. Neither branch may report success.

Run:

```bash
bun test tests/persistence/persistOvernightSave.test.ts
```

Expected RED: helper missing.

- [ ] **Step 2: Implement the narrow transaction helper**

Create:

```ts
export async function persistOvernightSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<boolean> {
  if (!input.result.ok || input.result.code !== 'day-advanced') return false;
  if (!input.repository) throw new Error('Save storage is unavailable');
  await input.repository.save(createSaveFile(input.state));
  return true;
}
```

No status, Svelte, Phaser, retries, rollback, or global repository access belongs here.

Run:

```bash
bun test tests/persistence/persistOvernightSave.test.ts
bun run check
```

Expected: GREEN.

- [ ] **Step 3: Add the exact save-status lifecycle to App**

Add:

```ts
type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
let saveStatus = $state<SaveStatus>('idle');
let saveError = $state<string | null>(null);
```

`resetGamePresentation()` resets:

```ts
saveStatus = 'idle';
saveError = null;
```

Make `confirmSleep()` async with exact ordering:

```ts
async function confirmSleep(): Promise<void> {
  if (!sleepPromptVisible || sleepSubmitting) return;
  const currentCommands = commands;
  if (!currentCommands) {
    sleepPromptVisible = false;
    syncDayTransition();
    return;
  }

  sleepSubmitting = true;
  syncDayTransition();
  try {
    const result = currentCommands.sleep();
    sleepPromptVisible = false;
    syncDayTransition();
    if (!result.ok || result.code !== 'day-advanced') return;

    saveStatus = 'saving';
    saveError = null;
    try {
      await persistOvernightSave({
        result,
        state: currentCommands.state(),
        repository: saveRepository,
      });
      saveStatus = 'saved';
    } catch (error) {
      saveStatus = 'error';
      saveError = error instanceof Error ? error.message : String(error);
    }
  } finally {
    sleepSubmitting = false;
    syncDayTransition();
  }
}
```

Do not roll back the already-completed day transition.

In `startDay()`, capture the command result. After successful `day-started`, reset:

```ts
saveStatus = 'idle';
saveError = null;
```

This happens every morning; `Saved` must not remain visible into the next day.

- [ ] **Step 4: Add only the required Overlay save surface/gate and preserve focus**

Pass `saveStatus` and `saveError` to `Overlay.svelte`.

Render:

```svelte
{#if saveStatus !== 'idle'}
  <p data-save-status>
    {#if saveStatus === 'saving'}
      Saving…
    {:else if saveStatus === 'saved'}
      Saved
    {:else}
      Save failed: {saveError ?? 'Unknown error'}
    {/if}
  </p>
{/if}
```

Change Start Day disable condition:

```svelte
disabled={summarySubmitting || commands === null || saveStatus === 'saving'}
```

Update the existing focus effect so it does not try to focus a disabled button and reruns when saving settles:

```ts
$effect(() => {
  if (sleepPromptVisible) {
    void tick().then(() => requestAnimationFrame(() => confirmButton?.focus()));
  } else if (summary && saveStatus !== 'saving') {
    void tick().then(() => requestAnimationFrame(() => startDayButton?.focus()));
  }
});
```

Because this effect now reads `saveStatus`, the transition from `saving` to `saved` or `error` focuses the enabled Start Day button and preserves the existing keyboard accessibility contract.

No new `InputGate` reason, toast, timer, retry button, spinner framework, or log panel.

- [ ] **Step 5: Fix the shared multi-night helper so it waits for this night's save and preserved focus**

In `tests/e2e/helpers.ts::confirmAndStartDay`, after existing morning-summary assertions:

```ts
const start = page.getByRole('button', { name: 'Start Day ' + nextDay });
await expect(page.locator('[data-save-status]')).toHaveText('Saved');
await expect(start).toBeEnabled();
await expect(start).toBeFocused();
await start.click();
await expect(dialog).toBeHidden();
await expect(page.locator('[data-save-status]')).toHaveCount(0);
```

Keep existing pending-summary-clear and input-unlock assertions.

Because Task 5 resets status to `idle` after each successful Start Day, night 2+ cannot satisfy the `Saved` wait from night 1.

- [ ] **Step 6: Verify transaction coverage and all multi-night browser flows**

Run:

```bash
bun test tests/persistence/persistOvernightSave.test.ts
bun run check
bun run test:e2e
bun run test:coverage
bun run coverage:check
```

Expected: GREEN. Farming/economy/social multi-night loops pass without arbitrary waits and Start Day focus is preserved after each save.

- [ ] **Step 7: Commit Task 5**

```bash
git add src/persistence/persistOvernightSave.ts tests/persistence/persistOvernightSave.test.ts src/App.svelte src/components/Overlay.svelte tests/e2e/helpers.ts
git commit -m "feat: autosave Phoenix overnight state"
```

---

## Task 6: Prove browser persistence, Continue, bad-save recovery, and incompatible-restore recovery

**Files:**
- Create: `tests/e2e/persistence.pw.ts`

**Interfaces:**
- Consumes only normal title/game UI, `localStorage`, and the existing observation-only test hook
- Adds no production test mutators

- [ ] **Step 1: Add fresh-title/New Game acceptance**

```ts
await page.goto('/');
await expect(page.locator('[data-title-screen]')).toBeVisible();
await expect(page.locator('[data-new-game]')).toBeEnabled();
await expect(page.locator('[data-continue]')).toBeDisabled();
await page.locator('[data-new-game]').click();
await expect(page.getByText('World ready')).toBeVisible();
```

- [ ] **Step 2: Add save/reload/Continue acceptance**

Use normal gameplay helpers to make one observable state change, reach bed, confirm sleep, and wait for `Saved`.

Before reload:

```ts
const savedMorning = await gameSnapshot(page);
expect(savedMorning.pendingDaySummary).not.toBeNull();
```

Reload and Continue:

```ts
await page.reload();
await expect(page.locator('[data-title-screen]')).toBeVisible();
await expect(page.locator('[data-continue]')).toBeEnabled();
await page.locator('[data-continue]').click();
await expect(page.getByText('World ready')).toBeVisible();
```

Assert restored gameplay state matches saved morning mutable/read-model fields, while player position is the authored map spawn. Verify the pending morning summary appears, then Start Day clears it normally.

- [ ] **Step 3: Add malformed browser storage recovery**

Before navigation:

```ts
await page.addInitScript(() => {
  localStorage.setItem('phoenix.save.v1', '{broken json');
});
```

Assert title visible, Continue disabled, title error visible, New Game enabled, and New Game reaches `World ready`.

- [ ] **Step 4: Add structurally valid but current-rule-invalid Continue recovery**

Create a real browser save through the normal sleep path, then mutate only saved `day` to `999` in `localStorage` while keeping valid JSON/V1 structure. Reload: Continue is initially enabled because structural parsing succeeds. Click Continue.

Expected:

```text
GameSession rejects initial state before ready
title becomes visible again
error is shown
Continue is disabled for that in-memory candidate
New Game remains enabled and can launch
```

This proves structural parsing/current-rule validation ownership and pre-ready return-to-title wiring.

- [ ] **Step 5: Run persistence acceptance and full regression suite**

Run:

```bash
bun run test:e2e tests/e2e/persistence.pw.ts
bun run test:e2e
```

Expected: GREEN.

- [ ] **Step 6: Commit Task 6**

```bash
git add tests/e2e/persistence.pw.ts
git commit -m "test: cover Phoenix persistence flow"
```

---

## Task 7: Document shipped persistence behavior and perform full desktop/clean verification

**Files:**
- Modify: `README.md`
- Modify: `tests/config/handoff.test.ts`
- Review: `CLAUDE.md` persistence architecture bullet added in Task 2

**Interfaces:**
- No new production API
- Final browser + desktop acceptance for HPA-596

- [ ] **Step 1: Update README handoff facts only**

Document:

- title has New Game and Continue;
- Continue is disabled without a valid save;
- sleeping autosaves completed next-morning state;
- browser development uses localStorage;
- Tauri uses Store;
- Continue resumes gameplay at authored spawn while preserving farm/economy/social/day-summary state;
- malformed/unsupported/incompatible saves leave New Game usable;
- save failures are visible and do not roll back the completed day transition.

Do not add migration/backups/manual-save claims or rewrite unrelated controls/content.

- [ ] **Step 2: Update handoff contract tests for new pinned README claims**

In `tests/config/handoff.test.ts`, add focused phrase assertions for persistence facts future tickets must preserve. Do not pin implementation class/file names that belong in CLAUDE/spec rather than player-facing README.

Run:

```bash
bun test tests/config/handoff.test.ts
```

Expected: GREEN.

- [ ] **Step 3: Commit handoff updates before clean-checkout verification**

`verify:clean` validates a git archive of `HEAD`, so the README/handoff changes must be committed before running it.

```bash
git add README.md tests/config/handoff.test.ts
git commit -m "docs: document Phoenix persistence"
```

- [ ] **Step 4: Run the full verification matrix on committed `HEAD`**

Run:

```bash
bun run check
bun run lint
bun run format:check
bun test
bun run test:coverage
bun run coverage:check
bun run test:e2e
bun run build
cargo check --manifest-path src-tauri/Cargo.toml
bun run tauri:build -- --no-sign
bun run verify:clean
```

Expected: all GREEN. Do not waive the 90% line/function coverage gate.

- [ ] **Step 5: Perform final product-level Tauri close/reopen acceptance**

Run:

```bash
bun run tauri:dev
```

In the Tauri app:

1. verify title appears;
2. New Game;
3. make one visible gameplay change;
4. sleep;
5. observe `Saved` while morning summary is present;
6. close the Tauri window;
7. relaunch `bun run tauri:dev`;
8. verify Continue is enabled;
9. Continue;
10. verify same morning state restored at authored spawn;
11. wait for Start Day to be enabled/focused;
12. Start Day and verify save-status surface returns to idle/hidden.

Record this smoke explicitly in implementation PR validation notes. This is the product proof the Task 3 plugin smoke cannot provide.

- [ ] **Step 6: Run final diff/scope checks**

Run:

```bash
git diff --check main...HEAD
git status --short
```

Review diff and confirm no authored map/assets, `InputGate`, gameplay cost/content values, CI workflow shape, desktop WebDriver setup, migration framework, or unrelated refactor entered HPA-596.

---

## Plan Self-Review

- HPA-596 remains one PR and one coherent persistence slice.
- `GameState` is canonical and `GameSnapshot` derives mutable fields from it.
- Primary round-trip proof is command-driven across farming, economy/shipping, social, and overnight behavior rather than a hand-enumerated full-state fixture.
- `GameSession` owns current-rule ranges and authored farm identity; `parseSaveFile` owns only structural V1 parsing.
- Rule-invalid state cannot boot into day/time/stamina/count/growth soft-locks.
- Restored farm tiles explicitly rebuild `farmTilesByKey`, and a real post-restore plant command proves it.
- Shared parser primitives are extracted once from `loadProofMap.ts`; persistence does not fork them.
- `loadTitleState` unit-tests repository creation/load/parse branches before Svelte wiring.
- App starts title loading from a synchronous `onMount` and ignores late async resolution after cleanup.
- `launchSource` is cleared in `handleReady`, so only genuine pre-ready failures return to title.
- `persistOvernightSave` unit-tests exactly-once/skip/unavailable/rejection branches before App wiring.
- Vite prefix is literal `TAURI_ENV_`, typed in `src/vite-env.d.ts`, and pinned by scaffold tests.
- Task 3 performs a real Tauri Store smoke immediately after plugin/capability wiring.
- Save status resets to `idle` on successful Start Day and presentation reset, so multi-night `Saved` waits cannot pass stale.
- Overlay defers Start Day focus while `saving` and refocuses automatically when the button becomes enabled.
- Task 4 runs full E2E after changing `waitForWorld`; Task 5 runs full E2E after changing `confirmAndStartDay`.
- `tests/persistence/` mirrors the new top-level persistence layer rather than misclassifying application/platform tests as game rules.
- `CLAUDE.md` documents persistence -> core dependency direction and App as runtime coordinator.
- README/handoff updates are committed before `verify:clean`, so clean-checkout validation sees the final documented state.
- Risks explicitly cover Store runtime wiring and shared E2E helper coupling.
- No new input-lock reason, test-hook mutator, state framework, schema framework, migration system, Store fallback, custom Rust save command, or desktop WebDriver harness is introduced.