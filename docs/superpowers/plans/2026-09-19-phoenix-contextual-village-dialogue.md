# Phoenix Contextual Village Dialogue Implementation Plan

**Linear:** HPA-461
**Branch:** `agent/hpa-461-contextual-village-dialogue-plan`
**Spec:** `docs/superpowers/specs/2026-09-19-phoenix-contextual-village-dialogue-design.md`

**Goal:** Give Mira, Rowan, and June deterministic relationship-tier variety plus rainy, lifetime-sold, and Days 12-14 reactions while preserving the current relationship economy, Close Friend event, persistence, and dialogue UI.

**Architecture:** Keep fixed speech tables and the pure candidate/selector policy in `VillagerRules`. Keep `GameSession.talk_to()` as the only mutable social authority and pass only day plus two booleans into the selector. Delete the old context-free dialogue accessor rather than preserve a stale second representation. Reuse the existing social result dictionary/panel and existing social integration coverage.

## Global constraints

- One ticket, one branch, one PR. Implementation continues on this same draft PR after planning review.
- Exactly 27 new lines: 18 extra normal lines and 9 contextual lines.
- Keep every existing normal slot-0 string, gift line, Close Friend event line, and finale line unchanged.
- Shipping flavor derives only from lifetime settled `_shipped_counts`; harvested and pending crops do not qualify.
- No dialogue history, RNG selection, new save field, schema change, event bus, dialogue graph, localization framework, speech bubble, image asset, or SFX.
- No generic condition/dialogue abstraction.
- Prefer shortening copy over changing the 640x360 dialogue layout.
- Boundary tests assert literal speech. Helper-equality tests stay only where `VillagerRules` itself is under test.

## Task 1: Reshape VillagerRules and land the only ordinary selector

**Files:**

- `scripts/game/villager_rules.gd`
- `tests/unit/test_villager_rules.gd`

### 1.1 RED — pin authored content without the new API

First pin facts that compile against the current class:

- [ ] Each villager still has three relationship tiers.
- [ ] The expected new table shape is three normal strings per tier.
- [ ] Existing HPA-595 strings are expected at slot 0.
- [ ] Slots 1/2 match the 18 new normal lines in the spec.
- [ ] Rainy/shipped/market tables contain the nine exact contextual strings.
- [ ] Gift, Close Friend event, and finale content remains unchanged.
- [ ] `MARKET_DIALOGUE_START_DAY == 12`.

The new statics do not exist yet; in GDScript, tests that call missing statics are parser-red for the whole file. Keep that window short rather than treating it as a behavioral assertion.

### 1.2 RED/GREEN — add helper signatures, reshape tables, and test selector behavior together

In one runnable step:

- [ ] Reshape `NORMAL_DIALOGUE[id][level]` to three strings.
- [ ] Delete `dialogue_line(id, level)`.
- [ ] Exact-content tests read `NORMAL_DIALOGUE[id][level][0]` directly when they mean authored slot 0.
- [ ] Add `MARKET_DIALOGUE_START_DAY := 12`.
- [ ] Add `RAINY_DIALOGUE`, `SHIPPED_DIALOGUE`, and `MARKET_DIALOGUE`.
- [ ] Add:
  - `ordinary_dialogue_candidates(id, level, day, is_rainy, has_settled_shipment) -> Array[String]`
  - `ordinary_dialogue_line(id, level, day, is_rainy, has_settled_shipment) -> String`
- [ ] Candidate order is exactly: three normals, rainy, shipped, market when each context is eligible.
- [ ] Test `is_rainy=true/has_settled_shipment=false` and `false/true` independently so adjacent booleans cannot silently swap.
- [ ] Day 11 excludes market; Days 12 and 14 include it.
- [ ] Identical inputs are stable.
- [ ] Day/villager rotation uses `posmod((day - 1) + int(id), candidates.size())`.
- [ ] Context-saturated tests assert the candidate array directly before asserting the chosen index.
- [ ] Do not add a dialogue entry/condition object, registry, resource file, or authoring layer.

**Checkpoint:** run the VillagerRules worktree GUT suite.

## Task 2: Wire talk_to() and pin literal session behavior

**Files:**

- `scripts/game/game_session.gd`
- `tests/unit/test_game_session.gd`

### 2.1 RED — literal boundary table

Session tests must assert what the player hears without calling `ordinary_dialogue_line()` for the expected side.

Pin these Day-1 sunny/unshipped Stranger literals:

- [ ] Mira: `The seed counter is open whenever you need it.`
- [ ] Rowan: `A straight row is nice, but a watered row is useful.`
- [ ] June: `You will learn which corners feel familiar before long.`

Pin these Day-12 rainy + settled-shipment Stranger literals:

- [ ] Mira: `The market is close. Keep some coin ready for what comes next.`
- [ ] Rowan: `Watered soil tells you what tomorrow will bring.`
- [ ] June: `The village notices steady footsteps more than grand entrances.`

Also pin the session-owned derivation boundary on the same Day-12 rainy Mira state:

- [ ] harvested-only -> `Turnips are quick. Potatoes ask for a little more patience.`
- [ ] pending-only -> the same no-shipment literal;
- [ ] non-zero settled `shipped` -> the market literal above.

Pin post-point relationship selection:

- [ ] a Mira state at 11 points talks once to 12 and says Friend slot 0: `Your fields are starting to look dependable.`

Retain:

- [ ] first valid daily talk gives +1; repeat gives +0;
- [ ] the injected weather-roll counter is unchanged by talk, because the Linear acceptance explicitly requires no weather-RNG consumption;
- [ ] equivalent restored state reproduces the same literal line.

Use `state()` / `restore_state()` to prepare day/weather/count cases. Do not use `sleep()` as a selector fixture and do not add a production setter.

### 2.2 GREEN — change only talk_to()'s ordinary branch

Keep the current order:

1. active-day/target guards;
2. first-talk point;
3. relationship level from updated points;
4. unseen Close Friend event;
5. ordinary line.

At step 5 only:

- [ ] derive `is_rainy := _weather == GameRules.Weather.RAINY`;
- [ ] derive `has_settled_shipment` as any `_shipped_counts[i] > 0`;
- [ ] call `VillagerRules.ordinary_dialogue_line(villager_id, level, _day, is_rainy, has_settled_shipment)`;
- [ ] keep the existing one-line result shape.

No snapshot/raw weather enum enters `VillagerRules`. No harvested/pending count is passed to it.

### 2.3 Update the existing Close Friend session test, do not duplicate it

`test_june_reaches_close_friend_and_special_sequence_once()` already covers talk -> favourite gift -> threshold -> unseen event -> seen flag -> post-event ordinary speech.

Keep that test and change only its stale ordinary expectation:

- [ ] the existing Day-3 sunny/no-shipment post-event line is the literal:
  `You do not look like a newcomer when you walk through town anymore.`
- [ ] existing special-event lines/points/seen assertions remain unchanged.

**Checkpoint:** run VillagerRules + GameSession worktree GUT suites.

## Task 3: Update the one live speech proof and truthful visual fixture

**Files:**

- `tests/integration/test_gameplay_shell.gd`
- `tests/visual/ui_fixture_factory.gd`
- `tests/visual/goldens/07-dialogue.png`

### 3.1 Update the existing all-villager direct-interaction test

Keep `test_all_villagers_route_through_same_direct_interaction_path()` and replace its `dialogue_line()` oracle with the three Day-1 literals:

- [ ] Mira -> `The seed counter is open whenever you need it.`
- [ ] Rowan -> `A straight row is nice, but a watered row is useful.`
- [ ] June -> `You will learn which corners feel familiar before long.`

Keep the existing panel/name/role/world-input checks.

Do not add the previously planned talk -> gift -> Close Friend shell flow. Existing unit/integration tests already own that unchanged behavior.

### 3.2 Make the dialogue visual fixture represent production

The current visual fixture declares Day 3, sunny, no settled shipment, Mira Friend. Update `dialogue_result()` to obtain the real production line through:

`ordinary_dialogue_line(SHOPKEEPER, FRIEND, 3, false, false)`

The expected line is:

`A mixed crop shelf keeps the counter interesting.`

Then:

- [ ] capture `07-dialogue` natively at 640x360;
- [ ] review the new copy and the longest new lines manually;
- [ ] replace only `tests/visual/goldens/07-dialogue.png`;
- [ ] do not add a fifteenth visual state or touch `DialoguePanel` layout/font unless a real clipping defect appears.

### 3.3 Verification sequence

During implementation:

- [ ] run affected worktree GUT suites after each runnable RED/GREEN checkpoint;
- [ ] run `git diff --check` before the implementation commit.

After committing the intended implementation state:

- [ ] run `./tools/verify-clean.sh` because it archives committed `HEAD`;
- [ ] run the native visual verifier for the updated existing golden;
- [ ] re-run `git diff --check`.

Keep all implementation, content review, regolden, and verification on this single HPA-461 PR.

## Risks

Primary: retaining or recreating a context-free ordinary-line accessor. There must be one production selector, not a stale slot-0 public API.

Secondary: tautological boundary tests that call the selector on both sides. Session and shell expected speech stays literal.

Lower: copy wrapping. The existing 392x28 autowrapping label already carries similarly long Close Friend copy; manually review before considering any layout work.

## Expected final diff

Runtime:

- `scripts/game/villager_rules.gd`
- `scripts/game/game_session.gd`

Unit/integration:

- `tests/unit/test_villager_rules.gd`
- `tests/unit/test_game_session.gd`
- `tests/integration/test_gameplay_shell.gd`

Visual fixture/evidence:

- `tests/visual/ui_fixture_factory.gd`
- `tests/visual/goldens/07-dialogue.png`

Planning docs:

- `docs/superpowers/specs/2026-09-19-phoenix-contextual-village-dialogue-design.md`
- `docs/superpowers/plans/2026-09-19-phoenix-contextual-village-dialogue.md`

Anything beyond these files needs a concrete implementation reason. In particular, do not proactively touch `DialoguePanel`, `GameHud`, persistence, scenes, generated art, audio, README, or CLAUDE.
