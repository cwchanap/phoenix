# HPA-775 — Protect the run and pace the day: single-PR implementation plan

**Status:** Planning only; none of the implementation, test execution or screenshot gates are claimed complete.  
**Design:** [Protect-run and pacing design specification](../specs/2026-11-16-phoenix-protect-run-and-pace-day-design.md)  
**Issue:** https://linear.app/cwchanap/issue/HPA-775/protect-the-run-and-pace-the-day  
**Reviewed base:** main c5eb32553d40d882a7bf156880096093e62ff1dd  
**Branch / PR:** agent/hpa-775-protect-run-pace-day-plan; implement **on this same draft PR**, then mark ready after automated evidence. One issue, one PR.

## Preflight: avoid duplicating existing behavior

The entire change is a UI/presentation safety slice plus one passive-clock tuning constant. Keep GameSession, SaveRepository, SaveFileCodec, SessionStateValidator, the result computation and the 30-minute travel command **unchanged**. Only AppRoot and TitleScreen may need a tiny selection-preference handoff for completed saves; this is not a save-format change.

Before editing, inspect these exact entry points:

- scripts/ui/title_screen.gd: set_continue_state() and _selected_index; scripts/app/app_root.gd:_load_title_state() validates saves and _launch() currently opens the result directly when finale_triggered is true.
- scripts/world/world_shell.gd: _interactable(), interact(), _attempt_travel(), _finish_finale(), load_map(), _advance_passive_clock(), _refresh_world_input_gate() and focus notifications.
- scripts/ui/game_hud.gd: _primary_modals (currently 10), _esc_close_order, _build_modals(), has_blocking_modal(), _open_modal(), close_modals() and _unhandled_input(); scripts/ui/shop_panel.gd:_header() and scripts/ui/sleep_panel.gd are the concrete market-card templates.
- scripts/game/game_rules.gd: REAL_SECONDS_PER_GAME_MINUTE = 0.5, TRAVEL_MINUTES = 30, 22:00 cutoff.
- scripts/game/game_session.gd: trigger_harvest_finale(), travel(), advance_clock(); these are domain commands and **not** targets for refactoring.
- assets/i18n/strings.csv (keys,zh_TW,ja) and existing UiStyle controls/icons.
- HPA-775 mockups: A1 Continue default, A2 Harvest Market confirmation, B1 driving overlay. Reuse existing assets/ui/icons/market.png and assets/sprites/kei-truck.png.
- tests/native_tour/rain_tour_base.gd, rain_tour.gd and seed_save.gd are the native, input-driven screenshot/focus harness. There is no separate "MCP-operated" in-repo framework; agents/MCP execute these real project tools.


Existing regressions to account for up front:

- `tests/integration/test_app_launch.gd:test_title_enter_keycap_marks_only_the_selected_action` expects New Game with a valid save. Add a `finale_triggered` completed-save case (and Result → Return to title) and retain invalid-slot behavior.
- `tests/native_tour/rain_tour_base.gd:_title_continue()` currently presses S to reach Continue; with Continue already selected, S would wrap to New Game. Make it check selection first, then press a direction **only if needed**.
- Two assertions in `tests/integration/test_gameplay_shell.gd` pin `_primary_modals.size() == 10`; market confirmation raises it to 11.
- `tests/integration/test_finale_cue.gd` expects immediate finale on market E and must now confirm Enter; retain cue duration/lifetime.
- Three sets of **immediate-swap** helpers: `tests/integration/test_gameplay_shell.gd:_drive_to_town/_drive_home`, `tests/integration/test_persistence_flow.gd:_drive_to_town` and `tests/integration/test_finale_cue.gd:_drive_to_town`. Add **one synchronous `hud.finish_travel()` line to each helper**, rather than awaiting the real 1.5-second animation in every unit/integration test.
- Both map-swap assertions in `tests/headless/world_shell_smoke.gd` (farm→town near line 1040 and town→farm near line 1358) need the same deterministic finish seam before checking scene-tree contents.
- `tests/e2e/gameplay_day_one_test.gd` contains three later travel paths (near lines 339, 424 and 457). They must **wait for travel to finish** before shopping, farming or issuing the next E.
- `tests/integration/test_gameplay_shell.gd:test_passive_clock_ticks_pauses_and_keeps_late_day_interactive` hardcodes increments for 0.5 s/min. Derive fractional rollover tests from the new constant.
- `tests/unit/test_game_session.gd:_run_benchmark_route` (near line 2325) already uses `REAL_SECONDS_PER_GAME_MINUTE` and asserts the Day-1 route finishes before 20:00 (near line 2400). Preserve its economics and anti-stranding proof after retuning.

### Verification discipline

For the in-progress uncommitted working tree run Godot import and direct headless smoke, then GUT when installed. The clean verifier archives **committed HEAD**, so invoke it only after coherent code commits.

~~~sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
~~~

The first two lines are quick iteration checks; the last three are required committed-head gates, alongside GitHub-hosted CI. Agents/MCP must also run the existing native `tests/native_tour/` harness on one supported platform, inspect its focus log and examine its native 1080p captures against A1/A2/B1. This is **agent visual inspection**, not the screenshot-golden image-diff gate removed on 2026-11-01; no human approval/sign-off is an acceptance step.


## Task 1 — Save-aware title default, including completed runs

**Files:** `scripts/ui/title_screen.gd`, `scripts/app/app_root.gd`, `tests/integration/test_app_launch.gd`, native tour title helper and launch e2e.

1. Red-first integration tests: seed a validated Day-5 *unfinished* SaveRepository slot, instantiate AppRoot, assert Continue gradient and keycap selected, press real `ui_accept`, verify Day 5 resumes without overwriting the slot. Explicitly selecting New Game still launches Day 1.
2. Add a **completed** (`finale_triggered == true`) valid save test: Continue remains selectable for deliberately viewing the old result but the title defaults to New Game; Result → Return to title → Enter does not re-enter the completed result. Missing, invalid and incompatible saves still default to New Game with existing warnings.
3. Let AppRoot pass whether a *valid* save is unfinished to TitleScreen's existing `set_continue_state()` as a tiny preference parameter. TitleScreen sets one `_selected_index` from availability/preference. No new validator, persistence or modal changes.
4. Update the keycap/wraparound integration test and `rain_tour_base.gd:_title_continue()` to skip its unconditional S press once Continue is already selected.
5. Add a real-key native/godot-e2e launch check and capture **A1** at 1920×1080 via a small `tests/native_tour/hpa_775_tour.gd` extending `rain_tour_base.gd` (isolated save/settings paths, using the existing seed-save pattern).

**Done when:** Unfinished Day N is protected by default; completed saves default to New Game without disabling explicit Continue; no-save starts Day 1; captured A1 visibly highlights the right row.


## Task 2 — Market confirmation reuses existing finale and modal seams

**Files:** `scenes/ui/market_confirm_panel.tscn` (new); `scripts/ui/market_confirm_panel.gd` (new); `scripts/ui/game_hud.gd`; `scripts/world/world_shell.gd`; `assets/i18n/strings.csv`; existing relevant GUT/e2e tests.

1. Red-first integration checks: Day `GameRules.MAX_DAY` E at town market shows confirmation **without** changing the session snapshot or save; Esc returns to identical state and world control; Enter triggers one canonical finale and the existing result. On earlier days, the real `GameSession.trigger_harvest_finale()` still returns `MARKET_NOT_READY` and its toast.
2. Build one `MarketConfirmPanel` from the existing `SleepPanel` Day-14 confirmation and shop-card patterns:
   - header via `UiStyle.gradient_band(UiStyle.HEADER_GRADIENT, 30, ...)` (`shop_panel.gd:_header()`),
   - `assets/ui/icons/market.png`, native City Pop text and WARN note from `sleep_panel.gd:_warning_card()`,
   - `UiStyle.primary_action` / `ghost_action` (`ui_style.gd`) and the same standard Enter/Esc event pattern.
   - Localize English key strings and zh_TW/ja in `strings.csv`; no reusable confirmation framework.
3. Register exactly one additional panel in `GameHud._primary_modals` and Esc order. Expose `market_confirmed`, `open_market_confirmation()` and `close_market_confirmation()` and use the existing modal gate.
4. Route market E in WorldShell: compare snapshot day to **`GameRules.MAX_DAY`**, show card only on that day, otherwise dispatch the real command for the existing refusal. Handler copies `_on_sleep_requested()`'s **`_finale_in_progress` guard** for HUD-originated duplicate Enter; only then calls the authoritative finale command once.
5. In `_finish_finale()`, set the existing finale lock before replacing `hud.close_sleep_confirmation()` with **`hud.close_modals()`**. The existing close_modals path is silent (no confirm SFX) and handles bed or market without a new close API. Preserve finale cue lifetime.
6. Update both modal-count pins (10→11), the finale-cue test, localization tests and a real-key e2e cancel→confirm scenario. Capture native **A2** from `hpa_775_tour.gd`; agent inspects warning, button states and card positioning against the attached mockup.

**Done when:** Cancellation does not mutate/save, acceptance uses one canonical finale, and all modal exclusivity, clock-pause and SFX guards continue working.


## Task 3 — One HUD-owned Tween per trip; immediate test completion seam

**Files:** `scenes/ui/travel_overlay.tscn` (new); `scripts/ui/travel_overlay.gd` (new); `scripts/ui/game_hud.gd`; `scripts/world/world_shell.gd`; the three integration travel helpers; both headless travel sites; e2e/native travel routes.

1. Add red-first checks for both directions, exact before/after time strings, initial synchronous input gate, frozen passive clock, late-trip `21:45 → 22:00` clamp, and refusal with **no** overlay/swap/clock change.
2. Add **one** transient TravelOverlay under GameHud, outside `_primary_modals`. Build its near-black fade, existing `assets/sprites/kei-truck.png`, dashed road, directional heading and actual source→arrival times. `has_blocking_modal()` includes overlay activity. Add the travel-overlay active check to the existing GameHud `_unhandled_input()` Esc early-return branch so Esc cannot open Pause mid-transition; modal shortcuts remain blocked by the existing gate.
3. Keep `WorldShell._attempt_travel()` **synchronous**: snapshot before; invoke `GameSession.travel(target)` once; on success snapshot after and call `hud.play_travel(before, after, load_map.bind(true))`. `play_travel` activates overlay and emits `modal_state_changed` **before returning** (no one-frame input or passive-clock gap).
4. One overlay-owned `create_tween()` does: fade out about 0.25 s → **`tween_callback(swap)`** while opaque → hold B1 card about 1 s → fade in about 0.25 s → hide and emit `modal_state_changed`. The node-owned tween is discarded with the scene, avoiding a WorldShell async coroutine and post-free continuation. Keep existing `load_map()` and session authority.
5. Expose only `hud.finish_travel()` as a deterministic **test seam**: step the tween through all stages with `Tween.custom_step()`, including the callback, without waiting wall time. Assert it is inactive and the destination map exists afterward. Do not use this seam in real gameplay.
6. Add the seam to `test_gameplay_shell.gd`, `test_persistence_flow.gd`, `test_finale_cue.gd` travel helpers and both `world_shell_smoke.gd` sites. Search all `world.interact()`→immediate-map assumptions. Update the three `tests/e2e/gameplay_day_one_test.gd` trips (near lines 339/424/457) and the existing `rain_tour_base.gd:_wait_map_location()` consumers to wait until `has_blocking_modal()` is false; these retain the **real-time Tween**.
7. Add real-key native tour + godot-e2e both-direction checks; capture an actual mid-transition frame for **B1** and visually inspect fade, legibility and time pill. Do not add new art or audio.

**Done when:** One atomic domain command and one Tween per successful E; integration/headless tests run without ~1.5 s waits per trip; real e2e verifies full animation, input lock and clock freeze.


## Task 4 — Derive the clock from UAT and pin a deterministic reference pace

**Files:** `scripts/game/game_rules.gd`; `tests/unit/test_game_session.gd`; `tests/integration/test_gameplay_shell.gd`; `tests/native_tour/hpa_775_tour.gd` (new); `README.md`; `CLAUDE.md`. Keep WorldShell's existing focus/modal gates unchanged.

1. **No extra 0.5 s/min baseline tour**: HPA-775 already contains human UAT data. Day 1's 3 × (Hoe 30 + Seeds 20 + Water 20) = **210 action minutes** and about **11:07** finish, so 06:00+210=09:30 and ~97 passive minutes at old 0.5 s/min implies ~48.5 s of active play.
2. State a **75-second representative active-play assumption** (roughly 48.5 s UAT farming plus the town trip), ~240 action minutes and **60 travel minutes**. For a model target at 19:30: `(19:30−06:00)−240−60 = 510 passive minutes`; 75/510 = **0.1471 s/game minute**. Pick the rounded proposed rate **0.15** unless code/test evidence disproves it. The modeled outcome `06:00 + 240 + 60 + 75/0.15 = 19:20`, inside 18:00–22:00. **Do not repeatedly adjust this rate to match a bot's wall time**.
3. Add a focused deterministic model assertion beside `test_game_session.gd:_run_benchmark_route()`: the chosen constant with 75 active seconds, 240 action minutes and 60 travel minutes yields a clock in the 18:00–22:00 window. Check that the existing `_run_benchmark_route` 20:00 anti-stranding assertion still passes unchanged; it derives movement seconds from `WorldContract.MOVE_SPEED`, not human tool latencies.
4. Update passive-clock integration tests to reference `GameRules.REAL_SECONDS_PER_GAME_MINUTE` rather than hardcoding two 0.25-second calls. Preserve fractional carry, whole-minute transitions, window-focus-out/no catch-up, modal pause, hitch delta clamp, 22:00 hard cutoff and late-day interaction. Add assertions for the **new** market/travel gates.
5. Run the new `hpa_775_tour.gd` using `rain_tour_base.gd`: isolated save/settings, actual movement/interaction and full-stamina + town trip to bed, timestamps, before/after game clocks, focus log (`window_focus`, `clock_focused`) and actual active seconds. This run **diagnoses** the real native path; it does **not** choose the constant. If the agent route ends earlier than 18:00 due to faster input, report it honestly. If the window never focused, mark the route's timing **invalid as clock evidence**, not a successful observed run; existing focus unit checks remain relevant.
6. Update README.md and CLAUDE.md: remove provisional 0.5 s/min claims and document **0.15 s/min as a UAT-derived modeled estimate**, the 75-second assumption, diagnostics and the limit that automated play cannot prove subjective human pacing. Do not introduce a human acceptance/checkpoint, extra rule fields, pacing modes or second runtime.

**Done when:** Deterministic 75-second reference day finishes 18:00–22:00 (expected ~19:20), existing 20:00 anti-stranding bound is green, and a real native tour logs timing/focus transparently. No human sign-off or unverified claim that automation reproduces a normal person's pacing.


## Task 5 — Automated end-to-end verification and agent visual evidence

Continue on this **same draft PR**, preserving one ticket→one PR. No generated art/SFX or additional task is needed.

- Run committed-head `./tools/verify-clean.sh`, GdUnit4, godot-e2e and hosted CI. Recheck the existing **Promising (175G)** and **Heart of the Harvest** routes, Day 14 bed finale, current save schema, truck nominal 30-minute cost and farm/economy invariants.
- Drive the app using a single supported native platform through the existing `tests/native_tour/` input-event harness, invoked by the agent/MCP. The new `hpa_775_tour.gd` should test an unfinished saved run and a completed run on title, market Esc/Enter and exactly-one finale, both directions of travel, passive clock gate and real input resume. Use existing `seed_save.gd` techniques to create valid isolated fixtures, **not** a second save mechanism.
- Capture native **1920×1080** screenshots of A1 (title Continue selected), A2 (Day-14 market confirmation) and B1 (town/home travel overlays). The agent visually checks these against the matching Linear ticket mockups for City Pop spacing, warning/caption legibility, correct fade/times, no clipped or overlapping controls, and no map flash. Store path/log references and images with PR verification evidence. This is **not** a screenshot-golden image-diff gate.
- Record the proposed rate, its transparent 75 s + 240 action + 60 travel calculation, model outcome ~19:20, and the **actual separately recorded native tour** timestamps and focus flags in the PR. Do not claim bot timing certifies human pace. A zero-focus tour is invalid evidence of ticking.
- Keep implementation and evidence on HPA-775; do not expand into HPA-743 world readability or HPA-861/863 artwork.


## End-to-end acceptance checklist (all required before ready-for-review)

- [ ] **Native title/save:** unfinished valid Day N save selects Continue, real Enter resumes Day N without overwriting it; finished valid save defaults to New Game yet explicit Continue can reopen the result; invalid/missing save selects New Game.
- [ ] **Native market:** Day 14 E opens A2 without session/save mutation, Esc preserves complete state/money, Enter invokes exactly one finale and result; earlier days still refuse; the Day-14 bed route remains valid.
- [ ] **Native travel:** Both E truck directions animate B1 with real pre/post snapshot times (including late cutoff), no map flash, frozen input/clock during the beat and correct resumed arrival HUD; `finish_travel()` covers deterministic helper calls while native/e2e runs the real Tween.
- [ ] **Pacing reference:** Deterministic 75 s active / ~240 action / 60 travel model places bedtime at **18:00–22:00** (anticipated 19:20 with 0.15), and current Day-1 route anti-stranding before 20:00 passes. Native played-day log reports actual time, actions, focus and pacing without tuning to bot latency; invalid zero-focus observations are labeled.
- [ ] **Agent visual check:** `tests/native_tour/hpa_775_tour.gd` produces real 1920×1080 captures; agent compares A1/A2/B1 against attached Linear mockups and records visible mismatches. No golden-image tool or human acceptance criterion.
- [ ] **Regressions and CI:** completed-run title case; old title/tour helpers; 11-modal registry; finale cue; all three integration travel helper sites, both smoke swaps and three e2e trips; passive focus/modal/hitch; 175G Promising/Heart outcomes; clean GUT/headless, GdUnit4, godot-e2e and hosted CI green.
- [ ] **Scope:** one HPA-775 PR containing design, plan and implementation; no persisted state/schema, economy or art/SFX changes.

## Stop conditions and reporting

Leave a criterion unchecked and record evidence if the deterministic 75-second reference does not reach the 18:00–22:00 window, the existing 20:00 anti-stranding assertion fails, the clock overshoots into the 22:00 cutoff **before** the planned action sequence can finish, UI focus never becomes true (native tour clock remains at zero passive ticks), a travel swap/gate is stale, CI is red or an agent visual comparison reports a substantial mismatch.

An automation-driven native day may return before 18:00 because it drives faster than the stated human-pace assumption, or report slow time because of tool latency. Log both the measured duration and focus state, but **do not tune the constant to that run or present it as human-pace certification**. If real focus never occurs, that run does not establish passive-clock behavior. Do not add manual sign-off as an acceptance gate, introduce sleep delays to fake realistic pacing, or broaden this ticket to HPA-743/HPA-861.
