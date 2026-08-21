# Phoenix Godot Cutover Roadmap

**Status:** Accepted

**Date:** 2026-08-20

**Tracking issue:** HPA-587

**Delivery target:** one Godot runtime that restores the existing Phoenix MVP through four bounded parity slices, followed by the existing content/finale and release tickets

## Decision

Phoenix will replace the current Bun/Vite/Svelte/Phaser/Tauri implementation with Godot 4.7.1 using the standard, non-.NET build and statically typed GDScript.

This is a hard cutover rather than a dual-runtime migration:

- HPA-590 removes the existing JavaScript/Tauri runtime while establishing the Godot world shell.
- Later migration tickets restore gameplay slices sequentially in the same repository.
- Git history remains the implementation reference for the Phaser/Tauri prototype.
- No browser/Tauri save migration or backward-compatible runtime is maintained.
- Each active issue is delivered in one PR.

The 14-day farming-life product scope does not change. Only the engine, UI toolkit, persistence implementation, automated verification, and desktop packaging path change.

## Why cut over now

The original prototype has already validated the important product seams:

- fixed-camera 64×32 sprite-isometric movement, collision, targeting, and depth ordering;
- a complete farming, crop-growth, daily-rhythm, and economy loop;
- three villagers, gifting, and relationship progression;
- one-slot autosave and Continue;
- a planned onboarding and Day 14 finale slice.

HPA-597 had reached planning only. Its closed PR contained design and implementation documents but no merged runtime implementation. The cutover therefore avoids discarding a partially implemented finale while preserving the completed prototype as an executable specification.

Keeping both engines alive until full parity was rejected. It would require duplicate rules, UI, assets, test infrastructure, persistence fixes, and release workflows, followed by another large final switch. A single migration PR was also rejected because it would create an unreviewable long-lived branch. Four sequential parity slices provide the smallest practical review boundaries.

## Target technical direction

### Runtime and language

- Pin Godot 4.7.1 standard, not the .NET build.
- Use statically typed GDScript.
- Do not add C#, GDExtension, a JavaScript bridge, or another gameplay runtime.

### World and rendering

- Keep the current logical 12×12 world and 64×32 2:1 diamond-isometric projection.
- Use Godot `TileMapLayer` nodes as the authored tile-map API.
- Keep one walkable elevation plane.
- Use bottom-center ground contact and Godot Y-sorting for front/behind rendering.
- Re-author the compact map directly in Godot rather than maintaining a Tiled runtime importer.
- Preserve the current authored logical cells, collision footprints, target stances, and market reserve unless a migration ticket documents a required port correction.

### Gameplay authority

- Keep one framework-light, statically typed GDScript `GameSession` as the mutable rules authority.
- Keep world nodes, rendering objects, and `Control` presentation out of authoritative gameplay state.
- Preserve the current command-oriented behavior: validate first, mutate once, and return an actionable success/failure result.
- Avoid state-machine frameworks, registries, event graphs, service locators, and speculative plugin systems.

### UI

- Use Godot `Control` scenes for the title, HUD, farming actions, shop, shipping, dialogue, day summary, tutorial prompts, help/settings, and result presentation.
- Use one reason-keyed input-lock mechanism so modal UI cannot leave movement or held keys stuck.
- Do not rebuild Svelte concepts as a generic Godot UI framework.

### Persistence

- Use one versioned JSON save under `user://`.
- Save authoritative gameplay state after a completed overnight transition.
- Resume the player at the authored spawn rather than persisting arbitrary world position or camera state.
- Reject malformed or current-rule-incompatible saves without blocking New Game.
- Do not migrate localStorage or Tauri Store data.
- Do not retain the current multi-adapter `SaveRepository` abstraction when only one production backend remains.

### Testing and packaging

- Use a Godot 4.7-compatible GUT 9.x version for rules, persistence, and result-boundary tests.
- Run Godot import/check and GUT headlessly in CI.
- Add only bounded scene-level smoke automation where it is stable and cheaper than a manual check.
- Do not recreate the large Playwright movement/save harness.
- Commit a Godot macOS export preset and prove an unsigned export from a clean checkout.

## What is reused

The following remain product or content sources of truth:

- the 14-day product scope and current feature boundaries;
- crop names, growth values, prices, sale values, and action costs until HPA-599 tunes them;
- villager identities, favourite crops, dialogue, and relationship thresholds;
- the 12×12 map layout, logical cells, projection, and target stances;
- the committed PNG sprite sheets where they remain useful;
- the existing TypeScript unit/E2E scenarios as behavioral references;
- the accepted HPA-597 onboarding/finale product design;
- Git history for the complete Phaser/Tauri implementation.

## What is ported behaviorally

- `GameSession` farming, time, weather, economy, social, and restore rules;
- command validation order and exactly-once mutations;
- title/New Game/Continue behavior;
- modal input locking and pending morning-summary behavior;
- map collision, targeting, and front/behind requirements;
- save structural/current-rule rejection;
- all three finale tiers and their exact thresholds once HPA-597 resumes.

The TypeScript files are not copied into a permanent `legacy` or `reference` runtime. Git history already preserves them.

## What is removed by HPA-590

- Bun and JavaScript package/runtime configuration;
- Vite and Svelte application code;
- Phaser scenes, adapters, input controllers, and browser test hooks;
- Tauri and Rust shell code;
- localStorage and Tauri Store adapters;
- Playwright acceptance infrastructure;
- JavaScript lint, format, and numeric coverage tooling;
- Tiled runtime parsing and exact generated-JSON parser contracts;
- browser packaging and browser-development support.

The committed sprite assets may remain when reused by Godot. Historical design documents remain unless they actively mislead the current implementation workflow.

## Active delivery sequence

The Linear workspace cannot add more issues, so four previously canceled horizontal placeholders are intentionally reactivated as the migration slices. Their previous cancellation history is recorded in their new descriptions.

### HPA-590 — Godot world-shell cutover

**Goal:** replace the web/Tauri runtime and prove the Godot project, isometric world, movement, collision, targeting, depth ordering, input lock, headless verification, and macOS export.

This PR intentionally reduces the playable feature set to the world shell. It removes the old runtime rather than placing it under a legacy directory.

### HPA-589 — farming, daily rhythm, and economy parity

**Goal:** restore the shared authoritative gameplay session and the full loop:

`buy seed → hoe → plant → water → sleep → grow → harvest → ship → receive income → reinvest`

Farming, daily rhythm, and economy remain one ticket because they share the same session fields and overnight transaction. Splitting them would repeatedly reshape the same rules authority.

### HPA-594 — social parity

**Goal:** restore Mira, Rowan, June, dialogue, gifting, relationship progression, daily social resets, collision/targeting, and modal input behavior through Godot scenes and typed GDScript.

This ticket does not add schedules, pathfinding, quests, romance, portraits, or a dialogue engine.

### HPA-598 — persistence parity

**Goal:** restore one-slot New Game/Continue and next-morning autosave using one Godot JSON save under `user://`.

This ticket creates a new save schema. It does not migrate browser/Tauri data or preserve the old V1 envelope.

### HPA-597 — onboarding and Day 14 finale

HPA-597 returns to Backlog and is blocked by HPA-598.

Its product scope remains intact, but implementation now targets:

- Godot world and `TileMapLayer` authoring;
- typed GDScript gameplay rules;
- Godot `Control` opening, prompt, HUD, and result scenes;
- the Godot gameplay save state;
- direct GUT rule/threshold tests plus bounded scene smoke tests.

Both market interaction and Day 14 sleep must settle final shipping and call the same exactly-once finale rule without creating Day 15.

### HPA-599 — Godot polish and release verification

HPA-599 remains the single closeout ticket after HPA-597.

It owns:

- focused art/readability and Y-sort corrections;
- lightweight weather presentation and placeholder/licensed audio;
- Godot audio-bus volume settings and separate settings persistence;
- data-only balance tuning;
- headless Godot/GUT verification;
- a supported macOS export;
- one complete packaged 14-day playthrough.

It does not rebuild a browser E2E system or split audiovisual polish into another ticket.

## Tracking and dependency graph

```text
HPA-590 Godot world shell
  -> HPA-589 farming/daily/economy
    -> HPA-594 social
      -> HPA-598 persistence
        -> HPA-597 onboarding/finale
          -> HPA-599 polish/release
            -> HPA-587 tracking completion
```

The completed prototype issues HPA-588, HPA-591, HPA-592, HPA-593, HPA-595, and HPA-596 stay Done and are not blockers in the new chain.

## Delivery constraints

- One issue equals one PR.
- Do not open a planning PR and then a separate implementation PR for the same migration ticket.
- Do not use stacked migration PRs that require merging out of order.
- Preserve current behavior during parity work; defer tuning to HPA-599.
- Prefer direct, readable GDScript and scene composition over framework abstractions.
- Keep the project macOS-first.
- Do not add backward compatibility for breaking changes or development saves.
- Do not pull HPA-597 content or HPA-599 polish into the migration parity tickets.

## Verification strategy by phase

### HPA-590

- Godot import/check succeeds headlessly.
- Core projection/collision/targeting tests pass.
- World smoke proves movement, collision, target highlight, input lock, and depth ordering.
- Clean macOS export succeeds.

### HPA-589

- Direct tests prove crop definitions, action budgets, weather behavior, sleep, shipping settlement, and the three-crop reinvestment loop.
- One scene smoke proves visible farming and overnight flow.

### HPA-594

- Direct tests prove every relationship threshold and duplicate-protection branch.
- Scene smoke proves one villager interaction, gifting, focus, and input unlock.

### HPA-598

- Direct tests prove save structure, current-rule validation, deep cloning, and farming/economy/social round trip.
- Manual exported-build smoke proves close/reopen/Continue.

### HPA-597

- Direct tests prove contextual prompts, final shipping, Day 14 triggers, duplicate prevention, and every tier boundary.
- Bounded scene smoke proves opening, market finale, sleep fallback, result scene, final save, and Continue-to-result.

### HPA-599

- Full headless verification from a clean checkout.
- Supported macOS export.
- One normal packaged 14-day playthrough plus representative mid-game/pre-finale save checks.

## Explicit non-goals

- dual Phaser and Godot runtimes;
- browser support;
- migration of Tauri/localStorage saves;
- C# or GDExtension;
- JavaScript embedded in Godot;
- a Tiled runtime importer;
- a generic quest, cutscene, event, state-machine, or dialogue framework;
- controller remapping;
- mobile packaging;
- feature expansion beyond the existing Phoenix MVP.

## References

- [Godot official release archive](https://godotengine.org/download/archive/)
- [Godot 4.7 stable documentation](https://docs.godotengine.org/en/stable/)
- [Godot `TileMapLayer` class reference](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
- [GUT Godot unit-test framework](https://github.com/bitwes/Gut)
