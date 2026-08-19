import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [svelte()],
  envPrefix: ['VITE_', 'TAURI_ENV_'],
  server: {
    host: 'localhost',
    port: 1420,
    strictPort: true,
    watch: {
      ignored: ['**/src-tauri/**'],
      ...(process.env.CHOKIDAR_USEPOLLING === 'true' ? { usePolling: true } : {}),
    },
  },
});
