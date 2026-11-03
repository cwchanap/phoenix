# HPA-682 — Native 1080p menus and panels: single-PR implementation plan

**Status:** Planning-only draft, 2026-11-02  
**Design:** [Native 1080p menus design](../specs/2026-11-02-phoenix-native-1080p-menus-design.md)  
**Linear:** https://linear.app/cwchanap/issue/HPA-682/restyle-phoenix-menus-and-panels-for-1080p  
**Base:** current `main`, after HPA-680, HPA-681, HPA-713 and the new village cast work.  
**Delivery:** Continue implementation in **this same HPA-682 draft PR** after reviewing this plan; do not create an implementation follow-up PR for this issue.

## Scope and guardrails

This is a native Godot Control and presentation refactor. Keep the current scene hierarchy roots as far as useful, panel public APIs and signal payloads, `GameHud` single-modal gating, `WorldShell` authority, keyboard commands, preferences, saved-state schema, translation format, and gameplay values. No art generation, SFX, story rewrite, backend, or new UI framework.

The older ticket's instruction to re-bless screenshots is obsolete. PR #29 removed the screenshot-golden gate; use the existing automated lanes and manual visual review, never recreate the golden system.

## Implementation sequence (all changes on one branch/one PR)

### Task 1 — Establish a stable UI baseline and shared frame

**Primary files**
- `scripts/ui/ui_style.gd`, `scripts/ui/slant_tag.gd` (reuse, only minimal shared helpers)
- New `scenes/ui/phone_frame.tscn`; small `scripts/ui/phone_frame.gd` if header, footer and body mounting need a shared API
- `scripts/ui/game_hud.gd` for the narrow, existing modal instantiation/wiring points

**Steps**
1. Record the current UI controls and callback contracts before changing node trees: `GameHud.open_*` / `close_*`, `_open_modal`, `_esc_close_order`, `modal_state_changed`; title/result buttons; `PausePanel.settings_requested`; `SettingsPanel.settings_changed`; acknowledgements, purchases, deposits and gifts.
2. Implement the centered native-size phone shell: dim, rounded surface, gradient header/title/subtitle, content slot and one footer hint row. Make it a purely visual child owned by each existing panel; it must not handle game input or own another controller.
3. Reuse `UiStyle.card`, `gradient_surface`, `keycap`, font fallbacks and `SlantTag`. Add a helper only for visual patterns repeated by multiple panels; avoid copying large style-tree traversals into a new common superclass.
4. Use anchors/containers at the 1920×1080 base size; leave `project.godot` resolution, `WorldContract.CAMERA_ZOOM` and `UiSettings.apply_window` intact.

**Check:** Instantiate each candidate phone shell at native size without node-path warnings, clipping or double-scaling. Confirm `HudRoot` remains full-screen and under existing `GameHud` control.

### Task 2 — Migrate the seven phone surfaces

**Files**
- `scenes/ui/{pause,bag,almanac,calendar,settings,morning_summary,sleep}_panel.tscn`
- Matching `scripts/ui/*_panel.gd` files; `scripts/ui/game_hud.gd` for signal wiring only

**Steps**
1. **Pause:** build home icons (Bag/Almanac/Calendar/Settings), Controls widget, footer; retain Esc/O. Tile clicks may emit narrow open requests to `GameHud`, which routes through existing `open_*`. Do not relax current world-only I/B/C shortcut checks or allow two modals.
2. **Bag:** show seed/harvest grids, carried quantities, shipping payout and selected item details from the existing snapshot. Preserve selection and close behavior.
3. **Almanac:** change presentation from three simultaneously visible cards to one selected crop page. Reuse the existing `_selected_kind`, A/D handling, crop art and pure `GameRules` facts; do not add crop state.
4. **Calendar:** keep its current day/weather/harvest computations and put them into a 7-column, 14-day grid with Coming Up; never fabricate future weather.
5. **Settings:** display Music/Sound (0–10), Window (1080p/Full), Tips, **and existing Language**. Keep row selection, A/D updates, save-error display, existing separate settings file, and per-locale rendering. The slider appearance does not require a second pointer-driven settings model.
6. **Morning Summary:** use a 06:00 lock-screen shell; present weather, farming, shipments, bank total, withering notice, Saved/save-error status and Enter to start the next day. Leave diary authoring and any new diary snapshot data to HPA-684; do not fake a diary line.
7. **Sleep:** show 06:00 alarm and current Day 14 ending warning; preserve Enter confirm, Esc cancel and current summary transition.

**Check:** The panels still expose the same `open_panel`/`present`/`selected_*`/`set_save_status` methods where they exist. The initial opening/closing transitions, focus, modal visibility and downstream signal payloads remain unchanged.

### Task 3 — Migrate interaction cards and dialogue

**Files**
- `scenes/ui/shop_panel.tscn`, `scripts/ui/shop_panel.gd`
- `scenes/ui/shipping_panel.tscn`, `scripts/ui/shipping_panel.gd`
- `scenes/ui/dialogue_panel.tscn`, `scripts/ui/dialogue_panel.gd`

**Steps**
1. Give Shop and Shipping a consistent rounded card, gradient header, selected pink row, quantity controls and one prominent action pill. Compute its displayed exact action and amount from the panel's existing selected quantity/snapshot state; never execute a purchase or deposit while merely rendering.
2. Keep the current M maximum shortcut, quantity bounds, disabled/upgraded states, and `buy_requested` / `upgrade_requested` / `deposit_requested` payloads. A pointer click and Enter must request the same action.
3. Restyle Dialogue as a visual-novel box with left portrait, slanted name tag, role, friendship hearts/value, dialogue text and gift chips. Preserve close-friend line handling, relationship rendering, gift availability, selected-gift focus and `gift_requested`.
4. Reuse existing icons and portraits; remove old 640x360 offsets rather than scaling old scene roots.

**Check:** Same session outcomes for buy/upgrade/deposit/gift with normal, insufficient-resource and unavailable-action states. Dialogue line progression and Esc behavior unaffected.

### Task 4 — Native standalone screens and onboarding

**Files**
- `scenes/ui/{title_screen,result_screen,onboarding_overlay}.tscn`
- `scripts/ui/{title_screen,result_screen,onboarding_overlay}.gd`

**Steps**
1. Title: native 1920×1080, existing hero art with a left fade, New Game/Continue gradient selection, unchanged disabled Continue and save-error status.
2. Opening: native letterbox, Day 1 `SlantTag`, existing introduction dialogue styling; preserve the blocking acknowledgement, tutorial-card logic and `blocking_state_changed` callback.
3. Result: native SEASON COMPLETE treatment, current scoreboard values, three existing residents/portraits, dynamic finale text, and existing new-game/return actions.
4. Do not land HPA-684 diary/story copy, change cast names, or add artwork to satisfy the design reference.

**Check:** A first-run intro remains blocking; continue for valid/completed saves follows the existing path; final result works from market or Day 14 sleep.

### Task 5 — Remove stopgap and reconcile tests

**Files**
- `scripts/ui/game_hud.gd` (remove ten-panel legacy scaling loop)
- `scripts/ui/ui_style.gd` (remove unused `LEGACY_LAYOUT_SIZE` / `fit_legacy_layout` / `fit_legacy_control` and legacy dark-only palette/style helpers after migrating all call sites)
- `scripts/ui/title_screen.gd`, `scripts/ui/result_screen.gd`, `scripts/ui/onboarding_overlay.gd` (remove standalone scaling)
- `assets/i18n/strings.csv`, `tests/unit/test_localisation.gd`
- Affected `tests/integration/test_gameplay_shell.gd`, `tests/integration/test_app_launch.gd`, `tests/headless/world_shell_smoke.gd`, `tests/e2e/ui_navigation_test.gd`, `tests/e2e/gameplay_day_one_test.gd`, and `tests/gdunit/*` as required
- `README.md` and `CLAUDE.md` for the updated UI contract

**Steps**
1. Search every runtime use of `fit_legacy_*`, old palette/style constants, 640×360 UI offsets, and stale panel node paths. Remove the stopgap only after all migrated screens load. Keep shared `UiStyle` functions still used by HUD or unaffected controls.
2. Rewire tests to native scene paths only where intentionally changed; preserve behavior assertions rather than weakening or deleting them. Keep the existing `HudRoot/BagPanel` etc. modal root names where feasible.
3. Add every new English UI string to the existing translation CSV with `zh_TW` and `ja` columns; use `tr(...)` for formatted dynamic strings and verify fallback-font fit. The existing localization unit suite does not enumerate UI literals, so explicitly cover the new labels (or document and review an exhaustive source-string inventory) instead of assuming the existing rules-string test catches them.
4. Update README/CLAUDE to state that title, result, intro and all modals are authored natively at 1080p and that the golden gate remains removed.

**Check:** The repository no longer uses the temporary UI scaling helpers, and translations do not introduce missing keys or placeholder mismatches.

## Validation plan

### Automated

Run the existing supported lanes (not new infrastructure):

1. `./tools/verify-clean.sh` — clean archived HEAD, Godot import, GUT rules/integration, project/world smoke and audio source sanity.
2. After `./tools/bootstrap-gdunit.sh`, run `./addons/gdUnit4/runtest.sh -a tests/gdunit -c` — existing GdUnit4 behavior tests.
3. In the configured godot-e2e environment, run `./addons/gdUnit4/runtest.sh -a tests/e2e -c` — real-key UI navigation and Day 1 gameplay. CI definitions: `.github/workflows/unit-tests.yml` and `.github/workflows/e2e-tests.yml`.

Minimum changed assertions:
- Opening/closing Pause→Settings→Pause→World with Esc/O; modal signals and movement gate.
- Bag/Almanac/Calendar access from world, A/D crop navigation and Esc closure.
- Shop/Shipping steppers, M max, accurate request arguments and available/disabled action visuals.
- Settings five rows, persistent Music/Sound/Window/Tips/Language; switch locale and keep text legible.
- Morning summary saved/error state and Day 14 sleep/finale; Dialogue gift selection and result screen actions.
- Native-size roots and absence of 3× UI scale on every screen family.

Keep the existing integration tests' business-state assertions intact. If a test asserts an old scene-internal `Frame/...` path, update that selector rather than weakening the observed behavior.

### Manual visual acceptance (human review required)

Check the 14 source mockup states in the actual Godot game at **1920×1080** and representative **960×540** window scaling. Exercise English, Traditional Chinese and Japanese; dense Calendar/Settings/Dialogue text; short and long crop names; selected/unselected/disabled states; shop insufficient funds; empty inventory; shipment warnings; save failure and Day 14 boundary. Check font fallback, focus highlight, clipping, dim layer, footer/hotkey accuracy and exact-action pill labels.

There is **no screenshot-golden re-bless or screenshot CI**. The PR should include a short manual review checklist and any non-blocking visual differences for human sign-off.

## Completion definition

- Native 1080p presentation on all targeted surfaces, with one reused phone frame and the approved City Pop style.
- No active `fit_legacy_*` call sites or remaining dependency on 640×360 panel coordinates.
- Existing gameplay/session and keyboard/modality behavior is preserved; no new persistent data, art or audio.
- Strings translated into zh_TW and ja, existing automated verification lanes passing, and 14 reference states visually reviewed.
- PR remains **one HPA-682 PR** from design through implementation. No split follow-up PRs; separate story/art issues remain independently owned.

## Out-of-scope follow-ups

HPA-684 supplies the 14 diary lines and story-specific intro/result copy. HPA-683/685/686 move farm/town responsibilities. HPA-687 owns town/kei-truck art. Any new icons/portraits/SFX should be ticketed separately rather than bundled with this UI code change.

## Implementation notes / risk register

- **Risk: scene path churn breaks tests.** Keep each existing panel root stable and refactor one UI family at a time; update selectors with the panel's actual behavior test.
- **Risk: phone frame clipping hides text.** Keep gradient layers behind text, don't nest clips, and test zh_TW/ja labels at minimum viewport.
- **Risk: Pause app icon behavior differs from reference.** Keep current shortcut gating; navigate tiles by narrow signals and request UX review before broadening keyboard semantics.
- **Risk: diary depends on HPA-684.** Leave content blank/omit until its data exists; do not create premature model fields.
- **Risk: presentation PR changes state handling.** Treat all `GameSession`, `WorldShell`, `UiSettings` persistence and `GameHud` modal gating as fixed contracts; review any incidental changes as a red flag.
