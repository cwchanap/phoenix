# HPA-684 — Quiet Field morning diary and narrative copy: design specification

**Status:** Proposed for review; docs-only draft. No implementation or verification is claimed.
**Linear:** https://linear.app/cwchanap/issue/HPA-684/add-the-players-morning-diary-and-rewrite-openingresult-copy-for-the
**Baseline:** Phoenix `main` after HPA-686 town/travel (PR #38). The farm is empty; Sato-san, Gen-san and Hana live in town; the existing native 1080p City Pop panels support EN, zh_TW and ja.
**Delivery:** One issue, one PR. Implement on this same PR after design review.

## Player experience

Kenji, a burned-out Tokyo software engineer, won the lottery and bought a neglected rural field. The opening now speaks in his voice, establishing the lottery premise and the Day 14 market. The opening also displays his **Day 1 diary**. After sleep, the already-blocking morning summary shows the **new day's diary** for Days 2–14. The result screen adds one short epilogue tied to its existing ending tier. The voice is cozy, dry and gently funny: a former software engineer notices the absurdities of farming without turning the game into a software joke generator.

This is an authored, deterministic 14-line sequence. It is **not** a simulation of actions completed. Lines must not claim a particular shop visit, crop harvest, weather event or friendship that the player might never have experienced.

## Existing seams and decisions

- `scripts/game/content_rules.gd` owns the existing static tutorial and result-content tables. Add `const DIARY_LINES: Array[String]` with exactly 14 nonempty English source strings and a small `diary_line(day: int) -> String` accessor (days 1 through 14, one-based). The English text is the translation key. No new save field, JSON asset, dialogue parser, story flags, randomizer or dynamic diary conditions.
- `scripts/ui/onboarding_overlay.gd::_build_opening()` already builds a blocking opening card with `Intro`, `Guide`, and a speaker tag currently (incorrectly) showing Sato-san/Seed-shop keeper. Replace that tag with **Kenji / Former software engineer**, rewrite Intro and Guide to establish the premise, and append a named `DiaryLine` in the existing content dock. Obtain the line from `ContentRules.diary_line(1)`. Preserve the Begin Day 1 action, blocking state, tutorial gating, texture and scene.
- `scripts/ui/morning_summary_panel.gd::present(summary)` already receives `next_day` from `GameSession`. Add one compact, wrapping `DiaryLine` under the daily information cards and above the flexible spacer/footer, or an equally space-safe position in that same PhoneFrame. It uses `tr(ContentRules.diary_line(next_day))`. Do not add a fourth notification card, hide financial/save information or modify the ack button. Morning summaries never exist for Day 1, and sleep on Day 14 ends the run instead of producing Day 15.
- `scripts/game/content_rules.gd::build_harvest_result()` already returns the immutable ending `tier`, title and scores. Keep the existing thresholds, tiers and titles unchanged; add three epilogue strings in `ContentRules.RESULT_TIER_LINES` keyed by existing tier identifiers. `scripts/ui/result_screen.gd::present(result)` displays the matching short `TierLine` beneath the title in the existing header. Do not mutate the result dictionary or the relationship cards merely to carry copy.
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
| 3 | The lottery bought the land. Learning what to do with it is on me. |
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

The result still displays shipped quantity/value, final money, all three villager cards, featured villager, save warning, New Game and Title. Do **not** rewrite the villager's existing relationship-driven finale quotes as part of this ticket.

## Localization and visual constraints

- All newly introduced player-facing English strings belong in `assets/i18n/strings.csv` with **both** `zh_TW` (Taiwan Traditional Chinese vocabulary) and `ja` translations in the same implementation commit. The CSV contract is `keys,zh_TW,ja`: English source text is the key, not a separate `en` column. Escape commas and quote marks correctly in CSV. Translation must preserve the diary's informal first-person voice; no machine-translation service or separate translation task.
- The name tag must localize properly (e.g., translate `Kenji` before uppercasing), and role/introduction/guide/diary/endings must be translated. Dynamic label assignments should use `tr()` like the other panels; no stale English text on opening, morning-summary or result screens when starting with zh_TW/ja.
- Use the existing 1920×1080 layout, assets, `UiStyle` typography and `PhoneFrame`. The phone is 560×920; the morning panel already has weather, farm, bank and save-status information. Keep the diary to a compact, wrapping note, not a large new card. Check text wrapping and important controls at **1920×1080** and the supported **960×540** window in all three locales. Protect morning save errors, shipment lines and the result action buttons from clipping.
- No new artwork, SFX, BGM, transitions, map changes or player customization. HPA-546 player walk animation remains a separate ticket.

## Acceptance criteria

1. New Game opening presents the lottery/Tokyo/field premise, a Kenji speaker tag and exactly the Day 1 diary; existing Begin action and input gating still work.
2. A genuine overnight advance from Day N to N+1 displays diary N+1 (2–14), not the previous day. Continue with a pending morning summary shows the same note; acknowledgment is unchanged.
3. The Day 14 ending and completed-run Continue show the correct short epilogue for each of the three **existing** result tiers. Scoring, shipping totals, thresholds, relationship cards and save format do not change.
4. GUT checks the exact 14-entry mapping, all three tier texts, and rendering hooks. Localisation tests cover every new key in zh_TW and ja, and language-specific visual checks catch clipping.
5. Implement in one PR, with established clean Godot test and export gates green before requesting merge. This initial draft contains planning documents only.
