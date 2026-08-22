# Phoenix handoff

## Runtime

Phoenix is a Godot 4.7.1 project using the standard non-.NET editor and
statically typed GDScript. Open the repository in Godot and run
`scenes/world/world.tscn`; WASD is the complete HPA-590 input surface. There is
no JavaScript or Tauri runtime in the current checkout.

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
- `scripts/player/player_controller.gd` owns input sampling and a
  `CharacterBody2D`. `move_and_slide()` supplies Godot-native response against
  projected logical collision polygons; do not port the old grid-axis resolver.
- `Entities` is the one Y-sorted container. Tree, building, and player roots
  are bottom-center ground-contact positions; child sprites are offset upward.
  They share a z-index and retain scene-tree order for exact-Y ties.

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

HPA-590 is only the rendered shell: authored ground, movement, facing, target
highlight, camera follow, collision, perimeter clamping, reachability, and
front/behind depth ordering. Farming, crops, economy, social behavior, and
persistence are intentionally later Godot work; shop/bed/shipping-bin cells and
villagers are not authored here. HPA-589 is the next gameplay-authority port.

## Headless workflow

Run the one clean Godot verifier from the repository root:

```bash
./tools/verify-clean.sh
```

It archives committed `HEAD`, then runs exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

The `.godot/` import cache is ignored. Git history and historical
`docs/superpowers/` documents are the behavior reference; no dormant second
runtime or TypeScript rules tree is maintained.
