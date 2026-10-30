# HPA-539 cozy farmer walk-sheet handoff

The user requested a full character redesign after reviewing the first proof-preserving take.
This supersedes the ticket's original pixel-identical-idle requirement: **column 0 now contains new idle art**.
The committed `proof-player.png` remains unchanged, and the live scene still uses it.
This PR remains art-only; [HPA-546](https://linear.app/cwchanap/issue/HPA-546/game-feel-play-the-player-walk-cycle-while-moving) owns runtime playback.

## Character and frame contract

A cozy chibi farmer: straw hat with teal band, chestnut hair, tan skin, teal work shirt, ochre neckerchief, indigo overalls, and brown boots.
The new silhouette has a readable face, articulated limbs, arm swing, and distinct passing poses.

`assets/sprites/player-walk.png` remains **128×192 RGBA**, four columns by four rows of **32×48** frames.
Rows follow `WorldMath.Facing`: **UP, RIGHT, DOWN, LEFT**.

| Column | Meaning | Future Sprite2D index |
| --- | --- | --- |
| 0 | Redesigned idle | `facing * 4` |
| 1 | Contact stride A | `facing * 4 + 1` |
| 2 | Passing pose | `facing * 4 + 2` |
| 3 | Contact stride B | `facing * 4 + 3` |

Frame rectangle: `Rect2i(column*32, row*48, 32, 48)`.
Future consumer settings: `hframes=4`, `vframes=4`, `offset=(0,-24)`.
Maximum visible height is 36 pixels; the lowest planted boot ends at `y=43` in every frame, leaving rows 44–47 clear.
The bottom-center anchor stays `(16,48)`, including the proof art's four-pixel gap.
No baked shadow. Binary alpha and one shared palette of at most 32 opaque colors; nearest filtering and integer scale.

Recommended walk loop: **1 → 2 → 3 → 2**, **8 fps / 125 ms per pose**.
Column 0 is idle only. Final pacing and stop/modal reset behavior remain HPA-546 work.

## Visual evidence

![Native and 2x comparisons, plus farm composites](contact-sheet.png)

[Animated walk preview](walk-preview.gif) shows all four directions at nearest 4×.
GIF delays are 120/130/120/130 ms: a 500 ms cycle, averaging 8 displayed poses/second.
Checkerboard, baseline guides, labels, and backdrop are evidence-only.
Farm panels composite old/new idle frames over the same committed production capture at native size; they are **not live runtime captures** of the new character.
Evidence is behind `.gdignore`.

## Generation and cleanup

- Tool: built-in ChatGPT `image_gen`, 2026-10-29 local date; transparent-background generation followed by one pose-correction edit. The tool did not expose a model identifier. No CLI/API fallback or external character art.
- The first new-character generation supplies columns 0–2; the edit supplies column 3 in all four rows.
- Source outputs are 1024×1536. Extract sixteen connected character silhouettes at alpha `>=128`, avoiding adjacent-row overflow; discard other source pixels. Alpha becomes strictly 0/255.
- Apply one shared nearest-neighbor scale, `36 / maximum_source_sprite_height`, across all silhouettes. Center each in its 32×48 frame and align its lowest boot to native row 43. No independent per-frame stretching or limb tracing.
- Quantize the entire sheet to one 32-color palette without dithering; set transparent RGB bytes to zero.
- Generated-source originals and local normalization tools are not committed.
- The existing Godot import sidecar retains its resource UID and lossless/no-mipmap/alpha-border settings. The project already uses nearest filtering.

### Generation prompt (verbatim)

```text
Use case: stylized-concept
Asset type: production pixel-art CHARACTER SPRITE SHEET for Phoenix, a cozy isometric farming game with richly detailed warm pixel-art cottages and greenery.
Primary request: Create a genuinely charming, expressive, beautifully designed new player farmer and a lively walk cycle. A finished small animated game character with personality, clearly articulated arms and legs, a readable face, and strong animation posing. This replaces an unattractive block placeholder; DO NOT imitate or preserve the old rectangular proof person.
Character design: one consistent young-adult androgynous farmer, warm tan skin, tousled chestnut hair, small straw farm hat with a teal band, teal rolled-sleeve work shirt, warm ochre neckerchief, dark indigo overalls with two brass buttons and a small cream chest patch, chunky brown work boots. Pleasant determined expression, dark dot eyes, small nose, warm cheek accent. Compact chibi proportions: large expressive head, short sturdy body, hands and boots easy to read. Original character, no franchise.
Art direction: premium cozy indie-game pixel art, warm harmonious earthy palette, restrained rich shading using approximately 24-32 colors, selective dark-brown outlines, clean clusters, crisp pixel steps. Deliberate low-resolution sprite detail; NOT a high-resolution painting shrunk into a tiny icon. No blur, no glow, no antialiasing, no gradients or soft shadows. Three-quarter slightly elevated camera matching a 2:1 isometric farm, seeing top of hat and shoulders. Cute and lively but not a toddler.
Composition: exact 4 COLUMNS x 4 ROWS, sixteen equally spaced full-body sprites, 1024x1536 transparent canvas. Each grid cell is 256x384, corresponding to one 32x48 game frame enlarged 8x. Draw with large crisp pixel blocks aligned to this scale. Each complete character fits inside a cell; characters never touch or overlap cells. Use the entire grid with no exterior title area.
Directions by row TOP TO BOTTOM: row 1 UP, walking away, BACK of hat/hair/overalls visible, NO FACE; row 2 RIGHT, facing screen-right profile / slight three-quarter; row 3 DOWN, facing viewer, full friendly face visible; row 4 LEFT, facing screen-left profile / slight three-quarter. All four views clearly belong to the SAME character, same clothes, same hat size.
Pose columns LEFT TO RIGHT in EVERY row: column 0 relaxed balanced idle; column 1 strong first contact stride, left leg forward and right arm forward; column 2 passing pose, feet crossing under torso and body raised subtly; column 3 opposite contact stride, right leg forward and left arm forward. Make walking visibly different from idle: knees bend, boots swing, arms counter-swing, shoulders tilt a little. Opposite stride poses must truly alternate the limbs, not duplicate the same pose. Small hat/scarf follow-through, no items or tools.
Anchoring: same character scale in all sixteen frames, width at most 26 native pixels, standing height about 36 native pixels. Every planted boot reaches the SAME y=43 baseline inside the 48-pixel-tall cell (enlarged lower boot edge at y=351). Keep four native transparent rows below feet and at least six above hat. Ground anchor centered horizontally at native x=16. Head may bob upward 1 native pixel only in passing pose; preserve body and hat proportions. Do not bake shadows into sprites.
Constraints: actual transparent background with clean alpha; sixteen sprites only; no panels, no grid lines, no labels, no text, no watermark, no ground, no landscape, no detached decorations. Polished sprite art ready for exact nearest-neighbor reduction into 32x48 game frames.
```

### Pose-correction prompt (verbatim)

```text
Use case: identity-preserve
Edit target: the supplied Phoenix farmer sprite sheet.
Primary request: Fix ONLY the FOUR SPRITES IN THE LAST / RIGHTMOST COLUMN. They currently repeat the first stride instead of the opposite stride. Make column 3 the clearly OPPOSITE leg-and-arm contact pose from column 1, in all four directional rows.
Keep this exact charming character identity and pixel-art quality: straw hat with teal band, chestnut hair, teal shirt, ochre scarf, indigo overalls, brown boots, cute face, same scale and proportions. Preserve all sprites in columns 0, 1 and 2. Do not alter those.
Precise rightmost-column pose corrections:
TOP / BACK row: currently the viewer-right boot is the prominent lower forward boot. Change it so the viewer-LEFT boot is the prominent lower boot and the viewer-right boot lifts behind; viewer-right hand swings forward as viewer-left hand swings back.
SECOND / RIGHT-FACING row: the near/lighted leg must swing BACK toward screen-left, while the far/darker leg extends FORWARD toward screen-right. The near/lighted arm swings FORWARD to screen-right, and the far arm swings back. Show two separated boots, not the same near-leg-forward pose as column 1.
THIRD / FRONT row: currently viewer-right boot projects downward toward us. Make viewer-LEFT boot project downward toward us instead, with viewer-right boot tucked back; viewer-right arm forward and viewer-left arm back. This must be visibly the opposite pose to column 1.
BOTTOM / LEFT-FACING row: near/lighted leg swings BACK to screen-right; far/darker leg extends FORWARD screen-left. Near arm reaches forward to screen-left; far arm goes back. Opposite to column 1.
All four rightmost sprites retain original head direction, face/hair/hat/clothes. Keep planted boots at the same baseline as the other poses. Modest secondary scarf/hat movement only. Keep the 4x4 layout and transparent background; no new sprites, no text, no shadow, no glow, no ground. Clean crisp pixel-art edges.
```

## Validation and consumer boundary

Image checks pass for dimensions/RGBA mode, binary alpha, shared palette, sixteen nonempty padded frames, four distinct poses per row, four newly designed idles, common foot baseline, and connected silhouettes (including diagonal pixel connections).
The motion preview has four frames and a 500 ms cycle.
Native/nearest-2× comparisons and farm composites were inspected for scale and readability.
Godot import/resource checks verify sixteen frame coordinates and the existing `Rect2(-16,-48,32,48)` sprite geometry.

**HPA-546 must accept the new idle appearance and update affected production goldens after visual review.**
Recheck HPA-459 tool-overlay attachment positions against the new hands/body.
The live player, tool code, collision, camera, saves, production goldens, and gameplay remain unchanged in this art PR.
In-world motion and subjective timing are not validated by composited previews.

| Artifact | SHA-256 |
| --- | --- |
| `assets/sprites/player-walk.png` | `d2b440bb8ebb8cb8fc9c11e3bfecfead281f675b4b9bf492bb8b8476338bd0f7` |
| `tests/visual/hpa-539/contact-sheet.png` | `f62a46808c5c670015f7956811810ea69e6d903c17e688b0b54dcdeaf487f154` |
| `tests/visual/hpa-539/walk-preview.gif` | `e4b16b1756194dd38bfb5a38ed54a9c0e46091c5aad90862d0fafb342ee9a946` |
