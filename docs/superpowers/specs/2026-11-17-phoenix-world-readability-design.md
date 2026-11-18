# HPA-743 — Make the world easy to use and read: design specification

**Status:** Proposed, docs-only draft; implementation and verification will be added to this same PR.  
**Issue:** https://linear.app/cwchanap/issue/HPA-743/make-the-world-easy-to-use-and-read  
**Repository/base inspected:** `cwchanap/phoenix`, `main` at `39a25b2be357a121fe5d715ed347028cacdb347d` (17 Nov 2026 Vancouver).  
**Delivery:** One Linear ticket = one PR, including this design, implementation and evidence.

## Outcome and source of truth

A player who approaches an interactable from any reachable side and faces it can press E successfully on the first attempt; the prompt and target diamond agree with that E action. The player stays visible when a foreground prop overlaps the player sprite. The farm camera no longer exposes grey void outside the authored 24×20 playable map, and the east road visibly continues. The farm's collision, camera, and farming gameplay are unchanged.

Source: 15 Nov UAT in HPA-743, including the target/occlusion screenshots and **B2** side-by-side farm-edge mockup (plus HTML board `#b2`). B2 shows the grass-filled edge; the implementation must additionally continue the east dirt road using current terrain art. Compare native 1920×1080 captures visually against B2; this is *agent-operated* visual inspection, not a pixel-golden test.

## Existing architecture and constraints

- Standard Godot 4.7.1 / statically typed GDScript. `WorldShell` is the sole live session holder and world coordinator; `GameSession` is the rules authority. No save-schema, economy, time, or travel-rule changes.
- `PlayerController.current_target_cell()` uses `WorldMath.TARGET_OFFSETS` to find one exact logical farm cell; this is **correct for Space/farming**. `PlayerController._update_target()` currently paints that same cell's diamond even when `WorldShell` is displaying an E hint.
- `WorldShell._interactable(target)`, `_process()`, and `interact()` depend on the exact raw target. The shop, upgrade, shipping, sleep and market-confirmation HUD callbacks also read `current_target_cell()` later, when the modal is open. Fixing E alone would still cause the final domain command to fail.
- The farm/town interactable cells, collision footprints and camera bounds are in `WorldContract` / `TownContract`; `FarmMap` and `TownMap` build static collisions from them. Each active map owns a Y-sorted `Entities` root; `load_map()` reparents the same Player as child index 0, so exact-Y ties draw later props in front.
- `TownMap` already paints `TownContract.backdrop_cells()` into a non-colliding `Backdrop` TileMapLayer using the farm terrain atlas. Reuse this rather than a camera-size-specific sprite or enlarged playable map.

## Decision 1 — One interaction resolution path, without changing farming

Keep `current_target_cell()` and the Space/hold farming path exactly as they are. Add **one world-shell interaction resolver** (e.g. `_resolve_interactable()`) returning a small result containing the authoritative contract `cell`, `label`, and `action` (or empty). It runs against the current Player position/facing and the active map's contract values. Do not introduce an interactable registry, physics service, Area2D hierarchy or new domain command.

Enumerate only actual interactables: farm bed, shipping bin, truck; town truck, Seed Shop, Harvest Market and the three villagers. Reuse `WorldContract` / `TownContract` cells and footprints. The bed's interaction hotspot is the contract bed cell at the house entrance, **not** the entire house footprint (which would make the bed usable from the far side of the building). Existing exact-cell targeting remains a valid match, preserving current scripted interactions.

For near-contact fallback, use a small pure projected-world-space helper in `WorldMath`: calculate the shortest distance from the player's ground point to the projected footprint edges, require a bounded **one-tile** reach (begin at half the 64-pixel diamond width = 32 projected pixels), and require the nearest/contact direction to lie in the facing half-plane with a modest cone tolerance. If the player/contact point is coincident, use the target-cell centre to disambiguate facing. Select the closest valid candidate, with stable contract enumeration order for ties. A two-cell gap or facing away never matches. The exact numerical tolerance is pinned by tests at real reachable collision-stop poses; do not widen it simply to make remote-teleport fixtures pass.

Use this **same resolver** to:
1. Select the E prompt label and its `_prompt_anchor(resolved.cell)`.
2. Draw the neutral/gold interaction diamond on the resolved cell. Expose a small presentation override on `PlayerController` while retaining the raw farming diamond for Space previews; reset the override on map load, when the target disappears and under blocking modals.
3. Dispatch `interact()`, passing the returned exact `cell` to the existing travel/finale domain paths.
4. Supply the contract target cell to `_on_buy_requested`, `_on_upgrade_requested`, `_on_deposit_requested`, `_on_sleep_requested` and `_on_market_confirmed` after their modal opens. The player cannot move while such a modal is active; resolving the same frozen pose on submission avoids adding a second persisted/cached target. The domain guards remain authoritative.

Farming previews/blocked farming hints keep their existing priority and tile-exact green/red diamond behavior. An E prompt, when shown, must point to and invoke exactly the resolved interactable. No E prompt should be shown when no valid candidate is faced; E then keeps the current refusal toast.

Change the E hint **Bed → Go to bed** in `WorldShell` and add `Go to bed` to `assets/i18n/strings.csv` with `zh_TW` and `ja` rows (English is the key). Do not rename the bed in unrelated inventory or help copy.

## Decision 2 — Shared presentation-only foreground fading

On each map, opt in static scenery roots directly under `Entities` using a Godot group such as `player_occluder` (house, shipping bin, fences, truck, tall farm props, town buildings and other tall occluding scenery). Villagers and crop visuals do not require a new occlusion policy. Every opted-in root already has a `Sprite2D` child; no per-prop tuning table, new art, shader, collision, or additional render layer.

One small `WorldShell` update method handles either active map. Compute projected global sprite bounds from `Sprite2D.get_rect()` and its transform, compare them with the player's visible sprite bounds, and fade only if they intersect **and** the prop is drawn in front of the player by the existing Y-sort ordering. A Y tie treats the later prop as in front because Player is inserted at index 0. Fade the prop's image (not the player's sprite or collision) toward a single shared partially transparent alpha (around 0.45–0.5), and smoothly restore to 1.0 once uncovered. A bounded `move_toward` per frame is sufficient; no tween registry or silhouette shader. Never restart animation every frame or flicker on exact-Y ties.

The check and opacity live only in presentation. Rebuilt maps start fully opaque and use the same mechanism after either truck trip. If a sprite's rectangular bounds include a little transparent padding, accept this simple conservative overlap check rather than adding pixel-perfect masks.

## Decision 3 — Farm backdrop follows the town and keeps the edge fixed

Add a `Backdrop` `TileMapLayer` to `farm_map.tscn` beneath the existing Ground/Water/Paths. Use the **existing** `terrain_tileset.tres`, the same TileMapLayer projected origin as farm Ground, and tile placement outside the `WorldContract.MAP_SIZE` rectangle only. `FarmMap._ready()` populates it, with no collision bodies.

Factor the camera-rectangle-to-logical-cell coverage calculation currently inside `TownContract.backdrop_cells()` into one small pure `WorldMath` helper, then let the town wrapper call it unchanged. The farm calls it with `WorldContract.CAMERA_BOUNDS`; retain the one-cell overdraw margin so even the camera's extreme edges are filled. Keep shared grass/road atlas IDs in the common terrain/world contract rather than maintaining duplicate tile IDs across maps. East of the truck, continue the authored dirt-road exit aligned with `WorldContract.TRUCK_CELL` / existing Paths edge; use grass elsewhere. No terrain or logical/collision cells inside the authored farm are replaced.

`WorldContract.MAP_SIZE`, camera bounds, player speed, perimeter collisions and truck arrival stay unchanged. HPA-863 separately owns enlarging the playable farm and applying the refreshed HPA-861 art; this ticket only eliminates backdrop void using present assets.

## Regressions and boundaries

- Preserve original `GameSession` command guards, 30-minute travel, Day 14 market confirmation, time/stamina costs, save format and modal input gate.
- A resolver cannot rely on the current farm's `FarmView` existing in town; use only the active map's contract and `Entities`.
- Farm action hold and Space use the raw tile regardless of which E candidate is nearby.
- On travel or `load_map()`, clear presentation overrides; no stale highlight, prompt, faded prop reference or duplicate signal/command.
- No generated image/audio assets, new world layout, physics layers, new NPC/interaction systems, additional app runtime or compatibility shims.

## End-to-end acceptance contract

1. **Reachability:** On both maps, for every interactable, approach from every physically reachable side, face it and press real E; the expected panel/dialogue/travel/market response appears on the first attempt. Test the house entry/bed, bin, both trucks, shop, market and all three villagers. E while facing away and at a two-tile gap refuses without mutation; when the E hint appears, its label/anchor/diamond and the executed interaction agree.
2. **Domain correctness:** After E opens shop/shipping/sleep/market confirmation, performing the panel action succeeds using the resolved contract target. Assert one purchase/deposit/sleep/travel/finale command with exactly the pre-existing price/time/day/save effects. A Space farming action still targets precisely the raw tile and its preview.
3. **Readability:** On the farm and town, stand behind an opted-in prop from a real reachable position; its sprite fades while the player remains legible and restores to full alpha when no longer overlapping. Verify stable Y ties, unoccluded props, and fresh default alpha after map swaps.
4. **Farm edge:** At the truck/right edge and south-west river corner, and across all reachable farm-camera extremes, no grey is visible. The east road continues coherently; no collision, camera bounds or tile-exact playable geometry changed. Match native 1920×1080 captures to **HPA-743 B2**; check grass/road continuity rather than literal pixel identity.
5. **Automation:** GUT, headless verifier, GdUnit4, and godot-e2e pass. Agents execute real game input through the MCP-operated e2e/native test path on one supported platform, collect screenshots of the E prompt, occlusion before/after, town and B2 farm edge, and inspect those captures visually. No human approval is required for acceptance.
