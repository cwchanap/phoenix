# Phoenix Godot Migration Design (HPA-590)

**Status:** Approved for implementation planning

**Date:** 2026-08-21

## Source of truth

HPA-590 is the first implementation slice after the accepted Godot cutover. The Phoenix Linear project description defines the final runtime direction: Godot 4.7.1, typed GDScript, TileMapLayer sprite-isometric rendering, and one runtime only.

The previous Phaser/Tauri implementation remains a behavioral reference. It is not a runtime dependency and its architecture is not being migrated.

## Outcome

A clean checkout opens as a Godot project and provides the playable world shell required by later gameplay slices:

- sprite-isometric map rendering;
- WASD movement;
- collision around authored scenery;
- facing updates;
- camera follow;
- target-cell highlight; and
- correct front/behind rendering.

No farming rules, economy, social systems, persistence, or finale content are introduced.

## Decisions

- Use standard non-.NET Godot 4.7.1.
- Use statically typed GDScript.
- Keep Godot scenes/resources as the authored world source of truth.
- Reuse existing proof sprites where useful.
- Keep the existing 12x12 map contract and 64x32 diamond projection.
- Replace Phaser-owned rendering/input with Godot-native nodes.
- Do not preserve a second runnable web runtime.

## World structure

The main scene owns:

- TileMapLayer ground;
- scenery nodes with collision;
- CharacterBody2D player;
- Camera2D;
- target highlight node; and
- minimal debug smoke UI if required.

The map remains one elevation plane. There are no 3D meshes, camera rotation, dynamic lighting, or terrain layers.

## Runtime ownership

Godot owns:

- rendering;
- collision;
- input mapping;
- camera behavior;
- sprite ordering.

The first gameplay authority is intentionally deferred to HPA-589. HPA-590 should not invent GameSession, registries, service layers, or event frameworks.

## Movement and interaction

WASD maps through Godot InputMap actions. CharacterBody2D movement uses engine collision handling.

The existing facing contract remains:

| Facing | Target offset |
| --- | --- |
| Up | (-1,-1) |
| Right | (+1,-1) |
| Down | (+1,+1) |
| Left | (-1,+1) |

The target highlight is hidden when the projected target leaves the map.

## Depth ordering

Use bottom-center sprite contact points and Y-sorted rendering. Tall objects and the player share the same ordering system.

The implementation should not recreate the previous manual Phaser depth sorter unless Godot cannot express the required behavior.

## Verification

Required proof:

- project opens without import errors;
- player movement works;
- collision prevents entering tree/building footprints;
- camera follows within bounds;
- target highlight matches facing direction;
- player can move in front of and behind scenery.

Automated coverage should focus on Godot startup/headless smoke. Gameplay rule tests belong to HPA-589 when authoritative state exists.

## Non-goals

- farming;
- crops;
- economy;
- villagers;
- dialogue;
- persistence;
- save migration;
- browser packaging;
- Tauri bridge;
- C#;
- GDExtension;
- backend/database; and
- framework abstractions.
