# Phoenix Social Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for policy/domain/parser changes and keep every task type-green before moving on.

**Goal:** Deliver HPA-595 as one compact village/social slice: three static villagers, daily talking, exact one-crop gifting, favourite bonuses, three relationship levels, one-time Close Friend dialogue, and browser/Tauri proof without adding an NPC/dialogue framework.

**Architecture:** `villagerDefinitions.ts` owns static content and pure relationship policy. The existing 12×12 map owns exact villager cells/footprints and is extended before `GameSession` consumes those cells. `GameSession` remains the only mutable social authority; Phaser remains the render/target adapter; Svelte owns one focused `DialoguePanel` and a complete UI/input lock. No persistence, market finale, schedule system, event engine, or compatibility layer is introduced.

**Tech Stack:** Bun 1.3.1 and `bun:test`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.4, deterministic Bun asset generation, existing Rust 1.96 macOS build boundary.

**Spec:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global constraints

- Implement only HPA-595. Do not start HPA-596 persistence or HPA-597 harvest-market behavior.
- Keep map 12×12, projection 64×32, origin `(384, 0)`, logical stage 640×360, existing camera behavior, and one walkable elevation.
- Villager IDs/names/favourites are exactly: `shopkeeper`/Mira/Potato, `farmer`/Rowan/Pumpkin, `resident`/June/Turnip.
- Exact cells are Mira 7,5; Rowan 3,5; June 9,5. Exact path cells are y=6, x=3 through 9.
- Exact villager footprints are 0.6×0.6: Mira x7.2/y5.2, Rowan x3.2/y5.2, June x9.2/y5.2.
- Exact target stances are: Mira from 6,6 facing right; Rowan from 4,6 facing up; June from 8,6 facing right.
- Relationship floors are 0 Stranger, 12 Friend, 30 Close Friend. First talk/day +1. First gift/day +3, favourite bonus +2.
- Talking/gifting cost no time or stamina. Do not modify `dailyRhythm.ts` for social costs.
- `GameSession` is the only mutable social authority. Store points, `talkedToday`, `giftedToday`, `closeFriendDialogueSeen`; derive level.
- A repeated talk succeeds with 0 points. A repeated/invalid gift fails before inventory/points mutation.
- Successful `sleep()` is the only daily reset seam for talk/gift flags.
- `SocialFeedback` exists only on `villager-talked`/`crop-gifted`; do not create a generic result envelope.
- `InputGate.ts` stays unchanged; it already accepts arbitrary string reasons. App uses `dialogue-panel`.
- Phaser locking is not sufficient: Overlay must receive `dialogueOpen` and disable action/seed HUD controls and its manual input-lock toggle while dialogue is open.
- Keep `window.__PHOENIX_TEST__` observation-only. No teleport, state injection, relationship setter, direct command hook, or weather hook.
- Use native `Continue` button activation. No window-level Enter/Space dialogue progression handler.
- Add no package/dependency and do not change package versions.
- Keep current Playwright retries/timeouts. Fix geometry/helpers rather than masking route problems with retries/sleeps.
- Every planned commit must pass `bun run check`; do not add compatibility aliases or hard-coded fallback villager cells merely to keep an intermediate commit green.

## File map

### Pure social content

- Create: `src/game/core/villagerDefinitions.ts`
- Create: `tests/game/villagerDefinitions.test.ts`
- Modify: `src/game/core/types.ts`

### Static village/map/render contract

- Modify: `tools/generate-proof-assets.ts`
- Modify generated: `src/assets/sprites/proof-tiles.png`
- Create generated: `src/assets/sprites/proof-villagers.png`
- Modify generated: `src/assets/maps/proof-map.json`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `tests/game/loadProofMap.test.ts`
- Modify: `tests/e2e/world.pw.ts`

### Authoritative social progression

- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `src/components/Overlay.svelte`
- Modify: `tests/game/GameSession.test.ts`

### Typed interaction bridge

- Modify: `src/game/phaser/interactionIntent.ts`
- Modify: `tests/game/interactionIntent.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`
- Modify: `src/App.svelte`

`src/components/GameHost.svelte` remains unchanged unless the compiler requires a mechanical type-only change; it forwards the intent opaquely.

### Dialogue presentation

- Create: `src/components/DialoguePanel.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

### Acceptance/handoff

- Create: `tests/e2e/social.pw.ts`
- Modify: `README.md`
- Modify: `tests/config/handoff.test.ts`

No planned changes: `package.json`, `bun.lock`, `src-tauri/**`, `.github/workflows/ci.yml`, `playwright.config.ts`, `src/vite-env.d.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`.

---

## Task 1: Add pure villager content and relationship policy

**Files**

- Create `src/game/core/villagerDefinitions.ts`
- Create `tests/game/villagerDefinitions.test.ts`
- Modify `src/game/core/types.ts`

**Produces**

```ts
export type VillagerId = 'shopkeeper' | 'farmer' | 'resident';
export type RelationshipLevel = 'stranger' | 'friend' | 'closeFriend';

export interface RelationshipSnapshot {
  points: number;
  level: RelationshipLevel;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}

export interface SocialFeedback {
  villagerId: VillagerId;
  lines: string[];
  level: RelationshipLevel;
  points: number;
  pointsGained: number;
  giftReaction: 'normal' | 'favourite' | null;
  closeFriendSequence: boolean;
}
```

- [ ] **Step 1: Write failing policy tests**

Cover exact `VILLAGER_IDS`, names/favourites, point constants, level boundaries, invalid point throws, one normal line per level, exact two-line Close Friend sequences, and fresh returned arrays.

Run:

```bash
bun test tests/game/villagerDefinitions.test.ts
```

Expected RED: module/types missing.

- [ ] **Step 2: Add only additive social types**

Add the closed unions/interfaces above. Do not modify `GameSnapshot`, command codes, `GameSessionConfig`, or current consumers in this task.

- [ ] **Step 3: Implement `villagerDefinitions.ts`**

Use the exact strings from the design spec and direct threshold comparisons. Exports:

```ts
export const VILLAGER_IDS = ['shopkeeper', 'farmer', 'resident'] as const;
export const TALK_POINTS = 1;
export const GIFT_POINTS = 3;
export const FAVOURITE_GIFT_BONUS = 2;
export function relationshipLevel(points: number): RelationshipLevel;
export function dialogueLines(id: VillagerId, level: RelationshipLevel): string[];
export function closeFriendDialogueLines(id: VillagerId): string[];
```

No classes, registries, callbacks, coordinates, event bus, or localization layer.

- [ ] **Step 4: Verify GREEN**

```bash
bun test tests/game/villagerDefinitions.test.ts
bun run check
bun run lint
```

- [ ] **Step 5: Commit**

```bash
git add src/game/core/types.ts src/game/core/villagerDefinitions.ts tests/game/villagerDefinitions.test.ts
git commit -m "feat: define social relationship policy"
```

---

## Task 2: Author and render the static village contract

This task lands the map/parser contract before `GameSessionConfig.villagerCells` becomes required, avoiding a broken `ProofScene` intermediate state.

**Files**

- Modify `tools/generate-proof-assets.ts`
- Modify generated `src/assets/sprites/proof-tiles.png`
- Create generated `src/assets/sprites/proof-villagers.png`
- Modify generated `src/assets/maps/proof-map.json`
- Modify `src/game/phaser/loadProofMap.ts`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `tests/game/loadProofMap.test.ts`
- Modify `tests/e2e/world.pw.ts`

**Exact map contract**

- 12×12, four layers, `nextlayerid: 5`, `nextobjectid: 17`.
- `proof-tiles.png`: 192×32, GIDs grass 1 / farm 2 / path 3.
- Path cells: `3,6 4,6 5,6 6,6 7,6 8,6 9,6` only.
- `proof-scenery.firstgid = 4`; global scenery GIDs tree/building/shipping = 4/5/6.
- HPA-597 reserve x8–10/y2–3 remains grass and empty.
- Collision IDs 11–13: shopkeeper 7.2/5.2/0.6/0.6; farmer 3.2/5.2/0.6/0.6; resident 9.2/5.2/0.6/0.6.
- Marker IDs 14–16: shopkeeper cell7,5/world448,208; farmer cell3,5/world320,144; resident cell9,5/world512,240.
- `proof-villagers.png`: 96×48, frames in `VILLAGER_IDS` order.

- [ ] **Step 1: Write parser/asset RED first**

Update `tests/game/loadProofMap.test.ts` to assert:

1. exact new tile metadata/path cells;
2. exact shifted scenery GIDs;
3. exact villager markers/placements/cells;
4. exact three 0.6 footprints;
5. exact six-footprint output order;
6. missing/duplicate/renamed/misplaced villager marker rejection;
7. missing/malformed/unexpected villager collision rejection;
8. market reserve remains empty;
9. PNG dimensions 192×32 and 96×48.

Run:

```bash
bun test tests/game/loadProofMap.test.ts
```

Expected RED against HPA-593 fixtures/parser.

- [ ] **Step 2: Extend deterministic generation**

Use existing `project()`/`logicalPolygon()` helpers. Add the path frame/cells, shift scenery GIDs, generate the villager sheet, add object IDs 11–16, and write `nextobjectid: 17`.

Run:

```bash
bun run assets:generate
```

- [ ] **Step 3: Fix the parser invariant explicitly**

Keep the existing scenery contract unchanged except the GID shift. Add a separate villager-footprint contract keyed by `VillagerId`.

`parseCollision` must validate exactly six collision objects and return:

```ts
[
  ...sceneryFootprintsInExistingSceneryOrder,
  ...VILLAGER_IDS.map((id) => villagerFootprintById.get(id)),
]
```

Do not cast villager collisions to `SceneryKind` and do not return only `scenery.map(...)`.

`ParsedProofMap` adds `villagers` and `villagerCells`, but `GameSnapshot` does not.

- [ ] **Step 4: Render static villagers in the existing depth system**

In `ProofScene.ts`, preload the 32×48 villager sheet, create one bottom-center sprite per parsed placement, include `villager:${id}` in debug/depth entries using marker object ID as stable order, and clean sprites up with the scene.

Do not add interaction or NPC movement yet.

- [ ] **Step 5: Retune existing world route immediately**

The current `world.pw.ts` tree detour travels through the new Mira footprint area. Change its waypoint/leg so it routes around Mira while preserving the same 3-second helper deadlines and retries 0.

Also prove before leaving this task:

- farm/shop/shipping/bed routes still work;
- all three path stances can acquire villager cells;
- representative villager collision blocks entry;
- player/villager depth reverses across the footpoint;
- camera remains bounded.

Do not postpone this to the long social journey.

- [ ] **Step 6: Verify GREEN and deterministic output**

```bash
bun run assets:generate
bun test tests/game/loadProofMap.test.ts
bun run check
bun run lint
bun run test:e2e -- tests/e2e/world.pw.ts tests/e2e/economy.pw.ts
bun run assets:generate
```

The final generator run must leave generated files byte-identical.

- [ ] **Step 7: Commit**

```bash
git add tools/generate-proof-assets.ts src/assets/maps/proof-map.json src/assets/sprites/proof-tiles.png src/assets/sprites/proof-villagers.png src/game/phaser/loadProofMap.ts src/game/phaser/ProofScene.ts tests/game/loadProofMap.test.ts tests/e2e/world.pw.ts
git commit -m "feat: author the compact village"
```

---

## Task 3: Make GameSession authoritative for social progression

**Files**

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/components/Overlay.svelte`
- Modify `tests/game/GameSession.test.ts`

**Interfaces**

```ts
villagerCells: Record<VillagerId, GridCell>;
relationships: Record<VillagerId, RelationshipSnapshot>;
talkTo(villagerId: VillagerId): CommandResult;
giftCrop(villagerId: VillagerId, crop: CropKind): CommandResult;
```

- [ ] **Step 1: Extend tests/config using real targeting**

Use the exact villager cells from Task 2. For direct domain target tests, build normal `GameSession` configs with a spawn at an appropriate diagonal stance and use `stepMovement(..., 0)` only to set facing. Do not add a target setter.

- [ ] **Step 2: Write failing social domain tests**

Cover:

1. fresh relationship state;
2. deep snapshot freshness;
3. `not-at-villager` without mutation;
4. first talk +1;
5. repeated talk +0;
6. normal gift consumes one/+3;
7. favourite gift consumes one/+5;
8. repeated gift rejects before consumption;
9. missing crop rejects before daily flag;
10. Friend at 12 / Close Friend at 30;
11. gift crossing 30 leaves special dialogue unseen;
12. next talk returns exact two-line sequence once;
13. later talk returns normal Close Friend line;
14. successful sleep resets daily flags only;
15. failed/Day14/summary-pending sleep does not reset twice;
16. summary pending blocks both commands;
17. JSON round trip;
18. constructor cloning/in-bounds/distinct cell invariants.

Obtain gift crops through existing domain farming/economy helpers; do not inject inventory state.

- [ ] **Step 3: Extend command/snapshot types**

Add `relationships` and the two social success codes/payloads plus `not-at-villager` and `gift-already-given`.

In the same step, extend `Overlay.svelte`'s exhaustive `commandResultMessage()` with mechanical labels for all four new codes. This is required here so `bun run check` stays green; do not defer the exhaustive switch to the dialogue task.

- [ ] **Step 4: Implement GameSession state and commands**

Clone/validate `villagerCells`; initialize social records; derive levels in snapshots/feedback; implement the exact validation/mutation orders from the design spec; reset daily flags only in successful `sleep()`.

- [ ] **Step 5: Wire the parsed cells and direct scene facades**

Task 2 already exposes `parsed.villagerCells`. Update the existing `new GameSession(...)` call to pass them when the config field becomes required.

Add `SceneCommands.talkTo` and `giftCrop` facades using the existing `publishCommand` path. No presentation command or session exposure.

- [ ] **Step 6: Verify GREEN**

```bash
bun test tests/game/villagerDefinitions.test.ts tests/game/GameSession.test.ts tests/game/loadProofMap.test.ts
bun test tests/game
bun run check
bun run lint
```

- [ ] **Step 7: Commit**

```bash
git add src/game/core/types.ts src/game/core/GameSession.ts src/game/phaser/ProofScene.ts src/components/Overlay.svelte tests/game/GameSession.test.ts
git commit -m "feat: add authoritative social progression"
```

---

## Task 4: Route the typed interaction intent without compatibility aliases

**Files**

- Modify `src/game/phaser/interactionIntent.ts`
- Modify `tests/game/interactionIntent.test.ts`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/App.svelte`

**Intent**

```ts
type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };
```

- [ ] **Step 1: Write intent RED**

Prove sleep/shop/shipping object intents, all three exact villager intents, and null/unrelated targets.

```bash
bun test tests/game/interactionIntent.test.ts
```

- [ ] **Step 2: Implement the closed union**

Use direct authored-cell equality and `VILLAGER_IDS`; do not build an interaction registry.

- [ ] **Step 3: Route E in ProofScene**

Pass bed/shop/shipping/villager cells to `interactionIntentForTarget`. Null still publishes `nothing-to-interact`; non-null forwards one typed intent. Keep `ActionController` unchanged.

- [ ] **Step 4: Convert App to `intent.kind` in the same task**

Do not leave the old `intent === 'sleep'` / `economyPanel = intent` consumer for Task 5.

Use a switch:

```ts
switch (intent.kind) {
  case 'sleep':
    // existing sleep presentation
    break;
  case 'shop':
  case 'shipping':
    economyPanel = intent.kind;
    syncEconomyPanel();
    break;
  case 'villager':
    commands?.talkTo(intent.villagerId);
    break;
}
```

The villager branch deliberately publishes the authoritative talk result but does not open dialogue presentation until Task 5. No string compatibility alias or temporary hard-coded mapping.

- [ ] **Step 5: Verify GREEN**

```bash
bun test tests/game/interactionIntent.test.ts tests/game/GameSession.test.ts
bun run check
bun run lint
```

- [ ] **Step 6: Commit**

```bash
git add src/game/phaser/interactionIntent.ts tests/game/interactionIntent.test.ts src/game/phaser/ProofScene.ts src/App.svelte
git commit -m "feat: route villager interactions"
```

---

## Task 5: Add one focused dialogue/gift panel and lock every control path

**Files**

- Create `src/components/DialoguePanel.svelte`
- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`
- Modify `src/app.css`

**Ownership**

- App owns panel-open state and `dialogue-panel` InputGate reason.
- DialoguePanel owns line index, gift-choice visibility, and local focus.
- GameSession owns points, flags, inventory, and feedback.
- Overlay remains HUD/economy/day summary; it only receives `dialogueOpen` to disable controls.

- [ ] **Step 1: Make App open authoritative social presentation**

Change the Task 4 villager branch to call `talkTo`, require the social success payload, store `{ villagerId, social }`, and set `inputGate.set('dialogue-panel', true)`.

Add `closeDialoguePanel()` and a gift callback. Gift success replaces current social feedback; failure stays in the existing command-result channel and does not close the panel. Reset/unmount clears the state/reason idempotently.

- [ ] **Step 2: Create `DialoguePanel.svelte`**

Required behavior:

- `role="dialog"`, `aria-modal="true"`, labelled by villager name;
- portrait placeholder/name/role/level;
- exactly one `social.lines[index]` visible;
- native `Continue` focused while another line remains;
- after last line: `Give gift` and `Close`;
- gift list contains only carried crop kinds with count > 0;
- each gift sends exactly one crop;
- no crops => `No harvested crops to give`;
- successful gift resets line index to zero and displays returned response/points/reaction/level;
- local Escape may close;
- no window-level Enter/Space progression handler;
- no relationship math in Svelte.

Do not use `QuantityStepper.svelte`.

- [ ] **Step 3: Close the HUD bypass**

Pass `dialogueOpen={dialoguePanel !== null}` into `Overlay.svelte`.

Update Overlay:

```ts
const actionsReady = $derived(
  status === 'ready' &&
    commands !== null &&
    snapshot !== null &&
    !dayTransitionActive &&
    economyPanel === null &&
    !dialogueOpen,
);
```

Also make the manual overlay input-lock toggle refuse/disable when `dialogueOpen` is true. Seed/action buttons already derive from `actionsReady`, so no second lock mechanism is needed.

Do **not** modify `InputGate.ts`; arbitrary reason strings already work.

- [ ] **Step 4: Add stage-local CSS**

Add a 640×360 dialogue layer above HUD/economy surfaces with the existing modal visual language. No HUD redesign.

- [ ] **Step 5: Verify static/UI regressions**

```bash
bun run check
bun run lint
bun run format:check
bun run build
bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts tests/e2e/economy.pw.ts
```

- [ ] **Step 6: Commit**

```bash
git add src/App.svelte src/components/DialoguePanel.svelte src/components/Overlay.svelte src/app.css
git commit -m "feat: add villager dialogue and gifting UI"
```

---

## Task 6: Prove the full social loop through real browser controls

**Files**

- Create `tests/e2e/social.pw.ts`

World geometry/collision route work belongs to Task 2 and should already be green.

- [ ] **Step 1: Build the five-Turnip setup through real controls**

Start a new session. Visit the seed shop and buy two additional Turnip seeds. Prepare five farm cells with real Hoe/Seeds controls.

The day-one stamina budget is exactly consumed by five hoes (15) plus five plants (5), so do not add a day-one watering expectation. Sleep once dry, then water normally for three growing nights and harvest five mature Turnips on the resulting morning.

- [ ] **Step 2: Implement the five-social-day June journey**

Use local route helpers built from existing `tests/e2e/helpers.ts`; do not widen the test hook.

For June at 9,5, stand on the y=6 path stance and face right before `E`.

Prove:

1. first talk locks world/UI, gives +1, Stranger;
2. close/reopen same day gives +0;
3. favourite Turnip gift consumes exactly one and gives +5;
4. second same-day gift preserves inventory/points;
5. sleep/start day clears June daily flags;
6. repeat talk + favourite gift for five social days total;
7. Friend appears exactly when crossing 12;
8. Close Friend appears exactly when crossing 30;
9. the gift that crosses 30 leaves special dialogue unseen;
10. reopen June the same day: exact two-line Close Friend sequence appears once;
11. with Continue focused, one Enter shows line two and does not skip to final actions;
12. close/reopen: only normal Close Friend line remains;
13. `GameSnapshot` JSON round-trips in page context.

Use `expect.poll` on authoritative snapshots and release held keys in `finally`.

- [ ] **Step 3: Verify the no-bypass modal contract**

While dialogue is open, assert:

- debug snapshot reports Phaser input locked;
- action/seed HUD buttons are disabled;
- manual `Lock world input` / `Unlock world input` toggle is disabled;
- movement keys do not move the player.

This proves both Phaser and Svelte control paths are blocked.

- [ ] **Step 4: Run focused and full browser suites**

```bash
bun run test:e2e -- tests/e2e/social.pw.ts tests/e2e/world.pw.ts
bun run test:e2e
```

If the journey is flaky, fix route geometry/helper waypoints. Do not increase retries/global timeout or add arbitrary sleeps/state hooks.

- [ ] **Step 5: Commit**

```bash
git add tests/e2e/social.pw.ts
git commit -m "test: prove the village social loop"
```

---

## Task 7: Pin the README contract and run full delivery verification

**Files**

- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

- [ ] **Step 1: Update README with stable HPA-595 facts**

Include these exact phrases so the existing handoff contract can pin them without fragile prose matching:

- `HPA-595`
- `E on a villager talks`
- `one harvested crop`
- `Friend at 12`
- `Close Friend at 30`
- `shopkeeper cell 7,5`
- `farmer cell 3,5`
- `resident cell 9,5`

Surrounding prose can remain concise. Do not document persistence/market finale as implemented.

- [ ] **Step 2: Extend `tests/config/handoff.test.ts`**

Add a social-content loop next to the current HPA-592/HPA-593 pinning:

```ts
for (const socialText of [
  'HPA-595',
  'E on a villager talks',
  'one harvested crop',
  'Friend at 12',
  'Close Friend at 30',
  'shopkeeper cell 7,5',
  'farmer cell 3,5',
  'resident cell 9,5',
]) {
  expect(readme.toLowerCase()).toContain(socialText.toLowerCase());
}
```

- [ ] **Step 3: Run deterministic and clean-checkout verification**

```bash
bun run assets:generate
bun run verify:clean
```

Fix generator/source ownership if generated fixtures differ; do not hand-edit generated outputs.

- [ ] **Step 4: Run current CI parity**

```bash
bun run check
bun run lint
bun run format:check
bun run build
bun run test
bun run test:coverage
bun run coverage:check
bun run test:e2e
```

Do not lower coverage thresholds.

- [ ] **Step 5: Run the macOS native boundary when on macOS**

```bash
bun run tauri:build -- --no-sign
```

If GUI access exists, manually smoke: walk to one villager, open dialogue, close, confirm movement resumes. Report environmental limitations rather than adding native-only social code.

- [ ] **Step 6: Self-review scope and known risks**

Verify the final diff has:

- map still 12×12;
- no dependency/lockfile change;
- no InputGate implementation change;
- no `dailyRhythm` social-cost work;
- no mutable relationship state in Phaser/Svelte;
- exact 0.6 villager footprints and targetable y=6 stances;
- `parseCollision` returns all six footprints in specified order;
- existing world/economy routes green after Mira collision;
- Overlay controls disabled during dialogue;
- test hook still observation-only;
- market reserve empty;
- HPA-596/HPA-597 behavior absent;
- gift consumes exactly one crop;
- successful sleep is the only daily social reset;
- snapshots plain/fresh/JSON-safe;
- README facts pinned by `handoff.test.ts`.

Run:

```bash
git diff --check
```

- [ ] **Step 7: Commit**

```bash
git add README.md tests/config/handoff.test.ts
git commit -m "docs: pin the social slice handoff"
```

## Primary implementation risks

1. **Map route regression:** Mira's new 0.6 footprint overlaps the area used by the current tree-detour route. Task 2 must retune and prove existing routes before social progression work continues.
2. **Five-day browser journey:** it is intentionally long because it is the only no-hook proof of daily reset + threshold crossing + one-time two-line dialogue. Keep retries/timeouts unchanged and fix waypoints rather than masking flakes.
3. **Ground/scenery GID shift:** generator, generated fixtures, parser, and fixture tests must land together.
4. **Modal control bypass:** `InputGate` locks Phaser only; Task 5 must also disable Overlay's button/toggle paths through `dialogueOpen`.

## Recommended implementation commit shape

1. `feat: define social relationship policy`
2. `feat: author the compact village`
3. `feat: add authoritative social progression`
4. `feat: route villager interactions`
5. `feat: add villager dialogue and gifting UI`
6. `test: prove the village social loop`
7. `docs: pin the social slice handoff`

No merge commit is required.

## Completion criteria

HPA-595 is complete only when:

- all three villagers are visible, walkable-around, targetable from their documented path stances, and depth-sorted correctly;
- talk credit is once/day and repeated talk still returns dialogue;
- gift consumes exactly one crop, awards normal/favourite points, and is once/day;
- Stranger/Friend/Close Friend use exact thresholds;
- one Close Friend sequence triggers once per villager;
- June reaches Close Friend through the real five-social-day browser journey;
- one Enter on focused Continue advances exactly one line;
- dialogue locks Phaser plus Overlay action/seed/toggle controls;
- social snapshot state is fresh plain JSON;
- README/handoff pins the new controls/thresholds/cells;
- current static/unit/coverage/E2E/build gates pass;
- unsigned macOS Tauri build remains green;
- no persistence/finale/NPC/dialogue framework work leaks into the slice.
