# Phoenix Social Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for domain/parser work and keep each task green before moving on.

**Goal:** Deliver HPA-595 as one compact village/social vertical slice: three static villagers, daily talk and one-crop gifting, favourite bonuses, three relationship levels, one-time Close Friend dialogue, and real browser/Tauri proof without adding an NPC or dialogue framework.

**Architecture:** `villagerDefinitions.ts` owns static villager content and pure relationship policy. `GameSession` remains the only mutable gameplay authority and stores plain relationship records plus direct `talkTo`/`giftCrop` commands. The existing 12×12 Tiled map gains a path, three villager markers, and three collision footprints; Phaser renders/targets static villager sprites and routes one discriminated interaction intent; Svelte owns one dedicated `DialoguePanel` and its InputGate reason. No map resize, second state authority, schedule system, event engine, or persistence work is introduced.

**Tech Stack:** Bun 1.3.1 and `bun:test`, TypeScript/Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.4, deterministic Bun asset generation, and the existing Rust 1.96 macOS build boundary.

**Spec:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global Constraints

- Implement only HPA-595. Do not start HPA-596 persistence or HPA-597 harvest-market content.
- Keep the map exactly 12×12, projection 64×32, origin `(384, 0)`, logical stage 640×360, and existing camera behavior.
- Add one path ground tile; do not add houses, interiors, another map, another scenery building, or a second elevation.
- Villager IDs are exactly `shopkeeper`, `farmer`, `resident`; names are Mira, Rowan, June; favourites are Potato, Pumpkin, Turnip respectively.
- Relationship level floors are exactly 0 Stranger, 12 Friend, 30 Close Friend. Talk grants +1 once/day. Gift grants +3 once/day plus +2 for a favourite crop. No decay, cap, dislike, random modifier, birthday, or hidden multiplier.
- Talking and gifting consume no time or stamina. Do not widen `dailyRhythm.ts` or introduce a generic action-cost system for social commands.
- `GameSession` is the only mutable social authority. Svelte and Phaser never change relationship points, daily flags, or inventory directly.
- Store only points plus `talkedToday`, `giftedToday`, and `closeFriendDialogueSeen`; derive relationship level from points. Do not persist dialogue lines or panel state in `GameSnapshot`.
- A repeated same-day talk still returns dialogue but adds 0 points. A repeated/invalid gift is rejected before inventory or relationship mutation.
- The one-time Close Friend sequence is triggered by the first talk while the villager is Close Friend and the flag is false; gifting across the threshold does not consume the sequence.
- Reset `talkedToday` and `giftedToday` only inside one successful `sleep()` transition. Failed sleep and duplicate summary-pending sleep must not reset again.
- Keep `window.__PHOENIX_TEST__` observation-only. Do not add teleport, inventory injection, relationship setters, direct commands, weather setters, or social test hooks.
- Use native button activation for dialogue `Continue`; do not add competing window-level Enter/Space progression handlers. One Enter key press on focused Continue must advance one line exactly once.
- Use Bun as the only JavaScript package manager and existing test runners. Add no package or dependency.
- No compatibility aliases are required for the internal interaction-intent type change; update all current consumers in the same task.
- Generated PNG/JSON assets stay deterministic and committed. `bun run assets:generate` must regenerate the checked-in fixtures exactly.
- Browser acceptance must enter through real movement keys, `E`, and visible buttons. Keep existing Playwright retries/timeouts; do not hide route failures with sleeps, retry increases, or mutation hooks.
- Final validation must match the current CI gates: static check, lint, format, frontend build, unit/coverage gates, full browser E2E, and unsigned macOS Tauri build when running on macOS.

## File Map

### Pure social policy and authoritative state

- Create: `src/game/core/villagerDefinitions.ts`
- Create: `tests/game/villagerDefinitions.test.ts`
- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `tests/game/GameSession.test.ts`

### Deterministic village assets and authored map

- Modify: `tools/generate-proof-assets.ts`
- Modify (generated): `src/assets/sprites/proof-tiles.png`
- Create (generated): `src/assets/sprites/proof-villagers.png`
- Modify (generated): `src/assets/maps/proof-map.json`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `tests/game/loadProofMap.test.ts`

### Phaser interaction and rendering

- Modify: `src/game/phaser/interactionIntent.ts`
- Modify: `tests/game/interactionIntent.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`

### Svelte dialogue presentation

- Create: `src/components/DialoguePanel.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

`src/components/GameHost.svelte` should remain unchanged unless the compiler requires a mechanical type-only adjustment: it already forwards `InteractionIntent` opaquely.

### Acceptance and handoff

- Create: `tests/e2e/social.pw.ts`
- Modify: `tests/e2e/world.pw.ts` only for physical villager collision/depth evidence that is clearer there than in the social journey.
- Modify: `README.md` with the new villager interaction/gifting control summary.

No change is planned for `package.json`, `bun.lock`, `src-tauri/**`, `.github/workflows/ci.yml`, `playwright.config.ts`, `src/vite-env.d.ts`, `src/game/core/dailyRhythm.ts`, or the development-hook shape.

---

## Task 1: Add Pure Villager Content and Relationship Policy

**Files:**

- Create: `src/game/core/villagerDefinitions.ts`
- Create: `tests/game/villagerDefinitions.test.ts`
- Modify: `src/game/core/types.ts`

**Interfaces:**

- Produces `VillagerId`, `RelationshipLevel`, `RelationshipSnapshot`, `SocialFeedback`.
- Produces stable `VILLAGER_IDS`, exact definitions, relationship constants, `relationshipLevel(points)`, and fresh dialogue-line helpers.
- Does not consume `GameSession`, Phaser, map data, or Svelte state.

- [ ] **Step 1: Write the failing definition/policy tests**

Create `tests/game/villagerDefinitions.test.ts` covering all of the following in one focused suite:

1. `VILLAGER_IDS` is exactly `['shopkeeper', 'farmer', 'resident']`.
2. Definitions are exactly:
   - shopkeeper → Mira → Potato;
   - farmer → Rowan → Pumpkin;
   - resident → June → Turnip.
3. Point policy is exactly talk 1, gift 3, favourite bonus 2.
4. Level boundaries are:
   - 0–11 Stranger;
   - 12–29 Friend;
   - 30+ Close Friend.
5. Negative, fractional, NaN, and unsafe point values throw as programmer errors.
6. Normal dialogue is available for all three levels for all three villagers.
7. Every Close Friend sequence has exactly two non-empty lines.
8. Returned dialogue arrays are fresh and mutating one returned array cannot change the static definitions.

Run:

```bash
bun test tests/game/villagerDefinitions.test.ts
```

Expected RED: module/types are missing.

- [ ] **Step 2: Add the additive social types**

In `src/game/core/types.ts` add:

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

Do not change `GameSnapshot` or `CommandResult` yet; Task 2 performs the authoritative migration.

- [ ] **Step 3: Implement the pure definitions**

Create `src/game/core/villagerDefinitions.ts` with only readonly content/constants and pure helpers.

Use the exact dialogue strings from the design spec. Keep the relationship level helper as a direct threshold comparison; do not introduce a level class, strategy, event table, localization framework, or dialogue AST.

- [ ] **Step 4: Run focused GREEN and static check**

```bash
bun test tests/game/villagerDefinitions.test.ts
bun run check
```

Expected: focused tests pass; existing app types remain green because the types are additive.

- [ ] **Step 5: Commit**

```bash
git add src/game/core/types.ts src/game/core/villagerDefinitions.ts tests/game/villagerDefinitions.test.ts
git commit -m "feat: define social relationship policy"
```

---

## Task 2: Make GameSession Authoritative for Talk, Gifts, and Daily Reset

**Files:**

- Modify: `src/game/core/types.ts`
- Modify: `src/game/core/GameSession.ts`
- Modify: `tests/game/GameSession.test.ts`

**Interfaces:**

- `GameSessionConfig` gains `villagerCells: Record<VillagerId, GridCell>`.
- `GameSnapshot` gains `relationships: Record<VillagerId, RelationshipSnapshot>`.
- `GameSession` gains `talkTo(villagerId)` and `giftCrop(villagerId, crop)`.
- Social successes carry `social: SocialFeedback`.
- Existing farming/economy/day command semantics remain unchanged.

- [ ] **Step 1: Extend the test config without adding a test hook**

Add one test-owned `villagerCells` record to the existing `config()` factory. Keep these cells distinct from farm/bed/shop/shipping.

For direct location tests, use a helper that creates a normal `GameSession` with a spawn one diagonal cell from the desired test villager and calls `stepMovement(..., 0)` only to change facing. `ProofWorld` target offsets already make this possible; do not add a target setter to production or tests.

- [ ] **Step 2: Write failing GameSession social tests**

Add focused cases for:

1. fresh session has zero points and all three flags false for every villager;
2. relationship records are deeply fresh across snapshots;
3. talk away from the requested villager returns `not-at-villager` with no mutation;
4. first valid talk adds exactly 1 and sets only that villager's `talkedToday`;
5. repeated same-day talk returns success dialogue with `pointsGained: 0` and unchanged points;
6. normal gift consumes exactly one carried crop and grants +3;
7. favourite gift consumes exactly one carried crop and grants +5;
8. repeated gift returns `gift-already-given` before consuming another crop;
9. gift with no carried selected crop returns `insufficient-crops` without marking the daily flag;
10. Friend is reflected at 12 points and Close Friend at 30;
11. crossing 30 through a gift leaves `closeFriendDialogueSeen` false;
12. first talk while Close Friend returns the exact two-line special sequence and sets the flag;
13. later talk returns the normal Close Friend line;
14. successful sleep resets `talkedToday` and `giftedToday` for all villagers while preserving points/Close Friend flag;
15. sleep away from bed, Day 14 sleep failure, and summary-pending duplicate sleep do not perform a second reset;
16. summary-pending active-day gating blocks `talkTo` and `giftCrop` with `day-summary-pending`;
17. a nontrivial social snapshot JSON-round-trips exactly.

Also extend constructor invariant tests for missing/duplicate/out-of-bounds/overlapping interaction cells and cloning of caller-owned `villagerCells`.

Run:

```bash
bun test tests/game/GameSession.test.ts
```

Expected RED: config/types/commands do not exist yet.

- [ ] **Step 3: Add the command/result and snapshot contracts**

In `types.ts`:

- add `relationships` to `GameSnapshot`;
- split the existing success side of `CommandResult` so `villager-talked` and `crop-gifted` require `social: SocialFeedback`;
- add failures `not-at-villager` and `gift-already-given`;
- preserve every current success/failure code exactly.

Do not add optional payloads to every command and do not replace the union with a generic command envelope.

- [ ] **Step 4: Add cloned configuration and mutable relationship records**

In `GameSession`:

- clone and validate `villagerCells` in the constructor;
- initialize one small mutable record for all `VILLAGER_IDS`;
- derive `level` only when producing snapshots/feedback;
- deep-clone every relationship record in `snapshot()`.

Validation should only ensure integer/in-bounds/distinct interaction cells and no ambiguity with farm/bed/shop/shipping cells. Do not reject a villager cell because its authored collision footprint occupies part of that cell; collision is intentional and owned by the map/world layer.

- [ ] **Step 5: Implement `talkTo`**

Order:

1. `activeDayFailure()`;
2. target equals `villagerCells[id]`;
3. if first talk today, set flag and add 1;
4. derive resulting level;
5. if level is Close Friend and special flag is false, return special lines and set flag;
6. otherwise return the normal line for resulting level.

Repeated talk is still `ok: true`, `code: 'villager-talked'`, and has `pointsGained: 0`.

- [ ] **Step 6: Implement `giftCrop`**

Order:

1. `activeDayFailure()`;
2. target equals villager cell;
3. reject `gift-already-given`;
4. reject `insufficient-crops` if carried count is zero;
5. decrement exactly one crop;
6. set `giftedToday`;
7. add 3 plus favourite bonus 2 when applicable;
8. return one-line gift response and resulting level.

Do not accept a quantity and do not reuse `depositCrop` or `QuantityStepper` semantics.

- [ ] **Step 7: Reset daily social flags in the successful sleep transaction**

Reset every `talkedToday`/`giftedToday` only after every sleep validation/provider check that can still fail, as part of the same successful state transition that increments `day` and creates the pending summary.

Preserve points and `closeFriendDialogueSeen`.

- [ ] **Step 8: Run focused and domain regression tests**

```bash
bun test tests/game/villagerDefinitions.test.ts tests/game/GameSession.test.ts
bun test tests/game
bun run check
```

Expected: all domain tests green. No map/UI code has been changed yet.

- [ ] **Step 9: Commit**

```bash
git add src/game/core/types.ts src/game/core/GameSession.ts tests/game/GameSession.test.ts
git commit -m "feat: add authoritative social progression"
```

---

## Task 3: Author the Village Path, Villager Markers, Collisions, and Sprite Sheet

**Files:**

- Modify: `tools/generate-proof-assets.ts`
- Modify (generated): `src/assets/sprites/proof-tiles.png`
- Create (generated): `src/assets/sprites/proof-villagers.png`
- Modify (generated): `src/assets/maps/proof-map.json`
- Modify: `src/game/phaser/loadProofMap.ts`
- Modify: `tests/game/loadProofMap.test.ts`

**Exact authored contract:**

- Map remains 12×12 and four layers.
- Ground PNG becomes 192×32: grass/farm/path.
- Ground GIDs are 1/2/3.
- Scenery `firstgid` becomes 4; global GIDs are tree 4, building 5, shipping bin 6.
- Path cells: `3,6 4,6 5,6 6,6 7,6 8,6 9,6 3,5 9,5 9,4`.
- Market reserve: x 8–10, y 2–3 stays grass and empty.
- Villager collision IDs 11–13 and marker IDs 14–16 are exact as the design spec states.
- `nextobjectid` becomes 17.
- Villager PNG is 96×48, 32×48 per frame in `VILLAGER_IDS` order.

- [ ] **Step 1: Update parser/asset tests first and observe RED**

In `tests/game/loadProofMap.test.ts`, change the authored-contract expectations before production edits:

- `nextobjectid: 17`;
- exact existing + villager footprints;
- exact villager placements/cells/stable object order;
- existing farm/bed/shop/shipping cells unchanged;
- path GID cells exact;
- six market-reserve cells remain GID 1 and have no object/footprint;
- `proof-tiles.png` expected 192×32;
- new `proof-villagers.png` expected 96×48;
- scenery tile IDs/metadata shifted to firstgid 4;
- missing/duplicate/renamed/misplaced villager marker failures;
- malformed/missing villager footprint failures;
- unknown marker/collision objects still rejected.

Run:

```bash
bun test tests/game/loadProofMap.test.ts
```

Expected RED against current HPA-593 fixtures/parser.

- [ ] **Step 2: Extend the deterministic generator**

In `tools/generate-proof-assets.ts`:

- expand the ground surface to 192×32 and draw one simple path diamond in frame 3;
- assign GID 3 to the exact path-cell set while preserving GID 2 only for the existing nine farm cells;
- shift scenery global IDs to 4/5/6 without changing scenery pixel frames;
- generate three distinct 32×48 villager frames into a 96×48 surface;
- add exact logical collision polygons IDs 11–13;
- add exact footpoint marker points IDs 14–16;
- set `nextobjectid: 17`;
- write `proof-villagers.png` with the other checked-in assets.

Keep `project()` and `logicalPolygon()` as the only coordinate conversion helpers. Do not hand-maintain duplicate pixel coordinates when the logical coordinate can be projected.

Run:

```bash
bun run assets:generate
```

- [ ] **Step 3: Extend the exact map parser, not a generic Tiled framework**

In `loadProofMap.ts`:

- update exact ground/scenery tileset metadata;
- keep the existing four-layer/header validation;
- validate path cells through the exact ground contract while returning the same nine `farmCells`;
- extend collision contracts with three villager footprints;
- extend allowed markers with the three `villager-*` names;
- parse exact marker IDs/positions into `VillagerPlacement[]` and `villagerCells`;
- keep existing scenery parsing limited to tree/building/shipping bin;
- return all six collision footprints in `world.footprints`.

Do not add properties to `GameSnapshot` for map placements.

- [ ] **Step 4: Run parser GREEN and generation consistency checks**

```bash
bun test tests/game/loadProofMap.test.ts
bun run assets:generate
bun test tests/game/loadProofMap.test.ts
bun run check
```

Run the generator twice before committing and verify the second run changes no generated bytes compared with the first run. Then inspect the generated JSON to confirm the market reserve and existing interaction cells were not moved.

- [ ] **Step 5: Commit**

```bash
git add tools/generate-proof-assets.ts src/assets/maps/proof-map.json src/assets/sprites/proof-tiles.png src/assets/sprites/proof-villagers.png src/game/phaser/loadProofMap.ts tests/game/loadProofMap.test.ts
git commit -m "feat: author the compact village"
```

---

## Task 4: Render Villagers and Route a Typed Interaction Intent

**Files:**

- Modify: `src/game/phaser/interactionIntent.ts`
- Modify: `tests/game/interactionIntent.test.ts`
- Modify: `src/game/phaser/ProofScene.ts`

**Interfaces:**

```ts
type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };
```

`SceneCommands` gains `talkTo` and `giftCrop`; every command still flows through `publishCommand`.

- [ ] **Step 1: Update interaction-intent tests first**

Rewrite the current string expectations to the object union and add all three villager cells. Prove:

- exact sleep/shop/shipping intents still resolve;
- each villager cell resolves to its exact `VillagerId`;
- null/unrelated targets return null;
- interaction cells are not inferred from names or sprite positions.

Run:

```bash
bun test tests/game/interactionIntent.test.ts
```

Expected RED because the old helper is string-only.

- [ ] **Step 2: Implement the closed intent union**

Update `interactionIntent.ts` with one `InteractionCells` shape containing bed/shop/shipping plus `villagerCells`. Use direct cell equality and stable `VILLAGER_IDS`; do not create an interaction registry or callback map.

- [ ] **Step 3: Preload and create static villager sprites**

In `ProofScene.ts`:

- preload `proof-villagers.png` as 32×48 frames;
- create one sprite from every `parsed.villagers` placement using bottom-center origin;
- keep a `Map<VillagerId, Sprite>`;
- pass `parsed.villagerCells` into `GameSession`;
- include `villager:${id}` in `DebugDepths` and the existing footpoint sort;
- destroy/clear villager sprites during scene cleanup.

Do not add update-loop movement for villagers.

- [ ] **Step 4: Route E and add direct command facades**

In `update()` obtain the current target, call `interactionIntentForTarget` with current map interaction cells, and:

- publish `nothing-to-interact` on null;
- forward the typed intent otherwise.

Add `SceneCommands.talkTo` and `giftCrop` facades that delegate to `GameSession` and call the existing `publishCommand` exactly once.

- [ ] **Step 5: Run adapter/domain checks**

```bash
bun test tests/game/interactionIntent.test.ts tests/game/GameSession.test.ts tests/game/loadProofMap.test.ts
bun run check
bun run lint
```

Expected: no compatibility alias and no changes to `ActionController`; `E` remains one edge-triggered interact key guarded by `InputGate`.

- [ ] **Step 6: Commit**

```bash
git add src/game/phaser/interactionIntent.ts tests/game/interactionIntent.test.ts src/game/phaser/ProofScene.ts
git commit -m "feat: render and target village residents"
```

---

## Task 5: Add One Focused Dialogue/Gift Panel

**Files:**

- Create: `src/components/DialoguePanel.svelte`
- Modify: `src/App.svelte`
- Modify: `src/components/Overlay.svelte`
- Modify: `src/app.css`

**Ownership:**

- App owns whether social presentation is open and the `dialogue-panel` InputGate reason.
- DialoguePanel owns only line index, gift-selector visibility, and focus presentation.
- `GameSession` owns points, daily flags, inventory consumption, and selected dialogue payload.
- `Overlay` remains HUD/economy/day-summary UI.

- [ ] **Step 1: Make App understand the typed intent and social panel state**

Replace the old string assumptions in `handleInteractIntent` with a switch on `intent.kind`.

Preserve sleep and economy behavior. For `villager`:

1. refuse opening if a day transition, economy panel, or dialogue panel is already active;
2. require current `commands`;
3. call `commands.talkTo(intent.villagerId)`;
4. if it returns social success, store `{ villagerId, social }` and set `inputGate.set('dialogue-panel', true)`.

Add one `closeDialoguePanel()` that clears both state and gate reason. Reset/unmount must clear it idempotently alongside existing reasons.

For gifting, add one App callback that calls `commands.giftCrop(currentVillager, crop)` and replaces the current social payload only on social success. Failure remains in the existing `commandResult` channel and must not close the panel.

Do not cache or recalculate relationship points in App.

- [ ] **Step 2: Create `DialoguePanel.svelte`**

Required props should be feature-specific and small: open panel state/social payload, current `GameSnapshot`, `onGift(crop)`, and `onClose()`.

Presentation requirements:

- `role="dialog"`, `aria-modal="true"`, labelled by villager name;
- simple portrait placeholder with name initial/role;
- relationship level text;
- show exactly one `social.lines[index]` at a time;
- if more lines remain, render native `Continue` and focus it;
- after the final line, render `Give gift` and `Close`;
- gift selector lists only `CROP_KINDS` with carried count > 0;
- each gift button clearly names the crop and means exactly one item;
- if no harvested crops are carried, show `No harvested crops to give` and keep gift action unavailable;
- after a successful gift payload, reset line index to zero and show its response/relationship feedback;
- show feedback from payload fields (`pointsGained`, favourite/normal, resulting level) without recomputing rules;
- optional Escape handling is local and only closes; it must not implement Enter/Space progression.

Do not reuse `QuantityStepper.svelte`: gifts are exactly one item.

- [ ] **Step 3: Keep Overlay changes mechanical**

Extend `commandResultMessage()` only for:

- `villager-talked`;
- `crop-gifted`;
- `not-at-villager`; and
- `gift-already-given`.

Do not move dialogue state or relationship math into Overlay.

- [ ] **Step 4: Add focused stage CSS**

In `app.css` add `[data-dialogue-panel]` as a 640×360 absolute stage overlay with z-index above the HUD and use the existing modal visual language. Add only feature-specific layout for portrait/text/actions/gift choices.

Do not redesign the HUD/economy panel in this task.

- [ ] **Step 5: Run Svelte/static checks and existing browser smoke**

```bash
bun run check
bun run lint
bun run format:check
bun run build
bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts tests/e2e/economy.pw.ts
```

The existing sleep/economy dialogs must still lock and unlock input correctly after the App state changes.

- [ ] **Step 6: Commit**

```bash
git add src/App.svelte src/components/DialoguePanel.svelte src/components/Overlay.svelte src/app.css
git commit -m "feat: add villager dialogue and gifting UI"
```

---

## Task 6: Prove Physical Village Behavior and the Full Social Loop in the Browser

**Files:**

- Create: `tests/e2e/social.pw.ts`
- Modify: `tests/e2e/world.pw.ts`

Do not widen `window.__PHOENIX_TEST__`; use only `snapshot()`, `gameSnapshot()`, and `remount()` already exposed.

- [ ] **Step 1: Add physical villager proof to `world.pw.ts`**

Use real movement helpers to prove at least one representative villager footprint behaves like existing tree/shipping collision:

- player cannot enter the 0.4×0.4 logical footprint;
- the villager target cell remains acquireable from an adjacent position;
- player/villager depth ordering reverses on opposite sides of that villager's footpoint;
- camera stays within bounds.

Also route to all three target cells once. Keep this test about world geometry, not relationship mutation.

- [ ] **Step 2: Create the social E2E journey with local route helpers**

Create `tests/e2e/social.pw.ts`. Prefer small helpers local to the social journey rather than moving the mature economy test's route library unless a helper is truly shared by three or more suites.

The journey starts from a real new session and performs this bounded scenario:

1. visit the seed shop and buy two extra Turnip seeds, leaving enough starter money;
2. prepare five farm cells with real Hoe/Seeds controls;
3. grow those five Turnips through normal sleep/watering transitions and harvest them;
4. walk to June at cell 9,5;
5. press `E` and verify dialogue opens, world is locked, relationship becomes 1, and level is Stranger;
6. close/reopen the same day and verify repeated talk does not add a second point;
7. give one Turnip and verify carried Turnips decrement by exactly one and June gains +5;
8. attempt a second gift that day and verify inventory/points are unchanged;
9. sleep/start the next day and verify June's daily flags are false again;
10. repeat one talk + one favourite gift across five social days total, reaching at least 30 points by Day 9 or earlier;
11. verify Friend appears after crossing 12 and Close Friend after crossing 30;
12. after reaching Close Friend, reopen June to trigger the two-line one-time sequence;
13. with `Continue` focused, press Enter once and assert the second line is visible and the dialog has **not** skipped directly to the final actions;
14. finish/close, reopen again, and assert June now uses only her normal Close Friend line;
15. JSON-round-trip the observed `GameSnapshot` in the page context and compare it to the source snapshot.

Use `expect.poll` on authoritative snapshots rather than arbitrary sleeps. Release every held key in `finally`.

- [ ] **Step 3: Run focused browser tests with retries unchanged**

```bash
bun run test:e2e -- tests/e2e/world.pw.ts tests/e2e/social.pw.ts
```

If a route is flaky, fix the authored route/helper. Do not increase retries, global timeout, or add a mutation/teleport hook.

- [ ] **Step 4: Run the full browser suite**

```bash
bun run test:e2e
```

Expected: farming, economy, lifecycle, sleep, world, and social suites all pass with the existing Playwright configuration.

- [ ] **Step 5: Commit**

```bash
git add tests/e2e/social.pw.ts tests/e2e/world.pw.ts
git commit -m "test: prove the village social loop"
```

---

## Task 7: Documentation, Full CI Parity, Native Boundary, and Self-Review

**Files:**

- Modify: `README.md`
- Verify all HPA-595 files above

- [ ] **Step 1: Update README minimally**

Document only player-visible controls/behavior introduced by HPA-595:

- walk the compact village path;
- `E` on a villager talks;
- dialogue panel can give one harvested crop;
- relationship level changes through repeat days.

Do not document future market/persistence systems as implemented.

- [ ] **Step 2: Run deterministic asset/clean-checkout verification**

```bash
bun run assets:generate
bun run verify:clean
```

If `verify:clean` reports a generated-fixture mismatch, fix generator/source ownership rather than hand-editing the PNG/JSON output.

- [ ] **Step 3: Run the same frontend/unit gates as CI**

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

All must pass. Do not lower coverage thresholds to land the feature.

- [ ] **Step 4: Run the existing macOS native build when on macOS**

```bash
bun run tauri:build -- --no-sign
```

This is a packaging/build boundary only; HPA-595 adds no Rust command. If a GUI environment is available, launch the unsigned app and do one bounded manual smoke: walk to one villager, open dialogue, close it, and confirm movement resumes. Record any environment limitation accurately instead of adding native-only test code.

- [ ] **Step 5: Perform scope/architecture self-review**

Before finalizing implementation, inspect the full diff and explicitly verify:

- map is still 12×12;
- no dependency/lockfile change;
- no `dailyRhythm` social cost work;
- no mutable social state exists in Phaser/Svelte;
- no NPC/schedule/dialogue/event framework was introduced;
- test hook remains observation-only;
- market reserve x 8–10/y 2–3 remains empty;
- HPA-597 harvest-market content is absent;
- HPA-596 persistence is absent;
- successful gift consumes exactly one crop;
- successful sleep is the only daily social reset seam;
- snapshots remain plain/fresh/JSON-safe.

Run:

```bash
git diff --check
```

- [ ] **Step 6: Commit final docs if needed**

```bash
git add README.md
git commit -m "docs: describe the social slice controls"
```

If README required no change after review, do not create an empty commit.

## Expected Implementation Commit Shape

The recommended implementation history is intentionally small and reviewable:

1. `feat: define social relationship policy`
2. `feat: add authoritative social progression`
3. `feat: author the compact village`
4. `feat: render and target village residents`
5. `feat: add villager dialogue and gifting UI`
6. `test: prove the village social loop`
7. optional `docs: describe the social slice controls`

No merge commit is required; rebase/squash policy can be chosen when the implementation PR is ready.

## Completion Criteria

HPA-595 is implementation-complete only when all Linear acceptance criteria are demonstrated against the real controls and the final state is ready for HPA-596:

- all three villagers are walkable/interactable with correct collision/depth;
- talk points are once/day per villager;
- gifting consumes exactly one crop, with normal/favourite points and once/day limit;
- Stranger/Friend/Close Friend dialogue is visible at exact thresholds;
- each one-time Close Friend sequence triggers once;
- a normal 14-day run can reach at least one Close Friend;
- dialogue locks Phaser input and one Enter press advances one line;
- social state is fresh plain JSON;
- browser suite is green;
- current unsigned macOS build remains green;
- no persistence/finale/framework work leaked into the slice.
