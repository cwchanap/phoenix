# Phoenix Godot Social Port Design (HPA-594)

**Status:** Draft for review

**Date:** 2026-08-23

**Delivery target:** Godot 4.7.1 desktop social-parity slice

## Source of truth

This design implements Linear HPA-594, **[Godot Social Port] Restore the village, dialogue, gifting, and relationships**, immediately after HPA-589 restored the farming, daily-rhythm, and three-crop economy loop.

HPA-589 is Done and HPA-594 is now the first unblocked issue in the Phoenix active delivery order. HPA-594 blocks HPA-598 persistence, so relationship state must remain authoritative, deterministic, and easy to include in the later Godot save snapshot without designing persistence in this ticket.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves implementation details against `main` at `7c69d8bacbf416ea550608a43685dcf9328a32ed`.

## Outcome

Phoenix restores the existing three-villager social loop directly on top of the Godot gameplay session. Mira, Rowan, and June are static authored entities in the already-existing village path area. The player faces a villager and presses the existing `E` interaction key to talk, can give exactly one carried harvested crop per villager per day, and progresses through Stranger, Friend, and Close Friend using the frozen HPA-595 values.

The port keeps the current Godot shape small:

- `GameSession` remains the only mutable gameplay authority.
- one small `VillagerRules` module owns static social content and pure relationship policy;
- `WorldContract` owns villager cells and collision footprints;
- `WorldShell` keeps direct facing-derived interaction routing;
- one focused `DialoguePanel` owns line progression, native button focus, gift choice, and close behavior;
- `GameHud` remains the single modal/input-gate source.

There is no NPC manager, schedule/pathfinding layer, dialogue engine, event bus, quest framework, generic item system, or second gameplay authority.

## Existing seams to preserve

HPA-589 leaves four useful seams that HPA-594 should extend rather than replace:

1. `GameSession` owns all mutable farm/economy/day state and returns deeply isolated snapshots.
2. `WorldContract` contains authored logical geometry while `WorldMath` owns the 2:1 projection and facing target calculation.
3. `WorldShell` asks `PlayerController.current_target_cell()` and routes the existing `E` interaction directly to the matching world action.
4. `GameHud.has_blocking_modal()` is the only source used by `WorldShell` to disable player movement and manual world commands.

The existing village path (`x=3..9, y=6`) and `proof-villagers.png` (`96x48`) already survived the Godot cutover, so HPA-594 does **not** regenerate the map or assets.

## Approved lean shape

- Add exactly one new pure content/policy file: `scripts/game/villager_rules.gd`.
- Keep all relationship mutation inside the existing `GameSession`; do not add a social service/controller.
- Keep villager coordinates and footprints in `WorldContract`, not `VillagerRules` and not the session snapshot.
- Add `talk_to(villager_id, target_cell)` and `gift_crop(villager_id, crop_kind, target_cell)` as the only new session commands.
- Existing farming/economy commands continue returning `GameRules.CommandCode` directly.
- Social commands may return one narrow Dictionary because successful talk/gift needs one-shot authored lines and point feedback that cannot be reconstructed safely from the post-command snapshot alone. Do not generalize that shape to every command.
- Talking and gifting cost no time or stamina.
- Daily talk/gift flags reset only inside a successful existing `sleep()` transaction.
- Keep active dialogue line index and focus state out of `GameSession` and out of snapshots.
- Reuse the current modal input gate; do not add a second lock reason or input manager.
- Use the retained villager sprite sheet; do not generate or import new art.

## Frozen villager content

Villager enum order is deliberately the same as the retained three-frame sprite sheet:

| `VillagerId` | Key | Name | Role | Favourite crop | Cell | Sprite frame |
| --- | --- | --- | --- | --- | --- | ---: |
| `SHOPKEEPER` | `shopkeeper` | Mira | Seed-shop keeper | Potato | `(6,5)` | 0 |
| `FARMER` | `farmer` | Rowan | Neighbouring farmer | Pumpkin | `(3,5)` | 1 |
| `RESIDENT` | `resident` | June | Village resident | Turnip | `(9,5)` | 2 |

The cells remain immediately north of the existing path. Facing-derived targeting remains unchanged: the player must physically stand where the existing `WorldMath.TARGET_OFFSETS` causes the highlighted target cell to equal the villager cell.

### Relationship policy

| Rule | Value |
| --- | ---: |
| Stranger floor | 0 |
| Friend floor | 12 |
| Close Friend floor | 18 |
| First successful talk per villager/day | +1 |
| First normal gift per villager/day | +3 |
| Favourite gift bonus | +2 |

There is no cap, decay, disliked gift category, birthday modifier, randomness, time cost, or stamina cost.

### Exact dialogue content

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

## `VillagerRules`: static content and pure policy

Create `scripts/game/villager_rules.gd` as a `class_name VillagerRules` / `RefCounted` module.

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

Parallel closed arrays hold keys, names, role labels, favourite crop enums, normal dialogue, two-line Close Friend dialogue, and gift responses. Unit tests pin every array to `VillagerId.size()` so adding a villager cannot silently desynchronize authored tables.

Expose only small pure helpers used by the session/UI:

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

`VillagerRules` contains no coordinates, mutable flags, session references, nodes, focus state, persistence logic, or event dispatch.

## World geometry and rendering

### `WorldContract`

Keep the existing map, path, projection, camera, tree, building, farm, shop, bed, and shipping values unchanged.

Add villager geometry in enum order:

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

Expose `villager_cell(id)`, `villager_footprint(id)`, and `villager_at(cell)`. `villager_at` returns the matching enum value or `-1`; it is the only lookup needed by `WorldShell` for facing-derived interaction.

The 0.6×0.6 footprint deliberately reuses the established tree/shipping collision scale.

### `world.tscn`

Add three collision polygons under the existing `StaticCollision` node and set their polygons from `WorldContract` in `WorldShell._ready()`.

Add three static direct children under the existing one-Y-sort `Entities` node:

- `VillagerShopkeeper`
- `VillagerFarmer`
- `VillagerResident`

Each root sits at the center/footpoint of its authored cell:

```gdscript
WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
```

Each contains one `Sprite2D` using `proof-villagers.png`, `hframes = 3`, frame `0/1/2`, and bottom-center `offset = Vector2(0, -24)`.

Do not create a reusable NPC scene, `VillageView`, movement script, AnimationPlayer, Area2D interaction trigger, or second Y-sort root. Static scene nodes are sufficient for three fixed villagers.

## Authoritative relationship state

`GameSession` gains one array of mutable dictionaries in `VillagerId` order. Each entry contains exactly:

```gdscript
{
    "points": 0,
    "talked_today": false,
    "gifted_today": false,
    "close_friend_dialogue_seen": false,
}
```

Relationship level is derived from `points`; it is never stored redundantly.

`GameSession.snapshot()` adds one top-level `relationships` Dictionary keyed by `VillagerRules.villager_key(id)`. Each entry contains:

```gdscript
{
    "points": int,
    "level": StringName,
    "talked_today": bool,
    "gifted_today": bool,
    "close_friend_dialogue_seen": bool,
}
```

The snapshot does **not** duplicate villager coordinates, collision, line index, open-panel state, current dialogue text, focus, or Godot nodes. HPA-598 can later serialize the durable relationship fields from authoritative session state without HPA-594 defining a save version.

## Social command result

Existing commands keep the direct `GameRules.CommandCode` contract.

`talk_to` and `gift_crop` return one narrow Dictionary because the caller needs one-shot non-derivable feedback. Every result has the same keys:

```gdscript
{
    "code": GameRules.CommandCode,
    "lines": Array[String],
    "points_gained": int,
    "gift_reaction": StringName, # &"", &"normal", or &"favourite"
    "close_friend_sequence": bool,
}
```

Failures return the same shape with empty lines, `0`, empty reaction, and `false`. This remains local to social commands; do not create a generic command result type or retrofit farming/economy methods.

Add only these `GameRules.CommandCode` values:

- `VILLAGER_TALKED`
- `CROP_GIFTED`
- `NOT_AT_VILLAGER`
- `GIFT_ALREADY_GIVEN`

`INSUFFICIENT_CROPS` and `DAY_SUMMARY_PENDING` are reused.

## `talk_to`

`talk_to(id, target_cell)` executes in this exact order:

1. apply `_active_day_failure()`;
2. require `target_cell == WorldContract.villager_cell(id)`; otherwise return `NOT_AT_VILLAGER` without mutation;
3. if this is the first talk for that villager today, set `talked_today` and add `TALK_POINTS`; otherwise gain `0` but still succeed;
4. derive the resulting relationship level;
5. if the resulting level is Close Friend and `close_friend_dialogue_seen` is false, set that flag and return the exact two-line Close Friend sequence;
6. otherwise return the one normal line for the resulting level.

Repeated same-day talk is intentionally successful with `points_gained = 0`.

If a gift crosses the Close Friend floor after the player already talked that day, the next same-day talk still succeeds with `0` points and consumes the one-time sequence. This preserves HPA-595 behavior.

## `gift_crop`

`gift_crop(id, crop_kind, target_cell)` executes in this exact order:

1. apply `_active_day_failure()`;
2. require the authored villager target;
3. reject `GIFT_ALREADY_GIVEN` before checking inventory;
4. reject `INSUFFICIENT_CROPS` if no carried harvested crop of that kind exists;
5. consume exactly one carried harvested crop;
6. set `gifted_today`;
7. add `3`, plus `2` when the crop is that villager's favourite;
8. return the exact normal/favourite gift line and reaction.

A gift never directly consumes the Close Friend dialogue sequence. Relationship level may change immediately in the snapshot, but the one-time sequence is only emitted by a subsequent successful `talk_to`.

## Daily reset

Successful `sleep()` already performs the complete atomic day transition. Extend only that success path to clear every relationship's `talked_today` and `gifted_today` flags.

Do not reset:

- points;
- `close_friend_dialogue_seen`;
- flags on failed sleep;
- flags when Day 14 rejects advancement;
- flags on duplicate sleep while Morning Summary is pending.

Because the reset happens during the successful transition, the blocking Morning Summary exposes the next day's already-reset social state, matching the existing next-morning snapshot model.

## World interaction routing

Keep direct routing in `WorldShell`; do not introduce a generic interaction registry.

In `_process`, check `WorldContract.villager_at(player.current_target_cell())` and show `"<Name> — E"` when a villager is targeted. Existing Shop/Bed/Shipping hints stay unchanged.

In `interact()`:

1. return immediately when `_world_input_enabled` is false;
2. resolve the current target;
3. if `villager_at(target)` returns a villager, call `GameSession.talk_to` and finish the social result;
4. otherwise preserve the current Shop → Shipping → Bed → Nothing routing.

Add one `_finish_social_command(villager_id, result)` helper. On success it refreshes the session snapshot first, then opens/updates the dialogue panel with the returned lines. On failure it only shows the matching existing/new command feedback and refreshes normally.

`WorldShell` stores no relationship state and no active line index.

## Focused Godot dialogue/gifting panel

Create one `scenes/ui/dialogue_panel.tscn` + `scripts/ui/dialogue_panel.gd` component and instance it under `GameHud/HudRoot`.

The panel owns only presentation state:

- active villager ID;
- current `lines` and `line_index`;
- `points_gained` and gift reaction display;
- whether the current payload is the Close Friend sequence;
- the latest read-only relationship/inventory snapshot needed to render gift choices;
- native focus selection.

It emits:

```gdscript
signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested
```

It does not receive `GameSession`, mutate inventory, calculate relationship points, or know world coordinates.

### Visible content

Show only the current MVP information:

- villager name and role;
- relationship level and points;
- current dialogue line;
- `+N relationship point(s)` when points were gained;
- `Favourite gift!` or `Gift accepted.` after gift success;
- harvested-crop gift buttons after the final line when gifting is still available;
- `Gift already given today` or `No harvested crops to give` when appropriate;
- `Continue` for multi-line dialogue;
- `Close` after the final line.

Portraits remain out of scope.

### Native focus behavior

Dialogue buttons use Godot's default focusable `Button` behavior; do **not** use `GameHud._add_button`, because that helper intentionally sets `focus_mode = FOCUS_NONE` for always-visible HUD buttons.

When the panel opens or changes lines:

1. focus `Continue` while more lines remain;
2. otherwise focus the first available gift button;
3. if no gift button is available, focus `Close`.

One `ui_accept` press therefore activates exactly one focused button. No raw Enter key switch and no window-level listener are added.

Handle `ui_cancel` inside `DialoguePanel` while visible. For the one-time Close Friend sequence, ignore cancel until the final line so the sequence cannot be consumed without showing both lines; after the final line, cancel closes normally. Mark handled cancel/continue events so they do not fall through into world controls.

## Modal/input-lock integration

`GameHud` remains the single input-gate source.

Extend `has_blocking_modal()` to include the dialogue panel. Opening dialogue closes Shop/Shipping/Sleep panels, keeps Morning Summary authoritative, and emits `modal_state_changed`. Closing dialogue emits the same signal.

The existing `WorldShell._refresh_world_input_gate()` then automatically:

- disables `PlayerController` movement;
- zeros player velocity;
- blocks action selection;
- blocks farming use;
- blocks repeated world `E` interactions.

The existing action/seed buttons are already disabled whenever `has_blocking_modal()` is true, so no extra button-lock system is needed.

When Morning Summary becomes visible, force any non-summary modal, including dialogue, hidden before evaluating the gate. Runtime gameplay cannot normally sleep while dialogue is open, but this keeps `GameHud.render()` deterministic under direct tests.

## Gifting flow

After a normal talk line or the final Close Friend line, `DialoguePanel` builds at most one button for each carried crop with count > 0. Clicking a button emits one crop kind; quantity is always exactly one.

`GameHud` forwards the signal as `gift_requested(villager_id, crop_kind)`. `WorldShell` calls `GameSession.gift_crop` using the still-current player target. The player cannot move while the panel is open, so the target remains authoritative; the session still validates it.

On gift success:

1. refresh the session snapshot;
2. update the same dialogue panel with the exact gift response line;
3. render the new relationship points and inventory;
4. hide gift choices because `gifted_today` is now true;
5. focus Close.

Do not use a quantity picker or a generic inventory/item selector.

## Tests

### Pure social policy

Add `tests/unit/test_villager_rules.gd` to pin:

- all three IDs, keys, names, roles, favourites, and exact dialogue strings;
- parallel table sizes;
- Stranger/Friend/Close Friend boundaries at `0/12/18`;
- normal/favourite gift gains `3/5`.

### Session rules

Extend `tests/unit/test_game_session.gd` to cover:

- exact starter relationship snapshot and deep-copy isolation;
- wrong-target talk/gift atomicity;
- first talk +1 and repeat same-day talk +0;
- normal gift +3 and favourite gift +5;
- exactly one harvested crop consumed;
- duplicate gift and insufficient crop paths do not mutate;
- gift crossing Close Friend does not consume the special sequence;
- same-day follow-up talk emits the two-line sequence once;
- subsequent Close Friend talk emits the normal one-line dialogue;
- successful sleep resets only daily flags;
- pending Morning Summary blocks social commands;
- Day 14 failed sleep preserves all social state.

### Scene/world contract

Extend `tests/headless/world_shell_smoke.gd` and `tests/integration/test_gameplay_shell.gd` to pin:

- three villager collision polygons;
- direct `Entities` child names/order;
- exact cell-center anchors;
- retained `proof-villagers.png`, three frames, frame mapping, and bottom-center offset;
- villagers share the existing Y-sort/z-index system;
- facing-target interaction opens the correct villager panel;
- opening dialogue immediately disables player/world input;
- closing restores input without mutating session state;
- one `ui_accept` advances only one Close Friend line;
- gift button success consumes one crop and updates relationship UI;
- Escape cannot leave the world permanently locked.

No new E2E framework or input automation package is added.

## Documentation and verification

Update README controls/player-facing behavior when implementation lands:

- `E` on a villager talks;
- one harvested crop can be gifted per villager/day;
- Friend at 12 and Close Friend at 18.

Update `CLAUDE.md` only enough to record the `VillagerRules` / `GameSession` / `DialoguePanel` responsibilities if its architecture handoff requires it.

Keep the existing verification entry point unchanged:

```bash
./tools/verify-clean.sh
```

It already runs all unit/integration GUT tests and the three headless smoke scripts from a clean archive.

## Risks and mitigations

1. **Input lock gets stuck after dialogue.** Keep dialogue visibility inside `GameHud.has_blocking_modal()`, emit `modal_state_changed` on both open and close, and test close/Escape restoration directly.
2. **Close Friend sequence gets consumed without being seen.** Preserve the old session behavior of marking it seen when emitted, and block panel cancel until the final special line is reached.
3. **World geometry drifts from social targeting.** Store cells/footprints once in `WorldContract`; both session validation and `WorldShell.villager_at` read that contract.
4. **`GameRules` turns into a content dump.** Keep social dialogue/content in one small `VillagerRules` sibling while adding only four social command codes to `GameRules`.
5. **Persistence scope leaks into HPA-594.** Keep relationship state snapshot-friendly but define no file format, version, repository, load path, or migration; HPA-598 owns all persistence work.

## Explicit non-goals

No NPC schedules, NPC movement/pathfinding, homes/interiors, quest system, romance, marriage, birthdays, relationship decay, disliked gifts, more than three villagers, portraits, voice acting, branching dialogue, generic dialogue/cutscene/event engine, generic item/inventory system, Area2D interaction registry, second input manager, save schema/repository, old-save migration, tutorial/finale behavior, localization infrastructure, mobile/controller remapping, backend/database, C#, GDExtension, JavaScript/Tauri compatibility runtime, or unrelated refactoring.