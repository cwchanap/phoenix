# Phoenix handoff

## Runtime

Phoenix is a Godot 4.7.1 project using the standard non-.NET editor and
statically typed GDScript. Open the repository in Godot and run
`scenes/app/app.tscn`; WASD moves, `1`/`2`/`3`/`4` select the farming
action, Space uses it, and E interacts with the shop, bed, or shipping bin.
There is no JavaScript or Tauri runtime in the current checkout.

- E interacts with villagers as well as shop/bed/shipping.
- I/B/C open and close Bag, Almanac, and Calendar while the world is available;
  each panel gates movement and closes on its matching key.
- Repeated `2` cycles the selected seed after the initial Seeds selection; M
  chooses the maximum quantity in Shop or Shipping; O opens Settings from
  Pause only.

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
  snapshots; it owns no gameplay state. House, shop-stall, villager, and
  player roots are bottom-center ground-contact positions with child sprites
  offset upward; they share a z-index and retain scene-tree order for exact-Y
  ties.
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
- scripts/persistence/save_file.gd owns schema-v2 JSON transport only; older
  saves are intentionally incompatible and there is no migration.
- scripts/persistence/save_repository.gd writes user://phoenix-save.json with FileAccess.
- `scripts/ui/ui_settings.gd` owns the separate preference file and its
  Music/Sound `0..10`, Window `1x/2x/3x/4x/FULL`, and Tutorial Cards `ON/OFF`
  settings; UI preferences never enter farm state.
- GameSession.state()/state_error()/restore_state() own mutable-state export, all persisted-state validation, and canonical restore; snapshot() remains the view read model.
- WorldShell remains the only live production session holder and synchronously writes once after successful overnight advancement.
- Player position/facing/camera/UI state remain transient/authored.
- HPA-599 delivered the release closeout: truthful farm preview/target tint
  and feedback table, code-built pause help with real Esc propagation, weather
  tint + ground shadows, placeholder audio with import-time music looping, the
  deterministic 5-Turnip/175G Promising GUT route, and pinned-SHA CI with
  import + unsigned macOS ZIP export; final docs live in README/CLAUDE.
- The UI redesign closeout keeps browser/mock references as manual design
  oracles and Godot production goldens as the automated oracle. Native macOS
  `./tools/verify-visual.sh` captures all 14 approved states, nearest 2x
  evidence, and masked diffs; Linux CI remains behavior/E2E-only.

## Locked world contract

The logical map is `24x20` with `64x32` ground diamonds and projection origin
`(768, 0)`. Player spawn is `(11.5, 8.5)`, half extent is `0.18`, speed is `96`
projected pixels/second, and player centers stay in `[0.18, 23.82]` on x and
`[0.18, 19.82]` on y. The farm patch is `FARM_PATCH Rect2i(4, 10, 6, 5)`
(`x=4..9,y=10..14`, 30 cells); the farm-side path starts at `x=10` and the
workbench spur joins the main path at `x=12`.

The house footprint is `(10,4,4,3)` with derived bottom-center ground anchor
`(976,336)`, and the House node displays its `96x96` prop frame at `2.5x` so
the drawn yard ellipse covers the footprint's projected diamond; the
shop-stall footprint is `(15,7,1,2)` with anchor `(1008,400)`.
Interactable cells are shop `(17,9)`, bed `(12,7)`, shipping `(10,13)` with
footprint `(10.2,13.2,0.6,0.6)`, and the harvest market cell `(19,10)` with
footprint `(19.2,10.2,0.6,0.6)` and projected cell-center anchor `(1056,480)`;
the world-shell smoke pins the cells, footprints, anchors, collisions, sprite
frames, and detour coverage. Villagers stand at `(16,8)`, `(18,7)`, and
`(17,11)`. Blockers are the forest band `(0,0,24,2)`, the west river
`(0,0,2,20)`, the south river `(0,18,12,2)`, and the workbench footprint
`(13.25,16.25,0.5,0.5)` at cell `(13,16)`; the village sign stands at `(21,8)`.
The retired `TREE_*`, `BUILDING_*`, `PATH_ROW`, and `path_cells()` constants
must not return as stale parallel representations.

Camera bounds are `Rect2(128,-96,1408,800)` with `96` pixels of top padding.
The project uses a `640x360` viewport, `viewport`/`keep` stretching, integer
scale, nearest filtering, and a minimum `640x360` window.

## Current boundary

HPA-590 authored the rendered shell: authored ground, movement, facing,
target highlight, camera follow, collision, perimeter clamping, reachability,
and front/behind depth ordering. HPA-589 is done: farming, the crop economy,
the daily clock/stamina rhythm, weather, shipping, and the morning-summary
gate all exist as Godot gameplay, with `GameRules`/`GameSession` as the
authority and shop `(17,9)` / bed `(12,7)` / shipping `(10,13)` cells wired
into the shell. Day 14 is the terminal day of the season — no settlement or
advance happens past it. HPA-594 now provides villagers and social behavior.
HPA-597 is done: the blocking introduction with contextual dismissible help,
the Day 14 harvest market, and the terminal result flow all shipped.
- HPA-598 owns serialization; HPA-594 defines no save schema.
- HPA-599 owns balance/polish/export.
- The starting-farm expansion replaced the HPA-590 `12x12` proof ground with
  the locked `24x20` homestead — house, `6x5` farm, river/forest, workbench
  yard, and eastbound village road — rendered from the approved committed art;
  the locked contract above and
  `docs/superpowers/specs/2026-09-07-phoenix-starting-farm-expansion-design.md`
  are the reference.

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

## Release gates

A release candidate passes four automated gates: the GUT/headless verifier
above, the GdUnit4 lane, the godot-e2e lane, and the import + unsigned macOS
export. CI wraps the two GdUnit4 lanes in `xvfb-run`; locally on macOS run
them without the wrapper after `./tools/bootstrap-gdunit.sh`:

```bash
./tools/verify-clean.sh
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/gdunit -c
GODOT_BIN=$(command -v godot) ./addons/gdUnit4/runtest.sh -a tests/e2e -c
godot --headless --path . --import
mkdir -p build
godot --headless --path . --export-release "macOS" build/Phoenix.zip
unzip -l build/Phoenix.zip | grep -F "Phoenix.app/Contents/MacOS/Phoenix"
```

Native macOS visual acceptance runs separately with
`./tools/verify-visual.sh`; it compares raw `640x360` captures to the approved
production goldens, while `tests/visual/design-reference/` remains a manual
side-by-side reference set. CI cannot bless goldens. Result reference 14 keeps
the source mock's clipped vertical spacing; the production fit intentionally
keeps the wreath/footer visible and clips the portrait as approved.

The deterministic Promising route is pinned by
`test_representative_reinvestment_route_reaches_promising()`:
five Turnips (3 starter + 2 reinvested from the first 105G shipment) settle
175G and reach the `promising_farmer` tier. Do not retune balance without
updating that route and its exact-value assertions in the same commit.

Sprite-isometric art contract
- Ground diamonds are 64×32.
- Entity roots are bottom-center ground contacts.
- Visible sprites offset upward from the root.
- Shadows are child sprites on the ground plane, never Y-sort roots.
- Entities remains the sole Y-sort owner for foreground/occluding world objects.
- Nearest filtering and integer scaling remain mandatory.
- World terrain and props derive from the two committed
  `starting-farm-*-source.webp` sheets; the sheets stay tracked as source
  provenance and approved art is never regenerated.
- The proof player/crops/villagers/soil/shadow/scenery sprites remain live
  entity textures; only provably unreferenced proof ground resources were
  deleted.
