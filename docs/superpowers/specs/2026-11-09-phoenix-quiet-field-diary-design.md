# HPA-684 — Quiet Field morning diary and narrative copy: design specification

**Status:** Proposed for review; docs-only draft. No implementation or verification is claimed.
**Linear:** https://linear.app/cwchanap/issue/HPA-684/add-the-players-morning-diary-and-rewrite-openingresult-copy-for-the
**Baseline:** Phoenix `main` after HPA-686 town/travel (PR #38). The farm is empty; Sato-san, Gen-san and Hana live in town; the existing native 1080p City Pop panels support EN, zh_TW and ja.
**Delivery:** One issue, one PR. Implement on this same PR after design review.

## Player experience

Kenji, a burned-out Tokyo software engineer, won the lottery and bought a neglected rural field. The opening now speaks in his voice, establishing the lottery premise and the Day 14 market. The opening also displays his **Day 1 diary**. After sleep, the already-blocking morning summary shows the **new day's diary** for Days 2–14. The result screen adds one short epilogue tied to its existing ending tier. The voice is cozy, dry and gently funny: a former software engineer notices the absurdities of farming without turning the game into a software joke generator.

This is an authored, deterministic 14-line sequence. It is **not** a simulation of actions completed. Lines must not claim a particular shop visit, crop harvest, weather event or friendship that the player might never have experienced.

## Existing seams and decisions

- `scripts/game/content_rules.gd` owns the existing static tutorial and result-content tables. Add `const DIARY_LINES: Array[String]` with exactly one nonempty English source line per season day and a small `diary_line(day: int) -> String` accessor (one-based). Assert `DIARY_LINES.size() == GameRules.MAX_DAY`; the accessor requires `1 <= day <= GameRules.MAX_DAY`. The MVP currently has 14 days. The English text is the translation key. No new save field, JSON asset, dialogue parser, story flags, randomizer or dynamic diary conditions.
- `scripts/ui/onboarding_overlay.gd::_build_opening()` already builds a blocking opening card with `Intro`, `Guide`, and a speaker tag currently (incorrectly) showing Sato-san/Seed-shop keeper. Replace that tag with **Kenji / Former software engineer**, rewrite Intro and Guide to establish the premise, and append a named `DiaryLine` in the existing content dock. Obtain the line from `ContentRules.diary_line(1)`. Preserve the Begin Day 1 action, blocking state, tutorial gating, texture and scene.
- `scripts/ui/morning_summary_panel.gd::present(summary)` already receives `next_day` from `GameSession`. Add one compact, wrapping `DiaryLine` under the daily information cards and above the flexible spacer/footer, or an equally space-safe position in that same PhoneFrame. It assigns `ContentRules.diary_line(next_day)` as the Label's English key and relies on Godot Control auto-translation (no explicit `tr()` for plain Label text). Use at least 16px native type. Do not add a fourth notification card, hide financial/save information or modify the ack button. Morning summaries never exist for Day 1, and sleep on Day 14 ends the run instead of producing Day 15.
- `scripts/game/content_rules.gd::build_harvest_result()` already determines the ending tier and returns its title and scores. Keep threshold selection unchanged; define a single `ContentRules.RESULT_TIERS` table keyed by the existing tier identifiers, with `{title, epilogue}` for each. After selecting the tier, `build_harvest_result()` reads both fields from that table and returns `epilogue` alongside `title`. `scripts/ui/result_screen.gd::present(result)` displays `result["epilogue"]` as a short `TierLine` below the title; this plain Label text is auto-translated. The result dictionary is presentation-only and is rebuilt from save state, so this does not affect persistence. Do not change relationship cards or villager quotes.
- `GameSession`, `SessionStateValidator`, `SaveRepository`, `WorldShell`, maps and game rules remain untouched. The morning panel is still shown exclusively for `pending_morning_summary`. Resume with a pending summary displays its saved `next_day` line; after acknowledgment the summary disappears normally. Resuming without a pending summary does not replay a diary.

## Proposed English copy — opening

**Speaker tag:** `Kenji`
**Speaker role:** `Former software engineer`

**Intro:**
> I won the lottery, left my software job in Tokyo, and bought a field that looks like it hasn't seen a hoe in years.

**Guide:**
> The harvest market opens on Day 14. I have two weeks to grow something—and maybe get to know the people in town.

Keep both paragraphs short and legible in the existing dock. The first-person diary goes immediately after the guide, visually distinguished as a personal note, not a tutorial objective. Reuse existing `UiStyle`/`SlantTag`; no new dedicated widget.

## Proposed English copy — one line per day

| Day | Diary line |
| --- | --- |
| 1 | No stand-up. No sprint. Just an enormous field and me. |
| 2 | The weeds don't use issue trackers. They still find every edge case. |
| 3 | The land was easy to buy. Figuring out how to care for it is another matter. |
| 4 | There's a road to town. I should probably remember how to talk to people. |
| 5 | The town has a seed shop. Predictable prices—imagine that. |
| 6 | I could stop by the café. Conversations don't need ticket numbers. |
| 7 | A week in. The silence is starting to sound less like a warning. |
| 8 | I can usually tell which patch needs care without a dashboard. |
| 9 | There is no perfect farming algorithm. The soil keeps proving it. |
| 10 | The truck can take me to town. It can also bring me home. |
| 11 | The place is still rough around the edges. So am I. |
| 12 | The harvest market is close. The field gets the final review. |
| 13 | I used to count releases. Tomorrow I'll count what grew. |
| 14 | Whatever happens at the market, this is the first thing I chose for myself. |

The four broad story beats are Days 1–3 alone, Days 4–7 exploring the possibility of town, Days 8–11 settling in, and Days 12–14 facing the market. Day 5/6/10 lines are possibilities or observations, not assertions that a town trip occurred. Day 14 appears in the morning **before** the market or final sleep, not on the result.

## Proposed English copy — ending epilogues

Existing title and tier are kept for tests and balance. One new sentence sits below the existing title:

| Tier key | Existing title | New epilogue |
| --- | --- | --- |
| `new_beginning` | New Beginning | The lottery bought the land. Choosing to stay is a different kind of win. |
| `promising_farmer` | Promising Farmer | The books are finally in the green. For once, success needs no deployment. |
| `heart_of_harvest` | Heart of the Harvest | The field grew crops. The friendships made it feel like home. |

The result still displays shipped quantity/value, final money, all three villager cards, featured villager, save warning, New Game and Title. Read both title and epilogue through `RESULT_TIERS` in `build_harvest_result()` rather than adding a second tier lookup to the view. Do **not** rewrite the villager's existing relationship-driven finale quotes as part of this ticket.

## Localization and visual constraints

- All newly introduced player-facing English strings belong in `assets/i18n/strings.csv` with **both** `zh_TW` (Taiwan Traditional Chinese vocabulary) and `ja` translations in the same implementation commit. The CSV contract is `keys,zh_TW,ja`: English source text is the key, not a separate `en` column. Escape commas and quote marks correctly in CSV. Translation must preserve the diary's informal first-person voice; no machine-translation service or separate translation task.
- The name tag must localize properly (e.g., translate `Kenji` before uppercasing), and role/introduction/guide/diary/endings must be translated. Dynamic label assignments should use `tr()` like the other panels; no stale English text on opening, morning-summary or result screens when starting with zh_TW/ja.
- Use the existing 1920×1080 logical layout, assets, `UiStyle` typography and `PhoneFrame`. The phone is 560×920; the morning panel already has weather, farm, bank and save-status information. Keep the diary as a compact, wrapping note with **at least 16px native font**, not a large new card. Since `canvas_items` scales the same 1080p layout to 960×540, perform automated containment at native 1080p for all three locales and Days 2–`MAX_DAY`, and visually check smaller-window legibility rather than duplicating the clipping matrix. Protect morning save errors, shipment lines, result cards, warning bar and action buttons from overlap.
- No new artwork, SFX, BGM, transitions, map changes or player customization. HPA-546 player walk animation remains a separate ticket.

## Acceptance criteria

1. New Game opening presents the lottery/Tokyo/field premise, a Kenji speaker tag and exactly the Day 1 diary; existing Begin action and input gating still work.
2. A genuine overnight advance from Day N to N+1 displays diary N+1 (2–14), not the previous day. Continue with a pending morning summary shows the same note; acknowledgment is unchanged.
3. The Day 14 ending and completed-run Continue show the correct short epilogue for each of the three **existing** result tiers. Scoring, shipping totals, thresholds, relationship cards and save format do not change.
4. GUT asserts the diary table size equals `GameRules.MAX_DAY`, all lines are nonempty and the three tier definitions include titles and epilogues. Extend existing `test_vn_surfaces.gd` opening/result checks, `test_phone_surfaces.gd` morning containment checks (all three locales × Days 2–`MAX_DAY`, full shipments/long error), and `test_app_launch.gd` pending-summary/final-result Continue checks. Localisation tests cover every new key in zh_TW and ja. Keep existing tier-boundary and save-validator tests instead of duplicating them.
5. Commit each coherent implementation checkpoint **before** running `./tools/verify-clean.sh` because it archives `HEAD`. Run the established final Godot test and export gates before requesting merge; this draft remains planning-only. No new test files, framework or art/audio ticket are needed.
