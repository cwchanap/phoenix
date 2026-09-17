# HPA-458 generated asset handoff

These runtime PNGs were generated for HPA-458 and normalized to the locked Phoenix geometry before commit. They are production candidates for the consumer tickets; runtime integration remains in HPA-459/HPA-460/HPA-462.

| Path | Size | hframes | Consumer | Notes |
| --- | ---: | ---: | --- | --- |
| `assets/sprites/polish/hoe-overlay.png` | 72x24 | 3 | HPA-459 | Frame order `DOWN, UP, SIDE`; no rotation. SIDE mirrors for LEFT. |
| `assets/sprites/polish/watering-can-overlay.png` | 72x24 | 3 | HPA-459 | Frame order `DOWN, UP, SIDE`; no rotation. SIDE mirrors for LEFT. |
| `assets/sprites/polish/soil-impact.png` | 96x32 | 3 | HPA-459 | Generated dirt-impact strip, cell-centered. |
| `assets/sprites/polish/planting-seed.png` | 8x8 | 1 | HPA-459 | Generated generic seed, cell-centered. |
| `assets/sprites/polish/water-splash.png` | 192x32 | 3 | HPA-459 | Generated splash source cleaned to transparent water-only frames, cell-centered. |
| `assets/sprites/polish/harvest-sparkle.png` | 48x16 | 3 | HPA-459 | Generated restrained sparkle strip; crop-sprite-space presentation. |
| `assets/ui/icons/watering-can-efficient.png` | 32x32 | 1 | HPA-460 | Generated upgraded-can candidate with non-text efficiency accent; review at 22x22 HUD draw size. |
| `assets/sprites/polish/river-ripple.png` | 192x32 | 3 | HPA-462 | Generated ripple source cleaned to transparent highlight-only frames, cell-centered. |
| `assets/sprites/polish/house-window-light.png` | 96x96 | 1 | HPA-462 | Warm window-light mask candidate; must remain aligned to house frame 0 / House scale 2. |

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

## Generation / cleanup

- Generated as transparent pixel-art source imagery with ChatGPT image generation.
- Normalized locally with nearest-neighbor resampling to the exact canvases above.
- Three-frame strips were split and repacked horizontally.
- Splash/ripple source images were color-masked so terrain/water backing pixels are not baked into the runtime overlays.
- Rejected large source generations are intentionally not committed.
- Review/source material stays behind `tests/visual/hpa-458/.gdignore`; `assets/art/.gdignore` prevents unrelated local source art from being imported.

## Validation status

Completed:

- exact runtime dimensions for all nine paths;
- transparent runtime canvases and evenly partitioned strips;
- hoe/watering-can facing decision against all four committed player frames;
- fixed tool attachment positions and transform permissions;
- native-scale farming-context review using committed proof player/soil/crop pixels plus the generated FX.

Still required before HPA-458 is marked Done:

- pixel-level `house-window-light.png` alignment against the actual current house frame 0;
- the single final committed contact sheet, including the 640x360 context and final house-mask comparison;
- repository-side import/smoke verification for the nine paths.
