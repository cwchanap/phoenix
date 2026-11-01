# UI font provenance

These files are upstream variable font files used by the Phoenix UI reference
implementation. They are not embedded mock payloads. The OFL license text is
kept beside each font.

| file | upstream | pinned source |
| --- | --- | --- |
| `m-plus-1-variable.ttf` | Google Fonts `google/fonts` | `main` fetched 2026-11-01, `ofl/mplus1/MPLUS1[wght].ttf` |
| `noto-sans-jp-variable.ttf` | Google Fonts `google/fonts` | `main` fetched 2026-11-01, `ofl/notosansjp/NotoSansJP[wght].ttf` |
| `noto-sans-tc-variable.ttf` | Google Fonts `google/fonts` | `main` fetched 2026-11-01, `ofl/notosanstc/NotoSansTC[wght].ttf` |

SHA-256 hashes:

- `m-plus-1-variable.ttf`: `32dab296a06c3e87841ecd2bc9912434a964ad541e22ea19f764969dae93fced`
- `noto-sans-jp-variable.ttf`: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- `noto-sans-tc-variable.ttf`: `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`

M PLUS 1 is the single City Pop UI face (HPA-681); it covers Latin, kana, and
common kanji. The two Noto fonts are CJK fallbacks behind it. M PLUS 1 and
Noto Sans JP exclude `zh` and Noto Sans TC excludes `ja` in their `.import`
`language_support`, so Traditional Chinese text renders in Noto Sans TC and
Japanese keeps the Japanese glyph forms.
