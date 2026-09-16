# Phoenix Farming and Homestead Polish Asset Pack Design

## Summary

HPA-458 produces the nine small runtime image paths needed by HPA-459, HPA-460, and HPA-462. It is an asset-focused slice: no gameplay integration, no reusable art pipeline, and no new rendering/animation framework.

The design goal is to finish every asset decision that would otherwise become expensive during consumer integration: exact geometry, origin, style lane, tool-facing fallback, provenance, and a small mechanical verification contract.

## Non-goals

No gameplay implementation, new map/building/crop/player/NPC art, UI redesign, weather texture, audio, shader system, generator, custom importer, registry, runtime manifest, SpriteFrames abstraction, migration/versioned asset format, or four-direction player/tool sheet.

A narrow extension of the existing `tests/headless/world_shell_smoke.gd::EXPECTED_ASSETS` validation is part of this ticket. It reuses the existing smoke rather than creating an asset-test framework.

## Existing conventions to reuse

- Phoenix renders at a logical `640x360`, integer-scaled with nearest filtering.
- `FarmView` places soil at cell center and uses horizontal frames; crops use bottom-center presentation with local `y=-24`.
- `player.tscn` has four authored horizontal frames. `WorldMath.Facing` is `UP, RIGHT, DOWN, LEFT`, and `PlayerController` assigns the sprite frame directly.
- The House uses native 96x96 frame 0, parent scale `2`, and sprite offset `(0, -48)`.
- The watering-can icon is native 32x32 and the HUD action-slot draw rect is 22x22.
- Existing texture imports use `compress/mode=0`, no mipmaps, `fix_alpha_border=true`, and the project-wide nearest filter.
- `EXPECTED_ASSETS` already dimension-pins image resources that are not instantiated by the world scene.
- Review/reference rasters already live behind `.gdignore` under `tests/visual/`.

Do not create a second convention where one of these fits.

## Visual style lanes

Use actual committed Phoenix pixels as references:

- `proof-soil.png`, `proof-crops.png` -> soil impact, seed, splash, sparkle: compact/geometric, not painterly.
- `proof-player.png` + existing hoe/can icons -> tool overlays: simple silhouettes on the real player poses; icons define tool identity, not rendering style.
- `assets/ui/icons/watering-can.png` -> efficient can: edit the existing icon, do not regenerate it.
- `starting-farm-terrain.png` -> ripple: extra-subtle overlay on current water.
- `starting-farm-props.png` frame 0 -> window light: native house-window mask only, never a new cottage.

## Locked runtime contract

This table is the design source of truth. The implementation plan references it instead of duplicating it; the final `tests/visual/hpa-458/README.md` becomes the shipped consumer handoff.

| Consumer | Final path | Canvas / frames | Origin / transform |
| --- | --- | --- | --- |
| HPA-459 | `assets/sprites/polish/hoe-overlay.png` | Prefer `24x24`, 1 frame. Allowed fallbacks: `48x24`, `hframes=2`, `DOWN,UP`; then `72x24`, `hframes=3`, `DOWN,UP,SIDE` if side-specific art is required. | Child of player sprite. No facing rotation. README records selected frame mapping and numeric per-facing attachment offsets. `SIDE` may mirror for the opposite side only if both real side composites pass. |
| HPA-459 | `assets/sprites/polish/watering-can-overlay.png` | Same bounded contract as hoe. | Same rules as hoe. |
| HPA-459 | `assets/sprites/polish/soil-impact.png` | `96x32`, `hframes=3`, three 32x32 frames. | Cell-center; no extra world offset. |
| HPA-459 | `assets/sprites/polish/planting-seed.png` | `8x8`, 1 frame. | Cell-center; no extra world offset. |
| HPA-459 | `assets/sprites/polish/water-splash.png` | `192x32`, `hframes=3`, three 64x32 frames. | Cell-center; one ground diamond. |
| HPA-459 | `assets/sprites/polish/harvest-sparkle.png` | `48x16`, `hframes=3`, three 16x16 frames. | Crop-sprite space; README records one numeric upward local offset. |
| HPA-460 | `assets/ui/icons/watering-can-efficient.png` | `32x32`, 1 frame. | Edited from current icon; reviewed at 22x22. |
| HPA-462 | `assets/sprites/polish/river-ripple.png` | `192x32`, `hframes=3`, three 64x32 frames. | Cell-center; all visible pixels remain inside water. |
| HPA-462 | `assets/sprites/polish/house-window-light.png` | `96x96`, 1 frame. | Native house frame alignment; current parent scale 2 and local offset `(0, -48)`. |

The tool paths keep one bounded filename each. HPA-458 resolves the smallest passing frame layout before handoff; HPA-459 never decides later that another facing asset is needed. If the three-frame `DOWN,UP,SIDE` form still cannot fit both side poses through reviewed mapping/mirroring and attachment offsets, redesign the silhouette inside HPA-458 rather than expanding to a four-direction sheet.

## Tool-facing gate

For each tool:

1. Start with one exact 24x24 DOWN-canonical silhouette.
2. Composite against the actual `proof-player.png` `UP, RIGHT, DOWN, LEFT` frames; do not rotate/redraw the player.
3. Per-facing attachment offsets are allowed. Texture rotation is not.
4. If UP needs distinct art, use `48x24` / `DOWN,UP`.
5. If side facings need a distinct silhouette, use `72x24` / `DOWN,UP,SIDE`; mirror SIDE only when both actual side composites pass.
6. Record final dimensions, `hframes`, frame mapping, frame 0 meaning, attachment offsets, and transform permissions in the README.

This is the maximum facing complexity allowed by the slice.

## Review and provenance

Only one review raster is committed:

```text
tests/visual/hpa-458/
├── .gdignore
├── README.md
└── contact-sheet.png
```

Do not commit generated-source originals. The README retains the useful provenance: source/edit method, prompt where applicable, cleanup performed, final path, geometry, frame mapping, origin/attachment, transforms, timing recommendation, and consumer.

Working composites used while selecting/cleaning assets may exist locally but are not retained after the final contact sheet is produced.

The final contact sheet must include:

- all tool-facing decisions on the real player frames;
- soil/seed/splash/sparkle on actual farm/crop pixels;
- base/upgraded watering cans at 22x22;
- actual water + ripple;
- native and current-placement house + window mask;
- at least one true `640x360` farming-context frame with the current HUD visible, using the existing `tests/visual/plates/farm.png` / production-capture convention, so effect readability is judged at the real output size rather than only as isolated sprites.

It may also show enlarged 2x details, but 2x is not the sole acceptance view. This contact sheet is review evidence, not a UI visual golden, and CI never blesses it automatically.

## Import guard

The implementation must create `assets/art/.gdignore` before any Godot import. That protects local/untracked source-art trees from producing unrelated `.import` sidecars during HPA-458 work while leaving Git ownership decisions for those source files unchanged.

`tests/visual/hpa-458/.gdignore` likewise keeps the handoff/contact raster out of the production resource import path.

## Mechanical verification

Extend the existing `EXPECTED_ASSETS` validation; do not add a new test file.

The nine HPA-458 rows carry `path`, exact accepted `size`, and `hframes`. The existing loop must verify:

1. the texture imports and has the exact size;
2. width partitions evenly by `hframes`;
3. every frame contains at least one non-transparent pixel;
4. every frame also contains transparency, preventing a fully opaque baked background/checkerboard from passing as a sprite/effect.

This intentionally does **not** try to build a general image-quality detector. Matte fringe, stray near-transparent noise, clipped effects, and frame-to-frame visual anchor jitter remain contact-sheet/manual inspection gates because automating those robustly would exceed this nine-file slice.

## Risks

1. **Isometric tool mismatch** — close with the bounded 1/2/3-frame facing gate on actual player poses.
2. **House-mask drift** — author/review on native 96x96 frame 0 before checking current 2x placement.
3. **Style drift** — enforce the explicit style lanes against actual production pixels.
4. **Import pollution** — add `assets/art/.gdignore` before running Godot import and inspect working-tree changes afterward.

## Acceptance

HPA-458 is complete when:

1. All nine runtime paths exist and match the locked contract.
2. Each tool resolves to the smallest passing 24x24 / 48x24 / 72x24 layout; no facing-art decision leaks to HPA-459.
3. The existing smoke mechanically verifies size, hframe partition, per-frame non-empty alpha, and per-frame transparency.
4. Visual inspection rejects matte/checkerboard residue, visible fringe/noise, clipped effects, and anchor jitter.
5. Farming FX are readable but restrained in a real 640x360 HUD-visible context.
6. The efficient can remains the existing icon plus one small accent at 22x22.
7. Ripple stays within current water and the window mask aligns to native/current House placement.
8. `tests/visual/hpa-458/README.md` contains complete provenance and consumer handoff; no source-generation raster archive is committed.
9. `assets/art/.gdignore` and `tests/visual/hpa-458/.gdignore` prevent unrelated/review image imports.
10. Clean Godot import, working-tree inspection, and `./tools/verify-clean.sh` pass without unrelated sidecars.
11. No gameplay/runtime integration or new asset framework is added.

## Delivery rule

One issue, one branch, one PR. Planning lands first on PR #15; production assets, two `.gdignore` guards, the narrow existing-smoke edit, contact sheet, README, and verification continue on the same PR. No second generation/cleanup/approval PR.