# Phoenix Persistence Slice Design (HPA-596)

**Status:** Draft for review — revised after repository, tooling, and reuse review

**Date:** 2026-08-18

**Last revised:** 2026-08-19

**Delivery target:** browser-development and Tauri one-slot persistence

## Source of truth

This design implements HPA-596, `[Persistence Slice] Add one-slot autosave and continue`, against current `main` after HPA-595 shipped.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves implementation details against the code that exists now:

- `GameSession` is the mutable gameplay authority;
- `ProofWorld` owns transient player world state and always starts from the authored map spawn;
- `ProofScene` is the Phaser adapter;
- `App.svelte` owns application/modal orchestration;
- the Tauri shell contains no gameplay logic;
- browser acceptance shares `tests/e2e/helpers.ts`, so title/save lifecycle changes must preserve that seam.

## Outcome

Phoenix opens on a small title screen. The player can start a fresh run or continue one valid save. Sleeping completes the existing overnight transaction first, then writes exactly one versioned copy of the completed new-morning gameplay state. Browser development uses `localStorage`; desktop uses the official Tauri Store plugin. Continue restores gameplay state while `ProofWorld` starts from the current authored map spawn.

The implementation adds one explicit persistence layer with one save envelope, one repository interface, two mandated adapters, and two small application-orchestration helpers. It does not add save slots, migrations, backup rotation, save-anywhere, cloud sync, a state-management framework, desktop WebDriver infrastructure, or Rust gameplay logic.

## Approved lean shape

- Persist `GameState`, never `GameSnapshot`.
- Keep `GameSession` as the only mutable gameplay authority and the owner of the persisted-state projection.
- Add `GameSession.state(): GameState`; make `snapshot()` derive from that state plus transient/derived read-model data.
- Restore `GameSession` from optional `initialState`, but always reconstruct `ProofWorld` from the authored map.
- Keep current-rule invariant checks in `GameSession`, where domain constants and authored farm identity are known.
- Share the existing plain-value parser primitives between Tiled parsing and save parsing instead of duplicating them.
- Add one `SaveFileV1` wrapper with `schemaVersion: 1` and structural parsing from `unknown`.
- Add one `SaveRepository` interface with exactly two adapters: browser `localStorage` and Tauri Store.
- Select the repository once at startup; do not scatter environment checks through gameplay or UI code.
- Extract title-load and overnight-save orchestration into small framework-free functions so Bun unit tests cover their branch logic.
- Mount Phaser only after New Game or Continue.
- Autosave once after successful `day-advanced` and before the pending morning summary can be dismissed.
- Keep the existing pending-day-summary/InputGate behavior; do not add another input-lock reason.
- Give save status an explicit lifecycle: `idle -> saving -> saved|error -> idle` when the morning summary is dismissed.
- Return a failed pre-ready Continue launch to the title screen so New Game remains usable.
- Verify the Tauri Store wiring once when it is introduced, then perform the full close/reopen acceptance at final verification.

## Architecture and dependency direction

Add `src/persistence/` as a small application/platform boundary:

- `saveFile.ts` owns the V1 envelope and structural parsing;
- `saveRepository.ts` owns browser/Tauri storage adapters and the single backend selector;
- `loadTitleState.ts` owns repository creation/load/parse bootstrap;
- `persistOvernightSave.ts` owns the one-write-after-`day-advanced` transaction.

Dependency direction is explicit:

```text
src/game/core  <-  src/persistence  <-  src/App.svelte
       ^                  ^
       |                  |
src/game/phaser           Tauri Store/localStorage adapters
```

`src/game/core/` never imports from `src/persistence/`. `ProofScene` never imports a storage adapter. `App.svelte` is the only production runtime consumer that coordinates the persistence layer with the game scene.

`CLAUDE.md` must document this new layer and dependency direction in the same PR so later work does not drag browser/Tauri APIs into the rules authority.

## Persisted state boundary

### Relationship state

Promote the current private mutable relationship shape into shared core types:

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

`pendingDaySummary` is persisted. Autosave occurs while the newly produced morning summary is pending, so reopening immediately after a save shows that same blocking summary until the player presses `Start Day N`.

`selectedAction` and `selectedSeed` are persisted because they are authoritative mutable fields.

## `GameSession` owns export and restore

### Canonical export

Add:

```ts
state(): GameState;
```

`state()` is the single plain-data projection of mutable rule state and deep-clones nested data. It reuses/extents the clone helpers already local to `GameSession.ts`; do not create a parallel family of persistence-only crop/count/relationship clones.

Type `GameSnapshot` from `GameState` so mutable-field additions flow into the read model by construction:

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

`snapshot()` calls `state()` and adds only:

- `ProofWorld.snapshot()` player/target;
- current `maxStamina`;
- relationship `level` derived from state points;
- authored interaction cells.

`ProofScene` exposes one read-only scene accessor:

```ts
state(): GameState;
```

on `SceneCommands`. It delegates directly to `GameSession.state()` and does not create a second callback/channel.

### Restore order

Extend `GameSessionConfig`:

```ts
initialState?: GameState;
```

Construction still validates the authored map/world/farm/interaction configuration first. When `initialState` exists:

1. validate current rule invariants;
2. require the saved farm tile positions to match the current authored farm-cell set exactly;
3. require all current villager relationship records;
4. clone scalar/inventory/shipment/relationship state into the current session;
5. replace the contents of `farmTiles` with cloned saved tile objects;
6. clear and rebuild `farmTilesByKey` from those restored objects.

The lookup rebuild is explicit. A restored snapshot that looks right while `farmTilesByKey` still points at default untilled objects is invalid.

Tests must execute a farm command after restore, not merely compare `snapshot().farmTiles`.

### Current rule invariants

Structural save parsing is not enough to construct a legal session. `GameSession` rejects values its own commands can never produce using the same `GameSession: invalid initial state ...` prefix.

At minimum:

- `day` is a safe integer in `[1, MAX_DAY]`;
- `timeMinutes` is a safe integer in `[DAY_START_MINUTES, ACTION_CUTOFF_MINUTES]`;
- `stamina` is a safe integer in `[0, MAX_STAMINA]`;
- `money`, inventory counts, pending shipment counts, and relationship points are non-negative safe integers;
- each farm tile soil/crop state is valid for the current authored tile;
- crop growth is a safe integer in `[0, CROP_DEFINITIONS[kind].growthDays]`.

Do not duplicate union/shape parsing here; `parseSaveFile()` already handles that. These are current-domain invariants that depend on rule constants/content and therefore belong in `GameSession`.

An invalid restored state follows the pre-ready error route back to title instead of booting into a permanent `day-limit-reached`, `action-too-late`, or otherwise impossible session.

### Round-trip proof

The primary round-trip regression is command-driven rather than a hand-enumerated expected-state literal.

Use a compact test-only authored config where shop, shipping bin, bed, and one villager are targetable from a known spawn by changing facing. Drive one session through the real current commands:

1. buy seeds;
2. till and plant at least two farm tiles;
3. water/grow/sleep until harvest;
4. harvest crops;
5. deposit one crop for shipping;
6. talk to and gift one villager;
7. sleep once more so the shipment appears in a pending morning summary;
8. export `state()` and construct a second `GameSession` with that state.

Compare the restored and original `snapshot()` values after removing only transient `player` and `target`. Separately assert the restored player starts at the authored spawn. Keep small targeted fixtures for invalid boundaries/daily flags, but do not make a hand-written full-state literal the main round-trip acceptance test.

## Shared plain-value parsing

`loadProofMap.ts` already owns private `fail`, `record`, `array`, `string`, finite-number, integer, and boolean primitives. HPA-596 needs the same class of parser for untrusted save JSON. Do not fork them.

Extract a framework-free helper to `src/game/core/parse.ts`:

```ts
export function createValueParser(prefix: string) {
  // returns fail, record, array, string, number, integer,
  // safeInteger, boolean, oneOf
}
```

The factory only captures the error prefix. Example prefixes:

```ts
const {
  fail,
  record,
  array,
  string,
  number,
  integer,
  boolean,
} = createValueParser('proof-map');

const {
  record,
  array,
  safeInteger,
  boolean,
  oneOf,
} = createValueParser('Invalid save');
```

This keeps the existing parser call style in `loadProofMap.ts` while deleting its duplicate primitive implementations. It is not a schema framework: no schema objects, decorators, migration/version registry, or generic object decoder are added.

Existing `loadProofMap.test.ts` plus new save-file tests exercise the shared helpers through both consumers; no standalone parsing framework is required.

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

`createSaveFile()` only deep-clones/wraps `GameState`.

`parseSaveFile()` uses the shared plain-value parser and validates only what can be known without the authored map/current session:

- top-level object shape;
- exact `schemaVersion === 1`;
- required current fields;
- current closed unions;
- integer/boolean/record/array shape;
- crop/relationship/day-summary nested structure.

It does **not** assert the current nine authored farm positions or current-domain ranges such as `MAX_DAY`, `MAX_STAMINA`, action cutoff, or crop maturity. Those belong to `GameSession`.

There is no coercion or repair path. Invalid save structure throws `Invalid save: ...`. There is no migration registry, schema library, or compatibility fallback.

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

`load()` returns `null` if absent and otherwise `JSON.parse`s the stored value. Invalid JSON rejects and is surfaced by title bootstrap.

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

Explicit `store.save()` is required so the UI can report completion/failure of the product-defined overnight transaction.

Rust only registers the plugin:

```rs
.plugin(tauri_plugin_store::Builder::default().build())
```

The main-window capability adds `store:default`. No custom Rust save command, Rust DTO, filesystem API, encryption, or Store event system is introduced.

### Correct Tauri/browser selector

Vite treats each `envPrefix` entry as a literal prefix. Configure exactly:

```ts
envPrefix: ['VITE_', 'TAURI_ENV_'],
```

Do not use `TAURI_ENV_*`; `*` is not a Vite glob.

Add the client type in `src/vite-env.d.ts`:

```ts
interface ImportMetaEnv {
  readonly TAURI_ENV_PLATFORM?: string;
}
```

`createSaveRepository()` uses `import.meta.env.TAURI_ENV_PLATFORM` as its single selector. Normal browser development has no value; Tauri frontend hooks provide the value.

A missing platform takes the browser adapter and must not invoke Store. A Store initialization failure on the Tauri path rejects; it never silently falls back to `localStorage` inside the webview.

`tests/config/scaffold.test.ts` pins the exact `['VITE_', 'TAURI_ENV_']` contract.

## Testable title bootstrap

The title bootstrap contains enough asynchronous branch logic to deserve a framework-free unit seam rather than living entirely inside a Svelte `onMount`.

Create `src/persistence/loadTitleState.ts`:

```ts
export interface TitleLoadState {
  repository: SaveRepository | null;
  save: SaveFileV1 | null;
  error: string | null;
}

export async function loadTitleState(
  createRepository?: () => Promise<SaveRepository>,
): Promise<TitleLoadState>;
```

Production defaults to `createSaveRepository`. Tests inject a tiny factory.

Behavior:

1. repository creation failure -> `{ repository: null, save: null, error }`;
2. repository created + no stored value -> repository retained, no save/error;
3. repository load rejection -> repository retained, save null, error shown;
4. structurally invalid save -> repository retained, save null, error shown;
5. valid V1 -> repository and parsed save returned, no error.

Keeping the repository after a load/parse failure lets New Game overwrite the one slot on the next successful sleep. Do not auto-delete or repair the bad save.

`App.svelte` only assigns returned repository/save/error values and moves from `loading-save` to `title`.

## Title and launch flow

Add `TitleScreen.svelte` inside the existing `StageFrame`.

`App.svelte` owns:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
type LaunchSource = 'new' | 'continue' | null;
```

New Game launches with `initialState = null`. Continue launches with a clone of `loadedSave.state`.

Only `playing` mounts `GameHost`, `Overlay`, and dialogue UI. `GameHost` carries `initialState` through `ProofSceneDependencies`; `ProofScene` passes it to `GameSession`.

Starting New Game does not delete the old save immediately. The next successful overnight write replaces the slot.

### Pre-ready world failure

A structurally valid V1 can still be incompatible with the current authored map or current rule invariants. `GameSession` discovers that only after `ProofScene.create()` has parsed the map.

If `GameHost` reports an error before `onReady`:

- stop/reset the failed world presentation;
- return `AppPhase` to `title`;
- show the error on the title;
- keep New Game enabled;
- if launch source was Continue, clear the in-memory loaded save so Continue is disabled instead of retrying the same incompatible state forever.

Do not strand this error in gameplay Overlay; HPA-596 has no return-to-title menu.

## Unit-testable overnight persistence

Keep overnight mutation in `GameSession.sleep()`.

Create `src/persistence/persistOvernightSave.ts`:

```ts
export async function persistOvernightSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<boolean>;
```

Behavior:

- non-success or success code other than `day-advanced` -> `false`, no save call;
- `day-advanced` with no repository -> reject with a clear storage error;
- `day-advanced` with repository -> `save(createSaveFile(state))` exactly once and resolve `true`;
- repository rejection propagates.

This helper is dependency-injected transaction logic, not a service locator or state owner.

`App.svelte::confirmSleep()` becomes asynchronous:

1. guard duplicate submission;
2. call `commands.sleep()` exactly once;
3. hide the confirmation prompt once the command returns;
4. for successful `day-advanced`, read `commands.state()`;
5. set `saveStatus = 'saving'`;
6. await `persistOvernightSave(...)`;
7. set `saved` only after resolution, or `error` on rejection;
8. clear submission state after the attempt settles.

The day transition is not rolled back when storage fails.

## Save-status lifecycle

Use:

```ts
export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
```

Exact lifecycle:

```text
new/continued day: idle
sleep succeeds:   saving
write succeeds:   saved
write fails:      error
Start Day N:      idle
presentation reset/title/error: idle
```

`resetGamePresentation()` resets both `saveStatus` and save-error text. `startDay()` resets them after the pending morning summary is successfully acknowledged.

This is required for both UX and test correctness. Leaving `Saved` visible all day would let the next night's E2E wait pass on stale text while the new write is still running.

While saving, the existing pending morning summary remains visible and continues to lock world input. `Start Day N` is disabled while `saveStatus === 'saving'`; success or failure re-enables it. No new `InputGate` reason is needed.

`Overlay.svelte` renders one stable `data-save-status` surface only when status is not `idle`:

- `Saving…`
- `Saved`
- `Save failed: <message>`

No toast system, timer, retries, progress bar, or save history is added.

## Existing E2E wiring changes

The title and save gate alter shared acceptance helpers, so those helper changes ship in the tasks that introduce the behavior.

### `waitForWorld`

`tests/e2e/helpers.ts::waitForWorld` becomes:

1. `page.goto('/')`;
2. wait for `data-title-screen`;
3. click `data-new-game`;
4. wait for `World ready` and the existing observation hook.

Every existing farming/economy/social/world/lifecycle/sleep test therefore uses the normal New Game entry without per-spec patches.

Because every existing spec calls this helper, the title task must run the **full** `bun run test:e2e` suite immediately after changing it, not a grep subset.

### `confirmAndStartDay`

After clicking Confirm and validating the morning summary, the helper waits for the current night's persistence attempt to settle:

1. wait for `data-save-status` to read `Saved` on the normal browser path;
2. wait for `Start Day N` to be enabled;
3. click it;
4. assert summary cleared/input unlocked;
5. assert save status returns to `idle`/the status surface is absent.

Because `startDay()` reset the previous night's `Saved`, this wait cannot pass on stale state during multi-night farming/economy/social loops.

Do not add arbitrary sleeps or loosen Playwright timeouts.

## Testing strategy

### Core state tests

`GameSession.test.ts` covers:

- `state()` deep cloning;
- `snapshot()` retaining current read-model shape while deriving mutable fields from `GameState`;
- current-rule invariant rejection;
- exact authored farm-cell identity rejection;
- relationship-state restore;
- explicit `farmTilesByKey` rebuild via a successful farm command after restore;
- command-driven farming + economy + social + sleep round trip;
- fixed authored spawn after restore.

### Persistence unit tests

Put new persistence tests under `tests/persistence/`:

- `saveFile.test.ts` — V1 envelope, structural parser, error prefixes, no authored-map identity checks;
- `saveRepository.test.ts` — localStorage, Store adapter fakes, exact backend selection, no Store fallback;
- `loadTitleState.test.ts` — repository-create failure, empty save, load failure, parse failure, valid save;
- `persistOvernightSave.test.ts` — exactly-once success, skip branch, missing repository, repository rejection.

The repo did not previously have `tests/persistence/`; it is introduced because `src/persistence/` is a new top-level layer. This is preferable to classifying platform/application orchestration as game-rule tests.

### Browser Playwright

Create `tests/e2e/persistence.pw.ts` for:

1. fresh title, Continue disabled, New Game launch;
2. real gameplay change -> sleep -> `Saved` -> reload -> Continue -> same pending morning/gameplay state at authored spawn -> Start Day;
3. malformed localStorage -> title error + disabled Continue + working New Game.

Keep `window.__PHOENIX_TEST__` observation-only. No teleport, weather setter, save injection method, or command hook is added.

### Tauri verification placement

Do not wait until final acceptance to discover Store wiring problems.

When the Tauri Store adapter/configuration is introduced, run a minimal real `bun run tauri:dev` smoke before moving on:

- confirm the webview starts with `TAURI_ENV_PLATFORM` taking the Tauri repository branch;
- confirm Store initialization/load succeeds under the configured `store:default` capability;
- from devtools, perform one temporary Store write/read using a separate smoke store/key, then remove/overwrite that smoke value so it cannot affect the Phoenix save slot.

This is a manual integration gate for environment/plugin/permission wiring; unit fakes and `cargo check` cannot prove it.

Final verification still performs the product-level close/reopen flow through Phoenix's own save repository:

1. New Game;
2. make one visible gameplay change;
3. sleep and observe `Saved`;
4. close the Tauri window;
5. relaunch `bun run tauri:dev`;
6. verify Continue is enabled;
7. Continue and verify the same morning state at the authored spawn.

No desktop WebDriver harness is added.

## Documentation impact

Update:

- `README.md` for the title/Continue/autosave behavior and desktop smoke;
- `tests/config/handoff.test.ts` for any newly pinned README handoff text;
- `CLAUDE.md` with the `src/persistence/` architecture bullet and dependency direction.

Do not change the active delivery model, CI workflow shape, or unrelated controls/content documentation.

## Risks and controls

### Tauri Store environment/capability wiring

**Risk:** unit fakes and compilation can pass while the real webview takes the browser branch or Store calls are denied.

**Control:** exact Vite prefix/type/config contract + Task 3 real `tauri:dev` Store initialization/write/read smoke + final close/reopen acceptance.

### Shared E2E helper coupling

**Risk:** title/save changes affect every existing Playwright spec through `waitForWorld` and multi-night tests through `confirmAndStartDay`.

**Control:** change those helpers in the feature tasks, reset save status to `idle` after each started day, and run the full E2E suite after the title helper change and again after autosave wiring.

## Expected file impact

### Core

- `src/game/core/types.ts`
- `src/game/core/GameSession.ts`
- `src/game/core/parse.ts`
- `src/game/phaser/loadProofMap.ts`
- `tests/game/GameSession.test.ts`
- `tests/game/loadProofMap.test.ts` only if imports/error assertions require adjustment

### Persistence

- `src/persistence/saveFile.ts`
- `src/persistence/saveRepository.ts`
- `src/persistence/loadTitleState.ts`
- `src/persistence/persistOvernightSave.ts`
- `tests/persistence/saveFile.test.ts`
- `tests/persistence/saveRepository.test.ts`
- `tests/persistence/loadTitleState.test.ts`
- `tests/persistence/persistOvernightSave.test.ts`

### Tauri/Vite

- `vite.config.ts`
- `src/vite-env.d.ts`
- `package.json`
- `bun.lock`
- `src-tauri/Cargo.toml`
- `src-tauri/Cargo.lock`
- `src-tauri/src/lib.rs`
- `src-tauri/capabilities/default.json`
- `tests/config/scaffold.test.ts`

### UI/scene bridge

- `src/components/TitleScreen.svelte`
- `src/App.svelte`
- `src/components/GameHost.svelte`
- `src/components/Overlay.svelte`
- `src/game/phaser/ProofScene.ts`
- `src/app.css`
- `tests/e2e/helpers.ts`
- `tests/e2e/persistence.pw.ts`

### Handoff

- `README.md`
- `CLAUDE.md`
- `tests/config/handoff.test.ts`

No planned changes: authored assets/map, `ProofWorld.ts`, `InputGate.ts`, `dailyRhythm.ts`, crop/villager content values, `.github/workflows/ci.yml`, `playwright.config.ts`, or a new desktop E2E framework.

## Acceptance mapping

- **One save after sleep:** `persistOvernightSave` accepts the real `CommandResult` and saves only successful `day-advanced` exactly once.
- **Equivalent desktop restore:** command-driven state round trip plus real Tauri close/reopen acceptance.
- **Browser development:** missing `TAURI_ENV_PLATFORM` selects localStorage and Store loader is never called.
- **No runtime-render state:** `GameState` excludes world/player/camera/Tiled/Phaser/Svelte state.
- **Continue availability:** only structurally parsed V1 enables Continue; incompatible current-domain/map state returns to title and disables that candidate.
- **Bad save recovery:** title remains usable and New Game can later overwrite the slot.
- **Visible failures:** `saved` is assigned only after repository resolution; failures surface as `error` and Start Day becomes usable once the attempt settles.
- **Complete round trip:** command-driven test exercises farming, economy, shipping, social interaction, overnight transition, and restoration without a full hand-enumerated expected state.
- **Current-rule safety:** impossible day/time/stamina/count/growth values are rejected by `GameSession` before play.
- **Existing suite stability:** shared title/save helpers are updated at the behavior-introducing tasks and exercised by the full Playwright suite.

## Non-goals

Multiple slots, manual save-anywhere, arbitrary player-position persistence, cloud sync, Steam Cloud, save thumbnails, backup rotation, compression, encryption, cross-device transfer, backwards compatibility for development saves, migration/version registries, save repair/coercion, state-management libraries, schema libraries, a custom Rust persistence command, new input-lock reasons, or desktop WebDriver infrastructure.