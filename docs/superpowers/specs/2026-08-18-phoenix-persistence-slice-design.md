# Phoenix Persistence Slice Design (HPA-596)

**Status:** Draft for review — revised after repository and tooling review

**Date:** 2026-08-18

**Delivery target:** browser-development and Tauri one-slot persistence

## Source of truth

This design implements HPA-596, `[Persistence Slice] Add one-slot autosave and continue`, against current `main` after HPA-595 shipped.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves the persistence boundary against the code that exists now: `GameSession` is the mutable gameplay authority, `ProofScene` is the Phaser adapter, `App.svelte` owns application/modal orchestration, and the Tauri shell contains no gameplay logic.

## Outcome

Phoenix opens on a small title screen. The player can start a fresh run or continue one valid save. Sleeping completes the existing overnight transaction first, then writes exactly one versioned snapshot of the completed new-morning gameplay state. Browser development uses `localStorage`; desktop uses the official Tauri Store plugin. Continue restores gameplay state while `ProofWorld` starts from the authored map spawn.

The implementation adds one explicit persistence boundary and two real adapters. It does not add save slots, migrations, backup rotation, save-anywhere, cloud sync, a state-management framework, a desktop WebDriver harness, or Rust gameplay logic.

## Approved lean shape

- Persist `GameState`, never `GameSnapshot`.
- Keep `GameSession` as the only mutable gameplay authority and the owner of the persisted-state projection.
- Add `GameSession.state(): GameState`; make `snapshot()` derive from that state plus world/presentation data.
- Restore `GameSession` from optional `initialState` while always reconstructing `ProofWorld` from the authored map.
- Add one `SaveFileV1` wrapper with `schemaVersion: 1` and structural parsing from `unknown`.
- Keep authored farm-cell identity validation in `GameSession`, where the parsed map is available.
- Add one `SaveRepository` interface with `load()` and `save()` and exactly two adapters.
- Select the adapter once at startup; do not scatter environment checks through gameplay or UI code.
- Mount Phaser only after New Game or Continue.
- Autosave once after successful `day-advanced` and before the pending morning summary can be dismissed.
- Keep the existing pending-day-summary/InputGate behavior; do not add another input-lock reason.
- Surface only `Saving…`, `Saved`, and a clear save error.
- Return a failed pre-ready world launch to the title screen so New Game remains available.

## Persisted state boundary

### Relationship state

Promote the current mutable relationship shape into shared core types:

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
```

`RelationshipLevel` remains derived from points and is not persisted.

### Game state

`GameState` contains every mutable gameplay field currently owned by `GameSession`:

```ts
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

The save deliberately excludes:

- player position, facing, and current target;
- camera state and projected/world coordinates;
- `maxStamina`, because it is a current rule constant;
- bed/shop/shipping/villager cells, collision footprints, and Tiled objects;
- Phaser scenes, sprites, controllers, or handles;
- Svelte modal/component state and feedback text;
- villager content and derived relationship levels.

`pendingDaySummary` is persisted. Autosave occurs while the newly produced morning summary is pending, so reopening immediately after a save must show that same blocking summary until the player presses `Start Day N`.

`selectedAction` and `selectedSeed` are persisted because they are authoritative mutable fields.

## `GameSession` owns export and restore

### Export

Add:

```ts
state(): GameState;
```

`state()` is the canonical plain-data projection of the mutable rule state. It deep-clones nested data.

`snapshot()` must call `state()` and then add only presentation/read-model data:

- `ProofWorld.snapshot()` player/target;
- current `maxStamina`;
- relationship `level` derived from `state.relationships`;
- authored interaction cells.

This avoids a persistence-layer copy of the mutable-field list. Adding a future mutable rule field requires updating the authoritative state projection and type, rather than independently teaching `saveFile.ts` how to strip the read model.

`ProofScene` exposes one read-only scene accessor:

```ts
state(): GameState;
```

on `SceneCommands`. It delegates directly to `GameSession.state()` and does not mutate anything. `App.svelte` reads it immediately after a successful synchronous `sleep()` command, so no second state callback/channel is introduced.

### Restore

Extend `GameSessionConfig` with:

```ts
initialState?: GameState;
```

Construction still validates the authored map/world/farm/interaction configuration first. When `initialState` exists:

1. require the saved farm tile positions to match the current authored farm-cell set exactly;
2. require all current villager relationship records;
3. clone scalar/inventory/shipment/relationship state into the existing session fields;
4. replace the contents of `farmTiles` with cloned saved tile objects;
5. clear and rebuild `farmTilesByKey` from those restored objects.

The map rebuild is explicit. A restored snapshot that looks correct but leaves `farmTilesByKey` pointing to the default untilled objects is invalid.

Tests must execute a farm command after restore, not merely compare `snapshot().farmTiles`, to prove the lookup map uses restored objects.

`ProofWorld` is never hydrated from the save. Its constructor continues to initialize position from the current map spawn, so Continue resumes at the authored morning spawn with normal initial facing/target behavior.

## Save envelope and validation ownership

Create `src/persistence/saveFile.ts`:

```ts
export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

export function createSaveFile(state: GameState): SaveFileV1;
export function parseSaveFile(value: unknown): SaveFileV1;
```

`createSaveFile` only deep-clones/wraps `GameState`.

`parseSaveFile` validates only what can be known without the authored map:

- top-level plain-object shape;
- exact `schemaVersion === 1`;
- required current fields;
- current closed unions;
- integer/record/array/value shapes;
- crop/relationship/day-summary nested structure.

It does **not** assert the current nine authored farm positions. That identity belongs to `GameSession`, after `ProofScene` has parsed the current map.

There is no coercion or repair path. Invalid saves throw a concise `Invalid save: ...` error. There is no migration registry, schema library, or compatibility fallback.

## Storage boundary

Create `src/persistence/saveRepository.ts`:

```ts
export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}

export async function createSaveRepository(): Promise<SaveRepository>;
```

Repositories store and retrieve the versioned envelope; they do not validate gameplay rules.

### Browser adapter

`LocalStorageSaveRepository` uses one key:

```text
phoenix.save.v1
```

`load()` returns `null` if absent and otherwise `JSON.parse`s the stored value. Invalid JSON rejects and is surfaced by the title bootstrap.

`save()` performs one `JSON.stringify(file)` and one `localStorage.setItem`.

No IndexedDB, temporary key, backup key, or second browser abstraction is added.

### Tauri adapter

Use `@tauri-apps/plugin-store` 2.4.4 and `tauri-plugin-store = "=2.4.4"`.

The frontend Store module is dynamically imported only on the Tauri branch. Use one store file and one key:

```ts
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});

await store.set('save', file);
await store.save();
```

Explicit `store.save()` is required so the UI can report completion/failure of the product-defined overnight save transaction.

Rust only registers the plugin:

```rs
.plugin(tauri_plugin_store::Builder::default().build())
```

The main-window capability adds `store:default`. No custom Rust save command, Rust DTO, filesystem API, encryption, or Store event system is introduced.

### Correct Tauri/browser selector

Vite treats each `envPrefix` entry as a literal string prefix. Configure exactly:

```ts
envPrefix: ['VITE_', 'TAURI_ENV_'],
```

Do **not** use `TAURI_ENV_*`; the `*` is not a glob in Vite prefix matching.

Add the client type in `src/vite-env.d.ts`:

```ts
interface ImportMetaEnv {
  readonly TAURI_ENV_PLATFORM?: string;
}
```

`createSaveRepository()` uses `import.meta.env.TAURI_ENV_PLATFORM` as its single selector. Normal browser development has no value; Tauri frontend hooks provide the value.

A missing platform must take the browser adapter and must not invoke the Store loader. A Store initialization failure on the Tauri path must reject; it must never silently fall back to `localStorage` inside the webview.

`tests/config/scaffold.test.ts` pins the exact `['VITE_', 'TAURI_ENV_']` contract.

## Title and startup flow

Add `TitleScreen.svelte` inside the existing `StageFrame`.

`App.svelte` owns:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
type LaunchSource = 'new' | 'continue' | null;
```

Startup runs once:

1. create the repository;
2. call `load()`;
3. no save -> title, Continue disabled;
4. parsed V1 -> title, Continue enabled;
5. load/parse failure -> title error, Continue disabled, New Game enabled.

New Game launches with `initialState = null`. Continue launches with a clone of `loadedSave.state`.

Only `playing` mounts `GameHost`, `Overlay`, and dialogue UI. `GameHost` carries `initialState` through `ProofSceneDependencies`; `ProofScene` passes it to `GameSession`.

Starting New Game does not delete the old save immediately. The next successful overnight write replaces the slot.

### Pre-ready world failure

A structurally valid V1 can still be incompatible with the current authored map. `GameSession` discovers that only after `ProofScene.create()` has parsed the map.

If `GameHost` reports an error before `onReady`:

- stop/reset the failed world presentation;
- return `AppPhase` to `title`;
- show the error on the title;
- keep New Game enabled;
- if the launch source was Continue, clear the loaded save so Continue is disabled rather than retrying the same incompatible state forever.

Do not strand this error in the gameplay Overlay; HPA-596 has no return-to-title menu.

## Autosave transaction

Keep overnight mutation in `GameSession.sleep()`.

Create one narrow, unit-testable persistence orchestration helper:

```ts
export async function persistOvernightSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<boolean>;
```

Behavior:

- if `result` is not successful `day-advanced`, return `false` without calling `save()`;
- if it is `day-advanced` and repository is unavailable, throw a clear storage error;
- otherwise write `createSaveFile(state)` exactly once and return `true` after resolution;
- propagate repository rejection.

This is not a service locator or state owner; it is a small dependency-injected transaction seam for the riskiest new branch logic.

`App.svelte::confirmSleep()` becomes asynchronous with this ordering:

1. guard duplicate submission;
2. call `commands.sleep()` exactly once;
3. the existing `publishCommand()` synchronously publishes the post-sleep snapshot before `sleep()` returns;
4. hide the confirmation prompt once the command returns;
5. for successful `day-advanced`, read `commands.state()` and set `saveStatus = 'saving'`;
6. await `persistOvernightSave(...)`;
7. set `saved` only after resolution, or `error` on rejection;
8. clear submission state after the attempt settles.

The day transition is not rolled back when storage fails.

While saving, the existing pending morning summary remains visible and continues to lock world input. `Start Day N` is disabled while `saveStatus === 'saving'`. Success or failure re-enables it. No new `InputGate` reason is needed.

## Save feedback

Use:

```ts
export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
```

`Overlay.svelte` renders one stable `data-save-status` surface:

- `Saving…`
- `Saved`
- `Save failed: <message>`

No toast system, timer, retries, progress bar, log view, or save history is added.

## Existing E2E wiring changes

The title and save gate alter shared acceptance helpers, so they are part of the feature tasks rather than deferred cleanup.

### `waitForWorld`

`tests/e2e/helpers.ts::waitForWorld` currently navigates directly and waits for `World ready`. After HPA-596 it must:

1. `page.goto('/')`;
2. wait for `data-title-screen`;
3. click `data-new-game`;
4. wait for `World ready` and the existing observation hook.

This keeps every existing farming/economy/social/world/lifecycle/sleep test on the normal New Game path without touching each spec.

### `confirmAndStartDay`

After clicking Confirm and validating the morning summary, the helper must wait for persistence to settle before clicking Start Day:

- wait for `data-save-status` to read `Saved` in the normal localStorage path;
- wait for `Start Day N` to be enabled;
- then click it and perform the existing summary-clear/input-unlock assertions.

Do not add arbitrary sleeps or loosen Playwright timeouts.

## Testing strategy

### Core/unit

`GameSession.test.ts` covers:

- `state()` deep-clone behavior;
- `snapshot()` preserving current read-model shape while deriving from state;
- representative full-state restore;
- exact current farm-cell identity rejection;
- relationship-state restore;
- fixed authored spawn after restore;
- a post-restore farm command proving `farmTilesByKey` points to restored tiles.

`saveFile.test.ts` covers the V1 envelope and structural parser, including unknown version and malformed nested structures, while explicitly avoiding authored farm-cell identity checks.

`saveRepository.test.ts` covers localStorage, Store adapter behavior, missing-platform browser selection, Tauri Store selection, and no fallback on Store initialization failure.

`persistOvernightSave.test.ts` covers:

- successful `day-advanced` writes exactly once;
- repository rejection propagates;
- unavailable repository rejects;
- non-`day-advanced` results never save.

These tests count toward the existing Bun coverage gate; Playwright does not replace them.

### Browser Playwright

Create `tests/e2e/persistence.pw.ts` for:

1. fresh title, Continue disabled, New Game launch;
2. real gameplay change -> sleep -> `Saved` -> reload -> Continue -> same pending morning/gameplay state at authored spawn -> Start Day;
3. malformed localStorage -> title error + disabled Continue + working New Game.

Keep `window.__PHOENIX_TEST__` observation-only. No teleport, weather setter, save injection method, or command hook is added.

### Tauri Store smoke

Do not add desktop WebDriver infrastructure.

The implementation PR validation notes must include one manual `bun run tauri:dev` close/reopen smoke:

1. New Game;
2. make one visible gameplay change;
3. sleep and observe `Saved`;
4. close the Tauri window;
5. relaunch `bun run tauri:dev`;
6. verify Continue is enabled;
7. Continue and verify the same morning state at the authored spawn.

The existing unsigned Tauri build remains the packaging gate.

## Expected file impact

### Core state

- `src/game/core/types.ts`
- `src/game/core/GameSession.ts`
- `tests/game/GameSession.test.ts`

### Persistence

- `src/persistence/saveFile.ts`
- `src/persistence/saveRepository.ts`
- `src/persistence/persistOvernightSave.ts`
- `tests/game/saveFile.test.ts`
- `tests/game/saveRepository.test.ts`
- `tests/game/persistOvernightSave.test.ts`

### Desktop/platform

- `vite.config.ts`
- `src/vite-env.d.ts`
- `package.json`
- `bun.lock`
- `src-tauri/Cargo.toml`
- `src-tauri/Cargo.lock`
- `src-tauri/src/lib.rs`
- `src-tauri/capabilities/default.json`
- `tests/config/scaffold.test.ts`

### Title/game bridge

- `src/components/TitleScreen.svelte`
- `src/App.svelte`
- `src/components/GameHost.svelte`
- `src/game/phaser/ProofScene.ts`
- `src/app.css`

### Acceptance/handoff

- `tests/e2e/helpers.ts`
- `tests/e2e/persistence.pw.ts`
- `README.md`
- `tests/config/handoff.test.ts`

No planned changes: authored assets/map, `ProofWorld.ts`, `InputGate.ts`, `dailyRhythm.ts`, crop/villager definitions, `loadProofMap.ts`, CI workflow, or Playwright configuration.

## Acceptance mapping

- **One save after sleep:** only successful `day-advanced` reaches `persistOvernightSave`; Store auto-save is disabled.
- **Equivalent restore:** `GameSession.state()` contains every mutable gameplay field; restore tests and Tauri smoke cover the round trip.
- **Fixed spawn:** world position/facing/target are absent from `GameState`; `ProofWorld` constructs from the authored spawn.
- **Browser development:** missing Tauri platform selects localStorage and never loads Store.
- **Desktop backend:** `TAURI_ENV_PLATFORM` is exposed with literal prefix `TAURI_ENV_`; Store failure never falls back.
- **Bad save recovery:** structural parser errors stay on title; map-identity restore errors return to title; New Game remains available.
- **Visible failure:** `Saved` is assigned only after the repository write resolves.
- **Existing E2E:** `waitForWorld` enters New Game and `confirmAndStartDay` waits for the new save gate.
- **Coverage:** autosave success/skip/failure branches have Bun unit coverage, not only Playwright coverage.
