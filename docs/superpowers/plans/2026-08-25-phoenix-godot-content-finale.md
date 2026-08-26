# Phoenix Godot Content and Harvest Finale Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Godot farming/economy/social/persistence shell into a self-explanatory 14-day MVP with contextual onboarding, one authored harvest-market finale, deterministic result tiers, and completed-save Continue.

**Architecture:** Keep `GameSession` as the only mutable gameplay authority and `WorldShell` as the direct world/save coordinator. Add one pure `ContentRules` sibling with a single tutorial definition table and result derivation, persist four content facts directly in `GameSession.state()`, route tutorial success through one `_commit()` funnel, extract one shipment-settlement helper, build onboarding as a code-created `Control` like `DialoguePanel`, author one market entity in the existing world, and land the complete Day 14 terminal domain/UI/save/AppRoot path atomically in Task 4. `SaveFileCodec` remains semantic-field-blind schema-v1 transport.

**Tech Stack:** Godot 4.7.1 standard non-.NET, statically typed GDScript, Godot `Control` UI, existing sprite-isometric `TileMapLayer`/Y-sort world, GUT 9.7.1, existing headless SceneTree smokes, FileAccess JSON autosave.

**Spec:** `docs/superpowers/specs/2026-08-25-phoenix-godot-content-finale-design.md`

## Global Constraints

- Deliver HPA-597 implementation on this same branch and PR; do not open a second implementation PR.
- Keep one runtime, one `GameSession`, one concrete `SaveRepository`, one authored world, and one save file.
- Keep `SaveFileCodec.SCHEMA_VERSION == 1`; older development saves missing HPA-597 fields are intentionally incompatible. No migration.
- Preserve starter money/seeds, crop growth/sale values, weather, action costs, and relationship thresholds. HPA-599 owns balance tuning.
- Add one pure `ContentRules` module only. No tutorial/quest/cutscene/event/scoring framework.
- Persist exactly `intro_acknowledged`, tutorial completion flags, lifetime shipped crop counts, and `finale_triggered`.
- Copy all four fields explicitly through both `state()` and the hand-built `snapshot()`.
- Keep tutorial identity/copy/completion mapping in one `ContentRules.TUTORIALS` table.
- Complete tutorial steps only after successful authoritative commands through one `_commit()` funnel; dismissal is transient UI state.
- Normal Day 1–13 sleep and the finale share one `_settle_pending_shipment()` helper.
- Only crops already deposited in the shipping bin count toward the finale. `harvested` inventory is never auto-shipped.
- Task 4 owns every live finale behavior together: finale codes, `_complete_finale()`, market command, Day 14 sleep flip, `WorldShell` handoff/save, `ResultScreen`, AppRoot routing, and `DAY_LIMIT_REACHED` removal.
- Onboarding follows the existing code-built HUD panel pattern; do not add `onboarding_overlay.tscn`.
- `GameHud.has_blocking_modal()` remains the one gameplay-input gate. Opening blocks; TutorialCard does not.
- Completed Continue routes directly to `ResultScreen`; there is no post-game world.
- Final save failure never rolls back the ending. Show it; do not add retry/queue machinery.
- New Game does not proactively delete the slot, matching HPA-598.
- Extend existing GUT/headless seams; no browser hooks, second E2E harness, production test API, or skip-intro flag.
- `AGENTS.md` stays a symlink to `CLAUDE.md`.
- `tools/verify-clean.sh` stays unchanged and is a post-commit gate because it verifies archived `HEAD`.
- Packaging/export verification belongs to HPA-599, not this ticket.

---

### Task 0: Provision worktree GUT and freeze the baseline

**Files:** no committed files; local gitignored `addons/gut/` only.

**Interfaces:** provides the existing direct RED/GREEN runner before commits.

- [ ] **Step 1: Confirm Godot and reuse the verifier's pinned GUT archive/checksum**

```bash
godot --version
sed -n '1,220p' tools/verify-clean.sh
```

Expected: standard non-.NET Godot `4.7.1`. Provision exactly the GUT version/checksum used by `tools/verify-clean.sh` into gitignored `addons/gut/`; do not commit it.

- [ ] **Step 2: Run the current baseline**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: current `main` behavior passes before production edits.

---

### Task 1: Add one pure tutorial/result policy table

**Files:**
- Create: `scripts/game/content_rules.gd`
- Create: `tests/unit/test_content_rules.gd`
- Modify: `scripts/game/villager_rules.gd`
- Modify: `tests/unit/test_villager_rules.gd`

**Interfaces:**
- Produces `ContentRules.TUTORIALS` as the single tutorial ID/copy/completion source.
- Produces `tutorial_keys()`, `initial_tutorial_progress()`, `tutorial_for_code()`, `next_tutorial_prompt()`, and `build_harvest_result()`.
- Extends `VillagerRules` with one `[villager][relationship]` finale-line table and `finale_line()`.
- No mutable state or scene/file access.

- [ ] **Step 1: Write RED tests that pin the single tutorial table**

Create `tests/unit/test_content_rules.gd`:

```gdscript
extends GutTest

func test_tutorial_table_is_exact_and_unique() -> void:
    var expected := [
        {"id": &"farm_basics", "code": GameRules.CommandCode.SOIL_TILLED},
        {"id": &"plant", "code": GameRules.CommandCode.CROP_PLANTED},
        {"id": &"water", "code": GameRules.CommandCode.CROP_WATERED},
        {"id": &"sleep", "code": GameRules.CommandCode.DAY_ADVANCED},
        {"id": &"talk", "code": GameRules.CommandCode.VILLAGER_TALKED},
        {"id": &"buy_seeds", "code": GameRules.CommandCode.SEEDS_PURCHASED},
        {"id": &"harvest", "code": GameRules.CommandCode.CROP_HARVESTED},
        {"id": &"shipping", "code": GameRules.CommandCode.CROP_DEPOSITED},
        {"id": &"gift", "code": GameRules.CommandCode.CROP_GIFTED},
    ]

    assert_eq(ContentRules.TUTORIALS.size(), expected.size())
    var ids: Array[StringName] = []
    for index in expected.size():
        var definition: Dictionary = ContentRules.TUTORIALS[index]
        assert_eq(definition["id"], expected[index]["id"])
        assert_eq(definition["completed_by"], expected[index]["code"])
        assert_ne(String(definition["title"]), "")
        assert_ne(String(definition["body"]), "")
        ids.append(definition["id"])
    assert_eq(ids.duplicate().duplicate(), ids)
    assert_eq(ids.size(), ids.duplicate().size())
```

Replace the last uniqueness assertion with a small dictionary/set census if GDScript Array does not expose a convenient unique operation; the required contract is nine unique IDs and nine unique completion codes.

Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit
```

Expected: RED because `ContentRules` does not exist.

- [ ] **Step 2: Add the one static table and derived identity helpers**

Create `scripts/game/content_rules.gd` with:

```gdscript
class_name ContentRules
extends RefCounted

const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

const TUTORIALS: Array[Dictionary] = [
    {
        "id": &"farm_basics",
        "title": "Prepare the field",
        "body": "Face a farm diamond until the gold outline appears. Press 1 for Hoe, then Space.",
        "completed_by": GameRules.CommandCode.SOIL_TILLED,
    },
    {
        "id": &"plant",
        "title": "Plant a seed",
        "body": "With tilled soil targeted, press 2 for Seeds, then Space.",
        "completed_by": GameRules.CommandCode.CROP_PLANTED,
    },
    {
        "id": &"water",
        "title": "Water the crop",
        "body": "On sunny days, press 3 for Water, then Space on a planted crop.",
        "completed_by": GameRules.CommandCode.CROP_WATERED,
    },
    {
        "id": &"sleep",
        "title": "End the day",
        "body": "When today's work is done, face the bed, press E, and sleep.",
        "completed_by": GameRules.CommandCode.DAY_ADVANCED,
    },
    {
        "id": &"talk",
        "title": "Meet the village",
        "body": "Face Mira, Rowan, or June and press E to talk.",
        "completed_by": GameRules.CommandCode.VILLAGER_TALKED,
    },
    {
        "id": &"buy_seeds",
        "title": "Reinvest",
        "body": "Face the seed counter, press E, and buy seeds to keep planting.",
        "completed_by": GameRules.CommandCode.SEEDS_PURCHASED,
    },
    {
        "id": &"harvest",
        "title": "Harvest",
        "body": "A fully grown crop is ready. Press 4 for Hands, then Space.",
        "completed_by": GameRules.CommandCode.CROP_HARVESTED,
    },
    {
        "id": &"shipping",
        "title": "Ship produce",
        "body": "Carry harvested produce to the shipping bin and deposit it for next-morning income.",
        "completed_by": GameRules.CommandCode.CROP_DEPOSITED,
    },
    {
        "id": &"gift",
        "title": "Give a gift",
        "body": "Open a villager conversation while carrying a crop and choose a gift.",
        "completed_by": GameRules.CommandCode.CROP_GIFTED,
    },
]

static func tutorial_keys() -> Array[StringName]:
    var result: Array[StringName] = []
    for definition in TUTORIALS:
        result.append(definition["id"])
    return result

static func initial_tutorial_progress() -> Dictionary:
    var result: Dictionary = {}
    for definition in TUTORIALS:
        result[definition["id"]] = false
    return result

static func tutorial_for_code(code: GameRules.CommandCode) -> StringName:
    for definition in TUTORIALS:
        if definition["completed_by"] == code:
            return definition["id"]
    return &""
```

Do not create a second `TUTORIAL_KEYS` constant or command mapping.

- [ ] **Step 3: Extend tests so all helper structures derive from the table**

Add:

```gdscript
func test_tutorial_helpers_derive_from_the_table() -> void:
    var expected_ids: Array[StringName] = []
    for definition in ContentRules.TUTORIALS:
        expected_ids.append(definition["id"])
        assert_eq(
            ContentRules.tutorial_for_code(definition["completed_by"]),
            definition["id"],
        )

    assert_eq(ContentRules.tutorial_keys(), expected_ids)
    var progress := ContentRules.initial_tutorial_progress()
    assert_eq(progress.keys().size(), expected_ids.size())
    for id in expected_ids:
        assert_true(progress.has(id))
        assert_false(progress[id])
```

Also assert `tutorial_for_code(GameRules.CommandCode.ACTION_SELECTED) == &""`.

- [ ] **Step 4: Write RED prompt-relevance tests**

Use real `GameSession.new().snapshot()` dictionaries enriched only with the HPA-597 presentation fields required before Task 2 exists. Pin:

- first eligible prompt after intro is `farm_basics`;
- `plant` requires tilled empty soil + a seed;
- `water` requires Sunny + immature unwatered crop and is suppressed by Rain;
- `sleep` follows a watered crop or a Rainy immature crop;
- `talk` and `buy_seeds` are Day 2+; buy also requires Turnip affordability;
- `harvest` requires a mature crop;
- `shipping`/`gift` require harvested inventory;
- excluded ID is skipped without mutating completion;
- `{}` when no relevant incomplete prompt exists.

Example:

```gdscript
var prompt := ContentRules.next_tutorial_prompt(snapshot, [&"talk"])
assert_ne(prompt.get("id", &""), &"talk")
assert_false(snapshot["tutorial"][&"talk"])
```

- [ ] **Step 5: Implement one ordered selector with one relevance match**

Use the table order for precedence:

```gdscript
static func next_tutorial_prompt(
    snapshot: Dictionary,
    excluded: Array[StringName] = [],
) -> Dictionary:
    var progress: Dictionary = snapshot.get("tutorial", {})
    for definition in TUTORIALS:
        var id: StringName = definition["id"]
        if bool(progress.get(id, false)) or excluded.has(id):
            continue
        if _tutorial_relevant(id, snapshot):
            return {
                "id": id,
                "title": definition["title"],
                "body": definition["body"],
            }
    return {}
```

`_tutorial_relevant(id, snapshot)` uses one `match id` and the concrete predicates listed in the spec. Do not introduce predicate objects or a DSL.

- [ ] **Step 6: Write RED harvest-result boundary tests**

Use canonical-state-shaped dictionaries with `shipped`, `money`, raw relationship `points`, and an unrelated `harvested` count.

Pin:

```gdscript
# 2 potatoes = 150G -> Promising
assert_eq(_result_for([0, 2, 0], [0, 0, 0])["tier"], &"promising_farmer")

# 4 potatoes = 300G but no Close Friend -> still Promising
assert_eq(_result_for([0, 4, 0], [0, 0, 0])["tier"], &"promising_farmer")

# 300G + Close Friend -> Heart
assert_eq(
    _result_for([0, 4, 0], [0, 0, VillagerRules.CLOSE_FRIEND_POINTS])["tier"],
    &"heart_of_harvest",
)
```

Also prove Friend alone -> Promising, below both boundaries -> New Beginning, and changing `harvested` inventory without changing `shipped` does not change the result.

- [ ] **Step 7: Add villager finale copy and pure result derivation**

In `VillagerRules`, add one `FINALE_LINES[villager][relationship]` table and:

```gdscript
static func finale_line(id: VillagerId, level: RelationshipLevel) -> String:
    return FINALE_LINES[id][level]
```

In `ContentRules.build_harvest_result(state)`, derive shipped count/value from `state["shipped"]` using `GameRules.sale_value()`, derive relationship level from persisted `points` using `VillagerRules.relationship_level()`, select one line/villager, and evaluate tiers highest-first. Ignore `state["harvested"]` for scoring.

- [ ] **Step 8: GREEN + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
git add scripts/game/content_rules.gd scripts/game/villager_rules.gd \
  tests/unit/test_content_rules.gd tests/unit/test_villager_rules.gd
git commit -m "feat: add Phoenix content and result policy"
```

---

### Task 2: Persist onboarding progress and lifetime shipping

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_save_file.gd` only if the existing generic recursive transport test does not already cover nested dictionaries

**Interfaces:**
- Produces four persisted fields and canonical validation/restore.
- Produces intro acknowledgement.
- Produces one `_commit()` tutorial-success funnel.
- Produces lifetime shipping through `_settle_pending_shipment()` for normal sleep.
- Does **not** add finale command codes, market finalization, or alter current Day 14 `DAY_LIMIT_REACHED` behavior.

- [ ] **Step 1: Write RED exact state/snapshot shape and isolation tests**

Extend `test_new_session_has_exact_starter_state()` and the state-isolation test:

```gdscript
assert_false(snapshot["intro_acknowledged"])
assert_eq(snapshot["tutorial"], ContentRules.initial_tutorial_progress())
assert_eq(snapshot["shipped"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
assert_false(snapshot["finale_triggered"])
```

Both `state()` and `snapshot()` must contain the four keys. Mutate returned `tutorial`/`shipped` dictionaries and prove fresh projections are isolated.

- [ ] **Step 2: Add the four session fields and explicit projection copies**

In `GameSession`:

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

Add to `state()`:

```gdscript
"intro_acknowledged": _intro_acknowledged,
"tutorial": _tutorial_progress.duplicate(true),
"shipped": _counts_snapshot(_shipped_counts),
"finale_triggered": _finale_triggered,
```

Add the same four keys explicitly to the hand-built `snapshot()` dictionary. Do not assume `snapshot()` spreads new state keys automatically.

- [ ] **Step 3: Write RED persisted-state validation cases**

Start from `GameSession.new().state()` and add candidates for:

- each missing HPA-597 field;
- non-boolean `intro_acknowledged`;
- tutorial missing key;
- tutorial extra key;
- tutorial non-boolean value;
- negative `shipped` count;
- non-boolean `finale_triggered`;
- `finale_triggered == true` before Day 14;
- triggered finale with pending morning summary;
- triggered finale with non-empty pending shipment.

Old pre-HPA-597 state without the fields must fail loudly.

- [ ] **Step 4: Extend `state_error()` and `restore_state()` only**

Use the existing `_field()`, `_named_dictionary_value()`, `_counts_state_error()`, and whole-int helpers. Validate tutorial keys against `ContentRules.tutorial_keys()` and shipped counts through the existing count shape.

On restore:

```gdscript
_intro_acknowledged = bool(candidate["intro_acknowledged"])
_tutorial_progress = {}
for id in ContentRules.tutorial_keys():
    var field := _named_dictionary_value(candidate["tutorial"], id, "tutorial %s" % id)
    _tutorial_progress[id] = bool(field["value"])
_shipped_counts = _counts_array(candidate["shipped"])
_finale_triggered = bool(candidate["finale_triggered"])
```

Do not change `SaveFileCodec.SCHEMA_VERSION` or teach the codec these field names.

- [ ] **Step 5: Add intro codes and acknowledgement**

Add only these new Task 2 codes to `GameRules.CommandCode`:

```gdscript
INTRO_ACKNOWLEDGED,
INTRO_ALREADY_ACKNOWLEDGED,
```

Add:

```gdscript
func acknowledge_intro() -> GameRules.CommandCode:
    if _intro_acknowledged:
        return GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED
    _intro_acknowledged = true
    return GameRules.CommandCode.INTRO_ACKNOWLEDGED
```

Test first call mutates once and duplicate call leaves `state()` unchanged.

- [ ] **Step 6: Write RED tutorial success-vs-failure tests**

Pin at least one failure and the successful completion for every tutorial-bearing code. Example:

```gdscript
var session := GameSession.new()
assert_eq(session.hoe(Vector2i(0, 0)), GameRules.CommandCode.NOT_FARM_CELL)
assert_false(session.state()["tutorial"][&"farm_basics"])

var cell := WorldContract.farm_cells()[0]
assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
assert_true(session.state()["tutorial"][&"farm_basics"])
```

Cover Plant, Water, normal Day 1–13 Sleep, Buy Seeds, Talk, Harvest, Deposit, and Gift. Action/seed selection must not complete a tutorial.

- [ ] **Step 7: Add one `_commit()` funnel and route success returns through it**

Add:

```gdscript
func _commit(code: GameRules.CommandCode) -> GameRules.CommandCode:
    var tutorial_id := ContentRules.tutorial_for_code(code)
    if tutorial_id != &"":
        _tutorial_progress[tutorial_id] = true
    return code
```

After each authoritative mutation, replace tutorial-bearing success returns with `return _commit(GameRules.CommandCode.X)`.

For social results, centralize inside the existing success constructor:

```gdscript
func _social_success(
    code: GameRules.CommandCode,
    lines: Array[String],
    points_gained: int,
    gift_reaction: StringName = &"",
    close_friend_sequence: bool = false,
) -> Dictionary:
    code = _commit(code)
    return {
        "code": code,
        "lines": lines.duplicate(),
        "points_gained": points_gained,
        "gift_reaction": gift_reaction,
        "close_friend_sequence": close_friend_sequence,
    }
```

Failures continue through `_social_failure()` and never call `_commit()`.

- [ ] **Step 8: Write RED cumulative shipping tests**

Through public crop/deposit/sleep commands prove:

- normal sleep pays the pending shipment;
- pending shipment clears;
- `shipped` records exactly those quantities;
- a later normal sleep accumulates additional quantities;
- morning summaries remain per-night, not cumulative;
- `harvested` inventory that was not deposited does not affect `shipped`.

- [ ] **Step 9: Extract one settlement helper and reuse it in normal sleep**

```gdscript
func _settle_pending_shipment() -> Dictionary:
    var payout := GameRules.shipment_payout(_counts_snapshot(_pending_shipment_counts))
    for kind in range(GameRules.CropKind.size()):
        _shipped_counts[kind] += _pending_shipment_counts[kind]
    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    return payout
```

Replace only the existing payout/money/bin-clear section of Day 1–13 `sleep()` with this helper. Preserve crop growth, weather, day/time/stamina reset, morning summary, and social daily reset.

Do not alter the existing Day 14 branch:

```gdscript
if _day >= GameRules.MAX_DAY:
    return GameRules.CommandCode.DAY_LIMIT_REACHED
```

The existing Day 14 unit test remains the characterization; do not add a throwaway replacement test in Task 2.

- [ ] **Step 10: GREEN + commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git diff --check
git grep -n "DAY_LIMIT_REACHED" -- scripts tests
```

Expected: green, and `DAY_LIMIT_REACHED` is still present in the pre-finale domain/HUD/test contract.

If `test_save_file.gd` already proves recursive arbitrary dictionaries and canonical restore, leave it unchanged.

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: persist Phoenix onboarding and shipping progress"
```

Add `tests/unit/test_save_file.gd` only if it actually changed.

---

### Task 3: Author the market and code-built onboarding UI

**Files:**
- Modify: `scripts/world/world_contract.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `assets/sprites/proof-scenery.png`
- Modify: `assets/sprites/proof-scenery.png.import` only if normal Godot import changes it
- Create: `scripts/ui/onboarding_overlay.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/headless/world_shell_smoke.gd`

**Interfaces:**
- Produces authored `MARKET_*` geometry and visible market art, but no live market interaction yet.
- Produces the blocking opening + non-blocking TutorialCard through the existing `GameHud` gate.
- Updates the shared gameplay test factory so normal tests start after the real Start button.
- Leaves `DAY_LIMIT_REACHED` and its current Day 14 sleep behavior/copy untouched until Task 4.

- [ ] **Step 1: Add RED market contract tests**

Add to the existing world-contract/headless checks:

```gdscript
assert_eq(WorldContract.MARKET_CELL, Vector2i(8, 6))
assert_eq(WorldContract.MARKET_FOOTPRINT, Rect2(8.2, 6.2, 0.6, 0.6))
assert_eq(
    WorldContract.MARKET_ANCHOR,
    WorldMath.grid_to_world(Vector2(WorldContract.MARKET_CELL) + Vector2(0.5, 0.5)),
)
```

- [ ] **Step 2: Add the market world constants**

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

Keep geometry in `WorldContract`; snapshots do not persist it.

- [ ] **Step 3: Update every smoke bookkeeping contract before authoring the scene**

In `tests/headless/world_shell_smoke.gd` pin:

```gdscript
EXPECTED_ASSETS["proof-scenery"] = Vector2i(384, 96)
```

Collision order:

```gdscript
var collision_names := [
    "TreeCollision",
    "BuildingCollision",
    "ShippingCollision",
    "HarvestMarketCollision",
] + WorldContract.VILLAGER_COLLISION_NAMES + [
    "PerimeterTop",
    "PerimeterRight",
    "PerimeterBottom",
    "PerimeterLeft",
]
```

Perimeter lookup becomes:

```gdscript
collision_names[index + 7]
```

Entity order begins:

```gdscript
[
    "Player",
    "Tree",
    "Building",
    "Shipping",
    "HarvestMarket",
    "VillagerShopkeeper",
    "VillagerFarmer",
    "VillagerResident",
]
```

Dynamic crops follow. In GUT scene tests change `7 + cells.size()` / `7 + index` to `8 + cells.size()` / `8 + index`.

Also pin Tree/Building/Shipping/HarvestMarket to `proof-scenery.png`, `hframes == 4`, frames `0/1/2/3`; market anchor/collision; and market shared entity z-index.

Expected: RED before scene/art changes.

- [ ] **Step 4: Author the market with existing world conventions**

Extend `proof-scenery.png` from `288x96` to `384x96` with one proof-quality 96x96 market stall frame. Keep transparent background and bottom-center contact.

In `world.tscn`:

- set existing Tree/Building/Shipping scenery sprites to `hframes = 4`, keeping frames 0/1/2;
- insert `HarvestMarketCollision` after ShippingCollision and before villager collisions;
- insert `Entities/HarvestMarket` after Shipping and before villagers, at `MARKET_ANCHOR`, frame 3, `offset = Vector2(0, -48)`.

In `WorldShell._ready()`:

```gdscript
var market_collision := static_collision.get_node("HarvestMarketCollision") as CollisionPolygon2D
market_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.MARKET_FOOTPRINT)
```

`FarmView` remains unchanged.

- [ ] **Step 5: Write RED fresh-opening/test-factory contracts**

Refactor the test factory around one internal helper:

```gdscript
func _spawn_world(acknowledge_intro: bool) -> WorldShell:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var world := packed.instantiate() as WorldShell
    assert_not_null(world)
    if world == null:
        return null
    add_child_autoqfree(world)
    if acknowledge_intro:
        var start := world.hud.get_node(
            "HudRoot/OnboardingOverlay/OpeningPanel/Start"
        ) as Button
        start.pressed.emit()
    return world

func _world() -> WorldShell:
    return _spawn_world(true)

func _locked_world() -> WorldShell:
    return _spawn_world(false)
```

Keep one lock test on `_locked_world()`:

```gdscript
func test_fresh_opening_blocks_world_input() -> void:
    var world := _locked_world()
    var opening := world.hud.get_node(
        "HudRoot/OnboardingOverlay/OpeningPanel"
    ) as Control
    assert_true(opening.visible)
    assert_false(world._world_input_enabled)
    assert_false(world._session.state()["intro_acknowledged"])
```

All existing tests continue calling `_world()` and therefore need no per-test edits.

- [ ] **Step 6: Create the code-built `OnboardingOverlay` class**

Create `scripts/ui/onboarding_overlay.gd` following `DialoguePanel`:

```gdscript
class_name OnboardingOverlay
extends Control

signal intro_acknowledged

var _dismissed: Array[StringName] = []
var _opening_panel: Control
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}

func _ready() -> void:
    _opening_panel = _build_opening_panel()
    _tutorial_card = _build_tutorial_card()
    _opening_panel.visible = false
    _tutorial_card.visible = false
```

Do not set the root to full rect. Its default zero size gives it no hit area.

Build OpeningPanel as a positioned `ColorRect` with `MOUSE_FILTER_STOP`, two labels, and `Start`; pressing Start emits `intro_acknowledged`.

Build TutorialCard as a small positioned `ColorRect` with `MOUSE_FILTER_STOP`, title/body, and Dismiss. Place it away from the existing top-left action/seed bar. Dismiss appends the current prompt ID to `_dismissed` and re-renders from `_last_snapshot`; it never mutates the session.

Expose:

```gdscript
func render(snapshot: Dictionary) -> void
func is_opening_visible() -> bool
```

`render()` shows OpeningPanel iff `intro_acknowledged == false`; after intro it asks `ContentRules.next_tutorial_prompt(snapshot, _dismissed)` and updates TutorialCard.

- [ ] **Step 7: Wire onboarding through the current HUD/modal gate**

In `GameHud._build_modals()`:

```gdscript
_onboarding_overlay = OnboardingOverlay.new()
_onboarding_overlay.name = "OnboardingOverlay"
_root.add_child(_onboarding_overlay)
_onboarding_overlay.intro_acknowledged.connect(func() -> void:
    intro_acknowledged.emit()
)
```

Add `signal intro_acknowledged` and include only `_onboarding_overlay.is_opening_visible()` in `has_blocking_modal()`.

`GameHud.render(snapshot)` calls `_onboarding_overlay.render(snapshot)` before the final modal-state/input refresh logic.

In `WorldShell._ready()` connect HUD intro signal, and add:

```gdscript
func _on_intro_acknowledged() -> void:
    _finish_command(_session.acknowledge_intro())
```

Do not reject this handler because `_world_input_enabled` is false; it is the action that releases the opening gate.

- [ ] **Step 8: Prove TutorialCard does not intercept normal HUD actions**

After `_world()` has started and while `farm_basics` card is visible:

```gdscript
var selected: Array[int] = []
world.hud.select_action_requested.connect(func(action: int) -> void:
    selected.append(action)
)

var hoe_button := world.hud.get_node("HudRoot/Action_0") as Button
hoe_button.pressed.emit()
assert_eq(selected, [GameRules.FarmingAction.HOE])
assert_true(world._world_input_enabled)
```

Also press Dismiss and assert the session tutorial flag remains false, then perform a successful Hoe and assert `farm_basics` becomes true and the card changes/disappears after refresh.

- [ ] **Step 9: Add the persistent objective only**

Add one HUD objective label:

- Day 1–13: `Harvest Market: Day 14 · N days left`
- Day 14, while the old boundary still exists: `Harvest Market today — prepare your final shipment.`

Do not add `Harvest Market — E` yet. Do not replace `DAY_LIMIT_REACHED` or claim that sleep finishes the run before Task 4 lands.

- [ ] **Step 10: Update headless smoke to press Start once before input checks**

Add a tiny helper that presses the real UI button on the single world instance:

```gdscript
func _acknowledge_intro(world: WorldShell) -> void:
    var start := world.get_node(
        "GameHud/HudRoot/OnboardingOverlay/OpeningPanel/Start"
    ) as Button
    start.pressed.emit()
```

Run structural/world-contract checks first. Call `_acknowledge_intro(world)` once before the existing section that first presses movement/actions. Do not mutate session internals.

- [ ] **Step 11: GREEN + commit**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

```bash
git add scripts/world/world_contract.gd scenes/world/world.tscn \
  assets/sprites/proof-scenery.png scripts/ui/onboarding_overlay.gd \
  scripts/ui/game_hud.gd scripts/world/world_shell.gd \
  tests/integration/test_gameplay_shell.gd tests/headless/world_shell_smoke.gd
```

Add `assets/sprites/proof-scenery.png.import` only if Godot changed it.

```bash
git commit -m "feat: add harvest market and contextual onboarding"
```

---

### Task 4: Land the complete terminal harvest slice atomically

**Files:**
- Modify: `scripts/game/game_rules.gd`
- Modify: `scripts/game/game_session.gd`
- Modify: `scripts/ui/game_hud.gd`
- Modify: `scripts/world/world_shell.gd`
- Modify: `tests/unit/test_game_session.gd`
- Create: `scenes/ui/result_screen.tscn`
- Create: `scripts/ui/result_screen.gd`
- Modify: `scenes/app/app.tscn`
- Modify: `scripts/app/app_root.gd`
- Modify: `tests/integration/test_app_launch.gd`
- Modify: `tests/integration/test_gameplay_shell.gd`
- Modify: `tests/integration/test_persistence_flow.gd`

**Interfaces:**
- Consumes Task 2's `_settle_pending_shipment()` and four persisted fields.
- Consumes Task 3's authored market.
- Produces all finale codes/domain rules, market + bed terminal routing, one final save attempt, `ResultScreen`, completed Continue, and removal of the old Day 14 hard stop.
- Uses `remove_child()` + `queue_free()` for synchronous WorldShell signal teardown.

- [ ] **Step 1: Write RED domain tests for the complete Day 14 rule**

Use a narrow `_day14_session_from(state)` fixture that seeds only what reaching Day 14 literally would obscure, immediately asserts the seeded values, then uses public terminal commands.

Pin:

- market before Day 14 -> `MARKET_NOT_READY`;
- Day 14 wrong market target -> `NOT_AT_MARKET`;
- Day 14 market -> `FINALE_TRIGGERED`;
- Day 14 bed -> `FINALE_TRIGGERED`;
- market and bed from identical pre-final state produce identical canonical state;
- pending shipment pays and increments `shipped` once;
- carried `harvested` inventory remains in inventory and does not increment `shipped`;
- day stays 14;
- no morning summary;
- no weather roll/crop growth/time/stamina/social daily reset;
- duplicate terminal command -> `FINALE_ALREADY_TRIGGERED` with no mutation;
- later gameplay commands are terminal-blocked.

Expected: RED because the current code still returns `DAY_LIMIT_REACHED` and has no market command.

- [ ] **Step 2: Add finale codes and one terminal domain helper**

Add to `GameRules.CommandCode`:

```gdscript
FINALE_TRIGGERED,
MARKET_NOT_READY,
NOT_AT_MARKET,
FINALE_ALREADY_TRIGGERED,
```

Add:

```gdscript
func trigger_harvest_finale(target_cell: Variant) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if _day != GameRules.MAX_DAY:
        return GameRules.CommandCode.MARKET_NOT_READY
    if not (target_cell is Vector2i) or target_cell != WorldContract.MARKET_CELL:
        return GameRules.CommandCode.NOT_AT_MARKET
    return _complete_finale()

func _complete_finale() -> GameRules.CommandCode:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
    _settle_pending_shipment()
    _finale_triggered = true
    return GameRules.CommandCode.FINALE_TRIGGERED
```

Update `_active_day_failure()` so `_finale_triggered` returns `FINALE_ALREADY_TRIGGERED` before ordinary gameplay.

Change `sleep()` only now, after its existing active-state and bed-target checks:

```gdscript
if _day == GameRules.MAX_DAY:
    return _complete_finale()
```

Remove `DAY_LIMIT_REACHED` from the enum after all callers/tests are updated in this task.

- [ ] **Step 3: Write RED result-screen/AppRoot Continue test**

Create a valid terminal state through the new public terminal command, save it through real `SaveRepository`, instantiate AppRoot, emit Continue, then assert:

```gdscript
assert_null(app.get_node_or_null("World"))
var result := app.get_node("ResultScreen") as ResultScreen
assert_true(result.visible)
```

Pin the labels against `ContentRules.build_harvest_result(completed_state)` rather than duplicating scoring logic in UI tests.

- [ ] **Step 4: Add presentation-only `ResultScreen`**

Create `scenes/ui/result_screen.tscn` as an app-level screen sibling to `TitleScreen` with:

- result title;
- shipped count/value;
- final money;
- relationship summary;
- Mira/Rowan/June final lines;
- final-save status;
- New Game button;
- Return to Title button.

Create `scripts/ui/result_screen.gd`:

```gdscript
class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

func present(result: Dictionary, save_error: int = OK) -> void:
    ($Panel/Title as Label).text = String(result["title"])
    ($Panel/Shipped as Label).text = "Shipped: %d crops · %dG" % [
        int(result["shipped_count"]),
        int(result["shipped_value"]),
    ]
    ($Panel/Money as Label).text = "Final money: %dG" % int(result["final_money"])
    ($Panel/SaveStatus as Label).text = (
        ""
        if save_error == OK
        else "Final result was not saved."
    )
    visible = true
```

Fill the relationship/villager-line labels from the provided result dictionary only. Connect button signals in `_ready()`. No file/session access.

Instance it hidden beside TitleScreen in `scenes/app/app.tscn`.

- [ ] **Step 5: Extend AppRoot with validated result routing and safe teardown**

Add `@onready var _result_screen` and connect its two signals in `_ready()`.

At the top of `_launch(initial_state)` after the existing live-World guard:

```gdscript
if initial_state != null and bool(initial_state["finale_triggered"]):
    _show_result(initial_state, OK)
    return
```

Do not use `.get("finale_triggered", false)`; `_load_title_state()` already validates the shape.

When launching World, connect before `add_child(world)`:

```gdscript
world.finale_completed.connect(_on_finale_completed)
```

Implement:

```gdscript
func _on_finale_completed(final_state: Dictionary, save_error: int) -> void:
    _show_result(final_state, save_error)

func _show_result(state: Dictionary, save_error: int) -> void:
    var world := get_node_or_null("World")
    if world != null:
        remove_child(world)
        world.queue_free()
    _title_screen.visible = false
    _result_screen.present(ContentRules.build_harvest_result(state), save_error)
```

Use `queue_free()`, never `free()`, because WorldShell emits the signal synchronously from its own call stack. `remove_child()` immediately clears `_launch()`'s `World` guard for same-frame Result -> New Game.

Result New Game hides result then `_launch(null)` without deleting the slot. Return to Title hides result, shows title, and calls `_load_title_state()`.

- [ ] **Step 6: Write RED one-save terminal integration tests using the existing fake**

Reuse `CountingSaveRepository` already defined in `tests/integration/test_persistence_flow.gd`.

From equivalent pre-final states prove:

1. live market interaction saves exactly once and reaches ResultScreen;
2. live Day 14 sleep saves exactly once and reaches ResultScreen;
3. terminal canonical states/results are equal;
4. duplicate finalization cannot add a save;
5. pending final shipment is paid/recorded exactly once;
6. carried harvested crops remain uncounted/unshipped.

Do not add another repository fake.

- [ ] **Step 7: Add one WorldShell terminal handoff and live market routing**

Add:

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

In `interact()` add the market branch on its distinct cell:

```gdscript
elif target == WorldContract.MARKET_CELL:
    _finish_finale(_session.trigger_harvest_finale(target))
```

Change `_on_sleep_requested()`:

```gdscript
func _on_sleep_requested() -> void:
    var target: Variant = player.current_target_cell()
    var code := _session.sleep(target)
    if code == GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_finale(code)
        return
    if code != GameRules.CommandCode.DAY_ADVANCED or _save_repository == null:
        _finish_command(code)
        return

    hud.show_feedback(code)
    _refresh_from_session()
    var save_error := _save_repository.save(_session.state())
    if save_error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(&"error", "Save failed — this morning is not persisted.")
```

Add:

```gdscript
func _finish_finale(code: GameRules.CommandCode) -> void:
    if code != GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_command(code)
        return
    hud.show_feedback(code)
    _refresh_from_session()
    var state := _session.state()
    var save_error := ERR_UNAVAILABLE
    if _save_repository != null:
        save_error = _save_repository.save(state)
    finale_completed.emit(state, save_error)
```

No await, save queue, fallback repository, or reentrancy flag.

- [ ] **Step 8: Replace the old Day 14 UI contract with explicit shipped-only copy**

Add market target hint in `_process()`:

```text
Harvest Market — E
```

On Day 14 use:

```text
Objective: Harvest Market today — ship crops first, then visit the village path stall.
Shipping: Day 14: only crops deposited here count toward the finale.
Sleep: Day 14: sleeping ends the run and settles the shipping bin.
```

Remove the old `DAY_LIMIT_REACHED` feedback/warnings in the same task.

Add a scene test with harvested-but-not-deposited crops and assert the Day 14 shipping copy contains `only crops deposited here count`.

- [ ] **Step 9: Prove save-failure and result actions**

Using the existing unwritable-directory repository style:

- terminal state remains completed when final save fails;
- ResultScreen is still shown;
- save-status text says the final result was not saved;
- Return to Title reloads the prior valid save if one exists;
- Result -> New Game launches a fresh World in the same frame because the old World was removed before `queue_free()`;
- New Game does not delete the old slot.

- [ ] **Step 10: GREEN, remove the old boundary everywhere, and commit**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
git grep -n "DAY_LIMIT_REACHED" -- . ':!docs/superpowers/**'
git diff --check
```

Expected: GUT green; grep has no live production/test matches.

```bash
git add scripts/game/game_rules.gd scripts/game/game_session.gd \
  scripts/ui/game_hud.gd scripts/world/world_shell.gd \
  tests/unit/test_game_session.gd scenes/app/app.tscn \
  scenes/ui/result_screen.tscn scripts/app/app_root.gd \
  scripts/ui/result_screen.gd tests/integration/test_app_launch.gd \
  tests/integration/test_gameplay_shell.gd tests/integration/test_persistence_flow.gd
git commit -m "feat: add terminal harvest result flow"
```

---

### Task 5: Close the acceptance loop and document the shipped slice

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify existing tests only if the acceptance pass exposes an actual missing contract

**Interfaces:**
- Verifies complete HPA-597 through current Godot/GUT/headless/save seams.
- Leaves balance/polish/export/package work to HPA-599.

- [ ] **Step 1: Extend the existing persistence acceptance path, not a new harness**

Use real UI/session/save seams to prove:

1. fresh opening starts locked;
2. press the real Start button;
3. Hoe/Plant/Water complete tutorial flags through `_commit()`;
4. normal sleep saves and records intro/tutorial state;
5. reopen/Continue does not reopen the introduction;
6. existing crop/social path completes Harvest/Talk/Gift/Shipping;
7. later normal sleep persists cumulative shipped counts.

Do not play thirteen literal UI days just to reach the focused Day 14 unit/integration boundary tests.

- [ ] **Step 2: Pin completed-save reopen with no post-game**

From a terminal state saved through real `WorldShell` handoff:

```gdscript
var restored_app := APP_SCENE.instantiate() as AppRoot
restored_app.configure(repository)
add_child_autoqfree(restored_app)
var title := restored_app.get_node("TitleScreen") as TitleScreen
title.continue_requested.emit()
await get_tree().process_frame
assert_null(restored_app.get_node_or_null("World"))
assert_true((restored_app.get_node("ResultScreen") as ResultScreen).visible)
```

Also assert result shipped totals ignore carried `harvested` inventory and match canonical `ContentRules.build_harvest_result()`.

- [ ] **Step 3: Update README and CLAUDE.md**

README player-facing facts:

- Start introduction + contextual dismissible help;
- Day 14 objective;
- only crops deposited in the shipping bin count toward farming result;
- market `E` and sleep fallback both finish the run;
- three encouraging endings;
- completed Continue -> result;
- no post-game/free-play.

CLAUDE.md implementation facts:

- `ContentRules.TUTORIALS` is the one tutorial identity/copy/completion table;
- `GameSession._commit()` derives completion via `ContentRules.tutorial_for_code()`;
- four persisted fields are copied through `state()` + `snapshot()` and old saves are intentionally incompatible;
- `_settle_pending_shipment()` records lifetime shipped counts;
- carried inventory is not auto-shipped at completion;
- OnboardingOverlay is code-built under `GameHud` like DialoguePanel;
- market world contract and smoke offsets;
- Task 4 terminal path shares `_complete_finale()`;
- AppRoot result teardown is `remove_child()` + `queue_free()`;
- HPA-599 owns balance/polish/export.

Keep `AGENTS.md` untouched.

- [ ] **Step 4: Run full worktree verification**

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
git diff --check
```

- [ ] **Step 5: Commit closeout docs/tests**

```bash
git add README.md CLAUDE.md
```

If Task 5 exposed a real missing test contract, add only those changed test files.

```bash
git commit -m "docs: finish HPA-597 content slice handoff"
```

- [ ] **Step 6: Run the committed clean-archive gate**

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected: green, clean worktree, no JavaScript/Tauri/browser runtime return.

---

## Done definition

HPA-597 is done in this one PR when:

- fresh play has a short blocking introduction followed by relevant dismissible non-blocking help;
- tutorial ID/copy/completion mapping has one source (`ContentRules.TUTORIALS`);
- tutorial completion comes only from successful `GameSession` commands through `_commit()` and survives save/continue;
- lifetime shipped counts survive multiple nights/save round trips;
- carried harvested crops do not silently count as shipped at the finale, and Day 14 UI says so;
- one authored harvest market exists on the current isometric/Y-sort world seam;
- Day 14 market and Day 14 bed use one `_complete_finale()` transaction;
- final shipping settles exactly once and no route reaches Day 15;
- New Beginning, Promising Farmer, and Heart of the Harvest exact thresholds have direct tests;
- final save is attempted exactly once and failure does not undo completion;
- AppRoot removes the live World and queues it for deletion safely before showing ResultScreen;
- completed Continue opens ResultScreen directly with no post-game world;
- README/CLAUDE are current;
- `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass.
