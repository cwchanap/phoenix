# Phoenix River and Rain Ambience Audio Assets Design

**Linear:** HPA-440
**Repository:** `cwchanap/phoenix`
**Branch:** `agent/hpa-440-river-rain-audio-plan`
**Base reviewed:** `main` at `e3bead7d2d752559d4f2410e7b3c4cec0ae6712b`
**Delivery:** one HPA-440 asset-only PR; HPA-402 remains blocked until this PR merges.

## Goal

Produce exactly two small, neutral ambience loops for the Phoenix homestead:

- `assets/audio/river-ambience.wav`
- `assets/audio/rain-ambience.wav`

They must be project-owned, source-level mono 16-bit PCM at 22050 Hz, approximately 4-6 seconds long, quiet enough to sit below farming feedback, and configured by Godot to forward-loop over the full clip without an obvious seam.

This ticket stops at the asset boundary. HPA-402 owns runtime players, Sound-setting integration, weather-driven playback, and lifecycle behavior.

## Why this is the next actionable slice

HPA-440 is the only unblocked Phoenix Todo. HPA-402 explicitly depends on these exact two paths and forbids placeholders or self-generated substitute WAVs on its branch. HPA-462 / PR #19 already shipped the visual river/rain presenter and left audio integration to the HPA-440 -> HPA-402 handoff.

## Existing conventions to reuse

- `assets/audio/README.md` already records project-generated audio provenance and one-off synthesis recipes rather than committing a reusable generator framework.
- Existing Phoenix audio is mono/stereo WAV imported as `AudioStreamWAV`; looping music uses `.import` metadata with `edit/loop_mode=2`, `edit/loop_begin=0`, and `edit/loop_end=-1`.
- `tests/headless/project_smoke.gd` already performs narrow resource-existence checks and runs inside `./tools/verify-clean.sh`.
- The repository commits source-adjacent `.import` sidecars; only `.godot/` generated import cache is ignored.
- HPA-402 will apply an additional fixed `-12 dB` ambience headroom at runtime, so HPA-440 should not compensate by making the source aggressively loud.

Do not introduce a second audio asset convention for two files.

## Considered approaches

### 1. Deterministic Python-stdlib synthesis — selected

Generate both loops locally with Python's standard library only (`wave`, `math`, `random`, `struct`) and fixed seeds. Build the texture from many periodic harmonic components whose frequencies complete an integer number of cycles in the 5-second clip, so the loop boundary is phase-continuous by construction.

Use separate spectral envelopes for river and rain rather than adding authored events such as birds, drops, thunder, or splashes.

Why this fits:

- no sample licensing or attribution burden;
- exact source format is under our control;
- deterministic/project-owned provenance is easy to document;
- a 5-second mono 22050 Hz PCM asset is small enough that no generation pipeline is justified;
- phase-continuous synthesis avoids adding a crossfade processor or audio-editing dependency merely to hide the seam.

The generation script is a temporary local implementation aid, not a shipped tool. Record the exact algorithm class, loop length, seeds, spectral ranges, and fixed gains in `assets/audio/README.md` so future regeneration is possible without maintaining a one-use framework.

### 2. External generative-audio service — rejected

This could sound more natural on the first pass, but it adds an external dependency, weaker reproducibility, more provenance questions, and post-processing work to guarantee exact PCM format and seamless looping. That is unnecessary for two deliberately restrained background textures.

### 3. Recorded field ambience — rejected

Self-recording would avoid third-party licensing, but it is slower to produce, harder to make deterministic, and still needs editing/de-noising/loop work. The ticket does not need photorealistic field audio.

## Locked source contract

Both source WAVs use:

- duration: exactly `5.0 s`;
- sample rate: `22050 Hz`;
- channels: mono;
- sample width: 16-bit signed PCM;
- sample count: `110250` frames;
- no embedded music, voice, wildlife, thunder, wind gusts, or discrete dramatic events;
- conservative fixed synthesis gain; no normalization to full scale;
- final absolute sample peak must remain below `0.30` full scale.

The `< 0.30` peak ceiling is a safety guard, not a loudness target. Manual review still decides whether either loop competes with farming cues.

### River recipe

Use seed `44001`.

Build a low/mid broadband water bed from deterministic periodic harmonic layers:

- strongest energy in roughly `90-900 Hz`;
- lighter texture extending to about `2200 Hz`;
- several slow periodic amplitude-modulation components below `2 Hz` so the bed breathes without producing a beat or melody;
- no isolated transients or splash events.

The result should read as nearby moving water rather than white noise.

### Rain recipe

Use seed `44002`.

Build a brighter, denser periodic noise texture:

- broad energy in roughly `700-7000 Hz`;
- lighter low-mid body so the loop does not become a thin hiss;
- slow periodic density/amplitude variation below `3 Hz`;
- no thunder, gusts, pitched drops, or discrete impact events.

The result should be clearly distinguishable from the river while remaining steady enough to support HPA-462's visual rain streaks.

## Seam strategy

Do not generate arbitrary noise and repair it with an editor crossfade afterward.

Every oscillator/component used for the final loop must complete an integer number of cycles inside the exact 5-second period. Randomness selects amplitudes/phases from the fixed seed, not non-periodic sample positions. This makes the synthetic waveform periodic at the source and removes a separate destructive seam-editing step.

A manual repeated-loop listen remains required because mathematical continuity can still produce a perceptually obvious repeating texture even when there is no click.

## Godot import contract

After the two WAVs exist, run the normal Godot import and commit the generated sidecars:

- `assets/audio/river-ambience.wav.import`
- `assets/audio/rain-ambience.wav.import`

The sidecars must use full-clip forward looping:

- `edit/loop_mode=2` (Forward import mode);
- `edit/loop_begin=0`;
- `edit/loop_end=-1`.

Do not add loop markers to the source WAV, a custom importer, `.tres` wrapper, `AudioStreamRandomizer`, or alternate Ogg/MP3 copies.

Godot's imported runtime resource must load as `AudioStreamWAV`, report `mix_rate == 22050`, remain mono, use `AudioStreamWAV.LOOP_FORWARD`, and have a duration within 4-6 seconds.

The source file's PCM-16 requirement is verified from the WAV container separately because Godot may compress imported WAV data internally.

## Provenance and handoff

Extend the existing `assets/audio/README.md`; do not create a second audio provenance document.

Add one HPA-440 section recording for each file:

- exact runtime path;
- purpose / sonic lane;
- `5.0 s`, mono, PCM-16, `22050 Hz`;
- fixed seed (`44001` river, `44002` rain);
- periodic-harmonic synthesis approach and spectral ranges;
- conservative source-gain / `< 0.30` peak rule;
- no external samples or third-party attribution;
- full-clip forward-loop import contract;
- HPA-402 as the runtime consumer.

Do not commit the temporary local generator or intermediate candidate audio. Git history needs only the accepted runtime assets and the compact deterministic recipe.

## Mechanical verification

Reuse `tests/headless/project_smoke.gd`; do not add an audio-test framework.

Add the two ambience paths to a small audio-resource validation loop that asserts:

1. `ResourceLoader.exists(path)`;
2. `ResourceLoader.load(path)` is `AudioStreamWAV`;
3. `mix_rate == 22050`;
4. `stereo == false`;
5. `loop_mode == AudioStreamWAV.LOOP_FORWARD`;
6. `get_length()` is between `4.0` and `6.0` seconds.

Keep source-container validation as a one-shot implementation check using Python stdlib `wave`:

- 1 channel;
- 2-byte sample width;
- 22050 Hz;
- 110250 frames;
- peak below 0.30 full scale.

Do not teach production code about these asset-generation constraints.

## Audible acceptance

Mechanical checks cannot judge whether the textures are pleasant or whether a repeating pattern is distracting.

Before closeout, loop each asset continuously for at least 30 seconds and compare it at equal playback gain against the existing farming success cues:

- River must be quieter and less attention-grabbing than `farm-hoe.wav` / `farm-harvest.wav`.
- Rain must be quiet enough to sit under UI/SFX and must not contain a conspicuous rhythmic pulse.
- Neither loop may click at the seam.
- River and Rain must be obviously distinguishable within a few seconds.

Use a disposable local Godot/editor preview if needed; no preview scene or runtime playback code is committed under HPA-440.

## Risks

1. **Synthetic texture sounds tonal** — use many randomly phased integer-cycle components and reject candidates with obvious pitch/beat character.
2. **No click but obvious five-second repetition** — manual 30-second looping review rejects repeating swells or distinctive events.
3. **Rain becomes harsh hiss** — keep some low-mid body and cap source peak rather than brightening through amplitude.
4. **River competes with farm feedback** — source stays conservative; HPA-402 also applies `-12 dB` runtime headroom.
5. **Godot import drifts** — commit generated sidecars and pin runtime load/rate/mono/loop facts in existing project smoke.

## Acceptance

HPA-440 is complete when:

1. `river-ambience.wav` and `rain-ambience.wav` exist at the exact HPA-402 paths.
2. Both source files are exactly 5.0-second mono PCM-16 WAVs at 22050 Hz with peak below 0.30 full scale.
3. Both are project-generated from the documented deterministic recipe with no external samples or attribution burden.
4. Both Godot sidecars forward-loop the full clip and the imported resources pass the existing headless project smoke.
5. A 30-second repeated listen finds no obvious click, distracting pattern, musical content, thunder, wildlife, or dramatic transient.
6. River and Rain are distinguishable and deliberately quieter than farming feedback cues at equal preview gain.
7. `assets/audio/README.md` records complete provenance and HPA-402 handoff.
8. `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass with no unrelated changes.
9. No runtime player/settings/weather/world code, reusable generation framework, alternate audio format, or unrelated refactor is added.

## Delivery rule

One issue, one branch, one PR. This planning commit starts HPA-440's only PR. Final WAVs, generated `.import` sidecars, README provenance, the narrow existing-smoke update, listening evidence in the PR description, and verification all continue on this same branch and draft PR. HPA-402 starts only after this PR merges.
