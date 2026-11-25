# HPA-863 acceptance ledger — farm v2 world art

Date: 2026-11-23, updated 2026-11-25
Branch: `plan/hpa-863-farm-map-v2-world-art`
Status: **Implementation and local acceptance evidence recorded at `b0726f4`;
the approved blockout/mockup comparison and all four real-input yard/field gate
crossings are evidenced below. GitHub verify, GdUnit4 and godot-e2e are green
at `b0726f4` (runs `45655935184`, `45655935229`, `45655935443`). The local
combined godot-e2e lane timing caveat remains. This is agent-operated
evidence, not human acceptance.**
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
| `5b289b6` | final pack/gate evidence pinned to `4250a26` |
| `b405be7` | acceptance status wording |
| `c2d8741` | Z parity in the Y-sort draw-order helper |
| `804be45` | west/east yard gate crossings in the MCP driver + focused GUT route pin |
| `b0726f4` | native tour at the Y-sort head, house-rear pose, 19 captures, Run E log |

## Test evidence (Godot 4.7.1, isolated `HOME`)

All CLI runs used `PATH=/tmp/opencode/phoenix-bin:$PATH`
(`Godot_v4.7.1-stable_linux.arm64`, `4.7.1.stable.official.a13da4feb`) and a
fresh temporary `HOME`. `./tools/verify-clean.sh` archives committed `HEAD`.
Rows name the local head they were taken at; the CI lanes are reported
separately at `b0726f4`.

| Check | Command | Result |
| --- | --- | --- |
| Clean verifier (`b0726f4`) | `./tools/verify-clean.sh` | **exit 0**: import, GUT **640/640** (51,280 asserts; includes the 6 focused driver regressions), project smoke, world-math smoke, terrain-stamp drift (35 sources / 1,542 tiles / 1,920 cells), world-shell smoke (`48x40`, 47 props, 85 fences, 8 decor, 18 bamboo clumps, 3-plank PierDeck), audio |
| CI verify (`b0726f4`) | GitHub Actions `CI` run [45655935184](https://github.com/cwchanap/phoenix/actions/runs/45655935184) | **success** |
| GdUnit4 (`b405be7` local; `b0726f4` CI) | `GODOT_BIN=... xvfb-run -a ./addons/gdUnit4/runtest.sh -a tests/gdunit -c`; CI run [45655935229](https://github.com/cwchanap/phoenix/actions/runs/45655935229) | local **16/16**, 0 errors/failures/orphans; CI **success** |
| Driver regression (`b0726f4`) | `godot ... -gtest=res://tests/integration/test_mcp_acceptance_driver.gd -gexit` | **6/6**, 86 asserts; isolated playtest save/settings paths, busy held through the interact marker, failed seek returns false, releases input, keeps Error and no At_ marker; input-facing succeeds; west `(18,10)` and east `(30,11)` gate routes cross their gate cells |
| godot-e2e, individual suites (`b405be7` local; `b0726f4` CI) | same harness with `-a tests/e2e/world_readability_test.gd` and `-a tests/e2e/gameplay_day_one_test.gd`; CI run [45655935443](https://github.com/cwchanap/phoenix/actions/runs/45655935443) | `world_readability` **1/1 pass** (29.1 s); `gameplay_day_one` **7/7 pass** (2 min 42 s); CI **success** |
| godot-e2e, full lane (`b405be7` local) | `... -a tests/e2e -c` (three runs) | **exit 100 all three times**; 13 cases. Runs 1–2: 3 errors / 85 failures; run 3 (lower host load): 1 error / 21 failures. The failing set varies inside `gameplay_day_one_test` (`held_row`, `player_moves`, `travel_overlay`, `observe`); `app_launch` 3/3, `market_confirm` 1/1, `ui_navigation` 1/1 and `world_readability` 1/1 passed in every run. Every failure begins with `Command 'wait_seconds' timed out after 1300–1600 ms` followed by `E2E session is not open`; no map/decor assertion failed. Each affected suite passes alone, and the CI e2e lane at `b0726f4` passed. The suspected cause is host CPU/llvmpipe frame latency under unrelated load, but that is **not proven**: no profiler or frame-time trace was captured, and the failing subset changes between runs. |


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

## Approved layout and reference comparison

`.superpowers/sdd/2026-11-21-phoenix-farm-v2-world-art-implementation/approved-layout.json`
was re-checked on the committed tree: `48x40`, all 28 terrain entries in order
and spawn `(23.5,11.5)` match **exactly** (`approved layout match: true`).

On 2026-11-25 the approved HPA-863 references were retrieved through the
connected Linear MCP API (`get_attachment`, `format=content`) and inspected
locally at their native sizes:

| Attachment | Title | Size |
| --- | --- | --- |
| `d2d2251f-b0a7-4c74-8540-5d41eb6d341a` | front-door blockout under the HUD | 1920x1080 |
| `b04de7dd-1ede-426a-8cdd-5ee0cf77f072` | field blockout under the HUD | 1920x1080 |
| `44109c1c-8696-4483-8886-28bf62b0f99d` | storehouse-yard blockout under the HUD | 1920x1080 |
| `95176b99-d78c-4257-a639-08021c91604b` | `world-mockup-vs-game.jpg` | 2416x675 |

The native tour was re-run at `b0726f4` (19 captures, `TOUR|DONE clean
tour=hpa-863`, exit 0) and every capture below is from that run. The
comparison is visual, not pixel-golden:

| Reference | Current capture | Comparison |
| --- | --- | --- |
| Front-door blockout | `hpa863-01-farm-front-door-contact.png` | Same 3x3 farmhouse at the approved footprint, south door/bed cell, well to the west, storehouse to the east and the bamboo yard fence. The flat stand-in building is replaced by the final farmhouse art; the house stays opaque and the player is drawn in front of the south face, so the earlier faded-house-over-player pose is gone. The seeded Day 1 06:11 HUD differs from the reference's Day 3 09:20 only by run state. |
| Front-door blockout, rear face | `hpa863-01b-farm-house-behind-contact.png` (new) | Player at the house's rear/west contact; the house correctly fades toward `FADE_ALPHA` over the player, confirming the rear-face HPA-743 behavior is unchanged by the SortProxy fix. |
| Field blockout | `hpa863-04-farm-field.png`, `hpa863-04b-farm-field-wet-dry.png` | Same 6x5 plot, wooden perimeter fence, east gate `(21,20..21)`, bin east of the gate, scarecrow and greenhouse. Final crop/soil art and the seeded three-kind crop grid replace the empty stand-in plot; wet frame 1 sits beside dry frame 0 in 04b. |
| Storehouse-yard blockout | `hpa863-03-farm-storehouse-yard.png` | Same kura `(12,8,5,4)`, five rope-marked lots, build board, well and yard fence. The player stands at a legal south front contact rather than the blockout's west eave pose; the contact shadow sits under the kura base and the player is drawn in front. |
| `world-mockup-vs-game.jpg` | all farm/town captures | Current captures show continuous ground and paths, no tile grid, no grass islands, no dotted town paving seams and no grey at the camera extremes, matching the mockup's structural target. The mockup's painted density is not reproduced pixel-for-pixel; this remains a visual check, not a golden test. |
| Approved plan (bamboo groves) | `hpa863-15-farm-bamboo-west.png`, `hpa863-16-farm-bamboo-east.png`, `hpa863-mcp-13/14` | Both 3x3 blocking groves are dressed with nine bamboo clumps each (18 total), with no invisible blockage. |

Retained deviations: the shipped art is the HPA-861 sprite-isometric set, not
the mockup's painted style; the blockouts are flat stand-ins; capture HUD
state differs by seeded day/time. No new art, SFX or pixel-golden gate was
added.

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
   `CrossFieldEastGate`, `WalkBambooA` and `WalkBambooB`. Run E added
   `CrossYardWestGate` and `CrossYardEastGate`. Run F re-walked
   `WalkBambooA`/`WalkBambooB`; Run G re-walked `WalkFrontDoor` and
   `WalkStorehouse`.
5. Map swaps confirmed with `find_node` on
   `/root/McpAcceptanceDriver/App/World/FarmMap` / `TownMap`.
6. `capture_screenshot` for each pose; `get_runtime_state`/state markers and
   the native log recorded the live state. `stop_project` ended the session.
   The native run uses `test_output/mcp_acceptance/actions.jsonl`; GUT now sets
   `PHOENIX_MCP_LOG=user://mcp-driver-gut.jsonl`, so it can no longer overwrite
   the native log. Run C was observed live but its complete trace was not
   retained; Run D's 19-line log, Run E's 25-line gate log, Run F's 9-line
   bamboo log and Run G's 9-line building-contact log are committed under
   `docs/superpowers/validation/hpa-863-mcp-captures/`.

The driver is test-only and in `tests/native_tour/` (excluded from export). It
configures the app with dedicated ignored playtest files
(`test_output/mcp_acceptance/playtest-save.json` and
`playtest-settings.cfg`), so confirming sleep or changing settings cannot replace
the developer's real save or preferences. It does not teleport or touch the
session: each walk uses AStar waypoints, real Input move actions and live
collision; each `Action`/`Interact` sends the real `use_action`/`interact`
action, and a successful interact goto establishes the final facing through one
directional Input action.

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
- **Run E — all four yard/field gates (clock disabled, `b0726f4`).** New Game →
  SkipIntro → EnglishUI → DismissTutorial → ClockOff → ToggleUI, then the four
  gate buttons. The retained 25-line log records every waypoint:
  `CrossYardWestGate` `(19,10)->(18,10)->(17,10)`,
  `CrossYardEastGate` `(29,11)->(30,11)->(31,11)`,
  `CrossYardSouthGate` `(23,13)->(23,14)->(23,15)->(23,16)` and
  `CrossFieldEastGate` `(22,20)->(21,20)->(20,20)`. All four emitted a
  `gate_crossing` event with no `walk_error`; the log is committed as
  `run-e-native-actions.jsonl`.
- **Run F — grove refresh (clock disabled, `b0726f4`).** New Game → SkipIntro →
  EnglishUI → ClockOff → ToggleUI → `WalkBambooA` `(23,11)..(4,7)` →
  `WalkBambooB` `(4,7)..(10,7)`. The west approach also crosses the west-yard
  gate `(18,10)` through real input. Captures 13/14 were replaced with the
  18-clump views; the 9-line log is committed as `run-f-native-bamboo.jsonl`.
- **Run G — building-contact refresh (clock disabled, `b0726f4`).** New Game →
  SkipIntro → EnglishUI → ClockOff → ToggleUI → `WalkFrontDoor`
  `(23,11)->(23,10)` → `WalkStorehouse` `(23,10)..(14,12)` (through the west
  yard gate). Captures 02/03 were replaced: the farmhouse and storehouse stay
  opaque and the player draws in front of their south faces. The 9-line log is
  committed as `run-g-native-building-contacts.jsonl`.

The MCP game inherited the host Japanese locale for Runs A/B/C/D, so their
HUD/modal copy is Japanese. Runs E/F/G pressed `EnglishUI`, so the refreshed
captures 02/03/13/14 show English copy.

Committed at `docs/superpowers/validation/hpa-863-mcp-captures/`:

| Capture | Run | Evidence |
| --- | --- | --- |
| `hpa863-mcp-01-day-one-yard.png` | B | Day 1, paused at 06:00, yard in front of the farmhouse |
| `hpa863-mcp-02-front-door-contact.png` | G | door-slice contact, `[E] Go to bed`, farmhouse opaque with the player drawn in front |
| `hpa863-mcp-03-storehouse-yard.png` | G | storehouse south contact; storehouse opaque with the player drawn in front |
| `hpa863-mcp-04-field-action.png` | A | 30-cell field, Space till preview and post-action stamina 17 |
| `hpa863-mcp-05-shipping-bin.png` | A | full-cell bin opened the shipping panel |
| `hpa863-mcp-06-bed.png` | A | bed opened the 06:00 sleep confirmation |
| `hpa863-mcp-07-town-paving.png` | A | arrived town paving/truck/villagers, no tile rims |
| `hpa863-mcp-08-shop.png` | A | Seed Shop panel in town |
| `hpa863-mcp-09-inert-refusal.png` | A | station prop E refusal toast |
| `hpa863-mcp-10-farm-return.png` | A | return trip landed on the farm at `TRUCK_ARRIVAL` |
| `hpa863-mcp-11-camera-southwest.png` | A | farm SW camera extreme: continuous water/reeds/grass, no grey |
| `hpa863-mcp-12-camera-northeast.png` | A | farm NE camera extreme: continuous road/paddy/grass, no grey |
| `hpa863-mcp-13-bamboo-west.png` | F | real-input approach to `(4,7)`; west `(3,4,3,3)` grove dressed by nine bamboo clumps |
| `hpa863-mcp-14-bamboo-east.png` | F | real-input approach to `(10,7)`; east `(9,4,3,3)` grove dressed by nine bamboo clumps |

The earlier native-tour note (`2026-11-23-hpa-863-native-tour.md`) now covers
the seeded wet/dry field view (`hpa863-04b`), both bamboo grove approaches
(`hpa863-15/16`), explicit top/bottom camera-limit captures (`hpa863-14/17`)
and the unchanged crop/town/pier/Y-sort checks. None of the MCP captures is a
screenshot-golden test.

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

Post-ledger CI check on `b405be7`: [CI run
45438164076](https://github.com/cwchanap/phoenix/actions/runs/45438164076)
exported the unmodified checkout — no temporary S3TC/BPTC import override —
and its `Verify exported PCK` step passed with
`export_pack_smoke: 6 scenes and 19 textures load from the pack`. The local
override recorded above was therefore host-specific evidence only, not a
release-export requirement.

CI re-check at `b0726f4`: [CI run
45655935184](https://github.com/cwchanap/phoenix/actions/runs/45655935184)
completed with `success`; its `Verify exported PCK loads its world resources`
step also passed on the unmodified checkout.

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

## Open blockers and caveats

- **No acceptance blocker remains at `b0726f4`.** GitHub verify, GdUnit4 and
  godot-e2e are green (runs `45655935184`, `45655935229`, `45655935443`), the
  approved reference comparison is recorded above, and Run E evidences all
  four real-input yard/field gate crossings.
- **Local combined godot-e2e lane timing caveat.** The combined suite was red
  locally with the `wait_seconds`/`E2E session is not open` pattern above;
  each affected suite passes alone. CI run
  [45655935443](https://github.com/cwchanap/phoenix/actions/runs/45655935443)
  passed the lane at `b0726f4`, so the remaining question is local host
  latency, not a proven product regression.
- The MCP bridge runs 4.7.2 Mono; all CLI gates above use pinned 4.7.1.
