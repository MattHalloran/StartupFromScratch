// vite.config.ts
import { defineConfig, loadEnv } from "file:///root/StartupFromScratch/node_modules/vite/dist/node/index.js";
import react from "file:///root/StartupFromScratch/node_modules/@vitejs/plugin-react/dist/index.mjs";
import path from "path";
var __vite_injected_original_dirname = "/root/StartupFromScratch/packages/ui";
var vite_config_default = ({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "VITE_");
  return defineConfig({
    // Root directory for dev server and build
    root: path.resolve(__vite_injected_original_dirname, "src"),
    // Base public path
    base: "./",
    // Plugins
    plugins: [react()],
    resolve: {
      alias: { "@": path.resolve(__vite_injected_original_dirname, "src") }
    },
    server: {
      port: 3e3,
      open: false
    },
    define: {
      __API_URL__: JSON.stringify(env.VITE_API_URL)
    },
    build: {
      // Output directory for production build
      outDir: path.resolve(__vite_injected_original_dirname, "dist"),
      emptyOutDir: true,
      rollupOptions: {
        // Use HTML entry
        input: path.resolve(__vite_injected_original_dirname, "src/index.html")
      }
    }
  });
};
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCIvcm9vdC9TdGFydHVwRnJvbVNjcmF0Y2gvcGFja2FnZXMvdWlcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9yb290L1N0YXJ0dXBGcm9tU2NyYXRjaC9wYWNrYWdlcy91aS92aXRlLmNvbmZpZy50c1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwgPSBcImZpbGU6Ly8vcm9vdC9TdGFydHVwRnJvbVNjcmF0Y2gvcGFja2FnZXMvdWkvdml0ZS5jb25maWcudHNcIjtpbXBvcnQgeyBkZWZpbmVDb25maWcsIGxvYWRFbnYgfSBmcm9tICd2aXRlJztcbmltcG9ydCByZWFjdCBmcm9tICdAdml0ZWpzL3BsdWdpbi1yZWFjdCc7XG5pbXBvcnQgcGF0aCBmcm9tICdwYXRoJztcblxuZXhwb3J0IGRlZmF1bHQgKHsgbW9kZSB9OiB7IG1vZGU6IHN0cmluZyB9KSA9PiB7XG4gIC8vIExvYWQgZW52aXJvbm1lbnQgdmFyaWFibGVzIHByZWZpeGVkIHdpdGggVklURV9cbiAgY29uc3QgZW52ID0gbG9hZEVudihtb2RlLCBwcm9jZXNzLmN3ZCgpLCAnVklURV8nKTtcblxuICByZXR1cm4gZGVmaW5lQ29uZmlnKHtcbiAgICAvLyBSb290IGRpcmVjdG9yeSBmb3IgZGV2IHNlcnZlciBhbmQgYnVpbGRcbiAgICByb290OiBwYXRoLnJlc29sdmUoX19kaXJuYW1lLCAnc3JjJyksXG4gICAgLy8gQmFzZSBwdWJsaWMgcGF0aFxuICAgIGJhc2U6ICcuLycsXG4gICAgLy8gUGx1Z2luc1xuICAgIHBsdWdpbnM6IFtyZWFjdCgpXSxcbiAgICByZXNvbHZlOiB7XG4gICAgICBhbGlhczogeyAnQCc6IHBhdGgucmVzb2x2ZShfX2Rpcm5hbWUsICdzcmMnKSB9LFxuICAgIH0sXG4gICAgc2VydmVyOiB7XG4gICAgICBwb3J0OiAzMDAwLFxuICAgICAgb3BlbjogZmFsc2UsXG4gICAgfSxcbiAgICBkZWZpbmU6IHtcbiAgICAgIF9fQVBJX1VSTF9fOiBKU09OLnN0cmluZ2lmeShlbnYuVklURV9BUElfVVJMKSxcbiAgICB9LFxuICAgIGJ1aWxkOiB7XG4gICAgICAvLyBPdXRwdXQgZGlyZWN0b3J5IGZvciBwcm9kdWN0aW9uIGJ1aWxkXG4gICAgICBvdXREaXI6IHBhdGgucmVzb2x2ZShfX2Rpcm5hbWUsICdkaXN0JyksXG4gICAgICBlbXB0eU91dERpcjogdHJ1ZSxcbiAgICAgIHJvbGx1cE9wdGlvbnM6IHtcbiAgICAgICAgLy8gVXNlIEhUTUwgZW50cnlcbiAgICAgICAgaW5wdXQ6IHBhdGgucmVzb2x2ZShfX2Rpcm5hbWUsICdzcmMvaW5kZXguaHRtbCcpLFxuICAgICAgfSxcbiAgICB9LFxuICB9KTtcbn07ICJdLAogICJtYXBwaW5ncyI6ICI7QUFBOFIsU0FBUyxjQUFjLGVBQWU7QUFDcFUsT0FBTyxXQUFXO0FBQ2xCLE9BQU8sVUFBVTtBQUZqQixJQUFNLG1DQUFtQztBQUl6QyxJQUFPLHNCQUFRLENBQUMsRUFBRSxLQUFLLE1BQXdCO0FBRTdDLFFBQU0sTUFBTSxRQUFRLE1BQU0sUUFBUSxJQUFJLEdBQUcsT0FBTztBQUVoRCxTQUFPLGFBQWE7QUFBQTtBQUFBLElBRWxCLE1BQU0sS0FBSyxRQUFRLGtDQUFXLEtBQUs7QUFBQTtBQUFBLElBRW5DLE1BQU07QUFBQTtBQUFBLElBRU4sU0FBUyxDQUFDLE1BQU0sQ0FBQztBQUFBLElBQ2pCLFNBQVM7QUFBQSxNQUNQLE9BQU8sRUFBRSxLQUFLLEtBQUssUUFBUSxrQ0FBVyxLQUFLLEVBQUU7QUFBQSxJQUMvQztBQUFBLElBQ0EsUUFBUTtBQUFBLE1BQ04sTUFBTTtBQUFBLE1BQ04sTUFBTTtBQUFBLElBQ1I7QUFBQSxJQUNBLFFBQVE7QUFBQSxNQUNOLGFBQWEsS0FBSyxVQUFVLElBQUksWUFBWTtBQUFBLElBQzlDO0FBQUEsSUFDQSxPQUFPO0FBQUE7QUFBQSxNQUVMLFFBQVEsS0FBSyxRQUFRLGtDQUFXLE1BQU07QUFBQSxNQUN0QyxhQUFhO0FBQUEsTUFDYixlQUFlO0FBQUE7QUFBQSxRQUViLE9BQU8sS0FBSyxRQUFRLGtDQUFXLGdCQUFnQjtBQUFBLE1BQ2pEO0FBQUEsSUFDRjtBQUFBLEVBQ0YsQ0FBQztBQUNIOyIsCiAgIm5hbWVzIjogW10KfQo=
