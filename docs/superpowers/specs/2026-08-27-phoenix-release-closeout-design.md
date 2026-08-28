# Phoenix HPA-599 Release Closeout Design

**Linear:** HPA-599 — `[Release] Polish, balance, and verify the complete 14-day MVP`

**Scope:** One closeout PR. Planning and implementation stay on `agent/hpa-599-release-closeout-plan`; do not split HPA-599 into a second implementation PR.

## Context

HPA-597 completed the last gameplay/content slice. Phoenix now has one Godot-native 14-day loop, persistence, villagers/social progression, contextual onboarding, a Day 14 harvest finale, and terminal results. PR #11 added GdUnit4 and godot-e2e as focused parallel workflows beside the mature GUT/headless clean verifier.

HPA-599 is therefore a release closeout, not a new gameplay slice. It should make existing behavior readable, add a deliberately small presentation/audio pass, verify the frozen balance against an actual packaged run, produce the unsigned macOS build, and prove a normal New Game → Day 14 result path without developer instructions.

The existing owners are already sufficient:

- `GameRules`, `VillagerRules`, and `ContentRules` own closed rules/content.
- `GameSession` owns mutable gameplay and command validation.
- `WorldShell` is the only production session holder/coordinator.
- `PlayerController`, `FarmView`, and `GameHud` own presentation.
- `SaveFile`/`SaveRepository` own persistence.
- GUT is the broad rules/integration release oracle.
- GdUnit4 and godot-e2e remain focused parallel lanes.
- `export_presets.cfg` already owns the single macOS export preset.

## Decision

Use an **in-place closeout**. Extend the owners above and do not introduce a polish service, event bus, audio manager, settings subsystem, generic pause manager, renderer abstraction, second gameplay state layer, or new test framework migration.

### Alternatives rejected

1. **Generic feedback/polish subsystem.** Rejected because Phoenix has one gameplay shell and the current command-code/HUD seams already carry the required information.
2. **GdUnit-only release rules.** Rejected because `tools/verify-clean.sh` runs the mature GUT suite; release-critical session contracts must remain in that oracle.
3. **Verification-only closeout.** Rejected because the ticket explicitly owns remaining target/readability/audio/help gaps.
4. **Separate help scene.** Rejected because every current HUD modal is code-built through `GameHud._build_modals()`/`_add_panel()`; a one-off `pause_help.tscn` would create a second construction convention for a static panel.

## Release-candidate balance

Do not tune by instinct. The existing values are the release-candidate baseline:

| Rule | Release candidate |
| --- | ---: |
| Day | 06:00–22:00, 14 days |
| Stamina | 20/day |
| Starting money | 150G |
| Starting seeds | 3 Turnip, 0 Potato, 0 Pumpkin |
| Rain chance | 25% |
| Growth nights | Turnip 3 / Potato 5 / Pumpkin 7 |
| Seed prices | 20G / 40G / 70G |
| Sale values | 35G / 75G / 140G |
| Hoe | 30 min / 3 stamina |
| Plant | 20 min / 1 stamina |
| Water | 20 min / 2 stamina |
| Harvest | 20 min / 1 stamina |
| Talk | +1 once/day |
| Gift | +3; favourite +2 bonus |
| Friend / Close Friend | 12 / 18 points |
| Promising threshold | 150G shipped value, or Friend |
| Heart threshold | 300G shipped value + Close Friend |

These values are already pinned by the GUT rules/content/session tests. Change a value only when the release checks expose a concrete defect: a representative normal run cannot reach **Promising Farmer** (`shipped_value >= 150` without relying on friendship), a forced economy dead-end appears, or a specific value creates an observed usability/readability failure. Heart of the Harvest remains optional for the packaged acceptance run.

## 1. Farming preview, target color, hint text, and onboarding copy

### Shared read-only preview

Add:

```gdscript
GameSession.preview_selected_action(target_cell: Variant) -> GameRules.CommandCode
```

The preview must share the exact validation path used by `hoe`, `plant`, `water`, and `harvest`:

- active-day/finale/summary guards;
- target type and farm-cell membership;
- tile state;
- selected seed inventory;
- weather constraints;
- action time/stamina budget.

Factor the current guards into private read-only helpers and call those helpers from both preview and the mutating command. Preview never mutates state, time, stamina, farm tiles, inventory, tutorial progress, or relationship state. Do not implement preview by cloning a session and executing a command.

The release-critical preview contract belongs in `tests/unit/test_game_session.gd` beside the existing command guard/atomicity tests. Do not duplicate it in `tests/gdunit/test_game_session_flows.gd`.

### Green/red/gold target contract

`WorldShell._process()` previews only when the faced target is one of `WorldContract.farm_cells()`:

- **green:** preview returns the selected action's success code;
- **red:** target is a farm cell but preview returns any guard/failure code;
- **gold:** target is non-farm, preserving the current ordinary target/interactable cue for shop, bed, shipping bin, harvest market, and villagers.

`PlayerController` owns only the target colors/setter. It does not learn gameplay rules.

### Reuse the existing hint channel for “why”

Extract the current `GameHud.show_feedback()` text table into:

```gdscript
func feedback_text(code: GameRules.CommandCode) -> String
```

`show_feedback(code)` becomes a thin setter using `feedback_text(code)` so there is still one command-code → sentence table.

For farm targets:

- valid preview: interaction hint is `Space — use selected action`;
- invalid preview: interaction hint is `feedback_text(preview_code)`.

This preserves green/red as the fast “can I?” signal while also explaining red states such as untilled soil, no selected seeds, rain watering crops, mature crops, insufficient stamina, or late actions before Space is pressed. No new widget or feedback model is added.

### Fix the Day-1 tutorial in the same change

The current `farm_basics` tutorial says “gold outline,” which becomes false once valid farm targets turn green. Change that one body to the new contract, for example:

> Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.

Pin that exact player-facing body in `tests/unit/test_content_rules.gd`; the current non-empty-only assertion is insufficient for this release cue.

The current README does not need a gold-copy correction unless implementation introduces one. Keep gold documented only as the neutral/non-farm targeting state if the README is updated.

## 2. HUD help, Esc ownership, weather tint, shadows, and depth readability

### Code-built help panel

Add `_build_pause_help()` beside the existing `_build_shop_panel()`, `_build_shipping_panel()`, `_build_sleep_panel()`, and `_build_summary_panel()` methods. Build it with the existing `_add_panel`, `_add_label`, and `_add_button` helpers.

Required copy:

```text
Phoenix — Controls
WASD — Move
1 / 2 / 3 / 4 — Hoe / Seeds / Water / Hands
Space — Use selected action
E — Interact
Esc — Close / controls
```

`GameHud` stores the panel, includes it in `has_blocking_modal()`, connects Resume, and emits the existing `modal_state_changed` signal on visibility changes. Do not create `pause_help.tscn`. Do not pause the `SceneTree`; Phoenix's clock is command-driven and the existing modal input gate is enough.

### Esc ownership must preserve existing blocking flows

`GameHud._unhandled_input()` must use this order:

1. If the morning summary is visible, consume Esc and do nothing.
2. If `OnboardingOverlay.is_opening_visible()` is true, consume Esc and do nothing. Start remains the required opening action.
3. If shop, shipping, or sleep is visible, close that panel, consume Esc, and return.
4. If `DialoguePanel` is visible, **do not toggle help and do not directly close it**. Return without handling so `DialoguePanel._unhandled_input()` retains ownership of both normal close and the existing unskippable close-friend sequence.
5. If the help panel is visible, close it and consume Esc.
6. Otherwise open help and consume Esc.

This avoids stacking Help over the blocking intro and avoids bypassing `DialoguePanel`'s close-friend lock.

### Weather tint

Add one full-screen `ColorRect` under HUD content, owned by `GameHud`, and derive its color directly from the existing snapshot weather key. Use only subtle sunny/rainy tints. No shader, particles, post-processing, lighting system, or new weather state.

### Reused ground shadow

Add one small translucent `assets/sprites/proof-shadow.png` and reuse it under the player, tree, building, shipping bin, harvest market, three villagers, and dynamic crop roots where ground contact needs help.

Shadows are children of the existing entity roots and are never Y-sort roots. `Entities` remains the sole Y-sort owner. Crop shadow visibility follows crop visibility.

The current smoke test has exact child-name contracts such as `['Sprite2D']`; implementation must update those existing assertions to the new exact child list (for example `['Shadow', 'Sprite2D']`) instead of merely adding separate shadow assertions.

There is no authored fence entity in the current world. Do not add one for a checklist-only occlusion test.

### Sprite-isometric art contract

Record in `CLAUDE.md`:

- 64×32 ground diamonds;
- entity root = bottom-center ground contact;
- visible sprite offsets upward from that root;
- shadows stay as children on the ground plane;
- foreground/occluding entities stay under the existing Y-sorted `Entities` owner;
- nearest filtering and integer scaling remain mandatory.

## 3. Minimal audio

Use a tiny project-generated placeholder WAV set under `assets/audio/` and document its provenance in `assets/audio/README.md`. No external license dependency is required for the MVP placeholders.

Keep exactly two players on `GameHud`:

- `SfxPlayer` — short feedback clips;
- `MusicPlayer` — one quiet looping daytime track.

Reuse `show_feedback(code)`/`feedback_text(code)` as the command presentation seam and map representative command categories to SFX. Use the same players for confirm/cancel, save/day-transition, and finale cues where those transitions are not solely represented by a command code.

Minimum categories:

- farming action;
- commerce/shipping;
- dialogue/gift;
- confirm;
- cancel/error;
- sleep/wake/save transition;
- finale;
- one quiet music loop.

No audio manager, bus abstraction, settings page, volume controls, or persistent audio settings are planned. If the packaged run exposes a bad default mix, adjust asset/player levels directly.

## 4. Verification and unsigned macOS export

### Keep the current test lanes

Do not migrate GUT to GdUnit4.

- `tools/verify-clean.sh` stays the broad release oracle: clean archive, import, full GUT unit/integration suite, project/world smokes.
- `.github/workflows/unit-tests.yml` stays the focused GdUnit4 lane.
- `.github/workflows/e2e-tests.yml` stays the bounded godot-e2e lane.

Preview guard/no-mutation tests belong in GUT because the clean verifier runs them. The green/red/gold shell behavior belongs in `tests/integration/test_gameplay_shell.gd`. GdUnit4/godot-e2e gain HPA-599 coverage only if a new behavior is uniquely better exercised there; do not duplicate session-rule assertions.

Existing persistence integration coverage already proves a representative complete morning and Day 14 pre-finale save/result equivalence; extend it only if HPA-599 changes those seams.

### CI pin convention

When editing `.github/workflows/ci.yml`, adopt the pin/security convention already used by `unit-tests.yml`/`e2e-tests.yml`:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
  with:
    persist-credentials: false
- uses: chickensoft-games/setup-godot@f166999204a4f2722c6fe042fbaa3b3ea0d9c789 # v2.4.1
  with:
    version: 4.7.1
    use-dotnet: false
    include-templates: true
```

Then run the existing clean verifier and export the current macOS preset:

```bash
./tools/verify-clean.sh
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Upload `build/Phoenix.zip` with the repository's pinned `actions/upload-artifact` convention. The package remains unsigned. No signing, notarization, DMG, macOS runner, release publication, installer, or updater is added.

## 5. Packaged acceptance pass

The implementation is not release-complete solely because CI is green. Run one normal exported macOS playthrough from New Game to the Day 14 result.

Verify:

- onboarding and the code-built help panel are sufficient without README/developer instructions;
- the Day-1 tutorial matches green/red/gold targeting;
- all four farm actions show both pre-action validity/reason and post-action feedback;
- dry/wet soil and crop stages are distinguishable at 1×;
- purchase, shipping income, gifts/relationship gains, sleep/wake/save, and finale transitions are readable/audible;
- tree/building/mature-crop/villager crossings preserve front/behind order;
- default and smaller supported windows keep required controls visible and pixel presentation crisp;
- Continue restores the already-covered representative midgame morning and pre-finale state without presentation desynchronization;
- repeated input does not duplicate purchase, shipment, gift, day transition, save, or finale processing;
- a representative farming/reinvestment run reaches **Promising Farmer** via shipped value (`>= 150G`) without debug state; Heart is optional.

Retune only when this pass exposes an observable defect: Promising is unreachable under a normal farming/reinvestment route, a forced economy dead-end occurs, or a concrete readability/presentation issue requires a value change. Update the exact GUT value tests in the same commit as any accepted tuning.

## Explicit non-goals

- No new crops, villagers, maps, tools, quests, seasons, endings, or post-game.
- No controller remapping or settings screen.
- No final soundtrack production, voice acting, particle system, dynamic lighting, projected shadows, shaders, or post-processing.
- No GUT→GdUnit migration or 14-day UI automation script.
- No browser/Tauri/C#/GDExtension path.
- No signing, notarization, DMG, App Store, updater, installer, or release service.
- No generic audio, feedback, theme, pause, or rendering framework.
- No compatibility layer for old development saves.
- No fence added solely for release verification.

## Expected implementation footprint

Production changes should stay concentrated in the existing owners:

- `scripts/game/game_session.gd`
- `scripts/game/content_rules.gd`
- `scripts/world/world_shell.gd`
- `scripts/player/player_controller.gd`
- `scripts/world/farm_view.gd`
- `scripts/ui/game_hud.gd`
- `scenes/player/player.tscn`
- `scenes/world/world.tscn`
- `scenes/ui/game_hud.tscn` only for the two audio players if kept scene-authored
- `assets/sprites/proof-shadow.png`
- `assets/audio/*`
- focused existing GUT/integration/headless tests
- `.github/workflows/ci.yml`
- `README.md`/`CLAUDE.md` for final player/art/release instructions

There is no `pause_help.tscn`, no GdUnit-only session-rule oracle, and no second modal construction style. Anything substantially broader than this footprint is a signal to reduce scope rather than add another abstraction.
