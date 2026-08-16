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
- Bun 1.3.1 produces LCOV and honors coverage exclusions, but a deliberately
  below-threshold probe did not make its bunfig coverageThreshold setting fail
  the test process. The 90% gate therefore cannot rely on that setting while
  the repository remains pinned to Bun 1.3.1.
- The repository intentionally pins direct JavaScript dependencies in
  tests/config/scaffold.test.ts, so adding quality tooling must update that
  contract and Bun's lockfile together.

## Chosen approach

One workflow, CI, runs on pushes, pull requests, and manual dispatches. A
concurrency group cancels superseded runs for the same workflow/ref pair.
Workflow permissions are least-privilege: repository contents are read-only,
with an OIDC identity token only for the Codecov upload. It has two required
jobs so browser failures and native bundle failures are independently visible.

### 1. Quality

An Ubuntu job installs the Bun version declared by package.json with a frozen
lockfile, then runs:

1. static Svelte/TypeScript checking;
2. ESLint;
3. Prettier in check mode; and
4. Bun unit tests with LCOV coverage;
5. the repository-owned 90% coverage checker;
6. the existing Playwright browser E2E suite; and
7. the Vite production build.

This job is named Quality so it can be selected as a required GitHub status
check. It invokes package scripts rather than embedding a second command list
in workflow YAML.

### 2. Unit coverage reporting

A Quality-job step creates coverage/lcov.info with Bun's native coverage
output. A small repository-owned coverage checker reads LCOV summaries and
fails unless both measurable line and function coverage are at least 90%.
Missing, malformed, or zero-total measured metrics fail rather than passing
silently.

Branch coverage is explicitly not gated because the current Bun report has no
branch total. Treating zero measured branches as 100% would make the gate
misleading. If Bun later emits branch data, the checker can add the same 90%
requirement without changing the workflow contract.

The LCOV scope is explicit in bunfig.toml: test files, tools, and generated
output do not enter the application-coverage denominator. This makes the
90% contract stable while preserving coverage for production files imported by
the unit suite.

The LCOV file is both:

- uploaded to Codecov using the official Codecov action with OIDC
  authentication; and
- retained as a GitHub Actions artifact for inspection independent of the
  external service.

The local checker is the coverage gate. Codecov is the user-requested reporting
destination and does not block merges when that external service is unavailable.

### 3. Tauri build

A macOS job installs the pinned Bun runtime and Rust 1.96, installs dependencies
from the frozen lockfile, and runs the existing Tauri build command with
--no-sign. This avoids depending on a hosted runner's signing identities and
does not alter local Tauri signing policy. This preserves the project boundary
selected during design: browser tests prove application interaction on Ubuntu,
while the macOS build proves an unsigned native bundle can be produced.

Failure-only Playwright reports and traces are uploaded from Quality. A
successful unsigned Tauri app/DMG bundle is uploaded from the macOS job as a
short-retention CI artifact. No artifact is released to users.

## Local developer quality checks

The repository gains:

- an ESLint flat configuration covering TypeScript and Svelte source, tests,
  and tools while ignoring generated output;
- Prettier configuration and ignores matching the generated/build directories;
- bunfig.toml coverage scope for the Bun test runner;
- scripts for linting, formatting, generating coverage, and checking the
  coverage threshold;
- Husky's prepare hook; and
- a pre-commit hook that invokes lint-staged.

lint-staged applies ESLint autofixes followed by Prettier to staged TypeScript,
JavaScript, and Svelte files, and Prettier to staged JSON, CSS, Markdown, and
YAML files. It does not run the full test suite at commit time.

The CI workflow and clean-checkout verifier set HUSKY=0 while installing
dependencies. That leaves the requested hook active for developers without
installing Git hooks in ephemeral CI or archive checkouts.

## Validation plan

Implementation follows a focused red-green cycle:

1. Extend the existing scaffold and handoff contracts with the scripts,
   quality-tool dependencies, coverage scope, hook, two workflow jobs,
   coverage artifact/upload, local matrix, and required commands.
2. Add tests for the LCOV checker using passing, below-threshold, malformed,
   and unmeasured-branch fixtures.
3. Observe the existing contract and checker tests fail before adding the
   workflow and checker.
4. Add the smallest configuration and checker implementation that makes the
   tests pass.
5. Run lint, Prettier check, static check, unit tests with coverage, the
   90% coverage checker, browser E2E, Vite build, unsigned macOS Tauri build,
   and the full clean-checkout verifier.

GitHub branch protection is a repository setting outside this local checkout.
After the workflow is pushed to a GitHub repository, protect the target branch
and require the Quality and Tauri build checks to make GitHub block merges on
a failure.

## Expected files

- Create .github/workflows/ci.yml, bunfig.toml, eslint.config.js,
  .prettierrc.json, .prettierignore, .husky/pre-commit, and
  tools/check-coverage.ts.
- Modify package.json, bun.lock, .gitignore, README.md,
  tools/verify-clean-checkout.ts, tests/config/scaffold.test.ts, and
  tests/config/handoff.test.ts.
- Add focused configuration and coverage-checker tests.

## Scope boundaries

- No native tauri-driver/WebDriver suite is introduced.
- No Linux or Windows Tauri support is asserted.
- No GitHub release, deployment, signing, notarization, or branch-protection
  API mutation is performed.
