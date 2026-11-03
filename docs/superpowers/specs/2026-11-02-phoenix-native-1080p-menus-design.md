# HPA-682 — Native 1080p menus and panels: design specification

**Status:** Proposed for review (planning-only draft, 2026-11-02)  
**Linear:** https://linear.app/cwchanap/issue/HPA-682/restyle-phoenix-menus-and-panels-for-1080p  
**Visual reference:** https://claude.ai/artifact/1DdvEPpVjfLwCGqSpCH2VV  
**Design direction:** https://claude.ai/artifact/91H3GuS9EcHmpb4NHqB5cF  
**Dependencies:** HPA-680 and HPA-681 are complete; HPA-713 localization is already on main.

## Goal and success criteria

Complete the City Pop 1080p UI migration by replacing the old 640×360 layouts for every non-HUD screen. The screens must feel like one game, remain readable in English, Traditional Chinese (Taiwan wording) and Japanese, and behave exactly as they did before the restyle.

Success means native 1920×1080-authored Control layouts, no 3×-scaled legacy panels, the UI reference's 14 states reviewed by eye, and behavior regression coverage passing. This issue is **one implementation PR**; this draft contributes only the spec and plan and is the **same PR** to implement later.

## Verified baseline on main

- `project.godot` already renders at 1920×1080 using `canvas_items` stretch; the world camera zoom of 3 is intentional and unchanged.
- `UiStyle` already supplies City Pop colors, M PLUS 1 with Noto JP/TC fallbacks, `card()`, `gradient_surface()`, `keycap()`, `pin()` and `SlantTag`. Do not create a second design-system abstraction.
- `GameHud._build_modals()` currently instantiates ten existing modal scenes and scales all of them with `UiStyle.fit_legacy_layout()`. Title and Result call that helper independently. `OnboardingOverlay` scales its opening card with `fit_legacy_control()`.
- `GameHud` owns the single-primary-modal gate, the Esc close order, input handling, modal signals, and presentation from snapshots. `WorldShell` remains the only production session owner.
- `assets/i18n/strings.csv` has columns `keys,zh_TW,ja`; English source text is the key. Existing Settings includes a **Language** row, despite the older HPA-682 mockup/ticket only listing four preferences.
- PR #29 removed the screenshot-golden workflow. GUT, GdUnit4, godot-e2e, headless smoke, and manual visual review are the supported checks.

## Design decisions

### 1. Build one small, shared phone frame; retain existing panel controllers

Add **one** reusable `PhoneFrame` presentation scene under `scenes/ui/` (with a small script only if required to expose header/body/footer setters). Its shell owns the translucent world dim, rounded phone surface, gradient app header with English title and Japanese subtitle, body mount, and single footer hint row. Use the same shell for Pause, Bag, Almanac, Calendar, Settings, Morning Summary (lock-screen treatment), and Sleep (alarm treatment).

Each existing panel script remains responsible for its current selection, rendering, signals, and keyboard handling. The shared frame is **not** a modal manager, navigation framework, data source, or reusable general component library. A small phone-shell variant for lock/alarm presentation is acceptable; copying independent phone frames into seven scenes is not.

Use Godot native anchors and Containers in each scene with real 1920×1080 coordinates. At the existing 960×540 minimum window, Godot scales the entire canvas uniformly. Do not introduce per-resolution branching, custom responsive layout calculations, new fonts, or art assets.

### 2. Preserve the single-modal and input contracts

Keep `GameHud.open_*()` / `close_*()` / `_open_modal()`, `_esc_close_order`, `has_blocking_modal()` and `modal_state_changed` semantics. Only one primary modal is visible; opening it blocks world input. Morning Summary and opening intro keep their special blocking behavior. Esc still closes the active modal and Settings still returns to Pause; Enter still acknowledges/sleeps/confirms as appropriate. Do not move input ownership to the phone frame.

Pause shows Bag (I), Almanac (B), Calendar (C) and Settings (O) tiles plus Controls. The tiles can emit presentation/navigation requests routed by `GameHud` through its existing `open_*` methods. The **existing keyboard gate remains unchanged**: I/B/C are direct-from-world shortcuts and do not start operating through an already-open Pause screen; O remains Pause-only. The tiles' key hints identify the existing shortcuts. This avoids adding a second modal input route while allowing mouse/tile navigation.

No changes to gameplay commands, snapshot shapes, save schema, clock, stamina, economy, social behavior, or UI preference persistence.

### 3. Screen inventory and presentation contract

| Surface | Native visual treatment | Preserve |
| --- | --- | --- |
| Pause / home | Shared phone, four app tiles, Controls widget, one footer | Existing Esc and O, plus optional tile clicks routed to existing open methods |
| Bag | Seed and harvest grids, selected-item detail card, shipment payout row | Selection and inventory values from the current snapshot |
| Almanac | One crop per page, large crop art, growth/seed/sale facts | A/D selection, `selected_kind()`, no changes to crop rules |
| Calendar | 7-column grid spanning Days 1–14 and Coming Up information | Existing calendar computations; only show weather already known by the session |
| Settings | Music/Sound slider visuals, 1080p/Full segment, Tips and **Language** controls | Five existing settings rows, values, persistence and A/D adjustments |
| Morning Summary | 06:00 phone lock screen, weather/farm/bank notifications, Saved/error status and Start Day action | Current summary fields, wither warning, shipments, save-status and acknowledgement |
| Sleep | Phone alarm face at 06:00, Day 14 boundary notice, Sleep/Not Yet footer | `sleep_requested`; Enter/Esc behavior |
| Shop / Shipping | Matching City Pop world cards with gradient header, quantity steppers, selected-row tint, precise action pill | Existing selection, M=max, buy/upgrade/deposit signal payloads and disabled-state rules |
| Dialogue | Visual-novel box, slanted name tag, role pill, relationship hearts, portrait left, inline gift chips | Line advance, gift counts, focus, close-friend sequence and signal payloads |
| Onboarding | Letterbox + Day 1 slanted label + visual-novel line | Opening acknowledgement and tutorial-card behavior |
| Title | Reuse current key art, dark left fade, selected gradient pill | New Game/Continue availability, keyboard selection and error message |
| Result | SEASON COMPLETE tag, stat cards, three current villager cards | Score/tier/content, completed-run Continue and New Game/title actions |

These are named surfaces, not a claim that the visual reference has exactly one state per surface. During review enumerate the actual **14 reference states**, including relevant selected/variant states, and compare every one. The mockup is the visual authority; this document is the runtime/ownership contract.

### 4. Handle story and art dependencies without scope creep

- HPA-684 owns Kenji's **14 diary lines** and opening/result rewrite. HPA-682 may reserve a location for a diary line in the lock-screen design, but must not invent text, add diary data to `ContentRules`, or require a new snapshot field. Until HPA-684 lands, display only existing morning-summary copy or omit the empty diary area.
- HPA-683/HPA-686 own farm emptiness, town travel, villagers' location and shop relocation. Use the current names, portraits and data as shipped on main; do not hardcode the mockup's story copy.
- Reuse current portraits, crop icons, title art and sprite textures. Any new art/SFX belongs to a separate ticket, not this PR.
- HPA-713 established three languages. Preserve Japanese and Traditional Chinese text wrap, dynamic formatting, and the current Language control. Every introduced English UI source string gets both translations in the CSV in this PR.

### 5. Keep styling local and predictable

Reuse `UiStyle` primitives and existing texture assets. Add only small shared style helpers when at least two panels need the exact same treatment (for example, a selected row or gradient primary pill). Keep panel-specific sizes and anchors in their scenes; avoid a JSON-driven screen registry, generalized UI schema, layout DSL, custom renderer, or UI state machine.

Keep the existing panel public methods and node names when inexpensive to do so, especially `GameHud`'s modal root names; update tests deliberately when a subtree changes. Preserve current controls' enabled/focus behavior when moving to the new hierarchy. Label/error/warning text must never be obscured by a clip/gradient container; the `UiStyle.gradient_surface()` helper itself warns against nested clipping.

## Alternatives considered

- **Multiply every old offset by 3 and recolor:** quickest initially, but retains fragile old dimensions and duplicates frame markup. Rejected: not actually native UI.
- **New phone/app/navigation framework:** highly reusable, but duplicates `GameHud` input ownership and slows this one-off migration. Rejected (YAGNI).
- **One shared phone scene + per-panel native content:** one consistent shell while preserving existing panel classes and behavior. **Chosen.**

## Acceptance and verification

1. All covered panels, intro, title and result are authored natively at 1920×1080; no production calls to `fit_legacy_layout` or `fit_legacy_control` remain, and unused legacy style helpers/constants are removed.
2. All named layouts follow the approved visual reference, use the existing City Pop kit, and display accurate current-game data.
3. New Game, Continue, full Day 1 intro, Bag/Almanac/Calendar, shop/ship, settings, morning save status, sleep/Day 14, dialogue/gifting, and finale navigation all retain their current command and input behavior.
4. No new gameplay state, schema version, rules, map, art, SFX, localization mechanism, or extra runtime is introduced.
5. GUT/headless smoke and the relevant GdUnit4/godot-e2e lanes pass after updating assertions tied to changed scene paths. All new English UI labels have zh_TW/ja translations.
6. Manual review: all 14 reference states at 1920×1080, plus representative dense text at 960×540, in English, Traditional Chinese and Japanese; check clipping, focus, contrast, key hints, unavailable actions and save errors. This is **not** a new golden-image gate.

## Review questions

- Does the reference require any Pause-key routing change, or is the existing I/B/C world-only keyboard gate plus clickable phone tiles acceptable?
- Is the optional diary area acceptable until HPA-684 supplies actual lines?
- Are any of the 14 reference variants materially different enough to require an explicit state-specific test?

These are visual/UX review points, not reasons to broaden the game architecture or split the ticket into multiple PRs.
