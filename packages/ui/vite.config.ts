import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default ({ mode, ssrBuild }: { mode: string; ssrBuild: boolean }) => {
  // Load env variables prefixed with VITE_
  const env = loadEnv(mode, process.cwd(), 'VITE_');

  return defineConfig({
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
      },
    },
    server: {
      port: 3000,
      open: true,
    },
    define: {
      __API_URL__: JSON.stringify(env.VITE_API_URL),
    },
    // Build settings for client vs SSR
    build: ssrBuild
      ? {
          ssr: 'src/entry-server.tsx',
          outDir: path.resolve(__dirname, '../server/dist'),
          rollupOptions: {
            input: 'src/entry-server.tsx',
          },
        }
      : {
          outDir: 'dist',
        },
  });
}; 