# Phoenix Contextual Village Dialogue Implementation Plan

**Linear:** HPA-461  
**Branch:** `agent/hpa-461-contextual-village-dialogue-plan`  
**Spec:** `docs/superpowers/specs/2026-09-19-phoenix-contextual-village-dialogue-design.md`

**Goal:** Give Mira, Rowan, and June deterministic relationship-tier variety plus rainy, lifetime-sold, and Days 12-14 reactions while preserving the current relationship economy, Close Friend event, persistence, and dialogue UI.

**Architecture:** Keep authored content plus the pure candidate/selection policy in `VillagerRules`. Keep `GameSession.talk_to()` as the only mutable social authority and pass only day, `is_rainy`, and `has_settled_shipment` into the selector. Reuse the existing social result dictionary and `DialoguePanel`; add no new state or UI subsystem.

## Global constraints

- One ticket, one branch, one PR. Implementation continues on this same draft PR after planning review.
- Exactly 27 new lines: 18 extra normal lines and 9 contextual lines.
- Keep every current normal slot-0 line, gift line, Close Friend line, and finale line unchanged.
- Shipping flavor comes only from lifetime settled `_shipped_counts`; harvested and pending crops do not qualify.
- Keep the unseen Close Friend sequence above ordinary selection.
- No dialogue history, RNG, new save field, schema change, event bus, dialogue graph, localization framework, speech bubble, new image, or new SFX.
- Prefer shortening copy over changing the existing 640x360 dialogue layout.
- Do not use `ContentRules` as a greeting owner or reuse snapshot-shaped tutorial helpers.

## Task 1: Expand VillagerRules and land the selector as one green unit

**Files:**

- `scripts/game/villager_rules.gd`
- `tests/unit/test_villager_rules.gd`

### 1.1 RED — pin the authored and public API contract

Add focused tests before changing the rules:

- [ ] Each villager still has three relationship tiers.
- [ ] Each tier now has exactly three normal lines.
- [ ] Normal slot 0 exactly matches the current HPA-595 oracle line.
- [ ] Slots 1 and 2 match the 18 new normal lines in the design spec.
- [ ] `RAINY_DIALOGUE`, `SHIPPED_DIALOGUE`, and `MARKET_DIALOGUE` each contain exactly one line per villager.
- [ ] The nine contextual lines match the design spec exactly.
- [ ] Existing gift, Close Friend, and finale content remains unchanged.
- [ ] `MARKET_DIALOGUE_START_DAY == 12`.
- [ ] `dialogue_line(id, level)` means slot 0 only.
- [ ] Public helpers exist with the narrow signatures:
  - `ordinary_dialogue_candidates(id, level, day, is_rainy, has_settled_shipment) -> Array[String]`
  - `ordinary_dialogue_line(id, level, day, is_rainy, has_settled_shipment) -> String`

### 1.2 RED/GREEN — reshape tables and add candidate + selector helpers together

Land the table shape and accessors in the same green step so the HPA-595 oracle never sits broken between checkpoints:

- [ ] Change `NORMAL_DIALOGUE[id][level]` from a string to an array of three strings.
- [ ] Keep `dialogue_line(id, level)` returning slot 0 for the exact-content oracle and static fixtures only.
- [ ] Add `MARKET_DIALOGUE_START_DAY := 12` beside the relationship thresholds.
- [ ] Add the three villager-indexed contextual arrays.
- [ ] Implement `ordinary_dialogue_candidates()` with exact order: three normals, rainy when `is_rainy`, shipped when `has_settled_shipment`, market when `day >= MARKET_DIALOGUE_START_DAY`.
- [ ] Implement `ordinary_dialogue_line()` as `candidates[posmod((day - 1) + int(id), candidates.size())]`.
- [ ] Baseline sunny/unshipped days rotate through the three normal options.
- [ ] Identical arguments return the identical line.
- [ ] Villager identity offsets the same-day choice.
- [ ] Overlapping rainy + shipped + market tests assert the candidate array ordering directly.
- [ ] Do not introduce a dialogue entry class, condition object, registry, resource file, or authoring layer.

**Checkpoint:** run the VillagerRules worktree GUT suite before touching `GameSession`.

## Task 2: Wire talk_to() and pin the production call site

**Files:**

- `scripts/game/game_session.gd`
- `tests/unit/test_game_session.gd`

### 2.1 RED — require talk_to()["lines"] to use the selector

Add focused production-boundary assertions:

- [ ] Day-1 sunny/unshipped Mira result equals:
  `[VillagerRules.ordinary_dialogue_line(id, level, day, false, false)]`.
- [ ] A restored rainy state returns the helper-selected line without changing weather.
- [ ] On the same restored day/weather, harvested-only state returns the false-shipping helper result.
- [ ] On that same day/weather, pending-only state also returns the false-shipping helper result.
- [ ] On that same day/weather, non-zero restored `shipped` totals return the true-shipping helper result.
- [ ] An 11 -> 12 first-talk transition uses the Friend tier in the helper call after awarding +1.
- [ ] First valid talk still gives exactly +1 once per day; repeat talk gives +0.
- [ ] A talk does not invoke the injected weather-roll counter callable.
- [ ] Restoring equivalent state into a fresh session returns the same ordinary line.

Use `state()` / `restore_state()` for selector-input isolation. Do not use `sleep()` to build these cases because sleep simultaneously changes day, weather, and settlement. Do not add a test-only production setter.

### 2.2 GREEN — change only the ordinary branch

Keep the current order in `talk_to()`:

1. existing active-day/target guards;
2. existing first-talk point mutation;
3. existing post-point relationship-level calculation;
4. existing unseen Close Friend branch;
5. ordinary line selection.

For step 5 only:

- [ ] derive `is_rainy := _weather == GameRules.Weather.RAINY`;
- [ ] derive `has_settled_shipment` as true when any `_shipped_counts[i] > 0`;
- [ ] call `VillagerRules.ordinary_dialogue_line(villager_id, level, _day, is_rainy, has_settled_shipment)`;
- [ ] keep the current one-line `lines` array and social result dictionary.

Do not pass the whole snapshot or raw weather enum into `VillagerRules`. Do not reuse a snapshot-dictionary count helper.

### 2.3 RED/GREEN — protect Close Friend precedence and update stale oracles

Pin and update the existing tests rather than weakening them:

- [ ] Reaching 18+ on the first daily talk still returns the existing two-line event.
- [ ] Reaching 18+ through a gift does not mark the event seen.
- [ ] The next repeat talk can trigger that unseen event with 0 talk points.
- [ ] After the event is seen, later Close Friend talks use `ordinary_dialogue_line()` and never replay the event.
- [ ] Update `test_june_reaches_close_friend_and_special_sequence_once()` ordinary-line expectations to the selector.
- [ ] Any other session `talk_to()["lines"]` assertion uses `ordinary_dialogue_line()`, not `dialogue_line()`.
- [ ] Keep `dialogue_line()` only where the test explicitly means authored slot 0.

**Checkpoint:** run VillagerRules + GameSession worktree GUT suites. No UI work should be necessary at this point.

## Task 3: Update the existing shell contract and prove the live flow

**Files:**

- `tests/integration/test_gameplay_shell.gd`
- planning docs already in this PR
- runtime UI files only if a concrete regression proves the reviewed assumption wrong

### 3.1 Update the existing all-villager direct-interaction assertion

Extend `test_all_villagers_route_through_same_direct_interaction_path()` instead of loosening it:

- [ ] Keep the shared E-interaction/panel/name/role checks.
- [ ] Calculate each expected Day-1 Stranger line through `ordinary_dialogue_line(id, STRANGER, 1, false, false)`.
- [ ] This intentionally proves the villager offset live: Mira slot 0, Rowan slot 1, June slot 2.
- [ ] Do not replace the exact line check with non-empty/contains assertions.

### 3.2 Add the compact ordinary talk -> gift -> Close Friend flow on the real session

Prepare the live world by restoring state into `world._session`, not by mutating a detached snapshot:

- [ ] Start from `world._session.state()`.
- [ ] Set one villager to 14 relationship points and seed one favourite harvested crop in that state.
- [ ] Validate/restore the prepared state into `world._session`.
- [ ] Interact: ordinary talk gives +1 and opens the existing Friend-tier selector-owned line.
- [ ] Give the favourite gift: relationship crosses Close Friend threshold.
- [ ] Close the panel.
- [ ] Interact again the same day: repeat talk gives +0 and opens the unseen two-line Close Friend sequence.
- [ ] Continue through the sequence; verify it is marked seen.
- [ ] Talk again and verify ordinary Close Friend selection returns rather than replaying the event.
- [ ] Existing world-input gating, gift controls, Esc behavior, and Continue behavior remain intact.

Do not add a production setter and do not create a new E2E harness.

### 3.3 640x360 text review

Review the longest new line for each villager in the existing native panel:

- [ ] Mira: lifetime-sold line.
- [ ] Rowan: Close Friend or market line.
- [ ] June: Close Friend or lifetime-sold line.

If any line clips or becomes awkward, shorten the sentence in `VillagerRules` and update the exact-content unit expectation. Do not resize the panel or reduce font size.

No new visual golden is expected when layout is unchanged.

### 3.4 Verification sequence

During implementation:

- [ ] Run the affected worktree GUT suites after each RED/GREEN checkpoint.
- [ ] Run `git diff --check` before the implementation commit.

After committing the implementation state intended for verification:

- [ ] Run `./tools/verify-clean.sh`; it archives committed HEAD, so do not treat it as a worktree TDD command.
- [ ] Re-run `git diff --check`.
- [ ] Confirm the visual suite remains unchanged unless an actual layout change was required.

Keep content review, implementation, tests, and verification on this one HPA-461 PR.

## Risks

Primary: stale `dialogue_line()` production/test oracles. The new Day + villager formula intentionally makes Rowan and June differ from slot 0 on Day 1 and changes later-day ordinary expectations. Point those assertions at `ordinary_dialogue_line()`; do not weaken them.

Secondary: content wrapping. Existing dialogue already supports similarly long copy, so manual 640x360 review is enough unless layout actually changes.

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
