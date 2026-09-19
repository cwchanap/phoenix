# Phoenix Contextual Village Dialogue Design

**Linear:** HPA-461  
**Repository:** `cwchanap/phoenix`  
**Branch:** `agent/hpa-461-contextual-village-dialogue-plan`  
**Base reviewed:** `main` at `207511222970f0f171b400da901a9f9bfca4e252`

## Goal

Make Mira, Rowan, and June react to the current farming run and stop repeating one line per relationship tier, without adding a dialogue engine, conversation history, new state, new art, or new interaction mode.

This is a content-and-selection-policy slice. The existing relationship rules, full dialogue panel, gifting flow, Close Friend event, save shape, and E/Esc controls remain authoritative.

## Current seams to preserve

The current implementation is already small enough for this feature:

- `VillagerRules` owns villager identity, relationship thresholds, authored normal dialogue, Close Friend dialogue, gift reactions, and finale lines.
- `GameSession.talk_to()` owns talk eligibility, the once-per-day talk point, relationship mutation, and Close Friend event precedence.
- `GameSession` already owns the exact context this ticket needs: current day, current weather, settled `_shipped_counts`, and relationship state.
- Pending shipment and harvested inventory are separate from settled `shipped` totals. Only settled totals may enable shipping reactions.
- `DialoguePanel` renders the existing social result dictionary and already supports one-line ordinary dialogue plus the player-paced two-line Close Friend sequence.
- `WorldShell` only coordinates session results into the existing dialogue panel. It does not need a new event path.
- The current save already persists day, weather, shipped totals, and relationship state, so the same restored state can choose the same line without storing dialogue history.

Extend those owners only. No new persistence field, dialogue graph, event bus, or UI mode is needed.

## Bounded authored content

Keep the current normal line as slot 0 at every villager/tier and add exactly two more normal lines beside it. Add exactly one rainy, one settled-shipment, and one Days 12-14 market reaction per villager.

That is 27 new lines total.

### Mira — seeds, trade, and farm economics

Keep the existing tier lines unchanged.

**Stranger — add:**

1. "Turnips are quick. Potatoes ask for a little more patience."
2. "Buy only the seeds you have time to water."

**Friend — add:**

1. "You are planning your seed money better now."
2. "A mixed crop shelf keeps the counter interesting."

**Close Friend — add:**

1. "You know what your fields can afford now."
2. "I save the better seed lots when I know you will stop by."

**Rainy:**

- "Rain saves you a watering round. Good day to plan the next planting."

**Settled shipment:**

- "Produce has left your farm now. Growing and selling are different skills."

**Days 12-14:**

- "The market is close. Keep some coin ready for what comes next."

### Rowan — farming effort and field craft

Keep the existing tier lines unchanged.

**Stranger — add:**

1. "A straight row is nice, but a watered row is useful."
2. "Do the work you can finish before dusk."

**Friend — add:**

1. "You move through the field with less wasted effort now."
2. "A few well-kept plots beat a field you cannot tend."

**Close Friend — add:**

1. "You have learned when to push and when to leave the soil alone."
2. "Your farm has your rhythm in it now."

**Rainy:**

- "Let the rain do its share. Save your strength for the rest."

**Settled shipment:**

- "You have sent real harvest out now. That means the farm is working."

**Days 12-14:**

- "The market is close. Finish what will be ready before you plant more."

### June — belonging and village life

Keep the existing tier lines unchanged.

**Stranger — add:**

1. "The village notices steady footsteps more than grand entrances."
2. "You will learn which corners feel familiar before long."

**Friend — add:**

1. "It is nice seeing your farm light up another part of the road."
2. "People say your farm now, not the old farm."

**Close Friend — add:**

1. "You do not look like a newcomer when you walk through town anymore."
2. "Some places become home one ordinary day at a time."

**Rainy:**

- "Rain pulls the village closer. Everyone listens to the same roofs."

**Settled shipment:**

- "Your produce is going out now. The farm touches more than your own day."

**Days 12-14:**

- "The market is almost here. You will see who noticed your season."

## Content rules

- Shipping reactions require at least one crop in the settled shipped totals.
- Harvested inventory and pending shipment never qualify.
- Do not claim a shipment happened "today", was the player's first shipment, or happened once. Those claims would require new state.
- Market reactions are eligible on Days 12, 13, and 14 only.
- Rain reactions are eligible only when the current session weather is rainy.
- Relationship-tier normal lines always use the level after the current talk point is awarded, matching current semantics.
- The unseen Close Friend conversation remains higher priority than every ordinary candidate.
- Finale lines, gift lines, favourite-gift rules, thresholds, and point values are unchanged.

## Pure selection policy

### Authored table shape

Change `NORMAL_DIALOGUE` from one string per villager/tier to three strings per villager/tier:

`NORMAL_DIALOGUE[villager_id][relationship_level][normal_slot]`

Slot 0 is the existing line. Slots 1 and 2 are the new lines above.

Add three one-dimensional authored arrays, each indexed by villager:

- `RAINY_DIALOGUE`
- `SHIPPED_DIALOGUE`
- `MARKET_DIALOGUE`

Do not add a dialogue-entry class, condition object, tag registry, or data file. The current content set is fixed and small.

### Eligible ordinary set

`VillagerRules` owns one pure helper that builds the eligible ordinary lines from:

- villager id;
- relationship level;
- current day;
- current weather;
- whether any settled shipment exists.

The candidate order is intentionally fixed:

1. the three normal lines for the current relationship tier;
2. rainy reaction when rainy;
3. settled-shipment reaction when settled shipped total is greater than zero;
4. market reaction when day is at least 12.

This order is part of the deterministic contract and should be covered by focused tests.

### Deterministic choice

Choose one candidate with:

`posmod((day - 1) + int(villager_id), candidates.size())`

Why this shape:

- same state always returns the same greeting;
- baseline sunny/unshipped days rotate through the three normal options;
- different villagers do not all land on the same slot on the same day;
- no gameplay RNG, weather RNG, timestamp, process hash, or persisted history is needed;
- restoring equivalent state naturally reproduces the same result.

Contextual lines join the ordinary candidate set rather than overriding one another. Rain, shipping, and market can overlap without a priority ladder or extra event state.

## GameSession wiring

Keep `talk_to()` as the only social command owner.

The order stays:

1. reject inactive day / wrong villager target;
2. award the first valid daily talk point if not already awarded;
3. calculate the relationship level from the updated points;
4. if Close Friend is now reached and its event is unseen, mark it seen and return the existing two-line Close Friend sequence;
5. otherwise derive narrow read-only context and ask `VillagerRules` for one ordinary line.

The context is deliberately narrow:

- `_day`;
- `_weather`;
- one derived boolean, `has_settled_shipment`, computed only from `_shipped_counts`.

Do not pass the full session snapshot into `VillagerRules`. Do not let `VillagerRules` mutate session state.

The existing social result dictionary stays unchanged:

- `code`
- `lines`
- `points_gained`
- `gift_reaction`
- `close_friend_sequence`

No new result field is required.

## Relationship and interaction semantics

This ticket must not change any of the existing social economy:

- the first valid talk per villager per day awards exactly 1 point;
- repeat talks award 0 points;
- one gift per villager per day remains the limit;
- normal gift = 3 points;
- favourite gift = 5 points total;
- Friend remains 12 points;
- Close Friend remains 18 points;
- the Close Friend two-line event is still shown exactly once;
- repeat talks after that event use ordinary selection at the Close Friend tier;
- gifting does not directly consume or mark the Close Friend event;
- Esc dismissal and E interaction remain unchanged.

A useful integration route is:

1. seed a villager at 14 points with one favourite harvested crop;
2. ordinary talk gives +1 and opens a Friend-tier ordinary line;
3. give the favourite gift for +5;
4. close the panel;
5. talk again the same day for +0;
6. the unseen Close Friend sequence takes precedence over ordinary selection;
7. complete the two-line event and verify it does not replay.

This exercises ordinary talk, gifting, threshold crossing, repeat-talk semantics, and event precedence in one short flow.

## Persistence and RNG

No save-schema change.

The selector uses only data already persisted by `GameSession.state()`:

- day;
- weather;
- shipped totals;
- relationship points and Close Friend seen flag.

Therefore a restored equivalent state must choose the same ordinary greeting.

Talking must not call `_weather_roll`, `randf()`, or any other RNG source. Weather RNG remains sleep-only. Add a focused session test with an observable weather-roll callable so a talk proves it does not consume a roll.

Do not persist:

- last line;
- line index;
- per-villager history;
- last contextual reaction;
- per-day talk seed.

## UI and visual scope

No runtime UI code is expected to change.

`DialoguePanel` already autowraps the line label and renders the existing result shape. Keep:

- the same full dialogue panel;
- the same portrait;
- the same relationship display;
- the same gift controls;
- E to interact;
- Esc to dismiss ordinary dialogue;
- Continue gating for the existing Close Friend sequence.

At 640x360, review the longest new lines in the existing panel. If a line reads poorly or clips, shorten the authored sentence. Do not enlarge the panel, move gift controls, reduce font size, or add a speech-bubble mode for this content-only problem.

Do not create a new visual golden merely because text changed. Add focused visual evidence only if the existing panel layout itself must change, which is not expected.

## Verification strategy

### VillagerRules

Cover:

- three villagers;
- three relationship tiers;
- exactly three normal lines per tier;
- all existing slot-0 lines unchanged;
- all 27 new authored lines present in the intended tables;
- baseline sunny/unshipped rotation across successive days;
- stable output for identical inputs;
- different villager offsets;
- rainy candidate absent/present with weather;
- shipping candidate absent with harvested-only or pending-only state at the session layer and present after settlement;
- market candidate absent on Day 11 and eligible on Days 12 and 14;
- overlapping rain + shipped + market uses the fixed candidate order and deterministic selector.

### GameSession

Cover:

- first talk/repeat talk point semantics unchanged;
- relationship level is calculated after the first-talk point;
- settled shipment is the only shipping context source;
- talk does not consume weather RNG;
- same state restored into a fresh session returns the same ordinary line;
- unseen Close Friend event still preempts ordinary selection;
- once seen, Close Friend ordinary dialogue uses the new selector;
- gift limits, favourite bonus, and failure atomicity remain unchanged.

### Integration

Extend the existing social integration coverage rather than adding a second harness:

- ordinary talk opens the existing panel;
- ordinary talk -> favourite gift -> repeat talk crosses into the unseen Close Friend event;
- Close Friend Continue/Esc behavior remains unchanged;
- no extra modal or world-input path is added;
- review the longest Mira/Rowan/June lines at the shipped 640x360 window.

Run the existing clean verifier and affected social/unit tests before the PR leaves draft.

## Expected implementation files

Primary runtime:

- `scripts/game/villager_rules.gd`
- `scripts/game/game_session.gd`

Focused tests:

- `tests/unit/test_villager_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`

Planning docs remain in this PR. No `DialoguePanel`, `GameHud`, scene, persistence, image, audio, README, or CLAUDE change is expected unless implementation discovers a concrete contradiction with the reviewed seams.

## Non-goals

No new NPCs, schedules, pathing, quests, request board, romance, voice acting, speech bubbles, AI-authored runtime text, localization framework, dialogue graph, generic event system, dialogue-history persistence, save migration, relationship rebalance, new ending, new portrait, new image generation, or new SFX.
