# HPA-775 — Protect the run and pace the day: design specification

**Status:** Implemented on PR #42 (title default, market confirmation, travel overlay, 0.15 s/min clock); automated suites and native tours green at head. Evidence limits are recorded in the implementation plan.  
**Issue:** https://linear.app/cwchanap/issue/HPA-775/protect-the-run-and-pace-the-day  
**Repository/base:** cwchanap/phoenix, main at c5eb32553d40d882a7bf156880096093e62ff1dd (16 Nov 2026 inspection)  
**Delivery:** One ticket, one PR. Continue implementation on this same draft PR after plan review.

## Outcome and evidence

An **unfinished** valid saved run is the Enter-key default; a completed season defaults to New Game. Day 14 market exit requires confirmation, the passive clock is calibrated against a stated human-pace assumption rather than automation speed, and each 30-minute truck ride is communicated through a short, noninteractive transition.

This addresses the 15 Nov UAT attached to HPA-775. Use its authoritative mockup boards **A1 (title)**, **A2 (market confirmation)** and **B1 (travel beat)** for **agent-operated native 1920×1080 frame captures and visual comparison**; no screenshot-golden or pixel-diff gate. The image attachments and HTML source are references, not new art work.

## Existing architecture and non-negotiable boundaries

- Godot 4.7.1, statically typed GDScript; GameSession alone owns rules, clock minutes, travel, finale and persistent state. WorldShell owns session and input; GameHud owns presentation.
- AppRoot._load_title_state() already distinguishes missing, valid, invalid and incompatible saves and calls TitleScreen.set_continue_state(). TitleScreen initializes _selected_index to New Game and only resets selection when Continue is *unavailable*.
- WorldShell's passive clock is driven by GameRules.REAL_SECONDS_PER_GAME_MINUTE = 0.5. Its existing input-modal gate, focus notifications, CLOCK_DELTA_CLAMP = 0.1 and GameSession.advance_clock() must remain intact.
- Town Harvest Market currently calls GameSession.trigger_harvest_finale(target) directly from WorldShell._interactable(). This command changes the run when eligible; never call it merely to decide whether to show a confirmation.
- GameSession.travel(target) atomically changes the transient map location and applies the authoritative nominal 30-minute time charge, clamped to 22:00. WorldShell.load_map(true) disposes the old map, reparents the same player and refreshes presentation. It also calls GameHud.close_modals().
- New game/save encoding, currency, stamina, action costs, shipping settlement, crop/weather rules, travel duration and finale result calculation do not change. No save migration, no extra save slots and no compatibility scaffolding.


## Decision 1 — Save-aware default including completed runs

TitleScreen.set_continue_state() remains the single selection seam. AppRoot._load_title_state() continues validating save compatibility and should pass the *preferred selection* alongside availability:

- Valid save with `finale_triggered == false`: Continue is available **and selected** by default; Enter resumes the existing run.
- Valid save with `finale_triggered == true`: Continue remains available for deliberately reopening the result, but **New Game is selected** on title entry and on Result → Return to title. Enter does not loop back into the already-finished result.
- Missing, invalid, incompatible or unreadable save: Continue disabled and New Game selected; retain the existing warning for invalid slots.

Keep one tiny explicit preference parameter on `TitleScreen.set_continue_state(available, status, prefer_continue)` (default preference may be true) rather than inventing a new title-state service. **Assign `_selected_index = 1 if (available and prefer_continue) else 0` on every call**, not only when Continue is unavailable. AppRoot derives the preference only after validation, so Result → Return to title resets the selection even when the previous title visit had Continue highlighted. W/S and pointer selection continue working; choosing New Game remains explicit. No New Game confirmation dialog, new save slot or persistence format change.


## Decision 2 — Confirm the Day 14 market, keep the domain untouched

On E at `TownContract.MARKET_CELL`, `WorldShell` compares the current session day to `GameRules.MAX_DAY`:

- Before Day 14, call the existing `GameSession.trigger_harvest_finale(target)` so the original MARKET_NOT_READY toast displays; do not add a separate session preview query.
- On Day 14 with ordinary world input enabled, open a focused native `MarketConfirmPanel` (small Control/scene) through `GameHud`. Merely opening or cancelling it does not mutate the session or save.
- Register it in GameHud's ordinary `_primary_modals` and Esc-close order, and emit one `market_confirmed` signal for WorldShell. This reuses existing exclusive modal/tutorial/input/clock gating and the controls from `SleepPanel`.
- WorldShell's confirmation handler must copy the existing `_finale_in_progress` early return from `_on_sleep_requested()` because a HUD signal bypasses the world-input gate; no second custom duplicate-enter state flag. On confirmation invoke the existing `GameSession.trigger_harvest_finale(player.current_target_cell())` once.
- Keep `_finish_finale()` as the canonical finale/SFX/save/result path. After the finale flag and HUD SFX lock are set, use the existing `hud.close_modals()` to silently close whichever confirmation is open; it replaces the sleep-only close and requires no new close API.
- The Day 14 bed finale and all economy/shipping settlement rules stay intact.

**A2 appearance:** a centered native 1080p white City Pop card over a dimmed town. Reuse `UiStyle.gradient_band(UiStyle.HEADER_GRADIENT, 30, ...)` as in `ShopPanel`; `UiStyle.primary_action` / `ghost_action`; the amber WARN card from `SleepPanel`; and `assets/ui/icons/market.png`. The card shows “HARVEST MARKET · DAY 14”, “End the season?”, a short finality line, an amber “Crops in your bag are not sold. Ship them first.” note, Enter / “Open the market” and Esc / “Not yet”. No generic confirmation framework.


## Decision 3 — Calibrate passive time from the UAT, not from bot speed

Keep `GameRules.REAL_SECONDS_PER_GAME_MINUTE` as the **single** tuning constant. Do not iterate it against agent wall-clock runs: scripted key inputs can be too fast, MCP/tool pauses can be too slow, and an unfocused native desktop can produce **zero** passive ticks.

Use the existing 15 Nov UAT as the baseline, so no new 0.5-second re-baseline is needed: three Day-1 crop operations used 210 action minutes and 18 stamina, and the UAT clock showed about 11:07. Starting at 06:00, that implies about 97 passive minutes, or approximately 48.5 real active seconds at 0.5 s/min.

For a **stated planning assumption**, model a 75-second active-play day (UAT pace plus a town round trip), about 240 action minutes and 60 nominal travel minutes, with a target bed time of **19:30**:

```text
Target elapsed = (19:30 - 06:00) = 810 game minutes
Passive budget = 810 - 240 action - 60 travel = 510 minutes
Rate = 75 real active seconds / 510 passive minutes = 0.1471 s/game minute
Proposed rounded candidate = 0.15 s/game minute
Model outcome = 06:00 + 240 action + 60 travel + 75/0.15 passive
              = 19:20 (20-minute tolerance from the target)
```

Pin the 75-second/240-action/60-travel reference and 18:00–22:00 modeled window in a deterministic GUT test **beside `_run_benchmark_route` in `tests/unit/test_game_session.gd`**, and recheck that route's existing `20:00` anti-stranding bound under the new constant. The rate remains a **modeled human-pace estimate**, not proven subjective player pacing.

Reuse `tests/native_tour/rain_tour_base.gd` to run and record a real-input day **as diagnostic evidence**, logging actual active seconds, game time, the focus flags and travel/market gate observations. Do not retune to that particular agent's speed and do not claim that an automated route measured a representative human pace. If the window never received focus and the clock never ticked, flag the run as invalid pacing evidence rather than treating it as a successful calibration. Keep the current WorldShell modal gate, focus notifications, `CLOCK_DELTA_CLAMP = 0.1`, `GameSession.advance_clock()`, action/stamina/economy, and travel cost unchanged.

Update README.md and CLAUDE.md with the chosen **modeled** rate and stated assumptions. Automated testing covers the specified model and gameplay invariants; subjective real-player pacing remains an openly stated uncertainty, not a required human acceptance gate.


## Decision 4 — HUD-owned one-Tween travel beat

A transient **GameHud TravelOverlay**, outside ordinary `_primary_modals`, owns one node-bound Tween, the dark scrim and the B1 truck card. It survives `load_map()` because that function only closes ordinary modals. Its active state is included in `GameHud.has_blocking_modal()`, and Esc during travel is consumed in the existing `_unhandled_input()` early-return branch (before `open_pause()`). The overlay knows no gameplay rules or persisted data.

Keep `WorldShell._attempt_travel(target)` **synchronous**:

1. Read the before snapshot and invoke `GameSession.travel(target)` **exactly once**. Failure keeps the map/clock/overlay unchanged and shows the existing refusal.
2. Read the after snapshot and immediately call `hud.play_travel(before, after, load_map.bind(true))`; its first synchronous step activates the overlay and emits `modal_state_changed` before any frame boundary. WorldShell cancels held action gestures through its existing input gate.
3. The HUD overlay builds **one** node-bound `create_tween()`: fade the world to dark (~0.25 s), execute `tween_callback(swap)` to run existing `load_map(true)` while covered, hold the B1 card (~1 s), fade the new map in (~0.25 s), then hide and emit `modal_state_changed` to release input.
4. The tween is owned by the overlay/HUD node so scene teardown also kills it; there is no long-lived WorldShell coroutine or post-free resume. Do not create a cutscene manager or new map-load API.
5. Expose only a small `hud.finish_travel()` **test seam**: return immediately if inactive; otherwise **boundedly step** the Tween with `Tween.custom_step()` until the full fade → map-swap callback → hold → fade-in sequence finishes. Do not assume one large step necessarily drains all chained tweeners; assert the callback ran once and the gate was released. Integration and headless helpers use this to avoid real-time 1.5-second waits; real e2e and native tours wait for the actual overlay to release its input gate.

Direction derives from the after-snapshot map. Source/destination times use `GameRules.format_time()` on the **before/after session snapshots**, never independently recomputed. The “+30 min” caption describes `GameRules.TRAVEL_MINUTES`, including a 21:45 → 22:00 clamped arrival.

**B1 appearance and input layer:** the TravelOverlay is a full-canvas `Control` added at the **end of `GameHud._build_modals()`**, after Chrome/Onboarding/ordinary modals and **before `_build_toast()`**, with `MOUSE_FILTER_STOP` while visible so SeedCard/tutorial clicks cannot leak through. Show a near-black scrim, **one frame** of the existing 192×96 two-frame `assets/sprites/kei-truck.png` via an `AtlasTexture` region `Rect2(0, 0, 96, 96)` (nearest filtered), dashed road, “Driving to town” / “Driving home”, a source → destination time pill and “+30 min”. Do not show the raw two-frame texture through `UiStyle.icon()`. No skip control, extra image art or SFX. Test Esc, clicks, input, clock and both map-swap directions.

## Localization and visual contract

The i18n CSV header is **keys,zh_TW,ja**: English text is the key, not a fourth “en” column. Localize all *new* card text in en (key), Taiwan Traditional Chinese and Japanese, including the directional travel headings, market labels, warning, and keyboard action captions. Keep stable 1920×1080 native layouts, scaling/nearest-filtered existing art and the current City Pop tokens; avoid creating new assets or altering existing source sheets.

Native 1920×1080 frame captures from the existing `tests/native_tour/` harness are **visually inspected by the agent** against HPA-775 attachments **A1, A2, B1** respectively. This is a contextual mockup check, **not** a screenshot-golden/pixel-diff test, consistent with the screenshot-golden gate removal on 2026-11-01. Allow language substitutions and differing live state values. A1 must highlight Continue with a valid save. A2 must show the warning and Enter/Esc actions without cropping or overlapping the town. B1 must show the truck, directional title, clock pill and visible +30-min caption with legible fade.

## Explicit non-goals

- New Game confirmation, save-slot changes or save-schema migration.
- Gameplay/economy/stamina/action cost rebalance, additional town destinations, or new dusk visuals.
- New image or audio generation; no skip button, loading-screen system, generic cutscene/transition manager or new engine abstraction.
- HPA-743 interaction reach/fading/backdrop and HPA-861/HPA-863 artwork.

## End-to-end behavior contract (implementation must prove)

1. **Save protected:** App launch with a valid *unfinished* Day N state shows Continue highlighted and real Enter resumes Day N; a completed/finale-triggered save leaves Continue available but selects New Game; a missing/invalid save also selects New Game. Explicit New Game and deliberate finished-run Continue both work.
2. **Market safe:** Day 14 E shows A2 but does not commit or save; Esc leaves the exact same snapshot/money/day; Enter triggers exactly one canonical finale and result. Day 1–13 still show the refusal toast; bed finale remains possible.
3. **Pacing model and diagnostic tour:** The deterministic 75 s active / ~240 action / 60 travel minute reference models an 18:00–22:00 finish at the rounded rate, and the existing benchmark's 20:00 anti-stranding bound holds. A native input-driven tour records real gameplay, travel and focus; its clock result is diagnostic, not used to tune to automation speed. No false claim of human-pace certification.
4. **Travel readable:** Both truck directions show B1 fade/card with accurate before/after times; the HUD at arrival agrees; all input and clock advancement are blocked throughout the one-Tween beat, resume afterward, and the test-only `finish_travel()` allows immediate deterministic integration assertions.
5. **Regression:** WorldShell focus-out/modals pause the clock, a hitch banks no time, GameSession.travel() remains atomic, and GUT, GdUnit4, godot-e2e plus existing Promising / Heart finale routes pass.
6. **Visual:** An agent captures and examines native 1080p screenshots against Linear mockups A1/A2/B1, documenting concrete UI differences without golden-image tooling. No human acceptance or sign-off step is required.
