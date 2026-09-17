# HPA-458 generated asset handoff

These runtime PNGs were produced for HPA-458 and normalized to the locked Phoenix geometry before commit. They are production candidates for the consumer tickets; runtime integration remains in HPA-459/HPA-460/HPA-462. Generation/editing and cleanup details per asset are recorded below; no `source/` directory is committed.

## Asset table

| Path | Size | hframes | Consumer | Provenance |
| --- | ---: | ---: | --- | --- |
| `assets/sprites/polish/hoe-overlay.png` | 72x24 | 3 | HPA-459 | Generated, composited against committed `proof-player.png` frames |
| `assets/sprites/polish/watering-can-overlay.png` | 72x24 | 3 | HPA-459 | Generated, composited against committed `proof-player.png` frames |
| `assets/sprites/polish/soil-impact.png` | 96x32 | 3 | HPA-459 | Generated, cleaned |
| `assets/sprites/polish/planting-seed.png` | 8x8 | 1 | HPA-459 | Generated |
| `assets/sprites/polish/water-splash.png` | 192x32 | 3 | HPA-459 | Generated, color-masked to transparent water-only frames |
| `assets/sprites/polish/harvest-sparkle.png` | 48x16 | 3 | HPA-459 | Generated |
| `assets/ui/icons/watering-can-efficient.png` | 32x32 | 1 | HPA-460 | Edited from `assets/ui/icons/watering-can.png` (see below) |
| `assets/sprites/polish/river-ripple.png` | 192x32 | 3 | HPA-462 | Generated, color-masked to transparent highlight-only frames |
| `assets/sprites/polish/house-window-light.png` | 96x96 | 1 | HPA-462 | Re-authored from house frame 0 of `starting-farm-props.png` (see below) |

Strips are horizontally packed; frame `i` occupies `x in [i*frame_w, (i+1)*frame_w)`. Every frame above satisfies the smoke gates: width divides evenly by `hframes`, each frame has at least one non-transparent and one transparent pixel.

## Tool-facing contract

Both tool strips were composited directly against the committed `proof-player.png` frames in the runtime facing order `UP, RIGHT, DOWN, LEFT`. The three-frame fallback is required and accepted: the distinct UP frame is used for UP, the DOWN frame for DOWN, and the SIDE frame for RIGHT with `flip_h=true` for LEFT. Texture rotation is never used.

The accepted tool Sprite2D center positions, in Player-local pixels, are the same for both tools:

| Facing | Tool frame | flip_h | local position |
| --- | ---: | --- | --- |
| UP | 1 (`UP`) | false | `(0, -22)` |
| RIGHT | 2 (`SIDE`) | false | `(10, -21)` |
| DOWN | 0 (`DOWN`) | false | `(4, -16)` |
| LEFT | 2 (`SIDE`) | true | `(-10, -21)` |

These positions were recovered from exact native-pixel composites against the 32x48 player frames (`Sprite2D.offset = (0, -24)`), not from a scaled mockup. HPA-459 may animate the child presentation around these anchors, but should not move the CharacterBody2D/root or invent a fourth directional texture.

**Frame mapping (both tool strips):** frame 0 = `DOWN` pose, frame 1 = `UP` pose, frame 2 = `SIDE` pose. There is no strip playback: one frame is selected per facing and held for the action. Allowed transforms: `flip_h` on frame 2 for LEFT only; no rotation, no scaling.

## Effect strips (HPA-459)

All effect overlays are cell-centered unless stated: origin is the projected cell center on the ground plane, sprite drawn bottom-anchored so the frame's content sits on the soil. Allowed transform: none (no flip, no rotation); integer-scale draw at 2x alongside the proof terrain, matching the proof sprites.

| Asset | Frames (meaning) | Recommended timing |
| --- | --- | --- |
| `soil-impact.png` | 32x32 frames; 0 = impact onset (54 lit px), 1 = peak burst (187), 2 = settle (57) | One-shot per till action; ~6-8 fps ascending 0→1→2 then clear. Presentation-side only; `GameRules.ACTION_MINUTES` budgets the world time, not the animation. |
| `water-splash.png` | 64x32 frames; 0 = impact, 1 = rising sheet, 2 = widest spread | One-shot per watering action; ~8-10 fps 0→1→2 then clear. |
| `harvest-sparkle.png` | 16x16 frames; 0 = glint speck, 1 = 4-point star peak, 2 = settle | One-shot at harvest pop; ~8 fps 0→1→2. |
| `planting-seed.png` | single 8x8 generic seed | Static flash on the tilled cell during the planting action; clear on completion. |
| `river-ripple.png` | 64x32 frames; 0 = calm highlight (175 lit px), 1-2 = sparser drift | Slow ambient loop (~2 fps, order 0→1→2→0 or ping-pong); drawn over water at 2x, all visible pixels stay within water tones. |

**`harvest-sparkle.png` numeric local offset (crop-sprite space): `(0, -44)`.** The sparkle is a child of the crop `Sprite2D` (`proof-crops.png`, `hframes=4`, `vframes=3` → 32x48 frames, `offset = (0, -24)`, so frame-local y spans `[-48, 0]` with ground contact at `(0, 0)`). All three mature crop frames (indices `kind*4 + 3`, i.e. 3/7/11) share canopy top at local `y = -38`; at `y = -44` the 16x16 sparkle's star content occupies `y in [-48, -42]`, hovering just above the canopy with zero overlap of canopy or produce on every crop kind (pixel-verified on frames 3, 7, and 11). Horizontal center `x = 0` is correct; no nonzero x is needed.

## HPA-460 icon

`watering-can-efficient.png` is a pixel-level edit of the committed `assets/ui/icons/watering-can.png` (32x32 RGBA, unchanged canvas). Exactly 3 pixels differ — a cream specular L-glint on the body's dark slate band using colors sampled from the icon's own palette (`(22,15)` and `(22,16)` → cream `(250,239,207)`, `(21,16)` → light steel `(162,170,175)`; alphas preserved). No text, no redraw, no resize. The accent coordinates survive the nearest-neighbor 32→22 HUD draw (visible at destination `(15,10)`, `(15,11)`, `(14,11)`), so the icon remains "existing icon plus one small accent" at the real 22x22 HUD size. Static; allowed transforms: none.

## HPA-462 house window light

`house-window-light.png` (96x96 RGBA, 1 frame) is a warm window-light mask derived from house frame 0 of `starting-farm-props.png` (384x192 sheet, `hframes=4`, `vframes=2`; house = top-left 96x96 rect). The mask targets the two wall windows' glass cores — left `(29, 51)`, right `(70, 53)` in frame-0 pixels — as stepped warm-amber bands (peak alpha 140 at the glass, fading to 14; hard alpha steps, no gradient mush). It must be drawn as a sibling/child of the House sprite with the same center, `offset = (0, -48)`, integer scale 2; with that placement the halos land on the window frames and the roof/door/awning stay untinted. Allowed transforms: none. Static (no timing); consumer may pulse alpha gently, but the geometry is fixed.

History note: the first committed version of this file was corrupt (invalid IDAT CRC, undecodable by Godot/Pillow); it was re-authored per the design contract from the native house frame and verified chunk-by-chunk (IHDR/IDAT/IEND CRC-OK, PIL decode OK, alpha bbox `(11, 33, 89, 72)`).

## Generation / cleanup

- Effect/overlay sources were generated as transparent pixel-art imagery with ChatGPT image generation, then normalized locally with nearest-neighbor resampling to the exact canvases above; three-frame strips were split and repacked horizontally.
- Splash/ripple sources were color-masked so terrain/water backing pixels are not baked into the runtime overlays.
- Tool strips were composited against the committed proof player frames (positions in the tool-facing contract above).
- The efficient-can icon is a deterministic pixel edit of the committed base icon, not a generation.
- The window-light mask was re-authored programmatically from the committed house frame 0 pixels.
- Rejected large source generations are intentionally not committed.
- Review/source material stays behind `tests/visual/hpa-458/.gdignore`; `assets/art/.gdignore` prevents unrelated local source art from being imported.

## Validation status

Completed:

- exact runtime dimensions for all nine paths;
- transparent runtime canvases and evenly partitioned strips;
- hoe/watering-can facing decision against all four committed player frames;
- fixed tool attachment positions and transform permissions;
- native-scale farming-context review using committed proof player/soil/crop pixels plus the generated FX;
- pixel-level `house-window-light.png` alignment against the actual current house frame 0 (glass cores, scale-2 `(0,-48)` placement, overlay proof reviewed);
- numeric `harvest-sparkle.png` offset `(0, -44)` validated against mature frames 3/7/11;
- efficient-can provenance corrected to an edit of the committed base icon, reviewed at 22x22;
- world-shell smoke asset gates extended to the nine HPA-458 paths (import, exact dimensions, `hframes` divisibility, per-frame non-empty alpha, per-frame transparency);
- the committed contact sheet `tests/visual/hpa-458/contact-sheet.png` (tool composites on all four poses, FX on real farm/crop pixels, base/upgraded can at 22x22, water+ripple, native vs current-placement house+window-light, and one true 640x360 farming-context panel with the live HUD);
- `.import` sidecars for the nine paths generated by `godot --headless --path . --import` with the repo texture settings (`compress/mode=0`, `mipmaps/generate=false`, `process/fix_alpha_border=true`) and committed; no unrelated sidecars or cache added.

Nothing outstanding: HPA-458's mechanical gates are `./tools/verify-clean.sh` (which includes the extended world-shell smoke) plus `git diff --check main...HEAD` for text hygiene.
