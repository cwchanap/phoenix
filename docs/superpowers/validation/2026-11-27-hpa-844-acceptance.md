# HPA-844 acceptance ledger — phone app and card polish

Date: 2026-11-27
Branch: `agent/hpa-844-phone-app-card-polish-plan`
PR: [#50](https://github.com/cwchanap/phoenix/pull/50)
Status: **Implementation and agent-operated acceptance evidence recorded at
`d4c3c80414ecf67ef6e551f5acd86dbebf89613f` (`d4c3c80`). This is not human
acceptance.**

## Automated evidence

| Check | Provenance | Result |
| --- | --- | --- |
| GitHub `verify` | [run 45929853579](https://github.com/cwchanap/phoenix/actions/runs/45929853579), head `d4c3c80` | **pass**: 668/668 GUT tests, 53,266 assertions, headless smokes, audio-source checks, release import, unsigned macOS export, exported-PCK smoke (6 scenes, 19 textures) |
| GitHub `unit-tests` | [run 45929853487](https://github.com/cwchanap/phoenix/actions/runs/45929853487), head `d4c3c80` | **pass**: 16/16 |
| GitHub `e2e-tests` | [run 45929853455](https://github.com/cwchanap/phoenix/actions/runs/45929853455), head `d4c3c80` | **pass**: 14/14, including both physical-Tab navigation cases |
| Local clean verifier | committed head `cdc68f4`, standard Godot 4.7.1 | **pass**: 659/659 GUT tests, 52,874 assertions, all headless smokes and audio-source checks |
| Local GdUnit | `6c15ee5` | **pass**: 16/16 |
| Local full godot-e2e | same local validation effort | **not a pass**: 10/14; four day-one cases hit `wait_seconds` transport timeouts. The real overnight-save case and both physical-Tab cases passed. The timeout signature matches the HPA-863 local-lane caveat, but the cause remains unconfirmed. |

Main's HPA-1250 typewriter merge initially exposed two HUD-fixture assumptions. On the exact prior CI merge `ca06238`, the VN suite reproduced 102/104; using the existing animation opt-out in the HUD fixture passed 104/104. A full local GUT run of that patched merge timed out after 600 seconds and is not a full-suite pass. The recorded GitHub verify lane is the decisive clean result at `d4c3c80`.

## MCP visual/functional evidence

Representative original PNG captures are attached to the PR body under **MCP capture evidence**. They are not committed to git. The complete ignored local archive remains `test_output/hpa-844-mcp-2a82ea2/`; the attached subset is enough to review each changed surface without a full repeated tour.

Provenance:

- Captured on 2026-11-26, 13:46–14:41 UTC, at 1920×1080 through the stock Godot MCP bridge.
- The bridge used Godot 4.7.2 Mono and isolated playtest save/settings files. The automated gates use standard Godot 4.7.1; no compatibility claim is made beyond the recorded runs.
- The first walkthrough sequence began after `4185dcd`. The later locale/commerce sequence followed `6c15ee5`; that commit changed read-only calendar/test seams and removed a stale comment, not the rendered layout.
- The archive predates `077296e` (test fixture only), `cdc68f4` (diary-heading color), and `d4c3c80` (idle-render skipping). `d4c3c80` does not change the saved-state composition shown in the capture.
- MCP dismissal used the existing dismiss control where stock native key input was unavailable. Physical Tab proof comes from the E2E lane, not from MCP button activation.

| Attached capture | Locale | Evidence |
| --- | --- | --- |
| `01-title-en.png` | en | New game/Continue sentence case |
| `02-world-tip-tab-en.png` | en | visible world tip and Tab affordance |
| `03-settings-tip-over-menu-en.png` | en | tip over ordinary Settings menu; filled segments; no save-path row; English Japanese kicker |
| `04-phone-home-ja.png` | ja | localized phone home after live locale switching |
| `05-morning-diary-ja-pre-contrast-refresh.png` | ja | diary card, one Progress saved line, Start day action; pre-contrast-refresh heading |
| `06-settings-zh-tw.png` | zh_TW | localized Settings segments and no save-path row |
| `07-bag-empty-zh-tw.png` | zh_TW | empty-bin line without a blank grid strip |
| `08-calendar-en.png` | en | Calendar title, centered day above markers, wrapped legend chips |
| `09-seed-shop-en.png` | en | Seed shop sentence case and commerce layout |
| `10-town-tip-en.png` | en | nonblocking town tip |
| `11-result-en.png` | en | New game/Title result actions |
| `12-shipping-zh-tw.png` | zh_TW | localized shipping surface |
| `13-dialogue-ja.png` | ja | localized dialogue actions |
| `14-dialogue-zh-tw.png` | zh_TW | localized dialogue actions |
| `15-seed-shop-zh-tw.png` | zh_TW | localized seed shop |
| `16-title-ja.png` | ja | localized title |
| `17-result-ja.png` | ja | localized result |

## Explicit visual gap

The diary capture was not refreshed after `cdc68f4`. Its card composition, day heading, single `Progress saved` line, and `Start day N` action remain representative, but the heading still shows the pre-review `INK_MUTED` color. The final implementation uses local `#806479` (4.82:1 on `SOFT` versus 4.10:1 for `INK_MUTED`), and the integration test measures the rendered contrast rather than token equality. No other post-capture production commit intentionally changed the captured visual composition.

## Deferred review observations

These remain coverage follow-ups, not confirmed behavior defects: direct proof that tip-body clicks reach an underlying receiver; locale change while a phone panel is hidden before reopening it; Day 14 marker gap/vertical-alignment pinning; stronger scroll-reset, bottom-endpoint, and inactive W/S input tests.
