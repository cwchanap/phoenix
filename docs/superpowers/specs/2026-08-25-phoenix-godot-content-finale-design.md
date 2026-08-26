# Phoenix Godot Content and Harvest Finale Design (HPA-597)

**Status:** Draft for review — revised after reuse/churn review

**Date:** 2026-08-25

**Revision:** 2026-08-26

**Delivery target:** contextual onboarding and one deterministic Day 14 harvest-market ending in the current Godot runtime

## Source of truth

This design implements HPA-597, `[Content Slice] Add contextual onboarding and the Day 14 harvest finale`, against `main` at `8c11bf5ac0aaa005e4de6792fb05dc558a04714c` after HPA-598 merged.

The live Linear issue and Phoenix project description remain authoritative. HPA-597 extends the current Godot vocabulary instead of introducing a parallel subsystem:

- `AppRoot` owns title/load/launch lifecycle and one `SaveRepository`;
- `WorldShell` owns the one live `GameSession`, direct world routing, and save handoff;
- `GameSession.state()` is the canonical persisted mutable projection;
- `GameSession.snapshot()` is the explicit view read model;
- `GameSession.state_error()` is the one current-rule validator;
- `SaveFileCodec` is schema-v1, semantic-field-blind transport and remains untouched;
- `GameHud` owns the live HUD and blocking-modal census;
- `DialoguePanel` proves the existing pattern for a code-built focused `Control` under `HudRoot`;
- `VillagerRules` owns static villager copy and relationship thresholds;
- `WorldContract` owns authored logical cells, footprints, and anchors;
- `world.tscn` is the authored world source of truth;
- GUT plus the existing headless smokes are the verification path.

The superseded Phaser/Svelte HPA-597 branch is a product-behavior reference only. No TypeScript, Svelte, Tauri, browser save, Tiled runtime importer, or old-save compatibility code returns.

## Outcome

A fresh run opens with a short blocking introduction that establishes the neglected farm and the Day 14 harvest market. After Start, one small dismissible contextual card points at the next useful action. Tutorial progress changes only when the authoritative gameplay command succeeds; dismissing a card is temporary presentation state.

The HUD keeps the Day 14 objective visible. On Day 14 the player can finish by interacting with one authored harvest-market stall, or by attempting to sleep. Both routes use the same terminal domain transaction, settle the shipping bin once, remain on Day 14, save the same terminal state once, and transition to one result screen.

Completed saves Continue directly to the result screen. There is no Day 15, post-game free play, tutorial/quest engine, cutscene framework, score object, second save route, or migration layer.

## Repository findings that shape the design

### Current balance already supports onboarding

`GameRules` starts the player with 150G and three Turnip seeds. Turnips mature after three watered nights and sell for 35G. HPA-597 does not change starter resources, crop values, growth, action costs, weather, or relationship thresholds. HPA-599 owns deliberate balance tuning.

### Later tutorial beats cannot literally fit in the first two days

Harvest, shipping, and gifting require a real harvest, while the fastest crop needs three growth nights. The useful ticket invariant is therefore relevance: prompts appear when the action is actually possible, rather than being forced into a literal two-day window.

### Current state loses cumulative shipping history

`pending_shipment` is paid and cleared by normal sleep. `pending_morning_summary` only describes the latest settlement. HPA-597 therefore persists lifetime shipped crop counts. Shipped value is always derived from those counts and `GameRules.sale_value()`; there is no persisted total value.

### Finale scoring is intentionally based on shipped crops, not carried inventory

The ticket explicitly evaluates cumulative **shipped** crop count/value and requires pending Day 14 shipping to settle once. Crops still in `harvested` inventory at completion are not auto-deposited and do not count toward the farming result.

This is deliberate rather than implicit. On Day 14 the UI tells the player to deposit crops they want counted before ending the run:

- shipping panel: `Day 14: only crops deposited here count toward the finale.`
- sleep panel: `Day 14: sleeping ends the run and settles the shipping bin.`
- objective: `Harvest Market today — ship crops first, then visit the village path stall.`

That preserves the existing shipping loop instead of making the market secretly bypass it.

### The temporary Day 14 hard stop is removed only with the complete terminal slice

Current `sleep()` returns `DAY_LIMIT_REACHED` on Day 14. There is no benefit in manufacturing a temporary intermediate finale API in an earlier task and then rewiring it later: every HPA-597 task lands in this one PR, and the terminal behavior is one cohesive vertical slice.

Tasks before the terminal slice may add the persisted `finale_triggered` field and validate it, but no command sets it. Task 4 adds the finale codes, `_complete_finale()`, market command, Day 14 sleep flip, shell save handoff, result screen, AppRoot routing, and removal of `DAY_LIMIT_REACHED` together.

### Existing UI construction patterns are enough

`DialoguePanel` is a code-built zero-size `Control` whose positioned inner `ColorRect` consumes mouse input. `GameHud` creates it with `DialoguePanel.new()` and parents it under `HudRoot`; the other gameplay modals are also built from `game_hud.gd`.

Onboarding follows that convention. `OnboardingOverlay` is a focused code-built `Control`, not a new `.tscn`. Its root has no hit area; the positioned OpeningPanel and TutorialCard are the only `STOP` surfaces. This keeps HUD structure in one representation and avoids a full-screen overlay that needs a special mouse-filter contract.

`ResultScreen` is different: it is an app-level screen sibling to `TitleScreen`, so a `.tscn` + presentation script is the existing app-screen pattern and remains appropriate.

## Considered approaches

### A. One pure content table + four persisted facts + one terminal slice — chosen

Add one pure `ContentRules` sibling. Keep mutable progression in `GameSession`, presentation under `GameHud`/`AppRoot`, and author one market entity in the existing world. Derive the ending from canonical state whenever needed.

### B. HUD-owned policy — rejected

Putting tutorial completion or result thresholds in UI would make persistence and rules depend on presentation reconstruction and would invert the existing state/view boundary.

### C. Generic tutorial/quest/cutscene/event system — rejected

Nine prompts and one ending do not justify a graph, registry, DSL, event bus, or quest engine.

## Approved lean shape

Keep these decisions fixed for HPA-597:

- one Godot 4.7.1 runtime and one `GameSession`;
- one concrete `SaveRepository` and one save file;
- `SaveFileCodec.SCHEMA_VERSION == 1`, semantic-field-blind, no migration;
- older development saves missing the new fields are incompatible and rejected loudly;
- one pure `ContentRules` module;
- one tutorial definition table, not parallel ID/copy/completion tables;
- exactly four new persisted facts: intro acknowledgement, tutorial completion flags, lifetime shipped crop counts, finale-triggered state;
- explicit copies of those facts in both `state()` and hand-built `snapshot()`;
- one `_commit()` success funnel for tutorial completion;
- one `_settle_pending_shipment()` helper shared by normal sleep and the finale;
- one `_complete_finale()` terminal transaction shared by Day 14 market and bed;
- one authored market on the existing Y-sorted world;
- code-built `OnboardingOverlay` following `DialoguePanel`;
- one presentation-only `ResultScreen` sibling under `AppRoot`;
- completed Continue never instantiates gameplay;
- terminal result is derived, never persisted;
- crops in hand do not count; only lifetime + pending shipped crops count after final settlement;
- final save failure never rolls back completion;
- New Game never proactively deletes the slot;
- no post-game/free-play;
- HPA-599 owns balance, polish, export/package verification.

## ContentRules: one closed tutorial table

Create `scripts/game/content_rules.gd`:

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
```

Do not also maintain a separate `TUTORIAL_KEYS` constant or command-to-ID table.

Derive the supporting APIs from `TUTORIALS`:

```gdscript
static func tutorial_keys() -> Array[StringName]
static func initial_tutorial_progress() -> Dictionary
static func tutorial_for_code(code: GameRules.CommandCode) -> StringName
static func next_tutorial_prompt(snapshot: Dictionary, excluded: Array[StringName] = []) -> Dictionary
```

`tutorial_keys()` returns the IDs in table order. `initial_tutorial_progress()` builds the exact false-key dictionary. `tutorial_for_code()` returns the matching ID or `&""`.

`next_tutorial_prompt()` scans the same table and calls one small `match id` relevance function. Relevance remains real code because each step has different state predicates; IDs/copy/completion mapping do not need parallel structures.

### Prompt relevance

Use these concrete predicates:

- `farm_basics`: intro acknowledged and not completed;
- `plant`: tilled empty soil plus at least one seed;
- `water`: Sunny and an immature unwatered crop exists;
- `sleep`: a crop was watered today, or Rainy with an immature planted crop;
- `talk`: Day 2+;
- `buy_seeds`: Day 2+ and at least one Turnip seed is affordable;
- `harvest`: a mature crop exists;
- `shipping`: harvested inventory exists;
- `gift`: harvested inventory exists.

At most one prompt is returned. Excluded/dismissed IDs are skipped. Dismissal never changes the persisted tutorial dictionary.

### Opening copy

Keep the opening to two short lines:

1. `This farm has been quiet for a while. It is yours now — bring it back one day at a time.`
2. `Mira: The village harvest market is on Day 14. Grow what you can, and get to know the village before then.`

The opening blocks world input only until Start. There is no branching or cutscene runner.

## Persisted state

Extend `GameSession` with:

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

Add exactly these four keys to both `state()` and the hand-built `snapshot()`:

```gdscript
"intro_acknowledged": _intro_acknowledged,
"tutorial": _tutorial_progress.duplicate(true),
"shipped": _counts_snapshot(_shipped_counts),
"finale_triggered": _finale_triggered,
```

Do not introduce a nested DTO or another persistence model.

### Validation and restore

`GameSession.state_error()` remains the only gameplay validator. Add checks that:

- `intro_acknowledged` is boolean;
- `tutorial` is a dictionary with exactly `ContentRules.tutorial_keys()`, every value boolean;
- `shipped` uses exactly the crop keys and non-negative whole integers through the existing count-validation style;
- `finale_triggered` is boolean;
- when true, day is exactly `MAX_DAY`, pending morning summary is null, and pending shipment is empty.

`restore_state()` canonicalizes JSON String keys back to runtime keys. It does not repair missing fields. `SaveFileCodec` and `SaveRepository` need no production edits.

## Authoritative tutorial completion

Add intro command codes in Task 2:

```gdscript
INTRO_ACKNOWLEDGED
INTRO_ALREADY_ACKNOWLEDGED
```

`acknowledge_intro()` flips the flag once; duplicate acknowledgement returns the duplicate code without mutation.

For ordinary successful commands, add one narrow funnel:

```gdscript
func _commit(code: GameRules.CommandCode) -> GameRules.CommandCode:
    var tutorial_id := ContentRules.tutorial_for_code(code)
    if tutorial_id != &"":
        _tutorial_progress[tutorial_id] = true
    return code
```

Success sites return through `_commit(...)` after their mutation has committed. Failure returns never call it.

The two social success paths already converge through `_social_success(...)`; call `_commit(code)` inside `_social_success()` before returning its result dictionary. This keeps talk/gift completion centralized without changing the social result shape.

Selecting an action/seed does not complete any tutorial because those codes are absent from `TUTORIALS`.

## Lifetime shipment settlement

Extract the existing payout/bin-clear transaction:

```gdscript
func _settle_pending_shipment() -> Dictionary:
    var payout := GameRules.shipment_payout(_counts_snapshot(_pending_shipment_counts))
    for kind in range(GameRules.CropKind.size()):
        _shipped_counts[kind] += _pending_shipment_counts[kind]
    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    return payout
```

Day 1–13 sleep uses this helper and otherwise keeps its current crop growth, weather, stamina, daily-social reset, morning summary, and save behavior.

Task 2 stops here for terminal behavior. `DAY_LIMIT_REACHED` remains the Day 14 sleep rule until Task 4.

## Harvest result policy

`ContentRules.build_harvest_result(state: Dictionary) -> Dictionary` consumes canonical `state()`, not `snapshot()`.

It derives:

- total shipped crop count;
- total shipped value using `GameRules.sale_value()`;
- final money for display only;
- relationship levels from raw persisted points using `VillagerRules.relationship_level()`;
- one villager finale line per final relationship level;
- tier key/title.

Thresholds:

- **Heart of the Harvest** — shipped value >= 300G and at least one Close Friend;
- **Promising Farmer** — shipped value >= 150G or at least one Friend-or-better;
- **New Beginning** — everything else.

Final money is not a tie-breaker. There is no persisted score/result object.

### Villager finale copy

Extend `VillagerRules` with one `[villager][relationship level]` `FINALE_LINES` table and:

```gdscript
static func finale_line(id: VillagerId, level: RelationshipLevel) -> String:
    return FINALE_LINES[id][level]
```

This matches the existing `NORMAL_DIALOGUE`/`dialogue_line()` shape.

## Authored harvest market

Add to `WorldContract`:

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

`MARKET_ANCHOR` equals `WorldMath.grid_to_world(Vector2(MARKET_CELL) + Vector2(0.5, 0.5))`.

Extend `proof-scenery.png` from `288x96` to `384x96`. Existing Tree/Building/Shipping use `hframes = 4`, frames 0/1/2; HarvestMarket uses frame 3. Add one `HarvestMarketCollision` after Shipping and one `HarvestMarket` entity after Shipping and before villagers.

`WorldShell._ready()` derives the market collision with `WorldMath.footprint_to_polygon()` like existing scenery.

Headless smoke pins all affected bookkeeping together:

- scenery asset `384x96`;
- scenery `hframes == 4`;
- collision order Tree, Building, Shipping, HarvestMarket, villagers, perimeters;
- perimeter offset `index + 7`;
- entity order Player, Tree, Building, Shipping, HarvestMarket, villagers, dynamic crops;
- dynamic crop offset `8 + index`;
- HarvestMarket anchor/frame/collision/shared z-index.

`FarmView` remains unchanged because it resolves crop roots by name.

## Onboarding UI

Create only `scripts/ui/onboarding_overlay.gd`:

```gdscript
class_name OnboardingOverlay
extends Control

signal intro_acknowledged

var _dismissed: Array[StringName] = []
```

`GameHud._build_modals()` instantiates it with `OnboardingOverlay.new()`, names it `OnboardingOverlay`, parents it to `HudRoot`, and connects its signal.

Like `DialoguePanel`, the root keeps its default zero size. `_ready()` creates positioned children:

- `OpeningPanel`: `ColorRect`, `MOUSE_FILTER_STOP`, two opening lines + Start;
- `TutorialCard`: small `ColorRect`, `MOUSE_FILTER_STOP`, title/body + Dismiss.

There is no full-rect overlay node and no `onboarding_overlay.tscn`.

`GameHud.render(snapshot)` forwards the snapshot. Only a visible OpeningPanel participates in `has_blocking_modal()`. TutorialCard is never a world-input blocker.

A scene test presses a normal HUD action button while TutorialCard is visible and proves `select_action_requested` still emits. This guards the actual hit-testing regression without adding a special root mouse-filter contract.

### Test factory contract

Most `test_gameplay_shell.gd` tests describe the post-opening gameplay shell. Avoid a per-test Start tax:

- private `_spawn_world(acknowledge_intro: bool)` instantiates the real scene;
- `_world()` calls `_spawn_world(true)` and presses the real `OpeningPanel/Start` button synchronously before returning;
- `_locked_world()` calls `_spawn_world(false)` for the one opening-lock test.

No production skip flag or direct `_intro_acknowledged` mutation exists.

The headless smoke has only one world instance; it presses the real Start button once before the first movement/action section. Structural scene checks may run before that.

## Atomic terminal slice

Task 4 introduces all live finale behavior together.

Add command codes:

```gdscript
FINALE_TRIGGERED
MARKET_NOT_READY
NOT_AT_MARKET
FINALE_ALREADY_TRIGGERED
```

Remove `DAY_LIMIT_REACHED` in the same task after the new bed path is live.

Add:

```gdscript
func trigger_harvest_finale(target_cell: Variant) -> GameRules.CommandCode
```

It requires no pending summary, no prior finale, exact Day 14, and exact `MARKET_CELL`, then delegates to `_complete_finale()`.

Change Day 14 `sleep()` after its existing bed/active-state checks to delegate to the same helper.

```gdscript
func _complete_finale() -> GameRules.CommandCode:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
    _settle_pending_shipment()
    _finale_triggered = true
    return GameRules.CommandCode.FINALE_TRIGGERED
```

The helper:

- settles only `_pending_shipment_counts`;
- does **not** move `_harvested_counts` into shipping;
- leaves day == 14;
- creates no morning summary;
- performs no weather roll/crop growth/time/stamina/social reset.

After completion `_active_day_failure()` returns `FINALE_ALREADY_TRIGGERED` for gameplay commands.

## World routing and final save

Add to `WorldShell`:

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

Market targeting displays `Harvest Market — E` only after the terminal route exists.

Market interaction calls `trigger_harvest_finale()`. Day 14 bed confirmation receives `FINALE_TRIGGERED` from `sleep()`. Both call one `_finish_finale()`:

1. show feedback and refresh from terminal state;
2. capture canonical `state()`;
3. synchronously save once through the configured repository, or use `ERR_UNAVAILABLE` for direct world tests;
4. emit `finale_completed(state, save_error)`.

Normal `DAY_ADVANCED` keeps the existing morning-summary save path unchanged.

Duplicate terminal commands do not reach `_finish_finale()`, so settlement/save cannot repeat.

## ResultScreen and AppRoot routing

Create `scenes/ui/result_screen.tscn` + `scripts/ui/result_screen.gd` as the app-level sibling to `TitleScreen`.

`ResultScreen` receives a derived result dictionary and save error. It owns labels plus `New Game` and `Return to Title` signals only; it never reads files or creates a session.

`AppRoot._load_title_state()` continues to validate the save through `GameSession.state_error()`. `_launch(initial_state)` routes completed validated state with direct indexing:

```gdscript
if initial_state != null and bool(initial_state["finale_triggered"]):
    _show_result(initial_state, OK)
    return
```

Do not use `.get("finale_triggered", false)`.

When a live world emits `finale_completed`, `_show_result()` derives `ContentRules.build_harvest_result(final_state)` and tears the world down safely:

```gdscript
var world := get_node_or_null("World")
if world != null:
    remove_child(world)
    world.queue_free()
```

Use `queue_free()`, never `free()`, because the finale signal is emitted synchronously from the WorldShell call stack. `remove_child()` clears the `_launch()` `World` guard immediately, so a same-frame Result -> New Game is not swallowed by a queued node that is still parented.

Then hide title and show the result.

- Result -> New Game hides result and launches a fresh world without deleting the existing slot.
- Result -> Return to Title hides result, shows title, and reloads the save state.
- If final save failed, result still displays; Return to Title may expose the previous valid autosave. No rollback or retry queue is added.

## Testing strategy

### Unit

`test_content_rules.gd` pins:

- exact `TUTORIALS` IDs/order/copy/completed_by values;
- `tutorial_keys()`, initial progress, and `tutorial_for_code()` all derive from that table;
- prompt relevance/order/exclusion;
- rainy-day water suppression;
- mature harvest prompt;
- tier boundaries at 150G/300G;
- Heart requires both farming threshold + Close Friend;
- result uses raw relationship points from canonical state;
- carried `harvested` inventory does not affect shipped totals/result.

`test_game_session.gd` pins:

- four new starter fields in both state/snapshot and deep isolation;
- total validation/canonical restore;
- old state missing fields rejected;
- `_commit()` completion only after successful commands;
- social success completion through `_social_success()`;
- intro acknowledgement idempotency;
- lifetime shipped counts across normal sleeps;
- Task 2 still keeps current Day 14 `DAY_LIMIT_REACHED` behavior;
- Task 4 replaces that with market/bed equivalent finalization;
- final shipment settles once;
- carried harvested inventory stays carried and uncounted;
- no Day 15/weather/crop/reset on completion;
- duplicate/terminal blocking.

`test_save_file.gd` remains transport-focused; add no field-aware parsing.

### Scene/integration

`test_gameplay_shell.gd`:

- `_world()` acknowledges Start through real UI by default;
- `_locked_world()` proves one fresh-world input lock;
- market geometry/Y-sort/entity offset;
- tutorial Dismiss is transient;
- TutorialCard does not block action-button signal/click path;
- objective/Day 14 shipped-only copy;
- market hint/interaction once terminal routing lands;
- Day 14 bed fallback.

`test_persistence_flow.gd` reuses the existing `CountingSaveRepository` for both terminal routes and proves one save.

`test_app_launch.gd` proves completed Continue opens ResultScreen without World and exercises Result -> New Game/Return Title.

`world_shell_smoke.gd` pins market bookkeeping and presses real Start once before movement/action checks.

No browser hooks, new E2E framework, production mutation API, second save fake, or skip-intro setting is added.

## Documentation and acceptance

Update `README.md` with opening/help, Day 14 shipping-only result rule, market/sleep finish controls, three encouraging endings, completed Continue, and no post-game.

Update `CLAUDE.md` with:

- `ContentRules.TUTORIALS` as the single tutorial identity/copy/completion table;
- `_commit()` tutorial-completion funnel;
- four persisted fields / no migration;
- lifetime shipped counts + shipped-only finale semantics;
- code-built OnboardingOverlay;
- market world contract;
- shared settlement/finalization;
- `remove_child()` + `queue_free()` result handoff;
- HPA-599 next for balance/polish/export.

Final committed verification remains:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
```

No macOS export-release step belongs to HPA-597; HPA-599 owns packaging verification.

## Explicit non-goals

- tutorial/quest/cutscene/event framework;
- branching opening/ending;
- festival minigames or competition logic;
- animated crowd/NPC schedules;
- romance-specific endings;
- persisted score/result object;
- automatic conversion of carried crops into shipped crops at the finale;
- post-game/free-play;
- save migration/schema framework/backups/manual/cloud save;
- browser/Tauri/TypeScript compatibility;
- new test automation framework;
- production skip-intro/test flags;
- unrelated world/UI refactors;
- balance changes or packaging work owned by HPA-599.
