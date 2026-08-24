# Phoenix Godot Persistence Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-slot Godot persistence so Phoenix starts at a title screen, autosaves the completed next-morning gameplay state after successful sleep, and can Continue that state at the authored player spawn.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority, add one canonical persisted-state projection plus restore validation, and put JSON/FileAccess details in two small persistence files. A new `AppRoot` owns title/load/launch lifecycle and explicitly configures the existing `WorldShell`, which remains the only live session holder and performs the one post-sleep write. No autoload, repository interface, migration layer, compatibility path, or second production adapter is introduced.

**Tech Stack:** Godot 4.7.1 standard non-.NET build, statically typed GDScript, Godot `JSON`, `FileAccess`/`DirAccess`, existing GUT 9.7.1 test flow, existing macOS export preset.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-persistence-port-design.md`

## Global Constraints

- Deliver HPA-598 in this single PR; implementation continues on `agent/hpa-598-godot-persistence-plan` after planning review. Do not open a second implementation PR.
- Persist one schema-version-1 JSON document at `user://phoenix-save.json` only after `GameSession.sleep()` returns `GameRules.CommandCode.DAY_ADVANCED` and the complete next-morning state exists.
- Do not migrate, read, or emulate the old TypeScript/localStorage/Tauri Store save.
- Do not preserve arbitrary player position, facing, target, camera, HUD/dialogue state, or focus state; every launch uses the authored `WorldContract.PLAYER_SPAWN`.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Keep `GameHud.has_blocking_modal()` as the single world-input gate; do not add another modal/input-lock subsystem for saving.
- Use one concrete FileAccess-backed `SaveRepository`; do not add a repository interface, autoload `SaveManager`, plugin system, service locator, backups, retry queue, encryption, compression, or cloud storage.
- Continue must be disabled for missing, malformed, unsupported, or current-rule-incompatible saves while New Game remains usable.
- Save failure must remain visible and must not undo the completed day transition.
- HPA-597 owns tutorial/finale state; do not add it here.
- Keep `AGENTS.md -> CLAUDE.md` unchanged.
- `tools/verify-clean.sh` validates committed `HEAD`, not uncommitted worktree changes. Use direct GUT commands during RED/GREEN and the clean verifier after each task commit.

## Local RED/GREEN test setup

The repository ignores `/addons/`, so provision the same pinned GUT used by `tools/verify-clean.sh` once in the worktree before Task 1:

```bash
rm -rf addons/gut /tmp/phoenix-gut.tgz /tmp/phoenix-gut
mkdir -p addons/gut /tmp/phoenix-gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o /tmp/phoenix-gut.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut.tgz" | shasum -a 256 -c -
tar -xzf /tmp/phoenix-gut.tgz --strip-components=3 -C addons/gut "Gut-9.7.1/addons/gut"
godot --headless --path . --editor --quit
```

Run a single GUT file with:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

---

### Task 1: Canonical GameSession State and Restore Validation

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `GameSession.state() -> Dictionary`
- Produces: `GameSession.state_error(candidate: Variant) -> String` where `""` means valid
- Produces: `GameSession.restore_state(candidate: Dictionary) -> bool`
- Preserves: `GameSession.snapshot() -> Dictionary` current view contract, including derived `max_stamina` and relationship `level`
- Consumed later by: `SaveFileCodec`, `AppRoot`, and `WorldShell`

- [ ] **Step 1: Add failing canonical-state and deep-clone tests**

Add tests that pin the persisted boundary rather than persisting the existing view snapshot:

```gdscript
func test_state_is_deeply_isolated_and_excludes_derived_fields() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var june := VillagerRules.VillagerId.RESIDENT
    _seed_harvested(session, [1, 0, 0])
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )

    var state := session.state()
    assert_false(state.has("max_stamina"))
    assert_false(state["relationships"][&"resident"].has("level"))
    state["harvested"][&"turnip"] = 99
    state["relationships"][&"resident"]["points"] = 99
    state["farm"][0]["tilled"] = true

    var fresh := session.state()
    assert_eq(fresh["harvested"][&"turnip"], 1)
    assert_eq(fresh["relationships"][&"resident"]["points"], 1)
    assert_false(fresh["farm"][0]["tilled"])

    var snapshot := session.snapshot()
    assert_eq(snapshot["max_stamina"], GameRules.MAX_STAMINA)
    assert_eq(snapshot["relationships"][&"resident"]["level"], &"stranger")
```

Also change the existing starter snapshot test only where necessary so it still pins the public snapshot shape.

- [ ] **Step 2: Run the state test and verify RED**

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

Expected: FAIL because `GameSession.state()` does not exist.

- [ ] **Step 3: Implement `state()` and derive `snapshot()` from it**

Replace the duplicated mutable projection with one canonical state projection. Reuse `_farm_snapshot()` as the state representation and split relationship state from derived relationship level:

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

func snapshot() -> Dictionary:
    var result := state()
    result["max_stamina"] = GameRules.MAX_STAMINA
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        var relationship: Dictionary = result["relationships"][key]
        relationship["level"] = VillagerRules.relationship_key(
            VillagerRules.relationship_level(int(relationship["points"]))
        )
    return result.duplicate(true)

func _relationships_state() -> Dictionary:
    var result: Dictionary = {}
    for id in range(VillagerRules.VillagerId.size()):
        var relationship: Dictionary = _relationships[id]
        result[VillagerRules.villager_key(id)] = {
            "points": relationship["points"],
            "talked_today": relationship["talked_today"],
            "gifted_today": relationship["gifted_today"],
            "close_friend_dialogue_seen": relationship["close_friend_dialogue_seen"],
        }
    return result
```

Remove `_relationships_snapshot()` after its callers are replaced. Do not add a second persistence-specific mutable-field list.

- [ ] **Step 4: Add failing command-driven restore tests**

Build the valid fixture by using current commands, not by hand-writing every field:

```gdscript
func test_command_driven_state_restores_and_remains_commandable() -> void:
    var original := GameSession.new(func() -> float: return 0.9)
    var cell := Vector2i(2, 7)
    var june := VillagerRules.VillagerId.RESIDENT

    assert_eq(original.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(original.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(original.water(cell), GameRules.CommandCode.CROP_WATERED)
    _seed_harvested(original, [1, 0, 0])
    assert_eq(
        original.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.CROP_GIFTED,
    )
    assert_eq(original.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var saved := original.state()
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_eq(GameSession.state_error(saved), "")
    assert_true(restored.restore_state(saved))
    assert_eq(restored.state(), saved)
    assert_eq(restored.snapshot(), original.snapshot())

    assert_eq(
        restored.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    assert_eq(
        restored.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
```

Add focused invalid-state tests by cloning one real valid state at a time:

```gdscript
func test_state_error_rejects_current_rule_incompatibilities() -> void:
    var base := GameSession.new(func() -> float: return 0.9).state()

    var bad_day := base.duplicate(true)
    bad_day["day"] = GameRules.MAX_DAY + 1
    assert_ne(GameSession.state_error(bad_day), "")

    var bad_time := base.duplicate(true)
    bad_time["time_minutes"] = GameRules.ACTION_CUTOFF_MINUTES + 1
    assert_ne(GameSession.state_error(bad_time), "")

    var bad_stamina := base.duplicate(true)
    bad_stamina["stamina"] = GameRules.MAX_STAMINA + 1
    assert_ne(GameSession.state_error(bad_stamina), "")

    var bad_money := base.duplicate(true)
    bad_money["money"] = -1
    assert_ne(GameSession.state_error(bad_money), "")

    var bad_farm := base.duplicate(true)
    bad_farm["farm"][0]["cell"] = Vector2i(11, 11)
    assert_ne(GameSession.state_error(bad_farm), "")

    var bad_relationships := base.duplicate(true)
    bad_relationships["relationships"].erase(&"resident")
    assert_ne(GameSession.state_error(bad_relationships), "")
```

Add crop-growth and summary-consistency cases after creating those states through real commands:

```gdscript
func test_state_error_rejects_crop_and_summary_inconsistency() -> void:
    var growing := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(growing)
    var bad_growth := growing.state()
    bad_growth["farm"][0]["crop"]["growth"] = GameRules.growth_nights(GameRules.CropKind.TURNIP) + 1
    assert_ne(GameSession.state_error(bad_growth), "")

    var morning := GameSession.new(func() -> float: return 0.9)
    assert_eq(morning.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var bad_summary := morning.state()
    bad_summary["pending_morning_summary"]["next_day"] = int(bad_summary["day"]) + 1
    assert_ne(GameSession.state_error(bad_summary), "")
```

- [ ] **Step 5: Run the restore tests and verify RED**

Run the same `test_game_session.gd` command. Expected: FAIL because `state_error()` and `restore_state()` do not exist.

- [ ] **Step 6: Implement current-rule validation and restore**

Use small private helpers local to `GameSession`; do not build a schema framework. Exact validation responsibilities:

```gdscript
static func state_error(candidate: Variant) -> String:
    if not (candidate is Dictionary):
        return "state must be a Dictionary"
    var state: Dictionary = candidate
    if int(state["day"]) < 1 or int(state["day"]) > GameRules.MAX_DAY:
        return "day is outside current rules"
    if int(state["time_minutes"]) < GameRules.DAY_START_MINUTES \
            or int(state["time_minutes"]) > GameRules.ACTION_CUTOFF_MINUTES:
        return "time is outside current rules"
    if int(state["stamina"]) < 0 or int(state["stamina"]) > GameRules.MAX_STAMINA:
        return "stamina is outside current rules"
    if int(state["money"]) < 0:
        return "money cannot be negative"

    var count_error := _count_state_error(state)
    if count_error != "":
        return count_error
    var farm_error := _farm_state_error(state["farm"])
    if farm_error != "":
        return farm_error
    var relationship_error := _relationship_state_error(state["relationships"])
    if relationship_error != "":
        return relationship_error
    return _morning_summary_state_error(state)
```

The helpers must additionally enforce the closed selected action/seed/weather keys, exact `WorldContract.farm_cells()` order, crop-on-tilled rule, crop growth maximum, all three relationship records, non-negative relationship points, and summary `next_day`, `next_weather`, and `money_after_shipping` consistency described by the spec.

Restore only after validation succeeds:

```gdscript
func restore_state(candidate: Dictionary) -> bool:
    if state_error(candidate) != "":
        return false

    _day = int(candidate["day"])
    _time_minutes = int(candidate["time_minutes"])
    _stamina = int(candidate["stamina"])
    _weather = GameRules.WEATHER_KEYS.find(candidate["weather"])
    _selected_action = GameRules.ACTION_KEYS.find(candidate["selected_action"])
    _selected_seed = GameRules.CROP_KEYS.find(candidate["selected_seed"])
    _money = int(candidate["money"])
    _seed_counts = _counts_array(candidate["seeds"])
    _harvested_counts = _counts_array(candidate["harvested"])
    _pending_shipment_counts = _counts_array(candidate["pending_shipment"])
    _farm = _farm_array(candidate["farm"])
    _relationships = _relationship_array(candidate["relationships"])
    _pending_morning_summary = (
        candidate["pending_morning_summary"].duplicate(true)
        if candidate["pending_morning_summary"] != null
        else null
    )
    return true
```

Implement `_counts_array`, `_farm_array`, and `_relationship_array` as direct conversions from the validated plain state. Reconstruct crop enum values from `GameRules.CROP_KEYS.find(...)`; never retain aliases into the caller's dictionary.

- [ ] **Step 7: Run GameSession tests and verify GREEN**

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

Expected: all existing and new GameSession tests PASS.

- [ ] **Step 8: Commit Task 1 and run clean verification**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add restorable Godot gameplay state"
./tools/verify-clean.sh
```

Expected: clean verifier passes from committed `HEAD`.

---

### Task 2: Versioned Save Codec and Concrete FileAccess Repository

**Files:**
- Create: `scripts/persistence/save_file.gd`
- Create: `scripts/persistence/save_repository.gd`
- Create: `tests/unit/test_save_file.gd`
- Create: `tests/integration/test_save_repository.gd`

**Interfaces:**
- Consumes: `GameSession.state()` runtime Dictionary shape
- Produces: `SaveFileCodec.encode(state: Dictionary) -> String`
- Produces: `SaveFileCodec.decode(text: String) -> Dictionary` with `{ "ok": true, "state": Dictionary }` or `{ "ok": false, "error": String }`
- Produces: `SaveRepository.new(path: String = SaveRepository.DEFAULT_PATH)`
- Produces: `SaveRepository.load() -> Dictionary` with statuses `missing`, `loaded`, `invalid`, `io_error`
- Produces: `SaveRepository.save(state: Dictionary) -> Error`

- [ ] **Step 1: Write failing SaveFileCodec round-trip tests**

Create `tests/unit/test_save_file.gd` and build state through `GameSession` commands:

```gdscript
extends GutTest

func _state_with_pending_summary() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    return session.state()

func test_encode_decode_round_trip_preserves_runtime_state() -> void:
    var state := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(state))
    assert_true(decoded["ok"])
    assert_eq(decoded["state"], state)
    assert_true(decoded["state"]["farm"][0]["cell"] is Vector2i)

func test_decode_result_is_deeply_isolated() -> void:
    var state := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(state))
    decoded["state"]["farm"][0]["tilled"] = false
    assert_true(state["farm"][0]["tilled"])
```

- [ ] **Step 2: Add failing malformed/unsupported-shape tests**

Pin the error surface without depending on exact parser prose:

```gdscript
func test_decode_rejects_malformed_json_and_wrong_schema() -> void:
    var malformed := SaveFileCodec.decode("{not json")
    assert_false(malformed["ok"])
    assert_ne(String(malformed["error"]), "")

    var wrong_version := SaveFileCodec.decode('{"schema_version":2,"state":{}}')
    assert_false(wrong_version["ok"])

func test_decode_rejects_fractional_and_unknown_closed_values() -> void:
    var state := _state_with_pending_summary()
    var envelope := JSON.parse_string(SaveFileCodec.encode(state))

    var fractional := envelope.duplicate(true)
    fractional["state"]["day"] = 1.5
    assert_false(SaveFileCodec.decode(JSON.stringify(fractional))["ok"])

    var unknown_weather := envelope.duplicate(true)
    unknown_weather["state"]["weather"] = "snow"
    assert_false(SaveFileCodec.decode(JSON.stringify(unknown_weather))["ok"])

    var missing_relationship := envelope.duplicate(true)
    missing_relationship["state"]["relationships"].erase("resident")
    assert_false(SaveFileCodec.decode(JSON.stringify(missing_relationship))["ok"])
```

Also add one nested crop/farm wrong-shape case and one wrong morning-summary shipment shape case.

- [ ] **Step 3: Run codec tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd -gexit
```

Expected: FAIL because `SaveFileCodec` does not exist.

- [ ] **Step 4: Implement the explicit schema-v1 codec**

Create `scripts/persistence/save_file.gd`:

```gdscript
class_name SaveFileCodec
extends RefCounted

const SCHEMA_VERSION := 1

static func encode(state: Dictionary) -> String:
    return JSON.stringify({
        "schema_version": SCHEMA_VERSION,
        "state": _encode_state(state),
    })

static func decode(text: String) -> Dictionary:
    var parser := JSON.new()
    var error := parser.parse(text)
    if error != OK:
        return {
            "ok": false,
            "error": "Invalid save JSON at line %d: %s" % [
                parser.get_error_line(),
                parser.get_error_message(),
            ],
        }
    return _decode_envelope(parser.data)

static func _failure(message: String) -> Dictionary:
    return {"ok": false, "error": message}
```

Keep schema helpers private and concrete. `_encode_state()` must convert each runtime `Vector2i` farm cell to `{ "x": cell.x, "y": cell.y }`, convert `StringName` keys/values to JSON strings, and explicitly copy state/relationships/summary rather than serializing scene/runtime objects.

For integer-shaped JSON fields, use one helper that rejects fractional/non-finite numeric values instead of truncating them:

```gdscript
static func _integer(value: Variant, path: String, result: Dictionary) -> Variant:
    if not (value is int or value is float):
        result["error"] = "%s must be an integer" % path
        return null
    var number := float(value)
    if not is_finite(number) or floor(number) != number:
        result["error"] = "%s must be a finite whole number" % path
        return null
    return int(number)
```

Implement direct `_dictionary`, `_array`, `_boolean`, `_string`, `_closed_key`, `_decode_counts`, `_decode_farm`, `_decode_relationships`, and `_decode_summary` helpers. They validate structure and known identifiers only; they must not duplicate `GameRules.MAX_DAY`, stamina limits, current farm identity, crop growth limits, or money/count range rules.

Decode known crop/action/weather/villager identifiers back into the runtime `StringName` values expected by `GameSession.state()`.

- [ ] **Step 5: Run codec tests and verify GREEN**

Run the codec test command again. Expected: PASS.

- [ ] **Step 6: Write failing concrete repository tests**

Create `tests/integration/test_save_repository.gd` with an isolated path:

```gdscript
extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-test.json"

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func after_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_missing_then_save_replace_and_load() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    assert_eq(repository.load()["status"], &"missing")

    var first := GameSession.new(func() -> float: return 0.9).state()
    assert_eq(repository.save(first), OK)
    var loaded := repository.load()
    assert_eq(loaded["status"], &"loaded")
    assert_eq(loaded["state"], first)

    var second_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(second_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var second := second_session.state()
    assert_eq(repository.save(second), OK)
    assert_eq(repository.load()["state"], second)

func test_malformed_file_is_invalid_not_a_crash() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string("{broken")
    file.close()
    var result := SaveRepository.new(TEST_PATH).load()
    assert_eq(result["status"], &"invalid")
    assert_ne(String(result["error"]), "")

func test_nonexistent_parent_directory_returns_write_error() -> void:
    var repository := SaveRepository.new("user://missing-hpa-598-dir/save.json")
    var error := repository.save(GameSession.new().state())
    assert_ne(error, OK)
```

- [ ] **Step 7: Run repository tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_save_repository.gd -gexit
```

Expected: FAIL because `SaveRepository` does not exist.

- [ ] **Step 8: Implement the concrete FileAccess repository**

Create `scripts/persistence/save_repository.gd`:

```gdscript
class_name SaveRepository
extends RefCounted

const DEFAULT_PATH := "user://phoenix-save.json"

var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
    _path = path

func load() -> Dictionary:
    if not FileAccess.file_exists(_path):
        return {"status": &"missing"}
    var file := FileAccess.open(_path, FileAccess.READ)
    if file == null:
        return {
            "status": &"io_error",
            "error": "Could not open save: %s" % error_string(FileAccess.get_open_error()),
        }
    var text := file.get_as_text()
    var read_error := file.get_error()
    file.close()
    if read_error != OK:
        return {
            "status": &"io_error",
            "error": "Could not read save: %s" % error_string(read_error),
        }
    var decoded := SaveFileCodec.decode(text)
    if not decoded["ok"]:
        return {"status": &"invalid", "error": decoded["error"]}
    return {"status": &"loaded", "state": decoded["state"].duplicate(true)}

func save(state: Dictionary) -> Error:
    var file := FileAccess.open(_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(SaveFileCodec.encode(state))
    file.flush()
    var write_error := file.get_error()
    file.close()
    return write_error
```

Do not add delete/backup/temp-file/retry methods; New Game does not delete the prior slot.

- [ ] **Step 9: Run Task 2 tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd,res://tests/integration/test_save_repository.gd -gexit
```

Expected: both files PASS.

- [ ] **Step 10: Commit Task 2 and run clean verification**

```bash
git add scripts/persistence tests/unit/test_save_file.gd tests/integration/test_save_repository.gd
git commit -m "feat: add one-slot Godot save storage"
./tools/verify-clean.sh
```

Expected: clean verifier passes.

---

### Task 3: Title Screen and App-Owned New Game/Continue Launch

**Files:**
- Create: `scripts/app/app_root.gd`
- Create: `scenes/app/app.tscn`
- Create: `scripts/ui/title_screen.gd`
- Create: `scenes/ui/title_screen.tscn`
- Modify: `project.godot`
- Modify: `tests/headless/project_smoke.gd`
- Create: `tests/integration/test_app_launch.gd`

**Interfaces:**
- Consumes: `SaveRepository.load()` and `GameSession.state_error()`
- Produces: `TitleScreen.new_game_requested`
- Produces: `TitleScreen.continue_requested`
- Produces: `TitleScreen.set_continue_state(available: bool, status: String = "") -> void`
- Produces: `AppRoot.configure(repository: SaveRepository) -> void` as a pre-tree test/injection seam
- Consumes later: `WorldShell.configure(initial_state: Variant, repository: SaveRepository)`; add the method stub in this task so AppRoot can launch the real world before Task 4 adds autosave behavior

- [ ] **Step 1: Write failing title/app launch tests**

Create `tests/integration/test_app_launch.gd`. Use a dedicated save path and clean it before/after each test:

```gdscript
extends GutTest

const APP_SCENE := preload("res://scenes/app/app.tscn")
const TEST_PATH := "user://phoenix-hpa-598-app-test.json"

func _repository() -> SaveRepository:
    return SaveRepository.new(TEST_PATH)

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func test_missing_save_keeps_new_game_and_disables_continue() -> void:
    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(_repository())
    add_child_autofree(app)
    await get_tree().process_frame
    var title := app.get_node("TitleScreen") as TitleScreen
    assert_false(title.continue_available())
    assert_false(title.new_game_disabled())

func test_valid_save_enables_continue_and_invalid_rule_state_does_not() -> void:
    var valid := GameSession.new(func() -> float: return 0.9)
    assert_eq(valid.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(_repository().save(valid.state()), OK)

    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(_repository())
    add_child_autofree(app)
    await get_tree().process_frame
    assert_true((app.get_node("TitleScreen") as TitleScreen).continue_available())
```

Add a second test that writes a structurally valid but rule-invalid state by editing the encoded envelope's `day` to `GameRules.MAX_DAY + 1`; assert Continue is disabled and New Game remains enabled.

Add launch assertions:

```gdscript
func test_new_game_and_continue_each_create_one_world() -> void:
    var saved_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(saved_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(_repository().save(saved_session.state()), OK)

    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(_repository())
    add_child_autofree(app)
    await get_tree().process_frame

    app.launch_continue_for_test()
    await get_tree().process_frame
    var world := app.get_node("World") as WorldShell
    assert_not_null(world)
    assert_eq(world.session_state_for_test(), saved_session.state())
    assert_eq(world.player.logical_position, WorldContract.PLAYER_SPAWN)
```

The two read-only helpers `launch_continue_for_test()` and `session_state_for_test()` may be `@warning_ignore("unused_private_class_variable")`-free public methods because they exercise real production launch/session state without mutation hooks. Do not add arbitrary state setters.

- [ ] **Step 2: Run app tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd -gexit
```

Expected: FAIL because the app/title scenes and classes do not exist.

- [ ] **Step 3: Author the presentation-only title scene**

Create `scripts/ui/title_screen.gd`:

```gdscript
class_name TitleScreen
extends Control

signal new_game_requested
signal continue_requested

@onready var _new_game_button: Button = $Panel/NewGame as Button
@onready var _continue_button: Button = $Panel/Continue as Button
@onready var _status_label: Label = $Panel/Status as Label

func _ready() -> void:
    _new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
    _continue_button.pressed.connect(func() -> void: continue_requested.emit())
    _continue_button.disabled = true

func set_continue_state(available: bool, status: String = "") -> void:
    _continue_button.disabled = not available
    _status_label.text = status

func continue_available() -> bool:
    return not _continue_button.disabled

func new_game_disabled() -> bool:
    return _new_game_button.disabled
```

Author `scenes/ui/title_screen.tscn` as a full-viewport `Control` with one centered panel containing named nodes `Title`, `NewGame`, `Continue`, and `Status`. Use ordinary Godot `Control` nodes only; no custom UI framework.

- [ ] **Step 4: Add pre-tree WorldShell configuration without changing sleep behavior yet**

Modify `scripts/world/world_shell.gd` so the session is created/restored before its first render:

```gdscript
var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository = null

func configure(initial_state: Variant, repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository

func session_state_for_test() -> Dictionary:
    return _session.state()
```

At the top of `_ready()`:

```gdscript
_session = GameSession.new()
if _initial_state != null:
    assert(_session.restore_state(_initial_state), "AppRoot supplied invalid restored state")
```

Do not persist anything in this task. Existing tests that instantiate `world.tscn` directly are allowed to leave `_save_repository == null`.

- [ ] **Step 5: Implement AppRoot load/launch ownership**

Create `scripts/app/app_root.gd`:

```gdscript
class_name AppRoot
extends Node

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var _save_repository: SaveRepository
var _continue_state: Variant = null

@onready var _title_screen: TitleScreen = $TitleScreen as TitleScreen

func configure(repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _save_repository = repository

func _ready() -> void:
    if _save_repository == null:
        _save_repository = SaveRepository.new()
    _title_screen.new_game_requested.connect(_on_new_game_requested)
    _title_screen.continue_requested.connect(_on_continue_requested)
    _load_title_state()

func _load_title_state() -> void:
    var result := _save_repository.load()
    match result["status"]:
        &"missing":
            _continue_state = null
            _title_screen.set_continue_state(false)
        &"loaded":
            var error := GameSession.state_error(result["state"])
            if error == "":
                _continue_state = result["state"].duplicate(true)
                _title_screen.set_continue_state(true)
            else:
                _continue_state = null
                _title_screen.set_continue_state(false, "Save is incompatible; start a New Game.")
        &"invalid", &"io_error":
            _continue_state = null
            _title_screen.set_continue_state(false, "Save unavailable; start a New Game.")

func _on_new_game_requested() -> void:
    _launch(null)

func _on_continue_requested() -> void:
    if _continue_state != null:
        _launch(_continue_state)

func _launch(initial_state: Variant) -> void:
    var world := WORLD_SCENE.instantiate() as WorldShell
    world.name = "World"
    world.configure(initial_state, _save_repository)
    add_child(world)
    _title_screen.visible = false

func launch_continue_for_test() -> void:
    _on_continue_requested()
```

Guard `_launch()` from creating a second world if one already exists. New Game must not delete the existing save file.

Create `scenes/app/app.tscn` with root `AppRoot` and one child instance named `TitleScreen`.

- [ ] **Step 6: Switch the project main scene and pin it in headless smoke**

Change:

```ini
run/main_scene="res://scenes/app/app.tscn"
```

Add to `tests/headless/project_smoke.gd`:

```gdscript
if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/app/app.tscn":
    _fail("main scene must be the HPA-598 app root")
    return
```

Do not make `world_shell_smoke.gd` load the app; it should remain a direct world-contract smoke.

- [ ] **Step 7: Run app launch plus existing gameplay-shell tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd,res://tests/integration/test_gameplay_shell.gd -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
```

Expected: title/app tests PASS, existing gameplay-shell tests remain PASS, project smoke passes with the new main scene.

- [ ] **Step 8: Commit Task 3 and run clean verification**

```bash
git add scripts/app scenes/app scripts/ui/title_screen.gd scenes/ui/title_screen.tscn \
  scripts/world/world_shell.gd project.godot tests/integration/test_app_launch.gd \
  tests/headless/project_smoke.gd
git commit -m "feat: add Godot new game and continue launch"
./tools/verify-clean.sh
```

Expected: clean verifier passes.

---

### Task 4: Post-Sleep Autosave, Save Status, and Persistence Flow Acceptance

**Files:**
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Create: `tests/integration/test_persistence_flow.gd`

**Interfaces:**
- Consumes: configured `SaveRepository`
- Produces: `GameHud.set_save_status(status: StringName, message: String = "") -> void`
- Preserves: `GameHud.has_blocking_modal()` as the only world-input gate
- Preserves: `GameSession.sleep()` as the complete synchronous overnight gameplay transaction

- [ ] **Step 1: Write failing HUD save-status test**

Add a focused test in `test_gameplay_shell.gd` that renders a pending morning summary, then checks saving disables only the summary acknowledgement control:

```gdscript
func test_morning_summary_save_status_gates_acknowledge_only_while_saving() -> void:
    var world := await _spawn_world()
    var hud := world.hud
    world._session.set("_pending_morning_summary", {
        "completed_day": 1,
        "next_day": 2,
        "crops_advanced": 0,
        "next_weather": &"sunny",
        "stamina_restored": 0,
        "shipments": [],
        "shipping_income": 0,
        "money_after_shipping": GameRules.STARTING_MONEY,
    })
    world._refresh_from_session()

    hud.set_save_status(&"saving")
    assert_true((hud.get_node("HudRoot/MorningSummaryPanel/Acknowledge") as Button).disabled)
    assert_eq(
        (hud.get_node("HudRoot/MorningSummaryPanel/SaveStatus") as Label).text,
        "Saving…",
    )

    hud.set_save_status(&"saved")
    assert_false((hud.get_node("HudRoot/MorningSummaryPanel/Acknowledge") as Button).disabled)
    assert_eq(
        (hud.get_node("HudRoot/MorningSummaryPanel/SaveStatus") as Label).text,
        "Saved.",
    )
```

If the existing integration file avoids private test setup, create the session summary using the existing sleep interaction helper instead of direct `set()`. Do not add a production state mutator solely for this test.

- [ ] **Step 2: Run the HUD test and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit
```

Expected: FAIL because `set_save_status()` and `SaveStatus` do not exist.

- [ ] **Step 3: Add the minimal morning-summary save status UI**

In `GameHud`, retain the summary button/label:

```gdscript
var _morning_summary_acknowledge: Button
var _save_status_label: Label
```

In `_build_summary_panel()`:

```gdscript
_save_status_label = _add_label(
    panel,
    "SaveStatus",
    "",
    Vector2(12, 154),
    Vector2(184, 20),
)
_morning_summary_acknowledge = _add_button(
    panel,
    "Acknowledge",
    "Acknowledge",
    Vector2(208, 170),
    Vector2(104, 28),
)
_morning_summary_acknowledge.pressed.connect(
    func() -> void: morning_summary_acknowledged.emit()
)
```

Add:

```gdscript
func set_save_status(status: StringName, message: String = "") -> void:
    match status:
        &"idle":
            _save_status_label.text = ""
            _morning_summary_acknowledge.disabled = false
        &"saving":
            _save_status_label.text = "Saving…"
            _morning_summary_acknowledge.disabled = true
        &"saved":
            _save_status_label.text = "Saved."
            _morning_summary_acknowledge.disabled = false
        &"error":
            _save_status_label.text = message
            _morning_summary_acknowledge.disabled = false
        _:
            assert(false, "unknown save status")
```

When the summary transitions from visible to hidden, call `set_save_status(&"idle")`. Do not add a second modal or modify `has_blocking_modal()`.

- [ ] **Step 4: Write failing production autosave flow tests**

Create `tests/integration/test_persistence_flow.gd` with a test-only concrete repository subclass that counts real writes while still using FileAccess:

```gdscript
extends GutTest

class CountingSaveRepository extends SaveRepository:
    var save_calls := 0

    func save(state: Dictionary) -> Error:
        save_calls += 1
        return super.save(state)

const APP_SCENE := preload("res://scenes/app/app.tscn")
const TEST_PATH := "user://phoenix-hpa-598-flow-test.json"

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
```

Drive representative state through real session commands, then use the world sleep handler with the player targeting the authored bed. Reuse existing gameplay-shell player/target helpers rather than adding a teleport/debug API.

The success test must assert all of these after the one-frame save completes:

```gdscript
assert_eq(repository.save_calls, 1)
assert_eq(world.session_state_for_test()["day"], 2)
assert_not_null(world.session_state_for_test()["pending_morning_summary"])
assert_eq(repository.load()["state"], world.session_state_for_test())
assert_eq(
    (world.hud.get_node("HudRoot/MorningSummaryPanel/SaveStatus") as Label).text,
    "Saved.",
)
```

Then free the first app/world, create a fresh AppRoot with the same repository, launch Continue, and assert:

```gdscript
assert_eq(restored_world.session_state_for_test(), saved_state)
assert_eq(restored_world.player.logical_position, WorldContract.PLAYER_SPAWN)
assert_eq(
    restored_world.session_state_for_test()["pending_morning_summary"],
    saved_state["pending_morning_summary"],
)
```

Acknowledge the restored summary and perform one real farm or social command so restore is proven operational, not merely equal by snapshot.

Add a duplicate-input case that invokes the sleep request twice before the first save frame completes and asserts `save_calls == 1` and `day == 2`.

Add failure coverage using `SaveRepository.new("user://missing-hpa-598-flow-dir/save.json")`: after sleep, assert day advanced, the summary still exists, status text is `Save failed — this morning is not persisted.`, and the acknowledge button is enabled after the attempt.

- [ ] **Step 5: Run persistence flow tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_persistence_flow.gd -gexit
```

Expected: FAIL because WorldShell does not perform post-sleep persistence or guard duplicate save orchestration.

- [ ] **Step 6: Implement one-write post-sleep orchestration in WorldShell**

Add:

```gdscript
var _overnight_save_in_progress := false
```

Replace `_on_sleep_requested()` with the one transaction boundary:

```gdscript
func _on_sleep_requested() -> void:
    if _overnight_save_in_progress:
        return

    var target: Variant = player.current_target_cell()
    var code := _session.sleep(target)
    if code != GameRules.CommandCode.DAY_ADVANCED or _save_repository == null:
        _finish_command(code)
        return

    _overnight_save_in_progress = true
    hud.show_feedback(code)
    _refresh_from_session()
    hud.set_save_status(&"saving")
    await get_tree().process_frame

    var error := _save_repository.save(_session.state())
    if error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(
            &"error",
            "Save failed — this morning is not persisted.",
        )
    _overnight_save_in_progress = false
```

The completed state is rendered before the write, and no state rollback occurs on error. Existing direct world tests without a configured repository keep the old no-storage behavior, while the production `AppRoot` always supplies one repository.

- [ ] **Step 7: Run full integration tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration -gexit
```

Expected: app launch, repository, gameplay shell, and persistence flow tests all PASS.

- [ ] **Step 8: Commit Task 4 and run clean verification**

```bash
git add scripts/world/world_shell.gd scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd
git commit -m "feat: autosave completed Godot mornings"
./tools/verify-clean.sh
```

Expected: clean verifier passes.

---

### Task 5: Handoff Documentation, Full Verification, and macOS Close/Reopen Acceptance

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `AGENTS.md`
- Verify only: `export_presets.cfg`
- Verify only: all implementation/test files from Tasks 1–4

**Interfaces:**
- No new runtime interface.
- Documentation must identify HPA-597 as the next delivery slice after HPA-598.

- [ ] **Step 1: Update README with the player-visible persistence contract**

Document these exact behaviors in the existing gameplay/run sections:

```text
Phoenix now opens on a title screen. New Game always starts a fresh run.
Continue is enabled only when user://phoenix-save.json contains a valid current
schema-v1 save. Sleeping successfully advances the day first, then writes that
completed next-morning state. The saved morning summary is restored on
Continue. Player position is not saved; Continue starts at the authored spawn.
If loading or saving fails, New Game/play remains available and a completed day
is never rolled back.
```

Do not document old TypeScript/Tauri storage as a supported runtime.

- [ ] **Step 2: Update CLAUDE.md architecture/handoff rules**

Add the persisted boundary without weakening the existing authorities:

```text
- scripts/app/app_root.gd owns title/load/launch lifecycle and one concrete
  SaveRepository. It never owns gameplay mutation.
- scripts/persistence/save_file.gd owns schema-v1 JSON structure/conversion.
- scripts/persistence/save_repository.gd is the only production storage adapter
  and writes user://phoenix-save.json through FileAccess.
- GameSession.state()/state_error()/restore_state() own mutable-state export and
  current-rule compatibility; snapshot() remains the derived read model.
- WorldShell remains the only live production session holder and writes exactly
  once after successful overnight advancement.
- World/player position, facing, camera, and UI state remain transient and are
  reconstructed from authored scenes.
- HPA-597 is the next delivery slice and extends this Godot state directly.
```

Keep the `AGENTS.md` symlink unchanged.

- [ ] **Step 3: Run static consistency checks**

```bash
git diff --check main...HEAD
test -L AGENTS.md
test "$(readlink AGENTS.md)" = "CLAUDE.md"
grep -R "localStorage\|Tauri Store\|SaveManager" \
  scripts scenes README.md CLAUDE.md --exclude='*.uid' || true
```

Inspect any grep hit. Historical wording outside active runtime documentation is acceptable only when explicitly labeled historical; production code must contain no localStorage/Tauri Store/SaveManager implementation.

- [ ] **Step 4: Run the complete committed clean verifier**

Commit the docs first because the verifier archives `HEAD`:

```bash
git add README.md CLAUDE.md
git commit -m "docs: document Godot persistence handoff"
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected: verifier passes, diff check is clean, and worktree is clean.

- [ ] **Step 5: Perform the required macOS exported-build close/reopen acceptance**

With Godot 4.7.1 export templates installed, export the existing `macOS` preset:

```bash
rm -rf /tmp/Phoenix-HPA-598.app
godot --headless --path . --export-debug "macOS" /tmp/Phoenix-HPA-598.app
open /tmp/Phoenix-HPA-598.app
```

In the exported app:

1. Confirm the title screen appears and Continue is disabled when no valid save exists.
2. Choose New Game.
3. Make at least one visible gameplay-state change and successfully sleep once.
4. Wait until the morning summary shows `Saved.`.
5. Quit the app normally.
6. Reopen `/tmp/Phoenix-HPA-598.app`.
7. Confirm Continue is enabled.
8. Continue and confirm the saved day/current state and pending morning summary are restored.
9. Confirm the player is at the authored spawn rather than the previous world position.
10. Acknowledge the summary and perform one normal action/interact command.

Record the result in the PR description; do not add a desktop WebDriver harness or CI export matrix.

- [ ] **Step 6: Final self-review before marking implementation ready**

Review `main...HEAD` as one HPA-598 PR and confirm:

```bash
git diff --stat main...HEAD
git diff --name-only main...HEAD
./tools/verify-clean.sh
git diff --check main...HEAD
```

The diff must contain the planning docs plus only the HPA-598 runtime/tests/docs described above. Confirm there is no save migration, backward-compatibility code, generic repository abstraction, autoload manager, tutorial/finale implementation, unrelated refactor, or second PR/branch delivery split.

## Plan self-review

- **Spec coverage:** Tasks 1–4 cover canonical state, structural schema, current-rule validation, FileAccess storage, title flow, fixed-spawn Continue, post-sleep one-write autosave, duplicate-input protection, save status/failure semantics, and automated round-trip acceptance. Task 5 covers handoff docs, full clean verification, and the required exported macOS close/reopen check.
- **Scope:** One ticket, one branch, one PR. No platform abstraction, migration, backup, security hardening, or HPA-597/HPA-599 work has been introduced.
- **Type/interface consistency:** `GameSession.state()/state_error()/restore_state()`, `SaveFileCodec.encode()/decode()`, `SaveRepository.load()/save()`, `AppRoot.configure()`, `WorldShell.configure()`, and `GameHud.set_save_status()` are defined once and consumed consistently by later tasks.
- **Placeholder scan:** The plan contains no TBD/TODO/follow-up implementation placeholders; every task names exact files, commands, interfaces, and expected test outcomes.
