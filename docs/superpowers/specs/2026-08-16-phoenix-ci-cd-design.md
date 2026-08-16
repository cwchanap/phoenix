# Phoenix CI/CD design

## Goal

Add a GitHub Actions quality gate for Phoenix that builds and lints the
application, enforces at least 90% measured unit-test coverage, uploads the
coverage report, runs the existing browser end-to-end suite, and proves that
the macOS Tauri application bundles successfully.

This is CI only. It does not publish releases, sign or notarize macOS bundles,
or change Phoenix's macOS-only support policy.

## Current constraints

- Phoenix uses Bun 1.3.1, bun:test, Playwright, Svelte, and Tauri 2.
- The existing Playwright suite is browser-based; there is no native
  tauri-driver harness. It is the established exhaustive interaction proof.
- The native acceptance boundary is a macOS Tauri build.
- The current unit suite emits 97.59% line coverage and 97.14% function
  coverage in Bun LCOV output. Bun reports no branch totals for this suite.
- The repository intentionally pins direct JavaScript dependencies in
  tests/config/scaffold.test.ts, so adding quality tooling must update that
  contract and Bun's lockfile together.

## Chosen approach

One workflow, CI, runs on pushes, pull requests, and manual dispatches. A
concurrency group cancels superseded runs for the same workflow/ref pair.
Workflow permissions are least-privilege: repository contents are read-only,
with an OIDC identity token only for the Codecov upload.

### 1. Build and lint

An Ubuntu job installs the Bun version declared by package.json with a frozen
lockfile, then runs:

1. static Svelte/TypeScript checking;
2. ESLint;
3. Prettier in check mode; and
4. the Vite production build.

This job is named Build and lint so it can be selected as a required GitHub
status check.

### 2. Unit coverage

A second Ubuntu job creates coverage/lcov.info with Bun's native coverage
output. A small repository-owned coverage checker reads LCOV summaries and
fails unless both measurable line and function coverage are at least 90%.
Missing, malformed, or zero-total measured metrics fail rather than passing
silently.

Branch coverage is explicitly not gated because the current Bun report has no
branch total. Treating zero measured branches as 100% would make the gate
misleading. If Bun later emits branch data, the checker can add the same 90%
requirement without changing the workflow contract.

The successful LCOV file is both:

- uploaded to Codecov using the official Codecov action with OIDC
  authentication and fail-on-upload-error enabled; and
- retained as a GitHub Actions artifact for inspection independent of the
  external service.

The local checker is the coverage gate. Codecov is the reporting destination,
not the only enforcement mechanism.

### 3. Desktop E2E and Tauri build

A macOS job installs the pinned Bun runtime and Rust 1.96, installs dependencies
from the frozen lockfile, installs Playwright Chromium, runs the existing
browser E2E suite, and runs the existing Tauri build command. This preserves
the project boundary selected during design: browser tests prove application
interaction, while the macOS build proves the native bundle can be produced.

Failure-only Playwright reports and traces are uploaded for diagnosis. A
successful Tauri app/DMG bundle is uploaded as a short-retention CI artifact.
No artifact is released to users.

## Local developer quality checks

The repository gains:

- an ESLint flat configuration covering TypeScript and Svelte source, tests,
  and tools while ignoring generated output;
- Prettier configuration and ignores matching the generated/build directories;
- scripts for linting, formatting, generating coverage, and checking the
  coverage threshold;
- Husky's prepare hook; and
- a pre-commit hook that invokes lint-staged.

lint-staged applies ESLint autofixes followed by Prettier to staged TypeScript,
JavaScript, and Svelte files, and Prettier to staged JSON, CSS, Markdown, and
YAML files. It does not run the full test suite at commit time.

## Validation plan

Implementation follows a focused red-green cycle:

1. Add configuration tests that specify the new scripts, quality-tool
   dependencies, hook, workflow jobs, coverage artifact/upload, and required
   commands.
2. Add tests for the LCOV checker using passing, below-threshold, malformed,
   and unmeasured-branch fixtures.
3. Observe those tests fail before adding the workflow and checker.
4. Add the smallest configuration and checker implementation that makes the
   tests pass.
5. Run lint, Prettier check, static check, unit tests with coverage, the
   90% coverage checker, browser E2E, Vite build, and macOS Tauri build.

GitHub branch protection is a repository setting outside this local checkout.
After the workflow is pushed to a GitHub repository, protect the target branch
and require the Build and lint, Unit coverage, and Desktop E2E and Tauri build
checks to make GitHub block merges on a failure.

## Expected files

- Create .github/workflows/ci.yml.
- Create the ESLint, Prettier, Husky, lint-staged, and coverage-checker files.
- Modify package.json, bun.lock, .gitignore, README.md, and the existing
  scaffold contract test.
- Add focused configuration and coverage-checker tests.

## Scope boundaries

- No native tauri-driver/WebDriver suite is introduced.
- No Linux or Windows Tauri support is asserted.
- No GitHub release, deployment, signing, notarization, or branch-protection
  API mutation is performed.
