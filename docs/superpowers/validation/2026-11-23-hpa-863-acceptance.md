# HPA-863 acceptance ledger — farm v2 world art

Date: 2026-11-23
Branch: `plan/hpa-863-farm-map-v2-world-art`
Status: **local acceptance complete; CI pending the coordinator's final push.**
Operator: agent-operated, not human. No new art or SFX was generated.

## Commits covered

| Commit | Scope |
| --- | --- |
| `fa79130` | v2 Continue and pre-v2 save-rejection GUT assertions |
| `7483cac` | review/proof asset prune and pack-provenance gate |
| `d8c972a` | MCP acceptance driver (test-only, never exported) |
| `0c007f7` | README/CLAUDE/AGENTS 48x40 contract and save policy |

## Test evidence (Godot 4.7.1, isolated `HOME`)

All CLI runs used `PATH=/tmp/opencode/phoenix-bin:$PATH`
(`Godot_v4.7.1-stable_linux.arm64`, `4.7.1.stable.official.a13da4feb`) and a
fresh temporary `HOME`. `./tools/verify-clean.sh` archives committed `HEAD`.

| Check | Command | Result |
| --- | --- | --- |
| Clean verifier | `./tools/verify-clean.sh` | **exit 0**: import, GUT **632/632** (51,113 asserts), project smoke, world-math smoke, terrain-stamp drift (35 sources / 1,542 tiles / 1,920 cells), world-shell smoke (`48x40`, 47 props, 85 fences, 8 decor, 3-plank PierDeck), audio |
| GdUnit4 | `GODOT_BIN=... xvfb-run -a ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` | **16/16**, 0 errors/failures/orphans |
| godot-e2e, individual suites | same harness with `-a tests/e2e/world_readability_test.gd` and `-a tests/e2e/gameplay_day_one_test.gd` | `world_readability` **1/1 pass** (29.1 s); `gameplay_day_one` **7/7 pass** (2 min 42 s) |
| godot-e2e, full lane | `... -a tests/e2e -c` (two runs) | **exit 100 both times**; 13 cases, **3 errors / 85 failures**, all inside `gameplay_day_one_test`: `held_row` 26, `player_moves` 5, `travel_overlay` 52, `observe` 2. `app_launch` 3/3, `market_confirm` 1/1, `ui_navigation` 1/1 and `world_readability` 1/1 passed in the same run. Every failure begins with `Command 'wait_seconds' timed out after 1300–1600 ms` followed by `E2E session is not open`; no map/decor assertion failed. The same suite passes alone, so this is host load/llvmpipe latency, not a v2 regression. |

The two previously reported child-server failures (`test_player_moves_with_real_input`
and `test_travel_overlay_blocks_input_and_resumes_the_clock`) now fail only in
the combined lane under load; both pass when `gameplay_day_one_test` runs alone.
The full lane remains an honest open blocker, not claimed green.

## Save policy

- `test_v2_save_continues_at_new_farm_spawn` pins a current save's Continue at
  `(23.5, 11.5)`, the `48x40` map, farm cells `(15,19)`..`(20,23)` and
  `GameRules.MapId.FARM`.
- `test_pre_v2_farm_cells_are_rejected_without_migration` writes the retired
  `(4..9,10..14)` cell order into a schema-4 save. It decodes
  (`status: loaded`), then `SessionStateValidator` returns exactly
  `farm[0].cell does not match the authored farm order`; Continue is disabled,
  the title says `Save is incompatible; start a New Game.`, AppRoot refuses
  the emitted Continue, and the old cell remains `(4,10)` on disk (no
  migration/rewrite).
- TDD sensitivity: temporarily disabling the validator's cell-order branch
  turned the pre-v2 test red (Continue launched a World), then the branch was
  restored and the test re-ran green.

## Approved layout and screenshots

`.superpowers/sdd/2026-11-21-phoenix-farm-v2-world-art-implementation/approved-layout.json`
was re-checked on the committed tree: `48x40`, all 28 terrain entries in order
and spawn `(23.5,11.5)` match **exactly** (`approved layout match: true`).

The approved HPA-863 blockouts and `world-mockup-vs-game.jpg` could **not** be
fetched: no Linear MCP tool is exposed in this session, and the previously
recorded blocker is
`mcp-remote: Authentication is still pending in another instance on port 22227.`
No credentials or tokens were searched for. The screenshots below were
therefore reviewed against the written checkpoint and `approved-layout.json`,
not against the approved images. That comparison remains open.

## Native MCP acceptance

MCP runtime bridge: `@cwchanap/godot-plugin` `tools.godot.*`. Its executable
is **4.7.2.stable.mono** (`get_godot_version`), not the pinned 4.7.1 CLI:
the bridge has no executable selector and the running MCP server's binary
cannot be changed from the tool API. The game itself was the current worktree.

Exact method:

1. `tools.godot.run_project({projectPath, scene:
   "res://tests/native_tour/mcp_acceptance_driver.tscn", runtimeControl:true})`.
   The bridge installed its untracked `.godot` addon/autoload; `project.godot`
   was reverted after the run and `addons/` is ignored.
2. `tools.godot.get_runtime_state` → `connected`, `session-4`,
   `scenePath: res://tests/native_tour/mcp_acceptance_driver.tscn`.
3. `tools.godot.invoke_node_action` on
   `/root/McpAcceptanceDriver/App/TitleScreen/Menu/NewGame` — a real title
   button press.
4. Driver buttons pressed via `invoke_node_action` (only BaseButton `press` is
   supported by the bridge): `SkipIntro` (real Skip press), `DismissTutorial`,
   `ClockOff`, `ToggleUI`, then `WalkField`, `Action`, `WalkBin`, `Interact`,
   `Cancel`, `WalkBed`, `Interact`, `Cancel`, `WalkFarmTruck`, `Interact`,
   `WalkShop`, `Interact`, `Cancel`, `WalkInert`, `Interact`, `WalkTownTruck`,
   `Interact`.
5. Map swaps confirmed with `find_node` on
   `/root/McpAcceptanceDriver/App/World/FarmMap` / `TownMap`.
6. `capture_screenshot` for each pose; `get_runtime_state`/state markers and
   `test_output/mcp_acceptance/actions.jsonl` (ignored) recorded the live
   state. `stop_project` ended the session.

The driver is test-only and in `tests/native_tour/` (excluded from export). It
does not teleport or touch the session: each walk uses AStar waypoints, real
Input move actions and live collision; each `Action`/`Interact` sends the real
`use_action`/`interact` action. Observed results: field action changed stamina
20→17 and time 628→835; prompts were `[E] 出荷箱` (bin), `[E] 寝る` (bed),
`[E] 町までドライブ` (farm truck), `[E] 種屋` (shop) and
`[E] 家までドライブ` (town truck); the inert station answered the red
`調べられるものが無い` toast; the town arrived at 22:00 and the return trip also
stayed legal at the 22:00 cutoff.

The clean capture pass (second MCP run) used `ClockOff`, English tutorial
disabled (dismissed card) and the driver panel hidden. The MCP game inherited
the host Japanese locale, so HUD/modal copy in the captures is Japanese.

Committed at `docs/superpowers/validation/hpa-863-mcp-captures/`:

| Capture | Evidence |
| --- | --- |
| `hpa863-mcp-01-day-one-yard.png` | Day 1, 06:00, yard in front of the farmhouse |
| `hpa863-mcp-02-front-door-contact.png` | door-slice contact, `[E] 寝る`, HPA-743 house fade |
| `hpa863-mcp-03-storehouse-yard.png` | storehouse south contact; the fade there is the HPA-743 occluder, not lost art |
| `hpa863-mcp-04-field-action.png` | 30-cell field, Space till preview and post-action stamina 17 |
| `hpa863-mcp-05-shipping-bin.png` | full-cell bin opened the shipping panel |
| `hpa863-mcp-06-bed.png` | bed opened the 06:00 sleep confirmation |
| `hpa863-mcp-07-town-paving.png` | arrived town paving/truck/villagers, no tile rims |
| `hpa863-mcp-08-shop.png` | Seed Shop panel in town |
| `hpa863-mcp-09-inert-refusal.png` | station prop E refusal toast |
| `hpa863-mcp-10-farm-return.png` | return trip landed on the farm at `TRUCK_ARRIVAL` |
| `hpa863-mcp-11-camera-southwest.png` | farm SW camera extreme: continuous water/reeds/grass, no grey |
| `hpa863-mcp-12-camera-northeast.png` | farm NE camera extreme: continuous road/paddy/grass, no grey |

The earlier Task 4 note (`2026-11-23-hpa-863-native-tour.md`) covers the
seeded crop growth/soil readability set, town camera extremes, pier deck and
Y-sort/fade. None of the MCP captures is a screenshot-golden test.

## Export PCK gate

On a temporary `git archive` of committed `HEAD` (`7ff4e47`) with the
host-only `textures/vram_compression/import_s3tc_bptc=true` added **only in
the temporary copy**, the unsigned macOS export produced a 97 MB ZIP with
`Phoenix.app/Contents/MacOS/Phoenix` and `Contents/Resources/Phoenix.pck`.
The PCK was extracted into an isolated directory and run as:

```bash
godot --headless --main-pack Phoenix.pck --script res://tools/export_pack_smoke.gd
```

Result: **exit 0, `export_pack_smoke: 6 scenes and 18 textures load from the
pack`** (app/world/farm/town, farm/town tilesets, crops, soil, ground phases,
multi-junctions, farmhouse/storehouse, bin, town buildings, player, truck,
villagers, shadow). The gate also asserts the checkout-only canary is absent
and that `hpa-861-review` source/provenance paths resolve neither in the pack
nor in the checkout. A checkout-side `ResourceLoader.exists()` probe returns
false for `farm-source.png`, the old `ground-v2` tile and the review README.

## Cleanup

Removed after a live-reference search (historical notes under
`docs/superpowers` and `tests/visual` are retained as history, not runtime
references):

- top-level `proof-crops`, `proof-soil`, `proof-scenery`, `proof-villagers`;
- old `starting-farm-terrain.png` / `starting-farm-props.png` runtime atlases
  (the two `starting-farm-*-source.webp` source sheets stay tracked);
- obsolete `town-props.png` / `town-terrain.png` runtime atlases;
- every review scene, preview, candidate atlas, `ground-v2` split/check image,
  `tiles/` split and extracted review cutout under
  `assets/sprites/hpa-861-review/`, plus its stale `.import` sidecars.

The provenance folder now holds only 16 `*-source.png` generation sheets, the
prompt README and `.gdignore`; `world-v2/` keeps the promoted runtime art.

## Open blockers

- **CI has not run** on the final SHA; the coordinator owns the push and PR
  checks. No CI/`unit-tests`/`e2e-tests` lane is claimed green here.
- **Approved-image comparison unavailable** (Linear OAuth pending, no Linear
  MCP tool in this session). Geometry matches `approved-layout.json`; the
  visual comparison to the blockouts/`world-mockup-vs-game.jpg` is still open.
- **Full godot-e2e lane is red locally** (combined suite only) with the
  timing/`wait_seconds` pattern above; each affected suite passes alone.
- The MCP bridge runs 4.7.2 Mono; all CLI gates above use pinned 4.7.1.
