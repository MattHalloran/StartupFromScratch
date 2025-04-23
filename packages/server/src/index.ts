import express, { Request, Response } from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { getSsoConfig } from './db/sso-config.js';
// No longer using entry-server render helper (simplified routes)

// Determine __dirname equivalent in ES module scope
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 4000;

// Serve static assets: in development/test serve from `src`, in production from `dist`
const serverRoot = __dirname;
const uiPackageRoot = path.resolve(serverRoot, '../../../packages/ui');
const clientDist = process.env.NODE_ENV !== 'production'
  ? path.join(uiPackageRoot, 'src')
  : path.join(uiPackageRoot, 'dist');

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

/**
 * Compose head tags including SSO and OpenGraph metadata.
 */
function composeHeadTags(
  sso: { clientId: string; issuer: string },
  og: { title: string; description?: string; url?: string; image?: string }
): string {
  const tags = [
    `<meta name="sso-client-id" content="${sso.clientId}"/>`,
    `<meta name="sso-issuer" content="${sso.issuer}"/>`,
    `<meta property="og:title" content="${og.title}"/>`,
    og.description ? `<meta property="og:description" content="${og.description}"/>` : '',
    og.url ? `<meta property="og:url" content="${og.url}"/>` : '',
    og.image ? `<meta property="og:image" content="${og.image}"/>` : ''
  ];
  return tags.filter(Boolean).join('');
}

// Simple UI routes with dummy SSO meta for smoke testing
app.get('/', async (req: Request, res: Response) => {
  const sso = await getSsoConfig();
  const headTags = composeHeadTags(sso, {
    title: 'Home Page',
    description: 'Welcome to StartupFromScratch!',
    url: `${req.protocol}://${req.get('host')}${req.originalUrl}`
  });
  const homeHtml = template
    .replace('<!--%HEAD_TAGS%-->', headTags)
    .replace('<!--app-html-->', '<h2>Home Page</h2>');
  res.send(homeHtml);
});

app.get('/about', async (req: Request, res: Response) => {
  const sso = await getSsoConfig();
  const headTags = composeHeadTags(sso, {
    title: 'About Page',
    description: 'Learn more about StartupFromScratch.',
    url: `${req.protocol}://${req.get('host')}${req.originalUrl}`
  });
  const aboutHtml = template
    .replace('<!--%HEAD_TAGS%-->', headTags)
    .replace('<!--app-html-->', '<h2>About Page</h2>');
  res.send(aboutHtml);
});

// Serve static assets AFTER specific SSR routes
app.use(express.static(clientDist));

// Start server unless in test environment
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });
}

// Export Express app for testing
export default app; 