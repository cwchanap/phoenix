# Phoenix Farming and Homestead Polish Asset Pack Design

## Summary

Produce the small runtime-ready image pack that unlocks the next Phoenix polish slices without changing gameplay, replacing existing art, or creating a reusable art pipeline.

This is HPA-458 and remains an asset-only delivery. The accepted files are consumed later by HPA-459 (farming feedback), HPA-460 (one watering-can upgrade), and HPA-462 (river/evening ambience). Those consumer tickets own runtime integration and verification.

The pack must read beside the current merged homestead and UI rather than introducing a second visual language. Use the committed `starting-farm-*-source.webp`, proof player/crop/soil sprites, and existing `assets/ui/icons/hoe.png` / `watering-can.png` as the visual references.

## Goals

1. Deliver exactly the small set of generated/cleaned images required by HPA-459, HPA-460, and HPA-462.
2. Preserve Phoenix's current 640x360 logical viewport, 64x32 isometric ground geometry, nearest filtering, integer scaling, and bottom-center world anchoring.
3. Keep action feedback short, local, and readable without requiring a new player animation sheet.
4. Keep ambience additive: river/window art overlays existing terrain/house art rather than replacing it.
5. Make every final runtime image deterministic to consume: exact canvas/frame size, real alpha, stable frame alignment, and documented anchor/transform guidance.
6. Keep one asset-only PR. Generation, cleanup, contact sheets, provenance, and handoff stay together.

## Non-goals

Do not create or modify gameplay code, new maps/buildings, player/NPC animation sheets, replacement crops/soil/terrain, portraits, UI skins, weather textures, foliage/wildlife, audio, shaders, a sprite-generation pipeline, an asset registry, or custom import tooling.

Rain streaks and tinting remain runtime presentation in HPA-462. Target diamonds/text remain runtime presentation in HPA-459. Crop pickup reuses current crop imagery.

## Existing-art contract

Reference the actual committed production art before generating anything:

- `assets/sprites/starting-farm-tiles-source.webp`
- `assets/sprites/starting-farm-props-source.webp`
- `assets/sprites/proof-player.png`
- `assets/sprites/proof-crops.png`
- `assets/sprites/proof-soil.png`
- `assets/ui/icons/hoe.png`
- `assets/ui/icons/watering-can.png`

The starting-farm source sheets are regular 4x2 sheets with 96x96 source cells. The approved house remains on its 96x96 source canvas and is displayed at integer 2x in the world. New overlays must align to that existing composition rather than redraw it.

Do not regenerate any of the reference assets. Generated output is raw source material; cleanup/normalization is expected before a file becomes a runtime asset.

## Runtime deliverables

| Consumer | Final path | Contract |
| --- | --- | --- |
| HPA-459 | `assets/sprites/polish/hoe-overlay.png` | One transparent canonical hoe silhouette, approximately 24x24 native pixels. No hand/body. HPA-459 positions/rotates/flips it for facing and motion. |
| HPA-459 | `assets/sprites/polish/watering-can-overlay.png` | One transparent canonical watering-can silhouette, approximately 24x24 native pixels. Same transform contract as the hoe. |
| HPA-459 | `assets/sprites/polish/soil-impact.png` | 96x32 strip: three 32x32 transparent frames, fixed frame origin, restrained dirt/puff progression. |
| HPA-459 | `assets/sprites/polish/planting-seed.png` | One generic seed on an 8x8 transparent canvas. Reused for all crops. |
| HPA-459 | `assets/sprites/polish/water-splash.png` | 192x32 strip: three 64x32 transparent frames aligned to one isometric ground diamond. No baked facing. |
| HPA-459 | `assets/sprites/polish/harvest-sparkle.png` | 48x16 strip: three 16x16 transparent frames. Restrained enough for both harvest feedback and targeted mature-crop readiness. |
| HPA-460 | `assets/ui/icons/watering-can-efficient.png` | One transparent upgraded-can icon. Start from a 32x32 runtime canvas and match the existing can silhouette/readability; use a small non-text efficiency accent only. |
| HPA-462 | `assets/sprites/polish/river-ripple.png` | 192x32 strip: three 64x32 transparent frames. Subtle overlay wholly contained by an existing water diamond. |
| HPA-462 | `assets/sprites/polish/house-window-light.png` | One 96x96 transparent mask aligned exactly to the approved house source frame. Illuminate windows only; yard/roof/walls remain transparent. |

This is eight asset groups and nine runtime PNGs because the tool-overlay group contains two files.

## Visual behavior locks

### Tool overlays

Generate one canonical silhouette per tool, not four directional sprites. The final handoff documents which runtime rotations/flips are visually safe after checking all four existing player facings. Tool art must stay visually subordinate to the player and must not imply a new animation rig.

### Farming effects

All strips have fixed frame boundaries and no frame-to-frame anchor drift.

- Soil impact: compact outward puff, then dissipate; do not create a replacement tilled-soil tile.
- Seed: small but visible at native scale; crop identity remains UI/session state.
- Water splash: ground-hugging and centered on the worked diamond; do not bake a directional stream.
- Sparkle: brief readiness/harvest accent, not a permanent glow.

The first runtime tuning target in HPA-459 is roughly 150-250 ms total. HPA-458 records recommended per-frame duration but does not implement animation timing.

### Efficient watering-can icon

The icon must look like the current can first and "upgraded" second. Use one small visual accent rather than text, a badge system, or a second toolbar style.

### River ripple

The strip is an overlay only. It must not replace the water terrain, change shoreline geometry, or create an opaque rectangle/halo around the ripple.

### House-window light

The final file preserves the full 96x96 source canvas so HPA-462 can reuse the house's existing placement/scale directly. Only window-light pixels are non-transparent. No redrawn siding, roof, fence, or yard.

## Generation and cleanup strategy

Prefer a small number of source generations that are easy to clean over asking an image model for a production-ready sprite sheet with exact frame geometry.

For each asset group:

1. Generate a simple isolated concept against transparency or a plain removable background, using the current Phoenix art as reference.
2. Select one source candidate only after checking silhouette/style against the committed art.
3. Normalize to the exact final canvas/frame contract.
4. Remove background contamination, halos, partial transparency noise, and clipped pixels.
5. Align repeated frames to a fixed pivot/origin and verify no jitter.
6. Review at native 1x and integer 2x before accepting.

Do not retain every rejected generation in git.

## Source, review, and provenance layout

Keep runtime assets under `assets/`; keep review-only material out of runtime asset paths:

```text
docs/art/hpa-458/
├── README.md
├── source/
│   └── selected accepted generator originals only
└── review/
    ├── contact-sheet.png
    ├── farming-actions.png
    └── homestead-ambience.png
```

`README.md` is the handoff manifest. One row per final runtime file records:

- source/prompt/provenance;
- final path and native dimensions;
- strip frame order and recommended frame duration where relevant;
- anchor/pivot or alignment contract;
- allowed facing transforms for tool overlays;
- intended consumer ticket;
- any cleanup performed.

The review composites use actual committed Phoenix farm/player/house art. Labels may appear in review images, never in runtime PNGs.

## Contact-sheet acceptance views

At minimum show:

1. hoe overlay + soil puff on a dry farm tile in representative facings;
2. seed drop on prepared soil;
3. watering-can overlay + splash on dry/wet farm context;
4. mature crop + sparkle/harvest cue;
5. base and efficient watering-can icons side by side at their real UI draw size;
6. river ripple on the current river tile;
7. approved house with the evening window mask enabled.

Review each composition at native 640x360 context and integer 2x. The pack is rejected if it only looks acceptable when enlarged beyond Phoenix's normal presentation.

## Import and repository contract

Final runtime PNGs use normal Godot imports and nearest/no-filter behavior consistent with the existing project. Commit the resulting source-adjacent `.import` sidecars if the repository's current Godot workflow produces them; never commit `.godot/` cache files.

Do not add a runtime manifest, loader, atlas framework, custom import script, or new resource abstraction. Consumer tickets load/use the files through their existing scenes/scripts.

## Acceptance criteria

The asset pack is complete when:

1. All nine runtime PNGs exist at the final paths above with the required canvas/frame geometry.
2. Alpha is real and clean: no checkerboard background, matte fringe, large halos, clipped effects, or stray near-transparent pixels that read at 2x.
3. Every three-frame strip is evenly partitioned and visually anchored with no frame jitter.
4. Tool overlays remain readable in all four existing player facings without new character sheets.
5. Farming effects are distinguishable but restrained at native 640x360.
6. The efficient-can icon reads as the existing watering can plus one small upgrade cue.
7. River ripple stays inside water and the window mask aligns to the existing 96x96 house frame.
8. Contact sheets/composites use current committed Phoenix art and are reviewed before acceptance.
9. `docs/art/hpa-458/README.md` provides complete provenance/handoff for every runtime file.
10. Clean Godot import succeeds and no runtime/gameplay code is changed.

## Delivery rule

This is one issue / one branch / one PR. The planning documents land first on the HPA-458 draft PR. Image generation, cleanup, packaging, review evidence, and final asset handoff continue on that same PR; do not open a second implementation or approval PR.