/// <reference types="vitest/config" />
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// VITE_BASE_PATH erlaubt das Hosting in einem Unterordner (z. B. GitHub Pages: "/repo-name/").
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  const base = env.VITE_BASE_PATH || '/';
  // Für „Liste fest einbauen“: Repository und Branch. Netlify setzt REPOSITORY_URL und BRANCH beim Build automatisch.
  const repoFromUrl = (process.env.REPOSITORY_URL ?? '').match(/github\.com[/:]([^/]+\/[^/.]+)/)?.[1] ?? '';
  return {
    base,
    define: {
      __GITHUB_REPO__: JSON.stringify(env.VITE_GITHUB_REPO || repoFromUrl),
      __GITHUB_BRANCH__: JSON.stringify(env.VITE_GITHUB_BRANCH || process.env.BRANCH || ''),
    },
    plugins: [react()],
    server: { host: '127.0.0.1', port: 5173 },
    preview: { host: '127.0.0.1', port: 4173 },
    test: {
      environment: 'node',
      include: ['src/**/*.test.ts'],
    },
  };
});
