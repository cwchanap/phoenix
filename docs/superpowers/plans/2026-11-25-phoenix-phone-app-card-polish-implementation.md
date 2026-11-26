# HPA-844 — Phone app and card polish: implementation plan

**Status:** Proposed, documentation-only draft.  
**Design:** [Phone app and card polish](../specs/2026-11-25-phoenix-phone-app-card-polish-design.md)  
**Linear:** [HPA-844](https://linear.app/cwchanap/issue/HPA-844/phone-app-and-card-polish)  
**Branch:** `agent/hpa-844-phone-app-card-polish-plan`; implement and verify on this same PR.  
**Reviewed base:** `aec429d6c2d9c0bdac8c0ef05d4f37b475fad182`. Recheck main before coding.

## Preflight

- [ ] Refresh main and diff against reviewed base, especially HPA-863 map geometry and any merged UI changes. There is no competing HPA-844 PR. PR #49 is unrelated generated-capture cleanup; don't depend on it.
- [ ] Inspect both attached reference images and, if layout details needed, HTML #c1 in the ticket. Use existing PhoneFrame/UiStyle and current authored farm. Identify localization and test assertions before touching code. No new assets needed.
- [ ] Run baseline verifier and note any pre-existing failures. Use Godot 4.7.1, standard non-.NET. Isolate save/settings paths/HOME, don't touch real player files. Tests disable passive tick where appropriate.
- [ ] Audit repository references to old source keys, SavePath/save_path_text(), Saved., SAVED, Legend, JpSubtitle, Season, action labels, node paths, and screenshot/mock references. The CSV validator covers rules and row completeness, not every UI-only key.

## 1. Fix the tip card key and visible-menu contract

**Files:** project.godot, scripts/ui/onboarding_overlay.gd, scripts/ui/game_hud.gd, tests/integration/test_gameplay_shell.gd, tests/e2e/ui_navigation_test.gd; README.md/AGENTS.md controls/presentation wording if needed.

- [ ] Add named dismiss_tutorial action (Tab). Handle on the overlay in _input before focus navigation; gate on current visible prompt, reject modifier/echo, mark handled before calling shared click dismissal. No raw KEY_TAB check in production.
- [ ] Add a small overlay suppression seam. Reuse existing _render_tutorial, _last_snapshot, _dismissed; do not let render, settings or close re-show a suppressed or dismissed card. Consolidate GameHud._open_modal and _reconcile_modal_presentation policy: ordinary phone menus allow a tip, protected/transactional screens mask it. Keep has_blocking_modal, HUD chrome and session gate unchanged. Ensure no transient input gap during open/close.
- [ ] Fix draw/hit ordering only as required for the visible tip above ordinary menus; a click on the real Dismiss button must reach it while panel controls still work. Keep toast on top and avoid any hidden overlay intercepting input.
- [ ] Extend test_start_releases_gate_and_tutorial_card_guides_first_actions for real key press/release, same _dismissed result as click, no session tutorial-completion change, subsequent eligible prompt still appears. Replace test_settings_change_keeps_tutorial_card_hidden_under_open_modal with explicit updated policy test: visible across allowed menus and settings refresh, Tab while menu open stays open and dismisses, no resurrection after close. Preserve existing test_primary_shop_modal_covers_tutorial_card_and_restores_it and test_successful_shop_refresh_preserves_modal_mask_until_close for masked panels.
- [ ] Test tips disabled, intro, protected/hidden panels, no prompt, echo and Shift+Tab (no accidental dismissal), and no change to dialogue Tab focus tests. Verify opening Settings/Bag/etc. still blocks movement and passive clock. Use actual InputEventKey with KEY_TAB press/release in tests, not direct _on_dismiss_pressed or synthetic completion. Include a mouse dismissal regression while allowed menu open.

**Checkpoint:** focused GUT/UI navigation tests green; no changes to prologue or gameplay/session code.

## 2. Correct shared phone headers and Settings segments

**Files:** scripts/ui/phone_frame.gd, scripts/ui/settings_panel.gd, scripts/ui/calendar_panel.gd (header only here), tests/integration/test_phone_panels.gd, tests/integration/test_phone_surfaces.gd; assets/i18n/strings.csv if changed.

- [ ] PhoneFrame refreshes JpSubtitle visibility when setting header and on NOTIFICATION_TRANSLATION_CHANGED, with no blank space when hidden. English retains the fixed decorative Japanese string; zh_TW/ja hide it even after live locale switch; do not affect unheaded morning summary or status bar.
- [ ] Use Calendar key for the app header. Update existing test_phone_apps_keep_localized_titles_and_fixed_jp_subtitles to test correct locale visibility, including English → ja → zh_TW → English on existing frames, not only re-instantiation; update test_calendar_integrated_header_and_market_tag and affected title checks.
- [ ] In SettingsPanel._seg, give OptionHit controls equal expand/fill allocation (container sizes based on largest intrinsic option), align chip content and gradient to full hit rect. Keep the UiStyle.hit_button anchored child/full pointer target and release-outside semantics; inspect after a layout frame. No new shared helper unless another actual consumer requires it.
- [ ] Remove _save_path, save_path_text, SavePath node and _refresh formatting; retain error _status and its row. Verify settings write failures are still visible; do not remove preference persistence or save transport. Remove unused CSV key only after reference audit.
- [ ] Update test_settings_window_tips_language_controls, test_settings_stays_inside_the_screen_in_all_locales, existing pointer geometry/locale tests. Assert selected background spans the hit cell, centers label, inactive option has no gradient, no clipped text/hit overlap at 1080p and 960×540. Verify clicking edges and canceled release, keyboard adjusts same value, status errors still show.

**Checkpoint:** existing header/chrome, settings pointer/keyboard, locale and min-window tests pass.

## 3. Calendar chips and centered markers; empty Bag shelf

**Files:** scripts/ui/calendar_panel.gd, scripts/ui/bag_panel.gd, assets/i18n/strings.csv, tests/integration/test_phone_panels.gd, tests/integration/test_gameplay_shell.gd.

- [ ] Replace _legend Label with four independently translated chip labels plus color/icon markers in HFlowContainer; move readiness watering note to separate conditional wrapping Label. Keep weather caption and _coming_signature refresh behavior; recalculate Coming Up scroll using available height after chips wrap. Ensure translated text never overruns PhoneFrame, including Day 14/mixed readiness.
- [ ] Refactor _day_cell top HBox to centered day row and icons beneath; preserve keys and node-based day_state() read seam. Keep distinct known weather, market, last-night, readiness markers (single/multi). Preserve factual weather/rendered flags, coming-up rows and market tag. No new readiness logic. Adjust vertical rows and padding so all 14 cells fit; no shrink to illegible glyphs.
- [ ] Add explicit Bag bin-empty Label under the shelf header and hide grid when no pending crop; use total pending count from _update_view, existing slot/payout paths when >0. Empty → loaded → empty must update from snapshots without closing; no selection or command changes.
- [ ] Update test_calendar_legend_is_localized_and_legible_in_all_locales (chips, labels, flow rows, conditional note), test_calendar_grid_cells_match_reference_with_legible_markers and marker nonoverlap tests to assert vertical layout and containment, not old HBox topology. Preserve test_calendar_day_state_tracks_only_rendered_controls, known history, mixed crop, Day 14/current+market+readiness, Coming Up scroll/multiple-row tests. Add at least one forced wrap geometry test or narrow flow fixture and actual in-frame checks at both supported sizes.
- [ ] Add Bag tests for exact localized empty label visibility, no empty grid strip, populated payout and positive slots, empty again after overnight. Preserve existing bag bin payout and selection tests.

**Checkpoint:** phone/calendar/bag integration tests green across en, zh_TW, ja.

## 4. Morning card and sentence-case copy

**Files:** scripts/ui/morning_summary_panel.gd, scripts/ui/title_screen.gd, scripts/ui/result_screen.gd, scripts/ui/dialogue_panel.gd, scripts/ui/shop_panel.gd, scripts/ui/shipping_panel.gd, assets/i18n/strings.csv, tests/integration/test_phone_surfaces.gd, tests/integration/test_vn_surfaces.gd, tests/integration/test_commerce_panels.gd, tests/integration/test_gameplay_shell.gd, tests/integration/test_persistence_flow.gd.

- [ ] Mount existing diary label in a rounded backed card, styled like C1; use existing icon or simple small text heading, localize Diary · Day %d if used; bind next_day to heading and ContentRules.diary_line(next_day) to body. Do not change story/diary text. Check layout under max shipments/longest translated diary and max error.
- [ ] Render saved state as one icon + Progress saved line, centered on backed card. Hide/reset body scroll/hint in success; keep error badge, full message and bounded scroll/hint intact; idle hides card. Reconcile _sync_save_status_height and _input so only visible overflowing error consumes W/S. Keep save_status_text truthful and summary_state test seams (update old expectations for success).
- [ ] Set Start day %d caption; change only user-facing titles/actions covered by #9: title New game/Continue; result New game/Title; dialogue Continue/Give %s/Close (preserve selected crop and button signal; remove .to_upper() on crop); shop Seed shop; shipping Shipping bin. Keep small uppercase labels and existing action hints, selected/default state, result tiers, and all commerce amounts. Audit whether old keys still serve other surfaces before removal. No blanket UiStyle case conversion.
- [ ] Localize all new/changed English keys in the same change; reuse existing Calendar, Continue, Close and any other exact existing key. Keep distinct Save error semantics; add any missing keys for legend/diary/bin. Check Japanese title Continue remains understandable with shared neutral translation. Validate placeholders/duplicate keys with test_localisation.gd; explicitly test UI keys and translations because current validator does not scan arbitrary UI code.
- [ ] Update test_morning_save_chip_and_error_stay_inside_the_phone and test_morning_summary_save_status_shows_saved_error_and_clears: exact visible success text once, no visible duplicate, idle/saved/error transitions including error → saved, longest error scroll still reachable. Preserve test_morning_long_save_error_wraps_bounded_inside_the_phone, test_morning_long_error_scrolls_with_move_keys_and_shows_hint, day14 summary and persistence failure. Verify diary card and action remain inside screen. Update title/result/commerce/dialogue caption assertions rather than removing behavioral checks; maintain gift focus/Enter agreement, title Continue default and disabled logic, pointer release cancel, and final return to title.

**Checkpoint:** focused tests and localization pass. Run full lanes after final integration.

## 5. End-to-end verification and acceptance (same PR)

- [ ] Run `./tools/verify-clean.sh` against committed implementation HEAD, then bootstrap GdUnit with `./tools/bootstrap-gdunit.sh` as documented and run `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` and `GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c`. Use isolated HOME/storage and xvfb-run on Linux when needed; check GitHub unit-tests/e2e-tests/verify including existing macOS export gate. Preserve Promising/Heart routes, save-failure handling, world contracts and prologue.
- [ ] Add/extend real-input e2e UI navigation test through app launch (Esc skips prologue), visible tip dismissal in world and menu (fresh run/relevant prompt), panel close and reopen, locale switch, day advance. Never satisfy key acceptance solely with direct signal or function call.
- [ ] **MCP acceptance:** run the actual app/native Godot desktop via the Godot MCP bridge. Use existing tests/native_tour/mcp_acceptance_driver.tscn and mcp_acceptance_driver.gd if the bridge cannot inject native keys; add narrowly scoped real InputEventKey press/release drivers for Tab (and needed existing navigation keys) via viewport input, not direct dismiss/simulation of state. Current DismissTutorial driver emits button.pressed, which cannot prove Tab. Preserve existing harness path, isolated save/settings paths, real movement/interact route, and use ToggleUI for clean captures. Add small driver regression test in test_mcp_acceptance_driver.gd if edited. Prefer direct MCP native key input where supported. Verify fixture-only controls cannot enter production scenes/export. For populated bin/Day 14/result/error captures use real play or existing isolated valid save fixtures loaded through Continue; document fixtures and don't claim seeded states were earned by play. Do not write direct production session state in the MCP driver.
- [ ] Perform the following agent-operated acceptance scenarios on one supported desktop (1920×1080 plus 960×540 layout spot checks); no separate native platform acceptance is necessary. Capture before/after relevant controls and record the tested SHA, platform, locale, viewport and actual interaction outcome.

| Scenario | Required observation/evidence |
| --- | --- |
| New Game, prologue Esc, first world tip | Tab consumes exactly one visible tip, no Pause/world action, same gameplay/tutorial progress; mouse path equivalent; another eligible prompt may appear only when relevant. |
| Fresh eligible tip → Pause → Settings/Bag/Calendar | Visible tip on allowed menu, Tab dismisses without changing settings or closing it; no reappearance on render, close/reopen or live locale change. Hidden tip on shop/dialogue/summary/transition cannot be dismissed; Tab in dialogue retains normal focus cycling. Menu still blocks passive time/movement. |
| Settings in all three locales | Kicker only en; both segments fill and center, no SavePath, click and keyboard adjustment agree; Tips toggles and preferences persist. Compare C1 Settings and Japanese Sleep/header references. |
| Calendar with known history and a ready crop, then busy Day 14 | Header Calendar, four distinct wrapping chips, note conditional, day above icons, all known weather/event/readiness retained; no overlaps/truncation or coming-up scroll regression. Compare C1 chips and original left-side day grid. |
| Bag empty, loaded, empty after sleep | One localized empty message, loaded shelf/payout unchanged; compare original Bag shelf composition, no blank strip. |
| Sleep → Day 2 morning → Start day 2 | Diary has its own card, correct diary day, success appears once as Progress saved, action caption sentence case. Actual day/clock advances and Continue restores expected state; C1 comparison. Long error fixture remains fully legible/scrollable. |
| Title, commerce, dialogue, result | New game/Continue, Seed shop, Shipping bin, Continue/Give crop/Close, New game/Title are sentence case with unchanged button/key behavior. Compare left reference; retain uppercase micro-labels. |
| Locale matrix | Repeat relevant surfaces with en, zh_TW, ja (including live transition); no duplicated Japanese kicker, missing translations, overflow, or regressions at 960×540. |

- [ ] **Visual parity check by MCP agent:** compare actual screenshot crops against the two Linear mockup images, not merely node dimensions; record for each changed surface what matches and any intentional variance (current map, data, Calendar/Start day precedence). Capture Settings, Calendar (all locales), Japanese Sleep, morning success, empty and loaded Bag, title/shop/shipping/dialogue/result, and world/menu tip before/after. Capture busy Day 14 and long-error layouts as needed. No screenshot golden pipeline or human signoff. If MCP cannot run or capture, explicitly mark that acceptance unverified rather than substituting unit tests as evidence.
- [ ] Keep generated screenshots/logs in ignored test_output or CI artifacts; link artifacts and record concise validation evidence in PR body/validation markdown per repo conventions, not committed generated screenshots. Verify git diff stays scoped to HPA-844; update README/AGENTS only for changed input/presentation contract; no gameplay rules, save/schema, art/SFX, build-stack or HPA-1250 change.
- [ ] All checks and MCP/visual acceptance complete before marking this **same** PR ready. Keep draft while verification is incomplete.

## Proposed scope decisions

The older modal-mask tests conflict with the explicit menu Tab requirement. This plan enables tips only over ordinary phone menus and preserves masking for protected flows (including dialogue's existing Tab behavior), not a hidden-tip dismissal or universal overlay. The C1 board still shows uppercase Start Day and inline weather; the written ticket and original comparison determine the corrected behavior. One shared neutral Continue key is preferred over a locale-specific branching system. No asset generation or additional PRs.
