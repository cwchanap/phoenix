import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.pw.ts',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: 'line',
  use: {
    baseURL: 'http://localhost:1422',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'bun run dev -- --port 1422',
    url: 'http://localhost:1422',
    reuseExistingServer: false,
    env: { ...process.env, CHOKIDAR_USEPOLLING: 'true' },
  },
});
