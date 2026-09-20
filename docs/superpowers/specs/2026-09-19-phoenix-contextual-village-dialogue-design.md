# Phoenix Contextual Village Dialogue Design

**Linear:** HPA-461  
**Repository:** `cwchanap/phoenix`  
**Branch:** `agent/hpa-461-contextual-village-dialogue-plan`  
**Base reviewed:** `main` at `207511222970f0f171b400da901a9f9bfca4e252`

## Goal

Make Mira, Rowan, and June react to the current farming run and stop repeating one line per relationship tier, without adding a dialogue engine, conversation history, new state, new art, or new interaction mode.

This is a content-and-selection-policy slice. The existing relationship rules, full dialogue panel, gifting flow, Close Friend event, save shape, and E/Esc controls remain authoritative.

## Current seams to preserve

- `VillagerRules` owns villager identity, relationship thresholds, authored speech, gift reactions, finale lines, and the new pure ordinary-dialogue policy.
- `GameSession.talk_to()` remains the only social talk mutation boundary.
- `GameSession` already owns the exact context this ticket needs: current day, current weather, lifetime settled `_shipped_counts`, and relationship state.
- Harvested inventory, pending shipment, and settled shipped totals remain separate. Only lifetime settled shipped totals may enable shipped flavor.
- Settled shipped totals are sticky lifetime state, not a one-shot event. The shipped line joins the ordinary candidate pool; it must never claim a shipment just happened.
- `DialoguePanel` continues to render the existing social result dictionary and existing player-paced Close Friend sequence.
- `WorldShell` continues to coordinate session results into the current panel; it gets no new social state or event path.
- The current save already persists every selector input, so equivalent restored state reproduces the same line without dialogue history.

Do not route greetings through `ContentRules`; tutorial relevance remains a separate owner.

## Bounded authored content

Keep each current normal line as slot 0 in the reshaped table and add exactly two normal lines beside it. Add exactly one rainy, one lifetime-sold, and one Days 12-14 market reaction per villager.

That is 27 new lines total.

### Mira — seeds, trade, and farm economics

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

**Lifetime-sold:**

- "Produce has left your farm now. Growing and selling are different skills."

**Days 12-14:**

- "The market is close. Keep some coin ready for what comes next."

### Rowan — farming effort and field craft

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

**Lifetime-sold:**

- "You have sent real harvest out now. That means the farm is working."

**Days 12-14:**

- "The market is close. Finish what will be ready before you plant more."

### June — belonging and village life

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

**Lifetime-sold:**

- "Your produce is going out now. The farm touches more than your own day."

**Days 12-14:**

- "The market is almost here. You will see who noticed your season."

## Content rules

- Add `MARKET_DIALOGUE_START_DAY := 12` beside the relationship thresholds.
- Shipping flavor is eligible iff any lifetime settled `_shipped_counts[i] > 0`.
- Harvested and pending counts never qualify.
- Never claim a shipment happened "today", was the first shipment, or happened once.
- Market flavor is eligible when `day >= MARKET_DIALOGUE_START_DAY`.
- Rain flavor is eligible only for rainy current weather.
- Normal dialogue uses the relationship level after the current first-talk point is awarded.
- The unseen Close Friend sequence remains above every ordinary candidate.
- Gift lines, gift values, relationship thresholds, Close Friend event lines, and finale lines remain unchanged.

## Pure selection policy

### Authored table shape

Reshape:

`NORMAL_DIALOGUE[villager_id][relationship_level][normal_slot]`

Each tier contains exactly three strings. Slot 0 is the existing HPA-595 line.

Add the villager-indexed arrays:

- `RAINY_DIALOGUE`
- `SHIPPED_DIALOGUE`
- `MARKET_DIALOGUE`

There is no dialogue-entry class, condition object, tag registry, resource file, or authoring framework.

### Public API

Expose only the real ordinary-dialogue API:

`ordinary_dialogue_candidates(id, level, day, is_rainy, has_settled_shipment) -> Array[String]`

`ordinary_dialogue_line(id, level, day, is_rainy, has_settled_shipment) -> String`

Delete the old `dialogue_line(id, level)` accessor. Once ordinary speech depends on day/context, a public slot-0 accessor would be a stale parallel representation that future production code could misuse.

Exact-content tests that need slot 0 index `NORMAL_DIALOGUE[id][level][0]` directly.

### Candidate order

`ordinary_dialogue_candidates()` returns:

1. the three current-tier normal lines;
2. rainy line when `is_rainy`;
3. lifetime-sold line when `has_settled_shipment`;
4. market line when `day >= MARKET_DIALOGUE_START_DAY`.

The two context inputs are booleans. `VillagerRules` does not receive a session snapshot or raw weather enum.

### Deterministic choice

`ordinary_dialogue_line()` returns:

`candidates[posmod((day - 1) + int(villager_id), candidates.size())]`

Same inputs therefore always reproduce the same line, while successive eligible days and villager identity rotate the pool without gameplay/weather RNG or history state.

Context eligibility does not guarantee a contextual line. This is intentional: contextual lines join the pool rather than override normal relationship speech.

## Distribution review and literal acceptance table

The policy is tested internally in `VillagerRules`, but session/UI boundaries must assert literal player-visible lines rather than recomputing expected values through the helper under test.

### Day 1 — sunny, no settled shipment, Stranger

| Villager | Literal player-visible line |
| --- | --- |
| Mira | "The seed counter is open whenever you need it." |
| Rowan | "A straight row is nice, but a watered row is useful." |
| June | "You will learn which corners feel familiar before long." |

### Day 12 — rainy, settled shipment, Stranger

There are six eligible candidates. The fixed formula deliberately produces:

| Villager | Literal player-visible line |
| --- | --- |
| Mira | "The market is close. Keep some coin ready for what comes next." |
| Rowan | "Watered soil tells you what tomorrow will bring." |
| June | "The village notices steady footsteps more than grand entrances." |

This distribution is accepted. A context-rich day does not force every villager to mention rain/shipping/market; that would require weighting or precedence machinery that this ticket intentionally avoids.

For derivation coverage, a Day-12 rainy Mira with harvested-only or pending-only state still has `has_settled_shipment == false` and therefore says:

"Turnips are quick. Potatoes ask for a little more patience."

The equivalent state with any settled shipped count says the Day-12 market line above.

## GameSession wiring

Keep `talk_to()` in its current order:

1. active-day / target guards;
2. first valid daily talk point;
3. relationship level from updated points;
4. unseen Close Friend sequence;
5. ordinary selector.

Step 5 derives:

- `is_rainy := _weather == GameRules.Weather.RAINY`;
- `has_settled_shipment := any _shipped_counts[i] > 0`.

It then calls `VillagerRules.ordinary_dialogue_line(...)` and returns the same one-line social result dictionary.

Do not pass the snapshot, raw weather enum, harvested counts, or pending counts into `VillagerRules`. Do not reuse the snapshot-shaped private count helper in `ContentRules`.

## Relationship and interaction semantics

Unchanged:

- first valid talk per villager/day = +1;
- repeat talk = +0;
- one gift per villager/day;
- normal gift = +3;
- favourite gift = +5 total;
- Friend = 12;
- Close Friend = 18;
- unseen Close Friend two-line event appears once and preempts ordinary dialogue;
- gifting can cross the threshold but does not mark the Close Friend event seen;
- later Close Friend talks use the ordinary selector;
- E/Esc/Continue behavior stays unchanged.

The existing `test_june_reaches_close_friend_and_special_sequence_once()` already owns the state-machine proof. Update its post-event ordinary line to the literal selected by the new policy; do not add a second full integration copy.

On its existing Day-3 sunny/no-shipment state, June's post-event Close Friend line is:

"You do not look like a newcomer when you walk through town anymore."

## Persistence and RNG

No save-schema change and no new persisted line/history state.

The selector uses already-persisted day, weather, shipped totals, relationship points, and Close Friend seen state.

Talking must not invoke `_weather_roll` or other RNG. Although the new selector does not approach weather-roll code, keep one focused counter-callable assertion because HPA-461 explicitly requires that dialogue selection not advance weather RNG.

Equivalent restored state must return the same literal line.

## Visual fixture and golden truthfulness

The existing `07-dialogue` fixture declares:

- Day 3;
- sunny;
- zero settled shipment;
- Mira at Friend.

Production selection for that exact state is Friend normal slot 2:

"A mixed crop shelf keeps the counter interesting."

Update `tests/visual/ui_fixture_factory.gd` to call `ordinary_dialogue_line(SHOPKEEPER, FRIEND, 3, false, false)`, then natively regolden the existing `tests/visual/goldens/07-dialogue.png`.

This is not a new visual state and does not justify a panel/layout change. It makes the existing golden truthful for its declared state.

The line label remains the current autowrapping 640x360 panel. Review long new copy manually and shorten wording if needed; do not resize the panel or reduce font size.

## Verification strategy

### VillagerRules

Pin:

- exact three-slot table content for every villager/tier;
- all 27 new strings;
- existing slot-0 strings directly through `NORMAL_DIALOGUE[id][level][0]`;
- contextual table sizes/content;
- `MARKET_DIALOGUE_START_DAY == 12`;
- exact candidate order;
- true/false rain and shipped gates independently;
- Day 11 / 12 / 14 market eligibility;
- stable identical-input result;
- day and villager rotation;
- overlap candidate array;
- helper output equals the documented `posmod` index.

### GameSession

Assert player-visible literals, not helper-vs-helper tautologies:

- Day-1 sunny/unshipped literal lines for all three villagers;
- Day-12 rainy + settled-shipment literal lines for all three villagers;
- Day-12 rainy Mira harvested-only and pending-only both return the literal no-shipment line;
- the equivalent Mira settled-shipment state returns the literal market line;
- 11 -> 12 points uses the Friend-tier literal after +1;
- first/repeat talk point behavior unchanged;
- weather-roll counter remains untouched by talk;
- equivalent restored state returns the same literal;
- existing Close Friend state-machine test uses the new literal post-event line.

Use `state()` / `restore_state()` to isolate day/weather/count context rather than `sleep()`, which changes several inputs together.

### Integration

Keep the existing all-villager direct-interaction test and update its Day-1 line assertions to the three literals above. That is the one new live fact this ticket needs: production `talk_to()` reaches the existing panel with the selected line.

Do not add a new talk -> gift -> Close Friend integration flow. Existing session and shell tests already cover relationship threshold/event behavior, gift round-trip, and Close Friend panel progression.

### Visual

Update only the existing dialogue fixture and `07-dialogue.png` golden. No additional visual state.

### Verification sequence

Use worktree GUT during RED/GREEN development. `./tools/verify-clean.sh` archives committed `HEAD`, so run it only after committing the implementation state intended for verification.

Run `git diff --check` before that implementation commit and again before leaving draft.

## Risks

Primary: stale `dialogue_line()` call sites. Delete the accessor and move all current users either to the real selector or direct table indexing where a test explicitly inspects authored slot 0.

Secondary: session assertions accidentally recomputing expectations through the selector. Boundary tests must pin literals.

Lower risk: text wrapping. Existing same-label copy is already comparable in length; manual 640x360 review is enough unless layout actually changes.

## Expected implementation files

Runtime:

- `scripts/game/villager_rules.gd`
- `scripts/game/game_session.gd`

Unit/integration tests:

- `tests/unit/test_villager_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`

Visual fixture/evidence:

- `tests/visual/ui_fixture_factory.gd`
- `tests/visual/goldens/07-dialogue.png`

Planning docs remain in this PR. No `DialoguePanel`, `GameHud`, persistence, scene, image asset, audio, README, or CLAUDE change is expected.

## Non-goals

No new NPCs, schedules, pathing, quests, request board, romance, voice acting, speech bubbles, AI-authored runtime text, localization framework, dialogue graph, generic event system, dialogue-history persistence, save migration, relationship rebalance, new ending, new portrait, new generated art, or new SFX.
