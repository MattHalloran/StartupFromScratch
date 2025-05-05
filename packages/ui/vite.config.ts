import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default ({ mode }: { mode: string }) => {
  // Load environment variables prefixed with VITE_
  const env = loadEnv(mode, process.cwd(), 'VITE_');

  // Extract hostname from VITE_API_URL
  let apiHost = 'localhost'; // Default fallback
  let doOriginHost = 'localhost';
  try {
    if (env.VITE_API_URL) {
      const apiUrl = new URL(env.VITE_API_URL);
      apiHost = apiUrl.hostname; // e.g., rustyisthebest.com
      doOriginHost = `do-origin.${apiHost}`; // e.g., do-origin.rustyisthebest.com
    }
  } catch (error) {
    console.error('Error parsing VITE_API_URL for allowedHosts:', error);
  }

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
      host: '0.0.0.0',
      port: parseInt(env.VITE_PORT_UI || '3000', 10), // Ensure port is a number
      open: false,
      allowedHosts: [
        // Dynamically allow the host derived from VITE_API_URL
        apiHost,
        // Allow the corresponding do-origin host
        doOriginHost,
        // Keep localhost and default IP addresses allowed
        'localhost',
      ],
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