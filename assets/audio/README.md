# Phoenix placeholder audio

These WAV files are project-generated placeholder tones created for the HPA-599 MVP closeout. They contain no externally sourced recording or composition and require no third-party attribution. They are intentionally disposable if authored audio replaces them later.

## HPA-459 farming success cues

`farm-hoe.wav`, `farm-plant.wav`, `farm-water.wav`, and `farm-harvest.wav` are project-generated with the same throwaway Python stdlib recipe as the HPA-599 tones (`wave`/`math`/`random` only; mono 16-bit 22050 Hz, <0.5 s each). No synthesis script is committed; regenerate by re-running the recipe below and normalizing peak amplitude to 0.85.

| File | Length | Timbre | Recipe |
| --- | ---: | --- | --- |
| `farm-hoe.wav` | 0.22 s | low dirt thud | 85 Hz sine, 45 ms decay, plus a 12 ms white-noise burst |
| `farm-plant.wav` | 0.18 s | droplet pluck | single sine sweeping 620→170 Hz (exp. pitch falloff τ=30 ms) with 50 ms decay |
| `farm-water.wav` | 0.35 s | noise swish | one-sample high-passed white noise under a single full-length sine-squared swell |
| `farm-harvest.wav` | 0.28 s | bright two-note pop | 780 Hz blip then a 1170 Hz blip entering at 60 ms (60 ms decay), plus 20 ms sparkle noise |

All four map one-to-one through `GameHud._sfx_for_code()` to the farming success codes (`SOIL_TILLED`, `CROP_PLANTED`, `CROP_WATERED`, `CROP_HARVESTED`) and play through the existing SFX player, so the Sound setting governs them automatically.
