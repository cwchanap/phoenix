# HPA-863 — Farm map v2 and refreshed world art: design specification

**Status:** Proposed; documentation-only draft PR. No gameplay implementation or verification is claimed here.
**Issue:** https://linear.app/cwchanap/issue/HPA-863/build-the-bigger-farm-map-and-show-the-refreshed-world-art
**Repository/base inspected:** cwchanap/phoenix, main b14a3756e54c9949ca437c9f9ecfe0598140dd35 (2026-11-21 local).
**Dependency status:** HPA-861 (art) and HPA-743 (contact-first interaction/backdrop) are Done. There are no open Phoenix PRs at planning time.
**Delivery:** One implementation PR for HPA-863: extend this draft PR, rather than opening another PR. All new art was scoped to HPA-861; HPA-863 only integrates its committed outputs.

## Outcome and visual source of truth

Expand the authored farm from 24×20 to **48×40 logical cells** at the existing 64×32 isometric grid. Preserve the short daily gameplay loop while replacing the raised, visibly repeating terrain and grass-island props with the continuous world shown in the approved Linear mockup.

Treat the following HPA-863 attachments as the approved design inputs, **not runtime data**:
- farm-map-v2-plan.png: numbered 48×40 top-down arrangement.
- farm-map-v2-layout.json: terrain regions, 60 object records, fence positions, footprints, zone names and blocking/decorative intent.
- farm-map-v2-blockout-*.png: expected farm size and front-door, field and storehouse-yard camera compositions.
- world-mockup-vs-game.jpg: target grass, paths, building grounding, soil, crop and HUD composition.

HPA-861 has committed new cutouts, candidate terrain, soil, crops and review scenes under assets/sprites/hpa-861-review. Its README explicitly calls those textures **candidates**, warns about multi-material junctions, cutout fringes and unverified Godot anchors, and says the previews are not native-render proof. HPA-863 must run native visual validation before accepting an asset. Any truly missing/rejected newly generated art goes back to a **separate art ticket**; do not mix image generation or SFX production into this implementation.

## Non-negotiable gameplay and architecture boundaries

- Standard Godot 4.7.1, typed GDScript, existing GameSession, WorldShell, FarmMap, TownMap, FarmView and GameMap. **No new renderer, content registry, runtime JSON importer, shader framework, persistence migration or second PR.**
- Keep 1920×1080 UI and the existing 3× world-camera zoom (640×360 world view). Keep the 64×32 projection, nearest filtering, bottom-centre ground contact, ground-plane shadows and Entities as the only Y-sort owner.
- **WorldContract is authoritative** for farm map dimensions, spawn, farm patch, interactable cells and regions, object footprints/anchors, blocker/fence geometry, camera bounds and backdrop rules. Author the visible ground and props in the existing Godot scene/TileSet resources; do not introduce a competing layout lookup in WorldShell, FarmView or GameSession.
- **TownContract and the town layout do not change.** Only town terrain, backdrop, art frames and optional edge decorations are refreshed.
- Farm E actions remain **bed/door, shipping bin and truck**. The truck arrival is a spawn position, not a fourth E command. The approved layout also marks the 30-cell plot as interactive terrain; that remains **Space-based farming**, not a new E action. Shrine, lots, board, greenhouse, orchard, fallow plots and pier are scenery only.
- Economy, stamina, time, shipping, farming actions, travel duration, NPCs, saves and result tiers remain untouched. A saved run starts at the new authored farm spawn because location/position are transient.

## Authoritative farm geometry

| Contract | Approved value |
| --- | --- |
| Map size | 48×40 cells |
| Spawn | (23.5, 11.5) |
| House blocking footprint | Rect2(22, 7, 3, 3) |
| House door / bed E cell | (23, 10) |
| Farmable patch | Rect2i(15, 19, 6, 5): exactly 30 cells |
| Shipping E cell | (22, 19), by field east gate |
| Farm truck E cell | (33, 12) |
| Truck return arrival | (32, 13) |
| Storehouse | Rect2(12, 8, 5, 4) |
| Five building lots | (3,8,4,3), (8,8,3,3), (3,13,4,3), (8,13,4,3), (13,13,4,3) |
| Road and rice paddies | x=42..43; x=44..47 |
| River/reeds | West river and southern bend as in attached JSON; wetlands block movement |
| Fences | 35 bamboo-yard segments and 50 wooden-field segments, with authored gate gaps |

The attached JSON also defines forest, bamboo, water, reeds and paddies as blocking terrain; other blockers are identified by object footprint. Flower beds, torii, lot ropes and fallow plots remain walk-through. A preliminary **4-neighbour grid** check of the supplied layout, including all approved blockers and fence segments, found **1,129/1,129 non-blocked cells reachable from spawn**. This is only a design-data sanity check: live Godot collision and player half-extents still require their own verification.

**HPA-743 door interaction trap:** The old bed E region is the intersection of the house footprint with the bed cell. In v2 the 3×3 house ends at y=10 and the door cell begins at y=10, so that intersection is **empty**. Derive a narrow, reachable *south-door contact strip* from the house footprint edge and door x in WorldContract; pin its physical reach with tests. Do not change the 14-world-pixel contact-first E rule, invent a whole-house interaction region, or fall back to distant raw targets when touching another object.

## Terrain and backdrop rendering

1. Continue to use the authored FarmMap TileMapLayers (Backdrop, Ground, Water, Paths, GroundDecoration) and existing TileSets. Author 48×40 visible cells plus decorative edge treatments at the approved positions. Static art is committed in Godot scene/resources; the layout JSON is design provenance, never loaded at runtime.
2. Prefer HPA-861's supplied 64×32 four-phase shared-surface textures and precomposed edge/corner candidates where they prevent repeated diamond rims. The supplied ground-v2 textures include two-material transitions and multi-junction candidate tiles. Place them as ordinary authored atlas tiles; no runtime material-blending, tile generator, bespoke draw loop or new render architecture. An optional **one-off editor/build-time authoring helper**, if needed to reduce hand placement, must emit ordinary scene/TileSet data rather than become a runtime dependency.
3. Check actual edge pixels at 3×: no grid on grass, no stepping-stone joins along paths, no dotted town seams, continuous banks/water and acceptable multi-material corners. Pick the simplest supplied tiles that pass this visual gate.
4. Update the shared GameMap backdrop painter and its contract-provided tile choices to use the new terrain atlas. The larger farm camera must show painted overdraw at all four corners, with road, water or grass continuations appropriate to the corresponding edge. Town Backdrop must use compatible new grass and paved-edge textures; do not disturb the 16×12 town geometry.
5. Derive the new farm camera bounds from the 48×40 projected map through WorldMath.map_camera_bounds() (or an equivalent **single** WorldContract value), keeping top padding and current zoom. No extra free-camera or zoom system.

## Scenery, depth and collisions

- Instantiate the approved farm's 60 object records in the authored FarmMap scene, reusing HPA-861 cutouts for the farmhouse, storehouse, five marked lots, shed, shrine, greenhouse, orchard, yard furniture, riverside and roadside. The 85 fence positions produce contiguous bamboo and wood runs with the approved holes and posts.
- Position each visual from the WorldContract logical footprint/anchor using WorldMath projection. Keep shadow Sprite2D nodes on the ground plane and a bottom-centre art contact, adjusting offsets only for the approved cutout frame size. Large sprites may exceed a tile's bounds; their **footprint** still controls collision, not the art rectangle.
- Generate/position StaticCollision polygons from the authoritative contract footprint list. Walk-through decoration has **no collider**. Consolidate contiguous blocking terrain where convenient; no per-tile gameplay scripts or extra interaction types.
- Keep props in the existing Entities Y-sort root, with occluder-group behavior only for props that should fade in front of the player. Keep the WorldShell E resolver and player reparenting during truck travel unchanged except for the updated contract regions.
- Keep all 30 farm crops, their soil decals and target feedback in FarmView, but point visual textures to the HPA-861 128×144 4×3 crop candidate, 128×32 dry/wet soil atlas and transparent shipping-bin cutout. Preserve each crop's original kind/stage selection, maturity sparkle and wet/dry behavior.
- Replace town terrain and existing four building frames without changing their authored positions/footprints or villager/truck behavior. Dress town edges only with supplied scenery.

## Migration and cleanup

The geometry is a deliberate hard cutover; no old farm coordinates, old layouts, old save-position fallback or compatibility tests are preserved. **Do not delete any file merely because its name begins with proof- or starting-farm-**: first search runtime scenes/scripts/tests/prologue for consumers. Retire only provably unused old atlases and source sheets; update CLAUDE.md and README.md (and AGENTS.md if mirroring handoff text) to replace the stale 24×20 contract and record the new accepted art sources.

## Acceptance contract (implementation PR, not this planning PR)

1. Contract/geometry: exactly 48×40, one 6×5 farmable plot, canonical door/bin/truck/truck-arrival positions, walk-through vs blocking distinctions, all intended walkable cells reachable from spawn with the player footprint, and the short door→bin (~3.0 s) and door→truck (~3.3 s) projected travel paths still feasible.
2. Native-render visual: agent-controlled Godot running at 1920×1080 with zoom 3; compare **front door, field, storehouse yard and town** screenshots side by side against the supplied mockup/blockouts. Verify no grass grid or islands, consistent paths/fences, readable crops and wet soil, seamless town paving and no grey visible at any camera extreme.
3. Input/depth: actual player walks all gate routes, remains visible around every major building/fence and can face/E the three farm interactables from reachable contact; Enter/Space/E and town-return flow continue to work. All scenic objects remain inert on E.
4. Regression: world_shell_smoke, world_math_smoke, GUT, GdUnit4, godot-e2e and existing Promising Farmer/Heart of the Harvest routes pass; tests assert **new** canonical contract, assets, scene nodes and collision coverage rather than retaining hardcoded old frame counts.
5. **MCP-driven end-to-end acceptance:** use a Godot MCP-connected runtime to drive the real app through New Game → prologue skip → field action → shipping → sleep/next-day → farm truck → town interaction → return; capture the four 1080p comparison screenshots from the same session. Run the existing test suites via their supported runner/CI and record both the MCP route and literal-suite results separately; do **not** claim the MCP ran a suite it cannot invoke.
6. One platform's agent-driven native validation is sufficient because this changes shared Godot maps, not platform-specific code. No human approval or human-run test is an acceptance gate.

**Excluded:** lot construction, storage, fallow-plot farming, town re-layout, new art/SFX production, revised gameplay balance, new seasons/systems, screenshots as pixel-golden CI assertions.
