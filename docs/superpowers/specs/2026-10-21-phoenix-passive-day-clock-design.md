# HPA-263 — Passive Day Clock and Budget Balance Design

**Linear:** [HPA-263](https://linear.app/cwchanap/issue/HPA-263/daily-pacing-make-the-day-clock-a-real-constraint)  
**Delivery:** one draft-then-implementation PR on `agent/hpa-263-passive-day-clock-plan`, based on `main` at `d277295764484cd337afc7a38164bf2d4fd8afde`.  
**Follow-on:** HPA-351 economy tuning comes *after* this task; HPA-353/HPA-264 and HPA-352 remain separate.

## Goal and current facts

The 14-day, 06:00–22:00 farming loop currently advances `time_minutes` only through action costs; walking and normal social interactions do not use the clock. A full 20-stamina work day often ends hundreds of clock minutes before curfew. Add one passive real-time clock so time and stamina both matter in normal play, without a forced sleep or additional gameplay systems.

Reuse verified seams:
- `GameRules.DAY_START_MINUTES = 360`, `ACTION_CUTOFF_MINUTES = 1320`, `MAX_STAMINA = 20`; `ACTION_MINUTES = [30, 20, 20, 20]`, `ACTION_STAMINA = [3, 1, 2, 1]`; Efficient Can changes only watering stamina via `effective_action_cost()`.
- `WorldShell._process(delta)` already checks `_world_input_enabled`, updates action-hold and previews; `_refresh_world_input_gate()` derives permission from `not _finale_in_progress and not hud.has_blocking_modal()`.
- `GameHud.has_blocking_modal()` already handles opening intro plus the existing panel registry. The contextual tutorial card is non-blocking.
- `GameSession._active_day_failure()` blocks pending morning summary and completed finale; `GameRules.evaluate_action_budget()` already rejects a farming action that would exceed 22:00.
- `WorldShell._refresh_from_session()` is the one snapshot fan-out to farm/rain/HUD and refreshes the modal/input gate.

## One clock owner, one session command

Add `GameRules.REAL_SECONDS_PER_GAME_MINUTE := 0.7` as the initial tuning constant (960 game minutes × 0.7 seconds per minute = **672 seconds / 11.2 real minutes** without action costs). Do **not** add a timer node, autoload, time service, or save-schema field.

In `GameSession`, add `advance_clock(minutes: int) -> bool`:
- Reject nonpositive increments, pending summary or finale via `_active_day_failure()` and leave state unchanged.
- Saturate `_time_minutes` at `ACTION_CUTOFF_MINUTES`; return true only if the clock actually advanced.
- Do **not** change stamina, day, weather, tutorial, crops, pending shipment, or save state; do not call sleep/finale or `_commit()`. An ordinary command can still talk, shop, ship or sleep at 22:00.

In `WorldShell`, keep only a **transient** `_clock_elapsed_seconds: float` accumulator and a `clock_running := true` switch. Add a narrow `_advance_passive_clock(delta: float)` called once near the beginning of `_process` **before preview is read**, so the HUD and action failure tint see the new time:
- Tick only when `clock_running`, `_world_input_enabled` and `not hud.has_blocking_modal()` are true, the World is in-tree, and `_finale_in_progress` is false. The existing input gate already covers intro/summary/pause/settings/shop/shipping/dialogue/other blocking panels.
- Accumulate `delta` in real seconds, consume whole in-game minutes using `floori(_clock_elapsed_seconds / GameRules.REAL_SECONDS_PER_GAME_MINUTE)`, retain fractional remainder (no real wall-clock catch-up after a paused modal). Pass the whole-minute amount in **one** `advance_clock()` call per frame.
- When an increment succeeds, call **only** the existing `_refresh_from_session()`; no per-minute UI signal or render loop. At 22:00 clear/stop the unused accumulator and avoid further updates until a new day.
- At successful `DAY_ADVANCED`, reset the accumulator so the next day starts exactly at 06:00; the pending morning summary holds the clock paused. A new World gets a fresh accumulator.
- Hold-to-work and farming commands keep their **additional** action minute cost; do not rewrite `GameRules.evaluate_action_budget()`. Day cutoff affects farming only; time no longer progresses at 22:00 but free movement and late-night interactions remain enabled.

## Balance and deterministic tests

Keep 20 stamina and the authored HUD stamina pip count unchanged. Start with 0.7 real seconds per game minute and the existing action costs; measure a deterministic **representative sunny mid-game route**, then pin its clock/stamina end state. **Do not invent travel minutes or final tuning numbers before running the route.** Select explicit reachable standing positions and collision-clear waypoints using `WorldContract`'s farm patch, bed, shop, shipping cell and villagers. For each actual walking segment compute projected distance with `WorldMath.grid_to_world(...)` and `WorldContract.MOVE_SPEED = 96.0` projected pixels/second; walking game minutes derive from `sum(segment_distance / MOVE_SPEED) / REAL_SECONDS_PER_GAME_MINUTE`, consuming whole minutes **cumulatively** while carrying fractional seconds between legs (never round each leg separately). Include detours around authored obstacles rather than measuring impossible straight lines through them, and record each chosen segment, projected distance and arithmetic in the test comment. Count only time with world input enabled: talking/shop/dialogue while a blocking modal is open uses **zero passive minutes**, though any unblocked walking or waiting to reach those interactions counts. Combine these derived minutes with the actual GameSession farming commands and their separate action-minute charges; require both time and stamina close to exhausted at a documented tolerance, rather than making the route fit a desired number. Adjust the tick-rate constant and, only if demonstrated necessary, existing per-action minute values as a small explicit table; do not change stamina/action behavior, crop prices or energy systems in this ticket.

Safety rails when tuning: 
- Re-run `test_representative_reinvestment_route_reaches_promising()` and `test_balance_gate_two_hundred_gold_buys_real_throughput_by_day_nine()`; the latter fixes six-vs-ten Pumpkins, 840G/1400G shipped, and a ten-crop Day 1 without missing the 22:00 cutoff.
- Keep `ACTION_CUTOFF_MINUTES = 1320` and `MAX_STAMINA = 20`; don't introduce a stamina-bar redesign.
- The passive tick never changes the persisted state shape. Morning-only autosave continues to record 06:00; manually refreshed World time is in `snapshot()`, not new storage.

## Test and visual isolation

Real-time advance in every test fixture would make assertions race elapsed frames. `clock_running` defaults **true in production**. Survey **all** actual World constructors, using pre-tree opt-out when direct and post-launch opt-out when AppRoot owns creation:
- `tests/integration/test_gameplay_shell.gd::_spawn_world` and the **second direct constructor** `_configured_world` (near the existing overnight save test): set `world.clock_running = false` **before** `add_child_autoqfree`. Write **one dedicated clock integration test** that explicitly opts in and drives deterministic `_advance_passive_clock(delta)` calls.
- `tests/integration/test_app_launch.gd`, `test_persistence_flow.gd` and `test_finale_cue.gd` construct World **through AppRoot**; a pre-tree World switch is unavailable. Immediately after each new/continued World is retrievable, opt out before further awaited frames (at shared helper sites where safe). Remember a subsequent New Game creates a **different** World and needs its own opt-out. Audit blocked/terminal fixtures rather than assuming the clock always advances.
- `tests/headless/world_shell_smoke.gd` directly calls `root.add_child(world)` then awaits a frame: disable on its World **before** adding it.
- `tests/visual/capture_homestead_ambience.gd` creates a **real World** for phase-0 sunny/rainy evidence (distinct from the UI goldens): disable passive ticking before `root.add_child(world)`; keep its existing phase freeze unchanged.
- `tests/e2e/gameplay_day_one_test.gd::_start_new_game()` remotely sets `clock_running = false` on its child World as soon as New Game creates it. **There is a nonzero startup race** between World insertion and remote opt-out, which can cover whole minutes on slow CI; do not add an exact-time E2E assertion based on post-launch opt-out. Use dedicated pre-tree World tests for exact 06:00/tick assertions.
- `tests/visual/capture_ui_states.gd` uses `UiCaptureHost` with **only** a standalone HUD and fixed `UiFixtureFactory` snapshot, not a WorldShell. Its seeded 09:20 and approved golden captures stay fixed; do not modify this HUD-only harness or re-bless goldens for the clock alone.

Any additional GUT/GdUnit constructors discovered during the full survey use the same nearest-fixture opt-out, never a global production disable.

Test `GameSession.advance_clock()` with exact upper boundary, no day rollover, invalid increments, pending summary, finale, no time/backward advance after cutoff, and preservation of the rest of the snapshot. Test 0.7s fractional accumulation, a multi-minute frame, no catch-up while a modal is up, and 22:00 guard with farm actions vs allowed interactions in focused integration coverage. Avoid actual multi-minute wall-clock sleeps in CI.

## Non-goals and risk

No pass-out, automatic sleeping, food/energy recovery, real-time crop growth, new modal architecture, alternate clock owner, save migration, new on-screen clock widget, or changes to 14-day length. The greatest risk is balance: too-fast passive time strands players before watering or the seed-shop trip; pin one realistic representative route and both existing reinvestment tests before changing costs. Performance risk is low because HUD refresh happens only on whole-minute advancement.

## Acceptance

1. Free-world time ticks, all blocking modals and finale/summary stop it, non-blocking tutorial cards do not; it caps at 22:00.
2. Farming time and passive time both count toward existing `ACTION_TOO_LATE`; shop/shipping/talk/sleep remain usable at cutoff.
3. Representative sunny day ends with **both** time and stamina near spent at documented constants, while Day 1 ten-crop and 14-day Promising routes remain possible.
4. Unit/GUT/GdUnit/E2E/visual lanes are deterministic, no saved-state schema change, `./tools/verify-clean.sh` and `git diff --check` pass on committed HEAD.
5. README/CLAUDE correctly describe passive time, modal pause, cutoff and test-only disable mechanism; verification evidence must be recorded, not presumed.
