# UI font provenance

These files are upstream variable font files used by the Phoenix UI reference
implementation. They are not embedded mock payloads. The OFL license text is
kept beside each font.

| file | upstream | pinned source |
| --- | --- | --- |
| `open-sans-variable.ttf` | Google Fonts `googlefonts/opensans` | commit `bd7e37632246368c60fdcbd374dbf9bad11969b6`, `fonts/variable/OpenSans[wdth,wght].ttf` |
| `jetbrains-mono-variable.ttf` | JetBrains `JetBrainsMono` | commit `19371302b95d218af43299bce79ddbddd0bc364d`, `fonts/variable/JetBrainsMono[wght].ttf` |
| `noto-sans-jp-variable.ttf` | Google Fonts `google/fonts` | `main` fetched 2026-11-01, `ofl/notosansjp/NotoSansJP[wght].ttf` |
| `noto-sans-tc-variable.ttf` | Google Fonts `google/fonts` | `main` fetched 2026-11-01, `ofl/notosanstc/NotoSansTC[wght].ttf` |

SHA-256 hashes:

- `open-sans-variable.ttf`: `36643644f318a812aab2d2ed3bb98f8cf0872527f835fe9398d95fe6b9adb878`
- `jetbrains-mono-variable.ttf`: `3cfafa86e28b87184d592fef82846e8c10cb48653c62efcda34f082da225ec34`
- `noto-sans-jp-variable.ttf`: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- `noto-sans-tc-variable.ttf`: `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`

The two Noto fonts are CJK fallbacks behind Open Sans / JetBrains Mono. Their
`.import` files set `language_support` (JP excludes `zh`, TC excludes `ja`)
so Godot picks the Japanese or Traditional Chinese glyph forms by locale.
