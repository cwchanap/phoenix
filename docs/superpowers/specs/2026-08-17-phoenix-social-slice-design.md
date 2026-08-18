# Phoenix Social Slice Design (HPA-595)

**Status:** Draft for review

**Date:** 2026-08-17

**Delivery target:** macOS-first browser and Tauri social slice

## Source of truth

This design implements the next active vertical slice under [HPA-587](https://linear.app/cwchanap/issue/HPA-587/tracking-deliver-the-phoenix-14-day-farming-mvp): [HPA-595](https://linear.app/cwchanap/issue/HPA-595/social-slice-add-the-village-three-villagers-gifting-and-relationships).

HPA-593 is complete on `main`, so HPA-595 is no longer blocked. HPA-595 blocks HPA-596 persistence, therefore this slice must leave social state explicit, deterministic, and JSON-serializable without introducing a second gameplay authority.

The live Linear issue and Phoenix project description remain authoritative for product scope, delivery order, and non-goals. This document resolves the implementation details needed to build the slice against the current repository state.

## Outcome

The existing 12×12 isometric farm map gains a compact village path in the currently unused northern half rather than becoming a larger world. The player can walk from the farm to three static villagers, interact with each villager using the existing `E` action, talk once per day for relationship credit, give exactly one harvested crop per villager per day, receive a favourite-crop bonus, and see dialogue evolve from Stranger to Friend to Close Friend.

Each villager has one short two-line Close Friend sequence that is shown once through the normal dialogue panel. Afterwards the villager uses their normal Close Friend line. The same authoritative TypeScript state and frontend run in the browser and Tauri.

This is intentionally a social **slice**, not an NPC framework: villagers never move, there are no homes or schedules, relationship rules are three small records, and dialogue presentation is one focused Svelte component.

## Approved implementation direction

### Keep the current world size

Do not resize the map, projection, camera, or logical stage. The 12×12 map already has enough unused space north of the farm and shop for the MVP village. Expanding content inside the existing bounds avoids a large camera/parser migration while still giving the player a visible destination beyond the farm.

The village adds one new ground tile for a visible walking path, three Tiled villager markers, three small collision footprints, one generated three-frame villager spritesheet, and a reserved empty market area for HPA-597.

### Use exactly three villagers

Villager IDs are role-based and stable; display names remain content:

| Villager ID | Name | Role | Favourite crop | Authored cell |
| --- | --- | --- | --- | --- |
| `shopkeeper` | Mira | Seed-shop keeper | Potato | 7,6 |
| `farmer` | Rowan | Neighbouring farmer | Pumpkin | 3,5 |
| `resident` | June | Village resident | Turnip | 9,5 |

Role-based IDs let HPA-597 refer to the shopkeeper without coupling future logic to a display name.

### Keep relationship pacing small and deterministic

Relationship levels use these exact minimum-point thresholds:

| Level | Minimum points |
| --- | ---: |
| Stranger | 0 |
| Friend | 12 |
| Close Friend | 30 |

The player earns:

- +1 point for the first successful talk with a villager each day;
- +3 points for the first successful gift to that villager each day; and
- an additional +2 points when that gift is the villager's favourite crop, for +5 total.

There is no relationship cap, decay, dislike penalty, random bonus, birthday modifier, or hidden multiplier.

A focused favourite routine earns at most six points per villager-day, so Close Friend is reachable in five social days. A normal-gift routine earns four points per villager-day and still reaches Close Friend comfortably within the 14-day MVP.

Talking and gifting consume no game time or stamina in this slice. The per-villager daily limits already bound repetition, and adding a second time-cost system would widen HPA-595 without improving the acceptance proof.

## Explicit non-goals

HPA-595 does **not** add villager schedules, NPC pathfinding, homes or interiors, romance, marriage, jealousy, birthdays, relationship decay, quests, item likes/dislikes beyond one favourite crop, gifts other than harvested crops, gift quantities, inventory capacity, generic items, a generic NPC base class, a generic relationship service, a dialogue scripting language, branching dialogue, cutscenes, voice, animated portraits, event triggers, another map, another renderer, backend state, persistence, the harvest-market event, or HPA-597 finale logic.

The Close Friend sequence is not an event engine. It is a two-line static array selected by one boolean flag.

## Architecture and ownership

### Pure villager definitions

Create `src/game/core/villagerDefinitions.ts` as the only content and pure-policy module for this slice.

It exports:

- `VILLAGER_IDS` in stable `shopkeeper`, `farmer`, `resident` order;
- `VILLAGER_DEFINITIONS` as one readonly exhaustive record;
- `RELATIONSHIP_THRESHOLDS` with exact floors 0, 12, and 30;
- `TALK_POINTS = 1`;
- `GIFT_POINTS = 3`;
- `FAVOURITE_GIFT_BONUS = 2`;
- `relationshipLevel(points)`; and
- pure helpers that return fresh dialogue lines for a villager and relationship level.

The definitions contain only data needed by HPA-595: display name, role, favourite crop, three normal dialogue entries, one two-line Close Friend sequence, one normal gift response, and one favourite gift response.

They contain no mutable relationship state, Phaser objects, Tiled coordinates, Svelte callbacks, timers, schedules, persistence code, or event dispatch.

### Shared social types

Add these domain concepts to `src/game/core/types.ts`:

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

`GameSnapshot` gains exactly:

```ts
relationships: Record<VillagerId, RelationshipSnapshot>;
```

It does not store villager display names, favourite crops, Tiled positions, portrait data, or dialogue strings. Those are immutable definitions or authored map data.

Social command success carries a `SocialFeedback` payload while existing command shapes remain unchanged:

```ts
type CommandResult =
  | { ok: true; code: PlainSuccessCode }
  | { ok: true; code: 'villager-talked' | 'crop-gifted'; social: SocialFeedback }
  | { ok: false; code: FailureCode };
```

Add failure codes `not-at-villager` and `gift-already-given`. Reuse `insufficient-crops` when the selected harvested crop is not carried.

### GameSession remains authoritative

`GameSession` remains the only mutable gameplay authority.

`GameSessionConfig` gains one cloned map-owned record:

```ts
villagerCells: Record<VillagerId, GridCell>;
```

Construction validates that all three cells are integer cells in bounds, distinct from each other, and distinct from the farm, bed, shop, and shipping interaction cells. The authored map/parser owns the exact positions and collision shapes.

Mutable social state is only:

```ts
Record<VillagerId, {
  points: number;
  talkedToday: boolean;
  giftedToday: boolean;
  closeFriendDialogueSeen: boolean;
}>;
```

`level` is derived from points for snapshots and command feedback; it is not stored redundantly.

The session gains two direct commands:

```ts
talkTo(villagerId: VillagerId): CommandResult;
giftCrop(villagerId: VillagerId, crop: CropKind): CommandResult;
```

Both commands:

1. apply the existing active-day gate first;
2. require the authoritative target to match that villager's authored cell;
3. mutate only `GameSession` state; and
4. return fresh JSON-serializable feedback.

#### Talk semantics

A valid talk always succeeds and shows dialogue.

On the first talk to that villager that day, `talkedToday` becomes true and one relationship point is added. Further talks that day return dialogue with `pointsGained: 0` and do not mutate points.

Normal dialogue is selected from the relationship level **after** any talk point is applied.

If the villager is already Close Friend and `closeFriendDialogueSeen` is false, the talk returns the two-line Close Friend sequence and sets the flag true. This trigger is independent of the daily point credit, so a player who crossed the threshold through a gift may reopen the villager the same day and see the sequence without gaining a second talk point. Every later talk uses the normal Close Friend line.

#### Gift semantics

A valid gift always consumes exactly one harvested crop from `inventory.crops`.

Validation order is:

1. active-day gate;
2. correct villager target;
3. daily gift not already used;
4. at least one selected harvested crop is carried.

Only after all validation passes does the session decrement the carried crop, mark `giftedToday`, and apply relationship points.

A normal crop gives +3. The villager's favourite crop gives +3 plus +2, for +5 total. Gift feedback uses the villager's static normal/favourite response and reports the resulting relationship level. A gift that crosses 30 points does **not** consume the one-time Close Friend sequence; that sequence remains a talk event.

Repeated or invalid gifts consume nothing and add no relationship points.

#### Day transition reset

Only one successful `sleep()` transition resets every villager's `talkedToday` and `giftedToday` flags for the new day. Failed sleep, Day 14 rejection, and a duplicate sleep while the morning summary is pending do not perform another reset.

Relationship points and `closeFriendDialogueSeen` never reset during the 14-day run.

### Authored map and deterministic assets

Keep the map at 12×12, the 64×32 2:1 projection, origin `(384, 0)`, four existing layers, and `nextlayerid: 5`.

#### Ground tiles

Expand `proof-tiles.png` from 128×32 to **192×32** with three 64×32 frames:

1. GID 1: grass;
2. GID 2: farm soil; and
3. GID 3: village path.

`proof-ground` becomes `columns: 3`, `tilecount: 3`, and `imagewidth: 192`.

Because the ground tileset gains one global tile ID, `proof-scenery` moves from `firstgid: 3` to **`firstgid: 4`**. Its existing local frame order remains tree, building, shipping bin, so the authored global IDs become 4, 5, and 6 respectively. No scenery frame is added.

The exact path cells are:

```text
3,6  4,6  5,6  6,6  7,6  8,6  9,6
3,5                              9,5
                                 9,4
```

The existing farm remains exactly x 2–4, y 7–9. Every other ground cell remains grass.

The rectangle x 8–10, y 2–3 is the **HPA-597 market reserve**. HPA-595 leaves those six cells grass, walkable, and free of collision, markers, or new scenery.

#### Villager markers and footprints

Keep all existing object IDs 1–10 unchanged. Add:

| Object ID | Layer | Name | Contract |
| ---: | --- | --- | --- |
| 11 | Collision | `villager-shopkeeper` | logical footprint x 7.3, y 6.3, w 0.4, h 0.4 |
| 12 | Collision | `villager-farmer` | logical footprint x 3.3, y 5.3, w 0.4, h 0.4 |
| 13 | Collision | `villager-resident` | logical footprint x 9.3, y 5.3, w 0.4, h 0.4 |
| 14 | Markers | `villager-shopkeeper` | logical cell 7,6; footpoint world 416,224 |
| 15 | Markers | `villager-farmer` | logical cell 3,5; footpoint world 320,144 |
| 16 | Markers | `villager-resident` | logical cell 9,5; footpoint world 512,240 |

The map sets `nextobjectid: 17`.

The marker points are villager footpoints, not sprite top-left positions. They are the bottom-center sprite anchors and the source of the interaction cell. The collision footprints are deliberately smaller than a cell so players can route around a villager and target the occupied cell from an adjacent position.

`ParsedProofMap` gains:

```ts
villagers: VillagerPlacement[];
villagerCells: Record<VillagerId, GridCell>;
```

`VillagerPlacement` is a Phaser/map-adapter type containing `id`, authored world footpoint, cell, and stable object order. It is not persisted gameplay state.

`loadProofMap.ts` remains an exact proof-map parser. Extend the existing explicit contracts instead of replacing them with a generic Tiled schema framework.

#### Villager sprites

Generate `src/assets/sprites/proof-villagers.png` as exactly **96×48**: three 32×48 frames in `VILLAGER_IDS` order. Each frame uses a distinct silhouette/palette and shares the player's bottom-center footpoint convention.

The portrait in Svelte remains a styled placeholder using the villager's name/initial. HPA-595 does not add a second portrait asset pipeline.

### Phaser adapter

`ProofScene` remains responsible for map loading, static sprite creation, target detection, input sampling, rendering, and depth reconciliation. It does not own relationship rules or dialogue content.

Preload `proof-villagers.png`, create one sprite per parsed villager marker, and keep them in a `Map<VillagerId, Phaser.GameObjects.Sprite>`.

Add villager entity IDs to the debug depth shape using a template form such as `villager:${VillagerId}`. Villagers participate in the existing `sortDepthEntries` pass with their authored footpoint y and marker object ID as stable order. Do not create a second depth system.

Replace the current string-only interaction intent with one small discriminated union:

```ts
type InteractionIntent =
  | { kind: 'sleep' }
  | { kind: 'shop' }
  | { kind: 'shipping' }
  | { kind: 'villager'; villagerId: VillagerId };
```

`interactionIntentForTarget` checks the existing authored cells plus the three villager cells. Off-target `E` keeps the existing `nothing-to-interact` result.

`SceneCommands` gains only:

```ts
talkTo(villagerId: VillagerId): CommandResult;
giftCrop(villagerId: VillagerId, crop: CropKind): CommandResult;
```

The facades delegate to `GameSession` and use the same `publishCommand` path as every other command. Do not expose the session, relationship setters, inventory injection, teleportation, or test-only social mutation.

### Svelte presentation

`App.svelte` continues to own mutually exclusive presentation state and InputGate reasons.

Keep `economyPanel: 'shop' | 'shipping' | null` and add one social panel state containing the current `villagerId` and latest `SocialFeedback`.

Opening a villager interaction performs `commands.talkTo(villagerId)` and opens the social panel from its returned payload. While the panel is open, App holds one `dialogue-panel` InputGate reason. The panel cannot coexist with economy, sleep confirmation, or morning summary state. Reset/unmount clears the reason idempotently.

Create `src/components/DialoguePanel.svelte` as a focused feature component, not a reusable dialogue framework. It receives authoritative snapshot/social feedback plus callbacks for gifting and closing.

The panel shows:

- villager name and role;
- a portrait placeholder;
- current relationship level;
- one dialogue line at a time;
- a native `Continue` button for multi-line dialogue;
- `Give gift` after the current dialogue is complete;
- a simple crop chooser containing only carried harvested crops;
- relationship feedback such as `+5 · Favourite gift · Friend`; and
- Close.

Gifting always sends exactly one selected crop; do not reuse the quantity stepper.

Use native button activation for dialogue progression. Do not add a window-level Enter/Space handler that competes with button activation. When `Continue` is focused, one Enter key press produces one native click and advances exactly one line. Phaser receives nothing because the InputGate is locked. Escape may close the panel through one panel-local handler, matching the economy-panel pattern.

`Overlay.svelte` keeps HUD/economy/day-summary responsibility. It only needs new command-result labels if social success/failure codes are surfaced in its existing feedback region; the dialogue UI itself lives in `DialoguePanel.svelte` so `Overlay.svelte` does not become a general modal controller.

## Exact dialogue content

HPA-597 will own harvest-market exposition. HPA-595 dialogue deliberately stays about the village/farm so the finale is not preimplemented.

### Mira — shopkeeper — favourite Potato

- Stranger: `Seeds are on the counter if you need them.`
- Friend: `Your farm is starting to look settled in.`
- Close Friend: `The shop feels livelier when you stop by.`
- One-time Close Friend sequence:
  1. `You have become part of the village rhythm.`
  2. `I am glad you chose to tend that farm.`
- Normal gift: `Thank you. I will put this to good use.`
- Favourite gift: `A potato? Perfect. I always save these for supper.`

### Rowan — farmer — favourite Pumpkin

- Stranger: `Water early and the rest of the day feels easier.`
- Friend: `Your rows look steadier every time I pass.`
- Close Friend: `You have good instincts with that field.`
- One-time Close Friend sequence:
  1. `I thought the farm might wear you down.`
  2. `I was wrong. You have earned my respect.`
- Normal gift: `A farm gift is never wasted. Thanks.`
- Favourite gift: `That pumpkin is a beauty. You grew this?`

### June — resident — favourite Turnip

- Stranger: `It is nice seeing someone use the old farm again.`
- Friend: `I have started looking for you on the village path.`
- Close Friend: `The village feels smaller now that we know each other.`
- One-time Close Friend sequence:
  1. `When you arrived, you felt like a visitor.`
  2. `You do not anymore.`
- Normal gift: `Thanks. That is kind of you.`
- Favourite gift: `Turnips are my favourite. You remembered—or got lucky.`

## Persistence handoff for HPA-596

HPA-595 must leave the following social state recoverable without Phaser/Svelte objects or runtime closures:

- relationship points for all three villagers;
- `talkedToday` for all three villagers;
- `giftedToday` for all three villagers; and
- `closeFriendDialogueSeen` for all three villagers.

Every `snapshot()` returns fresh nested relationship records, and a nontrivial social snapshot must round-trip through `JSON.stringify`/`JSON.parse` exactly.

The current open dialogue line, modal focus, or panel visibility is presentation state and is **not** part of `GameSnapshot`.

## Acceptance evidence

### Unit and parser proof

Add focused Bun tests for:

- exact villager content, favourites, point values, thresholds, and relationship-level boundaries;
- talk credit once per villager/day while repeated talk still returns dialogue;
- normal versus favourite gift points;
- exactly one carried crop removed on successful gift;
- invalid/repeated gifts leave inventory and relationships unchanged;
- level changes at 12 and 30 points;
- one-time Close Friend sequence then normal Close Friend dialogue;
- successful sleep resets both daily flags while failed sleep does not;
- fresh/JSON-safe relationship snapshots;
- exact path GIDs, unchanged farm cells, market reserve, new marker IDs/cells, collision footprints, and `nextobjectid: 17`;
- exact 192×32 ground and 96×48 villager PNG dimensions; and
- villager intent routing without changing sleep/shop/shipping/off-target behavior.

### Real browser proof

Create one `tests/e2e/social.pw.ts` vertical journey using real movement, `E`, visible buttons, and the existing observation-only development hook.

The journey proves:

1. the player can route from the farm to all three villager target cells;
2. each villager collision blocks entry while remaining interactable;
3. villager/player depth ordering reverses across at least one villager footpoint;
4. opening dialogue locks world input;
5. first talk adds one point and a repeated same-day talk adds zero;
6. a gift removes exactly one crop and grants +3 or +5 as appropriate;
7. a repeated same-day gift consumes nothing;
8. sleep resets the two daily limits;
9. June can reach Close Friend through a normal five-day favourite-gift routine after the player grows enough turnips;
10. the one-time two-line Close Friend sequence appears once;
11. one Enter activation on focused Continue advances one line, not two; and
12. subsequent interactions use June's normal Close Friend line.

Existing economy, farming, sleep, lifecycle, and world E2E suites remain green.

### Native boundary

The same frontend is packaged by the existing unsigned macOS Tauri build. HPA-595 adds no Rust command or native API. CI's macOS `tauri-build` remains the build proof; a bounded manual smoke may verify launch, one villager interaction, and dialogue close/focus behavior when a native GUI environment is available.

## Alternatives rejected

### Larger map

Rejected for HPA-595. The existing 12×12 world has enough unused space, while resizing would force unnecessary projection/camera/route retuning before content actually requires it.

### NPC entity framework or schedule system

Rejected. Three fixed villagers need data records, sprites, collision, and two commands—not an entity hierarchy, scheduler, steering, or pathfinding layer.

### Generic dialogue engine

Rejected. Three normal lines plus one two-line special sequence per villager do not justify a scripting language, node graph, event bus, or branching state machine.

### Relationship state outside GameSession

Rejected. It would create a second mutable gameplay authority and make HPA-596 persistence harder.

### Social time/stamina costs

Deferred. Daily talk/gift limits already bound progression and the Linear slice does not require a second action-budget policy. Balance can be revisited after the full 14-day loop is playable.
