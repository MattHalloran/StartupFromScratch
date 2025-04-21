# Development Guide

This guide explains how to develop StartupFromScratch both with Docker and natively (Windows/Mac/Linux) using the `scripts/develop.sh` entrypoint or the one‑click executables.

## Prerequisites

- **Node.js** (v18+) and **Yarn** (v4) installed locally
- **Docker** & **Docker Compose** (if using Docker mode)
- **Corepack** enabled for Yarn:
  ```bash
  corepack enable
  ```
- Environment files:
  - `.env-dev` (local dev)
  - Optional: `.env-test` (for tests)

## Setting Up Dev Environment

1. **Clone the repo**:
   ```bash
   git clone <repo-url> StartupFromScratch
   cd StartupFromScratch
   ```

2. **Install dependencies and generate Prisma client**:
   ```bash
   bash scripts/setup.sh
   ```

3. **Prepare `.env-dev`** (if not already):
   ```bash
   cp .env-example .env-dev
   # Edit values as needed for your local DB and Redis
   ```

## Docker‑Backed Development

Run all services in containers, with shared code mounted:

```bash
# Default: uses .env-dev inside containers
bash scripts/develop.sh
```

- This spins up Postgres (pgvector), Redis, server, jobs, and UI via Docker Compose.  
- Logs stream in the terminal. Ctrl+C to stop.

## Native (Non‑Docker) Development

Run services entirely on your machine:

```bash
USE_DOCKER=false bash scripts/develop.sh
```

- Links the appropriate Prisma schema (`.env-dev` vs `.env-prod`).  
- Launches TypeScript watchers for:
  - `yarn workspace @startupfromscratch/server dev`  – **SSR-enabled Express server** at `http://localhost:4000` that renders React on the server and hydrates on the client
  - `yarn workspace @startupfromscratch/jobs dev`
  - `yarn workspace @startupfromscratch/ui dev`

## SSR Development

Once you've scaffolded the SSR entries and configured `server/src/index.ts` for server-side rendering:

1. Ensure your UI is building in watch mode:
   ```bash
   USE_DOCKER=false bash scripts/develop.sh  # this already starts the Vite dev server and SSR server
   ```
2. In your browser, navigate to `http://localhost:4000/` to see the app pre-rendered on the server (view source to confirm HTML) and hydrated on the client.
3. Edit your React components or data-loaders; both Vite HMR and `ts-node-dev` will reload the UI and SSR server automatically.

### Database‑driven SSR meta tags

Instead of static env‑injected placeholders, you can fetch fresh SSO settings from your database on each request and render meta tags programmatically via React Helmet:

```ts
// packages/server/src/index.ts
import express from 'express';
import { renderToString } from 'react-dom/server';
import { StaticRouter }   from 'react-router-dom/server';
import { HelmetProvider } from 'react-helmet-async';
import App                from '../../../ui/dist/App.js';
import { getSsoConfig }   from '../db/sso-config';

const app = express();
// ...mount static, API, webhook routes first...

// SSR catch‑all
app.get('*', async (req, res) => {
  const { clientId, issuer } = await getSsoConfig();
  const helmetContext = {};
  const appHtml = renderToString(
    <HelmetProvider context={helmetContext}>
      <StaticRouter location={req.url}>
        <App sso={{ clientId, issuer }} />
      </StaticRouter>
    </HelmetProvider>
  );
  const { helmet } = helmetContext;
  const html = template
    .replace('<!--%HEAD_TAGS%-->', helmet.meta.toString())
    .replace('<!--app-html-->', appHtml);
  res.send(html);
});
```

In your top‑level React component (e.g. `App.tsx`), consume the `sso` prop and emit:

```tsx
import { Helmet } from 'react-helmet-async';

interface AppProps { sso: { clientId: string; issuer: string } }

export function App({ sso }: AppProps) {
  return (
    <>
      <Helmet>
        <meta name="sso-client-id" content={sso.clientId} />
        <meta name="sso-issuer"    content={sso.issuer}    />
      </Helmet>
      {/* ...rest of your app... */}
    </>
  );
}
```

Every SSR render now reads the latest values from your database and injects them into the HTML head.

## Windows/Mac One‑Click Start

We offer bundled executables for each platform (built via `pkg`):

- `StartupFromScratch-win.exe`
- `StartupFromScratch-mac`

Usage:
```bash
# On Windows
./StartupFromScratch-win.exe --production

# On macOS/Linux
./StartupFromScratch-mac -p
```

These binaries will:
1. Read the appropriate `.env-dev` or `.env-prod`
2. Start the server (SQLite if `USE_DOCKER=false` internally)
3. Open your browser at `http://localhost:...`

--- 