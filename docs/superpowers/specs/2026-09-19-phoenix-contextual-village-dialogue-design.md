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
- Pending shipment and harvested inventory are separate from settled shipped totals. Only settled totals may enable shipping flavor.
- Settled shipped totals are lifetime state, not a one-shot event. Once the player has sold produce, the shipping line remains one eligible ordinary candidate; it must never claim a shipment just happened.
- `DialoguePanel` renders the existing social result dictionary and already supports one-line ordinary dialogue plus the player-paced two-line Close Friend sequence.
- `WorldShell` only coordinates session results into the existing dialogue panel. It does not need a new event path.
- The current save already persists day, weather, shipped totals, and relationship state, so the same restored state can choose the same line without storing dialogue history.

Extend those owners only. Do not route greetings through `ContentRules`; that owner remains tutorial-specific.

## Bounded authored content

Keep the current normal line as slot 0 at every villager/tier and add exactly two more normal lines beside it. Add exactly one rainy, one lifetime-sold, and one Days 12-14 market reaction per villager.

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

**Settled shipment / lifetime-sold:**

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

**Settled shipment / lifetime-sold:**

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

**Settled shipment / lifetime-sold:**

- "Your produce is going out now. The farm touches more than your own day."

**Days 12-14:**

- "The market is almost here. You will see who noticed your season."

## Content rules

- Add `MARKET_DIALOGUE_START_DAY := 12` in `VillagerRules` beside the relationship thresholds.
- Shipping flavor requires at least one crop in the settled lifetime `_shipped_counts`.
- Harvested inventory and pending shipment never qualify.
- Do not claim a shipment happened "today", was the player's first shipment, or happened once. Those claims would require new state.
- Market reactions are eligible when `day >= MARKET_DIALOGUE_START_DAY`; in the current 14-day game that means Days 12-14.
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

### Public helper contract

Keep the old accessor only for the original HPA-595 oracle and static fixtures:

`dialogue_line(id, level) -> String`

It returns `NORMAL_DIALOGUE[id][level][0]` and is no longer the production talk selector.

Add exactly two ordinary-dialogue helpers:

`ordinary_dialogue_candidates(id, level, day, is_rainy, has_settled_shipment) -> Array[String]`

`ordinary_dialogue_line(id, level, day, is_rainy, has_settled_shipment) -> String`

The candidate helper is intentionally public so tests can pin overlap ordering directly rather than searching for a day whose modulo happens to land on a contextual slot.

Both context flags are booleans. `VillagerRules` does not need the full weather enum or a session snapshot.

### Eligible ordinary set

`ordinary_dialogue_candidates()` returns candidates in one fixed order:

1. the three normal lines for the current relationship tier;
2. rainy reaction when `is_rainy`;
3. lifetime-sold reaction when `has_settled_shipment`;
4. market reaction when `day >= MARKET_DIALOGUE_START_DAY`.

This order is part of the deterministic contract.

### Deterministic choice

`ordinary_dialogue_line()` chooses:

`candidates[posmod((day - 1) + int(villager_id), candidates.size())]`

Why this shape:

- same state always returns the same greeting;
- baseline sunny/unshipped days rotate through the three normal options;
- different villagers do not all land on the same slot on the same day;
- no gameplay RNG, weather RNG, timestamp, process hash, or persisted history is needed;
- restoring equivalent state naturally reproduces the same result.

Contextual lines join the ordinary candidate set rather than overriding one another. Rain, lifetime-sold, and market can overlap without a priority ladder or extra event state.

## GameSession wiring

Keep `talk_to()` as the only social command owner.

The order stays:

1. reject inactive day / wrong villager target;
2. award the first valid daily talk point if not already awarded;
3. calculate the relationship level from the updated points;
4. if Close Friend is now reached and its event is unseen, mark it seen and return the existing two-line Close Friend sequence;
5. otherwise derive narrow read-only context and call `VillagerRules.ordinary_dialogue_line()`.

The ordinary branch passes only:

- villager id;
- post-talk relationship level;
- `_day`;
- `_weather == GameRules.Weather.RAINY`;
- `has_settled_shipment`, derived as true when any element of `_shipped_counts` is greater than zero.

Do not reuse a snapshot-shaped generic count helper. Do not pass the full session snapshot or raw weather enum into `VillagerRules`.

The existing social result dictionary stays unchanged:

- `code`
- `lines`
- `points_gained`
- `gift_reaction`
- `close_friend_sequence`

No new result field is required.

## Existing call-site contract

The selector deliberately changes ordinary spoken lines, so existing tests must stop using `dialogue_line()` as the production-talk oracle.

Required updates:

- Session tests that assert ordinary `talk_to()["lines"]` compare against `ordinary_dialogue_line(...)`.
- `test_june_reaches_close_friend_and_special_sequence_once()` updates any post-event ordinary-line assertion to the new selector.
- `test_all_villagers_route_through_same_direct_interaction_path()` must expect the selector on Day 1. Mira lands on normal slot 0, Rowan slot 1, and June slot 2 with the current formula.
- HPA-595 exact-content tests and static visual fixtures may continue calling `dialogue_line(id, level)` because that accessor intentionally means slot 0.

Do not weaken those assertions to "non-empty line"; point them at the new policy.

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

1. restore the live session to 14 points with one favourite harvested crop;
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

Talking must not call `_weather_roll`, `randf()`, or any other RNG source. Weather RNG remains sleep-only. Reuse the existing counter-callable testing pattern to prove a talk does not consume a weather roll.

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

Do not create a new visual golden merely because text changed. Add focused visual evidence only if the panel layout itself changes, which is not expected.

## Verification strategy

### VillagerRules

Cover only rules-owned facts:

- three villagers;
- three relationship tiers;
- exactly three normal lines per tier;
- all existing slot-0 lines unchanged;
- all 27 new authored lines present in the intended tables;
- `dialogue_line()` returns slot 0 only;
- exact candidate ordering;
- baseline sunny/unshipped rotation across successive days;
- stable output for identical inputs;
- different villager offsets;
- rainy boolean absent/present;
- settled-shipment boolean absent/present;
- market candidate absent before `MARKET_DIALOGUE_START_DAY` and present on the start day and Day 14;
- overlapping rainy + shipped + market preserves the fixed candidate order;
- selector equals the documented `posmod` choice from that candidate array.

Do not put harvested-vs-pending-vs-settled session facts in `VillagerRules` tests.

### GameSession

Pin production wiring, including direct line assertions:

- Day-1 sunny/unshipped Mira `talk_to()["lines"]` equals `ordinary_dialogue_line(...)`.
- A restored rainy state returns the helper-selected line and does not mutate weather.
- On the same day/weather, harvested-only and pending-only state both pass `has_settled_shipment == false`; restored settled shipped totals pass true.
- An 11 -> 12 first-talk threshold uses the Friend tier after awarding the talk point.
- First talk/repeat talk point semantics remain unchanged.
- Talk does not consume the injected weather-roll callable.
- Restoring an equivalent state into a fresh session returns the same ordinary line.
- Unseen Close Friend event still preempts ordinary selection.
- Once seen, Close Friend ordinary dialogue uses the new selector.
- Gift limits, favourite bonus, and failure atomicity remain unchanged.

Prepare isolation cases with `state()` / `restore_state()` rather than `sleep()` when the test is about selector inputs; sleep changes day, weather, and settlement together.

### Integration

Extend the existing social integration coverage rather than adding a second harness:

- update the existing all-villager Day-1 line assertions to the selector;
- restore prepared state into `world._session` before the live interaction flow;
- ordinary talk opens the existing panel with the selector-owned line;
- ordinary talk -> favourite gift -> repeat talk crosses into the unseen Close Friend event;
- Close Friend Continue/Esc behavior remains unchanged;
- no extra modal or world-input path is added;
- review the longest Mira/Rowan/June lines at the shipped 640x360 window.

Run worktree GUT suites during TDD. The repository clean verifier archives committed HEAD, so run `./tools/verify-clean.sh` only after committing the implementation state that is meant to be verified. Run `git diff --check` before the final implementation commit and again before leaving draft.

## Risks

The primary regression risk is stale `dialogue_line()` call sites: the new villager offset intentionally changes Rowan and June's Day-1 ordinary lines and changes later-day ordinary assertions. Explicitly update those tests to the selector rather than weakening them.

Text wrapping is lower risk. Existing dialogue already supports similarly long lines; manual 640x360 review is sufficient unless the panel layout actually changes.

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
