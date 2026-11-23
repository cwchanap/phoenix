# HPA-863 native visual check — farm v2 passable decor and polish

Date: 2026-11-23
Branch: `plan/hpa-863-farm-map-v2-world-art` (Task 4, on top of `be4dea3`)
Operator: agent-operated native run (agent vision review of real rendered captures), not a human
playtest.

Runtime: Godot 4.7.1.stable.official.a13da4feb (`Godot_v4.7.1-stable_linux.arm64`) on the 1920x1080
Xvfb `:99` display, gl_compatibility / llvmpipe software rendering. Every capture is the real
1920x1080 viewport saved as PNG by `tests/native_tour/hpa_863_tour.gd`; the tour asserts each
capture's dimensions before writing it.

## Provenance

- The tour boots the real app through a seeded Day-1 save (all 30 field cells tilled, with a
  3-kind x stages 2-4 crop grid) and a windowed/English settings fixture with tutorial cards
  disabled, so the HUD stays visible without the transient tip card covering the world.
- The farm poses teleport the live player; walking is transport only, not a reachability proof.
  Interaction/reachability stays pinned by the headless, GUT and godot-e2e suites.
- One real E at the reachable farm-truck north-west contact (`32.78,12.72` facing RIGHT) drives to
  town through the real travel overlay and map swap; the town captures are the arrived map.
- Rerun command (from the repo root):

  ```bash
  HOME=$(mktemp -d) PATH=/tmp/opencode/phoenix-bin:$PATH \
    PHOENIX_SAVE_PATH=$HOME/save.json PHOENIX_SETTINGS_PATH=$HOME/settings.cfg \
    TOUR_OUT=/tmp/hpa863-out DISPLAY=:99 \
    godot --path . --script res://tests/native_tour/hpa_863_tour.gd
  ```

  Result: exit 0, `TOUR|DONE clean tour=hpa-863`, 12 captures.

## Captures

Committed at `docs/superpowers/validation/hpa-863-tour-captures/`.

| Capture | Pose | Check |
| --- | --- | --- |
| `hpa863-01-farm-front-door-contact.png` | door slice, facing UP | E prompt over the drawn doorway; house fade (HPA-743) active |
| `hpa863-02-farm-yard.png` | yard centre, facing UP | house art base and door align with the 3x3 footprint/`(23,10)` cell; flower beds flank the door; no tile rims |
| `hpa863-03-farm-storehouse-yard.png` | lots/kura, facing UP | five lot rope markers, kura grounding, yard/lot/path joins |
| `hpa863-04-farm-field.png` | patch, facing DOWN | 30 tilled soil decals, crop kinds and stages 2-4 readable; Space preview |
| `hpa863-05-farm-field-east-gate.png` | field east gate, facing LEFT | `(21,20..21)` gate open; bin at its full-cell anchor (player-occluder fade visible) |
| `hpa863-06-farm-driveway-roadside.png` | driveway, facing RIGHT | truck, mailbox, sign, vending machine, poles, jizo, orchard, road/paddy join |
| `hpa863-07-farm-pier.png` | pier, facing DOWN | three plank sections over the pier cells; bench and rocks; ripples on contract water |
| `hpa863-08-farm-camera-southwest.png` | SW camera extreme | continuous water/reeds/forest, no grey void |
| `hpa863-09-farm-camera-northeast.png` | NE camera extreme | continuous forest/road/paddy, no grey void |
| `hpa863-10-town-centre.png` | town centre | continuous paving, props, villagers, truck |
| `hpa863-11-town-camera-northeast.png` | town NE edge | paved/grass edge, no tile rim or void |
| `hpa863-12-town-camera-southwest.png` | town SW edge | paved/grass edge, no tile rim or void |

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
