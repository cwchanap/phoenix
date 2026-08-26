# Phoenix handoff

## Runtime

Phoenix is a Godot 4.7.1 project using the standard non-.NET editor and
statically typed GDScript. Open the repository in Godot and run
`scenes/app/app.tscn`; WASD moves, `1`/`2`/`3`/`4` select the farming
action, Space uses it, and E interacts with the shop, bed, or shipping bin.
There is no JavaScript or Tauri runtime in the current checkout.

- E interacts with villagers as well as shop/bed/shipping.

## Architecture

- `scripts/world/world_contract.gd` is the single source for fixed HPA-590
  constants: map, projection, spawn, movement, footprints, anchors, farm/path
  cells, perimeter, and camera bounds. Do not duplicate those values in scene
  checks or gameplay code.
- WorldContract owns the three static villager cells/footprints.
- `scripts/world/world_math.gd` is framework-free pure math for projection,
  inverse projection, cell lookup, diamonds, facing, targets, and projected
  logical footprints. It does not own nodes, input, physics, or gameplay state.
- `scenes/world/world.tscn` and `scripts/world/world_shell.gd` own the authored
  world scene. Ground is an authored `TileMapLayer`; shell setup derives the
  collision geometry from `WorldContract` and `WorldMath`.
- `scripts/game/game_rules.gd` is the closed rules/content source: crop
  economy, action time/stamina budgets, day/stamina/weather constants, payout
  math, and the `CommandCode` enum returned by every command. It is stateless.
- VillagerRules owns frozen HPA-595 content and pure relationship policy.
- `scripts/game/content_rules.gd` (`ContentRules`) owns the frozen HPA-597
  content policy: `TUTORIALS` is the one tutorial identity/copy/completion
  table, plus prompt relevance and the harvest result tiers/totals. It is
  stateless.
- `scripts/game/game_session.gd` is the only mutable gameplay authority. All
  commands go through it; existing farming/economy commands return `GameRules.CommandCode`;
  social commands `talk_to`/`gift_crop` return one narrow result Dictionary local to those methods; views read the immutable `snapshot()` dictionaries and never session internals.
- GameSession owns relationship points, daily talk/gift flags, and close_friend_dialogue_seen.
- GameSession derives tutorial completion only inside `_commit()` via
  `ContentRules.tutorial_for_code()`; guard failures never complete a tutorial.
- The four HPA-597 persisted fields (`intro_acknowledged`, `tutorial`,
  `shipped`, `finale_triggered`) are copied through `state()` and
  `snapshot()`; old saves missing them are intentionally incompatible.
- `_settle_pending_shipment()` pays the pending bin once and records the
  lifetime `shipped` counts; carried `harvested` inventory is never
  auto-shipped at completion.
- The Day 14 market and Day 14 sleep routes share one `_complete_finale()`
  transaction; no route reaches Day 15.
- `FarmSoil` in `scenes/world/world.tscn` holds the non-Y-sorted farm ground
  decals. `Entities` (scripted as `scripts/world/farm_view.gd`, `FarmView`)
  remains the one Y-sort owner and renders crop sprites from session
  snapshots; it owns no gameplay state. Tree, building, and player roots are
  bottom-center ground-contact positions with child sprites offset upward;
  they share a z-index and retain scene-tree order for exact-Y ties.
- `scripts/ui/game_hud.gd` and `scenes/ui/game_hud.tscn` own presentation and
  modal state only. The HUD emits request signals and renders snapshots; it
  never touches `GameSession`.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- OnboardingOverlay is code-built under `GameHud` (like DialoguePanel) and
  forwards opening/tutorial visibility through the existing
  `modal_state_changed` signal; it owns no gameplay state.
- GameHud.has_blocking_modal() remains the single world-input gate.
- `scripts/world/world_shell.gd` is the only production session holder and
  coordinator: it owns the `GameSession` instance, wires HUD signals to
  session commands, refreshes `FarmView`/`GameHud` from snapshots, and gates
  world input while a modal blocks. Do not create a second session holder.
- `scripts/player/player_controller.gd` owns input sampling for
  movement/facing/targeting only and a `CharacterBody2D`. `move_and_slide()`
  supplies Godot-native response against projected logical collision
  polygons; do not port the old grid-axis resolver.
- scripts/app/app_root.gd owns title/load/launch lifecycle and one concrete SaveRepository.
- Completed-run Continue routes straight to `ResultScreen`; the AppRoot
  result teardown removes the live World with `remove_child()` then
  `queue_free()` before presenting it.
- scripts/persistence/save_file.gd owns schema-v1 JSON transport only; it does not validate gameplay content.
- scripts/persistence/save_repository.gd writes user://phoenix-save.json with FileAccess.
- GameSession.state()/state_error()/restore_state() own mutable-state export, all persisted-state validation, and canonical restore; snapshot() remains the view read model.
- WorldShell remains the only live production session holder and synchronously writes once after successful overnight advancement.
- Player position/facing/camera/UI state remain transient/authored.
- HPA-599 is the next delivery slice.

## Closed shell contract

The logical map is `12x12` with `64x32` ground diamonds and projection origin
`(384, 0)`. Player spawn is `(2.5, 9.5)`, half extent is `0.18`, speed is `96`
projected pixels/second, and player centers stay in `[0.18, 11.82]` on both
axes. The farm patch is `x=2..4,y=7..9`; the path row is `x=3..9,y=6`.

The tree footprint is `(7.2,4.2,0.6,0.6)` with projected anchor `(480,192)`;
the building footprint is `(7,7,2,2)` with projected anchor `(384,288)`.
The harvest market cell is `(8,6)` with footprint `(8.2,6.2,0.6,0.6)` and
projected cell-center anchor `(448,240)`; the world-shell smoke pins the
cell, footprint, anchor, collision, sprite frame, and detour offsets.
Camera bounds are `Rect2(0,-96,768,480)` with `96` pixels of top padding. The
project uses a `640x360` viewport, `viewport`/`keep` stretching, integer scale,
nearest filtering, and a minimum `640x360` window.

## Current boundary

HPA-590 authored the rendered shell: authored ground, movement, facing,
target highlight, camera follow, collision, perimeter clamping, reachability,
and front/behind depth ordering. HPA-589 is done: farming, the crop economy,
the daily clock/stamina rhythm, weather, shipping, and the morning-summary
gate all exist as Godot gameplay, with `GameRules`/`GameSession` as the
authority and shop `(6,7)` / bed `(6,8)` / shipping `(6,10)` cells wired into
the shell. Day 14 is the terminal day of the season — no settlement or
advance happens past it. HPA-594 now provides villagers and social behavior.
HPA-597 is done: the blocking introduction with contextual dismissible help,
the Day 14 harvest market, and the terminal result flow all shipped.
- HPA-598 owns serialization; HPA-594 defines no save schema.
- HPA-599 owns balance/polish/export.

## Headless workflow

Run the one clean Godot verifier from the repository root:

```bash
./tools/verify-clean.sh
```

It archives committed `HEAD`, then runs exactly:

```bash
git archive HEAD              # verifier archives committed state, not the worktree
curl -fsSL .../Gut/v9.7.1.tar.gz   # fetched into the archive + sha256-verified; GUT lives in no git tree
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

GUT 9.7.1 is not committed: `tools/verify-clean.sh` downloads the tagged
upstream tarball into its temp archive before running the suite, so clean
verifications need network access. Only the `.godot/` import cache is
ignored; the source-adjacent `.import` and `.uid` sidecars are committed so
asset import settings and resource UIDs survive clean clones and CI. Git
history and historical `docs/superpowers/` documents are the behavior
reference; no dormant second runtime or TypeScript rules tree is maintained.
