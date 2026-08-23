# Phoenix Godot Social Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Phoenix's shipped three-villager talk, gifting, relationship, and one-time Close Friend dialogue loop on the live Godot HPA-589 gameplay shell.

**Architecture:** Extend the existing `GameSession` as the only mutable gameplay authority. Add one pure `VillagerRules` content/policy sibling, keep authored villager geometry in `WorldContract`, add three static villager roots/collisions to the existing world scene, route `E` directly through `WorldShell`, and add one code-built stateful `DialoguePanel` class under the existing `GameHud/HudRoot`. Reuse `GameHud.has_blocking_modal()` as the only world-input gate.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, GUT 9.7.1, existing SceneTree headless smokes, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-23-phoenix-godot-social-port-design.md`

**Behavior oracle:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global Constraints

- Deliver HPA-594 in this same branch and PR; do not open a second implementation PR.
- Implement against current Godot paths: `scripts/game/*`, `scripts/world/*`, `scripts/ui/*`, `scenes/world/world.tscn`, `scenes/ui/game_hud.tscn`, `tests/unit/`, `tests/integration/`, `tests/headless/`, and `tools/verify-clean.sh`.
- Preserve the current world, farm/economy/day behavior, shop `(6,7)`, bed `(6,8)`, shipping `(6,10)`, and path `x=3..9,y=6`.
- Villagers remain Mira `(6,5)`, Rowan `(3,5)`, June `(9,5)` with `0.6×0.6` footprints and retained `res://assets/sprites/proof-villagers.png` frames `0/1/2`.
- HPA-595 is the immutable content oracle: talk `+1`, gift `+3`, favourite bonus `+2`, Friend `12`, Close Friend `18`, names, roles, favourites, and every spoken line stay exact.
- `GameSession` owns mutable relationships; `WorldContract` owns geometry; snapshots do not echo villager cells.
- Existing farming/economy methods keep returning `GameRules.CommandCode`; the narrow social Dictionary remains local to `talk_to`/`gift_crop`.
- Add only `VILLAGER_TALKED`, `CROP_GIFTED`, `NOT_AT_VILLAGER`, and `GIFT_ALREADY_GIVEN`; reuse `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING`.
- Successful `sleep()` resets only `talked_today`/`gifted_today`; failed sleep and pending summary do not.
- `GameHud.has_blocking_modal()` remains the sole world-input gate; no registry, event bus, NPC manager, social service, or second input manager.
- Dialogue buttons use native focus. `DialoguePanel` is a class built in code from `GameHud._build_modals()`; do not add `dialogue_panel.tscn`.
- Do not add a production/debug test seam. Tests may inspect the existing `world._session` just as the current integration suite already does.
- `AGENTS.md` remains the symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` remains unchanged and is a **post-commit** gate only because it starts from `git archive HEAD`.

---

### Task 0: Provision a worktree-visible GUT runner

**Files:**
- No committed files.
- Local only: gitignored `addons/gut/`.

**Interfaces:**
- Produces a local GUT 9.7.1 checkout visible to uncommitted worktree changes.
- Reuses the exact tarball/checksum already pinned by `tools/verify-clean.sh`.
- Establishes the rule: direct worktree commands for RED/GREEN; `./tools/verify-clean.sh` only after commit.

- [ ] **Step 1: Confirm the expected Godot runtime**

```bash
godot --version
```

Expected: `4.7.1` standard non-.NET build.

- [ ] **Step 2: Install GUT into the already-gitignored local addon directory**

```bash
mkdir -p addons/gut
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz -o /tmp/phoenix-gut-9.7.1.tgz
echo "6da99c4e9228d9bec3fb4bd1730a487770a989f0f511dac82a2897a964613385  /tmp/phoenix-gut-9.7.1.tgz" \
  | shasum -a 256 -c -
tar -xzf /tmp/phoenix-gut-9.7.1.tgz --strip-components=3 \
  -C addons/gut "Gut-9.7.1/addons/gut"
```

Expected: checksum passes and `addons/gut/gut_cmdln.gd` exists. `/addons/` is already ignored; do not commit it.

- [ ] **Step 3: Prove the direct worktree runner is healthy before changing code**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: current baseline passes. This command set sees the worktree directly; unlike `verify-clean.sh`, it does not archive `HEAD` first.

---

### Task 1: Freeze the HPA-595 oracle in `VillagerRules`

**Files:**
- Create: `scripts/game/villager_rules.gd`
- Create: `tests/unit/test_villager_rules.gd`
- Modify: `scripts/game/game_rules.gd`

**Interfaces:**
- Produces `VillagerRules.VillagerId`, `RelationshipLevel`, frozen content arrays, and pure accessors/policy helpers.
- Produces four new `GameRules.CommandCode` values only.
- Consumes `GameRules.CropKind`; no mutable session/world state.

- [ ] **Step 1: Write RED oracle tests**

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

    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Mira")
    assert_eq(VillagerRules.role_label(VillagerRules.VillagerId.SHOPKEEPER), "Seed-shop keeper")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Rowan")
    assert_eq(VillagerRules.role_label(VillagerRules.VillagerId.FARMER), "Neighbouring farmer")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)
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
```

Add one table-driven `test_spoken_content_is_verbatim_hpa_595_oracle()` containing the exact 9 normal relationship lines, 6 Close Friend sequence lines, and 6 normal/favourite gift replies from the spec. Mutate one returned Close Friend array and assert a second call returns the original two lines.

- [ ] **Step 2: Run the worktree suite and verify RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: failure because `VillagerRules` is absent.

- [ ] **Step 3: Add the four social command codes**

Append only:

```gdscript
VILLAGER_TALKED,
CROP_GIFTED,
NOT_AT_VILLAGER,
GIFT_ALREADY_GIVEN,
```

Do not add a generic result base type or migrate existing commands.

- [ ] **Step 4: Implement the pure content/policy module**

Create `scripts/game/villager_rules.gd` with:

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

Fill the four dialogue/gift arrays with the exact oracle strings from the design spec and add direct static helpers:

```gdscript
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

static func close_friend_dialogue_lines(id: VillagerId) -> Array[String]:
    var result: Array[String] = []
    for line in CLOSE_FRIEND_DIALOGUE[id]:
        result.append(line)
    return result
```

Also implement `relationship_key`, `relationship_display_name`, `dialogue_line`, `is_favourite`, `gift_points`, and `gift_line` as direct array lookups/pure helpers.

- [ ] **Step 5: Run worktree GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: all GUT tests pass against uncommitted worktree changes.

- [ ] **Step 6: Commit Task 1**

```bash
git add scripts/game/game_rules.gd scripts/game/villager_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: freeze HPA-594 villager rules"
```

- [ ] **Step 7: Verify committed HEAD**

```bash
./tools/verify-clean.sh
```

Expected: archive verifier passes the newly committed Task 1 content.

---

### Task 2: Add authoritative relationship state and session commands

**Files:**
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces snapshot field `relationships`, keyed by `VillagerRules.villager_key(id)`.
- Produces `talk_to(id, target_cell) -> Dictionary` and `gift_crop(id, crop, target_cell) -> Dictionary`.
- Every social result has exactly `code`, `lines`, `points_gained`, `gift_reaction`, `close_friend_sequence`.

- [ ] **Step 1: Add a typed test-seeding helper beside the existing farm helpers**

In `tests/unit/test_game_session.gd`:

```gdscript
func _seed_harvested(session: GameSession, counts: Array[int]) -> void:
    session.set("_harvested_counts", counts)
    var harvested: Dictionary = session.snapshot()["harvested"]
    assert_eq(harvested[&"turnip"], counts[GameRules.CropKind.TURNIP])
    assert_eq(harvested[&"potato"], counts[GameRules.CropKind.POTATO])
    assert_eq(harvested[&"pumpkin"], counts[GameRules.CropKind.PUMPKIN])
```

Never call `session.set("_harvested_counts", [1, 0, 0])` with an untyped literal. For the multi-gift fixture, bind the typed value first:

```gdscript
var seeded: Array[int] = [3, 0, 0]
_seed_harvested(session, seeded)
```

- [ ] **Step 2: Write RED starter/guard/gift tests**

Extend the exact starter snapshot with one new top-level `relationships` dictionary. Add wrong-target/repeat-talk tests and use the already-existing `_grow_and_harvest_turnip()` helper for a real single-crop gift where possible:

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

Add complete-snapshot atomicity for:

```text
DAY_SUMMARY_PENDING → NOT_AT_VILLAGER → GIFT_ALREADY_GIVEN → INSUFFICIENT_CROPS → mutation
```

Also cover first talk `+1`, repeat talk `+0`, normal gift `+3`, favourite gift `+5`, duplicate gift consumes nothing, and relationship snapshot deep-copy isolation.

- [ ] **Step 3: Write RED full progression/reset test with the typed helper**

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

Extend existing pending-summary and Day 14 rejection tests to prove social state is blocked/preserved correctly.

- [ ] **Step 4: Run worktree RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: social session tests fail because state/methods do not exist.

- [ ] **Step 5: Implement relationships and narrow social results**

Add one `_relationships: Array[Dictionary]`, initialize one entry per villager, and project a fresh `relationships` dictionary in `snapshot()`.

Use local helpers:

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

Implement `talk_to` in order: pending summary → exact target → first-talk mutation → derived level → one-time Close Friend sequence → normal line.

Implement `gift_crop` in order: pending summary → exact target → duplicate gift → carried-crop guard → consume one crop → set daily flag → add policy points → oracle gift line/reaction.

- [ ] **Step 6: Reset only daily social flags in successful `sleep()`**

Immediately before the existing successful `DAY_ADVANCED` return:

```gdscript
for relationship in _relationships:
    relationship["talked_today"] = false
    relationship["gifted_today"] = false
```

Do not reset on failed sleep or `acknowledge_morning_summary()`.

- [ ] **Step 7: Run worktree GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

- [ ] **Step 8: Commit and verify committed HEAD**

```bash
git add scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: restore HPA-594 relationship rules"
./tools/verify-clean.sh
```

Expected: archive verifier includes and passes Task 2.

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
- Reuses retained `proof-villagers.png`.
- Preserves `Entities` as the one Y-sort-enabled `CanvasItem`.

- [ ] **Step 1: Inventory all hard-coded offsets before editing**

```bash
grep -nE 'index \+ 3|4 \+ cells\.size\(\)|4 \+ index' \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
```

Expected: perimeter lookup `index + 3`, both `4 + cells.size()` expressions, and crop index `4 + index` are visible. Update every occurrence in this task.

- [ ] **Step 2: Write RED exact geometry/scene tests**

Extend the smoke collision list to:

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

Update the perimeter lookup:

```gdscript
var collision := static_collision.get_node(collision_names[index + 6]) as CollisionPolygon2D
```

Extend authored entity names with `VillagerShopkeeper`, `VillagerFarmer`, `VillagerResident` immediately after `Shipping`. For each villager assert:

```gdscript
_expect_vec2(
    villager.position,
    WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5)),
    "villager %d center" % id,
)
_expect_polygon(
    collision.polygon,
    WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id)),
    "villager %d collision" % id,
)
```

Also assert retained texture, `hframes == 3`, frame `== id`, offset `(0,-24)`, and shared entity z-index.

In `test_gameplay_shell.gd`, update **both** count expressions and crop indexing:

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

Expected: missing geometry/nodes fail directly from the worktree tests.

- [ ] **Step 4: Add the narrow world contract**

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

Keep Shop/Bed/Shipping as their current explicit constants.

- [ ] **Step 5: Author three villager roots and collision placeholders in `world.tscn`**

Add the retained villager texture as an ext-resource. Add collision nodes after `ShippingCollision`. Add direct `Entities` children after `Shipping` with authored positions:

```text
VillagerShopkeeper  position = Vector2(416, 192)  frame = 0
VillagerFarmer      position = Vector2(320, 144)  frame = 1
VillagerResident    position = Vector2(512, 240)  frame = 2
```

Each contains one `Sprite2D` with `hframes = 3` and `offset = Vector2(0, -24)`.

Do **not** assign villager root positions from `WorldShell._ready()`; the smoke must catch scene drift. In `_ready()`, derive only the three collision polygons exactly like tree/shipping:

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

- [ ] **Step 6: Run worktree GREEN**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

- [ ] **Step 7: Commit and verify committed HEAD**

```bash
git add scripts/world/world_contract.gd scenes/world/world.tscn scripts/world/world_shell.gd \
  tests/headless/world_shell_smoke.gd tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 village residents"
./tools/verify-clean.sh
```

---

### Task 4: Add code-built `DialoguePanel` and direct social routing

**Files:**
- Create: `scripts/ui/dialogue_panel.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`

**Interfaces:**
- `DialoguePanel` emits `gift_requested(villager_id: int, crop_kind: int)` and `close_requested`.
- `DialoguePanel.present(villager_id, social, snapshot)`, `refresh_snapshot(snapshot)`, and `close_panel()`.
- `GameHud` creates the panel in `_build_modals()`, includes it in `has_blocking_modal()`, and forwards gift requests.
- `WorldShell` adds `_finish_social_command` and `_on_gift_requested` while keeping the existing `_finish_command` for non-social commands.

- [ ] **Step 1: Write RED shell open/close/input-gate test using the existing helpers**

Use `_place_target()` and `_panel(hud, name)`:

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
    assert_eq((panel.get_node("Panel/Name") as Label).text, VillagerRules.display_name(june))
    assert_eq(
        (panel.get_node("Panel/Line") as Label).text,
        VillagerRules.dialogue_line(june, VillagerRules.RelationshipLevel.STRANGER),
    )

    var before := world._session.snapshot()
    world.select_action_slot(2)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)

    hud.close_dialogue()
    assert_true(world._world_input_enabled)
    assert_null(get_viewport().gui_get_focus_owner())
```

Add an equivalent `ui_cancel` close case and assert focus is also null afterward.

- [ ] **Step 2: Write RED synthetic multiline/focus test**

Present the exact Close Friend lines without mutating shell relationship state:

```gdscript
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
```

Assert Continue owns focus. Send one pressed/released `ui_accept` `InputEventAction` and assert exactly the second line appears. On line one, `ui_cancel` stays inside the panel; on the final line it closes and leaves `gui_get_focus_owner() == null`.

- [ ] **Step 3: Write RED real-data gift round-trip**

This intentionally uses the integration suite's existing direct access to `world._session`; no production test API is added:

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

This covers the actual `DialoguePanel → GameHud → WorldShell → GameSession → GameHud → DialoguePanel` path.

- [ ] **Step 4: Run worktree RED**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Expected: dialogue/routing tests fail because the class/wiring is absent.

- [ ] **Step 5: Build the stateful panel class in code**

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

In `_ready()`, build exactly:

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

`Feedback` owns `+N relationship point(s)` plus `Favourite gift!` / `Gift accepted.`. `GiftStatus` owns only `Gift already given today` / `No harvested crops to give`. Build gift buttons with `Button.new()` so they keep normal focus; do not use `GameHud._add_button()`.

- [ ] **Step 6: Implement progression/focus/close behavior**

```gdscript
func _focus_primary() -> void:
    if _line_index < _lines.size() - 1:
        $Panel/Continue.grab_focus()
        return
    var gifts := $Panel/GiftButtons as VBoxContainer
    if gifts.get_child_count() > 0:
        (gifts.get_child(0) as Button).grab_focus()
        return
    $Panel/Close.grab_focus()

func close_panel() -> void:
    var focus_owner := get_viewport().gui_get_focus_owner()
    if focus_owner != null and is_ancestor_of(focus_owner):
        focus_owner.release_focus()
    visible = false
```

`_unhandled_input()` handles only visible `ui_cancel`: consume it on a non-final Close Friend line, otherwise emit `close_requested`. Do not handle `ui_accept`; native focused Buttons own it.

- [ ] **Step 7: Instantiate it from the existing modal builder**

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

Extend `has_blocking_modal()` with `_dialogue_panel.visible`. `open_dialogue()` hides Shop/Shipping/Sleep then calls `present()` and emits `modal_state_changed`. `update_dialogue()` calls `present()` while staying blocked. `close_dialogue()` calls `close_panel()` then emits `modal_state_changed` once. Morning Summary hides dialogue beside the existing three non-summary modals.

- [ ] **Step 8: Route direct villager interaction and reuse current feedback**

Connect `hud.gift_requested` in `WorldShell._ready()`.

In `_process`, show `"<Name> — E"` when `WorldContract.villager_at(target) >= 0`; otherwise preserve current hints.

In `interact()` route villager before Shop/Shipping/Bed:

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

Use one sibling finish helper:

```gdscript
func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())
```

`_on_gift_requested()` re-reads `player.current_target_cell()` and calls `gift_crop`, matching buy/deposit handler style.

Add the four social cases to the existing `GameHud.show_feedback()` match; reuse existing insufficient-crop and pending-summary messages.

- [ ] **Step 9: Run worktree GREEN**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: shell routing, real gift round-trip, focus/cancel, existing farming/economy tests, and world smoke all pass against worktree changes.

- [ ] **Step 10: Commit and verify committed HEAD**

```bash
git add scripts/ui/dialogue_panel.gd scripts/ui/game_hud.gd scripts/world/world_shell.gd \
  tests/integration/test_gameplay_shell.gd
git commit -m "feat: restore HPA-594 dialogue and gifting"
./tools/verify-clean.sh
```

---

### Task 5: Complete scene acceptance and handoff documentation

**Files:**
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes Tasks 1–4.
- Adds no new gameplay/test API.

- [ ] **Step 1: Add table-driven all-villager routing acceptance**

```gdscript
func test_all_villagers_route_through_the_same_direct_interaction_path() -> void:
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

No three-day shell journey is added; Task 2 already proves that state machine.

- [ ] **Step 2: Update README with only player-facing behavior**

Add near existing controls:

```text
- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.
```

Do not duplicate geometry in README.

- [ ] **Step 3: Update canonical handoff target only**

`AGENTS.md` is the symlink to `CLAUDE.md`. Modify `CLAUDE.md` to record:

```text
- E now interacts with villagers as well as shop/bed/shipping.
- VillagerRules owns frozen HPA-595 content and pure relationship policy.
- GameSession owns relationship points, daily talk/gift flags, and close_friend_dialogue_seen.
- WorldContract owns the three static villager cells/footprints.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- GameHud.has_blocking_modal() remains the single world-input gate.
- HPA-598 owns serialization; HPA-594 defines no save schema.
```

Do not replace or duplicate `AGENTS.md`.

- [ ] **Step 4: Run final worktree verification before commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

Expected: all worktree tests pass and `git diff --check` is empty.

- [ ] **Step 5: Commit Task 5**

```bash
git add tests/integration/test_gameplay_shell.gd README.md CLAUDE.md
git commit -m "docs: complete HPA-594 social handoff"
```

- [ ] **Step 6: Run the canonical committed-HEAD gate**

```bash
./tools/verify-clean.sh
git diff --check origin/main...HEAD
git status --short
git diff --name-only origin/main...HEAD
```

Expected: archive verifier passes; diff check is empty; worktree is clean; `AGENTS.md` remains a symlink to `CLAUDE.md`; changed files are limited to HPA-594 policy/state/world/UI/tests/docs plus the two planning documents. Keep this PR as the single HPA-594 delivery PR.

## Execution Notes

- Task 0 is mandatory before any RED/GREEN work; otherwise `verify-clean.sh` will validate only the previous commit.
- Re-run the direct GUT/worktree command after every code edit group before committing.
- Run `./tools/verify-clean.sh` only after each task commit to prove reproducibility from committed HEAD.
- If a typed test fixture is needed, make the `Array[int]` type explicit and assert it landed immediately.
- Do not weaken gift guards or add a debug API to compensate for a bad test fixture.
