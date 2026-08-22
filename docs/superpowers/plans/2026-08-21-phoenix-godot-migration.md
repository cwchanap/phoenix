# Phoenix Godot Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Phoenix Phaser/Svelte/Tauri runtime with one Godot 4.7.1 world shell that preserves the authored isometric geometry, movement/targeting behavior, reachability, camera bounds, and front/behind rendering required by later gameplay ports.

**Architecture:** Godot owns rendering, input, `CharacterBody2D` collision response, camera, and Y-sort. `world_contract.gd` owns only the fixed HPA-590 shell constants, while `world_math.gd` owns pure projection/facing/target/footprint math; scenes remain the authored content and headless smoke verifies that they conform to the closed contract. The old JavaScript/TypeScript runtime remains only long enough to serve as an implementation reference during the port, then is deleted in this same PR; Git history is the later migration reference.

**Tech Stack:** Standard non-.NET Godot 4.7.1, statically typed GDScript, `TileMapLayer`, `CharacterBody2D`, `CollisionPolygon2D`, `Camera2D`, `Line2D`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-21-phoenix-godot-migration-design.md`

## Global Constraints

- Deliver HPA-590 in the existing single draft PR; do not split the ticket across PRs.
- Standard non-.NET Godot is pinned to `4.7.1`.
- One playable/runtime toolchain remains at merge: Godot only.
- Preserve the closed world contract from the spec; do not eyeball map/scenery/collision positions.
- Use `TileMapLayer` for the ground; if its isometric convention cannot be reconciled by transform/offset, stop for design review rather than silently changing projection.
- Use Godot-native collision response with projected logical geometry; do not port the old grid-axis collision resolver.
- Port behavioral test intent, not Phaser/Bun/browser implementation details such as the `8 ms` substep loop or `ProjectionAdapter` delegation.
- Do not add GUT, a debug HUD, `GameSession`, managers, service locators, registries, event buses, C#, GDExtension, a Tiled importer, or a compatibility bridge.
- Re-home all six committed proof PNG source sheets unchanged; HPA-590 renders only ground/player/scenery and later Godot slices consume soil/crop/villager assets. Do not port the Bun asset generator.
- Keep CI changes to the minimum required by the hard cutover: one pinned Godot headless verification path. HPA-590 does not add coverage/export infrastructure.
- HPA-599 owns packaged-release verification; HPA-590 needs headless import/runtime verification, not a release build.

## Target file structure

```text
project.godot
export_presets.cfg
assets/
  sprites/
    proof-tiles.png
    proof-player.png
    proof-scenery.png
    proof-soil.png
    proof-crops.png
    proof-villagers.png
scenes/
  world/
    world.tscn
    proof_ground_tileset.tres
  player/
    player.tscn
scripts/
  world/
    world_contract.gd
    world_math.gd
    world_shell.gd
  player/
    player_controller.gd
tests/
  headless/
    project_smoke.gd
    world_math_smoke.gd
    world_shell_smoke.gd
tools/
  verify-clean.sh
.github/workflows/ci.yml
README.md
CLAUDE.md
```

The final cutover deletes the old runnable/tooling tree (`src/`, `src-tauri/`, old TypeScript/Bun/Playwright tests and tools, package/config files) after all six PNG sources are re-homed and the Godot replacement checks are green. Historical `docs/superpowers/` planning documents stay in place.

---

### Task 1: Bootstrap Godot 4.7.1 and establish the replacement verification path

**Files:**
- Create: `project.godot`
- Create: `export_presets.cfg`
- Create: `tests/headless/project_smoke.gd`
- Create: `tools/verify-clean.sh`
- Modify: `.gitignore`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: a parseable Godot project, `godot` headless command contract, and `tools/verify-clean.sh` clean-archive entry point used by every later task.
- Temporarily preserves: existing Bun jobs/tooling until Task 6, so the branch has both old verification and the new Godot smoke while the port is in progress; only Godot survives the final task.

- [ ] **Step 1: Add a failing project smoke that pins the presentation/runtime contract**

Create `tests/headless/project_smoke.gd` as a direct `SceneTree` script. It must fail if the engine/project settings drift:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    var version := Engine.get_version_info()
    if version["major"] != 4 or version["minor"] != 7 or version["patch"] != 1:
        _fail("Phoenix requires Godot 4.7.1")
        return
    if ProjectSettings.get_setting("display/window/size/viewport_width") != 640:
        _fail("viewport width must be 640")
        return
    if ProjectSettings.get_setting("display/window/size/viewport_height") != 360:
        _fail("viewport height must be 360")
        return
    if ProjectSettings.get_setting("display/window/stretch/mode") != "viewport":
        _fail("stretch mode must be viewport")
        return
    if ProjectSettings.get_setting("display/window/stretch/aspect") != "keep":
        _fail("stretch aspect must be keep")
        return
    if ProjectSettings.get_setting("display/window/stretch/scale_mode") != "integer":
        _fail("stretch scale mode must be integer")
        return
    if ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") != 0:
        _fail("default CanvasItem texture filter must be nearest")
        return
    quit(0)
```

- [ ] **Step 2: Run it before the project exists and observe RED**

Run:

```bash
godot --headless --path . --script res://tests/headless/project_smoke.gd
```

Expected: non-zero because Phoenix is not yet a Godot project / required settings are absent.

- [ ] **Step 3: Add the minimum Godot project**

Create `project.godot` with:

- `application/config/name="Phoenix"`;
- `application/run/main_scene="res://scenes/world/world.tscn"` once the scene exists (Task 3 may add this line if Godot rejects a missing scene during Task 1);
- viewport `640x360`;
- `display/window/stretch/mode="viewport"`;
- `display/window/stretch/aspect="keep"`;
- `display/window/stretch/scale_mode="integer"`;
- `rendering/textures/canvas_textures/default_texture_filter=0` (nearest);
- `move_up`, `move_down`, `move_left`, `move_right` InputMap actions bound to W/S/A/D; and
- the project renderer kept simple for 2D desktop use.

Create a macOS `export_presets.cfg` with the Phoenix application identity, but do not add an export build gate yet.

Add `.godot/` to `.gitignore`; never commit imported cache.

- [ ] **Step 4: Add the initial clean-archive verifier**

Create `tools/verify-clean.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git archive --format=tar HEAD | tar -xf - -C "$tmp"
(
  cd "$tmp"
  godot --headless --path . --editor --quit
  godot --headless --path . --script res://tests/headless/project_smoke.gd
)
```

Later tasks append their smoke scripts to the same verifier; do not create parallel verification entry points.

- [ ] **Step 5: Add a temporary Godot smoke job alongside existing CI**

Add one Ubuntu job to `.github/workflows/ci.yml` using:

```yaml
- uses: chickensoft-games/setup-godot@v2.4.1
  with:
    version: 4.7.1
    use-dotnet: false
    include-templates: false
- run: godot --version
- run: ./tools/verify-clean.sh
```

Do not remove existing Bun/Tauri jobs yet; Task 6 performs the atomic toolchain cutover after the replacement is green. This temporary addition is only a migration safety gate, not the broad CI migration deferred by HPA-590.

- [ ] **Step 6: Verify GREEN**

Run:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/project_smoke.gd
./tools/verify-clean.sh
```

Expected: all commands exit `0`; `.godot/` is ignored.

- [ ] **Step 7: Commit**

```bash
git add project.godot export_presets.cfg .gitignore tests/headless/project_smoke.gd tools/verify-clean.sh .github/workflows/ci.yml
git commit -m "build: bootstrap Godot verification"
```

---

### Task 2: Port the closed world contract and pure isometric/facing/target behavior

**Files:**
- Create: `scripts/world/world_contract.gd`
- Create: `scripts/world/world_math.gd`
- Create: `tests/headless/world_math_smoke.gd`
- Modify: `tools/verify-clean.sh`
- Reference only: `src/game/core/isometric.ts`
- Reference only: `src/game/core/ProofWorld.ts`
- Reference only: `tests/game/isometric.test.ts`
- Reference only: `tests/game/ProofWorld.test.ts`

**Interfaces:**
- Produces: `WorldContract` constants and pure `WorldMath` helpers consumed by world authoring, collision, player targeting, and headless shell verification.
- `WorldMath` must not touch scene nodes, InputMap, physics, camera, or gameplay state.

- [ ] **Step 1: Write RED world-math smoke cases by porting the existing behavior**

`tests/headless/world_math_smoke.gd` must cover at least:

- fractional round-trip `(0,0)`, `(2.5,9.5)`, `(12,12)`;
- cell lookup at all map edges;
- existing one-nanounit boundary epsilon behavior;
- cell `(0,0)` diamond points `(384,0)`, `(416,16)`, `(384,32)`, `(352,16)`;
- horizontal-wins facing ties and idle facing retention;
- four target offsets from `(5.5,5.5)`;
- `null` target when facing out of bounds; and
- tree/building logical rectangles projecting to deterministic polygon points.

Use a local failure helper and exit non-zero on the first mismatch. Example RED assertion:

```gdscript
var projected := WorldMath.grid_to_world(Vector2(2.5, 9.5))
_expect_vec2(projected, Vector2(160.0, 192.0), "spawn projection")
```

- [ ] **Step 2: Run RED**

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
```

Expected: parse/load failure because `world_contract.gd` / `world_math.gd` do not exist.

- [ ] **Step 3: Implement `WorldContract` once**

Create `scripts/world/world_contract.gd` with the spec's exact constants, including:

```gdscript
class_name WorldContract
extends RefCounted

const MAP_SIZE := Vector2i(12, 12)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(384.0, 0.0)
const PLAYER_SPAWN := Vector2(2.5, 9.5)
const PLAYER_HALF_EXTENT := 0.18
const MOVE_SPEED := 96.0
const TREE_FOOTPRINT := Rect2(7.2, 4.2, 0.6, 0.6)
const TREE_ANCHOR := Vector2(480.0, 192.0)
const BUILDING_FOOTPRINT := Rect2(7.0, 7.0, 2.0, 2.0)
const BUILDING_ANCHOR := Vector2(384.0, 288.0)
const CAMERA_TOP_PADDING := 96.0
const CAMERA_BOUNDS := Rect2(0.0, -96.0, 768.0, 480.0)
```

Represent the farm/path cells with closed constants/helpers, not duplicated literals in `world.tscn` verification.

- [ ] **Step 4: Implement pure `WorldMath`**

Create `scripts/world/world_math.gd` with:

```gdscript
class_name WorldMath
extends RefCounted

enum Facing { UP, RIGHT, DOWN, LEFT }

const TARGET_OFFSETS := {
    Facing.UP: Vector2i(-1, -1),
    Facing.RIGHT: Vector2i(1, -1),
    Facing.DOWN: Vector2i(1, 1),
    Facing.LEFT: Vector2i(-1, 1),
}

static func grid_delta_to_world(delta: Vector2) -> Vector2:
    return Vector2(
        (delta.x - delta.y) * (WorldContract.TILE_SIZE.x / 2.0),
        (delta.x + delta.y) * (WorldContract.TILE_SIZE.y / 2.0),
    )

static func grid_to_world(point: Vector2) -> Vector2:
    return WorldContract.PROJECTION_ORIGIN + grid_delta_to_world(point)

static func world_to_grid(point: Vector2) -> Vector2:
    var offset := point - WorldContract.PROJECTION_ORIGIN
    return Vector2(
        offset.x / 64.0 + offset.y / 32.0,
        offset.y / 32.0 - offset.x / 64.0,
    )
```

Also implement `grid_cell_at_world`, `cell_diamond`, `facing_for_input`, `target_cell`, `footprint_to_polygon`, and a centered-player footprint polygon helper. Keep the boundary epsilon equivalent to the old cell lookup; do not copy parser/collision framework code.

- [ ] **Step 5: Verify GREEN and extend the clean verifier**

Append:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
```

to `tools/verify-clean.sh`, then run:

```bash
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
./tools/verify-clean.sh
```

Expected: all ported math/facing/target cases pass from a clean archive.

- [ ] **Step 6: Commit**

```bash
git add scripts/world/world_contract.gd scripts/world/world_math.gd tests/headless/world_math_smoke.gd tools/verify-clean.sh
git commit -m "feat: port isometric world contract"
```

---

### Task 3: Prove TileMapLayer alignment and author the fixed world/collision geometry

**Files:**
- Move/re-home: `src/assets/sprites/proof-tiles.png` -> `assets/sprites/proof-tiles.png`
- Move/re-home: `src/assets/sprites/proof-player.png` -> `assets/sprites/proof-player.png`
- Move/re-home: `src/assets/sprites/proof-scenery.png` -> `assets/sprites/proof-scenery.png`
- Move/re-home: `src/assets/sprites/proof-soil.png` -> `assets/sprites/proof-soil.png`
- Move/re-home: `src/assets/sprites/proof-crops.png` -> `assets/sprites/proof-crops.png`
- Move/re-home: `src/assets/sprites/proof-villagers.png` -> `assets/sprites/proof-villagers.png`
- Create: `scenes/world/proof_ground_tileset.tres`
- Create: `scenes/world/world.tscn`
- Create: `scripts/world/world_shell.gd`
- Create: `tests/headless/world_shell_smoke.gd`
- Modify: `project.godot`
- Modify: `tools/verify-clean.sh`
- Reference only: `src/game/phaser/loadProofMap.ts`
- Reference only: `tests/e2e/world.pw.ts`

**Interfaces:**
- Consumes: `WorldContract`, `WorldMath.footprint_to_polygon()`.
- Produces: the final `World` scene, authored ground layout, generated logical collision geometry, stable node names used by later player/depth tests, and all six proof PNG source sheets under the Godot asset tree.

- [ ] **Step 1: Re-home all six proof PNG source assets unchanged**

Move the existing committed PNG bytes to `assets/sprites/` without regenerating or editing them. HPA-590 immediately consumes only `proof-tiles.png`, `proof-player.png`, and `proof-scenery.png`; the soil/crop/villager sheets are intentionally unused until HPA-589/HPA-594.

Verify checksums before/after the move so the engine cutover does not silently change art bytes.

- [ ] **Step 2: Write the TileMap alignment RED checks before filling the map**

In `world_shell_smoke.gd`, load `res://scenes/world/world.tscn` and assert:

```gdscript
var ground := world.get_node("Ground") as TileMapLayer
var expected_center := WorldMath.grid_to_world(Vector2(0.5, 0.5))
_expect_vec2(ground.to_global(ground.map_to_local(Vector2i(0, 0))), expected_center, "cell 0,0 center")
if ground.local_to_map(ground.map_to_local(Vector2i(0, 0))) != Vector2i(0, 0):
    _fail("TileMapLayer 0,0 must round-trip")
```

Repeat for representative farm/path cells such as `(2,7)`, `(4,9)`, `(3,6)`, `(9,6)`.

- [ ] **Step 3: Run RED**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: failure because `world.tscn` does not exist.

- [ ] **Step 4: Create only enough TileMapLayer content to solve the origin spike**

Create a 3-tile isometric atlas resource from `proof-tiles.png` and a `Ground` `TileMapLayer`. Set its transform/position so Godot cell centers match `WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))`.

Run the alignment smoke immediately. Do **not** author all 144 ground cells until these representative cells pass. If no transform/offset can make the formulas agree, stop the task and return to the design rather than changing `WorldMath` to fit Godot accidentally.

- [ ] **Step 5: Fill the closed 12x12 ground pattern**

Author:

- default ground on every cell;
- farm tile on `x=2..4`, `y=7..9`;
- path tile on `x=3..9`, `y=6`.

Extend `world_shell_smoke.gd` to enumerate all 144 cells and assert the exact expected tile kind. This ports the old `loadProofMap.ts` ground contract without recreating a Tiled parser.

- [ ] **Step 6: Author scenery at exact bottom-center anchors**

Under `Entities` (`Node2D`, `y_sort_enabled=true`), add:

- `Tree` root at `(480,192)` with a `Sprite2D` child showing scenery frame 0, offset upward so the root is the bottom-center contact;
- `Building` root at `(384,288)` with a `Sprite2D` child showing scenery frame 1, likewise bottom-center anchored.

Use the committed 96x96 scenery frames; do not derive positions from texture rectangles.

- [ ] **Step 7: Generate collision polygons from logical rectangles**

`world_shell.gd` configures the collision root from `WorldContract`, using `WorldMath.footprint_to_polygon()` for tree/building and four projected outside bands around the logical 12x12 map for the perimeter.

Do not hand-edit polygon vertices in the editor. Extend smoke assertions to compare actual polygon points to `WorldMath` output and prove no extra collision footprints exist.

This task intentionally accepts Godot normal-based slide response later; here only geometry is pinned.

- [ ] **Step 8: Verify GREEN**

Append world shell smoke to `tools/verify-clean.sh` and run:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/verify-clean.sh
```

Expected: exact TileMap alignment, 144-cell pattern, anchors, logical collision polygons, and perimeter geometry pass; all six PNG sources import from the clean archive.

- [ ] **Step 9: Commit**

```bash
git add assets/sprites scenes/world scripts/world/world_shell.gd tests/headless/world_shell_smoke.gd project.godot tools/verify-clean.sh
git commit -m "feat: author Godot isometric world"
```

---

### Task 4: Add player movement, camera, and target highlight with behavioral parity checks

**Files:**
- Create: `scenes/player/player.tscn`
- Create: `scripts/player/player_controller.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`
- Reference only: `src/game/core/ProofWorld.ts`
- Reference only: `tests/game/ProofWorld.test.ts`
- Reference only: `tests/e2e/world.pw.ts`

**Interfaces:**
- Consumes: `assets/sprites/proof-player.png`, `WorldContract.PLAYER_SPAWN`, `MOVE_SPEED`, `PLAYER_HALF_EXTENT`, `CAMERA_BOUNDS`; `WorldMath` facing/target/collision polygon helpers.
- Produces: stable `Player`, `TargetHighlight`, and `Camera2D` behavior for HPA-589.

- [ ] **Step 1: Add RED headless behavior cases**

Extend `world_shell_smoke.gd` to instantiate the scene and prove:

- player root starts at `WorldMath.grid_to_world(Vector2(2.5,9.5)) == Vector2(160,192)`;
- player collision polygon equals the projected centered `0.18` logical half-extent;
- `InputMap` contains W/A/S/D movement actions;
- normalized diagonal requested velocity has the same magnitude as cardinal requested velocity (`96`);
- facing ties choose horizontal and idle retains facing;
- spawn targets are up `(1,8)`, right `(3,8)`, down `(3,10)`, left `(1,10)`;
- off-map facing hides the target;
- camera limits correspond to `Rect2(0,-96,768,480)`; and
- movement cannot cross the projected tree/building/perimeter geometry.

Port the *behavioral intent* of `ProofWorld.test.ts` and `world.pw.ts`; do not add the old 50 ms/8 ms subdivision algorithm.

- [ ] **Step 2: Run RED**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: failure because player/controller/camera/target nodes do not exist.

- [ ] **Step 3: Implement the player controller**

`player_controller.gd` should keep input sampling and movement small:

```gdscript
class_name PlayerController
extends CharacterBody2D

var facing: WorldMath.Facing = WorldMath.Facing.DOWN

func _physics_process(_delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    facing = WorldMath.facing_for_input(input_vector, facing)
    velocity = input_vector * WorldContract.MOVE_SPEED
    move_and_slide()
```

Update the four-frame player sprite from `facing`. Place the player's visual root at the ground-contact point; offset the 32x48 child sprite upward rather than using its center as the sort position.

The player collision polygon is generated from the `0.18` logical half extent; do not use the PNG's rectangle as collision.

- [ ] **Step 4: Add target highlight**

On each movement/facing update:

1. convert the player's projected ground-contact position through `WorldMath.world_to_grid()`;
2. call `WorldMath.target_cell()`;
3. set `TargetHighlight.points` from `WorldMath.cell_diamond()` when non-null; and
4. hide the line when null.

Do not store a second logical player position just for targeting.

- [ ] **Step 5: Add bounded Camera2D and minimum window size**

Add a child `Camera2D` with native smooth follow. Set limits from `WorldContract.CAMERA_BOUNDS` rather than copied literals. On world startup set:

```gdscript
get_window().min_size = Vector2i(640, 360)
```

Do not translate the old Phaser `0.12` coefficient; verify smooth follow manually and exact bounds headlessly.

- [ ] **Step 6: Port the important reachability checks**

Drive the player through fixed physics frames in the headless scene and assert:

- tree approach stops outside the tree polygon and a detour can pass it;
- building approach cannot penetrate and can slide around its corner;
- all four map edges keep the player's logical center within `[0.18,11.82]`; and
- crossing the `x=2..4`, `y=7..9` farm patch remains unobstructed.

An engine-level high-motion collision smoke should prove the production Godot path does not tunnel through the tree. Do not reproduce the old `8 ms` internal-substep assertion.

- [ ] **Step 7: Verify GREEN**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/verify-clean.sh
```

Expected: movement/facing/target/camera/collision/reachability cases pass.

- [ ] **Step 8: Commit**

```bash
git add scenes/player scenes/world/world.tscn scripts/player tests/headless/world_shell_smoke.gd
git commit -m "feat: add Godot world navigation shell"
```

---

### Task 5: Lock Y-sort setup and front/behind checkpoints

**Files:**
- Modify: `scenes/world/world.tscn`
- Modify: `tests/headless/world_shell_smoke.gd`
- Reference only: `src/game/core/isometric.ts`
- Reference only: `tests/game/isometric.test.ts`
- Reference only: `tests/e2e/world.pw.ts`

**Interfaces:**
- Consumes: bottom-center player/tree/building roots from Tasks 3-4.
- Produces: renderer ordering contract later crop/villager scenes can follow without a custom depth sorter.

- [ ] **Step 1: Add RED ordering-setup assertions**

Assert headlessly:

- `Entities.y_sort_enabled == true`;
- player/tree/building visual roots use the same `z_index`;
- the scene-tree order is stable for exact-Y ties; and
- moving the player to sampled positions gives player ground Y `< tree.y` then `> tree.y`, and likewise around building Y.

Use the historical checkpoints as source behavior: tree anchor Y `192`, building anchor Y `288`.

- [ ] **Step 2: Run RED if setup differs**

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

Expected: any wrong z-index/y-sort/ground-contact setup fails deterministically.

- [ ] **Step 3: Fix only scene ordering configuration**

Keep one Y-sorted `Entities` container, one shared entity z-index, and bottom-center root positions. Do not add a manual `sort_depth_entries` port.

- [ ] **Step 4: Run GREEN and perform one visual smoke**

Automated:

```bash
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
./tools/verify-clean.sh
```

Manual Godot playtest:

- walk above/below the tree;
- walk above/below the building;
- confirm the player visibly flips behind/in front with no flicker;
- confirm target diamond remains aligned while moving.

The manual check verifies rendering, not numeric geometry already covered headlessly.

- [ ] **Step 5: Commit**

```bash
git add scenes/world/world.tscn tests/headless/world_shell_smoke.gd
git commit -m "test: lock Godot depth ordering"
```

---

### Task 6: Perform the hard runtime/toolchain cutover and minimally replace handoff/CI

**Files:**
- Delete: old Phaser/Svelte/Vite runtime under `src/` after all six PNG sources are re-homed
- Delete: `src-tauri/`
- Delete: old TypeScript/Bun/Playwright tests, including `tests/config/`, `tests/game/`, `tests/e2e/`, while keeping `tests/headless/`
- Delete: `package.json`, `bun.lock`, `bunfig.toml`, `playwright.config.ts`, TypeScript/Vite/Svelte/ESLint/Prettier/Husky config files
- Delete: old JavaScript/TypeScript tools including `tools/generate-proof-assets.ts`, coverage tooling, and `tools/verify-clean-checkout.ts`
- Modify: `.github/workflows/ci.yml`
- Modify: `tools/verify-clean.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `.gitignore`
- Preserve: `assets/sprites/proof-*.png`
- Preserve: `docs/superpowers/` historical specs/plans

**Interfaces:**
- Produces: the merge-state repository contract: one Godot runtime/toolchain, one clean verifier, one minimal CI path, no dormant TypeScript rules implementation.
- HPA-589 consumes Git history/historical docs as behavior reference, not a checked-in `reference/` code tree.

- [ ] **Step 1: Strengthen the final verifier before deleting the old contract tests**

Ensure `tools/verify-clean.sh` runs exactly:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/project_smoke.gd
godot --headless --path . --script res://tests/headless/world_math_smoke.gd
godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
```

from a `git archive` of `HEAD`, exits on first failure, and cleans its temp directory with `trap`.

Run it once while the old runtime still exists. Expected: GREEN.

- [ ] **Step 2: Delete the old runtime and the entire dormant Bun/TypeScript toolchain**

Remove production web/Tauri code, framework-free TypeScript rules/world code, Playwright/unit/config suites, Bun package/coverage/lint/build tooling, and the procedural asset generator.

Do **not** move them to `reference/`. The project roadmap already establishes Git history as the reference, and HPA-589 explicitly reimplements behavior in GDScript rather than copying the previous architecture.

Keep all six re-homed PNG sources and historical planning docs. Do not perform unrelated repository restructuring.

- [ ] **Step 3: Replace only the obsolete runtime CI gates**

Rewrite `.github/workflows/ci.yml` to one minimal Godot verification job:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: chickensoft-games/setup-godot@v2.4.1
        with:
          version: 4.7.1
          use-dotnet: false
          include-templates: false
      - run: godot --version
      - run: ./tools/verify-clean.sh
```

No Bun, Playwright, Rust/Tauri, Codecov, export templates, or packaging job remains. Do not add replacement coverage/export matrices in HPA-590; this is only the minimum CI change required for the hard runtime swap.

- [ ] **Step 4: Rewrite README and CLAUDE as Godot-only handoff docs**

README must document:

- Godot 4.7.1 prerequisite;
- opening/running the project;
- WASD controls;
- 640x360 integer-scaled pixel-art contract;
- `./tools/verify-clean.sh`;
- exact HPA-590 world contract and current feature boundary; and
- that farming/economy/social/persistence are intentionally restored by later Godot tickets.

CLAUDE.md must describe:

- `world_contract.gd` vs `world_math.gd` vs scene ownership;
- `TileMapLayer` authored ground;
- CharacterBody2D engine collision with projected logical polygons;
- Y-sort/bottom-center convention;
- headless smoke workflow; and
- no JavaScript/Tauri runtime.

Do not keep historical Bun commands in current setup docs; history already preserves them.

- [ ] **Step 5: Verify no obsolete runtime/toolchain remains**

Run searches such as:

```bash
git ls-files | grep -E '(^src-tauri/|package.json|bun.lock|playwright|vite.config|\.svelte$)' && exit 1 || true
git grep -nE 'bun run|tauri:|Phaser|Svelte' -- README.md CLAUDE.md .github/workflows/ci.yml && exit 1 || true
```

Expected: no current runtime/config references. Historical docs under `docs/superpowers/` are allowed to describe the previous implementation.

Also verify all six Godot asset sources exist:

```bash
for asset in proof-tiles proof-player proof-scenery proof-soil proof-crops proof-villagers; do
  test -f "assets/sprites/${asset}.png"
done
```

- [ ] **Step 6: Run the final clean verification matrix**

```bash
./tools/verify-clean.sh
```

Expected: PASS from a git archive containing no Bun/npm/Rust/Tauri runtime dependency.

Also run:

```bash
git status --short
git diff --check main...HEAD
```

Expected: only intended tracked changes; no whitespace errors; no `.godot/` cache.

- [ ] **Step 7: Update the draft PR body and commit the cutover**

The PR body must retain the HPA-590 non-goals and state explicitly that:

- Godot is the only runnable runtime;
- collision geometry is preserved while response is Godot-native;
- old web/Tauri/TypeScript code is available in Git history only;
- CI was changed only as required for the runtime swap; and
- HPA-589 is the next gameplay-authority port.

Commit:

```bash
git add -A
git commit -m "refactor: complete Godot runtime cutover"
```

---

## Final self-review gate

Before marking the draft ready for implementation review:

- [ ] Confirm every closed world-contract value in the design appears once in `WorldContract` and is asserted by headless smoke where observable.
- [ ] Confirm scene geometry is derived/verified against `WorldContract`; no hand-authored collision vertices duplicate logical footprint numbers.
- [ ] Confirm `CharacterBody2D` uses Godot collision response and no port of `collision.ts` survives.
- [ ] Confirm the important historical behavioral cases are ported: projection round-trip/edges, facing tie+idle, four targets, off-map null, perimeter clamp intent, tree stop/detour, building corner route, farm traversal, camera limits, tree/building depth reversal.
- [ ] Confirm old-engine internals are not ported: Phaser lerp `0.12`, 8 ms substeps, `ProjectionAdapter`, Tiled parser, browser lifecycle hooks.
- [ ] Confirm all six proof PNG source sheets survive unchanged under `assets/sprites/` and the Bun generator is gone.
- [ ] Confirm final CI and clean verifier use Godot only and do not grow into coverage/export work.
- [ ] Confirm no second runnable or dormant TypeScript rules toolchain remains.
- [ ] Confirm HPA-590 remains one PR and no gameplay/economy/social/persistence work or unrelated cleanup leaked into scope.
