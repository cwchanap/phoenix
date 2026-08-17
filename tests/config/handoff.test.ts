import { describe, expect, test } from 'bun:test';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');

describe('Task 8 handoff contract', () => {
  test('documents the macOS-only setup, controls, checks, ownership, and map contract', async () => {
    const readmePath = resolve(root, 'README.md');
    expect(existsSync(readmePath)).toBe(true);

    const readme = await Bun.file(readmePath).text();
    expect(readme).toMatch(/macOS/i);
    expect(readme).toMatch(
      /does not\s+claim\s+(?:acceptance|verification)\s+for Windows or Linux/i,
    );
    for (const prerequisite of [
      'Bun 1.3.1',
      'Rust/Cargo 1.96',
      'Xcode command-line tools',
      'bun install',
      'bun run test:e2e:install',
      'bun run dev',
      'bun run tauri:dev',
      'WASD',
      'input lock',
      'bun run check',
      'bun test',
      'bun run test:e2e',
      'bun run build',
      'bun run tauri:build',
      'bun run verify:clean',
      'framework-free TypeScript',
      'Phaser',
      'Svelte',
      'Tauri',
      '12×12',
      '64×32',
      'embedded Tiled tilesets',
    ]) {
      expect(readme.toLowerCase()).toContain(prerequisite.toLowerCase());
    }
    for (const dailyRhythmText of [
      'HPA-592',
      '06:00',
      '22:00',
      '20 stamina',
      'Sunny',
      'Rainy',
      'Morning summary',
      'Start Day',
      'Day 14',
    ]) {
      expect(readme.toLowerCase()).toContain(dailyRhythmText.toLowerCase());
    }
    for (const economyText of [
      'HPA-593',
      '150G',
      'Turnip',
      'Potato',
      'Pumpkin',
      '3 watered nights',
      '5 watered nights',
      '7 watered nights',
      'Seed shop',
      'Shipping bin',
      '20G',
      '35G',
      '40G',
      '75G',
      '70G',
      '140G',
      'Select Turnip',
      'Select Potato',
      'Select Pumpkin',
      'minus, plus, Max',
      'Deposit',
      'Shipping income',
      'reinvest',
      'shop cell 6,7',
      'adjacent shop-counter cell at 6,7',
      'shipping cell 6,10',
    ]) {
      expect(readme.toLowerCase()).toContain(economyText.toLowerCase());
    }
  });

  test('verifies an exact committed archive with the approved seven-command matrix', async () => {
    const verifierPath = resolve(root, 'tools/verify-clean-checkout.ts');
    expect(existsSync(verifierPath)).toBe(true);

    const verifier = await Bun.file(verifierPath).text();
    for (const command of [
      "['bun', 'install', '--frozen-lockfile']",
      "['bun', 'run', 'test:e2e:install']",
      "['bun', 'run', 'check']",
      "['bun', 'test']",
      "['bun', 'run', 'test:e2e']",
      "['bun', 'run', 'build']",
      "['bun', 'run', 'tauri:build']",
    ]) {
      expect(verifier).toContain(command);
    }
    expect(verifier).toContain("mkdtemp(join(tmpdir(), 'phoenix-clean-'))");
    expect(verifier).toMatch(/git['",\s]+archive['",\s]+[^\n]*HEAD/);
    expect(verifier).toContain("stdin: 'inherit'");
    expect(verifier).toContain("stdout: 'inherit'");
    expect(verifier).toContain("stderr: 'inherit'");
    expect(verifier).toMatch(/if \(code !== 0\)/);
    expect(verifier).toMatch(/finally\s*\{/);
    expect(verifier).toContain('rm(archive');
    expect(verifier).toContain('rm(checkout');
  });

  test('passes mutable argv arrays to Bun.spawn', async () => {
    const verifier = await Bun.file(resolve(root, 'tools/verify-clean-checkout.ts')).text();
    expect(verifier).not.toContain('readonly string[]');
    expect(verifier).not.toContain("['git', 'archive', '--format=tar', 'HEAD'] as const");
  });

  test('initializes Git metadata in the archive checkout for ignore checks', async () => {
    const verifier = await Bun.file(resolve(root, 'tools/verify-clean-checkout.ts')).text();
    expect(verifier).toContain("run(['git', 'init'], checkout)");
  });

  test('exposes the committed clean-checkout verifier through Bun', async () => {
    const pkg = await Bun.file(resolve(root, 'package.json')).json();
    expect(pkg.scripts?.['verify:clean']).toBe('bun run tools/verify-clean-checkout.ts');
  });
});
