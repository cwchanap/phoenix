# Phoenix Godot Migration Design (HPA-590)

**Status:** Approved for implementation planning

**Date:** 2026-08-21

## Source of truth

HPA-590 is the first implementation slice after the accepted Godot cutover. The Phoenix Linear project description defines the final runtime direction: standard non-.NET Godot 4.7.1, statically typed GDScript, `TileMapLayer` sprite-isometric rendering, and one runtime only.

The previous Phaser/Tauri implementation is a behavioral reference available through Git history and the historical planning documents. It is not a runtime dependency, compatibility target, or architecture to preserve.

Within the Godot implementation, committed scenes/resources remain the authored world. Fixed shell invariants that more than one node/test needs live once in `scripts/world/world_contract.gd`; the headless smoke verifies that the authored scene conforms to those constants. This is a small closed contract, not a content registry or gameplay service.

## Outcome

A clean checkout opens as a Godot project and provides the playable world shell required by later gameplay slices:

- sprite-isometric map rendering;
- WASD movement;
- collision around authored scenery and the map perimeter;
- facing updates;
- bounded camera follow;
- target-cell highlight; and
- correct front/behind rendering.

No farming rules, economy, social systems, persistence, or finale content are introduced.

## Decisions

- Use standard non-.NET Godot 4.7.1.
- Use statically typed GDScript.
- Use Godot scenes/resources for authored world content and `world_contract.gd` for the small set of fixed shell invariants.
- Re-home all six committed proof PNG sheets unchanged under the Godot asset tree. HPA-590 renders ground/player/scenery; soil/crop/villager sheets are retained only as source assets for their later Godot slices. Do not port `tools/generate-proof-assets.ts`.
- Do not import the old Tiled JSON map or recreate `loadProofMap.ts`.
- Preserve the existing logical projection, authored positions, reachable routes, target behavior, and visual front/behind behavior.
- Replace Phaser-owned rendering/input with Godot-native nodes.
- Use engine-native `CharacterBody2D` collision response; do not port the old grid-axis collision resolver.
- Do not preserve a second runnable web runtime or a dormant JavaScript/TypeScript toolchain after HPA-590 merges.
- Do not invent `GameSession`, registries, service layers, event buses, or plugin abstractions. HPA-589 owns gameplay authority.
- Change CI only as required to remove obsolete web/Tauri gates and establish one Godot headless smoke path; broader CI, coverage, and export work remain outside HPA-590.

## Closed world contract

`world_contract.gd` owns these fixed HPA-590 values:

| Property | Value |
| --- | --- |
| Map size | `12x12` logical cells |
| Ground diamond | `64x32` |
| Projection origin | `(384, 0)` |
| Player spawn | `(2.5, 9.5)` logical |
| Player half extent | `0.18` logical cells |
| Player move speed | `96` projected pixels/second |
| Player center limits | `x,y in [0.18, 11.82]` |
| Farm patch | `x=2..4`, `y=7..9` |
| Path row | `x=3..9`, `y=6` |
| Tree footprint | `x=7.2`, `y=4.2`, `w=0.6`, `h=0.6` logical |
| Tree sprite bottom-center anchor | `(480, 192)` projected world |
| Building footprint | `x=7`, `y=7`, `w=2`, `h=2` logical |
| Building sprite bottom-center anchor | `(384, 288)` projected world |
| Camera projected bounds padding | `96` pixels above projected map |
| Camera projected bounds | `Rect2(0, -96, 768, 480)` |
| Logical viewport | `640x360` |
| Stretch mode/aspect/scale | `viewport` / `keep` / integer scale |
| Minimum desktop window | `640x360` |
| Texture filtering | nearest |

The previous Phaser follow lerp value `0.12` is **not** a Godot contract: Phaser and `Camera2D` smoothing use different parameters. HPA-590 preserves smooth bounded follow, not an engine-specific coefficient.

Shipping-bin, shop/bed interaction cells, and villagers are not authored in this shell. HPA-589 and HPA-594 restore those feature-specific world objects from the historical behavior reference.

## Isometric world math

A small framework-free typed GDScript module, `scripts/world/world_math.gd`, owns the reusable shell math:

- grid-to-world conversion;
- world-to-grid conversion;
- grid-cell lookup with the existing boundary epsilon policy;
- projected cell-diamond vertices;
- grid-delta projection;
- `Facing` enum;
- the four target offsets;
- dominant-axis facing selection; and
- logical footprint projection.

The projection stays:

```text
worldX = 384 + (gridX - gridY) * 32
worldY =       (gridX + gridY) * 16
```

and the inverse stays:

```text
gridX = (worldX - 384) / 64 + worldY / 32
gridY = worldY / 32 - (worldX - 384) / 64
```

Target lookup floors the continuous logical player position, applies the facing offset, and returns `null` when the target leaves the 12x12 map. Off-map targets are hidden, never clamped.

Facing policy stays:

- dominant screen axis determines facing;
- horizontal wins ties;
- idle retains the previous facing.

`CharacterBody2D` executes movement; it does not own projection or target rules.

## TileMapLayer alignment

Godot's isometric cell-origin convention is an implementation risk, so HPA-590 proves it before authoring the full map.

The first world test must establish a `TileMapLayer` transform/offset such that known cell centers agree with `world_math.gd`, including cell `(0,0)` and representative farm/path cells. `local_to_map(map_to_local(cell))` must round-trip those cells. The accepted implementation keeps `TileMapLayer`; if its transform cannot be reconciled with the closed projection contract, implementation stops for design review instead of silently changing projection or falling back to a second renderer.

## Collision model

The previous implementation stored obstacle footprints as axis-aligned logical rectangles and resolved movement per grid axis. HPA-590 intentionally does **not** port that resolver.

Instead:

- tree and building collision polygons are generated from the closed logical rectangles using `world_math.gd` projection helpers;
- the player's collision polygon is generated from the `0.18` logical half extent around its ground-contact point;
- map-perimeter collision is generated from the 12x12 logical boundary rather than from sprite image bounds; and
- `CharacterBody2D.move_and_slide()` supplies Godot-native collision response.

This preserves collision **geometry and reachability contracts**, while accepting that Godot's normal-based slide response is not byte-for-byte equivalent to the previous grid-axis resolver. The migration is accepted only if the ported route checks prove the player still cannot enter the authored tree/building footprints, cannot leave the map, can slide around the building corner, and can traverse the farm/path routes needed by later slices.

The old browser-specific `50 ms` frame cap and `8 ms` collision substeps are implementation details and are not ported. Their behavioral purpose—no obstacle tunneling—is preserved by an engine-level collision smoke under the Godot physics loop.

## World scene structure

Keep the node graph small:

```text
World (Node2D)
├── Ground (TileMapLayer)
├── StaticCollision (StaticBody2D)
│   ├── TreeCollision (CollisionPolygon2D)
│   ├── BuildingCollision (CollisionPolygon2D)
│   └── Perimeter collision shapes
├── Entities (Node2D, y_sort_enabled=true)
│   ├── Tree (Node2D + Sprite2D)
│   ├── Building (Node2D + Sprite2D)
│   └── Player (CharacterBody2D)
│       ├── Sprite2D
│       ├── CollisionPolygon2D
│       └── Camera2D
└── TargetHighlight (Line2D)
```

The collision root stays outside the Y-sorted visual entity container. Tree/building/player roots use bottom-center ground-contact positions; their child sprites are offset upward so Y-sort uses the ground contact rather than texture centers.

## Depth ordering

`Entities` uses Godot Y-sorting. All sorted entities remain on the same `z_index`; the authored scene-tree order supplies deterministic tie order when ground-contact Y values match.

The historical renderer sorted by projected ground Y and used stable object order only for exact ties. HPA-590 preserves that observable behavior through Godot's Y-sort instead of recreating a manual sorter.

Headless verification samples the player above and below each tall object and asserts:

- the Y-sort container is enabled;
- the entities share the same `z_index`;
- the player's ground-contact Y is lower than the scenery anchor at the behind sample and higher at the in-front sample; and
- scene-tree order remains deterministic for equal-Y ties.

One short visual playtest still confirms the rendered transition has no flicker; the rest is deterministic.

## Camera and presentation

`Camera2D` follows the player's projected ground-contact point and is constrained to the closed projected bounds `Rect2(0, -96, 768, 480)`. Smooth follow is preserved using native `Camera2D` behavior; no attempt is made to translate Phaser's `0.12` lerp coefficient literally.

Project settings pin the pixel-art presentation:

- viewport width `640`;
- viewport height `360`;
- stretch mode `viewport`;
- stretch aspect `keep`;
- stretch scale mode `integer`;
- minimum desktop window `640x360`; and
- nearest texture filtering.

This replaces the old Svelte `StageFrame`; no Godot debug HUD is introduced.

## Runtime and toolchain cutover

The final HPA-590 branch has one executable/toolchain path: Godot.

After the Godot shell and replacement verification are green, the same PR deletes only the obsolete runnable/runtime/tooling surface required by the hard cutover, including:

- Phaser/Svelte/Vite application code;
- `src-tauri/` and Tauri configuration;
- framework-free TypeScript runtime code, including the old `GameSession`/`ProofWorld` implementation;
- Playwright/browser E2E;
- Bun unit/config tests and coverage tooling;
- JavaScript package/lock/config files; and
- JavaScript asset-generation and clean-checkout scripts.

This is not a general repository-cleanup pass. Unrelated files/history are not reorganized.

Do **not** move removed code into a `reference/` directory. Git history and the historical specs/plans are the reference for HPA-589/HPA-594/HPA-598. Keeping an unplugged TypeScript rules tree would leave a second maintenance/toolchain burden without a production consumer.

All six committed proof PNG source sheets are re-homed under `assets/sprites/` before `src/` is removed. The current shell consumes ground/player/scenery; soil/crop/villager sheets remain unused source assets until their owning Godot slices. Generated import cache under `.godot/` is not committed.

## Verification strategy

HPA-590 uses direct headless GDScript assertions, not GUT.

The source behavior to port is explicitly taken from:

- `tests/game/isometric.test.ts` for projection round-trips, edge cell lookup, boundary epsilon, cell diamonds, and depth tie intent;
- `tests/game/ProofWorld.test.ts` for normalized input, facing tie policy, idle-facing retention, map bounds, collision geometry intent, target offsets, off-map target behavior, and route reachability; and
- `tests/e2e/world.pw.ts` for tree stop/detour, building-corner routing, perimeter target hiding, camera bounds, and tree/building front/behind checkpoints.

Port **behavioral cases**, not old-engine internals. In particular, do not reproduce the `8 ms` substep test, `ProjectionAdapter` delegation test, Phaser lifecycle hooks, or browser-only timing helpers.

The replacement verification matrix is deliberately smaller than the old web/Tauri CI matrix:

1. `godot --version` reports 4.7.1.
2. Headless editor/import exits successfully with no parse/import errors.
3. `tests/headless/world_math_smoke.gd` asserts projection/facing/target contracts.
4. `tests/headless/world_shell_smoke.gd` loads the main scene and asserts authored scene constants, TileMap alignment, collision geometry, perimeter behavior, camera bounds, and Y-sort setup/checkpoints.
5. A short manual Godot playtest confirms WASD feel, camera follow, target drawing, and visual front/behind transitions.

`tools/verify-clean.sh` runs the deterministic checks from a `git archive` of `HEAD`, preserving the existing clean-checkout guarantee without Bun. CI calls that same verifier.

CI uses a pinned Godot setup action with standard Godot `4.7.1`, non-.NET mode, and no floating `latest` engine version. This is the minimum CI replacement required by the runtime cutover, not the broader CI migration explicitly deferred by HPA-590. HPA-590 does not require coverage infrastructure, export templates, or a packaged build; HPA-599 owns release packaging verification.

## Risks and mitigations

### TileMapLayer isometric origin

**Risk:** Godot's isometric cell-center convention may not initially align with the historical `(384,0)` top-corner projection.

**Mitigation:** prove known cell centers and round-trips before authoring the whole layer; reconcile using the TileMapLayer transform/offset without changing the closed projection formula.

### Engine collision response differs

**Risk:** normal-based sliding can produce a slightly different path than the former grid-axis resolver.

**Mitigation:** generate identical projected footprint geometry and port the route/reachability assertions that matter to later farm/shop/social stances. Exact intermediate floating-point coordinates are not compatibility requirements.

### Godot CI installation

**Risk:** the new repository has no Bun fallback if the pinned Godot install or headless invocation is wrong.

**Mitigation:** establish and run the 4.7.1 headless verifier before deleting the old CI/toolchain, then make the minimal cutover atomically in the same PR.

### Asset import

**Risk:** reusing the six PNGs while deleting the Bun generator could accidentally change filtering or rely on uncommitted import cache.

**Mitigation:** re-home all six PNG source files unchanged, set nearest filtering in project settings, ignore `.godot/`, and prove a clean archive imports successfully.

## Delivery

HPA-590 remains **one PR**, matching the Phoenix project delivery model. Reviewability comes from small conventional commits and task checkpoints inside that PR, not from splitting one Linear issue across multiple PRs.

The same draft PR that carries this design/plan becomes the implementation PR after review.

## Non-goals

- farming;
- crops;
- economy;
- villagers;
- dialogue;
- persistence;
- save migration;
- browser packaging;
- Tauri bridge;
- C#;
- GDExtension;
- backend/database;
- GUT;
- broad CI/coverage/export expansion;
- unrelated repository cleanup;
- a second renderer/runtime;
- a compatibility/reference source tree; and
- generic framework abstractions.
