# HPA-775 — Protect the run and pace the day: design specification

**Status:** Proposed; planning only (no runtime changes or verification claimed)  
**Issue:** https://linear.app/cwchanap/issue/HPA-775/protect-the-run-and-pace-the-day  
**Repository/base:** cwchanap/phoenix, main at c5eb32553d40d882a7bf156880096093e62ff1dd (16 Nov 2026 inspection)  
**Delivery:** One ticket, one PR. Continue implementation on this same draft PR after plan review.

## Outcome and evidence

A valid existing run is the Enter-key default, the Day 14 market cannot terminate a season without confirmation, a normal active day uses most of the 06:00–22:00 window, and each 30-minute truck ride is communicated through a short, noninteractive transition.

This addresses the 15 Nov UAT attached to HPA-775. Use its authoritative mockup boards **A1 (title)**, **A2 (market confirmation)** and **B1 (travel beat)** for automated native 1920×1080 screenshot checks. The image attachments and HTML source are references, not new art work.

## Existing architecture and non-negotiable boundaries

- Godot 4.7.1, statically typed GDScript; GameSession alone owns rules, clock minutes, travel, finale and persistent state. WorldShell owns session and input; GameHud owns presentation.
- AppRoot._load_title_state() already distinguishes missing, valid, invalid and incompatible saves and calls TitleScreen.set_continue_state(). TitleScreen initializes _selected_index to New Game and only resets selection when Continue is *unavailable*.
- WorldShell's passive clock is driven by GameRules.REAL_SECONDS_PER_GAME_MINUTE = 0.5. Its existing input-modal gate, focus notifications, CLOCK_DELTA_CLAMP = 0.1 and GameSession.advance_clock() must remain intact.
- Town Harvest Market currently calls GameSession.trigger_harvest_finale(target) directly from WorldShell._interactable(). This command changes the run when eligible; never call it merely to decide whether to show a confirmation.
- GameSession.travel(target) atomically changes the transient map location and applies the authoritative nominal 30-minute time charge, clamped to 22:00. WorldShell.load_map(true) disposes the old map, reparents the same player and refreshes presentation. It also calls GameHud.close_modals().
- New game/save encoding, currency, stamina, action costs, shipping settlement, crop/weather rules, travel duration and finale result calculation do not change. No save migration, no extra save slots and no compatibility scaffolding.

## Decision 1 — Safe keyboard default without a new confirmation

In TitleScreen.set_continue_state(available, status), choose the Continue row when available is true; otherwise choose New Game. AppRoot's existing validated-save check remains the authority for availability. Both rows remain selectable with W/S and mouse, and explicitly choosing New Game still works. Reopening the title from the result refreshes the default from the current save. Invalid/incompatible/unreadable saves remain visible only through existing status warnings and default to New Game.

No New Game confirmation dialog: the request specifically excludes it. This reduces accidental Enter selection, but does not pretend to protect a user who explicitly selects New Game.

## Decision 2 — Confirm the Day 14 market, keep the domain untouched

On E at TownContract.MARKET_CELL, WorldShell reads the current session snapshot:

- Before Day 14, dispatch the existing command as today so MARKET_NOT_READY produces its existing refusal toast. Do not show a confirmation.
- On Day 14 while ordinary world input is enabled, ask GameHud to open a new **MarketConfirmPanel** (a small native City Pop Control/scene). Merely opening or cancelling it does not change any session field, save or wallet.
- GameHud registers the panel as one primary blocking modal, connects Enter/confirm to a dedicated market_confirmed signal, connects Esc/cancel to close, and preserves the normal one-modal exclusivity, tutorial masking and pause-clock gating. Ignore duplicate Enter while confirmation has already started.
- WorldShell's confirmation handler calls the existing GameSession.trigger_harvest_finale(player.current_target_cell()), then passes its result through the unchanged _finish_finale() path. That path retains save-on-finale, final SFX and result-screen lifetime behavior. Make the finale lock suppress any modal-close confirmation sound.
- A Day 14 bed finale remains unchanged and uses its existing confirmation.

**A2 appearance:** native 1080p centered white card on dimmed town; warm City Pop gradient header with existing market icon, “HARVEST MARKET · DAY 14” and “End the season?”; one short finality line; amber “Crops in your bag are not sold. Ship them first.” notice; prominent Enter / “Open the market” pill; quiet Esc / “Not yet” action. Use UiStyle tokens and existing icons, not a generic modal framework.

## Decision 3 — Retune only passive time

Keep GameRules.REAL_SECONDS_PER_GAME_MINUTE as the **single** tunable constant, using real active-world elapsed time only. Collect a baseline from a reproducible native Godot route consisting of realistic movement, spending all 20 stamina where possible, at least one town round trip, and ending at the bed; record elapsed wall time and in-game return-to-bed time. Adjust that one rate (initial candidates around 0.10–0.20 seconds/game minute, not a pre-approved fixed number), rerun the route and choose a value giving approximately **18:00–22:00** on a typical actively played day.

Do not accelerate action minutes, lower stamina, add idle waits to fake the outcome, or modify GameSession.advance_clock(). A route that cannot reach the goal under the existing 22:00 clamp must be reported and retuned rather than declared passing. Retain focus-out, blocking-modal and travel-presentation pauses and the existing hitched-frame delta clamp. Update README.md and CLAUDE.md from their provisional 0.5 values to the measured final rate and its reproducible validation evidence.

## Decision 4 — An overlay that survives the map swap

A transient **GameHud travel overlay**, separate from the ordinary _primary_modals list, owns a dark full-screen fade and a small B1 truck card. This is required because WorldShell.load_map() closes ordinary modals. Include the overlay in GameHud.has_blocking_modal() and explicitly consume/ignore world and menu shortcuts while the travel beat is active. It does not own location, calculate minutes or persist anything.

WorldShell._attempt_travel(target) runs the following one-shot sequence:

1. Capture the pre-travel session snapshot; invoke GameSession.travel(target) **once**.
2. On failure, show the existing feedback and leave the current map and HUD unchanged.
3. On success, capture the post-travel snapshot immediately, synchronously show/activate the HUD overlay and emit the normal input-gate change (no one-frame input/clock gap).
4. Fade to dark (roughly 0.2–0.3 seconds), display the B1 card for roughly one second, and invoke the existing load_map(true) **behind the opaque overlay**. The single GameSession and same Player/HUD instances survive.
5. Fade into the destination at the contract-defined arrival cell; remove the overlay and release input only after it fully finishes. Cancel pending repeat interaction/held farming gestures.

The card direction comes from **post-travel** snapshot location. The from/to clock strings come from **before and after GameSession snapshots** through GameRules.format_time(); they must not be calculated independently. The “+30 min” caption describes the nominal GameRules.TRAVEL_MINUTES charge even when the destination clock is clamped at 22:00. A successful travel is still exactly one atomic session command, independent of animation frame timing.

**B1 appearance:** a near-black world fade, existing kei-truck graphic above a simple dashed road, centered “Driving to town” / “Driving home”, a source → destination time pill and “+30 min”; no skip control. Avoid new truck sprite, SFX, animation systems or additional game state. If the scene is being freed during a transition, the coroutine should return without trying to reopen input.

## Localization and visual contract

The i18n CSV header is **keys,zh_TW,ja**: English text is the key, not a fourth “en” column. Localize all *new* card text in en (key), Taiwan Traditional Chinese and Japanese, including the directional travel headings, market labels, warning, and keyboard action captions. Keep stable 1920×1080 native layouts, scaling/nearest-filtered existing art and the current City Pop tokens; avoid creating new assets or altering existing source sheets.

Automated visual comparison is against **HPA-775 attachment A1, A2, B1** respectively, allowing language substitutions and differing live state values. A1 must highlight Continue with a valid save. A2 must show the warning and Enter/Esc actions without cropping or overlapping the town. B1 must show the truck, directional title, clock pill and visible +30-min caption with legible fade.

## Explicit non-goals

- New Game confirmation, save-slot changes or save-schema migration.
- Gameplay/economy/stamina/action cost rebalance, additional town destinations, or new dusk visuals.
- New image or audio generation; no skip button, loading-screen system, generic cutscene/transition manager or new engine abstraction.
- HPA-743 interaction reach/fading/backdrop and HPA-861/HPA-863 artwork.

## End-to-end behavior contract (implementation must prove)

1. **Save protected:** App launch with a valid persisted Day N state shows Continue highlighted and real Enter resumes Day N; missing/invalid save highlights New Game and Enter starts Day 1. Explicit New Game still works.
2. **Market safe:** Day 14 E shows A2 but does not commit or save; Esc leaves the exact same snapshot/money/day; Enter triggers exactly one canonical finale and result. Day 1–13 still show the refusal toast; bed finale remains possible.
3. **Active pacing:** An MCP-operated native reference day actually consumes stamina and makes a town round trip, returns at approximately 18:00–22:00, with measured time recorded in the PR. No intentional idle padding.
4. **Travel readable:** Both truck directions show B1 fade/card and accurate before/after times; the HUD at arrival agrees; all input and clock advancement are disabled during the beat, and resumes afterwards, including when 22:00 caps the displayed time.
5. **Regression:** WorldShell focus-out/modals pause the clock, a hitch banks no time, GameSession.travel() remains atomic, and GUT, GdUnit4, godot-e2e plus existing Promising / Heart finale routes pass.
6. **Visual:** Agent-driven native 1080p screenshot comparisons with Linear mockups A1/A2/B1 pass. No human acceptance step is required or counted as verification.
