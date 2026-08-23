# Phoenix Godot Social Port Design (HPA-594)

**Status:** Draft for review — revised against live Godot contracts

**Date:** 2026-08-23

**Delivery target:** Godot 4.7.1 desktop social-parity slice

## Source of truth

This design implements Linear HPA-594, **[Godot Social Port] Restore the village, dialogue, gifting, and relationships**, immediately after HPA-589 restored the farming, daily-rhythm, and three-crop economy loop.

The implementation baseline is Phoenix `main` at `7c69d8bacbf416ea550608a43685dcf9328a32ed`. The repository handoff is `AGENTS.md`, which is a symlink to `CLAUDE.md`; both therefore describe the same live Godot architecture.

The shipped HPA-595 design at `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md` is the **behavior/content oracle** for this port. Names, role keys, cells, favourite crops, relationship gains/thresholds, gift replies, normal dialogue, and the one-time two-line Close Friend sequences below are copied verbatim from that oracle. HPA-594 changes the engine implementation only; it must not re-author those values.

The live Linear issue and Phoenix project description remain authoritative for scope and non-goals. HPA-594 blocks HPA-598 persistence, so relationship state must remain authoritative and snapshot-friendly without defining a save schema here.

## Live Godot baseline

HPA-594 extends these seams in place:

- `scripts/game/game_session.gd` — the only mutable farm/economy/day authority; `sleep()` owns the successful day transition and `snapshot()` returns isolated dictionaries.
- `scripts/game/game_rules.gd` — closed crop/action/weather rules plus `GameRules.CommandCode`.
- `scripts/world/world_contract.gd` — fixed map/farm/path/shop/bed/shipping geometry.
- `scripts/world/world_math.gd` — 2:1 projection, cell lookup, facing targets, and projected logical footprints.
- `scripts/world/world_shell.gd` — the only production `GameSession` holder; direct `E` routing and the current `_finish_command(code)` feedback/refresh path live here.
- `scripts/player/player_controller.gd` — `current_target_cell()` and movement input.
- `scripts/ui/game_hud.gd` / `scenes/ui/game_hud.tscn` — `$HudRoot`, code-built shop/shipping/sleep/summary modals, `show_feedback()`, and `has_blocking_modal()`.
- `scenes/world/world.tscn` — authored `StaticCollision` and the single Y-sorted `Entities` root.
- `tests/unit/`, `tests/integration/test_gameplay_shell.gd`, `tests/headless/world_shell_smoke.gd` — the current direct test seams.
- `tools/verify-clean.sh` — the clean **committed-HEAD** verifier. It starts with `git archive HEAD`, so it is not a worktree RED/GREEN runner.

Three exact scene/test contracts matter when villagers are inserted:

1. `tests/headless/world_shell_smoke.gd` pins the authored `World`, `StaticCollision`, and `Entities` child names/order.
2. Its perimeter loop currently resolves `collision_names[index + 3]`; three villager collision nodes inserted after `ShippingCollision` move that offset to `index + 6`.
3. `FarmView._ready()` appends nine runtime `FarmCrop_*` roots under `Entities`; `tests/integration/test_gameplay_shell.gd` currently uses `4 + farm_cells.size()` in both the equality and guard and indexes crops at `4 + index`. HPA-594 changes all three expressions to the seven-authored-child equivalents.

No parallel game/world/UI/test tree or verification path is introduced.

## Outcome and lean shape

Phoenix restores the existing three-villager social loop directly on top of the live Godot gameplay session. Mira, Rowan, and June are static authored entities immediately north of the existing village path. The player faces a villager and presses `E` to talk, can give exactly one carried harvested crop per villager per day, and progresses through Stranger, Friend, and Close Friend using the shipped HPA-595 policy.

The port keeps the current architecture small:

- `GameSession` remains the only mutable gameplay authority.
- one pure `VillagerRules` sibling owns frozen social content and relationship policy;
- `WorldContract` owns villager cells and collision footprints;
- `WorldShell` keeps direct facing-derived interaction routing;
- one focused `DialoguePanel` class owns transient line/focus/gift-choice presentation;
- `GameHud.has_blocking_modal()` remains the only world-input gate.

There is no social service, NPC manager, schedule/pathfinding layer, generic interaction registry, dialogue/event engine, event bus, quest framework, generic item system, persistence layer, or second gameplay authority.

## Frozen HPA-595 behavior/content

Villager enum order matches the retained three-frame sprite sheet:

| `VillagerId` | Key | Name | Role | Favourite crop | Cell | Sprite frame |
| --- | --- | --- | --- | --- | --- | ---: |
| `SHOPKEEPER` | `shopkeeper` | Mira | Seed-shop keeper | Potato | `(6,5)` | 0 |
| `FARMER` | `farmer` | Rowan | Neighbouring farmer | Pumpkin | `(3,5)` | 1 |
| `RESIDENT` | `resident` | June | Village resident | Turnip | `(9,5)` | 2 |

Relationship policy is unchanged:

| Rule | Value |
| --- | ---: |
| Stranger floor | 0 |
| Friend floor | 12 |
| Close Friend floor | 18 |
| First successful talk per villager/day | +1 |
| First normal gift per villager/day | +3 |
| Favourite gift bonus | +2 |

Talking and gifting cost no time or stamina. There is no cap, decay, disliked gift category, birthday modifier, or randomness.

### Exact dialogue oracle copy

These strings are verbatim from `2026-08-17-phoenix-social-slice-design.md` and are not independently editable HPA-594 copy.

**Mira / shopkeeper**

- Stranger: `The seed counter is open whenever you need it.`
- Friend: `Your fields are starting to look dependable.`
- Close Friend: `You have made this little farm part of the village.`
- Close Friend sequence:
  1. `You kept showing up, even on the slow days.`
  2. `The harvest market will feel different with you there.`
- Normal gift: `A useful harvest. Thank you.`
- Favourite gift: `Potatoes? You remembered.`

**Rowan / farmer**

- Stranger: `Watered soil tells you what tomorrow will bring.`
- Friend: `Your rows are getting cleaner every day.`
- Close Friend: `I would trust you with a field of my own.`
- Close Friend sequence:
  1. `I noticed when the farm stopped looking neglected.`
  2. `You earned that change one ordinary day at a time.`
- Normal gift: `Good produce. I can use this.`
- Favourite gift: `A pumpkin this good is hard to ignore.`

**June / resident**

- Stranger: `It is quieter here than the road makes it look.`
- Friend: `I keep seeing you around. I like that.`
- Close Friend: `The village feels more like home with you here.`
- Close Friend sequence:
  1. `You came here as the new farmer, but that is not how I think of you now.`
  2. `You are one of us.`
- Normal gift: `That is kind of you.`
- Favourite gift: `Turnips are my favourite. Perfect choice.`

## `VillagerRules`: pure content/policy sibling

Create `scripts/game/villager_rules.gd` as `class_name VillagerRules extends RefCounted`.

It owns only the three IDs/levels, the exact HPA-595 content tables, and these policy values:

```gdscript
const TALK_POINTS := 1
const GIFT_POINTS := 3
const FAVOURITE_GIFT_BONUS := 2
const FRIEND_POINTS := 12
const CLOSE_FRIEND_POINTS := 18
```

Parallel arrays hold keys, names, roles, favourites, normal dialogue, Close Friend sequences, and gift replies. `tests/unit/test_villager_rules.gd` pins every parallel array to `VillagerId.size()` and pins every spoken string once against the HPA-595 oracle.

Expose only direct static accessors/pure helpers used by session/UI: key/name/role/favourite lookup, relationship derivation/display, dialogue lookup, favourite detection, gift points, and gift line. `close_friend_dialogue_lines()` returns a fresh `Array[String]`.

`VillagerRules` has no coordinates, mutable flags, nodes, session references, persistence, or event dispatch. Only four social codes are added to `GameRules.CommandCode`:

- `VILLAGER_TALKED`
- `CROP_GIFTED`
- `NOT_AT_VILLAGER`
- `GIFT_ALREADY_GIVEN`

Existing `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` are reused.

## World geometry and authored scene contract

### `WorldContract`

Keep all current map/projection/player/farm/path/shop/bed/shipping values unchanged. Add only villager geometry in `VillagerId` order:

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
```

Expose `villager_cell(id)`, `villager_footprint(id)`, and `villager_at(cell)`. `villager_at` returns the matching enum value or `-1`. Do not echo villager cells into `GameSession.snapshot()`.

### `world.tscn`

Under the existing `StaticCollision`, insert exactly after `ShippingCollision`:

- `VillagerShopkeeperCollision`
- `VillagerFarmerCollision`
- `VillagerResidentCollision`

Under the existing Y-sorted `Entities`, insert exactly after `Shipping`:

- `VillagerShopkeeper` at authored `Vector2(416, 192)`;
- `VillagerFarmer` at authored `Vector2(320, 144)`;
- `VillagerResident` at authored `Vector2(512, 240)`.

Each villager root contains one `Sprite2D` using retained `res://assets/sprites/proof-villagers.png`, `hframes = 3`, frame `0/1/2`, and bottom-center `offset = Vector2(0, -24)`.

The authored position convention intentionally matches existing Tree/Building/Shipping: the scene carries the concrete position and the smoke proves it agrees with the logical contract:

```gdscript
WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5))
```

Do **not** overwrite villager root positions from `WorldShell._ready()`; doing so would make the scene-position test tautological and hide authored drift.

Collision polygons are different: like Tree/Building/Shipping, they have no authored polygon counterpart. `WorldShell._ready()` derives only the three new polygons through:

```gdscript
WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))
```

In the same change:

- extend the smoke's collision name/order list and change perimeter lookup from `collision_names[index + 3]` to `collision_names[index + 6]`;
- extend the authored entity name/order list with the three villagers;
- change both `4 + farm_cells.size()` expressions in `test_gameplay_shell.gd` to `7 + farm_cells.size()`;
- change crop root indexing from `4 + index` to `7 + index`.

Do not add a reusable NPC scene, `VillageView`, `Area2D` interaction layer, movement script, AnimationPlayer, or second Y-sort root.

## Authoritative relationship state and social commands

`GameSession` gains one mutable relationship entry per villager:

```gdscript
{
    "points": 0,
    "talked_today": false,
    "gifted_today": false,
    "close_friend_dialogue_seen": false,
}
```

Relationship level is derived from points and is never stored redundantly. `GameSession.snapshot()` adds only one top-level `relationships` dictionary keyed by villager key, containing points, derived level, both daily flags, and the one-time-dialogue flag. It does not duplicate geometry, dialogue text, line index, modal state, focus, or nodes.

Existing farming/economy commands continue returning `GameRules.CommandCode` directly. `talk_to` and `gift_crop` return one narrow dictionary because successful social actions need one-shot lines and `points_gained` that are not recoverable from the post-command snapshot alone:

```gdscript
{
    "code": GameRules.CommandCode,
    "lines": Array[String],
    "points_gained": int,
    "gift_reaction": StringName, # &"", &"normal", or &"favourite"
    "close_friend_sequence": bool,
}
```

Failures use the same shape with empty/zero values. This shape stays local to the two social methods; it does not become a generic result envelope.

`talk_to` applies pending-summary failure, validates exact target, grants the first daily talk point, derives the resulting level, emits/marks the one-time Close Friend sequence when appropriate, and otherwise returns the normal oracle line. Repeat same-day talk remains successful with `points_gained = 0`.

`gift_crop` applies pending-summary failure, validates exact target, rejects duplicate gift before inventory, rejects insufficient carried crop, consumes exactly one harvested crop, sets the daily flag, adds `3` plus favourite bonus `2`, and returns the exact oracle gift line/reaction. A gift that crosses Close Friend does not consume the special sequence; the next talk can emit it.

Successful existing `sleep()` clears only every relationship's `talked_today` and `gifted_today`. Failed sleep, Day 14 rejection, pending Morning Summary, and `acknowledge_morning_summary()` preserve all social state.

## Direct world routing and existing feedback

Keep the current `WorldShell.interact()` if/elif model. Resolve `player.current_target_cell()` once; route a villager before the explicit Shop/Shipping/Bed branches. No registry or interaction map is added.

`_process()` shows `"<Name> — E"` for a targeted villager and otherwise keeps current hints.

Add one sibling to the existing `_finish_command(code)` path:

```gdscript
func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())
```

This intentionally reuses the existing feedback/refresh model. Add the four social codes to `GameHud.show_feedback()`; do not introduce social toast state or another feedback route.

`_on_gift_requested(villager_id, crop_kind)` re-reads `player.current_target_cell()` before calling `gift_crop`, matching the existing buy/deposit handlers. The modal prevents player movement, but the session still validates target ownership.

## `DialoguePanel`: separate stateful class, code-built modal

A separate `DialoguePanel` class is justified because line index, dynamic gift buttons, native focus, and cancel behavior do not belong in `GameHud` or `GameSession`. A separate `.tscn` is not justified: every existing HUD modal is built in `GameHud._build_modals()`, so dialogue follows that packaging convention.

Create only:

- `scripts/ui/dialogue_panel.gd`

`GameHud._build_modals()` instantiates `DialoguePanel.new()`, names it `DialoguePanel`, adds it under the existing `$HudRoot`, wires its signals, and keeps it hidden initially. `DialoguePanel._ready()` builds this small subtree in code:

```text
DialoguePanel (Control)
└── Panel (ColorRect)
    ├── Name (Label)
    ├── Role (Label)
    ├── Relationship (Label)
    ├── Line (Label)
    ├── Feedback (Label)
    ├── GiftStatus (Label)
    ├── GiftButtons (VBoxContainer)
    ├── Continue (Button)
    └── Close (Button)
```

`Feedback` renders the non-persistent command feedback for the current payload: `+N relationship point(s)` and, after gifting, `Favourite gift!` or `Gift accepted.`. `GiftStatus` renders only `Gift already given today` or `No harvested crops to give` when no gift button should be shown. This avoids three overlapping feedback labels with no distinct contract.

The panel stores only active villager ID, social lines/line index, points/reaction/special-sequence flags, and the latest read-only snapshot needed to derive relationship/inventory display. It emits:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested
```

It never receives `GameSession`, mutates inventory, calculates relationship points, or knows world coordinates.

### Native focus, Space overlap, and closing

Dialogue buttons use normal focusable Godot `Button` behavior. Do **not** use `GameHud._add_button`, which sets `FOCUS_NONE` for current HUD controls.

Focus order is:

1. `Continue` while another line remains;
2. otherwise first available gift button;
3. otherwise `Close`.

Godot's built-in `ui_accept` includes Space while Phoenix also maps Space to `use_action`. While dialogue is visible, the existing modal gate blocks world commands, so Space may activate the focused dialogue button but cannot farm. When dialogue closes, `DialoguePanel.close_panel()` releases focus from a descendant control before hiding itself; tests assert `get_viewport().gui_get_focus_owner() == null` after both Close and `ui_cancel`.

Do not add raw Enter/Space handling; focused buttons own `ui_accept`. Handle `ui_cancel` inside `DialoguePanel`; while a Close Friend sequence has another line, consume cancel without closing, then allow close after the final line.

Extend `GameHud.has_blocking_modal()` with dialogue visibility. Opening/closing dialogue emits the existing `modal_state_changed`. Morning Summary hides dialogue together with Shop/Shipping/Sleep before becoming visible. The existing `WorldShell._refresh_world_input_gate()` and action/seed button-disable path remain unchanged.

## Test strategy

### Pure content/policy

`tests/unit/test_villager_rules.gd` is the literal content oracle test. It pins all HPA-595 strings and policy values once. Session and UI tests reference `VillagerRules` helpers/result payloads instead of re-authoring independent spoken-line copies.

### Session rules

Extend `tests/unit/test_game_session.gd` to prove wrong-target/duplicate/insufficient atomicity, snapshot isolation, daily reset, pending-summary blocking, Day 14 preservation, and the complete three-social-day June journey:

```text
Day 1: talk +1, favourite gift +5 => 6 Stranger
sleep/ack
Day 2: talk +1, favourite gift +5 => 12 Friend
sleep/ack
Day 3: talk +1 => 13, favourite gift +5 => 18 Close Friend
same-day follow-up talk => +0 and two-line special sequence
next talk => +0 and normal Close Friend line
```

Reuse the existing `_grow_and_harvest_turnip()` helper for a real single-crop gift test where practical. For the compact three-gift progression fixture, if carried inventory is seeded directly, use a typed test helper:

```gdscript
func _seed_harvested(session: GameSession, counts: Array[int]) -> void:
    session.set("_harvested_counts", counts)
    var harvested: Dictionary = session.snapshot()["harvested"]
    assert_eq(harvested[&"turnip"], counts[GameRules.CropKind.TURNIP])
    assert_eq(harvested[&"potato"], counts[GameRules.CropKind.POTATO])
    assert_eq(harvested[&"pumpkin"], counts[GameRules.CropKind.PUMPKIN])
```

Do not call `session.set("_harvested_counts", [..])` with an untyped array literal; `_harvested_counts` is `Array[int]` and the failed property assignment is otherwise easy to misdiagnose as a gifting bug.

### Shell/UI integration

Do not add a production/debug mutation API. The existing integration suite already reaches `world._session`, so one narrowly scoped real-data gift round-trip may seed its typed `_harvested_counts` fixture directly to prove the newest cross-layer path:

```text
DialoguePanel gift button
→ GameHud.gift_requested
→ WorldShell._on_gift_requested
→ GameSession.gift_crop
→ _finish_social_command
→ GameHud.update_dialogue
→ DialoguePanel.present
```

That test asserts one crop is consumed and the open panel rerenders the oracle gift line/reaction. Separate synthetic `DialoguePanel` data tests cover two-line focus/cancel behavior without manufacturing relationship thresholds in `WorldShell`.

Also prove facing target → panel, modal gate/close restoration, all three villager routes, and `gui_get_focus_owner() == null` after dialogue closes.

### Exact scene contract

In the geometry task, update in place:

- exact `StaticCollision` names/order and perimeter offset `index + 6`;
- exact authored `Entities` names/order;
- authored villager positions checked against `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`;
- both integration child-count expressions to `7 + farm_cells.size()`;
- crop-root index to `7 + index`.

Before editing those assertions, grep the two test files for the old `+ 3` / `+ 4` offsets rather than assuming the known list is exhaustive.

No new E2E framework or input automation package is added.

## Worktree and committed-HEAD verification

`tools/verify-clean.sh` must remain unchanged. It deliberately archives `HEAD`, provisions pinned GUT inside that temporary archive, and verifies committed-tree reproducibility.

That means it is a **post-commit gate**, not a RED/GREEN loop. Implementation first provisions the exact same GUT 9.7.1 tarball into gitignored local `addons/gut/`, then every inner RED/GREEN cycle runs GUT/headless scripts directly against the worktree. After each task commit, run `./tools/verify-clean.sh` to prove the committed archive.

When implementation lands, update `README.md` with only player-facing social controls/thresholds and update `CLAUDE.md`; keep the existing `AGENTS.md -> CLAUDE.md` symlink intact.

## Risks and mitigations

1. **Verification observes the previous commit instead of the change.** Never use `verify-clean.sh` for pre-commit RED/GREEN. Use local gitignored GUT/worktree commands; reserve the archive verifier for committed HEAD.
2. **Typed test seeding silently misses `_harvested_counts`.** Seed through a typed `Array[int]` helper that immediately asserts the snapshot received the values.
3. **Content drifts from HPA-595.** Treat the historical design as the oracle and pin its exact strings once in `test_villager_rules.gd`.
4. **Exact scene contracts go stale.** Update collision offsets, authored child lists, both child-count expressions, and crop indexes in the same geometry task.
5. **Input lock/focus gets stuck.** Reuse `has_blocking_modal()`/`modal_state_changed`, release focused descendants on close, and assert no GUI focus owner remains.
6. **Gift UI and session work separately but not together.** Add one typed real-data shell gift round-trip through the actual open panel.
7. **Persistence leaks into this slice.** Define no save version, repository, load path, migration, or compatibility behavior.

## Explicit non-goals

No NPC schedules, NPC movement/pathfinding, homes/interiors, quest system, romance, marriage, birthdays, relationship decay, disliked gifts, more than three villagers, portraits, voice acting, branching dialogue, generic dialogue/cutscene/event engine, generic item/inventory system, interaction registry, second input manager, save schema/repository, old-save migration, tutorial/finale behavior, localization infrastructure, mobile/controller remapping, backend/database, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactoring.
