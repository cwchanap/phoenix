# HPA-1137 — Skippable six-scene prologue: design specification

**Status:** Proposed; this draft PR is documentation only.  
**Issue:** https://linear.app/cwchanap/issue/HPA-1137/play-a-skippable-story-prologue-before-day-1  
**Implementation plan:** [2026-11-20-phoenix-skippable-prologue-implementation.md](../plans/2026-11-20-phoenix-skippable-prologue-implementation.md)  
**Reviewed source:** `main` at `67894bd89a7a`, plus PR #47's 21 Nov review. Refresh before implementation.  
**Delivery:** Implement this issue **in the same draft PR**, one ticket / one PR.

## Outcome and story contract

Replace Phoenix's two-sentence intro with the **approved 58 lines in six scenes**, played before Day 1. Source of truth for story order/meaning is the Traditional Chinese script in HPA-1137. Author an English source key and Japanese translation for each authored line; keep the current character names.

| Scene | Lines | Location / local time | Existing or supplied background |
| --- | --- | --- | --- |
| 1 — Platform | 1–7 (7) | Station, 19:00 | `assets/ui/backgrounds/prologue-platform.png` |
| 2 — Station front | 8–17 (10) | Station front, 19:05 | `assets/ui/backgrounds/prologue-station.png` |
| 3 — Country road | 18–37 (20) | Country road, 19:20 | `assets/ui/backgrounds/prologue-road.png` |
| 4 — Farm at night | 38–49 (12) | Moriyama farm, 19:50 | `assets/ui/backgrounds/intro.png` with a dark background grade |
| 5 — House interior | 50–55 (6) | House interior, 21:30 | `assets/ui/backgrounds/interior-night.png` (supplied Linear attachment; **darken this background in-game** after import) |
| 6 — Morning | 56–58 (3) | Day 1, 06:00 | `assets/ui/backgrounds/intro.png` without night grade |

**Art dependency is complete:** HPA-1138's *finished* 1280×720 platform/station/road paintings already exist on main; disregard HPA-1137's earlier placeholder-instruction for those files. Scene 5's `interior-night.png` is attached to HPA-1137, not yet present in the repository. Import that user-supplied painting; **do not generate new art**. Scene 3 uses one 96×96 frame of the existing 192×96 `kei-truck.png` spritesheet.

Narrative facts must stay consistent with gameplay: Gen-san's 30-minute farm/town drive, the Seed Shop, the Day-14 Harvest Market (13 days from Day 1), the 22:00 farming cutoff, overnight shipping payout, and the existing Day-1 start (150G and three Turnip seeds).

## Minimal content and presentation model

`ContentRules.PROLOGUE_SCENES: Array[Dictionary]` is one ordered stateless story table. **No new cutscene engine, custom JSON schema, scene-per-page resources, session state or save fields.**

- Declare `enum LineKind { NARRATION, DIALOGUE, INNER_VOICE, NOTE }` in `ContentRules`. Each line contains `kind: LineKind` and English `text`; **only dialogue** needs `villager`, an existing `VillagerRules.VillagerId` for Hana/Gen-san or `-1` for Kenji. No separate speaker strings, portrait names or role map.
- Each scene contains localized English `tag`, resource `background`, `portrait` (existing `VillagerRules.VillagerId` or `-1`), `night` (background-only tint boolean), `truck` (static truck boolean), and `lines`. **Set `night = true` for both the farm-at-night and house-interior scenes** and `false` for the morning. The shared restrained night tint applies to the painting only (including the already-dark bedroom painting), never text, portrait, paper card or letterboxes.
- Reuse `VillagerRules.display_name()`, `role_label()`, `PORTRAIT_NAMES` and the already-translated role labels for Hana and Gen-san. Keep existing `ContentRules.OPENING_SPEAKER` and `OPENING_ROLE` for Kenji's name and normal-dialogue role; remove only obsolete `OPENING_INTRO` and `OPENING_GUIDE` copy after updating its consumers. Inner voice uses the translated `Inner voice` label. The note uses a single translated `Mrs Moriyama` attribution (no new villager).
- A scene's `portrait` is shown at full opacity when that villager speaks, dimmed for other speakers or Kenji's inner voice (use existing `DialoguePanel.DIMMED`), and hidden as appropriate for no-dock narration/note. A `NOTE` line persists onscreen until the end of its scene; Kenji's next inner-voice reply appears below it. **No branches on hardcoded scene 3/4/5/6 or line 54/55 identifiers in the view**: the fields and page kind determine presentation.
- `OnboardingOverlay` remains the only presenter. Its only new mutable state is `_scene_index := 0` and `_line_index := 0`. Fresh New Game creates a fresh World/overlay, so no page-reset logic or `completed` flag. `render(snapshot)` updates visibility from `intro_acknowledged` without resetting the indexes; it may rerender the current page, but not advance it.
- Preserve the existing signal route `OnboardingOverlay.intro_acknowledged` → `GameHud.intro_acknowledged` → `WorldShell._on_intro_acknowledged()` → `GameSession.acknowledge_intro()`. `GameHud.has_blocking_modal()` remains the only world-input/clock gate; the single existing `intro_acknowledged` value remains the only save flag.

## Interaction contract

1. New Game opens scene 1 / page 1 over the blocked world. No movement, farming, passive-clock tick, or tutorial while the prologue is visible.
2. Enter/`ui_accept` or a left click **anywhere on the unobstructed opening/background or on the Continue hint** advances exactly one authored line on all page kinds, including narration/note pages that hide the VN dock. Scene and background advance automatically at the next record; no extra title/interstitial page.
3. On the 58th line, the primary action changes to the existing **Begin Day 1** button. Enter or clicking it emits the existing intro acknowledgement exactly once. The next frame resumes the existing Day-1 and tutorial flow, without any change to economy/save rules.
4. Esc/`ui_cancel` or clicking **Skip intro** on *any page* immediately calls the same acknowledgement path. **Consume the Esc event before emitting** so synchronous hiding cannot pass the same Esc to `GameHud._unhandled_input()` and open Pause. No intermediate final-page requirement.
5. Create Skip and Continue through the existing `UiStyle.hit_button()` and Accept through `UiStyle.primary_action()`; all are backed by `UiStyle._pill_button()` which already sets `Control.FOCUS_NONE`. Avoid a redundant focus override or a raw focusable `Button.new()`. Hidden buttons must not intercept clicks. Once acknowledged, the opening is hidden and a repeated key cannot signal again; no separate `completed` flag.
6. A valid Continue save with `intro_acknowledged = true` never shows the prologue. A new run instantiates a new overlay at scene 1. Finishing all lines and skipping from any point produce the same authoritative session snapshot.

## UI contract: use the actual Linear mockups

**Reference:** HPA-1137's `prologue-overview.jpg`, six `prologue-N-*.jpg` key frames and `prologue-mockup.html`. The six-key-frame mockups are 1920×1080; the finished HPA-1138 background paintings legitimately differ from the older placeholder landscapes.

- Every page: 90 px `LetterboxTop` / `LetterboxBottom` black bars; localized Prologue at top-left, plus a persistent top-right **Skip intro** hit target made with `UiStyle.hit_button(UiStyle.key_hint("Esc", "Skip intro", 17, UiStyle.CARD))`. The slanted place/time label is around (120,128), above six progress dots with one elongated active dot. Existing `UiStyle` colors and font, full native 1920×1080.
- **Keep navigation independent of the VN dock.** The persistent bottom-right **Continue** hit target is a `UiStyle.hit_button(UiStyle.key_hint("Enter", "Continue", 17, UiStyle.CARD))` child of `LetterboxBottom` for pages **1–57**, including no-dock narration and note pages. Hide it on page 58. The existing `UiStyle.primary_action("Enter", "BEGIN DAY 1")` **Accept** button remains in the VN dock footer **only on page 58**, which is an inner-voice/dock page. Both pointer and keyboard paths must work without double advancing: let the existing full-screen `OpeningPanel` handle background left-clicks while `UiStyle.hit_button()`'s child buttons consume their own clicks, so clicking Skip/Continue/Accept cannot also trigger background advancement.
- Dialogue: existing City Pop `UiStyle.vn_dock()` anchored around x=120–1800, localized speaker name and role, scene's existing portrait. Kenji has no portrait; when Kenji speaks with Gen-san, Gen-san remains as a dimmed listener.
- Narration: centered white line above background, no VN dock.
- Inner voice: Kenji night-color nameplate, localized Inner voice pill and muted-violet unquoted copy in dock.
- Note: center paper card for Mrs Moriyama's note, retained with Kenji's response shown beneath it on the subsequent page.
- Scene properties control the background-only night tint (farm night **and** interior night) and static one-frame truck. `SlantTag` currently cannot change fill or copy after `_init()`; add a tiny `set_tag(text_value, fill: Array[Color])` method in `scripts/ui/slant_tag.gd` to update its `Text` label and `_colors`, then `queue_redraw()`, instead of recreating tags per page or reaching into private fields. No train/truck or background animation, voice acting, new SFX or dialogue choices.

## Localization and automated fit

The actual CSV header is **`keys,zh_TW,ja`**. English copy *is the key*, not an `en` column. Every new story line, scene tag, hint, note author and role goes into `assets/i18n/strings.csv` with both zh_TW and ja in the same implementation commit. Reuse existing identical strings and the existing `OPENING_SPEAKER` / `OPENING_ROLE`. Change the current `Sato-san` zh_TW cell and existing references from `佐藤先生` to `佐藤小姐` while preserving her English/Japanese identities.

Existing `test_every_key_has_both_translations_with_matching_placeholders` already verifies uniqueness/placeholder consistency; **reuse it**. Change `test_localisation.gd:_rules_strings()` to enumerate the six prologue tags and 58 line strings, plus retained Kenji/name labels, rather than duplicate key checks. Content tests assert exact scene line counts `[7,10,20,12,6,3]`, `ResourceLoader.exists(scene["background"])`, and every required rule-bearing story fact.

**Do not use `get_visible_line_count() == get_line_count()` as the fit proof.** `UiStyle.vn_dock()` is bottom-anchored and grows upward: even unclipped lines can cover the scene tag or portrait. For each of 58 pages in each of en/zh_TW/ja, measure the rendered text/dock/note rects after layout: the dock's top must stay below the tag/progress dots, narration and note must stay between the 90 px bars, and text/button rects must not overlap or exit their containers.

## End-to-end acceptance (implementation; all pending)

- A real New Game traverses all six scenes/58 ordered pages and finally begins normal Day 1 at 06:00 with 150G, three Turnip seeds and existing tutorial behavior.
- Esc/Skip on first, middle and final pages produces the same session snapshot as finishing, without Pause, clock ticking, duplicate acknowledgement, or tutorial mutation; Continue from a valid acknowledged save bypasses opening.
- All authored content/hints are translated in en/zh_TW/ja; the 58×3 geometry check and translation tests pass, with no overlap/clipping.
- **MCP-driven end-to-end acceptance required by the project:** from an available MCP-connected execution environment, run the repository's existing real-input Godot/GdUnit4 e2e on **one supported desktop platform** (New Game → Enter advances → Esc skips → Day 1). A Godot-specific MCP is **not** required; the command may be invoked through a connected terminal/desktop environment. Do not invent an available connection or describe standalone shell/CI as MCP. If none is available, record the gate as **unverified** and do not represent acceptance as complete.
- The executing agent performs the project's **required visual UI check**: compare **actual 1920×1080 rendered frames** for the six representative scene compositions against the attached Linear mockups and inspect en/zh_TW/ja layout. Reuse screenshot support from existing Godot tooling/native tour helpers if it is available; **no new mandatory native-tour runner, capture framework or golden-image suite**. Record truthful capture/execution provenance and any uncovered gap; the check remains pending if rendered captures cannot be obtained.
- Existing verifier, headless smoke, GUT/integration, GdUnit4, godot-e2e and GitHub CI are green on committed implementation. Publish en/ja copy clearly in the PR for editorial feedback, but **human approval is not an acceptance gate**.

**Non-goals:** generating new art or sound, cutscene/scene framework, train/truck animation, choices, new player naming, save migration/backwards compatibility, economy/balance changes, multiple PRs, or multi-platform duplicate acceptance.
