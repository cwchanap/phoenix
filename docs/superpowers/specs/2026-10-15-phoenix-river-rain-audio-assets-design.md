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
- Phoenix keeps authored source artifacts when they materially improve reproducibility; HPA-440 originally followed that precedent with a committed source generator, now superseded by the post-review change — the committed WAVs are the artifacts of record.
- Existing Phoenix audio imports as `AudioStreamWAV`; looping music uses `.import` metadata with `edit/loop_mode=2`, `edit/loop_begin=0`, and `edit/loop_end=-1`.
- Existing WAV sidecars use `compress/mode=2`; Godot documents this WAV compression lane as QOA. HPA-440 starts with that project default and changes only if imported-stream review exposes a seam artifact.
- `tests/headless/project_smoke.gd` already owns narrow resource checks and runs inside `./tools/verify-clean.sh`.
- The repository commits source-adjacent `.import` sidecars; only `.godot/` generated import cache is ignored.
- `UiSettings` defaults Music to 4 and Sound to 7. `db_for_level()` therefore resolves Music to `-24 dB` and Sound to `-12 dB`; HPA-402's additional `-12 dB` ambience headroom puts ambience at the same effective default gain as music. HPA-440 must therefore review ambience under `farm-day-loop.wav`, not only against one-shot SFX.

Do not introduce an audio-generation framework for two files.

## Chosen approach: one deterministic source generator (superseded — see Post-review change)

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
- provenance: ElevenLabs MCP `eleven_text_to_sound_v2` takes with prompts/model/parameters/take ids and post-processing recipe recorded in `assets/audio/README.md`;
- no music, voice, wildlife, thunder, wind gusts, or discrete dramatic events;
- fixed level set by the recorded post-processing recipe; no normalization to full scale;
- final absolute sample peak below `0.30` full scale;
- measured RMS recorded in the handoff README as evidence, not as a second arbitrary numeric loudness gate.

The `< 0.30` peak ceiling is only a clipping/headroom guard. Perceived prominence is decided by the imported-stream mix review.

### River

`river-ambience.wav` is a low/mid broadband water bed:

- strongest energy roughly `90-900 Hz`;
- lighter texture extending to about `2200 Hz`;
- slow periodic amplitude movement below `2 Hz`;
- no isolated transient or splash event.

It should read as nearby moving water rather than white noise or a pitched pad.

### Rain

`rain-ambience.wav` is a brighter, denser texture:

- broad dominant energy roughly `700-7000 Hz`;
- restrained low-mid body so it does not become a thin hiss;
- slow periodic density/amplitude movement below `3 Hz`;
- no thunder, gusts, pitched drops, or discrete impact events.

It must be immediately distinguishable from River while remaining steady enough to support HPA-462's visual rain streaks.

## Provenance and regeneration contract

The two committed WAVs are the artifacts of record; no generator is committed. They were produced through the ElevenLabs MCP `eleven_text_to_sound_v2` flow, and `assets/audio/README.md` records the verbatim prompts, model, parameters, selected take ids, and post-processing recipe as provenance. MCP generation is not byte-reproducible — rerunning generation produces new takes, not these files — so no byte-identical regeneration gate applies, and no rerun may overwrite the committed paths. Any future regeneration is a fresh take accepted through the same imported-stream review, not a reproduction of these bytes.

## Godot import contract

Commit generated sidecars:

- `assets/audio/river-ambience.wav.import`
- `assets/audio/rain-ambience.wav.import`

Both use full-clip forward looping:

- `edit/loop_mode=2`;
- `edit/loop_begin=0`;
- `edit/loop_end=110250`.

`loop_end` is the exclusive wrap point: Godot replays `[loop_begin, loop_end)`, so covering the full clip requires the frame count `110250`, not `-1` (which resolves to `frames-1` and would drop the last sample every pass).

Start with the repository-default WAV compression setting (`compress/mode=2`). The 30-second-equivalent seam review must measure the **imported Godot resource**, not only the source WAV. If QOA import introduces an audible loop click that is absent from the source, set only these two ambience sidecars to `compress/mode=0`, reimport, and repeat the same imported-stream review. Two ~220 KB PCM imports are acceptable; do not add an alternate codec or wrapper.

Do not add source WAV loop chunks, a custom importer, `.tres` wrapper, `AudioStreamRandomizer`, or Ogg/MP3 copies.

Godot's runtime resource must load as `AudioStreamWAV`, report `mix_rate == 22050`, remain mono, use `AudioStreamWAV.LOOP_FORWARD`, and report exactly `5.0` seconds duration (110250 frames). The smoke test intentionally does not pin compression mode because either project-default QOA or the seam-driven PCM fallback is acceptable.

## Provenance and handoff

Extend the existing `assets/audio/README.md`; do not create another provenance document.

The HPA-440 section records:

- both runtime paths and sonic purposes;
- `5.0 s`, mono, PCM-16, `22050 Hz`;
- ElevenLabs prompt/model/parameter/take-id provenance and the post-processing recipe as the source record (no generator is committed; seeds `44001`/`44002` no longer apply);
- measured source peak **and RMS** for each file;
- accepted Godot compression mode for the two sidecars;
- no external samples or third-party attribution;
- full-clip Forward import contract;
- final imported-stream measurement verdict: ≥30-second seam/repetition result, within-period modulation result, placement under `farm-day-loop.wav` at equal gain, and prominence relative to `farm-hoe.wav` / `farm-harvest.wav`;
- HPA-402 as the runtime consumer.

Do not duplicate filter constants/tuning values into prose. The committed WAVs are the artifacts of record; the README is the compact handoff record.

## Mechanical verification

Reuse `tests/headless/project_smoke.gd`; do not add an audio-test framework.

The script already has `_fail(message)` + `quit(1)`. Use that failure path consistently instead of bare `assert()` so a negative smoke run exits cleanly in headless CI.

As part of the same narrow edit:

- convert the six existing asset-existence assertions to `if not ResourceLoader.exists(path): _fail(...); return`;
- validate each ambience path with explicit `_fail(...); return` checks for existence, `AudioStreamWAV`, 22050 Hz, mono, `LOOP_FORWARD`, `loop_begin == 0`, `loop_end == frame count`, and exactly 5.0-second duration.

Use Python stdlib `wave` as the source-container check, committed as `tools/check_audio_sources.py` and run by `tools/verify-clean.sh` so the contract stays enforced:

- 1 channel;
- 2-byte sample width;
- 22050 Hz;
- 110250 frames;
- peak below 0.30 full scale;
- print peak and RMS for the handoff record.

Do not teach production code about asset-generation constraints.

## Acceptance review

All final acceptance is against the **imported Godot resources**. The human listening gate was removed at owner direction (2026-10-16): acceptance is a measurement-based imported-stream review recorded in `assets/audio/README.md`.

The review covers:

1. each loop concatenated for at least 30 seconds — reject seam-localized clicks or level jumps at any wrap, tonal spikes, or dramatic transients, and reject a dominant once-per-loop swell: the within-period 0.2 Hz envelope component must stay below 10% of the mean 100 ms RMS envelope and below the strongest ≤2 Hz component;
2. River, then Rain, against `farm-day-loop.wav` at equal gain — the deciding check is imported-stream RMS under **both** unweighted and A-weighted measurement, with the explicit threshold "strictly below the music bed" (< 0 dB relative) under both. The unweighted-only check demonstrably inverts: the music bed concentrates its energy near 123 Hz where A-weighting discounts ~25 dB, so a bed can pass unweighted while measuring louder perceptually. A-weighted RMS is the metric that tracks perceived loudness, so both must hold;
3. comparison against `farm-hoe.wav` and `farm-harvest.wav` at equal gain — the ambience measures less prominent than farming feedback, likewise under both unweighted and A-weighted RMS;
4. River and Rain must remain clearly distinguishable by spectrum.

If sonic balance is wrong, rework the committed take's post-processing (spectral refit, periodic-line repair, level) or generate a new take and re-measure. If only the imported seam clicks, try the `compress/mode=0` fallback before changing the source.

Record the durable measurement verdict in `assets/audio/README.md`; the PR description may repeat it but is not its only home. No preview scene is committed.

## Downstream ownership

HPA-440 owns the asset-level import contract, including `LOOP_FORWARD`. HPA-402 consumes the accepted paths and owns player count, path wiring, headroom, settings updates, rain start/stop behavior, and lifecycle. Its plan should not separately re-prove the forward-loop import property.

## Risks

1. **Synthetic texture sounds tonal** — the imported-stream measurement review rejects tonal results; the fix is a new ElevenLabs take with a darker prompt or different post-processing, not code.
2. **No source click but imported seam artifact** — measure the Godot-imported resource; fall back to uncompressed PCM only for these two files if needed.
3. **Ambience competes with music** — record RMS, then judge the actual default gain relationship under `farm-day-loop.wav`.
4. **Rain becomes harsh hiss** — keep low-mid body and tune filtering rather than solving brightness with amplitude.
5. **Asset drift** — the committed WAVs are the artifacts of record; MCP regeneration produces new takes and must never overwrite the committed paths.
6. **Smoke failure hangs CI** — use existing `_fail()`/`quit(1)` rather than bare assertions for all resource checks in this script.

## Acceptance

HPA-440 is complete when:

1. Both exact WAV paths exist.
2. Both are exactly 5.0-second mono PCM-16 WAVs at 22050 Hz with peak below 0.30 full scale; peak and RMS are recorded.
3. Both WAVs are committed artifacts of record under the repo's ElevenLabs MCP audio convention: `assets/audio/README.md` records verbatim prompts, model, parameters, take ids, and the post-processing recipe; no generator is committed and no byte-identical regeneration gate applies.
4. Both Godot sidecars forward-loop the full clip and imported resources pass the existing project smoke using clean `_fail()` exits.
5. An imported-stream measurement review over at least 30 seconds of looped content finds no seam-localized click, tonal spike, musical content, thunder, wildlife, or dramatic transient, and within-period envelope analysis finds no dominant once-per-loop pulse/swell (0.2 Hz component below 10% of the mean envelope and below the strongest ≤2 Hz component); `compress/mode=0` is used only if needed to eliminate an import-induced seam.
6. River and Rain remain subordinate under `farm-day-loop.wav` at equal player gain — imported-stream RMS strictly below the music bed (< 0 dB relative) under both unweighted and A-weighted measurement — remain less attention-grabbing than farming one-shots under both metrics, and remain clearly distinguishable.
7. `assets/audio/README.md` records compact provenance, peak/RMS, accepted compression mode, measurement verdict, and HPA-402 handoff.
8. `./tools/verify-clean.sh` and `git diff --check main...HEAD` pass with no unrelated changes.
9. No runtime player/settings/weather/world code, generic generation framework, alternate audio format, or unrelated refactor is added.

## Delivery rule

One issue, one branch, one PR. Generate, import, mechanically verify, measure, and accept the assets before committing their implementation files. Final WAVs, `.import` sidecars, README handoff, narrow `project_smoke.gd` update, and verification all remain on this same draft PR; no generator ships. HPA-402 starts only after this PR merges.

## Post-review change (2026-10-16): ElevenLabs provenance

After the deterministic-generator implementation was accepted and verified on
this branch, the repository owner directed that Phoenix audio generation use
the ElevenLabs MCP (now recorded as the repo audio convention in CLAUDE.md).
Both ambience WAVs were regenerated with `eleven_text_to_sound_v2`
(`duration_seconds=5.0`, `loop=true`, `prompt_influence=0.7`), post-processed
(mono 22050 Hz PCM-16 conversion, river lowpass tilt at 1400 Hz, rain peak
taming, 100 ms equal-power circular crossfade so the loop wrap joins adjacent
source samples) and re-verified through the same imported-stream gates: seam,
periodicity, non-tonality, mix-level, and peak/RMS all pass as recorded in
`assets/audio/README.md`. Consequences for this spec's contract: the
"Chosen approach" deterministic generator and its byte-identical
regeneration gate are superseded — the committed WAVs are the artifacts of
record, provenance is the recorded prompt/model/post-processing recipe, and
seeds 44001/44002 no longer apply. The container contract, 0.30 peak guard,
Forward-loop import contract, smoke coverage, and HPA-402 boundary are
unchanged. The human listening gate in the original Acceptance is removed at
owner direction: acceptance is the imported-stream measurement review recorded
in `assets/audio/README.md`.

## Second post-review change (2026-10-17): measurement-rework pass

Review of the merged candidate found the committed takes failed the locked
contract in ways the unweighted-RMS check could not see: river's dominant band
was 900–2200 Hz rather than 90–900 Hz, rain put 36% of its energy above the
locked 7 kHz band top, river dipped ~3.5 dB in the ~200 ms straddling the loop
wrap, both takes carried discrete periodic-comb lines at 200 Hz multiples, and
the beds measured 10–12 dB **above** the music under A-weighted loudness while
passing only on unweighted RMS. The committed buffers were reworked (no
regeneration): periodic-comb repair, wrap-preserving spectral refit into the
locked bands, a circular gain repair of the wrap trough, and re-leveling to
−44.7 dBFS(A) — 4 dB below the imported music bed — so subordination holds
under both unweighted and A-weighted RMS; the acceptance gate above was
amended to require both metrics. `edit/loop_end` was corrected from `-1` to
`110250` because the value is the exclusive wrap point (`-1` resolved to
`frames-1`, dropping one sample per pass). The source-container check is now
committed as `tools/check_audio_sources.py` and run by `tools/verify-clean.sh`,
and the smoke pins `loop_end ==` frame count with exactly 5.0 s duration.
