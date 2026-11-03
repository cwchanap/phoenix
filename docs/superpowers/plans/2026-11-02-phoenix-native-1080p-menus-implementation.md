# HPA-682 — Native 1080p menus and panels: single-PR implementation plan

**Status:** Revised after PR #35 design review, 2026-11-02. Planning-only; no implementation or test execution claimed.  
**Design:** [Native 1080p menus specification](../specs/2026-11-02-phoenix-native-1080p-menus-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-682/restyle-phoenix-menus-and-panels-for-1080p  
**Delivery:** Implement **on this same draft PR**, one cohesive issue → one PR. Do not create a separate implementation PR.

## Non-negotiable contracts

- Godot 4.7.1 and native 1920×1080 `Control` rendering. No canvas-size, camera zoom, gameplay, save, balance or rule changes.
- Every non-HUD surface uses a **code-built control tree**, following `HudChrome`, not a new mix of authored scene contents with runtime stylers. Keep each `.tscn` file as a root plus attached existing script. Keep each root name, public panel method and signal shape.
- One lean code-built `PhoneFrame` class: bezel, status-bar time, home indicator and content mount **only**. Each panel builds its own app-header/footer if applicable. `GameHud` remains the modal owner; no navigation framework, app mode registry or new session owner.
- Reuse `UiStyle` and existing images. All added player-facing English strings receive zh_TW/ja values in the existing CSV, including Settings' **Language** control.
- HPA-684 owns actual diary lines and opening/result story rewrite; HPA-687 owns new art; town changes remain HPA-683/685/686.
- PR #29 removed screenshot goldens. Do not reintroduce them.

## Commit rule: each migrated surface family is green

Keep this one PR, but group commits into coherent screen families. **For each family in the sequence below:**

1. Code-build its screen roots and delete the old `_style_tree` / node-path styling code.
2. In the **same commit**, remove those screen roots from `GameHud._build_modals()`'s legacy scale loop (or their standalone `fit_legacy_*` calls); don't scale a rebuilt panel.
3. Migrate affected GUT/GdUnit4/e2e assertions in that commit. Prefer existing `selected_*` accessors or a narrow read-only value seam (current line, selected price/action, known calendar day, sleep boundary), **not** hundreds of new internal node paths. Keep current behavioral assertions.
4. Extend the **existing** `tests/integration/test_app_launch.gd::test_legacy_640x360_ui_roots_fill_the_1080p_canvas` progressively: migrated surfaces have `scale == Vector2.ONE` and a full native `Rect2(0,0,1920,1080)`. Unmigrated surfaces retain their valid legacy assertions. Rename it to the native-root test when none remain.
5. Update the translation CSV for every new label from this family.
6. **Commit first**, then run `./tools/verify-clean.sh`, which archives committed `HEAD`. Fix failures, commit, rerun. Also run the relevant GdUnit4/e2e suites for affected input and navigation paths. Do not leave a long-lived red intermediate migration state.

This order supersedes the old "migrate UI, then update tests and stopgap in Task 5" plan.

## Phase 1 — PhoneFrame and Pause home

**Files:** `scripts/ui/phone_frame.gd` (new), `scripts/ui/pause_panel.gd`, `scenes/ui/pause_panel.tscn`, `scripts/ui/game_hud.gd`, `scripts/ui/ui_style.gd` (small shared builders only), matching tests, CSV.

- Implement the `PhoneFrame` node as a code class with status-bar `Label` and content mount. No `phone_frame.tscn` or editable-children scene inheritance.
- Build Pause wallpaper, four app tiles and Controls widget via `UiStyle`. No app-header variant flag. Give tiles truthful I/B/C/O hints; connect the tile requests to **existing** `GameHud.open_bag`/`open_almanac`/`open_calendar`/`open_settings`.
- In `GameHud._unhandled_input`, allow I/B/C when no modal is open **or Pause is open**; keep blocks for every other primary modal. Closing Bag/Almanac/Calendar goes back to the world, not Pause. Settings continues to return to Pause.
- Have `GameHud.render(snapshot)` format `GameRules.format_time(int(snapshot["time_minutes"]))` once and supply it through a narrow phone-panel time setter. Supply Pause day/weather from the same render path; no snapshot parameter on `open_pause` or other `open_*`.
- Remove Pause from the legacy-scale loop in this commit. Do not affect non-Pause panels.

**Tests:** Reuse existing Pause→Settings→Pause→World navigation; add one GUT interaction test for Pause→I→Bag, Pause hidden and world gated, plus B/C equivalent smoke if low cost. Assert new native root rect/scale and truthful status-time source. Run `./tools/verify-clean.sh` on committed HEAD; relevant e2e navigation lane.

## Phase 2 — Phone apps: Bag, Almanac, Calendar

**Files:** each existing `scenes/ui/{bag,almanac,calendar}_panel.tscn` and corresponding `scripts/ui/*_panel.gd`, `scripts/ui/game_hud.gd` scaling entries/status-time setter wiring, integration tests, CSV.

- Bag: seeds/harvest grid, currently selected item detail, bin payout; preserve current `open_panel`/`present` selection and snapshot semantics.
- Almanac: one selected crop at a time, A/D navigation, crop art and real game rules; preserve `selected_kind()`.
- Calendar: fixed 7×2 day grid and Coming Up; use existing `weather_history`/day-known flags, never a future forecast.
- Each panel instantiates its own `PhoneFrame` and app header/footer with shared builders; it does not hand input control to the frame.
- Stopgap/test/translation updates land with each migrated surface or this tightly grouped family, not after all screens.

**Tests:** Keep value assertions (quantity, growth, known days, selection/close) via existing selectors or minimum read seams. Extend the native-root test per surface. Verify clean + targeted navigation.

## Phase 3 — Phone Settings, Sleep and Morning Summary

**Files:** `scenes/ui/{settings,sleep,morning_summary}_panel.tscn`, matching `scripts/ui` files, `scripts/ui/game_hud.gd`, tests, CSV.

- Settings: retain all five rows Music/Sound/Window/Tips/**Language**, persistence and A/D controls. The current on-screen values must always match `UiSettings`. Only the presentation changes.
- Sleep: 06:00 alarm app and Day 14 warning; keep `sleep_requested` and Enter/Esc flow. The status bar shows current session time fed by `GameHud.render()`, while the **alarm target** is fixed at 06:00.
- Morning Summary: lock-screen view of current summary facts, shipments, withering, bank and saved/error status. No diary content, no added snapshot field.
- Remove the duplicated sleep boundary handling from `GameHud`: delete `_day14_sleep_boundary`, `get_node("Boundary")` and redundant `render()` text assignment. `SleepPanel.present(snapshot)` alone computes/updates this notice. Provide a narrow `day14_warning_visible()` or equivalent observable if existing tests used the node directly.
- Preserve Settings→Pause and morning-summary blocking behavior.

**Tests:** Existing preference persistence and language tests, save error/saved notice, sleep Day 14 boundary and summary acknowledgement. Add status-time and native-root assertions; run the per-commit verifier.

## Phase 4 — World cards: Shop, Shipping, Dialogue

**Files:** `scenes/ui/{shop,shipping,dialogue}_panel.tscn`, matching `scripts/ui`, `scripts/ui/game_hud.gd` legacy entries, `tests/integration/test_gameplay_shell.gd` and other relevant GUT/e2e tests, CSV.

- Shop and Shipping: use one simple repeated **visual** card style, selected-row tint, native stepper controls and dynamic exact-action pill. Keep M=max, quantity bounds, disabled actions, upgrade availability, signals and money/inventory math unchanged.
- Avoid rewriting tests to target new `Frame/Body/Row_0/Price` paths. Expose read-only **display** seams where real user feedback is asserted: e.g. `selected_action_text()`, `display_price_for_row(index)`. Prefer current state/snapshot methods for pure numerical facts.
- Dialogue: current portraits, slanted name tag, relationship and gifts, with no input/line behavior changes. Expose a narrow `current_line_text()` for tests that read `Panel/Line`. Preserve the close-friend flow, gift focus and signal payload.
- Remove these three roots from the legacy loop and update native-root assertions **with** their code migration.

**Tests:** Purchase, upgrade, deposit and gifting request arguments; insufficient money/stock and disabled-action states; Day 14 shipping/market warning; selected action text; dialogue line progression. Verify clean per family/commit.

## Phase 5 — Title, Result, Opening

**Files:** `scenes/ui/{title_screen,result_screen,onboarding_overlay}.tscn`, matching `scripts/ui/*`, `scripts/app/app_root.gd` only if unavoidable, tests, CSV.

- Title: reuse existing key art and Continue/new-game behavior; native left fade and gradient selected action. Keep save-error and unavailable-Continue behavior. Add a narrow `status_text()` only if needed to replace old `Panel/Status/Label` test lookups.
- Result: render current season totals, three villager cards, finale tier and existing new game/title controls with no content changes.
- Opening: replace 640×360-scaled opening card with native code-built Day 1 letterbox and visual-novel introduction; leave the already-native tutorial card intact. Preserve `OnboardingOverlay` signals and gating.
- Remove `fit_legacy_layout(self)` from Title/Result and `fit_legacy_control(_opening_panel)` from onboarding **as each is migrated**. The scene/resource root names and app launch routes remain unchanged.

**Tests:** New Game, invalid-save Continue disabled, completed-run Continue→Result, result buttons, intro acknowledgement and tutorial behavior, native root scale/rect; verify clean.

## Phase 6 — Final cleanup and full validation

**Files:** `scripts/ui/ui_style.gd`, `scripts/ui/game_hud.gd`, `scripts/world/farm_action_effects.gd`, docs, and any remaining references found by search.

1. Search whole repository (production and tests) for `fit_legacy_layout`, `fit_legacy_control`, `LEGACY_LAYOUT_SIZE`, `UiStyle.GOLD`, other legacy colors, `UiStyle.panel`/`UiStyle.button`, `font(..., _mono)`, old direct `Frame/...` lookups and remaining assumed 640×360 panel geometry.
2. Delete the now-empty ten-modal legacy loop and the obsolete layout helpers. Prune legacy `UiStyle` theme palette and styling methods **only when all callers have been converted**. Retarget `UiStyle.text()`'s default from legacy `TEXT` to `INK`, and migrate `scripts/world/farm_action_effects.gd`'s harvest `+1` color from `UiStyle.GOLD` to a retained City Pop hue.
3. Keep `UiStyle` primitives used by existing `HudChrome`/`OnboardingOverlay` untouched; avoid broad styling refactors.
4. Rename the existing native-root integration test and verify native `scale == Vector2.ONE` + full-screen rect for all 13 surfaces.
5. Update `README.md`/`CLAUDE.md` to document no legacy 3× UI scale, phone-frame ownership, Pause I/B/C behavior and the lack of screenshot-golden CI.

Commit and run the full existing verification lanes:

`./tools/verify-clean.sh`

`./tools/bootstrap-gdunit.sh`, then `./addons/gdUnit4/runtest.sh -a tests/gdunit -c`

In the configured godot-e2e environment, `./addons/gdUnit4/runtest.sh -a tests/e2e -c`

Review CI from `.github/workflows/unit-tests.yml` and `.github/workflows/e2e-tests.yml`. Update assertions, not coverage policy. The clean script archives `HEAD`: uncommitted changes are not validated.

## Visual verification / completion

Check the fixed **13 HPA-682 reference states** in the design spec:

`02-seed-shop`, `03-shipping-day14`, `04-bag`, `05-almanac`, `06-calendar`, `07-dialogue`, `08-morning-summary`, `09-sleep`, `10-pause`, `11-settings`, `12-intro`, `13-title`, `14-result-heart-of-harvest`.

HPA-681 owns `01-hud` and the native tutorial-card tab. Compare HPA-682 views to the mockup at **1920×1080 and 960×540**, including **English, zh_TW and ja**; check accurate buttons/hotkeys, dense localized text, clipping, font fallback, selected/disabled action states, Day 14 warnings, save failure, and end-tier stats. Manually review visuals; no new golden tests or art-generation task.

**Done when:** all targeted surfaces native, legacy scale/palette removed without orphaned callers, existing gameplay/input/save behavior preserved, the translation CSV complete, all existing automated lanes green, and visual review complete. Implementation remains on **PR #35**.
