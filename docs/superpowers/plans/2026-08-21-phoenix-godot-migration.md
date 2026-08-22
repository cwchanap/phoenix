# Phoenix Godot Migration Plan (HPA-590)

## Goal

Deliver the first Godot runtime slice in one PR. The PR replaces the old web runtime with a Godot-native world shell and leaves later gameplay ports a clean foundation.

## Task 1: Bootstrap Godot project

- Add Godot 4.7.1 project files.
- Configure the main scene and macOS desktop export path.
- Move reusable sprite assets into Godot resources.
- Remove assumptions that Bun/Vite/Svelte/Phaser are the runtime.

Validation:

- Godot opens the project without parse/import failures.

## Task 2: Re-author the isometric world

- Create TileMapLayer terrain.
- Recreate the compact 12x12 world.
- Preserve the 64x32 diamond projection.
- Add tree/building scenery and authored collision shapes.

Validation:

- Scene visually matches the intended proof world.
- Collision footprints exist only where authored.

## Task 3: Add player movement and camera

- Add CharacterBody2D player.
- Add InputMap actions.
- Add Camera2D follow with bounds.
- Keep movement implementation inside Godot rather than porting old Phaser movement code.

Validation:

- WASD movement works.
- Player cannot pass scenery.
- Camera stays inside world bounds.

## Task 4: Restore targeting smoke

- Add facing state.
- Calculate logical target cell.
- Draw target diamond.
- Hide invalid targets outside the map.

Validation:

- All four directions select expected neighboring cells.

## Task 5: Verify depth ordering

- Configure Y-sorting and bottom-center contacts.
- Verify player transitions behind/in front of tall scenery.

Validation:

- No visible ordering flicker.

## Task 6: Update project documentation and checks

- Replace old runtime documentation with Godot workflow.
- Add minimal Godot verification commands.
- Avoid introducing GUT or gameplay test infrastructure before HPA-589.

## Explicitly avoid

- porting Phaser classes;
- creating a compatibility layer;
- keeping two runnable runtimes;
- creating generic managers/services;
- adding gameplay systems early.

## Delivery

One implementation PR for HPA-590. Later HPA tickets build on this runtime directly.
