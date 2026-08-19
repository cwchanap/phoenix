# Phoenix Persistence Slice Design (HPA-596)

**Status:** Draft for review

**Date:** 2026-08-18

**Delivery target:** browser-development and Tauri one-slot persistence

## Source of truth

This design implements HPA-596, `[Persistence Slice] Add one-slot autosave and continue`, against the current `main` after HPA-595 shipped.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves the persistence boundary against the code that exists now: `GameSession` is the mutable gameplay authority, `ProofScene` is an adapter, `App.svelte` owns screen-space lifecycle/modal orchestration, and the current Tauri shell has no gameplay logic.

## Outcome

Phoenix opens on a small title screen instead of immediately constructing Phaser. The player can start a fresh run or continue one valid save. Sleeping advances the existing overnight transaction first, then writes exactly one versioned snapshot of the completed new-morning gameplay state. Closing and reopening the desktop app or reloading browser development can continue that run at the authored player spawn while preserving all gameplay state.

The implementation adds one explicit persistence boundary and two real storage adapters. It does not add slots, migrations, backup rotation, save-anywhere, a persistence framework, a second game-state owner, or Rust gameplay logic.

## Approved lean shape

- Introduce a plain `GameState` DTO containing only mutable gameplay state.
- Keep `GameSnapshot` as the presentation/read model; do not serialize it directly.
- Restore `GameSession` from optional `initialState` while reconstructing world position from the authored map spawn.
- Add one `SaveFileV1` wrapper with `schemaVersion: 1` and structural validation from `unknown`.
- Add one `SaveRepository` interface with `load()` and `save()` only.
- Use `localStorage` in browser development and the official Tauri Store plugin in Tauri.
- Select the repository once during application startup; gameplay and UI never branch on environment.
- Mount Phaser only after New Game or Continue is selected.
- Autosave only after successful `sleep()` has emitted the completed next-morning snapshot.
- Keep the existing pending day-summary gate. While the save write is in flight, the morning summary remains the natural blocking surface.
- Surface only `Saving…`, `Saved`, and a clear save error. Do not add progress, retry queues, notifications, or save history.

## Why `GameSnapshot` is not the save format

`GameSnapshot` currently combines three categories:

1. mutable gameplay state such as day, weather, money, farm tiles, inventory, shipments, and relationships;
2. transient world state such as player position, facing, and current target;
3. authored/static interaction data such as bed, shop, shipping, and villager cells.

Only the first category belongs in a save. Persisting the whole snapshot would accidentally make Phaser-facing movement state and map-derived cells part of the compatibility surface, directly contradicting HPA-596's requirement to resume at a fixed spawn and avoid projected/runtime state.

`GameState` therefore becomes the single serialization DTO while `GameSnapshot` stays optimized for rendering, interaction, and tests.

## Persisted gameplay state

Add a persistence-safe relationship shape that excludes the derived relationship level:

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

Add the exact mutable gameplay state:

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
- Phaser sprites, scenes, controllers, or resource handles;
- Svelte modal state, feedback text, save status, or component state;
- villager display content and derived `RelationshipLevel`.

`pendingDaySummary` is persisted. A real autosave happens while the new morning summary is still pending; reopening should show that same summary and preserve the existing `day-summary-pending` command gate until the player presses `Start Day N`.

`selectedAction` and `selectedSeed` are also persisted because they are current authoritative mutable fields. This keeps the round-trip definition simple: every mutable gameplay field owned by `GameSession` is represented once.

## State extraction and restore

### Export

Add one pure helper next to the save shape:

```ts
export function gameStateFromSnapshot(snapshot: GameSnapshot): GameState;
```

It deep-clones mutable data and strips presentation-only fields plus the derived relationship `level`.

This uses the already-published post-command `GameSnapshot`. `ProofScene.publishCommand()` synchronously publishes the new snapshot before `commands.sleep()` returns, so `App.svelte` can call `gameStateFromSnapshot(gameSnapshot)` immediately after a successful `day-advanced` result without adding another scene command or mutable state channel.

### Restore

Extend `GameSessionConfig` with:

```ts
initialState?: GameState;
```

Construction still clones and validates the authored map/world/farm/interaction configuration first. If `initialState` is present, `GameSession` deep-clones it into the existing mutable fields after validating the state against current domain expectations.

Restore validation is intentionally current-version only:

- day/time/stamina/money/counts are finite safe integers in their current legal ranges;
- weather, selected action, crop kinds, and relationship IDs are current closed unions;
- there is exactly one saved farm tile for every current authored farm cell, with no duplicates or foreign positions;
- crop growth is a non-negative safe integer and current crop kinds are supported;
- all three current villager relationship records are present;
- optional day-summary shipment lines are structurally valid.

There is no coercion and no repair path. Invalid development saves are rejected.

The `ProofWorld` is always constructed from the current authored `ProofMap`, so Continue starts at `parsed.world.spawn` (currently the existing 2.5,9.5 marker) with the normal initial facing/target behavior. Saved player movement never influences restore.

## Save file format

Create `src/persistence/saveFile.ts`:

```ts
export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

export function createSaveFile(snapshot: GameSnapshot): SaveFileV1;
export function parseSaveFile(value: unknown): SaveFileV1;
```

`createSaveFile` delegates to `gameStateFromSnapshot` and returns fresh data.

`parseSaveFile` accepts only `unknown`. It first requires a plain object and exact `schemaVersion === 1`, then validates the current state shape. It returns a fresh cloned `SaveFileV1` or throws a concise `Invalid save: ...` error.

Do not add Zod, JSON Schema, a codec library, migration tables, per-version parsers, or compatibility fallbacks. There is one version and no real user data to preserve yet.

## Storage boundary

Create `src/persistence/saveRepository.ts`:

```ts
export interface SaveRepository {
  load(): Promise<unknown | null>;
  save(file: SaveFileV1): Promise<void>;
}

export async function createSaveRepository(): Promise<SaveRepository>;
```

Repositories store/retrieve the versioned file and do not understand gameplay rules. Parsing stays above the adapter boundary so both backends share identical validation.

### Browser adapter

`LocalStorageSaveRepository` uses exactly one key:

```text
phoenix.save.v1
```

`load()` returns `null` when absent, otherwise parses the stored JSON text into `unknown`. Invalid JSON rejects with an explicit error that the title bootstrap can display.

`save()` uses `JSON.stringify(file)` followed by one `localStorage.setItem`.

There is no second key, temp key, backup key, IndexedDB wrapper, or storage abstraction beyond `SaveRepository`.

### Tauri adapter

Use the official Tauri Store plugin rather than a custom Rust command or filesystem API.

Pin the current Store release used by this plan:

```json
"@tauri-apps/api": "2.11.1",
"@tauri-apps/plugin-store": "2.4.4"
```

and:

```toml
tauri-plugin-store = "=2.4.4"
```

The direct `@tauri-apps/api` dependency is used only for its public `isTauri()` runtime probe. `@tauri-apps/plugin-store` is dynamically imported only when that probe is true, so browser startup never executes Store plugin code.

Initialize one store file and one entry:

```ts
const store = await load('phoenix-save.json', {
  defaults: {},
  autoSave: false,
});

await store.set('save', file);
await store.save();
```

`defaults: {}` is explicit because the current Store options require a defaults object. `autoSave: false` is deliberate: Phoenix has one product-defined autosave transaction, so explicit `store.save()` makes completion/error semantics match the UI instead of relying on the plugin's debounce.

Rust registers the plugin once:

```rs
.plugin(tauri_plugin_store::Builder::default().build())
```

The main-window capability adds:

```json
"store:default"
```

No custom command, Rust DTO, filesystem path resolution, serializer, encryption, or Store event listener is required.

### Backend selection

`createSaveRepository()` is the only environment branch:

1. if public `isTauri()` is true, dynamically import the Store plugin and return `TauriStoreSaveRepository`;
2. otherwise return `LocalStorageSaveRepository(window.localStorage)`.

Do not silently fall back from a failed Tauri Store initialization to `localStorage`. That would make desktop persistence appear successful while writing to a different backend. The title can still allow New Game, but it must show that saving is unavailable.

## Title and startup flow

Add `TitleScreen.svelte` as a small screen-space component inside the existing 640×360 `StageFrame`.

`App.svelte` owns one application phase:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing';
```

and startup state:

```ts
let saveRepository: SaveRepository | null;
let loadedSave: SaveFileV1 | null;
let titleError: string | null;
let initialState: GameState | null;
```

Startup runs once:

1. create the repository;
2. call `load()`;
3. if absent, show title with Continue disabled;
4. if present and `parseSaveFile` succeeds, store it and enable Continue;
5. if load or validation fails, retain a clear title error, disable Continue, and still enable New Game.

New Game sets `initialState = null` and switches to `playing`.

Continue clones `loadedSave.state` into `initialState` and switches to `playing`.

Only the playing branch mounts `GameHost`, `Overlay`, and dialogue UI. `GameHost` accepts `initialState` and carries it in `ProofSceneDependencies`; `ProofScene` passes it to the one `GameSession` constructor.

There is no pause-menu return-to-title action in HPA-596.

Starting New Game does not immediately delete or overwrite an existing save. The next successful sleep replaces the single save. This avoids inventing a destructive confirmation flow for the MVP.

## Autosave transaction

Keep overnight gameplay mutation exactly where it is now: `GameSession.sleep()`.

`App.svelte::confirmSleep()` becomes asynchronous but preserves the existing command ordering:

1. guard against duplicate submit;
2. call `commands.sleep()` once;
3. if it does not return `day-advanced`, do not save;
4. use the synchronously published post-sleep `gameSnapshot` to create `SaveFileV1`;
5. set save status to `saving`;
6. write exactly once through the startup-selected repository;
7. set status to `saved` only after the write resolves;
8. on rejection, set status to `error` and retain the error message;
9. release submit state after the save attempt completes.

The successful day transition is not rolled back if persistence fails. Gameplay state remains valid; the UI simply reports that the latest morning was not saved.

While status is `saving`, the existing pending morning summary remains visible and blocking. `Start Day N` is disabled until the save promise settles. After success or failure, the player may start the day normally. No new `InputGate` reason is needed.

## Save feedback

Add only:

```ts
export type SaveStatus = 'idle' | 'saving' | 'saved' | 'error';
```

`Overlay.svelte` receives the current status/error and renders a small `data-save-status` element:

- `Saving…`
- `Saved`
- `Save failed: <message>`

`Saved` may remain visible until the next save attempt. Do not add timers, toasts, animated spinners, retries, or logs to persistent UI.

The title uses its own load/validation message; save-status state starts fresh when gameplay begins.

## Error behavior

Errors are deliberately recoverable but not repaired:

- no save: Continue disabled, no error;
- malformed JSON/localStorage value: Continue disabled, clear invalid-save message, New Game enabled;
- unsupported `schemaVersion`: same behavior;
- structurally invalid V1 state: same behavior;
- Tauri Store initialization/load failure: Continue disabled, storage error shown, New Game enabled;
- save write failure: gameplay continues, status becomes error, never `saved`;
- restored state rejected by `GameSession`: world load fails through the existing `onError` path rather than mutating/repairing data.

Do not delete a bad save automatically. A later successful New Game sleep naturally overwrites the single slot.

## Testing strategy

### Pure/unit coverage

Extend `GameSession.test.ts` with a representative round trip that proves every mutable gameplay field survives `GameState` export/restore while world position does not.

The representative state must exercise:

- advanced day/time/stamina/weather;
- selected action/seed;
- tilled soil and a growing crop;
- seed/crop inventory and money;
- a non-zero pending shipment in a pre-sleep state;
- social points/daily flags and a one-time Close Friend flag;
- a pending day summary in a post-sleep state.

The test reconstructs a second `GameSession` with the same authored config plus `initialState` and compares exported game state field-for-field. It also verifies the second session player starts at the authored spawn, independent of the original session's moved world position.

Create `saveFile.test.ts` for:

- exact V1 creation and deep cloning;
- every current `GameState` field present in the round trip;
- unknown version rejection;
- malformed/missing top-level fields;
- invalid unions/counts/farm/relationship structures;
- derived/static/presentation fields absent from the saved shape.

Repository tests use a tiny fake `Storage` for localStorage behavior rather than JSDOM.

### Browser Playwright

Create `tests/e2e/persistence.pw.ts` with three product-visible paths:

1. fresh load shows title, Continue disabled, New Game launches the current world;
2. perform representative farming + social interaction, sleep, observe `Saved`, reload, Continue, verify the persisted morning summary/state and authored player spawn, then start the day;
3. inject malformed browser storage before reload, verify Continue is disabled with a clear error, then verify New Game still launches.

Do not add state-mutating methods to `window.__PHOENIX_TEST__`. Existing observation-only hooks and normal UI controls remain the acceptance seam.

The longer economy E2E already proves real buy/grow/ship behavior. Persistence unit round-trip covers non-zero pending shipments directly, while the browser path proves the actual one-save-after-sleep orchestration without duplicating the full economy playthrough.

### Tauri Store smoke

Because the repository has no desktop WebDriver harness, do not create one for this ticket.

The implementation PR must include one explicit `bun run tauri:dev` smoke in its validation notes:

1. New Game;
2. make one visible gameplay change;
3. sleep and observe `Saved` on the morning summary;
4. close the Tauri window;
5. relaunch `bun run tauri:dev`;
6. verify Continue is enabled;
7. Continue and verify the same morning state at the authored spawn.

The existing `bun run tauri:build -- --no-sign` remains the packaging/build gate.

## Dependency and configuration impact

HPA-596 is the first slice that legitimately changes the desktop shell dependencies.

Expected changes:

- `package.json` / `bun.lock`: add exact `@tauri-apps/api` and Store plugin versions;
- `src-tauri/Cargo.toml` / `Cargo.lock`: add Store plugin;
- `src-tauri/src/lib.rs`: register Store;
- `src-tauri/capabilities/default.json`: grant `store:default`;
- `tests/config/scaffold.test.ts`: update exact direct dependency expectations and assert Store wiring.

No Tauri command or gameplay Rust module is added.

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

- authored Tiled map or generated sprite assets;
- `ProofWorld.ts`, projection, collision, or camera rules;
- `InputGate.ts` / `GateBoundKeys.ts`;
- `dailyRhythm.ts`, crop definitions, villager definitions;
- economy/social feature rules;
- CI workflow structure or Playwright config.

## Non-goals

Multiple save slots, manual save-anywhere, delete/rename slot UI, overwrite confirmation, save thumbnails, backups, atomic multi-file rotation, compression, encryption, cloud sync, Steam Cloud, cross-device transfer, migration infrastructure, backwards compatibility for development saves, persistent arbitrary player position, camera persistence, UI restoration, pause-menu title navigation, telemetry, database storage, and custom Rust persistence commands are all outside HPA-596.

## Acceptance mapping

- **One save after sleep:** the App calls `save()` only after one successful `day-advanced`; `autoSave` is disabled for Tauri Store.
- **Equivalent desktop restore:** `GameState` covers every mutable gameplay field, and the Tauri smoke closes/reopens the app.
- **Browser development:** localStorage is selected at startup and the Store plugin is not executed there.
- **No runtime-render state:** save shape excludes world/player/camera/Tiled/Phaser/Svelte state.
- **Continue availability:** only a successfully parsed V1 enables Continue.
- **Bad save recovery:** errors stay on title while New Game remains enabled.
- **Visible failures:** `saved` is assigned only after repository resolution; rejection surfaces as `error`.
- **Complete round trip:** unit tests compare current mutable state field-for-field.
- **Farming/shipping/social:** representative round-trip covers all three domains; browser E2E proves real autosave/reload orchestration.
