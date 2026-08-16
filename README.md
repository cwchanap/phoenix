# Phoenix

Phoenix combines the HPA-588 foundation slice, the HPA-591 turnip day-loop
slice, the HPA-592 daily-rhythm slice, and HPA-593's three-crop economy loop: a
browser and Tauri proof world where you can move through the authored map, hoe,
plant, water, and harvest Turnip, Potato, and Pumpkin crops; buy seeds at the
Seed shop; deposit harvests in the Shipping bin; sleep for itemized Shipping
income; and reinvest the proceeds. HPA-592 adds an action-driven clock and
stamina, sunny and rainy days, and a blocking morning summary. This macOS-first
farming MVP is verified on macOS only; it does not claim acceptance for Windows or Linux.

## Prerequisites

- macOS
- Bun 1.3.1
- Rust/Cargo 1.96
- Xcode command-line tools

## Setup

```bash
bun install
bun run test:e2e:install
```

## Run

Start the browser at the strict development URL with:

```bash
bun run dev
```

Run the desktop shell with:

```bash
bun run tauri:dev
```

## Controls and three-crop economy (HPA-593)

Controls are keyboard-first: WASD moves in screen-relative directions; `1 Hoe`,
`2 Seeds`, `3 Water`, and `4 Hands` select the farming action. Seeds uses the
currently selected crop kind. Press Space to apply the selected action to the
highlighted farm cell. The Select Turnip, Select Potato, and Select Pumpkin
buttons change the seed kind without changing the farming action.

Press E to open sleep, Seed shop, or Shipping bin from its highlighted authored
target. The shop and shipping dialogs use minus, plus, Max controls, explicit
Buy/Deposit actions, Escape/Close dismissal, and a world-input lock. The
overlay input lock prevents keyboard movement while it is enabled; unlock it
to resume movement.

Each new session starts with 150G and three turnip seeds. Crop growth and
prices are fixed by this table:

| Crop | Growth | Seed price | Sale price |
| --- | --- | ---: | ---: |
| Turnip | 3 watered nights | 20G | 35G |
| Potato | 5 watered nights | 40G | 75G |
| Pumpkin | 7 watered nights | 70G | 140G |

Deposits are final and free. One successful sleep credits itemized Shipping
income once and clears the pending shipment before the blocking Morning
summary. The 290G/210G acceptance example demonstrates reinvest: after buying
one Potato seed and one Pumpkin seed, shipping one mature crop of each kind
plus one Turnip yields 250G of Shipping income and 290G total; buying four
Turnip seeds for 80G leaves 210G. This demonstrates the loop without making
that balance a guaranteed general session outcome.

## Daily rhythm (HPA-592)

Each new session starts on Day 1 at 06:00 with 20 stamina and Sunny weather.
Successful farming actions drive the clock and consume stamina; walking, action
selection, sleep confirmation, and summary acknowledgment are free. An action
must finish by 22:00, and a valid action that is short on both time and stamina
reports the time cutoff first. The exact farming costs are:

| Action | Time | Stamina |
| --- | ---: | ---: |
| Hoe | 30 minutes | 3 |
| Plant | 20 minutes | 1 |
| Water | 20 minutes | 2 |
| Harvest | 20 minutes | 1 |

Rainy days automatically water planted crops and render tilled farm soil wet.
Manual watering on a rainy day is rejected without spending time or stamina;
Sunny days use the Water cost above.

Sleep is a two-stage flow. Press E at the bed to open the confirmation panel;
Confirm advances the authoritative session once and keeps world input locked
while the blocking Morning summary is shown. The summary reports the completed
day, crops advanced, next day, next weather, and stamina restored. Select
`Start Day N` to acknowledge it; only then does world input resume. Canceling
the confirmation releases the lock without changing the farm.

Day 14 is fully playable, but sleeping there returns the temporary final-day
result instead of advancing to Day 15. HPA-597 will replace this boundary with
the finale.

## Verification and builds

```bash
bun run check
bun test
bun run test:e2e
bun run build
bun run tauri:build
bun run verify:clean
```

`verify:clean` archives the committed `HEAD` into a temporary checkout and
runs the complete frozen-install, browser, static-check, unit-test, frontend,
and macOS Tauri build matrix there.

## Architecture and authored map contract

- Framework-free TypeScript owns projection, movement, collision, facing, and
  targeting rules. `GameSession` is the authority for the day, selected
  action, farm tiles, crop growth, and inventory.
- Phaser owns the world/render adapter, camera, assets, and keyboard sampling.
- Svelte owns the fitted stage and screen-space overlay, including the HUD,
  action buttons, feedback, sleep confirmation, and input lock presentation.
- Tauri remains the unchanged macOS-only desktop shell; gameplay authority
  stays in the frontend rules layer.

The existing compact 12×12 (12x12) world is a finite logical grid using 64×32
(64x32) 2:1 isometric tiles and embedded Tiled tilesets. The authored shop cell 6,7
is the adjacent shop-counter cell at 6,7 beside the existing building, while the
shipping cell 6,10 is the authored shipping-bin target. Economy scenery uses the
three-frame 288×96 scenery sheet; the compact world, map IDs, and collision routes
remain stable.
