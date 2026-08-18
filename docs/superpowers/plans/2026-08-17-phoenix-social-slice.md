# Phoenix Social Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use TDD for pure policy/domain/parser work and keep every task type-green before moving on.

**Goal:** Deliver HPA-595 as one compact village/social slice with three static villagers, daily talk, exactly-one-crop gifting, favourite bonuses, Stranger/Friend/Close Friend progression, one-time Close Friend dialogue, and real browser/Tauri proof without introducing an NPC/dialogue framework.

**Architecture:** `villagerDefinitions.ts` owns immutable villager content and pure relationship policy. The existing 12×12 authored map owns exact villager cells/footprints; `GameSession` consumes and republishes those cells and remains the only mutable social authority. Phaser renders/targets static villagers through the existing depth/input seams. Svelte owns one focused `DialoguePanel` plus a complete UI lock. Acceptance reuses one shared weather-aware watering helper rather than copying random-weather branching a third time.

**Tech Stack:** Bun 1.3.1 and `bun:test`, Svelte 5.56.8, Phaser 4.2.1, Playwright 1.62.1, Vite 8.2.1, Tauri 2.11.4, deterministic Bun asset generation, existing Rust 1.96 macOS boundary.

**Spec:** `docs/superpowers/specs/2026-08-17-phoenix-social-slice-design.md`

## Global constraints

- Implement only HPA-595. Do not start HPA-596 persistence or HPA-597 harvest-market behavior.
- Keep the map 12×12, projection 64×32, origin `(384, 0)`, logical stage 640×360, current camera behavior, and one walkable elevation.
- Villagers are exactly: Mira/shopkeeper/Potato at 6,5; Rowan/farmer/Pumpkin at 3,5; June/resident/Turnip at 9,5.
- Exact path cells are y=6, x=3 through 9.
- Exact footprints are 0.6×0.6: Mira 6.2/5.2; Rowan 3.2/5.2; June 9.2/5.2.
- Exact target stances: Mira from 5,6 facing right; Rowan from 4,6 facing up; June from 8,6 facing right.
- Relationship floors are 0 Stranger, 12 Friend, 18 Close Friend. First talk/day +1. First gift/day +3. Favourite bonus +2.
- Talking/gifting consume no time or stamina. Do not modify `dailyRhythm.ts` for social costs.
- `GameSession` is the only mutable social authority. Store points, `talkedToday`, `giftedToday`, `closeFriendDialogueSeen`; derive level.
- `GameSnapshot` includes both `relationships` and cloned `villagerCells` plain records.
- `SocialFeedback` contains only `lines`, `pointsGained`, `giftReaction`, `closeFriendSequence`.
- Social domain/scene methods use narrow `TalkResult`/`GiftResult` return types; keep the existing broad `CommandResult` for common publication/UI feedback.
- Repeated talk succeeds with 0 points. Repeated/invalid gift fails before inventory/points mutation.
- Successful `sleep()` is the only daily social reset seam.
- `InputGate.ts` remains unchanged. App uses the arbitrary reason `dialogue-panel`.
- Dialogue must also disable Overlay action/seed buttons and the manual world-lock toggle; Phaser locking alone is incomplete.
- Do not add window-level dialogue key listeners. Preserve `lifecycle.pw.ts`'s exact `{ keydown: 1, keyup: 1 }` census.
- Keep `window.__PHOENIX_TEST__` observation-only. No teleport, state injection, social setter, direct command hook, or weather hook.
- Use native `Continue` activation; dialog-scoped Escape may close.
- Add no dependency/package version change.
- Keep existing Playwright retries/timeouts. Fix helpers/geometry instead of masking flakes.
- Every planned commit must pass `bun run check`; do not add compatibility aliases or fallback villager cells.

## File map

### Pure social content

- Create `src/game/core/villagerDefinitions.ts`
- Create `tests/game/villagerDefinitions.test.ts`
- Modify `src/game/core/types.ts`

### Authored village assets/parser

- Modify `tools/generate-proof-assets.ts`
- Modify generated `src/assets/sprites/proof-tiles.png`
- Create generated `src/assets/sprites/proof-villagers.png`
- Modify generated `src/assets/maps/proof-map.json`
- Modify `src/game/phaser/loadProofMap.ts`
- Modify `tests/game/loadProofMap.test.ts`

### Authoritative social state

- Modify `src/game/core/types.ts`
- Modify `src/game/core/GameSession.ts`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/components/Overlay.svelte`
- Modify `tests/game/GameSession.test.ts`

### Phaser rendering/interaction bridge

- Modify `src/game/phaser/interactionIntent.ts`
- Modify `tests/game/interactionIntent.test.ts`
- Modify `src/game/phaser/ProofScene.ts`
- Modify `src/App.svelte`

### Dialogue presentation

- Create `src/components/DialoguePanel.svelte`
- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`
- Modify `src/app.css`

### Browser acceptance reuse/proof

- Modify `tests/e2e/helpers.ts`
- Modify `tests/e2e/farming.pw.ts`
- Modify `tests/e2e/economy.pw.ts`
- Modify `tests/e2e/world.pw.ts`
- Create `tests/e2e/social.pw.ts`

### Handoff

- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

No planned changes: `package.json`, `bun.lock`, `src-tauri/**`, `.github/workflows/ci.yml`, `playwright.config.ts`, `src/vite-env.d.ts`, `src/game/core/InputGate.ts`, `src/game/core/dailyRhythm.ts`, `src/components/GameHost.svelte`, `tests/e2e/lifecycle.pw.ts`.

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
  lines: string[];
  pointsGained: number;
  giftReaction: 'normal' | 'favourite' | null;
  closeFriendSequence: boolean;
}
```

- [ ] **Step 1: Write definition/policy RED**

Create `tests/game/villagerDefinitions.test.ts` covering:

1. exact `VILLAGER_IDS` order;
2. exact names/favourites;
3. talk 1 / gift 3 / favourite bonus 2;
4. relationship boundaries 0–11 Stranger, 12–17 Friend, 18+ Close Friend;
5. negative/fractional/NaN/unsafe points throw;
6. exact normal dialogue for every villager/level;
7. exact two-line Close Friend sequences;
8. fresh returned arrays.

Run:

```bash
bun test tests/game/villagerDefinitions.test.ts
```

Expected RED: module/types missing.

- [ ] **Step 2: Add only additive social types**

Add the closed unions/interfaces above. Do not modify `GameSnapshot`, command result codes, or `GameSessionConfig` yet.

- [ ] **Step 3: Implement `villagerDefinitions.ts`**

Use exact copy from the design spec. Export:

```ts
export const VILLAGER_IDS = ['shopkeeper', 'farmer', 'resident'] as const;
export const TALK_POINTS = 1;
export const GIFT_POINTS = 3;
export const FAVOURITE_GIFT_BONUS = 2;
export function relationshipLevel(points: number): RelationshipLevel;
export function dialogueLines(id: VillagerId, level: RelationshipLevel): string[];
export function closeFriendDialogueLines(id: VillagerId): string[];
```

No class, registry, coordinates, callback, event bus, schedule, or localization layer.

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

## Task 2: Author the compact village assets and exact parser contract

This task is deliberately generator/map/parser/fixture only. Mira at 6,5 avoids the existing tree-detour route, so no existing E2E route rewrite belongs in this atomic GID/marker migration.

**Files**

- Modify `tools/generate-proof-assets.ts`
- Modify generated `src/assets/sprites/proof-tiles.png`
- Create generated `src/assets/sprites/proof-villagers.png`
- Modify generated `src/assets/maps/proof-map.json`
- Modify `src/game/phaser/loadProofMap.ts`
- Modify `tests/game/loadProofMap.test.ts`

**Exact authored contract**

- 12×12, four layers, `nextlayerid: 5`, `nextobjectid: 17`.
- `proof-tiles.png`: 192×32; GIDs grass 1, farm 2, path 3.
- Path cells only `3,6 4,6 5,6 6,6 7,6 8,6 9,6`.
- `proof-scenery.firstgid = 4`; global GIDs tree/building/shipping = 4/5/6.
- Market reserve x8–10/y2–3 remains grass/empty.
- Collision IDs: 11 shopkeeper 6.2/5.2/0.6/0.6; 12 farmer 3.2/5.2/0.6/0.6; 13 resident 9.2/5.2/0.6/0.6.
- Marker IDs: 14 shopkeeper cell6,5/world416,192; 15 farmer cell3,5/world320,144; 16 resident cell9,5/world512,240.
- `proof-villagers.png`: 96×48, one 32×48 frame per `VILLAGER_IDS` entry.

- [ ] **Step 1: Write parser/asset RED**

Update `tests/game/loadProofMap.test.ts` first to assert exact tile metadata/path cells, shifted scenery GIDs, marker placements/cells, three 0.6 villager footprints, six-footprint output order, malformed/missing/extra collision rejection, malformed/missing/duplicate/misplaced marker rejection, market reserve emptiness, and new PNG dimensions.

```bash
bun test tests/game/loadProofMap.test.ts
```

Expected RED against current HPA-593 assets/parser.

- [ ] **Step 2: Extend deterministic generator**

Use existing `project()` and `logicalPolygon()`. Add the third ground frame/path cells, shift scenery global GIDs, add the 96×48 villager sheet, add objects 11–16, set `nextobjectid: 17`, and write the new PNG.

```bash
bun run assets:generate
```

- [ ] **Step 3: Replace the collision-count assumption**

Keep scenery parsing limited to tree/building/shipping-bin. Add a separate villager-footprint contract.

`parseCollision` validates exactly six supported collision objects and returns:

```ts
[
  treeFootprint,
  buildingFootprint,
  shippingFootprint,
  shopkeeperFootprint,
  farmerFootprint,
  residentFootprint,
]
```

The final three follow `VILLAGER_IDS`. Remove the current `footprints.length === scenery.length` assumption and `scenery.map(...)` return.

- [ ] **Step 4: Table-drive integer-cell markers, keep spawn special**

Keep `player-spawn` validation separate because it is an authored half-cell point. Add:

```ts
const cellMarkerContract = {
  'bed-interaction': { objectId: 6, cell: { x: 6, y: 8 } },
  'shop-counter': { objectId: 9, cell: { x: 6, y: 7 } },
  'shipping-bin': { objectId: 10, cell: { x: 6, y: 10 } },
  'villager-shopkeeper': { objectId: 14, cell: { x: 6, y: 5 } },
  'villager-farmer': { objectId: 15, cell: { x: 3, y: 5 } },
  'villager-resident': { objectId: 16, cell: { x: 9, y: 5 } },
} as const;
```

Use one loop for existence, ID, common point metadata, and exact `gridCellAtWorld` equality. Derive the allowed integer-cell marker names from this table; do not build a generic Tiled schema system.

Return `villagers` and `villagerCells` from `ParsedProofMap`.

- [ ] **Step 5: Verify GREEN/determinism**

```bash
bun run assets:generate
bun test tests/game/loadProofMap.test.ts
bun run check
bun run lint
bun run assets:generate
```

The second generator run must leave generated bytes unchanged.

- [ ] **Step 6: Commit**

```bash
git add tools/generate-proof-assets.ts src/assets/maps/proof-map.json src/assets/sprites/proof-tiles.png src/assets/sprites/proof-villagers.png src/game/phaser/loadProofMap.ts tests/game/loadProofMap.test.ts
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
export type TalkResult =
  | { ok: true; code: 'villager-talked'; social: SocialFeedback }
  | { ok: false; code: 'day-summary-pending' | 'not-at-villager' };

export type GiftResult =
  | { ok: true; code: 'crop-gifted'; social: SocialFeedback }
  | {
      ok: false;
      code: 'day-summary-pending' | 'not-at-villager' | 'gift-already-given' | 'insufficient-crops';
    };
```

`GameSnapshot` gains:

```ts
relationships: Record<VillagerId, RelationshipSnapshot>;
villagerCells: Record<VillagerId, GridCell>;
```

- [ ] **Step 1: Extend test config with real villager cells/targeting**

Add `villagerCells` to the test config. For direct target tests, construct a normal session with a spawn on a valid diagonal stance and call `stepMovement(..., 0)` only to set facing; never add a target setter.

- [ ] **Step 2: Write social domain RED**

Cover fresh/deep-cloned relationships and villagerCells; `not-at-villager`; first/repeated talk; normal/favourite one-crop gifts; repeated gift; no-crop gift; Friend 12; Close Friend 18; gift crossing 18 leaves special unseen; first subsequent talk returns exact two-line sequence once; later talk returns normal close line; successful sleep resets only daily flags; failed/Day14/summary-pending sleep does not reset; summary pending blocks social commands; JSON round trip; constructor in-bounds/distinct/cloning invariants.

Use existing domain farming/economy actions to obtain gift crops; no inventory injection.

```bash
bun test tests/game/GameSession.test.ts
```

Expected RED: config/snapshot/commands missing.

- [ ] **Step 3: Add narrow result/snapshot contracts and keep Overlay exhaustive**

In `types.ts` add `TalkResult`, `GiftResult`, the two social success codes, `not-at-villager`, `gift-already-given`, `relationships`, and `villagerCells`.

Keep broad `CommandResult` for common publication. `SocialFeedback` stays the four-field shape from Task 1.

In the same step add the mechanical `commandResultMessage()` labels for:

- `villager-talked`;
- `crop-gifted`;
- `not-at-villager`;
- `gift-already-given`.

This closes Overlay's current exhaustive `assertNever` before `bun run check`.

- [ ] **Step 4: Implement authoritative state/commands**

Clone/validate config `villagerCells`; initialize relationship state; snapshot fresh `relationships` and `villagerCells`; derive level through `relationshipLevel`; implement exact talk/gift validation order; reset daily flags only inside successful `sleep()`.

- [ ] **Step 5: Wire map cells and type-preserving scene facades**

Pass `parsed.villagerCells` into the required `GameSessionConfig` at the existing `new GameSession(...)` call.

Add `SceneCommands.talkTo: (id) => TalkResult` and `giftCrop: (id, crop) => GiftResult`.

Make publication type-preserving:

```ts
private publishCommand<T extends CommandResult>(result: T): T {
  const snapshot = this.requireSession().snapshot();
  this.reconcileFarmSprites(snapshot);
  this.dependencies.onCommandResult(result);
  this.dependencies.onGameSnapshot(snapshot);
  return result;
}
```

App will therefore never receive an impossible social success variant from a specific social command.

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

## Task 4: Render villagers and route the typed interaction intent

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

Prove exact sleep/shop/shipping object intents, all three villager intents from `snapshot.villagerCells`, and null/unrelated targets.

```bash
bun test tests/game/interactionIntent.test.ts
```

- [ ] **Step 2: Implement the closed union**

Expand `InteractionCells` with `villagerCells`. Use direct equality and stable `VILLAGER_IDS`; no registry/callback map.

- [ ] **Step 3: Render static villager sprites/depth**

Preload `proof-villagers.png` as 32×48 frames. Create one bottom-center sprite from each parsed placement. Keep a `Map<VillagerId, Sprite>`. Add `villager:${id}` to debug/depth entries with marker object ID as stable order. Destroy/clear on scene cleanup. No NPC update-loop movement.

- [ ] **Step 4: Route E using the existing snapshot bag**

Continue calling:

```ts
interactionIntentForTarget(snapshot.target, snapshot)
```

because Task 3 added `villagerCells` to `GameSnapshot`. Null publishes `nothing-to-interact`; non-null forwards the typed intent.

- [ ] **Step 5: Convert App consumer in the same task**

Replace the string assumptions, including the current economy type, with:

```ts
type EconomyPanel = Exclude<InteractionIntent['kind'], 'sleep' | 'villager'> | null;
```

Switch on `intent.kind`:

```ts
case 'sleep':
  // existing sleep state
  break;
case 'shop':
case 'shipping':
  economyPanel = intent.kind;
  syncEconomyPanel();
  break;
case 'villager':
  commands?.talkTo(intent.villagerId);
  break;
```

The villager branch publishes the authoritative result but does not open the panel until Task 5. No compatibility alias.

- [ ] **Step 6: Verify GREEN**

```bash
bun test tests/game/interactionIntent.test.ts tests/game/GameSession.test.ts tests/game/loadProofMap.test.ts
bun run check
bun run lint
```

- [ ] **Step 7: Commit**

```bash
git add src/game/phaser/interactionIntent.ts tests/game/interactionIntent.test.ts src/game/phaser/ProofScene.ts src/App.svelte
git commit -m "feat: render and route village residents"
```

---

## Task 5: Add one focused dialogue/gift panel and preserve listener census

**Files**

- Create `src/components/DialoguePanel.svelte`
- Modify `src/App.svelte`
- Modify `src/components/Overlay.svelte`
- Modify `src/app.css`

`tests/e2e/lifecycle.pw.ts` is intentionally unchanged; it is a regression oracle.

- [ ] **Step 1: Make App open authoritative social presentation**

For `intent.kind === 'villager'`, call narrow `commands.talkTo(id)`. If `!result.ok`, do not open. On success, store `{ villagerId, social: result.social }` and set `inputGate.set('dialogue-panel', true)`.

Add `closeDialoguePanel()` and a gift callback. The gift callback calls narrow `giftCrop`; on success replace only the current social feedback. Failure remains in the existing command-result channel and leaves the panel open.

Reset/unmount clears state and `dialogue-panel` idempotently.

- [ ] **Step 2: Create `DialoguePanel.svelte`**

Props include current `villagerId`, `SocialFeedback`, current `GameSnapshot`, `onGift(crop)`, and `onClose()`.

Requirements:

- `role="dialog"`, `aria-modal="true"`, label with villager name;
- portrait placeholder/name/role;
- read current points/level from `snapshot.relationships[villagerId]`;
- exactly one `social.lines[index]` visible;
- native `Continue` focused while another line remains;
- after final line render Give gift + Close;
- gift choices only for carried crop counts > 0;
- each gift means exactly one crop;
- no crops => `No harvested crops to give`;
- successful gift payload resets line index to zero and renders response/reaction/+points;
- local element-scoped Escape may close;
- **no `<svelte:window onkeydown>` and no window-level Enter/Space listener**.

Do not use `QuantityStepper.svelte`.

- [ ] **Step 3: Close the Overlay button bypass**

Pass:

```svelte
<Overlay ... dialogueOpen={dialoguePanel !== null} />
```

Add `dialogueOpen` to Overlay props and require `!dialogueOpen` in `actionsReady`. Also refuse/disable the manual Lock/Unlock world-input toggle while dialogue is open.

Do not modify `InputGate.ts`.

- [ ] **Step 4: Add stage-local CSS**

Add one 640×360 dialogue layer above the HUD using the existing modal visual language. No HUD/economy redesign.

- [ ] **Step 5: Verify UI, sleep/economy, and listener census**

```bash
bun run check
bun run lint
bun run format:check
bun run build
bun run test:e2e -- tests/e2e/sleep-confirmation.pw.ts tests/e2e/economy.pw.ts tests/e2e/lifecycle.pw.ts
```

`lifecycle.pw.ts` must remain unchanged and continue observing exactly one keydown and one keyup window listener before/after HMR.

- [ ] **Step 6: Commit**

```bash
git add src/App.svelte src/components/DialoguePanel.svelte src/components/Overlay.svelte src/app.css
git commit -m "feat: add villager dialogue and gifting UI"
```

---

## Task 6: Reuse weather-aware watering and prove the complete browser social loop

**Files**

- Modify `tests/e2e/helpers.ts`
- Modify `tests/e2e/farming.pw.ts`
- Modify `tests/e2e/economy.pw.ts`
- Modify `tests/e2e/world.pw.ts`
- Create `tests/e2e/social.pw.ts`

- [ ] **Step 1: Promote the existing random-weather branch once**

Add to `tests/e2e/helpers.ts`:

```ts
export async function waterForCurrentWeather(
  page: Page,
  targetKey: string,
  targetCell: GridCell,
): Promise<GameSnapshot> {
  await acquireTarget(page, targetKey, targetCell);
  const before = await gameSnapshot(page);
  const feedback = before.weather === 'sunny'
    ? 'Crop watered'
    : 'Rain is watering the crops';

  await page.keyboard.down('Space');
  try {
    await expect(page.locator('[data-feedback]')).toHaveText(feedback);
  } finally {
    await page.keyboard.up('Space');
  }

  const after = await gameSnapshot(page);
  if (before.weather === 'sunny') {
    expect(after.timeMinutes).toBe(before.timeMinutes + 20);
    expect(after.stamina).toBe(before.stamina - 2);
  } else {
    expect(after).toEqual(before);
  }
  return after;
}
```

Refactor `farming.pw.ts` to delete its local `waterForCurrentWeather` and use the shared helper. Refactor the economy loop to replace its inline sunny/rain feedback branch with the same helper.

Do not change weather probabilities or inject weather into tests.

- [ ] **Step 2: Add physical villager proof to `world.pw.ts` without route rewrites**

Mira at 6,5 must not require changing existing route helpers. Add focused checks that:

- existing tree/building/shop/shipping/farm tests remain unchanged and green;
- all three `snapshot.villagerCells` equal the authored cells;
- each documented path stance acquires the corresponding villager cell;
- one representative 0.6 villager footprint blocks entry;
- player/villager depth order reverses on opposite sides of that footpoint;
- camera remains bounded.

Keep geometry proof out of relationship mutation.

- [ ] **Step 3: Create the shortest no-hook social setup**

Use only the three starter Turnip seeds; do not visit the shop merely to lengthen acceptance.

Day 1:

1. hoe three farm cells;
2. plant all three starter Turnips;
3. select Water;
4. call shared `waterForCurrentWeather` on each crop;
5. sleep/start Day 2.

Worst-case sunny stamina is 3 hoes ×3 + 3 plants ×1 + 3 waters ×2 = 18, so the setup fits Day 1. On rain, watering is rejected without mutation and sleep still advances growth.

Repeat weather-aware watering on Day 2 and Day 3. Day 4 morning must have three mature Turnips; harvest all three through real controls.

- [ ] **Step 4: Prove three social days with June**

At June, use the authored stance 8,6 facing right before `E`.

Social Day 1:

- open dialogue; world locked; HUD action/seed/toggle disabled;
- first talk gives +1 and Stranger;
- close/reopen same day gives +0;
- give one Turnip: inventory -1, +5 favourite points, total 6;
- second same-day gift attempt leaves inventory/points unchanged;
- sleep/start next day; daily flags false.

Social Day 2:

- talk + favourite gift => total 12, Friend;
- sleep/start next day.

Social Day 3:

- talk + favourite gift => total 18, Close Friend;
- the threshold-crossing gift leaves `closeFriendDialogueSeen` false;
- close/reopen same day: exact two-line Close Friend sequence appears and sets the flag;
- with Continue focused, one Enter displays line two and does not skip to final actions;
- close/reopen again: only normal Close Friend line appears.

Finally JSON-round-trip the observed `GameSnapshot` and assert `villagerCells` plus relationships survive exactly.

Use `expect.poll`; release every held key in `finally`; do not widen the test hook.

- [ ] **Step 5: Run focused and full E2E**

```bash
bun run test:e2e -- tests/e2e/farming.pw.ts tests/e2e/economy.pw.ts tests/e2e/world.pw.ts tests/e2e/social.pw.ts
bun run test:e2e
```

If routes are flaky, fix helpers/waypoints. Do not increase retries/global timeout or add arbitrary sleeps/state hooks.

- [ ] **Step 6: Commit**

```bash
git add tests/e2e/helpers.ts tests/e2e/farming.pw.ts tests/e2e/economy.pw.ts tests/e2e/world.pw.ts tests/e2e/social.pw.ts
git commit -m "test: prove the village social loop"
```

---

## Task 7: Pin player-facing handoff facts and run full delivery verification

**Files**

- Modify `README.md`
- Modify `tests/config/handoff.test.ts`

- [ ] **Step 1: Update README minimally**

Include these exact stable player-facing phrases:

- `HPA-595`
- `E on a villager talks`
- `one harvested crop`
- `Friend at 12`
- `Close Friend at 18`

Do **not** pin villager cells in README; generator/parser/world tests own placement.

- [ ] **Step 2: Extend handoff test with the same five facts**

Add next to the existing HPA-592/HPA-593 loops:

```ts
for (const socialText of [
  'HPA-595',
  'E on a villager talks',
  'one harvested crop',
  'Friend at 12',
  'Close Friend at 18',
]) {
  expect(readme.toLowerCase()).toContain(socialText.toLowerCase());
}
```

- [ ] **Step 3: Run deterministic/clean-checkout verification**

```bash
bun run assets:generate
bun run verify:clean
```

Fix generator/source ownership if generated output changes; do not hand-edit generated assets.

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

- [ ] **Step 5: Run macOS native build when on macOS**

```bash
bun run tauri:build -- --no-sign
```

If GUI access exists, manually smoke one villager dialogue open/close and verify movement resumes. Report environment limitations rather than adding native-only social code.

- [ ] **Step 6: Self-review exact scope**

Verify:

- map still 12×12;
- no dependency/lockfile change;
- no InputGate implementation change;
- no `dailyRhythm` social-cost work;
- `lifecycle.pw.ts` unchanged and listener census still green;
- no mutable social state in Phaser/Svelte;
- exact 0.6 footprints and path stances;
- Mira is 6,5 and existing routes did not need rewriting;
- `parseCollision` returns six footprints in defined order;
- integer-cell marker parsing uses one contract table while spawn remains special;
- `GameSnapshot` includes fresh `relationships` and `villagerCells`;
- `SocialFeedback` contains only non-derivable command feedback;
- narrow social scene returns preserved through generic `publishCommand`;
- Overlay controls disabled during dialogue;
- shared weather helper used by farming/economy/social;
- test hook observation-only;
- market reserve empty;
- HPA-596/HPA-597 behavior absent;
- gift consumes exactly one crop;
- successful sleep is the only daily reset seam;
- README pins only five player-facing HPA-595 facts.

```bash
git diff --check
```

- [ ] **Step 7: Commit**

```bash
git add README.md tests/config/handoff.test.ts
git commit -m "docs: pin the social slice handoff"
```

## Primary implementation risks

1. **Random weather:** the social setup must use the shared weather-aware watering helper; no sunny-day assumptions.
2. **Window listener count:** DialoguePanel must use element-scoped key handling and leave `lifecycle.pw.ts` unchanged/green.
3. **Ground/scenery GID shift:** generator, generated fixtures, parser, and parser tests land atomically in Task 2.
4. **Modal bypass:** `dialogueOpen` disables Overlay button/toggle paths while InputGate blocks Phaser.
5. **No-hook journey:** Close Friend 18 reduces social acceptance to three cycles; keep retries/timeouts unchanged.

## Recommended implementation commit shape

1. `feat: define social relationship policy`
2. `feat: author the compact village`
3. `feat: add authoritative social progression`
4. `feat: render and route village residents`
5. `feat: add villager dialogue and gifting UI`
6. `test: prove the village social loop`
7. `docs: pin the social slice handoff`

No merge commit is required.

## Completion criteria

HPA-595 is complete only when:

- all three villagers are visible, collision-safe, targetable from documented path stances, and depth-sorted;
- talk credit is once/day and repeated talk still returns dialogue;
- gift consumes exactly one crop, awards normal/favourite points, and is once/day;
- Stranger/Friend/Close Friend use 0/12/18 thresholds;
- one Close Friend sequence triggers once per villager;
- June reaches Close Friend through the real three-social-day journey;
- random rainy days do not make the setup nondeterministic;
- one Enter on focused Continue advances one line;
- dialogue locks Phaser plus Overlay action/seed/toggle controls;
- window listener census remains unchanged;
- snapshot state including `villagerCells` is fresh plain JSON;
- README/handoff pins only stable player-facing facts;
- current static/unit/coverage/E2E/build gates pass;
- unsigned macOS Tauri build remains green;
- no persistence/finale/NPC/dialogue framework work leaks into the slice.
