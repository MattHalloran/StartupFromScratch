import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default ({ mode }: { mode: string }) => {
  // Load environment variables prefixed with VITE_
  const env = loadEnv(mode, process.cwd(), 'VITE_');

  return defineConfig({
    // Root directory for dev server and build
    root: path.resolve(__dirname, 'src'),
    // Base public path
    base: './',
    // Plugins
    plugins: [react()],
    resolve: {
      alias: { '@': path.resolve(__dirname, 'src') },
    },
    server: {
      port: 3000,
      open: false,
    },
    define: {
      __API_URL__: JSON.stringify(env.VITE_API_URL),
    },
    build: {
      // Output directory for production build
      outDir: path.resolve(__dirname, 'dist'),
      emptyOutDir: true,
      rollupOptions: {
        // Use HTML entry
        input: path.resolve(__dirname, 'src/index.html'),
      },
    },
  });
}; 