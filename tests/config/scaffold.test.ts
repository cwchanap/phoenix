import { describe, expect, test } from 'bun:test';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dir, '../..');

describe('Phoenix scaffold', () => {
  test('pins the approved direct JavaScript dependencies', async () => {
    const pkg = await Bun.file(resolve(root, 'package.json')).json();
    expect(pkg.packageManager).toBe('bun@1.3.1');
    expect(pkg.dependencies).toEqual({ phaser: '4.2.1', svelte: '5.56.8' });
    expect(pkg.devDependencies).toEqual({
      '@playwright/test': '1.62.1',
      '@sveltejs/vite-plugin-svelte': '7.3.0',
      '@tauri-apps/cli': '2.11.4',
      '@typescript/native': 'npm:typescript@7.0.2',
      '@types/bun': '1.3.14',
      'svelte-check': '4.7.5',
      typescript: '6.0.3',
      vite: '8.2.1',
    });
    expect(pkg.scripts.check).toBe('svelte-check --tsconfig ./tsconfig.json --tsgo');
  });

  test('uses only Bun and Cargo lockfiles', () => {
    expect(existsSync(resolve(root, 'bun.lock'))).toBe(true);
    expect(existsSync(resolve(root, 'src-tauri/Cargo.lock'))).toBe(true);
    for (const forbidden of ['package-lock.json', 'pnpm-lock.yaml', 'yarn.lock']) {
      expect(existsSync(resolve(root, forbidden))).toBe(false);
    }
  });

  test('configures the macOS-first Tauri window and Bun hooks', async () => {
    const config = await Bun.file(resolve(root, 'src-tauri/tauri.conf.json')).json();
    expect(config.identifier).toBe('com.hapadona.phoenix');
    expect(config.build).toEqual({
      beforeDevCommand: 'bun run dev',
      beforeBuildCommand: 'bun run build',
      devUrl: 'http://localhost:1420',
      frontendDist: '../dist',
    });
    expect(config.app.windows[0]).toMatchObject({
      label: 'main', title: 'Phoenix', width: 1280, height: 720,
      minWidth: 640, minHeight: 360,
    });
  });
});
