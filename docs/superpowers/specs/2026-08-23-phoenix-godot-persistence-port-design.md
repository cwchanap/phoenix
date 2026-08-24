# Phoenix Godot Persistence Port Design (HPA-598)

**Status:** Draft for review

**Date:** 2026-08-23

**Delivery target:** Godot one-slot autosave and Continue

## Source of truth

This design implements HPA-598, `[Godot Persistence Port] Restore one-slot autosave and continue`, against `main` after HPA-594 merged. The repository state reviewed for this plan includes current `main` at `39892813ec985d6db4491c4e2af3b98277cf06b8`.

The live Linear issue and Phoenix project description remain authoritative for product scope, delivery order, and non-goals. This document resolves the implementation details against the Godot code that now exists:

- `GameSession` is already the only mutable gameplay authority and owns farming, economy, daily rhythm, shipping, morning summaries, and relationship state.
- `GameSession.snapshot()` already returns a deep-cloned plain read model.
- `WorldShell` is the only production session holder and currently constructs a fresh `GameSession` eagerly.
- `GameHud` already owns the blocking morning-summary modal and the single world-input gate.
- `project.godot` currently boots directly into `scenes/world/world.tscn`.
- `WorldContract.PLAYER_SPAWN` remains the authored player spawn; position/facing/camera are presentation state, not gameplay state.
- Godot `FileAccess` supports persistent `user://` files in exported builds, so HPA-598 needs no platform plugin or second storage adapter.

## Outcome

Phoenix opens on a small title screen. `New Game` always starts a fresh `GameSession`; `Continue` is enabled only when the single local save exists, parses as schema version 1, and satisfies the current Godot gameplay rules.

Sleeping remains a gameplay transaction owned by `GameSession`. After `sleep()` has successfully produced the complete next-morning state and blocking morning summary, `WorldShell` writes exactly one versioned JSON save to `user://phoenix-save.json`. The player can then acknowledge the summary and continue. Save failure is visible but never rolls back the already completed overnight gameplay transition.

On restart, Continue reconstructs the authoritative gameplay state and instantiates the same authored world scene. The player always starts at `WorldContract.PLAYER_SPAWN`; arbitrary world position, facing, camera, and modal focus are never persisted.

The implementation remains one PR and adds no migration framework, compatibility layer, backup rotation, cloud save, save-anywhere, second runtime, global save singleton, or generic repository interface.

## Approaches considered

### 1. Small app root + concrete FileAccess repository — recommended

Add one long-lived application root that owns the title/game launch boundary and one concrete `SaveRepository` that writes `user://phoenix-save.json`. The root validates a save before enabling Continue, then instantiates `world.tscn` and passes only the optional restored state plus the repository into `WorldShell`.

This keeps responsibilities narrow:

- app root: title/load/launch lifecycle;
- `GameSession`: mutable gameplay state plus current-rule restore validation;
- save codec: JSON schema conversion and structural parsing;
- concrete repository: one file path and FileAccess I/O;
- `WorldShell`: owns the live session and performs the one overnight save;
- HUD/title: presentation only.

It costs a few focused files but avoids turning either the world scene or an autoload into a mixed application manager.

### 2. Put title/load/save directly in WorldShell — rejected

This would add the fewest files, but the world would exist before the player chooses New Game or Continue and `WorldShell` would gain title lifecycle, storage bootstrap, gameplay coordination, and save presentation responsibilities. That makes the existing coordinator harder to understand and gives HPA-597 a worse seam to extend.

### 3. Autoload `SaveManager` singleton — rejected

An autoload is common in larger Godot projects, but Phoenix currently has one save file, one consumer, and no cross-scene save service requirement. A global manager would be a service locator introduced before there is a second caller. HPA-598 stays with explicit object ownership instead.

## Architecture

### Application root

Create:

- `scenes/app/app.tscn`
- `scripts/app/app_root.gd`
- `scenes/ui/title_screen.tscn`
- `scripts/ui/title_screen.gd`

`project.godot` changes `run/main_scene` from `world.tscn` to `app.tscn`.

`AppRoot` owns exactly one `SaveRepository` instance and one optional prevalidated Continue state. On `_ready()` it loads the save once:

1. missing file → Continue disabled;
2. JSON/schema/shape failure → Continue disabled with a short non-blocking status;
3. structurally valid but current-rule-incompatible state → Continue disabled with a short non-blocking status;
4. valid state → cache a deep clone and enable Continue.

`New Game` does not delete the old file. It launches a fresh session, and the next successful overnight save replaces the one slot. This avoids adding a destructive/delete path that HPA-598 does not require.

When either title action launches gameplay, `AppRoot` instantiates `scenes/world/world.tscn`, configures it before adding it to the tree, hides the title, and lets `WorldShell` remain the only live gameplay-session holder. HPA-598 does not add a route back to the title screen during play.

### Title screen

`TitleScreen` is presentation only. It owns:

- a Phoenix title label;
- `New Game` button;
- `Continue` button;
- one small status label for missing/invalid/incompatible save feedback.

It emits `new_game_requested` and `continue_requested`. It never imports or creates `GameSession`, `SaveRepository`, or `WorldShell`.

Continue is disabled until `AppRoot` supplies one validated state.

## Canonical gameplay state

### Separate mutable state from the view snapshot

Add one canonical `GameSession.state()` projection containing only mutable gameplay state:

```gdscript
func state() -> Dictionary:
    return {
        "day": _day,
        "time_minutes": _time_minutes,
        "stamina": _stamina,
        "weather": GameRules.weather_key(_weather),
        "selected_action": GameRules.action_key(_selected_action),
        "selected_seed": GameRules.crop_key(_selected_seed),
        "money": _money,
        "seeds": _counts_snapshot(_seed_counts),
        "harvested": _counts_snapshot(_harvested_counts),
        "pending_shipment": _counts_snapshot(_pending_shipment_counts),
        "farm": _farm_state(),
        "pending_morning_summary": _pending_morning_summary,
        "relationships": _relationships_state(),
    }.duplicate(true)
```

`state()` deliberately excludes derived/presentation values:

- `max_stamina`;
- relationship `level`;
- player position/facing/current target;
- camera state;
- fixed bed/shop/shipping/villager cells outside the farm identity carried by farm entries;
- collision footprints and scene nodes;
- HUD/dialogue/modal/focus/feedback state.

Refactor `snapshot()` to derive from the canonical state and add only the existing derived fields needed by views. Do not maintain two unrelated hand-enumerated mutable-field lists.

### Farm identity

The persisted farm array carries the authored cell for each of the nine entries. The JSON representation encodes a cell as:

```json
{"x": 2, "y": 7}
```

On restore, current-rule validation requires the save to contain exactly `WorldContract.farm_cells()` in the current authored order. HPA-598 does not repair, reorder, or migrate a mismatched farm.

### Relationship state

Persist for all three villagers:

- `points`;
- `talked_today`;
- `gifted_today`;
- `close_friend_dialogue_seen`.

Relationship `level` remains derived through `VillagerRules.relationship_level(points)` and is never stored.

### Pending morning summary

Persist `pending_morning_summary` exactly because autosave occurs after `sleep()` creates the next-morning state but before the summary is acknowledged. A player who closes the app immediately after a successful save must see the same blocking summary after Continue.

The summary remains nullable so the state shape is usable by future save points without changing the schema merely to represent “no summary”. HPA-598 itself still writes only after successful overnight advancement.

## Restore validation ownership

### Structural JSON validation belongs to the save codec

Create `scripts/persistence/save_file.gd` with `class_name SaveFileCodec`.

The single schema is:

```json
{
  "schema_version": 1,
  "state": { "...": "GameSession mutable state" }
}
```

The codec owns:

- exact `schema_version == 1`;
- required top-level/state fields;
- Dictionary/Array/boolean/string/integer-shaped JSON types;
- closed string keys for crop/action/weather/villager identifiers;
- farm/crop/relationship/morning-summary nested structure;
- conversion between runtime `Vector2i` farm cells and `{x,y}` JSON objects.

Godot JSON numbers deserialize as numeric Variants rather than preserving an integer JSON type, so integer helpers must accept only finite whole numbers and convert them to `int`. Do not silently truncate fractional values.

The codec does not own gameplay ranges such as `MAX_DAY`, `MAX_STAMINA`, current crop growth limits, current authored farm cells, or summary consistency. Those belong to `GameSession`/current content.

Use `JSON.new().parse(text)` rather than only `JSON.parse_string()` so invalid JSON can produce a useful error message without crashing the title flow. Use `JSON.stringify()` for writes. Do not add a schema library or generic parser framework; a few file-local parsing helpers are sufficient.

### Current-rule validation belongs to GameSession

Add one static validator shared by title bootstrap and restore:

```gdscript
static func state_error(candidate: Variant) -> String:
    # empty string means valid
```

At minimum it rejects:

- day outside `1..GameRules.MAX_DAY`;
- time outside `GameRules.DAY_START_MINUTES..GameRules.ACTION_CUTOFF_MINUTES`;
- stamina outside `0..GameRules.MAX_STAMINA`;
- negative money, seed, harvested, pending-shipment, or relationship counts;
- unknown selected action/seed/weather keys;
- a farm count/order/cell identity different from `WorldContract.farm_cells()`;
- crop on untilled soil;
- unknown crop kind;
- crop growth outside `0..GameRules.growth_nights(kind)`;
- missing/extra villager relationship entries;
- inconsistent pending morning summary identity, including `next_day != state.day`, wrong `next_weather`, or `money_after_shipping != state.money`.

Add:

```gdscript
func restore_state(candidate: Dictionary) -> bool:
```

It calls the same validator, mutates nothing on failure, and on success deep-copies the candidate into private session arrays/dictionaries. No save parser reaches into private fields with `set()`.

`AppRoot` uses `GameSession.state_error()` before enabling Continue. `WorldShell` then restores the already validated state into its newly created session before the first HUD/farm render.

There is no migration attempt. An unsupported or incompatible save remains on disk, Continue is disabled, and New Game still works; the next successful overnight save may replace it.

## Save repository

Create `scripts/persistence/save_repository.gd` with `class_name SaveRepository` as one concrete FileAccess-backed class, not an interface.

Default path:

```text
user://phoenix-save.json
```

Constructor path injection is allowed only to keep filesystem tests isolated:

```gdscript
func _init(path: String = DEFAULT_PATH) -> void:
    _path = path
```

The repository exposes only the product operations HPA-598 needs:

```gdscript
func load() -> Dictionary
func save(state: Dictionary) -> Error
```

`load()` returns a small result dictionary distinguishing `missing`, `loaded`, `invalid`, and `io_error`. A loaded result contains the decoded runtime state; invalid/I/O results contain a short message. The repository does not evaluate current gameplay ranges; `AppRoot` does that with `GameSession.state_error()`.

`save()` encodes one V1 envelope, opens the file with `FileAccess.WRITE`, stores the JSON text, flushes/closes it, and returns the resulting `Error`. Opening or writing failure is returned to the world coordinator. No backup file, temp file, lock file, encryption, compression, directory hierarchy, or retry queue is added.

Godot documents `user://` as the writable persistent user-data location and `FileAccess` as the normal save-file API in exported projects, so the same repository is used in editor and macOS builds.

## WorldShell restore and autosave flow

### Configuration before `_ready()`

Replace eager session construction with explicit pre-tree configuration:

```gdscript
var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository

func configure(initial_state: Variant, repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository
```

In `_ready()`:

1. create a fresh `GameSession`;
2. restore `_initial_state` when provided and assert it succeeds because `AppRoot` already validated it;
3. continue the existing collision/HUD wiring;
4. render once from the restored/fresh session.

The player scene is untouched, so every launch uses the authored `WorldContract.PLAYER_SPAWN` already encoded in `player.tscn`/the player controller contract.

Tests that instantiate `world.tscn` directly may call `configure(null, SaveRepository.new(test_path))`; production always goes through `AppRoot`.

### Autosave timing

Keep `GameSession.sleep()` unchanged as the gameplay transaction. Change only the world-shell orchestration around its successful result.

On sleep confirmation:

1. if an overnight save is already in progress, ignore the repeated request;
2. call `_session.sleep(target)` exactly once;
3. for any non-`DAY_ADVANCED` result, keep the existing `_finish_command()` path;
4. for `DAY_ADVANCED`, immediately refresh the HUD/farm so the completed new-morning state and blocking summary exist;
5. mark save status `saving` and disable summary acknowledgement;
6. yield one process frame so `Saving…` can render;
7. call `_save_repository.save(_session.state())` once;
8. show `Saved.` on success or a visible failure message on error;
9. clear the in-progress guard and re-enable summary acknowledgement.

The save is therefore always a completed next-morning snapshot. It is never a pre-sleep snapshot and never runs twice for one transition.

Repeated sleep input is also naturally rejected by `GameSession` after the first call because `pending_morning_summary` becomes non-null, but the explicit `_overnight_save_in_progress` guard keeps the orchestration contract obvious and testable while the one-frame save presentation is pending.

### Save failure semantics

Save failure does not mutate `GameSession` again and never rolls back the completed day transition. The morning summary stays valid and can be acknowledged once the save attempt finishes. The player may keep playing; a later successful sleep attempts to overwrite the one slot again.

The failure copy should make the risk clear without adding a modal, for example:

```text
Save failed — this morning is not persisted.
```

No automatic retry or crash dialog is added.

## HUD changes

Extend `GameHud` minimally:

- retain the morning-summary acknowledge button in a field;
- add one small save-status label to the existing morning-summary panel;
- add `set_save_status(status: StringName, message: String = "")`;
- disable the acknowledge button only while status is `saving`;
- clear save status when the morning summary is acknowledged/closed.

Do not add another modal, input-gate reason, global notification system, or generic status component. `GameHud.has_blocking_modal()` remains the single world-input gate.

## Test strategy

### GameSession unit tests

Extend `tests/unit/test_game_session.gd` to prove:

- `state()` is a deep clone and excludes derived `max_stamina`/relationship level;
- a state produced by real commands restores to an equivalent snapshot;
- restored farm entries remain commandable after restore;
- invalid day/time/stamina/count/growth/farm identity/relationship shape/summary consistency is rejected without mutating a target session.

The primary state fixture should be command-driven rather than a giant hand-written valid dictionary.

### Save codec unit tests

Create `tests/unit/test_save_file.gd` for:

- encode/decode round trip including farm cells, crops, relationships, pending shipment, and pending morning summary;
- deep-clone behavior;
- malformed JSON;
- wrong/unknown schema version;
- missing/wrong nested fields;
- fractional/non-finite/incompatible numeric shapes where applicable;
- unknown crop/action/weather/villager keys.

### Repository integration tests

Create `tests/integration/test_save_repository.gd` using an injected `user://` test path and cleanup through `DirAccess`:

- missing file;
- successful replace/write/read;
- malformed file reported as invalid;
- deterministic open failure using a path inside a nonexistent `user://` subdirectory.

No mock filesystem abstraction is added.

### App/world persistence integration

Create `tests/integration/test_persistence_flow.gd` and reuse the real scenes/session seams.

The main acceptance path is command-driven:

1. launch New Game through the app/title seam;
2. perform representative farming/economy/social state changes using real `GameSession` commands/helpers;
3. deposit a crop and interact socially;
4. sleep once;
5. assert the session has advanced and save status reaches success;
6. read/decode the file and confirm its pending morning summary/new-morning state;
7. create a fresh app/world launch from that state;
8. compare restored authoritative state with the saved state;
9. assert the player starts at `WorldContract.PLAYER_SPAWN`, not an arbitrary prior position;
10. acknowledge the restored morning summary and perform one farm/social command to prove indexes/arrays were rebuilt correctly.

Add a focused failure path that injects an unwritable repository path, verifies the day still advanced, verifies the failure text is visible, and verifies the summary can be acknowledged after the attempt.

Add one duplicate-input assertion proving one sleep request produces one day transition and one repository write.

### Headless project contract

Update `tests/headless/project_smoke.gd` to pin `run/main_scene` to the new app scene. Existing world-shell smoke continues loading `world.tscn` directly and should remain a world contract test rather than becoming a title-flow test.

`tools/verify-clean.sh` already runs every GUT test under `tests/unit` and `tests/integration`; no new test runner or dependency is needed.

## Manual macOS acceptance

HPA-598 performs one manual exported-build persistence check using the existing `macOS` export preset; HPA-599 still owns packaging/release polish.

Acceptance sequence:

1. export a debug macOS build from the existing preset;
2. launch and choose New Game;
3. create a visible state change and successfully sleep once;
4. close the application normally after `Saved.` appears;
5. reopen the exported app;
6. verify Continue is enabled;
7. Continue and confirm the saved day/state plus pending morning summary are restored at the authored player spawn;
8. acknowledge the summary and continue playing.

Do not add desktop WebDriver automation or a CI packaging matrix for this ticket.

## Documentation changes during implementation

Update `README.md` and `CLAUDE.md` in the implementation commit(s) to document:

- title/New Game/Continue flow;
- `user://phoenix-save.json` one-slot behavior;
- save-after-successful-sleep timing;
- invalid/incompatible save fallback to New Game;
- `GameSession.state()`/restore validation ownership;
- concrete persistence layer and dependency direction;
- `AppRoot` as the launch owner and `WorldShell` as the only live session holder;
- player world position remains authored/transient;
- HPA-597 is the next delivery slice.

Keep the existing `AGENTS.md -> CLAUDE.md` symlink unchanged.

## Explicit non-goals

- TypeScript/Tauri/localStorage save migration or compatibility.
- Backward compatibility with any prior Godot development save.
- Multiple slots or profiles.
- Manual save-anywhere.
- Arbitrary player position, facing, target, camera, HUD, dialogue, or focus restore.
- Backup rotation, atomic journal, recovery history, retry queue, or corruption repair.
- Encryption, compression, cloud sync, Steam Cloud, or cross-device transfer.
- Autoload/global `SaveManager`.
- Repository interface or multiple production storage adapters.
- Generic serializer/schema/migration framework.
- Tutorial/finale flags or HPA-597 content.
- Release packaging automation or broader HPA-599 polish.

## Delivery rule

HPA-598 remains one PR. This planning commit contains only the design and implementation plan. After review, implementation continues on the same branch/PR; do not create a second HPA-598 implementation PR.
