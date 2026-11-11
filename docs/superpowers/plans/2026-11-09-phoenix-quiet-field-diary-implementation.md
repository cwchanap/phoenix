# HPA-684 — Quiet Field diary/copy: single-PR implementation and verification plan

**Status:** Implemented on this PR — content, localization, UI wiring, and test verification complete.
**Linear:** https://linear.app/cwchanap/issue/HPA-684/add-the-players-morning-diary-and-rewrite-openingresult-copy-for-the
**Companion design:** [2026-11-09-phoenix-quiet-field-diary-design.md](../specs/2026-11-09-phoenix-quiet-field-diary-design.md)
**Delivery:** One HPA-684 issue → one PR. Implement in **this same PR** after the design is reviewed. No separate implementation PR.

## Ground-truth baseline (after HPA-686)

- `ContentRules.build_harvest_result(state)` currently determines the existing `tier` and `title` together. `AppRoot._show_result()` builds this presentation dictionary afresh from persisted state; it is not part of the save schema.
- `OnboardingOverlay._build_opening()` builds the Intro, Guide, NameTag, Role and Accept controls; it still uses Sato-san's name/role and old copy. `tests/integration/test_vn_surfaces.gd::test_intro_vn_box_keeps_authored_name_role_and_copy` (around line 390) explicitly pins `SATO-SAN` and the old Intro, so updating this test is mandatory.
- `MorningSummaryPanel.present(summary)` gets the persisted and validated `next_day`; `GameHud.render(snapshot)` displays the panel only while `pending_morning_summary` exists. `summary_state()` exposes rendered labels. The 560×920 `PhoneFrame` already has weather, farm, bank, save error and acknowledgment. `GameRules.MAX_DAY` is the source of the season length (currently 14).
- `ResultScreen.present(result)` already receives the result dictionary and renders title, scores, villager cards, warning and actions. Its `_header()` has a title and kicker.
- `assets/i18n/strings.csv` uses `keys,zh_TW,ja`, with English text as the key. Plain text assigned to a Godot Label auto-translates, including `SlantTag`'s internal Label. **Use literal key `KENJI`** (rather than pre-translating and uppercasing `Kenji` at construction): this lets an existing speaker tag refresh after locale changes. Remove the three obsolete opening CSV rows (including `SATO-SAN`) when adding new ones. Reserve explicit `tr()` for genuinely formatted/transformed text.
- `tools/verify-clean.sh` runs `git archive HEAD` and downloads GUT into a temporary archive; **it never tests uncommitted worktree changes**. Commit each checkpoint first, then run it. GdUnit4 and e2e are separate release gates.

## Commit 1 — Content and localization (no UI wiring yet)

**Files:** `scripts/game/content_rules.gd`, `assets/i18n/strings.csv`, `tests/unit/test_content_rules.gd`, `tests/unit/test_localisation.gd`.

1. Add `const DIARY_LINES: Array[String]` with the 14 approved English source strings from the design. Add `static func diary_line(day: int) -> String` with a one-based lookup and `assert(day >= 1 and day <= GameRules.MAX_DAY)`. Pin `DIARY_LINES.size() == GameRules.MAX_DAY` in GUT rather than scattering literal 14 checks. No conditionals, storytelling state, JSON or new save keys.
2. Centralize ending title and epilogue in `const RESULT_TIERS := {&"new_beginning": {"title": "New Beginning", "epilogue": ...}, &"promising_farmer": {...}, &"heart_of_harvest": {...}}`. Keep the three existing tier keys and the existing score/relationship **threshold conditionals** in `build_harvest_result()`. After choosing the tier, read both title and epilogue from `RESULT_TIERS[tier]` and return `"epilogue"` alongside `"title"`. The result dictionary is transient/presentation-only; do **not** add either field to saved game state. Avoid a parallel table or duplicate lookup in the view.
3. In `assets/i18n/strings.csv`, **replace** the three obsolete opening entries near lines 229–231 (the old `This farm has been quiet…` Intro, `SATO-SAN` tag and old `The village harvest market…` Guide). Add the new Intro and Guide, literal uppercase **`KENJI`** key (with natural Traditional Chinese and Japanese translations; no duplicate `Kenji` key), `Former software engineer` role, 14 diary lines and 3 epilogues. Keep CSV escaping correct and every locale translation nonempty. The revised Day 3 diary sentence differs from the New Beginning epilogue so the ending does not repeat the day note.
4. Extend `test_content_rules.gd` with `DIARY_LINES.size() == GameRules.MAX_DAY`, nonempty entries for every valid day, first/last-day mapping, and exact coverage/contents of the three `RESULT_TIERS` keys. **Reuse** existing `test_harvest_result_tier_boundaries` and totals tests (around lines 290–316) rather than duplicating scoring assertions.
5. In `test_localisation.gd::_rules_strings()` iterate `ContentRules.DIARY_LINES` and each `RESULT_TIERS` entry's `title` and `epilogue`, replacing the hard-coded ending-title list. Explicitly include the two new opening paragraphs, `KENJI` and `Former software engineer`, which the rules-string scan otherwise misses. Assert both locales resolve `KENJI` and the role; the existing CSV duplicate/missing/placeholder tests still apply.
6. **Commit** content+CSV+tests together. Then run `./tools/verify-clean.sh` against that committed HEAD. No worktree-only GUT run disguised as a clean verification.

**Checkpoint:** The content has a single source, the localization is complete and the existing scoring behavior remains covered.

## Commit 2 — Wire existing surfaces and update the tests they own

**Files:** `scripts/ui/onboarding_overlay.gd`, `scripts/ui/morning_summary_panel.gd`, `scripts/ui/result_screen.gd`, plus existing `tests/integration/test_vn_surfaces.gd`, `test_phone_surfaces.gd`, `test_app_launch.gd` and localized README/CLAUDE.md updates. Implement the following surface/test pairs together before committing; never leave a known old-copy assertion red.

1. **Opening / `test_vn_surfaces.gd` around line 390:** Replace old Intro and Guide with the approved lottery/Tokyo/Day 14 copy. Pass the literal **`"KENJI"`** key to `SlantTag.new(...)` for `NameTag` and the plain `"Former software engineer"` key to `Role`; both existing Labels auto-translate. **Do not** use `tr("Kenji").to_upper()` or add a second name constant/key: pre-translating at construction can leave a stale name if locale changes. Add one named, wrapping `DiaryLine` from `ContentRules.diary_line(1)` below Guide, without altering Intro, Guide, NameTag, Role, Accept node names. Update `test_intro_vn_box_keeps_authored_name_role_and_copy` to expect the `KENJI` source key, localized role, opening copy and Day 1 diary. Keep the existing blocking/Begin behavior regression; don't create a second opening test suite.
2. **Morning / `test_phone_surfaces.gd` around lines 979 and 1097:** Add a **bare wrapping Label** named `DiaryLine` directly to `MorningSummaryPanel`'s main `Column` above its flexible `Spacer`, with **no padded card wrapper**. Use a legible **16px** text style such as `UiStyle.shadowed_label("", 16, 600)` over the dimmed wallpaper. The existing 560×920 `PhoneFrame` has only about **35–45px spare** in the worst-case fixture (3 shipment rows + 2 withered crops + long save error); keep EN/zh_TW/ja diary strings to **1–2 lines at ~490px width**. `present(summary)` assigns `ContentRules.diary_line(int(summary["next_day"]))` directly; **do not** wrap plain Label values in `tr()`. Add `"diary_line": _diary_line.text` to `summary_state()`. Extend `test_morning_full_content_long_error_keeps_acknowledge_reachable` to re-present one panel across **`LOCALES` × days 2..`GameRules.MAX_DAY`** with the worst-case content; after each settle, run `_assert_controls_inside` and check Acknowledge stays reachable. Assert `summary_state()["diary_line"] == ContentRules.diary_line(day)` (the stable English source key); check actual translations through existing localization checks. **If** the 2-line CJK wrap causes a few pixels' overflow, first reduce `Column` separation from 8px to 6px, or `LockTime` font from 90px to 84px; use test evidence to choose, never hide shipment/save information. Keep the existing Day 14 coverage, no fourth card or new scrolling framework.
3. **Result / `test_vn_surfaces.gd` around line 1767:** Add one named wrapping `TierLine` under the header title and assign `String(result["epilogue"])` directly (Control auto-translation). Add `"tier_line"` to `result_state()`. Reuse the existing result fixtures, which already call `ContentRules.build_harvest_result()`, and assert correct epilogues across all three tiers. Extend `test_result_warning_label_is_20px_and_stays_clear_of_actions` with a **Cards vs SavePill and Cards vs Actions** no-overlap assertion in the existing locale × window-size loops. Keep existing scores, villager quotes and button actions unchanged.
4. **Continue / `test_app_launch.gd` around lines 214 and 257:** Add one rendered `summary_state()["diary_line"]` assertion to `test_continue_restores_one_dry_night_and_wither_summary`, after the loaded world has shown its pending summary. Add one `result_state()["tier_line"]` assertion in `test_continue_with_completed_finale_shows_result_screen`. Reuse these real save roundtrips; do **not** add a "no diary/story keys" save test (strict state validator already rejects unexpected shape), a "no duplicate nodes on re-present" test (present only assigns labels), or a new finale/scoring gate (existing tests cover it).
5. **Layout:** The 1920×1080 canvas scales proportionally at 960×540. Run automated clipping/containment checks on the native canvas for EN/zh_TW/ja × Days 2–`MAX_DAY`, with worst-case shipments/withered/error and an unboxed diary line; trim only the small existing spacing or clock font if measured overflow requires it. Keep a lightweight smaller-window **legibility** spot check rather than duplicating the clipping matrix; existing result warnbar test can retain both window sizes. Ensure the result subtitle does not push villager cards into the save pill or action buttons. Visually inspect one native 1080p sample per locale.
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
