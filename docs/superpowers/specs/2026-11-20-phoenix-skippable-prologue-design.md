# HPA-1137 — Skippable story prologue: design specification

**Status:** Proposed (documentation only; no gameplay implemented in this PR yet)  
**Issue:** https://linear.app/cwchanap/issue/HPA-1137/play-a-skippable-story-prologue-before-day-1  
**Implementation plan:** [2026-11-20-phoenix-skippable-prologue-implementation.md](../plans/2026-11-20-phoenix-skippable-prologue-implementation.md)  
**Reviewed main:** `67894bd89a7a` (20 November 2026). Recheck the branch base before implementing.  
**Delivery:** One implementation PR for HPA-1137, starting with this draft design/plan PR.

## Outcome and authoritative story

Replace the two-sentence opening (`ContentRules.OPENING_INTRO` / `OPENING_GUIDE`) with the **approved six-scene, 58-line** story before playable Day 1. It introduces Kenji's arrival at 19:00, Hana, the drive with Gen-san, the late-night farm handoff, Mrs Moriyama's note, and Day 1 at 06:00. The approved Traditional Chinese script in HPA-1137 is the **line/order/meaning source of truth**; author English source keys and Japanese translations to match it. Do not invent or remove lines.

| Scene | Lines | Place / local time | Background | Presentation |
| --- | --- | --- | --- | --- |
| 1 — Platform | 1–7 (7) | Station, 19:00 | `prologue-platform.png` | Narration, then Kenji inner voice |
| 2 — Station front | 8–17 (10) | Station front, 19:05 | `prologue-station.png` | Hana dialogue, narration, Kenji inner voice |
| 3 — Country road | 18–37 (20) | Country road, 19:20 | `prologue-road.png` | Gen-san/Kenji conversation, narration, inner voice; truck drawn separately |
| 4 — Farm at night | 38–49 (12) | Moriyama farm, 19:50 | existing `intro.png` with background-only night grade | Gen-san's handoff and departure |
| 5 — Inside the house | 50–55 (6) | House interior, 21:30 | attached `interior-night.png`, darkened | Narration/inner voice; Mrs Moriyama's paper note |
| 6 — Morning | 56–58 (3) | Day 1, 06:00 | existing `intro.png` | Narration, Kenji inner voice, Begin Day 1 |

The three scene-1–3 **finished painted 1280×720 backgrounds are already committed on main** by completed art issue [HPA-1138](https://linear.app/cwchanap/issue/HPA-1138/image-generation-paint-the-prologue-backgrounds-station-platform); they replace the placeholders originally mentioned by HPA-1137. Reuse these actual files at their existing paths, not the older placeholder PNG attachments. Scene 5's `interior-night.png` is a separately supplied mockup asset attached to HPA-1137 and is not presently in `assets/ui/backgrounds/`; import that supplied file in the implementation PR, without generating new artwork. Scene 3 uses the existing `assets/sprites/kei-truck.png` sheet and shows **one** 96×96 frame, not both sprites.

## Small, existing architecture

- **Story/content:** Replace the four intro-only constants with `ContentRules.PROLOGUE_SCENES`, one ordered `Array[Dictionary]`. Each scene has an English `tag` (place/time), a background resource path and ordered `lines`; each line has `speaker` (English key or empty), `kind` (one of `dialogue`, `inner_voice`, `narration`, `note`), and English `text`. Keep all 58 lines in this one table and avoid parallel story lists, new domain types, scene files per page, or a generic cutscene system.
- **Presentation:** Only `OnboardingOverlay` renders this content. Maintain two transient integers: scene index and line index. Each page shows exactly one new authored line; moving to the next line updates the background only at scene boundaries. Display props (portrait/road truck/note) remain presentation-only. Existing `UiStyle` helpers, `SlantTag`, `UiStyle.vn_dock()`, fonts and the single native 1920×1080 control tree are reused.
- **Session/gate:** Keep the current `OnboardingOverlay.intro_acknowledged` → `GameHud.intro_acknowledged` → `WorldShell._on_intro_acknowledged()` → `GameSession.acknowledge_intro()` path. Persist only the existing `intro_acknowledged` boolean. `GameHud.has_blocking_modal()` remains the **sole** world-input/clock gate. No changes to GameSession, SaveRepository, save schema, farming, or tutorial progress.
- **Render lifecycle:** `render(snapshot)` controls opening visibility from `snapshot["intro_acknowledged"]` but must **not reset page position on a routine render**. Initialize indexes at the start of a fresh opening; reset them when a new unacknowledged session first appears, never on ordinary re-render or locale change. Already-acknowledged Continue sessions show no prologue.

## Interaction behavior

1. On New Game, world content exists behind the opening, but movement, action hold and the passive clock stay gated. The first visible page is scene 1 / line 1.
2. Enter / `ui_accept` or a click on the **Continue** affordance advances exactly one line. After the last line of a scene, advance to the next scene without adding an interstitial page.
3. The **58th line** is the final page; its existing primary action is labeled **Begin Day 1**. Enter or clicking this action acknowledges the intro **once**, hides the opening, and exposes the unchanged first tutorial prompt through the ordinary flow.
4. Esc / `ui_cancel` or clicking **Skip intro** from **any** prologue page invokes that *same acknowledgement path immediately*, without spawning Pause, requiring another button press, changing time, or writing a special skip flag. Hold, key-repeat, and focused-button handling cannot double-advance or double-acknowledge.
5. Existing valid saves with `intro_acknowledged = true`, including Continue, bypass the prologue. A new game always starts at page one. Opening dismissal does not itself save or advance a day; the existing persistence rules are unchanged.

## Visual and story-page contract

**Authoritative references:** HPA-1137's attached `prologue-overview.jpg`, six `prologue-N-*.jpg` key frames, and `prologue-mockup.html` (1920×1080, exact sizing/colours). Compare screenshots with those attachments, not with the old flat placeholders.

- Every page: 90 px black top/bottom letterbox bars; top bar with localized Prologue and Esc/Skip intro; scene's place/time slant tag around x=120, y=128; **six** scene progress dots (active elongated); bottom-right Enter/Continue. Use existing City Pop tokens. UI overlays and portraits stay **above** any background night tint.
- **Dialogue:** reuse the bright VN dock around x=120–1800, with a colored speaker name tag and localized role pill. Hana portrait for scene 2 and Gen-san portrait for scenes 3–4. Kenji has no portrait; when he speaks to Gen-san, keep Gen-san visible as a **dimmed listener**. No portrait for Mrs Moriyama.
- **Narration:** centered white text above the background with no dock, as in frame 1.
- **Inner voice:** VN dock, night-colored Kenji name tag, localized Inner voice role, muted-violet text and no dialogue quotation marks.
- **Note:** Mrs Moriyama's authored note (line 54) is a centered paper card. On the next page (line 55), **retain the note on screen and display Kenji's response beneath it**, to reproduce the fifth mockup while still advancing one authored line per page.
- **Night scenes:** scene 4 shows the existing farm intro painting with a dark grade; scene 5 dims the supplied bedroom painting. Scene 6 returns to the normal intro background. Avoid fading UI text/portraits along with the background.
- **No animations required:** the train and truck do not drive; no voice-over, new SFX, dialogue choices, or transition manager. Frame 3 truck is static.

## Localization contract

The actual existing CSV header is **`keys,zh_TW,ja`**, with English source text in `keys` (not a fourth `en` column). For every new line, tag, speaker, role, and hint, add English key + approved Taiwanese Traditional Chinese + Japanese translation in `assets/i18n/strings.csv` **in the same implementation commit**. Reuse preexisting identical strings instead of duplicating keys. Localize dynamic labels with `tr()`; auto-translated Godot `Label.text` may be used where appropriate. Preserve formatting/placeholders and CSV quoting.

Change the existing `Sato-san` zh_TW entry from `佐藤先生` to **`佐藤小姐`**, and correct existing zh_TW text that refers to her by the old honorific. Do not rename her English/Japanese identity. Mrs Moriyama is a note attribution/name only, not a new `VillagerRules` NPC.

## End-to-end acceptance contract (implementation phase)

- A genuine New Game shows all **six scenes and 58 pages in exact order**, with authored scene tags, character treatment, backgrounds, and content. After the final Begin Day 1 action, the unchanged farm opens at Day 1 06:00, **150G and three Turnip seeds**, tutorial guidance resumes, and the player can farm.
- Esc/Skip from an early, middle, and final page results in the **same** Day 1 session snapshot/gate as completing all 58 pages; no duplicate command, Pause menu, clock advance, or tutorial-state change.
- A seeded, valid acknowledged Day-N save resumed from Continue **never** shows the opening; new game starts again from scene 1. Existing Day-14/result and persistence paths remain intact.
- For **en, zh_TW and ja**, every prologue line, speaker/role/tag/hint has a translation; automated label-height/visible-line checks prove **all 58 lines fit** their intended 1080p presentation. Native **1920×1080 screenshots for the six mockup key scenes** are visually compared by the executing agent against HPA-1137 attachments, checking dialogue/narration/note composition and no clipping.
- The **MCP-driven Godot end-to-end** path runs on **one supported desktop platform** with real app input (normal finish, skip, Continue); unit/integration, headless verification, GdUnit4 and godot-e2e lanes pass. Record evidence in the same PR. No human sign-off or multi-platform duplicate acceptance is required.

**Non-goals:** any new art/SFX generation (already a separate, completed HPA-1138 ticket), voice acting, moving train/truck, background animation, choices, entering a new player name, balancing, extra saved fields, backwards compatibility, or a reusable cutscene framework.
