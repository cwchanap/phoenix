# HPA-1137 — Skippable prologue: single-PR implementation plan

**Status:** Revised after PR #47's second 21 Nov review. Documentation only; all implementation, execution and visual acceptance gates remain open.  
**Design:** [Skippable prologue design specification](../specs/2026-11-20-phoenix-skippable-prologue-design.md)  
**Issue:** https://linear.app/cwchanap/issue/HPA-1137/play-a-skippable-story-prologue-before-day-1  
**Implementation branch / PR:** `agent/hpa-1137-skippable-prologue-plan` / **#47** — implement and verify on this same draft PR. **Single PR per issue.**  
**Reviewed base:** `main` at `67894bd89a7a`. Recheck if main moves before coding.

## Preflight — actual code, fixtures and assets

The change is small: keep `ContentRules` as one story table and `OnboardingOverlay` as one renderer, with two transient indexes, existing `GameHud` gate/signals and existing `GameSession.acknowledge_intro()` command. No new save field, cutscene engine, background animation or generated art.

- `scripts/ui/onboarding_overlay.gd` currently displays the two-string `OPENING_INTRO` / `OPENING_GUIDE` plus Day-1 diary, and pressing one Enter acknowledges. The tutorial card is separate and must stay unchanged.
- `scripts/game/content_rules.gd` owns opening copy; `scripts/game/villager_rules.gd` already owns `VillagerId`, `DISPLAY_NAMES`, `ROLE_LABELS`, `PORTRAIT_NAMES`. Keep existing `OPENING_SPEAKER` and `OPENING_ROLE` for Kenji; replace only the obsolete two lines with the authored `PROLOGUE_SCENES` table.
- `GameHud._build_modals()` relays `intro_acknowledged`, `GameHud.has_blocking_modal()` is the only input gate, and `WorldShell._on_intro_acknowledged()` calls the already-idempotent session command. Changing only the overlay's keyboard/paint behavior is sufficient.
- `assets/i18n/strings.csv` is `keys,zh_TW,ja` (English keys). `test_localisation.gd` already covers unique keys and matching placeholders. Extend `_rules_strings()` to all story tags and 58 lines; do not copy the existing CSV validator. Fix `Sato-san` / `佐藤先生` → `佐藤小姐` in existing zh_TW rows referencing her.
- **No art dependency:** completed HPA-1138 already committed `prologue-platform.png`, `prologue-station.png` and `prologue-road.png` under `assets/ui/backgrounds/`. Import the **supplied** HPA-1137 `interior-night.png` attachment there. Use the first frame of the existing `assets/sprites/kei-truck.png` `AtlasTexture` (96×96).
- Approved visual contract: six HPA-1137 JPG mockup frames and `prologue-mockup.html` at 1920×1080. There is no need for a new screenshot golden suite.

### Critical regression audit: fixtures relying on one Enter

**Do this before Enter changes.** Existing tests dismiss the old opening with one `ui_accept`; switching to line-by-line advancement without updating them disables most test worlds and cascades into misleading failures.

| Fixture/caller | Change |
| --- | --- |
| `tests/integration/test_gameplay_shell.gd:_spawn_world(true)` (used by `_world()` and `_settings_world()`) | Replace its intro-dismiss Enter with `ui_cancel` press/release; all dependent tests still start unlocked |
| `tests/integration/test_gameplay_shell.gd:_configured_world()` (separate seeded-world helper around previous line 4450) | Replace its **additional** intro-dismiss Enter with `ui_cancel` **only if** `(world.hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay).is_opening_visible()`; a seeded acknowledged save may already show a different modal |
| `tests/headless/world_shell_smoke.gd:_acknowledge_intro()` | Replace one Enter with Esc/`ui_cancel` |
| `tests/integration/test_app_launch.gd` (opening dismissal around old lines 124–131) | Use Esc and assert tutorial/state preserved |
| `tests/e2e/gameplay_day_one_test.gd` New Game launcher (~53) | Use Esc for intro dismissal; leave commerce-panel Enter inputs untouched |
| `tests/e2e/ui_navigation_test.gd` New Game launcher (~28) | Use Esc before testing Pause/navigation; leave later Escape modal inputs intact |
| `tests/e2e/world_readability_test.gd` New Game launcher (~145) | Use Esc for intro dismissal; leave other modal/farming controls intact |
| `tests/integration/test_gameplay_shell.gd:test_escape_does_not_open_help_over_blocking_intro` (~3185) | **Invert** the expectation: Esc hides intro, unblocks world, and **does not** open `PausePanel` |
| `tests/integration/test_vn_surfaces.gd` intro assertions (~372–487) | Replace old DayTag/Intro/Guide/DiaryLine/one-Enter-ack assertions with scene/tag/dots/page-kind/last-page assertions |

Do a repository-wide audit for other **intro-dismiss** `ui_accept` fixtures before merging; do **not** blindly replace Enter used by shops/dialogue/title. `tests/e2e/app_launch_test.gd`'s existing acknowledged-save Continue path does not need a new dedicated e2e; it already validates an acknowledged Day-5 save. `AppRoot._launch()` instantiates a fresh World/overlay per New Game.

## Task 1 — Introduce Esc skip and fix fixtures, with a green checkpoint

**Files:** `scripts/ui/onboarding_overlay.gd`, the two `test_gameplay_shell.gd` fixture helpers and inverted Esc test, `tests/headless/world_shell_smoke.gd`, `tests/integration/test_app_launch.gd`, `tests/e2e/gameplay_day_one_test.gd`, `tests/e2e/ui_navigation_test.gd`, `tests/e2e/world_readability_test.gd`.

1. Add Esc/`ui_cancel` in the overlay's existing `_unhandled_input()` gate. While `OpeningPanel.visible` is true, **call `get_viewport().set_input_as_handled()` before emitting `intro_acknowledged`**. It must not propagate to `GameHud._unhandled_input()`; otherwise the now-hidden intro lets that same Esc open Pause.
2. Switch exactly the intro-dismiss fixtures above from Enter to Esc. **Guard `_configured_world()` with `OnboardingOverlay.is_opening_visible()` before sending Esc**: when a seeded save is already acknowledged (e.g. Day-2 state in the existing tests), unconditional Esc could close a different modal or open Pause. The existing one-Enter behavior still works temporarily. Invert the locked-world regression test to assert intro closed, Pause hidden and world input resumed. Keep the tutorial progress assertion unchanged.
3. Run the existing full integration/headless/e2e lanes and record a green commit/checkpoint **before** changing Enter semantics. This is the high-leverage ordering from the GitHub review: the commonly used `_spawn_world(true)` helper must not remain broken while later UI work is underway.

**Done when:** Esc skips to the canonical Day-1 state in both direct and shared fixtures, no Pause is opened, and previously exercised suites still pass.

## Task 2 — One typed content table and translations, without duplicate localization machinery

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, **supplied `assets/ui/backgrounds/interior-night.png`**, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`.

1. Add `ContentRules.LineKind` enum for NARRATION, DIALOGUE, INNER_VOICE, NOTE and exactly six ordered scene dictionaries. Use typed enum values as `kind` (no typo-prone strings). The line record needs `kind`, English `text` and a `villager` only for dialogue (`VillagerRules.VillagerId`, or `-1` for Kenji). The scene record needs `tag`, `background`, `portrait` (`VillagerId` or `-1`), `night`, `truck`, `lines`. Reuse villager name/role/portrait lookups instead of a separate speaker registry.
2. Transcribe **all 58 numbered zh_TW lines verbatim in meaning/order**, author 58 English source keys and Japanese translations. Keep 6 scene tags (19:00, 19:05, 19:20, 19:50, 21:30, 06:00), localize all role/name/hint/note-author strings; reuse existing `OPENING_SPEAKER`, `OPENING_ROLE` and already-translated `VillagerRules` identities. Add each new English key and its zh_TW/ja to CSV in the **same commit**. Change old Sato-san references to `佐藤小姐`.
3. **Import the existing HPA-1137 `interior-night.png` attachment** into `assets/ui/backgrounds/interior-night.png` **during Task 2**, then run `godot --headless --path . --editor --quit` so its texture import exists. This is a supplied asset, not a new art-generation task. Set the scene-4 and scene-5 `night` fields to `true` (including a background-only darkening of the supplied bedroom painting), and the morning scene to `false`.
4. Test six scene count and per-scene line counts **[7,10,20,12,6,3]**, total 58; `ResourceLoader.exists(scene["background"])` for every scene **after import**; legal speaker/portrait IDs and the fixed gameplay facts (30-minute travel, Day-14 market, 22:00 cutoff, overnight shipping, initial three Turnip seeds).
5. Update `test_localisation.gd:_rules_strings()` (old `OPENING_*` block near lines 80–86) to traverse `PROLOGUE_SCENES` tags and all 58 line strings, and include the retained Kenji name/role and note author. Existing `test_every_key_has_both_translations_with_matching_placeholders` already checks CSV duplicates and placeholders; do not reimplement it. There is no proper-name exemption: these names have distinct translations.
6. Remove obsolete `OPENING_INTRO` / `OPENING_GUIDE` only in the coordinated overlay commit after its rendering consumers are replaced, so an intermediate staged branch is not pointlessly broken. No legacy compatibility adapter is needed.

**Done when:** Table shape and translations are correct, all referenced background paths exist, and no duplicate identity, translation or script lookup is introduced.

## Task 3 — Render page kinds and make Enter advance (second green checkpoint)

**Files:** `scripts/ui/onboarding_overlay.gd`, **`scripts/ui/slant_tag.gd`**, existing overlay scene only if necessary, `tests/integration/test_vn_surfaces.gd`, `tests/integration/test_app_launch.gd`, `tests/integration/test_gameplay_shell.gd`.

1. Keep the existing native 1920×1080 `OnboardingOverlay` tree, background, `UiStyle.vn_dock()`, slant tags and primary actions. Add only `_scene_index := 0` and `_line_index := 0` plus simple `_show_page()`, `_advance_page()` helpers; **no reset/completed boolean or second state machine**. Every new World instantiates a new overlay; `render(snapshot)` must not reset page position.
2. Implement six-scene composition from **scene data**, not hardcoded index checks: `background`, background-only `night` grade for **both scene 4 farm-night and scene 5 bedroom-night**, `truck` first-frame 96×96 atlas, `portrait` ID (existing `VillagerRules.PORTRAIT_NAMES` and roles), translated `tag` and six active-progress dots. Keep 90 px letterbox bars, localized Prologue/Skip/Continue hints. Add a tiny `SlantTag.set_tag(text_value: String, fill: Array[Color])` in `scripts/ui/slant_tag.gd`: set its `Text` label, assign `_colors` (copy fill), and `queue_redraw()`. This supports dynamic scene tags and speaker color without rebuilding nodes or mutating private fields from the overlay.
3. Render each `LineKind`: NARRATION centered white with no dock; DIALOGUE with the existing name/role dock and VillagerRules portrait (Kenji no portrait); INNER_VOICE with Kenji dark tag and muted violet unquoted text; NOTE with central paper card and localized fixed Mrs Moriyama attribution. Persist the note until scene boundary so the next Kenji reply is below the note. Scene portrait is full opacity when its villager talks, otherwise dimmed using existing `DialoguePanel.DIMMED` where applicable.
4. **Pin click-target ownership outside the dock:** a top-right **Skip intro** hit target belongs to `LetterboxTop`, built with `UiStyle.hit_button(UiStyle.key_hint("Esc", "Skip intro", 17, UiStyle.CARD))` and always visible. A bottom-right **Continue** hit target belongs to `LetterboxBottom`, built with `UiStyle.hit_button(UiStyle.key_hint("Enter", "Continue", 17, UiStyle.CARD))` and visible on pages **1–57**, including dock-hidden narration and note. The original `Accept` (`UiStyle.primary_action("Enter", "BEGIN DAY 1")`) stays in the VN dock footer **only on page 58** (an inner-voice page). Clicking any of these routes to the same advance/skip/accept actions as Enter/Esc. Also handle a left-click on the otherwise passive full-screen `OpeningPanel` to advance (as the ticket's **click anywhere** interaction), while allowing each `UiStyle.hit_button()` child to consume its own click so Skip/Continue/Accept do **not** double-fire.
5. Change Enter/`ui_accept` to **one-line advance** until the last page; final Enter or Accept click emits the existing acknowledgement exactly once. Esc/Skip remains the Task-1 direct acknowledgement. `UiStyle.hit_button()` and `UiStyle.primary_action()` already use `_pill_button()` with **`FOCUS_NONE`**, so do not add a redundant focus flag or a raw focusable button. Use the visibility guard against repeated input after dismissal; never introduce `_completed`.
6. Replace obsolete `test_vn_surfaces.gd` intro assertions: letterboxes plus place/time tag and six dots, four kinds, portraits, the **top-bar Skip and bottom-bar Continue hit targets on no-dock pages**, background left-click progression without duplicate button dispatch, final-page dock-only Accept, note persistence and one-signal behavior on final Enter followed by repeated Enter. Add a **GUT integration loop over all 58 pages** verifying order, scene changes and completion vs skip snapshot equality (including unchanged initial money, seed, time and tutorial completion). The common world fixture changes are already present from Task 1.
7. **Meaningful geometry test** in the same GUT suite: for en, zh_TW and ja, render all 58 pages at 1920×1080 and assert the dock's top is **below the progress dots/tag**, narration and paper note are **between the 90 px letterbox bars**, and text/button rects (including top/bottom bar targets) don't overflow containers or overlap. `get_visible_line_count() == get_line_count()` alone is NOT a fit test because the bottom-anchored `VBoxContainer` can grow upward indefinitely.
8. Verify one extra `ui_accept` after final completion does not re-acknowledge, and Esc from page 1, mid-page and page 58 does not open Pause or advance the clock.

**Done when:** The new 58-page playback and all fixtures are green; content and portrait selection are data-driven, with no extra state or gameplay code.

## Task 4 — Focused e2e and project-required MCP/visual acceptance, committed-head CI

**Existing tools:** `GdUnitE2ETestSuite` with `launch_game`, `input_action`, `click_node`, `wait_for_property`; existing GUT integration and native project tooling. Do not create a new mandatory `tests/native_tour/hpa_1137_tour.gd` framework or duplicate Continue test.

1. Add **one focused real-input godot-e2e test**: title → New Game → Enter once **still shows prologue at page 2** → Esc → opening hidden, HUD Day 1 visible, gameplay enabled (same 150G / 3 seeds). Run on **one supported desktop platform**, no duplicate native-platform acceptance needed. Preserve existing `app_launch_test.gd` Continue test for a seeded acknowledged Day-5 save.
2. For **MCP-based end-to-end acceptance as required by this project's working criteria**, use an **available MCP-connected command/desktop execution environment** to invoke the **existing** real-input Godot e2e on one platform. **Do not create a new Godot-specific MCP tool or an extra test framework.** Perform the project's visual UI check by using existing Godot screenshot facilities/native-tour helpers (if available) to obtain **actual 1920×1080 frames** for the six representative mockup compositions; the executing agent compares them with the six HPA-1137 JPG/HTML references and checks the en/zh_TW/ja layouts. No mandatory new native-tour runner, capture pipeline or golden test. Document actual environment, test results, screenshot provenance and comparison notes on this same PR.
3. The repository has **no dedicated Godot MCP transport**, and earlier HPA-743 native verification correctly distinguished an agent shell run from an MCP run. The project's MCP criterion refers to **how the test is invoked and observed**, not a requirement to build a Godot MCP plugin. **Do not mislabel CI or local shell output as MCP execution.** If no connected execution environment can run Godot, this criterion and any unperformed screenshot check remain **unverified**; do not claim all acceptance passed or silently waive them. The standard GdUnit e2e lane remains the code-level automated check regardless.
4. Surface English/Japanese translations clearly in the PR for the editorial review mentioned in HPA-1137. This review can refine copy; **human approval is not an acceptance criterion** and all test/visual gates are agent-verifiable.
5. Once implementation is committed, execute the verifier, unit/integration GUT, Godot smoke, GdUnit4 and godot-e2e; inspect GitHub CI. The clean verifier archives **committed HEAD**, so don't run it as proof of uncommitted work:

```sh
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
# After coherent implementation commit(s)
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
```

6. Record the exact tested commit, commands, test outcomes, screenshots and mockup-comparison notes in PR #47. Keep this same PR draft while any required acceptance gate is unverified; **do not invent evidence or silently treat CI as the MCP/visual check**. Do not open a second PR.

## End-to-end acceptance checklist (pending; plan-only update)

- [ ] All **58 lines × six scenes** appear in ticket order, with correct localized tags, paintings, speakers/roles/portraits, dimmed listener, truck and retained note.
- [ ] Real-input New Game → Enter advances exactly one page → Esc skips to Day 1; finishing the 58th page also starts normal Day 1 at **06:00 / 150G / 3 Turnip seeds**, with original tutorial and world input gate.
- [ ] First/middle/final Esc all produce the same session snapshot as completion, **without opening Pause**, double acknowledgement, extra time advance or changed tutorial completion; acknowledged Continue bypasses the opening.
- [ ] Both `test_gameplay_shell.gd` helpers (**guard `_configured_world()`'s skip when an acknowledged save has no prologue**), headless intro helper, app-launch integration and all three e2e New Game fixture paths are updated; existing unrelated Enter interactions remain intact.
- [ ] All 58 story lines, scene tags, roles, hints and note author translate en/zh_TW/ja; the **58×3 real geometry check** shows no dock/tag or bar overlap, including **Skip/Continue hit targets when the VN dock is hidden**, with Sato-san corrected to `佐藤小姐`.
- [ ] The project's **MCP-driven** real-input Godot e2e runs on **one platform** and the executing agent compares **actual 1920×1080 frames** for the six representative scenes against HPA-1137 mockups, checks en/zh_TW/ja layouts and records provenance. Existing capture/test tooling only; no new capture framework. If no connected execution/capture route exists, keep this acceptance gate **unverified**, rather than reporting a non-MCP run as passing.
- [ ] Unit/integration GUT, headless smoke, committed-head clean verifier, GdUnit4, godot-e2e and GitHub CI green on the final implementation. Editorial en/ja feedback invited in the PR, **not** a human-approval acceptance gate.

**Changes deliberately excluded:** new art/SFX generation, generic cutscene framework, animation, save migrations/backwards compatibility, additional test frameworks, mandatory new native tour, multi-PR split, and duplicate platform testing.

## Implementation notes and deviations

Recorded during implementation. The acceptance checkboxes above stay open.

- **NOTE attribution stays inline.** The approved zh_TW and ja note text already ends with the signature, so `ContentRules.NOTE_AUTHOR` and its `Mrs Moriyama` CSV row were removed instead of printing the signature twice.
- **Scene 3's mirrored right-hand Gen-san is not reproduced.** The table has no side data, so the country-road scene shows the truck and the scene's portrait rules only.
- **Listeners are dimmed with `DialoguePanel.DIMMED`**, the same 45% alpha the dialogue panel uses for non-speaking characters.
- **The night grade is a single `NIGHT_GRADE` modulate.** It darkens only the background painting for scenes 4 and 5; the letterbox bars, dock and text stay unshaded.
- **Inner voice keeps the pink-to-orange dock band.** The mockup's violet band would need a per-page recolour of the gradient that `UiStyle.gradient_band()` builds once, so it was not applied. The mockup's `#5e4470` 34px/500 body text and `#6b4a9e` role-label text colour are applied (the pill itself keeps the white card).
- **Kenji's note reply uses the dock.** The mockup shows a bare line under the card; the overlay keeps the inner-voice dock so every spoken line looks alike.
- **Narration pages draw a bottom `Scrim` gradient**, added after review, matching the mockup's darkened lower part so the text reads over any painting.
- **The top-bar label is the translated "Prologue" alone**, so zh_TW shows 序章 where the mockup shows 序章 PROLOGUE.
