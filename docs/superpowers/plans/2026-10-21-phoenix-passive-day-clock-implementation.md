# HPA-263 — Passive Day Clock Implementation Plan

**Issue:** [HPA-263](https://linear.app/cwchanap/issue/HPA-263/daily-pacing-make-the-day-clock-a-real-constraint)  
**Design:** [2026-10-21-phoenix-passive-day-clock-design.md](../specs/2026-10-21-phoenix-passive-day-clock-design.md)  
**Delivery:** one PR #22 on `agent/hpa-263-passive-day-clock-plan`; design now, implementation and verification later **on the same PR**. Base `main` @ `d277295764484cd337afc7a38164bf2d4fd8afde`.  
**Status:** docs-only design review; no runtime changes, tests or native playtest have been performed here.

## Task 0 — Baseline reuse and fixtures

- [ ] Inspect `scripts/game/game_rules.gd` (action/time budgets), `scripts/game/game_session.gd` (`_active_day_failure`, budget, sleep), `scripts/world/world_shell.gd` (`_process`, input gate, `_notification`), and `scripts/ui/game_hud.gd::has_blocking_modal()`.
- [ ] Confirm `GameSession.state()` schema is unchanged and overnight `DAY_ADVANCED` saves only next-morning time; no migration or new fields needed.
- [ ] Survey real-World constructors now: both `test_gameplay_shell.gd::_spawn_world()` and `_configured_world()`; `tests/headless/world_shell_smoke.gd`; `tests/visual/capture_homestead_ambience.gd`; AppRoot-backed `test_app_launch.gd`, `test_persistence_flow.gd`, `test_finale_cue.gd`; and other GUT/GdUnit constructors discovered by a repository search. `tests/visual/capture_ui_states.gd`/ `UiCaptureHost` is HUD-only; no World to gate.
- [ ] Read `tests/unit/test_game_session.gd::_run_benchmark_route()`: the prepared upgraded ten-Pumpkin Day 1 costs 400 action minutes and 20 stamina. Preserve its Day-9 840G/1400G and Promising-route regressions.

**Checkpoint:** record baseline verification if Godot is available. No new clock manager, Timer or settings UI.

## Task 1 — Session command, test first

**Files:** `tests/unit/test_game_session.gd`, `scripts/game/game_session.gd`

- [ ] Write failing assertions for `advance_clock(1)`, a multi-minute advance, exact 22:00 and overshoot clamp, no day rollover at cutoff, no increase after 22:00, unchanged stamina/farm/weather/summary and no tutorial side effects.
- [ ] Reuse existing pending-morning-summary and Day-14 finale fixtures to assert both reject the clock advance without changing state.
- [ ] Implement `advance_clock(minutes: int) -> bool` with `assert(minutes > 0)`, guard through `_active_day_failure()`, `mini(..., ACTION_CUTOFF_MINUTES)`, and `bool` return only if time advanced. No new `CommandCode`, `_commit()`, or save changes. **Nonpositive is a programmer error:** remove any old planned test expecting `false`.

**Checkpoint:** targeted unit GUT tests. Do not yet turn on automatic ticking.

## Task 2 — Minimal WorldShell clock plus *all direct-fixture opt-outs*

**Files:** `scripts/game/game_rules.gd`, `scripts/world/world_shell.gd`, `tests/integration/test_gameplay_shell.gd`, `tests/headless/world_shell_smoke.gd`, `tests/visual/capture_homestead_ambience.gd`.

**Keep these edits in one commit/checkpoint** so existing live-World tests are deterministic as soon as production clock ticking is enabled.

- [ ] Add `GameRules.REAL_SECONDS_PER_GAME_MINUTE := 0.5` as the selected provisional rate. Rationale: the 400-action-minute busy day needs 560 passive minutes, or **280 real unblocked seconds (4:40)** at this value; a 200-action-minute day needs 380 seconds (6:20). The full passive 960 minutes would take 8 real minutes. This is a target, not native-play evidence. Don't add a separate test that the constant is positive.
- [ ] In `WorldShell` add `clock_running := true`, `_clock_elapsed_seconds := 0.0`, `_clock_window_focused := true`. In existing `_notification` (currently cancels action hold on application/window focus-out), set focus false on those events and true on matching focus-in; **alt-tabbing pauses time**. No wall-clock catch-up.
- [ ] At the beginning of `_process(delta)`, before gameplay preview/hold, call `_advance_passive_clock(delta)` only when `clock_running and _clock_window_focused`. **Do not check `clock_running` inside the helper**.
- [ ] Inside `_advance_passive_clock(delta)`, early-return when `not _world_input_enabled` or `delta <= 0.0`. The input gate already includes all blocking modals, intro, summary and finale: do not duplicate `hud.has_blocking_modal()`, `_finale_in_progress` or `is_inside_tree()`. Accumulate seconds, calculate `whole_minutes = floori(accumulator / GameRules.REAL_SECONDS_PER_GAME_MINUTE)`, and for `whole_minutes > 0` **always subtract** `whole_minutes * rate` before/after one `_session.advance_clock(whole_minutes)`. Refresh once only on `true`. No 22:00 special case, and **no `DAY_ADVANCED` accumulator reset**.
- [ ] In `test_gameplay_shell.gd::_spawn_world` **and** `_configured_world`, `world.clock_running = false` before `add_child_autoqfree(world)`. In `world_shell_smoke.gd` set false before `root.add_child(world)`. In real-World `capture_homestead_ambience.gd` set false before `root.add_child(world)` while keeping its visual phase-freeze. Do not change the HUD-only UI golden capture.
- [ ] In **one** existing gameplay-shell integration test, leave automatic clock disabled and directly drive `world._advance_passive_clock(0.25)` twice, then a multi-minute delta. Assert clock/HUD changes, modal-open pause without accumulator growth or catch-up, non-blocking tutorial not pausing, focus-out/refocus at `_process` call site, cutoff farming rejection and late interactions. Explicitly confirm `await` does not advance the clock in this fixture.

**Checkpoint:** unit + full `test_gameplay_shell.gd`, world-shell headless smoke, homestead evidence capture if runnable; no intermittent frame-time regressions.

## Task 3 — Audit AppRoot tests, **do not change E2E by default**

**Files:** only the AppRoot GUT fixtures where an actual exact-time or whole-state assertion requires opt-out.

- [ ] In `tests/integration/test_app_launch.gd`, `test_persistence_flow.gd` and `test_finale_cue.gd`, audit launch and each New Game/Continue path. AppRoot instantiates World itself so callers **cannot** pre-tree opt out. But New Game opens behind an unacknowledged intro, and valid persisted Continue opens behind a morning summary. Where the test will release that gate and later compare the **whole state/exact time**, set `world.clock_running=false` **before acknowledging** intro/summary. Do not mechanically modify every AppRoot fixture or introduce global test flags.
- [ ] `tests/e2e/gameplay_day_one_test.gd` has **no exact clock/cutoff assertions**. Keep production ticking; **do not** introduce the previously proposed remote `game.set_property(WORLD, "clock_running", false)` or a startup-race workaround. `_start_new_game()` begins behind intro; `_continue_seeded_game()` uses an intro-acknowledged crafted save, but its purchase/water check is not time-equality sensitive. If real CI timing makes it fail, investigate and address that evidence before adding any fixture switch.
- [ ] Leave `tests/visual/capture_ui_states.gd`, `UiCaptureHost`, `UiFixtureFactory`, and approved goldens alone.

**Checkpoint:** AppRoot GUT and GdUnit/E2E lanes still pass; no unnecessary fixture edits.

## Task 4 — Extend existing Day 1 benchmark for **anti-stranding**, not clock-binding

**File:** `tests/unit/test_game_session.gd`. No new stand-alone representative-day test or balance framework.

- [ ] In the **existing** `_run_benchmark_route(session, crop_count)` Day 1 path, derive travel legs for the prepared shop/bed → ten farm cells → bed route (six cells for baseline) from **walkable** `WorldContract` interaction standing cells, with obstacle-clear waypoints; no straight path through authored buildings/colliders. For each projected segment, compute length from `WorldMath.grid_to_world()` and real seconds from `WorldContract.MOVE_SPEED = 96` px/s.
- [ ] Accumulate travel seconds *across legs* and convert to game minutes via the chosen `REAL_SECONDS_PER_GAME_MINUTE` with a carried fractional remainder. Insert corresponding `GameSession.advance_clock(whole_minutes)` during the Day 1 action loop/route. Document each waypoint, segment length, total walk seconds and resulting passive minutes in a compact test comment. Time inside blocking shop/dialogue panels is **not** added; action minutes are already charged separately.
- [ ] Assert the upgraded 10 Plant + 10 Water Day 1 completes by **20:00** (120-minute margin before 22:00), after charging the travel minutes. This is **not** a claim that normal gameplay reaches 22:00: it is protection against a day rate that strands an efficiently busy 20-stamina route.
- [ ] Preserve the existing full Day-9 benchmark result (six-vs-ten Pumpkins, 840G/1400G shipped) and re-run `test_representative_reinvestment_route_reaches_promising()` as *economy* pins only; they cannot measure human passive-time pressure. Keep 20 stamina, `ACTION_MINUTES`, sale prices and finale tiers unchanged unless a specific regression requires a narrowly reviewed repair.

**Checkpoint:** upgraded Day 1 ends by 20:00 with derived travel, Day-9 and Promising regressions still pass. No extra test whose only purpose is to force both budgets to end together.

## Task 5 — Native pace evidence, docs and final verification

**Files:** `README.md`, `CLAUDE.md` and touched source/tests.

- [ ] **Native timed playtest (required for the gameplay acceptance):** play one focused full-effort sunny day at normal decision speed and no artificial idle delay. Record start/end HUD time, the actual seconds of **unblocked** gameplay, number/type of farming commands and their minute costs, stamina when the clock first binds (or clock when stamina first runs out), and whether usual shop/shipping/watering routes remain practical. Pause menus and app-focus-out and verify no hidden accrual; at 22:00 farm blocks but movement/talk/shop/ship/sleep remain possible. This cannot be inferred from a CI walking-only simulation.
- [ ] If 0.5 s/min is too harsh or still leaves the clock irrelevant, change **only the tick-rate constant** according to observations, rerun Task 4's 120-minute buffer and rerun native spot check. Do not inflate `ACTION_MINUTES` just to make two resource totals meet.
- [ ] Update README/CLAUDE to describe passive time, focused-window requirement, modal pauses, 22:00 cutoff and the `clock_running` test opt-out.
- [ ] Run targeted GUT, full headless smokes, existing E2E/GdUnit as applicable, `./tools/verify-clean.sh` on **committed HEAD**, and `git diff --check`. UI golden capture remains HUD-only and unchanged.
- [ ] Review GitHub comments and address findings on **PR #22**; fill in actual CI/native evidence, keep draft until implementation and tests have shipped.

## Expected implementation diff

`scripts/game/game_rules.gd`; `scripts/game/game_session.gd`; `scripts/world/world_shell.gd`; `tests/unit/test_game_session.gd`; `tests/integration/test_gameplay_shell.gd`; `tests/headless/world_shell_smoke.gd`; `tests/visual/capture_homestead_ambience.gd`; `README.md`; `CLAUDE.md`. Touch AppRoot-backed GUT fixtures only if their unblocked whole-state/time assertions need it; **do not plan to edit `tests/e2e/gameplay_day_one_test.gd`**. No visual golden re-blessing.

**Out of scope:** timer/service/autoload, save-schema changes, time widget, E2E remote clock switch, second balance fixture, forced sleep/food, stamina/pips redesign, HPA-351 crop economy, HPA-353 validator split, HPA-264 target-driven controls, or unmeasured action-minute inflation.
