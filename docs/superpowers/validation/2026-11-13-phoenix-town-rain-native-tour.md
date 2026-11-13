# HPA-860 native macOS visual/audio verification — town rain without farm ripples

Date: 2026-11-13 (revised same day, review round 1: layer-identity telemetry, capture-failure
gating, temporal frame-sequence bursts, continuity claims narrowed — see "Round-1 review
hardening" below; review round 2: continuous per-frame movie recording of the rainy travel and
camera-edge movement — see "Round-2 continuous movie recording" below)
Build: committed `HEAD` = `04347d6` (branch `agent/hpa-860-town-rain-visual-plan`), worktree
`/Users/chanwaichan/orca/workspaces/phoenix/hpa-860-plan-town-rain-visuals-without-farm-rive`
Operator: agent-operated native run (vision review of real rendered captures), not a human playtest.
Runtime: Godot 4.7.1 stable, macOS (Apple M1 Pro), real windowed app — window logged
`(1920, 1080)` on a screen with usable rect `(3024, 1898)`; captures are the actual 1920x1080
viewport renders saved as PNG.

## Method

`tests/native_tour/rain_tour.gd` (committed with this note) runs the real `scenes/app/app.tscn`
in a windowed SceneTree, drives real input events (title Continue via W/Enter, WASD walking,
E interact, Esc close), and saves viewport captures plus structured observation lines:

```
OBS <phase> | weather=... rain_layer_id=... rain_falling=...(expect ...) rain_audio=...
river_audio=... tint=... blocking_modal=... window_focus=... clock_focused=... farm_ripples=...
target=... facing=...
```

Every capture checks its `save_png()` result and a usable `TOUR_OUT` directory; any write failure
fails the run. Around each truck travel the tour captures consecutive-frame bursts (8 frames
before the E-press, 12 frames immediately after each map swap) plus five ~2 s-spaced walk samples
at the town camera edge; a rainy burst whose frames are all byte-identical fails the run as stale
(rain animates every drawn frame). The tour sets `WINDOW_FLAG_ALWAYS_ON_TOP` at startup because an
occluded macOS window stops drawing and later captures silently return one stale frame.

`tests/native_tour/seed_save.gd` seeds a schema-v4 save with a forced weather through the real
`GameSession`/`SessionStateValidator`/`SaveRepository` path so Continue starts rainy or sunny
deterministically. `HOME`, `PHOENIX_SAVE_PATH`, and `PHOENIX_SETTINGS_PATH` were isolated under
`/tmp/phoenix-hpa860-tour`; real player settings/saves were never touched.

Rerun (from repo root):

```bash
TOUR=/tmp/phoenix-hpa860-tour
export HOME="$TOUR/home" PHOENIX_SAVE_PATH="$TOUR/save/phoenix-save.json" \
  PHOENIX_SETTINGS_PATH="$TOUR/settings/phoenix-settings.cfg"
mkdir -p "$TOUR/home" "$TOUR/save" "$TOUR/settings" "$TOUR/out-rainy" "$TOUR/out-sunny"
TOUR_WEATHER=rainy godot --headless --path . --script res://tests/native_tour/seed_save.gd
TOUR_WEATHER=rainy TOUR_OUT="$TOUR/out-rainy" \
  godot --path . --resolution 1920x1080 --script res://tests/native_tour/rain_tour.gd
# repeat with TOUR_WEATHER=sunny / TOUR_OUT="$TOUR/out-sunny"
```

Both final runs ended `DONE clean tour=...` (exit 0, zero recorded failures). The tour asserts:
shop modal opens, Hana dialogue opens, market refusal toast names Day 14, both truck travels swap
maps, `rain_falling` matches the seeded weather at every observation point, and facing matches at
every interaction. Review round 1 adds: every capture must save, the rain layer instance ID must
never change across the whole tour, and a rainy burst must not be entirely byte-identical.

## Rainy tour results (all `rain_falling=true`)

| Phase | Weather | Rain layer | Rain audio | River audio | HUD tint | Farm ripples | Notes |
|---|---|---|---|---|---|---|---|
| farm spawn/bed/truck | rainy | falling | playing | playing | `(0.38, 0.52, 0.72, 0.12)` | 3 | streaks over whole farm view |
| E at farm truck `(22,9)` | rainy | — | — | — | — | — | travel accepted, clock 06:00→06:30 (+30) |
| town arrival | rainy | falling | playing | playing | same | -1 (none) | streaks over town view; round-1 rerun: 12-frame post-swap burst, rain in every frame |
| town east-edge walk (+2 mid-walk captures) | rainy | falling | playing | playing | same | -1 | round-1 rerun: 5 walk samples 06:42→06:44, rain in every sample, no popping (sampled frames) |
| Seed Shop `(7,4)` E → modal, Esc close | rainy | falling | playing | playing | same | -1 | "E Seed Shop" prompt pill; panel native |
| Hana `(11,6)` E → dialogue | rainy | falling | playing | playing | same | -1 | rainy-weather dialogue line renders |
| Market `(13,7)` E → refusal | rainy | falling | playing | playing | same | -1 | red toast "The Harvest Market opens on Day 14." |
| town truck `(2,9)` E → travel home | rainy | falling | playing | playing | same | 3 restored | 07:00 on return; rain continues |
| return farm | rainy | falling | playing | playing | same | 3 | same `rain_layer_id` across both travels (round 1) |

## Sunny tour results (all `rain_falling=false`, quick phase)

| Phase | Weather | Rain layer | Rain audio | River audio | HUD tint | Farm ripples |
|---|---|---|---|---|---|---|
| farm spawn/bed/truck | sunny | not falling | stopped | playing | `(1.0, 0.96, 0.86, 0.03)` | 3 |
| town arrival + east edge | sunny | not falling | stopped | playing | same | -1 |
| return farm | sunny | not falling | stopped | playing | same | 3 |

## Visual findings (vision review of the actual captures)

- Rain streaks render over the farm and over the town, identical rendering in both maps; absent
  in sunny captures in both maps. The streak code path and look are unchanged from the
  pre-HPA-860 reference, with one disclosed layering difference: the old ambience painted
  streaks on its own canvas item, which draws beneath its child ripple sprites, while the shell
  `RainLayer` — same z=6, but a later World sibling than `FarmMap` — draws streaks over the
  ripple strips. Farm captures here therefore show streaks above the ripples where the old
  build showed them under; geometry, color and motion are unchanged.
- Persistent layer identity (round 1): `rain_layer_id` (Godot instance ID) is identical at every
  observation and at both map-swap boundaries — the same `RainLayer` node existed across both
  truck travels. The original "no restart gap" phrasing claimed more than still captures plus a
  falling-state boolean could establish (a recreated layer or brief flicker could have passed);
  the instance-ID comparison and the consecutive-frame bursts (12 frames right after each swap,
  rain in every sampled frame) are the actual continuity evidence.
- Farm shows its three river ripple sprites (`farm_ripples=3`); town reports `-1` (no farm
  ambience node) and no ripple visuals appear in any town capture.
- HUD rainy tint `(0.38, 0.52, 0.72, 0.12)` / Sunny pill vs warm sunny tint
  `(1.0, 0.96, 0.86, 0.03)` — weather tint retained and weather-correct.
- Camera-edge walk to the town's south-east band corner, round-1 rerun sampled as five walk
  frames (06:42→06:44, ~2 s apart) plus endpoint stills: rain present in every sample, steady
  camera progression, no popping or new occlusion bugs in the sampled frames; player/prop/villager
  Y-sort correct. Subjective smoothness between samples remains a human live check (open).
- Depth, gold target, floating prompts ("E Seed Shop", "E Gen-san", "E Harvest Market"), Seed
  Shop panel, Hana dialogue (with her rainy-day line), market refusal toast, and key pills all
  render correctly in rainy captures; travel clock math visible (06:00 → 06:30 → 07:00).
- Audio (observable state only): rain ambience player plays in rainy farm and town, stops in
  sunny; river audio player plays throughout (farm with ripples; town remains the accepted
  audio-without-visuals limitation, unchanged by this branch).

## Round-1 review hardening (2026-11-13)

Task-5 review flagged two findings; both are fixed in `tests/native_tour/rain_tour.gd` and
re-verified with fresh native runs. No production code changed.

1. **Temporal continuity was overstated.** Fixed with two mechanisms: `rain_layer_id` (Godot
   instance ID) telemetry — recorded in every OBS line and both `map swapped` logs, run fails if
   it ever changes — proves layer persistence by identity instead of inferring it from a falling
   boolean; and consecutive-frame burst captures around each travel plus ~2 s-spaced camera-edge
   walk samples give reviewable temporal sequences. A rainy burst that is entirely byte-identical
   fails the run (rain animates every drawn frame), so a stalled renderer cannot masquerade as
   smooth rain. Vision review of the rerun sequences: rainy farm pre-swap 8/8 frames with
   streaks; town arrival 12/12 frames with streaks over plaza and roofs (clock 06:39→06:41, Day
   2/14, travel +30 visible); camera-edge walk 5 samples 06:42→06:44 tracking the walk with no
   popping or occlusion regressions; return farm 12/12 with streaks (07:32 after the second +30);
   sunny arrival and sunny return 12/12 each with no streaks. This is still sampled-frame
   evidence — inside bursts one capture per processed frame (wall clock stretched to a few Hz by
   readback cost), ~2 s spacing on the walk — not video; a human subjective live check remains
   open.
2. **Failed evidence capture still permitted a clean exit.** `_shot()` logged `save_png()` errors
   without recording a failure. The tour now validates `TOUR_OUT` (empty name and
   `make_dir_recursive` result) and every `save_png()` error code, appending each to the failure
   list, so unwritable evidence fails the run instead of printing `DONE clean`.

Rerun on the committed tour (isolated `HOME`, same seed/launch interface as above, outputs under
`/tmp/phoenix-hpa860-tour-r1`; exact commands and outputs in `.superpowers/sdd/2026-11-11-phoenix-town-rain-visual-implementation/task-5-report.md`):

- Rainy: `DONE clean tour=rainy`, exit 0; all 59 captures distinct; bursts 7/7, 11/11, 7/7, 11/11
  differing consecutive pairs; `rain_layer_id` constant across all 11 OBS points and both swap
  boundaries; `farm_ripples=3` on farm before/after travel, `-1` in town; clock 06:09 → 06:39 →
  07:02 → 07:32 across the two +30 drives, Day 2/14 throughout (the window stayed focused this
  time, so the passive clock ran during the tour).
- Sunny: `DONE clean tour=sunny`, exit 0; `rain_layer_id` constant; sunny bursts legitimately
  near-static (no rain; the staleness failure is rainy-only) with ticking-clock pairs logged.
- Failure path: with `chmod 000` on the output directory the run recorded 57 `FAIL capture ...`
  `not saved: save_png err=12` lines and exited 2 with `DONE with 68 failures` (the other 11
  came from a deliberately mismatched sunny save under the rainy label; every failure class gates
  the exit).

A hazard surfaced during the first round-1 rerun attempt: with the game window occluded by
another window, macOS stopped drawing and every later capture silently returned one stale frame
(57 of 58 files byte-identical) while the tour still printed `DONE clean`. The committed tour now
sets `ALWAYS_ON_TOP`, fails stale rainy bursts, and gates on capture write errors; reruns above
are clean under those guards.

## Round-2 continuous movie recording (2026-11-13)

Task-5 review round 2 required a genuine continuous recording of the rainy truck travel and
camera-edge movement: the round-1 bursts and ~2 s-spaced walk samples cannot exclude a brief
rendering gap *between* samples.

**OS screen-recording attempts (both blocked by TCC):**

- `screencapture -v -V 3 probe.mov` (macOS 26.6.2 native facility) → exit 1, no file produced,
  `could not create image from display` on the still-capture probe too. The shell's host app
  (`orca-terminal-host`) does not hold Screen Recording permission; granting it requires a human
  in System Settings → Privacy & Security → Screen Recording plus an app restart, which an agent
  cannot do. Still captures fail identically, so this is a permission block, not a transient
  error.
- `ffmpeg -f avfoundation -i "1:0" -t 5` → ffmpeg lists the device modes but the device open
  fails with `Error opening input: Input/output error`, exit 1, no file — the same TCC gate
  expressed as an I/O error.

Exact commands and exits are in the task-5 report. No OS-desktop recording is possible from this
session without a human granting Screen Recording permission; that check is left open rather than
faked.

**Continuous per-frame movie recording (performed):** Godot's Movie Maker mode
(`--write-movie`) records the *actual game render* frame-accurately — it synchronously writes
every rendered frame at a fixed fps under a fixed timestep, so frames cannot be dropped by
construction. It is not an OS desktop capture (it records the game's own rendered output, which
is exactly what HPA-860 changed), but it is a genuine continuous recording, distinct from the
slow discrete `get_image` captures in `rain_tour.gd`: there are no frames missing between
samples, so a brief rendering gap cannot hide anywhere in the movie.

`tests/native_tour/rain_movie_tour.gd` (committed with this note) drives the real app through
the rainy farm truck travel, the town camera-edge walk, and the travel home while the movie is
written; it logs `frame=<Engine.get_frames_drawn()>` with every observation so movie frames map
to tour events exactly, keeps the round-1 gates (constant `rain_layer_id`, `rain_falling=true`
at every observation), and is read-only toward gameplay.

```bash
REC=/tmp/phoenix-hpa860-rec
mkdir -p "$REC/home" "$REC/save" "$REC/settings" "$REC/run"
export HOME="$REC/home" PHOENIX_SAVE_PATH="$REC/save/phoenix-save.json" \
  PHOENIX_SETTINGS_PATH="$REC/settings/phoenix-settings.cfg"
TOUR_WEATHER=rainy godot --headless --path . --script res://tests/native_tour/seed_save.gd
TOUR_WEATHER=rainy godot --path . --resolution 1920x1080 \
  --write-movie "$REC/run/rain-travel.avi" --fixed-fps 30 \
  -s res://tests/native_tour/rain_movie_tour.gd
```

Result: exit 0, `DONE clean movie tour`, 514 frames at 30 FPS, movie length 17.133333 s
(514 = 30 × 17.133333 exactly), MJPEG 1920×1080 AVI (255 MB, kept under `/tmp/phoenix-hpa860-rec`,
not committed — no large video assets in the repo). Frame-count integrity: `ffprobe` reports
`nb_frames=514`, `r_frame_rate=30/1`, `duration=17.133333` — no dropped frames.

**Whole-movie frame analysis (PIL + md5 over all 514 extracted frames, plus vision review of
labeled contact sheets):**

- Liveness (hash pass): all 13 byte-identical consecutive frame pairs are frames 1–15 (the
  static title screen before the world loads). Every gameplay frame 15–514 differs from its
  predecessor — the renderer produced a fresh frame on every single gameplay frame, so no
  stale-frame masquerade is possible. The hashes prove frame freshness only, not what a frame
  depicts: rain presence is established visually on the sheets below, whose walk sheets sample
  every 2nd frame rather than every frame.
- Map swap 1 (farm → town): `E-press` at frame 184, `map swapped` logged at frame 185. Frames
  178–185 show the rainy farm with streaks up to the truck ("Drive to town" prompt); frame 186
  — the immediately following frame — already renders the town **with rain streaks over it**
  (station, truck, villagers, clock 06:11→06:41 from the +30 travel). The swap is covered by
  adjacent frames with no gap, black, or flicker frame, and rain renders on both sides.
- Map swap 2 (town → farm): `E-press` at frame 482, `map swapped` logged at frame 483. Frames
  482–483 render the rainy town with streaks ("Drive home" prompt, 07:01); frame 484 renders
  the rainy farm with streaks (07:31). Same frame-adjacent continuity, rain on both sides.
- Camera-edge walk (frames 216–330, contact sheets every 2nd frame plus endpoints): rain
  streaks present in every inspected tile — frames between the every-2nd-frame sheet samples
  were not vision-checked — while the camera pans south-east to the perimeter
  band corner and back; gold target and the "Gen-san" prompt pill track correctly; no popping,
  no new occlusion or depth regressions at any sampled frame.
- Farm walk to the truck (frames 16–184, sheets every 10th frame) and the return-farm tail
  (frames 476–514): rain streaks in every inspected tile; bed prompt, truck prompt, and Y-sort
  correct throughout.
- Layer identity: `rain_layer_id` is constant across all five OBS points and both swap logs;
  `rain_falling=true` at every observation; the window was focused the whole run, so the
  passive clock is visibly live in the movie (06:02 → 06:41 → 07:01 → 07:33 across the two
  +30 drives).

Vision review was performed by the operator on labeled contact sheets built from the movie
frames (whole-movie coarse sheets, per-frame sheets spanning both swap boundaries, every-2nd-
frame sheets spanning the camera-edge walk, and full-res boundary frames 185/186 and
482/483/484). This closes the review-round-2 finding within the limits of that sampling: rain
is verified visually at true single-frame granularity across both truck swaps (full-res
adjacent frames on both sides), and at every-2nd-frame granularity along the camera-edge walk,
while the md5 pass proves every gameplay frame in the movie is a fresh render — a rendering
stall or dropped-frame gap is excluded anywhere in the movie by evidence rather than sampling
luck. What the evidence cannot exclude is a hypothetical one-frame rain absence at an
uninspected walk frame; frames between the walk-sheet samples were not vision-checked.

**Still open after round 2:** an OS-desktop-level screen recording (needs a human-granted TCC
Screen Recording permission for the agent's terminal host; both macOS facilities fail with the
exact errors above until then), and the human subjective live-look checks (rain smoothness,
audio listening, unlocked-desktop pacing/focus) from round 1.

## Limitations

- Focus and the passive clock, split by run generation: the original locked-session capture
  runs never received a real OS focus transition (`window_focus=false` in every OBS line), so
  the clock stayed frozen in those runs (only the +30 travel steps moved it; one earlier
  focused run of the same build ticked 06:00→06:06). The corrected final runs ran focused
  instead — the round-1 rerun kept the window focused (clock ticking 06:09→06:39→07:02→07:32)
  and the round-2 movie logged `window_focus=true` throughout (clock visibly live,
  06:02→06:41→07:01→07:33) — so the frozen-clock caveat applies to the original runs, not to
  the final evidence. Clock freeze/tick/cutoff behavior itself is covered by the deterministic
  GUT focus-notification tests; a human unlocked-desktop pacing/focus check remains open per
  the HPA-263 note.
- Audio was verified by player `playing` state and code identity only — no human listening check.
- No pixel-diff against the pre-change build: a second checkout at the baseline commit was
  declined (worktree/branch constraints). Farm-rain equivalence is of streak geometry, color
  and motion — supported by the unchanged rendering code path, the Task-3 z-order pins and the
  visual match of the rainy farm captures — but it is not strict per-pixel identity: the
  disclosed streak-over-ripple layering difference above is real, and equivalence claims must
  not cover it.
- The tour initially failed truck/shop/social interactions; diagnosis showed tour-authoring bugs,
  not product bugs: `WorldMath.TARGET_OFFSETS` are isometric diagonal grid neighbors, town
  perimeter bands sit two cells inside each map edge, and villager footprints block straight-line
  walk hops. The committed tour routes around all three and asserts every interaction outcome.
- Temporal review is sampled-frame based in the round-1 tours: burst captures inside the swaps
  (one capture per processed frame) and ~2 s-spaced walk samples establish rain presence, layer
  identity, and no popping at those samples. Round 2 supersedes this for the travel/camera-edge
  question with the continuous per-frame movie recording above: rain visually confirmed at
  single-frame granularity across both swaps, at every-2nd-frame granularity on the walk, and
  every gameplay frame hash-verified fresh; the remaining open items are the OS-desktop
  recording permission and the human subjective checks (smoothness, audio, pacing/focus).
- Pre-round-1 tour versions could print `DONE clean` with frozen or unsaved captures (occlusion
  stale frames; `save_png` errors only logged). Treat `DONE clean` as valid only for the round-1
  tour or later.
