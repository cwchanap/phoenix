# HPA-1137 prologue: verification record

Agent-run evidence for the skippable six-scene prologue. The acceptance
checkboxes in the plan and spec stay open: the MCP-driven gate below is
unverified, and the local e2e lane was not clean in a single full run.

## Environment

- Linux arm64 shared host, load average 7 to 19 on 4 cores, 23 GB RAM with swap in use.
- Godot 4.7.1 stable non-mono (`Godot_v4.7.1-stable_linux.arm64`), the version CI pins.
  The default `godot` on the host is 4.7.2 mono and fails the e2e lane for unrelated reasons.
- GUT 9.7.1, GdUnit4 and godot-e2e from `./tools/bootstrap-gdunit.sh`; e2e under
  `xvfb-run -s "-screen 0 1920x1080x24"` with software rendering.
- Isolated `HOME`, `PHOENIX_SAVE_PATH` and `PHOENIX_SETTINGS_PATH`.

## Lane results

Tested commit `9af1632`, the head after the last test change.

| Lane | Result |
|---|---|
| `godot --headless --editor --quit` (import) | pass |
| GUT unit and integration | 629 of 629 pass, 42,278 asserts |
| `project_smoke`, `world_math_smoke`, `world_shell_smoke` | pass |
| `tools/check_audio_sources.py` | pass |
| `tools/verify-clean.sh` (archives committed HEAD, fetches GUT) | pass, 629 of 629 |
| GdUnit4 `tests/gdunit` | 16 of 16 pass |
| godot-e2e `tests/e2e` | **not clean locally**, see below |

### godot-e2e on this host

The new test `test_new_game_enter_advances_one_page_then_escape_skips_to_day_one`
passed in every run. `app_launch_test`, `market_confirm_test`, `ui_navigation_test`
and `world_readability_test` passed in the full-lane runs.

`gameplay_day_one_test` failed at least one test in six of six HEAD runs, and a
different test each time. Every failure was a `wait_seconds` command that timed out
after 1.5 s, which means the game process stalled for more than a second under host
load. Each of the seven tests passed in at least one HEAD run. The pre-change
baseline (`f3ede08`) passed 7 of 7 in three runs at the same or higher load.

I could not explain the difference. An 8 s frame probe on Day 1 showed no systematic
cost: 9 to 12 fps on both builds, the same draw calls, 1,997 nodes against 1,968.
HEAD has no per-frame work in the overlay, and the intro background and panel are
hidden after the skip. A clean snapshot copy of HEAD flaked the same way, so the
worktree location is not the cause. **GitHub CI on the pushed branch is the authority
for this lane**, and the next step if it fails there is to look for what the prologue
changes in `gameplay_day_one_test` timing.

## MCP-driven acceptance: unverified

The repository has no Godot MCP transport and this session had no MCP-connected
Godot execution environment. Every run above is an agent shell run, not an MCP run,
so the plan's MCP criterion is **unverified**. Nothing here should be read as MCP
evidence.

## Visual check at 1920x1080

Frames come from `scenes/app/app.tscn`, driven by real key and mouse events (title
New Game click, then Enter presses to the key page), with a scratch script that is not
committed. Each capture is a native 1920x1080 viewport image under `xvfb`, in en,
zh_TW and ja, on pages 1, 15, 32, 44, 55 and 58. The sheets in
`hpa-1137-prologue/` are these frames downscaled to 660 px wide.

The reference is the Linear `prologue-overview.jpg` sheet. I viewed both sheets in an
isolated headless Chromium. The full-size frames are not committed.

What matches the mockup:

- Letterbox bars, "Prologue" label and Esc skip hint in the top bar.
- Place and time tag with six progress dots, with the active scene stretched.
- Hana's and Gen-san's portraits on the left in their scenes; no portrait for Kenji.
- The kei truck on the road in scene 3.
- White dock with name tag, role pill and quoted text; Enter Continue hint; the
  Begin Day 1 button on the last page.
- The paper note card in scene 5.
- No clipped, overlapping or illegible text in any of the 18 frames. The 58 pages in
  three locales are also checked by rect in `test_vn_surfaces.gd`.

Differences from the mockup:

1. **Backgrounds.** The frames use the finished HPA-1138 paintings already on `main`
   (scenes 1 to 3) and the supplied `interior-night.png`, so they are richer than the
   mockup's flat vector backdrops. This is expected, not a defect.
2. **Scene 4 night grade is lighter.** The mockup applies brightness 0.55,
   saturation 0.65, a blue gradient overlay and a warm glow. The overlay applies one
   modulate (`NIGHT_GRADE`), so scene 4 reads less dark and less blue. Scene 5's
   brightness is close.
3. **Scene 3 listener.** Gen-san is dimmed to 45% on the left. The mockup shows him
   mirrored on the right, darkened and opaque.
4. **Scene 5 layout.** The note shows the whole translated sentence reflowed in the
   card with the signature inline. The mockup breaks the lines and right-aligns the
   signature. Kenji's reply uses the dock; the mockup shows a bare line under the card.
   The caption about the note on the low table shows on its own narration page, not over the card.
5. **Inner-voice dock band** stays pink-to-orange; the mockup's is violet.
6. **Narration has no bottom scrim.** The mockup darkens the lower part of scene 1.
   The text stays legible on the current art, with lower contrast than the mockup.
7. **Top bar label.** zh_TW shows "序章" where the mockup shows "序章 PROLOGUE".

Items 2, 3 and 5, and the inline signature in item 4, are the documented deviations in the plan and spec notes.

## Editorial review

The English and Japanese copy for all 58 lines and six tags is in
`2026-11-21-hpa-1137-prologue-translations.md`. The user reviews it; human approval is
not an acceptance gate.
