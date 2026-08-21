# Phoenix Content and Harvest Finale Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use TDD for core state, finale rules, save parsing/orchestration, and map contracts; keep each task type-green before moving on; deliver HPA-597 in this single PR.

**Goal:** Deliver HPA-597 with a short opening, contextual action-completion onboarding, a visible Day 14 harvest-market objective, cumulative shipping results, one authored market stall, three deterministic finale tiers, persisted completion, and a terminal Svelte result screen.

**Architecture:** `GameSession` remains the only mutable gameplay authority and gains one persisted `ContentProgress` object plus a shared shipment-settlement/finale path. `contentProgress.ts` and `harvestFinale.ts` are small framework-free read/rule helpers. The existing strict Tiled generator/parser gains one authored market interaction. Phaser forwards that interaction and command; Svelte owns opening/tutorial/result presentation and final-save timing; persistence extends the current V1 state directly with no migration layer.

**Tech Stack:** Bun 1.3.1 and `bun:test`, TypeScript, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.x, existing Tauri Store persistence, existing procedural PNG/Tiled asset generator.

**Spec:** `docs/superpowers/specs/2026-08-20-phoenix-content-finale-slice-design.md`

## Global Constraints

- Implement only HPA-597. Do not start HPA-599 polish/balance/release work.
- Keep HPA-597 in this one PR; continue implementation on this planning PR after review.
- Keep `GameSession` as the only mutable gameplay authority.
- Extend the current `GameState`/V1 save shape directly. Keep `SAVE_SCHEMA_VERSION = 1`; no migration or compatibility fallback for development saves.
- Do not add a quest system, objective framework, dialogue scripting engine, cutscene runner, event graph, state-management library, or schema library.
- Keep the current 150G / three-Turnip starting balance, crop growth/prices, stamina costs, weather, and relationship thresholds/points.
- Interpret “first two days” as “onboarding starts immediately”; Harvest/Shipping/Gift prompts appear when their existing prerequisites become possible rather than changing crop growth to force them into Day 2.
- Tutorial completion must come only from successful authoritative commands. Dismissal is presentation-only and never completes a step.
- Combine targeting + Hoe into one first prompt; `soil-tilled` is the completion proof. Do not add target/movement progress to persisted state.
- Persist lifetime shipped crop counts, not a redundant shipped-value total. Derive value through existing crop sale values.
- Settle pending shipping on Day 14 finale so final-day deposits count exactly once.
- Market interaction and Day 14 sleep must call the same finalization/settlement path and stay on Day 14.
- There is no Day 15, morning summary after finale, post-game movement, or free-play route.
- Final money is presentation-only for the result; it does not affect tier selection.
- Use exactly these initial tier boundaries unless implementation evidence proves them impossible: Promising at 150G shipped value or any Friend; Heart at 300G shipped value plus any Close Friend.
- Add the market through `tools/generate-proof-assets.ts` + committed Tiled JSON + strict `loadProofMap.ts` contract. Do not draw it ad hoc in Phaser or loosen parser validation.
- Use market cell `{ x: 8, y: 6 }`, world center `{ x: 448, y: 240 }`, 0.6×0.6 footprint, object IDs 17/18/19, and `nextobjectid: 20`.
- Keep `window.__PHOENIX_TEST__` observation-only. Browser Day 14 fixtures may seed the existing public localStorage save slot; do not add a test mutation API.
- Reuse existing E2E movement/targeting helpers and fixed timing policy. Do not add fixed sleeps, retries, or per-spec timeout inflation.
- Keep new modal/input behavior reason-keyed through the existing `InputGate`; do not modify `InputGate` API.
- Update README/CLAUDE/handoff contracts in the same PR when implementation changes the documented Day 14/map behavior.

## File Map

### Content state and tutorial rules

- Modify: `src/game/core/types.ts`
- Create: `src/game/core/contentProgress.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `src/persistence/saveFile.ts`
- Create: `tests/game/contentProgress.test.ts`
- Modify: `tests/game/GameSession.test.ts`
- Modify: `tests/persistence/saveFile.test.ts`

### Finale rules and character content

- Create: `src/game/core/harvestFinale.ts`
- Modify: `src/game/core/villagerDefinitions.ts`
- Modify: `src/game/core/GameSession.ts`
- Create: `tests/game/harvestFinale.test.ts`
- Modify: `tests/game/villagerDefinitions.test.ts`
- Modify: `tests/game/GameSession.test.ts`

### Authored market and Phaser interaction

- Modify: `src/game/core/types.ts`
- Modify: `tools/generate-proof-assets.ts`
- Regenerate: `src/assets/sprites/proof-scenery.png`
- Regenerate: `src/assets/maps/proof-map.json`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `src/game/phaser/interactionIntent.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `tests/game/loadProofMap.test.ts`
- Modify: `tests/game/interactionIntent.test.ts`
- Modify: affected asset/config tests only where the exact authored contract changes

### Opening and contextual tutorial UI

- Create: `src/components/OpeningPanel.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/App.svelte`
- Modify: `src/app.css`
- Modify: `tests/e2e/helpers.ts`

### Final persistence and result UI

- Create: `src/persistence/persistFinaleSave.ts`
- Create: `tests/persistence/persistFinaleSave.test.ts`
- Create: `src/components/ResultScreen.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

### Acceptance and handoff

- Create: `tests/e2e/content.pw.ts`
- Modify: existing E2E specs only where the new opening/finale intentionally changes shared startup/Day 14 behavior
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `tests/config/handoff.test.ts`

No planned changes: `src/game/core/ProofWorld.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`, crop prices/growth, relationship thresholds/point values, persistence backend selection, Tauri Store wiring, `src-tauri/**`, `vite.config.ts`, CI structure, or `playwright.config.ts`.

## Risks

### Existing E2E startup assumes world input is immediately usable

Most browser specs call `waitForWorld()` and then move. The new opening intentionally locks input. Task 4 updates the shared helper once with an `acknowledgeOpening` option and runs the full E2E suite immediately, instead of patching individual specs.

### Strict map contracts fan out across generator, parser, depth rendering, tests, and docs

The market is not “just one sprite.” Task 3 changes the source generator, committed outputs, strict parser constants, Phaser depth map, interaction cell, and exact tests together. It must not relax map validation to make the new object fit.

### Final-day payout can double-count if market/sleep paths diverge

Task 2 extracts exactly one private settlement method and exactly one private finalization method. Unit tests call both public trigger routes from equivalent states and then call them again to prove no second payout or trigger.

---

## Task 1: Add persisted content progress and successful-command tutorial completion

**Files:**
- Modify: `src/game/core/types.ts`
- Create: `src/game/core/contentProgress.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `src/persistence/saveFile.ts`
- Create: `tests/game/contentProgress.test.ts`
- Modify: `tests/game/GameSession.test.ts`
- Modify: `tests/persistence/saveFile.test.ts`

**Interfaces:**
- Produces: `TutorialStep`, `TutorialProgress`, `ContentProgress`, `TutorialPrompt`
- Produces: `createInitialContentProgress()`, `nextTutorialPrompt(state)`
- Produces: `GameSession.acknowledgeIntro()`
- Extends: `GameState.content`
- Preserves: current V1 envelope number, current command semantics, current starter balance

- [ ] **Step 1: Write RED helper tests for the new content state and contextual prompt selector**

Create `tests/game/contentProgress.test.ts` around plain `GameState` fixtures. Pin the initial shape:

```ts
expect(createInitialContentProgress()).toEqual({
  introAcknowledged: false,
  tutorial: {
    'farm-basics': false,
    plant: false,
    water: false,
    sleep: false,
    'buy-seeds': false,
    talk: false,
    harvest: false,
    shipping: false,
    gift: false,
  },
  shippedCrops: { turnip: 0, potato: 0, pumpkin: 0 },
  finaleTriggered: false,
});
```

Cover prompt selection with focused state fixtures rather than one giant scenario:

```ts
expect(nextTutorialPrompt(freshState)?.id).toBe('farm-basics');

const tilled = stateWithTilledEmptyCell();
tilled.content.tutorial['farm-basics'] = true;
expect(nextTutorialPrompt(tilled)?.id).toBe('plant');

const sunnyCrop = stateWithUnwateredCrop({ weather: 'sunny' });
sunnyCrop.content.tutorial['farm-basics'] = true;
sunnyCrop.content.tutorial.plant = true;
expect(nextTutorialPrompt(sunnyCrop)?.id).toBe('water');

const rainyCrop = stateWithUnwateredCrop({ weather: 'rainy' });
rainyCrop.content.tutorial['farm-basics'] = true;
rainyCrop.content.tutorial.plant = true;
expect(nextTutorialPrompt(rainyCrop)?.id).not.toBe('water');
```

Also prove:

- completed ids are never returned again;
- Sleep becomes eligible after the first farm loop is introduced;
- Buy Seeds and Talk become eligible after the first completed night;
- Harvest requires a mature crop;
- Shipping/Gift require carried crops;
- all tutorial flags complete → `null`.

Run and observe RED:

```bash
bun test tests/game/contentProgress.test.ts
```

- [ ] **Step 2: Add the content types and one small read-only helper module**

In `types.ts` add:

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

Add `content: ContentProgress` to `GameState`. Do not add duplicate content fields to `GameSnapshot`; its existing `GameState` composition carries the state through.

Create `contentProgress.ts` with:

- `TUTORIAL_STEPS` exact tuple for parsing/testing;
- `OPENING_COPY` as the two short caretaker/Mira lines;
- `createInitialContentProgress()` returning a fresh deep object each call;
- an ordered list of small prompt definitions/predicates;
- `nextTutorialPrompt(state)` returning a new plain object or null.

Keep predicates explicit and readable. Do not create a generic expression DSL.

Run:

```bash
bun test tests/game/contentProgress.test.ts
```

Expected GREEN before continuing.

- [ ] **Step 3: Write RED `GameSession` tests for persisted content ownership and completion-on-success**

Extend the existing `GameSession.test.ts` helper config only as needed for the new required state field.

Add tests for:

1. fresh state contains a deep-cloned initial `content` object;
2. mutating a returned `state().content` does not mutate the session;
3. `acknowledgeIntro()` returns `{ ok: true, code: 'intro-acknowledged' }` once and a duplicate failure thereafter;
4. successful farm/economy/social commands mark only their mapped tutorial step;
5. failed commands do not mark any step;
6. repeated successful Talk with zero extra relationship points still counts as a successful Talk action if the tutorial is incomplete.

Use a table only where setup can stay clear. The important assertion is state mutation after a real existing command, e.g.:

```ts
expect(session.state().content.tutorial['farm-basics']).toBe(false);
expect(session.hoe(FARM_CELL)).toEqual({ ok: true, code: 'soil-tilled' });
expect(session.state().content.tutorial['farm-basics']).toBe(true);
```

For a failure:

```ts
const before = session.state().content.tutorial;
expect(session.harvest(FARM_CELL)).toEqual({ ok: false, code: 'no-crop' });
expect(session.state().content.tutorial).toEqual(before);
```

Run and observe RED:

```bash
bun test tests/game/GameSession.test.ts
```

- [ ] **Step 4: Make `GameSession` own and clone content progress**

In `GameSession.ts`:

- initialize `private content = createInitialContentProgress()`;
- include `content: cloneContentProgress(this.content)` in `state()`;
- restore it from `initialState.content` after current-rule validation;
- add a small `completeTutorial(step)` helper that only flips the boolean;
- add `acknowledgeIntro()` and the two new command-result literals;
- call `completeTutorial()` only after each existing operation has passed all validation and committed its real mutation.

Completion call sites in this task:

```text
hoe success              -> farm-basics
plant success            -> plant
water success            -> water
harvest success          -> harvest
buySeeds success         -> buy-seeds
depositCrop success      -> shipping
talkTo success           -> talk
giftCrop success         -> gift
```

Sleep completion is added in Task 2 alongside the settlement refactor so the final-day branch remains explicit.

Do not infer tutorial success from `CommandResult` text in Svelte.

Run:

```bash
bun test tests/game/GameSession.test.ts tests/game/contentProgress.test.ts
```

- [ ] **Step 5: Write RED save-parser tests for the intentionally changed V1 shape**

In `tests/persistence/saveFile.test.ts`:

- add `content` to the required current-state field table;
- assert a normal `createSaveFile()` round trip contains the new initial content;
- add structural rejection cases for missing/invalid `introAcknowledged`, `tutorial`, each tutorial key, `shippedCrops`, and `finaleTriggered`;
- add an unknown tutorial id case;
- preserve the existing test that structurally valid but current-rule-impossible numeric values pass `parseSaveFile()`.

Run and observe RED:

```bash
bun test tests/persistence/saveFile.test.ts
```

- [ ] **Step 6: Parse the exact content shape without a schema-version bump**

In `saveFile.ts`:

- import `TUTORIAL_STEPS` and the new content types;
- keep `SAVE_SCHEMA_VERSION = 1`;
- add `parseContentProgress()`;
- use the existing `record`, `boolean`, `safeInteger`, `oneOf` primitives;
- parse `shippedCrops` through the existing crop-count parser;
- require every exact tutorial id and reject unknown ids by iterating object keys through `oneOf` before checking missing ids.

No migration/default injection is allowed. An HPA-596 save missing `content` must reject.

Run:

```bash
bun test tests/persistence/saveFile.test.ts tests/game/GameSession.test.ts tests/game/contentProgress.test.ts
bun run check
```

- [ ] **Step 7: Add current-rule restore validation for content**

In `validateInitialStateInvariants()`:

- assert each `content.shippedCrops[kind]` is a non-negative safe integer;
- reject `finaleTriggered` unless `state.day === MAX_DAY`;
- reject a `finaleTriggered` state with non-null `pendingDaySummary`.

Do not add speculative invariants tying intro/tutorial order together; core commands remain callable independently in unit tests and the opening lock is presentation orchestration.

Add targeted invalid restore tests and run:

```bash
bun test tests/game/GameSession.test.ts tests/persistence/saveFile.test.ts
bun run check
```

- [ ] **Step 8: Commit Task 1**

```bash
git add src/game/core/types.ts src/game/core/contentProgress.ts src/game/core/GameSession.ts \
  src/persistence/saveFile.ts tests/game/contentProgress.test.ts tests/game/GameSession.test.ts \
  tests/persistence/saveFile.test.ts
git commit -m "feat(game): add persisted onboarding progress"
```

---

## Task 2: Reuse shipping settlement and make Day 14 a deterministic terminal rule

**Files:**
- Create: `src/game/core/harvestFinale.ts`
- Modify: `src/game/core/villagerDefinitions.ts`
- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Create: `tests/game/harvestFinale.test.ts`
- Modify: `tests/game/villagerDefinitions.test.ts`
- Modify: `tests/game/GameSession.test.ts`

**Interfaces:**
- Produces: `HarvestTier`, `HarvestResult`, `buildHarvestResult(state)`
- Produces: `finaleLine(id, level)`
- Produces: `GameSession.triggerHarvestFinale()`
- Adds: `GameSessionConfig.marketCell`, `GameSnapshot.marketCell`
- Replaces: Day 14 `day-limit-reached` with `finale-triggered`

- [ ] **Step 1: Write RED pure finale boundary tests first**

Create `tests/game/harvestFinale.test.ts` using plain `GameState` fixtures. Pin the exact tier boundaries:

```text
149G shipped + all Stranger             -> New Beginning
0G shipped + any Friend                 -> Promising Farmer
150G shipped + all Stranger             -> Promising Farmer
299G shipped + any Close Friend         -> Promising Farmer
300G shipped + no Close Friend          -> Promising Farmer
300G shipped + any Close Friend         -> Heart of the Harvest
```

Because crop denominations cannot always produce every integer with real counts, build the threshold fixtures from valid crop-count combinations where possible and use a small exported evaluator input helper only if needed. Prefer testing `buildHarvestResult(GameState)` with realizable totals:

- 140G = one Pumpkin;
- 150G = two Potatoes;
- 280G = two Pumpkins;
- 300G = four Potatoes;
- 315G = nine Turnips.

Also pin:

- shipped count is the sum of lifetime crop counts;
- shipped value comes from existing `shipmentPayout()` values;
- final money is copied for display only;
- relationship levels are derived with `relationshipLevel()`;
- exactly one villager line is selected for each villager.

Run and observe RED:

```bash
bun test tests/game/harvestFinale.test.ts
```

- [ ] **Step 2: Add the pure evaluator and character finale copy**

In `villagerDefinitions.ts`, extend `VillagerDefinition` with:

```ts
readonly finale: Readonly<Record<RelationshipLevel, string>>;
```

Author one short Stranger/Friend/Close Friend final line for Mira, Rowan, and June, and expose:

```ts
export function finaleLine(id: VillagerId, level: RelationshipLevel): string;
```

Keep final lines adjacent to the existing character dialogue/favourite-gift content.

Create `harvestFinale.ts` with constants:

```ts
export const PROMISING_SHIPPED_VALUE = 150;
export const HEART_SHIPPED_VALUE = 300;
```

and a simple highest-first evaluator. Do not add weights, points, percentages, tie-breakers, or a predicate registry.

Run:

```bash
bun test tests/game/harvestFinale.test.ts tests/game/villagerDefinitions.test.ts
```

- [ ] **Step 3: Write RED `GameSession` tests for lifetime shipping and both Day 14 trigger routes**

Extend the test config with a distinct `marketCell`, e.g. `{ x: 5, y: 8 }`, and update any constructor collision/distinctness fixture required by the new config contract.

Add tests for normal settlement:

```ts
// deposit one turnip, sleep, then verify
expect(session.state().content.shippedCrops.turnip).toBe(1);
expect(session.state().pendingShipment.turnip).toBe(0);
expect(session.state().money).toBe(startMoney + 35);
expect(session.state().content.tutorial.sleep).toBe(true);
```

Add a second night shipment and prove lifetime counts accumulate instead of being replaced.

Create equivalent valid Day 14 states with:

- no pending morning summary;
- a non-zero pending shipment;
- known lifetime shipment counts;
- known relationship points;
- player targetable market/bed cells.

Pin these domain boundaries:

1. Day 13 market trigger → `harvest-market-not-ready` and unchanged state.
2. Day 14 trigger away from the market → `not-at-harvest-market`.
3. Day 13 sleep still returns `day-advanced` and produces Day 14 morning summary.
4. Day 14 market trigger returns `finale-triggered`, settles the pending bin, leaves day at 14, and creates no summary.
5. Day 14 sleep at the bed returns `finale-triggered` with the same settlement semantics.
6. A second trigger returns `finale-already-triggered` with no second money/count change.
7. Market and sleep from equivalent Day 14 initial states produce equal `content.shippedCrops`, money, day, pending shipment, and finale flag.

Run and observe RED:

```bash
bun test tests/game/GameSession.test.ts
```

- [ ] **Step 4: Extract one private settlement helper and reuse it from normal sleep**

Refactor only the current shipping portion of `sleep()`:

```ts
private settlePendingShipment(): { lines: ShipmentLine[]; total: number } {
  const payout = shipmentPayout(this.pendingShipment);
  for (const kind of CROP_KINDS) {
    const next = this.content.shippedCrops[kind] + this.pendingShipment[kind];
    if (!Number.isSafeInteger(next)) {
      throw new RangeError('lifetime shipped crop count exceeds safe integer range');
    }
    this.content.shippedCrops[kind] = next;
  }
  this.money += payout.total;
  this.pendingShipment = { turnip: 0, potato: 0, pumpkin: 0 };
  return payout;
}
```

Use the existing style/helpers if a safe-integer money check is already local; do not create a generic accounting service.

Normal Day 1–13 sleep calls it before constructing `DaySummary` and marks `tutorial.sleep` only after the real day transition has succeeded.

Run the existing economy/day tests immediately:

```bash
bun test tests/game/GameSession.test.ts tests/game/cropDefinitions.test.ts tests/game/dailyRhythm.test.ts
```

- [ ] **Step 5: Add the terminal Day 14 command and shared private finalizer**

Add result literals:

```ts
// SuccessCode
'intro-acknowledged'
'finale-triggered'

// FailureCode
'intro-already-acknowledged'
'harvest-market-not-ready'
'not-at-harvest-market'
'finale-already-triggered'
```

Add `marketCell` to config/snapshot and constructor distinctness/in-bounds checks alongside bed/shop/shipping cells.

Implement:

```ts
triggerHarvestFinale(): CommandResult
```

Validation order:

1. pending day summary → existing `day-summary-pending`;
2. already finalized → `finale-already-triggered`;
3. day is not 14 → `harvest-market-not-ready`;
4. current target is not market cell → `not-at-harvest-market`;
5. call `completeFinale()`.

`completeFinale()` settles shipping, sets the flag, returns `finale-triggered`, and does nothing else.

Change `sleep()` after bed-target validation:

```ts
if (this.day === MAX_DAY) return this.completeFinale();
```

Do not choose weather, grow crops, reset stamina, reset social daily flags, or create a summary in this branch.

After this change, search for runtime producers/consumers of `day-limit-reached`. If none remain, remove it from `FailureCode`, `Overlay` feedback, and obsolete tests instead of retaining dead API.

Run:

```bash
bun test tests/game/GameSession.test.ts tests/game/harvestFinale.test.ts
bun run check
```

- [ ] **Step 6: Commit Task 2**

```bash
git add src/game/core/harvestFinale.ts src/game/core/villagerDefinitions.ts \
  src/game/core/types.ts src/game/core/GameSession.ts tests/game/harvestFinale.test.ts \
  tests/game/villagerDefinitions.test.ts tests/game/GameSession.test.ts
git commit -m "feat(game): add deterministic harvest finale"
```

---

## Task 3: Author the harvest-market stall through the existing map pipeline

**Files:**
- Modify: `src/game/core/types.ts`
- Modify: `tools/generate-proof-assets.ts`
- Regenerate: `src/assets/sprites/proof-scenery.png`
- Regenerate: `src/assets/maps/proof-map.json`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `src/game/phaser/interactionIntent.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `tests/game/loadProofMap.test.ts`
- Modify: `tests/game/interactionIntent.test.ts`
- Modify: exact asset/config tests if required by generated-file hashes/dimensions

**Authored constants:**
- `market-stall` frame: 3
- gid: 7
- sheet: 384×96, 4 columns, 4 tiles
- logical interaction cell: `{ x: 8, y: 6 }`
- center: `{ x: 8.5, y: 6.5 }` → `{ x: 448, y: 240 }`
- footprint: `{ x: 8.2, y: 6.2, width: 0.6, height: 0.6 }`
- scenery object: 17
- collision object: 18
- marker object: 19
- `nextobjectid`: 20

- [ ] **Step 1: Write RED parser/interaction tests for the exact new authored contract**

In `loadProofMap.test.ts`, extend the canonical success assertions to require:

```ts
expect(parsed.marketCell).toEqual({ x: 8, y: 6 });
expect(parsed.scenery).toContainEqual(
  expect.objectContaining({ kind: 'market-stall', frame: 3, world: { x: 448, y: 240 } }),
);
```

Add exact rejection mutations for:

- `nextobjectid !== 20`;
- proof-scenery width/columns/tilecount not 384/4/4;
- market scenery id/gid/world position changed;
- market collision id/footprint changed;
- `harvest-market` marker id/cell changed;
- market object omitted;
- collision order changed if the parser pins order.

In `interactionIntent.test.ts`, extend `InteractionCells` with `marketCell` and assert:

```ts
expect(interactionIntentForTarget({ x: 8, y: 6 }, cells)).toEqual({
  kind: 'harvest-market',
});
```

Run and observe RED:

```bash
bun test tests/game/loadProofMap.test.ts tests/game/interactionIntent.test.ts
```

- [ ] **Step 2: Extend the procedural scenery sheet and Tiled source generator**

Add `'market-stall'` to `SceneryKind`.

In `generate-proof-assets.ts`:

- expand the scenery surface to `384, 96`;
- draw a simple fourth 96×96 market frame at x-offset 288 using existing `fillRect`/`fillDiamond` helpers;
- set scenery tileset columns/tilecount/imagewidth to `4/4/384`;
- create market world position with `project({ x: 8.5, y: 6.5 })`;
- create `logicalPolygon(18, 'market-stall', 8.2, 6.2, 8.8, 6.8)`;
- append scenery object 17 with gid 7;
- add marker object 19 named `harvest-market` at the market world position;
- set `nextobjectid: 20`.

Do not hand-edit the generated PNG after generation.

Run:

```bash
bun run assets:generate
```

Inspect the generated JSON diff and confirm only the intended tileset dimensions/object additions changed.

- [ ] **Step 3: Update the strict parser rather than making it permissive**

In `loadProofMap.ts`:

- extend `ParsedProofMap` with `marketCell`;
- extend the scenery contract with object 17/gid 7/frame 3/world 448,240;
- extend the scenery collision contract/order with object 18 and exact 0.6 footprint;
- extend marker contract with object 19 / cell 8,6 / world 448,240;
- update exact tileset columns/tilecount/image width and `nextobjectid`;
- return `marketCell` from the parsed marker data.

Do not change the parser’s failure philosophy or remove existing exact checks.

Run:

```bash
bun test tests/game/loadProofMap.test.ts
```

- [ ] **Step 4: Wire market rendering/depth and typed interaction intent into Phaser**

In `interactionIntent.ts`:

```ts
export type InteractionIntent =
  | ...
  | { kind: 'harvest-market' };
```

Add `marketCell` to `InteractionCells` and check it as a distinct authored target.

In `ProofScene.ts`:

- add `'market-stall'` to the depth entity id union/result initialization;
- include its sprite in `updateDepths()` with the other scenery;
- pass `parsed.marketCell` to `GameSession`;
- add `triggerHarvestFinale()` to `SceneCommands`;
- delegate it through `publishCommand()` like other commands.

The existing generic scenery loop already creates the actual sprite; do not add a dedicated `marketSprite` rendering branch unless the type system proves it necessary.

Run:

```bash
bun test tests/game/loadProofMap.test.ts tests/game/interactionIntent.test.ts tests/game/GameSession.test.ts
bun run check
bun run build
```

- [ ] **Step 5: Verify generated assets are committed-source-consistent and commit Task 3**

Run the repository’s relevant asset/config tests, then:

```bash
git status --short
git diff -- src/assets/maps/proof-map.json tools/generate-proof-assets.ts src/game/phaser/loadProofMap.ts
```

Confirm the PNG is regenerated by the tool and there are no unrelated asset changes.

Commit:

```bash
git add src/game/core/types.ts tools/generate-proof-assets.ts src/assets/sprites/proof-scenery.png \
  src/assets/maps/proof-map.json src/game/phaser/loadProofMap.ts src/game/phaser/interactionIntent.ts \
  src/game/phaser/ProofScene.ts tests/game/loadProofMap.test.ts tests/game/interactionIntent.test.ts
git commit -m "feat(world): author the harvest market"
```

---

## Task 4: Present the opening and contextual tutorial without creating another rules layer

**Files:**
- Create: `src/components/OpeningPanel.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/App.svelte`
- Modify: `src/app.css`
- Modify: `tests/e2e/helpers.ts`
- Modify: existing E2E specs only if their startup assertion explicitly conflicts with the intended opening

**Interfaces:**
- Consumes: `OPENING_COPY`, `nextTutorialPrompt(snapshot)`
- Consumes: `SceneCommands.acknowledgeIntro()`
- Adds InputGate reason: `opening-panel`
- Adds visible data hooks for opening/tutorial only

- [ ] **Step 1: Add the shared E2E startup seam before changing the UI**

Change `waitForWorld()` in `tests/e2e/helpers.ts` to accept an option while preserving every current caller:

```ts
export async function waitForWorld(
  page: Page,
  options: { acknowledgeOpening?: boolean } = {},
): Promise<void> {
  const acknowledgeOpening = options.acknowledgeOpening ?? true;
  // existing title -> New Game -> world ready flow
  if (acknowledgeOpening) {
    const opening = page.locator('[data-opening-panel]');
    if (await opening.isVisible()) {
      await page.locator('[data-opening-continue]').click();
      await expect(opening).toBeHidden();
    }
  }
}
```

Do not add waits that assume the new component already exists. This helper change may remain green until the UI lands.

- [ ] **Step 2: Create the small blocking opening panel**

`OpeningPanel.svelte` should be a focused component with props:

```ts
interface Props {
  lines: readonly string[];
  onContinue: () => void;
}
```

Render:

- one accessible dialog/title;
- the two static lines;
- one `Start farming` button;
- `data-opening-panel` and `data-opening-continue` hooks.

No dialogue paging, speaker model, skip history, typewriter effect, or generic story API.

- [ ] **Step 3: Wire opening visibility directly from authoritative content state**

In `App.svelte`, derive opening visibility from:

```ts
status === 'ready' &&
gameSnapshot !== null &&
!gameSnapshot.content.introAcknowledged
```

Use a Svelte effect or existing sync helper to set:

```ts
inputGate.set('opening-panel', openingOpen);
```

`OpeningPanel` calls a small handler that invokes `commands?.acknowledgeIntro()`. Because the scene command publishes a fresh snapshot, the authoritative flag hides the panel; no second local “intro seen” boolean is needed.

Reset/cleanup must clear the `opening-panel` InputGate reason.

Pass `openingOpen` to `Overlay` so action buttons and the manual overlay lock stay disabled while the modal is active.

- [ ] **Step 4: Add one non-modal contextual tutorial card to `Overlay`**

Import `nextTutorialPrompt` and derive the current candidate from `snapshot`.

Keep only local transient dismissal:

```ts
let dismissedTutorialId = $state<TutorialStep | null>(null);
const tutorialPrompt = $derived(nextTutorialPrompt(snapshot));
```

When the candidate id changes, clear the old dismissal. Render the card only when:

- world status is ready;
- intro is acknowledged/opening is closed;
- a prompt exists;
- its id is not the currently dismissed id;
- no blocking sleep/economy/dialogue transition is covering it.

The Dismiss button only sets `dismissedTutorialId`. It must not call a GameSession completion command.

Add stable `data-tutorial-prompt` / `data-tutorial-id` / `data-tutorial-dismiss` hooks.

Also add the persistent objective line in the HUD:

```text
Days 1–13: Harvest Market: Day 14 · N days remaining
Day 14:    Harvest Market today · village square
```

Import `MAX_DAY`; derive remaining days rather than storing them.

- [ ] **Step 5: Update exhaustive command feedback for the new content/finale result codes**

`Overlay.commandResultMessage()` must cover all current SuccessCode/FailureCode values after Task 2, including:

- intro acknowledged/already acknowledged;
- harvest market not ready;
- not at harvest market;
- finale already triggered;
- finale triggered.

If `day-limit-reached` was removed in Task 2, remove its dead message here.

- [ ] **Step 6: Run the complete browser suite immediately after the shared opening change**

First run focused static/unit checks:

```bash
bun run check
bun test tests/game/contentProgress.test.ts tests/game/GameSession.test.ts
```

Then run all browser tests, not only the new future content spec:

```bash
bun run test:e2e
```

Existing specs should remain unchanged where `waitForWorld()` can acknowledge the opening centrally. Fix the shared helper if startup breaks; do not add per-spec opening clicks.

- [ ] **Step 7: Commit Task 4**

```bash
git add src/components/OpeningPanel.svelte src/components/Overlay.svelte src/App.svelte \
  src/app.css tests/e2e/helpers.ts
git commit -m "feat(ui): add contextual onboarding"
```

---

## Task 5: Persist terminal completion and replace the world with the result screen

**Files:**
- Create: `src/persistence/persistFinaleSave.ts`
- Create: `tests/persistence/persistFinaleSave.test.ts`
- Create: `src/components/ResultScreen.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

**Interfaces:**
- Produces: `persistFinaleSave({ result, state, repository }): Promise<SaveFileV1 | null>`
- Adds app phase: `result`
- Consumes: `buildHarvestResult(state)`

- [ ] **Step 1: Write RED persistence orchestration tests**

Create `tests/persistence/persistFinaleSave.test.ts` using the same tiny fake-repository style as `persistOvernightSave.test.ts`.

Pin:

1. non-success/non-finale result → no save and `null`;
2. successful `finale-triggered` → exactly one repository save;
3. saved file has schemaVersion 1 and the final state;
4. returned file equals what was saved but does not alias the supplied mutable state;
5. missing repository on a real finale throws `Save storage is unavailable`;
6. repository failure rejects unchanged.

Run and observe RED:

```bash
bun test tests/persistence/persistFinaleSave.test.ts
```

- [ ] **Step 2: Implement the narrow final-save helper without generalizing overnight persistence**

Mirror the current helper shape:

```ts
export async function persistFinaleSave(input: {
  result: CommandResult;
  state: GameState;
  repository: SaveRepository | null;
}): Promise<SaveFileV1 | null> {
  if (!input.result.ok || input.result.code !== 'finale-triggered') return null;
  if (!input.repository) throw new Error('Save storage is unavailable');
  const file = createSaveFile(input.state);
  await input.repository.save(file);
  return file;
}
```

Do not refactor `persistOvernightSave` into a generic “save after result” framework in this ticket.

Run:

```bash
bun test tests/persistence/persistFinaleSave.test.ts tests/persistence/persistOvernightSave.test.ts
```

- [ ] **Step 3: Create `ResultScreen.svelte` as a terminal application screen**

Props:

```ts
interface Props {
  result: HarvestResult;
  saveStatus: 'idle' | 'saving' | 'saved' | 'error';
  saveError: string | null;
  onNewGame: () => void;
  onReturnToTitle: () => void;
}
```

Render:

- `result.title` as the primary heading;
- shipped count/value;
- final money;
- relationship names/levels;
- Mira/Rowan/June final lines;
- save status/error if relevant;
- New Game and Return to Title buttons.

Add stable result/data hooks for E2E. Do not mount GameHost/Overlay behind this screen.

- [ ] **Step 4: Add one `finishRun()` path in `App.svelte` and use it from both market and sleep**

Extend:

```ts
type AppPhase = 'loading-save' | 'title' | 'playing' | 'result';
```

Add `harvestResult` state. Implement one async helper that receives the already-successful `finale-triggered` result and current commands:

```ts
async function finishRun(result: CommandResult, currentCommands: SceneCommands): Promise<void> {
  if (!result.ok || result.code !== 'finale-triggered') return;
  const finalState = currentCommands.state();
  harvestResult = buildHarvestResult(finalState);
  saveStatus = 'saving';
  saveError = null;
  appPhase = 'result'; // unmount the world before awaiting storage

  try {
    const file = await persistFinaleSave({ result, state: finalState, repository: saveRepository });
    if (file) loadedSave = file;
    saveStatus = 'saved';
  } catch (error) {
    saveStatus = 'error';
    saveError = error instanceof Error ? error.message : String(error);
  }
}
```

The key order is intentional: build the result and switch to the terminal screen before awaiting I/O, so there is no world interaction window during the final save and no new InputGate reason is required.

Update market intent handling:

```ts
case 'harvest-market': {
  const result = currentCommands.triggerHarvestFinale();
  if (result.ok && result.code === 'finale-triggered') void finishRun(result, currentCommands);
  break;
}
```

Update `confirmSleep()`:

- keep current `day-advanced` → overnight-save flow for Days 1–13;
- if `sleep()` returns `finale-triggered`, close the sleep prompt and call the same `finishRun()`;
- do not wait for/create a morning summary on that branch.

- [ ] **Step 5: Route restored completed saves back to the same result evaluator**

In `handleReady(nextCommands)` after the scene has successfully constructed/validated its restored `GameState`:

```ts
const state = nextCommands.state();
if (state.content.finaleTriggered) {
  harvestResult = buildHarvestResult(state);
  saveStatus = 'saved';
  saveError = null;
  appPhase = 'result';
  launchSource = null;
  return;
}
```

Do not derive a result directly from the unvalidated parsed title save before `GameSession` construction.

Render `ResultScreen` in the `result` phase. Implement:

- Return to Title → reset active game presentation/result UI, keep `loadedSave`, set phase title;
- New Game → reset result/presentation, set `initialState = null`, launch playing;
- final-save failure → still stays on result; Return to Title exposes whatever older valid loaded save actually exists.

- [ ] **Step 6: Run focused tests, typecheck, and browser smoke before acceptance work**

```bash
bun test tests/persistence/persistFinaleSave.test.ts tests/game/harvestFinale.test.ts \
  tests/game/GameSession.test.ts
bun run check
bun run test:e2e tests/e2e/sleep-confirmation.pw.ts
```

The normal Day 1 sleep flow must still show/save the morning summary.

- [ ] **Step 7: Commit Task 5**

```bash
git add src/persistence/persistFinaleSave.ts tests/persistence/persistFinaleSave.test.ts \
  src/components/ResultScreen.svelte src/App.svelte src/components/Overlay.svelte src/app.css
git commit -m "feat(ui): finish runs on the harvest result screen"
```

---

## Task 6: Prove onboarding, both Day 14 endings, persistence, and handoff in one acceptance slice

**Files:**
- Create: `tests/e2e/content.pw.ts`
- Modify: `tests/e2e/helpers.ts` only for genuinely shared reusable helpers
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `tests/config/handoff.test.ts`
- Modify: existing tests only when they intentionally pin the superseded Day 14/map contract

- [ ] **Step 1: Add a visible onboarding E2E without duplicating existing full farming/economy/social specs**

Use:

```ts
await waitForWorld(page, { acknowledgeOpening: false });
```

Assert:

1. opening panel is visible and world input is locked;
2. opening mentions new caretaker/farm context and Day 14 harvest market;
3. Start farming hides the opening and unlocks world input;
4. first tutorial card is `farm-basics` and mentions gold target + Hoe/Space;
5. use existing `acquireTarget` / farming helpers to till → prompt advances to Plant;
6. plant → Water appears on Sunny weather;
7. water → Sleep appears;
8. dismissing a prompt does not set its persisted completion flag;
9. complete the first sleep/save, reload/Continue, and assert already completed farm/plant/water/sleep prompts do not return.

Do not re-prove every economy/social interaction end-to-end here; existing economy/social E2E plus core completion tests already cover those commands.

- [ ] **Step 2: Add a reusable test-only function that seeds Day 14 through the existing save boundary**

Do not add production/test-hook mutation APIs. In `content.pw.ts` or a small E2E helper:

1. start a normal new game;
2. read `gameSnapshot()` from the observation-only hook;
3. construct the exact persisted `GameState` projection by removing transient/derived fields (`player`, `target`, `maxStamina`, authored cells, relationship `level`);
4. set `day = 14`, `timeMinutes = 360`, valid stamina/weather, no pending summary;
5. set desired `content.shippedCrops`, `pendingShipment`, relationship points, and tutorial flags;
6. write `{ schemaVersion: 1, state }` to `phoenix.save.v1` via `localStorage`;
7. reload and press Continue.

Keep the fixture semantically valid under `GameSession` restore checks. If projection code becomes noisy, create a test-only typed helper in `tests/e2e/helpers.ts`; do not expose `GameSession.state()` on `window` just for this.

- [ ] **Step 3: Prove the authored market ending visibly**

Seed a Day 14 state that will produce Heart of the Harvest, with:

- at least 300G lifetime shipped value;
- one Close Friend;
- a non-zero pending shipment so final settlement is observable.

Navigate to target market cell `{ x: 8, y: 6 }` using existing movement + `acquireTarget`. Press E.

Assert:

- result screen replaces the world;
- tier is `Heart of the Harvest`;
- shipped total includes the pending final shipment exactly once;
- day never becomes 15 (verify through saved browser state if the world is unmounted);
- all three villager lines are present;
- save status reaches Saved;
- Return to Title shows Continue;
- Continue returns to the same result screen instead of gameplay.

- [ ] **Step 4: Prove the Day 14 sleep fallback visibly uses the same terminal rule**

Seed an equivalent Day 14 state and navigate to the bed. Open the existing sleep confirmation and Confirm.

Assert:

- no Morning summary appears;
- result screen appears;
- tier/shipped value match the pure expected calculation for the seeded state;
- browser save has `state.day === 14` and `state.content.finaleTriggered === true`;
- pending shipment is cleared and money/lifetime totals reflect one settlement.

Do not compare visual text by hard-coded incidental whitespace; use result data hooks/roles.

Run the new file repeatedly enough to expose movement fragility without adding retries:

```bash
bun run test:e2e tests/e2e/content.pw.ts
bun run test:e2e tests/e2e/content.pw.ts
```

If the second run flakes, fix the shared targeting route before proceeding.

- [ ] **Step 5: Run the complete E2E suite after the new app phase and map object are in place**

```bash
bun run test:e2e
```

Do not accept focused-green if an existing spec is still blocked by opening/modal changes.

- [ ] **Step 6: Update README and architecture handoff from the shipped behavior, not the plan prose**

`README.md`:

- extend the opening feature summary through HPA-597;
- add a concise Onboarding and Harvest Finale section;
- document one contextual tutorial card and success-only completion;
- state the Day 14 objective/market behavior;
- replace the temporary `day-limit-reached` paragraph;
- document final shipping settlement;
- list exact tier boundaries;
- update the authored map/scenery contract from 3-frame 288×96 to 4-frame 384×96 and include market cell 8,6;
- keep existing setup/verification strings intact unless intentionally superseded.

`CLAUDE.md`:

- document `ContentProgress` and lifetime shipped counts under GameSession authority;
- document `contentProgress.ts` and `harvestFinale.ts` as framework-free helpers;
- note the result app phase/final-save orchestration;
- add the market to the authored interaction contract.

Update `tests/config/handoff.test.ts` only for the intentional README/map/Day 14 contract changes.

Run:

```bash
bun test tests/config/handoff.test.ts
```

- [ ] **Step 7: Run the full repository verification matrix**

Run every ordinary gate first so failures are localized:

```bash
bun run check
bun run lint
bun run format:check
bun test
bun run test:coverage
bun run coverage:check
bun run test:e2e
bun run build
bun run tauri:build -- --no-sign
```

Then run the clean-checkout proof:

```bash
bun run verify:clean
```

Do not claim HPA-597 complete without fresh successful output from `verify:clean` on the implementation HEAD.

- [ ] **Step 8: Self-review the final diff against HPA-597 and scope guards**

Check:

```bash
git diff main...HEAD --stat
git diff main...HEAD
```

Explicitly verify:

- no Day 15 path exists;
- market/sleep finalization share one domain method;
- pending final shipping settles once;
- every tutorial flag is completed only after a successful command;
- tutorial dismissal is not persisted as completion;
- final save contains `finaleTriggered` and lifetime shipping totals;
- continued completed save reaches result, not free-play;
- no migration/version bump/framework/quest engine/test mutator slipped in;
- generated asset/map changes match the generator;
- HPA-599 balance/polish work was not pulled forward.

- [ ] **Step 9: Commit acceptance/handoff changes**

```bash
git add tests/e2e/content.pw.ts tests/e2e/helpers.ts README.md CLAUDE.md tests/config/handoff.test.ts
git commit -m "test: verify the HPA-597 content slice"
```

If an existing E2E/test file changed for a legitimate superseded contract, include it in this commit as well.

---

## Completion Checklist

Before moving the PR out of draft:

- [ ] Opening establishes caretaker context and Day 14 market.
- [ ] First tutorial prompt teaches target diamond + Hoe without a separate movement-state system.
- [ ] Successful actions persist tutorial completion; failed/dismissed actions do not.
- [ ] Rain never leaves the player with an impossible manual-water tutorial requirement.
- [ ] Lifetime shipping counts persist and normal nightly money remains unchanged.
- [ ] HUD shows Day 14 objective/remaining days.
- [ ] Authored market exists at cell 8,6 through generator + strict parser.
- [ ] Market cannot finish before Day 14.
- [ ] Day 14 market and sleep both settle pending shipping exactly once and never advance to Day 15.
- [ ] New Beginning, Promising Farmer, and Heart of the Harvest exact boundaries are unit-tested.
- [ ] Each villager contributes one result line based on relationship level.
- [ ] Final state saves immediately and Continue returns completed saves to ResultScreen.
- [ ] Result screen has only New Game / Return to Title; no post-game/free-play.
- [ ] `SAVE_SCHEMA_VERSION` remains 1 and no compatibility/migration layer exists.
- [ ] Full E2E passes without added fixed waits/retries.
- [ ] `bun run verify:clean` passes on final HEAD.
- [ ] README, CLAUDE, and handoff tests describe the shipped contract.
