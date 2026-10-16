# Phoenix River and Rain Ambience Audio Assets Design

**Linear:** HPA-440\
**Repository:** `cwchanap/phoenix`\
**Branch:** `agent/hpa-440-river-rain-audio-plan`\
**Base reviewed:** `main` at `e3bead7d2d752559d4f2410e7b3c4cec0ae6712b`\
**Delivery:** one HPA-440 asset-only PR; HPA-402 remains blocked until this PR merges.

## Goal

Produce exactly two small, neutral ambience loops for the Phoenix homestead:

- `assets/audio/river-ambience.wav`
- `assets/audio/rain-ambience.wav`

They are project-owned, source-level mono 16-bit PCM at 22050 Hz, exactly 5 seconds long, quiet enough to sit under the existing farm music and farming feedback, and configured by Godot to forward-loop over the full imported clip without an obvious seam.

This ticket stops at the asset boundary. HPA-402 owns runtime players, Sound-setting integration, weather-driven playback, and lifecycle behavior.

## Why this is the next actionable slice

HPA-440 is the only unblocked Phoenix Todo. HPA-402 explicitly depends on these exact two paths and forbids placeholders or substitute WAVs on its branch. HPA-462 / PR #19 already shipped the visual river/rain presenter and left audio integration to the HPA-440 -> HPA-402 handoff.

## Existing conventions to reuse

- `assets/audio/README.md` already records project-generated audio provenance.
- Phoenix keeps authored source artifacts when they materially improve reproducibility; HPA-440 follows that precedent with one small source generator rather than transcribing a complex texture recipe into prose.
- Existing Phoenix audio imports as `AudioStreamWAV`; looping music uses `.import` metadata with `edit/loop_mode=2`, `edit/loop_begin=0`, and `edit/loop_end=-1`.
- Existing WAV sidecars use `compress/mode=2`; Godot documents this WAV compression lane as QOA. HPA-440 starts with that project default and changes only if imported-loop listening exposes a seam artifact.
- `tests/headless/project_smoke.gd` already owns narrow resource checks and runs inside `./tools/verify-clean.sh`.
- The repository commits source-adjacent `.import` sidecars; only `.godot/` generated import cache is ignored.
- `UiSettings` defaults Music to 4 and Sound to 7. `db_for_level()` therefore resolves Music to `-24 dB` and Sound to `-12 dB`; HPA-402's additional `-12 dB` ambience headroom puts ambience at the same effective default gain as music. HPA-440 must therefore review ambience under `farm-day-loop.wav`, not only against one-shot SFX.

Do not introduce an audio-generation framework for two files.

## Chosen approach: one deterministic source generator

Commit one single-purpose Python-stdlib script:

`tools/generate_hpa_440_ambience.py`

The generator owns only these two HPA-440 assets. It uses seeded periodic noise buffers plus simple stable filters and periodic LFOs; it does not synthesize thousands of individual 0.2 Hz-spaced oscillators.

### Periodic-buffer construction

For each asset:

1. use the fixed seed to create exactly one 5-second white-noise buffer;
2. treat that finite buffer as the repeating source period;
3. shape it with a small number of stdlib-implemented one-pole / simple band-shaping filters;
4. warm each stable filter by processing complete buffer periods before retaining the final pass, so filter state converges to the repeating-buffer state instead of starting from zero at sample 0;
5. apply only LFOs whose cycle counts are integers over the 5-second period (`0.2 Hz` multiples);
6. write the final mono PCM-16 buffer directly, with no editor crossfade or post-normalization.

The implementation may use two or more whole-buffer warm-up passes; the final committed generator owns the exact count. The design promise is practical loop continuity of one synthesized periodic buffer, verified on the imported Godot stream. It does **not** claim platform-independent floating-point byte identity or a formal exact-IIR periodic solution.

This shape is O(samples x a few filters), keeps tuning fast, and avoids the tonal/performance tradeoff of sparse additive harmonics.

The generator is provenance, not infrastructure:

- no generic asset registry;
- no plugin/config framework;
- no external packages;
- no reusable runtime audio API;
- no runtime dependency on Python;
- no candidate archive.

Keeping the script is cheaper and more truthful than promising reconstruction from prose constants. External generative-audio services and recorded field ambience remain rejected because both add more provenance/editing work than this restrained two-file slice needs.

## Locked source contract

Both source WAVs use:

- duration: exactly `5.0 s`;
- sample rate: `22050 Hz`;
- channels: mono;
- sample width: 16-bit signed PCM;
- sample count: `110250` frames;
- fixed seeds: River `44001`, Rain `44002`;
- no music, voice, wildlife, thunder, wind gusts, or discrete dramatic events;
- conservative fixed synthesis gain; no normalization to full scale;
- final absolute sample peak below `0.30` full scale;
- measured RMS recorded in the handoff README as evidence, not as a second arbitrary numeric loudness gate.

The `< 0.30` peak ceiling is only a clipping/headroom guard. Perceived prominence is decided by the imported-stream mix review.

### River

Shape seed `44001` into a low/mid broadband water bed:

- strongest energy roughly `90-900 Hz`;
- lighter texture extending to about `2200 Hz`;
- slow periodic amplitude movement below `2 Hz`;
- no isolated transient or splash event.

It should read as nearby moving water rather than white noise or a pitched pad.

### Rain

Shape seed `44002` into a brighter, denser texture:

- broad dominant energy roughly `700-7000 Hz`;
- restrained low-mid body so it does not become a thin hiss;
- slow periodic density/amplitude movement below `3 Hz`;
- no thunder, gusts, pitched drops, or discrete impact events.

It must be immediately distinguishable from River while remaining steady enough to support HPA-462's visual rain streaks.

## Reproducibility contract

The committed generator is the recipe source of truth. Within the same implementation environment, rerunning it from the same source revision must leave the two committed WAVs unchanged:

```bash
python3 tools/generate_hpa_440_ambience.py
git diff --exit-code -- assets/audio/river-ambience.wav assets/audio/rain-ambience.wav
```

This catches accidental unseeded randomness or hidden local editing. Do not promise cross-platform byte identity: Python/libm floating-point details are not a product contract.

## Godot import contract

Commit generated sidecars:

- `assets/audio/river-ambience.wav.import`
- `assets/audio/rain-ambience.wav.import`

Both use full-clip forward looping:

- `edit/loop_mode=2`;
- `edit/loop_begin=0`;
- `edit/loop_end=-1`.

Start with the repository-default WAV compression setting (`compress/mode=2`). The 30-second seam review must listen to the **imported Godot resource**, not only the source WAV. If QOA import introduces an audible loop click that is absent from the source, set only these two ambience sidecars to `compress/mode=0`, reimport, and repeat the same imported-stream review. Two ~220 KB PCM imports are acceptable; do not add an alternate codec or wrapper.

Do not add source WAV loop chunks, a custom importer, `.tres` wrapper, `AudioStreamRandomizer`, or Ogg/MP3 copies.

Godot's runtime resource must load as `AudioStreamWAV`, report `mix_rate == 22050`, remain mono, use `AudioStreamWAV.LOOP_FORWARD`, and have a duration within 4-6 seconds. The smoke test intentionally does not pin compression mode because either project-default QOA or the seam-driven PCM fallback is acceptable.

## Provenance and handoff

Extend the existing `assets/audio/README.md`; do not create another provenance document.

The HPA-440 section records:

- both runtime paths and sonic purposes;
- `5.0 s`, mono, PCM-16, `22050 Hz`;
- seeds `44001` / `44002`;
- `tools/generate_hpa_440_ambience.py` as the exact source recipe;
- measured source peak **and RMS** for each file;
- accepted Godot compression mode for the two sidecars;
- no external samples or third-party attribution;
- full-clip Forward import contract;
- final imported-stream listening verdict: 30-second seam/repetition result, placement under `farm-day-loop.wav` at equal gain, and prominence relative to `farm-hoe.wav` / `farm-harvest.wav`;
- HPA-402 as the runtime consumer.

Do not duplicate filter constants/tuning values into prose. The script is the reproducible source; the README is the compact handoff record.

## Mechanical verification

Reuse `tests/headless/project_smoke.gd`; do not add an audio-test framework.

The script already has `_fail(message)` + `quit(1)`. Use that failure path consistently instead of bare `assert()` so a negative smoke run exits cleanly in headless CI.

As part of the same narrow edit:

- convert the six existing asset-existence assertions to `if not ResourceLoader.exists(path): _fail(...); return`;
- validate each ambience path with explicit `_fail(...); return` checks for existence, `AudioStreamWAV`, 22050 Hz, mono, `LOOP_FORWARD`, and 4-6 second duration.

Use Python stdlib `wave` as a one-shot source-container check:

- 1 channel;
- 2-byte sample width;
- 22050 Hz;
- 110250 frames;
- peak below 0.30 full scale;
- print peak and RMS for the handoff record.

Do not teach production code about asset-generation constraints.

## Audible acceptance

All final listening is against the **imported Godot resources**.

Use one acceptance pass that covers:

1. each loop alone for at least 30 seconds — reject clicks, level jumps, obvious five-second pulses/swells, tonal River, harsh/pulsing Rain, or dramatic events;
2. River, then Rain, under `farm-day-loop.wav` at equal player gain — ambience must remain subordinate rather than competing with the music at the effective default mix relationship;
3. comparison against `farm-hoe.wav` and `farm-harvest.wav` at equal player gain — the ambience must remain less attention-grabbing than farming feedback;
4. River and Rain must remain obviously distinguishable within a few seconds.

If sonic balance is wrong, tune the committed generator and regenerate. If only the imported seam clicks, try the `compress/mode=0` fallback before changing source synthesis.

Record the durable qualitative verdict in `assets/audio/README.md`; the PR description may repeat it but is not its only home. No preview scene is committed.

## Downstream ownership

HPA-440 owns the asset-level import contract, including `LOOP_FORWARD`. HPA-402 consumes the accepted paths and owns player count, path wiring, headroom, settings updates, rain start/stop behavior, and lifecycle. Its plan should not separately re-prove the forward-loop import property.

## Risks

1. **Synthetic texture sounds tonal or tuning becomes slow** — filtered seeded noise keeps broadband generation linear in sample count; listening still rejects tonal results.
2. **No source click but imported seam artifact** — listen to the Godot-imported resource; fall back to uncompressed PCM only for these two files if needed.
3. **Ambience competes with music** — record RMS, then judge the actual default gain relationship under `farm-day-loop.wav`.
4. **Rain becomes harsh hiss** — keep low-mid body and tune filtering rather than solving brightness with amplitude.
5. **Generator drifts from committed assets** — same-environment deterministic rerun must leave both WAVs unchanged.
6. **Smoke failure hangs CI** — use existing `_fail()`/`quit(1)` rather than bare assertions for all resource checks in this script.

## Acceptance

HPA-440 is complete when:

1. Both exact WAV paths exist.
2. Both are exactly 5.0-second mono PCM-16 WAVs at 22050 Hz with peak below 0.30 full scale; peak and RMS are recorded.
3. `tools/generate_hpa_440_ambience.py` deterministically reproduces both committed WAVs in the same implementation environment with no external samples.
4. Both Godot sidecars forward-loop the full clip and imported resources pass the existing project smoke using clean `_fail()` exits.
5. A 30-second imported-loop listen finds no obvious seam, distracting pattern, musical content, thunder, wildlife, or dramatic transient; `compress/mode=0` is used only if needed to eliminate an import-induced seam.
6. River and Rain remain subordinate under `farm-day-loop.wav` at equal player gain, remain less attention-grabbing than farming one-shots, and remain clearly distinguishable.
7. `assets/audio/README.md` records compact provenance, peak/RMS, accepted compression mode, listening verdict, and HPA-402 handoff.
8. `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass with no unrelated changes.
9. No runtime player/settings/weather/world code, generic generation framework, alternate audio format, or unrelated refactor is added.

## Delivery rule

One issue, one branch, one PR. Generate, import, mechanically verify, listen, and accept the assets before committing their implementation files. Final generator, WAVs, `.import` sidecars, README handoff, narrow `project_smoke.gd` update, and verification all remain on this same draft PR. HPA-402 starts only after this PR merges.
