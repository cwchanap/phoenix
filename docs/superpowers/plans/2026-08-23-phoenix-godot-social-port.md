# Phoenix Godot Social Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's shipped three-villager talk, gifting, relationship, and one-time Close Friend dialogue loop on the live Godot HPA-589 gameplay shell.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority. Add one pure `VillagerRules` sibling, extend `WorldContract` for fixed villager geometry, author three static villager roots/collisions in the existing world scene, route `E` directly through `WorldShell`, and add one code-built stateful `DialoguePanel` class under the existing `GameHud/HudRoot`. `GameHud.has_blocking_modal()` remains the only world-input gate.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-social-port-design.md`

**Behavior oracle:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global Constraints

- Deliver HPA-594 in this same branch and PR; do not open a second implementation PR.
- Preserve current farm/economy/day behavior and the existing direct Shop/Shipping/Bed routing.
- HPA-595 is immutable behavior/content: Mira `(6,5)` / Potato, Rowan `(3,5)` / Pumpkin, June `(9,5)` / Turnip; talk `+1`; gift `+3`; favourite bonus `+2`; Friend `12`; Close Friend `18`; all spoken lines exact.
- `GameSession` owns mutable relationships; `WorldContract` owns geometry; snapshots never echo villager cells.
- Existing farming/economy methods keep returning `GameRules.CommandCode`; the narrow social result Dictionary stays local to `talk_to`/`gift_crop`.
- Add only `VILLAGER_TALKED`, `CROP_GIFTED`, `NOT_AT_VILLAGER`, `GIFT_ALREADY_GIVEN`; reuse `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING`.
- `GameHud.has_blocking_modal()` remains the sole world-input gate. No interaction registry, NPC manager, social service, event bus, or second input manager.
- `DialoguePanel` is a separate class but code-built from `GameHud._build_modals()`; do not add `dialogue_panel.tscn`.
- Do not add a production/debug test seam. Existing integration tests may inspect `world._session` as they already do.
- `AGENTS.md` remains the symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` remains unchanged and is a **post-commit** gate because it starts from `git archive HEAD`.

---

### Task 0: Provision worktree-visible GUT

**Files:**
- No committed files.
- Local only: gitignored `addons/gut/`.

**Interfaces:**
- Produces local GUT 9.7.1 visible to uncommitted worktree changes.
- Reuses the exact tarball/checksum from `tools/verify-clean.sh`.

- [ ] **Step 1: Confirm Godot 4.7.1**

```bash
godot --version
```

Expected: standard non-.NET Godot `4.7.1`.

- [ ] **Step 2: Provision the pinned GUT archive locally**

```bash
mkdir -p addons/gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz \
  -o /tmp/phoenix-gut-9.7.1.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut-9.7.1.tgz" \
  | shasum -a 256 -c -
tar -xzf /tmp/phoenix-gut-9.7.1.tgz --strip-components=3 \
  -C addons/gut "Gut-9.7.1/addons/gut"
```

Expected: checksum passes and `addons/gut/gut_cmdln.gd` exists. `/addons/` is already ignored; never commit it.

- [ ] **Step 3: Prove the worktree runner against the current baseline**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: current baseline passes. Use these direct commands for every pre-commit RED/GREEN cycle. Use `./tools/verify-clean.sh` only after commits.

---

### Task 1: Freeze the HPA-595 social oracle

**Files:**
- Create: `scripts/game/villager_rules.gd`
- Create: `tests/unit/test_villager_rules.gd`
- Modify: `scripts/game/game_rules.gd`

**Interfaces:**
- Produces `VillagerRules.VillagerId`, `RelationshipLevel`, exact content tables, and pure accessors/policy helpers.
- Produces four new `GameRules.CommandCode` values only.

- [ ] **Step 1: Write RED identity/policy tests**

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

    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Mira")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Rowan")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.RESIDENT), "June")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.RESIDENT), GameRules.CropKind.TURNIP)

    assert_eq(VillagerRules.TALK_POINTS, 1)
    assert_eq(VillagerRules.GIFT_POINTS, 3)
    assert_eq(VillagerRules.FAVOURITE_GIFT_BONUS, 2)
    assert_eq(VillagerRules.relationship_level(11), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(12), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(17), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(18), VillagerRules.RelationshipLevel.CLOSE_FRIEND)
```

- [ ] **Step 2: Pin every spoken string once**

Add `test_spoken_content_is_verbatim_hpa_595_oracle()` with this table:

```gdscript
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
```

For each entry assert all three relationship lines and both special lines through `VillagerRules`; assert normal/favourite gift lines for each villager. Mutate one returned special array and assert a second call still returns the oracle content.

- [ ] **Step 3: Run worktree RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: failure because `VillagerRules` is absent.

- [ ] **Step 4: Add only the four social codes**

```gdscript
VILLAGER_TALKED,
CROP_GIFTED,
NOT_AT_VILLAGER,
GIFT_ALREADY_GIVEN,
```

- [ ] **Step 5: Implement `VillagerRules`**

Create:

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
```

Copy the exact oracle strings from Step 2 into `NORMAL_DIALOGUE`, `CLOSE_FRIEND_DIALOGUE`, `NORMAL_GIFT_LINES`, and `FAVOURITE_GIFT_LINES`. Implement direct static accessors for key/name/role/favourite, relationship key/display/derivation, dialogue lookup, favourite detection, gift points, and gift line. `close_friend_dialogue_lines()` must return a fresh typed `Array[String]`.

- [ ] **Step 6: Run worktree GREEN, commit, then verify committed HEAD**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git add scripts/game/game_rules.gd scripts/game/villager_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: freeze HPA-594 villager rules"
./tools/verify-clean.sh
```

---

### Task 2: Add fixed villager geometry and authored scene roots

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- Consumes `VillagerRules.VillagerId` from Task 1.
- Produces `WorldContract.villager_cell(id)`, `villager_footprint(id)`, and `villager_at(cell)` for later session/shell tasks.
- Preserves `Entities` as the single Y-sort owner.

- [ ] **Step 1: Inventory every affected hard-coded offset**

```bash
grep -nE 'index \+ 3|4 \+ cells\.size\(\)|4 \+ index' \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
```

Expected: perimeter `index + 3`, both `4 + cells.size()` expressions, and crop index `4 + index` appear. Update every occurrence in this task.

- [ ] **Step 2: Write RED world-contract and exact scene tests**

Extend the smoke collision list:

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

Update perimeter lookup to:

```gdscript
var collision := static_collision.get_node(collision_names[index + 6]) as CollisionPolygon2D
```

Extend authored `Entities` order after `Shipping` with `VillagerShopkeeper`, `VillagerFarmer`, `VillagerResident`. Assert each root position against:

```gdscript
WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5))
```

and each polygon against `WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))`. Also pin retained texture, `hframes == 3`, frame `== id`, offset `(0,-24)`, and shared z-index.

In `test_gameplay_shell.gd`, update all three arithmetic contracts:

```gdscript
assert_eq(entities.get_child_count(), 7 + cells.size())
if entities.get_child_count() < 7 + cells.size():
    return
...
var crop_root := entities.get_child(7 + index) as Node2D
```

- [ ] **Step 3: Run worktree RED**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: missing geometry/nodes fail.

- [ ] **Step 4: Extend `WorldContract`**

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

- [ ] **Step 5: Author roots in `world.tscn`; derive only collisions in `_ready()`**

Add the retained villager sheet as an ext-resource. Insert collision placeholders after `ShippingCollision`. Insert direct entity roots after `Shipping`:

```text
VillagerShopkeeper  position = Vector2(416, 192)  frame = 0
VillagerFarmer      position = Vector2(320, 144)  frame = 1
VillagerResident    position = Vector2(512, 240)  frame = 2
```

Each root has one `Sprite2D`, `hframes = 3`, `offset = Vector2(0,-24)`.

Do **not** assign root positions in `WorldShell._ready()`; the scene is authored and the smoke proves it matches the logical contract. Derive only collision polygons:

```gdscript
var villager_collision_names := [
    "VillagerShopkeeperCollision",
    "VillagerFarmerCollision",
    "VillagerResidentCollision",
]
for id in range(VillagerRules.VillagerId.size()):
    var collision := static_collision.get_node(villager_collision_names[id]) as CollisionPolygon2D
    collision.polygon = WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))
```

- [ ] **Step 6: Run worktree GREEN, commit, then verify committed HEAD**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git add scripts/world/world_contract.gd scenes/world/world.tscn scripts/world/world_shell.gd \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 village residents"
./tools/verify-clean.sh
```

---

### Task 3: Add authoritative relationship state and session commands

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes `VillagerRules` and `WorldContract.villager_cell()` from Tasks 1–2.
- Produces snapshot `relationships` plus `talk_to`/`gift_crop`.

- [ ] **Step 1: Add one typed inventory-seeding helper beside existing farm helpers**

```gdscript
func _seed_harvested(session: GameSession, counts: Array[int]) -> void:
    session.set("_harvested_counts", counts)
    var harvested: Dictionary = session.snapshot()["harvested"]
    assert_eq(harvested[&"turnip"], counts[GameRules.CropKind.TURNIP])
    assert_eq(harvested[&"potato"], counts[GameRules.CropKind.POTATO])
    assert_eq(harvested[&"pumpkin"], counts[GameRules.CropKind.PUMPKIN])
```

Never pass an untyped array literal to `session.set("_harvested_counts", ...)`.

- [ ] **Step 2: Write RED starter/guard/real-single-gift tests**

Extend the starter snapshot with one top-level `relationships` dictionary keyed by `&"shopkeeper"`, `&"farmer"`, `&"resident"`, each containing points `0`, derived level `&"stranger"`, both daily flags `false`, and `close_friend_dialogue_seen=false`.

Use the existing `_grow_and_harvest_turnip()` helper for a real single-crop gift:

```gdscript
func test_favourite_gift_consumes_one_real_harvested_crop() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _grow_and_harvest_turnip(session)
    var june := VillagerRules.VillagerId.RESIDENT
    var result := session.gift_crop(
        june,
        GameRules.CropKind.TURNIP,
        WorldContract.villager_cell(june),
    )
    assert_eq(result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(result["points_gained"], 5)
    assert_eq(result["lines"], [VillagerRules.gift_line(june, GameRules.CropKind.TURNIP)])
    assert_eq(session.snapshot()["harvested"][&"turnip"], 0)
```

Also cover first talk `+1`, repeat talk `+0`, normal gift `+3`, favourite `+5`, snapshot isolation, and complete-snapshot atomicity for:

```text
DAY_SUMMARY_PENDING → NOT_AT_VILLAGER → GIFT_ALREADY_GIVEN → INSUFFICIENT_CROPS → mutation
```

- [ ] **Step 3: Write RED three-day progression with typed fixture**

```gdscript
func test_june_reaches_close_friend_and_special_sequence_once() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded: Array[int] = [3, 0, 0]
    _seed_harvested(session, seeded)
    var june := VillagerRules.VillagerId.RESIDENT

    for expected_points in [6, 12]:
        assert_eq(session.talk_to(june, WorldContract.villager_cell(june))["points_gained"], 1)
        assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["points_gained"], 5)
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

    var normal := session.talk_to(june, WorldContract.villager_cell(june))
    assert_false(normal["close_friend_sequence"])
    assert_eq(
        normal["lines"],
        [VillagerRules.dialogue_line(june, VillagerRules.RelationshipLevel.CLOSE_FRIEND)],
    )
```

Extend existing pending-summary and Day 14 tests so social commands/state follow the same boundary behavior.

- [ ] **Step 4: Run worktree RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: social session tests fail because relationship state/methods do not exist.

- [ ] **Step 5: Implement mutable relationships and isolated snapshot projection**

Add one `_relationships: Array[Dictionary]`, initialized one entry per `VillagerId`. Add `_relationships_snapshot()` that derives relationship level and returns fresh dictionaries. Add only `relationships` to the top-level snapshot.

- [ ] **Step 6: Implement narrow social results and commands**

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

`talk_to`: pending summary → exact target → first-talk mutation → derived level → one-time special → normal line.

`gift_crop`: pending summary → exact target → duplicate gift → inventory guard → consume one → set daily flag → add policy points → oracle line/reaction.

- [ ] **Step 7: Reset only daily flags inside successful `sleep()`**

Immediately before the existing successful `DAY_ADVANCED` return:

```gdscript
for relationship in _relationships:
    relationship["talked_today"] = false
    relationship["gifted_today"] = false
```

- [ ] **Step 8: Run worktree GREEN, commit, then verify committed HEAD**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore HPA-594 relationship rules"
./tools/verify-clean.sh
```

---

### Task 4: Add code-built dialogue UI, direct routing, and one real gift round-trip

**Files:**
- Create: `scripts/ui/dialogue_panel.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- `DialoguePanel` emits `gift_requested(villager_id, crop_kind)` and `close_requested`.
- `GameHud` creates it from `_build_modals()`, includes it in `has_blocking_modal()`, and forwards gift signals.
- `WorldShell` adds `_finish_social_command` and `_on_gift_requested`; existing `_finish_command` remains untouched for non-social commands.

- [ ] **Step 1: Write RED shell open/close/gate test using existing `_panel` and `_place_target` helpers**

```gdscript
func test_villager_interaction_opens_dialogue_and_gates_world_input() -> void:
    var world := _world()
    var hud := _hud(world)
    var june := VillagerRules.VillagerId.RESIDENT
    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()

    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    assert_true(panel.visible)
    assert_false(world._world_input_enabled)
    assert_eq((panel.get_node("Panel/Name") as Label).text, "June")

    var before := world._session.snapshot()
    world.select_action_slot(2)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)

    hud.close_dialogue()
    assert_true(world._world_input_enabled)
    assert_null(get_viewport().gui_get_focus_owner())
```

Add an equivalent `ui_cancel` close case; it must also leave no GUI focus owner.

- [ ] **Step 2: Write RED synthetic multiline native-focus test**

Use `hud.open_dialogue()` with `VillagerRules.close_friend_dialogue_lines(june)` and a copied snapshot whose June display points/level are set to 18/Close Friend. Assert Continue owns focus, one pressed/released `ui_accept` advances exactly one line, cancel is consumed before the final special line, and final close clears focus.

- [ ] **Step 3: Write RED real gift-button round-trip**

```gdscript
func test_gift_button_round_trips_through_session_and_updates_open_panel() -> void:
    var world := _world()
    var hud := _hud(world)
    var june := VillagerRules.VillagerId.RESIDENT
    var seeded: Array[int] = [1, 0, 0]
    world._session.set("_harvested_counts", seeded)
    assert_eq(world._session.snapshot()["harvested"][&"turnip"], 1)

    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()
    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    var gift_buttons := panel.get_node("Panel/GiftButtons") as VBoxContainer
    assert_eq(gift_buttons.get_child_count(), 1)
    var give_turnip := gift_buttons.get_child(0) as Button
    assert_eq(give_turnip.text, "Give Turnip")

    give_turnip.pressed.emit()

    assert_eq(world._session.snapshot()["harvested"][&"turnip"], 0)
    assert_eq(world._session.snapshot()["relationships"][&"resident"]["points"], 6)
    assert_eq(
        (panel.get_node("Panel/Line") as Label).text,
        VillagerRules.gift_line(june, GameRules.CropKind.TURNIP),
    )
    assert_true((panel.get_node("Panel/Feedback") as Label).text.contains("Favourite gift"))
    assert_eq(gift_buttons.get_child_count(), 0)
```

No production test API is added; this is the same direct `_session` access style already present in the integration suite.

- [ ] **Step 4: Run worktree RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

- [ ] **Step 5: Implement `DialoguePanel` as one code-built class**

Create `scripts/ui/dialogue_panel.gd`:

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

`_ready()` builds exactly:

```text
DialoguePanel
└── Panel
    ├── Name
    ├── Role
    ├── Relationship
    ├── Line
    ├── Feedback
    ├── GiftStatus
    ├── GiftButtons
    ├── Continue
    └── Close
```

`Feedback` renders `+N relationship point(s)` and `Favourite gift!` / `Gift accepted.` for the current social payload. `GiftStatus` renders only `Gift already given today` / `No harvested crops to give`. Dynamic gift buttons are normal `Button.new()` controls, not `GameHud._add_button()`.

- [ ] **Step 6: Implement focus/progression/close behavior**

```gdscript
func _focus_primary() -> void:
    if _line_index < _lines.size() - 1:
        ($Panel/Continue as Button).grab_focus()
        return
    var gifts := $Panel/GiftButtons as VBoxContainer
    if gifts.get_child_count() > 0:
        (gifts.get_child(0) as Button).grab_focus()
        return
    ($Panel/Close as Button).grab_focus()

func close_panel() -> void:
    var focus_owner := get_viewport().gui_get_focus_owner()
    if focus_owner != null and is_ancestor_of(focus_owner):
        focus_owner.release_focus()
    visible = false
```

Handle visible `ui_cancel` in `_unhandled_input()`: consume it while a Close Friend sequence still has another line, otherwise emit `close_requested`. Do not handle `ui_accept`; native buttons own it. This matters because Godot `ui_accept` includes Space while Phoenix also maps Space to `use_action`; the modal gate blocks world actions while open and `close_panel()` removes lingering GUI focus afterward.

- [ ] **Step 7: Instantiate the class from the existing modal builder**

In `GameHud._build_modals()`:

```gdscript
_dialogue_panel = DialoguePanel.new()
_dialogue_panel.name = "DialoguePanel"
_root.add_child(_dialogue_panel)
_dialogue_panel.gift_requested.connect(func(villager_id: int, crop_kind: int) -> void:
    gift_requested.emit(villager_id, crop_kind)
)
_dialogue_panel.close_requested.connect(close_dialogue)
_dialogue_panel.visible = false
```

Extend `has_blocking_modal()` with dialogue visibility. Opening dialogue hides Shop/Shipping/Sleep and emits `modal_state_changed`; closing releases focus and emits the same signal. Morning Summary hides dialogue with the other non-summary panels.

- [ ] **Step 8: Route direct social interaction and reuse current feedback**

Connect `hud.gift_requested` in `WorldShell._ready()`. In `_process`, show `"<Name> — E"` for a targeted villager. In `interact()`, route villager before current Shop/Shipping/Bed cases:

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

Use one sibling helper:

```gdscript
func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())
```

`_on_gift_requested()` re-reads `player.current_target_cell()` before `gift_crop`, matching buy/deposit style. Add the four social codes to the existing `GameHud.show_feedback()` match; reuse current insufficient-crop/pending-summary messages.

- [ ] **Step 9: Run worktree GREEN, commit, then verify committed HEAD**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git add scripts/ui/dialogue_panel.gd scripts/ui/game_hud.gd scripts/world/world_shell.gd \
  tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 dialogue and gifting"
./tools/verify-clean.sh
```

---

### Task 5: Complete routing acceptance and handoff docs

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes Tasks 1–4.
- Adds no gameplay or test API.

- [ ] **Step 1: Add table-driven all-villager routing acceptance**

```gdscript
func test_all_villagers_route_through_same_direct_interaction_path() -> void:
    var world := _world()
    var hud := _hud(world)
    for id in range(VillagerRules.VillagerId.size()):
        await _place_target(world, WorldContract.villager_cell(id))
        world.interact()
        var panel := _panel(hud, "DialoguePanel") as DialoguePanel
        assert_true(panel.visible)
        assert_eq((panel.get_node("Panel/Name") as Label).text, VillagerRules.display_name(id))
        assert_eq((panel.get_node("Panel/Role") as Label).text, VillagerRules.role_label(id))
        assert_eq(
            (panel.get_node("Panel/Line") as Label).text,
            VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER),
        )
        hud.close_dialogue()
        assert_true(world._world_input_enabled)
        assert_null(get_viewport().gui_get_focus_owner())
```

Do not add a three-day shell journey; Task 3 already proves that state machine directly.

- [ ] **Step 2: Update README with only player-facing behavior**

```text
- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.
```

- [ ] **Step 3: Update `CLAUDE.md`, preserving the `AGENTS.md` symlink**

Record:

```text
- E interacts with villagers as well as shop/bed/shipping.
- VillagerRules owns frozen HPA-595 content and pure relationship policy.
- GameSession owns relationship points, daily talk/gift flags, and close_friend_dialogue_seen.
- WorldContract owns the three static villager cells/footprints.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- GameHud.has_blocking_modal() remains the single world-input gate.
- HPA-598 owns serialization; HPA-594 defines no save schema.
```

Do not replace `AGENTS.md`.

- [ ] **Step 4: Run final worktree verification**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

Expected: all worktree tests pass and `git diff --check` is empty.

- [ ] **Step 5: Commit and run the canonical committed-HEAD gate**

```bash
git add tests/integration/test_gameplay_shell.gd README.md CLAUDE.md
git commit -m "docs: complete HPA-594 social handoff"
./tools/verify-clean.sh
git diff --check origin/main...HEAD
git status --short
git diff --name-only origin/main...HEAD
```

Expected: archive verifier passes; worktree is clean; `AGENTS.md` remains a symlink to `CLAUDE.md`; diff is limited to HPA-594 policy/state/world/UI/tests/docs plus these planning documents.

## Execution Rules

- Task 0 is mandatory: pre-commit RED/GREEN must observe the worktree.
- After each task's worktree GREEN, commit first, then run `./tools/verify-clean.sh` against committed HEAD.
- Typed `Array[int]` fixtures must assert the seeded snapshot immediately.
- Do not weaken gift guards or add a debug API to compensate for a broken test fixture.
