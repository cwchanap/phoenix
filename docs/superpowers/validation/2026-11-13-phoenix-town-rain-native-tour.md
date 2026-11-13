# HPA-860 native macOS visual/audio verification — town rain without farm ripples

Date: 2026-11-13 (revised same day, review round 1: layer-identity telemetry, capture-failure
gating, temporal frame-sequence bursts, continuity claims narrowed — see "Round-1 review
hardening" below)
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
mkdir -p "$TOUR/save" "$TOUR/out-rainy" "$TOUR/out-sunny"
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
  in sunny captures in both maps. Farm rain look is unchanged from the pre-HPA-860 reference.
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

## Limitations

- Locked-session runs never received a real OS focus transition (`window_focus=false` in OBS for
  the final runs), so the passive day clock stayed frozen during the capture tours; one earlier
  run of the same build did tick 06:00→06:06 while focused, and clock behavior itself is covered
  by the deterministic GUT focus-notification tests. A human unlocked-desktop pacing/focus check
  remains open per the HPA-263 note.
- Audio was verified by player `playing` state and code identity only — no human listening check.
- No pixel-diff against the pre-change build: a second checkout at the baseline commit was
  declined (worktree/branch constraints). Equivalence of farm rain is supported by the unchanged
  rendering code path, the Task-3 z-order pins, and visual match of the rainy farm captures.
- The tour initially failed truck/shop/social interactions; diagnosis showed tour-authoring bugs,
  not product bugs: `WorldMath.TARGET_OFFSETS` are isometric diagonal grid neighbors, town
  perimeter bands sit two cells inside each map edge, and villager footprints block straight-line
  walk hops. The committed tour routes around all three and asserts every interaction outcome.
- Temporal review is sampled-frame based: burst captures inside the swaps (one capture per
  processed frame) and ~2 s-spaced walk samples establish rain presence, layer identity, and
  no popping at those samples; rain motion between samples and subjective smoothness are human
  live checks that remain open.
- Pre-round-1 tour versions could print `DONE clean` with frozen or unsaved captures (occlusion
  stale frames; `save_png` errors only logged). Treat `DONE clean` as valid only for the round-1
  tour or later.
