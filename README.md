# Phoenix

Phoenix is a Godot-only isometric farming game. HPA-590 provides the
authored world, movement, collision, targeting, camera, and depth-ordering
foundation; HPA-589 ports the gameplay authority — the complete farming and
economy loop — on top of it.

## Prerequisite

- Godot 4.7.1, standard non-.NET edition

## Open and run

Open this repository as a project in Godot 4.7.1. The main scene is
`scenes/app/app.tscn`; press **Play** to run it. From a terminal, the same
project can be opened or run with:

```bash
godot --editor --path .
godot --path .
```

## Player contract

Phoenix opens on a title screen. New Game starts a fresh run without deleting
the current slot. Continue is enabled only for a schema-v1 save accepted by
current GameSession rules at user://phoenix-save.json. Successful sleep
advances gameplay first, then synchronously writes the completed next-morning
state and pending morning summary. Continue restores gameplay at the authored
spawn. Invalid/incompatible loads and save failures never block New Game or
roll back an already completed day.

A fresh run opens on a short blocking introduction; pressing Start releases
the world and is followed by dismissible, contextual help for the current
step. Continuing a completed run opens the final result screen directly —
there is no post-game or free play.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move; facing selects the adjacent target cell |
| `1` / `2` / `3` / `4` | Select Hoe / Seeds / Watering can / Hands |
| Space | Use the selected action on the targeted farm cell |
| E | Interact with the targeted shop, bed, or shipping-bin cell |
| Esc | Close the open modal |

The target diamond is hidden when the faced cell is outside the map. Facing
the shop cell `(6,7)`, bed cell `(6,8)`, or shipping cell `(6,10)` from an
adjacent tile shows a contextual interaction hint (for example `Shop — E`).

- Face Mira, Rowan, or June and press E to talk.
- The first talk with each villager each day adds 1 relationship point.
- Give at most one harvested crop per villager per day from the dialogue panel.
- A normal gift adds 3 points; that villager's favourite crop adds 5 total.
- Relationship levels are Stranger, Friend at 12 points, and Close Friend at 18 points.

## Gameplay loop

`GameSession` is the single gameplay authority; every farming/economy command
returns a `GameRules.CommandCode` and the HUD renders the refreshed snapshot.
The social commands `talk_to` and `gift_crop` instead return a narrow result
dictionary (lines, points gained, gift reaction) that the dialogue panel
renders.

1. **Farm.** Face a cell in the `3x3` farm patch and press `1`–`4` to select
   an action, then Space to use it: till soil with the hoe, plant the
   selected seed, water the crop, and harvest once it is mature.
2. **Budget the day.** Each action costs clock minutes and stamina; the day
   runs 06:00 to 22:00 and stamina caps at 20. Rain waters every crop for
   free, so the watering can is unneeded on rainy days.
3. **Shop.** Face the shop cell and press E to open the seed shop: buy
   Turnip, Potato, or Pumpkin seeds with the day's money.
4. **Ship.** Face the shipping cell and press E to open the bin: deposit
   harvested crops into the pending shipment.
5. **Sleep.** Face the bed cell and press E to open a sleep confirmation.
   Sleeping pays out the pending shipment, grows watered crops, restores
   stamina, rolls tomorrow's weather, and advances the day — then a morning
   summary must be acknowledged before play resumes.

The season runs 14 days and the HUD objective counts down to the Day 14
harvest market. Only crops deposited in the shipping bin count toward the
farming result — harvested crops still carried in hand do not. On Day 14,
pressing E at the harvest market finishes the run; sleeping that night is
the fallback route that finishes it instead. The result is one of three
encouraging endings — New Beginning, Promising Farmer, or Heart of the
Harvest — based on shipped value and village friendships. The exhaustive crop
economy, action-budget, and command-code tables are frozen in
`tests/unit/test_game_rules.gd`, `tests/unit/test_game_session.gd`, and
`tests/integration/test_gameplay_shell.gd`; those tests are the reference,
not this README.

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

HPA-590 authored the 12x12 sprite-isometric shell: WASD movement, facing,
adjacent-cell targeting, authored farm/path ground, tree/building/perimeter
collision, bounded camera follow, and front/behind depth ordering. HPA-589
added the complete single-player farming/economy loop on that shell: tilling,
planting, watering, harvesting, seed shopping, shipping, sleeping, weather,
and the morning summary, with `GameRules`/`GameSession` as the gameplay
authority.

Day 14 is the terminal day of the season. HPA-594 added the villagers and
social systems: Mira, Rowan, and June stand at fixed cells, talking and
gifting follow the relationship rules above, and `VillagerRules`/`GameSession`
hold the frozen content and mutable relationship state. HPA-597 finished the
content slice: the blocking introduction with contextual help, the Day 14
harvest market that ends the run (with sleeping as the fallback route),
shipping-bin deposits as the only farming-result scoring, three encouraging
endings, and Continue on a completed run reopening the result screen — there
is no post-game or free play.

## Verification

The clean verifier archives committed `HEAD` and runs the Godot-only import,
test, and headless smoke checks:

```bash
./tools/verify-clean.sh
```

It runs the editor/import smoke, the GUT unit and integration tests, the
project contract smoke, world-math smoke, and world-shell smoke in that
order. There is no second JavaScript or desktop-shell runtime in the current
checkout; historical behavior references remain in Git history and
`docs/superpowers/`.
