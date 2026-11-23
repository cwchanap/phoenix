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

## Runtime art (HPA-863)

`town-art-source.webp` remains the source sheet; `town-art-cutouts.png` and
`town-truck-views.png` preserve its intermediate transparent cutouts. The
retired runtime atlases `town-terrain.png` and `town-props.png` were deleted
in HPA-863 cleanup. Runtime now uses:

- `scenes/world/town_tileset.tres`: standalone grass/paving/road four-phase
  sources from `assets/sprites/world-v2/ground/*-phases.png`.
- `assets/sprites/world-v2/cutouts/{station,seed-shop,cafe,market}.png`:
  single 96×96 props, bottom-centre anchored on their existing footprints.
- `kei-truck.png`: two 96×96 cells, front view on the left and rear on the
  right.

Props and trucks are centred in their cells with their visible ground contact
on the bottom row. Use nearest filtering and place them under the existing
Y-sort owner with a separate ground-plane child shadow. Frames were reduced
with nearest-neighbour sampling and transparent edges were thresholded to
remove background speckles. Ground surfaces were cropped from the source and
masked to the 64×32 isometric diamond.

The town map is not present on this branch, so placement, tiling and scale
still need an in-game visual check when that map is available.
