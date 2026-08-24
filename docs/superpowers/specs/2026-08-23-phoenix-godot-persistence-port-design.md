# Phoenix Godot Persistence Port Design (HPA-598)

**Status:** Draft for review — revised after live-contract and reuse review

**Date:** 2026-08-23

**Delivery target:** Godot one-slot autosave and Continue

## Source of truth

This design implements HPA-598, `[Godot Persistence Port] Restore one-slot autosave and continue`, against `main` after HPA-594 merged. The repository baseline reviewed for this revision is `39892813ec985d6db4491c4e2af3b98277cf06b8`.

The live Linear issue and Phoenix project description remain authoritative for product scope, delivery order, and non-goals. The implementation must extend the contracts that exist now rather than introduce a parallel vocabulary:

- `scripts/game/game_session.gd`
  - `GameSession.snapshot() -> Dictionary`
  - `GameSession.sleep(target_cell: Variant) -> GameRules.CommandCode`
  - `GameSession.acknowledge_morning_summary() -> GameRules.CommandCode`
  - `_farm_snapshot()` is the existing farm deep-clone helper.
- `scripts/game/game_rules.gd`
  - `GameRules.CommandCode`
  - `GameRules.CROP_KEYS`
  - `GameRules.ACTION_KEYS`
  - `GameRules.WEATHER_KEYS`
  - `GameRules.crop_key()`, `action_key()`, and `weather_key()`.
- `scripts/game/villager_rules.gd`
  - `VillagerRules.VILLAGER_KEYS`
  - `VillagerRules.villager_key()`.
- `scripts/world/world_shell.gd`
  - `_on_sleep_requested()` calls `_session.sleep(target)` and finishes through `_finish_command()` today.
  - `WorldShell` is the only production `GameSession` holder.
- `scripts/ui/game_hud.gd`
  - `HudRoot/MorningSummaryPanel/Acknowledge` is the current summary button path.
  - `_build_summary_panel()` owns the existing morning-summary UI.
  - `GameHud.has_blocking_modal()` is the single world-input gate.
- `scripts/player/player_controller.gd`
  - `current_target_cell()` is the target API.
  - the authored spawn is applied to `global_position` in `_ready()`.
- `scripts/world/world_math.gd`
  - `WorldMath.grid_to_world()` / `world_to_grid()` are the projection APIs.
- `project.godot` currently boots `res://scenes/world/world.tscn`.

New HPA-598 identifiers are limited to `GameSession.state()`, `GameSession.state_error()`, `GameSession.restore_state()`, `SaveFileCodec`, `SaveRepository`, `AppRoot`, `TitleScreen`, `WorldShell.configure()`, and `GameHud.set_save_status()`.

## Outcome

Phoenix opens on a small title screen. `New Game` always starts a fresh `GameSession`; `Continue` is enabled only when the single local save exists, parses as schema version 1, and satisfies current Godot gameplay rules.

Sleeping remains a gameplay transaction owned by `GameSession`. After `sleep()` returns `GameRules.CommandCode.DAY_ADVANCED`, the complete next-morning state and blocking morning summary already exist. `WorldShell` then writes exactly one versioned JSON save to `user://phoenix-save.json`. Save failure is visible but never rolls back the completed overnight transition.

On restart, Continue restores authoritative gameplay state into a fresh `GameSession` and instantiates the same authored world. The player always starts at `WorldContract.PLAYER_SPAWN`; arbitrary position, facing, target, camera, HUD/dialogue state, and focus state are not persisted.

The implementation remains one PR and adds no migration framework, compatibility layer, backup rotation, cloud save, save-anywhere, second runtime, global save singleton, or generic repository interface.

## Approved lean shape

Keep these decisions fixed:

- `AppRoot` owns title/load/launch lifecycle; title logic does not move into `WorldShell`.
- `TitleScreen` is presentation only.
- One concrete FileAccess-backed `SaveRepository`; no interface and no second adapter.
- `GameSession.state()` is the canonical mutable-state projection; views continue to consume `snapshot()`.
- `SaveFileCodec` owns JSON/schema/shape parsing; `GameSession.state_error()` owns current-rule ranges/content compatibility.
- Autosave occurs only after successful `sleep()`.
- I/O failure changes UI only and never rewinds gameplay.
- New Game never deletes the existing slot; the next successful sleep replaces it.
- Incompatible saves disable Continue at the title; there is no launch-then-bounce flow.
- One process frame displays `Saving…`; `_overnight_save_in_progress` prevents duplicate orchestration during that window.
- Direct `world.tscn` tests may leave the repository `null` and remain storage-free.
- The primary acceptance path grows two real Turnips, gifts one, ships one, and never seeds harvested state through a test-only production hook.
- HPA-597 tutorial/finale state stays out of this schema.
- Keep `AGENTS.md -> CLAUDE.md` unchanged.

## Rejected alternatives

### Put title/load/save directly in WorldShell

Rejected because it mixes application lifecycle, storage bootstrap, gameplay coordination, and presentation in the current world coordinator.

### Autoload `SaveManager`

Rejected because Phoenix has one save file and one application-level caller. A global service locator is unnecessary.

### Repository interface / multiple adapters

Rejected because Godot `FileAccess` works for both editor and exported macOS builds. There is no second production storage implementation to abstract.

## Architecture

### Application root

Create:

- `scenes/app/app.tscn`
- `scripts/app/app_root.gd`
- `scenes/ui/title_screen.tscn`
- `scripts/ui/title_screen.gd`

Change `project.godot` to:

```ini
run/main_scene="res://scenes/app/app.tscn"
```

`AppRoot` owns exactly one `SaveRepository` and one optional prevalidated Continue state. On `_ready()` it loads once:

1. missing file → Continue disabled;
2. malformed/unsupported/shape-invalid save → Continue disabled with short status;
3. structurally valid but `GameSession.state_error()`-rejected state → Continue disabled with short status;
4. valid state → cache a deep clone and enable Continue.

`New Game` launches a fresh session without deleting the file. `Continue` launches only the cached valid state. Either path instantiates `world.tscn`, calls `WorldShell.configure()` before adding it to the tree, and then hides the title.

### Title screen

`TitleScreen` owns only:

- title label;
- `Panel/NewGame`;
- `Panel/Continue`;
- `Panel/Status`;
- `new_game_requested` and `continue_requested` signals;
- `set_continue_state(available: bool, status: String = "")`.

It never imports or creates `GameSession`, `SaveRepository`, or `WorldShell`.

## Canonical gameplay state

### Extend the existing snapshot seam

Add `GameSession.state()` by reusing the same clone helpers already used by `snapshot()`:

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
        "farm": _farm_snapshot(),
        "pending_morning_summary": _pending_morning_summary,
        "relationships": _relationships_state(),
    }.duplicate(true)
```

Refactor `snapshot()` to call `state()` and add only current derived fields:

- `max_stamina`;
- relationship `level`.

Do not create a second farm clone helper such as `_farm_state()`. `_farm_snapshot()` remains the canonical deep-copy seam.

`state()` excludes:

- player position/facing/current target;
- camera state;
- fixed interaction cells/footprints;
- HUD/dialogue/modal/focus/feedback state;
- relationship `level` and `max_stamina`.

### Farm identity

The persisted farm array retains the authored cell for each of the nine entries. JSON encodes each `Vector2i` as `{ "x", "y" }`.

Current-rule validation requires exactly `WorldContract.farm_cells()` in authored order. No repair, reordering, or migration is attempted.

### Relationship state

Persist all three villagers using `VillagerRules.VILLAGER_KEYS` / `villager_key()`:

- `points`;
- `talked_today`;
- `gifted_today`;
- `close_friend_dialogue_seen`.

Relationship `level` remains derived.

### Pending morning summary

Persist `pending_morning_summary` because the save occurs after `sleep()` creates it and before acknowledgement. Continue must restore the same blocking summary.

## Validation ownership

### SaveFileCodec: JSON structure only

Create `scripts/persistence/save_file.gd` with `class_name SaveFileCodec` and schema version 1:

```json
{
  "schema_version": 1,
  "state": { "...": "GameSession mutable state" }
}
```

The codec owns:

- JSON parsing/encoding;
- exact schema version;
- required state/nested fields;
- Dictionary/Array/boolean/string/whole-number shape;
- `Vector2i` ↔ `{x,y}` conversion;
- structural crop/action/weather/villager identifier validation.

The codec must reuse the existing closed sets rather than define another table:

```gdscript
GameRules.CROP_KEYS
GameRules.ACTION_KEYS
GameRules.WEATHER_KEYS
VillagerRules.VILLAGER_KEYS
```

A file-local helper may validate a decoded string with `allowed_keys.find(StringName(value))`. Do not hand-enumerate `"turnip"`, `"potato"`, `"pumpkin"`, villager IDs, actions, or weather values a second time.

Godot JSON numbers deserialize as numeric Variants, so integer parsing accepts only finite whole values and converts them to `int`; it never truncates `1.5`.

The codec does **not** own `MAX_DAY`, `MAX_STAMINA`, non-negative counts, current farm identity, crop-growth limits, or summary equality.

### GameSession: current rules and restore

Add:

```gdscript
static func state_error(candidate: Variant) -> String
func restore_state(candidate: Dictionary) -> bool
```

`state_error()` rejects at minimum:

- day outside `1..GameRules.MAX_DAY`;
- time outside `GameRules.DAY_START_MINUTES..GameRules.ACTION_CUTOFF_MINUTES`;
- stamina outside `0..GameRules.MAX_STAMINA`;
- negative money/counts/relationship points;
- selected keys absent from the existing `*_KEYS` arrays;
- farm identity/order mismatch with `WorldContract.farm_cells()`;
- crop on untilled soil;
- crop growth outside `0..GameRules.growth_nights(kind)`;
- missing/extra relationship records vs `VillagerRules.VILLAGER_KEYS`;
- pending-summary inconsistency such as `next_day != state.day`, `next_weather != state.weather`, or `money_after_shipping != state.money`.

`restore_state()` validates first, mutates nothing on failure, then reconstructs new arrays/dictionaries on success. It must never retain aliases into the decoded candidate.

The restore proof must exercise the farm, not merely selection state. After restoring a planted crop and acknowledging its pending summary, run `restored.water(cell)` and assert:

- the command returns `GameRules.CommandCode.CROP_WATERED`;
- the restored live state changed;
- the original saved candidate did **not** change.

This simultaneously proves farm lookup/commandability and deep-copy isolation. No test-only setter/API is added.

## Save repository

Create `scripts/persistence/save_repository.gd` with `class_name SaveRepository` as one concrete FileAccess-backed class.

Default path:

```text
user://phoenix-save.json
```

Constructor path injection exists only for isolated filesystem tests:

```gdscript
func _init(path: String = DEFAULT_PATH) -> void:
    _path = path
```

Expose only:

```gdscript
func load() -> Dictionary
func save(state: Dictionary) -> Error
```

`load()` distinguishes `missing`, `loaded`, `invalid`, and `io_error`. It decodes structure but does not apply current gameplay rules. `AppRoot` calls `GameSession.state_error()` before enabling Continue.

`save()` writes one schema-v1 JSON document using `FileAccess.WRITE`, flushes/closes it, and returns the resulting `Error`.

No delete API, backup/temp file, retry queue, encryption, compression, directory hierarchy, or second adapter is added.

## WorldShell restore and autosave

### Configuration before `_ready()`

Replace eager construction with:

```gdscript
var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository = null

func configure(initial_state: Variant, repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository
```

At the beginning of `_ready()`:

1. create `GameSession.new()`;
2. restore `_initial_state` when supplied and assert success because AppRoot prevalidated it;
3. continue existing collision/HUD wiring;
4. render once.

Direct `world.tscn` tests do **not** need to call `configure()` and keep `_save_repository == null`; they remain save-free. Production `AppRoot` always configures a repository.

The player scene/controller remains unchanged, so every launch still applies `WorldContract.PLAYER_SPAWN` through the existing player `_ready()` path.

### Autosave timing

Extend the live `_on_sleep_requested()` seam only:

1. return immediately when `_overnight_save_in_progress` is true;
2. get `player.current_target_cell()`;
3. call `_session.sleep(target)` exactly once;
4. non-`DAY_ADVANCED` or null repository → existing `_finish_command(code)` path;
5. successful production sleep → set guard, show feedback, refresh session state;
6. call `hud.set_save_status(&"saving")`;
7. await one process frame so `Saving…` is visible;
8. call `_save_repository.save(_session.state())` exactly once;
9. show `Saved.` or the failure message;
10. clear the guard.

Save failure never invokes `restore_state()` and never rewinds the day. The existing morning summary remains acknowledgement-gated by `GameHud` and may be acknowledged after the save attempt.

## HUD changes

Extend `_build_summary_panel()` only:

- retain `HudRoot/MorningSummaryPanel/Acknowledge` in a field;
- add `HudRoot/MorningSummaryPanel/SaveStatus`;
- add `set_save_status(status: StringName, message: String = "")`;
- disable Acknowledge only for `&"saving"`;
- clear status when the summary closes.

Do not add a new modal, input-gate reason, generic notification system, or status framework.

## Test strategy

### GameSession unit tests

Extend `tests/unit/test_game_session.gd` using the existing `extends GutTest`, `GameRules.CommandCode.*`, `_plant_turnip()`, and typed helper conventions.

Prove:

- `state()` deep-clones and excludes derived fields;
- real-command state restores equivalently;
- after restore, `water()` on the restored crop succeeds and mutates the live session while the saved candidate remains unchanged;
- invalid current-rule state is rejected without mutating the target session.

### Save codec unit tests

Create `tests/unit/test_save_file.gd` for round-trip/deep-clone/malformed/wrong-schema/nested-shape cases. Identifier cases must derive values from the existing key arrays; the codec itself must not define parallel closed-key lists.

### Repository integration tests

Create `tests/integration/test_save_repository.gd` with an injected `user://` test path:

- missing;
- write/replace/read;
- malformed file → `invalid`;
- deterministic write failure via nonexistent parent directory.

No filesystem interface/mock is introduced.

### App/title integration

Create `tests/integration/test_app_launch.gd` and inspect the real title nodes/signals.

Cover:

- missing save → Continue disabled;
- valid save → Continue enabled and restores state at authored spawn;
- valid current slot + New Game → fresh Day 1 and file remains;
- **structurally valid but `state_error()`-incompatible slot** → Continue disabled with status, then New Game still launches a fresh Day 1 session and the incompatible file remains on disk.

This proves the actual recovery promise rather than only testing disabled Continue.

### Command-driven persistence acceptance

Create `tests/integration/test_persistence_flow.gd`.

Primary path:

1. grow two Turnips through real `hoe`/`plant`/`water`/`sleep`/acknowledge commands;
2. harvest both;
3. talk to June and gift one Turnip;
4. deposit the other Turnip;
5. load that state through the real codec/repository/AppRoot Continue path;
6. target the bed using `WorldMath.grid_to_world()` and `player.current_target_cell()`;
7. emit the existing HUD sleep signal;
8. assert one save write and the complete new-morning state;
9. recreate the app and Continue;
10. assert equivalent `GameSession.state()`, pending summary, and authored player spawn;
11. acknowledge and execute a normal command.

Add duplicate-input coverage for `_overnight_save_in_progress` and save-failure coverage proving day advancement survives I/O failure.

### Existing world/headless tests

`tests/integration/test_gameplay_shell.gd` and `tests/headless/world_shell_smoke.gd` continue loading `world.tscn` directly with no repository. They should not become persistence tests.

Update only `tests/headless/project_smoke.gd` to pin `application/run/main_scene` to `res://scenes/app/app.tscn`.

Use the existing command form throughout RED/GREEN:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd ...
```

`tools/verify-clean.sh` remains the committed-HEAD verifier and is run after commits, not as a substitute for worktree RED/GREEN.

## Manual macOS acceptance

Use the existing `macOS` export preset:

1. export debug build;
2. New Game;
3. make a state change and successfully sleep;
4. wait for `Saved.`;
5. close normally;
6. reopen;
7. verify Continue enabled;
8. restore the saved state/pending summary at authored spawn;
9. acknowledge and continue playing.

No desktop WebDriver or CI export matrix is added.

## Documentation changes during implementation

Update `README.md` and `CLAUDE.md` to document:

- title/New Game/Continue;
- `user://phoenix-save.json`;
- post-successful-sleep save timing;
- invalid/incompatible fallback to New Game;
- `GameSession.state()` / restore ownership;
- concrete persistence boundary;
- `AppRoot` launch ownership and `WorldShell` session ownership;
- transient player/world presentation state;
- HPA-597 as the next slice.

Keep `AGENTS.md -> CLAUDE.md` unchanged.

## Explicit non-goals

- TypeScript/Tauri/localStorage migration or compatibility.
- Backward compatibility with prior Godot development saves.
- Multiple slots/profiles.
- Manual save-anywhere.
- Arbitrary position/facing/target/camera/HUD/dialogue/focus restore.
- Backup rotation, atomic journal, recovery history, retry queue, or corruption repair.
- Encryption, compression, cloud sync, Steam Cloud, or cross-device transfer.
- Autoload/global `SaveManager`.
- Repository interface or multiple production adapters.
- Generic serializer/schema/migration framework.
- Tutorial/finale flags or HPA-597 content.
- Release packaging automation or broader HPA-599 polish.

## Delivery rule

HPA-598 remains one PR. Planning and implementation continue on `agent/hpa-598-godot-persistence-plan`; do not create a second HPA-598 implementation PR.
