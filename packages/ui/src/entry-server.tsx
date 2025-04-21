// Entry point for server-side rendering
import React from 'react';
import { StaticRouter } from 'react-router-dom/server';
import { HelmetProvider } from 'react-helmet-async';
import App from './App';

/**
 * This file is used by Vite's SSR build.
 * It should export the React app as a string for any given URL.
 */
export function render(url: string, context: Record<string, any>) {
  const helmetContext: any = {};
  const appHtml = React.createElement(
    HelmetProvider,
    { context: helmetContext },
    React.createElement(
      StaticRouter,
      { location: url, ...context },
      React.createElement(App, context)
    )
  );
  const html = require('react-dom/server').renderToString(appHtml);
  return { html, helmet: helmetContext.helmet };
} 