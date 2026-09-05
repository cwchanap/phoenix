# Phoenix UI Reference Contract

Date: 2026-09-04
Status: Normative companion to `2026-09-04-phoenix-ui-redesign-design.md`

This document freezes the visual fixtures, comparison surfaces, asset names, and verification roles before implementation. It deliberately separates **design approval** from **machine regression** so the browser mock is never treated as a pixel-identical output of Godot.

## Two-tier visual contract

### Tier 1 — mock-derived design references

The supplied HTML mock is the human design oracle. Store normalized 1280x720 reference PNGs under:

`tests/visual/design-reference/`

They are reviewed side-by-side against 2x production captures. These references answer: “Does the production UI visually match the approved design?”

They are **not** the automated pixel oracle. A Godot 640x360 frame nearest-upscaled to 1280x720 cannot be pixel-identical to Chromium/WebKit native 1280x720 rasterization: glyph antialiasing, border coverage, and subpixel layout differ by renderer even when the layout is correct.

### Tier 2 — production regression goldens

After a state has been visually approved against its mock-derived design reference, `tools/verify-visual.sh --update-goldens <state>` writes the real 640x360 Godot capture to:

`tests/visual/goldens/`

Normal verification captures the same production state and compares it to that production-generated golden. CI never runs `--update-goldens`.

Machine goldens answer: “Did an already-approved production UI regress?” They do not replace the human design-parity review.

### Raw-image loading

`tests/visual/design-reference/`, `tests/visual/goldens/`, and `tests/visual/plates/` each contain a `.gdignore`. Comparison code loads PNG bytes with:

```gdscript
Image.load_from_file(ProjectSettings.globalize_path(path))
```

Do not use `ResourceLoader` or `CompressedTexture2D.get_image()` for reference/golden files. This avoids texture-import compression/mipmap behavior changing the oracle.

## UI-vs-world comparison boundary

The task redesigns UI, not the authored `TileMapLayer` / `FarmView` world. Test capture may hide world drawing and compose the **real production UI** over test-only plates. No production scene may depend on a plate.

| State | Human design-comparison surface |
| --- | --- |
| 01 HUD | Compare only 1280x720 regions `y=0..71` and `y=588..719`; the 516 px live-world middle band is excluded. |
| 02 Seed Shop | Full frame, real Shop panel over `tests/visual/plates/farm.png`. |
| 03 Shipping Bin | Full frame, real Shipping panel over `tests/visual/plates/shipping.png`. |
| 04 Bag | Full frame over `tests/visual/plates/farm.png`. |
| 05 Almanac | Full UI-owned frame. |
| 06 Calendar | Full UI-owned frame. |
| 07 Dialogue | Full frame over `tests/visual/plates/farm.png`. |
| 08 Morning Summary | Full frame over `tests/visual/plates/morning.png`. |
| 09 Sleep | Center the mock’s 628x520 sample in 1280x720 over `tests/visual/plates/sleep.png`; compare full frame. |
| 10 Pause | Center the mock’s 628x520 sample in 1280x720 over `tests/visual/plates/farm.png`; compare full frame. |
| 11 Settings | Full UI-owned frame on `UiStyle.INSET`. |
| 12 Intro | Full frame; Intro owns its background. |
| 13 Title | Full frame; Title owns its background. |
| 14 Result | Full frame; Result owns its background. |

Production capture always starts from the 640x360 root viewport. `capture_ui_states.gd` waits for `RenderingServer.frame_post_draw` and asserts exactly 640x360. The 640x360 image is the machine-regression input. A copy is nearest-neighbor resized to 1280x720 only for human design evidence.

`project.godot` remains 640x360 logical resolution.

## Deterministic typography

Parity-critical text must not depend on host fonts. Bundle pinned open-licensed variable TrueType files from official upstream distributions, plus their license text:

- `assets/ui/fonts/open-sans-variable.ttf`
- `assets/ui/fonts/jetbrains-mono-variable.ttf`

`UiStyle` loads them as `FontFile`s and uses `FontVariation` weights 400/600/700/800. Do not use `SystemFont`, and do not extract the mock’s embedded webfont bytes.

## Platform-drift calibration

Godot uses `gl_compatibility`; Linux CI renders through Xvfb/llvmpipe while local macOS uses its GL stack. Do not freeze arbitrary image-diff tolerances before measuring this.

State `01-hud` proves the harness first. After it is visually approved and a production golden exists:

1. Run the comparer in `--report-only` mode on macOS.
2. Let the PR CI run the same state under Linux/Xvfb in `--report-only` mode and retain its capture artifact.
3. Compare the two production captures and record `max_channel_delta` and `mismatch_ratio` in the PR.
4. Set the machine thresholds to the smallest values that cover the observed drift plus one 8-bit channel step. Hard ceiling: channel tolerance `12/255` and mismatch ratio `0.002`. If measured drift exceeds either ceiling, fix rendering determinism instead of weakening the gate.
5. Remove `--report-only` from CI for state 01 before adding further states.

Later states use the already-proven capture path and thresholds.

## Frozen fixture table

All farm-state fixtures must satisfy `GameSession.state_error(state) == ""` before restore. Transient display-only state uses existing presentation seams rather than fake gameplay fields.

| # | State | Frozen presentation inputs |
| --- | --- | --- |
| 01 | HUD | Day `3/14`; `09:20` (`time_minutes=560`); Sunny; market in `11`; money `150`; stamina `14/20`; selected Hoe; selected seed Turnip; seeds `3/0/0`; harvested `2/0/0`; pending `0/0/0`; tutorial `PREPARE THE FIELD`; interaction `E SHOP`; feedback `SOIL TILLED`. |
| 02 | Seed Shop | money `150`; Turnip selected; quantity `5`; price `20`; live total `100`; seed holdings `3/0/0`. |
| 03 | Shipping Bin | Day `14`; harvested `7/0/0`; Turnip selected; quantity `7`; selected deposit value `245`; pending starts `0/0/0`. |
| 04 | Bag | seeds `3/0/0`; harvested `7/2/0` (total 9); pending `4/0/0` (`140G`); Seeds shelf + Turnip selected; detail `3 nights`, `20G`, `35G`, June favourite. |
| 05 | Almanac | Turnip/June `3,20,35,+15`; Potato/Mira `5,40,75,+35`; Pumpkin/Rowan `7,70,140,+70`. |
| 06 | Calendar | Day `3`; market in `11`; history `[sunny,rainy,sunny]`; Turnip growth `0` gives earliest Day 6; Pumpkin growth `1` gives earliest Day 9; no future-weather icons; Day 14 Market. |
| 07 | Dialogue | Mira; `13` points / Friend; talked today; presentation +1; harvested Turnip `7`, Potato `2`, Pumpkin `0`; Potato selected/favourite `+5`; normal `+3`; dialogue `Your fields are starting to look dependable.` |
| 08 | Morning Summary | current Day `4`; completed `3`; next `4`; crops advanced `2`; next weather Rainy; Turnip x2 `70G`; income `70`; money after `220`; stamina `20 FULL`; save `SAVED`. |
| 09 | Sleep | Day `14`; terminal warning; Enter action `SLEEP`. |
| 10 | Pause | Controls panel open. |
| 11 | Settings | Music `4/10`; Sound `7/10`; Window `2x`; Tutorial Cards `ON`; Music selected; displayed save path **always** `SaveRepository.DEFAULT_PATH` (`user://phoenix-save.json`), never the `PHOENIX_SAVE_PATH` test override. |
| 12 | Intro | fresh Day `1`; intro not acknowledged; existing two paragraphs; Enter `BEGIN DAY 1`. |
| 13 | Title | Continue unavailable; reason exactly `Save is incompatible; start a New Game.`; New Game selected; footer `Godot 4.7.1 · 640×360`. |
| 14 | Result | **Normalized to production-valid data:** Day 14 completed state with shipped Turnip `4`, Potato `3`, Pumpkin `2` = `9` crops / `645G`; final money `505G`; June at Close Friend and featured; tier `Heart of the Harvest`. The normalized design reference replaces the mock’s impossible `415G` text with `645G`. Capture goes through `ContentRules.build_harvest_result()` -> `ResultScreen.present()`, not a capture-only dictionary. |

The raw mock’s `415G` result is unreachable for any non-negative combination of the fixed 35/75/140 sale values. Like the Calendar corrections, the normalized reference fixes the datum rather than changing gameplay.

## Rule helpers required by the reference

Calendar growth arithmetic stays in `GameRules`:

```gdscript
static func earliest_ready_day(kind: CropKind, growth: int, current_day: int) -> int:
    assert(growth >= 0 and growth <= growth_nights(kind))
    assert(current_day >= 1 and current_day <= MAX_DAY)
    var ready_day := current_day + (growth_nights(kind) - growth)
    return ready_day if ready_day <= MAX_DAY else -1
```

The Calendar must label this concept **EARLIEST** / **EARLIEST READY**, never unconditional `READY`, because actual growth still depends on watering/rain.

Almanac inverse favourite lookup stays in `VillagerRules`:

```gdscript
static func favourite_villager_for_crop(kind: GameRules.CropKind) -> VillagerId:
    var index := FAVOURITE_CROPS.find(kind)
    assert(index >= 0)
    return index as VillagerId
```

## Semantic asset map

All 53 mock PNGs are used by at least one reference state. Production assets use semantic names; the four illustrative world plates live under tests so they cannot accidentally become production dependencies.

| Mock UUID | Repository path |
| --- | --- |
| `019e94f0-0e96-4153-a617-f6b14633712c.png` | `assets/ui/portraits/mira-full.png` |
| `0576ca52-a5f2-461a-92b0-f747924ca4f1.png` | `assets/ui/icons/bag.png` |
| `084bc990-04f2-4192-b6a5-3ec432d79298.png` | `assets/ui/backgrounds/result.png` |
| `0bca1b21-031e-4c55-9b10-f4b533795741.png` | `assets/ui/icons/dialogue.png` |
| `1b85a473-1390-4d41-b4c8-b5f81807644e.png` | `assets/ui/icons/growth.png` |
| `1ee49533-54e6-42af-b015-5eb843134dde.png` | `assets/ui/icons/controls.png` |
| `2b52c0ab-c178-46e8-bae4-fa645d3f94c6.png` | `assets/ui/icons/hands.png` |
| `2e317b8c-9f90-4c75-9e9b-4ac24c1bc905.png` | `assets/ui/crops/potato.png` |
| `339e0886-6999-4eed-9b4e-774f93114b13.png` | `assets/ui/portraits/rowan.png` |
| `35c5f44a-8953-4b0d-8868-de674356b14f.png` | `tests/visual/plates/shipping.png` |
| `3bc97003-73f9-4c66-a0df-36e11b1033c4.png` | `tests/visual/plates/farm.png` |
| `3ed19f81-4544-408d-a53a-627de3f3354b.png` | `assets/ui/icons/watering-can.png` |
| `42c31139-59d2-48c9-a0ed-8fac19c9cdbf.png` | `assets/ui/crops/seed-packet-potato.png` |
| `441d90db-9c4d-4064-89a7-e29c27ad302e.png` | `assets/ui/icons/hoe.png` |
| `4a2f7388-73a7-4298-8dae-025311ddcbea.png` | `assets/ui/crops/pumpkin.png` |
| `4c4472c8-1b56-421d-950c-ecf602d41169.png` | `assets/ui/icons/tutorial.png` |
| `55422f4a-aed3-45dc-b06b-2783233fb418.png` | `assets/ui/icons/seeds.png` |
| `5bffa17d-37d9-4bc5-a819-4c8179422afd.png` | `assets/ui/icons/heart-outline.png` |
| `5ceea104-aafc-481a-9b6a-57cb03c28da9.png` | `assets/ui/icons/heart-filled.png` |
| `5f7f388c-d4f0-4588-b2a7-207e835c6f9c.png` | `assets/ui/crops/pumpkin-art.png` |
| `6650e117-3b17-4da3-a74d-bf806f6db111.png` | `assets/ui/crops/turnip-art.png` |
| `7ab12592-f3e6-4eac-8718-67dbcdefe043.png` | `assets/ui/icons/bed.png` |
| `7b0ca627-aac6-4745-93f0-64384d1c2069.png` | `assets/ui/icons/settings.png` |
| `84b1189e-eb7e-456b-87ea-1992e0e34713.png` | `assets/ui/portraits/mira.png` |
| `86ad6473-1d89-4e2f-9202-9249c1e578c3.png` | `assets/ui/icons/rain.png` |
| `8b0b8512-7c7b-4078-90c3-0f062047f832.png` | `assets/ui/icons/market.png` |
| `91338860-cc52-4332-854d-37d87f6b1071.png` | `assets/ui/icons/almanac.png` |
| `935cb814-f340-444a-97d8-b9b9f032e361.png` | `assets/ui/portraits/june.png` |
| `98407c7f-954b-4218-a5c5-910c5ad46bee.png` | `assets/ui/icons/coin-stack.png` |
| `9b3586c4-fc88-4b37-a572-708cf3bb72c4.png` | `tests/visual/plates/sleep.png` |
| `9f30082a-3a04-4b9f-80f8-5eebad22620c.png` | `assets/ui/icons/coin.png` |
| `a2f155d1-bedf-4ca7-b9d5-7f6c5db42430.png` | `assets/ui/icons/window-scale.png` |
| `a9c18573-6c58-43f5-b5da-55ffd1e7050b.png` | `assets/ui/crops/turnip.png` |
| `ada0d151-4db4-4cdd-8969-98658f75c8b3.png` | `assets/ui/icons/movement.png` |
| `b0ecdd5c-c572-4221-b84a-665ce03be127.png` | `assets/ui/backgrounds/intro.png` |
| `b0f61267-8017-407c-b118-48166096c4e3.png` | `assets/ui/icons/clock.png` |
| `b2b9053f-a774-4a55-b971-562487bdd0a4.png` | `assets/ui/crops/seed-packet-turnip.png` |
| `b2c84e72-a49f-473e-84d5-4f34604dfefd.png` | `assets/ui/icons/harvest-wreath.png` |
| `b8d27d08-0e4f-4af6-9e3e-6c8040aa1843.png` | `assets/ui/backgrounds/title.png` |
| `c26e265b-051e-4db4-a688-de1bb4502eef.png` | `assets/ui/icons/money-bag.png` |
| `c9560f45-8aa6-43a4-bb1b-022cd8717657.png` | `assets/ui/icons/moon.png` |
| `cb5bb869-8e1a-4442-bea7-18fc53233eea.png` | `assets/ui/icons/sun.png` |
| `ce03872e-36eb-4fa5-8a95-5a222ee53f76.png` | `assets/ui/crops/seed-packet-pumpkin.png` |
| `d3950505-4f4a-48e5-b13d-0b6f4175b658.png` | `assets/ui/icons/warning.png` |
| `d9925564-c724-4efc-9a7c-3a7f14d88fa7.png` | `assets/ui/icons/calendar.png` |
| `da33192b-9ce0-499b-9b50-25daa54cf9db.png` | `assets/ui/icons/music.png` |
| `dacb725d-eec4-4ab6-a25f-5a10a019d7da.png` | `assets/ui/icons/stamina.png` |
| `def2cf32-ab1f-48dc-a233-47b42c82a9f9.png` | `assets/ui/icons/save.png` |
| `dfcbb297-6a34-4b44-89e1-edbd60219dac.png` | `tests/visual/plates/morning.png` |
| `e2307ef4-6f86-4b95-9966-ea25213da1fe.png` | `assets/ui/icons/shipping.png` |
| `e7059798-5f18-479b-b309-953767683895.png` | `assets/ui/crops/potato-art.png` |
| `e8635589-3744-4ec7-aec1-0ea2654a7055.png` | `assets/ui/icons/sound.png` |
| `eb88a1ed-5c4c-4627-bc02-8f0570e10e7e.png` | `assets/ui/logo/phoenix.png` |

The test-only image directories are excluded from Godot import/export with `.gdignore`. Production `.tscn` files may reference only `assets/ui/**`, never `tests/visual/**`.