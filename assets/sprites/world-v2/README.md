# world-v2 runtime art

Accepted HPA-861 art, promoted once for HPA-863. Generation prompts, processing
notes and the review conclusions stay with the source sheets in
`assets/sprites/hpa-861-review/README.md` (that folder is `.gdignore`d and
export-excluded; nothing under it may be referenced at runtime).

- `ground/<material>-phases.png`: 12 four-phase material sheets, four 64×32
  cells ordered `(0,0),(1,0),(0,1),(1,1)`; pick by cell parity
  `posmod(x,2) + 2*posmod(y,2)`.
- `ground/A-to-B.png`: 23 two-material transition sheets, 16 corner masks by
  four phase rows; mask bits are corner `(0,0),(1,0),(0,1),(1,1)`.
- `ground/multi-junctions.png` + `multi-junctions.json`: the indexed
  three-material corner tiles for the farm layout.
- `cutouts/*.png`: 50 accepted single-prop cutouts; 96×96 frames unless the
  review README states a larger multi-cell frame.
- `crops.png`: 128×144 crop atlas, 32×48 frames, rows Turnip/Potato/Pumpkin
  and columns growth stages 1–4 (`FarmView.CROP_TEXTURE`).
- `soil.png`: 128×32 tilled/wet soil atlas, 64×32 frames.

HPA-863 pruned the superseded review scaffolding from
`assets/sprites/hpa-861-review/`: the redundant `ground-v2/*-00..11.png`
splits, `tiles/`, individual `cutouts/crop-*.png` stages, candidate atlases,
previews, review scenes and stale `.import` sidecars are gone. Only the
generation source sheets, the prompt record and `.gdignore` remain there.
The legacy starting-farm and town source sheets/prompt record moved to
`assets/sprites/provenance/`, which is also `.gdignore`d and export-excluded.
Nothing under either provenance folder may be referenced at runtime.
`tools/stamp_farm_ground.gd` is the only writer of the farm ground TileSet
and cell data; `town_tileset.tres` carries the standalone town sources.
