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

They are project-owned, source-level mono 16-bit PCM at 22050 Hz, exactly 5 seconds long, quiet enough to sit below farming feedback, and configured by Godot to forward-loop over the full clip without an obvious seam.

This ticket stops at the asset boundary. HPA-402 owns runtime players, Sound-setting integration, weather-driven playback, and lifecycle behavior.

## Why this is the next actionable slice

HPA-440 is the only unblocked Phoenix Todo. HPA-402 explicitly depends on these exact two paths and forbids placeholders or substitute WAVs on its branch. HPA-462 / PR #19 already shipped the visual river/rain presenter and left audio integration to the HPA-440 -> HPA-402 handoff.

## Existing conventions to reuse

- `assets/audio/README.md` already records project-generated audio provenance.
- Phoenix keeps authored source artifacts when they materially improve reproducibility; HPA-440 follows that precedent with one small source generator rather than transcribing a complex texture recipe into prose.
- Existing Phoenix audio imports as `AudioStreamWAV`; looping music uses `.import` metadata with `edit/loop_mode=2`, `edit/loop_begin=0`, and `edit/loop_end=-1`.
- `tests/headless/project_smoke.gd` already performs narrow resource checks and runs inside `./tools/verify-clean.sh`.
- The repository commits source-adjacent `.import` sidecars; only `.godot/` generated import cache is ignored.
- HPA-402 will apply a fixed `-12 dB` ambience headroom at runtime, so HPA-440 must not compensate by making the sources aggressively loud.

Do not introduce an audio-generation framework for two files.

## Chosen approach: one deterministic source generator

Commit one single-purpose Python-stdlib script:

`tools/generate_hpa_440_ambience.py`

It owns only these two HPA-440 assets. It uses `wave`, `math`, `random`, and `struct`, fixed seeds, and periodic harmonic components whose frequencies complete an integer number of cycles in the five-second clip. The loop boundary is therefore phase-continuous by construction.

The generator is provenance, not infrastructure:

- no generic asset registry;
- no plugin system or configuration file;
- no external packages;
- no reusable audio API;
- no runtime dependency on Python;
- no candidate archive.

Keeping the script is cheaper and more truthful than promising exact reconstruction from prose constants. The fixed seeds become load-bearing, and later tuning changes the source-of-truth code beside the generated assets instead of reverse-engineering a README paragraph.

External generative-audio services and recorded field ambience remain rejected: both add more provenance/editing work than this restrained two-file slice needs.

## Locked source contract

Both source WAVs use:

- duration: exactly `5.0 s`;
- sample rate: `22050 Hz`;
- channels: mono;
- sample width: 16-bit signed PCM;
- sample count: `110250` frames;
- no music, voice, wildlife, thunder, wind gusts, or discrete dramatic events;
- conservative fixed synthesis gain; no normalization to full scale;
- final absolute sample peak below `0.30` full scale.

The `< 0.30` peak ceiling is a safety guard, not a loudness target. Manual review still decides whether either loop competes with farming cues.

### River

Use seed `44001`.

Build a low/mid broadband water bed from deterministic periodic harmonic layers:

- strongest energy roughly `90-900 Hz`;
- lighter texture extending to about `2200 Hz`;
- slow periodic amplitude movement below `2 Hz`;
- no isolated transient or splash event.

It should read as nearby moving water rather than white noise or a pitched pad.

### Rain

Use seed `44002`.

Build a brighter, denser periodic texture:

- broad dominant energy roughly `700-7000 Hz`;
- restrained low-mid body so it does not become a thin hiss;
- slow periodic density/amplitude movement below `3 Hz`;
- no thunder, gusts, pitched drops, or discrete impact events.

It must be immediately distinguishable from River while remaining steady enough to support HPA-462's visual rain streaks.

## Seam and reproducibility strategy

Do not generate arbitrary noise and repair it with an editor crossfade.

Every oscillator/component used by the final generator completes an integer number of cycles inside the exact five-second period. Randomness selects deterministic amplitudes/phases from the fixed seed, not non-periodic sample positions.

After an accepted candidate is committed, rerunning `tools/generate_hpa_440_ambience.py` from the same revision must reproduce the committed WAV bytes exactly. A clean `git diff --exit-code -- assets/audio/river-ambience.wav assets/audio/rain-ambience.wav` after regeneration is the reproducibility check.

A repeated-loop listen is still required because mathematical continuity can avoid clicks while leaving a perceptually obvious five-second pattern.

## Godot import contract

Commit generated sidecars:

- `assets/audio/river-ambience.wav.import`
- `assets/audio/rain-ambience.wav.import`

Both use full-clip forward looping:

- `edit/loop_mode=2`;
- `edit/loop_begin=0`;
- `edit/loop_end=-1`.

Do not add source WAV loop chunks, a custom importer, `.tres` wrapper, `AudioStreamRandomizer`, or alternate Ogg/MP3 copies.

Godot's runtime resource must load as `AudioStreamWAV`, report `mix_rate == 22050`, remain mono, use `AudioStreamWAV.LOOP_FORWARD`, and have a duration within 4-6 seconds. Source PCM-16 format is verified from the WAV container separately because Godot may compress imported data internally.

## Provenance and handoff

Extend the existing `assets/audio/README.md`; do not create another provenance document.

The HPA-440 section records:

- both runtime paths and sonic purposes;
- `5.0 s`, mono, PCM-16, `22050 Hz`;
- seeds `44001` / `44002`;
- `tools/generate_hpa_440_ambience.py` as the exact source recipe;
- measured source peaks;
- no external samples or third-party attribution;
- full-clip Forward import contract;
- the final listening verdict, including that both ambience loops are less attention-grabbing than `farm-hoe.wav` / `farm-harvest.wav` at equal preview gain;
- HPA-402 as the runtime consumer.

Do not duplicate the generator's component tables and tuning constants into prose. The script is the reproducible source; the README is the compact handoff record.

## Mechanical verification

Reuse `tests/headless/project_smoke.gd`; do not add an audio-test framework.

For each ambience path assert:

1. `ResourceLoader.exists(path)`;
2. loaded resource is `AudioStreamWAV`;
3. `mix_rate == 22050`;
4. `stereo == false`;
5. `loop_mode == AudioStreamWAV.LOOP_FORWARD`;
6. `get_length()` is between `4.0` and `6.0` seconds.

Use Python stdlib `wave` as a one-shot source-container check:

- 1 channel;
- 2-byte sample width;
- 22050 Hz;
- 110250 frames;
- peak below 0.30 full scale.

Do not teach production code about asset-generation constraints.

## Audible acceptance

Before closeout, loop each asset continuously for at least 30 seconds and compare at equal preview gain against `farm-hoe.wav` and `farm-harvest.wav`.

Accept only when:

- neither loop clicks or jumps at the seam;
- neither exposes a distracting five-second swell/pulse;
- River stays non-musical and water-like;
- Rain stays steady without thunder-like transients or harsh attention-grabbing hiss;
- River and Rain are distinguishable within a few seconds;
- both are less attention-grabbing than the farming one-shots at equal gain.

Record the durable qualitative verdict in `assets/audio/README.md`; the PR description may repeat the evidence but is not its only home. No preview scene is committed.

## Risks

1. **Synthetic texture sounds tonal** — many randomly phased integer-cycle components plus listening rejection.
2. **No click but obvious five-second repetition** — 30-second loop review rejects repeating swells or distinctive events.
3. **Rain becomes harsh hiss** — keep low-mid body and cap source peak rather than brightening through amplitude.
4. **River competes with farming feedback** — conservative source level plus HPA-402's later `-12 dB` headroom.
5. **Generator drifts from committed assets** — deterministic rerun must leave both WAVs byte-identical.
6. **Godot import drifts** — commit sidecars and pin runtime rate/mono/loop facts in existing project smoke.

## Acceptance

HPA-440 is complete when:

1. Both exact WAV paths exist.
2. Both are exactly 5.0-second mono PCM-16 WAVs at 22050 Hz with peak below 0.30 full scale.
3. `tools/generate_hpa_440_ambience.py` deterministically reproduces both committed WAVs with no external samples.
4. Both Godot sidecars forward-loop the full clip and imported resources pass the existing project smoke.
5. A 30-second repeated listen finds no obvious click, distracting pattern, musical content, thunder, wildlife, or dramatic transient.
6. River and Rain are distinguishable and deliberately less attention-grabbing than farming feedback cues at equal preview gain.
7. `assets/audio/README.md` records compact provenance, listening verdict, and HPA-402 handoff.
8. `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass with no unrelated changes.
9. No runtime player/settings/weather/world code, generic generation framework, alternate audio format, or unrelated refactor is added.

## Delivery rule

One issue, one branch, one PR. Final generator, WAVs, `.import` sidecars, README handoff, narrow existing-smoke update, listening evidence, and verification all continue on this same draft PR. HPA-402 starts only after this PR merges.
