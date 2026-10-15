# Phoenix River and Rain Ambience Audio Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the two deterministic HPA-440 river/rain ambience WAVs, document their provenance, and prove Godot imports them as full-clip forward loops without adding runtime audio code.

**Architecture:** Keep HPA-440 entirely at the asset boundary. Generate two fixed 5-second mono PCM-16 WAVs from a temporary local Python-stdlib recipe, commit only accepted outputs plus their Godot `.import` sidecars, extend the existing audio README, and reuse `tests/headless/project_smoke.gd` for resource/import assertions. HPA-402 remains the sole runtime consumer.

**Tech Stack:** Python 3 standard library (`wave`, `math`, `random`, `struct`), Godot 4.7.1 import pipeline, GDScript headless smoke, existing Phoenix verification scripts.

**Spec:** `docs/superpowers/specs/2026-10-15-phoenix-river-rain-audio-assets-design.md`

## Global Constraints

- Deliver exactly `assets/audio/river-ambience.wav` and `assets/audio/rain-ambience.wav` as new runtime audio files.
- Each source WAV is exactly 5.0 seconds / 110250 frames, mono, signed PCM-16, 22050 Hz.
- Use fixed seeds `44001` (River) and `44002` (Rain) with periodic integer-cycle synthesis; no external samples.
- Final source peak for each file stays below 0.30 full scale; do not normalize to full scale.
- Godot import uses full-clip Forward looping: `edit/loop_mode=2`, `edit/loop_begin=0`, `edit/loop_end=-1`.
- Extend `assets/audio/README.md` rather than creating another provenance document.
- Reuse `tests/headless/project_smoke.gd`; add no audio framework or new test file.
- Commit no generator script, candidate audio, preview scene, runtime player/settings/weather code, Ogg/MP3 copy, or unrelated refactor.
- One ticket / one branch / one PR; implementation continues on `agent/hpa-440-river-rain-audio-plan`.

## Review Focus

- **Container drift:** a generated file accidentally becomes stereo, 8-bit, wrong-rate, or wrong-length; Task 1's Python `wave` verifier must reject it.
- **Source clipping/loudness drift:** synthesis gain produces a peak at or above 0.30 full scale; Task 1's PCM peak assertion must reject it before commit.
- **Import-loop drift:** Godot imports either stream without full-clip forward looping; Task 2's `project_smoke.gd` assertions must fail.
- **Perceptual seam/repetition:** a mathematically continuous five-second loop still clicks or exposes an obvious repeating swell; Task 2 requires a 30-second repeated listen for each stream.
- **Sonic-lane drift:** River becomes hissy/tonal or Rain becomes thunderous/rhythmic and the two are not immediately distinguishable; Task 1 candidate review and Task 2 equal-gain comparison must reject the candidate.

---

### Task 1: Generate the two accepted source WAVs and record provenance

**Files:**
- Create: `assets/audio/river-ambience.wav`
- Create: `assets/audio/rain-ambience.wav`
- Modify: `assets/audio/README.md`
- Local only: temporary HPA-440 Python generator; do not commit it

**Interfaces:**
- Consumes: the source/recipe contract from the design spec and the existing project-generated-audio convention in `assets/audio/README.md`.
- Produces: two exact source WAV paths for Godot import; README provenance that HPA-402 can treat as the asset handoff.

- [ ] **Step 1: Write the local source-container verifier first**

Create a temporary local Python check (inline shell heredoc or untracked helper) that opens both final paths with `wave` and asserts for each:

```python
channels == 1
sample_width == 2
sample_rate == 22050
frame_count == 110250
max_abs_sample / 32767.0 < 0.30
```

The verifier should also print duration and peak for review. Do not commit this helper.

- [ ] **Step 2: Run the verifier before generation to confirm the gate is red**

Run the local verifier.

Expected: FAIL because `river-ambience.wav` / `rain-ambience.wav` do not exist yet.

- [ ] **Step 3: Generate deterministic River candidate**

Using a temporary Python-stdlib generator, write `assets/audio/river-ambience.wav` with:

- `5.0 s`, 22050 Hz, mono PCM-16;
- seed `44001`;
- many randomly phased periodic harmonic components whose frequencies complete integer cycles inside the five-second period;
- strongest spectral energy roughly `90-900 Hz`, lighter texture to roughly `2200 Hz`;
- only slow periodic amplitude movement below `2 Hz`;
- conservative fixed output gain with no post-normalization to full scale;
- no isolated splash/bird/voice/music events.

The implementer may tune component counts/weights locally, but must keep the locked format, seed, periodic construction, spectral lane, and peak ceiling. Whatever final counts/ranges/gains ship must be copied into the README in Step 7.

- [ ] **Step 4: Generate deterministic Rain candidate**

Using the same temporary generator shape, write `assets/audio/rain-ambience.wav` with:

- `5.0 s`, 22050 Hz, mono PCM-16;
- seed `44002`;
- many randomly phased periodic harmonic components completing integer cycles inside the five-second period;
- broad dominant energy roughly `700-7000 Hz` plus restrained low-mid body;
- only slow periodic density/amplitude movement below `3 Hz`;
- conservative fixed output gain with no post-normalization to full scale;
- no thunder, gusts, pitched drops, voice, music, or discrete impact events.

The two recipes should share construction, not timbre. Record the final component counts/ranges/gains rather than leaving them as implementation-only tuning.

- [ ] **Step 5: Run the source-container verifier**

Run the verifier from Step 1.

Expected for both assets:

```text
channels=1
sample_width=2
sample_rate=22050
frames=110250
duration=5.000s
peak<0.30
```

If either file fails, fix synthesis/export before continuing; do not patch the WAV header by hand.

- [ ] **Step 6: Perform first sonic-lane review**

Listen to each source once end-to-end before looping it.

Accept only if:

- River reads as low/mid moving water, not a pitched pad or broadband hiss;
- Rain is brighter/denser than River without thunder or a rhythmic pattern;
- neither contains a single event that will advertise a five-second repeat;
- the two are distinguishable within a few seconds.

Regenerate from the same fixed seed with adjusted deterministic weights if the lane is wrong; do not change seeds to hunt randomly for a lucky candidate.

- [ ] **Step 7: Extend `assets/audio/README.md` with the HPA-440 recipe/handoff**

Add one `## HPA-440 river and rain ambience` section that records both paths and, for each, the exact locked source format, fixed seed, periodic-harmonic method, **final component counts, harmonic/frequency ranges, amplitude-weight rules, modulation frequencies/depths, and fixed output gain**, measured peak, absence of external samples, full-clip Forward import requirement, and HPA-402 consumer ownership.

The documented constants must be sufficient to reconstruct the accepted waveform with the same standard-library algorithm even though the temporary script itself is not retained.

Keep the existing HPA-599/HPA-459 provenance intact. State explicitly that the temporary generator is not committed, matching the current one-off audio convention.

- [ ] **Step 8: Inspect the task diff**

Run:

```bash
git status --short
git diff -- assets/audio/README.md
```

Expected: only the two WAVs and README are new/modified at this stage; no candidate files, temporary generator, `.godot/`, runtime code, or unrelated sidecars are staged.

- [ ] **Step 9: Commit the accepted source assets**

```bash
git add assets/audio/river-ambience.wav assets/audio/rain-ambience.wav assets/audio/README.md
git commit -m "feat(audio): add river and rain ambience sources"
```

### Task 2: Pin Godot loop imports, existing-smoke coverage, and audible acceptance

**Files:**
- Create: `assets/audio/river-ambience.wav.import`
- Create: `assets/audio/rain-ambience.wav.import`
- Modify: `tests/headless/project_smoke.gd`
- Verify only: `assets/audio/river-ambience.wav`
- Verify only: `assets/audio/rain-ambience.wav`

**Interfaces:**
- Consumes: Task 1's exact source WAV paths.
- Produces: Godot-imported full-loop `AudioStreamWAV` resources that HPA-402 can preload directly after this PR merges.

- [ ] **Step 1: Add the failing ambience-resource smoke assertions**

Extend `tests/headless/project_smoke.gd` with one narrow loop over:

```gdscript
[
    "res://assets/audio/river-ambience.wav",
    "res://assets/audio/rain-ambience.wav",
]
```

For each path, assert:

```gdscript
ResourceLoader.exists(path)
var stream := ResourceLoader.load(path) as AudioStreamWAV
stream != null
stream.mix_rate == 22050
stream.stereo == false
stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
stream.get_length() >= 4.0
stream.get_length() <= 6.0
```

Do not assert imported compression format; the source PCM-16 contract is owned by Task 1's WAV-container check.

- [ ] **Step 2: Run the project smoke before fixing import loop metadata**

Run the same headless project-smoke command used by `tools/verify-clean.sh` after allowing Godot to discover/import the new WAVs if necessary.

Expected: FAIL on `loop_mode` for at least one newly imported stream because default import metadata has not yet been pinned to Forward.

- [ ] **Step 3: Generate and pin the two Godot `.import` sidecars**

Run:

```bash
godot --headless --path . --editor --quit
```

Then ensure both generated sidecars retain Godot's normal WAV import settings but set exactly:

```ini
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
```

Do not create `.tres` wrappers or source WAV loop chunks. Re-import once if Godot requires it after the sidecar change.

- [ ] **Step 4: Run the focused project smoke again**

Run the project smoke directly.

Expected: PASS, with both ambience resources loading as mono 22050 Hz `AudioStreamWAV` using `LOOP_FORWARD` and 4-6 second duration.

- [ ] **Step 5: Re-run the Task 1 source-container/peak verifier**

Run the same temporary Python verifier against the committed source WAVs.

Expected: both remain 1-channel / 2-byte / 22050 Hz / 110250-frame files with peak `<0.30`; Godot import work must not rewrite source audio.

- [ ] **Step 6: Perform the 30-second loop/seam acceptance**

Using Godot's editor audio preview or a disposable uncommitted local preview, loop each asset continuously for at least 30 seconds.

Reject/regenerate if:

- a click or level jump occurs at the seam;
- a distinctive swell/event exposes the five-second period;
- River develops an obvious pitch/beat;
- Rain develops an obvious pulse, thunder-like transient, or harsh attention-grabbing hiss.

No preview scene is committed.

- [ ] **Step 7: Compare source prominence against existing farming cues at equal gain**

At the same preview/player gain, compare River and Rain to at least:

- `assets/audio/farm-hoe.wav`
- `assets/audio/farm-harvest.wav`

Accept only if both ambience loops are deliberately less attention-grabbing than the one-shot farming cues and still remain distinguishable from each other. Do not boost source level to compensate for HPA-402's future `-12 dB` runtime headroom.

Record this qualitative result in the PR description, not in a new repository artifact.

- [ ] **Step 8: Commit the import/test change before the clean verifier**

`./tools/verify-clean.sh` archives committed `HEAD`, so commit the Task 2 files before using it as an oracle:

```bash
git add assets/audio/river-ambience.wav.import \
        assets/audio/rain-ambience.wav.import \
        tests/headless/project_smoke.gd
git commit -m "test(audio): verify ambience loop imports"
```

- [ ] **Step 9: Run committed-head repository verification**

Run:

```bash
./tools/verify-clean.sh
git diff --check main...HEAD
git status --short
```

Expected:

- `verify-clean.sh` passes against the committed Task 1 + Task 2 head;
- `git diff --check` reports no whitespace errors;
- only the intended HPA-440 files differ from `main`;
- no untracked temporary generator/candidate/preview artifact remains in the repository worktree.

If verification exposes a defect, fix it and commit the narrow correction on this same branch, then rerun the full step.

- [ ] **Step 10: Update the same draft PR for implementation closeout**

Keep HPA-440 on this one PR. Update the PR description with:

- exact source metadata and documented recipe constants for both WAVs;
- measured source peaks;
- confirmation of fixed seeds and no external samples;
- 30-second seam/repetition review result;
- equal-gain comparison result versus farming cues;
- `./tools/verify-clean.sh` and `git diff --check` results;
- explicit handoff that HPA-402 can now branch from merged `main` and consume the two exact paths.

Do not open a second implementation PR.
