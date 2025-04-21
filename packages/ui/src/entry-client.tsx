// Entry point for client-side hydration
import React from 'react';
import { hydrateRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { HelmetProvider } from 'react-helmet-async';
import App from './App';

const container = document.getElementById('root');
if (container) {
  hydrateRoot(
    container,
    <HelmetProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </HelmetProvider>
  );
} else {
  console.error('Root container missing in HTML');
} 