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
- Do not import the old JSON map format or recreate its parser.
- Keep the existing world contract and projection numbers.
- Replace Phaser-owned rendering/input with Godot-native nodes.
- Do not preserve a second runnable web runtime.

## World contract

The Godot scene must preserve the existing proof-world behavior contract:

| Property | Value |
| --- | --- |
| Map size | 12x12 logical cells |
| Ground diamond | 64x32 |
| Projection origin | (384, 0) |
| Player spawn | (2.5, 9.5) |
| Player half extent | 0.18 logical cells |
| Farm patch | x=2..4, y=7..9 |
| Path row | x=3..9, y=6 |
| Tree footprint | x=7.2, y=4.2, width=0.6, height=0.6 |
| Building footprint | x=7, y=7, width=2, height=2 |

Shipping bin and villager placement are owned by later slices and are not part of HPA-590's contract.

The scene should be authored from this table rather than approximated visually. Future gameplay slices depend on these logical positions.

## Runtime ownership

Godot owns:

- rendering;
- collision;
- input mapping;
- camera behavior;
- sprite ordering.

A small framework-free typed GDScript module owns shared world math:

- isometric grid/world conversion;
- facing enum;
- facing target offsets;
- target-cell calculation.

CharacterBody2D owns movement execution only. It does not become the owner of targeting or projection rules.

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

Facing policy remains:

- dominant screen axis determines facing;
- horizontal wins ties;
- idle retains the previous facing.

The target highlight is hidden when the projected target leaves the map.

## Depth ordering

Use bottom-center sprite contact points and Y-sorted rendering. Tall objects and the player share the same ordering system.

The implementation should not recreate the previous manual Phaser depth sorter unless Godot cannot express the required behavior.

## Verification

Required proof:

- project opens without import errors;
- headless smoke validates map size, projection constants, spawn, target offsets, off-map target hiding, and collision contract;
- player movement works;
- collision prevents entering tree/building footprints;
- camera follows within bounds;
- target highlight matches facing direction;
- player can move in front of and behind scenery.

Do not add GUT or broad gameplay test infrastructure in HPA-590. Direct gameplay rule tests belong to HPA-589 when authoritative state exists.

## Presentation contract

- Viewport remains 640x360.
- Pixel art uses nearest filtering.
- No debug HUD is required; deterministic headless assertions are preferred.

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
