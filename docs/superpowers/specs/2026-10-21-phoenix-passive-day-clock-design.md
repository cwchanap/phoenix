# HPA-263 — Passive Day Clock and Budget Balance Design

**Linear:** [HPA-263](https://linear.app/cwchanap/issue/HPA-263/daily-pacing-make-the-day-clock-a-real-constraint)  
**Delivery:** one draft-then-implementation PR on `agent/hpa-263-passive-day-clock-plan`, based on `main` @ `d277295764484cd337afc7a38164bf2d4fd8afde`.  
**Downstream:** HPA-351 (crop economy) follows this task. HPA-353, HPA-264 and HPA-352 remain separate.

## Outcome and existing seams

Phoenix's 14-day, 06:00–22:00 clock currently advances on farming commands only, while 20 stamina is exhausted long before 22:00. Make time matter during ordinary unblocked gameplay without forcing sleep, changing saves or making menus cost time. **Do not force stamina and the clock to run out together in a walking-only unit test:** walking is an efficient lower bound, not a representative human session.

Reuse `GameRules.DAY_START_MINUTES = 360`, `ACTION_CUTOFF_MINUTES = 1320`, `MAX_STAMINA = 20`, `ACTION_MINUTES = [30,20,20,20]`, and `ACTION_STAMINA = [3,1,2,1]`. `GameSession._active_day_failure()` already guards summary/finale; `GameRules.evaluate_action_budget()` already returns `ACTION_TOO_LATE` for farming. `WorldShell._process(delta)` owns the frame loop, `_world_input_enabled` already folds in `GameHud.has_blocking_modal()` and finale, and `_refresh_from_session()` fans out one snapshot to visuals/HUD.

## Pacing choice and arithmetic

Choose `GameRules.REAL_SECONDS_PER_GAME_MINUTE := 0.5` as the **initial tuning value**. The full 960-game-minute day would take 480 real seconds (8 minutes) without action charges. Existing farming uses **200–400 game minutes per 20 stamina**, because effective action costs consume at most 20 minutes per stamina point. To reach the cutoff during a full-effort day, passive time must contribute 560–760 game minutes.

| Value | At 400 action minutes | At 200 action minutes |
| --- | ---: | ---: |
| Passive game minutes to 22:00 | 560 | 760 |
| Unblocked real seconds at 0.5 s/min | **280 (4:40)** | **380 (6:20)** |
| Unblocked real seconds at old 0.7 candidate | 392 (6:32) | 532 (8:52) |

Target **about five minutes of engaged, unblocked time** for a focused full-effort day; use 0.5 rather than the much less binding 0.7 or an unsafe ~one-minute whole day. These are budget calculations, **not observed playtest data**. Menu/dialogue/intro/summary/pause time does not count. The native playtest below decides whether this initial rate is actually appropriate; if not, revise the single constant.

## Minimal runtime contract

**`GameSession.advance_clock(minutes: int) -> bool`**

- `assert(minutes > 0)` because only whole-minute accumulator increments are valid. Do not silently treat nonpositive values as valid player commands; no `CommandCode` or `_commit()`.
- Block when `_active_day_failure()` says morning summary or finale. Otherwise set `_time_minutes = mini(_time_minutes + minutes, GameRules.ACTION_CUTOFF_MINUTES)` and return whether it advanced.
- No change to stamina, crops, weather, day, tutorial, save state, or sleeping. After 22:00, shop, talk, shipping, movement and sleep still work; farming uses the existing budget guard.

**`WorldShell` only**

- Add a test switch `clock_running := true`, one `_clock_elapsed_seconds: float` accumulator, and one transient `_clock_window_focused := true`. No Timer, autoload, alternate authority or save field.
- At the **`_process(delta)` call site** before the current preview/hold, run `_advance_passive_clock(delta)` only if `clock_running and _clock_window_focused`. This is the sole place the test switch is checked. Existing `_notification()` cancels action holds on focus-out; extend it to set the flag on application/window focus-out and restore it on matching focus-in. **Focus loss pauses the clock**, with no catch-up on refocus.
- In `_advance_passive_clock(delta)`, guard **only** `_world_input_enabled` (plus `delta <= 0.0` no-op). The existing gate already covers intro, every blocking modal, morning summary and finale; `_process()` is in-tree. Direct GUT calls to the helper while `clock_running=false` remain deterministic.
- Add positive `delta` to elapsed seconds; consume `floori(elapsed / REAL_SECONDS_PER_GAME_MINUTE)` whole minutes in one `advance_clock()` call; **subtract consumed whole-minute seconds regardless of command success**, leaving fractional remainder under one tick. Refresh via `_refresh_from_session()` **once** only if the session changed.
- **No special 22:00 stop/clear branch; no accumulator reset in `_on_sleep_requested()`.** At cutoff, the command returns false, so there is no re-render. A remaining sub-tick fraction harmlessly carries through the paused morning summary into next day.
- Action-minute charges still apply separately via `evaluate_action_budget()`; do not change stamina, action costs to inflate time pressure, the 22:00 cutoff, or the 14-day length.

## Acceptance: anti-stranding gate and actual pacing evidence

**1. CI anti-stranding gate — extend an existing benchmark, not a new bespoke route.** The upgraded Day 1 in `tests/unit/test_game_session.gd::_run_benchmark_route()` has ten pre-tilled plots, 10 Plant + 10 upgraded Water commands, costing **400 action minutes / 20 stamina**. Augment that existing Day 1 route with derived walking time from collision-clear standing cells/waypoints (shop/bed to farm plots, then bed). Use `WorldMath.grid_to_world()` for projected pixel distances, `WorldContract.MOVE_SPEED = 96.0` px/s for elapsed real seconds, and the current `REAL_SECONDS_PER_GAME_MINUTE` for passive minutes. Carry fractional travel time **across legs** rather than rounding each one; record path segments, pixel lengths and arithmetic in the test. Blocking shop/dialogue time counts as zero. After Day 1 work and travel, require time at or before **20:00**: a 120-game-minute contingency before cutoff. This checks that a too-fast rate cannot strand an efficiently played busy day; it **does not** establish that time binds in normal play.

**2. Native timed playtest — actual time pressure.** With normal human decisions and no artificial waiting, run a focused, full-effort sunny day and record real **unblocked** seconds, action count/action-minute charges, HUD time and remaining stamina when the first resource binds, and whether watering, trips to shop/shipping and sleep remain viable. Verify the clock freezes on pause, blocking menus and loss of focus, then resumes without catch-up. If 0.5 s/min is punishing or irrelevant, change the constant based on these observations and rerun the anti-stranding test. Never claim listening/playing evidence inferred from static math.

Re-run `test_representative_reinvestment_route_reaches_promising()` and the existing six/ten-Pumpkin Day-9 throughput benchmark (840G/1400G shipped) as **economy regressions**. Without derived passive minutes, these cannot establish clock pacing. Keep existing sale values, 20 stamina/pips and schema-2 state. No HPA-351 economy changes here.

## Deterministic fixture coverage

The switch defaults **true** in production but is disabled before adding each directly instantiated test World: both `_spawn_world` and `_configured_world` in `test_gameplay_shell.gd`, `tests/headless/world_shell_smoke.gd`, and live-World `tests/visual/capture_homestead_ambience.gd`. Do these opt-outs in **the same implementation checkpoint** that turns on ticking, so intermediate suites stay green. The separate HUD-only `tests/visual/capture_ui_states.gd` / `UiCaptureHost` fixture has no World and stays unchanged, including goldens.

Audit AppRoot-backed `test_app_launch.gd`, `test_persistence_flow.gd` and `test_finale_cue.gd`. Real New Game Worlds start behind intro and genuine persisted Continue Worlds behind the morning summary; add an opt-out **before acknowledging that gate** only when a test will compare exact time/whole state after unblocking. Do not scatter post-launch switches through tests that never release the gate.

**No E2E opt-out:** `tests/e2e/gameplay_day_one_test.gd` has no time/cutoff assertions. New Game starts gated by intro; the crafted `_continue_seeded_game()` fixture has intro acknowledged, but tests only purchase/watering, not exact time. Keep production-like ticking, rather than adding a remote `clock_running=false` step and its startup race. Test exact clock arithmetic in one GUT World with `clock_running=false` and direct `_advance_passive_clock(0.25)` calls: `_process()` cannot race it because that is where the switch is checked.

Unit tests pin +1 / multi-minute / clamp / no day rollover / pending summary / finale / unchanged state; there is no regular false-return test for a nonpositive programmer-error increment. Integration tests pin modal and focus pause/resume, fractional accumulation, HUD refresh, 22:00 farming rejection and allowed interactions without wall-time sleeps.

## Non-goals and release gates

No forced sleep/pass-out, food, new Time service/Timer/autoload, idle timer, save migration, graphical clock changes, E2E test switch, independent representative-day unit fixture, crop price changes, stamina change, or visual golden re-blessing.

Acceptance: passive ticking in unblocked focused play; correct modal/focus pause; 22:00 behavior; **existing upgraded Day 1 anti-stranding route passes with travel and a 120-minute buffer**; real paced native day supplies time-pressure evidence; economy/CI tests pass; README and CLAUDE describe gameplay; `./tools/verify-clean.sh` and `git diff --check` pass on committed HEAD. Do not claim any of these checks before they run.
