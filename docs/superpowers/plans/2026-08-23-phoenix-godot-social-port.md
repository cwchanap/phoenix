# Phoenix Godot Social Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's three-villager talk, gifting, relationship, and one-time Close Friend dialogue loop in the existing Godot gameplay shell.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority, add one pure `VillagerRules` content/policy module, and keep authored villager cells/footprints in `WorldContract`. Render the retained villager sprite frames as static direct children of the existing Y-sorted `Entities`; route facing-derived `E` interactions directly through `WorldShell`; and add one focused `DialoguePanel` under `GameHud` so the existing modal gate remains the only world-input lock.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1 through the existing archive verifier, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-social-port-design.md`

## Global Constraints

- Deliver HPA-594 in this same branch and PR; do not open a second implementation PR.
- Preserve the 12×12 world, 64×32 projection, origin `(384,0)`, current player/camera/farm/economy behavior, shop `(6,7)`, bed `(6,8)`, shipping `(6,10)`, and village path `x=3..9,y=6`.
- Villagers remain Mira `(6,5)`, Rowan `(3,5)`, June `(9,5)` with `0.6×0.6` footprints and `proof-villagers.png` frames `0/1/2`.
- Social values remain talk `+1`, gift `+3`, favourite bonus `+2`, Friend `12`, Close Friend `18`.
- Mira likes Potato, Rowan likes Pumpkin, June likes Turnip; all shipped HPA-595 dialogue stays exact.
- Talking and gifting consume no time or stamina.
- `GameSession` owns mutable relationships; relationship level is derived from points and never stored redundantly.
- `WorldContract` owns villager geometry; do not duplicate villager cells into the session snapshot.
- Existing farming/economy commands continue returning `GameRules.CommandCode` directly. The narrow social result Dictionary is local to talk/gift and is not a generic command-result migration.
- Successful `sleep()` resets only `talked_today` and `gifted_today`; failed sleep, Day 14 rejection, and pending Morning Summary do not reset social state.
- `GameHud.has_blocking_modal()` remains the sole world-input gate. Do not add another lock registry, input manager, event bus, or generic interaction registry.
- Dialogue buttons use native focusable Godot `Button` behavior; do not use the HUD helper that sets `FOCUS_NONE`.
- Keep one `./tools/verify-clean.sh` verification entry point and the current CI job; add no new E2E framework.
- No NPC schedules/movement/pathfinding, homes, quests, romance, portraits, branching dialogue, dialogue/cutscene/event engine, generic item system, persistence/save format, migration, tutorial/finale behavior, localization framework, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactor.

---

### Task 1: Freeze villager content/policy and social command codes

**Files:**
- Create: `scripts/game/villager_rules.gd`
- Create: `tests/unit/test_villager_rules.gd`
- Modify: `scripts/game/game_rules.gd`

**Interfaces:**
- Produces: `VillagerRules.VillagerId`, `RelationshipLevel`, frozen content tables, relationship helpers, gift helpers.
- Produces `GameRules.CommandCode`: `VILLAGER_TALKED`, `CROP_GIFTED`, `NOT_AT_VILLAGER`, `GIFT_ALREADY_GIVEN`.
- Consumes: `GameRules.CropKind`; no mutable state or world nodes.

- [ ] **Step 1: Write RED tests for the closed social table**

Create `tests/unit/test_villager_rules.gd`:

```gdscript
extends GutTest

func test_identity_favourites_and_table_sizes_are_exact() -> void:
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
        assert_eq(table.size(), 3)

    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.SHOPKEEPER), &"shopkeeper")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Mira")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)
    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.FARMER), &"farmer")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Rowan")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)
    assert_eq(VillagerRules.villager_key(VillagerRules.VillagerId.RESIDENT), &"resident")
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.RESIDENT), "June")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.RESIDENT), GameRules.CropKind.TURNIP)

func test_thresholds_and_gains_are_exact() -> void:
    assert_eq(VillagerRules.relationship_level(0), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(11), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(12), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(17), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(18), VillagerRules.RelationshipLevel.CLOSE_FRIEND)
    assert_eq(VillagerRules.TALK_POINTS, 1)
    assert_eq(VillagerRules.GIFT_POINTS, 3)
    assert_eq(VillagerRules.FAVOURITE_GIFT_BONUS, 2)
    assert_eq(VillagerRules.gift_points(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.TURNIP), 5)
    assert_eq(VillagerRules.gift_points(VillagerRules.VillagerId.RESIDENT, GameRules.CropKind.POTATO), 3)
```

Add exact-string assertions for all three Stranger/Friend/Close Friend lines, all six Close Friend sequence lines, and all six normal/favourite gift replies from the design spec. Mutate an Array returned by `close_friend_dialogue_lines()` and assert a second call still returns the original two strings.

- [ ] **Step 2: Run the clean verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: GUT fails because `VillagerRules` does not exist.

- [ ] **Step 3: Add only the four new social command codes**

Append to `GameRules.CommandCode`:

```gdscript
VILLAGER_TALKED,
CROP_GIFTED,
NOT_AT_VILLAGER,
GIFT_ALREADY_GIVEN,
```

Do not add a generic `ok` result, success classifier, result base type, or code-to-string framework.

- [ ] **Step 4: Implement `VillagerRules` with the exact frozen content**

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

Expected: all new villager-rule tests, existing unit/integration tests, and all headless smokes pass.

- [ ] **Step 6: Commit Task 1**

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
- Produces snapshot field `relationships`, keyed by villager key.
- Produces `talk_to(id: VillagerRules.VillagerId, target_cell: Variant) -> Dictionary`.
- Produces `gift_crop(id: VillagerRules.VillagerId, crop: GameRules.CropKind, target_cell: Variant) -> Dictionary`.
- Every social result has exactly `code`, `lines`, `points_gained`, `gift_reaction`, `close_friend_sequence`.

- [ ] **Step 1: Write RED starter-state/deep-copy tests**

Extend the current exact snapshot contract:

```gdscript
func test_new_session_has_exact_starter_relationships() -> void:
    var snapshot := GameSession.new().snapshot()
    assert_eq(snapshot["relationships"], {
        &"shopkeeper": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
        &"farmer": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
        &"resident": {"points": 0, "level": &"stranger", "talked_today": false, "gifted_today": false, "close_friend_dialogue_seen": false},
    })

func test_relationship_snapshot_is_deeply_isolated() -> void:
    var session := GameSession.new()
    var snapshot := session.snapshot()
    snapshot["relationships"][&"resident"]["points"] = 99
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 0)
```

Update the existing snapshot size/key assertion to add only `relationships`; do not add villager cells, active dialogue, focus, or node references.

- [ ] **Step 2: Write RED talk/gift guard and value tests**

Pin talk behavior:

```gdscript
func test_talk_requires_target_and_repeat_talk_gains_zero() -> void:
    var session := GameSession.new()
    var june := VillagerRules.VillagerId.RESIDENT
    var before := session.snapshot()
    assert_eq(session.talk_to(june, Vector2i.ZERO)["code"], GameRules.CommandCode.NOT_AT_VILLAGER)
    assert_eq(session.snapshot(), before)

    var first := session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(first["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(first["lines"], ["It is quieter here than the road makes it look."])
    assert_eq(first["points_gained"], 1)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 1)

    var repeat := session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(repeat["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(repeat["points_gained"], 0)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 1)
```

Pin gifting with isolated carried-inventory setup, matching the private-state style already used by this unit suite:

```gdscript
func test_gift_consumes_one_and_favourite_is_five_points() -> void:
    var session := GameSession.new()
    var june := VillagerRules.VillagerId.RESIDENT
    session.set("_harvested_counts", [2, 0, 0])

    var result := session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))
    assert_eq(result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(result["points_gained"], 5)
    assert_eq(result["gift_reaction"], &"favourite")
    assert_eq(session.snapshot()["harvested"][&"turnip"], 1)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 5)
```

Add complete-snapshot atomicity cases for exact guard order:

`DAY_SUMMARY_PENDING → NOT_AT_VILLAGER → GIFT_ALREADY_GIVEN → INSUFFICIENT_CROPS → mutation`.

Also test a normal non-favourite gift gains `3` and returns `&"normal"`.

- [ ] **Step 3: Write RED threshold/one-time-dialogue/daily-reset tests**

Drive June for three social days using three preloaded Turnips and the real `sleep()`/`acknowledge_morning_summary()` boundary:

```text
Day 1: talk +1, favourite gift +5 => 6 Stranger
sleep/ack
Day 2: talk +1, favourite gift +5 => 12 Friend
sleep/ack
Day 3: talk +1 => 13, favourite gift +5 => 18 Close Friend
same-day follow-up talk => +0 and exact two-line Close Friend sequence
next talk => +0 and only normal Close Friend line
```

Assert the gift crossing to 18 does **not** set `close_friend_dialogue_seen`; the subsequent talk does. Assert successful sleep resets only `talked_today`/`gifted_today`, while points and the one-time flag persist. Extend the existing Day 14 rejection test to prove failed sleep preserves relationship state.

- [ ] **Step 4: Run verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: relationship/session tests fail because social state and commands do not exist.

- [ ] **Step 5: Implement one mutable relationship entry per villager**

Add:

```gdscript
var _relationships: Array[Dictionary] = []
```

and initialize exactly three entries in `_init()`:

```gdscript
for _id in range(VillagerRules.VillagerId.size()):
    _relationships.append({
        "points": 0,
        "talked_today": false,
        "gifted_today": false,
        "close_friend_dialogue_seen": false,
    })
```

Add `_relationships_snapshot()` that returns a fresh Dictionary keyed by `VillagerRules.villager_key(id)` and derives `level` via `relationship_key(relationship_level(points))`.

- [ ] **Step 6: Implement the narrow social result and commands**

Use two local helpers:

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

Implement `talk_to` in this order: `_active_day_failure()`; exact target match with `WorldContract.villager_cell(id)`; first-talk mutation; derived level; one-time Close Friend sequence; otherwise one normal line.

Implement `gift_crop` in this order: `_active_day_failure()`; exact target; duplicate-gift guard; carried-crop guard; consume one `_harvested_counts[crop]`; set `gifted_today`; add `VillagerRules.gift_points`; return `gift_line` and `&"normal"`/`&"favourite"`.

- [ ] **Step 7: Reset only daily flags inside successful `sleep()`**

After the existing day/economy transition has succeeded and before `DAY_ADVANCED` returns:

```gdscript
for relationship in _relationships:
    relationship["talked_today"] = false
    relationship["gifted_today"] = false
```

Do not reset in failed sleep or `acknowledge_morning_summary()`.

- [ ] **Step 8: Run verifier and verify GREEN**

```bash
./tools/verify-clean.sh
```

- [ ] **Step 9: Commit Task 2**

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
- Produces `WorldContract.villager_cell(id)`, `villager_footprint(id)`, `villager_at(cell)`.
- Consumes retained `res://assets/sprites/proof-villagers.png`; no asset generation.
- Preserves `Entities` as the one Y-sort-enabled `CanvasItem`.

- [ ] **Step 1: Write RED geometry/scene tests**

In the headless smoke pin:

```gdscript
var expected_cells := [Vector2i(6, 5), Vector2i(3, 5), Vector2i(9, 5)]
var expected_footprints := [
    Rect2(6.2, 5.2, 0.6, 0.6),
    Rect2(3.2, 5.2, 0.6, 0.6),
    Rect2(9.2, 5.2, 0.6, 0.6),
]
for id in range(VillagerRules.VillagerId.size()):
    if not _expect_vec2i(WorldContract.villager_cell(id), expected_cells[id], "villager cell %d" % id):
        return
    if not _expect(WorldContract.villager_footprint(id) == expected_footprints[id], "villager footprint %d" % id):
        return
    if not _expect(WorldContract.villager_at(expected_cells[id]) == id, "villager lookup %d" % id):
        return
```

Extend `StaticCollision` expected children with `VillagerShopkeeperCollision`, `VillagerFarmerCollision`, `VillagerResidentCollision` and compare each polygon against `WorldMath.footprint_to_polygon(...)`.

Extend `Entities` authored order to:

```text
Player, Tree, Building, Shipping,
VillagerShopkeeper, VillagerFarmer, VillagerResident,
then the nine runtime FarmCrop_* roots
```

For each villager assert exact cell-center position, `proof-villagers.png`, `hframes=3`, frame=`id`, offset `(0,-24)`, and the shared entity z-index.

In `test_gameplay_shell.gd`, table-drive `_place_target(world, WorldContract.villager_cell(id))` and assert `player.current_target_cell()` equals that cell.

- [ ] **Step 2: Run verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: missing villager geometry/collision/entity assertions fail.

- [ ] **Step 3: Add the narrow world contract**

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

Keep Shop/Bed/Shipping as their current explicit constants; do not create a generic interaction map.

- [ ] **Step 4: Add exactly three collisions and three static entity roots**

In `world.tscn`, add `proof-villagers.png` as one texture resource. Add the three collision nodes under the existing `StaticCollision` and three direct `Entities` children:

```text
VillagerShopkeeper position=(416,192), frame=0
VillagerFarmer      position=(320,144), frame=1
VillagerResident    position=(512,240), frame=2
```

Each root has one `Sprite2D` with `hframes=3` and `offset=(0,-24)`. Add no NPC script, `Area2D`, animation, reusable NPC scene, or second Y-sort root.

In `WorldShell._ready()`, set each collision polygon from `WorldContract.villager_footprint(id)` exactly like the current tree/shipping collision setup.

- [ ] **Step 5: Run world smoke then full verifier**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/verify-clean.sh
```

Expected: static geometry, retained asset, collision, targeting, Y-sort, and all previous tests pass.

- [ ] **Step 6: Commit Task 3**

```bash
git add scripts/world/world_contract.gd scenes/world/world.tscn scripts/world/world_shell.gd tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 village residents"
```

---

### Task 4: Build focused dialogue/gifting UI and route it through the existing modal gate

**Files:**
- Create: `scenes/ui/dialogue_panel.tscn`
- Create: `scripts/ui/dialogue_panel.gd`
- Modify: `scenes/ui/game_hud.tscn`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- `DialoguePanel` signals: `gift_requested(villager_id: int, crop_kind: int)`, `close_requested`.
- `DialoguePanel.present(villager_id: int, social: Dictionary, snapshot: Dictionary) -> void`.
- `DialoguePanel.refresh_snapshot(snapshot: Dictionary) -> void`.
- `DialoguePanel.close_panel() -> void`.
- `GameHud` adds `open_dialogue`, `update_dialogue`, `close_dialogue`, and forwards `gift_requested`.
- `WorldShell` adds `_finish_social_command(villager_id: int, result: Dictionary) -> void` and `_on_gift_requested`.

- [ ] **Step 1: Write RED panel/input-gate/focus tests**

The scene contract is exactly:

```text
DialoguePanel (Control, initially hidden, full viewport, mouse_filter=STOP)
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

Add an integration test that targets June, calls `world.interact()`, and asserts:

```gdscript
var panel := world.get_node("GameHud/HudRoot/DialoguePanel") as DialoguePanel
assert_true(panel.visible)
assert_false(world._world_input_enabled)
assert_eq((panel.get_node("Panel/Name") as Label).text, "June")
assert_eq((panel.get_node("Panel/Line") as Label).text, "It is quieter here than the road makes it look.")
assert_eq(world._session.snapshot()["relationships"][&"resident"]["points"], 1)
```

While open, assert movement is stopped and `select_action_slot`, `use_selected_action`, and repeated `world.interact()` leave the session unchanged.

Add explicit Close and `ui_cancel` tests; both must restore `_world_input_enabled` through `modal_state_changed`, with no manual gate refresh.

- [ ] **Step 2: Write RED two-line native-focus and gifting tests**

At the integration boundary, seed June at 18 points with `close_friend_dialogue_seen=false`, target June, and interact. Assert `Continue` is `get_viewport().gui_get_focus_owner()`. Push one pressed/released `ui_accept` `InputEventAction`; assert exactly the second special line appears. On the first special line, `ui_cancel` must be handled without closing; after the last line it may close.

For gifting, seed `_harvested_counts = [1,0,0]`, open June, and assert one visible `Give Turnip` native Button receives focus after the final line. Press it once and assert Turnip `1→0`, points `1→6`, reaction `Favourite gift!`, gift response `Turnips are my favourite. Perfect choice.`, and no second gift button remains.

- [ ] **Step 3: Run verifier and verify RED**

```bash
./tools/verify-clean.sh
```

Expected: dialogue scene/routing tests fail because the panel is absent.

- [ ] **Step 4: Create the focused `DialoguePanel`**

Use the exact node contract above and a fixed 640×360-compatible panel layout; do not add a theme system. Script state is only transient presentation:

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

`present()` copies the result/snapshot, resets line index to zero, shows the panel, renders, then defers `_focus_primary()`. `refresh_snapshot()` deep-copies the new snapshot and rerenders without changing line index. `close_panel()` hides the panel and clears transient arrays/dictionaries.

Rebuild `GiftButtons` from current `snapshot["harvested"]`: create one native `Button` per crop count > 0 only after the final line and only if the active relationship has not gifted today. Connect each with `_on_gift_pressed.bind(kind)`.

- [ ] **Step 5: Implement line progression, native focus, and cancel**

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

`_focus_primary()` selects Continue while another line exists, otherwise the first gift button, otherwise Close. Do not handle `ui_accept`; the focused Button owns it.

- [ ] **Step 6: Integrate dialogue into `GameHud` as another existing blocking modal**

Add:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
@onready var _dialogue_panel := $HudRoot/DialoguePanel as DialoguePanel
```

Forward the panel's gift signal and connect `close_requested` to `close_dialogue()`.

Extend `has_blocking_modal()` with `_dialogue_panel.visible`. `open_dialogue()` hides Shop/Shipping/Sleep, presents dialogue, and emits `modal_state_changed`. `update_dialogue()` presents the new social payload while staying blocked. `close_dialogue()` closes then emits `modal_state_changed` once. When Morning Summary becomes visible, force dialogue hidden alongside the existing non-summary panels.

Do not change the existing action/seed disable mechanism; because it already asks `has_blocking_modal()`, dialogue automatically participates.

- [ ] **Step 7: Route direct villager interaction/gifting in `WorldShell`**

Connect `hud.gift_requested` in `_ready()`.

In `_process`, resolve the target once. If `WorldContract.villager_at(target) >= 0`, show `"<Name> — E"`; otherwise preserve Shop/Bed/Shipping hints.

In `interact()`, route villager before the existing explicit Shop/Shipping/Bed cases:

```gdscript
var villager_id := WorldContract.villager_at(target)
if villager_id >= 0:
    _finish_social_command(villager_id, _session.talk_to(villager_id, target))
elif target == WorldContract.SHOP_CELL:
    hud.open_shop()
...
```

`_on_gift_requested(villager_id, crop_kind)` reads `player.current_target_cell()` and calls `gift_crop`. The player is immobile while dialogue is open, but the session still validates the target.

Use one helper only:

```gdscript
func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())
```

Gift failures keep the already-visible panel open because `_refresh_from_session()` does not close it; the normal HUD feedback shows the failure. Add no boolean mode flag and no second interaction abstraction.

- [ ] **Step 8: Add exact HUD feedback for new codes**

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

Reuse current `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` messages.

- [ ] **Step 9: Run verifier and verify GREEN**

```bash
./tools/verify-clean.sh
```

Expected: villager targeting, dialogue/gift UI, native focus, Escape/Close gate restoration, old modals, farming/economy tests, and all smoke scripts pass.

- [ ] **Step 10: Commit Task 4**

```bash
git add scenes/ui/dialogue_panel.tscn scripts/ui/dialogue_panel.gd scenes/ui/game_hud.tscn scripts/ui/game_hud.gd scripts/world/world_shell.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 dialogue and gifting"
```

---

### Task 5: Prove the complete social slice and update handoff docs

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes all HPA-594 seams from Tasks 1–4.
- Produces one deterministic scene-level social acceptance flow and concise project handoff documentation.

- [ ] **Step 1: Add one deterministic full progression integration test**

Use the real `WorldShell.interact()`, visible dialogue gift buttons, and real sleep/ack session transitions. Seed exactly three carried Turnips at the test boundary, then prove:

```text
Day 1: June talk +1; favourite gift +5 => 6 Stranger
sleep + acknowledge => daily flags reset
Day 2: talk +1; favourite gift +5 => 12 Friend
sleep + acknowledge => daily flags reset
Day 3: talk +1 => 13; favourite gift +5 => 18 Close Friend
same-day talk => exact two-line Close Friend sequence, +0
close and reopen => normal Close Friend line only
```

At the end assert all three Turnips are consumed, `close_friend_dialogue_seen=true`, the panel can close, and `_world_input_enabled=true`. Do not regrow crops in this test; HPA-589 already proves farming/growth.

- [ ] **Step 2: Add a table-driven all-villager routing test**

For Mira/Rowan/June, target `WorldContract.villager_cell(id)`, call `world.interact()`, and assert the panel's Name, Role, and Stranger line equal `VillagerRules`. Close between cases and assert world input restores each time.

- [ ] **Step 3: Update README with only player-facing social behavior**

Add these facts near existing controls:

```text
- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.
```

Do not duplicate cells/collision values in README.

- [ ] **Step 4: Update CLAUDE.md with narrow ownership boundaries**

Record exactly:

```text
- VillagerRules owns frozen social content and pure relationship policy.
- GameSession owns relationship points, daily talk/gift flags, and one-time dialogue-seen state.
- WorldContract owns the three static villager cells/footprints.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- GameHud.has_blocking_modal() remains the single world-input gate.
- HPA-598 owns serialization; HPA-594 defines no save schema.
```

- [ ] **Step 5: Run the final clean-archive gate**

```bash
./tools/verify-clean.sh
git diff --check origin/main...HEAD
git status --short
git diff --name-only origin/main...HEAD
```

Expected: verifier passes; `git diff --check` prints nothing; after the final commit `git status --short` is empty; changed runtime files are limited to HPA-594 policy/state/world/UI/tests/docs plus these two planning documents; no persistence layer, NPC AI/schedule, generic dialogue/event framework, dependency, workflow, browser/Tauri runtime, or unrelated refactor appears.

- [ ] **Step 6: Commit Task 5**

```bash
git add tests/integration/test_gameplay_shell.gd README.md CLAUDE.md
git commit -m "docs: complete HPA-594 social handoff"
```

- [ ] **Step 7: Re-run verification on committed HEAD**

```bash
./tools/verify-clean.sh
git status --short
```

Expected: verifier passes and the working tree is clean. Keep this PR as the single HPA-594 delivery PR; move it from draft to ready only after the completed implementation has been reviewed.