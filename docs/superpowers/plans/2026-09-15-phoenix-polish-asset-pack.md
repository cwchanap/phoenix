# Phoenix Farming and Homestead Polish Asset Pack Implementation Plan

**Linear:** HPA-458

**Goal:** Produce the nine small runtime PNGs and review/provenance material required by HPA-459, HPA-460, and HPA-462, while preserving the current Phoenix art contract and changing no gameplay code.

**Delivery shape:** One issue, one branch, one draft PR. Planning lands first; generation, cleanup, review, and final asset handoff continue on the same PR.

**Spec:** `docs/superpowers/specs/2026-09-15-phoenix-polish-asset-pack-design.md`

## Global constraints

- Branch: `agent/hpa-458-phoenix-polish-assets-plan`.
- Asset-only task. No runtime/gameplay implementation in this PR.
- Use actual committed Phoenix art as reference before generation.
- Keep 640x360, 64x32 isometric ground geometry, nearest filtering, integer scaling, and current anchoring conventions.
- Do not regenerate existing player, crop, soil, terrain, house, villager, portrait, or UI art.
- Do not add a sprite-generation pipeline, custom importer, asset registry, runtime manifest, shader system, or animation framework.
- Do not create four-direction tool sheets. One canonical overlay per tool is enough; the consumer owns runtime transforms.
- Generated output is source material, not automatically production-ready. Exact final canvas/frame geometry and alpha cleanup are required.
- Keep only selected accepted source generations in git.
- Consumer tickets own runtime integration:
  - HPA-459: action hints/effects/hold-to-work and farming SFX.
  - HPA-460: watering-can upgrade behavior/state/economy.
  - HPA-462: ripple/rain/evening presentation and ambience audio.

## Final runtime file map

```text
assets/sprites/polish/
├── hoe-overlay.png                 # ~24x24
├── watering-can-overlay.png        # ~24x24
├── soil-impact.png                 # 96x32, 3 x 32x32
├── planting-seed.png               # 8x8
├── water-splash.png                # 192x32, 3 x 64x32
├── harvest-sparkle.png             # 48x16, 3 x 16x16
├── river-ripple.png                # 192x32, 3 x 64x32
└── house-window-light.png          # 96x96

assets/ui/icons/
└── watering-can-efficient.png      # 32x32
```

Review/provenance material:

```text
docs/art/hpa-458/
├── README.md
├── source/
│   └── accepted source generations only
└── review/
    ├── contact-sheet.png
    ├── farming-actions.png
    └── homestead-ambience.png
```

---

## Task 1: Freeze the real visual baseline and handoff scaffold

The first implementation checkpoint should make the source-of-truth references and final filenames explicit before generating art.

### 1.1 Inspect current production references

- [ ] Review `assets/sprites/starting-farm-tiles-source.webp` and `starting-farm-props-source.webp` at native scale.
- [ ] Review `proof-player.png`, `proof-crops.png`, and `proof-soil.png` in the current farm composition.
- [ ] Review `assets/ui/icons/hoe.png` and `watering-can.png` at the actual current UI draw size.
- [ ] Confirm the existing house frame is the 96x96 source cell used by the current 2x world placement.
- [ ] Capture a small reference board locally for generation guidance; do not add a new runtime reference asset.

### 1.2 Create the handoff README skeleton

- [ ] Create `docs/art/hpa-458/README.md` with one row for each final runtime file.
- [ ] Include columns for source/prompt, final path, dimensions, frames, recommended timing, pivot/alignment, allowed transforms, consumer ticket, and cleanup notes.
- [ ] Add the exact final file map from this plan so later cleanup does not rename assets ad hoc.

### 1.3 Lock generation briefs

Use the design spec as the prompt contract. Keep prompts simple and isolated:

- tool overlay: one canonical transparent silhouette matching the existing tool;
- soil puff: three compact stages, expand/dissipate;
- seed: one generic readable seed;
- splash: three low ground-hugging stages inside one isometric tile;
- sparkle: three restrained frames;
- efficient can: existing-can identity plus one small non-text accent;
- ripple: three subtle water-surface frames;
- window mask: light pixels aligned to the existing house only.

Do not ask the generator for UI text, labels, complete gameplay screenshots, full directional player animation, weather/rain texture, or replacement terrain.

**Checkpoint:** commit the README scaffold/reference notes only if useful; otherwise keep Task 1 in the same asset commit as Task 2. Do not create a separate PR.

---

## Task 2: Generate and normalize the farming-feedback pack

This task produces the assets HPA-459 consumes.

### 2.1 Tool overlays

- [ ] Generate a small set of hoe candidates using the current player/hoe icon as reference.
- [ ] Select one candidate and clean it to `hoe-overlay.png` (~24x24 transparent canvas).
- [ ] Repeat for `watering-can-overlay.png`.
- [ ] Check both silhouettes against all four current player facings using local composites.
- [ ] Record safe runtime rotations/flips and the intended attachment/pivot in the README; do not generate four facing variants.

### 2.2 Soil impact

- [ ] Generate/select a compact dirt/puff concept.
- [ ] Normalize to three 32x32 frames in `soil-impact.png` (96x32 total).
- [ ] Keep the center/pivot fixed across all frames.
- [ ] Remove opaque/matte background and near-transparent fringe.

### 2.3 Planting seed

- [ ] Generate/select one generic seed.
- [ ] Normalize to `planting-seed.png` on an 8x8 transparent canvas.
- [ ] Verify it remains visible at native scale without becoming a large icon-like object.

### 2.4 Water splash

- [ ] Generate/select a small ground splash.
- [ ] Normalize to three 64x32 frames in `water-splash.png` (192x32 total).
- [ ] Keep the effect inside one ground diamond and direction-neutral.
- [ ] Ensure the frames read on both dry and wet soil without obscuring the tile state.

### 2.5 Harvest/readiness sparkle

- [ ] Generate/select one restrained sparkle sequence.
- [ ] Normalize to three 16x16 frames in `harvest-sparkle.png` (48x16 total).
- [ ] Check it on a mature crop and empty background; reject any large glow that would look permanent.

### 2.6 Farming contact composite

- [ ] Build `docs/art/hpa-458/review/farming-actions.png` using actual current farm/player/crop/soil art plus the normalized assets.
- [ ] Include representative hoe, plant, water, mature-target, and harvest states.
- [ ] Review at 1x and 2x before accepting this batch.

**Do not** implement HPA-459 animation, SFX, hold-state logic, or scene integration here.

---

## Task 3: Generate and normalize the upgrade/ambience pack

### 3.1 Efficient watering-can icon

- [ ] Use `assets/ui/icons/watering-can.png` as the identity/style reference.
- [ ] Generate/select a variant with one small non-text efficiency accent.
- [ ] Normalize to `assets/ui/icons/watering-can-efficient.png` on a 32x32 transparent canvas.
- [ ] Compare base/upgraded icons side by side at the real UI draw size; the upgraded icon must still read immediately as the same tool.

### 3.2 River ripple

- [ ] Generate/select a subtle water ripple sequence.
- [ ] Normalize to three 64x32 frames in `river-ripple.png` (192x32 total).
- [ ] Composite on the current river tile and verify every non-transparent pixel stays visually inside water.
- [ ] Keep all frames aligned; no scrolling water texture or shoreline replacement.

### 3.3 House-window light

- [ ] Derive the overlay from the current approved house frame rather than generating a new house.
- [ ] Produce `house-window-light.png` on the exact 96x96 source canvas.
- [ ] Leave all pixels transparent except the intended warm window-light areas.
- [ ] Composite directly over the current house at the existing 2x scene placement and verify alignment.

### 3.4 Homestead ambience composite

- [ ] Build `docs/art/hpa-458/review/homestead-ambience.png` with current river/house art plus ripple/window overlays.
- [ ] Do not add runtime rain streaks; HPA-462 owns those procedurally.
- [ ] Review at native 640x360 context and 2x.

---

## Task 4: Package the accepted source, runtime files, and review evidence

### 4.1 Keep only accepted source generations

- [ ] Store accepted generator originals under `docs/art/hpa-458/source/` using their original useful format.
- [ ] Remove rejected generations and redundant near-duplicates from the PR.
- [ ] Record the final prompt/provenance for each accepted source in `README.md`.

### 4.2 Verify runtime geometry and alpha mechanically

For every runtime PNG:

- [ ] Verify exact canvas dimensions.
- [ ] Verify alpha is present where required and no checkerboard/matte background is baked in.
- [ ] Verify strip width divides exactly into the required frame size.
- [ ] Inspect frame-to-frame bounds/pivot for jitter.
- [ ] Verify no effect is clipped against its frame edge unless intentionally fading to zero there.

Use one-off local image inspection/editing commands as needed; do not commit a general asset-processing script for nine files.

### 4.3 Build the final contact sheet

- [ ] Create `docs/art/hpa-458/review/contact-sheet.png` showing all nine runtime PNGs at native scale and integer 2x.
- [ ] Include the base/upgraded can comparison and the required current-art composites.
- [ ] Keep labels in the review sheet only.

### 4.4 Finish the handoff manifest

- [ ] Complete every README row with exact paths, dimensions, frame order, recommended frame time, alignment/pivot, allowed transforms, consumer issue, cleanup/provenance.
- [ ] Explicitly map HPA-459 to the six farming files, HPA-460 to the efficient-can icon, and HPA-462 to ripple/window files.
- [ ] State that consumer tickets must reuse these accepted files rather than regenerate substitutes.

---

## Task 5: Godot import and final asset-only verification

### 5.1 Import

- [ ] Run a clean Godot import after all runtime files are present:

```bash
godot --headless --path . --import
```

- [ ] Commit source-adjacent `.import` files produced by the repository's current workflow where appropriate.
- [ ] Confirm `.godot/` cache files are not added.

### 5.2 Regression gates

- [ ] Run:

```bash
git diff --check main...HEAD
./tools/verify-clean.sh
```

The asset PR intentionally does not add or update gameplay/E2E tests because none of these files is integrated into production scenes yet.

### 5.3 Final visual acceptance

- [ ] Inspect the final contact sheet and composites at native 1x and integer 2x.
- [ ] Confirm tools work visually with all four current facings.
- [ ] Confirm effects remain local/readable on representative farm tiles/crops.
- [ ] Confirm ripple/window overlays align to current river/house art.
- [ ] Confirm no existing production art has been replaced or modified unintentionally.

### 5.4 PR closeout

- [ ] Update the existing draft PR body with the final file inventory and verification evidence.
- [ ] Keep HPA-458 as the single asset-delivery PR; do not open follow-up generation/cleanup/approval PRs.
- [ ] After the pack is accepted/merged, HPA-459 becomes the next priority coding slice. HPA-462 is independently unblocked by the same merge; HPA-460 still waits for HPA-459.

---

## Self-review

Before moving the draft PR out of planning-only state, confirm:

- the task is still asset-only;
- exactly nine runtime PNGs cover the eight requested groups;
- no full player/NPC animation sheet was added;
- no rain/weather texture was generated;
- no existing crop/terrain/house/UI art was regenerated;
- no runtime asset registry/import pipeline/framework was introduced;
- tool facings rely on documented transforms, not duplicated direction sheets;
- source/review images stay outside runtime asset paths;
- only accepted source generations are retained;
- final files have exact frame geometry, clean alpha, and stable anchors;
- current-art composites were reviewed at 640x360 and integer 2x;
- HPA-459/HPA-460/HPA-462 handoff paths are explicit;
- implementation remains on this same branch and PR.