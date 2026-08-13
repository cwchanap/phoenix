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
  is pending its separate defect-fix commit and a fresh committed verifier run.

## Fresh automated matrix

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

The handoff commit is `b7795fa`. The follow-up verifier defect fix and fresh
`verify:clean` result must be recorded after that fix commit; the working tree
must be clean before Task 8 is handed back for review.
