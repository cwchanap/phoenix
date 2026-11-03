# Town art source

`town-art-source.webp` is the lossless WebP conversion of a generated source
sheet, using the two committed `starting-farm-*-source.webp` sheets as visual
references. It contains, from left to right:

| Row | Artwork |
| --- | --- |
| 1 | Town paving, road, station, seed and hardware shop |
| 2 | Cafe, market stall, kei truck front view, kei truck rear view |

The sheet is source artwork, not a runtime atlas. It has a magenta background
and the ground tiles include raised edges. `town-art-cutouts.png` preserves the
generated transparent-background edit used to prepare the four prop frames.

`town-truck-views.png` preserves the separately generated isolation based on
the two truck views in the source sheet. Its front view is on the left and its
rear view is on the right.

## Runtime atlases

- `town-terrain.png`: three 64×32 diamond cells, left to right: paving, marked
  road, plain asphalt. The marked cell includes curb markings; use the plain
  cell for continuous road areas. Both road cells come from the source road.
- `town-props.png`: four 96×96 cells in a 2×2 grid: station and seed shop on
  the first row, cafe and market stall on the second.
- `kei-truck.png`: two 96×96 cells: front view on the left, rear on the right.

Props and trucks are centred in their cells with their visible ground contact
on the bottom row. Use nearest filtering and place them under the existing
Y-sort owner with a separate ground-plane child shadow. Frames were reduced
with nearest-neighbour sampling and transparent edges were thresholded to
remove background speckles. Ground surfaces were cropped from the source and
masked to the 64×32 isometric diamond.

The town map is not present on this branch, so placement, tiling and scale
still need an in-game visual check when that map is available.
