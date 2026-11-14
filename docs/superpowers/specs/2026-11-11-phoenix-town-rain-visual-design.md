# HPA-860 — Town rain streaks: design specification

**Status:** Revised after [PR #41 design review](https://github.com/cwchanap/phoenix/pull/41#pullrequestreview-5870418693) and **implemented** on `agent/hpa-860-town-rain-visual-plan` (PR #41, commits df08970 onward); this spec is the accepted design of record. Open acceptance items — final-HEAD verifier, remote CI/export, PR metadata and the human macOS live checks — are tracked in the implementation plan's checklist; see also `docs/superpowers/validation/2026-11-13-phoenix-town-rain-native-tour.md`.
**Linear:** https://linear.app/cwchanap/issue/HPA-860/show-existing-rain-streaks-in-town-without-farm-river-ripples
**Baseline:** `main` after HPA-546 / PR #40, inspected 2026-11-11 (Vancouver).
**Delivery:** One issue → one PR for the plan and subsequent implementation. Existing art and audio are sufficient.

## Player-visible outcome

Rain should continue visually when Kenji drives from a rainy farm to town, without flickering into clear weather. Both maps show the same subtle, camera-relative rain streaks while weather is rainy and neither shows streaks during sun. The river's three ripple sprites remain exclusive to the farm.

**Explicit audio decision:** Keep current audio routing unchanged. In particular, the existing `GameHud/RiverAmbience` stream plays in town as it does today, even though town has no river ripple sprites. This is an *accepted pre-existing audio limitation*, not a claim of full river ambience parity. Gate town river audio only in a separate, explicitly scoped follow-up if desired. Rain audio/tint remain HUD-owned and work across both maps.

Truck travel (30 in-game minutes), shop/social interactions, weather probabilities, stamina, time, camera, save schema, and localisation must not change.

## Verified code baseline and ownership

- `scripts/world/homestead_ambience.gd` currently combines two independent visual effects:
  - **Map-independent rain:** `_rain_offsets`, `render(snapshot)`, `is_rain_falling()`, `_process()`, `_draw()`, `_rain_span()`, `_world_view_size()`. Rain reads only the weather snapshot and active viewport camera (`WorldContract.CAMERA_ZOOM`).
  - **Farm-only river ripples:** `_ripple_cells`, `RIPPLE_TEXTURE`, `_add_ripple()`, `_start_ripple_loop()`, `_show_frame()`; anchors derive from `WorldContract.RIVER_*_FOOTPRINT`.
- `FarmMap` owns `HomesteadAmbience` at z=6; `TownMap` intentionally has no river/ambience node.
- `WorldShell.load_map()` swaps map nodes and reparents the same player/camera; `_refresh_from_session(snapshot)` currently calls `farm.ambience.render(snapshot)` only on the farm.
- `WorldShell` already owns a map-independent `TargetHighlight`, and `world.tscn` keeps `GameHud` outside either map. Existing HUD rain tint and audio follow the snapshot; river audio is not map-gated.
- PR #38 documents missing town rain as an accepted interim rendering difference; [PR #41 review](https://github.com/cwchanap/phoenix/pull/41#pullrequestreview-5870418693) identified the map ownership issue in the initial HPA-860 design.

## Accepted architecture — one persistent, shell-owned rain layer

1. **Extract, do not duplicate:** Move the rain-specific constants, offset initialization, snapshot rendering, update, camera-relative drawing and helper methods from `homestead_ambience.gd` into one new `scripts/world/rain_layer.gd` (`class_name RainLayer extends Node2D`). Preserve the 72 deterministic streaks, color/velocity, delta clamp, camera logic and existing behavior.
2. **Keep the farm class farm-only:** `HomesteadAmbience` retains only the existing river-ripple sprites and Tweens, and no longer has a `render(snapshot)` rain method. `scenes/world/farm_map.tscn` retains that node at z=7 (above shell `RainLayer` z=6, preserving the pre-HPA-860 ripples-over-rain appearance). `scenes/world/town_map.tscn` stays unchanged; it has no river ripples by construction. Do **not** add a `show_river_ripples` flag.
3. **Give rain the correct lifetime:** Add exactly one authored `RainLayer` node in `scenes/world/world.tscn`, z=6, after the persistent Player and before `TargetHighlight`. After `WorldShell.load_map()` moves the current map to index 0 and reparents Player into it, runtime World children are `[FarmMap|TownMap, RainLayer, TargetHighlight, GameHud]`. The rain node remains the same instance across swaps; its animation phase does not restart just because the destination changes.
4. **One direct refresh seam:** Add a typed `@onready var rain_layer: RainLayer = $RainLayer as RainLayer` in `WorldShell`. Call `rain_layer.render(snapshot)` unconditionally from `_refresh_from_session()`, outside the farm-only `FarmView.refresh(snapshot)` branch. `load_map()` already refreshes after map attachment and player/camera placement. There is no null-guarded map-node lookup and no silent skipped weather renderer.
5. **Preserve layering:** Rain at z=6 remains above ground/soil/effects (at or below z=5) and below farm `HomesteadAmbience` (z=7), shell `TargetHighlight` (z=10), and the map's Y-sorted `Entities` (z=20). Validate appearance near both maps' camera edges and after travel.
6. **No new infrastructure:** `GameSession` remains the sole weather authority, `GameHud` remains the only rain/river audio and weather-tint controller. No weather manager, signal bus, virtual `GameMap` method, extra map field or persisted state.

## Behavior contract

| Active map | Weather | Shell rain streaks | Map river ripples | Existing river audio |
| --- | --- | --- | --- | --- |
| Farm | Rainy | Visible, animated | Three | Playing as today |
| Farm | Sunny | Hidden | Three | Playing as today |
| Town | Rainy | Visible, animated | None | Playing as today (accepted limitation) |
| Town | Sunny | Hidden | None | Playing as today (accepted limitation) |

Only one `RainLayer` lives at `World/RainLayer`. Its active weather state is refreshed from the same session snapshot whether the map is farm or town. World state is not mutated by visuals.

## Files and test ownership

**Production:** `scripts/world/rain_layer.gd` (new), `scripts/world/homestead_ambience.gd` (ripples only), `scenes/world/world.tscn` (one persistent rain node), and `scripts/world/world_shell.gd` (typed reference + unconditional render). **No edit to `town_map.tscn` or `GameHud`.**

**Tests:**
- `tests/integration/test_gameplay_shell.gd`: migrate existing rain-state, refresh, missing-camera and presentation-nonmutation tests from `HomesteadAmbience` to `RainLayer` instead of duplicating them. Add just two end-to-end tests using the existing weather-restore and real-truck helpers: (1) rainy farm → town → farm, rain active at every point and same persistent `RainLayer`; (2) sunny farm → town, rain inactive on both. The new test should fail *semantically* against the old baseline using a scene-path lookup, not a yet-undefined `RainLayer` symbol. Existing ripple scene checks already cover farm-only ripple behavior.
- Update existing World child/order expectations from three to four in `tests/integration/test_gameplay_shell.gd` (farm reload, town travel) and `tests/headless/world_shell_smoke.gd`. Move the smoke rain/overlay z-order assertion to shell `RainLayer`, while keeping the farm ripple texture/count assertions.
- No new town-ripple runtime test (there is no ripple node in the authored town scene), no duplicate nonmutation test, no screenshot-golden infrastructure.

**After implementation:** Adjust the short, relevant historical limitation/ownership passages in `README.md` and `CLAUDE.md`, explicitly retaining the known town river-*audio* behavior. No `strings.csv` change.

## End-to-end acceptance

1. On **macOS**, inspect native Godot 4.7.1 at 1920×1080 in rainy/sunny farm and town. The same subtle rain remains animated across truck travel without weather flicker; camera movement, ground depth, player, villager, target, dialog, shop and market stay readable. Farm ripples remain and town has none. No HPA-860 UI mockup exists; compare visually with the previously accepted farm rain.
2. Automated tests prove shell rain state across real travel, both weather states and the persistent single renderer. Existing farm-ripple and HUD audio/tint tests continue passing; existing session/nonmutation test is migrated.
3. Gameplay, HUD audio (including pre-existing town river sound), localisation, save schema, travel and social/shop/finale behavior remain unchanged.
4. Run `./tools/verify-clean.sh` locally from committed HEAD. Existing PR CI must pass its verify+unsigned macOS export, GdUnit4 and godot-e2e lanes; verify the exported macOS package. No redundant local execution of every CI lane is required.
5. Exactly one HPA-860 draft→implementation PR. No new art, SFX, general weather framework or second renderer; Android/Linux manual acceptance is not required (CI only).

## Out of scope

New art/SFX, rain gameplay effects, town river-audio routing changes, shaders, weather balancing, puddles, indoor weather, camera redesign, state migration and additional rendering layers.
