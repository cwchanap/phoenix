# Phoenix River and Rain Ambience Audio Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the two deterministic HPA-440 river/rain ambience WAVs, keep their exact source recipe reproducible, and prove Godot imports them as full-clip forward loops without adding runtime audio code.

**Architecture:** Keep HPA-440 entirely at the asset boundary. Add one single-purpose Python-stdlib source generator under `tools/`, generate exactly two 5-second mono PCM-16 WAVs, document compact provenance and listening acceptance in the existing audio README, commit Godot `.import` sidecars, and reuse `tests/headless/project_smoke.gd` for runtime-resource assertions. HPA-402 remains the sole runtime consumer.

**Tech Stack:** Python 3 standard library (`wave`, `math`, `random`, `struct`), Godot 4.7.1 import pipeline, GDScript headless smoke, existing Phoenix verification scripts.

**Spec:** `docs/superpowers/specs/2026-10-15-phoenix-river-rain-audio-assets-design.md`

## Global Constraints

- Deliver exactly `assets/audio/river-ambience.wav` and `assets/audio/rain-ambience.wav` as new runtime audio files.
- Add exactly one source generator: `tools/generate_hpa_440_ambience.py`.
- The generator is single-purpose HPA-440 provenance, not a reusable audio framework or runtime dependency.
- Each WAV is exactly 5.0 seconds / 110250 frames, mono, signed PCM-16, 22050 Hz.
- Use seeds `44001` (River) and `44002` (Rain) with periodic integer-cycle synthesis; no external samples.
- Final source peak for each file stays below 0.30 full scale; do not normalize to full scale.
- Godot import uses full-clip Forward looping: `edit/loop_mode=2`, `edit/loop_begin=0`, `edit/loop_end=-1`.
- Extend `assets/audio/README.md`; do not create another provenance/evidence document.
- Reuse `tests/headless/project_smoke.gd`; add no audio test framework.
- Commit no candidate archive, preview scene, runtime player/settings/weather code, alternate codec, or unrelated refactor.
- One ticket / one branch / one PR; implementation continues on `agent/hpa-440-river-rain-audio-plan`.

## Review Focus

- **Generator/output drift:** rerunning the committed generator must leave both committed WAVs byte-identical.
- **Container drift:** generated files must remain mono PCM-16 / 22050 Hz / 110250 frames.
- **Source clipping/loudness drift:** source peak must stay below 0.30 full scale and below farming-cue prominence by listening review.
- **Import-loop drift:** Godot must load both streams as mono 22050 Hz `AudioStreamWAV` with `LOOP_FORWARD`.
- **Perceptual seam/repetition:** a mathematically continuous loop must still pass a 30-second repeated listen without clicks or distracting five-second patterns.

---

### Task 1: Commit the deterministic source generator and accepted WAVs

**Files:**
- Create: `tools/generate_hpa_440_ambience.py`
- Create: `assets/audio/river-ambience.wav`
- Create: `assets/audio/rain-ambience.wav`
- Modify: `assets/audio/README.md`

**Interfaces:**
- Consumes: the source contract in the design spec.
- Produces: the exact two source WAV paths and one reproducible source recipe for Task 2 / HPA-402.

- [ ] **Step 1: Implement the single-purpose generator**

Create `tools/generate_hpa_440_ambience.py` using only Python stdlib.

The script owns these fixed contracts:

```text
sample_rate = 22050
duration = 5.0
frames = 110250
river_seed = 44001
rain_seed = 44002
```

It writes the exact two runtime paths by default. Keep the implementation direct: small helpers for periodic component synthesis and PCM-16 WAV writing are enough; no CLI/config/plugin abstraction.

River uses deterministic integer-cycle components concentrated around 90-900 Hz with lighter texture to ~2200 Hz and slow modulation below 2 Hz. Rain uses a brighter 700-7000 Hz bed with restrained low-mid body and slow modulation below 3 Hz. Neither recipe contains discrete authored events.

- [ ] **Step 2: Generate both source WAVs**

Run:

```bash
python3 tools/generate_hpa_440_ambience.py
```

Expected: exactly the two HPA-440 WAV paths are created/updated.

- [ ] **Step 3: Verify the source containers and peak guard**

Use an inline Python stdlib `wave` check for each file and assert:

```python
channels == 1
sample_width == 2
sample_rate == 22050
frame_count == 110250
max_abs_sample / 32767.0 < 0.30
```

Print duration and measured peak for the README/PR evidence.

Expected: both pass with duration exactly `5.000s`.

- [ ] **Step 4: Perform first sonic-lane review**

Listen to each file once end-to-end before looping.

Accept only if:

- River reads as low/mid moving water, not a pitched pad or broadband hiss;
- Rain is brighter/denser than River without thunder or a rhythmic pattern;
- neither has a discrete event that advertises a five-second repeat;
- the two are distinguishable within a few seconds.

If tuning is required, change constants/weights in the committed generator while keeping the fixed seeds and format. Do not hand-edit the WAVs.

- [ ] **Step 5: Prove generator reproducibility**

After accepting the candidate, run the generator again and check:

```bash
python3 tools/generate_hpa_440_ambience.py
git diff --exit-code -- assets/audio/river-ambience.wav assets/audio/rain-ambience.wav
```

Expected: no WAV diff after regeneration from the same source revision.

- [ ] **Step 6: Add compact README provenance**

Add `## HPA-440 river and rain ambience` to `assets/audio/README.md` with:

- both runtime paths and purposes;
- `5.0 s`, mono PCM-16, `22050 Hz`;
- seeds `44001` / `44002`;
- `tools/generate_hpa_440_ambience.py` as the exact recipe/source;
- measured source peaks;
- no external samples / no third-party attribution;
- full-clip Forward import requirement;
- HPA-402 as the runtime consumer.

Do **not** transcribe component tables/tuning constants from the script into prose. The generator is the reproducible source of truth.

- [ ] **Step 7: Inspect and commit Task 1**

Run:

```bash
git status --short
git diff -- assets/audio/README.md tools/generate_hpa_440_ambience.py
```

Expected scope: generator + two WAVs + README only; no candidate files, preview scene, `.godot/`, runtime code, or unrelated sidecars.

Commit:

```bash
git add tools/generate_hpa_440_ambience.py \
        assets/audio/river-ambience.wav \
        assets/audio/rain-ambience.wav \
        assets/audio/README.md
git commit -m "feat(audio): add reproducible river and rain ambience"
```

### Task 2: Pin Godot imports, smoke coverage, and durable listening acceptance

**Files:**
- Create: `assets/audio/river-ambience.wav.import`
- Create: `assets/audio/rain-ambience.wav.import`
- Modify: `tests/headless/project_smoke.gd`
- Modify: `assets/audio/README.md`

**Interfaces:**
- Consumes: Task 1's exact WAV paths and committed generator.
- Produces: HPA-402-ready imported loops plus durable mechanical/perceptual acceptance evidence.

- [ ] **Step 1: Add failing ambience-resource smoke assertions**

Extend `tests/headless/project_smoke.gd` with one narrow loop over:

```gdscript
[
    "res://assets/audio/river-ambience.wav",
    "res://assets/audio/rain-ambience.wav",
]
```

For each path assert:

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

Do not assert imported compression format; source PCM-16 is already owned by Task 1's container check.

- [ ] **Step 2: Run the project smoke before loop metadata is pinned**

Allow Godot to discover/import the new WAVs if needed, then run the same project-smoke command used by `tools/verify-clean.sh`.

Expected: FAIL on `loop_mode` before the new sidecars are pinned to Forward.

- [ ] **Step 3: Generate and pin the `.import` sidecars**

Run:

```bash
godot --headless --path . --editor --quit
```

Ensure both sidecars retain normal WAV import settings and set exactly:

```ini
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
```

Re-import once if Godot requires it. Do not add `.tres` wrappers or source WAV loop chunks.

- [ ] **Step 4: Run focused mechanical checks**

Run the project smoke again.

Expected: both ambience resources load as mono 22050 Hz `AudioStreamWAV`, use `LOOP_FORWARD`, and report 4-6 second duration.

Then rerun the Task 1 source-container/peak check to prove import work did not rewrite the source files.

- [ ] **Step 5: Perform 30-second loop/seam acceptance**

Using Godot's editor audio preview or a disposable uncommitted local preview, loop each asset continuously for at least 30 seconds.

Reject/regenerate through the committed generator if:

- a click or level jump occurs at the seam;
- a distinctive swell exposes the five-second period;
- River develops an obvious pitch/beat;
- Rain develops an obvious pulse, thunder-like transient, or harsh hiss.

No preview scene is committed.

- [ ] **Step 6: Compare prominence at equal gain**

At the same preview/player gain, compare River and Rain against:

- `assets/audio/farm-hoe.wav`
- `assets/audio/farm-harvest.wav`

Accept only if both ambience loops are less attention-grabbing than the farming one-shots and remain distinguishable from each other. Do not raise source gain to compensate for HPA-402's future `-12 dB` headroom.

- [ ] **Step 7: Record the durable listening verdict in `assets/audio/README.md`**

Append one concise qualitative acceptance line to the HPA-440 section, for example:

```text
Listening acceptance: both loops are seam-clean over a 30 s repeat, remain distinct, and are less attention-grabbing than farm-hoe.wav / farm-harvest.wav at equal preview gain.
```

Use the actual observed wording; do not claim acceptance until the checks in Steps 5-6 pass. The PR description may repeat this result but is not its only copy.

- [ ] **Step 8: Commit Task 2 before the clean verifier**

`./tools/verify-clean.sh` archives committed `HEAD`, so commit the import/smoke/README acceptance before using it as an oracle:

```bash
git add assets/audio/river-ambience.wav.import \
        assets/audio/rain-ambience.wav.import \
        tests/headless/project_smoke.gd \
        assets/audio/README.md
git commit -m "test(audio): verify ambience loop imports"
```

- [ ] **Step 9: Run committed-head repository verification**

Run:

```bash
./tools/verify-clean.sh
python3 tools/generate_hpa_440_ambience.py
git diff --exit-code -- assets/audio/river-ambience.wav assets/audio/rain-ambience.wav
git diff --check main...HEAD
git status --short
```

Expected:

- `verify-clean.sh` passes against committed HEAD;
- generator rerun leaves both WAVs byte-identical;
- `git diff --check` reports no whitespace errors;
- only intended HPA-440 files differ from `main`;
- worktree is clean and contains no preview/candidate artifact.

If verification exposes a defect, fix the narrow issue, commit it on this same branch, and rerun the full step.

- [ ] **Step 10: Update the same draft PR for closeout**

Update PR #20 with:

- exact source metadata and measured peaks;
- generator path, fixed seeds, and no-external-samples confirmation;
- deterministic rerun result;
- 30-second seam/repetition verdict;
- equal-gain farming-cue comparison;
- `./tools/verify-clean.sh` and `git diff --check` results;
- explicit HPA-402 handoff to the two exact paths.

Do not open a second implementation PR.
