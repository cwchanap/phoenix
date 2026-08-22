# Phoenix

Phoenix is a Godot-only isometric farming shell. HPA-590 provides the authored
world, movement, collision, targeting, camera, and depth-ordering foundation
for later gameplay ports.

## Prerequisite

- Godot 4.7.1, standard non-.NET edition

## Open and run

Open this repository as a project in Godot 4.7.1. The main scene is
`scenes/world/world.tscn`; press **Play** to run it. From a terminal, the same
project can be opened or run with:

```bash
godot --editor --path .
godot --path .
```

## Controls

WASD moves the player. The facing direction selects the adjacent target cell;
the target diamond is hidden when that cell is outside the map.

## Presentation contract

The game uses a `640x360` logical viewport, `viewport` stretching, `keep`
aspect, integer scale, a minimum `640x360` desktop window, and nearest texture
filtering. The presentation is pixel art and must remain crisp at every integer
window scale.

## HPA-590 world contract

| Contract | Value |
| --- | --- |
| Map | `12x12` logical cells |
| Ground diamond | `64x32` |
| Projection origin | `(384, 0)` |
| Player spawn | `(2.5, 9.5)` logical |
| Player half extent | `0.18` logical cells |
| Player speed | `96` projected pixels/second |
| Player center limits | `x,y in [0.18, 11.82]` |
| Farm patch | `x=2..4`, `y=7..9` |
| Path row | `x=3..9`, `y=6` |
| Tree footprint | `x=7.2`, `y=4.2`, `w=0.6`, `h=0.6` logical |
| Tree bottom-center anchor | `(480, 192)` projected world |
| Building footprint | `x=7`, `y=7`, `w=2`, `h=2` logical |
| Building bottom-center anchor | `(384, 288)` projected world |
| Camera padding | `96` projected pixels above the map |
| Camera bounds | `Rect2(0, -96, 768, 480)` |

The ground is an authored `TileMapLayer`. Scenery and player roots use
bottom-center ground-contact positions. Collision polygons are projected from
the logical tree, building, player, and perimeter geometry; Godot's
`CharacterBody2D` supplies the collision response. `Entities` is the single
Y-sorted container, with shared entity z-order and stable scene-tree tie order.

## Current feature boundary

HPA-590 includes the 12x12 sprite-isometric shell, WASD movement, facing,
adjacent-cell targeting, authored farm/path ground, tree/building/perimeter
collision, bounded camera follow, and front/behind depth ordering. The shell
does not author shop, bed, shipping-bin, villagers, or gameplay interactions.

Farming, crops, economy, social systems, and persistence are intentionally
restored by later Godot tickets. HPA-589 is the next gameplay-authority port.

## Verification

The clean verifier archives committed `HEAD` and runs the Godot-only import and
headless smoke checks:

```bash
./tools/verify-clean.sh
```

It runs the editor/import smoke, project contract smoke, world-math smoke, and
world-shell smoke in that order. There is no second JavaScript or desktop-shell
runtime in the current checkout; historical behavior references remain in Git
history and `docs/superpowers/`.
