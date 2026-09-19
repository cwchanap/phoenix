# Phoenix Contextual Village Dialogue Implementation Plan

**Linear:** HPA-461  
**Branch:** `agent/hpa-461-contextual-village-dialogue-plan`  
**Spec:** `docs/superpowers/specs/2026-09-19-phoenix-contextual-village-dialogue-design.md`

**Goal:** Give Mira, Rowan, and June deterministic relationship-tier variety plus rainy, settled-shipment, and Days 12-14 reactions while preserving the current relationship economy, Close Friend event, persistence, and dialogue UI.

**Architecture:** Keep authored content and the pure candidate/selection policy in `VillagerRules`. Keep `GameSession.talk_to()` as the only mutable social authority and pass only day, weather, and a settled-shipment boolean into the selector. Reuse the existing social result dictionary and `DialoguePanel`; add no new state or UI subsystem.

## Global constraints

- One ticket, one branch, one PR. Implementation continues on this same draft PR after planning review.
- Exactly 27 new lines: 18 extra normal lines and 9 contextual lines.
- Keep every current normal slot-0 line, gift line, Close Friend line, and finale line unchanged.
- Shipping context comes only from settled `_shipped_counts`; harvested and pending crops do not qualify.
- Keep the unseen Close Friend sequence above ordinary selection.
- No dialogue history, RNG, new save field, schema change, event bus, dialogue graph, localization framework, speech bubble, new image, or new SFX.
- Prefer shortening copy over changing the existing 640x360 dialogue layout.

## Task 1: Expand VillagerRules and pin deterministic selection

**Files:**

- `scripts/game/villager_rules.gd`
- `tests/unit/test_villager_rules.gd`

### 1.1 RED — pin the new authored table contract

Add focused tests before changing the rules:

- [ ] Each villager still has three relationship tiers.
- [ ] Each tier now has exactly three normal lines.
- [ ] Normal slot 0 exactly matches the current HPA-595 oracle line.
- [ ] Slots 1 and 2 match the 18 new normal lines in the design spec.
- [ ] `RAINY_DIALOGUE`, `SHIPPED_DIALOGUE`, and `MARKET_DIALOGUE` each contain exactly one line per villager.
- [ ] The nine contextual lines match the design spec exactly.
- [ ] Existing gift, Close Friend, and finale content remains unchanged.

### 1.2 GREEN — reshape only the fixed content tables

- [ ] Change `NORMAL_DIALOGUE[id][level]` from a string to an array of three strings.
- [ ] Add the three villager-indexed contextual arrays.
- [ ] Do not introduce a dialogue entry class, condition object, registry, resource file, or authoring layer.

### 1.3 RED/GREEN — add one pure eligible-set helper and selector

Pin the exact policy:

- [ ] Candidate order is three tier-normal lines, then rainy when eligible, then settled-shipment when eligible, then market when day >= 12.
- [ ] Day 11 never includes market; Days 12 and 14 do.
- [ ] Sunny/unshipped baseline days rotate through the three normal options.
- [ ] Identical arguments return the identical line.
- [ ] Villager identity offsets the same-day choice.
- [ ] Overlapping rainy + shipped + market context preserves the fixed candidate order.
- [ ] The final index is `posmod((day - 1) + int(villager_id), candidates.size())`.

Implement the smallest pure API needed by those tests. Keep all selection logic in `VillagerRules`.

**Checkpoint:** run the VillagerRules unit suite before touching `GameSession`.

## Task 2: Feed narrow session context without changing social semantics

**Files:**

- `scripts/game/game_session.gd`
- `tests/unit/test_game_session.gd`

### 2.1 RED — pin the session boundary

Add focused tests for:

- [ ] First valid talk still gives exactly +1 once per day.
- [ ] Repeat talk still gives +0.
- [ ] Relationship tier is still calculated after that first-talk point.
- [ ] Harvested-only inventory does not enable the shipping reaction.
- [ ] Pending shipment does not enable the shipping reaction.
- [ ] After sleep settles shipment into `shipped`, shipping context is enabled.
- [ ] Rainy session context reaches the selector without changing weather.
- [ ] A talk does not invoke the injected weather-roll callable.
- [ ] Restoring an equivalent state into a fresh session returns the same ordinary line.

Use real state/restore and existing commands to prepare these cases. Do not add a test-only production setter or new persistence field.

### 2.2 GREEN — wire the current talk path

Keep the current order in `talk_to()`:

1. existing active-day/target guards;
2. existing first-talk point mutation;
3. existing post-point relationship-level calculation;
4. existing unseen Close Friend branch;
5. ordinary line selection.

For the ordinary branch only:

- [ ] derive `has_settled_shipment` from `_shipped_counts`;
- [ ] pass villager id, level, `_day`, `_weather`, and that boolean to `VillagerRules`;
- [ ] keep the current one-line `lines` array and social result dictionary.

Do not pass the whole snapshot into `VillagerRules`.

### 2.3 RED/GREEN — protect Close Friend precedence

Pin:

- [ ] Reaching 18+ on the first daily talk still returns the existing two-line event.
- [ ] Reaching 18+ through a gift does not mark the event seen.
- [ ] The next repeat talk can trigger that unseen event with 0 talk points.
- [ ] After the event is seen, later Close Friend talks use the new ordinary selector and never replay the event.

**Checkpoint:** run VillagerRules + GameSession unit suites. No UI work should be necessary at this point.

## Task 3: Prove the existing panel flow and finish the single PR

**Files:**

- `tests/integration/test_gameplay_shell.gd`
- planning docs already in this PR
- runtime UI files only if a concrete regression proves the reviewed assumption wrong

### 3.1 Extend the existing social integration path

Add one compact flow using the current world/HUD/session seams:

- [ ] Seed one villager to 14 points and give the player one favourite harvested crop.
- [ ] Interact: ordinary talk gives +1 and opens the existing dialogue panel.
- [ ] Give the favourite gift: relationship crosses Close Friend threshold.
- [ ] Close the panel.
- [ ] Interact again the same day: repeat talk gives +0 and opens the unseen two-line Close Friend sequence.
- [ ] Continue through the sequence; verify it is marked seen and does not replay.
- [ ] Existing world-input gating, gift controls, Esc behavior, and Continue behavior remain intact.

Do not create a new E2E harness for deterministic text selection; the current unit + gameplay-shell integration layers already cover the ownership boundaries.

### 3.2 640x360 text review

Review the longest new line for each villager in the existing native panel:

- [ ] Mira: settled-shipment line.
- [ ] Rowan: Close Friend or market line.
- [ ] June: Close Friend or settled-shipment line.

If any line clips or becomes awkward, shorten the sentence in `VillagerRules` and update the exact-content unit expectation. Do not resize the panel or reduce font size.

No new visual golden is expected when layout is unchanged.

### 3.3 Final verification

Run the affected unit/integration suites and the repository's existing clean verifier:

- [ ] VillagerRules tests pass.
- [ ] GameSession social tests pass.
- [ ] Gameplay-shell social integration tests pass.
- [ ] Existing visual suite remains unchanged unless an actual layout change was required.
- [ ] `./tools/verify-clean.sh` passes.
- [ ] `git diff --check` passes.

Keep content review, implementation, tests, and verification on this one HPA-461 PR.

## Expected final diff

Expected runtime changes:

- `scripts/game/villager_rules.gd`
- `scripts/game/game_session.gd`

Expected test changes:

- `tests/unit/test_villager_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`

Expected planning docs:

- `docs/superpowers/specs/2026-09-19-phoenix-contextual-village-dialogue-design.md`
- `docs/superpowers/plans/2026-09-19-phoenix-contextual-village-dialogue.md`

Anything beyond those files needs a concrete reason discovered during implementation. In particular, do not proactively touch `DialoguePanel`, `GameHud`, persistence, scenes, assets, README, or CLAUDE.
