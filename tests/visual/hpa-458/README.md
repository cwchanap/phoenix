# HPA-458 generated asset handoff

These runtime PNGs were generated for HPA-458 and normalized to the locked Phoenix geometry before commit. They are production candidates for the consumer tickets; runtime integration remains in HPA-459/HPA-460/HPA-462.

| Path | Size | hframes | Consumer | Notes |
| --- | ---: | ---: | --- | --- |
| `assets/sprites/polish/hoe-overlay.png` | 72x24 | 3 | HPA-459 | Generated pixel-art tool strip, frame order `DOWN, UP, SIDE`; no rotation. |
| `assets/sprites/polish/watering-can-overlay.png` | 72x24 | 3 | HPA-459 | Generated pixel-art tool strip, frame order `DOWN, UP, SIDE`; no rotation. |
| `assets/sprites/polish/soil-impact.png` | 96x32 | 3 | HPA-459 | Generated dirt-impact strip, cell-centered. |
| `assets/sprites/polish/planting-seed.png` | 8x8 | 1 | HPA-459 | Generated generic seed. |
| `assets/sprites/polish/water-splash.png` | 192x32 | 3 | HPA-459 | Generated splash source cleaned to transparent water-only frames. |
| `assets/sprites/polish/harvest-sparkle.png` | 48x16 | 3 | HPA-459 | Generated restrained sparkle strip. |
| `assets/ui/icons/watering-can-efficient.png` | 32x32 | 1 | HPA-460 | Generated upgraded-can candidate with non-text efficiency accent. |
| `assets/sprites/polish/river-ripple.png` | 192x32 | 3 | HPA-462 | Generated ripple source cleaned to transparent highlight-only frames. |
| `assets/sprites/polish/house-window-light.png` | 96x96 | 1 | HPA-462 | Generated warm window-light mask candidate; align against house frame 0 during HPA-462 integration. |

## Generation / cleanup

- Generated as transparent pixel-art source imagery with ChatGPT image generation.
- Normalized locally with nearest-neighbor resampling to the exact canvases above.
- Three-frame strips were split and repacked horizontally.
- Splash/ripple source images were color-masked so terrain/water backing pixels are not baked into the runtime overlays.
- Rejected large source generations are intentionally not committed.

## Remaining validation

- Composite tool frames against the actual four player facings and confirm handle attachment offsets.
- Composite `house-window-light.png` against current house frame 0 and adjust mask pixels if alignment needs correction.
- Verify native 640x360 readability and build the single final contact sheet before HPA-458 is considered complete.
