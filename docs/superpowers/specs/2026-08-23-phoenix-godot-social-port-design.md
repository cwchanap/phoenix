# Phoenix Godot Social Port Design (HPA-594)

**Status:** Draft for review — revised against live Godot contracts

**Date:** 2026-08-23

**Delivery target:** Godot 4.7.1 desktop social-parity slice

## Source of truth

This design implements Linear HPA-594, **[Godot Social Port] Restore the village, dialogue, gifting, and relationships**, immediately after HPA-589 restored the farming, daily-rhythm, and three-crop economy loop.

The implementation baseline is Phoenix `main` at `7c69d8bacbf416ea550608a43685dcf9328a32ed`. The live repository handoff is `AGENTS.md`, which is a symlink to `CLAUDE.md`; both therefore describe the same current Godot architecture.

The shipped HPA-595 design at `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md` is the **behavior/content oracle** for this port. Names, role keys, cells, favourite crops, relationship gains/thresholds, gift replies, normal dialogue, and the one-time two-line Close Friend sequences below are copied verbatim from that oracle. HPA-594 changes the engine implementation only; it must not re-author those values.

The live Linear issue and Phoenix project description remain authoritative for scope and non-goals. HPA-594 blocks HPA-598 persistence, so relationship state must remain authoritative and snapshot-friendly without defining a save schema here.

## Live Godot baseline

HPA-594 extends these existing seams in place:

- `scripts/game/game_session.gd` — the only mutable farm/economy/day authority; `sleep()` owns the successful day transition and `snapshot()` returns isolated dictionaries.
- `scripts/game/game_rules.gd` — closed crop/action/weather rules plus `GameRules.CommandCode`.
- `scripts/world/world_contract.gd` — fixed map/farm/path/shop/bed/shipping geometry.
- `scripts/world/world_math.gd` — 2:1 projection, cell lookup, facing targets, and projected logical footprints.
- `scripts/world/world_shell.gd` — the only production `GameSession` holder; direct `E` routing and the current `_finish_command(code)` feedback/refresh path live here.
- `scripts/player/player_controller.gd` — `current_target_cell()` and movement input.
- `scripts/ui/game_hud.gd` / `scenes/ui/game_hud.tscn` — `$HudRoot`, code-built shop/shipping/sleep/summary modals, `show_feedback()`, and `has_blocking_modal()`.
- `scenes/world/world.tscn` — authored `StaticCollision` and one Y-sorted `Entities` root.
- `tests/unit/`, `tests/integration/test_gameplay_shell.gd`, `tests/headless/world_shell_smoke.gd` — the current direct test seams.
- `tools/verify-clean.sh` — the single clean-archive verification entry point.

Two scene contracts matter when villagers are inserted:

1. `tests/headless/world_shell_smoke.gd` pins the authored `World`, `StaticCollision`, and `Entities` child names/order.
2. `FarmView._ready()` appends nine runtime `FarmCrop_*` roots under `Entities`; `tests/integration/test_gameplay_shell.gd` currently expects `4 + farm_cells.size()` children. HPA-594 changes that exact count to `7 + farm_cells.size()` and shifts runtime crop assertions after the three new villager roots.

No parallel `scripts/game`, `WorldContract`, UI tree, test tree, or verification path is introduced.

## Outcome

Phoenix restores the existing three-villager social loop directly on top of the live Godot gameplay session. Mira, Rowan, and June are static authored entities immediately north of the existing village path. The player faces a villager and presses `E` to talk, can give exactly one carried harvested crop per villager per day, and progresses through Stranger, Friend, and Close Friend using the shipped HPA-595 policy.

The port keeps the existing shape small:

- `GameSession` remains the only mutable gameplay authority.
- one pure `VillagerRules` sibling owns frozen social content and relationship policy;
- `WorldContract` owns villager cells and collision footprints;
- `WorldShell` keeps direct facing-derived interaction routing;
- one focused `DialoguePanel` owns transient line/focus/gift-choice presentation;
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

It owns only:

```gdscript
enum VillagerId { SHOPKEEPER, FARMER, RESIDENT }
enum RelationshipLevel { STRANGER, FRIEND, CLOSE_FRIEND }

const TALK_POINTS := 1
const GIFT_POINTS := 3
const FAVOURITE_GIFT_BONUS := 2
const FRIEND_POINTS := 12
const CLOSE_FRIEND_POINTS := 18
```

Parallel arrays hold the oracle-copied keys, names, roles, favourites, normal dialogue, Close Friend sequences, and gift replies. `tests/unit/test_villager_rules.gd` pins every parallel array to `VillagerId.size()` and pins every spoken string against the HPA-595 oracle.

Expose only small pure helpers:

```gdscript
static func villager_key(id: VillagerId) -> StringName
static func display_name(id: VillagerId) -> String
static func role_label(id: VillagerId) -> String
static func favourite_crop(id: VillagerId) -> GameRules.CropKind
static func relationship_level(points: int) -> RelationshipLevel
static func relationship_key(level: RelationshipLevel) -> StringName
static func relationship_display_name(level: RelationshipLevel) -> String
static func dialogue_line(id: VillagerId, level: RelationshipLevel) -> String
static func close_friend_dialogue_lines(id: VillagerId) -> Array[String]
static func is_favourite(id: VillagerId, crop: GameRules.CropKind) -> bool
static func gift_points(id: VillagerId, crop: GameRules.CropKind) -> int
static func gift_line(id: VillagerId, crop: GameRules.CropKind) -> String
```

`VillagerRules` has no coordinates, mutable flags, nodes, session references, persistence, or event dispatch. Only four social codes are added to `GameRules.CommandCode`:

- `VILLAGER_TALKED`
- `CROP_GIFTED`
- `NOT_AT_VILLAGER`
- `GIFT_ALREADY_GIVEN`

Existing `INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` are reused.

## World geometry and scene contract

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

### `world.tscn` and `WorldShell._ready()`

Under the existing `StaticCollision`, add exactly:

- `VillagerShopkeeperCollision`
- `VillagerFarmerCollision`
- `VillagerResidentCollision`

Under the existing Y-sorted `Entities`, insert exactly after `Shipping` and before runtime crops:

- `VillagerShopkeeper`
- `VillagerFarmer`
- `VillagerResident`

Each villager root contains one `Sprite2D` using retained `res://assets/sprites/proof-villagers.png`, `hframes = 3`, frame `0/1/2`, and bottom-center `offset = Vector2(0, -24)`.

`WorldShell._ready()` derives each collision polygon from:

```gdscript
WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))
```

and derives each villager root position from the cell rather than introducing a second pixel-position authority:

```gdscript
WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5))
```

Scene tests assert that formula, not copied `(416,192)` / `(320,144)` / `(512,240)` literals.

`tests/headless/world_shell_smoke.gd` updates the exact `StaticCollision` and `Entities` name/order lists in the same task. `tests/integration/test_gameplay_shell.gd` updates its runtime child-count contract from `4 + farm_cells.size()` to `7 + farm_cells.size()`, with crop roots starting after index `7`.

Do not add a reusable NPC scene, `VillageView`, `Area2D` interaction layer, movement script, AnimationPlayer, or second Y-sort root.

## Authoritative relationship state

`GameSession` gains one mutable relationship entry per villager:

```gdscript
{
    "points": 0,
    "talked_today": false,
    "gifted_today": false,
    "close_friend_dialogue_seen": false,
}
```

Relationship level is derived from points and is never stored redundantly.

`GameSession.snapshot()` adds only one top-level `relationships` dictionary keyed by villager key. Each entry contains:

```gdscript
{
    "points": int,
    "level": StringName,
    "talked_today": bool,
    "gifted_today": bool,
    "close_friend_dialogue_seen": bool,
}
```

The snapshot does not duplicate villager cells/collision, dialogue text, line index, modal state, focus, or nodes.

## Narrow social command result

Existing farming/economy commands continue returning `GameRules.CommandCode` directly.

`talk_to` and `gift_crop` return one narrow dictionary because successful social actions need one-shot lines and `points_gained` that are not recoverable from the post-command snapshot alone:

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

### `talk_to`

`talk_to(id, target_cell)` executes:

1. `_active_day_failure()`;
2. require `target_cell == WorldContract.villager_cell(id)`;
3. first talk today sets `talked_today` and adds `+1`; repeats still succeed with `0`;
4. derive the resulting relationship level;
5. if Close Friend and `close_friend_dialogue_seen` is false, mark it seen and return the exact two-line oracle sequence;
6. otherwise return the one oracle normal line for that level.

A gift that crosses Close Friend does not consume the special sequence. A later same-day talk can emit it with `points_gained = 0`.

### `gift_crop`

`gift_crop(id, crop_kind, target_cell)` executes:

1. `_active_day_failure()`;
2. require the authored villager target;
3. reject `GIFT_ALREADY_GIVEN`;
4. reject `INSUFFICIENT_CROPS`;
5. consume exactly one `_harvested_counts[crop_kind]`;
6. set `gifted_today`;
7. add `3` plus favourite bonus `2` when applicable;
8. return the exact oracle gift line and `&"normal"` / `&"favourite"`.

## Daily reset

Extend only the existing successful `GameSession.sleep()` transaction to clear `talked_today` and `gifted_today` for all villagers. Preserve points and `close_friend_dialogue_seen`.

Failed sleep, Day 14 rejection, duplicate sleep while Morning Summary is pending, and `acknowledge_morning_summary()` do not reset social state.

## Direct world routing and feedback

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

This intentionally reuses the existing feedback system. Add the four social codes to `GameHud.show_feedback()`; do not introduce social toast state or another feedback route.

On social failure, `show_feedback` and `_refresh_from_session()` still run, but no dialogue open/update branch runs. Gift failures therefore leave an already-visible dialogue panel open while showing the normal HUD failure text.

## Dialogue panel inside the existing HUD

Use the existing `scenes/ui/` directory and `$HudRoot`; do not create a second CanvasLayer, modal stack, or UI directory.

Create one focused component:

- `scenes/ui/dialogue_panel.tscn`
- `scripts/ui/dialogue_panel.gd`

Instance it under `GameHud/HudRoot`. Shop/shipping/sleep/summary remain code-built as they are; only dialogue gets a small component because it owns transient line progression, dynamic gift buttons, and native focus.

The panel owns only:

- active villager ID;
- current social lines and line index;
- points/reaction display;
- Close Friend sequence flag;
- the latest read-only relationship/inventory snapshot needed to render gift choices;
- native focus selection.

It emits:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested
```

It never receives `GameSession`, mutates inventory, calculates relationship points, or knows world coordinates.

### Native focus and modal gate

Dialogue buttons use normal Godot focusable `Button` behavior. Do **not** use `GameHud._add_button`, which sets `FOCUS_NONE` for the current HUD controls.

Focus order is:

1. `Continue` while another line remains;
2. otherwise first available gift button;
3. otherwise `Close`.

Do not add raw Enter handling; focused buttons own `ui_accept`. Handle `ui_cancel` inside `DialoguePanel`; while a Close Friend sequence has another line, consume cancel without closing, then allow close after the final line.

Extend `GameHud.has_blocking_modal()` with dialogue visibility. Opening/closing dialogue emits the existing `modal_state_changed`. Morning Summary hides dialogue together with Shop/Shipping/Sleep before becoming visible. The existing `WorldShell._refresh_world_input_gate()` and action/seed button disable path remain unchanged.

## Test strategy

### Pure content/policy

`tests/unit/test_villager_rules.gd` is the literal content oracle test. It pins all HPA-595 strings and policy values once. Session and UI tests should prefer `VillagerRules` helpers/result payloads instead of re-authoring another independent copy of spoken lines.

### Session rules

Extend `tests/unit/test_game_session.gd` to prove the complete relationship behavior, including the three-social-day June journey:

```text
Day 1: talk +1, favourite gift +5 => 6 Stranger
sleep/ack
Day 2: talk +1, favourite gift +5 => 12 Friend
sleep/ack
Day 3: talk +1 => 13, favourite gift +5 => 18 Close Friend
same-day follow-up talk => +0 and two-line special sequence
next talk => +0 and normal Close Friend line
```

A bare `GameSession` unit test may seed its private `_harvested_counts` fixture because this suite already tests session internals directly. It must also cover wrong-target/duplicate/insufficient atomicity, snapshot isolation, daily reset, pending-summary blocking, and Day 14 failed-sleep preservation.

### Shell/UI integration

Do **not** add a test-only session mutation API, debug command bus, or private relationship/inventory injection through `WorldShell`.

At shell level prove only the cross-layer contract:

- facing target → `WorldShell.interact()` → correct villager panel;
- dialogue visibility immediately gates player/world input;
- close/Escape restores the existing gate;
- table-driven Mira/Rowan/June routing uses `WorldContract.villager_cell(id)`;
- a synthetic `DialoguePanel.present(...)` payload proves two-line native focus/cancel behavior without manufacturing relationship state in `WorldShell`;
- a synthetic snapshot with one carried crop proves exactly one native gift button and signal forwarding without pretending the UI test owns session mutation.

Actual talk/gift mutation, gift consumption, thresholds, and one-time-sequence semantics remain proven in `test_game_session.gd`. This keeps shell tests focused and avoids building a test API solely for HPA-594.

### Exact scene contract

In the geometry task, update in place:

- `tests/headless/world_shell_smoke.gd` exact `StaticCollision` names/order;
- `tests/headless/world_shell_smoke.gd` exact authored `Entities` names/order;
- cell-center positions via `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`;
- `tests/integration/test_gameplay_shell.gd` child count to `7 + farm_cells.size()` and crop-root offsets after the three villager children.

No new E2E framework or input automation package is added.

## Documentation and verification

When implementation lands, update `README.md` with only player-facing social controls/thresholds.

Update the repository handoff in `CLAUDE.md`; `AGENTS.md` is the 9-byte symlink whose target is `CLAUDE.md`, so do not replace the symlink with a second copy. The handoff should record `VillagerRules`, relationship ownership, villager geometry, `DialoguePanel`, the existing modal gate, and that HPA-598 owns persistence.

Keep the existing verifier unchanged as the single entry point:

```bash
./tools/verify-clean.sh
```

It already runs unit/integration GUT suites and all three headless smokes from a clean committed archive.

## Risks and mitigations

1. **Content drift from HPA-595.** Treat the historical design as the oracle and pin its exact strings once in `test_villager_rules.gd`.
2. **Input lock gets stuck.** Reuse `has_blocking_modal()` and `modal_state_changed`; test close/Escape restoration directly.
3. **Exact scene contracts go stale.** Update authored child lists and the `7 + farm_cells.size()` runtime invariant in the same geometry task.
4. **Shell tests grow a fake gameplay seam.** Keep the progression proof in bare `GameSession`; use synthetic panel payloads for UI-only focus/gift rendering.
5. **Persistence leaks into this slice.** Define no save version, repository, load path, migration, or compatibility behavior.

## Explicit non-goals

No NPC schedules, NPC movement/pathfinding, homes/interiors, quest system, romance, marriage, birthdays, relationship decay, disliked gifts, more than three villagers, portraits, voice acting, branching dialogue, generic dialogue/cutscene/event engine, generic item/inventory system, interaction registry, second input manager, save schema/repository, old-save migration, tutorial/finale behavior, localization infrastructure, mobile/controller remapping, backend/database, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactoring.
