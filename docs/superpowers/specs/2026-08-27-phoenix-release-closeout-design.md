# Phoenix HPA-599 Release Closeout Design

**Linear:** HPA-599 — `[Release] Polish, balance, and verify the complete 14-day MVP`

**Scope:** One closeout PR. This planning commit stays documentation-only; implementation continues on this same branch and PR after review.

## Context

HPA-597 completed the final gameplay/content slice. Phoenix now has one Godot-native 14-day loop, persistence, villagers/social progression, onboarding, a Day 14 finale, and terminal results. PR #11 also added GdUnit4 and godot-e2e workflows beside the existing GUT/headless release verifier.

HPA-599 is therefore not a feature-building ticket. It is the last MVP closeout pass: make existing actions easier to read, add a deliberately small amount of presentation/audio feedback, validate the already-frozen economy/social numbers, produce an unsigned macOS package, and prove the complete run is playable without developer instructions.

The current architecture already has the seams needed for this work:

- `GameRules`, `VillagerRules`, and `ContentRules` own closed data/rules.
- `GameSession` owns mutable gameplay and command validation.
- `WorldShell` coordinates the live session and world input.
- `PlayerController`, `FarmView`, and `GameHud` own presentation.
- `SaveRepository`/`SaveFile` already own persistence.
- GUT is the broad rules/integration oracle; GdUnit4 and godot-e2e are parallel focused lanes.
- `export_presets.cfg` already contains the single macOS preset.

## Decision

Use an **in-place release closeout**. Reuse the current owners, add only the smallest missing presentation seams, and do not introduce a general polish framework, event bus, audio manager, settings subsystem, renderer abstraction, or new gameplay layer.

### Alternatives considered

1. **Close out in place — selected.** Add exact action-preview validation to `GameSession`, render that status through the existing player/world/HUD chain, add one small help modal, a few lightweight sprite/audio assets, and extend existing verification/export. This is the least code and keeps ownership obvious.
2. **Create a generic presentation/feedback service — rejected.** A feedback router, audio manager, theme service, and generalized event stream would centralize future polish, but Phoenix has one screen and one gameplay shell. The indirection costs more than the reuse it provides for the MVP.
3. **Verification-only closeout — rejected.** CI/export work alone would leave HPA-599’s concrete readability/audio/help gaps unresolved.

## Release-candidate balance

Do not pre-emptively rebalance numbers that are already coherent and exhaustively pinned. The current values become the **release-candidate baseline**:

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
| Promising shipped value | 150G |
| Heart shipped value | 300G + Close Friend |

These values are already pinned in `tests/unit/test_game_rules.gd`, `tests/unit/test_content_rules.gd`, and villager/session tests. HPA-599 should change a value only when the deterministic checks or exported 14-day playthrough expose a concrete problem. Any such change stays in this PR and updates the exact-value tests in the same commit.

This avoids “tuning by instinct” and keeps the ticket focused on observed release blockers.

## Farming target and action feedback

The gold target diamond currently says only “this is the adjacent cell.” Invalid farming actions become apparent only after Space is pressed. HPA-599 will make the pre-action state readable without duplicating gameplay policy in presentation code.

### Read-only action preview

Add `GameSession.preview_selected_action(target_cell) -> GameRules.CommandCode`.

It must:

- perform the same active-day, target, tile-state, seed, weather, time, and stamina validation as the corresponding mutating command;
- return the success code that would be produced by the selected action (`SOIL_TILLED`, `CROP_PLANTED`, `CROP_WATERED`, or `CROP_HARVESTED`) when the action is currently valid;
- never mutate time, stamina, farm state, inventory, tutorial progress, or any other session state.

To keep preview and execution from drifting, factor the existing guard logic into private per-action validation helpers and have both preview and the mutating methods call those helpers. Do **not** copy the rule tree into `WorldShell`, `PlayerController`, or `GameHud`.

### Target colors

`WorldShell` asks the session for preview only when the adjacent target is one of `WorldContract.farm_cells()` and tells `PlayerController` how to render the target:

- **green:** selected farming action is valid now;
- **red:** target is a farm cell but the selected farming action is invalid now;
- **gold:** non-farm target/ordinary adjacent-cell targeting, preserving interaction targeting for shop, bed, shipping, market, and villagers.

Existing textual `GameHud.show_feedback()` remains the authoritative post-action explanation. The color is a fast preview, not a replacement for command codes or feedback strings.

## Soil, crops, weather, and depth readability

Keep the pixel-art/isometric renderer exactly as it is. No shaders and no second renderer.

### Art contract

Add a concise durable section to `CLAUDE.md` covering authored sprite rules:

- 64×32 ground diamonds;
- entity roots at bottom-center ground contact;
- child sprites offset upward from that contact;
- nearest-neighbor pixel art at integer scaling;
- shadows stay on the ground plane and never become Y-sort roots;
- foreground/occluding art stays inside the existing Y-sorted `Entities` hierarchy.

The current world contains trees, the building, crops, villagers, player, shipping bin, and market. It contains **no authored fence entity**. HPA-599 must not invent a fence solely to satisfy a generic polish checklist; depth verification covers the entities that actually exist.

### Soil/crops

Keep the existing two-frame dry/wet soil and four-stage crop model. Improve the proof sprites only if the current frames are ambiguous at 1× scale; do not add another crop-state model.

Add one reusable translucent ground-shadow sprite asset and place it beneath the entities where ground contact is unclear. Dynamic crop roots may reuse the same texture with a smaller scale. The shadow is presentation-only.

### Weather

Add one translucent full-screen weather tint owned by `GameHud`:

- sunny: transparent/warm-neutral;
- rainy: subtle cool tint.

`GameHud.render(snapshot)` derives the tint directly from the existing `weather` snapshot field. No post-processing, particles, lighting system, or shader is added.

## Audio

Use a small set of project-generated placeholder WAV files under `assets/audio/` and record their provenance in `assets/audio/README.md`. This avoids external licensing/attribution work for an MVP closeout.

Use only two `AudioStreamPlayer` nodes owned by `GameHud`:

- `SfxPlayer` for short feedback clips;
- `MusicPlayer` for one quiet looping daytime track.

`GameHud.show_feedback()` maps existing command codes to the appropriate SFX category. Modal open/close and save/finale transitions reuse the same two players. There is no audio event bus or manager.

Minimum categories:

- farming action;
- purchase;
- shipping;
- dialogue/gift;
- confirm;
- cancel/error;
- sleep/wake/save transition;
- finale;
- one quiet music loop.

Default asset levels are normalized conservatively. **No volume/settings UI is planned.** If the packaged playthrough shows that the default mix itself is bad, fix the file/player levels in this PR rather than adding a settings subsystem.

## Pause/help

Add one small `Control` scene, `scenes/ui/pause_help.tscn`, containing:

- Phoenix / Controls title;
- WASD — Move;
- 1/2/3/4 — Hoe / Seeds / Water / Hands;
- Space — Use selected action;
- E — Interact;
- Esc — Close / controls;
- Resume button.

`GameHud` owns its visibility and includes it in `has_blocking_modal()`. Esc keeps its current “close the top modal” behavior; when no existing modal is open, Esc toggles the help panel.

Do not set `SceneTree.paused`. Phoenix has no continuously advancing simulation; blocking world input through the existing modal gate is sufficient and avoids pause-mode complexity.

## Verification strategy

### Keep the current test lanes

Do not migrate the mature GUT suite to GdUnit4 in this ticket.

- `tools/verify-clean.sh` remains the broad clean-checkout oracle: import, full GUT unit/integration suite, and headless project/world smokes.
- `.github/workflows/unit-tests.yml` continues to run the focused GdUnit4 suite.
- `.github/workflows/e2e-tests.yml` continues to run bounded godot-e2e flows.

Add only tests that cover new HPA-599 behavior or explicit release gates. Do not duplicate every GUT assertion in GdUnit4.

### Automated additions

1. GUT tests pin read-only action preview against the actual command guards and prove preview does not mutate state.
2. Existing exact balance/result tests remain the release-number oracle; add missing `threshold - 1`, exact threshold, and combined Heart boundary cases only where not already explicit.
3. Integration tests pin the help modal/input gate, target validity colors, weather tint, audio-player wiring, and representative midgame/pre-finale save equivalence.
4. Extend the existing godot-e2e lane only for one stable release-relevant assertion if necessary; do not create a 14-day UI automation script.

### macOS export in CI

The current preset already names `macOS`. Update the main CI job to install Godot 4.7.1 export templates and, after `./tools/verify-clean.sh`, run:

```bash
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

The package is unsigned by design. Upload `build/Phoenix.zip` as a CI artifact for manual verification. Do not add signing, notarization, DMG creation, release publishing, or a deployment pipeline.

## Packaged acceptance pass

The final implementation PR is not ready solely because tests are green. Run one normal exported macOS playthrough from New Game through the Day 14 result and record the result in the PR description/checklist.

Verify:

- onboarding and help are sufficient without developer instructions;
- all four farming actions have readable target + post-action feedback;
- dry/wet soil and all crop stages are distinguishable at 1×;
- purchase, shipping income, gifts/relationship gains, sleep/wake/save, and finale transitions are readable/audible;
- tree/building/mature-crop/villager crossings keep correct front/behind order;
- default 640×360 and a smaller host window preserve crisp integer presentation without hiding required controls;
- save/Continue from a representative midgame morning and immediately before the finale restore equivalent gameplay state;
- no duplicated purchase/shipping/gift/finale processing appears;
- the representative economy reaches a satisfying result without requiring a hidden strategy.

If the playthrough exposes a balance or presentation defect, fix that concrete defect in the same HPA-599 PR and rerun the affected automated gate plus the packaged path.

## Explicit non-goals

- No new crops, villagers, maps, tools, quests, seasons, endings, or post-game.
- No controller remapping or settings screen.
- No original soundtrack production, voice acting, particle system, dynamic lighting, projected shadows, shaders, or post-processing.
- No GUT-to-GdUnit migration.
- No browser/Tauri/C#/GDExtension path.
- No signing, notarization, DMG, App Store, updater, installer, or release service.
- No generic audio, feedback, theme, pause, or rendering framework.
- No compatibility layer for pre-v1 saves.

## Expected implementation footprint

Production changes should stay concentrated in the existing owners plus one small help scene and assets:

- `scripts/game/game_session.gd`
- `scripts/world/world_shell.gd`
- `scripts/player/player_controller.gd`
- `scripts/world/farm_view.gd`
- `scripts/ui/game_hud.gd`
- `scenes/player/player.tscn`
- `scenes/world/world.tscn`
- `scenes/ui/game_hud.tscn`
- `scenes/ui/pause_help.tscn` (new)
- `assets/sprites/proof-shadow.png` (new)
- `assets/audio/*` (new, small placeholder set)
- focused tests under the existing GUT/GdUnit4/e2e directories
- `.github/workflows/ci.yml`
- `export_presets.cfg` only if the export command exposes a missing release option
- `README.md` / `CLAUDE.md` for final player/art/release instructions

Anything substantially broader than this footprint is a signal to reduce scope rather than introduce another abstraction.
