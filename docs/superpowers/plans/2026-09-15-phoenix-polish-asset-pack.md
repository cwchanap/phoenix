# Phoenix Farming and Homestead Polish Asset Pack Implementation Plan

**Linear:** HPA-458  
**PR:** #15 / `agent/hpa-458-phoenix-polish-assets-plan`  
**Spec:** `docs/superpowers/specs/2026-09-15-phoenix-polish-asset-pack-design.md`

**Goal:** Produce the nine HPA-458 runtime image paths, one consumer README, one committed contact sheet, and the narrow existing-smoke verification needed by HPA-459/460/462. No gameplay integration or reusable asset machinery.

The spec's **Locked runtime contract** is the only planning-time geometry/origin table. Do not duplicate those numbers here. The final `tests/visual/hpa-458/README.md` becomes the shipped consumer handoff.

## Global constraints

- One issue / one branch / one PR.
- Reuse horizontal `hframes`; no SpriteFrames abstraction or animation framework.
- Tool facing is resolved in HPA-458 with the spec's bounded 1/2/3-frame contract; no texture rotation and no four-direction sheet.
- Efficient can edits the existing icon; window light derives from house frame 0.
- No registry, generator, custom importer, shader system, runtime manifest, migration, audio, rain texture, or gameplay change.
- No committed archive of generated-source originals; provenance lives in the README.
- Only `tests/visual/hpa-458/contact-sheet.png` is committed as review imagery.

---

## Task 1: Establish the import guards and handoff scaffold

Do this before any image generation/editing is imported by Godot.

- [ ] Add `assets/art/.gdignore` so any local/untracked source-art tree cannot generate unrelated Godot `.import` sidecars.
- [ ] Add `tests/visual/hpa-458/.gdignore`.
- [ ] Create `tests/visual/hpa-458/README.md` with one row per runtime path from the spec.
- [ ] Copy the **contract values from the spec once** into the README: final path, selected dimensions/hframes, frame mapping/frame-0 meaning, origin/attachment, allowed transforms, consumer, recommended timing, provenance/edit notes.
- [ ] Keep `assets/ui/fonts/SOURCES.md` unchanged and font-specific.

The README is the artifact proving the current repo conventions were read correctly; there is no separate checklist-only inspection task.

---

## Task 2: Produce HPA-459 farming-feedback assets

### 2.1 Resolve each tool-facing contract

For hoe and watering can independently:

- [ ] Start with an exact 24x24 DOWN-canonical silhouette.
- [ ] Composite it locally against the actual four `proof-player.png` frames.
- [ ] Tune numeric per-facing attachment offsets; never rotate the texture.
- [ ] If UP needs distinct art, use the spec's 48x24 `DOWN,UP` fallback.
- [ ] If side facings need distinct art, use the 72x24 `DOWN,UP,SIDE` fallback and mirror SIDE only if both real side composites pass.
- [ ] If the bounded three-frame form still fails, redesign the silhouette within HPA-458 rather than adding four-direction art or deferring the decision.
- [ ] Record the selected dimensions, hframes/frame mapping, attachment offsets, and transform permissions in the README.

Working facing composites are temporary selection aids; do not commit them separately.

### 2.2 Produce the four farming effects

Following the spec contract and style lanes:

- [ ] `soil-impact.png`: geometric dirt/puff sequence; stable center and clean alpha.
- [ ] `planting-seed.png`: tiny generic seed; readable at native output size.
- [ ] `water-splash.png`: ground-hugging splash within one diamond; preserve dry/wet soil readability.
- [ ] `harvest-sparkle.png`: restrained crop-space cue; choose and record its numeric local offset.

Use actual proof soil/crops for local working previews. Do not commit a separate farming-actions raster.

---

## Task 3: Produce HPA-460/HPA-462 assets

- [ ] Edit existing `assets/ui/icons/watering-can.png` into `watering-can-efficient.png` with one small non-text accent; compare at the real 22x22 HUD size.
- [ ] Produce `river-ripple.png` as an extra-subtle overlay on actual current water; all visible pixels stay in water.
- [ ] Derive `house-window-light.png` from native house frame 0; review native alignment first, then current scale-2 / `(0,-48)` placement.

Working ambience previews are temporary; do not commit a separate homestead-ambience raster.

---

## Task 4: Finish handoff and one committed visual review artifact

### 4.1 Complete the README

For every runtime path, fill in:

- provenance/source/edit method and prompt where relevant;
- final selected geometry/hframes/frame mapping;
- frame 0 meaning and recommended timing;
- origin convention and numeric attachment/local offset;
- allowed transforms;
- consumer ticket;
- cleanup performed.

No `source/` directory is committed.

### 4.2 Build only `tests/visual/hpa-458/contact-sheet.png`

The contact sheet must be a superset of the temporary working previews and include:

- final tool-facing composites on all four real player poses;
- soil/seed/splash/sparkle on actual farm/crop pixels;
- base/upgraded can at 22x22;
- current water + ripple;
- native and current-placement house + window mask;
- one true `640x360` farming-context panel with the current HUD visible, using the existing `tests/visual/plates/farm.png` / production-capture convention.

Optional 2x detail panels are fine, but the real 640x360 view is mandatory. Do not add this sheet to UI visual goldens.

### 4.3 Manual visual gates

Review the contact sheet for qualities that the smoke should not try to infer:

- matte fringe / stray near-transparent noise;
- visible clipping;
- frame-to-frame visual anchor jitter;
- style drift;
- readability versus restraint at 640x360;
- tool/house/ripple alignment.

---

## Task 5: Extend the existing smoke and verify clean import

### 5.1 Extend `EXPECTED_ASSETS`, not the test framework

Add the nine HPA-458 paths with exact accepted `size` and `hframes` to the existing table. Keep existing rows compatible by defaulting missing `hframes` to 1 if that minimizes churn.

Extend the current asset loop to assert for each HPA-458 runtime image:

- [ ] texture imports and exact dimensions match;
- [ ] width divides evenly by `hframes`;
- [ ] every frame has at least one non-transparent pixel;
- [ ] every frame has at least one transparent pixel, rejecting a fully opaque baked background.

Do not claim this proves matte/fringe/jitter quality; Task 4.3 owns those visual checks.

### 5.2 Import after both `.gdignore` guards exist

Run:

```bash
godot --headless --path . --import
```

Then:

- [ ] inspect `git status --short` and reject unrelated `.import`/cache additions;
- [ ] verify the nine runtime sidecars use current repo texture settings (`compress/mode=0`, no mipmaps, `fix_alpha_border=true`);
- [ ] never commit `.godot/` cache files or copied UID/cache paths.

### 5.3 Final gates

Run:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
```

Treat `git diff --check` as text hygiene only, not the asset regression oracle. `verify-clean.sh` + the extended world smoke are the mechanical asset gates.

No gameplay/E2E suite is added because these files are not integrated into production behavior yet.

### 5.4 Closeout

- [ ] Update PR #15 with the final file inventory, selected tool-facing layouts, smoke/import evidence, and one contact-sheet review note.
- [ ] Keep HPA-458 as the only delivery PR.
- [ ] After merge, HPA-459 becomes the next priority coding slice; HPA-462 is independently unblocked; HPA-460 still waits for HPA-459.

---

## Self-review

Before handoff:

- exactly nine runtime paths remain;
- each tool resolves inside the bounded 24x24 / 48x24 / 72x24 contract;
- no texture rotation or four-direction tool sheet exists;
- no committed source-generation archive or extra review PNGs exist;
- one contact sheet contains a real 640x360 HUD-visible farming context;
- README is the only consumer-facing handoff copy of the spec contract;
- `assets/art/.gdignore` exists before import;
- `tests/visual/hpa-458/.gdignore` protects review material;
- existing smoke validates size, hframes partition, per-frame non-empty alpha, and transparency;
- visual review covers fringe/clipping/jitter/style/alignment;
- import produces no unrelated sidecars;
- no gameplay/runtime integration or new framework is introduced.