# Phoenix Farming and Homestead Polish Asset Pack Implementation Plan

**Linear:** HPA-458

**Goal:** Produce the nine small runtime PNG paths and ignored review/provenance material required by HPA-459, HPA-460, and HPA-462, with consumer geometry/facing contracts locked before handoff and no gameplay integration.

**Delivery shape:** One issue, one branch, one draft PR. Planning lands first; generation/editing, cleanup, review, verification, and final handoff continue on the same PR.

**Spec:** `docs/superpowers/specs/2026-09-15-phoenix-polish-asset-pack-design.md`

## Global constraints

- Branch: `agent/hpa-458-phoenix-polish-assets-plan` / PR #15.
- Asset-focused task. No runtime/gameplay integration.
- A narrow update to `tests/headless/world_shell_smoke.gd::EXPECTED_ASSETS` is required to pin the final asset paths and dimensions.
- Keep 640x360, 64x32 isometric ground geometry, nearest filtering, integer scaling, and current sprite origins.
- Do not regenerate existing player, crop, soil, terrain, house, villager, portrait, or general UI art.
- Do not add a generator, custom importer, asset registry, runtime manifest, shader system, animation framework, or SpriteFrames abstraction.
- Horizontal frame strips use existing `hframes`; do not introduce another animation representation.
- No four-direction player/tool sheet. The bounded fallback is at most two tool frames (`DOWN, UP`) on the same final path when the real UP-facing composite proves one frame insufficient.
- `flip_h` may be accepted for reviewed side facings. Rotation is never a legal facing transform.
- Generated output is source material; exact final geometry and alpha cleanup happen before acceptance.
- Keep only accepted source generations/edits in git.
- Consumer ownership remains:
  - HPA-459: action hints/effects/hold-to-work and farming SFX.
  - HPA-460: watering-can upgrade behavior/state/economy.
  - HPA-462: ripple/rain/evening presentation and ambience audio.

## Locked style lanes

- Soil impact / seed / splash / sparkle: geometric proof-soil/proof-crop language.
- Tool overlays: simple silhouettes that read on `proof-player.png`; use existing tool icons for identity only.
- Efficient can: edit `assets/ui/icons/watering-can.png` and add one accent; do not regenerate the can.
- River ripple: extra-subtle overlay on current water.
- Window light: derive from native house frame 0; do not generate a new house.

## Final runtime paths and geometry

```text
assets/sprites/polish/
├── hoe-overlay.png                 # 24x24, or 48x24 hframes=2 DOWN/UP only if facing gate requires it
├── watering-can-overlay.png        # same conditional contract
├── soil-impact.png                 # 96x32, hframes=3, 3 x 32x32
├── planting-seed.png               # 8x8
├── water-splash.png                # 192x32, hframes=3, 3 x 64x32
├── harvest-sparkle.png             # 48x16, hframes=3, 3 x 16x16
├── river-ripple.png                # 192x32, hframes=3, 3 x 64x32
└── house-window-light.png          # 96x96

assets/ui/icons/
└── watering-can-efficient.png      # 32x32, reviewed at 22x22
```

Origin locks:

- `soil-impact`, `planting-seed`, `water-splash`, `river-ripple`: cell-center like current soil; no extra world offset.
- `harvest-sparkle`: crop-sprite space, bottom-center; handoff records one numeric upward local offset.
- tool overlays: child of player sprite; handoff records numeric handle attachment from the accepted 24x24 frame origin.
- `house-window-light`: current House presentation, native 96x96, parent scale 2, local offset `(0, -48)`.
- `watering-can-efficient`: native 32x32; current HUD draw rectangle is 22x22.

## Ignored review/provenance layout

Use the established visual-reference convention rather than an importable docs raster tree:

```text
tests/visual/hpa-458/
├── .gdignore
├── README.md
├── source/
│   └── accepted source generations/edits only
└── review/
    ├── contact-sheet.png
    ├── farming-actions.png
    └── homestead-ambience.png
```

The README is the image provenance/handoff table. Keep `assets/ui/fonts/SOURCES.md` font-specific.

---

## Task 1: Freeze real repo contracts before producing art

### 1.1 Inspect current production references and conventions

- [ ] Inspect `starting-farm-tiles-source.webp`, `starting-farm-props-source.webp`, final terrain/props PNGs, `proof-player.png`, `proof-crops.png`, and `proof-soil.png` at native scale.
- [ ] Inspect `assets/ui/icons/hoe.png` and `watering-can.png` at native 32x32 and the current watering-can 22x22 HUD draw size.
- [ ] Confirm `FarmView` soil placement is cell-center, crops are bottom-center with local `-24` Y offset, and strips use `hframes`.
- [ ] Confirm player facing order is `UP, RIGHT, DOWN, LEFT` and player frame is assigned directly from that enum.
- [ ] Confirm House frame 0 uses native 96x96 source art, parent scale 2, and sprite offset `(0, -48)`.
- [ ] Confirm existing image import parameters (`compress/mode=0`, no mipmaps, `fix_alpha_border=true`) and nearest default filtering.

### 1.2 Create ignored review/provenance scaffold

- [ ] Create `tests/visual/hpa-458/.gdignore` before adding any source/review raster.
- [ ] Create `tests/visual/hpa-458/README.md` with one row per final runtime path.
- [ ] Include columns for source/edit provenance, final path, exact dimensions, `hframes`, frame order/frame 0 meaning, recommended timing, origin convention, numeric local attachment/offset where applicable, allowed transforms, consumer, and cleanup.

### 1.3 Lock briefs by style lane

- [ ] Farming FX prompts/edit briefs explicitly reference proof soil/crops and request geometric compact effects.
- [ ] Tool briefs request simple DOWN-canonical silhouettes against the actual player poses, not UI-style rendered icons.
- [ ] Efficient can starts from the existing `watering-can.png` pixels and receives one small accent.
- [ ] Ripple starts from the existing water appearance; no replacement tile.
- [ ] Window light is extracted/authored against house frame 0; no cottage generation.

**Checkpoint:** planning/reference scaffold may share a commit with the first accepted files; do not make another PR.

---

## Task 2: Produce and lock the HPA-459 farming-feedback pack

### 2.1 Tool-facing gate

For **each** tool:

- [ ] Produce/select one DOWN-canonical silhouette on an exact `24x24` transparent canvas.
- [ ] Composite it on the actual four `proof-player.png` frames (`UP, RIGHT, DOWN, LEFT`), not a rotated/redrawn player, at native 1x and integer 2x.
- [ ] Test reviewed horizontal mirroring for side facings. Do not rotate the texture.
- [ ] If UP does not read correctly, change the same final path to exact `48x24`, `hframes=2`, order `DOWN, UP`.
- [ ] Resolve this decision inside HPA-458. HPA-459 must not decide later that another facing asset is needed.
- [ ] Record final dimensions/hframes, frame 0 meaning, numeric handle attachment, and allowed mirroring in the README.

### 2.2 Soil impact

- [ ] Produce a compact geometric dirt/puff sequence.
- [ ] Normalize to exact `96x32`, `hframes=3`, three `32x32` frames.
- [ ] Use cell-center origin with no extra world offset.
- [ ] Keep center stable across all frames and clean matte/alpha noise.

### 2.3 Planting seed

- [ ] Produce one generic geometric seed on exact `8x8` transparent canvas.
- [ ] Use cell-center origin with no extra world offset.
- [ ] Verify it reads at native scale without becoming an icon-like blob.

### 2.4 Water splash

- [ ] Produce a geometric ground splash on exact `192x32`, `hframes=3`, three `64x32` frames.
- [ ] Use cell-center origin; keep all visible pixels inside one ground diamond.
- [ ] Verify on actual dry and wet proof-soil context without hiding the soil state.

### 2.5 Harvest/readiness sparkle

- [ ] Produce a restrained sequence on exact `48x16`, `hframes=3`, three `16x16` frames.
- [ ] Composite in actual crop-sprite space on a mature proof crop.
- [ ] Choose and record one numeric upward local offset from the crop bottom-center origin.
- [ ] Reject large glows or painterly effects.

### 2.6 Farming review composite

- [ ] Build `tests/visual/hpa-458/review/farming-actions.png` from actual current player/farm/crop/soil pixels plus normalized assets.
- [ ] Show all four real player frames for each tool-facing decision, plus hoe/plant/water/mature-target/harvest examples.
- [ ] Review at 1x and 2x.

Do not implement HPA-459 scene nodes, animation timing, SFX, hold state, hints, or command dispatch.

---

## Task 3: Produce HPA-460/HPA-462 upgrade and ambience files

### 3.1 Efficient watering-can icon

- [ ] Copy/edit the existing `assets/ui/icons/watering-can.png`; do not ask a generator to redraw it.
- [ ] Add one small non-text efficiency accent and normalize to exact `32x32`.
- [ ] Compare base/upgraded at native 32x32 and the real `22x22` HUD draw size.

### 3.2 River ripple

- [ ] Produce an extra-subtle ripple sequence on exact `192x32`, `hframes=3`, three `64x32` frames.
- [ ] Use cell-center origin with no extra world offset.
- [ ] Composite on the actual current water tile; all visible pixels must remain inside water.
- [ ] Keep current baked water texture/sparkles readable; do not repaint water or shoreline.

### 3.3 House-window light

- [ ] Derive the mask directly from native house frame 0 on exact `96x96` canvas.
- [ ] Leave everything except intended window-light pixels transparent.
- [ ] Review first on the native 96x96 house frame, then with current parent scale 2 and local offset `(0, -48)`.
- [ ] Reject any one-pixel source drift that becomes visibly misaligned at 2x.

### 3.4 Homestead review composite

- [ ] Build `tests/visual/hpa-458/review/homestead-ambience.png` from the actual current water/house art plus ripple/window overlays.
- [ ] Do not create rain textures; HPA-462 owns runtime-drawn/emitter rain.
- [ ] Review at native context and integer 2x.

---

## Task 4: Package accepted source and mechanical asset checks

### 4.1 Keep only accepted source material

- [ ] Store only accepted source generations/edits under `tests/visual/hpa-458/source/`.
- [ ] Remove rejected generations and near-duplicates.
- [ ] Record prompts/source/edit provenance in the README.

### 4.2 Verify geometry and alpha locally

For every runtime PNG:

- [ ] Verify exact final canvas dimensions.
- [ ] Verify real alpha, no checkerboard/matte background, no visible fringe, and no stray near-transparent noise.
- [ ] For strips, verify width divides exactly by the frame contract and frames do not jitter.
- [ ] Verify no effect is accidentally clipped at a frame edge.
- [ ] Verify the final tool size matches the Task 2.1 decision (`24x24` or the bounded `48x24` fallback).

Use one-off inspection/editing commands only; do not add a general image-processing pipeline for nine files.

### 4.3 Build final contact sheet

- [ ] Create `tests/visual/hpa-458/review/contact-sheet.png` showing all nine runtime paths at native scale and 2x.
- [ ] Include final tool-facing composites, base/upgraded can at 22x22, actual water+ripple, and native/current-placement house+mask.
- [ ] Keep labels in review rasters only.

### 4.4 Complete the handoff table

- [ ] Record exact paths, dimensions, hframes/frame order, frame 0 meaning, timing recommendation, origin convention, numeric local attachment/offset where needed, transform permissions, consumer, and provenance/cleanup.
- [ ] Explicitly state `rotate = no` for tool-facing synthesis.
- [ ] Map HPA-459 to six farming paths, HPA-460 to the efficient can, and HPA-462 to ripple/window.
- [ ] State consumer tickets reuse accepted assets rather than regenerate substitutes.

---

## Task 5: Reuse the existing import/dimension smoke and finish verification

### 5.1 Add the nine final assets to the existing smoke

- [ ] Extend `tests/headless/world_shell_smoke.gd::EXPECTED_ASSETS` with all nine runtime paths and exact accepted dimensions.
- [ ] Use the Task 2.1 final tool dimensions; do not leave approximate or wildcard sizes.
- [ ] Do not add a new test file or asset-validation framework.

### 5.2 Import using existing texture settings

- [ ] Run a clean Godot import:

```bash
godot --headless --path . --import
```

- [ ] Verify generated sidecars follow the existing texture settings: `compress/mode=0`, no mipmaps, `process/fix_alpha_border=true`.
- [ ] Let Godot create correct per-file UID/cache metadata; do not copy another asset's UID/path literally.
- [ ] Commit source-adjacent `.import` sidecars as required by the current repo workflow; never commit `.godot/` cache files.

### 5.3 Regression gates

- [ ] Run:

```bash
git diff --check main...HEAD
./tools/verify-clean.sh
```

No gameplay/E2E tests are added because the assets are not integrated into production behavior. The existing world smoke is the geometry/import oracle for this asset-only slice.

### 5.4 Final visual acceptance and PR closeout

- [ ] Re-review contact sheet/composites at 1x/2x.
- [ ] Confirm every tool-facing path is already resolved for HPA-459.
- [ ] Confirm farming FX match the geometric proof-world style, not the painterly homestead/UI style.
- [ ] Confirm ripple/window overlays align to actual current water/house art.
- [ ] Confirm source/review rasters remain behind `.gdignore` and no production scene depends on them.
- [ ] Update this same draft PR body with final inventory, facing decisions, and verification evidence.
- [ ] After merge, HPA-459 is the next priority coding slice; HPA-462 is independently unblocked; HPA-460 still waits for HPA-459.

---

## Risks and explicit gates

1. **Tool-facing mismatch** — gate on actual player frames 0-3; allow only `flip_h`, with bounded two-frame DOWN/UP fallback decided in HPA-458.
2. **House-mask alignment drift** — author/review at native 96x96 first, then current 2x placement; do not eyeball only the displayed 192x192 result.
3. **Generator style drift** — enforce separate style lanes and composite against actual proof-world pixels before investing in cleanup.

---

## Self-review

Before production work is considered ready for consumer handoff, confirm:

- task remains asset-focused and one PR;
- exactly nine runtime paths cover the eight requested groups;
- all fixed canvases are exact; tool size is resolved to one of the two bounded contracts;
- no tool texture uses rotation for facing;
- no four-direction character/tool sheet was added;
- no rain/weather texture was generated;
- efficient can is an edit of the existing icon;
- window mask comes from house frame 0 on native 96x96;
- style lanes are explicit and validated against actual repo art;
- source/review rasters live under `tests/visual/hpa-458/.gdignore`;
- README records origins, hframes/frame order, frame 0 meaning, numeric local attachments/offsets, transforms, consumers, and provenance;
- existing `EXPECTED_ASSETS` pins all nine runtime paths and exact final dimensions;
- import settings match existing repo conventions without copied UIDs/cache paths;
- `git diff --check` and `./tools/verify-clean.sh` pass;
- no runtime/gameplay integration is included.