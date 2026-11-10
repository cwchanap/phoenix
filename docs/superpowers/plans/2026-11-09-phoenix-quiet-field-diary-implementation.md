# HPA-684 — Quiet Field diary/copy: single-PR implementation and verification plan

**Status:** Planning-only revision after [GitHub design review](https://github.com/cwchanap/phoenix/pull/39#pullrequestreview-5836415721). No feature code or test results are claimed.
**Linear:** https://linear.app/cwchanap/issue/HPA-684/add-the-players-morning-diary-and-rewrite-openingresult-copy-for-the
**Companion design:** [2026-11-09-phoenix-quiet-field-diary-design.md](../specs/2026-11-09-phoenix-quiet-field-diary-design.md)
**Delivery:** One HPA-684 issue → one PR. Implement in **this same PR** after the design is reviewed. No separate implementation PR.

## Ground-truth baseline (after HPA-686)

- `ContentRules.build_harvest_result(state)` currently determines the existing `tier` and `title` together. `AppRoot._show_result()` builds this presentation dictionary afresh from persisted state; it is not part of the save schema.
- `OnboardingOverlay._build_opening()` builds the Intro, Guide, NameTag, Role and Accept controls; it still uses Sato-san's name/role and old copy. `tests/integration/test_vn_surfaces.gd::test_intro_vn_box_keeps_authored_name_role_and_copy` (around line 390) explicitly pins `SATO-SAN` and the old Intro, so updating this test is mandatory.
- `MorningSummaryPanel.present(summary)` gets the persisted and validated `next_day`; `GameHud.render(snapshot)` displays the panel only while `pending_morning_summary` exists. `summary_state()` exposes rendered labels. The 560×920 `PhoneFrame` already has weather, farm, bank, save error and acknowledgment. `GameRules.MAX_DAY` is the source of the season length (currently 14).
- `ResultScreen.present(result)` already receives the result dictionary and renders title, scores, villager cards, warning and actions. Its `_header()` has a title and kicker.
- `assets/i18n/strings.csv` uses `keys,zh_TW,ja`, with English text as the key. Plain text assigned to a Godot Label auto-translates; explicit `tr()` is only needed when transforming text (e.g. translating the Kenji name before uppercasing it).
- `tools/verify-clean.sh` runs `git archive HEAD` and downloads GUT into a temporary archive; **it never tests uncommitted worktree changes**. Commit each checkpoint first, then run it. GdUnit4 and e2e are separate release gates.

## Commit 1 — Content and localization (no UI wiring yet)

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`.

1. Add `const DIARY_LINES: Array[String]` with the 14 approved English source strings from the design. Add `static func diary_line(day: int) -> String` with a one-based lookup and `assert(day >= 1 and day <= GameRules.MAX_DAY)`. Pin `DIARY_LINES.size() == GameRules.MAX_DAY` in GUT rather than scattering literal 14 checks. No conditionals, storytelling state, JSON or new save keys.
2. Centralize ending title and epilogue in `const RESULT_TIERS := {&"new_beginning": {"title": "New Beginning", "epilogue": ...}, &"promising_farmer": {...}, &"heart_of_harvest": {...}}`. Keep the three existing tier keys and the existing score/relationship **threshold conditionals** in `build_harvest_result()`. After choosing the tier, read both title and epilogue from `RESULT_TIERS[tier]` and return `"epilogue"` alongside `"title"`. The result dictionary is transient/presentation-only; do **not** add either field to saved game state. Avoid a parallel table or duplicate lookup in the view.
3. Add CSV rows for the 14 diary lines, 3 epilogues, 2 opening paragraphs, and `Kenji` / `Former software engineer` in EN-key/Traditional Chinese (Taiwan wording)/Japanese. Keep CSV escaping correct. The revised Day 3 diary sentence differs from the New Beginning epilogue so the ending does not repeat the day note.
4. Extend `test_content_rules.gd` with `DIARY_LINES.size() == GameRules.MAX_DAY`, nonempty entries for every valid day, first/last-day mapping, and exact coverage/contents of the three `RESULT_TIERS` keys. **Reuse** existing `test_harvest_result_tier_boundaries` and totals tests (around lines 290–316) rather than duplicating scoring assertions.
5. In `test_localisation.gd::_rules_strings()` iterate `ContentRules.DIARY_LINES` and each `RESULT_TIERS` entry's `title` and `epilogue`, replacing the hard-coded ending-title list. Explicitly include the two opening paragraphs and the two speaker strings, which the rules-string scan otherwise misses. The existing CSV duplicate/missing/placeholder tests still apply.
6. **Commit** content+CSV+tests together. Then run `./tools/verify-clean.sh` against that committed HEAD. No worktree-only GUT run disguised as a clean verification.

**Checkpoint:** The content has a single source, the localization is complete and the existing scoring behavior remains covered.

## Commit 2 — Wire existing surfaces and update the tests they own

**Files:** `scripts/ui/onboarding_overlay.gd`, `scripts/ui/morning_summary_panel.gd`, `scripts/ui/result_screen.gd`, plus existing `tests/integration/test_vn_surfaces.gd`, `test_phone_surfaces.gd`, `test_app_launch.gd` and localized README/CLAUDE.md updates. Implement the following surface/test pairs together before committing; never leave a known old-copy assertion red.

1. **Opening / `test_vn_surfaces.gd` around line 390:** Replace old Intro and Guide with the approved lottery/Tokyo/Day 14 copy. Change the currently Sato-san-based `NameTag` and `Role` to one-off `Kenji` and `Former software engineer` strings; translate the name **before** calling `to_upper()` in `SlantTag`. Add one named, wrapping `DiaryLine` from `ContentRules.diary_line(1)` below Guide, without altering Intro, Guide, NameTag, Role, Accept node names. Update `test_intro_vn_box_keeps_authored_name_role_and_copy` to expect the new name, role, opening copy and Day 1 diary. Keep the existing blocking/Begin behavior regression; don't create a second opening test suite.
2. **Morning / `test_phone_surfaces.gd` around lines 979 and 1097:** Add a 16px-or-larger, wrapping `DiaryLine` in the existing `MorningSummaryPanel` main `Column` above its flexible `Spacer`. `present(summary)` assigns `ContentRules.diary_line(int(summary["next_day"]))` directly; **do not** wrap plain Label values in `tr()`, since the Control translates them. Add `"diary_line": _diary_line.text` to `summary_state()`. Extend `test_morning_full_content_long_error_keeps_acknowledge_reachable` to re-present one panel across **`LOCALES` × days 2..`GameRules.MAX_DAY`** with three shipment rows, two withered crops and a long save error; after each settle, run `_assert_controls_inside` and check the Acknowledge remains clickable/inside its footer. Assert `summary_state()["diary_line"] == ContentRules.diary_line(day)` (the English source key stored on the Label); check actual locale translations through the existing `test_localisation.gd` assertions and the UI layout/locale tests. Do not make `summary_state()` vary by locale. Keep the existing Day 14 coverage. No fourth notification card, new scroll container or duplicate-node test.
3. **Result / `test_vn_surfaces.gd` around line 1767:** Add one named wrapping `TierLine` under the header title and assign `String(result["epilogue"])` directly (Control auto-translation). Add `"tier_line"` to `result_state()`. Reuse the existing result fixtures, which already call `ContentRules.build_harvest_result()`, and assert correct epilogues across all three tiers. Extend `test_result_warning_label_is_20px_and_stays_clear_of_actions` with a **Cards vs SavePill and Cards vs Actions** no-overlap assertion in the existing locale × window-size loops. Keep existing scores, villager quotes and button actions unchanged.
4. **Continue / `test_app_launch.gd` around lines 214 and 257:** Add one rendered `summary_state()["diary_line"]` assertion to `test_continue_restores_one_dry_night_and_wither_summary`, after the loaded world has shown its pending summary. Add one `result_state()["tier_line"]` assertion in `test_continue_with_completed_finale_shows_result_screen`. Reuse these real save roundtrips; do **not** add a "no diary/story keys" save test (strict state validator already rejects unexpected shape), a "no duplicate nodes on re-present" test (present only assigns labels), or a new finale/scoring gate (existing tests cover it).
5. **Layout:** The 1920×1080 canvas scales proportionally at 960×540. Run automated clipping/containment checks on the native canvas over all three locales and all morning days, with worst-case shipment/error content. Keep a lightweight smaller-window **legibility** spot check rather than duplicating the full clipping matrix; existing result warnbar test can retain both window sizes. Ensure the result subtitle does not push villager cards into the save pill or action buttons. Visually inspect one native 1080p sample per locale.
6. **Docs:** Update `README.md` to describe the lottery/Kenji/daily diary, and `CLAUDE.md` to document `ContentRules` as owner of diary and result tier copy. Do not modify any game rules, maps, timing, social mechanics or save schema.

**Checkpoint:** **Commit** the UI wiring, updated existing tests, and docs on this same PR; then run `./tools/verify-clean.sh` against that committed HEAD.

## Four final release gates — run on implemented, committed HEAD

```bash
# 1. Clean Godot import, GUT unit/integration, headless smokes, audio
./tools/verify-clean.sh

# 2. GdUnit4
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c

# 3. godot-e2e
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c

# 4. Headless import, unsigned macOS export + ZIP integrity
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Record final HEAD SHA, actual pass counts, and any limits of manual native visual verification in PR #39. This document is planning-only: **the above gates have not been run on an implementation**.

## Non-goals and done criteria

- No branching diary, choice system, dialogue grammar, cutscene, extra UI framework, new JSON format, map or town change, character customization, tier-scoring change, state migration or compatibility shim.
- No new images, portraits, SFX, BGM or voice; any future asset production belongs to a separate task and PR. HPA-546 player walking remains separate.
- One ticket → one PR: both commits and their tests stay in **PR #39**, not separate PRs.
- Done only when every day has its authored localized diary, the opening uses Kenji's lottery premise, each existing finale tier displays its epilogue, the current game/save contracts remain unchanged, the existing named test suites cover the changes, all four release gates pass and native locale layouts are visually acceptable.
