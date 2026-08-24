# Phoenix Godot Persistence Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-slot Godot persistence so Phoenix starts at a title screen, autosaves the completed next-morning gameplay state after successful sleep, and can Continue that state at the authored player spawn.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority, extend its existing `snapshot()` clone seam with one canonical `state()` projection and restore validation, and put JSON/FileAccess concerns in two small persistence files. `AppRoot` owns title/load/launch lifecycle; `WorldShell` remains the only live session holder and performs the one post-sleep write. No autoload, storage interface, migration layer, compatibility path, or second production adapter is introduced.

**Tech Stack:** Godot 4.7.1 standard non-.NET build, statically typed GDScript, Godot `JSON`, `FileAccess`/`DirAccess`, existing GUT 9.7.1 test flow, existing macOS export preset.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-persistence-port-design.md`

## Global Constraints

- Deliver HPA-598 in this single PR; implementation continues on `agent/hpa-598-godot-persistence-plan` after planning review.
- Persist one schema-v1 JSON document at `user://phoenix-save.json` only after `GameSession.sleep()` returns `GameRules.CommandCode.DAY_ADVANCED`.
- Do not migrate/read/emulate the old TypeScript/localStorage/Tauri Store save.
- Do not persist arbitrary player position, facing, target, camera, HUD/dialogue state, or focus state; every launch uses `WorldContract.PLAYER_SPAWN`.
- Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the only live production session holder.
- Keep `GameHud.has_blocking_modal()` as the single world-input gate.
- Use one concrete FileAccess-backed `SaveRepository`; no repository interface, autoload `SaveManager`, second adapter, backup, retry queue, encryption, compression, or cloud storage.
- Continue is disabled for missing, malformed, unsupported, or current-rule-incompatible saves while New Game remains usable.
- New Game does not delete the slot.
- Save failure is visible and never rewinds a completed day transition.
- HPA-597 owns tutorial/finale state.
- Keep `AGENTS.md -> CLAUDE.md` unchanged.
- Do not add production methods whose only purpose is testing. Integration tests may inspect the existing private-by-convention `_session` through `world.get("_session")`.
- Primary persistence acceptance is command-driven: grow two real Turnips, harvest both, gift one, ship one, then sleep/save.
- Direct `world.tscn` tests keep `_save_repository == null` and remain save-free.
- Commit generated source-adjacent `.uid` files using the repository's existing Godot convention.
- `tools/verify-clean.sh` validates committed `HEAD`. Use raw GUT commands during worktree RED/GREEN, then run the clean verifier after commits.

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

Copy test setup from the existing `tests/unit/test_game_session.gd` helper style (`_plant_turnip`, typed arrays, `GameRules.CommandCode.*`) rather than inventing a parallel fixture vocabulary.

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

### Task 1: Canonical GameSession State and Restore Validation

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `GameSession.state() -> Dictionary`
- Produces: `GameSession.state_error(candidate: Variant) -> String`; `""` means valid
- Produces: `GameSession.restore_state(candidate: Dictionary) -> bool`
- Preserves: `GameSession.snapshot() -> Dictionary`
- Reuses: `_farm_snapshot()`, `GameRules.*_KEYS`, `VillagerRules.VILLAGER_KEYS`

- [ ] **Step 1: Write the failing state/deep-clone test**

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

Delete `_relationships_snapshot()` after its caller is gone. Keep `_farm_snapshot()`; do not introduce `_farm_state()`.

- [ ] **Step 4: Write failing restore, alias-isolation, and rule-rejection tests**

Use a real planted crop and a real overnight transition:

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
    assert_false(restored.state()["farm"][0]["crop"]["watered_today"])
    assert_eq(restored.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_true(restored.state()["farm"][0]["crop"]["watered_today"])

    # The live restored farm changed; the codec/session candidate did not.
    assert_eq(saved, saved_before_command)
    assert_false(saved["farm"][0]["crop"]["watered_today"])
```

Also clone one valid `state()` and reject each current-rule category without mutating a target session:

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
    bad_relationships["relationships"].erase(VillagerRules.VILLAGER_KEYS[-1])
    assert_ne(GameSession.state_error(bad_relationships), "")
```

Use `_plant_turnip()` for a crop-growth rejection and a real `sleep()` result for pending-summary consistency.

- [ ] **Step 5: Run GameSession tests and verify RED**

Run the Task 1 command again. Expected: FAIL because `state_error()` / `restore_state()` do not exist.

- [ ] **Step 6: Implement current-rule validation and deep-copy restore**

`state_error()` receives structurally parsed runtime state. It must reuse the existing key arrays:

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
    if GameRules.WEATHER_KEYS.find(value["weather"]) < 0:
        return "weather is not part of current rules"
    if GameRules.ACTION_KEYS.find(value["selected_action"]) < 0:
        return "selected action is not part of current rules"
    if GameRules.CROP_KEYS.find(value["selected_seed"]) < 0:
        return "selected seed is not part of current rules"

    var counts_error := _count_state_error(value)
    if counts_error != "":
        return counts_error
    var farm_error := _farm_state_error(value["farm"])
    if farm_error != "":
        return farm_error
    var relationship_error := _relationship_state_error(value["relationships"])
    if relationship_error != "":
        return relationship_error
    return _morning_summary_state_error(value)
```

Private validation helpers enforce non-negative counts/points, exact `WorldContract.farm_cells()` order, crop-on-tilled state, growth `0..GameRules.growth_nights(kind)`, exactly `VillagerRules.VILLAGER_KEYS`, and summary equality (`next_day`, `next_weather`, `money_after_shipping`).

Restore only after validation and construct fresh containers:

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

`_counts_array`, `_farm_array`, and `_relationship_array` create new containers and convert through the existing key arrays. Never retain an Array/Dictionary alias from `candidate`.

- [ ] **Step 7: Run Task 1 tests and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_session.gd -gexit
git add scripts/game/game_session.gd tests/unit/test_game_session.gd scripts/game/*.gd.uid
git commit -m "feat: add restorable Godot gameplay state"
./tools/verify-clean.sh
```

Expected: GameSession tests pass and clean verification exits 0.

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

func test_encode_decode_round_trip_preserves_runtime_state() -> void:
    var state := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(state))
    assert_true(decoded["ok"])
    assert_eq(decoded["state"], state)
    assert_true(decoded["state"]["farm"][0]["cell"] is Vector2i)

func test_decode_rejects_malformed_json_wrong_schema_and_unknown_closed_key() -> void:
    assert_false(SaveFileCodec.decode("{broken")["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":2,"state":{}}')["ok"])

    var state := _state_with_pending_summary()
    var encoded_variant: Dictionary = JSON.parse_string(SaveFileCodec.encode(state))
    encoded_variant["state"]["selected_seed"] = "not-a-current-crop"
    assert_false(SaveFileCodec.decode(JSON.stringify(encoded_variant))["ok"])
```

Add one fractional integer, missing relationship, wrong farm/crop nested type, and wrong summary-shipment type case by mutating an encoded valid envelope.

- [ ] **Step 2: Run codec tests and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_save_file.gd -gexit
```

Expected: FAIL because `SaveFileCodec` does not exist.

- [ ] **Step 3: Implement schema-v1 codec and reuse current closed-key tables**

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

static func _closed_key(value: Variant, allowed: Array[StringName], field: String) -> Dictionary:
    if not (value is String):
        return {"ok": false, "error": "%s must be a string" % field}
    var key := StringName(value)
    if allowed.find(key) < 0:
        return {"ok": false, "error": "%s is unknown" % field}
    return {"ok": true, "value": key}
```

All structural identifier validation must call `_closed_key()` with the existing arrays:

```gdscript
GameRules.CROP_KEYS
GameRules.ACTION_KEYS
GameRules.WEATHER_KEYS
VillagerRules.VILLAGER_KEYS
```

Do **not** define another `SAVE_CROP_KEYS`, `VALID_VILLAGERS`, string union, or hand-enumerated known-key table.

`_encode_state()` converts `Vector2i` cells to `{ "x", "y" }`, StringName values/keys to strings, and summary shipment crop keys to strings. File-local shape helpers validate Dictionary/Array/bool/string/whole finite number. The codec does not validate current day/stamina/count/growth/farm-identity ranges.

- [ ] **Step 4: Run codec tests and verify GREEN**

Run the Task 2 codec command again. Expected: PASS.

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

- [ ] **Step 6: Implement the concrete repository**

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
    var file := FileAccess.open(_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(SaveFileCodec.encode(state))
    file.flush()
    var write_error := file.get_error()
    file.close()
    return write_error
```

No delete/backup/temp/retry/alternate-adapter methods.

- [ ] **Step 7: Run Task 2 tests and commit**

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

Create `tests/integration/test_app_launch.gd` with an isolated `user://` path. Inspect real `Panel/NewGame`, `Panel/Continue`, and `Panel/Status` nodes; do not add test-only title accessors.

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
    var live_session := world.get("_session") as GameSession
    assert_eq(live_session.state(), saved_state)
    assert_true(
        WorldMath.world_to_grid(world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )
```

Add the recovery case that was previously missing:

```gdscript
func test_incompatible_slot_disables_continue_but_new_game_still_launches() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var incompatible := GameSession.new(func() -> float: return 0.9).state()
    incompatible["day"] = GameRules.MAX_DAY + 1
    assert_eq(repository.save(incompatible), OK) # structurally valid; current-rule invalid

    var app := _spawn_app(repository)
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    var status := title.get_node("Panel/Status") as Label
    assert_true(continue_button.disabled)
    assert_ne(status.text, "")

    title.new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    var live_session := world.get("_session") as GameSession
    assert_eq(live_session.state()["day"], 1)

    # New Game did not delete/repair the incompatible slot.
    assert_eq(repository.load()["state"]["day"], GameRules.MAX_DAY + 1)
```

Also cover missing save and New Game with a valid existing save.

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

Author `scenes/ui/title_screen.tscn` as a full-viewport Control with `Panel/Title`, `Panel/NewGame`, `Panel/Continue`, and `Panel/Status`.

- [ ] **Step 4: Make WorldShell configurable while preserving direct scene tests**

Replace eager `_session := GameSession.new()` with:

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
if _initial_state != null:
    assert(_session.restore_state(_initial_state), "AppRoot supplied invalid restored state")
```

Do not require direct `world.tscn` tests to call `configure()`. Null repository means no save I/O.

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

Expected: app tests, existing gameplay-shell tests, and both headless checks pass; existing world tests remain repository-free.

- [ ] **Step 7: Commit Task 3 and clean-verify**

```bash
git add scripts/app scenes/app scripts/ui/title_screen.gd scenes/ui/title_screen.tscn \
  scripts/world/world_shell.gd project.godot tests/integration/test_app_launch.gd \
  tests/headless/project_smoke.gd
git add scripts/app/*.gd.uid scripts/ui/*.gd.uid scenes/app/*.uid scenes/ui/*.uid 2>/dev/null || true
git commit -m "feat: add Godot new game and continue launch"
./tools/verify-clean.sh
```

---

### Task 4: Post-Sleep Autosave, Save Status, and Command-Driven Acceptance

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

- [ ] **Step 1: Write failing HUD save-status test**

Extend the existing `tests/integration/test_gameplay_shell.gd` using the live node path:

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

Run and verify RED:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_gameplay_shell.gd -gexit
```

- [ ] **Step 2: Add minimal status UI to the existing summary panel**

Add fields:

```gdscript
var _morning_summary_acknowledge: Button
var _save_status_label: Label
```

In `_build_summary_panel()` keep the existing `MorningSummaryPanel` and `Acknowledge` names, retain the button in `_morning_summary_acknowledge`, and add `SaveStatus`.

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

Call `set_save_status(&"idle")` when the morning summary becomes hidden. Do not add a modal/input-lock reason.

- [ ] **Step 3: Build the primary pre-save state entirely through real commands**

Create `tests/integration/test_persistence_flow.gd`:

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

Do not replace this acceptance fixture with `_seed_harvested()` or `set("_harvested_counts", ...)`.

Target the bed through the existing world APIs:

```gdscript
func _target_bed(world: WorldShell) -> void:
    world.player.global_position = WorldMath.grid_to_world(Vector2(5.5, 7.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.BED_CELL)
```

- [ ] **Step 4: Write failing one-write/Continue/failure tests**

Final production save path:

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
```

Also add:

- duplicate request: emit `sleep_requested` twice before the save frame resumes; assert `save_calls == 1` and day advances once;
- write failure with a nonexistent parent path: day still advances, pending summary remains, status is `Save failed — this morning is not persisted.`, Acknowledge is enabled after the attempt.

- [ ] **Step 5: Run persistence flow and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_persistence_flow.gd -gexit
```

Expected: FAIL because post-sleep persistence/guard do not exist.

- [ ] **Step 6: Extend the live `_on_sleep_requested()` seam**

Add:

```gdscript
var _overnight_save_in_progress := false
```

Replace only the existing `_on_sleep_requested()` orchestration:

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

The day transition happens once before I/O. A null repository keeps direct world tests save-free. Save failure changes presentation only.

- [ ] **Step 7: Run full integration and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration -gexit
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
- Documentation identifies HPA-597 as the next delivery slice.

- [ ] **Step 1: Update README player contract**

Document exactly:

```text
Phoenix opens on a title screen. New Game starts a fresh run without deleting
the current slot. Continue is enabled only for a valid current schema-v1 save
at user://phoenix-save.json. Successful sleep advances gameplay first, then
writes the completed next-morning state and pending morning summary. Continue
restores gameplay at the authored spawn. Invalid/incompatible loads and save
failures never block New Game or roll back an already completed day.
```

- [ ] **Step 2: Update CLAUDE.md architecture/handoff**

Add the new boundaries using the exact symbols:

```text
- scripts/app/app_root.gd owns title/load/launch lifecycle and one concrete SaveRepository.
- scripts/persistence/save_file.gd owns schema-v1 JSON structure/conversion and reuses GameRules/VillagerRules key arrays.
- scripts/persistence/save_repository.gd writes user://phoenix-save.json with FileAccess.
- GameSession.state()/state_error()/restore_state() own mutable-state export and current-rule compatibility; snapshot() remains the view read model.
- WorldShell remains the only live production session holder and writes once after successful overnight advancement.
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

- [ ] **Step 4: Perform required exported macOS close/reopen acceptance**

```bash
rm -rf /tmp/Phoenix-HPA-598.app
godot --headless --path . --export-debug "macOS" /tmp/Phoenix-HPA-598.app
open /tmp/Phoenix-HPA-598.app
```

Verify manually:

1. title appears;
2. New Game works;
3. one successful sleep reaches `Saved.`;
4. quit/reopen;
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

Then compare the implementation against the **Live Contract Lock** above. Reject migration/backward-compatibility code, parallel closed-key tables, generic storage interfaces, autoload managers, tutorial/finale behavior, unrelated refactors, or a second PR.

## Plan Self-Review

- **Spec coverage:** Tasks 1–4 cover state export/restore, structural codec, current-rule validation, FileAccess storage, title recovery, authored-spawn Continue, one-write autosave, duplicate-input protection, save status/failure, and the command-driven farming/economy/social round trip. Task 5 covers docs, committed-HEAD verification, and exported macOS acceptance.
- **Live vocabulary:** Existing identifiers/paths are locked at the top of this document. `_farm_snapshot()`, `GameRules.CommandCode`, `WorldMath.grid_to_world()`, `PlayerController.current_target_cell()`, and `HudRoot/MorningSummaryPanel/Acknowledge` match current `main`.
- **Closed-key reuse:** codec and restore logic consume `GameRules.CROP_KEYS`, `ACTION_KEYS`, `WEATHER_KEYS`, and `VillagerRules.VILLAGER_KEYS`; no save-specific identifier table is planned.
- **Restore proof:** Task 1 executes `water()` against a restored crop and proves both live mutation and non-aliasing of the saved candidate.
- **Recovery proof:** Task 3 launches New Game from a structurally valid but current-rule-incompatible slot and proves the slot remains untouched.
- **World-test isolation:** direct `world.tscn` tests remain repository-null and save-free.
- **Command-driven acceptance:** Task 4 grows two real Turnips, harvests both, gifts one, ships one, then exercises production overnight save and Continue.
- **Scope:** one ticket, one branch, one PR; no migration, backup, security hardening, storage abstraction, HPA-597, or HPA-599 implementation.
- **Verification meaning:** this planning self-review checks document consistency only. It does **not** claim the future implementation compiles or passes tests; Tasks 1–5 contain the commands that must provide that evidence.
- **Placeholder scan:** no TBD/TODO/implementation-later placeholders remain.
