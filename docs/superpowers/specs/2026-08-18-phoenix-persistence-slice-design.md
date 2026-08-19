# Phoenix Persistence Slice Design (HPA-596)

**Status:** Draft for review

**Date:** 2026-08-18

**Delivery target:** browser-development and Tauri one-slot persistence

## Source of truth

This design implements HPA-596, `[Persistence Slice] Add one-slot autosave and continue`, against the current `main` after HPA-595 shipped.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves the persistence boundary against the code that exists now: `GameSession` is the mutable gameplay authority, `ProofScene` is an adapter, `App.svelte` owns screen-space lifecycle/modal orchestration, and the Tauri side is currently only the desktop shell.

## Outcome

Phoenix opens on a small title screen instead of immediately constructing Phaser. The player can start a fresh run or continue one valid save. Sleeping completes the existing overnight mutation first, then writes exactly one versioned snapshot of the completed new-morning gameplay state. Closing and reopening the desktop app or reloading browser development can continue that run at the authored map spawn while preserving all gameplay state.

The implementation adds one explicit persistence boundary and two concrete storage adapters. It does not add slots, migrations, backup rotation, save-anywhere, a persistence framework, a second state owner, or Rust gameplay logic.

## Approved lean shape

- Introduce a plain `GameState` DTO containing only mutable gameplay state.
- Keep `GameSnapshot` as the presentation/read model; do not serialize it directly.
- Restore `GameSession` from optional `initialState` while reconstructing world position from the authored map spawn.
- Add one `SaveFileV1` wrapper with `schemaVersion: 1` and structural validation from `unknown`.
- Add one `SaveRepository` interface with `load()` and `save()` only.
- Use `localStorage` in normal browser development and the official Tauri Store plugin under `tauri dev` / `tauri build`.
- Select the repository once during application startup; gameplay/UI code never branches on environment.
- Mount Phaser only after New Game or Continue is selected.
- Autosave only after successful `sleep()` has emitted the complete next-morning snapshot.
- Keep the existing pending day-summary gate as the natural blocking surface while the save write is in flight.
- Surface only `Saving…`, `Saved`, and a clear save error.

## Why `GameSnapshot` is not the save format

`GameSnapshot` currently combines:

1. mutable gameplay state such as day, weather, money, farm tiles, inventory, shipments, and relationships;
2. transient world state such as player position, facing, and current target;
3. authored/static interaction data such as bed, shop, shipping, and villager cells.

Only the first category belongs in a save. Serializing the whole snapshot would make movement state and map-derived cells part of persistence, contradicting HPA-596's requirement to resume at a fixed spawn and avoid projected/runtime state.

`GameState` is therefore the one serialization DTO while `GameSnapshot` remains optimized for rendering, interaction, and tests.

## Persisted gameplay state

Split relationship persistence from the derived UI/read field:

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

Add the exact mutable rules state:

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

- `maxStamina`, because it is a current rules constant rather than mutable player state;
- player position/facing and target;
- camera scroll/bounds;
- bed/shop/shipping/villager cells;
- collision footprints, Tiled objects, projected/world coordinates;
- Phaser sprites/scenes/controllers/resources;
- Svelte modal state, feedback, title state, and save status;
- villager content and derived relationship level.

`pendingDaySummary` is persisted. The real autosave occurs while the new morning summary is pending; reopening should show that same summary and preserve the existing `day-summary-pending` command gate until `Start Day N`.

`selectedAction` and `selectedSeed` are also persisted because they are current authoritative mutable fields. The rule stays simple: every mutable gameplay field owned by `GameSession` is represented once.

## State extraction and restore

### Export

`src/persistence/saveFile.ts` owns one pure extraction helper:

```ts
export function gameStateFromSnapshot(snapshot: GameSnapshot): GameState;
```

It deep-clones mutable data and strips presentation/static fields plus relationship `level`.

This is sufficient because `ProofScene.publishCommand()` synchronously publishes the post-command `GameSnapshot` before `commands.sleep()` returns. `App.svelte` can therefore create the save from its updated snapshot immediately after a successful `day-advanced` result. No second state channel or `getState` scene command is needed.

### Restore

Extend the existing constructor input:

```ts
export interface GameSessionConfig {
  // current authored config
  initialState?: GameState;
}
```

Construction still clones/validates the authored world, farm cells, interaction cells, and villager cells first. If `initialState` is present, it validates current-version domain expectations and deep-clones those values into the existing mutable fields.

Current-version restore validation requires:

- legal current day/time/stamina/money/counts;
- current weather/action/crop unions only;
- exactly one saved farm tile for each current authored farm cell, with no duplicate or foreign positions;
- legal crop growth/watered state;
- exactly the three current villager relationship records;
- structurally valid pending day summary and shipment lines when present.

There is no coercion, repair, or compatibility path.

`ProofWorld` is always constructed from the current authored `ProofMap`. Continue therefore starts at the existing `parsed.world.spawn` marker (currently 2.5,9.5) using normal initial facing/target behavior. Saved player movement never participates in restore.

## Save file format

Create `src/persistence/saveFile.ts`:

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

`parseSaveFile` accepts only `unknown`, requires a plain object and exact `schemaVersion === 1`, validates the current state shape, then returns fresh cloned data. Errors use a concise `Invalid save: ...` prefix.

Do not add Zod, JSON Schema, codec dependencies, migration registries, per-version folders, or compatibility fallbacks. There is one version and no real user data to preserve yet.

## Storage boundary

Create `src/persistence/saveRepository.ts`:

```ts
export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}

export async function createSaveRepository(): Promise<SaveRepository>;
```

Repositories only store/retrieve the versioned object. Shared validation stays above the adapter boundary.

### Browser adapter

`LocalStorageSaveRepository` uses one key:

```text
phoenix.save.v1
```

`load()` returns `null` when absent, otherwise JSON-parses the text to `unknown`. Invalid JSON rejects with a clear message for title bootstrap.

`save()` performs one `JSON.stringify` and one `localStorage.setItem`.

No second key, temp key, backup, IndexedDB wrapper, or generic storage framework is needed.

## Tauri Store adapter

Use the official Tauri Store plugin instead of a custom Rust filesystem command.

Pin exactly:

```json
"@tauri-apps/plugin-store": "2.4.4"
```

and:

```toml
tauri-plugin-store = "=2.4.4"
```

Tauri's Vite integration exposes `TAURI_ENV_*` values to frontend hook builds when configured through Vite's `envPrefix`. Add only:

```ts
envPrefix: ['VITE_', 'TAURI_ENV_*'],
```

`createSaveRepository()` checks `import.meta.env.TAURI_ENV_PLATFORM`. When it is absent (normal `bun run dev` / browser build), return the localStorage adapter without importing Store. When present (`tauri dev` / `tauri build`), dynamically import `@tauri-apps/plugin-store` and create the Tauri adapter.

This avoids a direct `@tauri-apps/api` dependency and keeps the environment branch in one factory. Do not expose the broad `TAURI_` prefix.

Initialize one store file and one entry:

```ts
const { load } = await import('@tauri-apps/plugin-store');
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});

await store.set('save', file);
await store.save();
```

`defaults: {}` is explicit for the current Store options. `autoSave: false` is deliberate: Phoenix has one product-defined autosave transaction, so explicit `store.save()` gives one completion/error point instead of relying on plugin debounce.

Rust registers the plugin once:

```rs
.plugin(tauri_plugin_store::Builder::default().build())
```

The main-window capability adds:

```json
"store:default"
```

No custom command, Rust DTO, filesystem path handling, serializer, encryption, or Store listener is needed.

Do not silently fall back from failed Tauri Store initialization to localStorage. That would make desktop persistence appear successful while writing to the wrong backend. New Game may remain playable, but saving must report unavailable/failure.

## Title and startup flow

Add `TitleScreen.svelte` inside the existing 640×360 `StageFrame`.

`App.svelte` owns:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';

let saveRepository: SaveRepository | null;
let loadedSave: SaveFileV1 | null;
let titleError: string | null;
let initialState: GameState | null;
```

Startup runs once:

1. create repository;
2. load raw value;
3. absent -> title with Continue disabled;
4. parsed V1 -> title with Continue enabled;
5. load/parse failure -> title error, Continue disabled, New Game enabled.

New Game sets `initialState = null` and enters `playing`.

Continue clones `loadedSave.state` into `initialState` and enters `playing`.

Only `playing` mounts `GameHost`, `Overlay`, and dialogue UI. `GameHost` accepts `initialState`, carries it in `ProofSceneDependencies`, and `ProofScene` passes it to the existing `GameSession` constructor.

There is no return-to-title/pause-menu feature in HPA-596.

Starting New Game does not immediately delete an existing save. The next successful sleep overwrites the single slot, avoiding an extra destructive confirmation flow.

## Autosave transaction

Keep overnight mutation exactly where it is: `GameSession.sleep()`.

`App.svelte::confirmSleep()` becomes async but preserves command ordering:

1. duplicate-submit guard;
2. call `commands.sleep()` once;
3. if not `day-advanced`, do not save;
4. capture the synchronously published post-sleep `gameSnapshot`;
5. set status `saving`;
6. call repository `save(createSaveFile(snapshot))` exactly once;
7. set `saved` only after resolution;
8. on rejection, set `error` with message;
9. release submit state after the attempt settles.

The successful day transition is never rolled back if persistence fails. The latest run remains playable; the UI accurately reports that the new morning was not saved.

After `sleep()` succeeds, close the sleep-confirm dialog so the existing morning summary is visible during the write. Keep `Start Day N` disabled while `saving`; after success or failure it can be acknowledged normally. The existing pending summary already locks world input, so no new `InputGate` reason is needed.

## Save feedback

Use only:

```ts
export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
```

`Overlay.svelte` renders one stable `data-save-status` element for:

- `Saving…`
- `Saved`
- `Save failed: <message>`

`Saved` can remain until the next save attempt. No timer, toast framework, retry queue, animation, or log panel.

## Error behavior

- No save: Continue disabled, no error.
- Malformed localStorage JSON: Continue disabled, clear error, New Game enabled.
- Unsupported version: same.
- Structurally invalid V1: same.
- Tauri Store init/load failure: Continue disabled, storage error shown, New Game enabled.
- Save write failure: gameplay remains advanced; status becomes error, never saved.
- Restore rejected by `GameSession`: use the existing world error path; do not mutate/repair data.

Do not auto-delete a bad save. A later successful New Game sleep naturally overwrites it.

## Testing strategy

### Unit/pure tests

Extend `GameSession.test.ts` with full restore fixtures proving every mutable gameplay field restores while player world position does not.

Create `saveFile.test.ts` for V1 creation/deep clone, every current state field, unknown version, malformed state, and absence of static/render fields.

Create `saveRepository.test.ts` with a tiny fake `Storage` and narrow Store fake. Prove local missing/load/save/malformed behavior and factory selection. The Tauri failure case must not fall back to localStorage.

### Browser Playwright

Create `tests/e2e/persistence.pw.ts`:

1. fresh title -> Continue disabled -> New Game;
2. perform representative farming + social interaction, sleep, observe Saved, reload, Continue, verify same pending morning/gameplay state at authored spawn, then Start Day;
3. place malformed browser storage, reload, verify error + disabled Continue + usable New Game.

Keep `window.__PHOENIX_TEST__` observation-only.

The existing economy E2E already proves the long buy/grow/ship journey. The persistence round-trip unit fixture covers non-zero pending shipment state directly, while the browser test proves the actual autosave/reload orchestration without duplicating that long route.

### Tauri Store smoke

Do not add a desktop WebDriver harness solely for this ticket. The implementation PR must record one focused `bun run tauri:dev` close/reopen smoke:

1. New Game;
2. make a visible change;
3. sleep and observe Saved on morning summary;
4. close;
5. relaunch;
6. Continue;
7. verify same morning gameplay state at authored spawn.

The existing Tauri build remains a required gate.

## Dependency/configuration impact

Expected dependency/platform changes are limited to:

- `package.json` / `bun.lock`: add `@tauri-apps/plugin-store` 2.4.4;
- `vite.config.ts`: expose `TAURI_ENV_*` alongside `VITE_`;
- `src-tauri/Cargo.toml` / `Cargo.lock`: add `tauri-plugin-store = "=2.4.4"`;
- `src-tauri/src/lib.rs`: register Store;
- `src-tauri/capabilities/default.json`: add `store:default`;
- `tests/config/scaffold.test.ts`: update exact dependency/config assertions.

No gameplay Rust code is added.

## Expected file ownership

Create:

- `src/persistence/saveFile.ts`
- `src/persistence/saveRepository.ts`
- `src/components/TitleScreen.svelte`
- `tests/game/saveFile.test.ts`
- `tests/game/saveRepository.test.ts`
- `tests/e2e/persistence.pw.ts`

Modify:

- `src/game/core/types.ts`
- `src/game/core/GameSession.ts`
- `src/game/phaser/ProofScene.ts`
- `src/components/GameHost.svelte`
- `src/components/Overlay.svelte`
- `src/App.svelte`
- `src/app.css`
- `vite.config.ts`
- `package.json`
- `bun.lock`
- `src-tauri/Cargo.toml`
- `src-tauri/Cargo.lock`
- `src-tauri/src/lib.rs`
- `src-tauri/capabilities/default.json`
- `tests/game/GameSession.test.ts`
- `tests/config/scaffold.test.ts`
- `README.md`
- `tests/config/handoff.test.ts`

No planned changes:

- authored map or generated sprite assets;
- `ProofWorld`, projection, collision, camera, `InputGate`, or daily-rhythm rules;
- crop/villager definitions;
- CI workflow structure or Playwright config.

## Non-goals

Multiple slots, manual save-anywhere, delete/rename UI, overwrite confirmation, save thumbnails, backups, atomic rotation, compression, encryption, cloud/Steam sync, cross-device transfer, migration infrastructure, backwards compatibility for development saves, arbitrary player-position persistence, camera/UI restoration, pause-menu title navigation, telemetry, database storage, and custom Rust persistence commands are outside HPA-596.

## Acceptance mapping

- **One save after sleep:** App saves only after one successful `day-advanced`; Tauri Store plugin autosave is disabled.
- **Equivalent desktop restore:** `GameState` includes every mutable gameplay field; native smoke closes/reopens.
- **Browser development:** normal browser path selects localStorage and does not dynamically import Store.
- **No render/runtime state:** save excludes world/player/camera/Tiled/Phaser/Svelte fields.
- **Continue availability:** only a successfully parsed V1 enables Continue.
- **Bad save recovery:** title reports error while New Game remains available.
- **Visible failures:** `saved` is assigned only after repository resolution; rejection is displayed.
- **Complete round trip:** unit tests compare every current mutable gameplay field.
- **Farming/shipping/social:** representative state fixture covers all domains; browser E2E proves the real save/reload flow.
