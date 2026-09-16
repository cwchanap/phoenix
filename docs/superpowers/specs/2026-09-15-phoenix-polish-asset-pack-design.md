# Phoenix Farming and Homestead Polish Asset Pack Design

## Summary

Produce the small runtime-ready image pack that unlocks the next Phoenix polish slices without changing gameplay, replacing existing art, or creating an art pipeline.

This is HPA-458 and remains an asset-focused delivery. HPA-459 consumes farming feedback, HPA-460 consumes one watering-can upgrade icon, and HPA-462 consumes river/evening overlays. Those consumer tickets own runtime integration, timing, audio, and gameplay behavior.

The important output is not merely nine filenames. Each accepted file must have a locked canvas, origin convention, frame contract, style lane, and allowed transforms so consumer tickets do not rediscover those decisions while wiring the assets.

## Goals

1. Deliver exactly the small image set required by HPA-459, HPA-460, and HPA-462.
2. Preserve Phoenix's 640x360 logical viewport, 64x32 isometric ground geometry, nearest filtering, integer scaling, and current sprite origins.
3. Keep action feedback short, local, and readable without a full player animation sheet.
4. Keep ambience additive: ripple/window art overlays existing terrain/house art rather than replacing it.
5. Lock geometry and facing contracts before handoff, including an in-PR fallback when one canonical tool pose is insufficient.
6. Keep one HPA-458 PR. Planning, generation/editing, cleanup, visual review, provenance, verification, and final handoff stay together.

## Non-goals

No gameplay implementation, new maps/buildings, player/NPC animation sets, replacement crops/soil/terrain, portraits, UI skins, weather textures, foliage/wildlife, audio, shaders, generation pipeline, asset registry, runtime manifest, or custom importer.

A narrow verification edit to the existing `tests/headless/world_shell_smoke.gd::EXPECTED_ASSETS` table is allowed and expected. It is not a new asset/test framework.

Rain streaks and tinting remain runtime presentation in HPA-462. Target diamonds/text remain runtime presentation in HPA-459. Crop pickup reuses current crop imagery.

## Existing repo conventions to reuse

Phoenix already has the contracts this pack should fit:

- `FarmView` places soil at the world cell center, uses horizontal sprite frames, and places crop sprites at bottom-center with `offset = Vector2(0, -24)`.
- `player.tscn` uses four horizontal facing frames and `offset = Vector2(0, -24)`.
- `WorldMath.Facing` is ordered `UP, RIGHT, DOWN, LEFT`; `PlayerController` maps the facing directly to the player sprite frame.
- `world.tscn` places the House at scale `2`, with its sprite at `offset = Vector2(0, -48)` and frame 0 of the approved props sheet.
- `game_hud.tscn` draws the current watering-can icon in a real 22x22 action-slot rect.
- `world_shell_smoke.gd::EXPECTED_ASSETS` already loads image resources and asserts exact dimensions, including source art not wired as scene nodes.
- `tests/visual/design-reference/` already uses `.gdignore` so review/reference PNGs do not become imported production resources.
- Existing texture imports use nearest/default filter behavior, `compress/mode=0`, no mipmaps, and `process/fix_alpha_border=true`.

Do not introduce a second convention when one of these fits.

## Visual reference and style lanes

Use the actual committed production art before producing anything:

- `assets/sprites/starting-farm-tiles-source.webp`
- `assets/sprites/starting-farm-props-source.webp`
- `assets/sprites/starting-farm-terrain.png`
- `assets/sprites/starting-farm-props.png`
- `assets/sprites/proof-player.png`
- `assets/sprites/proof-crops.png`
- `assets/sprites/proof-soil.png`
- `assets/ui/icons/hoe.png`
- `assets/ui/icons/watering-can.png`

The references intentionally have different roles; do not average them into one vague style prompt:

- **Soil impact / planting seed / water splash / harvest sparkle:** geometric, compact, and keyed to the proof soil/crop palette. They live directly on the farming scene and must not introduce painterly FX.
- **Tool overlays:** simple small silhouettes that read on the four proof-player poses. Use the UI icons only to identify the hoe blade/can silhouette; do not render UI-icon art on the character.
- **Efficient watering can:** edit the existing `assets/ui/icons/watering-can.png`; add one small non-text efficiency accent. Do not regenerate the can from scratch.
- **River ripple:** an extra-subtle overlay on the existing water diamond, which already has visual texture/sparkle. Do not replace or repaint water.
- **House-window light:** derive a pixel mask from house frame 0 on the native 96x96 cell. The current windows already contain yellow pixels; this file is only the evening light mask, never a new cottage.

Generated output is source material, not production-ready output. Cleanup/normalization is required before acceptance.

## Locked runtime deliverables

| Consumer | Final path | Canvas / frames | Origin and transform contract |
| --- | --- | --- | --- |
| HPA-459 | `assets/sprites/polish/hoe-overlay.png` | Preferred `24x24`, 1 frame. Allowed fallback `48x24`, `hframes=2`, order `DOWN, UP` only if the real UP-facing composite fails. | Child of player `Sprite2D`. README records numeric handle attachment from the native canvas origin. Horizontal mirroring is allowed for side facings; rotation is not a legal facing transform. |
| HPA-459 | `assets/sprites/polish/watering-can-overlay.png` | Same contract as hoe. | Same player-child/attachment contract. `flip_h` allowed where reviewed; rotate disallowed. |
| HPA-459 | `assets/sprites/polish/soil-impact.png` | `96x32`, `hframes=3`, three `32x32` frames. | Cell-center, same world placement convention as soil; no extra world offset. |
| HPA-459 | `assets/sprites/polish/planting-seed.png` | Exact `8x8`, 1 frame. | Cell-center, no extra world offset. Reused for all crops. |
| HPA-459 | `assets/sprites/polish/water-splash.png` | `192x32`, `hframes=3`, three `64x32` frames. | Cell-center, one ground diamond, no extra world offset. |
| HPA-459 | `assets/sprites/polish/harvest-sparkle.png` | `48x16`, `hframes=3`, three `16x16` frames. | Crop-sprite space, bottom-center with one numeric upward local offset recorded in the handoff. Not a ground-diamond effect. |
| HPA-460 | `assets/ui/icons/watering-can-efficient.png` | Exact `32x32`, 1 frame. | Edited from existing icon and reviewed at the real `22x22` HUD draw size. |
| HPA-462 | `assets/sprites/polish/river-ripple.png` | `192x32`, `hframes=3`, three `64x32` frames. | Cell-center, no extra world offset; all visible pixels remain inside water. |
| HPA-462 | `assets/sprites/polish/house-window-light.png` | Exact `96x96`, 1 frame. | Sibling/child presentation aligned with `Entities/House/Sprite2D`: same native frame, parent scale `2`, local offset `(0, -48)`. |

This is eight asset groups and nine runtime paths. The only permitted size branch is the tool-overlay facing fallback, and HPA-458 must resolve it before handoff. Consumer tickets never decide later whether an UP frame is needed.

## Tool-facing acceptance gate

One arbitrary sprite plus runtime rotation is not acceptable for the four isometric player poses.

For each tool:

1. Author/select a canonical DOWN-facing silhouette on the exact 24x24 canvas.
2. Composite it on the actual `proof-player.png` frames for `UP, RIGHT, DOWN, LEFT` at native 1x and integer 2x.
3. Side-facing use may mirror the reviewed silhouette horizontally. Do not rotate the texture to synthesize a facing.
4. If the UP composite does not read correctly, the same final runtime path becomes a `48x24` two-frame strip with `hframes=2`, frame order `DOWN, UP`.
5. Record the final frame count, frame 0 meaning, numeric handle attachment, and allowed mirroring in the handoff README.

This keeps the pack small while preventing a second asset PR after HPA-459 has already integrated the wrong contract.

## Farming and ambience behavior locks

All three-frame strips use horizontal frames and fixed frame origins with no anchor jitter.

- Soil impact expands/dissipates but never becomes a replacement tilled-soil tile.
- Seed remains tiny and generic; crop identity remains game/UI state.
- Water splash stays ground-hugging inside one 64x32 diamond and never obscures dry/wet soil state.
- Harvest sparkle is brief and restrained enough for both mature-target readiness and harvest feedback.
- Ripple remains wholly inside current water.
- Window light leaves roof, walls, yard, and fence transparent.

HPA-459 may tune roughly 150-250 ms presentation later. HPA-458 records recommended timing but does not implement animation.

## Source, review, and provenance layout

Use the existing ignored visual-reference tree instead of introducing an importable `docs/art/` raster tree:

```text
tests/visual/hpa-458/
├── .gdignore
├── README.md
├── source/
│   └── selected accepted generator/source originals only
└── review/
    ├── contact-sheet.png
    ├── farming-actions.png
    └── homestead-ambience.png
```

The README is the image-pack provenance and handoff table. Keep the existing font-specific `assets/ui/fonts/SOURCES.md` focused on fonts rather than turning it into a general asset manifest.

One row per runtime file records:

- source/edit prompt/provenance;
- final path and exact native dimensions;
- `hframes`, frame order, and frame 0 meaning;
- recommended frame duration where relevant;
- exact origin convention and numeric local attachment/offset where needed;
- allowed transforms (`flip_h` only where reviewed; no facing rotation);
- intended consumer ticket;
- cleanup/editing performed.

Only accepted source material is retained. Rejected generations stay out of git.

## Review composites

Review rasters use actual committed Phoenix pixels, not redrawn stand-ins.

At minimum:

1. tool overlays composited on all four real `proof-player.png` frames at 1x and 2x;
2. soil/seed/splash on actual proof soil/farm context;
3. sparkle on an actual mature proof crop;
4. base and efficient watering-can icons side by side at the real 22x22 HUD draw size;
5. ripple on the actual current water tile;
6. house frame 0 with the window mask at native 96x96 and current 2x world placement.

The pack is rejected if an asset only works after arbitrary enlargement, rotation, or placement against a mock player/house.

## Import and verification contract

Final runtime PNGs follow the repository's current texture import behavior: nearest/default texture filter, `compress/mode=0`, no generated mipmaps, and `process/fix_alpha_border=true`. Let Godot produce correct per-file UID/path metadata; do not copy another file's UID or imported cache path.

Extend `tests/headless/world_shell_smoke.gd::EXPECTED_ASSETS` with all nine final runtime paths and their accepted exact dimensions. For tool overlays, use the dimension selected by the facing gate above. `./tools/verify-clean.sh` then becomes the mechanical geometry/import gate without introducing a new test harness.

Review/source rasters stay under the `.gdignore` tree and must never become production scene dependencies or UI visual goldens. CI does not bless generated art.

## Risks

1. **Isometric tool-facing mismatch.** A rotated DOWN tool will not necessarily match the distinct UP/RIGHT/DOWN/LEFT player poses. Mitigate with actual four-frame composites, `flip_h` only, and the bounded two-frame DOWN/UP fallback inside HPA-458.
2. **House mask pixel drift.** A one-pixel miss on the 96x96 source becomes two pixels at the current 2x House scale. Author/review on native house frame 0 first, then confirm the existing `(0, -48)` / 2x placement.
3. **Style drift from generation.** Farming FX can look like a second game if they inherit the painterly homestead/UI style. Keep explicit style lanes and reject candidates against actual proof soil/crop/player composites before cleanup work continues.

## Acceptance criteria

The pack is complete when:

1. All nine runtime paths exist with the exact accepted canvas/frame geometry above.
2. The tool-facing gate has resolved each overlay to either one `24x24` frame or the bounded `48x24` `DOWN,UP` strip; no consumer-side facing-art decision remains.
3. Alpha is clean: no checkerboard background, matte fringe, large halos, clipped effects, or stray near-transparent pixels that read at 2x.
4. Every three-frame strip partitions evenly and has stable visual anchoring.
5. Origin conventions and numeric attachment/local offsets are recorded before handoff.
6. Farming effects are readable but restrained at native 640x360.
7. The efficient can is recognizably the existing icon plus one small accent at 22x22.
8. Ripple stays inside current water and the 96x96 window mask aligns exactly to house frame 0/current placement.
9. `tests/visual/hpa-458/.gdignore` prevents source/review rasters from entering the Godot resource import path.
10. Review composites use actual player frames/house/water/farm art at 1x and integer 2x.
11. `EXPECTED_ASSETS` pins the nine final paths and dimensions; clean Godot import and `./tools/verify-clean.sh` pass.
12. No runtime/gameplay integration is added.

## Delivery rule

One issue, one branch, one PR. Planning documents land first on PR #15; production art, verification smoke update, review evidence, and handoff continue on the same PR. Do not open a second implementation, generation, or approval PR.