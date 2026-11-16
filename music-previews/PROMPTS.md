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
