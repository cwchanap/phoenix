# HPA-684 — Quiet Field diary/copy: single-PR implementation and verification plan

**Status:** Planning only, no code implemented or tests run on this draft.
**Linear:** https://linear.app/cwchanap/issue/HPA-684/add-the-players-morning-diary-and-rewrite-openingresult-copy-for-the
**Companion design:** [2026-11-09-phoenix-quiet-field-diary-design.md](../specs/2026-11-09-phoenix-quiet-field-diary-design.md)
**Delivery:** One task → one PR. Implement in this same branch/PR after review; do not create a separate implementation PR.

## Ground-truth baseline

Phoenix `main` already includes HPA-683 empty farm, HPA-685 swappable maps, HPA-686 town travel, and HPA-682 native-1080p panels.

- `ContentRules` has the tutorial table and existing `build_harvest_result(state)`, which returns `tier` and `title`. Tiers are `new_beginning`, `promising_farmer` and `heart_of_harvest`.
- `OnboardingOverlay._build_opening()` builds `OpeningPanel/DayTag` and an existing dock with `Intro`, `Guide`, `Accept`, and a speaker tag taken from `VillagerRules.VillagerId.SHOPKEEPER`. This now incorrectly credits Sato-san rather than the player. `render(snapshot)` owns the opening visibility; do not change it.
- `MorningSummaryPanel.present(summary)` receives `completed_day` and `next_day`; `GameHud.render(snapshot)` shows it when `pending_morning_summary != null`. `MorningSummaryPanel` owns a `PhoneFrame`, three notification cards, flexible spacer and footer/save status. `summary_state()` exposes a testable read-only view of rendered text.
- `ResultScreen.present(result)` already receives `result["tier"]` indirectly from `AppRoot._show_result`, displays the title and all scores/cards, and exposes `result_state()` for tests. `_header()` currently contains only a kicker and title.
- `assets/i18n/strings.csv` is `keys,zh_TW,ja`; `tests/unit/test_localisation.gd` checks CSV completeness/placeholders and a `_rules_strings()` list. `UiStyle.label` returns an auto-translated Godot Label; dynamic text still follows existing `tr()` conventions.
- No code changes are needed in `GameSession`, `SessionStateValidator`, `SaveRepository`, `WorldShell` or map scenes.

## Step 1 — Author fixed diary and result copy together with translations

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`.

1. Add `const DIARY_LINES: Array[String]` with the 14 approved English lines from the design (array index 0 = Day 1). Add one tiny static accessor `diary_line(day: int) -> String` with an assertion that day is in 1..14, returning `DIARY_LINES[day - 1]`. This keeps the mapping local, with no runtime save fields or fallback text.
2. Add `const RESULT_TIER_LINES := { &"new_beginning": ..., &"promising_farmer": ..., &"heart_of_harvest": ... }`. Use the exact existing tiers. A helper is optional if needed for a clean single lookup, but do not introduce a narrative service or dispatch registry. Do not modify `build_harvest_result()` or any tier thresholds.
3. Add EN-key/zh_TW/ja rows for the 14 diary lines, three tier epilogues, both opening paragraphs, `Kenji` and `Former software engineer` in the one existing CSV. Translate in-house in Taiwan Traditional Chinese and natural Japanese. Escape CSV punctuation correctly and keep every translated row nonblank. The English string is the key.
4. Extend `test_content_rules.gd` to assert exactly 14 nonempty diary lines, deterministic Day 1/Day 14 mapping, and exact coverage of the three tier keys. Keep a small test that `build_harvest_result()` has unchanged tier/score behavior by reusing existing fixtures, not building a new finale harness.
5. Extend `test_localisation.gd::_rules_strings()` with all `DIARY_LINES` and `RESULT_TIER_LINES` values; explicitly include the new opening/speaker copy keys because the UI strings aren't automatically discovered by the rules list. Assert both supported locales produce nonempty translations, with the existing CSV row/placeholder contract enforced. Preserve `after_each()` restoring `en`.
6. Run the existing GUT verifier for a safe checkpoint before committing; no panel changes in this step.

**Checkpoint:** All 14 authored lines and three tier epilogues are known, localizable content. Gameplay and save files are unchanged.

## Step 2 — Wire the three existing presentation surfaces

**Files:** `scripts/ui/onboarding_overlay.gd`, `scripts/ui/morning_summary_panel.gd`, `scripts/ui/result_screen.gd`, `tests/integration/test_gameplay_shell.gd` and existing result/persistence UI tests as appropriate.

1. **Day 1 opening:** In `OnboardingOverlay._build_opening()`, replace the two current static strings with the design's Intro and Guide. Replace the shopkeeper-based `NameTag`/`Role` contents with localized `Kenji` and `Former software engineer` (translate before uppercasing the name tag). Add one concise wrapping `DiaryLine` Label in the existing dock below `Guide`, sourced from `ContentRules.diary_line(1)`. Keep `Intro`, `Guide`, `NameTag`, `Role`, `Accept` and existing node names stable for current tests. Do not show a summary on Day 1; it is an opening note.
2. **Morning Days 2–14:** Add a named `DiaryLine` label near the bottom of `MorningSummaryPanel`'s main `Column`, before the flexible spacer/footer, styled as a small muted journal entry. In `present(summary)`, use `next_day` and set `_diary_line.text = tr(ContentRules.diary_line(next_day))`. Preserve all three cards, save badge/error, action text, and acknowledgment behavior. Add `"diary_line": _diary_line.text` to `summary_state()` for assertions. No new scrolling container or fourth notification card.
3. **Result:** Add a single centered wrapping `TierLine` label immediately after `_title` in `ResultScreen._header()`. In `present(result)`, look up `result["tier"]` in `ContentRules.RESULT_TIER_LINES` and assign the localized line. Extend `result_state()` with `"tier_line"`; retain all existing keys and rendered stats/cards. The ending title, score calculation and villager quote logic remain exactly as they are.
4. **Content ownership:** The two presentation panels read content, but do not write `GameSession`. Do not store the diary in `state()` or duplicate it into `pending_morning_summary`. The existing `next_day`/`tier` fields suffice. No new events or input actions.
5. **Layout:** The morning `PhoneFrame` is 560×920 and already reserves footer space. Limit diary typography to a short, wrapping note; if the three-card maximum shipment/save-error state overflows, adjust spacing within this panel minimally rather than removing information. Ensure the result subtitle does not push stats or buttons off the supported viewport.

**Checkpoint:** Real opening, overnight summary and result routes show only their intended text, without changing modal/input gating.

## Step 3 — Targeted regressions and localization/layout pass

**Files:** Prefer extending existing GUT integration/persistence tests rather than adding a parallel test framework. Potential homes include `tests/integration/test_gameplay_shell.gd` and `tests/integration/test_persistence_flow.gd`. Touch README/CLAUDE.md only to correct current user/handoff narrative.

1. **Opening:** In the existing locked-world test, assert `OnboardingOverlay`'s `NameTag`, `Role` and `DiaryLine` reflect Kenji and Day 1; `Intro` mentions the lottery/Tokyo move, the existing Begin button still unlocks input and tutorial navigation still proceeds.
2. **Overnight:** Use an existing real sleep/summary fixture. Verify the second morning uses Day 2 (not Day 1) and the last normal summary uses Day 14. Re-present the same summary and assert the same line (no duplicated nodes). Existing ack gates world input and clears the summary. Do not add an artificial Day 15 state.
3. **Continue:** Reuse the persistence round trip with a valid pending morning summary. Saving/reloading still yields the same `next_day` and exactly that day's note, while a save with no pending summary produces no extra overlay. Assert the serialized game state contains no `diary` or `story` keys and the current save schema is unchanged.
4. **Results:** Exercise each of the three existing result tiers through `ContentRules.build_harvest_result()` fixtures or existing result tests. Confirm matching `TierLine`, unchanged title/stat totals/villager cards, and completed-run Continue still opens ResultScreen directly. Use `result_state()` to avoid brittle scene searches.
5. **Locales:** For EN/zh_TW/ja verify `Intro`, `Guide`, `NameTag`/`Role`, morning `DiaryLine` and all three `TierLine` epilogues. Check native **1920×1080** and supported **960×540** with both typical and maximum shipment count, a visible save error, and all three end tiers. Check no label overlaps/hides acknowledgment or result action buttons. Use existing UI containment checks and a manual visual spot check; screenshot goldens were removed in PR #29 and must not be restored.
6. **Docs:** Update `README.md` intro/player contract to describe the lottery, Kenji and daily diary, and `CLAUDE.md` to record that `ContentRules` owns diary/tier copy. Keep this in the same issue/PR.

**Checkpoint:** Tests cover day mapping, resume, localisation and screen visibility while gameplay/economy rules stay fixed.

## Four final release gates (run only on implemented committed HEAD)

```bash
# 1. Clean Godot import, GUT tests, headless smokes and audio check
./tools/verify-clean.sh

# 2. GdUnit4
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c

# 3. godot-e2e
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c

# 4. Headless import, unsigned macOS export and ZIP integrity
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record commit SHA, actual counts/results, and any unverified native visual checks in the **same** PR. These gates have **not** been run for this docs-only planning commit. Do not state that a design review or implementation has already been approved.

## Explicit exclusions

- No new UI framework, modal, diary navigation screen, dynamic story conditions, branch choice system, cutscene, language engine or character customization.
- No modifications to day timing, crop economy, endings, townspeople relationship rules, map/truck behavior, `GameSession` state or save schema; no compatibility migration.
- No new images, portraits, sprite sheets, voice lines, BGM or SFX. Any future art/audio work is a **separate Linear task and separate PR**. HPA-546 owns player walk-cycle implementation and remains separate.
- Avoid opening separate PRs per screen or per locale. One coherent HPA-684 PR gets all copy, wiring, tests and docs.

## Done when

All 14 diary lines appear exactly once at their intended daily entry point, result-tier epilogues match existing scoring, Kenji's opening establishes the lottery premise, EN/zh_TW/ja are complete, and all four final release gates plus responsive layout checks pass on the final committed implementation. There is still exactly one PR for HPA-684.
