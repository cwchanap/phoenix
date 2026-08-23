# Phoenix Godot Social Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's three-villager talk, gifting, relationship, and one-time Close Friend dialogue loop in the existing Godot gameplay shell.

**Architecture:** Keep the current `GameSession` as the only mutable gameplay authority, add one pure `VillagerRules` content/policy module, and keep authored villager cells/footprints in `WorldContract`. Render the three retained villager frames as static direct children of the existing Y-sorted `Entities`; route facing-derived `E` interactions through `WorldShell`; and add one focused `DialoguePanel` under `GameHud` so the existing modal gate continues to be the only world-input lock.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1 through the existing archive verifier, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-social-port-design.md`

## Global Constraints

- Deliver HPA-594 in this same branch and PR; do not open a second implementation PR.
- Preserve the current 12×12 world, 64×32 projection, origin `(384,0)`, player spawn/movement/camera, farm, shop `(6,7)`, bed `(6,8)`, shipping `(6,10)`, and village path `x=3..9,y=6`.
- Villagers remain Mira `(6,5)`, Rowan `(3,5)`, June `(9,5)` with `0.6×0.6` footprints and `proof-villagers.png` frames `0/1/2`.
- Social values remain talk `+1`, gift `+3`, favourite bonus `+2`, Friend `12`, Close Friend `18`.
- Mira likes Potato, Rowan likes Pumpkin, June likes Turnip; all existing dialogue strings stay exact.
- Talking and gifting consume no time or stamina.
- `GameSession` remains the only mutable social authority; relationship level is derived from points.
- `WorldContract` remains the authored geometry authority; do not duplicate villager cells into the session snapshot.
- Existing farming/economy commands continue returning `GameRules.CommandCode` directly. The narrow social result Dictionary is not a generic command-result migration.
- Successful `sleep()` resets only `talked_today` and `gifted_today`; failed sleep, Day 14 rejection, and pending Morning Summary do not reset social state.
- `GameHud.has_blocking_modal()` remains the single input-gate source. Do not add another input manager, lock registry, or global event bus.
- Dialogue uses native focusable Godot `Button` nodes; do not use the HUD helper that sets `FOCUS_NONE`.
- Keep the existing `./tools/verify-clean.sh` entry point and current GitHub Actions job; do not add a new E2E framework.
- No NPC schedules/movement/pathfinding, homes, quests, romance, portraits, branching dialogue, generic dialogue/cutscene/event engine, generic item system, persistence/save format, migration, tutorial/finale behavior, localization framework, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactor.

---

### Task 1: Freeze villager content/policy and social command codes

**Files:**
- Create: `scripts/game/villager_rules.gd`
- Create: `tests/unit/test_villager_rules.gd`
- Modify: `scripts/game/game_rules.gd`

**Interfaces:**
- Produces: `VillagerRules.VillagerId`, `RelationshipLevel`, frozen content tables, relationship helpers, and gift helpers.
- Produces new command codes: `VILLAGER_TALKED`, `CROP_GIFTED`, `NOT_AT_VILLAGER`, `GIFT_ALREADY_GIVEN`.
- Consumes: `GameRules.CropKind` only; no mutable session/world state.

- [ ] **Step 1: Write RED tests for the closed villager table**

Create `tests/unit/test_villager_rules.gd` and pin every authored identity/favourite plus parallel table size:

```gdscript
extends GutTest

func test_villager_tables_are_closed_and_aligned() -> void:
    assert_eq(VillagerRules.VillagerId.size(), 3)
    for table in [
        VillagerRules.VILLAGER_KEYS,
        VillagerRules.DISPLAY_NAMES,
        VillagerRules.ROLE_LABELS,
        VillagerRules.FAVOURITE_CROPS,
        VillagerRules.NORMAL_DIALOGUE,
        VillagerRules.CLOSE_FRIEND_DIALOGUE,
        VillagerRules.NORMAL_GIFT_LINES,
        VillagerRules.FAVOURITE_GIFT_LINES,
    ]:
        assert_eq(table.size(), VillagerRules.VillagerId.size())

func test_villager_identity_and_favourites_are_exact() -> void:
    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.SHOPKEEPER), &"shopkeeper")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Mira")
    assert_eq(VillagerRules.role_label(VillagerRules.VillagerId.SHOPKEEPER), "Seed-shop keeper")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)

    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.FARMER), &"farmer")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Rowan")
    assert_eq(VillagerRules.role_label(VillagerRules.VillagerId.FARMER), "Neighbouring farmer")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)

    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.RESIDENT), &"resident")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.RESIDENT), "June")
    assert_eq(VillagerRules.role_label(VillagerRules.VillagerId.RESIDENT), "Village resident")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.RESIDENT), GameRules.CropKind.TURNIP)
```

- [ ] **Step 2: Add RED policy and exact-copy tests**

Append tests that pin the thresholds/gains and all player-facing lines:

```gdscript
func test_relationship_boundaries_and_gift_points_are_exact() -> void:
    assert_eq(VillagerRules.relationship_level(0), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(11), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(12), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(17), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(18), VillagerRules.RelationshipLevel.CLOSE_FRIEND)
    assert_eq(VillagerRules.TALK_POINTS, 1)
    assert_eq(VillagerRules.GIFT_POINTS, 3)
    assert_eq(VillagerRules.FAVOURITE_GIFT_BONUS, 2)
    assert_eq(
        VillagerRules.gift_points(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.TURNIP),
        5,
    )
    assert_eq(
        VillagerRules.gift_points(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.POTATO),
        3,
    )

func test_mira_dialogue_is_exact() -> void:
    var id := VillagerRules.VillagerId.SHOPKEEPER
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER), "The seed counter is open whenever you need it.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.FRIEND), "Your fields are starting to look dependable.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.CLOSE_FRIEND), "You have made this little farm part of the village.")
    assert_eq(VillagerRules.close_friend_dialogue_lines(id), [
        "You kept showing up, even on the slow days.",
        "The harvest market will feel different with you there.",
    ])
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.TURNIP), "A useful harvest. Thank you.")
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.POTATO), "Potatoes? You remembered.")

func test_rowan_dialogue_is_exact() -> void:
    var id := VillagerRules.VillagerId.FARMER
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER), "Watered soil tells you what tomorrow will bring.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.FRIEND), "Your rows are getting cleaner every day.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.CLOSE_FRIEND), "I would trust you with a field of my own.")
    assert_eq(VillagerRules.close_friend_dialogue_lines(id), [
        "I noticed when the farm stopped looking neglected.",
        "You earned that change one ordinary day at a time.",
    ])
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.TURNIP), "Good produce. I can use this.")
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.PUMPKIN), "A pumpkin this good is hard to ignore.")

func test_june_dialogue_is_exact() -> void:
    var id := VillagerRules.VillagerId.RESIDENT
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER), "It is quieter here than the road makes it look.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.FRIEND), "I keep seeing you around. I like that.")
    assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.CLOSE_FRIEND), "The village feels more like home with you here.")
    assert_eq(VillagerRules.close_friend_dialogue_lines(id), [
        "You came here as the new farmer, but that is not how I think of you now.",
        "You are one of us.",
    ])
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.POTATO), "That is kind of you.")
    assert_eq(VillagerRules.gift_line(id, GameRules.CropKind.TURNIP), "Turnips are my favourite. Perfect choice.")
```

Also mutate the Array returned by `close_friend_dialogue_lines()` and assert a second call still returns the two original strings so callers cannot mutate static content through a returned collection.

- [ ] **Step 3: Run the clean verifier and confirm RED**

```bash
./tools/verify-clean.sh
```

Expected: the GUT suite fails because `VillagerRules` is not defined yet.

- [ ] **Step 4: Add the four social command codes without changing the public command model**

Append these enum members to `GameRules.CommandCode`:

```gdscript
VILLAGER_TALKED,
CROP_GIFTED,
NOT_AT_VILLAGER,
GIFT_ALREADY_GIVEN,
```

Do not add a success classifier, string-key conversion, result base class, or generic command envelope.

- [ ] **Step 5: Implement the minimal pure `VillagerRules` module**

Create `scripts/game/villager_rules.gd` with the exact frozen tables and pure helpers:

```gdscript
class_name VillagerRules
extends RefCounted

enum VillagerId { SHOPKEEPER, FARMER, RESIDENT }
enum RelationshipLevel { STRANGER, FRIEND, CLOSE_FRIEND }

const TALK_POINTS := 1
const GIFT_POINTS := 3
const FAVOURITE_GIFT_BONUS := 2
const FRIEND_POINTS := 12
const CLOSE_FRIEND_POINTS := 18

const VILLAGER_KEYS: Array[StringName] = [&"shopkeeper", &"farmer", &"resident"]
const DISPLAY_NAMES: Array[String] = ["Mira", "Rowan", "June"]
const ROLE_LABELS: Array[String] = ["Seed-shop keeper", "Neighbouring farmer", "Village resident"]
const FAVOURITE_CROPS: Array[int] = [
    GameRules.CropKind.POTATO,
    GameRules.CropKind.PUMPKIN,
    GameRules.CropKind.TURNIP,
]
const RELATIONSHIP_KEYS: Array[StringName] = [&"stranger", &"friend", &"close_friend"]
const RELATIONSHIP_DISPLAY_NAMES: Array[String] = ["Stranger", "Friend", "Close Friend"]

const NORMAL_DIALOGUE: Array = [
    [
        "The seed counter is open whenever you need it.",
        "Your fields are starting to look dependable.",
        "You have made this little farm part of the village.",
    ],
    [
        "Watered soil tells you what tomorrow will bring.",
        "Your rows are getting cleaner every day.",
        "I would trust you with a field of my own.",
    ],
    [
        "It is quieter here than the road makes it look.",
        "I keep seeing you around. I like that.",
        "The village feels more like home with you here.",
    ],
]

const CLOSE_FRIEND_DIALOGUE: Array = [
    ["You kept showing up, even on the slow days.", "The harvest market will feel different with you there."],
    ["I noticed when the farm stopped looking neglected.", "You earned that change one ordinary day at a time."],
    ["You came here as the new farmer, but that is not how I think of you now.", "You are one of us."],
]

const NORMAL_GIFT_LINES: Array[String] = [
    "A useful harvest. Thank you.",
    "Good produce. I can use this.",
    "That is kind of you.",
]
const FAVOURITE_GIFT_LINES: Array[String] = [
    "Potatoes? You remembered.",
    "A pumpkin this good is hard to ignore.",
    "Turnips are my favourite. Perfect choice.",
]

static func relationship_level(points: int) -> RelationshipLevel:
    assert(points >= 0)
    if points >= CLOSE_FRIEND_POINTS:
        return RelationshipLevel.CLOSE_FRIEND
    if points >= FRIEND_POINTS:
        return RelationshipLevel.FRIEND
    return RelationshipLevel.STRANGER

static func is_favourite(id: VillagerId, crop: GameRules.CropKind) -> bool:
    return FAVOURITE_CROPS[id] == crop

static func gift_points(id: VillagerId, crop: GameRules.CropKind) -> int:
    return GIFT_POINTS + (FAVOURITE_GIFT_BONUS if is_favourite(id, crop) else 0)
```

Add the remaining direct index helpers from the design. `close_friend_dialogue_lines()` must build and return a fresh typed `Array[String]` rather than returning the constant nested Array by reference.

- [ ] **Step 6: Run the verifier and confirm GREEN**

```bash
./tools/verify-clean.sh
```

Expected: new `test_villager_rules.gd`, all existing GUT tests, and all three headless smokes pass.

- [ ] **Step 7: Commit the closed social policy**

```bash
git add scripts/game/game_rules.gd scripts/game/villager_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: freeze HPA-594 villager rules"
```

---

### Task 2: Add authoritative relationship state, talk/gift commands, and daily reset

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `VillagerRules`, `WorldContract.villager_cell(id)`, existing `_harvested_counts`, existing `_active_day_failure()`, and existing successful `sleep()` transaction.
- Produces snapshot field: `relationships: Dictionary` keyed by `&"shopkeeper"`, `&"farmer"`, `&"resident"`.
- Produces: `talk_to(id: VillagerRules.VillagerId, target_cell: Variant) -> Dictionary`.
- Produces: `gift_crop(id: VillagerRules.VillagerId, crop: GameRules.CropKind, target_cell: Variant) -> Dictionary`.
- Social result keys are exactly `code`, `lines`, `points_gained`, `gift_reaction`, `close_friend_sequence`.

- [ ] **Step 1: Write RED starter-state and deep-isolation tests**

Extend `tests/unit/test_game_session.gd`:

```gdscript
func test_new_session_has_exact_starter_relationships() -> void:
    var snapshot := GameSession.new().snapshot()
    assert_eq(snapshot["relationships"], {
        &"shopkeeper": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
        &"farmer": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
        &"resident": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
    })

func test_relationship_snapshot_is_deeply_isolated() -> void:
    var session := GameSession.new()
    var snapshot := session.snapshot()
    snapshot["relationships"][&"resident"]["points"] = 99
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 0)
```

Update the existing exact snapshot size/key assertion to include `relationships` and no villager coordinate/panel/focus fields.

- [ ] **Step 2: Write RED talk-target and duplicate-credit tests**

Use the authored target from `WorldContract` and compare complete snapshots on failure:

```gdscript
func test_talk_requires_matching_villager_target_and_repeat_talk_gains_zero() -> void:
    var session := GameSession.new()
    var id := VillagerRules.VillagerId.RESIDENT
    var before := session.snapshot()
    var wrong := session.talk_to(id, Vector2i(0, 0))
    assert_eq(wrong["code"], GameRules.CommandCode.NOT_AT_VILLAGER)
    assert_eq(session.snapshot(), before)

    var first := session.talk_to(id, WorldContract.villager_cell(id))
    assert_eq(first, {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": ["It is quieter here than the road makes it look."],
        "points_gained": 1,
        "gift_reaction": &"",
        "close_friend_sequence": false,
    })
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 1)
    assert_true(session.snapshot()["relationships"][&"resident"]["talked_today"])

    var repeat := session.talk_to(id, WorldContract.villager_cell(id))
    assert_eq(repeat["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(repeat["points_gained"], 0)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 1)
```

Also assert a pending Morning Summary returns `DAY_SUMMARY_PENDING` with the standard empty social payload and no mutation.

- [ ] **Step 3: Write RED gift atomicity and favourite-value tests**

The existing unit suite already sets private scalar/array state at explicit test boundaries, so seed only carried crop inventory directly rather than building a multi-day farm fixture for these isolated social rules:

```gdscript
func test_gift_consumes_exactly_one_crop_and_uses_normal_or_favourite_points() -> void:
    var resident := VillagerRules.VillagerId.RESIDENT

    var normal := GameSession.new()
    normal.set("_harvested_counts", [0, 1, 0])
    var normal_result := normal.gift_crop(
        resident,
        GameRules.CropKind.POTATO,
        WorldContract.villager_cell(resident),
    )
    assert_eq(normal_result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(normal_result["points_gained"], 3)
    assert_eq(normal_result["gift_reaction"], &"normal")
    assert_eq(normal.snapshot()["harvested"][&"potato"], 0)
    assert_eq(normal.snapshot()["relationships"][&"resident"]["points"], 3)

    var favourite := GameSession.new()
    favourite.set("_harvested_counts", [2, 0, 0])
    var favourite_result := favourite.gift_crop(
        resident,
        GameRules.CropKind.TURNIP,
        WorldContract.villager_cell(resident),
    )
    assert_eq(favourite_result["points_gained"], 5)
    assert_eq(favourite_result["gift_reaction"], &"favourite")
    assert_eq(favourite.snapshot()["harvested"][&"turnip"], 1)
```

Add separate atomicity assertions for this exact guard order:

`active-day failure → villager target → gift-already-given → carried crop availability → mutation`.

A duplicate gift must return `GIFT_ALREADY_GIVEN` without consuming a crop even when the requested crop count is zero. An inventory-invalid first gift returns existing `INSUFFICIENT_CROPS` without setting `gifted_today`.

- [ ] **Step 4: Write RED three-day threshold and one-time dialogue test**

Drive June with the existing sleep/ack flow and three carried favourite Turnips:

```gdscript
func test_gift_crossing_close_friend_defers_and_talk_consumes_sequence_once() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var june := VillagerRules.VillagerId.RESIDENT
    var target := WorldContract.villager_cell(june)
    session.set("_harvested_counts", [3, 0, 0])

    # Social day 1: 1 + 5 = 6.
    assert_eq(session.talk_to(june, target)["points_gained"], 1)
    assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, target)["points_gained"], 5)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 6)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    # Social day 2: 6 + 1 + 5 = 12 (Friend).
    session.talk_to(june, target)
    session.gift_crop(june, GameRules.CropKind.TURNIP, target)
    assert_eq(session.snapshot()["relationships"][&"resident"]["level"], &"friend")
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    # Social day 3: talk 13, gift crosses to 18; gift does not consume the sequence.
    session.talk_to(june, target)
    var crossing_gift := session.gift_crop(june, GameRules.CropKind.TURNIP, target)
    assert_false(crossing_gift["close_friend_sequence"])
    assert_eq(session.snapshot()["relationships"][&"resident"]["level"], &"close_friend")
    assert_false(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

    var special := session.talk_to(june, target)
    assert_eq(special["points_gained"], 0)
    assert_true(special["close_friend_sequence"])
    assert_eq(special["lines"], [
        "You came here as the new farmer, but that is not how I think of you now.",
        "You are one of us.",
    ])
    assert_true(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

    var normal_close_friend := session.talk_to(june, target)
    assert_false(normal_close_friend["close_friend_sequence"])
    assert_eq(normal_close_friend["lines"], ["The village feels more like home with you here."])
```

- [ ] **Step 5: Write RED daily-reset and Day 14 preservation tests**

Pin successful transition behavior:

```gdscript
func test_successful_sleep_resets_only_daily_social_flags() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var june := VillagerRules.VillagerId.RESIDENT
    var target := WorldContract.villager_cell(june)
    session.set("_harvested_counts", [1, 0, 0])
    session.talk_to(june, target)
    session.gift_crop(june, GameRules.CropKind.TURNIP, target)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var relationship: Dictionary = session.snapshot()["relationships"][&"resident"]
    assert_eq(relationship["points"], 6)
    assert_false(relationship["talked_today"])
    assert_false(relationship["gifted_today"])
    assert_false(relationship["close_friend_dialogue_seen"])
```

Extend the existing Day 14 test by setting one relationship to non-default points/flags before the rejected sleep and asserting the complete relationship snapshot is unchanged afterward.

- [ ] **Step 6: Run the verifier and confirm RED**

```bash
./tools/verify-clean.sh
```

Expected: the new relationship tests fail because the session has no social state/commands yet.

- [ ] **Step 7: Add relationship initialization and snapshot projection**

In `GameSession`, initialize exactly one entry per villager:

```gdscript
var _relationships: Array[Dictionary] = []

func _init(weather_roll: Callable = Callable()) -> void:
    _weather_roll = weather_roll if weather_roll.is_valid() else Callable(self, "_default_weather_roll")
    for cell in WorldContract.farm_cells():
        _farm.append({"cell": cell, "tilled": false, "crop": null})
    for _id in range(VillagerRules.VillagerId.size()):
        _relationships.append({
            "points": 0,
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        })
```

Add `"relationships": _relationships_snapshot()` to `snapshot()`. `_relationships_snapshot()` derives `level` with `VillagerRules.relationship_level(points)` and keys with `villager_key(id)`; it returns fresh nested dictionaries.

- [ ] **Step 8: Implement narrow social-result helpers and `talk_to`**

Keep the result shape local to `GameSession`:

```gdscript
func _social_failure(code: GameRules.CommandCode) -> Dictionary:
    return {
        "code": code,
        "lines": [],
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": false,
    }

func _social_success(
    code: GameRules.CommandCode,
    lines: Array[String],
    points_gained: int,
    gift_reaction: StringName = &"",
    close_friend_sequence: bool = false,
) -> Dictionary:
    return {
        "code": code,
        "lines": lines.duplicate(),
        "points_gained": points_gained,
        "gift_reaction": gift_reaction,
        "close_friend_sequence": close_friend_sequence,
    }
```

Implement `talk_to` using the exact order from the spec. Build the normal one-line Array explicitly so it satisfies `Array[String]`:

```gdscript
var lines: Array[String] = [VillagerRules.dialogue_line(id, level)]
```

Do not store dialogue text or relationship level in mutable session state.

- [ ] **Step 9: Implement `gift_crop` and extend only successful sleep**

`gift_crop` consumes `_harvested_counts[crop] -= 1` only after every failure guard passes, then marks `gifted_today` and adds `VillagerRules.gift_points(id, crop)`.

At the end of the existing successful `sleep()` transaction—after the day/weather/economy state has advanced and before returning `DAY_ADVANCED`—reset only:

```gdscript
for relationship in _relationships:
    relationship["talked_today"] = false
    relationship["gifted_today"] = false
```

Do not add social reset code to `acknowledge_morning_summary()` or any failed sleep branch.

- [ ] **Step 10: Run the verifier and confirm GREEN**

```bash
./tools/verify-clean.sh
```

Expected: all relationship rules and all previously existing farm/economy/day tests pass without changing old command behavior.

- [ ] **Step 11: Commit the authoritative social state**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore HPA-594 relationship rules"
```

---

### Task 3: Author the three static villagers and collision/target geometry

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces: `WorldContract.villager_cell(id) -> Vector2i`, `villager_footprint(id) -> Rect2`, `villager_at(cell: Variant) -> int`.
- Consumes retained asset: `res://assets/sprites/proof-villagers.png` (`96x48`, 3 frames).
- Preserves: `Entities` as the only Y-sort-enabled `CanvasItem`; villagers are direct children of it.

- [ ] **Step 1: Write RED world-contract tests in the existing headless smoke**

Add exact geometry assertions near the other `WorldContract` checks:

```gdscript
var villager_cells := [Vector2i(6, 5), Vector2i(3, 5), Vector2i(9, 5)]
var villager_footprints := [
    Rect2(6.2, 5.2, 0.6, 0.6),
    Rect2(3.2, 5.2, 0.6, 0.6),
    Rect2(9.2, 5.2, 0.6, 0.6),
]
for id in range(VillagerRules.VillagerId.size()):
    if not _expect_vec2i(WorldContract.villager_cell(id), villager_cells[id], "villager cell %d" % id):
        return
    if not _expect(WorldContract.villager_footprint(id) == villager_footprints[id], "villager footprint %d" % id):
        return
    if not _expect(WorldContract.villager_at(villager_cells[id]) == id, "villager lookup %d" % id):
        return
if not _expect(WorldContract.villager_at(Vector2i(0, 0)) == -1, "off-villager lookup"):
    return
```

- [ ] **Step 2: Write RED scene-contract checks for collisions and entity roots**

Extend `StaticCollision` expected children with:

```text
VillagerShopkeeperCollision
VillagerFarmerCollision
VillagerResidentCollision
```

and compare each polygon to `WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))`.

Extend the `Entities` expected authored order before the runtime crop roots:

```text
Player
Tree
Building
Shipping
VillagerShopkeeper
VillagerFarmer
VillagerResident
FarmCrop_2_7
...
FarmCrop_4_9
```

For each villager assert:

```gdscript
root.position == _cell_center(WorldContract.villager_cell(id))
sprite.texture.resource_path == "res://assets/sprites/proof-villagers.png"
sprite.hframes == 3
sprite.frame == id
sprite.offset == Vector2(0, -24)
root.z_index == shared_entity_z_index
```

The existing asset-size smoke already pins `proof-villagers.png` to `96x48`; do not add a generator.

- [ ] **Step 3: Add RED integration checks for collision-safe, targetable placement**

In `tests/integration/test_gameplay_shell.gd`, add a table-driven test that each authored villager root exists at the expected center and that `_place_target(world, cell)` makes `player.current_target_cell()` equal that same villager cell. This proves targeting uses the shipped facing math rather than an Area2D proximity shortcut.

- [ ] **Step 4: Run the clean verifier and confirm RED**

```bash
./tools/verify-clean.sh
```

Expected: world smoke/integration failures for the missing contract constants, collision nodes, and villager entity roots.

- [ ] **Step 5: Add the narrow authored geometry API**

In `world_contract.gd`:

```gdscript
const VILLAGER_CELLS: Array[Vector2i] = [
    Vector2i(6, 5),
    Vector2i(3, 5),
    Vector2i(9, 5),
]
const VILLAGER_FOOTPRINTS: Array[Rect2] = [
    Rect2(6.2, 5.2, 0.6, 0.6),
    Rect2(3.2, 5.2, 0.6, 0.6),
    Rect2(9.2, 5.2, 0.6, 0.6),
]

static func villager_cell(id: VillagerRules.VillagerId) -> Vector2i:
    return VILLAGER_CELLS[id]

static func villager_footprint(id: VillagerRules.VillagerId) -> Rect2:
    return VILLAGER_FOOTPRINTS[id]

static func villager_at(cell: Variant) -> int:
    if not (cell is Vector2i):
        return -1
    return VILLAGER_CELLS.find(cell)
```

Do not create a general interaction-cell registry. Shop/bed/shipping keep their current explicit constants.

- [ ] **Step 6: Add the three scene collision nodes and static entity roots**

Add `proof-villagers.png` as one `Texture2D` ext_resource in `world.tscn`.

Under `StaticCollision`, add the three empty `CollisionPolygon2D` nodes named above. In `WorldShell._ready()`, assign their polygons exactly as the existing tree/building/shipping polygons are assigned.

Under `Entities`, add the three roots in enum/frame order. Their final authored node shape is:

```text
VillagerShopkeeper (Node2D) position=(416,192)
└── Sprite2D texture=proof-villagers.png hframes=3 frame=0 offset=(0,-24)
VillagerFarmer (Node2D) position=(320,144)
└── Sprite2D texture=proof-villagers.png hframes=3 frame=1 offset=(0,-24)
VillagerResident (Node2D) position=(512,240)
└── Sprite2D texture=proof-villagers.png hframes=3 frame=2 offset=(0,-24)
```

Do not add scripts, `Area2D`, `AnimationPlayer`, or another scene per villager.

- [ ] **Step 7: Run the focused world smoke, then the full verifier**

If the local Godot project is imported, first run:

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Then run the clean-tree gate:

```bash
./tools/verify-clean.sh
```

Expected: all authored geometry/collision/Y-sort checks and prior tests pass.

- [ ] **Step 8: Commit the static village entities**

```bash
git add scripts/world/world_contract.gd scenes/world/world.tscn scripts/world/world_shell.gd tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 village residents"
```

---

### Task 4: Build the focused dialogue panel and route talk/gifting through the existing modal gate

**Files:**
- Create: `scenes/ui/dialogue_panel.tscn`
- Create: `scripts/ui/dialogue_panel.gd`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- `DialoguePanel` emits `gift_requested(villager_id: int, crop_kind: int)` and `close_requested`.
- `DialoguePanel.present(villager_id: int, social: Dictionary, snapshot: Dictionary) -> void` starts/replaces panel content.
- `DialoguePanel.refresh_snapshot(snapshot: Dictionary) -> void` refreshes read-only relationship/carried-crop presentation.
- `DialoguePanel.close_panel() -> void` clears its transient content and hides itself.
- `GameHud` forwards `gift_requested`; adds `open_dialogue`, `update_dialogue`, `close_dialogue`; dialogue visibility participates in `has_blocking_modal()`.
- `WorldShell` keeps direct target routing and adds `_finish_social_command` plus `_on_gift_requested`.

- [ ] **Step 1: Define the dialogue scene node contract and write RED panel-presence/input-gate tests**

Create tests before the scene exists. The final `dialogue_panel.tscn` must expose these stable node paths so tests do not depend on dynamic label order:

```text
DialoguePanel (Control, hidden, full viewport, mouse_filter=STOP)
└── Panel (ColorRect)
    ├── Name (Label)
    ├── Role (Label)
    ├── Relationship (Label)
    ├── Line (Label)
    ├── PointsFeedback (Label)
    ├── GiftFeedback (Label)
    ├── GiftStatus (Label)
    ├── GiftButtons (VBoxContainer)
    ├── Continue (Button)
    └── Close (Button)
```

Instance it at `GameHud/HudRoot/DialoguePanel`.

Add a RED integration test:

```gdscript
func test_villager_interaction_opens_dialogue_and_immediately_gates_world_input() -> void:
    var world := _world()
    if world == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()

    var panel := world.get_node("GameHud/HudRoot/DialoguePanel") as DialoguePanel
    assert_true(panel.visible)
    assert_false(world._world_input_enabled)
    assert_eq((panel.get_node("Panel/Name") as Label).text, "June")
    assert_eq((panel.get_node("Panel/Line") as Label).text, "It is quieter here than the road makes it look.")
    assert_eq(world._session.snapshot()["relationships"][&"resident"]["points"], 1)
```

Also capture player velocity/session snapshot after opening and assert action selection, farming use, and a repeated `world.interact()` call do not mutate while the modal is open.

- [ ] **Step 2: Write RED close/Escape restoration tests**

Test both explicit Close and `ui_cancel`. After close:

- `DialoguePanel.visible == false`;
- `world._world_input_enabled == true`;
- player can accept movement on the next physics frame;
- closing itself makes no additional session mutation.

For Escape, push one `InputEventAction` to the viewport:

```gdscript
var cancel := InputEventAction.new()
cancel.action = &"ui_cancel"
cancel.pressed = true
world.get_viewport().push_input(cancel)
await get_tree().process_frame
```

Do not call `WorldShell._refresh_world_input_gate()` manually in the test; restoration must occur through `modal_state_changed`.

- [ ] **Step 3: Write RED native-focus and two-line sequence test**

Seed the session relationship directly at the UI integration boundary so this test remains focused on panel behavior:

```gdscript
var relationships: Array = world._session.get("_relationships")
relationships[VillagerRules.VillagerId.RESIDENT] = {
    "points": 18,
    "talked_today": false,
    "gifted_today": true,
    "close_friend_dialogue_seen": false,
}
```

Target June and interact. Assert:

- the first special line is visible;
- `Continue` is `get_viewport().gui_get_focus_owner()`;
- pushing one pressed/released `ui_accept` action advances to exactly the second line, not past it;
- `ui_cancel` pushed on the first line leaves the panel visible;
- after the second line, Close receives focus and cancel can close.

This verifies native focus sequencing without adding an Enter key handler to application code.

- [ ] **Step 4: Write RED gifting UI and mutation test**

Seed one carried June-favourite Turnip:

```gdscript
world._session.set("_harvested_counts", [1, 0, 0])
```

Interact with June, then assert the final-line gift area contains one `Give Turnip` Button and that this button is the focus owner before Close. Emit exactly one press on that visible button and assert:

- harvested Turnip becomes `0`;
- June relationship goes `1 -> 6`;
- `gifted_today` becomes true;
- panel line becomes `Turnips are my favourite. Perfect choice.`;
- `GiftFeedback` is `Favourite gift!`;
- `GiftStatus` is `Gift already given today`;
- no gift buttons remain;
- world input is still locked until Close.

Add a no-crops case that shows `No harvested crops to give` and focuses Close.

- [ ] **Step 5: Run the clean verifier and confirm RED**

```bash
./tools/verify-clean.sh
```

Expected: integration failures because the dialogue scene/HUD/world routing do not exist yet.

- [ ] **Step 6: Implement the focused `DialoguePanel` scene and script**

Use a fixed pixel layout consistent with the existing 640×360 MVP HUD rather than introducing a theme/layout framework. The script keeps only transient presentation fields:

```gdscript
class_name DialoguePanel
extends Control

signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested

var _villager_id: int = -1
var _lines: Array[String] = []
var _line_index := 0
var _points_gained := 0
var _gift_reaction: StringName = &""
var _close_friend_sequence := false
var _snapshot: Dictionary = {}
```

`present()` copies the social lines/result and snapshot, sets `_line_index = 0`, makes the panel visible, renders, and calls `_focus_primary()` via `call_deferred` so the controls exist in the focus tree.

`refresh_snapshot()` deep-copies only the read model and rerenders without changing `_line_index`.

`_rebuild_gift_buttons()` removes old dynamic buttons and creates one native `Button` for each `GameRules.CropKind` whose latest `snapshot["harvested"][crop_key] > 0`, but only on the final line and only while `gifted_today` is false. Connect with:

```gdscript
button.pressed.connect(_on_gift_pressed.bind(kind))
```

Do not use `GameHud._add_button`; native dialogue buttons keep default focus mode.

- [ ] **Step 7: Implement panel line progression, focus, and cancel behavior**

Use only the buttons and `ui_cancel`:

```gdscript
func _on_continue_pressed() -> void:
    if _line_index >= _lines.size() - 1:
        return
    _line_index += 1
    _render()
    _focus_primary.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_action_pressed("ui_cancel"):
        return
    get_viewport().set_input_as_handled()
    if _close_friend_sequence and _line_index < _lines.size() - 1:
        return
    close_requested.emit()
```

`_focus_primary()` requests focus on Continue while more lines remain, otherwise the first gift button, otherwise Close. Do not handle `ui_accept` yourself; Godot's focused `Button` owns it.

- [ ] **Step 8: Integrate dialogue into `GameHud` without adding a second gate**

Add:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
@onready var _dialogue_panel: DialoguePanel = $HudRoot/DialoguePanel as DialoguePanel
```

Connect `DialoguePanel.gift_requested` to a direct forwarding handler and `close_requested` to `close_dialogue()`.

Extend `has_blocking_modal()` with `_dialogue_panel.visible`.

`open_dialogue(villager_id, social, snapshot)` closes Shop/Shipping/Sleep, presents the panel, and emits `modal_state_changed`. `update_dialogue` calls `present` on the already-visible panel without unlocking the world. `close_dialogue` hides/clears the panel and emits `modal_state_changed` once.

When `_set_morning_summary_visible(true)` runs, hide dialogue alongside the three current non-summary modals so the session-derived Morning Summary remains the highest-priority modal.

Keep the existing action/seed disabling code unchanged; because it already calls `has_blocking_modal()`, dialogue automatically disables those controls.

- [ ] **Step 9: Route villager hints/talk/gifts directly in `WorldShell`**

Connect `hud.gift_requested` in `_ready()`.

In `_process`, resolve the target once and prefer a villager hint when `WorldContract.villager_at(target) >= 0`:

```gdscript
var villager_id := WorldContract.villager_at(target)
if villager_id >= 0:
    hud.set_interaction_hint("%s — E" % VillagerRules.display_name(villager_id))
elif target == WorldContract.SHOP_CELL:
    ...
```

In `interact()`, route a villager first, then preserve the existing Shop/Shipping/Bed/Nothing cases:

```gdscript
var villager_id := WorldContract.villager_at(target)
if villager_id >= 0:
    _finish_social_command(villager_id, _session.talk_to(villager_id, target), false)
elif target == WorldContract.SHOP_CELL:
    hud.open_shop()
...
```

Implement `_on_gift_requested(villager_id, crop_kind)` by reading the still-current target and calling `GameSession.gift_crop`. The player cannot move while dialogue is open, but the session must still validate the target.

`_finish_social_command(villager_id, result, updating_dialogue)`:

1. calls `hud.show_feedback(result["code"])`;
2. refreshes FarmView/HUD from the post-command session snapshot;
3. if code is `VILLAGER_TALKED`, calls `hud.open_dialogue`;
4. if code is `CROP_GIFTED`, calls `hud.update_dialogue`;
5. on failure, leaves the current dialogue visible for gift failures and displays the failure feedback without closing/unlocking it.

Do not put relationship logic or line progression in `WorldShell`.

- [ ] **Step 10: Add exact HUD feedback for the four new command codes**

In `GameHud.show_feedback`:

```gdscript
GameRules.CommandCode.VILLAGER_TALKED:
    _feedback.text = "Talked with villager."
GameRules.CommandCode.CROP_GIFTED:
    _feedback.text = "Gift given."
GameRules.CommandCode.NOT_AT_VILLAGER:
    _feedback.text = "Face the villager."
GameRules.CommandCode.GIFT_ALREADY_GIVEN:
    _feedback.text = "Gift already given today."
```

Reuse the existing `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` strings for those social failures.

- [ ] **Step 11: Run the integration suite through the full verifier and confirm GREEN**

```bash
./tools/verify-clean.sh
```

Expected: talk targeting, panel content, focus, gifting, Escape/Close input restoration, all prior modals, and all farm/economy tests/smokes pass.

- [ ] **Step 12: Commit the playable dialogue/gifting slice**

```bash
git add scenes/ui/dialogue_panel.tscn scripts/ui/dialogue_panel.gd scenes/ui/game_hud.tscn scripts/ui/game_hud.gd scripts/world/world_shell.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 dialogue and gifting"
```

---

### Task 5: Prove the complete social parity slice and update project handoff docs

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes all HPA-594 public seams from Tasks 1–4.
- Produces one deterministic scene-level acceptance path plus concise player/developer handoff documentation.
- Adds no runtime abstraction or dependency.

- [ ] **Step 1: Add one deterministic three-day acceptance test using the real session + panel seams**

Keep this as a compact integration test rather than adding a browser-style automation framework. Seed exactly three carried Turnips directly at the test boundary, then use the real `WorldShell.interact()`, visible dialogue panel gift buttons, and real sleep/ack session methods to prove June's progression:

```text
Day 1 social: talk +1, gift favourite +5 => 6 Stranger
sleep + acknowledge
Day 2 social: talk +1, gift favourite +5 => 12 Friend
sleep + acknowledge
Day 3 social: talk +1 => 13, gift favourite +5 => 18 Close Friend
same-day talk => exact two-line Close Friend sequence with +0
close/reopen => normal Close Friend line only
```

At each day boundary assert `talked_today`/`gifted_today` reset while points persist. At the end assert all three Turnips are consumed, the special-seen flag is true, the panel can close, and `_world_input_enabled` is restored.

The test intentionally does not grow crops; crop growth is already covered by HPA-589 and social rules should not duplicate that expensive setup.

- [ ] **Step 2: Add a table-driven all-villager interaction check**

For Mira, Rowan, and June, use `_place_target` plus `world.interact()` and assert the panel displays the exact name, role, and Stranger line from `VillagerRules`. Close between entries and assert the world gate restores every time. This proves all three scene nodes route to the correct enum/content frame rather than only validating June.

- [ ] **Step 3: Update README with player-facing social controls and thresholds only**

Document these exact facts alongside the existing controls/gameplay section:

```text
- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.
```

Do not duplicate exact villager cells or collision values into README.

- [ ] **Step 4: Update CLAUDE.md with the final narrow ownership boundaries**

Add only the architecture facts needed for future HPA-598/HPA-597 work:

```text
- `VillagerRules` owns frozen social content/relationship policy.
- `GameSession` owns mutable relationship points, daily talk/gift flags, and one-time dialogue-seen state.
- `WorldContract` owns the three static villager cells/footprints.
- `DialoguePanel` owns transient line/focus/gift-choice presentation; it never mutates gameplay state.
- `GameHud.has_blocking_modal()` remains the single world-input gate.
```

Explicitly note that HPA-598 owns save serialization of relationship state; HPA-594 does not define a save schema.

- [ ] **Step 5: Run the complete clean-archive verification gate**

```bash
./tools/verify-clean.sh
```

Expected: all GUT unit/integration tests and all three headless smoke scripts pass from archived committed-tree content under Godot 4.7.1 with verifier-fetched GUT 9.7.1.

- [ ] **Step 6: Run final diff hygiene and scope checks**

```bash
git diff --check origin/main...HEAD
git status --short
git diff --name-only origin/main...HEAD
```

Expected:

- `git diff --check` prints nothing;
- working tree is clean after the final commit;
- runtime changes are limited to HPA-594 social policy/state, villager scene geometry, dialogue/HUD routing, tests, README, and CLAUDE plus the two already-reviewed planning documents;
- no persistence/save file, NPC AI/schedule, generic dialogue/event framework, new dependency, CI workflow, browser/Tauri runtime, or unrelated refactor appears.

- [ ] **Step 7: Commit the acceptance and handoff update**

```bash
git add tests/integration/test_gameplay_shell.gd README.md CLAUDE.md
git commit -m "docs: complete HPA-594 social handoff"
```

- [ ] **Step 8: Re-run the final verifier on the committed HEAD**

```bash
./tools/verify-clean.sh
git status --short
```

Expected: verifier passes and `git status --short` is empty. Keep the PR as the single HPA-594 delivery PR and move it from draft to ready only after code review of the completed implementation.