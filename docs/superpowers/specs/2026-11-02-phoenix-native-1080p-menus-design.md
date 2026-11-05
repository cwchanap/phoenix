# HPA-682 — Native 1080p menus and panels: design specification

**Status:** Revised for design review, 2026-11-02 (addresses PR #35 review)  
**Linear:** https://linear.app/cwchanap/issue/HPA-682/restyle-phoenix-menus-and-panels-for-1080p  
**Visual reference:** https://claude.ai/artifact/1DdvEPpVjfLwCGqSpCH2VV  
**Direction:** https://claude.ai/artifact/91H3GuS9EcHmpb4NHqB5cF  
**Dependencies:** HPA-680, HPA-681 and HPA-713 already landed.

## Goal and boundaries

Finish the City Pop 1080p migration for the **13 non-HUD reference states** while retaining existing gameplay, controls, panel methods, signals, localization, and save behavior. Implement on **this same HPA-682 PR** after the planning review; there is one PR per task, not a separate implementation PR.

- Runtime: Godot 4.7.1, statically typed GDScript, native 1920×1080 `Control` layouts; the existing `canvas_items` stretch handles the 960×540 minimum window without new layout branches.
- Reuse `UiStyle`, M PLUS 1/Noto fallbacks, existing textures, and `SlantTag`; do not build a second design system or new navigation/state framework.
- `GameHud` remains the only primary-modal/input gate; `WorldShell` remains the only session owner.
- No changes to gameplay rules, snapshot/save schema, world maps, balance, story dialogue, new assets, SFX, or engine/runtime.
- There is no screenshot-golden CI gate (removed by PR #29); native visual review is human, backed by GUT, GdUnit4, and godot-e2e behavior checks.

## Decision 1: code-build the presentation consistently

**All 13 non-HUD surfaces are code-built in their existing panel/controller scripts**, following `HudChrome` and `OnboardingOverlay._build_tutorial_card()`. Their `.tscn` resources stay as a root `Control` with the same script and **unchanged root node names**; `GameHud` still instantiates the existing resource paths. Remove each migrated panel's legacy `_style_tree`/`_style_authored_tree`/node-path theme setup rather than preserving two styling systems.

The existing `UiStyle.card()`, `gradient_surface()`, `keycap()`, and constructor-driven `SlantTag` produce runtime controls. A scene-authored phone frame mixed with runtime builder styling would complicate child ownership and duplicate work. Code-building resolves that ambiguity before any migration.

Use Godot `Container` layout and native anchoring in the **runtime-built control tree**. Code-built does not mean freehand pixel-positioning every child: controls should size/reflow predictably within the fixed native canvas. Keep code local to a panel except when a visual helper has at least two real consumers.

## Decision 2: small code-built PhoneFrame; no special-mode framework

Create `scripts/ui/phone_frame.gd` (`PhoneFrame`, a small `Control`/`PanelContainer` presentation class). Construct one per phone surface via `UiStyle.phone_mount()`. It owns **only** the rounded bezel, status-bar time, home indicator, one app-header band, one footer row, and a content mount (such as a `VBoxContainer`). It owns no app navigation, modal state, session data, settings, or input.

- **Five app surfaces:** Bag, Almanac, Calendar, Settings and Sleep configure the frame's gradient app header via `set_app_header()`/`app_header_accessory()`, build body rows in `content_mount()`, and add one truthful footer-hint row of controls via `footer_mount()`.
- **Pause:** phone home screen with wallpaper/app tiles and Controls widget; it does not call `set_app_header`.
- **Morning Summary:** lock-screen composition/notifications without an app header. Do not require diary content until HPA-684.
- No `mode` enum or variant registry in `PhoneFrame`. Each panel owns its content and presentation choices.

**Clock ownership:** `GameHud.render(snapshot)` already receives `time_minutes`/`day`/`weather`, including passive ticks. Format the time once with `GameRules.format_time(int(snapshot["time_minutes"]))` and update the existing phone-bearing panels' small status-time setters from that render path. Pause additionally receives day/weather for its "Paused" summary. No new parameters on `open_*`, no UI-local ticking, no synthetic real-world time, and no persisted status data. Sleep uses the session clock in the status bar while the alarm target itself remains 06:00.

## Decision 3: preserve modal ownership, make Pause shortcuts truthful

Retain `GameHud._open_modal()`, `_esc_close_order`, `has_blocking_modal()` and `modal_state_changed`; one primary modal remains visible and world input is blocked while it is open. Opening intro and Morning Summary continue to have their current special blocking semantics; Settings returns directly to Pause using the existing atomic transition.

The Pause home tiles display I/B/C/O keycaps, so their keyboard hints must work:

- `I`/`B`/`C` open Bag/Almanac/Calendar from either the world **or when Pause is the active modal**, using `GameHud.open_bag()`/`open_almanac()`/`open_calendar()`. Tile clicks use those same calls.
- An app closes to the **world** via its own toggle key or Esc, as today. Do not introduce a back stack or return to Pause for these apps.
- `O` opens Settings **from Pause only**. Esc on Settings returns to Pause; Esc on Pause returns to the world.
- No other modal (shop, dialogue, sleep, summary, intro, Settings) may be bypassed by an I/B/C hotkey. `_open_modal()` still guarantees one modal.
- Add one focused GUT integration test for Pause → I → Bag with Pause hidden, one primary modal and world input blocked. Existing pause/settings and close-path tests remain.

This is one narrow key-condition change in `GameHud._unhandled_input()`, not a second input owner.

## Decision 4: screen content without new systems

| Surface | City Pop 1080p presentation | Preserved behavior/data |
| --- | --- | --- |
| Pause | Wallpaper home, Bag/Almanac/Calendar/Settings tiles, Controls, day/weather/Paused text | Esc, O, new truthful I/B/C route; mouse tiles reuse `GameHud` |
| Bag | Seeds, harvested crops, selected-item detail and pending-bin payout | Selection, quantities and shipment facts from snapshot |
| Almanac | One crop per page, big existing crop art and current facts | A/D and `selected_kind()`, current prices/growth |
| Calendar | 7-column 14-day grid plus Coming Up | Existing `weather_history`/crop calculations; **no invented forecasts** |
| Settings | Music, Sound, Window, Tips, **Language** | Five existing settings rows, A/D editing and preference persistence |
| Morning | 06:00 lock screen, weather/farm/bank, shipments, wither warning and Saved/error notice | Existing summary fields and acknowledge behavior, **no fake diary** |
| Sleep | Alarm app, 06:00 target, Day 14 boundary, Sleep/Not Yet | Existing confirm/cancel and sleep signal |
| Shop & Shipping | Matching world cards, selected-row tint, quantity stepper, exact action pill | Prices/quantity bounds, M=max, disabled states, request payloads |
| Dialogue | Visual-novel box, slanted name tag, role/hearts, existing portrait, gift chips | Line progression, gifting and close-friend sequence |
| Onboarding | Letterboxed intro and Day 1 slanted tag, existing tutorial | Opening acknowledgement and tutorial-card visibility |
| Title | Current art, left fade, gradient selected action and visible status/error | New Game, Continue, keyboard navigation and save validity |
| Result | SEASON COMPLETE, stats and three resident cards | Finale tier, score, endings and button actions |

Keep current villager names and translated strings from main. Do not mix in HPA-684's 14 diary lines or story-specific copy; omit the optional diary area until its source exists. HPA-683/685/686 own town/farm behavior. HPA-687 owns town art. No new icon/portrait/audio work within this code ticket.

## Decision 5: migrate scale and tests with each surface

`GameHud._build_modals()` currently scales all ten modal roots using a legacy loop; Title, Result and the intro scale themselves. **In the same commit that rebuilds a surface**, remove it from the compatibility loop (or its self-call) and migrate its tests. Otherwise the new native panel would still render at 3×.

Use the existing `test_legacy_640x360_ui_roots_fill_the_1080p_canvas()` in `tests/integration/test_app_launch.gd` as the migration anchor: invert the migrated assertions to `scale == Vector2.ONE` and a full 1920×1080 root rect; add each surface as it migrates. When the final surface is native, remove the empty loop and `LEGACY_LAYOUT_SIZE`/`fit_legacy_*` helpers.

Reduce tests' reliance on scene-internal `Frame/...` paths. Keep existing public `selected_*()` methods and introduce **only a few focused read-only presentation accessors** needed to assert existing behavior (e.g. shop action text/price, calendar cell state, sleep Day 14 visibility, dialogue current line). Do not create a generic test API/framework, and do not add accessors just to mirror every new layout element. Keep behavioral and model assertions, not screenshots as CI.

A verified duplication to remove: `GameHud.render()` currently sets `_day14_sleep_boundary` and the Day 14 text, while `SleepPanel.present()` already computes and sets the same label from the snapshot. Leave the warning and its presentation owner inside `SleepPanel`; remove the redundant `GameHud` node lookup and update.

In the final cleanup, search **all** production references to legacy `UiStyle` constants and helpers, not just `scripts/ui`. `scripts/world/farm_action_effects.gd` uses `UiStyle.GOLD` for harvest `+1`; change that to an appropriate retained City Pop hue before deleting the legacy palette. Point `UiStyle.text()`'s default at `INK` and drop obsolete `font(..., _mono)`, `panel()` and `button()` only when no callers remain.

## Fixed visual acceptance checklist

The approved mockup has 14 references; **01-hud** and the native `hud-tip` tutorial card belong to completed HPA-681. HPA-682 owns the remaining **13**:

- [ ] `02-seed-shop`
- [ ] `03-shipping-day14`
- [ ] `04-bag`
- [ ] `05-almanac`
- [ ] `06-calendar`
- [ ] `07-dialogue`
- [ ] `08-morning-summary`
- [ ] `09-sleep`
- [ ] `10-pause`
- [ ] `11-settings` (includes additional Language row)
- [ ] `12-intro`
- [ ] `13-title` (also check incompatible-save status)
- [ ] `14-result-heart-of-harvest`

Review those 13 visually at **1920×1080** and **960×540**, in **en**, **zh_TW** and **ja**. Check clipping/long labels, font fallback, current data, focus and enabled/disabled states, exact-action hints, Day 14 warnings, save failures and top-tier result. These are reference *states*, not 13 separate code modules; Shipping/Title/Result variants are existing data paths. No duplicate state-specific test framework is necessary; retain and adjust existing regression tests.

## Verification and non-goals

Every migrated surface family must form a **green commit on this single PR**: code-built panel + removal of its scale entry + behavioral assertions/seams + translations + successful `./tools/verify-clean.sh` (run on committed HEAD). Existing GdUnit4 and godot-e2e suites remain required as relevant, plus the final full CI. Avoid parallel UI architectures, per-resolution special cases, art tasks, new save fields, framework abstractions, or a second implementation PR.
