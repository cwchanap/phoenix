# HPA-264 — Target-Driven Farming Action Design

**Linear:** https://linear.app/cwchanap/issue/HPA-264/gameplay-polish-make-space-pick-the-farming-action-from-the-target  
**Repository:** cwchanap/phoenix (Godot 4.7.1 / typed GDScript)  
**Delivery:** design review first, then implementation and validation on this *same* draft PR.  
**Dependency:** HPA-353 completed; SessionStateValidator now owns persisted-state checks.  
**Status:** planning proposal; no runtime code changed in this document commit.

## Product decision

Press Space on a farm cell to do the obvious next thing. The selected *seed kind*, not a selected *tool*, is the only farming choice. On an untilled farm cell: Hoe. On tilled, crop-free soil: plant selected seed. On a growing crop: Water. On a mature crop: Harvest. Do not auto-switch to another seed if the chosen kind has no stock.

| Target state | Resolved FarmingAction | Successful code | Blocked examples |
| --- | --- | --- | --- |
| Untilled farm tile | HOE | SOIL_TILLED | ACTION_TOO_LATE, INSUFFICIENT_STAMINA |
| Tilled, no crop | SEEDS | CROP_PLANTED | NO_SELECTED_SEEDS, time/stamina |
| Immature planted crop | WATERING_CAN | CROP_WATERED | ALREADY_WATERED, RAIN_WATERS_CROPS, time/stamina |
| Mature planted crop | HANDS | CROP_HARVESTED | time/stamina |
| Non-farm cell | no action | — | NO_TARGET / NOT_FARM_CELL, as today |

Resolve *which* action to use from the tile before asking whether that action can succeed. Thus already-watered/rainy crops still resolve to Water and display the truthful reason they cannot be worked. The mature state wins over Water, even if watered. Seed depletion must never make a tilled cell turn back into Hoe.

## Existing code / reuse survey (main, 2026-10-25)

- scripts/game/game_session.gd owns the private farm array, four action-specific failure checkers and commands, preview_selected_action(), apply_selected_action(), selected seed, and effective-cost seam _cost_for(). It currently stores selected_action in both state() and snapshot(), restores it, and dispatches by that field.
- scripts/game/session_state_validator.gd validates selected_action as a required field. Its state_error() checks required fields but does **not** reject arbitrary surplus top-level keys.
- scripts/world/world_shell.gd already renders target previews, executes commands and FarmActionEffects with a premutation crop preview, and owns the 0.15-second hold-to-work gesture. It currently changes the chosen tool on 1/2/3/4 and cancels held gestures on selection changes.
- scripts/ui/game_hud.gd and scenes/ui/game_hud.tscn already draw four action icons, seed buttons/badges and the Efficient Can icon. The HUD's farming_preview_text() consumes the existing preview {code, action, crop, cost} contract. Avoid a second toolbar model.
- project.godot maps select_hoe, select_seeds, select_water, select_hands; ContentRules.TUTORIALS and README/CLAUDE describe these old controls.
- Tests already exist at tests/unit/test_game_session.gd, tests/integration/test_gameplay_shell.gd, tests/e2e/gameplay_day_one_test.gd, tests/headless/world_shell_smoke.gd and tests/visual. Adapt those instead of creating a second testing harness.

## Domain / command contract

Add **one** private GameSession action resolver, e.g. _action_for_target(target_cell: Variant) -> Variant (a FarmingAction integer, or null for non-farm). Read the authoritative _farm tile and GameRules.is_mature(); do not cache action in GameSession or persist it.

Retain preview_selected_action(target_cell) and apply_selected_action(target_cell) as the stable WorldShell call sites. Both obtain the action from the same resolver. Preview returns the same four keys (code, action, crop, cost), with action=null, crop=null and cost={} on a non-farm/missing target. Preview uses existing _hoe_failure/_plant_failure/_water_failure/_harvest_failure, _cost_for() and existing CommandCode success values. The action-specific command still owns mutation and budget checks; do not duplicate farming mutations or build a new command framework. Keep the active-day/finale guard's precedence over target failures.

Remove _selected_action, select_action(), and the selected-action failure switch in GameSession. Retain FarmingAction and ACTION_KEYS for action-specific rules / HUD presentation. Remove the obsolete ACTION_SELECTED response handling only after checking usages; do not disturb other command codes or their semantics without test coverage.

For non-farm targets preserve NO_TARGET vs NOT_FARM_CELL and the current WorldShell interaction hints for shop, bed, shipping, villagers and market. Never invoke an action-specific failure checker with an invalid farm index.

## Held Space: lock action per gesture, not per cell

The first **fresh** Space press captures the resolved action in WorldShell._action_hold_action (nullable), *before* executing the first command. WorldShell._advance_action_hold() still requires its existing target dwell and success preview, but also requires preview.action == _action_hold_action. The one-shot press dispatch is unchanged; subsequent held work runs only on new cells eligible for the same action. In particular, an already-tilled cell now previews Seeds but a Hoe-locked hold must not plant it (including if the player dwells there). Continue using the existing just-worked-cell-ineligible-by-rules assumption and dwell/target tracking; no action queue or visited-cell set.

Fresh release resets the held action and target/dwell values. A seed change or modal/focus gate cancels the gesture as before. Start on a non-farm target: lock null, never mutate any subsequent farm cell in that gesture. Start on a blocked but valid farm cell: lock its resolved tool but do not mutate until encountering an eligible matching tile. Native single-press and E2E hold paths must agree.

## UI and control changes

- Keep the authored four icons and Efficient Can image. They become a **read-only indication** of the currently faced farm tile's resolved action, not selectable tools. Remove action-button pressed callbacks / select_action_requested wiring. Preserve the seed-kind buttons and their badges as the only interactive farming selection controls; use 2 to cycle Turnip → Potato → Pumpkin → Turnip on every press, including the first.
- Pass the current target's preview.action from WorldShell to a small transient GameHud setter when it changes (or a no-op setter that compares values). Do **not** call full hud.render() every frame or store resolved action in the save/snapshot. On non-farm/missing targets and while input is gated, highlight no action; preserve context interaction hints. Keep seed selection and Efficient Can icon driven by normal snapshot renders.
- Keep the existing green/red target tint and actionable hint from preview.code. Update authored keyboard legends (1/3/4 no longer select tools) and the seed-cycle hint in the scene.
- Update ContentRules.TUTORIALS copy: Space on bare soil, then Space to plant, Space to water on sunny unwatered growth, and Space to harvest when mature. Keep tutorial progress IDs and completion CommandCodes unchanged. No tutorial migration.

## Persistence contract: intentional old-save rejection

Delete selected_action from GameSession.state(), snapshot(), restore_state() and all state/snapshot fixtures. Continue persisting selected_seed. In SessionStateValidator.state_error(), remove the required selected_action check **and explicitly reject a state that still contains the retired selected_action field**, returning a concise incompatible-state error. This is necessary because the validator is not generally strict about surplus top-level fields: removing the requirement alone would accidentally accept legacy saves. No format migration, generalized strict-schema overhaul, SaveFileCodec rewrite, or backup behavior. Continue uses the existing validation-error path to disable incompatible saves, and New Game remains playable.

Keep the current save-file envelope/schema version for this deliberate no-migration prototype break; add tests that a fresh new-format state is accepted, a legacy-shaped state is rejected and restore_state() does not partially mutate on rejection.

## Acceptance / evidence

1. Rule tests: all four target states; no target/non-farm; nonselected seed stock; already-watered and rainy failure; insufficient time/stamina; premutation harvest crop; Efficient Can cost; preview nonmutating and matching actual command outcome.
2. World tests: hint/tint vs actual action, seed cycling and badge, non-interactive toolbar, modal gate, retained crop effects and contextual E hints.
3. Hold test: one continuous held Space sweeps three untilled cells, tills exactly those three and plants **zero**; another fresh gesture plants the three, another waters them; switching seed cancels hold.
4. Update the real GdUnit4 e2e Day 1 test and its held-row test, which currently click Action_0/1/2 buttons. Keep genuine key events/target movement and the save-isolation assertion.
5. Remove stale action-key assertions in world_shell_smoke; keep key 2 mapped. Update snapshot exact-key/order tests, visual fixture(s), README/CLAUDE controls.
6. Run ./tools/verify-clean.sh on committed HEAD, Godot/GdUnit4 unit + E2E, relevant headless smoke and visual comparisons. Re-bless **only** affected production goldens on macOS using ./tools/verify-visual.sh (CI cannot bless), and record evidence. No existing tests or native visual checks have been run for this planning-only PR.

## Explicit non-goals

Mouse farming, area actions, moving to targets automatically, opportunistic seed selection, additional crop mechanics, new save-migration layer, extra services/state owners, new art/audio, and changes to HPA-351/HPA-352. One issue → one PR.
