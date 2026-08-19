# Phoenix Persistence Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for pure state/parser/repository work, keep each task type-green before moving on, and deliver HPA-596 as one implementation PR.

**Goal:** Deliver HPA-596 with one versioned autosave slot, a New Game/Continue title screen, browser `localStorage`, Tauri Store persistence, complete current gameplay-state round trips, fixed-spawn restore, and visible save failures.

**Architecture:** `GameSession` remains the only mutable gameplay authority. A new plain `GameState` DTO contains only mutable rules state; `SaveFileV1` validates/serializes it; `SaveRepository` has exactly two adapters selected once at startup. Svelte owns title/bootstrap/save-status orchestration. Phaser receives optional initial state but never owns persistence. Tauri only supplies the Store plugin.

**Tech Stack:** Bun 1.3.1 and `bun:test`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.x, `@tauri-apps/plugin-store` 2.4.4, current Rust/Cargo toolchain.

**Spec:** `docs/superpowers/specs/2026-08-18-phoenix-persistence-slice-design.md`

## Global constraints

- Implement only HPA-596. Do not start HPA-597 finale/content or HPA-599 release polish.
- Deliver the implementation as one PR for HPA-596.
- Keep `GameSession` as the only mutable gameplay authority.
- Persist mutable gameplay state only; do not persist player position/facing/target, camera, projected/world coordinates, Tiled objects, Phaser objects, or Svelte state.
- Continue always reconstructs `ProofWorld` from the current authored map and therefore resumes at the existing map spawn.
- Persist `pendingDaySummary`; reopening immediately after autosave must still show the blocking morning summary until `Start Day N`.
- Persist selected action/seed and all current farming, economy, shipment, relationship, daily-flag, and one-time-dialogue state.
- Derive `maxStamina` and relationship level; do not save them redundantly.
- Save only after successful `sleep()` returns `day-advanced` and the post-sleep snapshot has been published.
- One successful sleep performs at most one repository `save()` call.
- Tauri Store uses explicit `store.save()` with plugin `autoSave: false`.
- No rollback of the successful day transition if the persistence write fails; show the failure and let the player continue after the attempt settles.
- Continue is enabled only for a successfully parsed V1 save.
- Malformed/unsupported saves never crash or soft-lock the title; New Game remains available.
- No migrations, backwards compatibility, backups, save rotation, slots, manual save, cloud sync, compression, encryption, or custom Rust save command.
- Do not add a state management library, schema library, JSDOM, persistence service locator, registry, or plugin framework.
- Keep `window.__PHOENIX_TEST__` observation-only.
- Keep existing Playwright retries/timeouts and movement helpers; do not mask flakes with arbitrary sleeps.
- Add only the Store plugin dependency. Browser/Tauri selection is build/runtime configuration at the repository factory, not scattered environment checks.
- Expose only safe `TAURI_ENV_*` variables through Vite; never expose a broad `TAURI_` prefix.

## File map

### Gameplay state and restore

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `tests/game/GameSession.test.ts`

### Save format and storage boundary

- Create `src/persistence/saveFile.ts`
- Create `src/persistence/saveRepository.ts`
- Create `tests/game/saveFile.test.ts`
- Create `tests/game/saveRepository.test.ts`

### Tauri Store integration

- Modify `vite.config.ts`
- Modify `package.json`
- Modify `bun.lock`
- Modify `src-tauri/Cargo.toml`
- Modify `src-tauri/Cargo.lock`
- Modify `src-tauri/src/lib.rs`
- Modify `src-tauri/capabilities/default.json`
- Modify `tests/config/scaffold.test.ts`

### Title/bootstrap/restore bridge

- Create `src/components/TitleScreen.svelte`
- Modify `src/App.svelte`
- Modify `src/components/GameHost.svelte`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/app.css`

### Autosave feedback

- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`

### Acceptance/handoff

- Create `tests/e2e/persistence.pw.ts`
- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

No planned changes: `src/assets/**`, `tools/generate-proof-assets.ts`, `src/game/core/ProofWorld.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`, crop/villager definitions, `src/game/phaser/loadProofMap.ts`, `.github/workflows/ci.yml`, or `playwright.config.ts`.

---

## Task 1: Define serializable gameplay state and restore it in `GameSession`

**Files**

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `tests/game/GameSession.test.ts`

### Step 1: Write restore RED tests

Add focused tests that construct a full current-version `GameState` fixture and pass it as `initialState` to a new `GameSession`.

The fixture must contain non-default values for every persisted field:

- day/time/stamina/weather;
- selected action and seed;
- money;
- seed/crop inventory;
- pending shipment;
- all nine farm tiles with at least one tilled empty tile and one growing crop;
- all three relationship records with points/daily flags and one `closeFriendDialogueSeen: true`;
- one non-null pending day summary with shipment lines.

Assert the resulting `GameSnapshot` matches those gameplay values, while:

```ts
expect(restored.snapshot().player.position).toEqual({ x: 2.5, y: 9.5 });
```

and the saved state contains no player/camera data.

Also add RED cases for duplicate/foreign farm cells and missing relationship entries. Invalid restore input must throw a `GameSession: invalid initial state ...` error rather than partially mutating.

Run:

```bash
bun test tests/game/GameSession.test.ts
```

Expected RED: `GameState`, `RelationshipState`, and `initialState` do not exist.

### Step 2: Add the state types

In `types.ts`, split persisted relationship data from the derived snapshot field:

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
```

Do not add `player`, `target`, `maxStamina`, interaction cells, or relationship `level`.

### Step 3: Restore optional state in the existing constructor

Extend:

```ts
export interface GameSessionConfig {
  // existing authored config
  initialState?: GameState;
}
```

Keep current authored-world validation first. After the normal farm/relationship containers exist, if `initialState` is present:

- validate current closed unions and numeric invariants;
- require exact farm-cell identity against the current nine authored farm cells;
- require all current `VILLAGER_IDS` exactly once;
- deep-clone arrays/records/summary lines into the existing mutable fields.

Do not create a second constructor/factory or generic hydration framework.

### Step 4: Keep snapshot semantics unchanged

`GameSnapshot` still exposes derived relationship levels and authored interaction cells for rendering/tests. Update helper typing only as needed to clone `RelationshipState` into `RelationshipSnapshot`.

Run:

```bash
bun test tests/game/GameSession.test.ts
bun run check
```

Expected GREEN.

### Step 5: Commit

```bash
git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts
git commit -m "feat: restore Phoenix gameplay state"
```

---

## Task 2: Add V1 save parsing and the browser repository

**Files**

- Create `src/persistence/saveFile.ts`
- Create `src/persistence/saveRepository.ts`
- Create `tests/game/saveFile.test.ts`
- Create `tests/game/saveRepository.test.ts`

### Step 1: Write save-file RED tests

Use a complete `GameSnapshot` fixture and test:

```ts
const file = createSaveFile(snapshot);
expect(file.schemaVersion).toBe(1);
expect(parseSaveFile(structuredClone(file))).toEqual(file);
```

Mutate the source snapshot after creation and assert the save is unchanged.

Assert the saved `state` does not contain:

```ts
player
target
maxStamina
bedCell
shopCell
shippingCell
villagerCells
```

and relationship entries do not contain `level`.

Add invalid cases for:

- non-object input;
- missing `schemaVersion`;
- version 0/2/string version;
- missing state fields;
- invalid weather/action/seed/crop kind;
- non-safe integer counts/money/day/time/stamina/growth;
- duplicate/malformed farm positions;
- malformed relationship records;
- malformed pending day summary/shipments.

Run:

```bash
bun test tests/game/saveFile.test.ts
```

Expected RED: module missing.

### Step 2: Implement one V1 codec without dependencies

Create:

```ts
export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

export function gameStateFromSnapshot(snapshot: GameSnapshot): GameState;
export function createSaveFile(snapshot: GameSnapshot): SaveFileV1;
export function parseSaveFile(value: unknown): SaveFileV1;
```

Keep validation as small explicit type guards/assertion helpers inside this module. Return fresh cloned records/arrays. Throw messages prefixed with `Invalid save:`.

Do not create `v1/`, migration registries, schemas, or codecs for nonexistent versions.

### Step 3: Write browser repository RED tests

Define the boundary:

```ts
export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}
```

Using a tiny in-memory object implementing the few `Storage` methods needed, test:

- missing key -> `null`;
- one save writes exactly key `phoenix.save.v1`;
- load returns parsed JSON object;
- malformed stored JSON rejects with a clear error;
- storage exceptions propagate.

### Step 4: Implement `LocalStorageSaveRepository`

No adapter-side schema validation. It only JSON parses/stringifies and lets the shared parser decide if the object is a valid V1 save.

Run:

```bash
bun test tests/game/saveFile.test.ts tests/game/saveRepository.test.ts
bun run check
```

Expected GREEN.

### Step 5: Commit

```bash
git add src/persistence tests/game/saveFile.test.ts tests/game/saveRepository.test.ts
git commit -m "feat: add Phoenix save format and browser repository"
```

---

## Task 3: Add the official Tauri Store adapter and single backend selector

**Files**

- Modify `vite.config.ts`
- Modify `package.json`
- Modify `bun.lock`
- Modify `src/persistence/saveRepository.ts`
- Modify `tests/game/saveRepository.test.ts`
- Modify `src-tauri/Cargo.toml`
- Modify `src-tauri/Cargo.lock`
- Modify `src-tauri/src/lib.rs`
- Modify `src-tauri/capabilities/default.json`
- Modify `tests/config/scaffold.test.ts`

### Step 1: Add RED repository-factory tests

Make backend creation dependency-injectable only at its narrow test seam, for example:

```ts
interface SaveRepositoryEnvironment {
  tauriPlatform?: string;
  storage: Storage;
  loadTauriStore?: () => Promise<TauriStoreLike>;
}
```

Production `createSaveRepository()` supplies real values; the helper used by tests can supply fakes.

Assert:

- no Tauri platform -> localStorage adapter and no Store loader invocation;
- Tauri platform -> Store loader invoked once;
- Tauri loader failure rejects and does not fall back to localStorage;
- Tauri `save()` calls one `set('save', file)` and one explicit `save()`;
- missing Store `save` value loads as `null`.

Do not expose this injection through App or gameplay code.

### Step 2: Configure only safe Tauri environment variables for Vite

Add to `vite.config.ts`:

```ts
envPrefix: ['VITE_', 'TAURI_ENV_*'],
```

The factory uses `import.meta.env.TAURI_ENV_PLATFORM` as its single Tauri/browser selector. Normal `bun run dev` has no Tauri platform value; `tauri dev` / `tauri build` invoke the frontend hooks with Tauri's `TAURI_ENV_*` values.

Do not use the unsafe broad `TAURI_` prefix.

### Step 3: Pin Store 2.4.4 and implement the adapter

Add exactly:

```json
"@tauri-apps/plugin-store": "2.4.4"
```

to direct runtime dependencies and regenerate `bun.lock` with Bun.

In the Tauri branch only:

```ts
const { load } = await import('@tauri-apps/plugin-store');
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});
```

The adapter:

```ts
load(): Promise<unknown | null> // store.get<unknown>('save') ?? null
save(file): Promise<void>       // store.set('save', file); store.save()
```

No static Store import belongs in a browser path.

### Step 4: Wire the Rust plugin and capability

Add to `src-tauri/Cargo.toml`:

```toml
tauri-plugin-store = "=2.4.4"
```

Register it in `lib.rs`:

```rs
tauri::Builder::default()
    .plugin(tauri_plugin_store::Builder::default().build())
```

Add `"store:default"` to the current main-window capability permissions.

Regenerate `Cargo.lock` through Cargo, not manual editing.

### Step 5: Update the exact scaffold contract

`tests/config/scaffold.test.ts` currently pins direct dependency objects exactly. Update it to require the Store dependency and add focused assertions that:

- Cargo.toml contains exact Store plugin pin;
- `lib.rs` registers Store;
- default capability contains `store:default`;
- Vite exposes only `VITE_` and `TAURI_ENV_*` prefixes.

Run:

```bash
bun test tests/game/saveRepository.test.ts tests/config/scaffold.test.ts
bun run check
cargo check --manifest-path src-tauri/Cargo.toml
```

Expected GREEN.

### Step 6: Commit

```bash
git add vite.config.ts package.json bun.lock src/persistence/saveRepository.ts tests/game/saveRepository.test.ts src-tauri tests/config/scaffold.test.ts
git commit -m "feat: add Tauri Store save backend"
```

---

## Task 4: Add title bootstrap and pass loaded state into the scene

**Files**

- Create `src/components/TitleScreen.svelte`
- Modify `src/App.svelte`
- Modify `src/components/GameHost.svelte`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/app.css`

### Step 1: Add the title component

`TitleScreen.svelte` receives only:

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

Continue is disabled while loading or when no valid save exists. New Game is disabled only while the initial storage probe is still running; after an error it remains available.

Keep title copy compact; no settings/credits/delete-save buttons.

### Step 2: Bootstrap the repository once in `App.svelte`

Add:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
```

On the existing `onMount`, before mounting gameplay:

```ts
const repository = await createSaveRepository();
const raw = await repository.load();
const save = raw === null ? null : parseSaveFile(raw);
```

Store the repository for the whole App lifetime. Catch load/parse errors into title error state, set loaded save to null, then show title.

New Game sets `initialState = null`.

Continue uses `structuredClone(loadedSave.state)`.

Both switch to `playing`; no immediate write/delete occurs.

### Step 3: Mount gameplay only in `playing`

Inside `StageFrame`:

- title phase renders only `TitleScreen`;
- playing phase renders the existing `GameHost`, `Overlay`, and dialogue panel.

The current `InputGate` instance remains App-owned. Reset gameplay presentation before a run starts.

### Step 4: Carry `initialState` through the adapter without persistence logic

Add `initialState: GameState | null` to `GameHost` props and then to `ProofSceneDependencies`.

`ProofScene.create()` changes only the existing constructor call:

```ts
this.session = new GameSession({
  // current parsed map config
  initialState: this.dependencies.initialState ?? undefined,
});
```

No Store/localStorage import in Phaser.

### Step 5: Type/style gate

Run:

```bash
bun run check
bun test tests/game/GameSession.test.ts tests/game/saveFile.test.ts tests/game/saveRepository.test.ts
bun run build
```

Expected GREEN.

### Step 6: Commit

```bash
git add src/components/TitleScreen.svelte src/App.svelte src/components/GameHost.svelte src/game/phaser/ProofScene.ts src/app.css
git commit -m "feat: add New Game and Continue bootstrap"
```

---

## Task 5: Autosave exactly once after the overnight transaction

**Files**

- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`

### Step 1: Add the narrow save status model

In App:

```ts
type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
let saveStatus = $state<SaveStatus>('idle');
let saveError = $state<string | null>(null);
```

Pass these to Overlay. Render one stable `data-save-status` element only when non-idle.

Copy:

- `Saving…`
- `Saved`
- `Save failed: ${saveError}`

Do not add a timer/toast/retry loop.

### Step 2: Convert `confirmSleep()` to the one autosave transaction

Keep the existing duplicate-submit guard. The exact sequence is:

```ts
const result = currentCommands.sleep();
if (!result.ok || result.code !== 'day-advanced') return;

const snapshot = gameSnapshot;
if (!snapshot?.pendingDaySummary) {
  throw new Error('post-sleep snapshot missing day summary');
}

saveStatus = 'saving';
saveError = null;
try {
  if (!saveRepository) throw new Error('save storage is unavailable');
  await saveRepository.save(createSaveFile(snapshot));
  saveStatus = 'saved';
} catch (error) {
  saveStatus = 'error';
  saveError = error instanceof Error ? error.message : String(error);
}
```

Close the sleep confirmation after `sleep()` succeeds so the existing morning summary is the blocking surface during the asynchronous write. Keep `sleepSubmitting` true until the save attempt settles.

### Step 3: Prevent starting the day during the write only

`startDay()` returns early when `saveStatus === 'saving'`. Overlay disables the `Start Day N` button while saving.

After `saved` or `error`, the current summary can be acknowledged normally.

Do not add a new InputGate reason; pending summary already locks world input.

### Step 4: Exercise failure locally with a unit-level fake repository if App logic is extracted

Do not introduce an App service solely to unit-test Svelte. Product-visible success/failure behavior is covered in Task 6 Playwright. Keep this task focused on orchestration.

Run:

```bash
bun run check
bun run lint
bun run format:check
```

Expected GREEN.

### Step 5: Commit

```bash
git add src/App.svelte src/components/Overlay.svelte
git commit -m "feat: autosave completed mornings"
```

---

## Task 6: Prove title, browser persistence, fixed-spawn restore, and bad-save recovery

**Files**

- Create `tests/e2e/persistence.pw.ts`
- Modify `tests/e2e/helpers.ts` only if an existing movement helper must be reused/exposed; do not duplicate it in the new test.

### Step 1: Fresh-title E2E

Start with cleared `localStorage` before navigation.

Assert:

```ts
await expect(page.locator('[data-title-screen]')).toBeVisible();
await expect(page.locator('[data-continue]')).toBeDisabled();
await page.locator('[data-new-game]').click();
await expect(page.locator('[data-game-host]')).toBeVisible();
```

Use the dev hook only to observe that the initial player is at the authored spawn.

### Step 2: Real autosave + reload E2E

Using normal controls/helpers:

1. New Game;
2. hoe one farm cell;
3. talk to one villager;
4. return to bed and confirm sleep;
5. assert morning summary is visible;
6. assert `data-save-status` becomes `Saved`;
7. record the current `gameSnapshot()` fields relevant to the actions/day;
8. `page.reload()`;
9. assert title and enabled Continue;
10. click Continue;
11. assert the pending Day 2 morning summary is still visible;
12. assert gameplay state matches the recorded post-sleep state;
13. assert `snapshot().player.position` equals `{x: 2.5, y: 9.5}` regardless of the pre-sleep world position;
14. start Day 2 and verify movement/action input resumes.

This test proves the actual browser backend and one autosave orchestration. Do not inject state through the dev hook.

### Step 3: Malformed save E2E

Before navigation, set:

```ts
localStorage.setItem('phoenix.save.v1', '{not-json');
```

Reload and assert:

- title is visible;
- Continue disabled;
- clear title error visible;
- New Game enabled and launches a fresh world.

Add a second lightweight case with valid JSON but `schemaVersion: 2` if it does not materially slow the suite.

### Step 4: Run the focused acceptance

```bash
bun run test:e2e tests/e2e/persistence.pw.ts
```

Then run all browser acceptance:

```bash
bun run test:e2e
```

Expected GREEN with no fixed-delay additions.

### Step 5: Commit

```bash
git add tests/e2e/persistence.pw.ts tests/e2e/helpers.ts
git commit -m "test: prove one-slot persistence flow"
```

---

## Task 7: Update handoff contracts and run the native/full verification matrix

**Files**

- Modify `README.md`
- Modify `tests/config/handoff.test.ts`
- Revisit `tests/config/scaffold.test.ts` only if the final dependency/config wording needs a paired assertion.

### Step 1: Update the player/developer handoff

Document only shipped HPA-596 behavior:

- app starts on New Game/Continue title;
- Continue availability means a valid V1 save exists;
- autosave occurs after sleep/new-morning transition;
- browser development uses localStorage key `phoenix.save.v1`;
- desktop uses Tauri Store;
- restore returns to authored morning spawn;
- bad dev saves disable Continue but New Game remains usable;
- no manual saves/multiple slots/migrations.

Do not turn README into a save-format specification; link the design doc for implementation detail.

### Step 2: Update exact README contract tests

Change `tests/config/handoff.test.ts` assertions together with README. Preserve all previously pinned setup/controls/economy/social/verification phrases unless HPA-596 intentionally replaces them.

Run:

```bash
bun test tests/config/handoff.test.ts tests/config/scaffold.test.ts
```

Expected GREEN.

### Step 3: Run focused native Store smoke

Run:

```bash
bun run tauri:dev
```

Manually record in the implementation PR validation notes:

1. New Game;
2. make a visible farm change;
3. sleep;
4. observe `Saved` while the morning summary is shown;
5. close the desktop window;
6. relaunch `bun run tauri:dev`;
7. verify Continue enabled;
8. Continue and verify the same morning gameplay state at the authored spawn.

If Store initialization or capability is wrong, fix the wiring rather than falling back to localStorage.

### Step 4: Run the repository gates

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

All must pass. Do not weaken the 90% coverage gate or clean-checkout verifier to land HPA-596.

### Step 5: Commit handoff only after verification

```bash
git add README.md tests/config/handoff.test.ts tests/config/scaffold.test.ts
git commit -m "docs: document Phoenix persistence flow"
```

---

## Final self-review checklist

Before marking the implementation PR ready:

- [ ] Diff contains only HPA-596 persistence/title/autosave work.
- [ ] One `GameState` owns the serialized mutable state shape; no duplicate state owner exists.
- [ ] Save file contains no player/camera/projected/Tiled/Phaser/Svelte state.
- [ ] `pendingDaySummary` survives close/reopen and remains blocking until acknowledged.
- [ ] Tauri and browser use the same `SaveFileV1` parser and repository interface.
- [ ] Browser path never invokes/imports the Store plugin at runtime.
- [ ] Tauri Store `autoSave` is false and each successful sleep calls one explicit repository save.
- [ ] No save occurs on failed sleep or ordinary commands.
- [ ] Save failures never display `Saved` and never roll back the completed day.
- [ ] Continue is disabled for absent/malformed/unsupported saves; New Game still works.
- [ ] Restore always uses the authored spawn rather than prior player position.
- [ ] No migration/backwards-compatibility/backup/manual-save infrastructure slipped in.
- [ ] Unit round trip covers every current mutable gameplay field, including social and shipment state.
- [ ] Browser E2E proves title -> save -> reload -> Continue and malformed-save recovery.
- [ ] `tauri:dev` close/reopen smoke proves the real Store backend.
- [ ] Full clean verification matrix passes without weakened gates.
