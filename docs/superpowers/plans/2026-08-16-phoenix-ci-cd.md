# Phoenix CI/CD Quality Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions CI gate that lint-checks and builds Phoenix, runs unit tests and browser E2E, produces/uploads LCOV, locally enforces at least 90% line and function coverage, and proves an unsigned macOS Tauri bundle can be built.

**Architecture:** Keep all quality policy in package scripts and repository-owned configuration. The Ubuntu `Quality` job invokes those scripts for static checks, unit/coverage, browser E2E, and Vite output. The macOS `Tauri build` job only proves the native unsigned bundle. A small LCOV parser is the authoritative coverage gate because Bun 1.3.1 does not enforce `coverageThreshold`; Codecov and Actions artifacts are reporting surfaces only.

**Tech Stack:** Bun 1.3.1, bun:test, LCOV, ESLint 10.8.1 with TypeScript-ESLint and eslint-plugin-svelte, Prettier 3.9.6 with prettier-plugin-svelte, Husky 9.1.7, lint-staged 17.3.0, GitHub Actions, Playwright 1.62.1, Tauri CLI 2.11.4, and Rust 1.96 on macOS.

## Global Constraints

- Preserve the current runtime pins, Bun lockfile policy, browser-based Playwright suite, macOS-only native support statement, and existing `verify:clean` archive model.
- Add only the approved developer tooling: `@eslint/js@10.0.1`, `eslint@10.8.1`, `eslint-config-prettier@10.1.8`, `eslint-plugin-svelte@3.23.0`, `globals@17.11.0`, `husky@9.1.7`, `lint-staged@17.3.0`, `prettier@3.9.6`, `prettier-plugin-svelte@4.1.1`, and `typescript-eslint@8.67.0`. Update `bun.lock` in the same change.
- The 90% gate applies only to measured **line** and **function** coverage. Missing, malformed, or zero-total values fail. Branch coverage remains explicitly out of scope until Bun emits a meaningful branch denominator.
- Coverage scope is declared in `bunfig.toml`: test files, tools, and generated/build output are excluded from the denominator. Do not exclude production TypeScript or Svelte source merely to increase the percentage.
- `Quality` is the only Ubuntu job and owns Chromium installation, browser E2E, LCOV, and Codecov. `Tauri build` is the only macOS job and must not install Playwright or run browser E2E.
- Both CI installs and archive-checkout installs set `HUSKY=0`. Developers retain the requested pre-commit hook.
- Use `bun run tauri:build -- --no-sign` for every CI/clean native build. Do not add signing, notarization, releases, deployment, a native tauri-driver suite, Linux/Windows support claims, caches, or branch-protection API calls.
- Keep workflow commands public package scripts; only `bun install --frozen-lockfile` and Actions setup commands may remain raw workflow commands.
- Pin the workflow action references selected during planning: `actions/checkout@v7`, `oven-sh/setup-bun@v2`, `actions/upload-artifact@v7`, `codecov/codecov-action@v7`, and `dtolnay/rust-toolchain@1.96.0`.
- Run a genuine focused RED command before each production/configuration implementation, then focused GREEN. Finish with the full local matrix and `rtk git diff --check` before claiming completion.

## File Map

### New files

- `.github/workflows/ci.yml`
- `.husky/pre-commit`
- `.prettierignore`
- `.prettierrc.json`
- `bunfig.toml`
- `eslint.config.js`
- `tests/tools/check-coverage.test.ts`
- `tools/check-coverage.ts`

### Modified files

- `.gitignore`
- `README.md`
- `bun.lock`
- `package.json`
- `tests/config/handoff.test.ts`
- `tests/config/scaffold.test.ts`
- `tools/verify-clean-checkout.ts`

---

### Task 1: Pin local quality tooling, formatting, and developer hook

**Files:**

- Create: `eslint.config.js`, `.prettierrc.json`, `.prettierignore`, `bunfig.toml`, `.husky/pre-commit`
- Modify: `package.json`, `bun.lock`, `.gitignore`, `tests/config/scaffold.test.ts`

**Interfaces:**

- `package.json` exposes `lint`, `lint:fix`, `format`, `format:check`, `prepare`, `test:coverage`, `coverage:check`, and `test:e2e:install:ci` alongside all existing scripts.
- ESLint checks JavaScript, TypeScript, and Svelte source/tests/tools without styling-rule conflicts from Prettier.
- `lint-staged` formats staged JSON/CSS/Markdown/YAML and runs ESLint autofix then Prettier on staged JavaScript/TypeScript/Svelte files.
- The actual coverage checker is introduced in Task 2; this task creates only its script boundary.

- [ ] **Step 1: Extend the scaffold contract first**

In `tests/config/scaffold.test.ts`, expand the direct-dev-dependency assertion to the following exact object, preserving the existing dependency assertion:

~~~ts
expect(pkg.devDependencies).toEqual({
  '@eslint/js': '10.0.1',
  '@playwright/test': '1.62.1',
  '@sveltejs/vite-plugin-svelte': '7.3.0',
  '@tauri-apps/cli': '2.11.4',
  '@typescript/native': 'npm:typescript@7.0.2',
  '@types/bun': '1.3.14',
  eslint: '10.8.1',
  'eslint-config-prettier': '10.1.8',
  'eslint-plugin-svelte': '3.23.0',
  globals: '17.11.0',
  husky: '9.1.7',
  'lint-staged': '17.3.0',
  prettier: '3.9.6',
  'prettier-plugin-svelte': '4.1.1',
  'svelte-check': '4.7.5',
  typescript: '6.0.3',
  'typescript-eslint': '8.67.0',
  vite: '8.2.1',
});
~~`

Add a test that requires these exact scripts and lint-staged policy:

~~~ts
expect(pkg.scripts).toMatchObject({
  lint: 'eslint .',
  'lint:fix': 'eslint . --fix',
  format: 'prettier --write .',
  'format:check': 'prettier --check .',
  prepare: 'husky',
  'test:coverage': 'bun test --coverage --coverage-reporter=lcov',
  'coverage:check': 'bun run tools/check-coverage.ts',
  'test:e2e:install:ci': 'playwright install --with-deps chromium',
});
expect(pkg['lint-staged']).toEqual({
  '*.{js,mjs,cjs,ts,svelte}': ['eslint --fix', 'prettier --write'],
  '*.{json,css,md,yml,yaml}': 'prettier --write',
});
~~`

Also test that `eslint.config.js`, `.prettierrc.json`, `.prettierignore`, `bunfig.toml`, and `.husky/pre-commit` exist; parse `.prettierrc.json` and require `printWidth: 100`, `singleQuote: true`, `trailingComma: 'all'`, and `plugins: ['prettier-plugin-svelte']`. Check `.gitignore` ignores `coverage/probe/lcov.info` via `git check-ignore --quiet`.

- [ ] **Step 2: Observe RED before adding packages or configuration**

Run: `rtk bun test tests/config/scaffold.test.ts`

Expected: FAIL because the direct dependencies, scripts, files, and coverage ignore entry do not yet exist.

- [ ] **Step 3: Add the exact packages and configuration**

Run exactly once to update both manifest and `bun.lock`:

~~~bash
rtk bun add --dev @eslint/js@10.0.1 eslint@10.8.1 eslint-config-prettier@10.1.8 eslint-plugin-svelte@3.23.0 globals@17.11.0 husky@9.1.7 lint-staged@17.3.0 prettier@3.9.6 prettier-plugin-svelte@4.1.1 typescript-eslint@8.67.0
~~~

Then use `apply_patch` to add the script and lint-staged entries from Step 1 to `package.json`. Add `coverage/` to `.gitignore`.

Create `eslint.config.js` exactly as the flat config below. It deliberately puts Prettier last and excludes generated/non-source trees rather than relaxing source rules:

~~~js
import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import tseslint from 'typescript-eslint';
import svelteConfig from './svelte.config.js';

export default tseslint.config(
  {
    ignores: [
      'coverage/**',
      'dist/**',
      'node_modules/**',
      'playwright-report/**',
      'test-results/**',
      '.svelte-check/**',
      'src-tauri/target/**',
      'src-tauri/gen/**',
      'src/assets/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs.recommended,
  {
    files: ['**/*.{js,mjs,cjs,ts,svelte}'],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
  },
  {
    files: ['**/*.svelte'],
    languageOptions: {
      parserOptions: {
        extraFileExtensions: ['.svelte'],
        parser: tseslint.parser,
        svelteConfig,
      },
    },
  },
  prettier,
);
~~~

Create `.prettierrc.json`:

~~~json
{
  "plugins": ["prettier-plugin-svelte"],
  "printWidth": 100,
  "singleQuote": true,
  "trailingComma": "all"
}
~~~

Create `bunfig.toml` now so the new `test:coverage` script has its approved,
explicit denominator before it is ever run. Task 2 will exercise this policy
against a real LCOV report:

~~~toml
[test]
coverageSkipTestFiles = true
coveragePathIgnorePatterns = [
  "coverage/**",
  "dist/**",
  "node_modules/**",
  "playwright-report/**",
  "test-results/**",
  ".svelte-check/**",
  "src-tauri/**",
  "tests/**",
  "tools/**",
]
~~~

Create `.prettierignore` with the generated/build trees and planning documents that should not receive a mechanical formatting rewrite:

~~~gitignore
node_modules/
dist/
coverage/
playwright-report/
test-results/
.svelte-check/
src-tauri/target/
src-tauri/gen/
src/assets/
src-tauri/icons/
bun.lock
src-tauri/Cargo.lock
docs/superpowers/
~~~

Create `.husky/pre-commit`:

~~~sh
#!/usr/bin/env sh
bunx lint-staged
~~~

Run `rtk chmod +x .husky/pre-commit` after creating it. Do not use Husky's legacy generated `_` shim or add test execution to the hook.

- [ ] **Step 4: Establish a format and lint baseline, then run focused GREEN**

Run: `rtk bun run format`

Inspect the resulting diff. Keep only deterministic formatting changes and configuration/package updates; do not change production behavior to satisfy a style tool.

Run in this order:

~~~bash
rtk bun run lint
rtk bun run format:check
rtk bun run check
rtk bun test tests/config/scaffold.test.ts
~~~

Expected: all four commands pass. If ESLint identifies an existing source issue, fix the smallest local source violation rather than disabling the relevant rule globally.

- [ ] **Step 5: Review and commit the local quality slice**

Run:

~~~bash
rtk git diff --check
rtk git diff -- . ':!bun.lock'
~~~

Verify the hook invokes only `bunx lint-staged`, the source ignores are limited to generated/build trees, and the pinned dependencies match the test. Commit:

~~~bash
rtk git add package.json bun.lock .gitignore eslint.config.js .prettierrc.json .prettierignore .husky/pre-commit tests/config/scaffold.test.ts
rtk git commit -m "chore: add local quality tooling"
~~~

### Task 2: Implement and test the repository-owned LCOV gate

**Files:**

- Create: `tools/check-coverage.ts`, `tests/tools/check-coverage.test.ts`
- Verify: `bunfig.toml` (created in Task 1)

**Interfaces:**

- `summarizeLcov(lcov: string)` returns aggregated line/function covered, total, and percentage data from LCOV summary entries.
- `assertCoverage(lcov: string, threshold = 90)` returns the same summary on success and throws on malformed, absent, zero-total, or below-threshold required metrics.
- When executed as a script, `tools/check-coverage.ts` reads `coverage/lcov.info` from the project root, prints both measured results, and exits nonzero on any rejected condition.

- [ ] **Step 1: Add focused failing parser tests**

Create `tests/tools/check-coverage.test.ts` and import the yet-to-exist exports:

~~~ts
import { describe, expect, test } from 'bun:test';
import { assertCoverage, summarizeLcov } from '../../tools/check-coverage';

const passingLcov = [
  'TN:',
  'SF:src/game/a.ts',
  'FNF:10',
  'FNH:9',
  'LF:100',
  'LH:90',
  'BRF:0',
  'BRH:0',
  'end_of_record',
].join('\n');

describe('check-coverage', () => {
  test('accepts exactly 90 percent measurable line and function coverage', () => {
    expect(summarizeLcov(passingLcov)).toEqual({
      lines: { covered: 90, total: 100, percentage: 90 },
      functions: { covered: 9, total: 10, percentage: 90 },
    });
    expect(assertCoverage(passingLcov)).toEqual(summarizeLcov(passingLcov));
  });

  test('combines totals across source records before deciding the threshold', () => {
    const report = `${passingLcov}\nSF:src/game/b.ts\nFNF:10\nFNH:9\nLF:100\nLH:90\nend_of_record`;
    expect(summarizeLcov(report).lines).toEqual({ covered: 180, total: 200, percentage: 90 });
    expect(summarizeLcov(report).functions).toEqual({ covered: 18, total: 20, percentage: 90 });
  });

  test('rejects either measured metric below 90 percent', () => {
    expect(() => assertCoverage(passingLcov.replace('LH:90', 'LH:89'))).toThrow(/line coverage/i);
    expect(() => assertCoverage(passingLcov.replace('FNH:9', 'FNH:8'))).toThrow(/function coverage/i);
  });

  test.each([
    ['missing function total', passingLcov.replace('FNF:10\n', '')],
    ['zero line denominator', passingLcov.replace('LF:100', 'LF:0').replace('LH:90', 'LH:0')],
    ['malformed summary', passingLcov.replace('FNH:9', 'FNH:not-a-number')],
    ['covered count above its denominator', passingLcov.replace('FNH:9', 'FNH:11')],
  ])('rejects %s', (_name, report) => {
    expect(() => assertCoverage(report)).toThrow();
  });
});
~~~

Run: `rtk bun test tests/tools/check-coverage.test.ts`

Expected: FAIL because `tools/check-coverage.ts` does not exist.

- [ ] **Step 2: Verify the Bun coverage denominator before exercising it**

Confirm that the `bunfig.toml` created in Task 1 contains this complete test policy. `coverageSkipTestFiles` is intentionally retained even though test paths are also explicit, so Bun's own test-file behavior and the documented scope agree.

~~~toml
[test]
coverageSkipTestFiles = true
coveragePathIgnorePatterns = [
  "coverage/**",
  "dist/**",
  "node_modules/**",
  "playwright-report/**",
  "test-results/**",
  ".svelte-check/**",
  "src-tauri/**",
  "tests/**",
  "tools/**",
]
~~~

- [ ] **Step 3: Add the minimal robust LCOV implementation**

Create `tools/check-coverage.ts`. Use `LF`/`LH` for line totals/covered lines and `FNF`/`FNH` for function totals/covered functions; sum each supported field across all records. Do not infer coverage from individual `DA` or `FNDA` lines because Bun already emits canonical summaries.

~~~ts
import { join } from 'node:path';

export interface CoverageMetric {
  covered: number;
  total: number;
  percentage: number;
}

export interface CoverageSummary {
  lines: CoverageMetric;
  functions: CoverageMetric;
}

function parseNonnegativeInteger(field: string, value: string): number {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${field} value: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new Error(`Invalid ${field} value: ${value}`);
  return parsed;
}

function summarizeMetric(
  lcov: string,
  name: 'line' | 'function',
  coveredField: string,
  totalField: string,
): CoverageMetric {
  let covered = 0;
  let total = 0;
  let coveredSeen = false;
  let totalSeen = false;
  for (const line of lcov.split(/\r?\n/)) {
    if (line.startsWith(`${coveredField}:`)) {
      covered += parseNonnegativeInteger(coveredField, line.slice(coveredField.length + 1));
      coveredSeen = true;
    }
    if (line.startsWith(`${totalField}:`)) {
      total += parseNonnegativeInteger(totalField, line.slice(totalField.length + 1));
      totalSeen = true;
    }
  }
  if (!coveredSeen || !totalSeen || total === 0 || covered > total) {
    throw new Error(`LCOV has no measurable ${name} coverage`);
  }
  return { covered, total, percentage: (covered / total) * 100 };
}

export function summarizeLcov(lcov: string): CoverageSummary {
  return {
    lines: summarizeMetric(lcov, 'line', 'LH', 'LF'),
    functions: summarizeMetric(lcov, 'function', 'FNH', 'FNF'),
  };
}

export function assertCoverage(lcov: string, threshold = 90): CoverageSummary {
  const summary = summarizeLcov(lcov);
  for (const [name, metric] of Object.entries(summary)) {
    if (metric.percentage < threshold) {
      throw new Error(`${name.slice(0, -1)} coverage ${metric.percentage.toFixed(2)}% is below required ${threshold.toFixed(2)}%`);
    }
  }
  return summary;
}

if (import.meta.main) {
  const coveragePath = join(process.cwd(), 'coverage', 'lcov.info');
  const report = Bun.file(coveragePath);
  if (!(await report.exists())) throw new Error(`Coverage report not found: ${coveragePath}`);
  const summary = assertCoverage(await report.text());
  console.log(`Coverage gate passed: lines ${summary.lines.percentage.toFixed(2)}%, functions ${summary.functions.percentage.toFixed(2)}%`);
}
~~~

- [ ] **Step 4: Run focused GREEN and prove the actual gate**

Run:

~~~bash
rtk bun test tests/tools/check-coverage.test.ts
rtk bun run test:coverage
rtk bun run coverage:check
~~~

Expected: parser tests pass; Bun writes `coverage/lcov.info`; the checker prints line and function percentages at or above 90%. Do not accept a passing checker if the LCOV file is absent or excludes all source files.

- [ ] **Step 5: Review and commit the coverage slice**

Run:

~~~bash
rtk git diff --check
rtk bun run check
~~~

Verify test fixtures cover exact-threshold success, aggregation, below-lines, below-functions, missing totals, zero totals, and malformed numbers. Commit:

~~~bash
rtk git add bunfig.toml tools/check-coverage.ts tests/tools/check-coverage.test.ts
rtk git commit -m "test: enforce coverage threshold"
~~~

### Task 3: Extend the clean verifier, workflow contract, and handoff documentation

**Files:**

- Create: `.github/workflows/ci.yml`
- Modify: `tools/verify-clean-checkout.ts`, `tests/config/handoff.test.ts`, `README.md`

**Interfaces:**

- The clean verifier archives `HEAD`, initializes Git metadata, executes the exact local quality/native matrix with `HUSKY=0`, and removes temporary artifacts in `finally`.
- Workflow job names are exactly `Quality` and `Tauri build`, which are the future branch-protection check names.
- `Quality` uploads an LCOV artifact and makes an OIDC Codecov upload best effort; `Tauri build` uploads a successful unsigned app/DMG bundle for seven days.

- [ ] **Step 1: Make the handoff contract fail before workflow changes**

In `tests/config/handoff.test.ts`:

1. Rename the archive-matrix test to say `approved eleven-command matrix`.
2. Replace the old test command with `"['bun', 'run', 'test']"` and require all of these additional verifier argv strings:

~~~ts
"['bun', 'run', 'lint']",
"['bun', 'run', 'format:check']",
"['bun', 'run', 'test:coverage']",
"['bun', 'run', 'coverage:check']",
"['bun', 'run', 'tauri:build', '--', '--no-sign']",
~~~

Require the verifier to contain `HUSKY: '0'` and keep its archive, `git init`, inherited stdio, nonzero-exit, and `finally` assertions.

3. Add a test that reads `.github/workflows/ci.yml` and requires the exact workflow boundary:

~~~ts
for (const expected of [
  'name: CI',
  'pull_request:',
  'workflow_dispatch:',
  'group: ${{ github.workflow }}-${{ github.ref }}',
  'cancel-in-progress: true',
  'name: Quality',
  'runs-on: ubuntu-latest',
  'name: Tauri build',
  'runs-on: macos-latest',
  'actions/checkout@v7',
  'oven-sh/setup-bun@v2',
  'dtolnay/rust-toolchain@1.96.0',
  'bun install --frozen-lockfile',
  'HUSKY: "0"',
  'bun run test:e2e:install:ci',
  'bun run test:coverage',
  'bun run coverage:check',
  'codecov/codecov-action@v7',
  'use_oidc: true',
  'continue-on-error: true',
  'fail_ci_if_error: false',
  'actions/upload-artifact@v7',
  'if: failure()',
  'retention-days: 7',
  'bun run tauri:build -- --no-sign',
]) expect(workflow).toContain(expected);
~~~

Additionally assert `workflow.match(/runs-on:/g)` has length two; split the YAML string at `tauri-build:` and assert the macOS portion does not contain `test:e2e` or `playwright`; and assert the `id-token: write` string appears exactly once before that split. This makes the two-job, browser/native separation a tested contract rather than just documentation.

4. Replace the old `bun test` README required-command item with `bun run test`, then extend that required-command loop with `bun run lint`, `bun run format:check`, `bun run test:coverage`, `bun run coverage:check`, and `bun run tauri:build -- --no-sign`.

Run: `rtk bun test tests/config/handoff.test.ts`

Expected: FAIL because the workflow is missing and the existing verifier/documentation retain the seven-command, signed-build contract.

- [ ] **Step 2: Extend the archive verifier without replacing its safeguards**

In `tools/verify-clean-checkout.ts`, set a single child environment and pass it to every `run` spawn:

~~~ts
const verificationEnv = { ...process.env, HUSKY: '0' };
// inside run's Bun.spawn options
env: verificationEnv,
~~~

Use this exact ordered command matrix:

~~~ts
const commands: string[][] = [
  ['bun', 'install', '--frozen-lockfile'],
  ['bun', 'run', 'test:e2e:install'],
  ['bun', 'run', 'check'],
  ['bun', 'run', 'lint'],
  ['bun', 'run', 'format:check'],
  ['bun', 'run', 'test'],
  ['bun', 'run', 'test:coverage'],
  ['bun', 'run', 'coverage:check'],
  ['bun', 'run', 'test:e2e'],
  ['bun', 'run', 'build'],
  ['bun', 'run', 'tauri:build', '--', '--no-sign'],
];
~~~

Keep archive extraction, `git init`, inherited stdio, nonzero failure propagation, and both `rm` calls in `finally` intact.

- [ ] **Step 3: Create the two-job GitHub Actions workflow**

Create `.github/workflows/ci.yml` with this complete structure. Keep `id-token: write` scoped to `Quality`, where the Codecov OIDC exchange occurs.

~~~yaml
name: CI

on:
  push:
  pull_request:
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  quality:
    name: Quality
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v7
      - uses: oven-sh/setup-bun@v2
      - name: Install dependencies
        run: bun install --frozen-lockfile
        env:
          HUSKY: "0"
      - name: Static check
        run: bun run check
      - name: Lint
        run: bun run lint
      - name: Format check
        run: bun run format:check
      - name: Unit tests
        run: bun run test
      - name: Unit test coverage
        run: bun run test:coverage
      - name: Enforce coverage threshold
        run: bun run coverage:check
      - name: Upload LCOV artifact
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: coverage-lcov
          path: coverage/lcov.info
          if-no-files-found: warn
          retention-days: 7
      - name: Upload coverage to Codecov
        if: success()
        continue-on-error: true
        uses: codecov/codecov-action@v7
        with:
          use_oidc: true
          files: ./coverage/lcov.info
          disable_search: true
          flags: unit
          fail_ci_if_error: false
      - name: Install Chromium
        run: bun run test:e2e:install:ci
      - name: Browser E2E
        run: bun run test:e2e
      - name: Frontend build
        run: bun run build
      - name: Upload Playwright failures
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: playwright-failures
          path: test-results/
          if-no-files-found: ignore
          retention-days: 7

  tauri-build:
    name: Tauri build
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v7
      - uses: oven-sh/setup-bun@v2
      - uses: dtolnay/rust-toolchain@1.96.0
      - name: Install dependencies
        run: bun install --frozen-lockfile
        env:
          HUSKY: "0"
      - name: Build unsigned macOS bundle
        run: bun run tauri:build -- --no-sign
      - name: Upload unsigned bundle
        if: success()
        uses: actions/upload-artifact@v7
        with:
          name: phoenix-macos-unsigned
          path: src-tauri/target/release/bundle/
          if-no-files-found: error
          retention-days: 7
~~~

No other job, platform matrix, cache, deployment, test retry, native driver, signing secret, or release step belongs in this workflow.

- [ ] **Step 4: Update the README truthfully**

Replace the verification command block with:

~~~bash
bun run check
bun run lint
bun run format:check
bun run test
bun run test:coverage
bun run coverage:check
bun run test:e2e
bun run build
bun run tauri:build -- --no-sign
bun run verify:clean
~~~

Immediately below it, explain that `test:coverage` writes `coverage/lcov.info`, `coverage:check` fails below 90% measured lines or functions, Codecov is a non-blocking copy of that report, and `tauri:build -- --no-sign` is an unsigned CI/local proof rather than a distributable release. Update the `verify:clean` sentence to list its frozen install, local Chromium, static/lint/format, plain unit, coverage/gate, browser E2E, frontend, and unsigned macOS bundle checks.

Add a final short GitHub administration note: after this workflow has run on the remote target branch, protect that branch and require the checks named `Quality` and `Tauri build`. Do not try to set branch protection locally.

- [ ] **Step 5: Run focused GREEN and commit the delivery contract**

Run:

~~~bash
rtk bun test tests/config/handoff.test.ts
rtk bun run lint
rtk bun run format:check
rtk bun run check
~~~

Expected: all pass, with static contracts showing exactly two jobs and the clean archive flow still protected by `finally` cleanup.

Review then commit:

~~~bash
rtk git diff --check
rtk git add .github/workflows/ci.yml tools/verify-clean-checkout.ts tests/config/handoff.test.ts README.md
rtk git commit -m "ci: add quality and macOS build gates"
~~~

### Task 4: Run the complete acceptance matrix and hand off the remote gate

**Files:** No intended new production/configuration files. Only source fixes that are directly required to make the approved checks pass may be made, followed by rerunning their focused tests.

- [ ] **Step 1: Verify frozen dependency installation and every local quality boundary**

Run in this order:

~~~bash
rtk bun install --frozen-lockfile
rtk bun run lint
rtk bun run format:check
rtk bun run check
rtk bun run test
rtk bun run test:coverage
rtk bun run coverage:check
rtk bun run test:e2e
rtk bun run build
rtk bun run tauri:build -- --no-sign
rtk bun run verify:clean
~~~

Expected: every command exits zero. The coverage command must create an LCOV file and the checker must report at least 90.00% for lines and functions. The final archive run repeats the local Chromium install and unsigned native build in an isolated checkout; do not substitute a non-frozen local run for it.

- [ ] **Step 2: Audit the final worktree and implementation boundaries**

Run:

~~~bash
rtk git diff --check
rtk git status --short
rtk rg -n "tauri-driver|webdriver|notar|signing|release|deploy" .github/workflows/ci.yml README.md package.json tools/verify-clean-checkout.ts
~~~

Expected: no whitespace errors; only planned files are modified; the final search contains the intended `--no-sign`/documentation wording but no added release, signing, notarization, deployment, or native-driver mechanism.

- [ ] **Step 3: Make branch protection actionable, without mutating remote state**

Record in the handoff that no Git remote is configured in this checkout, so Actions/Codecov and branch-protection success cannot be observed locally. Once a remote push is authorized, verify the first workflow run and configure the target branch to require exactly `Quality` and `Tauri build`. Do not claim remote status checks passed before that run exists.
