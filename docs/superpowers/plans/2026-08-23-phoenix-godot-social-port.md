# Phoenix Godot Social Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's shipped three-villager talk, gifting, relationship, and one-time Close Friend dialogue loop on the live Godot HPA-589 gameplay shell.

**Architecture:** Extend the existing `GameSession` as the only mutable gameplay authority. Add one pure `VillagerRules` content/policy sibling, keep authored villager geometry in `WorldContract`, add three static villager roots/collisions to the existing world scene, route `E` directly through `WorldShell`, and instance one focused `DialoguePanel` under the existing `GameHud/HudRoot`. Reuse `GameHud.has_blocking_modal()` as the only world-input gate.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1 through the existing archive verifier, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-social-port-design.md`

**Behavior oracle:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global Constraints

- Deliver HPA-594 in this same branch and PR; do not open a second implementation PR.
- Implement against current Godot paths: `scripts/game/*`, `scripts/world/*`, `scripts/ui/*`, `scenes/world/world.tscn`, `scenes/ui/*`, `tests/unit/`, `tests/integration/`, `tests/headless/`, and `tools/verify-clean.sh`.
- Preserve the 12×12 world, 64×32 projection, origin `(384,0)`, current player/camera/farm/economy behavior, shop `(6,7)`, bed `(6,8)`, shipping `(6,10)`, and path `x=3..9,y=6`.
- Villagers remain Mira `(6,5)`, Rowan `(3,5)`, June `(9,5)` with `0.6×0.6` footprints and retained `res://assets/sprites/proof-villagers.png` frames `0/1/2`.
- The HPA-595 design is the behavior/content oracle. Talk `+1`, gift `+3`, favourite bonus `+2`, Friend `12`, Close Friend `18`, names, roles, favourites, and every spoken line remain exact.
- Talking and gifting consume no time or stamina.
- `GameSession` owns mutable relationship state; relationship level is derived from points.
- `WorldContract` owns villager geometry; do not echo villager cells into `GameSession.snapshot()`.
- Existing farming/economy methods keep returning `GameRules.CommandCode` directly. The narrow social dictionary remains local to `talk_to`/`gift_crop`.
- Add only `VILLAGER_TALKED`, `CROP_GIFTED`, `NOT_AT_VILLAGER`, and `GIFT_ALREADY_GIVEN` to `GameRules.CommandCode`; reuse `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING`.
- Successful `sleep()` resets only `talked_today` and `gifted_today`; failed sleep, Day 14 rejection, and pending Morning Summary do not reset social state.
- `GameHud.has_blocking_modal()` remains the sole world-input gate. Do not add a lock registry, input manager, event bus, or generic interaction registry.
- Dialogue buttons use native focusable Godot `Button` behavior; do not use the existing `_add_button()` helper that sets `FOCUS_NONE`.
- `tests/headless/world_shell_smoke.gd` exact authored node lists and `tests/integration/test_gameplay_shell.gd` runtime child counts must be updated in the same task that inserts villagers.
- Do not inject private relationship/inventory state through `WorldShell` tests and do not add a debug/test command bus. Full social progression belongs in bare `GameSession` unit tests.
- `AGENTS.md` is a symlink to `CLAUDE.md`. Update the `CLAUDE.md` handoff target when implementation lands; do not replace `AGENTS.md` with a duplicated file.
- Keep one `./tools/verify-clean.sh` entry point and the current CI job; add no new E2E framework.
- No NPC schedules/movement/pathfinding, homes, quests, romance, portraits, branching dialogue, generic dialogue/cutscene/event engine, generic item system, persistence/save format, migration, tutorial/finale behavior, localization framework, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactor.

---

### Task 1: Freeze the HPA-595 social oracle in `VillagerRules`

**Files:**
- Create: `scripts/game/villager_rules.gd`
- Create: `tests/unit/test_villager_rules.gd`
- Modify: `scripts/game/game_rules.gd`

**Interfaces:**
- Produces `VillagerRules.VillagerId`, `RelationshipLevel`, frozen content tables, relationship helpers, and gift helpers.
- Produces four new `GameRules.CommandCode` values only.
- Consumes `GameRules.CropKind`; no mutable state or world nodes.

- [ ] **Step 1: Write RED oracle tests with the exact shipped values**

Create `tests/unit/test_villager_rules.gd`:

```gdscript
extends GutTest

func test_identity_favourites_and_policy_are_exact() -> void:
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

    assert_eq(VillagerRules.TALK_POINTS, 1)
    assert_eq(VillagerRules.GIFT_POINTS, 3)
    assert_eq(VillagerRules.FAVOURITE_GIFT_BONUS, 2)
    assert_eq(VillagerRules.relationship_level(11), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(12), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(17), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(18), VillagerRules.RelationshipLevel.CLOSE_FRIEND)

func test_spoken_content_is_verbatim_hpa_595_oracle() -> void:
    var expected := [
        {
            "id": VillagerRules.VillagerId.SHOPKEEPER,
            "dialogue": [
                "The seed counter is open whenever you need it.",
                "Your fields are starting to look dependable.",
                "You have made this little farm part of the village.",
            ],
            "special": [
                "You kept showing up, even on the slow days.",
                "The harvest market will feel different with you there.",
            ],
            "normal_gift": "A useful harvest. Thank you.",
            "favourite_gift": "Potatoes? You remembered.",
        },
        {
            "id": VillagerRules.VillagerId.FARMER,
            "dialogue": [
                "Watered soil tells you what tomorrow will bring.",
                "Your rows are getting cleaner every day.",
                "I would trust you with a field of my own.",
            ],
            "special": [
                "I noticed when the farm stopped looking neglected.",
                "You earned that change one ordinary day at a time.",
            ],
            "normal_gift": "Good produce. I can use this.",
            "favourite_gift": "A pumpkin this good is hard to ignore.",
        },
        {
            "id": VillagerRules.VillagerId.RESIDENT,
            "dialogue": [
                "It is quieter here than the road makes it look.",
                "I keep seeing you around. I like that.",
                "The village feels more like home with you here.",
            ],
            "special": [
                "You came here as the new farmer, but that is not how I think of you now.",
                "You are one of us.",
            ],
            "normal_gift": "That is kind of you.",
            "favourite_gift": "Turnips are my favourite. Perfect choice.",
        },
    ]

    for entry in expected:
        var id: VillagerRules.VillagerId = entry["id"]
        assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER), entry["dialogue"][0])
        assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.FRIEND), entry["dialogue"][1])
        assert_eq(VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.CLOSE_FRIEND), entry["dialogue"][2])
        assert_eq(VillagerRules.close_friend_dialogue_lines(id), entry["special"])

    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.TURNIP), expected[0]["normal_gift"])
    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.SHOPKEEPER, GameRules.CropKind.POTATO), expected[0]["favourite_gift"])
    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.FARMER, GameRules.CropKind.TURNIP), expected[1]["normal_gift"])
    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.FARMER, GameRules.CropKind.PUMPKIN), expected[1]["favourite_gift"])
    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.POTATO), expected[2]["normal_gift"])
    assert_eq(VillagerRules.gift_line(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.TURNIP), expected[2]["favourite_gift"])
```

Also mutate the array returned by `close_friend_dialogue_lines()` and assert a second call still returns the two oracle strings.

- [ ] **Step 2: Run the clean verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: GUT fails because `VillagerRules` does not exist.

- [ ] **Step 3: Add only the four social command codes**

Append to `GameRules.CommandCode`:

```gdscript
VILLAGER_TALKED,
CROP_GIFTED,
NOT_AT_VILLAGER,
GIFT_ALREADY_GIVEN,
```

Do not add a generic result base type, success classifier, code-to-string framework, or migrate existing commands.

- [ ] **Step 4: Implement the pure oracle module**

Create `scripts/game/villager_rules.gd`:

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
    ["The seed counter is open whenever you need it.", "Your fields are starting to look dependable.", "You have made this little farm part of the village."],
    ["Watered soil tells you what tomorrow will bring.", "Your rows are getting cleaner every day.", "I would trust you with a field of my own."],
    ["It is quieter here than the road makes it look.", "I keep seeing you around. I like that.", "The village feels more like home with you here."],
]
const CLOSE_FRIEND_DIALOGUE: Array = [
    ["You kept showing up, even on the slow days.", "The harvest market will feel different with you there."],
    ["I noticed when the farm stopped looking neglected.", "You earned that change one ordinary day at a time."],
    ["You came here as the new farmer, but that is not how I think of you now.", "You are one of us."],
]
const NORMAL_GIFT_LINES: Array[String] = ["A useful harvest. Thank you.", "Good produce. I can use this.", "That is kind of you."]
const FAVOURITE_GIFT_LINES: Array[String] = ["Potatoes? You remembered.", "A pumpkin this good is hard to ignore.", "Turnips are my favourite. Perfect choice."]

static func villager_key(id: VillagerId) -> StringName:
    return VILLAGER_KEYS[id]

static func display_name(id: VillagerId) -> String:
    return DISPLAY_NAMES[id]

static func role_label(id: VillagerId) -> String:
    return ROLE_LABELS[id]

static func favourite_crop(id: VillagerId) -> GameRules.CropKind:
    return FAVOURITE_CROPS[id]

static func relationship_level(points: int) -> RelationshipLevel:
    assert(points >= 0)
    if points >= CLOSE_FRIEND_POINTS:
        return RelationshipLevel.CLOSE_FRIEND
    if points >= FRIEND_POINTS:
        return RelationshipLevel.FRIEND
    return RelationshipLevel.STRANGER

static func relationship_key(level: RelationshipLevel) -> StringName:
    return RELATIONSHIP_KEYS[level]

static func relationship_display_name(level: RelationshipLevel) -> String:
    return RELATIONSHIP_DISPLAY_NAMES[level]

static func dialogue_line(id: VillagerId, level: RelationshipLevel) -> String:
    return NORMAL_DIALOGUE[id][level]

static func close_friend_dialogue_lines(id: VillagerId) -> Array[String]:
    var lines: Array[String] = []
    for line in CLOSE_FRIEND_DIALOGUE[id]:
        lines.append(line)
    return lines

static func is_favourite(id: VillagerId, crop: GameRules.CropKind) -> bool:
    return FAVOURITE_CROPS[id] == crop

static func gift_points(id: VillagerId, crop: GameRules.CropKind) -> int:
    return GIFT_POINTS + (FAVOURITE_GIFT_BONUS if is_favourite(id, crop) else 0)

static func gift_line(id: VillagerId, crop: GameRules.CropKind) -> String:
    return FAVOURITE_GIFT_LINES[id] if is_favourite(id, crop) else NORMAL_GIFT_LINES[id]
```

- [ ] **Step 5: Run the verifier and verify GREEN**

```bash
./tools/verify-clean.sh
```

Expected: new oracle tests, existing unit/integration tests, and all headless smokes pass.

- [ ] **Step 6: Commit Task 1**

```bash
git add scripts/game/game_rules.gd scripts/game/villager_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: freeze HPA-594 villager rules"
```

---

### Task 2: Add authoritative relationship state and session commands

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces snapshot field `relationships`, keyed by `VillagerRules.villager_key(id)`.
- Produces `talk_to(id: VillagerRules.VillagerId, target_cell: Variant) -> Dictionary`.
- Produces `gift_crop(id: VillagerRules.VillagerId, crop: GameRules.CropKind, target_cell: Variant) -> Dictionary`.
- Every social result has exactly `code`, `lines`, `points_gained`, `gift_reaction`, `close_friend_sequence`.

- [ ] **Step 1: Write RED starter/deep-copy and direct command tests**

Extend `test_new_session_has_exact_starter_state()` to add only `relationships` to the top-level snapshot contract, then add:

```gdscript
func test_new_session_has_exact_starter_relationships() -> void:
    assert_eq(GameSession.new().snapshot()["relationships"], {
        &"shopkeeper": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
        &"farmer": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
        &"resident": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
    })

func test_talk_requires_target_and_repeat_talk_gains_zero() -> void:
    var session := GameSession.new()
    var june := VillagerRules.VillagerId.RESIDENT
    var before := session.snapshot()
    assert_eq(session.talk_to(june, Vector2i.ZERO)["code"], GameRules.CommandCode.NOT_AT_VILLAGER)
    assert_eq(session.snapshot(), before)

    var first := session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(first["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(first["lines"], [VillagerRules.dialogue_line(june, VillagerRules.RelationshipLevel.STRANGER)])
    assert_eq(first["points_gained"], 1)

    var repeat := session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(repeat["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(repeat["points_gained"], 0)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 1)

func test_favourite_gift_consumes_exactly_one_crop() -> void:
    var session := GameSession.new()
    var june := VillagerRules.VillagerId.RESIDENT
    session.set("_harvested_counts", [2, 0, 0])
    var result := session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))
    assert_eq(result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(result["lines"], [VillagerRules.gift_line(june, GameRules.CropKind.TURNIP)])
    assert_eq(result["points_gained"], 5)
    assert_eq(result["gift_reaction"], &"favourite")
    assert_eq(session.snapshot()["harvested"][&"turnip"], 1)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 5)
```

Add complete-snapshot atomicity for guard order:

`DAY_SUMMARY_PENDING -> NOT_AT_VILLAGER -> GIFT_ALREADY_GIVEN -> INSUFFICIENT_CROPS -> mutation`.

Also assert a normal non-favourite gift grants `3`, snapshot relationship dictionaries are deeply isolated, and duplicate gift consumes nothing.

- [ ] **Step 2: Write RED full progression/reset tests on bare `GameSession`**

Use a bare session fixture and seed three carried Turnips through the existing private field used only in this unit suite:

```gdscript
func test_june_reaches_close_friend_and_special_sequence_once() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var june := VillagerRules.VillagerId.RESIDENT
    session.set("_harvested_counts", [3, 0, 0])

    for expected_points in [6, 12]:
        assert_eq(session.talk_to(june, WorldContract.villager_cell(june))["code"], GameRules.CommandCode.VILLAGER_TALKED)
        assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["code"], GameRules.CommandCode.CROP_GIFTED)
        assert_eq(session.snapshot()["relationships"][&"resident"]["points"], expected_points)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_false(session.snapshot()["relationships"][&"resident"]["talked_today"])
        assert_false(session.snapshot()["relationships"][&"resident"]["gifted_today"])
        assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    assert_eq(session.talk_to(june, WorldContract.villager_cell(june))["points_gained"], 1)
    assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["points_gained"], 5)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 18)
    assert_false(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

    var special := session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(special["points_gained"], 0)
    assert_true(special["close_friend_sequence"])
    assert_eq(special["lines"], VillagerRules.close_friend_dialogue_lines(june))
    assert_true(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

    var normal := session.talk_to(june, WorldContract.villager_cell(june))
    assert_false(normal["close_friend_sequence"])
    assert_eq(normal["lines"], [VillagerRules.dialogue_line(june, VillagerRules.RelationshipLevel.CLOSE_FRIEND)])
```

Extend the existing pending-summary test so social commands return `DAY_SUMMARY_PENDING` without mutation. Extend the existing Day 14 rejected-sleep test so relationship points/daily flags/one-time flag remain unchanged.

- [ ] **Step 3: Run the verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: session tests fail because social state/methods do not exist.

- [ ] **Step 4: Add relationship state and isolated snapshot projection**

Add:

```gdscript
var _relationships: Array[Dictionary] = []
```

Initialize exactly one entry per `VillagerId` in `_init()`:

```gdscript
for _id in range(VillagerRules.VillagerId.size()):
    _relationships.append({
        "points": 0,
        "talked_today": false,
        "gifted_today": false,
        "close_friend_dialogue_seen": false,
    })
```

Add `_relationships_snapshot()` and include it as the only new top-level social field in `snapshot()`.

- [ ] **Step 5: Implement the narrow social result helpers and commands**

```gdscript
func _social_failure(code: GameRules.CommandCode) -> Dictionary:
    return {"code": code, "lines": [], "points_gained": 0, "gift_reaction": &"", "close_friend_sequence": false}

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

Implement `talk_to` in this exact order: `_active_day_failure()`; target match; first-talk mutation; derived level; one-time Close Friend sequence; normal line.

Implement `gift_crop` in this exact order: `_active_day_failure()`; target match; duplicate-gift guard; carried-crop guard; consume one crop; set daily flag; add policy points; return oracle gift line/reaction.

- [ ] **Step 6: Reset only daily flags in successful `sleep()`**

Immediately before the existing successful `DAY_ADVANCED` return:

```gdscript
for relationship in _relationships:
    relationship["talked_today"] = false
    relationship["gifted_today"] = false
```

Do not reset in failed sleep or `acknowledge_morning_summary()`.

- [ ] **Step 7: Run the verifier and verify GREEN**

```bash
./tools/verify-clean.sh
```

- [ ] **Step 8: Commit Task 2**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore HPA-594 relationship rules"
```

---

### Task 3: Insert villager geometry into the exact live scene contracts

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Produces `WorldContract.villager_cell(id)`, `villager_footprint(id)`, and `villager_at(cell)`.
- Consumes retained `res://assets/sprites/proof-villagers.png`.
- Preserves `Entities` as the one Y-sort-enabled `CanvasItem`.

- [ ] **Step 1: Write RED exact geometry and authored-child tests**

In `tests/headless/world_shell_smoke.gd`, extend the current exact `StaticCollision` names after `ShippingCollision`:

```gdscript
var collision_names := [
    "TreeCollision",
    "BuildingCollision",
    "ShippingCollision",
    "VillagerShopkeeperCollision",
    "VillagerFarmerCollision",
    "VillagerResidentCollision",
    "PerimeterTop",
    "PerimeterRight",
    "PerimeterBottom",
    "PerimeterLeft",
]
```

Extend the exact authored entity prefix:

```gdscript
var entity_names := [
    "Player",
    "Tree",
    "Building",
    "Shipping",
    "VillagerShopkeeper",
    "VillagerFarmer",
    "VillagerResident",
]
for cell in WorldContract.farm_cells():
    entity_names.append("FarmCrop_%d_%d" % [cell.x, cell.y])
```

For each villager assert:

```gdscript
var cell := WorldContract.villager_cell(id)
_expect_vec2(villager.position, WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)), "villager center")
_expect_polygon(collision.polygon, WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id)), "villager collision")
```

Also assert texture path `res://assets/sprites/proof-villagers.png`, `hframes == 3`, `frame == id`, offset `Vector2(0,-24)`, and the existing shared entity z-index.

In `tests/integration/test_gameplay_shell.gd`, change:

```gdscript
assert_eq(entities.get_child_count(), 7 + cells.size())
```

and change crop-root indexing from `4 + index` to `7 + index`. Add a table-driven target assertion using `_place_target(world, WorldContract.villager_cell(id))` and `player.current_target_cell()`.

- [ ] **Step 2: Run the verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: exact node lists/counts/geometry fail because villager nodes/contracts are absent.

- [ ] **Step 3: Add the narrow `WorldContract` geometry**

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

Keep Shop/Bed/Shipping as their current explicit constants; do not create an interaction table.

- [ ] **Step 4: Add exactly three collision and three entity nodes to `world.tscn`**

Add one ext-resource for `proof-villagers.png`. Under `StaticCollision`, insert the three named `CollisionPolygon2D` nodes after `ShippingCollision`. Under `Entities`, insert `VillagerShopkeeper`, `VillagerFarmer`, `VillagerResident` after `Shipping`, each with one `Sprite2D` using the retained sheet, `hframes=3`, frame `0/1/2`, offset `(0,-24)`.

Do not paste cell-center pixels into tests. Let `WorldShell._ready()` set both villager roots and collision polygons from the logical contract:

```gdscript
var villager_names := ["VillagerShopkeeper", "VillagerFarmer", "VillagerResident"]
var collision_node_names := [
    "VillagerShopkeeperCollision",
    "VillagerFarmerCollision",
    "VillagerResidentCollision",
]
for id in range(VillagerRules.VillagerId.size()):
    var root := $Entities.get_node(villager_names[id]) as Node2D
    root.position = WorldMath.grid_to_world(
        Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5)
    )
    var collision := $StaticCollision.get_node(collision_node_names[id]) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))
```

Add no NPC script, `Area2D`, animation, reusable NPC scene, or second Y-sort root.

- [ ] **Step 5: Run world smoke and then the full verifier**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/verify-clean.sh
```

Expected: static geometry, retained asset, exact child lists, `7 + farm_cells.size()` runtime count, targeting, Y-sort, and all previous tests pass.

- [ ] **Step 6: Commit Task 3**

```bash
git add scripts/world/world_contract.gd scenes/world/world.tscn scripts/world/world_shell.gd tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 village residents"
```

---

### Task 4: Add the focused dialogue component and direct `WorldShell` routing

**Files:**
- Create: `scenes/ui/dialogue_panel.tscn` in the existing `scenes/ui/` directory
- Create: `scripts/ui/dialogue_panel.gd`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- `DialoguePanel` emits `gift_requested(villager_id: int, crop_kind: int)` and `close_requested`.
- `DialoguePanel.present(villager_id: int, social: Dictionary, snapshot: Dictionary) -> void`.
- `DialoguePanel.refresh_snapshot(snapshot: Dictionary) -> void`.
- `DialoguePanel.close_panel() -> void`.
- `GameHud` adds `open_dialogue`, `update_dialogue`, `close_dialogue`, and forwards `gift_requested`.
- `WorldShell` adds `_finish_social_command(villager_id: int, result: Dictionary) -> void` and `_on_gift_requested`.

- [ ] **Step 1: Write RED shell routing/gate tests without private session injection**

Use the existing `_place_target()` helper:

```gdscript
func test_villager_interaction_opens_panel_and_gates_world_input() -> void:
    var world := _world()
    var june := VillagerRules.VillagerId.RESIDENT
    await _place_target(world, WorldContract.villager_cell(june))

    world.interact()

    var panel := world.get_node("GameHud/HudRoot/DialoguePanel") as DialoguePanel
    assert_true(panel.visible)
    assert_false(world._world_input_enabled)
    assert_eq((panel.get_node("Panel/Name") as Label).text, VillagerRules.display_name(june))
    assert_eq((panel.get_node("Panel/Line") as Label).text, VillagerRules.dialogue_line(june, VillagerRules.RelationshipLevel.STRANGER))
    assert_eq(world._session.snapshot()["relationships"][&"resident"]["points"], 1)

    var before := world._session.snapshot()
    world.select_action_slot(2)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)
```

Add close and `ui_cancel` cases that assert `_world_input_enabled` returns true via `modal_state_changed` with no manual gate refresh.

- [ ] **Step 2: Write RED `DialoguePanel` focus/multiline/gift-button tests with synthetic presentation data**

Do not seed relationship/inventory private fields through `WorldShell`. Exercise transient UI state directly:

```gdscript
func test_dialogue_panel_multiline_uses_native_focus_and_cancel_guard() -> void:
    var world := _world()
    var hud := _hud(world)
    var june := VillagerRules.VillagerId.RESIDENT
    var social := {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": VillagerRules.close_friend_dialogue_lines(june),
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": true,
    }
    var snapshot := world._session.snapshot()
    snapshot["relationships"][&"resident"]["points"] = 18
    snapshot["relationships"][&"resident"]["level"] = &"close_friend"

    hud.open_dialogue(june, social, snapshot)
    await get_tree().process_frame
    var panel := world.get_node("GameHud/HudRoot/DialoguePanel") as DialoguePanel
    var continue_button := panel.get_node("Panel/Continue") as Button
    assert_eq(get_viewport().gui_get_focus_owner(), continue_button)
```

Send one pressed/released `ui_accept` action and assert only the second special line appears. Send `ui_cancel` on the first line and assert the panel remains open; after the last line assert cancel closes and restores the gate.

For gift rendering, pass a synthetic snapshot with exactly one harvested Turnip and `gifted_today=false`, present a one-line June payload, then assert exactly one `Give Turnip` native `Button` exists and receives focus. Connect to `GameHud.gift_requested`, press the button once, and assert the forwarded `(june, TURNIP)` signal. Do **not** assert session mutation in this UI-only fixture; Task 2 owns mutation/consumption semantics.

- [ ] **Step 3: Run the verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: dialogue scene/routing/focus tests fail because the component is absent.

- [ ] **Step 4: Create one `DialoguePanel` component under existing `$HudRoot`**

`scenes/ui/dialogue_panel.tscn` uses this exact node contract:

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

The script stores only transient presentation fields:

```gdscript
class_name DialoguePanel
extends Control

signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested

var _villager_id := -1
var _lines: Array[String] = []
var _line_index := 0
var _points_gained := 0
var _gift_reaction: StringName = &""
var _close_friend_sequence := false
var _snapshot: Dictionary = {}
```

`present()` copies the payload/snapshot, resets `_line_index = 0`, renders, and defers focus. `refresh_snapshot()` updates only the read-only snapshot and rerenders gift availability. Build dynamic gift buttons with `Button.new()` so native focus remains enabled; create one per carried crop count > 0 only after the final line and only when `gifted_today` is false.

- [ ] **Step 5: Implement native progression/focus/cancel**

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

`_focus_primary()` chooses Continue, then first gift button, then Close. Do not handle `ui_accept`; focused native buttons own it.

- [ ] **Step 6: Integrate dialogue into the existing `GameHud` modal stack**

Instance `DialoguePanel` under `GameHud/HudRoot` in the existing `scenes/ui/game_hud.tscn`.

Add:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
@onready var _dialogue_panel := $HudRoot/DialoguePanel as DialoguePanel
```

Forward its gift signal; connect `close_requested` to `close_dialogue()`. Extend `has_blocking_modal()` with `_dialogue_panel.visible`.

`open_dialogue()` hides Shop/Shipping/Sleep, calls `present()`, and emits `modal_state_changed`. `update_dialogue()` calls `present()` with the new social payload while remaining blocked. `close_dialogue()` hides the panel and emits `modal_state_changed` once. When Morning Summary becomes visible, hide dialogue beside the existing three non-summary panels.

Do not create a second CanvasLayer/modal stack and do not change the existing action/seed disable mechanism.

- [ ] **Step 7: Route direct villager interaction and reuse existing feedback**

Connect `hud.gift_requested` in `WorldShell._ready()`.

In `_process`, resolve the target once. If `WorldContract.villager_at(target) >= 0`, show `"<Name> — E"`; otherwise preserve Shop/Bed/Shipping hints.

In `interact()` route villager before existing explicit cases:

```gdscript
var target: Variant = player.current_target_cell()
var villager_id := WorldContract.villager_at(target)
if villager_id >= 0:
    _finish_social_command(villager_id, _session.talk_to(villager_id, target))
elif target == WorldContract.SHOP_CELL:
    hud.open_shop()
elif target == WorldContract.SHIPPING_CELL:
    hud.open_shipping()
elif target == WorldContract.BED_CELL:
    hud.open_sleep_confirmation()
else:
    hud.show_feedback(GameRules.CommandCode.NOTHING_TO_INTERACT)
```

`_on_gift_requested(villager_id, crop_kind)` reads `player.current_target_cell()` and calls `gift_crop`; the session still validates the target.

Use exactly one sibling finish helper:

```gdscript
func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())
```

Add the four codes to the existing `GameHud.show_feedback()` match:

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

Reuse current `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` messages. Add no second feedback system.

- [ ] **Step 8: Run the verifier and verify GREEN**

```bash
./tools/verify-clean.sh
```

Expected: target -> panel routing, native focus/cancel, synthetic gift-button forwarding, input-gate restoration, old modals, farming/economy suites, and all smokes pass.

- [ ] **Step 9: Commit Task 4**

```bash
git add scenes/ui/dialogue_panel.tscn scripts/ui/dialogue_panel.gd scenes/ui/game_hud.tscn scripts/ui/game_hud.gd scripts/world/world_shell.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 dialogue and gifting"
```

---

### Task 5: Close the social slice with lean scene acceptance and handoff docs

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `README.md`
- Modify: `CLAUDE.md` (`AGENTS.md` remains its symlink)

**Interfaces:**
- Consumes all Task 1–4 seams.
- Adds no new gameplay or test API.

- [ ] **Step 1: Add table-driven all-villager routing acceptance**

No full three-day shell progression test is added; Task 2 already proves that state machine directly.

```gdscript
func test_all_villagers_route_through_same_direct_interaction_path() -> void:
    var world := _world()
    var hud := _hud(world)
    for id in range(VillagerRules.VillagerId.size()):
        await _place_target(world, WorldContract.villager_cell(id))
        world.interact()
        var panel := world.get_node("GameHud/HudRoot/DialoguePanel") as DialoguePanel
        assert_true(panel.visible)
        assert_eq((panel.get_node("Panel/Name") as Label).text, VillagerRules.display_name(id))
        assert_eq((panel.get_node("Panel/Role") as Label).text, VillagerRules.role_label(id))
        assert_eq((panel.get_node("Panel/Line") as Label).text, VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER))
        hud.close_dialogue()
        assert_true(world._world_input_enabled)
```

This test uses only the public shell interaction path and ordinary first-talk state; it does not seed private `WorldShell` session state.

- [ ] **Step 2: Update README with only player-facing social behavior**

Add near existing controls:

```text
- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.
```

Do not duplicate villager cells/collision values in README.

- [ ] **Step 3: Update the canonical handoff target, preserving the AGENTS symlink**

`AGENTS.md` is the 9-byte symlink whose blob target is `CLAUDE.md`. Modify `CLAUDE.md` only; do not replace the symlink.

Update its Runtime/Architecture/Current boundary text to state:

```text
- E interacts with villagers as well as shop/bed/shipping.
- VillagerRules owns frozen HPA-595 social content and pure relationship policy.
- GameSession owns relationship points, daily talk/gift flags, and close_friend_dialogue_seen.
- WorldContract owns the three static villager cells/footprints.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- GameHud.has_blocking_modal() remains the single world-input gate.
- HPA-598 owns serialization; HPA-594 defines no save schema.
```

- [ ] **Step 4: Run the final committed-tree gate**

```bash
./tools/verify-clean.sh
git diff --check origin/main...HEAD
git status --short
git diff --name-only origin/main...HEAD
```

Expected: verifier passes; `git diff --check` is empty; working tree is clean after commit; diff is limited to HPA-594 policy/state/world/UI/tests/player docs/handoff plus the two planning documents. `AGENTS.md` remains a symlink to `CLAUDE.md`. No persistence, NPC AI/schedule, generic framework, dependency, workflow, browser/Tauri runtime, or unrelated refactor appears.

- [ ] **Step 5: Commit Task 5**

```bash
git add tests/integration/test_gameplay_shell.gd README.md CLAUDE.md
git commit -m "docs: complete HPA-594 social handoff"
```

- [ ] **Step 6: Re-run verification on committed HEAD**

```bash
./tools/verify-clean.sh
git status --short
```

Expected: verifier passes and the worktree is clean. Keep this PR as the single HPA-594 delivery PR; move it from draft to ready only after implementation and review.
