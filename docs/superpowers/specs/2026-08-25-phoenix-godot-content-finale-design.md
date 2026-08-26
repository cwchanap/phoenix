# Phoenix Godot Content and Harvest Finale Design (HPA-597)

**Status:** Draft for review

**Date:** 2026-08-25

**Delivery target:** contextual onboarding and one deterministic Day 14 harvest-market ending in the current Godot runtime

## Source of truth

This design implements HPA-597, `[Content Slice] Add contextual onboarding and the Day 14 harvest finale`, against `main` at `8c11bf5ac0aaa005e4de6792fb05dc558a04714c` after HPA-598 merged.

The live Linear issue and Phoenix project description remain authoritative. This design deliberately extends the repository vocabulary that already exists:

- `AppRoot` owns title/load/launch lifecycle and one `SaveRepository`;
- `WorldShell` owns the one live `GameSession`, direct world command routing, and the post-sleep save handoff;
- `GameSession.state()` is the canonical persisted mutable projection and `GameSession.state_error()` is the single current-rule validator;
- `SaveFileCodec` is schema-v1, semantic-field-blind JSON transport and stays that way;
- `GameHud` owns the live gameplay HUD, blocking modal census, and command feedback;
- `VillagerRules` owns the three villagers' static social content and relationship thresholds;
- `WorldContract` owns authored interaction cells/footprints;
- `world.tscn` is the authored Godot world source of truth;
- GUT unit/integration tests and the existing headless smokes are the verification path.

The superseded Phaser/Svelte HPA-597 planning branch is used only as a product-behavior oracle. No TypeScript, Svelte, Tauri, browser save, Tiled importer, or old-save compatibility code returns.

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

HPA-597 adds one lifetime shipped crop-count vector to `GameSession`. Lifetime shipped value is derived from those counts and the existing `GameRules.sale_value()` values rather than persisted a second time.

### Day 14 already has a temporary hard stop

Current `GameSession.sleep()` returns `DAY_LIMIT_REACHED` on Day 14 without settling the pending shipping bin. Current HUD copy explicitly warns that Day 14 shipping cannot settle.

HPA-597 replaces that temporary boundary. Day 14 bed confirmation becomes a finale fallback, and both bed and market use one private finalization path that first settles the pending shipment and then records completion. No weather roll, crop growth, stamina reset, relationship daily reset, or morning summary occurs because there is no next day.

### Existing application and save seams are enough

`AppRoot` already distinguishes title from gameplay and validates Continue before launch. `WorldShell` already owns the only post-day save. `SaveFileCodec` already transports arbitrary nested JSON-compatible state without knowing gameplay fields.

The finale therefore does not need a festival controller, save service, global singleton, or schema migration. `AppRoot` gets one presentation-only sibling `ResultScreen`; `WorldShell` emits one finale handoff after it synchronously attempts the existing repository save.

## Considered approaches

### A. One pure content-policy module plus small `GameSession` state — chosen

Add one pure `ContentRules` sibling for tutorial definitions/eligibility and harvest-result derivation. Keep all mutable progress and all command completion in `GameSession`. Keep presentation in focused Godot `Control` scenes.

This adds one policy module instead of a tutorial engine plus a finale engine, keeps authoritative facts in one session, and makes direct GUT tests easy.

### B. Put prompt/finale rules directly in `GameHud` and `AppRoot` — rejected

This would initially save one file, but tutorial completion, tier rules, and cumulative progress would become presentation-owned. Save/Continue and direct rules tests would then depend on UI reconstruction.

### C. Generic tutorial/quest/cutscene/event framework — rejected

HPA-597 has one opening, nine contextual learning beats, one market interaction, and one ending. A generic graph/registry/DSL is more infrastructure than content and conflicts with Phoenix's slice-first delivery model.

## Approved lean shape

Keep these decisions fixed for HPA-597:

- Keep Godot 4.7.1, statically typed GDScript, one `GameSession`, and one `SaveRepository`.
- Keep `SaveFileCodec.SCHEMA_VERSION == 1`; the codec remains semantic-field-blind.
- Intentionally reject older development saves that lack the new HPA-597 state fields. No migration or compatibility fallback.
- Keep starting money, starter seeds, crop growth, sale values, and relationship thresholds unchanged.
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
- Both market and Day 14 sleep use one finale finalization method.
- Final save is synchronous and attempted once after the session reaches its terminal state. Save failure never revokes the ending; the result screen reports it.
- `New Game` from the result screen follows HPA-598 semantics and does not proactively delete the old slot.
- There is no post-game/free-play mode.

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

The onboarding overlay keeps a transient set of dismissed prompt IDs and passes it as `excluded`. This lets the player dismiss `talk`, for example, and continue seeing later relevant help during the current application run. A reload may show an incomplete dismissed prompt again; only successful gameplay persists completion.

## Persisted content state

Extend `GameSession` with:

```gdscript
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _shipped_counts: Array[int] = [0, 0, 0]
var _finale_triggered := false
```

Extend `state()` and `snapshot()` directly with:

```gdscript
"intro_acknowledged": _intro_acknowledged,
"tutorial": _tutorial_progress.duplicate(true),
"shipped": _counts_snapshot(_shipped_counts),
"finale_triggered": _finale_triggered,
```

Do not introduce a second save DTO or a nested schema object. The current flat state projection is already the canonical persistence boundary.

### Validation and restore

`GameSession.state_error()` remains the only gameplay validator. Add checks that:

- `intro_acknowledged` is a boolean;
- `tutorial` is a dictionary containing exactly `ContentRules.TUTORIAL_KEYS`, each boolean;
- `shipped` contains exactly the crop keys and non-negative whole integers;
- `finale_triggered` is a boolean;
- a triggered finale is only valid on `GameRules.MAX_DAY`;
- a triggered finale has no pending morning summary;
- a triggered finale has an empty pending shipment, because finalization settles it first.

`restore_state()` canonicalizes JSON-decoded String keys back to the runtime `StringName` tutorial/crop keys just as it already canonicalizes crop/action/weather/relationship values. It never repairs missing HPA-597 fields.

`SaveFileCodec` and `SaveRepository` need no production changes.

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

1. takes a snapshot of `_pending_shipment_counts`;
2. calls `GameRules.shipment_payout()` once;
3. increments `_shipped_counts` by exactly those quantities;
4. adds the payout total to `_money`;
5. clears `_pending_shipment_counts`;
6. returns the existing `lines`/`total` payout dictionary for presentation callers.

Day 1–13 sleep uses this helper and keeps creating the current morning summary from its returned payout. No normal-day behavior changes beyond recording lifetime shipped counts.

## Harvest result policy

Keep result derivation in `ContentRules` and keep mutable completion in `GameSession`.

Use:

```gdscript
const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300
```

`ContentRules.build_harvest_result(state: Dictionary) -> Dictionary` derives cumulative shipped count/value, final money, relationship levels, and villager lines from the terminal state.

Evaluate tiers highest first:

- **Heart of the Harvest** — shipped value is at least `300G` **and** at least one villager is `Close Friend`;
- **Promising Farmer** — shipped value is at least `150G` **or** at least one villager is at least `Friend`;
- **New Beginning** — everything else.

Final money is displayed but does not affect the tier. There is no score, hidden point system, tie-breaker, grade, or game-over branch.

These thresholds are intentionally inherited from the historical HPA-597 product plan. They fit the current Godot sale values and 12/18-point relationship thresholds. HPA-599 may tune them after a full playthrough without changing architecture.

### Villager finale lines

Extend `VillagerRules` with one three-by-three static `FINALE_LINES` table indexed by villager and `RelationshipLevel`, plus:

```gdscript
static func finale_line(id: VillagerId, level: RelationshipLevel) -> String
```

Each villager contributes exactly one short line selected from final relationship progress. Keep this copy beside existing dialogue/gift content; do not add a story graph.

## Day 14 domain boundary

Add command codes:

```gdscript
INTRO_ACKNOWLEDGED
INTRO_ALREADY_ACKNOWLEDGED
FINALE_TRIGGERED
MARKET_NOT_READY
NOT_AT_MARKET
FINALE_ALREADY_TRIGGERED
```

Remove `DAY_LIMIT_REACHED` once no production path uses it.

Add:

```gdscript
func trigger_harvest_finale(target_cell: Variant) -> GameRules.CommandCode
```

It requires:

1. no pending morning summary;
2. finale not already triggered;
3. exact Day 14;
4. exact `WorldContract.MARKET_CELL` target.

It then delegates to `_complete_finale()`.

Day 14 `sleep()` still requires the authored bed target, but after that target check it delegates to the same `_complete_finale()` instead of returning `DAY_LIMIT_REACHED`.

`_complete_finale()`:

1. rejects duplicate completion;
2. calls `_settle_pending_shipment()` exactly once;
3. sets `_finale_triggered = true`;
4. returns `FINALE_TRIGGERED`;
5. leaves `day == 14`;
6. leaves `pending_morning_summary == null`;
7. does not call the weather roll;
8. does not grow/reset crops, restore stamina/time, or reset daily social flags.

After `_finale_triggered`, `_active_day_failure()` returns `FINALE_ALREADY_TRIGGERED` for gameplay commands. In normal application flow the world is immediately replaced by the result screen, but the domain invariant still prevents duplicate direct calls and duplicate save/settlement behavior.

## Authored harvest market

Add to `WorldContract`:

```gdscript
const MARKET_CELL := Vector2i(8, 6)
const MARKET_FOOTPRINT := Rect2(8.2, 6.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(448.0, 240.0)
```

The cell lies on the existing authored village path and is distinct from farm, shop, bed, shipping, tree, building, and villager interactions.

Add one `HarvestMarketCollision` under `StaticCollision` and one `HarvestMarket` under the existing Y-sorted `Entities`. Keep its ground contact at the authored anchor and use the existing scenery sprite sheet convention. Extend `proof-scenery.png` with one simple fourth 96×96 market-stall frame and change the existing scenery sprites to `hframes = 4`; the market uses frame 3.

This is deliberately proof-quality art. HPA-599 owns final presentation polish.

Because `FarmView` resolves dynamic crop sprites by node name rather than child index, no production rendering refactor is required. Scene tests that pin child arithmetic change from `7 + farm_cells.size()` / `7 + index` to `8 + farm_cells.size()` / `8 + index`.

## Onboarding and objective UI

Create `scenes/ui/onboarding_overlay.tscn` + `scripts/ui/onboarding_overlay.gd` as one focused `Control` scene with:

- a blocking opening panel with the two opening lines and one `Start` button;
- one non-blocking contextual tutorial card with title/body and `Dismiss`;
- transient dismissed prompt IDs held only by this scene.

Signals:

```gdscript
signal intro_acknowledged
signal blocking_state_changed
```

`GameHud.render(snapshot)` forwards the snapshot to the overlay. `GameHud` forwards `intro_acknowledged` to `WorldShell` and includes only the opening panel in `has_blocking_modal()`. The contextual card must not disable movement, tools, interaction, shop, dialogue, or sleep.

When the opening becomes visible, close any other gameplay modal and emit the existing modal-state change so the current player-input gate is reused. Do not add a second input-lock system.

Add one always-visible HUD objective label:

- Days 1–13: `Harvest Market: Day 14 · N days left`;
- Day 14: `Harvest Market today — village path stall`.

When the player directly targets `MARKET_CELL`, `WorldShell` shows `Harvest Market — E`.

Replace the temporary Day 14 shipping/sleep warnings with:

- shipping: `Day 14 shipment settles when the finale starts.`;
- sleep: `Day 14: sleeping ends the run and settles the final shipment.`

## World routing and final save

Add to `WorldShell`:

```gdscript
signal finale_completed(final_state: Dictionary, save_error: int)
```

Direct interaction order remains simple: villager, shop, shipping, bed, market (or market before the generic fallback; exact ordering only needs to preserve distinct cells).

Market interaction calls `GameSession.trigger_harvest_finale(target)`. Day 14 bed confirmation receives `FINALE_TRIGGERED` from the existing `sleep()` call.

Both success paths call one `_finish_finale()` helper in `WorldShell`:

1. refresh HUD/world from the terminal session state;
2. synchronously save `GameSession.state()` through the already-configured repository exactly once;
3. emit `finale_completed(state, save_error)`.

For direct `world.tscn` tests with no repository, use `ERR_UNAVAILABLE` as the handoff error and do not invent a repository fallback.

Normal `DAY_ADVANCED` sleep keeps the existing morning-summary save/status behavior. A tiny private save helper may be shared if it reduces duplication, but do not introduce a save service or async queue.

Duplicate market/sleep calls after completion return `FINALE_ALREADY_TRIGGERED` and never reach `_finish_finale()`, so they cannot settle or save twice.

## Result screen and application routing

Create `scenes/ui/result_screen.tscn` + `scripts/ui/result_screen.gd` as a presentation-only sibling to `TitleScreen` under `AppRoot`.

It owns:

- result title;
- shipped crop count/value;
- final money;
- relationship summary;
- one line from Mira, Rowan, and June;
- optional final-save failure message;
- `New Game` and `Return to Title` buttons/signals.

It receives one already-derived result dictionary plus save status. It does not read files or mutate gameplay.

Extend `AppRoot`:

- keep loading/validating the single Continue state exactly as HPA-598 does;
- when Continue state has `finale_triggered == true`, show `ResultScreen` directly instead of instantiating `WorldShell`;
- when a live world emits `finale_completed`, derive the result through `ContentRules.build_harvest_result(final_state)`, remove the world, hide the title, and present the result;
- `New Game` from result hides the result and launches a fresh world without deleting the slot;
- `Return to Title` hides the result, shows title, and reloads title save state so Continue reflects the latest successful write.

If the final save failed, the ending still displays. The result screen says the final result was not saved; returning to title may therefore expose the previous valid autosave. No rollback/retry queue is added.

## Testing strategy

### Pure/unit tests

Add `tests/unit/test_content_rules.gd` for:

- exact tutorial key/default shape;
- prompt relevance and ordering;
- excluded/dismissed prompt behavior;
- rainy-day water suppression;
- mature-crop harvest prompt;
- all three result tiers and exact 150G/300G boundaries;
- Heart requiring both farming threshold and a Close Friend;
- deterministic villager finale lines.

Extend `tests/unit/test_game_session.gd` for:

- new starter state and deep isolation;
- total validation/canonical restore of all HPA-597 fields;
- old state missing new fields rejected;
- successful command completion vs failed-command non-completion;
- intro acknowledgement idempotency;
- lifetime shipped counts across multiple normal sleeps;
- Day 14 market not-ready/off-target failures;
- shared market/sleep finalization;
- final shipment paid/counts recorded exactly once;
- no Day 15/weather roll/crop advance on finale;
- duplicate protection and terminal command blocking.

`tests/unit/test_save_file.gd` stays transport-focused. Add only a canonical GameSession encode/decode/restore case if existing coverage does not already exercise the new nested tutorial dictionary.

### Scene/integration tests

Extend existing tests rather than building new automation infrastructure:

- `test_gameplay_shell.gd`: market geometry/Y-sort contract, updated crop-child offset, opening input lock, non-blocking prompt, prompt dismissal, objective copy, market hint/interaction, Day 14 sleep fallback;
- `test_app_launch.gd`: completed Continue routes directly to result; result New Game and Return to Title behavior;
- `test_persistence_flow.gd`: market and sleep final paths save one terminal state, duplicate attempt does not add a save, and a completed save reopens directly to the result;
- headless world-shell smoke: one additional market collision/entity contract and corresponding entity-count arithmetic.

Do not add browser injection hooks, a movement E2E driver, test-only production mutators, or a second save adapter. Direct tests may continue using the repository's current narrow private-state fixture pattern where reaching Day 14 through thirteen sleeps would obscure the specific boundary under test; every such fixture immediately asserts the seeded state before exercising public commands.

## Documentation and acceptance

Update `README.md` with the player-facing opening/tutorial/finale flow and Day 14 ending controls. Update `CLAUDE.md` with the new `ContentRules`, terminal state, market world contract, result routing, and persistence boundary. Keep `AGENTS.md -> CLAUDE.md` unchanged.

Final committed verification uses the existing Godot 4.7.1 path:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
```

HPA-597 is complete when one command-driven run proves: onboarding completion is authoritative, cumulative shipping survives save/continue, Day 14 market and bed produce the same deterministic terminal calculation, final shipment settles once, a completed save Continue opens the result screen, and no route can enter Day 15 or post-game gameplay.

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
- unrelated world/UI refactors;
- balance changes that belong to HPA-599.
