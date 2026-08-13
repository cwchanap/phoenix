# Task 8 report — Phoenix foundation handoff

Date: 2026-08-12  
Worktree: `/Users/chanwaichan/workspace/phoenix/.worktrees/hpa-588-foundation`  
Branch: `codex/hpa-588-foundation`

## RED / GREEN

- RED: `rtk bun test tests/config/handoff.test.ts` failed 2 tests because
  `README.md` and `tools/verify-clean-checkout.ts` were absent (the existing
  `verify:clean` package script assertion passed).
- GREEN: after adding the handoff test, verifier, and README, the focused test
  passed 4/4 with 45 assertions. The contract includes the exact seven-command
  matrix, committed `HEAD` archive, inherited subprocess output, first-failure
  abort, and exact temporary-path cleanup.
- The first static check exposed a Bun typing issue in the new verifier:
  `Bun.spawn` requires mutable `string[]` argv. A focused contract assertion
  reproduced the readonly-array defect; changing only the verifier argv types
  made the regression pass and restored `svelte-check` to 0 errors/0 warnings.
- The first committed `verify:clean` run exposed one clean-checkout defect:
  the archived tar has no `.git` directory, so the scaffold's required
  `git check-ignore` assertion returned exit 128. A focused regression now
  requires `run(['git', 'init'], checkout)` after extraction; the minimal fix
  was committed separately as `e8a75b0` before further committed verifier runs.

## Fresh local automated matrix

Ran in the approved order from this checkout:

```text
rtk bun run assets:generate       PASS
rtk bun run check                 PASS — 0 errors, 0 warnings
rtk bun test                      PASS — 73 tests, 0 failures
rtk bun run test:e2e              PASS — 14 tests, 0 failures (private 1422)
rtk bun run build                 PASS — Vite 8.2.1 (existing >500 kB chunk warning)
rtk bun run tauri:build           PASS — macOS app + DMG (outside-sandbox hdiutil)
```

The first in-sandbox `tauri:build` compiled the release app but failed at
`hdiutil create failed - Device not configured`. A minimal hdiutil probe failed
the same way in-sandbox and passed with host access; rerunning the exact Tauri
build outside the sandbox completed both bundles. This is an execution
environment boundary, not a Phoenix source defect.

Artifacts:

- `src-tauri/target/release/bundle/macos/Phoenix.app` — 8.3 MB directory
  payload; `CFBundleIdentifier=com.hapadona.phoenix`, `CFBundleName=Phoenix`,
  `CFBundleExecutable=phoenix`, arm64 Mach-O, ad-hoc linker signature.
- `src-tauri/target/release/bundle/dmg/Phoenix_0.1.0_aarch64.dmg` — 3,163,632
  bytes; UDZO read-only compressed image, CRC32 checksum.

These are local/development artifacts, not distribution-ready packages. The
native smoke below proves that the app launches, and both the local and clean
archive Tauri build acceptance passed. The retained `.app` is nevertheless
only ad-hoc linker-signed: it has no Team ID or valid signing identity,
`Info.plist` is unbound, and sealed resources are absent. Strict
`codesign --verify --deep --strict` exits 1 with
`code has no resources but signature indicates they must be present`.
Gatekeeper assessment is likewise not valid: an observed `spctl` path reported
an internal error, while a fresh explicit execute assessment exited 1 with the
same missing-resources signature diagnostic. HPA-588 does not claim Developer
ID signing, notarization, or distribution readiness, so no signing-policy
change was made in this foundation task.

## Decisive committed archive verification

At exact committed `HEAD` `ea4dc71a4a5359f0bf6fcc15d4cd8091481342e9`,
one host-boundary `rtk bun run verify:clean` run completed GREEN. There was no
retry or test/config edit between preflight and completion. Its exact seven
stages ran in order:

1. `bun install --frozen-lockfile` — PASS (62 packages installed).
2. `bun run test:e2e:install` — PASS (Chromium installed/resolved).
3. `bun run check` — PASS (0 errors, 0 warnings).
4. `bun test` — PASS (74 tests, 0 failures, 181 expectations across 9 files).
5. `bun run test:e2e` — PASS (14 tests, 0 failures in 1.1 minutes on private
   port 1422).
6. `bun run build` — PASS with the existing >500 kB Vite chunk advisory.
7. `bun run tauri:build` — PASS; the optimized release compile completed in
   2 minutes 22 seconds and Tauri finished both `Phoenix.app` and the DMG.

The archived bundle paths were
`/private/var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/phoenix-clean-4qGzpk/src-tauri/target/release/bundle/macos/Phoenix.app`
and
`/private/var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/phoenix-clean-4qGzpk/src-tauri/target/release/bundle/dmg/Phoenix_0.1.0_aarch64.dmg`.
The verifier then removed both the exact temporary checkout and its `.tar` in
`finally`; post-run `stat` confirmed both paths absent.

The retained worktree artifacts audited after the decisive run were:

- `Phoenix.app`: 8,524 KiB directory payload; 8,660,464-byte arm64 Mach-O;
  `CFBundleIdentifier=com.hapadona.phoenix`, version `0.1.0`, minimum macOS
  `10.13`, with the development-only signing classification above.
- `Phoenix_0.1.0_aarch64.dmg`: 3,163,632 bytes; UDZO/zlib, GUID/HFS+ image,
  CRC32 `$3DC82AB5`; `hdiutil verify` reported the checksum `VALID`.

The post-run repository audit remained at exact `ea4dc71`, clean, with
`rtk git diff --check` passing. No Task 8 Phoenix, archived-checkout,
Playwright/Vite-1422 process or port-1422 listener remained. Unrelated Lyra on
ports 1420/1421 and old global Playwright/MCP browsers were not touched.

## Browser visual smoke

Chromium screenshots were captured outside the repository at exact logical
sizes and inspected with the image viewer:

- `/private/tmp/phoenix-browser-640x360.png` — 24.0 KB, 1x.
- `/private/tmp/phoenix-browser-1280x720.png` — 56.8 KB, 2x.

Both show crisp diamond/sprite pixels, aligned canvas and overlay, farm patch,
tree, building, player, target diamond, expected letterboxing, and no camera
bound clipping.

## Native macOS smoke

Port 1420 was rechecked and found owned by unrelated Lyra PID 1674 (1421 was
also owned by that process); neither process was terminated or modified. The
native dev smoke used a temporary outside-repository overlay at
`/private/tmp/phoenix-tauri-smoke.json`, changing only `beforeDevCommand` and
`devUrl` to verified-free port 1423. The actual Tauri dev process compiled and
ran as `target/debug/phoenix` (PID 80789), with Vite PID 80723.

The native Phoenix window was located with CoreGraphics as CGWindowID 114850,
1280×720 bounds, and captured at:

- `/private/tmp/phoenix-native-window.png` — 404.9 KB, actual Tauri dev window.
- `/private/tmp/phoenix-native-release-before.png` and
  `/private/tmp/phoenix-native-release-after-native-input.png` — release-app
  diagnostic captures retained outside the repo.

The dev capture directly proves a real Phoenix titlebar/window and browser
parity of the proof world (farm, tree, building, player, target, crisp pixels,
aligned overlay). macOS Accessibility/System Events exposed no WebView window
(`count of windows=0`) and the dev process was occluded behind unrelated
applications. Coordinate clicks therefore targeted the frontmost unrelated
application; NSRunningApplication activation did not provide a stable focus
boundary. A release-app diagnostic showed a player displacement after a
controlled Quartz key probe while the overlay still displayed `World input:
Locked`, so that probe is not treated as valid lock/movement evidence. No
unobserved claims are made for native WASD, overlay lock, edge targeting,
depth, resize, or native HMR interactions. The exact Task 8-created native
dev processes were stopped; no Phoenix or 1423 listener remains.

A later focused release smoke used only PID-targeted CoreGraphics/AppKit
events, with temporary tooling and captures under `/private/tmp`. The release
app was exact PID 98359; CoreGraphics identified Phoenix window 115762 at
1280×720 bounds `(x=116, y=91)`. `NSRunningApplication.activate` returned true
and directly reported Phoenix active and frontmost at PID 98359. The exact
window captures were:

- `/private/tmp/phoenix-native-p98359-w115762-focus-before.png` — directly
  shows the release world and overlay text `World input: Active` after focus.
- `/private/tmp/phoenix-native-p98359-w115762-after-d500.png` — directly shows
  substantial player displacement after a D key (virtual keycode 2) was posted
  only to PID 98359 for 500 ms.

This focused smoke therefore adds direct native release evidence for activation
and real WASD movement. A PID-targeted lock-button click was attempted, but its
exact-window capture
`/private/tmp/phoenix-native-p98359-w115762-after-lock-click.png` contained
blank WebView content, so it is excluded from acceptance evidence. Lock/block/
unlock, outward-edge target hiding, both sides of tree/building depth, resize,
and HMR remain not directly native-observed. The 14/14 Playwright acceptance
suite covers those behaviors in the identical frontend; this does not turn
them into native-observed claims. PID 98359 had no direct children, received
SIGTERM only, and both PID/child checks were empty afterward. No port-1422 or
port-1423 listener remained, the branch was clean, and `rtk git diff --check`
passed.

After reassessing this focused release evidence together with the identical-
frontend browser coverage, the independent Task 8 reviewer cleared the
HPA-588 native-evidence blocker under the brief's fallback. Human replay is
not required for Task 8 acceptance; the direct-native limitations above remain
explicitly retained.

## Source and repository audit

- `ProofWorld`, collision, targeting, and facing matches are confined to the
  framework-free core; `src/components/GameHost.svelte` only clones/publishes
  snapshots for presentation.
- No `Phaser` or `svelte` imports appear under `src/game/core`.
- No forbidden `package-lock.json`, `pnpm-lock.yaml`, or `yarn.lock` exists;
  Bun and Cargo remain the committed lockfiles.
- `rtk git diff --check` passed.

## Scope and handoff

This report covers macOS only. It makes no Windows/Linux verification claim,
does not touch Linear, and does not add Swift/Xcode wrapper files. The handoff
files are `README.md`, `tools/verify-clean-checkout.ts`, and
`tests/config/handoff.test.ts`; the verifier archives committed `HEAD` and
removes only its exact temporary checkout and tar paths in `finally`.

The handoff commit is `b7795fa`; the archive Git bootstrap fix is `e8a75b0`.
After `e8a75b0`, the first two browser-bearing clean-checkout runs preserved
below reached archived install, static checks, and 74/74 unit tests, then
exposed timing-sensitive browser acceptance:

- First run: 11/14 passed; HMR movement, farm traversal, and map-edge route
  timed out.
- Second unchanged run: 13/14 passed; only the bottom-right target-route
  test timed out (`x=8.3257`, `y=11.52`, facing right, target still visible).

An immediate standalone `rtk bun run test:e2e` outside the archive passed 14/14.
Per Task 8 scope, no retry policy was added. Later committed archive runs also
remained recorded rather than overwritten by the final success:

- At `e87e168`, 13/14 passed; the tree-detour test timed out just before its
  x-axis threshold (`x=5.98365`, required `>=6.1`).
- At `f7bf939`, 12/14 passed; the HMR movement-ratio assertion and the
  reachable-map-edge route timed out.

The final reviewed Task 7 acceptance commits are `f7bf939` (shorter tree
acceptance setup route), `1709011` (hardened HMR and edge acceptance proof),
and `ea4dc71` (corrected the HMR acceptance oracle). The decisive single clean
archive run at `ea4dc71` then passed all seven stages as recorded above. The
historical failures remain part of this report; the final verified repository
state before this report-only update was clean at `ea4dc71`.
