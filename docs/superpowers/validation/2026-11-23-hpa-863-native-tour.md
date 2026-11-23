# HPA-863 native visual check — farm v2 passable decor and polish

Date: 2026-11-23
Branch: `plan/hpa-863-farm-map-v2-world-art` (final review fix wave, after `1fba58f`)
Operator: agent-operated native run (agent vision review of real rendered captures), not a human
playtest.

Runtime: Godot 4.7.1.stable.official.a13da4feb (`Godot_v4.7.1-stable_linux.arm64`) on a
1920x1080 Xvfb display, gl_compatibility / llvmpipe software rendering. Every capture is the real
1920x1080 viewport saved as PNG by `tests/native_tour/hpa_863_tour.gd`; the tour asserts each
capture's dimensions before writing it.

## Provenance

- The tour boots the real app through a seeded Day-1 save (all 30 field cells tilled, with a
  3-kind x stages 2-4 crop grid; the three first-column planted cells are `watered_today` so the
  field carries both wet frame 1 and dry frame 0 soil) and a windowed/English settings fixture
  with tutorial cards disabled.
- The farm poses teleport the live player; walking is transport only, not a reachability proof.
  Interaction/reachability stays pinned by the headless, GUT and godot-e2e suites, and the
  separate MCP Run D log records real-input fence-gate crossings.
- This set supersedes the Task 4 set: it adds the wet/dry field view and the two dressed bamboo
  groves. The earlier shadow/pier corrections remain (building contact shadows at their ground
  root; pier planks in the below-actor `PierDeck`).
- One real E at the reachable farm-truck west-face contact (`32.78,12.72` facing RIGHT) drives to
  town through the real travel overlay and map swap; the town captures are the arrived map.
- The house root is the derived footprint anchor `(1248,560)`; its art base/doorway aligns with
  the `(23,10)` bed/door cell.
- Rerun command (from the repo root):

  ```bash
  HOME=$(mktemp -d) PATH=/tmp/opencode/phoenix-bin:$PATH \
    PHOENIX_SAVE_PATH=$HOME/save.json PHOENIX_SETTINGS_PATH=$HOME/settings.cfg \
    TOUR_OUT=/tmp/hpa863-out DISPLAY=:99 \
    godot --path . --script res://tests/native_tour/hpa_863_tour.gd
  ```

  Result: exit 0, `TOUR|DONE clean tour=hpa-863`, 16 captures.

## Captures

Committed at `docs/superpowers/validation/hpa-863-tour-captures/`.

| Capture | Pose | Check |
| --- | --- | --- |
| `hpa863-01-farm-front-door-contact.png` | door slice, facing UP | E prompt over the drawn doorway; house fade (HPA-743) active |
| `hpa863-02-farm-yard.png` | yard centre, facing UP | house art base and door align with the 3x3 footprint/`(23,10)` cell; flower beds flank the door; contact shadow sits under the base, not displaced; no tile rims |
| `hpa863-03-farm-storehouse-yard.png` | lots/kura, facing UP | five lot rope markers, kura contact shadow under the base, yard/lot/path joins |
| `hpa863-04-farm-field.png` | patch, facing DOWN | 30 tilled soil decals, crop kinds and stages 2-4 readable; Space preview |
| `hpa863-04b-farm-field-wet-dry.png` | closer field, facing DOWN | wet frame 1 (watered first column) beside dry frame 0 cells in one view |
| `hpa863-05-farm-field-east-gate.png` | field east gate, facing LEFT | `(21,20..21)` gate open; bin at its full-cell anchor (player-occluder fade visible) |
| `hpa863-06-farm-driveway-roadside.png` | driveway, facing RIGHT | truck, mailbox, sign, vending machine, poles, jizo, orchard, road/paddy join |
| `hpa863-07-farm-pier.png` | pier, facing DOWN | three plank sections over the pier cells; bench and rocks; ripples on contract water |
| `hpa863-08-farm-pier-standing.png` | review stance `(24.3125,33.8125)`, facing DOWN | player root (464,930) stands on a plank rooted at Y=944 and the whole player draws above the deck; deck stays below the actor layer |
| `hpa863-09-farm-camera-southwest.png` | SW camera extreme | continuous water/reeds/forest, no grey void |
| `hpa863-10-farm-camera-northeast.png` | NE camera extreme | continuous forest/road/paddy, no grey void |
| `hpa863-11-town-centre.png` | town centre | continuous paving, props, villagers, truck |
| `hpa863-12-town-camera-northeast.png` | town NE edge | paved/grass edge, no tile rim or void |
| `hpa863-13-town-camera-southwest.png` | town SW edge | paved/grass edge, no tile rim or void |
| `hpa863-15-farm-bamboo-west.png` | west grove approach `(4.5,7.5)`, facing UP | three bamboo clumps dress the approved `(3,4,3,3)` blocking footprint; no invisible blockage |
| `hpa863-16-farm-bamboo-east.png` | east grove approach `(10.5,7.5)`, facing UP | three bamboo clumps dress the approved `(9,4,3,3)` blocking footprint; no invisible blockage |

## Not performed

- **No approved-image comparison.** The Linear HPA-863 attachment images could not be fetched:
  `linear.get_issue` failed with
  `mcp-remote: Authentication is still pending in another instance on port 22227. Complete that
  sign-in and retry, or close the other instance to start a new sign-in.` No credentials or tokens
  were searched for. The captures were reviewed against the written checkpoint only
  (rims, islands, dotted seams, blocked gates, Y-sort, bin anchor, camera void), not against
  `farm-map-v2-plan.png`, the blockouts or `world-mockup-vs-game.jpg`.
- No human review; subjective pacing is out of scope.
- No terrain/tileset re-stamp: Task 4 changed no terrain art or source IDs.
