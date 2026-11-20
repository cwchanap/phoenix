# HPA-743 native visual verification — world readability tour and Linear B2 comparison

Date: 2026-11-20
Build: committed `HEAD` = `95f6c28` (branch `jack65786656/hpa-743-make-the-world-easy-to-use-and-read`, PR #46)
Operator: agent-operated native run (agent vision review of real rendered captures), not a human playtest.
Runtime: Godot 4.7.1.stable.official.a13da4feb (`Godot_v4.7.1-stable_linux.arm64`), Oracle Linux arm64, real windowed app on Xvfb `:101` (`-screen 0 1920x1080x24`, gl_compatibility / llvmpipe software rendering); every capture is the real 1920×1080 viewport saved as PNG.

## Execution provenance (recorded per PR review request)

- The tour re-ran on this date via an agent shell command on this VM — **not an MCP transport**. The
  reviewer asked for truthful provenance in place of an MCP-connectedness claim, so none is claimed
  for the run itself.
- The **Linear B2 reference image was retrieved through MCP**: Linear `get_attachment` on HPA-743
  Resources attachment `0a94ed57-aeae-47b4-b2a1-ddb9d1fd40a7` ("Mockup B2: farm edge now and with
  backdrop") returned a signed download URL; the 1920×1080 JPEG was fetched and compared directly
  by agent vision against the committed captures below.
- Environment isolation: `HOME=/tmp/hpa743-rerun/home`, `PHOENIX_SAVE_PATH` and
  `PHOENIX_SETTINGS_PATH` under `/tmp/hpa743-rerun/iso/` (the tour writes its own seeded Day-1 sunny
  save and a windowed+English settings fixture), `TOUR_OUT=/tmp/hpa743-rerun/out`.
- Rerun command (from repo root):

  ```bash
  Xvfb :101 -screen 0 1920x1080x24 &
  HOME=/tmp/hpa743-rerun/home \
    PHOENIX_SAVE_PATH=/tmp/hpa743-rerun/iso/save.json \
    PHOENIX_SETTINGS_PATH=/tmp/hpa743-rerun/iso/settings.cfg \
    TOUR_OUT=/tmp/hpa743-rerun/out DISPLAY=:101 \
    godot-4.7.1 --path . --script res://tests/native_tour/hpa_743_tour.gd
  ```

- Result: exit 0, `DONE clean tour=hpa-743`. 22 captures, each asserting its own 1920×1080
  dimensions in-tour; 39 `TOUR|ok` assertions, 22 `TOUR|shot` lines. A prior identical run (same
  file set) was executed during Task 5 on 2026-11-18 via an Orca-hosted shell route on Xvfb `:99`;
  this re-run is the provenance-of-record for the committed captures. The pre-existing
  leaked-objects warning at engine exit is unchanged from the main-branch baseline.

## Captures (committed alongside this note)

All 22 PNGs are committed at `docs/superpowers/validation/hpa-743-tour-captures/` — PR-accessible
evidence, no external hosting required.

| Capture | Asserted in-tour / visually verified |
|---|---|
| `hpa743-10-farm-bed-contact` | `[E] Go to bed` prompt + visible gold diamond at the house-door contact |
| `hpa743-11-farm-bin-contact` | `[E] Shipping` prompt + gold diamond at the bin contact |
| `hpa743-12-house-faded` / `hpa743-13-house-restored` | House sprite at 0.45 with player visible through it; restored to 1.0 south of the root anchor |
| `hpa743-14-fence-faded` / `hpa743-15-fence-restored` | FarmFence_2 fade/restore pair |
| `hpa743-16-bin-faded` / `hpa743-17-bin-restored` | Shipping bin fades on its −x contact, opaque on +x (cell-centre anchor) |
| `hpa743-18-truck-faded` / `hpa743-19-truck-east-edge-restored` | Farm truck fades on north-face contact; restored south of tip anchor — **east-edge B2 view** |
| `hpa743-20-truck-east-edge-prompt` | `[E] Drive to town` pill at the east-edge truck contact, truck correctly faded |
| `hpa743-21-truck-wrong-facing-refused` / `hpa743-22-truck-wrong-facing-toast` | Isolated wrong-facing refusal: no prompt + red `Nothing to interact with.` toast |
| `hpa743-23-farm-southwest-river` | South-west river corner: water, banks and backdrop grass fill to the screen edge, no void |
| `hpa743-30-town-shop-contact` / `hpa743-31-town-shop-faded` / `hpa743-32-town-shop-restored` | `[E] Seed Shop` prompt; shop fade/restore pair |
| `hpa743-33-town-station-faded` / `hpa743-34-town-station-restored` | Station fade/restore pair |
| `hpa743-35-town-sato-contact` | `[E] Sato-san` villager prompt + gold diamond |
| `hpa743-36-town-truck-contact` | `[E] Drive home` prompt at the town truck |
| `hpa743-40-return-farm-restored` | Map swap back to farm restores all occluders to alpha 1.0 |

## Linear B2 comparison (east edge)

Reference: HPA-743 Resources attachment `0a94ed57`, "Mockup B2: farm edge now and with backdrop"
(board `b2`, "T5 · The farm paints a backdrop past its edge, like the town"), committed alongside
the captures as `hpa-743-linear-b2-mockup.jpg`. Its "Now" side shows
the flat grey void past the farm truck; its "After" side fills that void with the farm's own grass
tile while leaving collision and camera bounds unchanged.

Direct comparison against `hpa743-19-truck-east-edge-restored.png` and
`hpa743-20-truck-east-edge-prompt.png`:

- **Grey void — eliminated.** Every pixel past the playable map edge is painted backdrop grass in
  the real captures, matching B2's "After" intent.
- **East road — continued.** The authored dirt road row visibly continues east past the truck to
  the screen edge. B2's mock shows grass only there; continuing the road is the spec's required
  addition beyond the mock (spec §"Outcome and source of truth": "the implementation must
  additionally continue the east dirt road using current terrain art").
- **Prompt/diamond — consistent.** `[E] Drive to town` renders at the near-contact pose with the
  gold diamond, as B2's mockup depicts.

Verdict: the east-edge frame satisfies the B2 comparison — no regression vs the mock, plus the
required road continuation.

## Limitations (unchanged from Task 5)

- Tour poses are teleported to integration-table contact/fade coordinates; walk-in reachability and
  collider standoff are pinned by the GUT integration tables, not this tour. Every E press is real
  input.
- Software rendering (llvmpipe) at 6–10 fps; the tour freezes the game clock via the sanctioned
  `clock_running` fixture flag for determinism.
- Evidence-only one-off; the tour is not run in CI.
