# Phoenix Content and Harvest Finale Slice Design (HPA-597)

**Status:** Draft for review

**Date:** 2026-08-20

**Delivery target:** one contextual onboarding flow and one deterministic Day 14 ending, delivered in the existing browser/Tauri game

## Source of truth

This design implements HPA-597, `[Content Slice] Add contextual onboarding and the Day 14 harvest finale`, against current `main` after HPA-596 shipped.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves implementation details against the code that exists now:

- `GameSession` is the mutable gameplay authority and exports/restores `GameState`;
- `ProofScene` is the Phaser adapter and exposes typed `SceneCommands`;
- `App.svelte` owns title/game/modal orchestration and persistence timing;
- `Overlay.svelte` owns the current screen-space HUD and contextual gameplay feedback;
- HPA-596 persists the current `GameState` shape through one V1 save envelope with no migration support;
- `loadProofMap.ts` hard-pins the authored 12×12 map, scenery, collision footprints, marker cells, and object IDs;
- `tools/generate-proof-assets.ts` is the source for the committed proof sprites and map JSON;
- the current temporary boundary is `MAX_DAY = 14`, where `sleep()` rejects Day 14 with `day-limit-reached`.

## Outcome

A fresh Phoenix run now has a short opening, one contextual tutorial card at a time, an always-readable 14-day goal, and a real ending. The player can learn the existing farm/economy/social interactions through normal play, reach Day 14, finish at a small authored harvest-market stall or by trying to sleep, receive one of three deterministic result tiers, and return to title or start over.

The slice adds only the state and presentation needed for that experience. It does not add quests, a cutscene scripting engine, a tutorial state machine framework, festival minigames, post-game/free-play, migrations, new persistence backends, or a second rules authority.

## Repository findings that shape the design

### The current starter economy already supports onboarding

A new session starts with 150G and three Turnip seeds. Turnips take three watered nights and sell for 35G. No HPA-597 balance change is required to prove the first crop cycle, so the current `STARTING_MONEY` and `STARTING_SEEDS` stay unchanged. HPA-599 remains the place for playthrough-wide tuning.

### “First two days” cannot literally include harvest, shipping, and gifting

The Linear ticket asks for contextual prompts during the first two days, but the existing fastest crop requires three watered nights. The same ticket also requires each prompt to appear only when its action becomes relevant.

The latter rule is the useful product invariant. HPA-597 therefore starts onboarding immediately on Day 1, covers hoe/plant/water/sleep first, and continues to surface later harvest/shipping/gifting prompts when their prerequisites actually exist. It does not shorten Turnip growth or show instructions for actions the player cannot yet perform.

### The game does not currently retain lifetime shipping totals

`pendingShipment` is cleared each successful night and `pendingDaySummary` only describes the latest settlement. HPA-597 needs cumulative shipped crop count/value for finale evaluation, so lifetime shipped crop counts must become authoritative persisted state. Lifetime value remains derived from those counts and the existing crop sale values rather than being stored twice.

### The Day 14 fallback must not throw away final-day shipments

Current shipping deposits are final but are paid on sleep. If Day 14 simply ended without settlement, crops deposited on the final day would not count. Both harvest-market interaction and Day 14 sleep therefore route through the same finalization method, which settles the current shipping bin once, records lifetime shipped counts, clears the pending bin, and then marks the finale triggered without advancing to Day 15 or growing crops overnight.

This gives both trigger paths the same deterministic economic boundary and prevents double payout.

## Considered approaches

### A. Small content state in `GameSession` plus pure prompt/finale helpers — chosen

Persist one `ContentProgress` object inside `GameState`. Existing successful commands mark tutorial steps complete. A pure helper chooses the highest-priority currently relevant tutorial prompt. A second pure helper derives the final result from `GameState`. Svelte only presents these rules and owns transient dismiss/modal state.

This keeps persistence and gameplay facts authoritative in the same place as the systems they describe and introduces only two small framework-free modules.

### B. Observe command-result text in Svelte and keep onboarding/finale progress in UI state — rejected

This is initially smaller, but it makes tutorial completion and duplicate-finale protection presentation-owned, cannot survive save/continue cleanly, and would make browser/Tauri persistence depend on reconstructing UI events. It also makes the Day 14 sleep fallback harder because the core rules layer still needs to know the run has ended.

### C. Build a generic tutorial/quest/cutscene engine — rejected

HPA-597 has one opening, nine contextual learning beats, and one ending. A general event graph, dialogue scripting DSL, quest registry, scene runner, or data-driven predicate engine would add more infrastructure than content and would violate the project’s slice-first delivery model.

## Approved lean shape

- Extend the current V1 `GameState` directly; keep `SAVE_SCHEMA_VERSION = 1` and intentionally invalidate older development saves that lack the new fields.
- Add one persisted `ContentProgress` object with opening acknowledgment, tutorial completion flags, lifetime shipped crop counts, and finale-triggered state.
- Keep tutorial dismissal transient in `Overlay.svelte`; dismissing a card never marks the underlying action complete.
- Complete tutorial steps only from successful authoritative gameplay commands.
- Combine “target a farm diamond” and “hoe” into one first prompt whose completion proof is the existing `soil-tilled` success.
- Keep the current 150G / three-Turnip start and existing crop/relationship balance.
- Derive cumulative shipped value from lifetime shipped crop counts via the existing `shipmentPayout()` values.
- Add one pure `harvestFinale.ts` evaluator with fixed result labels and thresholds; no scoring engine.
- Add one small authored market stall at logical cell `{ x: 8, y: 6 }` using the existing procedural asset/map pipeline and strict Tiled parser.
- Add one `harvest-market` interaction intent and one `GameSession.triggerHarvestFinale()` command.
- Make Day 14 `sleep()` call the same private finalization path instead of returning `day-limit-reached`.
- Finalization settles pending shipments exactly once, never advances to Day 15, never grows crops, and never creates a morning summary.
- Add one opening modal and one result screen; do not reuse villager dialogue state as a story engine.
- Persist the final state immediately after `finale-triggered`; a save failure does not revoke the completed run and is shown on the result screen.
- A continued save with `finaleTriggered: true` validates through `GameSession`, then goes directly to the result screen; there is no post-game world state.
- Keep the existing dev hook observation-only; seed Day 14 browser E2E state through the public localStorage save boundary rather than adding a mutation hook.

## Persisted content state

Add to `src/game/core/types.ts`:

```ts
export type TutorialStep =
  | 'farm-basics'
  | 'plant'
  | 'water'
  | 'sleep'
  | 'buy-seeds'
  | 'talk'
  | 'harvest'
  | 'shipping'
  | 'gift';

export type TutorialProgress = Record<TutorialStep, boolean>;

export interface ContentProgress {
  introAcknowledged: boolean;
  tutorial: TutorialProgress;
  shippedCrops: CropCounts;
  finaleTriggered: boolean;
}
```

Extend `GameState` with:

```ts
content: ContentProgress;
```

Because `GameSnapshot` already derives mutable fields from `GameState`, `content` flows into snapshots automatically.

New sessions start with every tutorial flag false, zero lifetime shipped crops, `introAcknowledged: false`, and `finaleTriggered: false`.

### Save parsing and restore invariants

`saveFile.ts` structurally parses the new object and exact tutorial keys as booleans. It continues to accept structurally valid integers even if negative, leaving current-rule checks to `GameSession`.

`GameSession` validates:

- every lifetime shipped crop count is a non-negative safe integer;
- `finaleTriggered` may only be true on Day 14;
- a final state has no pending morning summary.

No migration or compatibility fallback is added. Existing HPA-596 development saves without `content` are rejected by the V1 parser, which is acceptable for this pre-release project and explicitly allowed by HPA-597.

## Opening and tutorial model

Create `src/game/core/contentProgress.ts` with static opening copy, tutorial definitions, initial-state construction, and prompt selection.

The opening is deliberately tiny: one caretaker setup line and one Mira line that establishes the Day 14 harvest market. `OpeningPanel.svelte` displays those lines after the world is ready when `introAcknowledged` is false. It owns no progression state.

`GameSession.acknowledgeIntro()` flips the flag and returns `intro-acknowledged`. Duplicate acknowledgment returns `intro-already-acknowledged`.

`App.svelte` uses one new InputGate reason, `opening-panel`, while the opening is visible. The existing Overlay action controls also receive `openingOpen` and stay disabled until the introduction is acknowledged.

### Tutorial prompt definitions

The tutorial UI shows at most one card. `nextTutorialPrompt(state)` returns a small value such as:

```ts
export interface TutorialPrompt {
  id: TutorialStep;
  title: string;
  body: string;
}
```

Prompt selection is state-based, not position-based. App currently receives authoritative snapshots on commands, not every movement frame, and HPA-597 does not add a second movement-to-Svelte observation channel solely for tutorial proximity.

The first prompt teaches targeting and hoeing together:

> Face a farm diamond until the gold outline appears. Press 1 for Hoe, then Space.

Completion requires the existing `soil-tilled` success, so merely highlighting or dismissing the card never advances onboarding.

Subsequent completion mapping is direct:

| Successful result | Tutorial step completed |
| --- | --- |
| `soil-tilled` | `farm-basics` |
| `crop-planted` | `plant` |
| `crop-watered` | `water` |
| `day-advanced` | `sleep` |
| `seeds-purchased` | `buy-seeds` |
| `villager-talked` | `talk` |
| `crop-harvested` | `harvest` |
| `crop-deposited` | `shipping` |
| `crop-gifted` | `gift` |

The helper only offers prompts whose action is currently useful. Examples:

- Water appears only for a Sunny day with an immature unwatered crop; rain does not create an impossible manual-watering requirement.
- Harvest appears only when a mature crop exists.
- Shipping and gift appear only when the player carries a crop.
- Buy Seeds appears only after the first night and when the player can afford at least one seed.
- Talk appears after the first night, once the initial farm loop has been introduced.

This is intentionally a small ordered predicate list, not a generic rules engine.

`Overlay.svelte` stores only the currently dismissed prompt id. Dismissing hides that candidate for the current UI session. When another prompt becomes relevant it can appear normally; reload may show an incomplete dismissed prompt again. Only a real successful command persists completion.

## Lifetime shipping settlement

Add one private `GameSession.settlePendingShipment()` helper. It reuses `shipmentPayout(this.pendingShipment)` and performs the existing money/bin transaction plus the new lifetime count update:

1. calculate the current payout;
2. add each pending crop count to `content.shippedCrops` with safe-integer checks;
3. add the payout to money;
4. clear `pendingShipment`;
5. return the payout lines/total for callers that need presentation data.

Normal Day 1–13 sleep calls this helper and keeps using the returned lines/total in `DaySummary`.

Day 14 finalization calls the same helper before marking the run complete. It does not advance crops or reset daily social state because there is no next morning.

## Harvest result model

Create `src/game/core/harvestFinale.ts`.

```ts
export type HarvestTier = 'newBeginning' | 'promisingFarmer' | 'heartOfHarvest';

export interface HarvestResult {
  tier: HarvestTier;
  title: 'New Beginning' | 'Promising Farmer' | 'Heart of the Harvest';
  shippedCount: number;
  shippedValue: number;
  finalMoney: number;
  relationships: Record<VillagerId, RelationshipLevel>;
  villagerLines: Record<VillagerId, string>;
}

export function buildHarvestResult(state: GameState): HarvestResult;
```

The evaluator contains only two explicit farming thresholds:

```ts
export const PROMISING_SHIPPED_VALUE = 150;
export const HEART_SHIPPED_VALUE = 300;
```

Tier rules are evaluated highest first:

- **Heart of the Harvest** — cumulative shipped value is at least 300G **and** at least one villager is a Close Friend.
- **Promising Farmer** — cumulative shipped value is at least 150G **or** at least one villager is at least Friend.
- **New Beginning** — everything else.

These values are intentionally modest for the MVP. A Close Friend is already reachable in three favourite-gift social days under the existing +1 talk / +5 favourite gift cadence, and 300G of shipping is achievable well inside fourteen days. HPA-599 can tune them after a full playthrough without changing architecture.

Final money is displayed but does not affect tier choice. It is not useful enough to justify a tie-break rule in HPA-597.

### Villager finale lines

Keep character-specific copy with existing character content. Extend each `VillagerDefinition` with:

```ts
readonly finale: Readonly<Record<RelationshipLevel, string>>;
```

Add `finaleLine(id, level)` next to the existing dialogue helpers. `buildHarvestResult()` selects exactly one line for Mira, Rowan, and June from their final relationship level.

No branching story graph is introduced.

## Day 14 domain boundary

Add `marketCell` to `GameSessionConfig` and `GameSnapshot`, following the existing bed/shop/shipping/villager interaction-cell pattern.

Add:

```ts
triggerHarvestFinale(): CommandResult;
```

New success/failure codes:

```ts
// SuccessCode
'finale-triggered'
' intro-acknowledged' // without the leading space in code

// FailureCode
'harvest-market-not-ready'
'not-at-harvest-market'
'finale-already-triggered'
'intro-already-acknowledged'
```

The actual success literal is `intro-acknowledged`; the formatting above only separates it from prose.

`triggerHarvestFinale()` requires:

1. no pending morning summary;
2. current day exactly `MAX_DAY`;
3. current target equals `marketCell`;
4. finale has not already triggered.

It then delegates to one private `completeFinale()`.

Day 14 `sleep()` keeps the existing bed-target check, then calls the same `completeFinale()` instead of returning `day-limit-reached`. `completeFinale()`:

1. rejects duplicates;
2. settles the current pending shipping bin exactly once;
3. sets `content.finaleTriggered = true`;
4. returns `finale-triggered`;
5. leaves `day === 14`;
6. leaves `pendingDaySummary === null`;
7. does not choose next weather, restore stamina, or grow crops.

This removes the old temporary `day-limit-reached` player boundary. The failure code can remain in the union only if another current path still uses it; otherwise HPA-597 removes it and updates exhaustive UI tests/messages.

## Authored harvest market

Use the existing generator/parser path rather than drawing an ad-hoc Phaser rectangle.

Add `market-stall` to `SceneryKind` and make it scenery frame 3 / gid 7. Expand `proof-scenery.png` from 288×96 to 384×96 with four 96×96 frames. The new frame is a simple readable stall/canopy built with the existing procedural drawing helpers.

Author it at logical cell `{ x: 8, y: 6 }`:

- sprite/marker center: grid `{ x: 8.5, y: 6.5 }` → world `{ x: 448, y: 240 }`;
- collision footprint: `{ x: 8.2, y: 6.2, width: 0.6, height: 0.6 }`;
- market interaction cell: `{ x: 8, y: 6 }`.

This cell is on the existing village path, north of the building footprint and distinct from all current villager/bed/shop/shipping/farm cells.

Use the next free Tiled object IDs:

- scenery object 17 — `market-stall`;
- collision object 18 — `market-stall`;
- marker object 19 — `harvest-market`;
- `nextobjectid: 20`.

Update the strict `loadProofMap.ts` contracts rather than adding exceptions:

- proof-scenery columns/tilecount = 4, image width = 384;
- scenery contract includes `market-stall`;
- collision order includes market-stall with the other scenery before villagers;
- marker contract includes `harvest-market` at `{ x: 8, y: 6 }`;
- `ParsedProofMap` exposes `marketCell`.

`ProofScene` renders it through the existing scenery/depth path and passes the parsed cell into `GameSession`.

## Interaction and HUD

Extend `InteractionIntent` with:

```ts
{ kind: 'harvest-market' }
```

`interactionIntentForTarget()` checks `marketCell` along with the existing authored interactions. `App.svelte` handles this intent by calling `commands.triggerHarvestFinale()`; there is no intermediate festival panel.

Before Day 14, the command returns `harvest-market-not-ready` and the normal command feedback explains that the market opens on Day 14.

The HUD always keeps the goal readable:

- Days 1–13: `Harvest Market: Day 14 · N days remaining`.
- Day 14: `Harvest Market today · village square`.

No calendar subsystem is introduced; remaining days derive from `MAX_DAY - snapshot.day`.

## Result persistence and app phases

Extend the app phase to:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing' | 'result';
```

Add `ResultScreen.svelte` with:

- tier title;
- shipped crop count/value;
- final money;
- relationship summary;
- one finale line each from Mira, Rowan, and June;
- `New Game`;
- `Return to Title`.

There is no Continue button on the result itself and no resume/free-play action.

### Immediate final save

Create `src/persistence/persistFinaleSave.ts`, mirroring the small HPA-596 overnight helper rather than generalizing both into a persistence transaction framework.

It writes exactly when the supplied command result is `finale-triggered`, returns the `SaveFileV1` it wrote, and throws when storage is unavailable/fails.

`App.svelte` handles either market or sleep `finale-triggered` identically:

1. read `commands.state()` after final settlement;
2. derive `HarvestResult` with `buildHarvestResult()`;
3. try `persistFinaleSave()`;
4. on success, replace in-memory `loadedSave` with the returned final file;
5. on failure, retain the result and expose the persistence error on `ResultScreen`;
6. move to `result` and unmount the world.

A failed save never rolls the completed in-memory run back into gameplay.

### Continue after completion

A final save still goes through the existing title parser and `GameSession` restore validation. When `handleReady()` receives commands whose restored `state().content.finaleTriggered` is true, `App.svelte` derives the same `HarvestResult` and immediately moves to `result` instead of exposing the world.

This reuses the current restore validation path and avoids a second standalone validator just for the title screen.

`Return to Title` preserves the current loaded-save availability. If the final save succeeded, Continue leads back to the result screen. `New Game` starts a fresh `GameSession` with a new unacknowledged opening; the one slot is overwritten on the next successful save as today.

## UI input behavior

- `OpeningPanel` is a blocking modal and owns InputGate reason `opening-panel`.
- `ResultScreen` replaces/unmounts the game rather than adding another world-input lock.
- Tutorial cards are non-modal and do not lock movement or actions.
- Existing sleep/economy/dialogue locks remain unchanged.
- `InputGate.ts` itself needs no new API.

## Testing strategy

### Core unit coverage

Add `tests/game/contentProgress.test.ts` for:

- initial content state;
- highest-priority relevant prompt selection;
- rain suppressing the Water prompt until manual watering is actually relevant;
- mature crop enabling Harvest;
- crop inventory enabling Shipping/Gift;
- completed steps never being selected again.

Extend `GameSession.test.ts` for:

- opening acknowledgment and duplicate protection;
- each successful gameplay command marking only its corresponding tutorial step;
- failed commands never marking a step;
- normal overnight settlement accumulating lifetime shipped crop counts;
- restored content state deep cloning and validation;
- Day 13 sleep still advances to Day 14 normally;
- market finale rejected before Day 14 and away from the market cell;
- market finale on Day 14 settling pending shipments once and staying on Day 14;
- Day 14 sleep using the same final settlement path;
- equivalent Day 14 market/sleep states producing the same final `GameState` facts used by the evaluator;
- repeated finale attempts never double-pay or retrigger.

Add `tests/game/harvestFinale.test.ts` with exact boundary cases:

- 149G and no Friend → New Beginning;
- Friend with low shipping → Promising Farmer;
- 150G and no Friend → Promising Farmer;
- 299G plus Close Friend → Promising Farmer;
- 300G without Close Friend → Promising Farmer;
- 300G plus Close Friend → Heart of the Harvest;
- villager line selection for Stranger/Friend/Close Friend;
- exact shipped count/value derivation from crop counts.

### Persistence tests

Update `tests/persistence/saveFile.test.ts` so `content` is a required V1 state field and every tutorial/content subfield is structurally parsed.

Add `tests/persistence/persistFinaleSave.test.ts` for no-op non-finale results, one final save, returned file cloning, missing repository, and repository failure propagation.

The existing command-driven save/restore coverage continues to prove the full `GameState` round trip, now including content progress.

### Map and interaction tests

Update `loadProofMap.test.ts` to pin the new four-frame scenery sheet, market object IDs, exact world position, footprint, marker cell, collision order, and `nextobjectid: 20`.

Update `interactionIntent.test.ts` for the new market intent without changing precedence of bed/shop/shipping/villagers.

Asset-generation tests continue to prove committed generated files match the generator.

### Browser E2E

Add `tests/e2e/content.pw.ts`.

Visible onboarding scenario:

1. New Game opens the blocking introduction.
2. Acknowledge it and see the first farm-target/Hoe card.
3. Use existing movement/action helpers to till, plant, water, and sleep.
4. Assert prompts advance only after successful actions and do not block normal world input when merely displayed.
5. Reload/Continue after the overnight save and assert completed flags remain completed.

Day 14 scenarios do not add a mutating dev hook. Start from a normal fresh snapshot, convert its existing read model into a valid `GameState`, write a V1 browser save through `localStorage`, set Day 14/content totals/relationship points in that stored test fixture, reload, and Continue.

Cover both visible trigger routes:

- target the authored market stall and press E → result screen, final pending shipment counted once, Return to Title → Continue returns to result;
- target the bed on Day 14 and confirm sleep → same result calculation, no Day 15 or morning summary.

Keep the test hook observation-only and keep all movement targeting in the existing shared helpers.

## Documentation and handoff

Update `README.md` to:

- add HPA-595/HPA-596/HPA-597 to the opening feature summary;
- document the opening/tutorial behavior;
- replace the temporary Day 14 `day-limit-reached` note with the market/finale behavior;
- document the market cell and expanded four-frame scenery contract;
- document the exact result thresholds;
- preserve all strings pinned by `tests/config/handoff.test.ts`, updating that test only where HPA-597 intentionally changes the contract.

Update `CLAUDE.md` to note:

- `GameSession` now owns persisted content progress and lifetime shipment totals;
- `contentProgress.ts`/`harvestFinale.ts` are framework-free rule/content helpers;
- `App.svelte` owns opening/result orchestration and final-save timing;
- the authored interaction bag includes the harvest market.

## Explicit non-goals

- Generic quest/objective/event system
- Cutscene scripting engine or dialogue DSL
- Festival minigames, competitions, animated crowds, or NPC schedules
- New crop, economy, stamina, weather, or relationship balance beyond finale thresholds
- New map, camera, projection, terrain elevation, or renderer
- Multiple endings beyond the three result tiers
- Romance endings or branching character routes
- Post-game/free-play after Day 14
- New Game+ or carry-over progression
- Save migrations, schema-version bump, backup slot, manual save, cloud save, or recovery flow
- New test-only state mutator
- New state-management library or schema library

## Main risks and containment

### Tutorial relevance can become another gameplay authority

Containment: prompt helpers are read-only selectors over `GameState`; only successful existing `GameSession` commands mutate completion flags. Svelte never decides that a tutorial action succeeded.

### Finale can diverge between market and sleep

Containment: both call the same `completeFinale()` and `settlePendingShipment()` path, and unit tests compare equivalent Day 14 states plus duplicate payout behavior.

### Strict map authoring changes can break unrelated world tests

Containment: update the generator, committed map, strict parser contracts, and exact parser/asset tests together in one task. Do not loosen the parser.

### Final save failure can otherwise reopen gameplay accidentally

Containment: result presentation derives from the already-finalized in-memory state and stays terminal even if storage fails. The error is visible, but there is no rollback into Day 14 play.
