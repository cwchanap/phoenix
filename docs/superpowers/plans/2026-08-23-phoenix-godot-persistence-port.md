# Phoenix Godot Persistence Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-slot Godot persistence so Phoenix starts at a title screen, saves the completed next-morning gameplay state after successful sleep, and can Continue that state at the authored player spawn.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority and single persisted-state validator. `SaveFileCodec` is semantic-field-blind: it owns only schema-v1 JSON transport plus reversible `Vector2i` conversion, while `GameSession.state_error()/restore_state()` validate and canonicalize decoded state. `AppRoot` owns title/load/launch lifecycle; `WorldShell` remains the only live session holder and performs one synchronous post-sleep write. No autoload, storage interface, migration layer, compatibility path, async saving state, or second production adapter is introduced.

**Tech Stack:** Godot 4.7.1 standard non-.NET build, statically typed GDScript, Godot `JSON`, `FileAccess`/`DirAccess`, existing GUT 9.7.1 flow, existing macOS export preset.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-persistence-port-design.md`

## Global Constraints

- Deliver HPA-598 in this single PR on `agent/hpa-598-godot-persistence-plan`.
- Persist one schema-v1 JSON document at `user://phoenix-save.json` only after `GameSession.sleep()` returns `GameRules.CommandCode.DAY_ADVANCED`.
- Do not migrate/read/emulate the old TypeScript/localStorage/Tauri Store save.
- Do not persist player position, facing, target, camera, HUD/dialogue state, or focus; every launch uses `WorldContract.PLAYER_SPAWN`.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Keep `GameHud.has_blocking_modal()` as the single world-input gate.
- Use one concrete `SaveRepository`; no interface, autoload `SaveManager`, second adapter, backup, retry queue, encryption, compression, or cloud storage.
- Continue is disabled for missing, malformed, unsupported, or current-rule-incompatible saves while New Game remains usable.
- New Game does not delete/repair the slot.
- Save failure is visible and never rewinds a completed day transition.
- Saving is synchronous: no `await`, `Saving…`, `_overnight_save_in_progress`, or temporary Acknowledge disabling.
- HPA-597 owns tutorial/finale state.
- Keep `AGENTS.md -> CLAUDE.md` unchanged.
- Do not add production methods whose only purpose is testing.
- Primary persistence acceptance is command-driven: grow two real Turnips, harvest both, gift one, ship one, then sleep/save.
- Direct `world.tscn` tests keep `_save_repository == null` and remain save-free.
- Match the existing test accessor convention: use `world._session`, not `world.get("_session")`.
- `tools/verify-clean.sh` validates committed `HEAD`; use raw GUT commands during worktree RED/GREEN and the clean verifier after commits.

## Live Contract Lock

Do not rename these existing APIs while implementing HPA-598:

```text
GameSession.snapshot()
GameSession.sleep(target_cell)
GameSession.acknowledge_morning_summary()
GameSession._farm_snapshot()
GameRules.CommandCode
GameRules.CROP_KEYS / ACTION_KEYS / WEATHER_KEYS
VillagerRules.VILLAGER_KEYS
WorldShell._on_sleep_requested()
GameHud._build_summary_panel()
GameHud.has_blocking_modal()
PlayerController.current_target_cell()
WorldMath.grid_to_world() / world_to_grid()
HudRoot/MorningSummaryPanel/Acknowledge
```

New names introduced by this plan are exactly:

```text
GameSession.state()
GameSession.state_error()
GameSession.restore_state()
SaveFileCodec
SaveRepository
AppRoot
TitleScreen
WorldShell.configure()
GameHud.set_save_status()
```

## Local RED/GREEN Setup

Provision the same ignored GUT 9.7.1 used by `tools/verify-clean.sh`:

```bash
rm -rf addons/gut /tmp/phoenix-gut.tgz
mkdir -p addons/gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o /tmp/phoenix-gut.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut.tgz" | shasum -a 256 -c -
tar -xzf /tmp/phoenix-gut.tgz --strip-components=3 -C addons/gut "Gut-9.7.1/addons/gut"
godot --headless --path . --editor --quit
```

---

### Task 1: Canonical GameSession State, Total Validation, and Restore

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `GameSession.state() -> Dictionary`
- Produces: `GameSession.state_error(candidate: Variant) -> String`; `""` means valid
- Produces: `GameSession.restore_state(candidate: Dictionary) -> bool`
- Preserves: `GameSession.snapshot() -> Dictionary`
- Reuses: `_farm_snapshot()`, `GameRules.*_KEYS`, `VillagerRules.VILLAGER_KEYS`

- [ ] **Step 1: Write failing canonical state/deep-clone test**

Add beside the existing snapshot tests:

```gdscript
func test_state_is_deeply_isolated_and_excludes_derived_fields() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var harvested: Array[int] = [1, 0, 0]
    _seed_harvested(session, harvested)
    var june := VillagerRules.VillagerId.RESIDENT
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

- [ ] **Step 2: Run GameSession tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
```

Expected: FAIL because `state()` does not exist.

- [ ] **Step 3: Implement `state()` by extending the existing snapshot seam**

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
    return result

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

Delete `_relationships_snapshot()` after its caller is gone. Keep `_farm_snapshot()`; do not introduce `_farm_state()`.

- [ ] **Step 4: Write failing total-validation and restore/alias tests**

Pin total behavior first:

```gdscript
func test_state_error_returns_messages_for_missing_and_wrong_typed_fields() -> void:
    assert_ne(GameSession.state_error({}), "")

    var bad_day := GameSession.new().state()
    bad_day["day"] = "two"
    assert_ne(GameSession.state_error(bad_day), "")

    var bad_counts := GameSession.new().state()
    bad_counts["seeds"] = []
    assert_ne(GameSession.state_error(bad_counts), "")

    var bad_farm := GameSession.new().state()
    bad_farm["farm"] = "farm"
    assert_ne(GameSession.state_error(bad_farm), "")
```

Then prove restored farm commandability and no aliasing:

```gdscript
func test_command_driven_state_restores_farm_and_does_not_alias_candidate() -> void:
    var original := GameSession.new(func() -> float: return 0.9)
    var cell := Vector2i(2, 7)
    assert_eq(original.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(original.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(original.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(original.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var saved := original.state()
    var saved_before_command := saved.duplicate(true)
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_eq(GameSession.state_error(saved), "")
    assert_true(restored.restore_state(saved))
    assert_eq(restored.state(), saved)

    assert_eq(
        restored.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    assert_eq(restored.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_true(restored.state()["farm"][0]["crop"]["watered_today"])
    assert_eq(saved, saved_before_command)
    assert_false(saved["farm"][0]["crop"]["watered_today"])
```

Add focused rejection cases by cloning valid `state()` values, first asserting the unmodified clone passes validation:

- day > `GameRules.MAX_DAY`;
- day < 1;
- time > `GameRules.ACTION_CUTOFF_MINUTES`;
- time < `GameRules.DAY_START_MINUTES`;
- stamina > `GameRules.MAX_STAMINA`;
- stamina < 0;
- negative money and crop counts;
- negative relationship points;
- unknown selected crop/action/weather;
- missing/extra crop count key;
- farm count/order/cell mismatch;
- crop on untilled soil;
- crop growth > `GameRules.growth_nights(kind)`;
- missing/extra relationship record and wrong boolean field;
- inconsistent pending summary `next_day`, `next_weather`, `money_after_shipping`;
- unknown/negative shipment line values.

Each case calls only `GameSession.state_error()` and expects a non-empty string; malformed input must not raise.

- [ ] **Step 5: Run GameSession tests and verify RED**

Run the Step 2 command again. Expected: FAIL because `state_error()` / `restore_state()` do not exist.

- [ ] **Step 6: Implement total shape/current-rule helpers and validator**

Use helpers that return `{ "ok": true, "value": ... }` or `{ "ok": false, "error": ... }` rather than indexing/casting before validation:

```gdscript
static func _field(map: Dictionary, key: String, label: String) -> Dictionary:
    if not map.has(key):
        return {"ok": false, "error": "%s is missing" % label}
    return {"ok": true, "value": map[key]}

static func _dictionary(value: Variant, label: String) -> Dictionary:
    if not (value is Dictionary):
        return {"ok": false, "error": "%s must be a Dictionary" % label}
    return {"ok": true, "value": value}

static func _array(value: Variant, label: String) -> Dictionary:
    if not (value is Array):
        return {"ok": false, "error": "%s must be an Array" % label}
    return {"ok": true, "value": value}

static func _whole_int(value: Variant, label: String) -> Dictionary:
    if not (value is int or value is float):
        return {"ok": false, "error": "%s must be an integer" % label}
    var number := float(value)
    if not is_finite(number) or number != floor(number):
        return {"ok": false, "error": "%s must be an integer" % label}
    return {"ok": true, "value": int(number)}

static func _named(value: Variant, allowed: Array[StringName], label: String) -> Dictionary:
    if not (value is String or value is StringName):
        return {"ok": false, "error": "%s must be a name" % label}
    var key := StringName(value)
    if allowed.find(key) < 0:
        return {"ok": false, "error": "%s is unknown" % label}
    return {"ok": true, "value": key}

static func _named_dictionary_value(map: Dictionary, key: StringName, label: String) -> Dictionary:
    if map.has(key):
        return {"ok": true, "value": map[key]}
    var string_key := String(key)
    if map.has(string_key):
        return {"ok": true, "value": map[string_key]}
    return {"ok": false, "error": "%s is missing" % label}
```

`state_error()` must use these helpers before every range/shape check. It accepts both direct runtime state (`StringName` keys/values) and JSON-decoded state (`String` keys/values), but all membership checks use the existing `GameRules.*_KEYS` / `VillagerRules.VILLAGER_KEYS` arrays.

Keep the validator split only into focused private helpers:

```gdscript
static func _counts_state_error(value: Dictionary) -> String
static func _farm_state_error(value: Array) -> String
static func _relationship_state_error(value: Dictionary) -> String
static func _morning_summary_state_error(value: Variant, state: Dictionary) -> String
```

Each helper performs the exact rejection cases listed in Step 4. There is no second validator in `SaveFileCodec`.

- [ ] **Step 7: Implement canonical restore**

```gdscript
func restore_state(candidate: Dictionary) -> bool:
    if state_error(candidate) != "":
        return false

    _day = int(candidate["day"])
    _time_minutes = int(candidate["time_minutes"])
    _stamina = int(candidate["stamina"])
    _weather = GameRules.WEATHER_KEYS.find(StringName(candidate["weather"]))
    _selected_action = GameRules.ACTION_KEYS.find(StringName(candidate["selected_action"]))
    _selected_seed = GameRules.CROP_KEYS.find(StringName(candidate["selected_seed"]))
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

`_counts_array`, `_farm_array`, and `_relationship_array` construct new typed/internal containers. They retrieve JSON string keys through the same String/StringName-aware helper. Never retain a candidate Array/Dictionary by reference.

- [ ] **Step 8: Run Task 1 tests, commit, and clean-verify**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
git add scripts/game/game_session.gd tests/unit/test_game_session.gd scripts/game/*.gd.uid
git commit -m "feat: add restorable Godot gameplay state"
./tools/verify-clean.sh
```

Expected: GameSession tests pass and clean verification exits 0.

---

### Task 2: JSON Transport Codec and Concrete FileAccess Repository

**Files:**
- Create: `scripts/persistence/save_file.gd`
- Create: `scripts/persistence/save_repository.gd`
- Create: `tests/unit/test_save_file.gd`
- Create: `tests/integration/test_save_repository.gd`

**Interfaces:**
- Consumes: `GameSession.state()`
- Produces: `SaveFileCodec.encode(state: Dictionary) -> String`
- Produces: `SaveFileCodec.decode(text: String) -> Dictionary`
- Produces: `SaveRepository.new(path: String = SaveRepository.DEFAULT_PATH)`
- Produces: `SaveRepository.load() -> Dictionary`
- Produces: `SaveRepository.save(state: Dictionary) -> Error`

- [ ] **Step 0: Probe raw Godot JSON Variant fidelity before codec code**

Create an uncommitted `/tmp/hpa598_json_probe.gd`:

```gdscript
extends SceneTree

func _init() -> void:
    var state := GameSession.new(func() -> float: return 0.9).state()
    var text := JSON.stringify(state)
    var parsed: Variant = JSON.parse_string(text)
    print("weather original/parsed: ", typeof(state["weather"]), " / ", typeof(parsed["weather"]))
    print("farm original/parsed: ", typeof(state["farm"]), " / ", typeof(parsed["farm"]))
    print("cell original/parsed: ", typeof(state["farm"][0]["cell"]), " / ", typeof(parsed["farm"][0]["cell"]))
    print("seed keys original: ", state["seeds"].keys())
    print("seed keys parsed: ", parsed["seeds"].keys())
    quit()
```

Run:

```bash
godot --headless --path . --script /tmp/hpa598_json_probe.gd
```

Record the output in the implementation notes/commit message. Do not commit the probe. The implementation below does not depend on raw JSON preserving `StringName`, `Vector2i`, or typed-array identity.

- [ ] **Step 1: Write failing codec tests**

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

func test_codec_round_trip_restores_canonical_state() -> void:
    var original := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])
    assert_eq(GameSession.state_error(decoded["state"]), "")
    assert_true(decoded["state"]["farm"][0]["cell"] is Vector2i)

    # Raw decoded JSON keeps ordinary identifiers as String/untyped containers.
    assert_true(decoded["state"]["weather"] is String)
    assert_true(decoded["state"]["seeds"].keys()[0] is String)
    assert_true(decoded["state"]["farm"] is Array)

    # GameSession is the canonicalizer back to runtime state.
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(decoded["state"]))
    assert_eq(restored.state(), original)
    assert_true(restored.state()["weather"] is StringName)
    assert_true(restored.state()["seeds"].keys()[0] is StringName)

func test_decode_rejects_malformed_json_wrong_schema_and_bad_vector_marker() -> void:
    assert_false(SaveFileCodec.decode("{broken")["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":"1","state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":1.5,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":2,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":1,"state":5}')["ok"])
    assert_false(SaveFileCodec.decode(
        '{"schema_version":1,"state":{"__phoenix_type":"Vector2i","x":1}}'
    )["ok"])
```

Add a deep-isolation test: mutate `decoded["state"]`, then assert the original runtime state is unchanged.

- [ ] **Step 2: Run codec tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd -gexit
```

Expected: FAIL because `SaveFileCodec` does not exist.

- [ ] **Step 3: Implement semantic-field-blind transport codec**

Create `scripts/persistence/save_file.gd`:

```gdscript
class_name SaveFileCodec
extends RefCounted

const SCHEMA_VERSION := 1
const TYPE_MARKER := "__phoenix_type"
const VECTOR2I_MARKER := "Vector2i"

static func encode(state: Dictionary) -> String:
    return JSON.stringify({
        "schema_version": SCHEMA_VERSION,
        "state": _encode_variant(state),
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
    if not (parser.data is Dictionary):
        return {"ok": false, "error": "Save envelope must be an object"}
    var envelope: Dictionary = parser.data
    if not envelope.has("schema_version"):
        return {"ok": false, "error": "Save schema version is missing"}
    if not (envelope["schema_version"] is int or envelope["schema_version"] is float):
        return {"ok": false, "error": "Save schema version must be numeric"}
    var schema_number := float(envelope["schema_version"])
    if not is_finite(schema_number) or schema_number != floor(schema_number):
        return {"ok": false, "error": "Save schema version must be an integer"}
    if int(schema_number) != SCHEMA_VERSION:
        return {"ok": false, "error": "Unsupported save schema"}
    if not envelope.has("state"):
        return {"ok": false, "error": "Save state is missing"}
    var decoded := _decode_variant(envelope["state"])
    if not decoded["ok"]:
        return decoded
    if not (decoded["value"] is Dictionary):
        return {"ok": false, "error": "Save state must be an object"}
    return {"ok": true, "state": decoded["value"]}
```

Recursive encode rules:

```gdscript
static func _encode_variant(value: Variant) -> Variant:
    if value is Vector2i:
        return {
            TYPE_MARKER: VECTOR2I_MARKER,
            "x": value.x,
            "y": value.y,
        }
    if value is StringName:
        return String(value)
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value.keys():
            result[String(key)] = _encode_variant(value[key])
        return result
    if value is Array:
        var result: Array = []
        for entry in value:
            result.append(_encode_variant(entry))
        return result
    return value
```

Recursive decode rules:

- Dictionaries with `TYPE_MARKER == VECTOR2I_MARKER` must contain exactly whole numeric `x`/`y` values and decode to `Vector2i`.
- Other Dictionaries recursively decode values and keep JSON string keys as `String`.
- Arrays recursively decode to ordinary `Array`.
- Strings remain `String`.
- Scalars/null pass through.
- A dictionary that contains `TYPE_MARKER` with an unknown marker fails instead of being treated as gameplay data.

Do not import `GameRules` or `VillagerRules` in this file. Do not define crop/action/weather/villager tables. Content validation and canonical runtime `StringName`/typed-container reconstruction belong only to `GameSession.state_error()/restore_state()`.

- [ ] **Step 4: Run codec tests and verify GREEN**

Run the Step 2 command again. Expected: PASS.

- [ ] **Step 5: Write failing repository tests**

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

func test_missing_then_save_replace_load_and_restore() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    assert_eq(repository.load()["status"], &"missing")

    var first := GameSession.new(func() -> float: return 0.9).state()
    assert_eq(repository.save(first), OK)
    var first_loaded := repository.load()
    assert_eq(first_loaded["status"], &"loaded")
    assert_eq(GameSession.state_error(first_loaded["state"]), "")

    var second_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(second_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var second := second_session.state()
    assert_eq(repository.save(second), OK)
    var second_loaded := repository.load()
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(second_loaded["state"]))
    assert_eq(restored.state(), second)

func test_malformed_file_is_invalid_not_a_crash() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    assert_not_null(file)
    file.store_string("{broken")
    file.close()
    var result := SaveRepository.new(TEST_PATH).load()
    assert_eq(result["status"], &"invalid")
    assert_ne(String(result["error"]), "")

func test_nonexistent_parent_directory_returns_write_error() -> void:
    var repository := SaveRepository.new(
        "user://missing-hpa-598-dir-%d/save.json" % randi()
    )
    assert_ne(repository.save(GameSession.new().state()), OK)
```

- [ ] **Step 6: Implement concrete FileAccess repository**

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
    var temp_path := _path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(SaveFileCodec.encode(state))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        return write_error
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(_path),
    )
```

No delete/backup/temp/retry/alternate-adapter methods.

- [ ] **Step 7: Run Task 2 tests, commit, and clean-verify**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd,res://tests/integration/test_save_repository.gd -gexit
git add scripts/persistence tests/unit/test_save_file.gd tests/integration/test_save_repository.gd
git commit -m "feat: add one-slot Godot save storage"
./tools/verify-clean.sh
```

Expected: both new test files pass and clean verification exits 0.

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
- Direct `world.tscn` construction still works without calling `configure()`.

- [ ] **Step 1: Write failing app/title tests through production signals**

Create `tests/integration/test_app_launch.gd` with isolated test paths and `_spawn_app(repository)` helper.

Valid Continue case:

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
    assert_eq(world._session.state(), saved_state)
    assert_true(
        WorldMath.world_to_grid(world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )
```

Incompatible-slot guard + New Game recovery:

```gdscript
func test_incompatible_slot_refuses_continue_but_new_game_still_launches() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var incompatible := GameSession.new(func() -> float: return 0.9).state()
    incompatible["day"] = GameRules.MAX_DAY + 1
    assert_eq(repository.save(incompatible), OK)

    var app := _spawn_app(repository)
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    var status := title.get_node("Panel/Status") as Label
    assert_true(continue_button.disabled)
    assert_ne(status.text, "")

    # Bypass the disabled Button and prove AppRoot itself refuses the launch.
    title.continue_requested.emit()
    await get_tree().process_frame
    assert_null(app.get_node_or_null("World"))

    title.new_game_requested.emit()
    await get_tree().process_frame
    var world := app.get_node("World") as WorldShell
    assert_eq(world._session.state()["day"], 1)

    var still_incompatible := repository.load()
    assert_eq(still_incompatible["status"], &"loaded")
    assert_ne(GameSession.state_error(still_incompatible["state"]), "")
```

Also cover:

- missing save: Continue disabled; emit `continue_requested`; no `World` appears;
- malformed file: Continue disabled with status; emit `continue_requested`; no `World` appears;
- valid existing slot + New Game: fresh Day 1 and the existing slot remains unchanged.

- [ ] **Step 2: Run app tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd -gexit
```

- [ ] **Step 3: Author presentation-only TitleScreen**

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

Author `scenes/ui/title_screen.tscn` as a full-viewport `Control` with `Panel/Title`, `Panel/NewGame`, `Panel/Continue`, and `Panel/Status`.

- [ ] **Step 4: Make WorldShell configurable with release-safe restore**

Replace eager session construction with:

```gdscript
var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository = null

func configure(initial_state: Variant, repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository
```

At the start of `_ready()`:

```gdscript
_session = GameSession.new()
if _initial_state != null and not _session.restore_state(_initial_state):
    push_error("AppRoot supplied invalid restored state")
    _session = GameSession.new()
```

Do **not** write `assert(_session.restore_state(...))`. Release exports do not evaluate assert expressions, so restore must be a normal statement/branch. Pure `assert(not is_inside_tree())` checks may remain assertions.

Direct `world.tscn` tests do not call `configure()` and remain repository-null/save-free.

- [ ] **Step 5: Implement AppRoot load/launch ownership**

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
    if get_node_or_null("World") != null:
        return
    var world := WORLD_SCENE.instantiate() as WorldShell
    world.name = "World"
    world.configure(initial_state, _save_repository)
    add_child(world)
    _title_screen.visible = false
```

Create `scenes/app/app.tscn` with root `AppRoot` and child `TitleScreen`.

- [ ] **Step 6: Switch/pin main scene and run tests**

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

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_app_launch.gd,res://tests/integration/test_gameplay_shell.gd -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: app tests and existing world/headless tests pass; direct world tests remain repository-free.

- [ ] **Step 7: Commit Task 3 and clean-verify**

```bash
git add scripts/app scenes/app scripts/ui/title_screen.gd scenes/ui/title_screen.tscn \
  scripts/world/world_shell.gd project.godot tests/integration/test_app_launch.gd \
  tests/headless/project_smoke.gd
git commit -m "feat: add Godot new game and continue launch"
./tools/verify-clean.sh
```

---

### Task 4: Synchronous Post-Sleep Autosave, Status, and Command-Driven Acceptance

**Files:**
- Modify: `scripts/world/world_shell.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Create: `tests/integration/test_persistence_flow.gd`

**Interfaces:**
- Consumes: configured `SaveRepository`
- Produces: `GameHud.set_save_status(status: StringName, message: String = "") -> void`
- Preserves: `GameHud.has_blocking_modal()`
- Preserves: `GameSession.sleep()` as the complete synchronous gameplay transaction

- [ ] **Step 1: Write failing HUD status test**

Extend the existing gameplay-shell test using the real summary node path:

```gdscript
func test_morning_summary_save_status_shows_saved_error_and_clears() -> void:
    var world := _world()
    if world == null:
        return
    var session := GameSession.new(func() -> float: return 0.9)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    world.hud.render(session.snapshot())

    var status := world.hud.get_node(
        "HudRoot/MorningSummaryPanel/SaveStatus"
    ) as Label

    world.hud.set_save_status(&"saved")
    assert_eq(status.text, "Saved.")

    world.hud.set_save_status(&"error", "Save failed — this morning is not persisted.")
    assert_eq(status.text, "Save failed — this morning is not persisted.")

    world.hud.set_save_status(&"idle")
    assert_eq(status.text, "")
```

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit
```

Expected: FAIL because `SaveStatus` / `set_save_status()` do not exist.

- [ ] **Step 2: Add minimal save status to existing summary panel**

Add one field:

```gdscript
var _save_status_label: Label
```

In `_build_summary_panel()` add a `SaveStatus` label without renaming `MorningSummaryPanel` or `Acknowledge`.

Implement only three states:

```gdscript
func set_save_status(status: StringName, message: String = "") -> void:
    match status:
        &"idle":
            _save_status_label.text = ""
        &"saved":
            _save_status_label.text = "Saved."
        &"error":
            _save_status_label.text = message
        _:
            assert(false, "unknown save status")
```

When `_set_morning_summary_visible(false)` closes the summary, call `set_save_status(&"idle")`.

Do not add `saving`, disable Acknowledge, or add another input gate.

- [ ] **Step 3: Build the acceptance state entirely through real commands**

Create `tests/integration/test_persistence_flow.gd` with a concrete counting repository subclass and isolated test path:

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

Do not extract a shared cross-test farming fixture in HPA-598. The existing unit helper grows one crop; this integration fixture needs two crops plus social/shipping state, so a new support abstraction saves little and creates another dependency.

Target the bed through existing world APIs:

```gdscript
func _target_bed(world: WorldShell) -> void:
    world.player.global_position = WorldMath.grid_to_world(Vector2(5.5, 7.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.BED_CELL)
```

- [ ] **Step 4: Write failing one-write/Continue/failure acceptance**

```gdscript
func test_sleep_writes_once_and_continue_restores_complete_morning() -> void:
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
    assert_eq(world._session.state(), prepared)
    _target_bed(world)

    # Synchronous handler: the second signal sees the pending summary and cannot save again.
    world.hud.sleep_requested.emit()
    world.hud.sleep_requested.emit()

    assert_eq(repository.save_calls, 1)
    var saved_result := repository.load()
    assert_eq(saved_result["status"], &"loaded")
    var saved_state: Dictionary = saved_result["state"]
    assert_eq(GameSession.state_error(saved_state), "")
    assert_eq(int(saved_state["day"]), int(prepared["day"]) + 1)

    var canonical_saved := GameSession.new(func() -> float: return 0.9)
    assert_true(canonical_saved.restore_state(saved_state))
    assert_eq(canonical_saved.state(), world._session.state())
    assert_eq(canonical_saved.state()["pending_shipment"][&"turnip"], 0)
    assert_true(int(canonical_saved.state()["money"]) > int(prepared["money"]))
    assert_false(canonical_saved.state()["relationships"][&"resident"]["talked_today"])
    assert_false(canonical_saved.state()["relationships"][&"resident"]["gifted_today"])
    assert_not_null(canonical_saved.state()["pending_morning_summary"])

    app.queue_free()
    await get_tree().process_frame

    var restored_app := APP_SCENE.instantiate() as AppRoot
    restored_app.configure(repository)
    add_child_autoqfree(restored_app)
    var restored_title := restored_app.get_node("TitleScreen") as TitleScreen
    restored_title.continue_requested.emit()
    await get_tree().process_frame

    var restored_world := restored_app.get_node("World") as WorldShell
    assert_eq(restored_world._session.state(), canonical_saved.state())
    assert_true(
        WorldMath.world_to_grid(restored_world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )
```

Add write-failure coverage using `SaveRepository.new("user://missing-hpa-598-flow-dir/save.json")`: after New Game sleep, assert day is 2, the pending morning summary remains, and `SaveStatus` equals `Save failed — this morning is not persisted.`.

- [ ] **Step 5: Run persistence-flow tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_persistence_flow.gd -gexit
```

Expected: FAIL because WorldShell does not persist post-sleep state or render save status.

- [ ] **Step 6: Extend the live `_on_sleep_requested()` synchronously**

Replace only the current orchestration:

```gdscript
func _on_sleep_requested() -> void:
    var target: Variant = player.current_target_cell()
    var code := _session.sleep(target)
    if code != GameRules.CommandCode.DAY_ADVANCED or _save_repository == null:
        _finish_command(code)
        return

    hud.show_feedback(code)
    _refresh_from_session()

    var save_error := _save_repository.save(_session.state())
    if save_error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(
            &"error",
            "Save failed — this morning is not persisted.",
        )
```

There is no await or explicit reentrancy guard. `sleep()` rejects a second request with `DAY_SUMMARY_PENDING`, and the first `_refresh_from_session()` closes the sleep panel before the handler returns.

- [ ] **Step 7: Run full integration, commit, and clean-verify**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration -gexit
git add scripts/world/world_shell.gd scripts/ui/game_hud.gd \
  tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd
git commit -m "feat: autosave completed Godot mornings"
./tools/verify-clean.sh
```

---

### Task 5: Handoff Documentation, Full Verification, and Release macOS Close/Reopen Acceptance

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Verify only: `AGENTS.md`
- Verify only: `export_presets.cfg`

**Interfaces:**
- No new runtime interface.
- Documentation identifies HPA-597 as the next delivery slice.

- [ ] **Step 1: Update README player contract**

Document exactly:

```text
Phoenix opens on a title screen. New Game starts a fresh run without deleting
the current slot. Continue is enabled only for a schema-v1 save accepted by
current GameSession rules at user://phoenix-save.json. Successful sleep
advances gameplay first, then synchronously writes the completed next-morning
state and pending morning summary. Continue restores gameplay at the authored
spawn. Invalid/incompatible loads and save failures never block New Game or
roll back an already completed day.
```

- [ ] **Step 2: Update CLAUDE.md architecture/handoff**

Add the new boundaries with exact symbols:

```text
- scripts/app/app_root.gd owns title/load/launch lifecycle and one concrete SaveRepository.
- scripts/persistence/save_file.gd owns schema-v1 JSON transport only; it does not validate gameplay content.
- scripts/persistence/save_repository.gd writes user://phoenix-save.json with FileAccess.
- GameSession.state()/state_error()/restore_state() own mutable-state export, all persisted-state validation, and canonical restore; snapshot() remains the view read model.
- WorldShell remains the only live production session holder and synchronously writes once after successful overnight advancement.
- Player position/facing/camera/UI state remain transient/authored.
- HPA-597 is the next delivery slice.
```

Keep `AGENTS.md -> CLAUDE.md` unchanged.

- [ ] **Step 3: Commit docs and run complete clean/static verification**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document Godot persistence handoff"
./tools/verify-clean.sh
git diff --check main...HEAD
test -L AGENTS.md
test "$(readlink AGENTS.md)" = "CLAUDE.md"
git status --short
```

Expected: verifier exits 0, diff check is clean, symlink target is unchanged, worktree is clean.

- [ ] **Step 4: Perform required RELEASE exported-build close/reopen acceptance**

Godot assertions are ignored in non-debug exports, so this acceptance must use the release template:

```bash
rm -rf /tmp/Phoenix-HPA-598.app
godot --headless --path . --export-release "macOS" /tmp/Phoenix-HPA-598.app
open /tmp/Phoenix-HPA-598.app
```

Verify manually:

1. title appears;
2. New Game works;
3. one successful sleep reaches `Saved.`;
4. quit/reopen the release app;
5. Continue is enabled;
6. saved state and pending summary return;
7. player starts at authored spawn;
8. acknowledge and perform a normal action.

Record the result in the PR description. Do not add desktop WebDriver or a CI export matrix.

- [ ] **Step 5: Final single-PR scope and symbol review**

```bash
git diff --stat main...HEAD
git diff --name-only main...HEAD
./tools/verify-clean.sh
git diff --check main...HEAD
```

Then compare the implementation against the **Live Contract Lock**. Reject migration/backward-compatibility code, save-specific content tables in the codec, generic storage interfaces, autoload managers, async-saving machinery, tutorial/finale behavior, unrelated refactors, or a second PR.

## Risks

- **Godot JSON Variant fidelity:** raw JSON does not promise preservation of `StringName`, `Vector2i`, or typed GDScript container identity. Task 2 Step 0 measures the actual runtime behavior before codec implementation. The codec/restore contract does not rely on raw preservation.
- **Release-only restore regression:** GDScript release exports do not evaluate `assert()` expressions. Restore must be a normal statement/branch, and Task 5 verifies Continue in a release export.

## Plan Self-Review

- **Spec coverage:** Tasks 1–4 cover canonical state, total validation, transport codec, FileAccess storage, title recovery, authored-spawn Continue, synchronous post-sleep save, one-write repeated-input behavior, failure status, and command-driven farming/economy/social acceptance. Task 5 covers docs, committed-HEAD verification, and release macOS acceptance.
- **Validation ownership:** `SaveFileCodec` validates only envelope/transport mechanics. `GameSession.state_error()` is the single total gameplay-state validator and uses the existing `GameRules`/`VillagerRules` key arrays.
- **Transport normalization:** tagged `Vector2i` is reconstructed by the codec; JSON strings/keys remain Strings and are canonicalized by `GameSession.restore_state()` into runtime StringName-keyed/typed state.
- **Restore proof:** Task 1 executes `water()` against a restored crop and proves live mutation without aliasing the candidate.
- **Recovery proof:** Task 3 emits `continue_requested` against missing/malformed/incompatible slots and proves AppRoot itself refuses launch before testing New Game recovery.
- **Release safety:** `restore_state()` is never called only inside `assert()`, and Task 5 uses `--export-release`.
- **Autosave simplicity:** no `await`, `Saving…`, reentrancy flag, or temporary input gate. Existing `DAY_SUMMARY_PENDING` semantics prevent a second transition; Task 4 folds a two-signal/one-write assertion into the main acceptance.
- **World-test isolation:** direct `world.tscn` tests remain repository-null and save-free.
- **Accessor convention:** new integration tests use `world._session` directly, matching current `tests/integration/test_gameplay_shell.gd`.
- **Fixture scope:** the two-crop social/shipping acceptance stays local; no `tests/support` abstraction is added for one specialized reuse case.
- **Scope:** one ticket, one branch, one PR; no migration, backup, security hardening, storage abstraction, HPA-597, or HPA-599 implementation.
- **Verification meaning:** this planning self-review checks document consistency only. Future implementation must produce the GUT/clean-verifier/release-export evidence listed in Tasks 1–5.
- **Placeholder scan:** no TBD/TODO/implementation-later placeholders remain.
