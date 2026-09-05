# Phoenix UI Redesign and Visual Parity Design

Date: 2026-09-04
Status: Approved for implementation

## Goal

Rebuild Phoenix's player-facing UI to match the supplied `Phoenix UI (standalone).html` at full **UI** visual parity while preserving the farming, economy, social, persistence, authored world, and finale rules.

This remains one coherent implementation task and one PR. The mock is the human visual source of truth; `GameSession`, `GameRules`, `VillagerRules`, and `ContentRules` remain the behavioral source of truth.

The normative fixtures, visual-proof roles, comparison surfaces, semantic asset map, and known mock corrections live in:

`docs/superpowers/specs/2026-09-04-phoenix-ui-reference-contract.md`

## Source-of-truth rules

1. UI geometry, spacing, palette, borders, art placement, typography hierarchy, selected/disabled states, and panel composition come from the mock.
2. Gameplay numbers and policy stay in `GameRules`, `VillagerRules`, `ContentRules`, and `GameSession`.
3. New UI interactions reuse existing commands whenever possible.
4. Persist only genuinely unreconstructable run history.
5. No development-save migration/backward compatibility is required.
6. The authored farm world is not redesigned to imitate the mock's illustrative plates.
7. Browser screenshots are human design references, not strict machine goldens for the Godot renderer.

## Existing seams to reuse

Phoenix already has:

- 640x360 logical viewport, viewport stretch, aspect keep, integer scale, nearest filtering,
- the complete three-crop economy/action rules,
- farming/seed selection commands,
- seed buying and shipping quantity commands,
- day progression, weather rolls, shipment payout, stamina restoration, morning summary,
- villager talk/gift/relationship rules,
- intro/tutorial progression,
- Day-14 finale and result data,
- title/new/continue compatibility handling,
- `WorldShell` as the only mutable `GameSession` holder,
- `GameHud` as the gameplay UI orchestrator,
- existing private HUD/modal builders that can be extracted into focused scenes rather than replaced with a new framework.

## Presentation contract

### Logical resolution

Authored UI remains exactly 640x360:

- `window/size/viewport_width=640`,
- `window/size/viewport_height=360`,
- stretch mode `viewport`,
- aspect `keep`,
- integer scale,
- nearest texture filtering.

Production capture reads the real 640x360 root viewport after `RenderingServer.frame_post_draw`. Machine regression compares 640x360 captures directly. A copy is nearest-neighbor resized to 1280x720 only for side-by-side review against the 1280x720 mock reference.

Changing the logical viewport to make capture convenient is forbidden.

### Human design approval vs machine regression

Visual verification has two tiers:

1. **Human design parity.** The mock-derived 1280x720 references under `tests/visual/design-reference/` are compared by eye with 2x production captures. This is the authoritative decision that the implemented UI matches the design.
2. **Automated regression.** After a state is visually approved, the same Godot capture harness writes a 640x360 production golden under `tests/visual/goldens/`. CI compares future production captures to those goldens.

Browser-native 1280x720 renders are never used as a strict pixel oracle for nearest-upscaled Godot output. CI may not regenerate goldens.

### UI-vs-world boundary

The mock farm plate is illustrative. UI proof excludes live-world differences:

- HUD design review compares only the top 72 and bottom 132 pixels of the 1280x720 evidence frame.
- World-backed modal evidence renders the real production UI over test-only plates under `tests/visual/plates/`.
- Intro, Title, Result, Almanac, Calendar, and Settings compare their full UI-owned frame.
- production scenes never reference `tests/visual/**`.

### Deterministic typography

Bundle pinned open-licensed variable Open Sans and JetBrains Mono TrueType files from official upstream distributions, plus license text. `UiStyle` loads them as `FontFile`s / `FontVariation`s for the required weights.

Do not use `SystemFont` for parity-critical text and do not copy the mock's embedded webfont bytes.

### Shared visual language

Use the mock palette consistently:

- primary `#141A24`,
- header `#1D2634`,
- inset `#0E131B`,
- selection gold `#FFE673`,
- rainy blue `#617FB8`,
- warm cream `#FFF5DB`,
- success green `#7FBF5F`,
- warning red `#D4574E`.

All mock art is imported with semantic repository names. UUID filenames survive only in the reference-contract traceability map.

Do not add a Godot Theme resource or general UI framework. `UiStyle` helpers plus focused scenes are enough.

## UI composition

`GameHud` stays the `WorldShell` signal/orchestration boundary. Existing private panel builders are extracted into focused scene/script pairs:

- Shop,
- Shipping,
- Bag,
- Almanac,
- Calendar,
- Dialogue,
- Morning Summary,
- Sleep,
- Pause/Controls,
- Settings,
- Intro overlay.

Title and Result remain AppRoot-owned full-screen scenes.

No panel mutates `GameSession` directly. Command panels emit requests; read-only panels render snapshots/rules.

## Modal and Esc ownership

The current HUD has repeated hardcoded modal lists. With the redesign expanding the surface count, centralize that bookkeeping without creating a framework.

`GameHud` owns:

```gdscript
var _primary_modals: Array[Control]
var _esc_close_order: Array[Dictionary]
```

`_primary_modals` is the one list used by `_open_modal()`, `has_blocking_modal()`, and morning-summary exclusivity. `_open_modal(panel)` hides every other registered primary surface before showing `panel`.

`_esc_close_order` is an ordered list of `{control, close}` entries used by `GameHud._unhandled_input()`. Settings appears before Pause so Settings Esc returns to Pause. This is a small data table, not a modal/navigation framework.

Intro/Morning remain blocking Esc consumers. `DialoguePanel` keeps its current deliberate exception: while a required close-friend multi-line sequence remains, it consumes Esc without closing. Other panel scripts do not own general Esc.

## Input model

Keep WASD, `1`-`4`, Space, E.

Add:

- `I`: Bag,
- `B`: Almanac,
- `C`: Calendar,
- `M`: max/all in quantity panels,
- repeated `2`: while Seeds is already selected, cycle Turnip -> Potato -> Pumpkin -> Turnip,
- `O`: Settings only while Pause/Controls owns input.

Repeated `2` reuses `GameSession.select_seed()`.

Panel W/S/A/D/Enter/M/toggle handling is consumed before world movement. `WorldShell` continues to gate player control via `GameHud.has_blocking_modal()`.

## Domain helpers used by UI

Policy stays outside panels:

- `GameRules.earliest_ready_day(kind, growth, current_day) -> int`,
- `VillagerRules.favourite_villager_for_crop(kind) -> VillagerId`.

Calendar labels derived dates as **earliest ready**, not guaranteed `READY`, because real growth still depends on watering/rain.

## Screen requirements

### 1. HUD

Replace the current label stack with the mock top bar and bottom hotbar. Show day/time/weather, market countdown, money, bag/pending summary, 20 stamina pips, four action slots, selected seed/count, tutorial prompt, feedback, and Space/E context. Rain visually blocks Water without changing command semantics.

### 2. Seed Shop

Extract the existing shop behavior into a scene. W/S selects crop; A/D quantity; M legal max; Enter buys; GameHud owns Esc. Show money, price, owned count, quantity, live total.

### 3. Shipping Bin

Independent scene, no Shop/Shipping base class. W/S crop; A/D quantity; M all; Enter deposits; GameHud owns Esc. Show harvested count, value, and Day-14 warning.

### 4. Bag

Read-only Seeds / Harvested / Pending Shipment shelves. Detail derives growth/prices/favourite from rules. No new inventory model.

### 5. Almanac

Rules-only crop reference with growth nights, buy/sell/margin, seven-pip scale, favourite villager.

### 6. Calendar

Read-only 14-day view with past/current `weather_history`, today, market countdown, earliest-ready projections, and Day-14 Market. Never reveal future random weather.

The raw mock has two illustrative contradictions: future Day-4 rain while Day 3 is current, and a Day-9 Potato marker incompatible with Potato's five-night growth. The normalized design reference removes future rain and uses the valid Pumpkin Day-9 fixture from the reference contract.

### 7. Dialogue

Preserve talk/gift sequencing and close-friend lock. Render portrait, role, relationship/progress, dialogue, points feedback, crop gift cards/counts, favourite bonus, gifted-today state, keyboard selection.

### 8. Morning Summary

Keep `pending_morning_summary` as the only transition state. Render completed/next day, crops advanced, next weather, stamina, payout lines/income, money after shipping, save status. Enter acknowledges existing command.

### 9. Sleep

Restyle existing confirmation; preserve Day-14 terminal flow and finale-SFX lock.

### 10. Pause / Controls

Restyle existing pause help. List WASD, 1-4, Space, E, I/B/C, O, Esc. O opens Settings only here.

### 11. Settings

One `ConfigFile`-backed `UiSettings` outside farm state:

- Music 0-10,
- Sound 0-10,
- Window 1x/2x/3x/4x/fullscreen,
- Tutorial Cards on/off.

Tutorial Cards off suppresses presentation only. Esc returns to Pause. The visible save path is the product path `SaveRepository.DEFAULT_PATH`; test environment overrides must not leak into the label.

### 12. Intro

Keep once-per-run blocking state/copy. Use mock art/portrait/keycap composition. Enter acknowledges.

### 13. Title

Use mock background/logo/menu. W/S selects enabled items; Enter activates; disabled Continue is skipped and owns its incompatibility reason. AppRoot compatibility logic remains unchanged.

### 14. Result

Use full-screen completion presentation and three villager cards. Production data always comes from `ContentRules.build_harvest_result()`; ResultScreen does not rerank relationships.

Normalize the raw mock's impossible `9 crops / 415G` to the production-valid reference `4 Turnip + 3 Potato + 2 Pumpkin = 9 crops / 645G`, final money `505G`, June Close Friend/featured. The design reference changes only that impossible numeral. No capture-only result dictionary is used.

## Persistence

### Farm save

Add only ordered `weather_history` to `GameSession` state/snapshot/restore:

- length equals current day,
- all entries are valid weather keys,
- final entry equals current weather.

Bump `SaveFileCodec.SCHEMA_VERSION` to 2. Schema 1 is unsupported; no migration.

### User settings

Use `UiSettings` + `ConfigFile` in `user://`, with `PHOENIX_SETTINGS_PATH` available for test isolation. Preferences survive New Game and are outside farm validation.

## Testing and verification

### Existing gates

`./tools/verify-clean.sh` remains the canonical import + GUT + headless-smoke gate. Any node-path/input change affecting `tests/headless/world_shell_smoke.gd` updates it in the same task.

GdUnit4/godot-e2e remain additional gates.

### Behavior coverage

Cover:

- weather history + schema 2,
- repeated-2 cycling,
- I/B/C gating,
- Shop/Shipping keyboard flows,
- rule-owned earliest-ready/favourite lookup,
- Dialogue gifting/close-friend Esc,
- Morning acknowledgement,
- Pause -> Settings -> Pause,
- title disabled Continue,
- production AppRoot -> ContentRules -> ResultScreen.

### Visual proof cadence

The harness is not deferred until the end.

- Task 5 creates capture/compare support for `01-hud`, proves the 640x360 capture path, deterministic fonts, masks, raw-image loading, and cross-platform tolerance.
- After HUD is visually approved against the mock-derived reference, create its production golden.
- Each later UI task adds and visually approves the states it introduces, then adds their production goldens.
- Task 11 only aggregates the already-proven states into CI and final evidence.

### Machine golden rules

- goldens are 640x360 Godot production captures,
- raw PNGs are loaded with `Image.load_from_file(ProjectSettings.globalize_path(...))`,
- reference/golden/plate directories are `.gdignore`d,
- `--update-goldens` is explicit and unavailable to CI,
- thresholds are calibrated from state 01 across local macOS and Linux/Xvfb before being frozen,
- browser mock PNGs are never compared as strict pixel goldens.

## Risks and mitigations

### Renderer drift

Risk: macOS GL and Linux/Xvfb llvmpipe may differ slightly. Mitigation: state-01 report-only calibration before thresholds are frozen; hard ceilings prevent “solving” large drift by weakening the gate.

### Design/reference drift

Risk: production-generated regression goldens could bless a bad redesign. Mitigation: a golden is updated only after the corresponding production capture has been manually approved side-by-side against the mock-derived design reference. PR evidence shows that comparison.

### Modal-registration drift

Risk: adding surfaces to several separate hardcoded lists. Mitigation: one `_primary_modals` registry and one ordered Esc table introduced before the new surfaces register.

### Fixture drift

Risk: screenshots fail because fixture values are reverse-engineered late. Mitigation: the reference contract freezes every visible value before panel implementation.

### Large single PR

Risk: the cohesive redesign is a large diff. Mitigation: keep one PR as requested, but preserve task-level commits/review checkpoints. Do not split behavior/UI/gate into separate PRs because the accepted workflow is one ticket/task -> one PR and final visual acceptance spans the whole slice.

## Explicit non-goals

- No world-art rewrite.
- No new crops/villagers/economy/relationship/season rules.
- No controller redesign.
- No mouse-first alternate flow requirement.
- No responsive redesign beyond fixed 640x360 + integer scale.
- No Theme resource, modal framework, navigation framework, component library, DI, settings-repository interface, or Shop/Shipping base class.
- No save migration.
- No second session holder.
- No split into multiple implementation PRs.

## Final acceptance

Complete only when:

1. All 14 normalized mock-derived design states have deterministic production counterparts.
2. Each state has been manually approved side-by-side against its mock-derived reference.
3. Each approved state has a production-generated regression golden and passes the automated gate.
4. The authored world remains functionally unchanged.
5. Every UI mechanism is functional, not screenshot-only.
6. Calendar never leaks future weather and uses rule-owned earliest-ready policy.
7. Existing gameplay changes only by the explicit input/settings/history additions.
8. `./tools/verify-clean.sh`, GdUnit4, godot-e2e, and visual regression verification pass.
9. PR #13 contains design side-by-side evidence for all 14 states before leaving draft.