# Phoenix handoff

## Runtime

Phoenix is a Godot 4.7.1 project using the standard non-.NET editor and
statically typed GDScript. Open the repository in Godot and run
`scenes/world/world.tscn`; WASD moves, `1`/`2`/`3`/`4` select the farming
action, Space uses it, and E interacts with the shop, bed, or shipping bin.
There is no JavaScript or Tauri runtime in the current checkout.

## Architecture

- `scripts/world/world_contract.gd` is the single source for fixed HPA-590
  constants: map, projection, spawn, movement, footprints, anchors, farm/path
  cells, perimeter, and camera bounds. Do not duplicate those values in scene
  checks or gameplay code.
- `scripts/world/world_math.gd` is framework-free pure math for projection,
  inverse projection, cell lookup, diamonds, facing, targets, and projected
  logical footprints. It does not own nodes, input, physics, or gameplay state.
- `scenes/world/world.tscn` and `scripts/world/world_shell.gd` own the authored
  world scene. Ground is an authored `TileMapLayer`; shell setup derives the
  collision geometry from `WorldContract` and `WorldMath`.
- `scripts/game/game_rules.gd` is the closed rules/content source: crop
  economy, action time/stamina budgets, day/stamina/weather constants, payout
  math, and the `CommandCode` enum returned by every command. It is stateless.
- `scripts/game/game_session.gd` is the only mutable gameplay authority. All
  commands go through it and return `GameRules.CommandCode`; views read the
  immutable `snapshot()` dictionaries and never session internals.
- `FarmSoil` in `scenes/world/world.tscn` holds the non-Y-sorted farm ground
  decals. `Entities` (scripted as `scripts/world/farm_view.gd`, `FarmView`)
  remains the one Y-sort owner and renders crop sprites from session
  snapshots; it owns no gameplay state. Tree, building, and player roots are
  bottom-center ground-contact positions with child sprites offset upward;
  they share a z-index and retain scene-tree order for exact-Y ties.
- `scripts/ui/game_hud.gd` and `scenes/ui/game_hud.tscn` own presentation and
  modal state only. The HUD emits request signals and renders snapshots; it
  never touches `GameSession`.
- `scripts/world/world_shell.gd` is the only production session holder and
  coordinator: it owns the `GameSession` instance, wires HUD signals to
  session commands, refreshes `FarmView`/`GameHud` from snapshots, and gates
  world input while a modal blocks. Do not create a second session holder.
- `scripts/player/player_controller.gd` owns input sampling for
  movement/facing/targeting only and a `CharacterBody2D`. `move_and_slide()`
  supplies Godot-native response against projected logical collision
  polygons; do not port the old grid-axis resolver.

## Closed shell contract

The logical map is `12x12` with `64x32` ground diamonds and projection origin
`(384, 0)`. Player spawn is `(2.5, 9.5)`, half extent is `0.18`, speed is `96`
projected pixels/second, and player centers stay in `[0.18, 11.82]` on both
axes. The farm patch is `x=2..4,y=7..9`; the path row is `x=3..9,y=6`.

The tree footprint is `(7.2,4.2,0.6,0.6)` with projected anchor `(480,192)`;
the building footprint is `(7,7,2,2)` with projected anchor `(384,288)`.
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
the shell. Day 14 is a temporary playable boundary — no settlement or advance
past it. Villagers, social behavior, and persistence remain intentionally
later Godot work; HPA-594 is the next social slice.

## Headless workflow

Run the one clean Godot verifier from the repository root:

```bash
./tools/verify-clean.sh
```

It archives committed `HEAD`, then runs exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

The `.godot/` import cache and generated `.uid`/`.import` sidecars
are ignored everywhere, including inside vendored `addons/`; the
archive-first verifier re-imports them from scratch. Git history and historical
`docs/superpowers/` documents are the behavior reference; no dormant second
runtime or TypeScript rules tree is maintained.
