# HPA-263 Passive Day Clock - Agent-Operated Native Playtest Evidence

Evidence class: **agent-operated native gameplay**. A scripted agent drove the
rendered Godot window with real `input_action` events (WASD, E, Space, 1-4, I,
Esc, Enter) and UI clicks; collisions were real `move_and_slide` responses.
Observer calls were read-only (property reads, screenshots, waits, OS
`grab_focus` attempts, `quit`). No `set_property`, `restore_state`, injected
`_notification`, or `Engine.time_scale` changes during measured play. This is
not human-play evidence and not release acceptance.

## Tested build and fixture

- Repo HEAD `211949540eb357238dbe1a43e2204ce72474457b`, branch
  `agent/hpa-263-passive-day-clock-plan`, clean worktree.
- Godot `4.7.1.stable.official.a13da4feb`, Apple M1 Pro, gdunit_e2e server 1.1.0.
- Fixture: seeded schema-2 save loaded through the real Continue button:
  Day 1 06:00, stamina 20, sunny, 200G, Efficient Can unowned, intro
  acknowledged, 10 Pumpkin seeds, ten pre-tilled farm cells.

## Measured results (wall timestamps and HUD/state are independent records)

| Event | Wall offset | HUD | Note |
| --- | --- | --- | --- |
| Day start | +0.0 s | 06:00 | clock_running=true, input enabled |
| Efficient Can bought via shop UI | +3.3 s | 06:05 | 200G -> 0G, real Enter press |
| 10 plant + 10 water (20 real Space actions) | +10.4-30.8 s | 06:40->13:40 | stamina 20 -> 0 |
| **First binding: stamina = 0** | **+30.8 s** | **13:40** | action_minutes exactly 400 |
| Bag modal 3.90 s / Pause 3.91 s | +47.6-51.6 s | 14:15 | zero whole minutes, no catch-up |
| 22:00 cutoff reached through play | +290.7 s | 22:00 | continuous engaged input |
| Late hoe on farm cell | +292.1 s | 22:00 | rejected: "It is too late for that action." |
| Late movement / talk / shop / shipping | +293-303 s | 22:00 | all worked (~1.2k px walked) |
| Sleep -> Day 2 06:00, stamina 20 | +307.8 s | 06:00 | morning summary; persisted save confirms day 2, can owned, 10 pumpkins at growth 1 |

## First-binding vs post-binding split (do not conflate)

- Farm-work window: spawn -> shop purchase -> 20 farm actions ended at wall
  +30.8 s with stamina 0 at HUD 13:40. The passive clock shared this window
  with action charges; **stamina, not time, was the first binding resource**.
- Post-binding window (+54 s to +290.7 s): ~4 min of continuous exploration
  laps with stamina already 0 reached 22:00. This proves passive accrual
  continues under engaged input; it is **not** evidence that the clock binds
  during farm work, and agent input speed is not claimed as a bound on human
  speed.

## Minute arithmetic (ledger arithmetic, not a wall measurement)

- Day span 960 min; action charges 400 min (20 x 20); authoritative
  `_time_minutes` shows **560 passive minutes applied** (1320 - 360 - 400).
- At the configured 0.5 s/min those 560 min predict **280.0 s** of unblocked
  accrual; this is pure arithmetic, not a measurement.
- Independent check: sampling `events.jsonl` wall timestamps gated on
  `world_input_enabled`/`clock_window_focused`/`clock_running` (2 614 samples,
  ~0.11 s mean interval) gives an unblocked-wall **estimate of ~281 s** with
  sampling-boundary uncertainty on the order of +-2 s (14 gate transitions)
  plus unsampled sub-interval effects, consistent with the 280.0 s
  expectation. This is an estimate, not an exact figure.
- The driver's `unblocked_seconds` (278.044) is reconstructed as
  `0.5 x sawtooth drops + remainder` and under-reads on multi-minute frames;
  it is circular and is not cited as independent evidence here.

## Focus limitation and deterministic coverage

- Native OS focus transitions were **unexercisable**: this GUI session is
  fronted by `com.apple.loginwindow` (locked console); `Window.has_focus()`
  returned false for the process's entire life and no OS focus-out could be
  produced (`osascript` activate no-ops, `screencapture` fails). The
  `_clock_window_focused` branch was never exercised natively.
- Deterministic GUT does cover the dispatch path:
  `tests/integration/test_gameplay_shell.gd:2817-2825` sends real
  `NOTIFICATION_APPLICATION_FOCUS_OUT`/`FOCUS_IN` notifications and asserts
  the flag flips, `_process` stops accruing, and resume adds no catch-up.
- Residual gap: one unlocked-desktop check that a real defocus freezes the
  HUD clock and refocus adds no jump.
- Follow-up (PR #22 review): the run above also exposed that
  `_clock_window_focused` initialized `true` regardless of real window focus,
  so this never-focused session still ticked. `WorldShell._ready()` now seeds
  the flag from `get_window().has_focus()`; transition notifications still
  own later updates.

## Rate status

`REAL_SECONDS_PER_GAME_MINUTE = 0.5` stays **PROVISIONAL**. Observed: a
full-effort sunny day is not stranding (work + routes fit well before 22:00)
and the cutoff is reachable under sustained input. Not established: human
subjective pace (humans act slower than scripted input, so the day may feel
shorter), and the native focus-pause branch above. Both remain open items for
a human/unlocked-desktop pass before the rate is final.

## Reproduction

```
# Native launch used for this evidence (isolated save/settings):
PHOENIX_SAVE_PATH=<scratch>/save.json PHOENIX_SETTINGS_PATH=<scratch>/settings.cfg \
  godot --path <repo> --scene res://addons/gdunit_e2e/runtime/bootstrap.tscn -- \
  --gdunit-e2e --gdunit-e2e-target-scene=res://scenes/app/app.tscn \
  --gdunit-e2e-port=0 --gdunit-e2e-port-file=<scratch>/port.txt \
  --gdunit-e2e-token=<random> --gdunit-e2e-log-verbosity=warning

# Automated verification of the committed tree:
./tools/verify-clean.sh
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit
```

Raw artifacts (events.jsonl, screenshots, seeded save, driver scripts) are untracked scratch under `.superpowers/sdd/2026-10-21-phoenix-passive-day-clock-implementation/native-play/`.
