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
- Do not add production methods whose only purpose is testing. Integration tests may inspect the existing private-by-convention `_session` through `world.get("_session")` and drive existing signals/player targeting instead.
- Preserve the typed-GDScript fixture pattern from HPA-594: when a helper expects `Array[int]`, create a typed variable rather than passing an untyped array literal through the boundary.
- The primary persistence round trip must be command-driven: grow and harvest real crops, gift one, ship one, then sleep/save. Direct private-field seeding is allowed only in already-established narrow unit fixtures, never as the acceptance path.
- `tools/verify-clean.sh` validates committed `HEAD`, not uncommitted worktree changes. Use direct GUT commands during RED/GREEN and the clean verifier after each task commit.

## Local RED/GREEN test setup

The repository ignores `/addons/`, so provision the same pinned GUT used by `tools/verify-clean.sh` once before Task 1:

```bash
rm -rf addons/gut /tmp/phoenix-gut.tgz
mkdir -p addons/gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o /tmp/phoenix-gut.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut.tgz" | shasum -a 256 -c -
tar -xzf /tmp/phoenix-gut.tgz --strip-components=3 -C addons/gut "Gut-9.7.1/addons/gut"
godot --headless --path . --editor --quit
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
- Preserves: `GameSession.snapshot() -> Dictionary`, including derived `max_stamina` and relationship `level`
- Consumed later by: `SaveFileCodec`, `AppRoot`, and `WorldShell`

- [ ] **Step 1: Add the failing canonical-state/deep-clone test**

```gdscript
func test_state_is_deeply_isolated_and_excludes_derived_fields() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var june := VillagerRules.VillagerId.RESIDENT
    var harvested: Array[int] = [1, 0, 0]
    _seed_harvested(session, harvested)
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )

    var mutable_state := session.state()
    assert_false(mutable_state.has("max_stamina"))
    assert_false(mutable_state["relationships"][&"resident"].has("level"))
    mutable_state["harvested"][&"turnip"] = 99
    mutable_state["relationships"][&"resident"]["points"] = 99
    mutable_state["farm"][0]["tilled"] = true

    var fresh := session.state()
    assert_eq(fresh["harvested"][&"turnip"], 1)
    assert_eq(fresh["relationships"][&"resident"]["points"], 1)
    assert_false(fresh["farm"][0]["tilled"])
    assert_eq(session.snapshot()["max_stamina"], GameRules.MAX_STAMINA)
    assert_eq(session.snapshot()["relationships"][&"resident"]["level"], &"stranger")
```

- [ ] **Step 2: Run the state test and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

Expected: FAIL because `GameSession.state()` does not exist.

- [ ] **Step 3: Implement one mutable-state projection and derive `snapshot()` from it**

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

Remove `_relationships_snapshot()` after its caller is gone. Keep `_farm_snapshot()` as the canonical farm-state clone rather than adding a persistence twin.

- [ ] **Step 4: Add failing command-driven restore/current-rule tests**

The valid restore fixture uses only real gameplay commands:

```gdscript
func test_command_driven_state_restores_and_remains_commandable() -> void:
    var original := GameSession.new(func() -> float: return 0.9)
    var cell := Vector2i(2, 7)
    assert_eq(original.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(original.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(original.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(original.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var saved := original.state()
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_eq(GameSession.state_error(saved), "")
    assert_true(restored.restore_state(saved))
    assert_eq(restored.state(), saved)
    assert_eq(restored.snapshot(), original.snapshot())

    assert_eq(restored.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    assert_eq(
        restored.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
```

Add focused current-rule incompatibilities by cloning a valid state:

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

Pin crop growth and pending-summary consistency separately:

```gdscript
func test_state_error_rejects_crop_and_summary_inconsistency() -> void:
    var growing := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(growing)
    var bad_growth := growing.state()
    bad_growth["farm"][0]["crop"]["growth"] = (
        GameRules.growth_nights(GameRules.CropKind.TURNIP) + 1
    )
    assert_ne(GameSession.state_error(bad_growth), "")

    var morning := GameSession.new(func() -> float: return 0.9)
    assert_eq(morning.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var bad_summary := morning.state()
    bad_summary["pending_morning_summary"]["next_day"] = int(bad_summary["day"]) + 1
    assert_ne(GameSession.state_error(bad_summary), "")
```

- [ ] **Step 5: Run GameSession tests and verify RED**

Run the Task 1 command again. Expected: FAIL because `state_error()` and `restore_state()` do not exist.

- [ ] **Step 6: Implement current-rule validation and deep-copy restore**

`state_error()` receives a structurally parsed state later produced by `SaveFileCodec`. Keep JSON parsing out of `GameSession` and enforce these current rules with small private helpers:

```gdscript
static func state_error(candidate: Variant) -> String:
    if not (candidate is Dictionary):
        return "state must be a Dictionary"
    var value: Dictionary = candidate
    if int(value["day"]) < 1 or int(value["day"]) > GameRules.MAX_DAY:
        return "day is outside current rules"
    if int(value["time_minutes"]) < GameRules.DAY_START_MINUTES \
            or int(value["time_minutes"]) > GameRules.ACTION_CUTOFF_MINUTES:
        return "time is outside current rules"
    if int(value["stamina"]) < 0 or int(value["stamina"]) > GameRules.MAX_STAMINA:
        return "stamina is outside current rules"
    if int(value["money"]) < 0:
        return "money cannot be negative"

    var counts_error := _count_state_error(value)
    if counts_error != "":
        return counts_error
    var farm_error := _farm_state_error(value["farm"])
    if farm_error != "":
        return farm_error
    var relationships_error := _relationship_state_error(value["relationships"])
    if relationships_error != "":
        return relationships_error
    return _morning_summary_state_error(value)
```

The helpers must additionally enforce current weather/action/seed keys, non-negative counts/relationship points, exactly `WorldContract.farm_cells()` in authored order, crop-on-tilled state, growth `0..GameRules.growth_nights(kind)`, all three current villager records, and summary `next_day == state.day`, `next_weather == state.weather`, `money_after_shipping == state.money`.

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

`_counts_array`, `_farm_array`, and `_relationship_array` must construct new containers and convert known StringName keys back to enum indexes. Never retain aliases into `candidate`.

- [ ] **Step 7: Run GameSession tests and verify GREEN**

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

---

### Task 2: Versioned Save Codec and Concrete FileAccess Repository

**Files:**
- Create: `scripts/persistence/save_file.gd`
- Create: `scripts/persistence/save_repository.gd`
- Create: `tests/unit/test_save_file.gd`
- Create: `tests/integration/test_save_repository.gd`

**Interfaces:**
- Consumes: `GameSession.state()`
- Produces: `SaveFileCodec.encode(state: Dictionary) -> String`
- Produces: `SaveFileCodec.decode(text: String) -> Dictionary` with `{ "ok": true, "state": Dictionary }` or `{ "ok": false, "error": String }`
- Produces: `SaveRepository.new(path: String = SaveRepository.DEFAULT_PATH)`
- Produces: `SaveRepository.load() -> Dictionary` with statuses `missing`, `loaded`, `invalid`, `io_error`
- Produces: `SaveRepository.save(state: Dictionary) -> Error`

- [ ] **Step 1: Write failing codec round-trip/shape tests**

Create `tests/unit/test_save_file.gd`:

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

func test_decode_rejects_malformed_json_and_wrong_schema() -> void:
    var malformed := SaveFileCodec.decode("{not json")
    assert_false(malformed["ok"])
    assert_ne(String(malformed["error"]), "")
    assert_false(SaveFileCodec.decode('{"schema_version":2,"state":{}}')["ok"])
```

Use the generated valid envelope to test fractional integers, unknown weather, a missing relationship, one wrong farm/crop nested type, and one wrong summary-shipment type.

- [ ] **Step 2: Run codec tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd -gexit
```

Expected: FAIL because `SaveFileCodec` does not exist.

- [ ] **Step 3: Implement the explicit schema-v1 codec**

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
    var parse_error := parser.parse(text)
    if parse_error != OK:
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

`_encode_state()` explicitly converts farm `Vector2i` cells to `{ "x", "y" }`, StringName values to strings, crop/villager keys to string keys, and summary shipment crop keys to strings. Use small private `_dictionary`, `_array`, `_boolean`, `_string`, `_integer`, `_closed_key`, `_decode_counts`, `_decode_farm`, `_decode_relationships`, and `_decode_summary` helpers. `_integer` accepts only numeric, finite, whole values and never truncates `1.5`.

The codec validates structure/known identifiers only. Do not duplicate max day/stamina, non-negative ranges, farm identity, crop growth limits, or summary equality from Task 1. Decode known identifier strings back into the runtime StringName values used by `GameSession.state()`.

- [ ] **Step 4: Run codec tests and verify GREEN**

Run the Task 2 codec command again. Expected: PASS.

- [ ] **Step 5: Write failing concrete repository tests**

Create `tests/integration/test_save_repository.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-repository-test.json"

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func test_missing_then_save_replace_and_load() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    assert_eq(repository.load()["status"], &"missing")
    var first := GameSession.new(func() -> float: return 0.9).state()
    assert_eq(repository.save(first), OK)
    assert_eq(repository.load()["state"], first)

    var second_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(second_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var second := second_session.state()
    assert_eq(repository.save(second), OK)
    assert_eq(repository.load()["state"], second)

func test_malformed_file_is_invalid_not_a_crash() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    assert_not_null(file)
    file.store_string("{broken")
    file.close()
    var result := SaveRepository.new(TEST_PATH).load()
    assert_eq(result["status"], &"invalid")
    assert_ne(String(result["error"]), "")

func test_nonexistent_parent_directory_returns_write_error() -> void:
    var repository := SaveRepository.new("user://missing-hpa-598-dir/save.json")
    assert_ne(repository.save(GameSession.new().state()), OK)
```

- [ ] **Step 6: Run repository tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_save_repository.gd -gexit
```

Expected: FAIL because `SaveRepository` does not exist.

- [ ] **Step 7: Implement the concrete FileAccess repository**

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
    file.close()
    var decoded := SaveFileCodec.decode(text)
    if not decoded["ok"]:
        return {"status": &"invalid", "error": decoded["error"]}
    return {"status": &"loaded", "state": decoded["state"].duplicate(true)}

func save(state: Dictionary) -> Error:
    var text := SaveFileCodec.encode(state)
    var file := FileAccess.open(_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(text)
    file.flush()
    var write_error := file.get_error()
    file.close()
    return write_error
```

Do not add delete, backup, temp-file, retry, or alternate adapter methods.

- [ ] **Step 8: Run Task 2 tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd,res://tests/integration/test_save_repository.gd -gexit
```

Expected: both files PASS.

- [ ] **Step 9: Commit Task 2 and run clean verification**

```bash
git add scripts/persistence tests/unit/test_save_file.gd tests/integration/test_save_repository.gd
git commit -m "feat: add one-slot Godot save storage"
./tools/verify-clean.sh
```

---

### Task 3: Title Screen and App-Owned New Game/Continue Launch

**Files:**
- Create: `scripts/app/app_root.gd`
- Create: `scenes/app/app.tscn`
- Create: `scripts/ui/title_screen.gd`
- Create: `scenes/ui/title_screen.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `project.godot`
- Modify: `tests/headless/project_smoke.gd`
- Create: `tests/integration/test_app_launch.gd`

**Interfaces:**
- Consumes: `SaveRepository.load()` and `GameSession.state_error()`
- Produces: `TitleScreen.new_game_requested`, `TitleScreen.continue_requested`
- Produces: `TitleScreen.set_continue_state(available: bool, status: String = "") -> void`
- Produces: `AppRoot.configure(repository: SaveRepository) -> void`
- Produces: `WorldShell.configure(initial_state: Variant, repository: SaveRepository) -> void`
- Does not produce test-only launch/state accessors

- [ ] **Step 1: Write failing title/load/launch tests using named nodes and real signals**

Create `tests/integration/test_app_launch.gd` with an isolated repository path. Cover missing save, valid save, and a structurally valid state with `day = GameRules.MAX_DAY + 1`. Inspect `Panel/NewGame`, `Panel/Continue`, and `Panel/Status` directly so no test-only title API is needed.

Continue must be driven through the production signal:

```gdscript
func test_continue_restores_state_and_uses_authored_spawn() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var saved_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(saved_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var saved_state := saved_session.state()
    assert_eq(repository.save(saved_state), OK)

    var app := _spawn_app(repository)
    var title := app.get_node("TitleScreen") as TitleScreen
    title.continue_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    var live_session := world.get("_session") as GameSession
    assert_eq(live_session.state(), saved_state)
    assert_true(
        WorldMath.world_to_grid(world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )
```

Add a New Game signal test asserting a fresh Day 1 session launches even if an older valid save exists; New Game must not delete that file.

- [ ] **Step 2: Run app tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd -gexit
```

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
```

Author `scenes/ui/title_screen.tscn` as a full-viewport `Control` containing `Panel`, `Panel/Title`, `Panel/NewGame`, `Panel/Continue`, and `Panel/Status`.

- [ ] **Step 4: Add pre-tree WorldShell configuration and restore before first render**

Replace eager session construction:

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

```gdscript
_session = GameSession.new()
if _initial_state != null:
    assert(_session.restore_state(_initial_state), "AppRoot supplied invalid restored state")
```

Do not persist anything in this task. Direct `world.tscn` tests may leave `_save_repository == null`.

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
            var state_error := GameSession.state_error(result["state"])
            if state_error == "":
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
    if get_node_or_null("World") != null:
        return
    var world := WORLD_SCENE.instantiate() as WorldShell
    world.name = "World"
    world.configure(initial_state, _save_repository)
    add_child(world)
    _title_screen.visible = false
```

Create `scenes/app/app.tscn` with root `AppRoot` and one child instance named `TitleScreen`.

- [ ] **Step 6: Switch and pin the project main scene**

Change `project.godot`:

```ini
run/main_scene="res://scenes/app/app.tscn"
```

Add to `tests/headless/project_smoke.gd`:

```gdscript
if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/app/app.tscn":
    _fail("main scene must be the HPA-598 app root")
    return
```

- [ ] **Step 7: Run app + existing gameplay-shell tests and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd,res://tests/integration/test_gameplay_shell.gd -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
```

- [ ] **Step 8: Commit Task 3 and run clean verification**

```bash
git add scripts/app scenes/app scripts/ui/title_screen.gd scenes/ui/title_screen.tscn \
  scripts/world/world_shell.gd project.godot tests/integration/test_app_launch.gd \
  tests/headless/project_smoke.gd
git commit -m "feat: add Godot new game and continue launch"
./tools/verify-clean.sh
```

---

### Task 4: Post-Sleep Autosave, Save Status, and Command-Driven Persistence Acceptance

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

- [ ] **Step 1: Write the failing HUD save-status test**

Use a standalone real session to create the summary; do not mutate the live WorldShell session:

```gdscript
func test_morning_summary_save_status_gates_acknowledge_only_while_saving() -> void:
    var world := _world()
    if world == null:
        return
    var session := GameSession.new(func() -> float: return 0.9)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    world.hud.render(session.snapshot())

    world.hud.set_save_status(&"saving")
    var acknowledge := world.hud.get_node(
        "HudRoot/MorningSummaryPanel/Acknowledge"
    ) as Button
    var status := world.hud.get_node(
        "HudRoot/MorningSummaryPanel/SaveStatus"
    ) as Label
    assert_true(acknowledge.disabled)
    assert_eq(status.text, "Saving…")

    world.hud.set_save_status(&"saved")
    assert_false(acknowledge.disabled)
    assert_eq(status.text, "Saved.")
```

- [ ] **Step 2: Run gameplay-shell tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit
```

- [ ] **Step 3: Add the minimal morning-summary save status UI**

Retain the summary button and add one label:

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

When the morning summary changes from visible to hidden, call `set_save_status(&"idle")`. Do not add another modal or input gate.

- [ ] **Step 4: Build the acceptance state entirely through real commands**

Create `tests/integration/test_persistence_flow.gd`. The setup state grows two Turnips for three real nights, harvests both, talks/gifts one, and ships the other:

```gdscript
extends GutTest

class CountingSaveRepository:
    extends SaveRepository

    var save_calls := 0

    func save(state: Dictionary) -> Error:
        save_calls += 1
        return super.save(state)

const APP_SCENE := preload("res://scenes/app/app.tscn")
const TEST_PATH := "user://phoenix-hpa-598-flow-test.json"

func _command_driven_pre_save_state() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var first: Vector2i = WorldContract.farm_cells()[0]
    var second: Vector2i = WorldContract.farm_cells()[1]

    for cell in [first, second]:
        assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

    for _night in GameRules.growth_nights(GameRules.CropKind.TURNIP):
        assert_eq(session.water(first), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.water(second), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )

    assert_eq(session.harvest(first), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(session.harvest(second), GameRules.CommandCode.CROP_HARVESTED)
    var june := VillagerRules.VillagerId.RESIDENT
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )
    assert_eq(
        session.gift_crop(
            june,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(june),
        )["code"],
        GameRules.CommandCode.CROP_GIFTED,
    )
    assert_eq(
        session.deposit_crop(
            GameRules.CropKind.TURNIP,
            1,
            WorldContract.SHIPPING_CELL,
        ),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    return session.state()
```

This is the primary round-trip fixture. Do not replace it with `set("_harvested_counts", ...)` or another private state shortcut.

Add a bed-target helper using the existing projection/target contract:

```gdscript
func _target_bed(world: WorldShell) -> void:
    world.player.global_position = WorldMath.grid_to_world(Vector2(5.5, 7.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.BED_CELL)
```

- [ ] **Step 5: Add failing one-write/Continue/failure tests**

Bootstrap the command-driven state through the real codec/repository, then use a counting subclass only for the final production save:

```gdscript
func test_final_sleep_writes_once_and_continue_restores_complete_morning() -> void:
    var prepared := _command_driven_pre_save_state()
    assert_eq(SaveRepository.new(TEST_PATH).save(prepared), OK)

    var repository := CountingSaveRepository.new(TEST_PATH)
    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(repository)
    add_child_autoqfree(app)
    var title := app.get_node("TitleScreen") as TitleScreen
    title.continue_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    var session := world.get("_session") as GameSession
    assert_eq(session.state(), prepared)
    _target_bed(world)
    world.hud.sleep_requested.emit()
    await get_tree().process_frame
    await get_tree().process_frame

    assert_eq(repository.save_calls, 1)
    var saved_state: Dictionary = repository.load()["state"]
    assert_eq(saved_state, session.state())
    assert_eq(saved_state["day"], int(prepared["day"]) + 1)
    assert_eq(saved_state["pending_shipment"][&"turnip"], 0)
    assert_true(int(saved_state["money"]) > int(prepared["money"]))
    assert_false(saved_state["relationships"][&"resident"]["talked_today"])
    assert_false(saved_state["relationships"][&"resident"]["gifted_today"])
    assert_not_null(saved_state["pending_morning_summary"])

    app.queue_free()
    await get_tree().process_frame

    var restored_app := APP_SCENE.instantiate() as AppRoot
    restored_app.configure(repository)
    add_child_autoqfree(restored_app)
    var restored_title := restored_app.get_node("TitleScreen") as TitleScreen
    restored_title.continue_requested.emit()
    await get_tree().process_frame

    var restored_world := restored_app.get_node("World") as WorldShell
    var restored_session := restored_world.get("_session") as GameSession
    assert_eq(restored_session.state(), saved_state)
    assert_true(
        WorldMath.world_to_grid(restored_world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )
    assert_eq(
        restored_session.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    assert_eq(
        restored_session.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
```

Add duplicate orchestration from a fresh New Game: target bed, emit `sleep_requested` twice before the first save frame resumes, await two frames, then assert `save_calls == 1` and day `== 2`.

Add failure coverage with `SaveRepository.new("user://missing-hpa-598-flow-dir/save.json")`: after a fresh New Game sleep and two frames, assert day is 2, the pending summary remains, status is exactly `Save failed — this morning is not persisted.`, and the acknowledge button is enabled.

- [ ] **Step 6: Run persistence-flow tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_persistence_flow.gd -gexit
```

Expected: FAIL because WorldShell does not perform post-sleep persistence or guard duplicate save orchestration.

- [ ] **Step 7: Implement exactly one post-sleep write in WorldShell**

Add:

```gdscript
var _overnight_save_in_progress := false
```

Replace `_on_sleep_requested()`:

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

    var save_error := _save_repository.save(_session.state())
    if save_error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(
            &"error",
            "Save failed — this morning is not persisted.",
        )
    _overnight_save_in_progress = false
```

The gameplay transition occurs once before the write. A write failure changes UI only; it never restores or rewinds state. Direct world tests with no configured repository remain storage-free; production `AppRoot` always supplies one.

- [ ] **Step 8: Run the full integration suite and verify GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration -gexit
```

- [ ] **Step 9: Commit Task 4 and run clean verification**

```bash
git add scripts/world/world_shell.gd scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd
git commit -m "feat: autosave completed Godot mornings"
./tools/verify-clean.sh
```

---

### Task 5: Handoff Documentation, Full Verification, and macOS Close/Reopen Acceptance

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `AGENTS.md`
- Verify only: `export_presets.cfg`

**Interfaces:**
- No new runtime interface.
- Documentation must identify HPA-597 as the next delivery slice after HPA-598.

- [ ] **Step 1: Update README with the player-visible persistence contract**

Integrate this behavior into the existing run/gameplay sections:

```text
Phoenix now opens on a title screen. New Game always starts a fresh run.
Continue is enabled only when user://phoenix-save.json contains a valid current
schema-v1 save. Sleeping successfully advances the day first, then writes that
completed next-morning state. The pending morning summary is restored on
Continue. Player position is not saved; Continue starts at the authored spawn.
If loading or saving fails, New Game/play remains available and a completed day
is never rolled back.
```

- [ ] **Step 2: Update CLAUDE.md architecture/handoff rules**

Add:

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

Keep `AGENTS.md -> CLAUDE.md` unchanged.

- [ ] **Step 3: Commit docs, then run complete clean/static verification**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document Godot persistence handoff"
./tools/verify-clean.sh
git diff --check main...HEAD
test -L AGENTS.md
test "$(readlink AGENTS.md)" = "CLAUDE.md"
git status --short
```

- [ ] **Step 4: Perform the required macOS exported-build close/reopen acceptance**

With Godot 4.7.1 export templates installed:

```bash
rm -rf /tmp/Phoenix-HPA-598.app
godot --headless --path . --export-debug "macOS" /tmp/Phoenix-HPA-598.app
open /tmp/Phoenix-HPA-598.app
```

Verify: title appears; New Game works; one successful sleep reaches `Saved.`; quit/reopen; Continue is enabled; the saved day/state and pending summary return; the player is at the authored spawn; acknowledge the summary and perform a normal action. Record the result in this PR description. Do not add desktop WebDriver or a CI export matrix.

- [ ] **Step 5: Final single-PR scope review**

```bash
git diff --stat main...HEAD
git diff --name-only main...HEAD
./tools/verify-clean.sh
git diff --check main...HEAD
```

The implementation diff may contain the two planning documents plus only the HPA-598 runtime/tests/docs above. Reject save migration/backward-compatibility code, generic storage interfaces, autoload managers, tutorial/finale behavior, unrelated refactors, or a second-PR delivery split.

## Plan self-review

- **Spec coverage:** Tasks 1–4 cover canonical mutable state, structural schema parsing, current-rule compatibility, FileAccess storage, title flow, fixed-spawn Continue, post-sleep one-write autosave, duplicate-input protection, save status/failure semantics, and automated round-trip acceptance. Task 5 covers docs, clean verification, and exported macOS close/reopen acceptance.
- **Command-driven acceptance:** The primary persistence fixture grows two real Turnips across three nights, harvests both, gifts one, ships one, and then exercises the production overnight save. No direct state mutation substitutes for that round trip.
- **Repo seam check:** Spawn assertions use `PlayerController.global_position` plus `WorldMath.world_to_grid()` because there is no invented logical-position property. Tests use production signals and `world.get("_session")`, not production `*_for_test` APIs.
- **Typed fixture check:** Typed arrays are used at typed helper boundaries, matching existing HPA-594 conventions.
- **Scope:** One ticket, one branch, one PR. No migration, backup, security hardening, storage abstraction, or HPA-597/HPA-599 implementation is included.
- **Type/interface consistency:** `GameSession.state()/state_error()/restore_state()`, `SaveFileCodec.encode()/decode()`, `SaveRepository.load()/save()`, `AppRoot.configure()`, `WorldShell.configure()`, and `GameHud.set_save_status()` are defined once and consumed consistently.
- **Placeholder scan:** No TBD/TODO/implementation-later placeholders remain; every task names exact files, commands, interfaces, and expected outcomes.
