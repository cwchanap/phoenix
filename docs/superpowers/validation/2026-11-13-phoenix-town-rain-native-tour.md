# HPA-860 native macOS visual/audio verification — town rain without farm ripples

Date: 2026-11-13
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
OBS <phase> | weather=... rain_falling=...(expect ...) rain_audio=... river_audio=...
tint=... blocking_modal=... window_focus=... clock_focused=... farm_ripples=... target=... facing=...
```

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
every interaction.

## Rainy tour results (all `rain_falling=true`)

| Phase | Weather | Rain layer | Rain audio | River audio | HUD tint | Farm ripples | Notes |
|---|---|---|---|---|---|---|---|
| farm spawn/bed/truck | rainy | falling | playing | playing | `(0.38, 0.52, 0.72, 0.12)` | 3 | streaks over whole farm view |
| E at farm truck `(22,9)` | rainy | — | — | — | — | — | travel accepted, clock 06:00→06:30 (+30) |
| town arrival | rainy | falling | playing | playing | same | -1 (none) | streaks over town view |
| town east-edge walk (+2 mid-walk captures) | rainy | falling | playing | playing | same | -1 | rain tracks camera, no popping |
| Seed Shop `(7,4)` E → modal, Esc close | rainy | falling | playing | playing | same | -1 | "E Seed Shop" prompt pill; panel native |
| Hana `(11,6)` E → dialogue | rainy | falling | playing | playing | same | -1 | rainy-weather dialogue line renders |
| Market `(13,7)` E → refusal | rainy | falling | playing | playing | same | -1 | red toast "The Harvest Market opens on Day 14." |
| town truck `(2,9)` E → travel home | rainy | falling | playing | playing | same | 3 restored | 07:00 on return; rain continues |
| return farm | rainy | falling | playing | playing | same | 3 | same layer alive across both travels |

## Sunny tour results (all `rain_falling=false`, quick phase)

| Phase | Weather | Rain layer | Rain audio | River audio | HUD tint | Farm ripples |
|---|---|---|---|---|---|---|
| farm spawn/bed/truck | sunny | not falling | stopped | playing | `(1.0, 0.96, 0.86, 0.03)` | 3 |
| town arrival + east edge | sunny | not falling | stopped | playing | same | -1 |
| return farm | sunny | not falling | stopped | playing | same | 3 |

## Visual findings (vision review of the actual captures)

- Rain streaks render over the farm and over the town, identical rendering in both maps; absent
  in sunny captures in both maps. Farm rain look is unchanged from the pre-HPA-860 reference.
- One persistent rain layer: `rain_falling=true` at town arrival with no restart gap, and the
  same layer still falling on the farm after travel home (state checked at every phase).
- Farm shows its three river ripple sprites (`farm_ripples=3`); town reports `-1` (no farm
  ambience node) and no ripple visuals appear in any town capture.
- HUD rainy tint `(0.38, 0.52, 0.72, 0.12)` / Sunny pill vs warm sunny tint
  `(1.0, 0.96, 0.86, 0.03)` — weather tint retained and weather-correct.
- Camera-edge walk to the town's south-east band corner with two mid-walk captures: rain tracks
  smoothly, no popping, no new occlusion bugs; player/prop/villager Y-sort correct.
- Depth, gold target, floating prompts ("E Seed Shop", "E Gen-san", "E Harvest Market"), Seed
  Shop panel, Hana dialogue (with her rainy-day line), market refusal toast, and key pills all
  render correctly in rainy captures; travel clock math visible (06:00 → 06:30 → 07:00).
- Audio (observable state only): rain ambience player plays in rainy farm and town, stops in
  sunny; river audio player plays throughout (farm with ripples; town remains the accepted
  audio-without-visuals limitation, unchanged by this branch).

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
