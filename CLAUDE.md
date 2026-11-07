# Phoenix handoff

## Runtime

Phoenix is a Godot 4.7.1 project using the standard non-.NET editor and
statically typed GDScript. Open the repository in Godot and run
`scenes/app/app.tscn`; WASD moves, `2` cycles the selected seed, Space
automatically tills, plants, waters, or harvests the faced farm cell, and E
interacts with the seed box, bed, or shipping bin.
There is no JavaScript or Tauri runtime in the current checkout.

- I/B/C open and close Bag, Almanac, and Calendar while the world is available;
  each panel gates movement and closes on its matching key, and the same keys
  also open that app while Pause is up.
- Every `2` press advances the selected seed; M
  chooses the maximum quantity in the Seed Box or Shipping; O opens Settings
  from Pause only.

## Architecture

- `scripts/world/world_contract.gd` is the single source for fixed HPA-590
  constants: map, projection, spawn, movement, footprints, anchors, farm/path
  cells, perimeter, and camera bounds. Do not duplicate those values in scene
  checks or gameplay code.
- `scripts/world/world_math.gd` is framework-free pure math for projection,
  inverse projection, cell lookup, diamonds, facing, targets, and projected
  logical footprints. It does not own nodes, input, physics, or gameplay state.
- `scenes/world/world.tscn` and `scripts/world/world_shell.gd` own the world
  shell: the one authored `Player` instance, the shell-owned
  `TargetHighlight`, and the `GameHud`.
- `scenes/world/farm_map.tscn` and `scripts/world/farm_map.gd` (`FarmMap`)
  own the authored farm map: the ground/water/path/decoration
  `TileMapLayer`s, `FarmSoil`, `FarmActionEffects`, `HomesteadAmbience`, the
  farm `StaticCollision` bodies, and the `Entities` Y-sort root. `FarmMap`
  derives its collision geometry, spawn, and camera bounds from
  `WorldContract` and `WorldMath` at `_ready()`.
- `WorldShell.load_map(MapId.FARM)` is the only map load/replace path: the
  shell binds `player.target_highlight` once before the first call, then
  each swap detaches the persistent `Player`, frees the old map, instances
  the new one as the first `World` child (runtime order `FarmMap`,
  `TargetHighlight`, `GameHud`), reparents the same `Player` under
  `FarmMap/Entities` at index 0 with `owner` restored so `World/%Player`
  keeps resolving, and places it via `player.enter_map()`. The swap is
  presentation-only — `GameSession`, the `Camera2D`, `GameHud`, and its
  signal connections survive untouched.
- `scripts/game/game_rules.gd` is the closed rules/content source: crop
  economy, action time/stamina budgets, day/pacing/stamina/weather constants
  including `DRY_NIGHTS_TO_WITHER`, payout math, and the `CommandCode` enum
  returned by every command. It is stateless.
- VillagerRules owns frozen HPA-595 content and pure relationship policy.
- `scripts/game/content_rules.gd` (`ContentRules`) owns the frozen HPA-597
  content policy: `TUTORIALS` is the one tutorial identity/copy/completion
  table, plus prompt relevance and the harvest result tiers/totals. It is
  stateless.
- `scripts/game/game_session.gd` is the only mutable gameplay authority. All
  commands go through it; existing farming/economy commands return `GameRules.CommandCode`;
  social commands `talk_to`/`gift_crop` return one narrow result Dictionary local to those methods; `advance_clock()` is the passive-clock command, returning bool and clamping at the cutoff with no commit; views read the immutable `snapshot()` dictionaries and never session internals.
- Farming preview and every farming guard/budget check route through
  `GameSession._cost_for()`; rules-owned effective cost changes (HPA-460) land
  at that one seam, never at call sites. The 200G Efficient Can is bought once
  via `buy_watering_can_upgrade()` at the seed box cell and persists as the
  `watering_can_upgraded` state/snapshot bit that `_cost_for()` reads.
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
- `FarmSoil` in `scenes/world/farm_map.tscn` holds the non-Y-sorted farm
  ground decals. `Entities` (scripted as `scripts/world/farm_view.gd`,
  `FarmView`, a `FarmMap` child) remains the one Y-sort owner and renders
  crop sprites from session snapshots; it owns no gameplay state. House,
  shop-stall, and player roots are bottom-center ground-contact positions
  with child sprites offset upward; they share a z-index and retain
  scene-tree order for exact-Y ties.
- `scripts/world/farm_action_effects.gd` (`FarmActionEffects`, a direct
  non-Y-sorted `FarmMap` child at z=5) renders transient farming success FX —
  tool overlays under the Player root, cell strips under itself, the harvest
  pop under `Entities`. It owns no gameplay state; sprites/tweens free on
  completion.
- `scripts/ui/game_hud.gd` and `scenes/ui/game_hud.tscn` own presentation and
  modal state only. The HUD emits request signals and renders snapshots; it
  never touches `GameSession`.
- HPA-681 City Pop HUD: `HudRoot` is native 1920x1080. `HudChrome`
  (`scripts/ui/hud_chrome.gd`, code-built as `HudRoot/Chrome`) draws the
  clock card, stamina pill, money/MARKET/Bin pills, the floating target
  prompt, the seed card, and the key pills; it owns no gameplay state and
  hides under modals. WorldShell picks the prompt per frame
  (`show_farming_prompt`/`show_blocked_prompt`/`show_interact_prompt`/
  `hide_prompt`) and passes the target cell centre in screen coordinates;
  GameHud owns the copy. `prompt_text()`, `prompt_icon()`, `action_icon()`,
  and `toast_text()` are the test seams. Only refusals (codes that play
  CANCEL_SFX) raise the red toast, the last `HudRoot` child so it shows over
  modals; successes show no HUD text.
- `UiStyle` is the City Pop design system: the mockup's tokens plus one
  hue per HUD widget (night clock card, mint stamina, pink money, blue
  market, green bin, per-crop seed card, coloured keycaps), rounded
  `card()` styleboxes with shadows, `gradient_surface()` (a rounded box
  masking a GradientTexture2D via `clip_children`; Godot does not nest
  clips, so keep gradient surfaces out of another clip parent), `keycap()`,
  `pin()`, and `SlantTag`. One font, M PLUS 1, with the Noto JP/TC
  fallbacks.
- HPA-682 City Pop menus: every non-HUD surface is a native 1920x1080
  code-built control tree on a root-plus-script `.tscn`, HudChrome-style —
  no authored contents with runtime stylers, no 3x canvas scale. The seven
  phone-app panels (Pause, Settings, Bag, Almanac, Calendar, Sleep, and the
  morning summary) mount their content in the shared `PhoneFrame`
  (`scripts/ui/phone_frame.gd`): bezel, status-bar time, home indicator,
  app-header band, footer row, and one content mount; panels configure
  header content and accessories, add footer controls, and build body
  rows in the mount.
  Shop, shipping, dialogue, title, result, and the intro overlay are native
  without the frame. `GameHud` remains the modal owner — no navigation
  framework or second session holder.
- DialoguePanel owns transient line/focus/gift-choice presentation only.
- OnboardingOverlay is code-built under `GameHud` (like DialoguePanel) and
  forwards opening/tutorial visibility through the existing
  `modal_state_changed` signal; it owns no gameplay state.
- GameHud.has_blocking_modal() remains the single world-input gate.
- `scripts/world/world_shell.gd` is the only production session holder and
  coordinator: it owns the `GameSession` instance, wires HUD signals to
  session commands, refreshes the active map's `FarmView`/ambience and
  `GameHud` from snapshots, and gates world input while a modal blocks.
  Do not create a second session holder.
- Hold-to-work is transient `WorldShell` state (`ACTION_HOLD_DWELL_SECONDS`,
  0.15s): a fresh press fires the target once and dwelling on eligible cells
  works one at a time. Each gesture locks the action from its starting farm
  tile, or from the first farm tile reached while walking in; release before
  using a newly resolved action on that same hold. While a gesture is locked,
  a farm tile resolving a different action previews neutral with no hint —
  the preview must never advertise work the hold will not do.
  Seed/focus/modal/day changes cancel the hold immediately.
- `WorldShell` runs the HPA-263 passive day clock: `_process` calls
  `_advance_passive_clock(minf(delta, CLOCK_DELTA_CLAMP))` only while
  `clock_running` and the window-focus flag hold — the flag seeds from
  `Window.has_focus()` at `_ready()`, is set only by
  `NOTIFICATION_WM_WINDOW_FOCUS_IN` while any focus-out flavor clears it,
  because application focus-in can arrive while the window is still
  hidden — and the helper
  itself gates on `_world_input_enabled`, so every blocking modal and
  window focus-out pauses the clock with no catch-up on resume. The
  per-frame delta clamp (0.1 s, mirroring `HomesteadAmbience.RAIN_DELTA_CLAMP`)
  keeps a hitched or stalled frame from banking game minutes. Whole minutes
  tick at `GameRules.REAL_SECONDS_PER_GAME_MINUTE` (0.5 s/min, the
  provisional tuning constant) into `GameSession.advance_clock()`, which
  clamps at the 22:00 cutoff — farming is refused there while movement,
  the seed box, shipping, and sleep stay open. `clock_running` is the
  deterministic test opt-out checked only at the `_process` call site;
  fixtures set it false so frames never tick.
- `scripts/player/player_controller.gd` owns input sampling for
  movement/facing/targeting only and a `CharacterBody2D` carrying the one
  `Camera2D`. `WorldShell` reparents it into the active map's `Entities`
  per load and calls `enter_map(spawn, camera_bounds)`, which applies the
  map's placement and camera limits and repaints the bound
  `target_highlight` immediately. `move_and_slide()` supplies Godot-native
  response against projected logical collision polygons; do not port the
  old grid-axis resolver.
- scripts/app/app_root.gd owns title/load/launch lifecycle and one concrete SaveRepository.
- Completed-run Continue routes straight to `ResultScreen`; the AppRoot
  result teardown removes the live World with `remove_child()` then
  `queue_free()` before presenting it.
- scripts/persistence/save_file.gd owns schema-v4 JSON transport only; older
  saves are intentionally incompatible and there is no migration.
- scripts/persistence/save_repository.gd writes user://phoenix-save.json with FileAccess.
- `scripts/ui/ui_settings.gd` owns the separate preference file and its
  Music/Sound `0..10`, Window `1080p/FULL`, Tutorial Cards `ON/OFF`,
  and Language `en/zh_TW/ja` settings (first run follows the OS locale);
  UI preferences never enter farm state.
- Localisation (HPA-713): English source text is the key in
  `assets/i18n/strings.csv` (`keys,zh_TW,ja`, Taiwan wording for zh_TW).
  Rules tables keep English; views translate. Plain text assigned to a
  Control auto-translates; formatted text uses `tr(template) % args` with each
  argument translated, and HUD re-renders on a language change. Every new or
  changed player-facing string goes into the CSV with both translations in
  the same commit. `tests/unit/test_localisation.gd` checks that every CSV
  row has both translations and that rules-table strings are translated; it
  does not detect UI strings missing from the CSV, so add those by hand.
  `UiStyle.font()` is M PLUS 1 with Noto Sans JP/TC fallbacks; M PLUS 1 and
  Noto Sans JP exclude `zh` and Noto Sans TC excludes `ja` in their import
  settings, so zh_TW Han text renders in Noto Sans TC and Japanese keeps
  Japanese glyph forms.
- GameSession.state()/restore_state() own mutable-state export and canonical restore; SessionStateValidator.state_error() owns all persisted-state validation; snapshot() remains the view read model.
- WorldShell remains the only live production session holder and synchronously writes once after successful overnight advancement.
- Player position/facing/camera/UI state remain transient/authored.
- HPA-599 delivered the release closeout: truthful farm preview/target tint
  and feedback table, code-built pause help with real Esc propagation, weather
  tint + ground shadows, placeholder audio with import-time music looping, the
  deterministic 5-Turnip/175G Promising GUT route, and pinned-SHA CI with
  import + unsigned macOS ZIP export; final docs live in README/CLAUDE.
- There is no screenshot-golden gate (removed 2026-11-01): UI changes are
  checked by eye in the running game; CI covers behavior only.

## Locked world contract

The logical map is `24x20` with `64x32` ground diamonds and projection origin
`(768, 0)`. Player spawn is `(11.5, 8.5)`, half extent is `0.18`, speed is `96`
projected pixels/second, and player centers stay in `[0.18, 23.82]` on x and
`[0.18, 19.82]` on y. The farm patch is `FARM_PATCH Rect2i(4, 10, 6, 5)`
(`x=4..9,y=10..14`, 30 cells); the farm-side path starts at `x=10` and the
workbench spur joins the main path at `x=12`.

The house footprint is `(11,4.5,2.75,2.75)` with derived bottom-center ground
anchor `(976,336)`, and the House node displays its `96x96` prop frame at
integer `2x` so the footprint's projected diamond is inscribed in the drawn
yard ellipse; the shop-stall footprint is `(15,7,1,2)` with anchor `(1008,400)`.
Interactable cells are the seed box `(17,9)`, bed `(12,7)`, shipping
`(10,13)` with footprint `(10.2,13.2,0.6,0.6)`, and the harvest market cell
`(19,10)` with footprint `(19.2,10.2,0.6,0.6)` and projected cell-center
anchor `(1056,480)`;
the world-shell smoke pins the cells, footprints, anchors, collisions, sprite
frames, and detour coverage. Blockers are the forest band `(0,0,24,2)`, the
west river `(0,0,2,20)`, the south river `(0,18,12,2)`, and the workbench
footprint `(13.25,16.25,0.5,0.5)` at cell `(13,16)`; the village sign stands
at `(21,8)`.
The retired `TREE_*`, `BUILDING_*`, `PATH_ROW`, and `path_cells()` constants
must not return as stale parallel representations.

Camera bounds are `Rect2(128,-96,1408,800)` with `96` pixels of top padding.
The project renders at a single 1080p: a `1920x1080` base viewport with
`canvas_items`/`keep` stretching, fractional scale, 2D transform pixel snap,
nearest filtering, and a minimum `960x540` window (`UiSettings`). The world
Camera2D zooms by `WorldContract.CAMERA_ZOOM` (`3`), so the camera still frames
a `640x360` world view and one art pixel is `3x3` screen pixels; a higher-res
art set changes only that constant. Every UI surface is native on the
1920x1080 canvas — the HPA-681 gameplay HUD plus the HPA-682 title, result,
introduction, and modal panels all draw at scale 1; the HPA-680 3x stopgap
and its `fit_legacy_*` helpers are gone.

## Current boundary

HPA-590 authored the rendered shell: authored ground, movement, facing,
target highlight, camera follow, collision, perimeter clamping, reachability,
and front/behind depth ordering. HPA-589 is done: farming, the crop economy,
the daily clock/stamina rhythm, weather, shipping, and the morning-summary
gate all exist as Godot gameplay, with `GameRules`/`GameSession` as the
authority and seed-box `(17,9)` / bed `(12,7)` / shipping `(10,13)` cells wired
into the shell. Day 14 is the terminal day of the season — no settlement or
advance happens past it. HPA-594 provides the social rules domain —
identities, relationship policy, dialogue and finale lines in
`VillagerRules` plus mutable relationship state in `GameSession` — but
HPA-683 removed the farm resident entities, their cells/footprints, and the
E-interaction ahead of HPA-686's town social play, so `talk_to`/`gift_crop`,
the relationship snapshot/save fields, and the dialogue/portrait UI stay
testable yet unreachable from the world; `interact()` on a former resident
cell returns `NOTHING_TO_INTERACT`. The same HPA-683 change made the shop
stall a self-service Seed Box (same cell, prices, rows, and modal behavior;
new prompt/panel/pause-help/tutorial copy) and cut the talk/gift tutorial
cards, leaving seven table-driven cards.
HPA-597 is done: the blocking introduction with contextual dismissible help,
the Day 14 harvest market, and the terminal result flow all shipped.
HPA-263 makes the day clock a real constraint: it ticks passively during
unblocked focused play at a provisional 0.5 s/min, pauses on modals and
focus-out, and clamps at the 22:00 farming cutoff. An agent-operated
native playtest (see below) observed ticking, modal freeze, the cutoff,
and late interactions end to end on the pre-seeding build; the rate stays
provisional because human subjective pacing and an unlocked-desktop focus
check remain open.
- Native evidence:
  `docs/superpowers/validation/2026-10-22-phoenix-passive-day-clock-native-playtest.md`
  is agent-operated, not human, evidence, recorded at `2119495` before the
  `has_focus()` flag seeding landed (`221e653`). Its locked-session console
  could not produce a real OS focus transition (`Window.has_focus()` never
  true), so under the current code that session could not tick at all: the
  run exercised the pre-seeding always-true flag, and the focus-seeded
  path is covered only by the deterministic GUT notification dispatch
  (`test_gameplay_shell.gd`); a human-run defocus check on an unlocked
  desktop and a human subjective pace check are still required before the
  0.5 s/min rate is final.
- HPA-598 owns serialization; HPA-594 defines no save schema.
- HPA-599 owns balance/polish/export.
- HPA-685 extracted the authored farm into `scenes/world/farm_map.tscn`
  (`FarmMap`) so `WorldShell.load_map()` can swap maps without touching the
  session, the one Player/Camera2D, or the HUD. HPA-686 remains the sole
  owner of town/travel/location semantics: `GameSession` will hold
  transient runtime location exposed in snapshots (not overnight
  `state()`/save), `WorldShell` will load maps in response to session
  snapshots without recursive refresh, and town rain will not reuse the
  farm-only ripple ambience.
- HPA-682 rebuilt every non-HUD surface natively — title, result, intro,
  Pause, Settings, Bag, Almanac, Calendar, Sleep, morning summary, Shop,
  Shipping, and Dialogue — with the seven phone apps on the shared
  `PhoneFrame`; HPA-684 owns diary/result copy and HPA-687 new art.
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
python3 tools/check_audio_sources.py
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
- Nearest filtering is mandatory; world art scales by the integer
  `WorldContract.CAMERA_ZOOM` on the 1080p canvas.
- World terrain and props derive from the two committed
  `starting-farm-*-source.webp` sheets; the sheets stay tracked as source
  provenance and approved art is never regenerated.
- The proof player/crops/soil/shadow/scenery sprites remain live entity
  textures; the villager sprite sheets stay committed but no world entity
  uses them until social play returns. Only provably unreferenced proof
  ground resources were deleted.

Audio generation convention
- New Phoenix audio assets are generated through the ElevenLabs MCP
  sound-effects tool `eleven_text_to_sound_v2`, not hand-written synthesis
  scripts. The committed WAV is the artifact of record; record the prompt,
  model id, plan tier/license terms, and any loop post-processing in
  `assets/audio/README.md`. Byte-identical regeneration gates do not apply to
  MCP-generated audio.
