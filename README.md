# Phoenix

Phoenix is a Godot-only isometric farming game. HPA-590 provides the
authored world, movement, collision, targeting, camera, and depth-ordering
foundation; HPA-589 ports the gameplay authority — the complete farming and
economy loop — on top of it; HPA-686 adds the authored town map and the
truck that carries the run between the two maps.

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
the current slot. Continue is enabled only for a schema-4 save accepted by
current GameSession rules at user://phoenix-save.json. Successful sleep
advances gameplay first, then synchronously writes the completed next-morning
state and pending morning summary. Continue restores gameplay at the authored
spawn. Invalid/incompatible loads and save failures never block New Game or
roll back an already completed day.

Farm saves use schema 4 and have no migration path; older schema versions are
rejected. UI preferences are stored separately in
user://phoenix-settings.cfg.

A fresh run opens on a short blocking introduction in Kenji's voice: he won
the lottery, left his software job in Tokyo, and bought a neglected field two
weeks before the Day 14 harvest market. The opening shows his Day 1 diary;
pressing Start releases the world and is followed by dismissible, contextual
help for the current step. Every overnight advance (Days 2–14) puts that
day's authored diary line in the blocking morning summary, and a completed
run's result screen adds the ending tier's short epilogue under its title.
Continuing a completed run opens the final result screen directly — there is
no post-game or free play.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move; facing selects the adjacent target cell |
| `2` | Cycle the selected seed (Turnip → Potato → Pumpkin → Turnip) |
| Space | Automatically till, plant, water, or harvest the faced farm cell |
| E | Interact with the targeted bed, shipping, truck, shop, market, or villager cell |
| Esc | Close the open modal |
| `I` / `B` / `C` | Open or close Bag / Almanac / Calendar when the world is available |
| `M` | Select the maximum quantity in Seed Shop or Shipping |
| `O` | Open Settings from Pause |

Every `2` press advances the selected seed, including the first press.
Bag, Almanac, and Calendar each gate movement and close with the same key;
pressed while Pause is up, the same keys open that app in the modal slot.
Settings edits Music and Sound from `0..10`, Window at `1080p` or `FULL`,
Tutorial Cards `ON` or `OFF`, and Language (English, 繁體中文,
日本語); `O` is handled only by Pause.

## Languages

Phoenix ships in English, Traditional Chinese (Taiwan wording, `zh_TW`), and
Japanese (`ja`). English source text is the translation key: every
player-facing string lives once in `assets/i18n/strings.csv`
(`keys,zh_TW,ja`), which Godot imports into the gitignored `*.translation`
files registered in `project.godot`. Text set on a Control is auto-translated;
formatted text calls `tr("... %d ...") % args` and translates its arguments.
Any new or changed player-facing string must land in the CSV with both
translations in the same commit; `tests/unit/test_localisation.gd` fails on a
missing translation, a placeholder mismatch, or an untranslated rules string.

The target diamond is hidden when the faced cell is outside the map. Facing
the farm bed cell `(12,7)`, shipping cell `(10,13)`, or truck cell `(22,9)`,
or the town shop cell `(7,4)`, market cell `(13,7)`, truck cell `(2,9)`, or
a villager, from an adjacent tile shows a contextual interaction hint (for
example `[E] Seed Shop` or `[E] Drive to town`).

- Green farm target = its next action can run.
- Red farm target = its next action is blocked; the hint explains why.
- Gold target = neutral/non-farm interaction targeting.
- Esc opens Controls when no blocking/closable UI owns the event.
- Phoenix includes lightweight placeholder music/SFX.

- Sato-san, Gen-san, and Hana stand at their authored town cells. Facing a
  resident and pressing E opens the dialogue panel for the daily talk and a
  crop gift; E on an ordinary non-interactable cell answers
  "Nothing to interact with."
- The first daily talk is worth 1 point, one gift per day adds 3 (5 for a
  favourite), and levels run Stranger, Friend at 12 points, Close Friend at
  18. From Day 12 the dialogue picks up market lines; the levels drive the
  result screen's villager cards and the Heart of the Harvest ending.

## Gameplay loop

`GameSession` is the single gameplay authority; every farming/economy command
returns a `GameRules.CommandCode` and the HUD renders the refreshed snapshot.
The social commands `talk_to` and `gift_crop` instead return a narrow result
dictionary (lines, points gained, gift reaction) that the dialogue panel
renders when a town resident is the E target.

1. **Farm.** Face a cell in the `6x5` farm patch and press Space to do its next
   action: till bare soil, plant the selected seed, water growing crops, or
   harvest mature crops. Hold Space to sweep across cells with one action;
   release before working the next stage.
2. **Budget the day.** Each action costs clock minutes and stamina; the day
   runs 06:00 to 22:00 and stamina caps at 20. The clock also advances
   passively while the world accepts input — 0.5 real seconds per game
   minute — so a focused day has a real-time budget, not only a stamina
   one. Watering costs 2 stamina, or 1 with the Efficient Can upgrade. Rain
   waters every crop for
   free, so the watering can is unneeded on rainy days.
3. **Drive to town.** Face the farm truck cell `(22,9)` and press E: the
   thirty-minute drive swaps the farm for the authored `16x12` town map and
   drops the player at its west truck arrival; the town truck `(2,9)` drives
   home for the same cost. The Seed Shop `(7,4)` sells Turnip, Potato, and
   Pumpkin seeds plus the 200G Efficient Can upgrade on the fourth row,
   which makes every watering cost 1 stamina for the rest of the run.
   Sato-san, Gen-san, and Hana stand at their own cells for the daily talk
   and one crop gift each, and the Harvest Market `(13,7)` ends the run on
   Day 14.
4. **Ship.** Face the farm shipping cell and press E to open the bin: deposit
   harvested crops into the pending shipment.
5. **Sleep.** Face the farm bed cell and press E to open a sleep confirmation.
   Sleeping pays out the pending shipment and grows watered crops. An
   immature crop withers after two consecutive nights without watering or
   rain; mature crops stay harvestable. Sleep restores stamina, rolls
   tomorrow's weather, and advances the day — then a morning summary with
   the new day's diary must be acknowledged before play resumes.

Anything that blocks world input pauses the passive clock: opening a panel
or dialogue, the sleep confirmation, Pause, the introduction, or the
morning summary all stop it, and so does switching away from the game
window. Resuming never banks the paused time — the clock picks up from
where it stopped, with no catch-up. At 22:00 farming actions are refused
as too late, but the day is not over: moving, driving the truck, shopping,
shipping crops, and sleeping all remain possible. The 0.5 s/min
rate is provisional tuning: an agent-operated native playtest
(`docs/superpowers/validation/2026-10-22-phoenix-passive-day-clock-native-playtest.md`)
observed the designed behavior end to end on a build that predates the
`Window.has_focus()` seeding, so its locked session exercised the
pre-seeding flag only — human subjective pacing and an unlocked-desktop
window-focus check remain open before the rate is final.

The season runs 14 days and the HUD's MARKET pill counts down to the Day 14
harvest market; a Bin pill shows tomorrow's payout while the shipping bin is
loaded. Only crops deposited in the shipping bin count toward the
farming result — harvested crops still carried in hand do not. On Day 14,
pressing E at the town Harvest Market finishes the run; sleeping that night
is the fallback route that finishes it instead. The result is one of three
encouraging endings — New Beginning, Promising Farmer, or Heart of the
Harvest — based on shipped value and village friendships: 150G of shipped
produce reaches Promising Farmer, and 300G plus at least one Close Friend
reaches Heart of the Harvest. Each ending keeps its title and adds one short
epilogue sentence. The exhaustive crop
economy, action-budget, and command-code tables are frozen in
`tests/unit/test_game_rules.gd`, `tests/unit/test_game_session.gd`, and
`tests/integration/test_gameplay_shell.gd`; those tests are the reference,
not this README.

## Presentation contract

The game renders at a single 1080p: a `1920x1080` base viewport with
`canvas_items` stretching, `keep` aspect, fractional scale, a minimum `960x540`
desktop window, and nearest texture filtering, so text draws at full
resolution. The world camera zooms by `WorldContract.CAMERA_ZOOM` (`3`): it
still frames a `640x360` world view and each art pixel is `3x3` screen pixels.
The windowed size is `1920x1080`, shrunk only when the screen cannot hold it.
Every UI surface draws natively on the 1920x1080 canvas — the gameplay HUD,
the title and result screens, the introduction, and every modal panel; no
surface is scaled up from a legacy canvas. The seven phone-app modals
(Pause, Settings, Bag, Almanac, Calendar, Sleep, and the morning summary)
build their content inside the shared code-built `PhoneFrame` chrome —
bezel, status-bar time, home indicator, app-header band, footer row, and one
content mount. Panels that show a header call `set_app_header()` and add
accessories through `app_header_accessory()`, add footer controls through
`footer_mount()`, and build body rows inside the content mount.

## World contract

| Contract | Value |
| --- | --- |
| Farm map | `24x20` logical cells |
| Town map | `16x12` logical cells |
| Ground diamond | `64x32` |
| Projection origin | `(768, 0)` |
| Player spawn | `(11.5, 8.5)` logical on the farm |
| Player half extent | `0.18` logical cells |
| Player speed | `96` projected pixels/second |
| Player center limits | `x in [0.18, 23.82]`, `y in [0.18, 19.82]` on the farm |
| Farm patch | `x=4..9`, `y=10..14` |
| House footprint | `x=11`, `y=4.5`, `w=2.75`, `h=2.75` logical |
| House bottom-center anchor | `(976, 336)` projected world |
| Farm truck | cell `(22,9)`, arrival `(21,10)` |
| Town truck | cell `(2,9)`, arrival `(3,8)` |
| Camera padding | `96` projected pixels above the map |
| Farm camera bounds | `Rect2(128, -96, 1408, 800)` |
| Town camera bounds | `Rect2(384, -96, 896, 544)` |

Each ground is an authored `TileMapLayer`; the town also carries a
`Backdrop` layer reusing the farm terrain atlas so the paved square sits
in a grass field and its road rows continue out of the map as a dirt
track. Scenery and player roots use
bottom-center ground-contact positions. Collision polygons are projected from
the logical house, forest/river/workbench, shipping, town station,
shop, cafe, market, villager, truck, and perimeter
geometry; Godot's `CharacterBody2D` supplies the
collision response. `Entities` is the single Y-sorted container, with shared
entity z-order and stable scene-tree tie order.

`WorldShell.load_map()` owns the only map swap: the same `Player`,
`Camera2D`, `GameHud`, and `GameSession` survive while the authored
`FarmMap`/`TownMap` scene is replaced underneath them. Location itself is
transient — `GameSession.state()` never persists it — so Continue always
resumes on the farm at the authored spawn even though `snapshot()` reports
the current map for live views.

## Current feature boundary

HPA-590 authored the 12x12 sprite-isometric shell: WASD movement, facing,
adjacent-cell targeting, authored farm/path ground, tree/building/perimeter
collision, bounded camera follow, and front/behind depth ordering. HPA-589
added the complete single-player farming/economy loop on that shell: tilling,
planting, watering, harvesting, seed shopping, shipping, sleeping, weather,
and the morning summary, with `GameRules`/`GameSession` as the gameplay
authority. The starting-farm expansion then replaced the `12x12` proof ground
with the locked `24x20` homestead — house, `6x5` farm, river/forest
boundaries, workbench yard, and an eastbound village road — using the approved
committed art.

Day 14 is the terminal day of the season. HPA-594 added the social systems —
the Sato-san, Gen-san, and Hana identities, the talk/gift relationship
rules above, dialogue and finale lines — with `VillagerRules`/`GameSession`
holding the frozen content and mutable relationship state. HPA-683 then
emptied the farm ahead of HPA-686's town social play, and HPA-686 landed it:
the authored `16x12` town map carries the three residents, the Seed Shop,
and the Harvest Market, with the truck driving between the maps for 30
minutes each way and every farm-owned command refusing to run while the
player is in town (and vice versa). The shell-owned `RainLayer` (`z_index = 6`)
draws the rain streaks across both maps above ground/soil/effects and below
`TargetHighlight` (`z_index = 10`), each map's `Entities` (`z_index = 20`), and
farm river ripples (`z_index = 7`); the river ripples stay farm-authored, and town
keeps the rainy HUD tint, rain audio, and river audio — river sound without
river visuals there is an accepted interim difference. HPA-597 finished the
content slice: the blocking introduction with contextual help, the Day 14
harvest market that ends the run (with sleeping as the fallback route),
shipping-bin deposits as the only farming-result scoring, three encouraging
endings, and Continue on a completed run reopening the result screen — there
is no post-game or free play. HPA-684 gives the opening Kenji's
lottery/Tokyo premise, a 14-line authored morning diary from Day 1 to Day 14,
and one epilogue per existing result tier; `ContentRules` owns that copy.

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

Live-World fixtures opt out of passive ticking with
`WorldShell.clock_running = false` — directly instantiated Worlds before
they enter the tree, AppRoot-launched Worlds before the blocking gate is
released — so test frames can never advance the clock nondeterministically;
clock arithmetic is verified by driving `WorldShell._advance_passive_clock()`
directly.

There is no screenshot-golden gate: UI changes are checked by eye in the
running game, and CI covers behavior through GUT, GdUnit4, and godot-e2e.

Local clean export:

```bash
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
```
