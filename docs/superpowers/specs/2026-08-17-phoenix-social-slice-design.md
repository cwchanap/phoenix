# Phoenix Social Slice Design (HPA-595)

**Status:** Draft for review — revised after repository contract review

**Date:** 2026-08-17

**Delivery target:** macOS-first browser and Tauri social slice

## Source of truth

This design implements [HPA-595](https://linear.app/cwchanap/issue/HPA-595/social-slice-add-the-village-three-villagers-gifting-and-relationships), the next active child of HPA-587 after the completed HPA-593 economy slice. HPA-595 blocks HPA-596 persistence, so all social gameplay state must remain authoritative, deterministic, fresh, and JSON-serializable.

The live Linear issue and Phoenix project description remain authoritative for product scope and non-goals. This document resolves the implementation contract against the current `main` code.

## Outcome

Phoenix keeps the existing 12×12 isometric world and adds a short village path in the unused northern area. Three static villagers stand immediately north of that path. The player walks to a known path stance, presses the existing `E` interaction key, talks once per day for relationship credit, gives exactly one harvested crop per villager per day, receives a favourite-crop bonus, and sees dialogue progress through Stranger, Friend, and Close Friend.

Each villager has one two-line Close Friend sequence shown once through a focused Svelte dialogue panel. Villagers do not move. There are no schedules, homes, pathfinding, quests, cutscene machinery, or generalized NPC/dialogue abstractions.

## Approved decisions

- Keep the map, projection, camera, logical stage, and one-elevation renderer unchanged.
- Use one static content/policy module, `villagerDefinitions.ts`, shaped like the existing `cropDefinitions.ts` pattern.
- Keep `GameSession` as the only mutable social authority.
- Add only two domain commands: `talkTo(villagerId)` and `giftCrop(villagerId, crop)`.
- Add a `SocialFeedback` payload only to `villager-talked` and `crop-gifted` successes; do not replace the current command-result model with a generic envelope.
- Keep talking and gifting free of time/stamina cost for HPA-595.
- Keep daily limits and relationship reset logic in the existing direct `sleep()` transition.
- Keep the development hook observation-only.
- Use a dedicated `DialoguePanel.svelte`; do not reuse the quantity stepper and do not build a dialogue engine.
- Keep persistence, the market finale, schedules, romance, and additional villagers out of this slice.

## Villager content and pacing

Villager IDs are stable role IDs. Names are content.

| Villager ID | Name | Role | Favourite crop | Authored cell | Interaction stance |
| --- | --- | --- | --- | --- | --- |
| `shopkeeper` | Mira | Seed-shop keeper | Potato | 7,5 | stand in 6,6 and face right |
| `farmer` | Rowan | Neighbouring farmer | Pumpkin | 3,5 | stand in 4,6 and face up |
| `resident` | June | Village resident | Turnip | 9,5 | stand in 8,6 and face right |

These stances intentionally match `ProofWorld`'s shipped facing offsets: right targets `{ +1, -1 }` and up targets `{ -1, -1 }` after flooring the player position. No villager requires standing inside the shop/building footprint or inventing a special targeting rule.

Relationship thresholds and gains are exact:

| Rule | Value |
| --- | ---: |
| Stranger floor | 0 |
| Friend floor | 12 |
| Close Friend floor | 30 |
| First talk per villager/day | +1 |
| First normal gift per villager/day | +3 |
| Favourite gift bonus | +2 |

A favourite talk+gift day gives six points, so one villager reaches Close Friend in five social days. A normal talk+gift day gives four points and still fits the 14-day arc.

### Exact dialogue content

`VILLAGER_DEFINITIONS` contains these strings so implementation does not invent copy later.

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

Create `src/game/core/villagerDefinitions.ts` with only static records, constants, and pure helpers. It exports:

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

`VILLAGER_IDS` is exactly `['shopkeeper', 'farmer', 'resident']`. Pure helpers validate programmer inputs, return fresh arrays, and throw for invalid point values. The module contains no coordinates, mutable state, Phaser/Svelte objects, callbacks, schedules, persistence logic, or event dispatch.

## Shared social types

Add closed unions and plain snapshot data to `src/game/core/types.ts`:

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

`GameSnapshot` gains only:

```ts
relationships: Record<VillagerId, RelationshipSnapshot>;
```

Relationship level is derived from points; it is not mutable authoritative state. Panel line index, dialogue strings, portrait presentation, map placement, and Svelte/Phaser values stay outside `GameSnapshot`.

The command result remains narrow:

```ts
type CommandResult =
  | { ok: true; code: PlainSuccessCode }
  | { ok: true; code: 'villager-talked' | 'crop-gifted'; social: SocialFeedback }
  | { ok: false; code: FailureCode };
```

Add `not-at-villager` and `gift-already-given`. Reuse `insufficient-crops` when the requested harvested crop is unavailable.

## GameSession authority

`GameSessionConfig` gains the map-owned cells after the map/parser task exposes them:

```ts
villagerCells: Record<VillagerId, GridCell>;
```

Construction clones the record and validates that all cells are in bounds, integer, unique, and distinct from farm, bed, shop, and shipping interaction cells.

Mutable social state is exactly:

```ts
Record<VillagerId, {
  points: number;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}>;
```

### `talkTo`

Validation and mutation order:

1. apply `activeDayFailure()`;
2. require the authoritative target to equal the requested villager cell;
3. on the first talk that day, set `talkedToday` and add one point;
4. derive the resulting level;
5. if the resulting level is Close Friend and the one-time sequence has not been seen, return the two-line sequence and set `closeFriendDialogueSeen`;
6. otherwise return the normal line for the resulting level.

Repeated same-day talks remain successful dialogue interactions with `pointsGained: 0`.

### `giftCrop`

Validation and mutation order:

1. apply `activeDayFailure()`;
2. require the authoritative target to equal the requested villager cell;
3. reject `gift-already-given`;
4. reject `insufficient-crops` before mutation;
5. consume exactly one crop;
6. set `giftedToday`;
7. add +3 plus +2 when the crop is that villager's favourite;
8. return the static gift response and resulting relationship level.

A gift that crosses 30 points does not consume the one-time Close Friend dialogue. The next talk does.

### Daily reset

Only a successful `sleep()` transition clears every `talkedToday` and `giftedToday`. Points and `closeFriendDialogueSeen` persist. Failed sleep, Day 14 rejection, and a duplicate sleep while the morning summary is pending do not reset social flags.

## Authored map contract

Keep the map exactly 12×12 with the current 64×32 isometric projection, origin `(384, 0)`, four layers, and `nextlayerid: 5`.

### Ground tiles

Expand `proof-tiles.png` from 128×32 to 192×32:

1. GID 1 grass;
2. GID 2 farm soil;
3. GID 3 village path.

`proof-ground` becomes `columns: 3`, `tilecount: 3`, `imagewidth: 192`. Because the ground tileset gains one global ID, `proof-scenery.firstgid` moves from 3 to 4; existing scenery global GIDs become tree 4, building 5, shipping bin 6.

The path is only the seven-cell row immediately north of the farm/shop approach:

```text
3,6  4,6  5,6  6,6  7,6  8,6  9,6
```

All three villagers stand one row north at y=5. The HPA-597 market reserve remains x 8–10, y 2–3: grass, walkable, and free of new markers/collision/scenery.

### Villager footprints and markers

Keep existing object IDs 1–10. Add exact contracts:

| Object ID | Layer | Name | Contract |
| ---: | --- | --- | --- |
| 11 | Collision | `villager-shopkeeper` | x 7.2, y 5.2, w 0.6, h 0.6 |
| 12 | Collision | `villager-farmer` | x 3.2, y 5.2, w 0.6, h 0.6 |
| 13 | Collision | `villager-resident` | x 9.2, y 5.2, w 0.6, h 0.6 |
| 14 | Markers | `villager-shopkeeper` | cell 7,5; world footpoint 448,208 |
| 15 | Markers | `villager-farmer` | cell 3,5; world footpoint 320,144 |
| 16 | Markers | `villager-resident` | cell 9,5; world footpoint 512,240 |

Set `nextobjectid: 17`.

The 0.6×0.6 size deliberately reuses the already-proven tree/shipping-bin footprint scale instead of introducing a 0.4×0.4 collision contract. Players target villagers from the y=6 path stances above rather than occupying the villager cell.

### Parser ownership and footprint ordering

`ParsedProofMap` gains:

```ts
villagers: VillagerPlacement[];
villagerCells: Record<VillagerId, GridCell>;
```

Keep existing scenery parsing limited to tree/building/shipping-bin. Add a separate villager-footprint contract instead of widening `SceneryKind`.

`parseCollision` must no longer assume collision count equals scenery count or return only `scenery.map(...)`. Its exact output contract becomes six footprints:

1. existing scenery footprints in existing scenery order: tree, building, shipping-bin;
2. villager footprints in `VILLAGER_IDS` order: shopkeeper, farmer, resident.

Missing, duplicate, renamed, malformed, or unexpected collision objects remain parser errors.

## Deterministic villager asset

Generate `proof-villagers.png` as exactly 96×48: one 32×48 bottom-center frame per `VILLAGER_IDS` entry. Reuse the player's simple deterministic sprite-generation convention. Portraits remain styled Svelte placeholders; there is no portrait asset pipeline.

## Phaser adapter

`ProofScene` preloads and renders the three static villager sprites from parsed placements. Villagers participate in the existing footpoint depth sort using IDs such as `villager:${VillagerId}` and marker object ID as stable order. No update-loop movement is added.

The interaction intent becomes one closed discriminated union:

```ts
type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };
```

`interactionIntentForTarget` uses authored cells only. No registry, entity lookup service, or sprite-position inference is introduced.

`SceneCommands` gains direct `talkTo` and `giftCrop` facades that delegate to `GameSession` and reuse `publishCommand`.

## Svelte presentation and complete input lock

`App.svelte` continues to own presentation state. It adds one social panel state with the current `villagerId` and latest `SocialFeedback`. Opening a villager interaction calls `talkTo`, stores the returned social payload, and sets the existing generic `InputGate` reason string `dialogue-panel`.

`InputGate.ts` itself does not change: it already supports arbitrary string reasons.

Create `DialoguePanel.svelte` for line index, gift-choice presentation, local focus, and local Escape-to-close behavior. It uses a native `Continue` button. There is no window-level Enter/Space dialogue handler, so one Enter activation on focused Continue advances exactly one line.

The Phaser gate alone is insufficient because Overlay buttons are a separate input path. `App.svelte` therefore passes `dialogueOpen` into `Overlay.svelte`, and Overlay must:

- include `!dialogueOpen` in `actionsReady` so action/seed HUD buttons are disabled;
- include `dialogueOpen` in the manual overlay-toggle guard/disabled state; and
- keep economy/day-summary behavior otherwise unchanged.

Dialogue state and relationship math remain outside Overlay.

Gifting lists carried harvested crops and sends exactly one crop. Do not reuse `QuantityStepper.svelte`.

## README/handoff contract

HPA-595 extends the existing checked README contract rather than updating README without pinning it. `tests/config/handoff.test.ts` must require the README to contain the same class of stable facts already pinned for HPA-592/HPA-593:

- `HPA-595`;
- `E on a villager talks`;
- `one harvested crop`;
- `Friend at 12`;
- `Close Friend at 30`;
- `shopkeeper cell 7,5`;
- `farmer cell 3,5`;
- `resident cell 9,5`.

The README can phrase surrounding prose naturally, but those facts stay test-pinned.

## Acceptance strategy

### Unit and parser coverage

Use `bun:test` for:

- exact definition content and relationship thresholds;
- first/repeated talk behavior;
- normal/favourite gift behavior and exact one-crop consumption;
- threshold crossing and one-time Close Friend dialogue;
- successful-sleep daily reset and failed-sleep non-reset;
- fresh/JSON-safe relationship snapshots;
- exact marker positions and 0.6 footprints;
- exact path cells and scenery GID shift;
- exact six-footprint parser ordering;
- typed interaction intents for all three villagers.

### Browser world proof

The static village/map task must retune existing `world.pw.ts` routes as soon as the new Mira footprint lands. The current tree-detour route crosses the new 7,5 footprint area, so preserving the old route until the final social test would defer a known map-contract regression.

World tests must prove:

- existing farm/shop/shipping/bed routes remain reachable;
- all three villager targeting stances work;
- representative villager collision blocks entry;
- player/villager footpoint depth reverses correctly;
- camera remains within bounds.

### Full social journey

`social.pw.ts` uses only real movement keys, `E`, and visible buttons. It prepares and harvests five Turnips through normal farming, then performs talk + favourite gift across five social days for June. The journey must demonstrate Stranger → Friend → Close Friend, daily reset, repeated-talk/gift limits, exact inventory consumption, the one-time two-line Close Friend sequence, one-Enter/one-line behavior, and JSON snapshot round-trip.

The five-day journey is intentionally retained: without mutation hooks it is the direct proof that daily reset, threshold crossing, and the one-time two-line sequence compose correctly.

## Risks and mitigations

1. **Existing route regression from new collision.** Mira's 0.6 footprint intersects the area used by the current tree-detour E2E route. Retune that route in the static village/map task, then rerun existing world/economy paths. Do not increase retries/timeouts.
2. **Long social E2E route flakiness.** The five-day journey is structurally required. Use existing movement helpers, `expect.poll`, and key release in `finally`; fix authored geometry/helper waypoints instead of adding sleeps, retries, teleportation, or mutation hooks.
3. **Strict Tiled GID/footprint migration.** The new ground GID shifts scenery firstgid. Keep generator, generated JSON/PNGs, parser contracts, and fixture tests in one task so an intermediate mismatched asset contract is not accepted.
4. **Modal bypass through HUD clicks.** InputGate blocks Phaser keys but not Svelte buttons. `dialogueOpen` must disable Overlay's action/seed/toggle paths while the social panel is open.

## Explicit non-goals

No schedules, NPC movement, pathfinding, homes/interiors, romance, marriage, birthdays, relationship decay, disliked-gift categories, generic items, inventory capacity, quests, cutscene/event system, branching dialogue, voice acting, portrait pipeline, more than three villagers, persistence, harvest-market implementation, another map, second renderer, backend, or gameplay logic in Rust.
