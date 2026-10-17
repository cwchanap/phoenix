# Phoenix River and Rain Ambience Audio Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the two HPA-440 river/rain ambience WAVs as committed artifacts of record under the repo's ElevenLabs MCP audio convention, and prove the imported Godot loops are seam-clean and correctly subordinate to existing Phoenix audio without adding runtime playback code.

**Architecture:** Keep HPA-440 entirely at the asset boundary. Generate both 5-second mono PCM-16 22050 Hz beds through the ElevenLabs MCP `eleven_text_to_sound_v2` flow, post-process them into the locked container with a 100 ms equal-power circular crossfade, import them through Godot, reuse `tests/headless/project_smoke.gd` with explicit `_fail()` exits, record prompt/model/post-processing provenance and imported-stream measurement acceptance in `assets/audio/README.md`, then commit the accepted asset slice once. HPA-402 remains the runtime consumer.

**Tech Stack:** ElevenLabs MCP `eleven_text_to_sound_v2`, disposable uncommitted post-processing tooling, Godot 4.7.1 import pipeline, GDScript headless smoke, existing Phoenix verification scripts.

**Spec:** `docs/superpowers/specs/2026-10-15-phoenix-river-rain-audio-assets-design.md`

## Post-execution change (2026-10-16): ElevenLabs provenance

After the deterministic-generator implementation was accepted on this branch,
the repository owner directed that Phoenix audio generation use the ElevenLabs
MCP (recorded as the repo audio convention in CLAUDE.md), matching the design
spec's post-review change. This plan's seeded-generator instructions are
superseded: `tools/generate_hpa_440_ambience.py` is deleted, seeds
`44001`/`44002` no longer apply, and MCP-generated audio is not subject to the
same-environment byte-identical rerun gate — rerunning generation produces new
takes, not these files. Do not run or recreate a generator; the committed WAVs
are the artifacts of record and provenance is the prompt/model/post-processing
recipe in `assets/audio/README.md`.

What was actually executed: four `eleven_text_to_sound_v2` takes per asset
(`duration_seconds=5.0`, `loop=true`, `prompt_influence=0.7`), take selection
plus post-processing into the locked container (mono 22050 Hz PCM-16, 110250
frames, peak < 0.30) with the README's 100 ms equal-power circular crossfade,
then the Step 4-7 smoke work — extended so the ambience checks also pin
`loop_begin == 0` and `loop_end` covering the full clip — the imported-stream
measurement acceptance recorded in `assets/audio/README.md`, and the Step
10-13 diff/commit/verify discipline minus the regeneration gate. The container
contract, Forward-loop import contract, `_fail()` smoke discipline, and
HPA-402 boundary are unchanged. The recorded acceptance is measurement-based;
the human listening gate was removed at owner direction (2026-10-16).

## Global Constraints

- Deliver exactly `assets/audio/river-ambience.wav` and `assets/audio/rain-ambience.wav` as new runtime audio files.
- Commit no generator; the two WAVs are the artifacts of record under the repo's ElevenLabs MCP audio convention.
- Provenance is the recorded prompt/model/post-processing recipe in `assets/audio/README.md`, not a committed synthesis script.
- Each source WAV is exactly 5.0 seconds / 110250 frames, mono, signed PCM-16, 22050 Hz.
- No external samples or recordings; the ElevenLabs prompts and take ids are recorded in the README.
- Make each loop seamless by construction with a 100 ms equal-power circular crossfade so the loop wrap joins adjacent source samples.
- Final source peak stays below 0.30 full scale; print and record RMS but do not invent a second arbitrary numeric loudness limit.
- Godot import uses full-clip Forward looping: `edit/loop_mode=2`, `edit/loop_begin=0`, `edit/loop_end=-1`.
- Start with repository-default `compress/mode=2`; use `compress/mode=0` only if imported-stream review exposes a compression-induced seam.
- Extend `assets/audio/README.md`; do not create another provenance/evidence document.
- Reuse `tests/headless/project_smoke.gd`; add no audio-test framework.
- Resource-check failures use its existing `_fail()` + `quit(1)` path, not bare `assert()`.
- All acceptance review uses the imported Godot resources.
- Do not promise byte identity at all; MCP generation is not byte-reproducible, so no regeneration gate applies.
- Commit no candidate archive, preview scene, runtime player/settings/weather code, alternate codec, or unrelated refactor.
- One ticket / one branch / one PR; implementation continues on `agent/hpa-440-river-rain-audio-plan`.

## Review Focus

- **Imported seam:** the source may loop cleanly while QOA import introduces a click; imported playback must own the final seam gate and may fall back to PCM.
- **Music masking/competition:** default Music 4 is `-24 dB`; Sound 7 plus HPA-402's `-12 dB` headroom also yields `-24 dB`, so ambience must be reviewed under `farm-day-loop.wav` at equal player gain.
- **Smoke failure behavior:** every negative resource check must exit through `_fail()` instead of hanging on a bare assertion.
- **Asset drift:** MCP regeneration produces new takes; the committed WAVs are the artifacts of record and must never be overwritten by a rerun.
- **Container/loudness drift:** files must remain mono PCM-16 / 22050 Hz / 110250 frames with peak `< 0.30`, and peak/RMS must be recorded.

---

### Task 1: Generate, import, accept, and commit the HPA-440 ambience assets

**Files:**
- Create: `assets/audio/river-ambience.wav`
- Create: `assets/audio/rain-ambience.wav`
- Create: `assets/audio/river-ambience.wav.import`
- Create: `assets/audio/rain-ambience.wav.import`
- Modify: `assets/audio/README.md`
- Modify: `tests/headless/project_smoke.gd`

**Interfaces:**
- Consumes: the source/import/acceptance contract in the design spec.
- Produces: two accepted HPA-402-ready `AudioStreamWAV` paths and durable provenance/measurement handoff evidence.

- [ ] **Step 1: Implement the single-purpose seeded-noise generator** (superseded — see Post-execution change; ElevenLabs MCP generation replaced this step and no generator is committed)

Create `tools/generate_hpa_440_ambience.py` with only Python stdlib.

Lock these public facts:

```text
sample_rate = 22050
duration = 5.0
frames = 110250
river_seed = 44001
rain_seed = 44002
```

Keep the implementation direct:

- create one deterministic 110250-sample white-noise buffer per seed;
- shape River with a few low/mid-oriented stable filters and Rain with a brighter/broader filter chain;
- process whole source-buffer periods repeatedly before retaining the final filtered pass so filter state converges to the repeating input rather than starting from zero at sample 0;
- apply only LFO frequencies that are `0.2 Hz` multiples so their phase repeats over five seconds;
- write exactly the two runtime WAV paths as mono PCM-16;
- no CLI/config/plugin abstraction and no thousands-of-oscillators additive bank.

The exact filter coefficients, warm-up pass count, LFO depths, and output gains live only in this committed script.

- [ ] **Step 2: Generate both source WAVs** (superseded — see Post-execution change; the committed WAVs are the artifacts of record)

Run:

```bash
python3 tools/generate_hpa_440_ambience.py
```

Expected: exactly `river-ambience.wav` and `rain-ambience.wav` are created/updated.

- [ ] **Step 3: Run the source-container / peak / RMS check**

Use one inline Python stdlib `wave` check for both files. Assert:

```python
channels == 1
sample_width == 2
sample_rate == 22050
frame_count == 110250
peak < 0.30
```

Also calculate and print:

```text
duration
peak
RMS
```

Expected: both durations are exactly `5.000s`; peak is below `0.30`. Keep the observed peak/RMS values for the README.

- [ ] **Step 4: Replace hanging resource assertions and add ambience smoke checks**

Modify `tests/headless/project_smoke.gd` in one narrow edit.

For the six existing asset paths, replace bare:

```gdscript
assert(ResourceLoader.exists(path))
```

with the existing explicit failure path:

```gdscript
if not ResourceLoader.exists(path):
    _fail("missing required resource: %s" % path)
    return
```

Then add one ambience-path loop over:

```gdscript
[
    "res://assets/audio/river-ambience.wav",
    "res://assets/audio/rain-ambience.wav",
]
```

For each path, use `if not ...: _fail(...); return` style checks for:

```text
ResourceLoader.exists(path)
loaded stream is AudioStreamWAV
stream.mix_rate == 22050
stream.stereo == false
stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
stream.loop_begin == 0
stream.loop_end == roundi(stream.get_length() * stream.mix_rate) - 1
4.0 <= stream.get_length() <= 6.0
```

Do not assert compression mode.

- [ ] **Step 5: Import once with default metadata and prove the smoke gate is red**

Run:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/headless/project_smoke.gd
```

Expected: the process exits non-zero promptly through `_fail()` on the new loop-mode requirement because the new sidecars are not yet pinned to Forward. A hang is a defect in Step 4.

- [ ] **Step 6: Pin full-clip Forward looping**

Edit only the generated ambience sidecars to set:

```ini
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
```

Leave `compress/mode=2` initially. Reimport once so Godot rebuilds the runtime samples from the pinned metadata.

Do not add `.tres` wrappers, source WAV loop chunks, Ogg/MP3 copies, or a custom importer.

- [ ] **Step 7: Prove the smoke gate is green**

Run:

```bash
godot --headless --path . --script res://tests/headless/project_smoke.gd
```

Expected: PASS; both resources load as mono 22050 Hz `AudioStreamWAV`, use `LOOP_FORWARD`, and report 4-6 second duration.

Rerun the Step 3 source-container check afterward to prove import work did not rewrite the source WAVs.

- [ ] **Step 8: Perform one imported-stream listening acceptance pass** (superseded — see Post-execution change; executed as imported-stream measurement acceptance recorded in `assets/audio/README.md`, and the human listening gate was removed at owner direction)

Use Godot's imported-resource preview or a disposable uncommitted `AudioStreamPlayer` preview. Do **not** evaluate the final seam only in an external WAV player.

For River and then Rain:

1. loop the imported resource alone for at least 30 seconds;
2. play it under `assets/audio/farm-day-loop.wav` at equal player gain;
3. compare it at equal player gain against `assets/audio/farm-hoe.wav` and `assets/audio/farm-harvest.wav`.

Accept only if:

- no click/level jump appears at the imported loop seam;
- no obvious five-second pulse/swell appears;
- River stays non-tonal and water-like;
- Rain stays steady without harsh attention-grabbing hiss or thunder-like transients;
- each ambience bed remains subordinate under `farm-day-loop.wav` at equal gain;
- both are less attention-grabbing than the farming one-shots;
- River and Rain remain clearly distinguishable.

If the source tone/balance is wrong, regenerate a fresh take and repeat Steps 2-8 (superseded: the generator no longer exists — MCP regeneration produces new takes).

If the **source is acceptable but only the imported loop clicks**, change only the two ambience sidecars to:

```ini
compress/mode=0
```

then reimport and repeat Steps 7-8. Do not change source synthesis merely to compensate for an import artifact.

- [ ] **Step 9: Add compact durable README handoff**

Extend `assets/audio/README.md` with `## HPA-440 river and rain ambience` containing:

- both exact paths/purposes;
- `5.0 s`, mono PCM-16, `22050 Hz`;
- ElevenLabs MCP prompt/model/take-id provenance (superseded: seeds `44001`/`44002` and `tools/generate_hpa_440_ambience.py` no longer apply);
- measured peak **and RMS** for each file;
- accepted sidecar compression mode (`2` unless the seam fallback was required);
- no external samples / no attribution;
- full-clip Forward import contract;
- actual imported-stream measurement verdict covering ≥30-second seam/repetition, equal-gain mix under `farm-day-loop.wav`, farming-SFX comparison, and River/Rain distinction;
- HPA-402 consumer handoff.

Do not duplicate filter coefficients or generator tuning constants into prose.

- [ ] **Step 10: Inspect the complete accepted implementation diff**

Run:

```bash
git status --short
git diff -- assets/audio/README.md \
             assets/audio/river-ambience.wav.import \
             assets/audio/rain-ambience.wav.import \
             tests/headless/project_smoke.gd
```

Expected implementation scope:

```text
assets/audio/river-ambience.wav
assets/audio/rain-ambience.wav
assets/audio/river-ambience.wav.import
assets/audio/rain-ambience.wav.import
assets/audio/README.md
tests/headless/project_smoke.gd
```

No preview/candidate file, runtime player/settings/world change, or unrelated sidecar is present.

- [ ] **Step 11: Commit the accepted implementation once**

Only after Steps 3, 7, 8, and 9 are accepted:

```bash
git add assets/audio/river-ambience.wav \
        assets/audio/rain-ambience.wav \
        assets/audio/river-ambience.wav.import \
        assets/audio/rain-ambience.wav.import \
        assets/audio/README.md \
        tests/headless/project_smoke.gd
git commit -m "feat(audio): add river and rain ambience loops"
```

- [ ] **Step 12: Verify the committed head** (superseded — the byte-identical regeneration gate does not apply to MCP-generated audio)

Run in this order:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected:

- `verify-clean.sh` passes against committed `HEAD`;
- the committed WAVs remain untouched (no regeneration rerun exists to diff);
- `git diff --check` reports no whitespace errors;
- worktree is clean;
- only intended HPA-440 implementation/planning files differ from `main`.

If verification exposes a real defect, make the narrow correction on this same branch, commit it, and rerun this full step. Do not open a second PR.

- [ ] **Step 13: Update PR #20 for closeout**

Record:

- peak/RMS metadata;
- accepted compression mode;
- ElevenLabs MCP prompt/model/take-id provenance and no-external-samples provenance;
- imported 30-second seam/repetition result;
- equal-gain `farm-day-loop.wav` mix verdict;
- farming-SFX comparison;
- `./tools/verify-clean.sh` and `git diff --check` results;
- explicit HPA-402 handoff.

Keep HPA-440 on this one PR.
