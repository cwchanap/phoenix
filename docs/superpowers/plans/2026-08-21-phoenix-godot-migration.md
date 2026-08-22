# Phoenix Godot Migration Plan (HPA-590)

## Goal

Deliver the first Godot runtime slice in one PR. The PR replaces the old web runtime with a Godot-native world shell and leaves later gameplay ports a clean foundation.

## Task 1: Bootstrap Godot project

- Add Godot 4.7.1 project files.
- Configure the main scene and macOS desktop export path.
- Move reusable sprite assets into Godot resources.
- Remove assumptions that Bun/Vite/Svelte/Phaser are the runtime.
- Keep existing framework-free TypeScript gameplay code only if it remains an unplugged reference/test dependency for later migration; it must not remain a second playable runtime.

Validation:

- Godot opens the project without parse/import failures.
- Runtime entry point is Godot only.

## Task 2: Re-author the isometric world

- Create TileMapLayer terrain.
- Recreate the compact 12x12 world.
- Preserve the 64x32 diamond projection and origin contract.
- Preserve spawn, farm patch, tree footprint, building footprint, and perimeter constraints from the world contract.
- Add tree/building scenery and authored collision shapes from logical footprints rather than visual approximation.

Validation:

- Headless smoke validates scene contract values.
- Collision footprints exist only where authored.

## Task 3: Add shared world math and player movement

- Add a small typed GDScript world-math module.
- Keep projection conversion, facing policy, and target-cell calculation outside CharacterBody2D.
- Add CharacterBody2D player.
- Add InputMap actions.
- Add Camera2D follow with bounds.

Validation:

- WASD movement works.
- Player cannot pass scenery or leave the map contract.
- Facing follows dominant axis behavior.

## Task 4: Restore targeting smoke

- Use the shared facing/target module.
- Draw target diamond.
- Hide invalid targets outside the map.

Validation:

- All four directions select expected neighboring cells.
- Off-map targets remain hidden.

## Task 5: Verify depth ordering

- Configure Y-sorting and bottom-center contacts.
- Verify player transitions behind/in front of tall scenery.

Validation:

- No visible ordering flicker.

## Task 6: Update project documentation and checks

- Replace old runtime documentation with Godot workflow.
- Replace web/Tauri runtime checks with Godot verification.
- Keep CI focused on the new runtime and remaining intentionally retained tests.
- Avoid introducing GUT or gameplay test infrastructure before HPA-589.

## Explicitly avoid

- porting Phaser classes;
- creating a compatibility layer;
- keeping two runnable runtimes;
- creating generic managers/services;
- adding gameplay systems early;
- importing the old JSON map parser;
- creating debug HUD infrastructure instead of deterministic checks.

## Delivery

One implementation PR for HPA-590. Later HPA tickets build on this runtime directly.
