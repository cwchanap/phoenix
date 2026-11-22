# HPA-1137 prologue: verification record

Agent-run evidence for the skippable six-scene prologue. The MCP-driven
gate below is verified on `3982ac1`; the acceptance checkboxes can close
once CI is green on the pushed head. The local e2e lane was not clean in
a single full run on the shared host, so GitHub CI remains the authority
for that lane.

## Environment

- Linux arm64 shared host, load average 7 to 19 on 4 cores, 23 GB RAM with swap in use.
- Godot 4.7.1 stable non-mono (`Godot_v4.7.1-stable_linux.arm64`), the version CI pins.
  The default `godot` on the host is 4.7.2 mono and fails the e2e lane for unrelated reasons.
- GUT 9.7.1, GdUnit4 and godot-e2e from `./tools/bootstrap-gdunit.sh`; e2e under
  `xvfb-run -s "-screen 0 1920x1080x24"` with software rendering.
- Isolated `HOME`, `PHOENIX_SAVE_PATH` and `PHOENIX_SETTINGS_PATH`.

## Lane results

Local lanes ran on `4d173e6`, except godot-e2e, which was last run locally on earlier commits (see below) because the host was too loaded to repeat it; GitHub CI covers the pushed head `f7a97e0`, including the prologue texture and locale changes.

| Lane | Result |
|---|---|
| `godot --headless --editor --quit` (import) | pass |
| GUT unit and integration | 629 of 629 pass, 42,378 asserts |
| `project_smoke`, `world_math_smoke`, `world_shell_smoke` | pass |
| `tools/check_audio_sources.py` | pass |
| `tools/verify-clean.sh` (archives committed HEAD, fetches GUT) | pass, 629 of 629 |
| GdUnit4 `tests/gdunit` | 16 of 16 pass |
| godot-e2e `tests/e2e` | **not clean locally**, see below |

### godot-e2e on this host

The new test `test_new_game_enter_advances_one_page_then_escape_skips_to_day_one`
passed in every run except one at load 23, where its 0.6 s walking wait timed out. The
walk was replaced by a wait on the shell's input gate (`ca1238e`), and the test then
passed at load 23. `market_confirm_test`, `ui_navigation_test` and
`world_readability_test` passed in the full-lane runs; the untouched
`test_unfinished_save_enter_resumes_seeded_day` failed once at load 23.

`gameplay_day_one_test` failed at least one test in six of six HEAD runs, and a
different test each time. Every failure was a `wait_seconds` command that timed out:
the client allows the requested wait plus 1.0 s of real time (failures logged 1.3, 1.5
and 1.6 s for waits of 0.3, 0.5 and 0.6 s). Each of the seven tests passed in at least
one HEAD run. The pre-change baseline (`f3ede08`) passed 7 of 7 in three runs at the
same or higher load.

The final review found the mechanism, not a code cause. The harness's `wait_seconds`
adds up game-side frame time. When a frame takes longer than about 133 ms, Godot's cap
of 8 physics steps per frame also shortens the frame time it reports, so game time runs
slower than real time (measured ratio 0.66 on HEAD at load 16, 0.39 a minute later), and
a wait of 0.3 s or more can exceed its 1 s margin. Only tests with such waits failed;
`test_day_one_town_trip_farming_loop_and_sleep` and `test_shop_purchase_updates_money`
use 0.1 s waits and never failed. The new e2e test waits 0.6 s while walking, so it can
flake the same way on a loaded host.

An 8 s Day 1 frame probe found the same cost on both builds (5 to 12 fps depending on
host load, the same draw calls, 1,997 nodes against 1,968), and the overlay does no
per-frame work after the skip. The baseline's three clean runs are most plausibly load
luck, and a clean snapshot copy of HEAD flaked the same way. **GitHub CI on the pushed
branch is the authority for this lane.**

## MCP-driven acceptance: verified

A later session ran the gate through the Godot MCP runtime bridge
(`addons/godot_mcp_runtime`, v0.1.5, gitignored) on `3982ac1`. Environment:
Godot 4.7.2 stable mono, llvmpipe GL under `Xvfb :99` at 1920x1080x24, fullscreen
mode so the client viewport is natively 1920x1080. Drive was `invoke_node_action
press` on real `BaseButton` nodes (`TitleScreen/Menu/NewGame`, the overlay's
`Skip` and `Continue`); `capture_screenshot` captured the rendered
viewport. The bridge's project.godot autoload line is a local-only change used
for this run and is not part of the branch.

Per locale (en, zh_TW, ja): New Game press → prologue page 1 → `Continue`
presses to the representative pages → `Skip` press → Day 1. Every captured frame
is 1920x1080; `mcp-frames-<locale>.jpg` sheets in `hpa-1137-prologue/` are these
frames downscaled to 660 px wide, and `mcp-day1.jpg` holds the three post-skip
Day 1 frames.

Coverage and results:

- en: pages 1, 2, 15, 32, 44, 55, 58, Day 1. Page 2 confirms one `Continue`
  press advances exactly one page (the Enter-equivalent path); page 2 frame is
  `mcp-en-page02.jpg`.
- zh_TW: pages 1, 16, 32, 44, 55, 58, Day 1. Page 16 is the scene-2 Hana frame
  (one extra press landed one line past 15; same scene and composition).
- ja: pages 1, 15, 32, 44, 55, 58, Day 1.

Post-skip Day 1 in all three locales shows the localized day tag (Day 1 /
第 1 天 / 1日目), 150G, Turnip seed ×3, the localized tutorial card and no pause
panel. The HUD clock read 06:05 (en), 06:16 (zh_TW) and 06:10 (ja) — expected,
not a defect. The clock starts at `DAY_START_MINUTES` (06:00) and is frozen
while the prologue holds the input gate (`WorldShell._advance_passive_clock`
early-returns on `_world_input_enabled` false); once Day 1 begins it advances
at `REAL_SECONDS_PER_GAME_MINUTE` = 0.15 s per game-minute, so a second of real
latency between the Skip press and the capture is several game minutes. The
e2e test asserts day tag/money/seeds, not a frozen clock.

The MCP frames match the shell-captured sheets and the mockup on every
composition element: letterbox bars and localized "Prologue" label and skip
hint, scene tag with six progress dots, speaker portrait and dimmed listener,
scene-3 kei truck, scenes 4 and 5 night grade, narration scrim, scene-5 paper
note card, scene-6 Begin Day 1 button, and localized name/role pills. No
clipped or overlapping text in any frame. The documented deviations (lighter
scene-4 grade, left-dimmed scene-3 listener, pink inner-voice band, inline
note signature, zh_TW 序章 label) appear identically in the MCP frames.

One environment note, not a defect: the first windowed capture came out
1879x1057 because the game's fit logic shrank the window to the X server's
usable rect; fullscreen on `:99` yields a native 1920x1080 client and all
frames above are native 1920x1080.

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
- Narration pages darken their lower part with a gradient scrim (added after the first capture; see "Follow-ups after review").
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
6. **Top bar label.** zh_TW shows "序章" where the mockup shows "序章 PROLOGUE".

Items 2, 3 and 5, and the inline signature in item 4, are the documented deviations in the plan and spec notes.

## Editorial review

The English and Japanese copy for all 58 lines and six tags is in
`2026-11-21-hpa-1137-prologue-translations.md`. The user reviews it; human approval is
not an acceptance gate.

## Follow-ups after review

Done on the same branch after the first push:

- **Narration scrim.** Narration pages now draw a bottom gradient (92% ink at the edge, clear
  560 px up), as the mockup does for scene 1. `hpa-1137-prologue/narration-scrim.jpg` shows
  pages 1, 38 and 56 in en, zh_TW and ja, captured the same way as the frames above. The text
  reads clearly over the bright platform painting and the night farm. Tests pin that the scrim
  shows on exactly the narration pages, ignores clicks and fills the bottom 560 px.
- **Gen-san's Japanese** now follows the voice the game already gives him (plain 〜ん
  negatives and 〜とる, as in 読まん and 見とる): 〜てる became 〜とる in three lines, and
  やれねえぞ and 手をつけてない became やれんぞ and 手をつけとらん. The English keys and zh_TW are unchanged.
- **Space** also advances pages because it is bound to `ui_accept`, like the other panels.
  The behaviour is kept and README and CLAUDE.md now say so.
- **Day 1 diary line.** `DIARY_LINES[0]` is no longer shown, but the 14-entry table is pinned
  by tests and by the morning summary's clamp, so it stays; CLAUDE.md now says it is unused.
- **Lazy prologue texture loading and locale re-render.** `OnboardingOverlay._ready()` no longer
  loads the scene-1 painting before `render()`, `render()` releases background/portrait textures
  once `intro_acknowledged` is true, and locale changes re-render the current page in place so
  quoted dialogue bodies update immediately.
