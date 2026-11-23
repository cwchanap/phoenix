# HPA-863 acceptance ledger — farm v2 world art

Date: 2026-11-23
Branch: `plan/hpa-863-farm-map-v2-world-art`
Status: **local changed-map/MCP/PCK acceptance complete for the runs recorded
here; approval-image comparison, the full godot-e2e lane and final-SHA CI
remain open. This is not overall release acceptance.**
Operator: agent-operated, not human. No new art or SFX was generated.

## Commits covered

| Commit | Scope |
| --- | --- |
| `fa79130` | v2 Continue and pre-v2 save-rejection GUT assertions |
| `7483cac` | review/proof asset prune and pack-provenance gate |
| `d8c972a` | MCP acceptance driver (test-only, never exported) |
| `0c007f7` | README/CLAUDE/AGENTS 48x40 contract and save policy |
| `f28c5a7` | fix MCP walk failure propagation and input-facing |
| `eb65a63` | move provenance out of the shipped pack; raw/imported gate |
| `921342c` | separate MCP capture runs; pack negative control |
| `7da4c8d` | timing-robust failed-seek regression |
| `a42165e` | bamboo grove dressing, gate crossings, separate native log |
| `4250a26` | bamboo/gate/wet-dry evidence and house-anchor docs |

## Test evidence (Godot 4.7.1, isolated `HOME`)

All CLI runs used `PATH=/tmp/opencode/phoenix-bin:$PATH`
(`Godot_v4.7.1-stable_linux.arm64`, `4.7.1.stable.official.a13da4feb`) and a
fresh temporary `HOME`. `./tools/verify-clean.sh` archives committed `HEAD`.

| Check | Command | Result |
| --- | --- | --- |
| Clean verifier | `./tools/verify-clean.sh` | **exit 0**: import, GUT **635/635** (51,152 asserts; includes the 3 focused driver regressions), project smoke, world-math smoke, terrain-stamp drift (35 sources / 1,542 tiles / 1,920 cells), world-shell smoke (`48x40`, 47 props, 85 fences, 8 decor, 6 bamboo clumps, 3-plank PierDeck), audio |
| GdUnit4 | `GODOT_BIN=... xvfb-run -a ./addons/gdUnit4/runtest.sh -a tests/gdunit -c` | **16/16**, 0 errors/failures/orphans |
| Driver regression | `godot ... -gtest=res://tests/integration/test_mcp_acceptance_driver.gd -gexit` | **3/3**, 33 asserts; failed seek returns false, releases input, keeps Error and no At_ marker; input-facing succeeds |
| godot-e2e, individual suites | same harness with `-a tests/e2e/world_readability_test.gd` and `-a tests/e2e/gameplay_day_one_test.gd` | `world_readability` **1/1 pass** (29.1 s); `gameplay_day_one` **7/7 pass** (2 min 42 s) |
| godot-e2e, full lane | `... -a tests/e2e -c` (three runs) | **exit 100 all three times**; 13 cases. Runs 1–2: 3 errors / 85 failures; run 3 (lower host load): 1 error / 21 failures. The failing set varies inside `gameplay_day_one_test` (`held_row`, `player_moves`, `travel_overlay`, `observe`); `app_launch` 3/3, `market_confirm` 1/1, `ui_navigation` 1/1 and `world_readability` 1/1 passed in every run. Every failure begins with `Command 'wait_seconds' timed out after 1300–1600 ms` followed by `E2E session is not open`; no map/decor assertion failed. Each affected suite passes alone. The suspected cause is host CPU/llvmpipe frame latency under unrelated load, but that is **not proven**: no profiler or frame-time trace was captured, and the failing subset changes between runs. |


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
   `ClockOff`, `ToggleUI`, then the route buttons. Run A/B used
   `WalkField`, `Action`, `WalkBin`, `Interact`, `Cancel`, `WalkBed`,
   `Interact`, `Cancel`, `WalkFarmTruck`, `Interact`, `WalkShop`, `Interact`,
   `Cancel`, `WalkInert`, `Interact`, `WalkTownTruck`, `Interact`. Run C added
   `WalkUnreachable`. Run D added `CrossYardSouthGate`,
   `CrossFieldEastGate`, `WalkBambooA` and `WalkBambooB`.
5. Map swaps confirmed with `find_node` on
   `/root/McpAcceptanceDriver/App/World/FarmMap` / `TownMap`.
6. `capture_screenshot` for each pose; `get_runtime_state`/state markers and
   the native log recorded the live state. `stop_project` ended the session.
   The native run uses `test_output/mcp_acceptance/actions.jsonl`; GUT now sets
   `PHOENIX_MCP_LOG=user://mcp-driver-gut.jsonl`, so it can no longer overwrite
   the native log. Run C was observed live but its complete trace was not
   retained; Run D's 19-line full log is committed as
   `docs/superpowers/validation/hpa-863-mcp-captures/run-d-native-actions.jsonl`.

The driver is test-only and in `tests/native_tour/` (excluded from export). It
does not teleport or touch the session: each walk uses AStar waypoints, real
Input move actions and live collision; each `Action`/`Interact` sends the real
`use_action`/`interact` action, and a successful interact goto establishes the
final facing through one directional Input action.

Capture provenance by run:

- **Run A — main acceptance route (clock running).** New Game → skip prologue
  → field Space action → bin → bed → farm truck → town shop → inert station →
  town truck → farm return, with no clock override. Prompts were `[E] 出荷箱`
  (bin), `[E] 寝る` (bed), `[E] 町までドライブ` (farm truck), `[E] 種屋`
  (shop) and `[E] 家までドライブ` (town truck); field action changed stamina
  20→17; the inert station answered the red `調べられるものが無い` toast; the
  town arrived at 22:00 and the return was still legal at the cutoff. This run
  produced committed captures 04–12. It predates the input-facing driver fix
  (the old driver assigned `player.facing` directly).
- **Run B — clean capture pass (clock disabled).** New Game → skip →
  DismissTutorial → ClockOff → ToggleUI → front door → storehouse → bin
  approach. This is a partial visual pass, not the acceptance route; it
  produced committed captures 01–03 and the clean yard/door/storehouse views.
- **Run C — post-fix acceptance route (clock disabled).** Same route as Run A
  plus `WalkUnreachable`, after the input-facing/failure-propagation fix. The
  unreachable probe produced `Error` and no `At_unreachable`; front door, bed,
  bin, farm truck, shop and town truck all resolved with facing established
  via directional input (logs show `facing` after the input step), and the town
  round trip returned to `FarmMap`. Run C used `ClockOff`, so it proves the
  changed-map movement/interaction path but not the passive clock/cutoff again;
  those remain covered by Run A and the deterministic suites.
- **Run D — retained gate/bamboo trace (clock disabled).** After the final
  scene dressing, real-input `CrossYardSouthGate` walked
  `(23,13)->(23,14)->(23,16)` through the yard south gap, and
  `CrossFieldEastGate` walked `(22,20)->(21,20)->(20,20)` through the field
  east gap. `WalkBambooA`/`WalkBambooB` then walked to `(4,7)`/`(10,7)` and
  produced committed captures 13/14. The complete 19-line log is committed as
  `run-d-native-actions.jsonl`, so these crossings and approach walks no longer
  rely on an unretained trace.

The MCP game inherited the host Japanese locale, so HUD/modal copy in the
captures is Japanese.

Committed at `docs/superpowers/validation/hpa-863-mcp-captures/`:

| Capture | Run | Evidence |
| --- | --- | --- |
| `hpa863-mcp-01-day-one-yard.png` | B | Day 1, paused at 06:00, yard in front of the farmhouse |
| `hpa863-mcp-02-front-door-contact.png` | B | door-slice contact, `[E] 寝る`, HPA-743 house fade |
| `hpa863-mcp-03-storehouse-yard.png` | B | storehouse south contact; the fade there is the HPA-743 occluder, not lost art |
| `hpa863-mcp-04-field-action.png` | A | 30-cell field, Space till preview and post-action stamina 17 |
| `hpa863-mcp-05-shipping-bin.png` | A | full-cell bin opened the shipping panel |
| `hpa863-mcp-06-bed.png` | A | bed opened the 06:00 sleep confirmation |
| `hpa863-mcp-07-town-paving.png` | A | arrived town paving/truck/villagers, no tile rims |
| `hpa863-mcp-08-shop.png` | A | Seed Shop panel in town |
| `hpa863-mcp-09-inert-refusal.png` | A | station prop E refusal toast |
| `hpa863-mcp-10-farm-return.png` | A | return trip landed on the farm at `TRUCK_ARRIVAL` |
| `hpa863-mcp-11-camera-southwest.png` | A | farm SW camera extreme: continuous water/reeds/grass, no grey |
| `hpa863-mcp-12-camera-northeast.png` | A | farm NE camera extreme: continuous road/paddy/grass, no grey |
| `hpa863-mcp-13-bamboo-west.png` | D | real-input approach to `(4,7)`; west `(3,4,3,3)` grove visibly dressed by three bamboo clumps |
| `hpa863-mcp-14-bamboo-east.png` | D | real-input approach to `(10,7)`; east `(9,4,3,3)` grove visibly dressed by three bamboo clumps |

The earlier native-tour note (`2026-11-23-hpa-863-native-tour.md`) now covers
the seeded wet/dry field view (`hpa863-04b`), both bamboo grove approaches
(`hpa863-15/16`) and the unchanged crop/town/pier/Y-sort checks. None of the
MCP captures is a screenshot-golden test.

## Export PCK gate

On a temporary `git archive` of committed `HEAD` (`4250a26`) with the
host-only `textures/vram_compression/import_s3tc_bptc=true` added **only in
the temporary copy**, the unsigned macOS export produced a 94 MB ZIP with
`Phoenix.app/Contents/MacOS/Phoenix` and `Contents/Resources/Phoenix.pck`
(41 MB PCK). The PCK was extracted into an isolated directory and run as:

```bash
godot --headless --main-pack Phoenix.pck --script res://tools/export_pack_smoke.gd
```

Result: **exit 0, `export_pack_smoke: 6 scenes and 19 textures load from the
pack`** (app/world/farm/town, farm/town tilesets, crops, soil, ground phases,
multi-junctions, farmhouse/storehouse, bin, town buildings, player, truck,
villagers, shadow, bamboo). The gate also rejects the checkout-only canary and checks
both provenance folders: raw files (`README.md`, source sheets, transparent
intermediates) with `FileAccess.file_exists()`, imported resources with
`ResourceLoader.exists()`, and a recursive `DirAccess` scan rejects any packed
entry beneath them. A checkout-side probe confirms the raw paths exist in the
checkout but `.gdignore` prevents them from resolving as imported resources;
the exported PCK resolves none of them.

Negative control: the same `4250a26` archive with the provenance excludes
removed, both `.gdignore` files deleted and the raw Markdown include filter
enabled produced a 114 MB leaky ZIP. The same gate exited **1** with 28
provenance errors: raw `hpa-861-review/README.md`/`provenance/town-art-source.md`,
imported `farm-source.png`/`town-art-cutouts.png`/`town-truck-views.png`, and
recursive `packed entry beneath provenance:` lines for every packed source and
`.import` sidecar. This proves the positive gate is not vacuous.

## Cleanup

Removed after a live-reference search (historical notes under
`docs/superpowers` and `tests/visual` are retained as history, not runtime
references):

- top-level `proof-crops`, `proof-soil`, `proof-scenery`, `proof-villagers`;
- old `starting-farm-terrain.png` / `starting-farm-props.png` runtime atlases
  (the two `starting-farm-*-source.webp` source sheets moved to
  `assets/sprites/provenance/`);
- obsolete `town-props.png` / `town-terrain.png` runtime atlases, and the
  imported `town-art-source.webp` / `town-art-cutouts.png` /
  `town-truck-views.png` intermediates, moved to the same provenance folder;
- every review scene, preview, candidate atlas, `ground-v2` split/check image,
  `tiles/` split and extracted review cutout under
  `assets/sprites/hpa-861-review/`, plus its stale `.import` sidecars.

`assets/sprites/hpa-861-review/` now holds only 16 `*-source.png` generation
sheets, its prompt README and `.gdignore`. `assets/sprites/provenance/` holds
the legacy starting-farm sheets, the town source webp, its transparent
intermediates, `town-art-source.md` and `.gdignore`. `world-v2/` keeps the
promoted runtime art. Both provenance folders are export-excluded.

## Open blockers

- **CI has not run** on the final SHA; the coordinator owns the push and PR
  checks. No CI/`unit-tests`/`e2e-tests` lane is claimed green here.
- **Approved-image comparison unavailable** (Linear OAuth pending, no Linear
  MCP tool in this session). Geometry matches `approved-layout.json`; the
  visual comparison to the blockouts/`world-mockup-vs-game.jpg` is still open.
- **Full godot-e2e lane is red locally** (combined suite only) with the
  timing/`wait_seconds` pattern above; each affected suite passes alone. Host
  load/llvmpipe latency is the suspected cause, not a proven one.
- The MCP bridge runs 4.7.2 Mono; all CLI gates above use pinned 4.7.1.
