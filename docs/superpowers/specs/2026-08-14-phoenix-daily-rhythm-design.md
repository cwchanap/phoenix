# Phoenix Daily Rhythm Design (HPA-592)

**Status:** Design approved; written-spec review pending

**Date:** 2026-08-14

**Delivery target:** macOS-first browser and Tauri daily-rhythm slice

## Source of truth

This design implements the third active slice under [HPA-587](https://linear.app/cwchanap/issue/HPA-587/tracking-deliver-the-phoenix-14-day-farming-mvp): [HPA-592](https://linear.app/cwchanap/issue/HPA-592). The live Linear issue and Phoenix project description remain authoritative for product scope, technology choices, delivery order, and non-goals.

HPA-592 builds directly on the completed HPA-588 foundation and HPA-591 turnip day loop. It adds the smallest complete daily rhythm needed for a repeatable 14-day farming game: action-driven time, stamina, sunny and rainy weather, a guarded day transition, and a blocking morning summary.

## Outcome

A new game starts on Day 1 at 06:00 with 20 stamina and sunny weather. Successful farming actions consume fixed time and stamina. Walking and action selection remain free. Farming cannot push the clock past 22:00 and cannot proceed without enough stamina.

Sleeping at the authored bed advances exactly one day, applies the completed day's watering and crop growth, restores the next day to 06:00 and full stamina, chooses the next weather, and opens a blocking morning summary. The player explicitly starts the new day from that summary before world input resumes. Rain automatically waters planted crops and makes tilled soil appear wet.

Day 14 remains fully playable. Attempting to sleep beyond it returns a clear final-day result without advancing to Day 15. HPA-597 will later replace this temporary boundary with the finale.

## Approved decisions

- Keep GameSession as the only mutable gameplay authority.
- Add a small framework-free dailyRhythm module for constants, action costs, time formatting, and weather selection.
- Represent time as integer minutes since midnight.
- Start every day at 06:00 with a maximum of 20 stamina.
- Use these exact costs:

| Action | Time | Stamina |
| --- | ---: | ---: |
| Hoe | 30 minutes | 3 |
| Plant | 20 minutes | 1 |
| Water | 20 minutes | 2 |
| Harvest | 20 minutes | 1 |

- Treat 22:00 as a hard action-completion cutoff. An action ending exactly at 22:00 succeeds; one ending later fails atomically.
- Validate target and farming state before checking time, then check stamina last. Time therefore wins when both budgets are insufficient.
- Keep walking, target selection, farming-action selection, sleep confirmation, and summary acknowledgment free.
- Make Day 1 sunny. For each later day, use a 25 percent rain chance through an injectable next-weather function.
- Make rainy weather count every planted crop as watered and render every tilled farm cell as wet.
- Reject manual watering on a rainy day without spending time or stamina.
- Allow sleep at the bed at any time from 06:00 through 22:00.
- Use two blocking presentation stages: sleep confirmation, then an authoritative morning summary.
- Keep world input locked continuously from opening sleep confirmation until the summary is acknowledged or the transition fails.
- Guard duplicate sleep and duplicate summary acknowledgment in both presentation and domain layers.
- Keep developer hooks observation-only.
- Keep browser acceptance as the exhaustive deterministic interaction proof and use a bounded native macOS smoke for the identical frontend.

## Explicit non-goals

This slice does not add real-time clock ticking, time costs for walking, movement stamina, passing out, forced bedtime, energy regeneration during the day, weather forecasts, rain particles, ambient weather simulation, seasons, money, shipping, shops, relationships, dialogue, persistence, autosave, save slots, potatoes, pumpkins, new maps, the Day 14 finale, signing, or notarization.

It does not introduce a scheduler, command middleware, event bus, generic stat system, wrapper session, or speculative complete-MVP schema. Rust remains a desktop shell and gains no gameplay logic.

## Architecture and ownership

### Pure daily-rhythm helpers

A new src/game/core/dailyRhythm.ts module owns the fixed rules:

- DAY_START_MINUTES = 360;
- ACTION_CUTOFF_MINUTES = 1320;
- MAX_STAMINA = 20;
- MAX_DAY = 14;
- RAIN_CHANCE = 0.25;
- the complete FarmingAction-to-ActionCost mapping;
- evaluateActionBudget(currentBudget, action);
- formatTime(minutes);
- weatherFromRandom(value); and
- the default next-weather function built from Math.random.

ActionCost has exactly minutes and stamina fields. The cost mapping is exhaustive over the existing four FarmingAction values. There is no default cost and no mutable configuration object.

evaluateActionBudget is a pure, non-mutating function. It checks the 22:00 cutoff first and stamina second, then returns either the exact failure code or the resulting time and stamina values. GameSession calls this one evaluator after farming-state validation. This keeps the currently content-limited game free of test-only clock setters while making the cutoff and precedence rules directly deterministic.

Its result is exactly:

    type ActionBudgetResult =
      | { ok: true; timeMinutes: number; stamina: number }
      | { ok: false; code: 'action-too-late' | 'insufficient-stamina' };

weatherFromRandom returns rainy for values greater than or equal to 0 and less than 0.25, and sunny for values greater than or equal to 0.25 and less than 1. Values outside the half-open interval from 0 through 1 are programmer/configuration errors and throw. The injected GameSession dependency returns Weather directly, so tests can supply a deterministic sequence without exposing random values or mutation controls to Phaser or Svelte.

formatTime returns zero-padded 24-hour HH:MM text. It accepts only integer minutes from 0 through 1439 and throws for other input. Authoritative gameplay supplies only the narrower 360-through-1320 range.

### GameSession

GameSession remains the only mutable gameplay authority. It keeps its existing ProofWorld composition, map validation, inventory, farm, selected-action, and bed ownership. It adds:

- current time in minutes;
- current stamina;
- current weather;
- an optional pending day summary; and
- a private nextWeather function.

GameSessionConfig gains an optional nextWeather dependency with type () => Weather. When omitted, construction uses the default 25 percent provider. The function is retained privately and never appears in a snapshot.

The session continues to return fresh JSON-serializable snapshots and stable CommandResult values. It never imports Phaser, Svelte, browser APIs, or Tauri.

### Phaser

ProofScene continues to own rendering, camera behavior, asset loading, and keyboard sampling. It constructs GameSession through the existing configuration plus the production weather provider, invokes session commands, reconciles farm visuals from snapshots, and publishes authoritative snapshots after commands.

SceneCommands gains one method:

- acknowledgeDaySummary(): CommandResult

The existing selectAction and sleep methods remain. The facade does not expose GameSession, weather injection, time setters, stamina setters, or a generic dispatch method.

ProofScene still publishes the initial game snapshot before readiness and publishes after each selection, farming, sleep, or summary-acknowledgment command. It does not publish the HUD at frame rate. Movement-only frames keep using the existing debug snapshot.

### Svelte

Svelte owns the HUD, feedback, sleep confirmation, morning-summary presentation, focus management, lifecycle status, and modal lock orchestration. It displays authoritative time, stamina, weather, day, farm, and summary state from GameSnapshot. It does not calculate costs, choose weather, advance crops, restore stamina, or create a second day model.

App.svelte owns only presentation state around the transition:

- whether sleep confirmation is visible;
- whether a sleep command is being submitted;
- whether summary acknowledgment is being submitted;
- the latest immutable GameSnapshot;
- the latest CommandResult; and
- the current SceneCommands facade.

Overlay.svelte renders the authoritative pending summary and emits explicit confirm, cancel, and start-day intentions. It does not clear a summary locally.

### Tauri and Rust

The Tauri application continues to load the same frontend used in browser development. Rust remains a thin macOS window and packaging shell. No daily-rhythm state crosses into Rust.

## Domain model

### Weather

Weather is exactly:

    type Weather = 'sunny' | 'rainy';

Day 1 is always sunny. A successful transition from Day 1 to Day 2 is the first time nextWeather is called. Every later successful transition calls it once. Rejected sleep, duplicate sleep, Day 14 sleep, and summary acknowledgment never call it.

The snapshot's weather is the current playable day's weather. The pending summary's nextWeather is the same value because the authoritative session has already advanced to the next day while input remains blocked.

### Time and stamina

timeMinutes is an integer number of minutes since midnight. It starts at 360, can increase only through successful farming actions, and can never exceed 1320.

stamina is a non-negative integer. It starts at maxStamina and can decrease only through successful farming actions. maxStamina is included in the snapshot so the HUD does not duplicate the constant. The initial value and each new-day value are 20.

There is no partial action, queued action, fractional cost, or automatic passage of time.

### Day summary

DaySummary has this serializable shape:

    interface DaySummary {
      completedDay: number;
      nextDay: number;
      cropsAdvanced: number;
      nextWeather: Weather;
      staminaRestored: number;
    }

cropsAdvanced counts crops whose growth level actually increased. Mature crops and dry sunny-day crops do not count. staminaRestored is the numeric amount required to return the completed day's stamina to maxStamina.

pendingDaySummary is null during active play. A successful sleep creates exactly one summary and leaves it present until acknowledgeDaySummary succeeds.

### Complete snapshot

GameSnapshot retains every HPA-591 field and adds:

- timeMinutes;
- stamina;
- maxStamina;
- weather; and
- pendingDaySummary: DaySummary | null.

Snapshots remain fresh, deterministic, and JSON round-trippable. They contain no provider functions, Phaser objects, Svelte state, timers, Date objects, Map, or Set.

## Command semantics

### Active-day lifecycle gate

When pendingDaySummary is not null:

- stepMovement ignores movement input;
- selectAction returns day-summary-pending;
- applySelectedAction and every direct farming command return day-summary-pending;
- sleep returns day-summary-pending; and
- a second successful day transition is impossible.

This domain gate is defensive. The presentation layer also keeps InputGate locked so ordinary input never reaches these commands.

acknowledgeDaySummary is the only command allowed through this gate. It clears the summary and returns day-started. Calling it without a pending summary returns no-day-summary without mutation.

### Farming transaction

Every farming command is one transaction:

1. Apply the active-day gate.
2. Validate target and command-specific farming state in the established HPA-591 order.
3. For Water on a valid non-mature crop, reject rainy weather with rain-waters-crops before checking already-watered.
4. Pass the current time, current stamina, and selected action to evaluateActionBudget.
5. Return its action-too-late or insufficient-stamina result unchanged when it fails.
6. Apply the farming mutation and the evaluator's resulting time and stamina together when it succeeds.

State validation deliberately precedes affordability. For example, hoeing an already tilled cell at 21:50 returns already-tilled, not action-too-late. When a valid action lacks both time and stamina, it returns action-too-late.

All failure paths preserve the complete authoritative snapshot. Successful actions charge exactly once. Existing command-specific success codes remain unchanged.

### Selection and walking

selectAction remains free during active play and returns action-selected. Walking and facing updates remain free. Neither changes time or stamina.

During a pending summary, selection fails and movement is ignored as described by the lifecycle gate.

### Rain behavior

On a rainy active day:

- every tilled farm tile renders with the wet-soil frame;
- every planted crop is effectively watered for the next sleep transition;
- manually watering a valid non-mature crop returns rain-waters-crops;
- manual wateredToday flags are not set merely because it is raining; and
- rain consumes no time or stamina.

At sleep, a crop is eligible to advance when wateredToday is true or the completed day's weather is rainy. A crop below growth level 3 advances by exactly one level. Every surviving crop's wateredToday flag is then reset to false for the new day.

### Sleep and day transition

sleep applies these checks in order:

1. Return day-summary-pending if a summary already exists.
2. Return not-at-bed unless the current ProofWorld target equals the authored bed cell.
3. Return day-limit-reached when the current day is 14.
4. Otherwise perform one atomic transition.

The successful transition:

1. Captures completedDay, completed weather, and completed stamina.
2. Calls nextWeather exactly once and validates that its result is sunny or rainy before mutating session state.
3. Computes the next farm state and actual growth count without changing the current farm state.
4. Commits the next farm state, including wateredToday reset on every surviving crop.
5. Increments day by one.
6. Sets timeMinutes to 360.
7. Sets stamina to maxStamina.
8. Stores the validated next weather as current weather.
9. Creates pendingDaySummary from the captured and resulting values.
10. Returns day-advanced.

Sleep is allowed at any valid active-day time, including 06:00 and 22:00. It has no separate time or stamina cost. A Day 14 rejection changes no crop, watering flag, time, stamina, weather, inventory, day, or provider state. An invalid provider result throws before authoritative state changes, so the day transition cannot be partially committed.

### Result codes

HPA-592 adds these success and failure codes:

| Kind | Code | Meaning |
| --- | --- | --- |
| Success | day-started | The blocking morning summary was acknowledged |
| Failure | day-summary-pending | Active gameplay is blocked by the morning summary |
| Failure | action-too-late | The valid action would finish after 22:00 |
| Failure | insufficient-stamina | The valid affordable-time action lacks stamina |
| Failure | rain-waters-crops | Rain already supplies the day's watering |
| Failure | day-limit-reached | Day 14 cannot advance to Day 15 in this slice |
| Failure | no-day-summary | No authoritative morning summary exists to acknowledge |

Expected failures use CommandResult and never throw. Invalid configuration, invalid injected random values, malformed map data, and unreachable exhaustive-switch violations remain errors.

## Presentation and input flow

### Expanded HUD

The existing compact overlay adds:

- formatted time such as 06:00 or 21:40;
- stamina such as 20 / 20; and
- weather text for Sunny or Rainy.

The existing day, selected action, seed count, turnip count, controls, feedback, and demonstration input-lock control remain. HUD values come only from the latest GameSnapshot.

Weather presentation is intentionally compact. Sunny and Rainy text plus wet-soil rendering satisfy this slice. Rain particles and weather animation remain out of scope.

### Two-stage modal transition

App.svelte uses one InputGate reason named day-transition for the entire flow. A single synchronization function sets that reason from:

- sleep confirmation visibility;
- sleep submission in flight;
- authoritative pendingDaySummary presence; or
- summary acknowledgment in flight.

Opening sleep confirmation sets the reason before rendering the modal. Confirm disables repeated submission and invokes SceneCommands.sleep once. ProofScene publishes the resulting snapshot synchronously with the command. App closes confirmation only after processing that result, and the authoritative pending summary keeps the same gate reason active. There is no unlock/relock frame between stages.

If sleep fails, App clears the in-flight state, closes confirmation, releases the reason, and leaves the returned failure as feedback. Cancel closes confirmation and releases the reason without invoking sleep.

The summary dialog has no cancel path. Its Start Day N button disables repeated submission, invokes acknowledgeDaySummary once, and releases the day-transition reason only after a snapshot with pendingDaySummary equal to null arrives. Errors and component teardown clear locally owned in-flight state and the gate reason symmetrically.

### Accessibility and controls

Both panels use blocking dialog semantics with clear headings. Sleep confirmation initially focuses Confirm. Morning summary initially focuses Start Day N. Background action-selection buttons and the demonstration lock control are disabled whenever either panel or transition is active.

The morning summary shows:

- completed day;
- crops advanced;
- next day;
- next weather; and
- stamina restored, including the resulting full value.

The player-facing feedback mapping adds concise messages for all new result codes. The Day 14 message explicitly says the final playable day cannot advance yet.

## Rendering

The pure farmVisuals mapper gains the current Weather as an explicit input. An untilled cell still has no soil sprite. Every tilled cell uses the wet frame when weather is rainy; otherwise it uses the wet frame only when its crop has wateredToday true. Crop-frame selection remains derived solely from growth.

ProofScene passes snapshot.weather when reconciling every farm tile. A weather change therefore reuses the existing keyed sprites and updates their frames without rebuilding the scene or keeping hidden Phaser weather state.

Crop depth, soil depth, target rendering, camera behavior, player movement, map collision, and the deterministic farming assets remain unchanged.

## Failure and lifecycle behavior

Every expected rejection returns a stable code and leaves the complete snapshot unchanged. The presentation layer maps codes to messages but does not reinterpret success or failure.

Scene remount, HMR, fatal startup error, and Svelte teardown clear command facades, in-flight transition state, and the day-transition InputGate reason. They continue to produce one canvas and one set of movement and action handlers.

The production build must not contain the development observation hook. No hook may set time, stamina, weather, day, summary, farm state, or invoke gameplay commands.

## Verification strategy

### Pure helper tests

Focused dailyRhythm tests prove:

- every exact cost;
- exhaustive coverage of all four FarmingAction values;
- the budget evaluator does not mutate its input;
- an action ending exactly at 22:00 succeeds;
- an action ending after 22:00 returns action-too-late;
- insufficient stamina returns insufficient-stamina;
- time failure precedes stamina failure;
- 06:00, 22:00, and representative time formatting;
- rainy values below 0.25;
- the exact 0.25 boundary is sunny;
- representative sunny values below 1; and
- out-of-range random values throw.

### GameSession tests

Focused GameSession tests prove:

- the exact Day 1, 06:00, 20 / 20, sunny defaults;
- snapshots remain fresh and JSON round-trippable with the new fields;
- each action charges its exact cost once;
- selection and walking are free;
- invalid target and farming-state failures charge nothing;
- rainy manual watering returns rain-waters-crops and charges nothing;
- naturally reachable stamina exhaustion returns insufficient-stamina without mutation;
- GameSession applies the shared evaluator's successful resulting budget atomically;
- every rejection preserves complete snapshot equality;
- sunny watered crops advance and sunny dry crops do not;
- rainy planted crops advance without manual watering;
- mature crops do not increment or count as advanced;
- every new day resets time, stamina, and manual watering state;
- nextWeather is called exactly once per successful transition;
- rejected, duplicate, summary-pending, and Day 14 sleep calls do not consume weather;
- the summary contains exact completed-day, next-day, crops-advanced, next-weather, and stamina-restored values;
- pending-summary selection, farming, movement, and sleep cannot mutate state;
- acknowledgment clears one summary and returns day-started;
- repeated acknowledgment returns no-day-summary without mutation; and
- Day 14 remains playable but cannot advance to Day 15.

Mutation checks must demonstrate that the tests fail when the cutoff comparison, failure precedence, rain watering, single provider call, duplicate-sleep gate, or atomic charge behavior is deliberately broken.

### Render and bridge tests

Focused tests prove:

- farmVisuals renders every tilled rainy tile wet, including empty soil;
- sunny dry/wet and crop-growth mappings remain correct;
- ProofScene includes acknowledgeDaySummary in SceneCommands;
- every command publishes its CommandResult and authoritative snapshot;
- the weather provider and mutable session are not exposed through the facade; and
- teardown remains idempotent.

### Browser acceptance

Playwright drives only real keyboard events and visible controls. The observation hook may read immutable debug and game snapshots but may not mutate them.

Browser coverage proves:

1. A new game visibly shows Day 1, 06:00, 20 / 20, and Sunny.
2. Representative successful farming actions update time and stamina by their exact costs.
3. Rejected farming leaves displayed and authoritative budgets unchanged.
4. Sleep confirmation locks movement and action input.
5. One confirmation advances exactly one day and displays one morning summary.
6. Input remains locked throughout the confirmation-to-summary handoff.
7. Summary content matches the authoritative snapshot.
8. Repeated confirmation cannot advance the day twice.
9. Start Day N clears the summary and restores world input.
10. The displayed next-day weather matches the authoritative current weather.
11. The existing complete turnip loop remains playable across repeated days.

Deterministic rain selection, rain-driven crop growth, the cutoff boundary, stamina exhaustion, and Day 14 are proved in pure tests. Browser acceptance does not gain a weather setter, clock setter, stamina setter, command hook, or test-only mutation API.

All existing foundation, farming, lifecycle, HMR, collision, depth, camera, stage-scaling, and map-edge acceptance remains green. Existing sleep helpers are updated to acknowledge the morning summary explicitly.

### Final macOS gate

Completion requires:

- deterministic asset generation with no asset diff;
- Svelte and TypeScript checks with zero diagnostics;
- the complete Bun unit suite;
- the complete Playwright suite;
- the production frontend build;
- a production-hook scan with no development-hook matches;
- Cargo check;
- the clean-checkout verifier;
- the Tauri macOS application and arm64 DMG build;
- DMG integrity and artifact metadata inspection; and
- a bounded native visual smoke of the shared HUD and day-transition presentation when the desktop interaction boundary is reliable.

The existing Phaser chunk-size advisory and unsigned/ad-hoc local packaging remain documented constraints. This slice does not claim Developer ID signing, notarization, or distribution readiness.

## Delivery boundary

HPA-592 is complete when a normal player can spend exact farming time and stamina, see the current time and weather, benefit from rain, sleep into one guarded morning summary, explicitly start the next day with restored stamina, repeat the HPA-591 turnip loop across days, and play Day 14 without advancing beyond it.

The authoritative state must remain pure, fresh, JSON-serializable, and protected from duplicate transitions. Existing HPA-588 and HPA-591 behavior must remain intact.

HPA-593, not this slice, will add money, shipping, and the first shop.
