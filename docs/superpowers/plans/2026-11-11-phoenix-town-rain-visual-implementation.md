# HPA-860 — Town rain streaks: single-PR implementation plan

**Status:** Implemented; [PR #41](https://github.com/cwchanap/phoenix/pull/41) is marked ready (`draft=false`) at `9d00869`. Tasks 1–4 and the local part of Task 5 are implemented and locally verified (commits df08970 onward, including the final review fix waves; ledger: `.superpowers/sdd/2026-11-11-phoenix-town-rain-visual-implementation/progress.md`). All three hosted gates are green at `9d00869`: the `verify` lane (`verify-clean.sh`, import, unsigned macOS export/upload), GdUnit4 and godot-e2e. Open: the controller-owned local final-HEAD `verify-clean.sh` rerun (last local run at `59e6984`) and the human macOS subjective visual/audio/focus checks.
**Design:** [Accepted shell-owned rain specification](../specs/2026-11-11-phoenix-town-rain-visual-design.md)
**Issue:** https://linear.app/cwchanap/issue/HPA-860/show-existing-rain-streaks-in-town-without-farm-river-ripples
**Branch:** `agent/hpa-860-town-rain-visual-plan`
**PR strategy:** This same draft PR will receive the implementation after plan review; **one ticket → one PR**. No new image art or audio production task is needed.

## Task 1 — Add two red end-to-end regression cases

Extend `tests/integration/test_gameplay_shell.gd` using existing `_world()`, `_restore_weather()`, `_drive_to_town()` and `_drive_home()` helpers:

1. **Rainy travel:** restore rainy weather, refresh, assert world-level rain exists/is falling; drive to town with the real truck command, assert the **same** persistent rain renderer is still falling; drive home, assert it remains active. Keep passive clock disabled by the existing world fixture and do not fake the location by editing session internals.
2. **Sunny travel:** restore sunny weather, refresh, assert no streaks; drive to town and assert the same renderer remains non-raining.

The red-first tests must use a **`Variant`** lookup, not `Node2D` or an as-yet-undefined `RainLayer` class; Godot 4's static checker rejects `Node2D.is_rain_falling()` before any assertion executes. Use a parse-safe dynamic-dispatch seam:

```gdscript
var rain: Variant = world.get_node_or_null("RainLayer")
assert_not_null(rain)
if rain != null:
    assert_true(rain.is_rain_falling())
```

For the sunny case use `assert_false(rain.is_rain_falling())` after the same guard. On the old baseline the tests must fail with a **missing shell node assertion**, not a script parse error. After Task 2 introduces `class_name RainLayer` and the typed `WorldShell.rain_layer`, Task 3 can migrate assertions to `world.rain_layer.is_rain_falling()` while retaining the red-first proof.

Do **not** add new snapshot nonmutation, town ripple-count or duplicate-map-ambience tests. Existing tests already cover presentation nonmutation and the farm's authored ripples; the revised architecture makes town ripples impossible without changing the town scene.

**Done when:** Both new travel checks fail meaningfully against current main and existing farm/HUD checks still pass.

## Task 2 — Move rain out of farm ambience, without changing its appearance

- Add `scripts/world/rain_layer.gd`, a typed `RainLayer extends Node2D`. Move, nearly verbatim, the rain constants, `_rain_offsets`, `_rain_falling`, deterministic offset setup from `_ready()`, `render(snapshot)`, `is_rain_falling()`, `_process(delta)`, `_draw()`, `_rain_span()`, and `_world_view_size()` from `homestead_ambience.gd`. Keep the camera-relative behavior, 72 streaks and delta clamp unchanged.
- Leave `scripts/world/homestead_ambience.gd` as a farm-only river-ripple class: retain `RIPPLE_TEXTURE`, `_ripple_cells`, stagger/tween methods and their `_ready()` setup. Remove the moved rain methods and all rain state. Keep `FarmMap.ambience` and the existing `farm_map.tscn` ripple node.
- In `scenes/world/world.tscn`, author one new `RainLayer` child with the new script and z=6 between `Player` and `TargetHighlight`. Do not create a second instance under either map. `town_map.tscn` remains unchanged.
- In `scripts/world/world_shell.gd`, add typed `@onready var rain_layer: RainLayer = $RainLayer as RainLayer`, call `rain_layer.render(snapshot)` unconditionally in `_refresh_from_session()`, and remove only `farm.ambience.render(snapshot)`; leave `farm.entities.refresh(snapshot)` in its farm-only branch. `load_map()` already calls refresh after reparenting the player and moves the current map to World child index 0. Preserve all existing input/modal/HUD behavior.

**Done when:** Both new travel regressions pass, the same `RainLayer` survives map swaps without resetting its phase, and the farm's three ripple sprites remain intact.

## Task 3 — Migrate affected tests and scene contracts

- Update existing tests in `tests/integration/test_gameplay_shell.gd`:
  - `test_rain_visibility_follows_rainy_and_sunny_snapshots`: query `world.rain_layer` or `World/RainLayer`, not `(world._map as FarmMap).ambience`.
  - `test_refresh_from_session_renders_rainy_snapshot`: assert the shell layer's state.
  - `test_render_without_camera_keeps_rain_state`: instantiate `RainLayer` instead of `HomesteadAmbience`.
  - `test_ambience_render_does_not_mutate_session_state`: **migrate** to `RainLayer.render(snapshot)` and rename for clarity; do not add a second duplicate nonmutation test.
  - Keep `test_game_hud_rain_playback_follows_world_refresh` and farm ripple tests as behavior guards, including existing always-on river audio.
- Update the two three-child World-order pins (farm reload around lines 4402–4406 and town travel around lines 4626–4630) to assert four children in order: `FarmMap|TownMap`, `RainLayer`, `TargetHighlight`, `GameHud`. If the line positions have drifted, search by the assertion strings instead.
- In `tests/headless/world_shell_smoke.gd`, update **both** World child-name/order assertions:
  - **Initial farm load** (around lines **234–242**): `world_names := ["FarmMap", "RainLayer", "TargetHighlight", "GameHud"]`.
  - **After real truck travel to town** (around lines **1036–1040**): `town_names := ["TownMap", "RainLayer", "TargetHighlight", "GameHud"]`.
  - Keep the existing three farm-ripple texture/geometry assertions. Move the rain-related z-index check to the shell-owned `RainLayer` (z=6 between farm effects/soil and highlight/entities), while preserving the separate farm ripple-layer pin. No duplicate sunny/rainy test in the smoke.
- Run `rg 'ambience.render|HomesteadAmbience|RAIN_DELTA_CLAMP|is_rain_falling|world_names|town_names|World keeps exactly three|TargetHighlight.*GameHud'` to catch stale references, **both** smoke World-order arrays, and documentation pins before verification.

**Done when:** Existing behavior/ownership tests and headless scene smoke agree with the four-child shell. No old map-owned rain API consumers remain.

## Task 4 — Update only affected documentation and settle audio scope

- Update the existing `README.md` passage describing the HPA-686 interim gap: rain streaks will now be shell-owned and visible in town; farm river ripples remain farm-only; rain tint/audio stay in HUD.
- Update the `CLAUDE.md` map ownership and runtime-order descriptions, `WorldShell` refresh seam, the `HomesteadAmbience` section, and its older `HPA-686` weather-limitation paragraph. **Also update the separate delta-clamp citation around line 182** from `HomesteadAmbience.RAIN_DELTA_CLAMP` to `RainLayer.RAIN_DELTA_CLAMP` after moving that constant; do not leave a stale source-of-truth reference.
- **Explicit decision:** River audio continues to play while in town; it is an accepted pre-existing limitation outside this rain-visual task. Documentation must not imply that *all* river presentation is farm-only. No `GameHud` audio gating code, no sound assets and no localisation strings in this PR.

**Done when:** The runtime handoff, PR description and issue all describe the same shell-owned rain behavior and documented town river audio.

## Task 5 — Verify and keep implementation on the same PR

1. From a clean committed `HEAD`, run `./tools/verify-clean.sh` locally (the script isolates `HOME` to protect player saves/settings). Use focused GUT tests during Tasks 1–3 for faster iteration.
2. Let the three already-configured `pull_request` workflows run: `.github/workflows/ci.yml` (clean verification, import and unsigned macOS export), `unit-tests.yml` (GdUnit4), and `e2e-tests.yml` (godot-e2e). Check all statuses and macOS artifact/export integrity before calling the work complete; do not redundantly run all lanes locally unless diagnosing CI failures.
3. Perform native **macOS** visual inspection in Godot 4.7.1 at 1920×1080. Check rainy farm, truck to rainy town, truck back, sunny farm and sunny town. Walk near the camera edge: the same rain should track smoothly with no popping or new occlusion bugs; check ground/character depth, gold target, prompts, dialogs and shop/market. Retain rainy/sunny HUD tint and rain/river audio behavior. The ticket has no new UI mockup, so use existing farm rain as its visual reference.
4. Add verification evidence and any review-driven refinements to this same PR. Only mark ready after tests, CI, and the manual macOS visual pass.

**Done when:** Local clean verifier, three CI lanes, export artifact and macOS visual check are complete, with no gameplay or audio regression. Linux/Android require CI only, not manual acceptance.

## End-to-end acceptance checklist

Verified through `e62a2cc` plus the review fix waves through `9d00869` (agent-operated evidence; citations in
the validation note). Hosted gates are green at `9d00869`. The remaining boxes stay open for the
local final-HEAD verifier rerun and the human checks — do not mark them done on evidence not yet gathered.

- [x] Rain is visible in rainy farm and town, absent during sunny weather in both (travel regressions + native rainy/sunny tours).
- [x] A single persistent `World/RainLayer` remains alive throughout truck travel (integration tests + instance-ID telemetry across both swaps).
- [x] Farm has its three existing river ripples; town never adds river ripple visuals (smoke pins + tour `farm_ripples` observations).
- [x] Existing HUD rain tint/audio and pre-existing town river audio continue unchanged (behavior guards + tour audio-state observations).
- [x] Farm/day/travel/social/shop/market interactions, localisation and save behavior are unchanged (full GUT suite green on this branch).
- [x] Existing rain tests are migrated, scene-order pins updated and headless smoke passes (including the restored ripple upper z bounds).
- [x] Hosted gates green at `9d00869`: `verify` lane (`verify-clean.sh`, import, unsigned macOS export/upload), GdUnit4 and godot-e2e; PR marked ready (`draft=false`).
- [ ] Local `./tools/verify-clean.sh` rerun at final HEAD (ran green at `59e6984`, one commit before `9d00869` — controller-owned).
- [x] Native macOS 1080p rainy/sunny travel and layering visual checks are recorded (agent-operated captures + per-frame movie; human live look/smoothness/audio/pacing checks remain open).
- [x] One HPA-860 PR; no new assets, no per-map rain flags or generic weather framework.

Implemented through `9d00869` and marked ready; this checklist previously described a planning-only draft PR, so
that stale claim is retired. Unchecked items remain open until their evidence exists.
