# HPA-860 — Town rain streaks: single-PR implementation plan

**Status:** Planning only. No code or tests implemented in the draft PR yet.
**Design:** [HPA-860 town rain design](../specs/2026-11-11-phoenix-town-rain-visual-design.md)
**Issue:** https://linear.app/cwchanap/issue/HPA-860/show-existing-rain-streaks-in-town-without-farm-river-ripples
**Branch:** `agent/hpa-860-town-rain-visual-plan`
**PR strategy:** Keep this draft PR as the sole implementation PR for HPA-860; after design review, add focused implementation commits to the same branch. No separate planning-versus-code PR.

## Task 1 — Assert the missing player-visible behavior (red)

- In `tests/integration/test_gameplay_shell.gd`, use the existing `_world()`, `_restore_weather(world, &"rainy")`, `_drive_to_town(world)`, and `_drive_home(world)` helpers. Call `world._refresh_from_session()` after test-only weather restoration.
- Assert the farm `HomesteadAmbience.is_rain_falling()` is true and retains three `RiverRipple*` children. After truck travel, assert a `TownMap/HomesteadAmbience` child exists, is raining, and has zero river-ripple children. Drive home and assert a fresh active farm ambience is raining with three ripple children.
- Add the sunny counterpart: no rain in either map, town still lacks ripple children, farm still has three. Assert the session snapshot is not mutated by an ambience refresh.
- Write tests via scene-path lookups rather than referencing a not-yet-existing `TownMap.ambience` property: the initial failure must be the missing town node, not a GDScript compile error.
- Run the focused GUT tests first and record a red baseline. Keep passive clock disabled through existing fixture behavior.

**Done when:** Focused regression fails against current `main` solely because town rain is missing; farm asserts still pass.

## Task 2 — Reuse the existing visual implementation

- In `scripts/world/homestead_ambience.gd`, add `@export var show_river_ripples: bool = true`. Keep the existing rain streak constants and camera-followed `_draw()` intact. Guard `_add_ripple()` setup in `_ready()` with this flag.
- In `scenes/world/town_map.tscn`, add a `HomesteadAmbience` direct child that uses the same existing script, z-index 6, `show_river_ripples = false`. Do not include ripple sprites/Tweens, audio nodes, or new art.
- In `WorldShell._refresh_from_session()`, keep `FarmView.refresh(snapshot)` on farm only, but render the active map's ambience using the shared child name. Do not duplicate the map's weather state or modify `GameSession`.
- Confirm `WorldShell.load_map()` invokes the refresh only after instantiating the new map and reparenting the Player, and `GameHud.render(snapshot)` remains the sole audio/tint controller.

**Done when:** Focused rainy/sunny and travel tests go green, and existing farm ambience tests remain green.

## Task 3 — Pin scene contract and documentation

- Add a narrow scene-smoke assertion if the existing world-shell smoke has a suitable town-map entry point: one town ambience, correct script/ripple flag/z-index, no extra world-root child. Avoid a second full weather state test there.
- Update `README.md` to say that rainy visuals now display on both maps while river ripples remain farm-only. Update the `CLAUDE.md` map and refresh ownership notes. No strings.csv edits.
- Check that other tests' existing expectations for `World` having exactly three children remain unchanged (the new visual node is below `TownMap`, not `World`).

**Done when:** Scene ownership and handoff docs match the implementation without expanding scope.

## Task 4 — Verify end to end and mark the PR ready

- Run `./tools/verify-clean.sh` from a clean committed HEAD. Follow the repository's isolated HOME handling to avoid touching real player saves/settings.
- Run the separate GdUnit4 and godot-e2e lanes (the existing project commands); run `godot --headless --path . --import` and `godot --headless --path . --export-release "macOS" build/Phoenix.zip`.
- On **macOS**, launch the game in Godot 4.7.1 at native 1920x1080 and visually compare rainy farm, rainy town, rainy return, sunny farm, and sunny town. Verify the truck, player/target depth, villagers, shop, market, HUD and modals still look correct. Inspect at least one near-screen-edge view so the rain follows camera movement without gaps. No mockup is attached to HPA-860; existing farm rainfall is the visual reference.
- CI covers other targets. No Android/Linux manual acceptance and no additional art/SFX ticket.
- Update the same PR with test evidence, screenshots or clear visual observations, and any small review-driven corrections; only then mark it ready for review.

**Done when:** All verification gates pass, subjective macOS visual inspection is recorded, and the ticket's acceptance criteria are satisfied.

## Scope guard and acceptance checklist

- [ ] Rain renders on rainy farm and rainy town; is absent on sunny farm and town.
- [ ] Farm retains exactly three river-ripple sprites; town has none.
- [ ] Truck travel rebinds the correct current-session weather and leaves no duplicate rain node.
- [ ] The existing HUD rain audio/tint, gameplay, locale strings, saves and market/social routes are unchanged.
- [ ] Headless/GUT, GdUnit4, godot-e2e and macOS export are green.
- [ ] macOS native 1080p visual check is recorded.
- [ ] One HPA-860 PR; no new assets, no framework changes, no extra PR.

The initial draft PR intentionally contains only this plan and the design document. It must not claim code delivery or passing tests.
