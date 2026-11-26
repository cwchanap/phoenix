# HPA-844 — Phone app and card polish

**Status:** Proposed; planning only.  
**Linear:** [HPA-844](https://linear.app/cwchanap/issue/HPA-844/phone-app-and-card-polish) (Todo, no dependencies).  
**Reviewed main:** `aec429d6c2d9c0bdac8c0ef05d4f37b475fad182` (HPA-863 merged).  
**Implementation:** [Single-PR plan](../plans/2026-11-25-phoenix-phone-app-card-polish-implementation.md).

## Goal and visual authority

Finish the eleven UAT corrections in the existing native 1920×1080 City Pop UI. English, Traditional Chinese (Taiwan), and Japanese should remain equally usable. The HPA-844 attachments **Mockup C1: phone apps after polish** (mock-c1.jpg; HTML board #c1 in phoenix-uat-fix-mockups.zip) and **Mockup (left) vs game (right): title, shop, Bag, Calendar** are the visual authorities; both image attachments were inspected for this design. Use their marked portions, not the obsolete farm backdrop, mock fixture values, or unrelated elements. The current HPA-863 map and HPA-1137 prologue stay intact.

Where references conflict, the explicit HPA-844 text wins: Calendar, not Season; Start day 2 rather than the uppercase button still present in C1; day number above icon (the original redesign, not C1's still-inline weather); Seed shop, not the original mock's different shop name. Empty bin text is specified by the ticket even though the left comparison has a populated bin. Keep all unaffected colors, type sizes, frame geometry, navigation, controls and gameplay data. No new image/audio generation, new themes, navigation framework, gameplay system, save changes, or prologue animation (HPA-1250).

## Player-facing contract and ownership

| # | Requirement | Existing owner / design |
| --- | --- | --- |
| 1 | Tab dismisses a visible contextual tip, same as its click target | InputMap + OnboardingOverlay + GameHud presentation; see below |
| 2 | Japanese header kicker only in English | PhoneFrame.set_app_header and translation-change notification |
| 3 | Calendar app title matches Pause/key hint | CalendarPanel uses existing Calendar translation key |
| 4 | Selected Window and Language choices fill their segments | SettingsPanel._seg; reuse the existing hit button and gradient |
| 5 | No developer save path in Settings | SettingsPanel removes SavePath, retains settings-write error status |
| 6 | One success message, Progress saved | MorningSummaryPanel success presentation only; retain idle/error states |
| 7 | Diary sits on its own card | MorningSummaryPanel existing ContentRules diary copy |
| 8 | Calendar legend wraps in distinct chips | CalendarPanel HFlowContainer using UiStyle cards and existing icons/colors |
| 9 | Action/title text sentence case | TitleScreen, ResultScreen, MorningSummaryPanel, DialoguePanel, ShopPanel, ShippingPanel; English CSV keys |
| 10 | Empty shipping shelf says The bin is empty | BagPanel derives visibility from pending_shipment count |
| 11 | Day number centered above weather/event markers | CalendarPanel._day_cell, preserve day_state and marker semantics |

### Tip input and modal policy

Current main hides TutorialCard in both GameHud._open_modal and _reconcile_modal_presentation. Existing integration tests explicitly require that Settings/shop hide it; the ticket also requires dismissing a visible tip in a panel. Make the narrow product decision to allow the notification over the **ordinary centered phone menus** (Pause, Settings, Bag, Almanac, Calendar) as well as the unblocked world, not over full-screen/transactional story, travel, dialogue, shop, shipping, sleep, market confirmation, or morning summary. Dialogue deliberately uses Tab to cycle gift focus. These masked surfaces must retain normal Tab/focus behavior; do not silently dismiss a hidden prompt. This intentionally supersedes the old Settings mask expectation only; shop and other blocking-mask regressions remain. If a panel's bounds collide with the tip at supported sizes, adjust the notification layout locally without moving the phone or overlaying a control.

- Register a named `dismiss_tutorial` action bound to unmodified Tab in project.godot. Use action checks, not a raw keycode in production. Handle the initial press in OnboardingOverlay._input before GUI focus traversal; only when TutorialCard is actually visible in tree, tutorial preference enabled, intro not visible, current prompt nonempty. Reject echo and modifiers; consume the matched event before dismissal. With no visible tip, do not consume Tab or change focus/progress. Existing Enter/Space/Esc prologue handler stays unchanged.
- Use one shared dismissal method for button and action, keyed by _current_prompt_id. Preserve transient _dismissed and existing ContentRules.next_tutorial_prompt behavior; never write tutorial completion to GameSession or persistent preferences. A held Tab cannot dismiss subsequent tips. No duplicate or resurrected dismissed prompt after snapshot/locale refresh or modal close.
- Keep GameHud the modal/presentation owner and OnboardingOverlay the prompt renderer. Replace the two direct TutorialCard.visible writes with one overlay suppression setter/refresh (combined with settings, intro and prompt gates). Compute suppression centrally from the registered visible panel(s), not separate state in each app. Reconcile after open/close/render/settings change and before emitting modal transition. Preserve _set_hud_chrome_visible, exclusivity and has_blocking_modal independently of tip visibility. The tip never blocks world input itself. Because the overlay is created before modal panels, arrange only the card's paint and pointer hit order above the allowed phone menus (e.g. ordering a mouse-ignoring overlay after ordinary panels while preserving protected-overlay layering; verify actual hit routing, not z_index alone). Retain toast priority; do not introduce a second input or navigation service.
- A mouse click on the visible dismiss row must still work over menus; clicks elsewhere on the notification are nonblocking. Tab does not open/close the menu, change settings, advance the clock, trigger world actions, or dismiss the prologue. Turning Tips off hides it; turning on recomputes the current eligible prompt.

### Phone frame and Settings

Use PhoneFrame._title_key and existing NOTIFICATION_TRANSLATION_CHANGED callback to update both title and JpSubtitle visibility. At first set_app_header, show the nonempty, deliberately untranslated JP string only when the applied language is English (normalize locale language code if necessary); zh_TW and ja hide the node so its space collapses. Header accessory, gradient, status row and unheaded morning wallpaper unchanged. Live language change and reopening panels must work; do not rebuild all frames.

Settings already constructs both segments through _seg and UiStyle.hit_button. Keep the fix local. Inspect actual Control rectangles after layout: equally distributed segment widths within each group (honor the longest localized/native option minimum), same height, fill the selected cell's inner bounds with the rounded pink/orange gradient, and center its label horizontally and vertically; the whole segment is the clickable target. Respect the existing gaps/track and phone width; no fixed English text widths or clipped JP/TC. Maintain current pointer-release cancellation, row focus ring, keyboard W/S A/D, slider and toggle behavior. Remove the SavePath node, _save_path field, save_path_text test seam and formatted path; preserve the independent _status label and error reporting. Do not remove SaveRepository or settings persistence.

### Morning summary

Use the C1 diary card visual: warm/cream backed rounded card, small diary label/icon using existing UiStyle tokens/icons (reuse an appropriate existing icon, no art), then readable wrapped diary text in ink, not white shadowed wallpaper text. Label it with the correct diary day per existing ContentRules.diary_line(next_day) (Day 2 on first morning; C1's fixture label is not authority for date). If adding a heading, use a localized format such as Diary · Day %d, not a second diary table. The existing summary's weather, crop growth, bank and balance remain authoritative.

For saved state, show a single centered success line with existing save icon and green Progress saved text on the white card; no separate SAVED label/body, scroll region, or scroll hint in this state. For error retain SAVE ERROR badge, full original message, backed legible scroll region and W/S more hint when needed; for idle hide the card. Explicitly reset visibility, scroll offset and status styles when moving among states; do not leave success text or stale scroll space on an error or later summary. Keep existing error seams truthful (save_status_text returns the actual presented message; success can read the sole visible caption). Use Start day %d as the primary caption. The new diary card must coexist with the longest diary/three-shipment/long-save-error layouts in all locales at 1920×1080 and 960×540; preserve footer and confirm input. Do not alter save writes, failure behavior, or the morning acknowledgment gate.

### Calendar

Use the existing Calendar translation, keep the Japanese kicker only in English. Replace the compound legend with four individual wrapping pill chips: Today (pink), Market (gold), Last night (moon), Earliest harvest (green/crop cue). Use actual translated Labels in an HFlowContainer and existing UiStyle rounded cards; no clipped single line or manual locale string splitting. Move the conditional Earliest days need nightly watering. into its own wrapping note, visible only when readiness exists; keep the actual weather-history caption separate. Preserve Coming Up scroll and its sizing recalculation.

For each of the 14 day cells keep the number horizontally centered in a fixed top row; weather below it, followed by existing market/moon and readiness markers. A single weather or event icon is centered; when weather + event + up to three crop kinds coexist, keep distinct legible rows (weather/event can share a centered strip beneath the number if widths permit, but not beside the number). Preserve 7×2 grid, gradient today, dimmed past, gold market, last-night marker, all multi-crop icons and factual weather history (no invented future weather). Rebalance cell vertical spacing, not font shrink or marker deletion, to fit the phone; test the worst case at Day 14 and both window sizes.

### Copy and localization

Use source sentence-case keys, not runtime case transformation of translated text. Explicit English wording: New game, Continue, Seed shop, Shipping bin, Start day %d, Close, Title, Give %s. Keep proper crop names (do not uppercase localized crop names) and existing dynamic purchase/shipping captions. Existing Continue/Close/Calendar keys are reused where semantics fit; the title Continue now uses the shared neutral Continue translation (check it is natural in Japanese; no duplicate identical English key). Add Title/New game/Seed shop/Shipping bin/Start day %d/Give %s/Progress saved/The bin is empty and chip/diary labels if missing, with zh_TW and ja and identical placeholders. Keep other callers of uppercase source keys intact; audit all usages before removing obsolete keys. Keep small uppercase labels SEEDS, TOTAL, TIP, MARKET, etc., and relationship/metadata labels that aren't actions. No blanket casing change in UiStyle or localization engine; don't rename the shop to a new proper noun. Avoid unrelated copy changes and keep title default/disabled Continue and dialogue action dispatch identical.

### Bag

Inside _shelf_card(2) create one plain localized empty line, controlled in _update_view from total pending crop count (same source as _bin_payout visibility). Empty: show one line and no crop slots or payout, no reserved empty grid strip. Loaded: hide the empty line; preserve visible positive-count slots, payout, crop-selection and detail behavior. Keyboard and pointer shelf traversal still work; no inventory mutation in view.

## Acceptance boundary

Complete all eleven fixes in a single PR with the linked plan's automated and **MCP-driven end-to-end acceptance**. Compare running-game captures to HPA-844 C1 and the left side of the original redesign comparison; include matching surfaces and locales, and actual key-path evidence. The repository has no screenshot-golden CI gate: the agent performs the visual parity check and records results/capture references, not a human sign-off. Save evidence as local ignored test_output artifacts or existing CI artifacts, not committed generated images. No additional platform-specific validation; one native Godot desktop run at supported viewport sizes is sufficient for this UI-only change. No claim that the plan itself has verified the runtime.
