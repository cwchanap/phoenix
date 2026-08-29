# Phoenix HPA-599 Release Closeout Design

**Linear:** HPA-599 — `[Release] Polish, balance, and verify the complete 14-day MVP`

**Scope:** One closeout PR. Planning and implementation stay on `agent/hpa-599-release-closeout-plan`; do not split HPA-599 into a second implementation PR.

## Context

HPA-597 completed the final gameplay/content slice. Phoenix now has one Godot-native 14-day loop, persistence, villagers/social progression, contextual onboarding, a Day 14 finale, and terminal results. PR #11 added GdUnit4 and godot-e2e as focused parallel workflows beside the mature GUT/headless clean verifier.

HPA-599 is a release closeout, not a new gameplay slice. Extend the current owners, make the remaining feedback readable, add a deliberately small visual/audio pass, prove the frozen economy is viable, export the unsigned macOS package, and perform one real packaged playthrough.

Existing owners are sufficient:

- `GameRules`, `VillagerRules`, and `ContentRules` own closed rules/content.
- `GameSession` owns mutable gameplay and command validation.
- `WorldShell` is the only production session holder/coordinator.
- `PlayerController`, `FarmView`, and `GameHud` own presentation.
- `SaveFile`/`SaveRepository` own persistence.
- GUT is the broad rules/integration release oracle.
- GdUnit4 and godot-e2e stay focused parallel lanes.
- `export_presets.cfg` already owns the macOS export preset.

## Decision

Use an **in-place closeout**. Do not introduce a polish service, feedback bus, audio manager, settings subsystem, generic pause manager, renderer abstraction, second gameplay state layer, or test-framework migration.

### Alternatives rejected

1. **Generic polish/feedback subsystem.** One gameplay shell already has command codes and HUD seams for the required feedback.
2. **GdUnit-only release rules.** `tools/verify-clean.sh` runs GUT; release-critical session and balance contracts belong there.
3. **Verification-only closeout.** Target readability, help, visual depth, and audio remain real HPA-599 gaps.
4. **Separate help scene.** Current HUD panels are code-built through `GameHud`; a one-off `pause_help.tscn` creates a second convention for static UI.
5. **Manual-only balance proof.** `GameSession` already supports deterministic weather and direct command tests, so arithmetic reachability should be automated rather than inferred from one human run.

## Release-candidate balance

Do not tune by instinct. Keep the existing values as release candidates:

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

Add one deterministic GUT route that starts from normal Day 1 state, uses the public farming/shop/shipping/sleep commands, reaches Day 14, triggers the finale, and proves `shipped_value >= ContentRules.PROMISING_SHIPPED_VALUE` without friendship or direct state mutation. The smallest representative route is five Turnips: grow/ship the three starter Turnips, buy two Turnip seeds, grow/ship those two, then advance normally to Day 14. Their shipped value is 175G, so the test proves the current 150G Promising threshold is reachable with reinvestment.

Change a numeric rule only if:

- that deterministic representative route fails the Promising threshold after a legitimate implementation change;
- the packaged run exposes a forced economy dead-end not represented by the scripted route; or
- a specific timing/threshold value causes an observed usability defect that presentation cannot solve.

Heart of the Harvest remains optional for the packaged acceptance run.

## 1. Farming preview, target tint, hint text, and onboarding copy

### Shared read-only preview

Add:

```gdscript
GameSession.preview_selected_action(target_cell: Variant) -> GameRules.CommandCode
```

Factor the current `hoe`, `plant`, `water`, and `harvest` guards into private read-only failure helpers. Both preview and each mutating command call the same helper in the same order. Preview never mutates session state and is covered beside the existing GUT command atomicity tests, reusing the existing `_assert_unchanged()` helper.

Do not clone a session, execute/rollback a command, or copy the rule tree into presentation code.

### Closed presentation tint

Avoid a `Variant` null/bool tri-state at the player seam. `PlayerController` owns one closed enum:

```gdscript
enum TargetTint { NEUTRAL, VALID, INVALID }

func set_target_tint(tint: TargetTint) -> void
```

`TargetTint.NEUTRAL` uses the existing gold color, `VALID` uses green, and `INVALID` uses red. `PlayerController` still owns no gameplay rules.

### Let GameSession classify farm membership

`WorldShell._process()` does not call `WorldContract.farm_cells().has(target)`. It asks `GameSession.preview_selected_action(target)` and classifies the returned code:

- selected-action success code → green/valid;
- `NO_TARGET` or `NOT_FARM_CELL` → gold/neutral, then use the existing villager/shop/bed/shipping/market hint chain;
- every other preview code → red/invalid and show its reason.

This keeps farm membership in the same session/`_target_failure()` authority used by actual commands and avoids rebuilding `farm_cells()` every frame just to duplicate membership policy.

### Do not preview while world input is blocked

If `_world_input_enabled` is false, `WorldShell._process()` sets neutral gold, clears the action/interact hint, and returns before calling preview. The blocking intro, morning summary, shop/dialogue/help panels therefore never advertise an action that input gating will ignore.

### Reuse the existing sentence table

Extract `GameHud.show_feedback()` into one reusable text function:

```gdscript
func feedback_text(code: GameRules.CommandCode) -> String
```

All currently displayed sentences remain unchanged. `INTRO_ACKNOWLEDGED` and `INTRO_ALREADY_ACKNOWLEDGED` are explicit silent (`""`) cases because intro completion already flows through `_finish_command()` but intentionally shows no feedback. The default branch asserts on an actually unmapped command code instead of silently hiding a future missing mapping.

For an active farm target:

- valid preview → `Space — use selected action`;
- invalid preview → `feedback_text(preview_code)`.

### Fix the Day-1 tutorial in the same change

Change the current stale “gold outline” farm tutorial to the new contract:

> Face a farm diamond. Green means the selected action can run; red means it cannot. Press 1 for Hoe, then Space.

Pin that exact string in `tests/unit/test_content_rules.gd`.

## 2. HUD help, real Esc propagation, weather tint, shadows, and depth

### Code-built help panel

Add `_build_pause_help()` beside the existing HUD panel builders using `_add_panel`, `_add_label`, and `_add_button`. No `pause_help.tscn`; no `SceneTree.paused`.

Required copy:

```text
Phoenix — Controls
WASD — Move
1 / 2 / 3 / 4 — Hoe / Seeds / Water / Hands
Space — Use selected action
E — Interact
Esc — Close / controls
```

The panel participates in the existing `has_blocking_modal()` / `modal_state_changed` world-input gate.

### Esc ownership follows actual Godot propagation

`DialoguePanel` is a descendant of `GameHud`. Godot delivers `_unhandled_input()` in reverse depth-first scene-tree order, so visible dialogue receives Esc first and already calls `Viewport.set_input_as_handled()`. Therefore `GameHud` does **not** need a dialogue branch.

Extend the existing `GameHud._unhandled_input()` so it handles only events that reach it:

1. morning summary → consume Esc and remain open;
2. blocking intro → consume Esc and remain open;
3. shop/shipping/sleep → close the visible panel and consume Esc;
4. help visible → close help and consume Esc;
5. otherwise → open help and consume Esc.

`DialoguePanel._unhandled_input()` remains untouched and preserves its existing close-friend sequence lock.

Integration tests inject Esc through the viewport/input pipeline (`Input.parse_input_event()` plus a processed frame) rather than directly calling either node's `_unhandled_input()`. This verifies real propagation instead of testing private methods in isolation. Reuse the existing `_hud(world)` and `_panel(hud, name)` helpers for HUD lookups.

### Weather tint

Add one full-screen non-interactive `ColorRect` under HUD content and derive its subtle sunny/rainy tint from the existing snapshot weather key. No shader, particles, lighting system, post-processing, or new weather state.

### Reused ground shadow

Add one small translucent `assets/sprites/proof-shadow.png` and reuse it under player, tree, building, shipping bin, market, villagers, and dynamic crop roots where ground contact needs help.

Shadows remain children of existing entity roots; `Entities` stays the only Y-sort owner. Update the current exact smoke child-name assertions from `['Sprite2D']` to `['Shadow', 'Sprite2D']` where applicable, including dynamic crop roots. Do not bolt on parallel assertions while leaving the old exact contracts stale.

There is no authored fence entity; do not add one for release verification.

### Sprite-isometric art contract

Record in `CLAUDE.md`:

- 64×32 ground diamonds;
- entity root = bottom-center ground contact;
- visible sprite offsets upward from the root;
- shadows remain child sprites on the ground plane;
- foreground/occluding objects stay under the existing Y-sorted `Entities` owner;
- nearest filtering and integer scaling remain mandatory.

## 3. Minimal audio

Generate a tiny project-owned placeholder WAV set under `assets/audio/` and document its provenance. Keep exactly two code-built players owned by `GameHud`:

- `SfxPlayer` for short feedback;
- `MusicPlayer` for one quiet daytime loop.

Do not edit `game_hud.tscn` just to add these two nodes; `GameHud` already builds its runtime presentation children in code. Add the players in a small `_build_audio()` helper during `_ready()`.

### Loop at import time, not by duplicating the resource

Configure `assets/audio/farm-day-loop.wav.import` with WAV import `edit/loop_mode=2` (Forward), then assign the imported `FARM_DAY_LOOP` resource directly to `MusicPlayer`. Do not `duplicate()` the stream and mutate `loop_mode` at runtime; the duplicate would lose the imported resource path that the wiring test intentionally pins.

Reuse `show_feedback()`/`feedback_text()` for command SFX categories and the same SFX player for modal confirmation/cancel and save transitions where no command code covers the event. No audio manager, bus abstraction, settings page, volume controls, or persisted audio state.

## 4. Verification, deterministic economy gate, and unsigned macOS export

### Keep current test lanes

- `tools/verify-clean.sh`: broad clean archive + GUT + headless smoke oracle.
- `.github/workflows/unit-tests.yml`: focused GdUnit4 lane.
- `.github/workflows/e2e-tests.yml`: bounded godot-e2e lane.

Preview guard/atomicity and the representative economy route belong in GUT. Green/red/gold shell behavior and help/audio wiring belong in existing integration tests. Do not duplicate them into GdUnit4 just for symmetry.

Existing persistence tests already prove representative morning and pre-finale save/restore equivalence; extend only if HPA-599 changes those seams.

### Deterministic Promising reachability

Add `test_representative_reinvestment_route_reaches_promising()` in `tests/unit/test_game_session.gd` using `GameSession.new(func() -> float: return 0.9)` for deterministic sunny weather. The route:

1. Hoe, plant, and water three starter Turnips.
2. Water them on the next two days; after the third growth night, harvest and deposit all three.
3. Buy two Turnip seeds, replant two of the already-tilled cells, water them, and continue watering through maturity.
4. Harvest and deposit those two; sleep once so the second shipment settles.
5. Advance/acknowledge normally to Day 14, trigger the market finale, and build the harvest result from the final state.
6. Assert `shipped_count == 5`, `shipped_value == 175`, `shipped_value >= ContentRules.PROMISING_SHIPPED_VALUE`, and tier `promising_farmer`.

This gives any future balance change an immediate arithmetic release gate.

### CI uses explicit import before release export

`tools/verify-clean.sh` imports/tests a temporary `git archive`, not the checked-out working tree. Godot's `--export-release` command does not document an implied import, while `--import` explicitly waits for resources to import. Therefore the checkout export path runs:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```

Use the same sequence in local/final verification blocks.

When editing `.github/workflows/ci.yml`, also adopt the exact pinned checkout/setup-Godot SHAs and `persist-credentials: false` convention already used by the GdUnit/e2e workflows, with `include-templates: true`. Upload the unsigned ZIP with the repository's pinned `actions/upload-artifact` SHA.

No signing, notarization, DMG, macOS runner, release publication, installer, or updater is added.

## 5. Packaged acceptance pass

The automated economy test owns Promising arithmetic. The real exported macOS playthrough owns what automated rules tests cannot establish:

- onboarding/help are understandable without README/developer instructions;
- green/red/gold target feedback is truthful and readable;
- dry/wet soil and crop stages are distinguishable at 1×;
- purchase, shipping, social, sleep/wake/save, and finale cues are readable/audible;
- tree/building/mature-crop/villager crossings preserve depth order;
- default and smaller supported windows keep controls visible and pixel art crisp;
- Continue feels synchronized with restored authoritative state;
- repeated user input does not visibly duplicate processing or soft-lock the run;
- no practical economy dead-end appears during a normal playthrough.

Record the final shipped value/tier as evidence, but do not use a one-shot human route as the arithmetic proof for the 150G threshold.

## Risks

1. **Linux-to-macOS export has no existing CI proof in Phoenix.** HPA-599 deliberately tests the supported Godot cross-export on `ubuntu-latest` with installed templates and explicit import. If that platform export fails for a real toolchain reason, treat it as a release-gate failure and revisit the delivery choice; do not silently add a macOS runner or signing machinery.
2. **Audio import metadata can drift if the WAV is regenerated.** Pin `farm-day-loop.wav.import` loop mode in the committed import sidecar and verify the imported stream path/loop wiring in integration tests.
3. **Balance changes can invalidate the representative route.** The new GUT route is intentionally coupled to the release-candidate economy and must change in the same review as any accepted balance adjustment.

## Explicit non-goals

- No new crops, villagers, maps, tools, quests, seasons, endings, or post-game.
- No controller remapping or settings screen.
- No final soundtrack production, voice acting, particles, dynamic lighting, projected shadows, shaders, or post-processing.
- No GUT→GdUnit migration or 14-day UI automation script.
- No browser/Tauri/C#/GDExtension path.
- No signing, notarization, DMG, App Store, updater, installer, or release service.
- No generic audio, feedback, theme, pause, or rendering framework.
- No compatibility layer for old development saves.
- No fence added solely for release verification.

## Expected implementation footprint

Production changes stay concentrated in existing owners:

- `scripts/game/game_session.gd`
- `scripts/game/content_rules.gd`
- `scripts/world/world_shell.gd`
- `scripts/player/player_controller.gd`
- `scripts/world/farm_view.gd`
- `scripts/ui/game_hud.gd`
- `scenes/player/player.tscn`
- `scenes/world/world.tscn`
- `assets/sprites/proof-shadow.png`
- `assets/audio/*`
- focused existing GUT/integration/headless tests
- `.github/workflows/ci.yml`
- `README.md` / `CLAUDE.md`

There is no `pause_help.tscn`, no `game_hud.tscn` audio edit, no GdUnit-only session-rule oracle, and no second modal construction style. Anything substantially broader is a signal to reduce scope rather than add another abstraction.
