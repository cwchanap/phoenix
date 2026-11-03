# Town art source

`town-art-source.webp` is the lossless WebP conversion of a generated source
sheet, using the two committed `starting-farm-*-source.webp` sheets as visual
references. It contains, from left to right:

| Row | Artwork |
| --- | --- |
| 1 | Town paving, road, station, seed and hardware shop |
| 2 | Cafe, market stall, kei truck front view, kei truck rear view |

The sheet is source artwork, not a runtime atlas. It has a magenta background
and the ground tiles include raised edges. Before use, extract and clean the
sprites, fit ground surfaces to the 64×32 diamond contract, and verify the
two truck views and prop scale in the game. Preserve this source sheet when
creating those derived assets.

`town-truck-views.png` is a generated isolation based on the two truck views
in the source sheet. It has a transparent background, with the front view on
the left and rear view on the right. It is also source artwork: prepare and
check the final sprite frames at the game's pixel scale before use.
