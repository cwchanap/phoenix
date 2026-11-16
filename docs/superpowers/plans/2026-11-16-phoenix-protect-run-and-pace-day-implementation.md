# HPA-775 — Protect the run and pace the day: single-PR implementation plan

**Status:** Planning only; none of the implementation, test execution or screenshot gates are claimed complete.  
**Design:** [Protect-run and pacing design specification](../specs/2026-11-16-phoenix-protect-run-and-pace-day-design.md)  
**Issue:** https://linear.app/cwchanap/issue/HPA-775/protect-the-run-and-pace-the-day  
**Reviewed base:** main c5eb32553d40d882a7bf156880096093e62ff1dd  
**Branch / PR:** agent/hpa-775-protect-run-pace-day-plan; implement **on this same draft PR**, then mark ready after automated evidence. One issue, one PR.

## Preflight: avoid duplicating existing behavior

The entire change is a UI/presentation safety slice plus one passive-clock tuning constant. Keep GameSession, SaveRepository, SaveFileCodec, SessionStateValidator, the current result computation and current truck travel 30-minute command **unchanged**.

Before editing, inspect these exact entry points:

- scripts/ui/title_screen.gd: set_continue_state() and _selected_index. AppRoot._load_title_state() already vets loaded saves.
- scripts/world/world_shell.gd: _interactable(), interact(), _attempt_travel(), _finish_finale(), load_map(), _advance_passive_clock(), _refresh_world_input_gate() and focus notifications.
- scripts/ui/game_hud.gd: _primary_modals (currently 10), _esc_close_order, _build_modals(), has_blocking_modal(), _open_modal(), close_modals() and _unhandled_input().
- scripts/game/game_rules.gd: REAL_SECONDS_PER_GAME_MINUTE = 0.5, TRAVEL_MINUTES = 30, 22:00 cutoff.
- scripts/game/game_session.gd: trigger_harvest_finale(), travel(), advance_clock(); these are domain commands and **not** targets for refactoring.
- assets/i18n/strings.csv (keys,zh_TW,ja) and existing UiStyle controls/icons.
- HPA-775 mockups: A1 Continue default, A2 Harvest Market confirmation, B1 driving overlay.

Existing regressions to account for up front:

- tests/integration/test_app_launch.gd:test_title_enter_keycap_marks_only_the_selected_action currently expects New Game to be initially selected **even with a save**; revise deliberately, not as an unrelated test failure.
- tests/integration/test_gameplay_shell.gd:_drive_to_town() and _drive_home() assume the destination map exists immediately after E. Change these shared helpers to await the new transition so their many existing callers still test the destination.
- Two assertions in that same suite pin _primary_modals.size() == 10; the new market panel should make 11.
- tests/integration/test_finale_cue.gd assumes E at market instantly starts the finale cue. It must prove the extra Enter-confirm step while retaining the cue-lifetime assertion.
- tests/integration/test_gameplay_shell.gd:test_passive_clock_ticks_pauses_and_keeps_late_day_interactive hardcodes two 0.25-second increments for the old 0.5 rate; rewrite around the *current* GameRules constant, not a magic literal.

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

The first two lines are quick iteration checks; the last three are required committed-head gates, alongside GitHub-hosted CI. Agent-operated/MCP-driven native end-to-end checks and 1080p screenshot comparisons are also mandatory, not optional manual review.

## Task 1 — Prove title selection behavior, then change the single selection seam

**Files:** scripts/ui/title_screen.gd; tests/integration/test_app_launch.gd; existing godot-e2e app launch tests.

1. Add/update a failing integration test that seeds a *validated* Day 5 save through SaveRepository, constructs AppRoot, and asserts TitleScreen.selected_action() == "continue" with the Continue gradient/Enter keycap visible. Send a real ui_accept input and assert the world restores Day 5 and the saved slot is not overwritten. Retain the explicit New Game path and a missing, invalid, incompatible-save case.
2. In TitleScreen.set_continue_state(), set _selected_index from the Boolean availability in one place; do not add new state to AppRoot, validators, SaveRepository or the persisted document. Continue button focus and pointer selection still behave normally.
3. Update the existing title/keycap test to reflect valid-save Continue selection and the ability to move the selection back to New Game. Check that returning to the title after the result reuses the availability check.
4. Add a real-key godot-e2e launch scenario for save present versus missing. A native screenshot at 1920×1080 must match the highlighted-row intent in mockup **A1** (localized labels may differ).

**Done when:** The failing test becomes green; valid-save Enter resumes the existing run, while missing/invalid-save Enter still creates Day 1. No second confirmation panel is introduced.

## Task 2 — Add market confirmation without pre-committing a finale

**Files:** scenes/ui/market_confirm_panel.tscn (new); scripts/ui/market_confirm_panel.gd (new); scripts/ui/game_hud.gd; scripts/world/world_shell.gd; assets/i18n/strings.csv; tests/integration/test_gameplay_shell.gd; tests/integration/test_finale_cue.gd; tests/unit/test_localisation.gd.

1. Add red-first integration coverage: Day 14 E at market opens an input-blocking card with no change to GameSession.snapshot() or persisted save; Esc restores the exact state and world input; Enter results in exactly one FINALE_TRIGGERED command and the same result as the existing direct canonical command. Also assert Day 1 E remains the original MARKET_NOT_READY toast and never shows the card.
2. Build a **single, focused** MarketConfirmPanel Control following the existing City Pop style and A2: gradient market header, end-of-season question, body, explicit bag-not-sold amber warning, Enter/confirm and Esc/cancel. Use existing UiStyle primitives/market icon and translations, and wire standard signals; do not invent a generic confirmation service. Display only on the eligible Day 14 E path.
3. Register the new panel in GameHud._primary_modals and _esc_close_order; expose open_market_confirmation(), close_market_confirmation() and one market_confirmed signal to WorldShell. Use _open_modal/_close_modal to keep clock and input gated. Ensure repeated accept or modal-close events cannot run finale twice.
4. On market E, WorldShell checks snapshot()["day"] and *only shows the card* if Day 14; all earlier days continue through the old refusal code. On confirmed Enter, invoke GameSession.trigger_harvest_finale() once with the actual market cell and pass the outcome to _finish_finale(). When starting the finale, set the finale SFX lock before dismissing the market card, as already done for sleep.
5. Update the two modal-registry count pins (10 -> 11) plus the finale cue test, and add explicit localization assertions for every new A2 text key. Never weaken existing canonical Day 14 bed and shop/market validation tests.
6. A MCP-operated/native screenshot of this modal must match mockup **A2** at 1920×1080 (City Pop gradient, full warning, Enter/Esc clearly visible, no overlap/clipping).

**Done when:** Cancel is nonmutating, confirm uses the original finale and cue, and all other modals remain mutually exclusive.

## Task 3 — Make both truck rides visually readable and input-atomic

**Files:** scenes/ui/travel_overlay.tscn (new); scripts/ui/travel_overlay.gd (new); scripts/ui/game_hud.gd; scripts/world/world_shell.gd; integration/headless/e2e travel tests.

1. Add meaningful red-first tests for both directions: immediately after successful E the travel overlay is active, world movement/interaction and passive clock are blocked, and destination time strings come from the exact GameSession before/after snapshots. Invalid travel requests must show no overlay and must not change map/time.
2. Add one **transient** travel overlay Control under GameHud (separate from _primary_modals because load_map() calls close_modals()). Compose a near-black ColorRect, existing kei truck art, dashed road and B1 title/time pill. Keep it owned by HUD; it has no gameplay authority. Expose small show/fade/finish methods and is_active() to GameHud, and count activity in has_blocking_modal().
3. In WorldShell._attempt_travel(), capture snapshot, run GameSession.travel(target) once, capture the resulting snapshot, and **activate the HUD travel gate synchronously before the first await**. The old immediate map cut is replaced by a straightforward await sequence: fade out ~0.25s, hold card ~1s, load_map(true) while dark, fade in ~0.25s, clear overlay and release input. Use the existing HUD modal_state_changed signal to update WorldShell's gate. No tween manager, no cutscene system, no additional persisted flags.
4. Feed GameRules.format_time(before["time_minutes"]) and GameRules.format_time(after["time_minutes"]) to the card, and label the nominal charge from GameRules.TRAVEL_MINUTES. Test a 21:45 → 22:00 clamped trip as well as an ordinary 12:05 → 12:35. Direction label derives from new snapshot location. Do not call GameSession.advance_clock() or the travel command a second time during the animation.
5. Keep load_map()'s normal player reparenting, old-map disposal and modal cleanup. Ensure the overlay survives the swap; do not reopen interaction until its final fade ends. Cancelling held farming gestures, closing old modals and handling scene teardown must not leave a blocking orphan overlay.
6. Update **shared** _drive_to_town/_drive_home() helpers to await completion; update headless/world-smoke tests and other assertions that expected an immediate TownMap/FarmMap. Add a Godot E2E real-E, both-directions test of gated controls and destination HUD clock.
7. Take MCP-driven 1080p screenshot(s) mid-transition with the real town/farm backdrop, compare against **B1**: near-black scrim, truck and dashed road, direction, before→after times and “+30 min” fully legible. Existing assets only; no SFX or new image-generation task.

**Done when:** Both trips use one authoritative command and an uninterrupted gate; no 30-minute cut appears as a one-frame map flash.

## Task 4 — Measure and adjust passive clock, and fix clock-bound tests

**Files:** scripts/game/game_rules.gd; scripts/world/world_shell.gd **only if a bug in current gate is exposed**; tests/integration/test_gameplay_shell.gd; a focused agent-operated native tour or tests/e2e/gameplay_day_one_test.gd; README.md; CLAUDE.md.

1. Baseline the real current 0.5 s/min behavior by running a repeatable native Godot itinerary: start from a clean save, walk and farm until stamina is exhausted, travel to and from town using actual E interactions, return to the bed, and note the game-time clock and wall-clock duration. **Do not insert idle time or teleport for pacing measurement**. Keep tutorial/pause screens closed during active time.
2. Change **only** GameRules.REAL_SECONDS_PER_GAME_MINUTE. Try the narrow candidate range around 0.10–0.20 s/min as an empirical starting point, rerun exactly the same itinerary, and choose a rate where a typical completed day returns between about **18:00 and 22:00**. Record old rate, chosen rate, start/end time, elapsed real time and route observations in the PR description. If the first candidate misses, iterate; do not claim acceptance without a recorded passing run.
3. Rewrite passive-clock integration checks using the selected constant (fractional accumulation and exact whole-minute rollovers) instead of hard-coded old-rate 0.25+0.25 arithmetic. Preserve coverage for panels, onboarding, window focus-out/in, no pause catch-up, hitch clamp, 22:00 cutoff and late-day accessibility.
4. Assert the new market and travel overlays hold the **clock** as well as movement. Focus-out during travel must not bank extra minutes; after travel the HUD and session show the same exact destination time.
5. Update README.md and CLAUDE.md to state the final measured tuning rather than describing 0.5 s/min as provisional. Keep the save, action, stamina, weather, crop and travel duration docs unchanged. Recheck any integration route whose time-budget expectation was coupled to passive ticks.

**Done when:** A reproducible *agent-operated, input-driven* full-day record demonstrates evening pacing, and all pause/focus/cutoff regressions pass. A mathematical calculation alone or a seeded instant-command fixture is not enough to certify subjective day pacing.

## Task 5 — Full automated end-to-end verification and visual evidence

Use the **same HPA-775 PR** for the implemented code, related tests and evidence. No follow-on implementation PR and no additional image-art/SFX ticket are necessary.

- Run GUT and the clean headless verifier on committed HEAD, plus the GdUnit4 and godot-e2e lanes and the repository's hosted CI. Exercise the existing **Promising (175G)** and **Heart of the Harvest** routes and Day 14 bed finale; money, shipped crop totals and result bands must be unchanged.
- Run MCP-controlled/native e2e with real keyboard E/Enter/Esc/WASD on **one supported platform**. Verify valid-save Continue (Day N), no-save New Game (Day 1), Day 14 market cancel then confirm, and both directions of travel including the nominal 30-minute and near-cutoff cases. Check no state mutation while market confirmation is merely open and no clock ticks during blocked overlay.
- Capture native **1920×1080** screenshots of (1) title Continue selected, (2) Day 14 market confirmation and (3) town/home travel overlays. Compare each visually to **Linear HPA-775 A1/A2/B1**, using the attached boards as oracle. Check City Pop spacing, warning/action legibility, proper fade/direction/time, and no clipped or overlapping controls. The screenshot checks are agent/MCP-performed; retain references or CI artifacts in the PR evidence, not a manual sign-off.
- Record the chosen passive rate and *observed* evening time for the representative day, with repeatable route actions and real elapsed duration. A photo at 22:00 after deliberate idling does not satisfy this check.
- Confirm there are no new sprites/audio, no persisted-state/schema diffs and no changes to stamina/economy/command costs. Keep change scope inside HPA-775.

## End-to-end acceptance checklist (all required before ready-for-review)

- [ ] **Real UI, saved run:** valid Day N save makes Continue the selected 1080p row; MCP real Enter resumes Day N and does not replace the save; invalid/missing slot selects New Game and starts Day 1.
- [ ] **Real UI, market:** Day 14 E opens A2, Esc leaves complete session snapshot/save/money intact, Enter starts one canonical finale and result, before-Day14 E still refuses, and Day 14 bed finale remains valid.
- [ ] **Real UI, travel:** both E-triggered truck directions show B1 fade/travel card, times match actual pre/post session and destination HUD; 22:00 clamp is represented honestly; no input or passive clock slips through while the overlay is visible.
- [ ] **Time:** a reproducible, no-idle, full-stamina-use plus town round-trip native session ends at 18:00–22:00, with the chosen constant, precise times and wall duration documented.
- [ ] **Automated visual:** MCP screenshot checks at native 1920×1080 match A1, A2 and B1 in composition/legibility, with no clipping or visible map flash.
- [ ] **Regression:** modal/focus pause and delta-clamp checks; existing garden/economy/social/Promising/Heart tests; committed-head GUT/headless, GdUnit4, godot-e2e and hosted CI all green.
- [ ] **One PR:** only this HPA-775 PR contains both planning docs and all subsequent implementation. No human approval, manual acceptance criterion or second PR is required.

## Stop conditions and reporting

If the representative full-day route still ends before 18:00, if an existing headless test cannot reliably await the transition, or if a native visual check fails, leave the relevant checkbox unchecked and report the actual result in the PR. Do not wave through a failing gate, introduce arbitrary sleeps to inflate the pacing measurement, or expand scope into HPA-743/HPA-861.
