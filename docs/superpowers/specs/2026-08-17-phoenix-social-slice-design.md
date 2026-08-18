# Phoenix Social Slice Design (HPA-595)

**Status:** Draft for review — revised after repository contract review

**Date:** 2026-08-17

**Delivery target:** macOS-first browser and Tauri social slice

## Source of truth

This design implements [HPA-595](https://linear.app/cwchanap/issue/HPA-595/social-slice-add-the-village-three-villagers-gifting-and-relationships), the next active Phoenix vertical slice after HPA-593. HPA-595 blocks HPA-596 persistence, so social state must stay authoritative, deterministic, fresh, and plain-JSON serializable.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves implementation details against the current `main` code.

## Outcome

Phoenix keeps the existing 12×12 isometric world and adds one short village path in the unused northern area. Three static villagers stand immediately north of that path. The player walks to a documented stance, presses the existing `E` interaction key, talks once per day for relationship credit, gives exactly one harvested crop per villager per day, receives a favourite-crop bonus, and sees dialogue progress through Stranger, Friend, and Close Friend.

Each villager has one two-line Close Friend sequence shown once through one focused Svelte dialogue panel. Villagers never move. There are no schedules, homes, pathfinding, quests, cutscene machinery, or generalized NPC/dialogue abstractions.

## Approved lean shape

- Keep the map, projection, camera, logical stage, and one-elevation renderer unchanged.
- Add exactly one static content/policy module, `villagerDefinitions.ts`, as a sibling of `cropDefinitions.ts`.
- Keep `GameSession` as the only mutable social authority.
- Add only `talkTo(villagerId)` and `giftCrop(villagerId, crop)`.
- Keep social result payloads narrow; do not replace the current command-result model with a generic envelope.
- Talking and gifting cost no time or stamina in HPA-595.
- Daily talk/gift flags reset only in the existing successful `sleep()` transaction.
- Keep the development hook observation-only.
- Use one dedicated `DialoguePanel.svelte`; do not reuse the quantity stepper or build a dialogue engine.
- Keep persistence, the harvest-market finale, schedules, romance, and additional villagers outside this slice.

## Villager placement and targeting

Villager IDs are role IDs; display names are content.

| Villager ID | Name | Role | Favourite crop | Cell | Valid path stance |
| --- | --- | --- | --- | --- | --- |
| `shopkeeper` | Mira | Seed-shop keeper | Potato | 6,5 | stand in 5,6 and face right |
| `farmer` | Rowan | Neighbouring farmer | Pumpkin | 3,5 | stand in 4,6 and face up |
| `resident` | June | Village resident | Turnip | 9,5 | stand in 8,6 and face right |

These stances match the shipped `ProofWorld` facing offsets exactly: right targets `{ +1, -1 }`; up targets `{ -1, -1 }` after flooring the player position.

Mira deliberately uses 6,5 instead of 7,5. With a 0.6×0.6 footprint at 7,5, Mira and the existing tree footprint form an impractically narrow centerline gap and obstruct the current tree-detour route. Moving Mira one cell west avoids that route entirely while leaving her adjacent to the shop approach.

Exact villager footpoints and footprints are:

| Villager | Footpoint world | Footprint |
| --- | --- | --- |
| Mira | 416,192 | x 6.2, y 5.2, w 0.6, h 0.6 |
| Rowan | 320,144 | x 3.2, y 5.2, w 0.6, h 0.6 |
| June | 512,240 | x 9.2, y 5.2, w 0.6, h 0.6 |

The 0.6 footprint scale intentionally reuses the already-shipped tree/shipping-bin convention rather than introducing a new 0.4 collision size.

## Relationship policy

Exact level floors and gains:

| Rule | Value |
| --- | ---: |
| Stranger floor | 0 |
| Friend floor | 12 |
| Close Friend floor | 18 |
| First successful talk per villager/day | +1 |
| First normal gift per villager/day | +3 |
| Favourite gift bonus | +2 |

Close Friend at 18 is deliberate. The previous 30-point value was not required by Linear or another product contract; it only lengthened the no-hook acceptance journey. At 18, a favourite talk+gift routine reaches Close Friend in three social days while still exercising all three levels. A normal talk+gift routine reaches it in five days, still comfortably inside the 14-day arc.

There is no cap, decay, dislike penalty, birthday multiplier, randomness, or hidden modifier.

### Exact dialogue content

`VILLAGER_DEFINITIONS` contains these strings.

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

## Pure villager definitions

Create `src/game/core/villagerDefinitions.ts` with only static records, constants, and pure helpers:

```ts
VILLAGER_IDS;
VILLAGER_DEFINITIONS;
RELATIONSHIP_THRESHOLDS;
TALK_POINTS;
GIFT_POINTS;
FAVOURITE_GIFT_BONUS;
relationshipLevel(points);
dialogueLines(villagerId, level);
closeFriendDialogueLines(villagerId);
```

`VILLAGER_IDS` is exactly `['shopkeeper', 'farmer', 'resident']`. Helpers validate programmer inputs, return fresh arrays, and throw for invalid point values. The module contains no coordinates, mutable state, Phaser/Svelte objects, callbacks, schedules, persistence code, or event dispatch.

## Shared social types and result shapes

Add:

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

`SocialFeedback` intentionally excludes `villagerId`, current points, and current level. App already knows the villager ID, and the same synchronous `publishCommand` call publishes the post-command `GameSnapshot`; points and level are therefore read from `snapshot.relationships[id]`. `lines`, `pointsGained`, gift reaction, and the one-shot sequence flag are the non-derivable command feedback.

`GameSnapshot` gains both mutable social state and the same kind of static interaction-cell echo already used for bed/shop/shipping:

```ts
relationships: Record<VillagerId, RelationshipSnapshot>;
villagerCells: Record<VillagerId, GridCell>;
```

`villagerCells` is cloned plain data. Keeping it in the snapshot lets the session-validated interaction cells remain the single bag used by `interactionIntentForTarget(snapshot.target, snapshot)` and makes authored placement observable in E2E without another source of truth.

Panel line index, dialogue definitions, portraits, and Phaser/Svelte objects remain outside `GameSnapshot`.

Keep the broad cross-app `CommandResult`, but give social domain/scene methods narrow return types:

```ts
type TalkResult =
  | { ok: true; code: 'villager-talked'; social: SocialFeedback }
  | { ok: false; code: 'day-summary-pending' | 'not-at-villager' };

type GiftResult =
  | { ok: true; code: 'crop-gifted'; social: SocialFeedback }
  | {
      ok: false;
      code: 'day-summary-pending' | 'not-at-villager' | 'gift-already-given' | 'insufficient-crops';
    };
```

`SceneCommands.talkTo` returns `TalkResult`; `giftCrop` returns `GiftResult`. `ProofScene.publishCommand` becomes type-preserving (`<T extends CommandResult>(result: T): T`) so App does not branch on impossible social success cases.

## GameSession authority

`GameSessionConfig` gains:

```ts
villagerCells: Record<VillagerId, GridCell>;
```

Construction clones it and validates each cell is integer/in-bounds, all three are distinct, and they do not alias farm/bed/shop/shipping interaction cells.

Mutable social state is exactly:

```ts
Record<VillagerId, {
  points: number;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}>;
```

Relationship level is derived from points for snapshots; it is not stored redundantly.

### `talkTo`

1. Apply `activeDayFailure()`.
2. Require authoritative target to equal the requested `villagerCells[id]`.
3. On the first talk that day, set `talkedToday` and add one point.
4. Derive resulting relationship level.
5. If level is Close Friend and the one-time sequence has not been seen, set the flag and return the two-line sequence.
6. Otherwise return the normal line for the resulting level.

Repeated same-day talk remains successful with `pointsGained: 0`.

### `giftCrop`

1. Apply `activeDayFailure()`.
2. Require target to equal requested villager cell.
3. Reject `gift-already-given`.
4. Reject `insufficient-crops` before mutation.
5. Consume exactly one crop.
6. Set `giftedToday`.
7. Add +3, plus +2 for the favourite crop.
8. Return one static gift-response line with `pointsGained` and reaction.

A gift that crosses the Close Friend floor does not consume the one-time Close Friend dialogue. The next talk does.

### Daily reset

Only successful `sleep()` clears every `talkedToday` and `giftedToday`. Points and `closeFriendDialogueSeen` persist. Failed sleep, Day 14 rejection, and duplicate summary-pending sleep do not reset social state.

## Authored map contract

Keep 12×12, 64×32 2:1 projection, origin `(384, 0)`, four existing layers, and `nextlayerid: 5`.

### Ground tiles

Expand `proof-tiles.png` from 128×32 to 192×32:

1. GID 1 grass;
2. GID 2 farm soil;
3. GID 3 village path.

`proof-ground`: `columns: 3`, `tilecount: 3`, `imagewidth: 192`.

The new ground GID shifts `proof-scenery.firstgid` from 3 to 4; existing global scenery GIDs become tree 4, building 5, shipping bin 6.

The exact path is only:

```text
3,6  4,6  5,6  6,6  7,6  8,6  9,6
```

The HPA-597 market reserve remains x 8–10, y 2–3: grass, walkable, and free of new markers/collision/scenery.

### Collision and marker IDs

Keep object IDs 1–10. Add:

| ID | Layer | Name | Contract |
| ---: | --- | --- | --- |
| 11 | Collision | `villager-shopkeeper` | x6.2/y5.2/w0.6/h0.6 |
| 12 | Collision | `villager-farmer` | x3.2/y5.2/w0.6/h0.6 |
| 13 | Collision | `villager-resident` | x9.2/y5.2/w0.6/h0.6 |
| 14 | Markers | `villager-shopkeeper` | cell6,5; world416,192 |
| 15 | Markers | `villager-farmer` | cell3,5; world320,144 |
| 16 | Markers | `villager-resident` | cell9,5; world512,240 |

Set `nextobjectid: 17`.

## Exact parser changes

`ParsedProofMap` gains:

```ts
villagers: VillagerPlacement[];
villagerCells: Record<VillagerId, GridCell>;
```

### Collision

Keep scenery parsing limited to tree/building/shipping-bin and add a separate villager-footprint contract. `parseCollision` must stop asserting `footprints.length === scenery.length` and stop returning only `scenery.map(...)`.

Its exact six-entry output order is:

1. tree;
2. building;
3. shipping-bin;
4. shopkeeper;
5. farmer;
6. resident.

The last three are ordered by `VILLAGER_IDS`.

### Markers

Do not grow the current hand-written bed/shop/shipping blocks to seven near-copies. Keep `player-spawn` special because it is an authored half-cell point (`2.5,9.5`), then add one small `cellMarkerContract` for the six integer-cell interaction markers:

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

Use one loop for existence, exact ID, common point metadata, and exact `gridCellAtWorld` equality. Derive the allowed cell-marker names from this table. This removes repetition without introducing a general Tiled schema abstraction.

## Deterministic villager asset and Phaser rendering

Generate `proof-villagers.png` as exactly 96×48: one 32×48 bottom-center frame in `VILLAGER_IDS` order. Reuse the simple player-frame generation convention. Portraits remain Svelte placeholders.

`ProofScene` preloads and creates one static sprite per parsed villager placement. Villagers join the existing `sortDepthEntries` pass using IDs such as `villager:${VillagerId}` and marker object ID as stable order. No NPC movement or second depth system is introduced.

## Interaction intent

Replace the string union with:

```ts
type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };
```

Because `GameSnapshot` now includes `villagerCells`, `interactionIntentForTarget(snapshot.target, snapshot)` remains the complete adapter call; the scene does not merge parsed map cells at interaction time.

When converting App, the economy type becomes exactly:

```ts
type EconomyPanel = Exclude<InteractionIntent['kind'], 'sleep' | 'villager'> | null;
```

Update App's intent-kind switch in the same task as the union. No compatibility aliases.

## Svelte presentation and complete input lock

`App.svelte` owns social panel-open state and uses the existing generic `InputGate` reason `dialogue-panel`. `InputGate.ts` itself stays unchanged.

Create `DialoguePanel.svelte` for the current line index, gift-choice visibility, local focus, and dialog-scoped Escape-to-close handling. Use a native `Continue` button. Do not add `<svelte:window onkeydown>` or any other window-level dialogue key listener.

This is an explicit lifecycle invariant, not only a key-behavior preference: `tests/e2e/lifecycle.pw.ts` asserts the app has exactly one active window `keydown` and one `keyup` listener before and after HMR. Follow the existing economy dialog's element-scoped `onkeydown` pattern for Escape so HPA-595 does not change that listener census.

InputGate blocks Phaser keys but not Svelte buttons. App therefore passes `dialogueOpen` into `Overlay.svelte`; while true, Overlay must disable:

- action buttons;
- seed-selection buttons; and
- its manual world-input lock toggle.

Dialogue state and relationship math remain outside Overlay.

Gifting sends exactly one carried harvested crop; do not use `QuantityStepper.svelte`.

## Weather-aware browser reuse

Weather is random (`RAIN_CHANCE = 0.25`). A sunny-day water succeeds and costs time/stamina; on rain, the same action returns `rain-waters-crops` with no mutation while overnight growth still advances. The social E2E must not assume three sunny growing days.

There are already two copies of this branch in farming/economy acceptance. Promote one generic real-control helper to `tests/e2e/helpers.ts`:

```ts
waterForCurrentWeather(page, targetKey, targetCell): Promise<GameSnapshot>
```

It acquires the cell, presses Space, expects `Crop watered` on sun or `Rain is watering the crops` on rain, verifies the sunny +20-minute/-2-stamina mutation or rainy no-mutation result, and returns the latest snapshot.

Refactor `farming.pw.ts` and `economy.pw.ts` to use the shared helper, then reuse it in `social.pw.ts`. Do not add a third local copy.

## Acceptance journey

Close Friend 18 means the journey needs only the three starter Turnip seeds and three favourite gifts. Do not buy extra seeds merely for the test.

A compact real-control setup is:

1. Day 1: hoe three cells, plant the three starter Turnips, and water each through `waterForCurrentWeather`. This costs at most 18 stamina and fits the day.
2. Day 2 and Day 3: water/rain-branch the three crops and sleep.
3. Day 4 morning: all three Turnips are mature; harvest all three.
4. Social Day 1: talk to June (+1), verify repeat talk +0, gift one favourite Turnip (+5) → 6 points, Stranger.
5. Sleep/start next day; verify daily flags reset.
6. Social Day 2: talk+favourite gift → 12 points, Friend.
7. Sleep/start next day.
8. Social Day 3: talk+favourite gift → 18 points, Close Friend; gift crossing does not consume special sequence.
9. Reopen June the same day; show the exact two-line Close Friend sequence once. With Continue focused, one Enter advances only to line two.
10. Close/reopen; now only June's normal Close Friend line appears.
11. JSON-round-trip the observed snapshot, including `villagerCells` and relationships.

The journey uses only real movement keys, `E`, visible controls, and the observation-only test hook.

## README/handoff contract

Keep README pinning player-facing, not implementation placement. `tests/config/handoff.test.ts` adds only:

- `HPA-595`;
- `E on a villager talks`;
- `one harvested crop`;
- `Friend at 12`;
- `Close Friend at 18`.

Exact villager cells remain generator/parser/unit/E2E geometry contracts; do not duplicate them in README/handoff.

## Risks and mitigations

1. **Random weather in the social setup.** Use the shared weather-aware real-control helper already justified by two existing copies; never assume a sunny day.
2. **Window listener regression.** Keep dialogue key handling on the dialog element and run the existing lifecycle listener-census suite after App/DialoguePanel changes.
3. **Ground/scenery GID shift.** Land generator, generated fixtures, parser contract, and parser tests atomically.
4. **Modal bypass through HUD clicks.** `dialogueOpen` disables Overlay button/toggle paths while InputGate blocks Phaser.
5. **Social journey length/flakiness.** Threshold 18 reduces the no-hook journey to three social cycles. Keep retries/timeouts unchanged and fix route helpers instead of adding sleeps or mutation hooks.

## Explicit non-goals

No schedules, NPC movement/pathfinding, homes/interiors, romance, marriage, birthdays, relationship decay, disliked-gift categories, generic items, inventory capacity, quests, cutscene/event system, branching dialogue, voice acting, portrait asset pipeline, more than three villagers, persistence, harvest-market implementation, another map, second renderer, backend, or gameplay logic in Rust.
