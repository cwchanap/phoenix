# Phoenix Persistence Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for core state/parser/repository/orchestration work, keep each task type-green before moving on, and deliver HPA-596 in this single PR.

**Goal:** Deliver HPA-596 with one versioned autosave slot, New Game/Continue title flow, browser `localStorage`, Tauri Store persistence, complete current gameplay-state round trips, fixed-spawn restore, and visible save failures.

**Architecture:** `GameSession` remains the only mutable gameplay authority and gains the canonical `state(): GameState` projection. `GameSnapshot` derives from that state plus world/presentation data. `SaveFileV1` only wraps/parses the state envelope; `SaveRepository` owns storage adapters; `persistOvernightSave` is the small testable transaction seam used by App after `sleep()`. Phaser carries optional initial state and exposes a read-only `SceneCommands.state()` accessor. Tauri only supplies Store.

**Tech Stack:** Bun 1.3.1 and `bun:test`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.x, `@tauri-apps/plugin-store` 2.4.4, current Rust/Cargo toolchain.

**Spec:** `docs/superpowers/specs/2026-08-18-phoenix-persistence-slice-design.md`

## Global constraints

- Implement only HPA-596. Do not start HPA-597 finale/content or HPA-599 release polish.
- Keep HPA-596 as one PR; continue implementation on this planning PR after approval.
- Keep `GameSession` as the only mutable gameplay authority.
- Persist mutable gameplay state only; never persist player position/facing/target, camera, projected/world coordinates, Tiled objects, Phaser objects, or Svelte state.
- Continue always reconstructs `ProofWorld` from the current authored map and therefore resumes at the authored map spawn.
- Persist `pendingDaySummary`, selected action/seed, farming/economy/shipment state, relationship daily flags, and one-time dialogue flags.
- Derive `maxStamina` and relationship level; do not save them redundantly.
- Save only after successful `sleep()` returns `day-advanced`.
- One successful overnight transition performs exactly one repository `save()` call.
- Tauri Store uses `autoSave: false` plus explicit `store.save()`.
- Do not roll back a successful day transition when persistence fails.
- Continue is enabled only for a structurally parsed V1 and is disabled if restore later proves incompatible with the current authored map.
- Malformed/unsupported/incompatible saves must return to a usable title with New Game enabled.
- No migrations, backwards compatibility, backups, save rotation, multiple slots, manual save, cloud sync, compression, encryption, or custom Rust save command.
- Do not add state-management, schema, JSDOM, service-locator, registry, or plugin frameworks.
- Keep `window.__PHOENIX_TEST__` observation-only.
- Keep existing Playwright retries/timeouts; fix shared helpers rather than adding sleeps.
- Use exact Vite `envPrefix: ['VITE_', 'TAURI_ENV_']`; `*` is not a glob in Vite prefix matching.

## File map

### Core state/restore

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `tests/game/GameSession.test.ts`

### Save format/storage/orchestration

- Create `src/persistence/saveFile.ts`
- Create `src/persistence/saveRepository.ts`
- Create `src/persistence/persistOvernightSave.ts`
- Create `tests/game/saveFile.test.ts`
- Create `tests/game/saveRepository.test.ts`
- Create `tests/game/persistOvernightSave.test.ts`

### Tauri/Vite integration

- Modify `vite.config.ts`
- Modify `src/vite-env.d.ts`
- Modify `package.json`
- Modify `bun.lock`
- Modify `src-tauri/Cargo.toml`
- Modify `src-tauri/Cargo.lock`
- Modify `src-tauri/src/lib.rs`
- Modify `src-tauri/capabilities/default.json`
- Modify `tests/config/scaffold.test.ts`

### Title/game bridge

- Create `src/components/TitleScreen.svelte`
- Modify `src/App.svelte`
- Modify `src/components/GameHost.svelte`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/app.css`
- Modify `tests/e2e/helpers.ts`

### Autosave presentation

- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`
- Modify `tests/e2e/helpers.ts`

### Acceptance/handoff

- Create `tests/e2e/persistence.pw.ts`
- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

No planned changes: `src/assets/**`, `tools/generate-proof-assets.ts`, `src/game/core/ProofWorld.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`, crop/villager definitions, `src/game/phaser/loadProofMap.ts`, `.github/workflows/ci.yml`, or `playwright.config.ts`.

---

## Task 1: Make `GameSession.state()` the single persisted projection and restore it safely

**Files**

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `tests/game/GameSession.test.ts`

**Produces**

```ts
export interface RelationshipState {
  points: number;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
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
```

### Step 1: Write `state()` and restore RED tests

Add tests to `GameSession.test.ts` for a non-default representative session state.

The fixture/arrangement must exercise:

- non-default day/time/stamina/weather;
- selected action/seed;
- money and all crop-count records;
- at least one tilled empty tile and one growing crop;
- non-zero pending shipment;
- all three relationships with daily flags and one `closeFriendDialogueSeen: true`;
- a non-null pending morning summary.

Assert:

```ts
expect(session.state()).toEqual(expectedState);
expect(session.state()).not.toBe(session.state());
expect(restored.snapshot().player.position).toEqual({ x: 2.5, y: 9.5 });
```

Mutate nested values on one returned state and prove the next `state()` call is unchanged.

Add current-map identity RED cases:

- one saved farm cell moved to a foreign coordinate;
- duplicate saved farm coordinate;
- missing current villager relationship.

Expected failure prefix:

```text
GameSession: invalid initial state
```

Finally add a post-restore behavior assertion. Restore a tile that is already tilled and empty, target it normally, select seeds, and plant successfully. This test must fail if `farmTilesByKey` still points at default untilled objects.

Run:

```bash
bun test tests/game/GameSession.test.ts
```

Expected RED: `RelationshipState`, `GameState`, `state()`, and `initialState` do not exist.

### Step 2: Promote relationship state and define `GameState`

Replace the private `MutableRelationship` shape with imported `RelationshipState`.

Keep snapshot relationship level derived:

```ts
export interface RelationshipSnapshot extends RelationshipState {
  level: RelationshipLevel;
}
```

Define `GameSnapshot` so current mutable fields come from `GameState` rather than being repeated independently:

```ts
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

This makes future `GameState` fields flow into the snapshot type automatically.

### Step 3: Add the canonical `state()` method

Implement `GameSession.state()` by cloning the mutable fields once:

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

Use small local clone helpers; do not create a generic serializer.

Change `snapshot()` to begin with:

```ts
const state = this.state();
const worldSnapshot = this.world.snapshot();
```

and spread `...state`, overriding only relationships with their derived levels and adding the existing world/maxStamina/interaction-cell fields.

### Step 4: Restore into existing containers and rebuild the farm lookup map

Extend config:

```ts
initialState?: GameState;
```

After current authored config validation and default container creation, validate the saved farm-cell set against the current authored farm cells.

Apply restored farm tiles explicitly:

```ts
const restoredTiles = initialState.farmTiles.map(cloneFarmTile);
this.farmTiles.splice(0, this.farmTiles.length, ...restoredTiles);
this.farmTilesByKey.clear();
for (const tile of this.farmTiles) {
  this.farmTilesByKey.set(cellKey(tile.position), tile);
}
```

Clone scalar/count/relationship/day-summary fields into the current session. Do not replace `ProofWorld`; it stays constructed from the current authored map.

### Step 5: Verify

Run:

```bash
bun test tests/game/GameSession.test.ts
bun run check
```

Expected GREEN, including the post-restore plant/lookup regression.

### Step 6: Commit

```bash
git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts
git commit -m "feat: add restorable Phoenix game state"
```

---

## Task 2: Add the V1 envelope with structural validation only

**Files**

- Create `src/persistence/saveFile.ts`
- Create `tests/game/saveFile.test.ts`

**Consumes**

```ts
GameState
RelationshipState
```

**Produces**

```ts
export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

export function createSaveFile(state: GameState): SaveFileV1;
export function parseSaveFile(value: unknown): SaveFileV1;
```

### Step 1: Write envelope/parser RED tests

Cover:

```ts
const file = createSaveFile(state);
expect(file).toEqual({ schemaVersion: 1, state });
expect(parseSaveFile(structuredClone(file))).toEqual(file);
```

Mutate the original nested state after `createSaveFile()` and prove the file is unchanged.

Reject:

- non-object input;
- missing/wrong `schemaVersion`;
- missing current state fields;
- unsupported weather/action/seed/crop IDs;
- unsafe/fractional numeric values;
- malformed crop-count records;
- malformed farm tile/crop object shape;
- malformed relationship records;
- malformed pending day-summary shipment lines.

Do **not** reject a structurally valid farm tile array merely because its coordinates do not match the current authored nine-cell farm. Add an explicit test proving such a file passes `parseSaveFile()`; Task 1 `GameSession` owns that rejection.

Run:

```bash
bun test tests/game/saveFile.test.ts
```

Expected RED: module missing.

### Step 2: Implement small explicit structural helpers

Keep all helpers private to `saveFile.ts`, for example:

```ts
function record(value: unknown, path: string): Record<string, unknown>;
function safeInt(value: unknown, path: string): number;
function oneOf<T extends string>(value: unknown, values: readonly T[], path: string): T;
function parseCounts(value: unknown, path: string): CropCounts;
function parseFarmTiles(value: unknown): FarmTileSnapshot[];
function parseRelationships(value: unknown): Record<VillagerId, RelationshipState>;
function parseDaySummary(value: unknown): DaySummary | null;
```

Every thrown parser error starts with:

```text
Invalid save:
```

No Zod, JSON Schema, version registry, migration table, or map coordinates belong here.

### Step 3: Implement V1 wrap/clone

`createSaveFile()` deep-clones the plain `GameState`. `parseSaveFile()` returns a fresh `SaveFileV1`, not the caller's original nested references.

Run:

```bash
bun test tests/game/saveFile.test.ts
bun run check
```

Expected GREEN.

### Step 4: Commit

```bash
git add src/persistence/saveFile.ts tests/game/saveFile.test.ts
git commit -m "feat: add Phoenix V1 save envelope"
```

---

## Task 3: Add localStorage/Tauri Store repositories with the correct Vite selector

**Files**

- Create `src/persistence/saveRepository.ts`
- Create `tests/game/saveRepository.test.ts`
- Modify `vite.config.ts`
- Modify `src/vite-env.d.ts`
- Modify `package.json`
- Modify `bun.lock`
- Modify `src-tauri/Cargo.toml`
- Modify `src-tauri/Cargo.lock`
- Modify `src-tauri/src/lib.rs`
- Modify `src-tauri/capabilities/default.json`
- Modify `tests/config/scaffold.test.ts`

### Step 1: Write repository RED tests

Define:

```ts
export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}
```

Use a tiny fake `Storage` object; do not add JSDOM.

Browser adapter tests:

- absent `phoenix.save.v1` -> `null`;
- one save writes exactly that key;
- load JSON-parses the stored object;
- malformed JSON rejects;
- storage exceptions propagate.

Factory/Tauri tests use a narrow injected environment seam:

```ts
interface SaveRepositoryEnvironment {
  tauriPlatform?: string;
  storage: Storage;
  loadTauriStore: () => Promise<TauriStoreLike>;
}
```

Assert:

- missing `tauriPlatform` chooses localStorage and never calls Store loader;
- present `tauriPlatform` calls Store loader once;
- Store load failure rejects and does not fall back to localStorage;
- Store save performs one `set('save', file)` and one explicit `save()`;
- missing Store `save` entry loads as `null`.

### Step 2: Fix Vite env exposure and TypeScript typing

Update `vite.config.ts` exactly:

```ts
export default defineConfig({
  plugins: [svelte()],
  envPrefix: ['VITE_', 'TAURI_ENV_'],
  // existing server config
});
```

Do not use `TAURI_ENV_*`; Vite checks literal prefixes.

In `src/vite-env.d.ts` add:

```ts
interface ImportMetaEnv {
  readonly TAURI_ENV_PLATFORM?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

Keep the existing Phoenix test-hook declarations.

### Step 3: Add the Store dependency and adapters

Add exactly:

```json
"@tauri-apps/plugin-store": "2.4.4"
```

to runtime dependencies and regenerate `bun.lock` with Bun.

Production selection is one branch in `createSaveRepository()`:

```ts
const tauriPlatform = import.meta.env.TAURI_ENV_PLATFORM;
```

When absent, return `LocalStorageSaveRepository(window.localStorage)`.

When present, dynamically import Store and load:

```ts
const { load } = await import('@tauri-apps/plugin-store');
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});
```

Do not statically import Store into the browser path and do not catch Store initialization to fall back to localStorage.

### Step 4: Register the Tauri plugin

Add:

```toml
tauri-plugin-store = "=2.4.4"
```

Register:

```rs
tauri::Builder::default()
    .plugin(tauri_plugin_store::Builder::default().build())
```

Add `"store:default"` to `src-tauri/capabilities/default.json`.

Regenerate `Cargo.lock` through Cargo.

### Step 5: Update scaffold contract tests

`tests/config/scaffold.test.ts` currently pins direct JS dependencies exactly. Update it for Store and add exact assertions for:

```ts
expect(viteConfigText).toContain("envPrefix: ['VITE_', 'TAURI_ENV_']");
expect(viteConfigText).not.toContain('TAURI_ENV_*');
```

Also assert the Cargo Store pin, Rust plugin registration, and `store:default` capability.

Run:

```bash
bun test tests/game/saveRepository.test.ts tests/config/scaffold.test.ts
bun run check
cargo check --manifest-path src-tauri/Cargo.toml
```

Expected GREEN.

### Step 6: Commit

```bash
git add vite.config.ts src/vite-env.d.ts package.json bun.lock src/persistence/saveRepository.ts tests/game/saveRepository.test.ts src-tauri tests/config/scaffold.test.ts
git commit -m "feat: add Phoenix save repositories"
```

---

## Task 4: Add title bootstrap, restore bridge, and update shared New Game E2E entry

**Files**

- Create `src/components/TitleScreen.svelte`
- Modify `src/App.svelte`
- Modify `src/components/GameHost.svelte`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/app.css`
- Modify `tests/e2e/helpers.ts`

### Step 1: Add the title component

`TitleScreen.svelte` props:

```ts
interface Props {
  loading: boolean;
  canContinue: boolean;
  error: string | null;
  onNewGame: () => void;
  onContinue: () => void;
}
```

Stable selectors:

```text
data-title-screen
data-new-game
data-continue
data-title-error
```

Continue is disabled while loading or without a usable save. New Game remains enabled after load/validation errors.

### Step 2: Add App phase/bootstrap state

In `App.svelte` add:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
type LaunchSource = 'new' | 'continue' | null;
```

Startup `onMount` sequence:

1. `createSaveRepository()`;
2. `repository.load()`;
3. absent -> title/no Continue;
4. `parseSaveFile()` success -> title/Continue enabled;
5. rejection -> title error/Continue disabled/New Game enabled.

Keep repository `null` if repository initialization itself fails. New Game can still launch; Task 5 will surface save-unavailable on sleep.

### Step 3: Mount Phaser only in playing phase

Render `TitleScreen` inside `StageFrame` for loading/title phases. Render `GameHost`, `Overlay`, and dialogue only for `playing`.

New Game:

```ts
initialState = null;
launchSource = 'new';
phase = 'playing';
```

Continue:

```ts
initialState = structuredClone(loadedSave!.state);
launchSource = 'continue';
phase = 'playing';
```

Do not delete the old save on New Game.

### Step 4: Thread initial state and expose read-only scene state

Add `initialState: GameState | null` to `GameHost` props and `ProofSceneDependencies`.

Construct:

```ts
this.session = new GameSession({
  // existing authored map config
  initialState: this.dependencies.initialState ?? undefined,
});
```

Add to `SceneCommands`:

```ts
state(): GameState;
```

with implementation:

```ts
state: () => this.requireSession().state(),
```

No separate `onGameState` callback is added.

### Step 5: Return pre-ready world failures to title

Track whether current launch has reached `handleReady`.

When `handleError` occurs before ready:

- call existing presentation reset;
- set `phase = 'title'`;
- show the error as `titleError`;
- keep New Game enabled;
- if `launchSource === 'continue'`, set `loadedSave = null` so Continue is disabled.

This handles a structurally valid V1 whose authored farm identity is rejected by `GameSession` and avoids stranding the player in Overlay error with no return-to-title path.

### Step 6: Fix `waitForWorld` in the same task

Change `tests/e2e/helpers.ts::waitForWorld` from direct world wait to the normal New Game flow:

```ts
export async function waitForWorld(page: Page): Promise<void> {
  await page.goto('/');
  await expect(page.locator('[data-title-screen]')).toBeVisible();
  await page.locator('[data-new-game]').click();
  await expect(page.getByText('World ready')).toBeVisible();
  await page.waitForFunction(() => Boolean(window.__PHOENIX_TEST__?.snapshot()));
}
```

Do not patch every existing E2E spec individually.

### Step 7: Verify

Run:

```bash
bun run check
bun run test:e2e --grep "world|lifecycle"
```

Expected: existing world/lifecycle tests enter through New Game and reach the same world.

### Step 8: Commit

```bash
git add src/components/TitleScreen.svelte src/App.svelte src/components/GameHost.svelte src/game/phaser/ProofScene.ts src/app.css tests/e2e/helpers.ts
git commit -m "feat: add Phoenix title and continue bootstrap"
```

---

## Task 5: Unit-test the overnight save transaction and wire save feedback/gating

**Files**

- Create `src/persistence/persistOvernightSave.ts`
- Create `tests/game/persistOvernightSave.test.ts`
- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`
- Modify `tests/e2e/helpers.ts`

### Step 1: Write transaction RED tests before changing App

Implement tests around this exact interface:

```ts
export async function persistOvernightSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<boolean>;
```

Use a fake repository with a save-call counter.

Cases:

```ts
expect(await persistOvernightSave({
  result: { ok: true, code: 'day-advanced' },
  state,
  repository,
})).toBe(true);
expect(saveCalls).toBe(1);
```

Also verify:

- repository rejection rejects and still records only one attempted save;
- `repository: null` with `day-advanced` rejects `Save storage unavailable`;
- `{ ok: true, code: 'soil-tilled' }` returns `false` and does not save;
- a failure result returns `false` and does not save.

Run:

```bash
bun test tests/game/persistOvernightSave.test.ts
```

Expected RED: helper missing.

### Step 2: Implement the narrow transaction helper

Implementation shape:

```ts
export async function persistOvernightSave({ result, state, repository }: Input) {
  if (!result.ok || result.code !== 'day-advanced') return false;
  if (!repository) throw new Error('Save storage unavailable');
  await repository.save(createSaveFile(state));
  return true;
}
```

Do not put UI status, retries, environment detection, or state ownership in this helper.

### Step 3: Add save presentation state

In `App.svelte`:

```ts
type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
```

Track `saveStatus` and `saveError` for the current gameplay run.

Pass both to `Overlay.svelte`.

`Overlay` renders:

```text
data-save-status
```

with exact user-visible states:

```text
Saving…
Saved
Save failed: <message>
```

No toast/timer/retry UI.

### Step 4: Convert `confirmSleep` to the tested transaction ordering

Keep the command itself synchronous and call it once:

```ts
const result = currentCommands.sleep();
sleepPromptVisible = false;
```

For `day-advanced`:

```ts
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
} finally {
  sleepSubmitting = false;
  syncDayTransition();
}
```

For non-`day-advanced`, clear submission state without saving.

Do not roll back `GameSession.sleep()` if storage fails.

### Step 5: Gate Start Day only while a write is in flight

Change the morning-summary button condition to include:

```svelte
disabled={summarySubmitting || commands === null || saveStatus === 'saving'}
```

The existing pending summary remains the input lock; do not add another `InputGate` reason.

### Step 6: Fix `confirmAndStartDay` in the same task

After existing morning-summary assertions, change the shared helper to wait for persistence:

```ts
await expect(page.locator('[data-save-status]')).toHaveText('Saved');
await expect(start).toBeEnabled();
await start.click();
```

Keep the existing focus, summary-clear, and input-unlock assertions. Do not use a fixed timeout/sleep.

### Step 7: Verify unit and targeted browser behavior

Run:

```bash
bun test tests/game/persistOvernightSave.test.ts
bun run check
bun run test:e2e tests/e2e/sleep-confirmation.pw.ts
```

Expected GREEN, and the existing sleep helper no longer races the save gate.

### Step 8: Commit

```bash
git add src/persistence/persistOvernightSave.ts tests/game/persistOvernightSave.test.ts src/App.svelte src/components/Overlay.svelte tests/e2e/helpers.ts
git commit -m "feat: autosave completed Phoenix mornings"
```

---

## Task 6: Add persistence acceptance without mutating test hooks

**Files**

- Create `tests/e2e/persistence.pw.ts`

### Step 1: Fresh-title acceptance

Navigate directly without `waitForWorld` because this test needs the title itself.

Assert:

```ts
await expect(page.locator('[data-title-screen]')).toBeVisible();
await expect(page.locator('[data-continue]')).toBeDisabled();
await expect(page.locator('[data-new-game]')).toBeEnabled();
```

Click New Game and wait for the existing observation-only world hook.

### Step 2: Real autosave/reload/continue acceptance

Through normal UI/input:

1. make one representative farm or social mutation;
2. reach the bed and open sleep confirmation;
3. Confirm;
4. assert `data-save-status` becomes `Saved` while the morning summary is visible;
5. capture the pending `gameSnapshot()` fields relevant to the mutation/day transition;
6. reload the page;
7. assert title Continue enabled;
8. click Continue;
9. assert the restored pending summary/gameplay fields equal the pre-reload state;
10. assert player position is the authored spawn rather than the pre-sleep travel position;
11. Start Day and verify the summary clears.

Do not add setters/teleports/save hooks to `window.__PHOENIX_TEST__`.

### Step 3: Malformed browser save recovery

Use Playwright browser storage setup only to place malformed raw localStorage before application bootstrap:

```js
localStorage.setItem('phoenix.save.v1', '{bad json');
```

Reload and assert:

- title error visible;
- Continue disabled;
- New Game enabled;
- New Game still launches the world.

This is storage setup, not a game-state mutation hook.

### Step 4: Run the focused spec, then the full E2E suite

```bash
bun run test:e2e tests/e2e/persistence.pw.ts
bun run test:e2e
```

The full suite is required here because the title and save gate affect every test using shared helpers.

### Step 5: Commit

```bash
git add tests/e2e/persistence.pw.ts
git commit -m "test: cover Phoenix save and continue flow"
```

---

## Task 7: Update handoff contracts and run the complete release-quality verification

**Files**

- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

### Step 1: Document only shipped HPA-596 behavior

README adds concise player/developer facts:

- title has New Game and Continue;
- Continue uses the one autosave slot;
- autosave occurs after successful sleep/new-morning transition;
- browser development uses localStorage;
- Tauri uses Store;
- restore starts at the authored morning spawn;
- malformed/unsupported saves disable Continue but leave New Game available;
- save failure is visible.

Do not document slots, manual save, migrations, backups, or cloud sync.

### Step 2: Update pinned handoff assertions

Update `tests/config/handoff.test.ts` only for the new README facts. Keep the existing verification-command and CI-job contracts unchanged.

Run:

```bash
bun test tests/config/handoff.test.ts
```

Expected GREEN.

### Step 3: Run full automated verification

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

Do not declare completion if any gate is red.

### Step 4: Perform the required real Tauri Store smoke

Run:

```bash
bun run tauri:dev
```

Manual smoke:

1. New Game.
2. Make one visible gameplay change.
3. Sleep and observe `Saved` before starting the new day.
4. Close the Tauri window.
5. Relaunch `bun run tauri:dev`.
6. Verify Continue is enabled.
7. Continue.
8. Verify the same pending morning/gameplay state at the authored spawn.
9. Start the day successfully.

Record this exact smoke in the PR validation notes. Do not replace it with a browser-localStorage result.

### Step 5: Commit

```bash
git add README.md tests/config/handoff.test.ts
git commit -m "docs: document Phoenix autosave and continue"
```

---

## Self-review checklist before implementation starts

- Every HPA-596 acceptance criterion maps to a task above.
- `GameSession.state()` is the only mutable-rule projection; `saveFile.ts` does not maintain a second field-selection list.
- `parseSaveFile` checks structure; `GameSession` checks authored farm identity.
- Restored farm tiles rebuild `farmTilesByKey`, and a command-after-restore test proves it.
- Vite prefix is literal `TAURI_ENV_`, not `TAURI_ENV_*`.
- `src/vite-env.d.ts` types `TAURI_ENV_PLATFORM`.
- `waitForWorld` clicks New Game in Task 4, so existing E2E specs are not stranded at title.
- `confirmAndStartDay` waits for `Saved`/enabled Start Day in Task 5, so existing E2E specs do not race autosave.
- `persistOvernightSave` has Bun unit tests for success, rejection, unavailable repository, and skip branches before App wiring.
- A pre-ready restore failure returns to title and disables Continue for the incompatible loaded save.
- No new input-lock reason, desktop WebDriver harness, migration system, state library, or custom Rust persistence command was introduced.
