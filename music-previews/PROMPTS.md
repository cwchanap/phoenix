# Draft background music previews

Generated with ElevenLabs Eleven Music via the REST API
(`POST https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128`).

- Model id: `music_v2_5`
- Requested duration: `music_length_ms = 75000` (75 s) for every file
- `force_instrumental = true`
- Two variations per track = two independent requests with the same prompt
  (no seed; seed cannot be combined with `prompt`).
- Drafts only: not wired into the game; nothing under `assets/` changed.

| File | Prompt |
|------|--------|
| `title-v1.mp3`, `title-v2.mp3` | Instrumental only, no vocals. Nostalgic 1980s Japanese City Pop ballad at a slow 80 bpm. Warm Rhodes electric piano chords, soft round bass, gentle shimmering synth pads. Evening city skyline feeling with a cozy rural warmth. Mellow and quiet background music for a video game title screen. Seamless loop: steady tempo throughout, no big intro, no fade-out ending, same energy at start and end. |
| `farm-day-v1.mp3`, `farm-day-v2.mp3` | Instrumental only, no vocals. Bright, relaxed acoustic farm tune at 95 bpm. Fingerpicked acoustic guitar with light marimba and delicate koto touches, soft shaker. Sunny Japanese countryside morning, carefree and cozy. Gentle background music for a farming video game, sits quietly under sound effects. Seamless loop: steady tempo, no big intro, no fade-out ending, same energy at start and end. |
| `farm-night-v1.mp3`, `farm-night-v2.mp3` | Instrumental only, no vocals. Calm lo-fi evening music at 70 bpm. Soft Rhodes electric piano, mellow upright bass, brushed drums. Cozy and a little lonely, a quiet night alone on a remote Japanese farm. Gentle background music for a video game, sits quietly under sound effects. Seamless loop: steady tempo, no big intro, no fade-out ending, same energy at start and end. |
| `town-v1.mp3`, `town-v2.mp3` | Instrumental only, no vocals. Upbeat light 1980s Japanese City Pop at 105 bpm. Funky clean electric guitar, light slap bass, Rhodes electric piano, light drums. Friendly small-town shopping street, cheerful and relaxed. Background music for a video game, sits under sound effects. Seamless loop: steady tempo, no big intro, no fade-out ending, same energy at start and end. |

## Measured durations

All eight files measure 75.0 s (macOS `afinfo`), MP3 44.1 kHz 128 kbps, ~1.1 MB each.
Loop seams have not been edited or checked by ear yet.

## Seamless loop drafts (`loop/`)

Eleven Music has no loop parameter, so the loop is cut after generation.

### `loop/title-loop-v1.wav` (+ `title-loop-v1-x3.m4a` review copy)

- Model `music_v2_5`, `force_instrumental = true`, `music_length_ms = 40000`,
  `output_format = mp3_44100_192`.
- Prompt: Instrumental only, no vocals. Nostalgic 1980s Japanese City Pop ballad at a steady 80 bpm in 4/4. Warm Rhodes electric piano chords, soft round bass, gentle shimmering synth pads. Evening city skyline feeling with a cozy rural warmth. Mellow and quiet background music for a video game title screen. Designed as a seamless loop: starts immediately mid-groove with no intro, constant tempo and dynamics throughout, no build-up, no breakdown, no ending, no fade-out; the last bar flows straight back into the first.
- Measured source tempo ~79.5 bpm (onset autocorrelation), so one bar is 3.0 s
  and 30.0 s is exactly 10 bars. Loudness held steady (-13 to -15 dBFS per
  3 s window) with no intro; only the last ~4 s of the take sags and is unused.
- Recipe: decode to 16-bit 44.1 kHz stereo WAV; loop body = source 0.0-30.0 s;
  the next bar (30.0-33.0 s) is equal-power crossfaded (sin/cos) into the
  first 3.0 s of the body. Output is exactly 30.000 s (1,323,000 frames) and
  wraps onto its own start.
- Seam check: wrap step (last -> first sample) L 208 / R 655, versus median
  neighbouring step 150 / 139 and 99th percentile 2071 / 1881.
- The `-x3.m4a` file is the loop repeated three times (AAC 192 kbps, 90 s) for
  listening to the seam twice; the WAV is the file to use in Godot.

### `loop/farm-day-loop-v1.wav` (+ `farm-day-loop-v1-x3.m4a` review copy)

- Model `music_v2_5`, `force_instrumental = true`, `music_length_ms = 40000`,
  `output_format = mp3_44100_192`.
- Prompt: Instrumental only, no vocals. Bright, relaxed acoustic farm tune at a steady 96 bpm in 4/4. Fingerpicked acoustic guitar with light marimba and delicate koto touches, soft shaker. Sunny Japanese countryside morning, carefree and cozy. Gentle background music for a farming video game, sits quietly under sound effects. Designed as a seamless loop: starts immediately mid-groove with no intro, constant tempo and dynamics throughout, no build-up, no breakdown, no ending, no fade-out; the last bar flows straight back into the first.
- Nominal 96 bpm, so one bar is 2.5 s and 30.0 s is exactly 12 bars.
  Onset-autocorrelation tempo estimate: 95.7. A self-similarity scan (the
  first 6 s against the 6 s starting at L, for L from 26 to 34 s) peaks at
  exactly L = 30.00 s, so the take stays on the bar grid.
- Recipe: same as the title loop. Body = source 0.0-30.0 s; the next bar
  (30.0 s to 30.0 s + 2.5 s) is equal-power crossfaded into the opening.
  Output is exactly 30.000 s (1,323,000 frames).
- Seam check: wrap step L 13 / R 200, versus median step 170 / 162 and 99th
  percentile 1038 / 1090. Loudness is steady per 3 s window, with no intro.

### `loop/farm-night-loop-v1.wav` (+ `farm-night-loop-v1-x3.m4a` review copy)

- Model `music_v2_5`, `force_instrumental = true`, `music_length_ms = 40000`,
  `output_format = mp3_44100_192`.
- Prompt: Instrumental only, no vocals. Calm lo-fi evening music at a steady 72 bpm in 4/4. Soft Rhodes electric piano, mellow upright bass, brushed drums. Cozy and a little lonely, a quiet night alone on a remote Japanese farm. Gentle background music for a video game, sits quietly under sound effects. Designed as a seamless loop: starts immediately mid-groove with no intro, constant tempo and dynamics throughout, no build-up, no breakdown, no ending, no fade-out; the last bar flows straight back into the first.
- Nominal 72 bpm, so one bar is 3.333 s and 30.0 s is exactly 9 bars.
  Onset-autocorrelation tempo estimate: unreliable (139.7, a double-time misread). A self-similarity scan (the
  first 6 s against the 6 s starting at L, for L from 26 to 34 s) peaks at
  exactly L = 30.00 s, so the take stays on the bar grid.
- Recipe: same as the title loop. Body = source 0.0-30.0 s; the next bar
  (30.0 s to 30.0 s + 3.333 s) is equal-power crossfaded into the opening.
  Output is exactly 30.000 s (1,323,000 frames).
- Seam check: wrap step L 8 / R 27, versus median step 91 / 88 and 99th
  percentile 629 / 542. Loudness is steady per 3 s window, with no intro.

### `loop/town-loop-v1.wav` (+ `town-loop-v1-x3.m4a` review copy)

- Model `music_v2_5`, `force_instrumental = true`, `music_length_ms = 40000`,
  `output_format = mp3_44100_192`.
- Prompt: Instrumental only, no vocals. Upbeat light 1980s Japanese City Pop at a steady 104 bpm in 4/4. Funky clean electric guitar, light slap bass, Rhodes electric piano, light drums. Friendly small-town shopping street, cheerful and relaxed. Background music for a video game, sits under sound effects. Designed as a seamless loop: starts immediately mid-groove with no intro, constant tempo and dynamics throughout, no build-up, no breakdown, no ending, no fade-out; the last bar flows straight back into the first.
- Nominal 104 bpm, so one bar is 2.308 s and 30.0 s is exactly 13 bars.
  Onset-autocorrelation tempo estimate: 103.4. A self-similarity scan (the
  first 6 s against the 6 s starting at L, for L from 26 to 34 s) peaks at
  exactly L = 30.00 s, so the take stays on the bar grid.
- Recipe: same as the title loop. Body = source 0.0-30.0 s; the next bar
  (30.0 s to 30.0 s + 2.308 s) is equal-power crossfaded into the opening.
  Output is exactly 30.000 s (1,323,000 frames).
- Seam check: wrap step L 118 / R 11, versus median step 190 / 159 and 99th
  percentile 3908 / 3294. Loudness is steady per 3 s window, with no intro.
