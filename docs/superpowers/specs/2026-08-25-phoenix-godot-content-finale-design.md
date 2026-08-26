# Phoenix Godot Content and Harvest Finale Design (HPA-597)

**Status:** Draft for review — revised after Day 14 sequencing, fresh-world input, HUD hit-testing, and smoke-contract review

**Date:** 2026-08-25

**Delivery target:** contextual onboarding and one deterministic Day 14 harvest-market ending in the current Godot runtime

## Source of truth

This design implements HPA-597, `[Content Slice] Add contextual onboarding and the Day 14 harvest finale`, against `main` at `8c11bf5ac0aaa005e4de6792fb05dc558a04714c` after HPA-598 merged.

The live Linear issue and Phoenix project description remain authoritative. HPA-597 extends the repository vocabulary that already exists:

- `AppRoot` owns title/load/launch lifecycle and one `SaveRepository`;
- `WorldShell` owns the one live `GameSession`, direct world command routing, and the current post-sleep save handoff;
- `GameSession.state()` is the canonical persisted mutable projection and `GameSession.state_error()` is the single current-rule validator;
- `SaveFileCodec` is schema-v1, semantic-field-blind JSON transport and stays that way;
- `GameHud` owns the live gameplay HUD, blocking-modal census, and command feedback;
- `GameRules` owns crop/economy/day rules and `CommandCode`;
- `VillagerRules` owns the three villagers' static social content and relationship thresholds;
- `WorldContract` owns authored interaction cells/footprints;
- `world.tscn` is the authored Godot world source of truth;
- GUT unit/integration tests and the existing headless smokes are the verification path.

The superseded Phaser/Svelte HPA-597 planning branch is a product-behavior oracle only. No TypeScript, Svelte, Tauri, browser save, Tiled importer, or old-save compatibility code returns.

## Outcome

A fresh game opens with a two-line introduction that establishes the neglected farm, Mira, and the Day 14 harvest market. After that minimum introduction, gameplay is never put on rails: one small dismissible tutorial card points at the next currently useful action and completes only when the authoritative `GameSession` command succeeds.

The HUD keeps the Day 14 objective visible throughout the run. On Day 14 the player can end the run by interacting with the authored harvest-market stall. If they instead try to sleep, the same finale transaction runs. Both paths settle the pending Day 14 shipment exactly once, remain on Day 14, derive the same result from authoritative state, save the completed state once, and transition to one terminal result screen.

Completed saves Continue directly to the result screen. There is no Day 15, post-game free play, quest framework, tutorial state machine, cutscene engine, event registry, second save path, or migration layer.

## Repository findings that shape the design

### The current starter economy does not need HPA-597 tuning

`GameRules` already starts the player with 150G and three Turnip seeds. Turnips mature after three watered nights and sell for 35G. That is enough to teach the first crop cycle without changing balance. HPA-599 remains the deliberate balance/polish ticket.

### “During the first two days” cannot literally include harvest, shipping, and gifting

The ticket also says prompts appear only when their action first becomes relevant. The fastest crop requires three growth nights, so harvest, shipping, and gifting cannot all be naturally relevant in the first two days.

The relevance rule is the useful invariant. HPA-597 starts onboarding immediately on Day 1, teaches the initial farm/sleep loop first, and lets later harvest/shipping/gifting prompts appear when authoritative state makes them possible. It does not shorten Turnip growth or show impossible instructions merely to satisfy a literal two-day window.

### Current state loses cumulative shipping history

`pending_shipment` is paid and cleared on each successful sleep. `pending_morning_summary` describes only the latest settlement. The finale therefore cannot infer total shipped progress from current state.

HPA-597 adds one lifetime shipped crop-count vector to `GameSession`. Lifetime shipped value is derived from those counts and existing `GameRules.sale_value()` values rather than persisted a second time.

### Day 14 has a temporary hard stop that must be replaced atomically

Current `GameSession.sleep()` returns `DAY_LIMIT_REACHED` on Day 14. Current `WorldShell._on_sleep_requested()` only treats `DAY_ADVANCED` as a save handoff; all other codes go through ordinary `_finish_command()`.

That sequencing matters. The domain can gain `trigger_harvest_finale()` and `_complete_finale()` before the application routes the market, because no live production caller reaches them yet. Day 14 `sleep()`, however, must **not** start returning `FINALE_TRIGGERED` until `WorldShell`, `AppRoot`, and `ResultScreen` can consume that terminal state in the same vertical slice. Otherwise the session becomes terminal while the player remains stranded in the world.

Therefore:

- the authoritative HPA-597 fields, shipment helper, market finale command, and `_complete_finale()` land first;
- Day 14 bed keeps the existing `DAY_LIMIT_REACHED` behavior during that intermediate task;
- the later terminal-flow task changes Day 14 bed to `_complete_finale()`, adds `_finish_finale()`, result routing, final save, and removes `DAY_LIMIT_REACHED` plus its temporary HUD copy in one commit.

This is sequencing, not a second finale path.

### The opening changes the fresh-world test contract

A new session starts with `intro_acknowledged == false`. Once the opening participates in `GameHud.has_blocking_modal()`, `WorldShell._refresh_world_input_gate()` disables player input immediately.

Existing integration and headless smoke tests instantiate a fresh world and then press movement keys or call direct world interaction methods without a Start click. HPA-597 must update those tests deliberately:

- keep one explicit test proving a fresh world is locked by the opening;
- add a small test helper that presses the real opening `Start` button;
- call that helper before every existing integration case that expects live movement/world commands;
- call the same production-button path once in `world_shell_smoke.gd` before its movement/facing/collision/reachability section.

There is no production `skip_intro` flag or test-only bypass.

### HUD hit-testing must stay explicit

`GameHud/HudRoot` is already full-rect with `MOUSE_FILTER_IGNORE`, which lets current HUD buttons and gameplay coexist. A new full-rect overlay using the default `MOUSE_FILTER_STOP` would sit above the action/seed buttons and silently eat their mouse clicks even if `has_blocking_modal()` reports false.

The overlay contract is therefore explicit:

- full-rect `OnboardingOverlay` root: `MOUSE_FILTER_IGNORE`;
- opening panel: `MOUSE_FILTER_STOP` so the introduction really blocks clicks;
- tutorial card: one small `MOUSE_FILTER_STOP` panel positioned away from the action/seed bar, so its own Dismiss button is clickable without covering the rest of the HUD;
- the tutorial card never participates in `has_blocking_modal()`.

Scene tests pin that after Start, pressing an existing action button still emits `select_action_requested`. Godot documents `MOUSE_FILTER_IGNORE` specifically as not blocking other Controls from receiving mouse events, which is the behavior this layout relies on.

### The headless world smoke has several hard-coded scene contracts

Adding one fourth scenery frame and one market collision/entity changes more than the crop-child offset. HPA-597 updates all of the current hard-coded smoke facts together:

- `EXPECTED_ASSETS["proof-scenery"]`: `288x96 -> 384x96`;
- Tree/Building/Shipping scenery `hframes`: `3 -> 4`;
- collision order: Tree, Building, Shipping, **HarvestMarket**, three villagers, four perimeters;
- perimeter lookup offset: `index + 6 -> index + 7`;
- entity order: Player, Tree, Building, Shipping, **HarvestMarket**, three villagers, then dynamic crops;
- crop child offset: `7 + index -> 8 + index`;
- market entity shares the same entity `z_index` as Player/scenery/villagers/crops.

These are authored-scene bookkeeping changes only; they do not justify a generic scene registry.

## Considered approaches

### A. One pure content-policy module plus small `GameSession` state — chosen

Add one pure `ContentRules` sibling for tutorial definitions/eligibility and harvest-result derivation. Keep all mutable progress and all command completion in `GameSession`. Keep presentation in focused Godot `Control` scenes.

This adds one closed policy table rather than a tutorial engine plus a finale engine, keeps authoritative facts in one session, and makes direct GUT tests easy.

### B. Put prompt/finale rules directly in `GameHud` and `AppRoot` — rejected

This would initially save one file, but tutorial completion, tier rules, and cumulative progress would become presentation-owned. Save/Continue and direct rules tests would then depend on UI reconstruction.

### C. Generic tutorial/quest/cutscene/event framework — rejected

HPA-597 has one opening, nine contextual learning beats, one market interaction, and one ending. A generic graph/registry/DSL is more infrastructure than content and conflicts with Phoenix's slice-first delivery model.

## Approved lean shape

Keep these decisions fixed for HPA-597:

- Keep Godot 4.7.1, statically typed GDScript, one `GameSession`, and one `SaveRepository`.
- Keep `SaveFileCodec.SCHEMA_VERSION == 1`; the codec remains semantic-field-blind.
- Intentionally reject older development saves that lack the new HPA-597 state fields. No migration or compatibility fallback.
- Keep starting money, starter seeds, crop growth, sale values, weather/action costs, and relationship thresholds unchanged.
- Add one pure `ContentRules` module, not separate tutorial/finale frameworks.
- Persist only four new content facts: intro acknowledgement, exact tutorial completion flags, lifetime shipped crop counts, and finale-triggered state.
- Complete tutorial steps only inside successful authoritative `GameSession` command paths.
- Keep tutorial dismissal presentation-only and non-persistent.
- Show at most one relevant tutorial card and never block normal play after the opening is acknowledged.
- Combine “target a farm diamond” and “hoe” into one `farm_basics` prompt because targeting alone is not an authoritative gameplay command; successful `SOIL_TILLED` is its completion proof.
- Add the harvest market at logical cell `Vector2i(8, 6)` on the existing village path.
- Reuse the existing world projection/Y-sort/collision conventions; no second map layer or scene-switching festival map.
- Add one `ResultScreen` sibling under `AppRoot`; completed Continue never instantiates gameplay.
- Normal Day 1–13 sleep and Day 14 finale share one shipment-settlement helper.
- Both market and, once the terminal shell route lands, Day 14 sleep use one finale finalization method.
- Final save is synchronous and attempted once after the session reaches its terminal state. Save failure never revokes the ending; the result screen reports it.
- `New Game` from the result screen follows HPA-598 semantics and does not proactively delete the old slot.
- There is no post-game/free-play mode.
- HPA-599 owns deliberate balance tuning, packaging/export verification, and final presentation polish.

## Content policy

Create `scripts/game/content_rules.gd` with `class_name ContentRules extends RefCounted`.

It owns static copy and pure derived policy only. It never mutates `GameSession`, reads files, creates scenes, or stores runtime dismissal state.

### Tutorial identifiers

Use exactly these persisted keys, in this order:

```gdscript
const TUTORIAL_KEYS: Array[StringName] = [
    &"farm_basics",
    &"plant",
    &"water",
    &"sleep",
    &"talk",
    &"buy_seeds",
    &"harvest",
    &"shipping",
    &"gift",
]
```

`ContentRules.initial_tutorial_progress()` returns all nine keys as `false`.

### Opening copy

Keep the opening to two short lines:

1. `This farm has been quiet for a while. It is yours now — bring it back one day at a time.`
2. `Mira: The village harvest market is on Day 14. Grow what you can, and get to know the village before then.`

The opening blocks world input only until the player acknowledges it. It is not a cutscene sequence and has no branching.

### Tutorial copy and completion proof

| Step | Prompt | Authoritative success that completes it |
| --- | --- | --- |
| `farm_basics` | Face a farm diamond until the gold outline appears. Press 1 for Hoe, then Space. | `SOIL_TILLED` |
| `plant` | With tilled soil targeted, press 2 for Seeds, then Space. | `CROP_PLANTED` |
| `water` | On sunny days, press 3 for Water, then Space on a planted crop. | `CROP_WATERED` |
| `sleep` | When today's work is done, face the bed, press E, and sleep. | `DAY_ADVANCED` |
| `talk` | Face Mira, Rowan, or June and press E to talk. | `VILLAGER_TALKED` |
| `buy_seeds` | Face the seed counter, press E, and buy seeds to keep planting. | `SEEDS_PURCHASED` |
| `harvest` | A fully grown crop is ready. Press 4 for Hands, then Space. | `CROP_HARVESTED` |
| `shipping` | Carry harvested produce to the shipping bin and deposit it for next-morning income. | `CROP_DEPOSITED` |
| `gift` | Open a villager conversation while carrying a crop and choose a gift. | `CROP_GIFTED` |

Failed commands never complete a step. Selecting an action/seed never completes a step. Dismissing a card never completes a step.

### Prompt eligibility

`ContentRules.next_tutorial_prompt(snapshot: Dictionary, excluded: Array[StringName] = []) -> Dictionary` scans `TUTORIAL_KEYS` and returns the first incomplete, non-excluded, currently relevant prompt or `{}`.

Keep relevance predicates concrete and small:

- `farm_basics`: relevant after intro until completed;
- `plant`: at least one tilled empty farm cell and at least one seed exists;
- `water`: Sunny weather and at least one immature, unwatered planted crop;
- `sleep`: at least one planted crop has been watered today, or current weather is Rainy with a planted immature crop;
- `talk`: Day 2 or later;
- `buy_seeds`: Day 2 or later and the player can afford at least one Turnip seed;
- `harvest`: at least one mature crop exists;
- `shipping`: at least one harvested crop exists;
- `gift`: at least one harvested crop exists.

The onboarding overlay keeps transient dismissed prompt IDs and passes them as `excluded`. A reload may show an incomplete dismissed prompt again; only successful gameplay persists completion.

## Persisted content state

Extend `GameSession` with exactly:

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

`GameSession.state()` and the existing hand-built `snapshot()` dictionary must **both** explicitly copy the four new keys:

```gdscript
"intro_acknowledged": _intro_acknowledged,
"tutorial": _tutorial_progress.duplicate(true),
"shipped": _counts_snapshot(_shipped_counts),
"finale_triggered": _finale_triggered,
```

Do not assume `snapshot()` spreads future `state()` fields automatically; the current implementation enumerates its presentation keys. Do not introduce a second save DTO or nested schema object.

### Validation and restore

`GameSession.state_error()` remains the only gameplay validator. Extend the current `_field()`/`_counts_state_error()` style with checks that:

- `intro_acknowledged` is a boolean;
- `tutorial` is a dictionary containing exactly `ContentRules.TUTORIAL_KEYS`, each boolean;
- `shipped` contains exactly the crop keys and non-negative whole integers;
- `finale_triggered` is a boolean;
- a triggered finale is only valid on `GameRules.MAX_DAY`;
- a triggered finale has no pending morning summary;
- a triggered finale has an empty pending shipment, because finalization settles it first.

`restore_state()` canonicalizes JSON-decoded String keys back to runtime `StringName` tutorial/crop keys just as it already canonicalizes current crop/action/weather/relationship values. It never repairs missing HPA-597 fields.

`SaveFileCodec` and `SaveRepository` need no production changes and `SCHEMA_VERSION` remains 1.

## Authoritative tutorial completion

Add:

```gdscript
func acknowledge_intro() -> GameRules.CommandCode
```

Success sets `_intro_acknowledged = true` and returns `INTRO_ACKNOWLEDGED`; repeat acknowledgment returns `INTRO_ALREADY_ACKNOWLEDGED` without mutation.

Add one private helper that maps successful command codes to tutorial IDs. Call it only after the command has committed its authoritative mutation. Keep direct mappings rather than a generic command/event bus.

For social commands, completion occurs inside the successful `talk_to()` / `gift_crop()` path before returning the existing result dictionary. Repeated talking is still `VILLAGER_TALKED` and therefore valid completion because the authoritative talk command succeeded even when it awards zero repeat points.

## Lifetime shipment settlement

Extract the current payment/bin-clear logic from `sleep()` into one private helper:

```gdscript
func _settle_pending_shipment() -> Dictionary
```

It:

1. snapshots `_pending_shipment_counts`;
2. calls `GameRules.shipment_payout()` once;
3. increments `_shipped_counts` by exactly those quantities;
4. adds the payout total to `_money`;
5. clears `_pending_shipment_counts`;
6. returns the existing `lines`/`total` payout dictionary.

Day 1–13 sleep uses this helper and keeps creating the current morning summary from its returned payout. No normal-day behavior changes beyond recording lifetime shipped counts.

## Harvest result policy

Keep result derivation in `ContentRules` and mutable completion in `GameSession`.

Use:

```gdscript
const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300
```

`ContentRules.build_harvest_result(state: Dictionary) -> Dictionary` consumes the canonical **state**, not `snapshot()`. It derives cumulative shipped count/value with `GameRules.sale_value()`, final money, and relationship levels from each relationship's persisted raw `points` via `VillagerRules.relationship_level(points)`. It then chooses one `VillagerRules.finale_line()` per villager.

Evaluate tiers highest first:

- **Heart of the Harvest** — shipped value is at least `300G` **and** at least one villager is `Close Friend`;
- **Promising Farmer** — shipped value is at least `150G` **or** at least one villager is at least `Friend`;
- **New Beginning** — everything else.

Final money is displayed but does not affect the tier. There is no persisted result, score, hidden point system, tie-breaker, grade, or game-over branch. Continue re-derives the same result from validated terminal state.

These thresholds are inherited from the historical HPA-597 product plan and fit the current Godot sale values and 12/18-point relationship thresholds. HPA-599 may tune them after a full playthrough without changing architecture.

### Villager finale lines

Extend `VillagerRules` with one three-by-three static `FINALE_LINES` table indexed by villager and `RelationshipLevel`, plus:

```gdscript
static func finale_line(id: VillagerId, level: RelationshipLevel) -> String
```

Each villager contributes exactly one short line selected from final relationship progress. Keep this copy beside existing dialogue/gift content; do not add a story graph.

## Day 14 domain boundary and sequencing

Add command codes:

```gdscript
INTRO_ACKNOWLEDGED
INTRO_ALREADY_ACKNOWLEDGED
FINALE_TRIGGERED
MARKET_NOT_READY
NOT_AT_MARKET
FINALE_ALREADY_TRIGGERED
```

`DAY_LIMIT_REACHED` stays temporarily until the terminal application slice lands.

Add:

```gdscript
func trigger_harvest_finale(target_cell: Variant) -> GameRules.CommandCode
```

It requires no pending morning summary, finale not already triggered, exact Day 14, and exact `WorldContract.MARKET_CELL`, then delegates to `_complete_finale()`.

`_complete_finale()`:

1. rejects duplicate completion;
2. calls `_settle_pending_shipment()` exactly once;
3. sets `_finale_triggered = true`;
4. returns `FINALE_TRIGGERED`;
5. leaves `day == 14` and `pending_morning_summary == null`;
6. does not call the weather roll;
7. does not grow/reset crops, restore stamina/time, or reset daily social flags.

After `_finale_triggered`, `_active_day_failure()` returns `FINALE_ALREADY_TRIGGERED` for gameplay commands.

**Sequencing contract:** when these domain methods first land, Day 14 `sleep()` still returns the existing `DAY_LIMIT_REACHED` without mutation. The terminal application task then changes Day 14 bed to `_complete_finale()` **in the same commit** that teaches `WorldShell` to save/emit the terminal state and `AppRoot` to display `ResultScreen`. That task also removes `DAY_LIMIT_REACHED` and its temporary HUD/test references.

## Authored harvest market

Add to `WorldContract`:

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

`MARKET_ANCHOR` is `WorldMath.grid_to_world(Vector2(8.5, 6.5))`. The cell lies on the existing authored village path and is distinct from farm, shop, bed, shipping, tree, building, and villager interactions.

Add one `HarvestMarketCollision` under `StaticCollision` and one `HarvestMarket` under the existing Y-sorted `Entities`. Extend `proof-scenery.png` from `288x96` to `384x96` with one simple fourth 96x96 market-stall frame. Tree/Building/Shipping and HarvestMarket all use `hframes = 4`; the market uses frame 3.

Pin the scene order used by the current smoke tests:

- collisions: Tree, Building, Shipping, HarvestMarket, three villagers, four perimeters; perimeter offset becomes `index + 7`;
- entities: Player, Tree, Building, Shipping, HarvestMarket, three villagers, then dynamic crops;
- dynamic crop roots therefore begin at `8 + index`;
- HarvestMarket has the same entity `z_index` as the existing Player/scenery/villagers/crops.

Because `FarmView` resolves dynamic crop sprites by node name rather than child index, no production rendering refactor is required. This is proof-quality art; HPA-599 owns final presentation polish.

## Onboarding and objective UI

Create `scenes/ui/onboarding_overlay.tscn` + `scripts/ui/onboarding_overlay.gd` as one focused `Control` scene with a blocking opening panel, one contextual tutorial card, and transient dismissed prompt IDs.

Mouse/input contract:

```text
OnboardingOverlay root: MOUSE_FILTER_IGNORE
OpeningPanel:          MOUSE_FILTER_STOP
TutorialCard:          MOUSE_FILTER_STOP, small and away from Actions/Seeds
```

The tutorial card is non-blocking in the gameplay sense: it never participates in `GameHud.has_blocking_modal()` and does not cover the existing action/seed controls. Its own panel still consumes clicks inside the card so Dismiss behaves normally.

`GameHud.render(snapshot)` forwards the snapshot to the overlay. `GameHud` forwards `intro_acknowledged` to `WorldShell` and includes only the opening panel in `has_blocking_modal()`. When the opening becomes visible, close any other gameplay modal and emit the existing modal-state change; do not add a second input-lock system.

`WorldShell._on_intro_acknowledged()` mirrors morning-summary acknowledgement and calls `_finish_command(_session.acknowledge_intro())`; it does not add a separate `_world_input_enabled` check because the Start button is the event that releases the blocking modal through the authoritative refresh.

Add one always-visible objective label:

- Days 1–13: `Harvest Market: Day 14 · N days left`;
- Day 14: `Harvest Market today — village path stall`.

During the market/UI authoring task, the existing temporary Day 14 sleep/settlement warning remains because Day 14 bed still has its old domain behavior. The final terminal-flow task changes the warning to `Day 14: sleeping ends the run and settles the final shipment.`, adds the `Harvest Market — E` target hint and live market routing, and removes `DAY_LIMIT_REACHED` atomically with the domain flip.

## World routing and final save

Add to `WorldShell`:

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

The terminal-flow task routes `MARKET_CELL` interaction to `GameSession.trigger_harvest_finale(target)`, and changes Day 14 bed so the existing `sleep()` can return `FINALE_TRIGGERED`.

Both success paths call one `_finish_finale()` helper:

1. if the code is not `FINALE_TRIGGERED`, use ordinary `_finish_command(code)`;
2. refresh HUD/world from the terminal session state;
3. take `GameSession.state()` once;
4. synchronously save it through the configured repository exactly once, or use `ERR_UNAVAILABLE` for direct `world.tscn` tests with no repository;
5. emit `finale_completed(state, save_error)`.

Normal `DAY_ADVANCED` sleep keeps the existing morning-summary save/status behavior. No async queue, second save path, or save service is added.

Duplicate market/sleep calls after completion return `FINALE_ALREADY_TRIGGERED` and never reach the successful branch of `_finish_finale()`, so they cannot settle or save twice.

## Result screen and application routing

Create `scenes/ui/result_screen.tscn` + `scripts/ui/result_screen.gd` as a presentation-only sibling to `TitleScreen` under `AppRoot`.

It owns result title, shipped crop count/value, final money, relationship summary, one line from each villager, optional final-save failure copy, and `New Game` / `Return to Title` signals. It does not read files or mutate gameplay.

Extend `AppRoot`:

- keep loading/validating the single Continue state exactly as HPA-598 does;
- `_launch(initial_state)` may inspect `finale_triggered` only after validation; use direct indexing, not a silent default:

```gdscript
if initial_state != null and bool(initial_state["finale_triggered"]):
    _show_result(initial_state, OK)
    return
```

- when a live world emits `finale_completed`, derive through `ContentRules.build_harvest_result(final_state)`, remove the world, hide the title, and present the result;
- `New Game` from result hides the result and launches a fresh world without deleting the slot;
- `Return to Title` hides the result, shows title, and reloads title save state so Continue reflects the latest successful write.

A missing `finale_triggered` key is already an incompatible state at `GameSession.state_error()` and must not silently fall back to gameplay. If the final save failed, the ending still displays; returning to title may expose the previous valid autosave. No rollback/retry queue is added.

## Testing strategy

### Pure/unit tests

Add `tests/unit/test_content_rules.gd` for exact tutorial shape/relevance, rainy suppression, excluded prompts, all three tier boundaries, Heart's combined requirement, and deterministic villager finale lines. `build_harvest_result()` tests use canonical state-shaped relationship dictionaries with raw `points`, not snapshot `level` fields.

Extend `tests/unit/test_game_session.gd` for:

- new starter state and deep isolation, explicitly covering both `state()` and `snapshot()` keys;
- total validation/canonical restore of all HPA-597 fields and rejection of old/malformed states;
- successful command completion vs failed-command non-completion;
- intro acknowledgement idempotency;
- lifetime shipped counts across normal sleeps;
- market not-ready/off-target failures;
- Day 14 market finalization, final shipment settlement, duplicate protection, and terminal blocking;
- **before** the application terminal slice, Day 14 bed still returns `DAY_LIMIT_REACHED` unchanged;
- **in** the application terminal slice, replace that characterization with bed == market terminal-state equivalence and no Day 15/weather/crop advancement.

`tests/unit/test_save_file.gd` stays transport-focused. Add only a canonical GameSession encode/decode/restore case if existing generic coverage does not already exercise the new nested tutorial dictionary.

### Scene/integration tests

Extend existing tests rather than building new automation infrastructure:

- `test_gameplay_shell.gd`: fresh opening input lock; a helper pressing the real Start button for every existing test that expects movement/direct world commands; non-blocking tutorial/dismissal; action-button hit-testing under the overlay; exact market geometry/Y-sort/entity offset; objective copy; then market hint/interaction and Day 14 sleep fallback when terminal routing lands;
- `world_shell_smoke.gd`: update the scenery dimensions/hframes, collision/entity order, `+7` perimeter offset, `8 + index` crop offset, market shared z-index; press the real opening Start button before the existing movement/facing/collision/reachability checks;
- `test_app_launch.gd`: completed Continue routes directly to result; result New Game and Return to Title behavior;
- `test_persistence_flow.gd`: reuse the existing `CountingSaveRepository` to prove market and bed each save one terminal state, duplicates do not add a save, and completed save reopens directly to the result.

Do not add browser injection hooks, a movement E2E driver, production `skip_intro`, test-only production mutators, or a second save adapter. Existing narrow private-state fixtures may seed Day 14/relationship/count values for focused boundary tests, but immediately assert the seeded state before exercising public commands.

## Documentation and acceptance

Update `README.md` with the player-facing opening/tutorial/finale flow and Day 14 ending controls. Update `CLAUDE.md` with `ContentRules`, four persisted facts, market world contract, overlay input contract, shared settlement/finalization paths, WorldShell final-save handoff, AppRoot completed-result routing, and HPA-599 as the next balance/polish/export ticket. Keep `AGENTS.md -> CLAUDE.md` unchanged.

Final committed verification for HPA-597 uses the existing repository gate:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
```

Do not add a macOS export-release acceptance step to HPA-597. HPA-599 already owns packaging/export verification.

HPA-597 is complete when one command-driven run proves onboarding completion is authoritative, cumulative shipping survives save/continue, Day 14 market and bed produce the same deterministic terminal calculation, final shipment settles once, a completed save Continue opens the result screen, and no route can enter Day 15 or post-game gameplay.

## Explicit non-goals

- tutorial/quest/cutscene/event framework;
- branching opening or ending;
- festival minigames or competitions;
- animated crowds or NPC schedules;
- romance-specific endings;
- achievements or scoring framework;
- post-game/free-play;
- save migration, schema framework, backup slot, manual save, cloud save;
- browser/Tauri/TypeScript compatibility;
- new test automation framework;
- macOS packaging/export verification (HPA-599);
- unrelated world/UI refactors;
- balance changes that belong to HPA-599.
