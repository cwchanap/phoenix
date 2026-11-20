# HPA-1137 — Six-scene prologue: single-PR implementation plan

**Status:** Planned, not implemented. This draft PR contains design/plan documentation only; execution and evidence checkboxes are intentionally open.  
**Design:** [Skippable prologue design specification](../specs/2026-11-20-phoenix-skippable-prologue-design.md)  
**Issue:** https://linear.app/cwchanap/issue/HPA-1137/play-a-skippable-story-prologue-before-day-1  
**Branch:** `agent/hpa-1137-skippable-prologue-plan`; **implement in this same PR** and mark ready only after automated evidence. **One ticket = one PR.**  
**Inspected base:** `main` at `67894bd89a7a` (20 Nov 2026). Refresh before changing code.

## Preflight / actual repository findings

- The existing onboarding is code-built in `scripts/ui/onboarding_overlay.gd`. It currently renders `OPENING_INTRO`, `OPENING_GUIDE`, `OPENING_SPEAKER`, `OPENING_ROLE`, and the Day 1 diary in one `UiStyle.vn_dock(130.0)`. Its Enter handler immediately emits `intro_acknowledged`. It also owns the independent tutorial notification; **do not rewrite the tutorial card**.
- `scripts/game/content_rules.gd` is the stateless source for onboarding/tutorial/diary content. `scripts/ui/game_hud.gd` instantiates one `OnboardingOverlay`, relays `intro_acknowledged` and `blocking_state_changed`, and includes `is_opening_visible()` in `has_blocking_modal()`. `scripts/world/world_shell.gd:_on_intro_acknowledged()` runs the existing session command. No new session holder, save field, world input gate, or signal route.
- `assets/i18n/strings.csv` uses `keys,zh_TW,ja` with English source keys. `tests/unit/test_localisation.gd:_rules_strings()` currently enumerates the old intro constants; replace its coverage with iteration of all prologue scene metadata and lines. Keep ordinary tutorial and diary translation coverage.
- **Art ready:** HPA-1138 is Done and `assets/ui/backgrounds/prologue-platform.png`, `prologue-station.png`, and `prologue-road.png` **are on main**, with `prologue-art.md` provenance. Reuse the painted files; the original HPA-1137 placeholder instruction is obsolete. The approved `interior-night.png` is attached to HPA-1137 but is not in the backgrounds directory; copy that provided file there. The scene-3 existing `assets/sprites/kei-truck.png` is a two-frame 192×96 sheet; show only its first 96×96 frame. No new image or sound generation is scoped to this coding PR.
- HPA-1137 provides a 1920×1080 HTML mockup and six key-frame JPGs, plus the approved **58-line zh_TW script**. These are the visual/copy contracts; use the attachments from the Linear issue (refresh expiring upload URLs rather than copying signed URLs into committed docs).
- There are **no currently open Phoenix PRs** covering this ticket. Do not start a second implementation PR.

## Task 1 — Pin the approved content and localization (red → green)

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`.

1. Add a failing content-contract test asserting exactly six ordered scene records with line counts **[7, 10, 20, 12, 6, 3]** (58 total), nonempty translated tag/background/text, valid kind in `dialogue`/`inner_voice`/`narration`/`note`, and stable speaker identity for dialogue/note/inner voice. Pin critical rule-bearing copy: 30-minute drive, Day-14 market/13 days from Day 1, 22:00 cutoff, seed shop, overnight shipping income, three starter Turnip seeds.
2. Replace only the obsolete `ContentRules.OPENING_*` constants with one `PROLOGUE_SCENES: Array[Dictionary]`. Use `tag`, `background`, and `lines` dictionaries, and `speaker`/`kind`/`text` per line. Preserve all **58 numbered meanings in Linear** and their exact scene order. English is the source; the approved zh_TW is used verbatim where grammatically possible, with Japanese newly authored. Avoid new JSON files, serializable cutscene types, or translation indirection.
3. Add/adjust CSV rows for all 58 English keys, the six tags, note attribution, speaker/role names and UI hints. Reuse existing identical strings, e.g. the current `BEGIN DAY 1`, `Gen-san`, `Hana`, `KENJI`, and `Enter` where appropriate. Every new/edited key has both zh_TW and ja in the **same commit**. Repair `Sato-san` → `佐藤小姐` in its current zh_TW cell and references, preserving English and Japanese labels.
4. Replace old intro-specific localisation expectations with comprehensive traversal of `ContentRules.PROLOGUE_SCENES`, asserting `tr(source) != source` for zh_TW and ja (except deliberately language-identical proper names if explicitly justified by test), CSV key uniqueness, and matching placeholders. Test all 58 `text` keys—not merely sample scenes.
5. Keep `ContentRules.DIARY_LINES`, `TUTORIALS`, result tiers, `VillagerRules`, and `GameRules` untouched, apart from the explicitly requested text translation correction.

**Checkpoint:** Story table and localization tests pass without changing session state or UI structure.

## Task 2 — Render the six mockup page kinds in the existing overlay

**Files:** `scripts/ui/onboarding_overlay.gd`, `scenes/ui/onboarding_overlay.tscn` only if required by its existing root convention, `assets/ui/backgrounds/interior-night.png` (supplied file), `tests/integration/test_vn_surfaces.gd`.

1. Add only `_scene_index` and `_line_index` transient page state to `OnboardingOverlay`; use a simple `_show_page()` helper to pull one record from `ContentRules.PROLOGUE_SCENES`. Reuse its existing `IntroBackground`, `OpeningPanel`, VN dock, buttons and slant tags. Background switches at scene boundaries, with intro painting for scene 4 (night-tinted) and scene 6 (normal).
2. Build the common native controls at 1920×1080: 90 px black letterboxes, localized Prologue title + Esc/Skip intro, localized scene time/place slant tag and **six** progress dots, Enter/Continue cue, and a final real `Accept` / Begin Day 1 pill. Match the attached HTML mockup's positions, colors, fonts and contrast; no 640×360 stopgap scaling.
3. Render by `kind`: narration as centered white no-dock text; inner voice as violet Kenji text with night tag and no dialogue quotes; dialogue in `UiStyle.vn_dock()` with localized speaker + role; note in a central paper card. For line 55, keep line 54's paper note visible while showing Kenji's reply below it. Keep quoted dialogue separate from inner voice, and do not create a Mrs Moriyama villager.
4. Show `assets/ui/portraits/hana.png` and `gen.png` for the relevant speakers using existing portrait framing; Kenji gets no portrait. Dim Gen-san's portrait **while he listens** to Kenji in scene 3; restore normal opacity when Gen-san speaks. Scene 3 draws one `AtlasTexture(Rect2(0,0,96,96))` from the existing truck sheet on the painted road. Apply any dusk/night overlay **below** text/portraits to keep them readable.
5. Adjust `test_vn_surfaces.gd`'s currently obsolete tests: `test_intro_letterboxes_and_day_tag_frame_the_floating_vn_card` must expect place/time plus six dots rather than `DayTag`; `test_intro_vn_box_keeps_authored_name_role_and_copy` must check representative narration/dialogue/inner voice/note pages instead of removed `Intro`, `Guide`, `DiaryLine` nodes. Retain native bounds and initial background assertions.

**Checkpoint:** The six key-frame page types render in the same control tree; the supplied images, role pills and text placement agree with the Linear mockups.

## Task 3 — Advance, skip and acknowledge exactly once without reopening the world

**Files:** `scripts/ui/onboarding_overlay.gd`, existing `GameHud` only if a small input-consumption fix is required; `tests/integration/test_vn_surfaces.gd`, `tests/integration/test_app_launch.gd`, `tests/integration/test_gameplay_shell.gd` where appropriate.

1. Red-first: on New Game, initial page is (scene 0, line 0), `ui_accept` advances **one** line, scene boundary selects the next background/tag, and the final page's Enter or `Accept` click emits `intro_acknowledged` **once**. Repeated presses must not skip or double-acknowledge because of focused-button activation, key repeat, or simultaneous click handlers.
2. Add `_advance_page()` and `_complete_intro()` as the only two player-flow actions. The former advances one authored line; when already on the 58th page it invokes the latter. The latter marks transient playback completed and emits the **existing** signal once; actual session acknowledgement remains in `WorldShell`. Do not add a second session mutation path.
3. `ui_cancel` / Esc and the visible top Skip intro click target call **`_complete_intro()` directly from every page** (including the final page), and consume the input so `GameHud._unhandled_input()` cannot open Pause. A middle-page click/Enter only advances; the final-page Enter/Accept only acknowledges. Make hidden controls non-interactive to avoid click-through.
4. `OnboardingOverlay.render(snapshot)` must not reset indexes each render or locale update; a fresh, newly unacknowledged opening starts at first page. Existing `intro_acknowledged` snapshots hide it and cannot receive skip/advance input. `GameHud.has_blocking_modal()` remains true throughout playback, so `WorldShell` input and passive clock cannot tick until completion.
5. Update `test_vn_surfaces.gd:test_intro_keyboard_accept_still_acknowledges` (now expects **advance** on first key) and `test_intro_accept_is_a_primary_pill_that_acknowledges` (now expects ack on final page only). Update `test_app_launch.gd`'s **one Enter closes opening** assumption to walk the prologue or use Esc, then assert tutorial and session state unchanged. Add integration checks for Esc at first/middle/final, no duplicate ack, visibility across rerenders, and Continue with `intro_acknowledged = true`.
6. Assert equal new-game session snapshots after full finish vs skip: Day 1, 06:00, 150G, three Turnip seeds, intro acknowledged, and unchanged tutorial completion; world movement/clock resume only afterward. Don't change `GameSession.acknowledge_intro()` or saved schema.

**Checkpoint:** Normal finish and any-page skip converge on the same authoritative game state and do not leak input or pause.

## Task 4 — One-platform MCP e2e and screenshot comparisons

**Files:** `tests/e2e/app_launch_test.gd` (or one focused `prologue_test.gd`); `tests/native_tour/hpa_1137_tour.gd` using `tests/native_tour/rain_tour_base.gd` conventions; relevant integration tests.

1. **MCP-driven real Godot app e2e**, one supported desktop platform only: title → New Game → prologue with real Enter/click inputs → six scene changes → Begin Day 1 → playable farming. Add separate launch paths for Esc skip at a middle page, Continue from an acknowledged save, and explicit fresh New Game after Continue. Test that old saved Day-N flow is unaffected. Avoid `_show_page()`/session-method shortcuts in the true e2e assertions; those belong in unit/integration tests.
2. Using the existing native tour harness and isolated `PHOENIX_SAVE_PATH` and `PHOENIX_SETTINGS_PATH`, capture **1920×1080** images of the six mockup key frames to an output directory. An MCP-connected executing agent opens the captures and compares them to the **six Linear HPA-1137 JPG mockups** and the HTML reference (layout, day/time tag, dots, portrait/truck, dock, note and readability). A different painted background is expected because HPA-1138 has already supplied the final art.
3. In `en`, `zh_TW` and `ja`, iterate all 58 pages in an automated 1080p viewport layout test to assert visible line count equals wrapped line count, no clipped dock/note, and visible action hints. Capture the longest/most crowded case in each locale for extra visual review. Avoid screenshot-golden/pixel-diff gates; this repository deliberately removed that gate.
4. The **MCP executing agent**, not a human sign-off, runs the real e2e route and inspects the screenshot outputs. Record platform, run command, captured paths and discrepancies in this PR. Do not mark e2e/visual acceptance complete solely from a unit test or GitHub CI check, and do not require a second native-platform acceptance run for a platform-neutral UI change.

**Checkpoint:** Input-driven running-game evidence plus agent visual checks against the supplied key-frame mockups, in all three languages.

## Task 5 — Verify committed HEAD, attach evidence, finish the same PR

Use the existing repository tools and CI; do not add another test or deployment system. On the implementation branch, after import and focused GUT checks:

```sh
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
# After committing the implementation: verify-clean archives committed HEAD.
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

Run the **MCP-driven** Godot e2e/native capture route above, inspect the screenshots against Linear and check the GitHub CI lanes. Put command output, saved image locations, comparison notes and unresolved limitations into this same PR. Update these design/plan docs if actual implementation differs, then mark the existing draft ready for review. No follow-on implementation PR and no human acceptance gate.

## End-to-end acceptance checklist (all pending; plan-only PR)

- [ ] New Game → 58 ordered lines in six scenes → Begin Day 1 via real Enter/click; gameplay starts at 06:00, 150G, three Turnip seeds, with the unchanged tutorial.
- [ ] Esc/Skip from scene 1, mid-prologue and final page converges on the same session snapshot, without Pause/extra ticks/extra acknowledgement.
- [ ] Continue on acknowledged Day-N save bypasses prologue; a new run starts again at scene 1; persisted fields and terminal Day-14 route are unchanged.
- [ ] Every scene tag, speaker, role, note, hint and all 58 lines localize to **en/zh_TW/ja**; Sato-san is **佐藤小姐** in zh_TW; every wrapped line fits at native 1080p.
- [ ] MCP-run e2e on **one desktop platform** passes and an agent opens and compares six 1920×1080 scene captures against the Linear HTML/JPG mockups, plus crowded lines in all three languages; evidence recorded.
- [ ] Unit/integration, headless smoke, committed-head verifier, GdUnit4 and godot-e2e, plus GitHub CI, pass on the completed implementation commit. No claim of passing verification is made by this planning-only commit.
