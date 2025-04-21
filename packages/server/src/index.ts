import express, { Request, Response } from 'express';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { getSsoConfig } from './db/sso-config';
// No longer using entry-server render helper (simplified routes)

// Load environment variables (.env-dev / .env-prod)
dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

// Serve static assets: in development/test serve from `src`, in production from `dist`
const serverRoot = __dirname;
const uiPackageRoot = path.resolve(serverRoot, '../../packages/ui');
const clientDist = process.env.NODE_ENV !== 'production'
  ? path.join(uiPackageRoot, 'src')
  : path.join(uiPackageRoot, 'dist');
app.use(express.static(clientDist));

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

// TODO: mount your API and webhook routers before SSR
// e.g., app.use('/api', apiRouter);

// Load HTML template once (fallback to src/index.html in test)
const templatePath = path.join(clientDist, 'index.html');
if (!fs.existsSync(templatePath)) {
  throw new Error(`UI template not found at ${templatePath}`);
}
const template = fs.readFileSync(templatePath, 'utf-8');

// Simple UI routes with dummy SSO meta for smoke testing
app.get('/', async (req: Request, res: Response) => {
  const { clientId, issuer } = await getSsoConfig();
  const homeHtml = template
    .replace('<!--%HEAD_TAGS%-->', `<meta name="sso-client-id" content="${clientId}"/><meta name="sso-issuer" content="${issuer}"/>`)
    .replace('<!--app-html-->', '<h2>Home Page</h2>');
  res.send(homeHtml);
});

app.get('/about', async (req: Request, res: Response) => {
  const { clientId, issuer } = await getSsoConfig();
  const aboutHtml = template
    .replace('<!--%HEAD_TAGS%-->', `<meta name="sso-client-id" content="${clientId}"/><meta name="sso-issuer" content="${issuer}"/>`)
    .replace('<!--app-html-->', '<h2>About Page</h2>');
  res.send(aboutHtml);
});

// Start server unless in test environment
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });
}

// Export Express app for testing
export default app; 