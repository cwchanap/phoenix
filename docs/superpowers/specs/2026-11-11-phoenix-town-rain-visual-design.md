# HPA-860 — Town rain streaks: design specification

**Status:** Proposed, design review requested. This draft PR contains planning documents only; no runtime or test code has changed.
**Linear:** https://linear.app/cwchanap/issue/HPA-860/show-existing-rain-streaks-in-town-without-farm-river-ripples
**Baseline:** `main` after HPA-546 / PR #40, inspected 2026-11-11 (Vancouver).
**Delivery:** One issue, one PR for the plan and subsequent implementation. No extra art/SFX task is needed because all presentation resources exist.

## Player-facing outcome

The weather should not appear to switch off visually when the player drives from a rainy farm to the town. Rain streaks appear over both maps in rainy weather, disappear from both in sunny weather, and retain the existing subtle camera-following style. River ripples remain exclusively in the farm's river; town buildings/roads do not acquire artificial river effects.

The 30-minute truck travel, shops, dialogue, relationship scores, weather rules, stamina, time, save schema, HUD rain tint and rain audio do not change.

## Confirmed implementation boundary

- `scenes/world/farm_map.tscn` already owns `HomesteadAmbience` (z-index 6), running `scripts/world/homestead_ambience.gd`. The same node owns three river-ripple sprites and a deterministic 72-streak `_draw()` rain layer, positioned relative to the active `Camera2D`.
- `scenes/world/town_map.tscn` has no ambience node today. It contains `Backdrop`, `Ground`, colliders, and the Y-sorted `Entities` root (z-index 20).
- `WorldShell.load_map()` swaps `FarmMap`/`TownMap`, retains the Player/Camera2D/HUD/GameSession, then calls `_refresh_from_session(snapshot)`. That refresh calls `farm.ambience.render(snapshot)` *only* when the active map is a `FarmMap`.
- `GameHud` already handles weather tint and the one rain audio player regardless of which map is installed. PR #38 records the town streaks as a known presentation-only gap.

## Design: reuse one existing renderer, no framework

1. Introduce a small exported Boolean on `HomesteadAmbience`, e.g. `@export var show_river_ripples: bool = true`. Only gate creation of the three ripple sprites and their Tweens in `_ready()`; preserve the deterministic rain offsets, `render(snapshot)`, `_process()`, `_draw()`, and farm default.
2. Author a `HomesteadAmbience` child in `town_map.tscn` with the same script and `show_river_ripples = false`, at z-index 6. Retain the node name to keep both maps' minimal shared presentation seam; no extra audio nodes or assets. Although the class name is historical, renaming/extracting a generic ambience subsystem is unnecessary for this one new consumer.
3. In `WorldShell._refresh_from_session()`, keep the farm-only `FarmView.refresh(snapshot)` branch, and apply `render(snapshot)` to the active map's `HomesteadAmbience` node for *both* maps. A direct typed child lookup (with a null guard) is sufficient. No extra `GameMap` virtual method, location state, signal bus, or weather manager.
4. Map replacement naturally frees the old ambience node and its Tweens. Each new map's ambience receives the same session snapshot during `load_map()`; there is never more than one active map-owned rain layer.
5. Keep existing layering: both ambience nodes at z=6, below the world target highlight (z=10) and Y-sorted entities (z=20). The HUD remains unchanged, with weather audio and tint applied there.

## Behavioral contract

| Active map | Weather | Rain streaks | River ripples |
| --- | --- | --- | --- |
| Farm | Rainy | Visible, animated | Present |
| Farm | Sunny | Hidden | Present |
| Town | Rainy | Visible, animated | Absent |
| Town | Sunny | Hidden | Absent |

Travel in either direction rebinds the current snapshot on the newly-instantiated map. No gameplay state is modified by rendering. No copy of the rain draw logic is introduced.

## Source files and tests

**Runtime:**
- `scripts/world/homestead_ambience.gd` — an exported ripple-creation switch, defaulting true.
- `scenes/world/town_map.tscn` — authored rain child, same existing script, river ripples off.
- `scripts/world/world_shell.gd` — refresh current map's ambience regardless of map type.

**Regression:**
- `tests/integration/test_gameplay_shell.gd` — verify rainy/sunny map states, truck transitions, missing town ripple children, farm ripple retention, and no state changes from presentation refresh. Reuse existing `_restore_weather` and travel helpers where practical. Tests must fail against the baseline for a real missing town layer, not because of an unresolved symbol.
- `tests/headless/world_shell_smoke.gd` — add only the lightweight authored town ambience/flag/z-index scene contract as appropriate; do not repeat GUT behavior checks.
- `README.md` and `CLAUDE.md` — correct the documented interim town-rain limitation and active-map refresh ownership *after* implementation.

No localisation keys change; no new player-facing copy. Existing rain WAV and ripple texture are retained.

## Acceptance criteria

1. macOS native Godot 4.7.1, 1920x1080: visually inspect sunny/rainy farm and town. A rainy farm-to-town drive keeps streaks visible without a visual jump to clear weather; town buildings, villagers, player, targets, and dialogs remain readable. A return drive restores the farm and its ripples. The ticket has no UI mockup; compare against the farm's existing rainfall appearance and screenshots.
2. GUT exercises rainy/sunny rendering state after `load_map()`, absence of town `RiverRipple*` children, farm ripple presence, and no duplicate/stale map ambience following travel.
3. The player, camera, HUD, weather rules, audio volume/routing, translations, travel mechanics, social interactions, and save data remain unchanged.
4. `./tools/verify-clean.sh`, GdUnit4, godot-e2e, and the existing headless import + unsigned macOS export gates pass before implementation is called complete.
5. Single PR for HPA-860, with no new art/SFX or speculative abstractions. Linux/Android rely on CI only; manual acceptance is for macOS.

## Non-goals

No new rain particles or material shaders, rain collisions, terrain puddles, umbrellas, indoor shelter logic, weather balancing, river features in town, animation overhaul, persistence migration, or second rendering/audio system.
