# HPA-263 — Passive Day Clock Implementation Plan

**Issue:** [HPA-263](https://linear.app/cwchanap/issue/HPA-263/daily-pacing-make-the-day-clock-a-real-constraint)  
**Design:** [2026-10-21-phoenix-passive-day-clock-design.md](../specs/2026-10-21-phoenix-passive-day-clock-design.md)  
**Delivery:** one PR from `agent/hpa-263-passive-day-clock-plan`, opened **draft with docs**; implement and verify on **this branch / PR**, not a second PR. Base `main` SHA `d277295764484cd337afc7a38164bf2d4fd8afde`.  
**Status:** planning only; no runtime changes or Godot execution yet.

## Task 0 — Baseline and reuse survey

- [ ] Read `scripts/game/game_rules.gd` (clock/action/stamina constants), `scripts/game/game_session.gd` (active-day failure, action budgets, `sleep()`), `scripts/world/world_shell.gd` (`_process`, `_refresh_world_input_gate`, `_on_sleep_requested`), and `scripts/ui/game_hud.gd::has_blocking_modal()`.
- [ ] Check existing tests: `tests/unit/test_game_rules.gd`, `tests/unit/test_game_session.gd`, `tests/integration/test_gameplay_shell.gd` (**both** `_spawn_world` and `_configured_world`), AppRoot-backed `test_app_launch.gd`, `test_persistence_flow.gd`, `test_finale_cue.gd`, `tests/headless/world_shell_smoke.gd`, live-World `tests/visual/capture_homestead_ambience.gd`, and `tests/e2e/gameplay_day_one_test.gd`. The separate `tests/visual/ui_capture_host.gd` is HUD-only; leave it unchanged.
- [ ] Record baseline GUT/headless verification if Godot is present. Never report unrun tests as passing.

**Checkpoint:** confirm the feature adds no new owner: WorldShell runs the frame, GameSession changes gameplay state, HUD already owns the modal gate.

## Task 1 — Test the session command before implementation

**Files:** `tests/unit/test_game_session.gd`, then `scripts/game/game_session.gd`

- [ ] First add failing focused assertions for `advance_clock(minutes: int) -> bool`: +1 minute, multi-minute advance, exact 22:00, clamping above cutoff, no further progress at cutoff, nonpositive increments, and no day/crop/stamina/summary/weather mutation.
- [ ] Construct a pending morning summary using the existing sleep helper and assert that `advance_clock()` rejects it; exercise Day 14 finale through existing unit fixture and assert it rejects post-finale advances. Do not add new save keys or duplicate validator tests.
- [ ] Implement one `advance_clock` method next to other session commands. Use `_active_day_failure()`, cap at `GameRules.ACTION_CUTOFF_MINUTES`, and return `true` iff it changed `_time_minutes`. Do not call `_commit()`, sleep, or any persistence function. No new `CommandCode`.

**Checkpoint:** run focused session GUT tests.

## Task 2 — Implement passive accumulation at the existing WorldShell seam

**Files:** `scripts/game/game_rules.gd`, `scripts/world/world_shell.gd`, `tests/integration/test_gameplay_shell.gd`

- [ ] Add `GameRules.REAL_SECONDS_PER_GAME_MINUTE := 0.7` (initial candidate) and test its positive value if not self-evident.
- [ ] Add `WorldShell.clock_running := true` and private `_clock_elapsed_seconds: float = 0.0`. Avoid Timer/SceneTreeTimer and wall-clock `Time.get_ticks_msec()`: real `_process(delta)` makes pause deterministic.
- [ ] Introduce `_advance_passive_clock(delta: float)` called at the start of `_process()`, ahead of target preview/hold, but after the modal/input gate has already been updated through its existing signals. Gate on `clock_running`, input availability, HUD blocking modal and finale; negative/zero delta is a no-op.
- [ ] Accumulate only when unblocked. Consume `floori(elapsed / REAL_SECONDS_PER_GAME_MINUTE)` whole minutes in one command; retain fractional time and refresh the snapshot **once** if the command advanced. When it reaches 22:00 clear remainder, stop spending cycles until the next morning.
- [ ] On an actual `GameRules.CommandCode.DAY_ADVANCED` path in `WorldShell._on_sleep_requested`, reset remainder to zero. During pending morning summary, do not accumulate; preserve existing save-on-sleep and modal wiring. Do not reset remainder on a mere UI pause/resume.
- [ ] In shared `_spawn_world` integration fixture, set `clock_running = false` on the new instance **before** adding it to the tree to keep existing exact-time tests stable. Add one dedicated passive clock integration test with opt-in ticking; use direct deterministic calls with 0.35/0.35s and a multi-minute delta rather than actual sleeps.
- [ ] Test: free input advances HUD clock; opening a blocking modal freezes ticks; closing resumes without catch-up; non-blocking tutorial card does not pause; 22:00 stays at cutoff while the World remains interactive. Confirm preview and action guard match after a tick across action cutoff.

**Checkpoint:** `test_gameplay_shell.gd` passes, including existing hold and modal behavior; repeated frame deltas cannot advance an extra minute under the block.

## Task 3 — Deflake real-world fixtures without changing visual goldens

**Files to survey explicitly:** `tests/integration/test_gameplay_shell.gd` (`_spawn_world` **and** `_configured_world` near line 2755); `tests/integration/test_app_launch.gd`; `tests/integration/test_persistence_flow.gd`; `tests/integration/test_finale_cue.gd`; `tests/headless/world_shell_smoke.gd`; `tests/visual/capture_homestead_ambience.gd`; `tests/e2e/gameplay_day_one_test.gd`. Check for additional World/AppRoot constructors in other GUT/GdUnit suites.

- [ ] **Direct World constructors:** set `clock_running = false` **before** `add_child_autoqfree(world)` or `root.add_child(world)`. Cover the second gameplay-shell constructor, world-shell headless smoke and real-World homestead ambience capture, not just `_spawn_world`.
- [ ] **AppRoot-path suites:** `test_app_launch.gd`, `test_persistence_flow.gd`, and `test_finale_cue.gd` create the World inside `AppRoot._launch()`. Pre-tree opt-out is not available from these callers: set `world.clock_running = false` **immediately after** `app.get_node("World")`, before any further awaited frames, ideally at the existing shared launch helpers. Do this for each newly created World, including New Game after Continue/result; audit blocked/terminal flows for existing implicit pauses.
- [ ] **E2E:** in `_start_new_game()`, after the new World exists, remotely call `game.set_property(WORLD, "clock_running", false)` before farming interactions. This **cannot eliminate the interval before the remote call arrives**; on slow CI whole minutes can pass, so do **not** add exact-time E2E assertions for the opening state. Exercise exact tick behavior in pre-tree-disabled GUT Worlds that explicitly opt in instead.
- [ ] **HUD-only goldens:** do **not** edit `tests/visual/capture_ui_states.gd`, `UiCaptureHost`, `UiFixtureFactory` or approved goldens: they render a fixed HUD snapshot with no WorldShell/passive timer. The *other* capture, `capture_homestead_ambience.gd`, does instantiate World and should be opted out before tree entry.
- [ ] Do not globally disable processing or pause the SceneTree: it would also disable movement, audio or action-hold semantics. Preserve a dedicated clock-enabled integration test; disable only at each fixture.

**Checkpoint:** regular gameplay/E2E timing checks remain repeatable.

## Task 4 — Pin one representative day; tune only where measured

**Files:** `tests/unit/test_game_session.gd`, `tests/unit/test_game_rules.gd` if constants change

- [ ] Build a deterministic sunny **mid-game full-effort workday** using existing `GameSession` commands and `advance_clock(minutes)` for **derived walking and other unblocked elapsed time only**, never invented travel/social minutes. Use actual `WorldContract` cells: bed `(12,7)`, farm `x=4..9, y=10..14`, shop `(17,9)`, shipping `(10,13)`, and villagers `(16,8)/(18,7)/(17,11)`, plus reachable interaction standing cells/waypoints that detour around authored collision footprints.
- [ ] For each walk segment `start -> waypoint -> destination`, compute **projected** pixel distance from `WorldMath.grid_to_world()` and seconds as `segment_length_px / WorldContract.MOVE_SPEED` (**96 px/s**). Convert cumulative walking seconds to game minutes with `floori(total_unblocked_seconds / GameRules.REAL_SECONDS_PER_GAME_MINUTE)` and carry the fractional remainder between legs, rather than rounding each leg independently. Add a concise test comment/table with route waypoints, each segment's pixel length, summed travel seconds and resulting game minutes at the candidate rate. Count time in blocking shop/dialogue/pause panels as **zero** passive time; actual farming commands independently charge `ACTION_MINUTES`. No `await` or real-time sleeps in this balance test.
- [ ] Document the starting state (farm plot count, Efficient Can status, ordered action route), resulting 22:00 proximity and remaining stamina. Set a **concrete, justified tolerance** after running the real-derived route; don't invent numbers to make the desired "both budgets near spent" gate pass.
- [ ] Start at rate 0.7s/game-minute and existing action minutes; adjust only `REAL_SECONDS_PER_GAME_MINUTE` and, if the benchmark forces it, existing `ACTION_MINUTES` entries. Keep `ACTION_STAMINA`, Efficient Can cost, crop sale values and 20-pip HUD unchanged.
- [ ] Re-run `test_representative_reinvestment_route_reaches_promising()` and `test_balance_gate_two_hundred_gold_buys_real_throughput_by_day_nine()`; verify the latter's ten-crop Day 1, six/ten Pumpkins and 840G/1400G outputs still fit. Explicitly record any re-pin if changing action minutes; do not silently loosen the budget guard.
- [ ] Do not add a second economy simulation framework, crop balancing adjustments, or HPA-351 work to this PR.

**Checkpoint:** representative route pins measured, reproducible travel arithmetic and chosen balance numbers; existing day-one and 14-day economic routes still pass.

## Task 5 — Docs, final verification, and review follow-through

**Files:** `README.md`, `CLAUDE.md`, plus touched test/production files only.

- [ ] Describe passive 06:00–22:00 clock, blocking-modal pauses, additional farming action costs, cutoff with continued movement/shop/talk/shipping/sleep, and how `clock_running` is disabled only in tests.
- [ ] Run GUT unit/integration, GdUnit and E2E as applicable, headless smokes and `./tools/verify-clean.sh` on **committed HEAD**, plus `git diff --check`.
- [ ] Verify no visual golden diff is needed (HUD-only capture host has no passive World); native manual spot-check: intro/modal pause, walking clock, 22:00 farm guard and free interactions, and Day 14 finale. Record actual results.
- [ ] Review latest PR comments, apply valid corrections here, update PR checklist and link evidence. Mark ready only once the runtime code and tests actually land.

## Expected implementation diff

`scripts/game/game_rules.gd`; `scripts/game/game_session.gd`; `scripts/world/world_shell.gd`; `tests/unit/test_game_session.gd`; `tests/integration/test_gameplay_shell.gd`; `tests/e2e/gameplay_day_one_test.gd`; `README.md`; `CLAUDE.md`. Also survey `tests/integration/test_app_launch.gd`, `test_persistence_flow.gd`, `test_finale_cue.gd`, `tests/headless/world_shell_smoke.gd` and `tests/visual/capture_homestead_ambience.gd`; touch only those that need explicit opt-outs, and do not change HUD-only visual golden capture.

**Explicitly out of scope:** new time service/timer/autoload, saved-state schema changes, visual re-blessing, stamina pips, passive crop growth, pass-out/food systems, HPA-351 economy, HPA-353 validator split, or HPA-264 action-selection redesign.
