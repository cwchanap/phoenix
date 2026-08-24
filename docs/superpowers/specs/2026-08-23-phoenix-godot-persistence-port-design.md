# Phoenix Godot Persistence Port Design (HPA-598)

**Status:** Draft for review — revised after release-build, validation-ownership, and reuse review

**Date:** 2026-08-23

**Delivery target:** Godot one-slot autosave and Continue

## Source of truth

This design implements HPA-598, `[Godot Persistence Port] Restore one-slot autosave and continue`, against `main` after HPA-594 merged. The repository baseline reviewed for this revision is `39892813ec985d6db4491c4e2af3b98277cf06b8`.

The live Linear issue and Phoenix project description remain authoritative. HPA-598 extends these existing repository contracts rather than inventing a parallel vocabulary:

- `GameSession.snapshot()`, `sleep()`, `acknowledge_morning_summary()`, and `_farm_snapshot()` in `scripts/game/game_session.gd`;
- `GameRules.CommandCode`, `CROP_KEYS`, `ACTION_KEYS`, and `WEATHER_KEYS` in `scripts/game/game_rules.gd`;
- `VillagerRules.VILLAGER_KEYS` and `villager_key()` in `scripts/game/villager_rules.gd`;
- `_on_sleep_requested()` and the sole live `GameSession` ownership in `scripts/world/world_shell.gd`;
- `_build_summary_panel()` and `has_blocking_modal()` in `scripts/ui/game_hud.gd`;
- `PlayerController.current_target_cell()` and the authored-spawn setup in `scripts/player/player_controller.gd`;
- `WorldMath.grid_to_world()` / `world_to_grid()` in `scripts/world/world_math.gd`;
- `project.godot` currently booting `res://scenes/world/world.tscn`.

New HPA-598 identifiers are limited to:

- `GameSession.state()`;
- `GameSession.state_error()`;
- `GameSession.restore_state()`;
- `SaveFileCodec`;
- `SaveRepository`;
- `AppRoot`;
- `TitleScreen`;
- `WorldShell.configure()`;
- `GameHud.set_save_status()`.

## Outcome

Phoenix opens on a small title screen. `New Game` always starts a fresh `GameSession`. `Continue` is enabled only when the single local save exists, has schema version 1, and `GameSession.state_error()` accepts the decoded state.

Sleeping stays a synchronous gameplay transaction owned by `GameSession`. After `sleep()` returns `GameRules.CommandCode.DAY_ADVANCED`, the complete next-morning state and pending morning summary already exist. `WorldShell` then synchronously writes that state once to `user://phoenix-save.json` and shows either `Saved.` or a visible failure message. File I/O failure never rolls back the completed day.

On restart, Continue restores authoritative gameplay state into a fresh `GameSession` and instantiates the authored world. Player position, facing, target, camera, HUD/dialogue state, and focus are never persisted; every launch uses `WorldContract.PLAYER_SPAWN`.

The implementation remains one PR and adds no migration framework, compatibility layer, backup rotation, cloud save, save-anywhere, second runtime, global save singleton, or repository interface.

## Approved lean shape

Keep these decisions fixed:

- `AppRoot` owns title/load/launch lifecycle; title logic does not move into `WorldShell`.
- `TitleScreen` is presentation only.
- One concrete FileAccess-backed `SaveRepository`; no interface and no second adapter.
- `GameSession.state()` is the canonical mutable-state projection; views continue to consume `snapshot()`.
- `SaveFileCodec` owns only the versioned JSON transport boundary; `GameSession.state_error()` is the single validator for persisted gameplay state.
- Autosave occurs only after successful `sleep()`.
- Saving stays synchronous; no one-frame `Saving…` state, async signal handler, or reentrancy flag is added.
- I/O failure changes UI only and never rewinds gameplay.
- New Game never deletes the existing slot; the next successful sleep replaces it.
- Invalid/incompatible saves disable Continue at the title; there is no launch-then-bounce flow.
- Direct `world.tscn` tests may leave the repository `null` and remain save-free.
- The primary acceptance path grows two real Turnips, gifts one, ships one, and never seeds harvested state through a production test hook.
- HPA-597 tutorial/finale state stays out of this schema.
- Keep `AGENTS.md -> CLAUDE.md` unchanged.

## Rejected alternatives

### Put title/load/save directly in WorldShell

Rejected because it mixes application lifecycle, storage bootstrap, gameplay coordination, and title presentation in the current world coordinator.

### Autoload `SaveManager`

Rejected because Phoenix has one save file and one application-level caller. A global service locator is unnecessary.

### Repository interface / multiple adapters

Rejected because Godot `FileAccess` covers the editor and exported macOS build. There is no second production storage implementation to abstract.

### Per-field validation in SaveFileCodec

Rejected because it duplicates rules already owned by `GameSession` and makes every future persisted field require edits in both the transport and gameplay layers. HPA-598 keeps one gameplay validator.

## Architecture

### Application root

Create:

- `scenes/app/app.tscn`;
- `scripts/app/app_root.gd`;
- `scenes/ui/title_screen.tscn`;
- `scripts/ui/title_screen.gd`.

Change `project.godot` to:

```ini
run/main_scene="res://scenes/app/app.tscn"
```

`AppRoot` owns exactly one `SaveRepository` and one optional prevalidated Continue state. On `_ready()` it loads once:

1. missing file → Continue disabled;
2. malformed/unsupported envelope → Continue disabled with short status;
3. decoded state rejected by `GameSession.state_error()` → Continue disabled with short status;
4. accepted state → cache a deep clone and enable Continue.

`New Game` launches a fresh session without deleting the file. `Continue` launches only the cached accepted state. Either path instantiates `world.tscn`, calls `WorldShell.configure()` before adding it to the tree, and hides the title.

`_on_continue_requested()` still guards `_continue_state != null`. Integration tests emit the production signal even while Continue is disabled to prove the application guard rejects missing/invalid/incompatible slots instead of relying only on `Button.disabled`.

### Title screen

`TitleScreen` owns only:

- `Panel/Title`;
- `Panel/NewGame`;
- `Panel/Continue`;
- `Panel/Status`;
- `new_game_requested` and `continue_requested` signals;
- `set_continue_state(available: bool, status: String = "")`.

It never imports or creates `GameSession`, `SaveRepository`, or `WorldShell`.

## Canonical gameplay state

### Extend the existing snapshot seam

Add `GameSession.state()` using existing clone helpers:

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

Refactor `snapshot()` to take the already-owned deep clone from `state()`, add only current derived fields, and return it directly. Do not deep-clone a second time after `state()` already cloned the nested data.

Derived/presentation data excluded from `state()`:

- `max_stamina`;
- relationship `level`;
- player position/facing/current target;
- camera state;
- fixed interaction cells/footprints;
- HUD/dialogue/modal/focus/feedback state.

Do not introduce `_farm_state()`. `_farm_snapshot()` remains the canonical farm clone helper.

### Farm identity

The persisted farm array retains each authored `Vector2i` cell. Current-rule validation requires exactly `WorldContract.farm_cells()` in authored order. No repair, reorder, or migration exists.

### Relationship state

Persist all three villagers:

- `points`;
- `talked_today`;
- `gifted_today`;
- `close_friend_dialogue_seen`.

Relationship `level` remains derived through `VillagerRules.relationship_level(points)`.

### Pending morning summary

Persist `pending_morning_summary` because the save occurs after `sleep()` creates it and before acknowledgement. Continue must restore the same blocking summary.

## Persistence transport and validation ownership

### SaveFileCodec: envelope + reversible transport only

Create `scripts/persistence/save_file.gd` with `class_name SaveFileCodec` and schema version 1:

```json
{
  "schema_version": 1,
  "state": { "...": "transport form of GameSession state" }
}
```

The codec is semantic-field-blind. It does not know crop IDs, action IDs, weather IDs, villager IDs, current ranges, farm identity, or summary rules.

It owns only:

- JSON parse/stringify;
- presence and whole-number validation of `schema_version`, followed by exact `schema_version == 1`;
- presence of the top-level `state` value;
- recursive conversion of JSON-compatible scalar/container values;
- a reversible transport representation for non-JSON `Vector2i` values;
- converting `StringName` values/dictionary keys to JSON strings on encode.

Use an explicit marker for `Vector2i` so decode never guesses that an arbitrary `{x,y}` dictionary is a vector:

```gdscript
{
    "__phoenix_type": "Vector2i",
    "x": 2,
    "y": 7,
}
```

`decode()` reconstructs only this tagged `Vector2i`. The marker itself is transport structure, so malformed/unknown markers fail in the codec. It leaves ordinary JSON object keys and string values as `String`. It does **not** attempt to guess which strings used to be `StringName`, and it does not attempt to reconstruct typed `Array[Dictionary]` containers.

That normalization belongs to `GameSession.restore_state()`. The transport round trip is therefore proven by restoring the decoded state and comparing the resulting canonical `GameSession.state()`, not by assuming raw parsed JSON has the same Variant container/key types as the original runtime dictionary.

The codec returns:

```gdscript
{"ok": true, "state": decoded_state}
```

or:

```gdscript
{"ok": false, "error": "..."}
```

for malformed JSON, unsupported/malformed schema version, missing top-level state, or malformed transport markers. No gameplay/content-specific validation occurs here.

### GameSession: single total validator + canonical restore

Add:

```gdscript
static func state_error(candidate: Variant) -> String
func restore_state(candidate: Dictionary) -> bool
```

`state_error()` is the only persisted gameplay-state validator and is total: every missing field, wrong type, unknown identifier, and invalid range returns a non-empty message instead of indexing/casting first and relying on the codec to have prevalidated shape.

Use small helpers such as:

```gdscript
static func _require_field(value: Dictionary, key: String) -> Dictionary
static func _require_dictionary(value: Variant, field: String) -> Dictionary
static func _require_array(value: Variant, field: String) -> Dictionary
static func _require_whole_int(value: Variant, field: String) -> Dictionary
static func _named_value(value: Variant, allowed: Array[StringName], field: String) -> Dictionary
static func _dictionary_value(map: Dictionary, key: StringName) -> Dictionary
```

`_named_value()` accepts `String` or `StringName`, converts with `StringName(value)`, and checks membership against the existing arrays. `_dictionary_value()` deliberately checks both the canonical `StringName` key and `String(key)` so direct runtime states and JSON-decoded states follow the same validator.

`state_error()` validates in one traversal:

- required top-level fields and their types;
- day `1..GameRules.MAX_DAY`;
- time `GameRules.DAY_START_MINUTES..GameRules.ACTION_CUTOFF_MINUTES`;
- stamina `0..GameRules.MAX_STAMINA`;
- non-negative money/counts/relationship points;
- selected crop/action/weather membership in `GameRules.CROP_KEYS`, `ACTION_KEYS`, and `WEATHER_KEYS`;
- exact seed/harvested/pending-shipment crop keys;
- exact farm count/order/cell identity vs `WorldContract.farm_cells()`;
- tilled/crop shape, crop kind membership, and growth `0..GameRules.growth_nights(kind)`;
- exact relationship keys vs `VillagerRules.VILLAGER_KEYS` and boolean daily/close-friend flags;
- nullable pending summary shape and consistency (`next_day == state.day`, `next_weather == state.weather`, `money_after_shipping == state.money`, non-negative shipment line values, known shipment crop IDs).

`restore_state()` calls the validator first, mutates nothing on failure, and on success rebuilds canonical typed/internal data:

- current `String`/`StringName` identifiers are mapped through the existing `*_KEYS` arrays;
- count dictionaries become new `Array[int]` values;
- farm becomes a new `Array[Dictionary]` containing real `Vector2i` cells;
- relationships become new private relationship dictionaries in `VillagerRules.VILLAGER_KEYS` order;
- pending summary is deep-cloned;
- no Array/Dictionary from the decoded candidate is retained by reference.

The restore proof must run a real farm command after restore and verify the decoded/saved candidate did not mutate.

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

`load()` distinguishes `missing`, `loaded`, `invalid`, and `io_error`. `loaded` means the envelope/transport decoded; `AppRoot` still calls `GameSession.state_error()` before enabling Continue.

`save()` writes one schema-v1 document with `FileAccess.WRITE`, flushes/closes it, and returns the resulting `Error`.

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

The `assert(not is_inside_tree())` calls are pure checks and may remain assertions. Restore itself must **not** be inside an assertion because release exports do not evaluate assert expressions.

At the beginning of `_ready()`:

```gdscript
_session = GameSession.new()
if _initial_state != null and not _session.restore_state(_initial_state):
    push_error("AppRoot supplied invalid restored state")
    _session = GameSession.new()
```

`AppRoot` should prevent this fallback in normal production by prevalidating Continue; the branch is still explicit and release-safe if the pre-tree contract is violated.

Direct `world.tscn` tests do not need `configure()` and keep `_save_repository == null`; they remain save-free. The existing authored player `_ready()` still applies `WorldContract.PLAYER_SPAWN`.

### Autosave timing stays synchronous

Extend only the live `_on_sleep_requested()` seam:

1. get `player.current_target_cell()`;
2. call `_session.sleep(target)` once;
3. non-`DAY_ADVANCED` or null repository → existing `_finish_command(code)` path;
4. successful production sleep → show feedback and `_refresh_from_session()` immediately, which closes the sleep panel and exposes the pending morning summary;
5. call `_save_repository.save(_session.state())` synchronously once;
6. show `Saved.` on success or the failure message on error.

No `await`, `_overnight_save_in_progress`, `Saving…`, or temporary Acknowledge disabling is required. A repeated sleep request is already rejected by `GameSession._active_day_failure()` because the pending morning summary exists; the first refresh also hides the sleep confirmation UI before the handler returns.

A small one-write assertion remains folded into persistence acceptance: two back-to-back production sleep signals must produce one save call and one day advancement. This covers HPA-598's repeated-input acceptance requirement without adding a guard or a separate async test.

Save failure never invokes `restore_state()` and never rewinds the day. The morning summary remains usable.

## HUD changes

Extend `_build_summary_panel()` only:

- add `HudRoot/MorningSummaryPanel/SaveStatus`;
- add `set_save_status(status: StringName, message: String = "")`;
- support only `&"idle"`, `&"saved"`, and `&"error"`;
- clear status when the morning summary closes.

There is no `saving` state and the existing `Acknowledge` button is never disabled for I/O.

Do not add a new modal, input-gate reason, generic notification system, or status framework.

## Test strategy

### GameSession unit tests

Extend `tests/unit/test_game_session.gd` using the existing `extends GutTest`, `GameRules.CommandCode.*`, `_plant_turnip()`, and typed helper conventions.

Prove:

- `state()` deep-clones and excludes derived fields;
- `snapshot()` derives from `state()` without a redundant second deep copy;
- `state_error()` rejects missing/wrong-typed fields as messages rather than raising;
- current rule/range/identifier/farm/relationship/summary failures are rejected;
- real-command state restores equivalently;
- after restore, `water()` on the restored crop succeeds and mutates the live session while the saved candidate remains unchanged.

### JSON semantics probe before codec implementation

Before writing the codec, run one throwaway Godot script against a real `GameSession.state()` and print the raw JSON round-trip Variant types for:

- `StringName` values;
- crop/relationship dictionary keys;
- `Vector2i` farm cells;
- the typed `Array[Dictionary]` farm container.

The probe is evidence only and is not committed. It confirms why the codec must not depend on raw JSON preserving Godot-specific Variant identity.

### Save codec unit tests

Create `tests/unit/test_save_file.gd` for:

- malformed JSON;
- missing/fractional/non-numeric/wrong schema version;
- malformed/unknown tagged `Vector2i` transport;
- recursive conversion deep isolation;
- a real state encode/decode followed by `GameSession.state_error(decoded_state) == ""`, `restore_state(decoded_state) == true`, and canonical `restored.state() == original_state`;
- explicit assertion that a decoded farm cell is `Vector2i`;
- explicit assertion that `restore_state()` canonicalizes JSON string keys/values back to the runtime state shape.

Do not assert raw decoded containers have the same typed-array/StringName identity as the original state.

### Repository integration tests

Create `tests/integration/test_save_repository.gd` with an injected `user://` test path:

- missing;
- write/replace/read;
- malformed file → `invalid`;
- deterministic write failure via nonexistent parent directory.

No filesystem interface/mock is introduced.

### App/title integration

Create `tests/integration/test_app_launch.gd` and inspect real title nodes/signals.

Cover:

- missing save → Continue disabled; emit `continue_requested` anyway and prove no `World` appears;
- malformed/unsupported save → Continue disabled; emit `continue_requested` and prove no `World` appears;
- valid save → Continue enabled and restores state at authored spawn;
- valid current slot + New Game → fresh Day 1 and file remains;
- structurally valid but `state_error()`-incompatible slot → Continue disabled with status; emit `continue_requested` and prove no `World`; then New Game launches Day 1 and leaves the slot untouched.

### Command-driven persistence acceptance

Create `tests/integration/test_persistence_flow.gd`.

Primary path:

1. grow two Turnips through real `hoe`/`plant`/`water`/`sleep`/acknowledge commands;
2. harvest both;
3. talk to June and gift one Turnip;
4. deposit the other Turnip;
5. load that state through the real codec/repository/AppRoot Continue path;
6. target the bed with `WorldMath.grid_to_world()` and `player.current_target_cell()`;
7. emit the existing HUD sleep signal twice back-to-back;
8. assert exactly one repository write, one day advancement, and the complete new-morning state;
9. recreate the app and Continue;
10. assert equivalent `world._session.state()`, pending summary, and authored player spawn;
11. acknowledge and execute a normal command.

Add save-failure coverage proving day advancement and pending summary survive an I/O failure and the error status is visible.

Do not extract a shared cross-test fixture yet. The existing unit helper grows one Turnip while this acceptance needs two crops plus social/shipping state; a new support abstraction would save little code and add another test dependency.

### Existing world/headless tests

`tests/integration/test_gameplay_shell.gd` and `tests/headless/world_shell_smoke.gd` continue loading `world.tscn` directly with no repository. Match the current integration convention and use `world._session` directly rather than `world.get("_session")`.

Update only `tests/headless/project_smoke.gd` to pin `application/run/main_scene` to `res://scenes/app/app.tscn`.

Use the existing GUT command form throughout RED/GREEN:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd ...
```

`tools/verify-clean.sh` remains the committed-HEAD verifier and is run after commits.

## Manual macOS acceptance

Use the existing `macOS` export preset with a **release** export so the acceptance exercises the same assert-stripping behavior as the shipped build:

```bash
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-598.app
```

Then:

1. launch the release app;
2. New Game;
3. make a visible state change and successfully sleep;
4. verify `Saved.`;
5. close normally;
6. reopen the same release app;
7. verify Continue enabled;
8. restore saved state/pending summary at authored spawn;
9. acknowledge and continue playing.

No desktop WebDriver or CI export matrix is added.

## Risks

### Godot JSON Variant fidelity

Raw JSON does not promise preservation of Godot-specific runtime types such as `StringName`, `Vector2i`, or typed GDScript arrays. This is the main implementation unknown. Task 2 begins with a direct probe, and the design deliberately avoids relying on raw JSON to restore `StringName` or typed-array identity.

### Release-only restore regression

GDScript assertions are ignored in non-debug exports and their expressions are not evaluated. Restore must never occur only as an `assert()` side effect. The release macOS acceptance specifically covers Continue after export.

## Documentation changes during implementation

Update `README.md` and `CLAUDE.md` to document:

- title/New Game/Continue;
- `user://phoenix-save.json`;
- post-successful-sleep synchronous save timing;
- invalid/incompatible fallback to New Game;
- `GameSession.state()` / total restore-validation ownership;
- semantic-field-blind codec and concrete persistence boundary;
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
- Generic schema/migration framework beyond the tiny recursive transport converter required for JSON-safe Variant values.
- Tutorial/finale flags or HPA-597 content.
- Release packaging automation or broader HPA-599 polish.

## Delivery rule

HPA-598 remains one PR. Planning and implementation continue on `agent/hpa-598-godot-persistence-plan`; do not create a second HPA-598 implementation PR.
